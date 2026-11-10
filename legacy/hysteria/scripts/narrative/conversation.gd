class_name Conversation
extends Node
## Plays a dialogue graph (content/dialogue/<id>.json) in the world, with the real characters
## where they stand: no cutaway, no menu screen. Kurt is voiced: the player picks an intent (a
## few words, and the way he says it: direct, observant, empathetic, humorous, defensive,
## intimidating), and Kurt says the whole authored line.
##
## Node types
##   line    {speaker, text, [id], [cond], [set], next}
##   choice  {options: [{id, intent, style, line: {text}, [cond], [once], [set], [socko], next}]}
##   branch  {cases: [{cond, next}], else}
##   action  {set, next}
##   socko   {text, [mode], next}                           Socko, unprompted
##   end     {[set]}
## An option's `socko` is Socko taking part in Kurt's line, deliberately, never at random:
##   aside      Kurt says his line; Socko adds something under it
##   interrupt  Kurt starts; Socko cuts across him (Kurt's line is cut where `cut` says)
##   proxy      Socko says it for him (his version of what Kurt meant)
##   hijack     Kurt's own mouth says Socko's words
## Everything said is recorded: the option picked, the line actually delivered, by whom, how Socko
## came into it (Game.flags["dialogue"][id]). Conditions and actions: WorldState.

signal finished(id: String)
signal choice_offered(options: Array)

const DIR := "res://content/dialogue/"

var speech: Speech
var main: Node
var graph := {}
var id := ""
var actors := {}                # speaker id -> Node3D (where their voice comes from, where Kurt looks)
var state := {}                 # Game.flags["dialogue"][id]
var menu: ChoiceMenu
var auto_choices: Array = []    # tests: option ids to pick in order instead of asking
var pace := 1.0                 # tests: how much faster than spoken time to move on
var _running := false

static func load_graph(conv_id: String) -> Dictionary:
	var p := DIR + conv_id + ".json"
	if not FileAccess.file_exists(p): return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	return d if d is Dictionary else {}

func start(p_main: Node, conv_id: String, p_actors := {}) -> bool:
	main = p_main; speech = main.speech; id = conv_id; actors = p_actors
	graph = load_graph(conv_id)
	if graph.is_empty():
		push_error("Conversation: no graph '%s'" % conv_id); return false
	var all: Dictionary = WorldState.flags().get_or_add("dialogue", {})
	state = all.get_or_add(id, {"seen": {}, "history": []})
	speech.conversation = self
	menu = ChoiceMenu.new(); menu.name = "ChoiceMenu"; main.add_child(menu)
	_lock(true)
	_run.call_deferred(String(graph.get("start", "start")))
	return true

func _lock(on: bool) -> void:
	var p: Node = main.player
	p.set("locked", on)
	if on and actors.has(_other()):
		p.set("look_target", (actors[_other()] as Node3D).global_position + Vector3(0, float(graph.get("look_height", 1.4)), 0))
	elif not on:
		p.set("look_target", null)

func _other() -> String:
	for s in graph.get("participants", []):
		if s != "kurt" and s != "socko": return s
	return ""

func _run(node_id: String) -> void:
	_running = true
	var nodes: Dictionary = graph.get("nodes", {})
	while node_id != "" and nodes.has(node_id):
		var n: Dictionary = nodes[node_id]
		(state.seen as Dictionary)[node_id] = true
		if n.has("cond") and not WorldState.check_all(n.cond, state.seen):
			node_id = String(n.get("else", n.get("next", ""))); continue
		match String(n.get("type", "line")):
			"line":
				await _speak(String(n.speaker), String(n.text), String(n.get("id", "%s.%s" % [id, node_id])), String(n.get("emotion", "neutral")))
				WorldState.apply_all(n.get("set", []))
				node_id = String(n.get("next", ""))
			"socko":
				await _speak("socko", String(n.text), "%s.%s" % [id, node_id], String(n.get("emotion", "lying")))
				_record({"node": node_id, "socko_mode": String(n.get("mode", "aside")), "delivered": n.text, "by": "socko"})
				node_id = String(n.get("next", ""))
			"action":
				WorldState.apply_all(n.get("set", []))
				node_id = String(n.get("next", ""))
			"branch":
				var to := String(n.get("else", ""))
				for c in n.get("cases", []):
					if WorldState.check_all(c.get("cond", []), state.seen): to = String(c.next); break
				node_id = to
			"choice":
				node_id = await _choose(node_id, n)
			"end":
				WorldState.apply_all(n.get("set", []))
				node_id = ""
			_:
				push_error("Conversation %s: node %s has unknown type" % [id, node_id]); node_id = ""
	_finish()

func _choose(node_id: String, n: Dictionary) -> String:
	var opts: Array = []
	var taken: Dictionary = state.get_or_add("taken", {})
	for o in n.get("options", []):
		if o.get("once", false) and taken.has("%s/%s" % [node_id, o.id]): continue
		if o.has("cond") and not WorldState.check_all(o.cond, state.seen): continue
		opts.append(o)
	if opts.is_empty(): return String(n.get("else", ""))
	choice_offered.emit(opts)
	var pick: Dictionary
	if auto_choices.size() > 0:
		var want := String(auto_choices.pop_front())
		pick = opts[0]
		for o in opts: if String(o.id) == want: pick = o
	else:
		menu.offer(opts)
		pick = await menu.chosen
	taken["%s/%s" % [node_id, pick.id]] = true
	# Kurt's line, and Socko's part in it, if he has one here
	var line: Dictionary = pick.get("line", {})
	var said := String(line.get("text", ""))
	var vid := "%s.%s.%s" % [id, node_id, pick.id]
	var rec := {"node": node_id, "option": pick.id, "intent": pick.get("intent", ""), "style": pick.get("style", ""), "selected": said, "delivered": said, "by": "kurt"}
	var sk: Dictionary = pick.get("socko", {})
	match String(sk.get("mode", "")):
		"":
			if said != "": await _speak("kurt", said, vid)
		"aside":
			if said != "": await _speak("kurt", said, vid)
			await _speak("socko", String(sk.text), vid + ".socko", String(sk.get("emotion", "lying")))
		"interrupt":
			var cut := int(sk.get("cut", said.length() / 2))
			var part := said.substr(0, cut).strip_edges() + "—"
			await _speak("kurt", part, vid + ".cut", "neutral", 0.6)
			speech.stop()
			await _speak("socko", String(sk.text), vid + ".socko", String(sk.get("emotion", "impatient")))
			rec.delivered = part
		"proxy":
			await _speak("socko", String(sk.text), vid + ".socko", String(sk.get("emotion", "happy")))
			rec.delivered = sk.text; rec.by = "socko"
		"hijack":
			await _speak("kurt", String(sk.text), vid + ".hijack")
			rec.delivered = sk.text; rec.by = "kurt (socko)"
	rec["socko_mode"] = String(sk.get("mode", ""))
	if pick.has("react"): rec["react"] = pick.react
	_record(rec)
	WorldState.apply_all(pick.get("set", []))
	return String(pick.get("next", ""))

## say a line, and wait until it's been said (or `frac` of it, for a line that's cut off)
func _speak(speaker: String, text: String, vid: String, emotion := "neutral", frac := 1.0) -> void:
	var at = (actors[speaker] as Node3D).global_position + Vector3(0, 1.4, 0) if actors.has(speaker) else null
	var s = main.get("socko")
	if s and s.visible and actors.has(speaker): s.call("attend", at, 3.0)
	var dur := speech.say(speaker, text, vid, at, emotion)
	var t := 0.0
	while t < dur * frac / pace:
		await get_tree().process_frame
		t += get_process_delta_time()
	await get_tree().create_timer(0.25 / pace).timeout

func _record(r: Dictionary) -> void:
	r["time"] = Time.get_unix_time_from_system()
	(state.history as Array).append(r)

func _finish() -> void:
	_running = false
	if menu: menu.queue_free()
	speech.conversation = null
	_lock(false)
	finished.emit(id)
	queue_free()

# ================================================================ the choice menu
## Intents, a few words each, with the way Kurt would say it in small type: keys 1–9, the mouse,
## a thumb, or a pad (up/down, A). Sits above the subtitles, inside the safe area.
class ChoiceMenu extends CanvasLayer:
	signal chosen(option: Dictionary)
	var box: VBoxContainer
	var opts: Array = []
	var buttons: Array = []
	var _was_captured := false

	func _ready() -> void:
		layer = 9
		box = VBoxContainer.new(); box.add_theme_constant_override("separation", 6)
		add_child(box); box.visible = false

	func offer(p_opts: Array) -> void:
		opts = p_opts
		for b in buttons: b.queue_free()
		buttons.clear()
		for i in opts.size():
			var o: Dictionary = opts[i]
			var b := Button.new(); b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.text = "%d   %s%s" % [i + 1, String(o.intent), ("     · " + String(o.style)) if o.has("style") else ""]
			b.add_theme_font_size_override("font_size", 20)
			b.custom_minimum_size = Vector2(560, 52)
			for st in ["normal", "hover", "focus", "pressed"]:
				var sb := StyleBoxFlat.new()
				sb.bg_color = Color(0.04, 0.04, 0.04, 0.72) if st == "normal" else Color(0.16, 0.14, 0.11, 0.9)
				sb.border_color = Color(0.95, 0.85, 0.55, 0.9) if st == "focus" else Color(0.85, 0.82, 0.74, 0.25)
				sb.set_border_width_all(1); sb.set_corner_radius_all(4); sb.content_margin_left = 16
				b.add_theme_stylebox_override(st, sb)
			b.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
			b.pressed.connect(_pick.bind(i))
			box.add_child(b); buttons.append(b)
		var vp := get_viewport().get_visible_rect().size
		box.reset_size()
		box.position = Vector2((vp.x - 560) * 0.5, vp.y - 210 - box.size.y)
		box.visible = true
		_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if buttons.size() > 0: (buttons[0] as Button).grab_focus()

	func _unhandled_input(e: InputEvent) -> void:
		if not box.visible: return
		if e is InputEventKey and e.pressed and not e.echo:
			var n: int = (e as InputEventKey).keycode - KEY_1
			if n >= 0 and n < opts.size():
				_pick(n); get_viewport().set_input_as_handled()

	func _pick(i: int) -> void:
		box.visible = false
		if _was_captured: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		chosen.emit(opts[i])
