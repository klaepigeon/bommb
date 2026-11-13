extends Node
## Plays authored conversations from data/dialogue/*.json (autoload "Dialogue").
##
## A conversation is a list of steps. A step with "who" and "text" is a spoken line: shown as a
## subtitle, typed out with that voice's syllables, held long enough to read. A step with
## "event" is a stage direction that the level (or Socko) acts on: knocking, the grab, Socko going
## cross-eyed. Any step may carry:
##   "pause"  seconds of silence before it          "if"    a condition (Expression over
##   "hold"   extra seconds after a line                    `memories` and `flags`)
##   "socko"  a performance cue for Socko: {"emotion", "gesture", "look", "eyes"} (see Socko.cue)
##   "tone"   how it's delivered: "quiet" (smaller, slower), "shout" (louder), "aside"
## A step with "choices" stops for the player to pick what Kurt says (docs/SKILLS.md):
##   {"choices": [{"text": shown, "steps": [what follows], "if": condition, "tag": "memory" |
##   "telepathy" (marked, coloured), "locked": true (show it greyed when its condition fails)}]}
## The pick plays its "steps" and the conversation carries on. Conditions can test `memories`,
## `flags` and `skills` (unlocked skill ids: skills.has("s_telepathy")).
## The subtitles are part of this node, so every scene gets them without wiring.
##
## Branching (docs/DIALOGUE.md): any step may have an "id"; {"goto": id} jumps to it (in this
## conversation, or "other_conversation:id"); {"end": true} ends the conversation. Steps and
## choices may carry "do": a list of consequences, applied when reached / picked:
##   {"rel": who, "add": {key: n}} / {"rel": who, "set": {key: v}}   a relationship (Game.rel)
##   {"flag": name} / {"flag": {name: value}} / {"unflag": name}     story flags
##   {"know": [who, fact]}       what someone knows (rel.who.known)   {"give": item} / {"take": item}
##   {"event": name}             the level acts on it                  {"objective": text}
## A choice may carry "approach" ("cooperative", "neutral", "suspicious", "hostile", "deceptive")
## and the choice list "with" (who it's said to): the pick counts toward rel.<with>.approach.
## Conditions see memories, flags, skills, rel (Game.rel), inv (Game.inventory) and
## Relations.disposition(who) as disp(who) is not available: use rel.super.disposition.
## Speakers beyond Kurt, Socko and Marta are declared in any file's "_speakers":
##   {"super": {"name": "SUPERINTENDENT", "color": "#b8a07a"}}

signal line_started(step: Dictionary)
signal line_finished(step: Dictionary)
signal event(name: String, step: Dictionary)
signal syllable(who: String)
signal chose(index: int, option: Dictionary)

const TAGS := {"memory": ["[Memory] ", Color("e0c890")], "telepathy": ["[Telepathy] ", Color("9fd4ff")]}

var NAMES := {"kurt": "KURT", "socko": "SOCKO", "marta": "MARTA"}
var COLORS := {"kurt": Color("d6cbb3"), "socko": Color("f2c94c"), "marta": Color("9fc7b8")}
const APPROACHES := ["cooperative", "neutral", "suspicious", "hostile", "deceptive"]

var data := {}
var busy := false
var speaking := ""            # who is talking right now ("" for nobody)
var _gen := 0                 # bumps on stop(), so an interrupted conversation stops awaiting
var _skip := false

var _layer: CanvasLayer
var _panel: PanelContainer
var _name: Label
var _text: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for f in DirAccess.get_files_at("res://data/dialogue"):
		if f.ends_with(".json"):
			var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/" + f))
			if typeof(d) == TYPE_DICTIONARY:
				for k in d:
					if k == "_speakers":
						for who in d[k]:
							NAMES[who] = String(d[k][who].get("name", who.to_upper()))
							COLORS[who] = Color(String(d[k][who].get("color", "#ffffff")))
					elif typeof(d[k]) == TYPE_ARRAY: data[k] = d[k]       # (a conversation; anything else is a note)
			else:
				push_error("dialogue: can't parse " + f)
	_build_ui()

func has(id: String) -> bool:
	return data.has(id)

## Play a conversation and wait for it to end. Returns false if it was interrupted.
func play(id: String) -> bool:
	if not data.has(id):
		push_error("dialogue: no conversation " + id); return false
	stop()
	busy = true
	var g := _gen
	var conv := id
	var steps: Array = data[id]
	var jump: String = await _run(steps, g)
	while jump != "" and g == _gen:
		if jump == "<end>": break
		if jump.contains(":"):
			conv = jump.get_slice(":", 0); jump = jump.get_slice(":", 1)
			if not data.has(conv): push_error("dialogue: no conversation " + conv); break
		var at := _find(data[conv], jump)
		if at < 0: push_error("dialogue: no step '%s' in %s" % [jump, conv]); break
		steps = (data[conv] as Array).slice(at)
		jump = await _run(steps, g)
	if g == _gen:
		busy = false
		_panel.visible = false
	return g == _gen

## The index of the step with this "id" (top level of the conversation).
func _find(steps: Array, id: String) -> int:
	for i in steps.size():
		if typeof(steps[i]) == TYPE_DICTIONARY and String(steps[i].get("id", "")) == id: return i
	return -1

## Plays steps; returns where to jump next ("" carry on / done, "<end>", or a step id).
func _run(steps: Array, g: int) -> String:
	for step in steps:
		if g != _gen: return ""
		if step.has("if") and not test(step["if"]): continue
		var p: float = step.get("pause", 0.0)
		if p > 0.0:
			await _wait(p, g)
		if g != _gen: return ""
		if step.has("do"): apply(step["do"])
		if step.has("event"):
			event.emit(step.event, step)
			if step.has("wait"): await _wait(float(step.wait), g)
		elif step.has("choices"):
			var pick: Dictionary = await _choose(step.choices, g)
			if g != _gen: return ""
			if not pick.is_empty():
				if pick.has("approach") and step.has("with"):
					var r: Dictionary = Game.rel_of(String(step.with))
					var ap: Dictionary = r.get("approach", {})
					ap[pick.approach] = int(ap.get(pick.approach, 0)) + 1
					r["approach"] = ap
				if pick.has("do"): apply(pick["do"])
				var j: String = await _run(pick.get("steps", []), g)
				if j != "": return j
				if pick.has("goto"): return String(pick.goto)
		elif step.has("text"):
			if not (Game.hides_placeholders() and Game.is_placeholder(String(step.get("text", "")))):
				await _say(step, g)
		if step.get("end", false): return "<end>"
		if step.has("goto"): return String(step.goto)
	return ""

## Consequences (see the header). Reusable: levels and scripts call it too.
func apply(ops) -> void:
	if typeof(ops) == TYPE_DICTIONARY: ops = [ops]
	for op in ops:
		if op.has("rel"):
			var r: Dictionary = Game.rel_of(String(op.rel))
			for k in op.get("add", {}): r[k] = float(r.get(k, 0.0)) + float(op.add[k])
			for k in op.get("set", {}): r[k] = op.set[k]
		if op.has("flag"):
			if typeof(op.flag) == TYPE_DICTIONARY:
				for k in op.flag: Game.flags[k] = op.flag[k]
			else: Game.flags[String(op.flag)] = true
		if op.has("unflag"): Game.flags.erase(String(op.unflag))
		if op.has("know"):
			var r2: Dictionary = Game.rel_of(String(op.know[0]))
			var kn: Array = r2.get("known", [])
			if not kn.has(op.know[1]): kn.append(op.know[1])
			r2["known"] = kn
		if op.has("give"): Game.add_item(String(op.give))
		if op.has("take"): Game.take_item(String(op.take))
		if op.has("objective") and Game.level and Game.level.has_method("objective"): Game.level.objective(String(op.objective))
		if op.has("event"): event.emit(String(op.event), op)

# ------------------------------------------------------------------ choices
var _choice_box: VBoxContainer
var _picked := -1
var _options: Array = []

## Show the options (those whose condition holds, and locked ones greyed), wait for a pick.
func _choose(choices: Array, g: int) -> Dictionary:
	_panel.visible = false
	_options = []
	for c in _choice_box.get_children(): _choice_box.remove_child(c); c.queue_free()
	for c in choices:
		var ok: bool = not c.has("if") or test(c["if"])
		if not ok and not c.get("locked", false): continue
		var tag: Array = TAGS.get(c.get("tag", ""), ["", Color("ece6d6")])
		var b := Button.new()
		b.text = "%d.  %s%s" % [_options.size() + 1, tag[0], c.get("text", "")]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_color_override("font_color", tag[1] if ok else Color(0.5, 0.48, 0.44))
		b.disabled = not ok
		var i := _options.size()
		b.pressed.connect(func(): _picked = i)
		_choice_box.add_child(b)
		_options.append(c)
	if _options.is_empty(): return {}
	var lv = Game.level
	var was_cut: bool = lv.cutscene if lv and lv.get("cutscene") != null else true
	if lv and lv.has_method("set_cutscene"): lv.set_cutscene(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_choice_box.visible = true
	_picked = -1
	(_choice_box.get_child(0) as Button).call_deferred("grab_focus")
	while _picked < 0 and g == _gen:
		await get_tree().process_frame
	_choice_box.visible = false
	if lv and is_instance_valid(lv) and lv.has_method("set_cutscene"): lv.set_cutscene(was_cut)
	if not Game.uses_touch(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _picked < 0: return {}
	chose.emit(_picked, _options[_picked])
	return _options[_picked]

func choosing() -> bool:
	return _choice_box != null and _choice_box.visible

## Pick option `i` (0-based) as if clicked (number keys; tests).
func pick(i: int) -> void:
	if _choice_box.visible and i >= 0 and i < _options.size() and not (_choice_box.get_child(i) as Button).disabled:
		_picked = i

func _unhandled_input(e: InputEvent) -> void:
	if _choice_box and _choice_box.visible and e is InputEventKey and e.pressed and not e.echo:
		var n: int = e.keycode - KEY_1
		if n >= 0 and n < 9: pick(n); get_viewport().set_input_as_handled()

## Stop whatever is being said (a cutscene took over, the level changed).
func stop() -> void:
	_gen += 1
	busy = false; speaking = ""
	if _panel: _panel.visible = false
	if _choice_box: _choice_box.visible = false

## Hurry the current line (the player tapped / pressed the skip key).
func skip_line() -> void:
	_skip = true

func test(cond: String) -> bool:
	var e := Expression.new()
	if e.parse(cond, ["memories", "flags", "skills", "rel", "inv"]) != OK:
		push_error("dialogue: bad condition " + cond); return false
	for who in ["super", "socko"]: Game.rel_of(who)        # (so rel.super.x never fails)
	var r = e.execute([Game.memories, Game.flags, Game.skills, Game.rel, Game.inventory])
	return bool(r) if not e.has_execute_failed() else false

func _say(step: Dictionary, g: int) -> void:
	var who: String = step.get("who", "kurt")
	var text: String = step.get("text", "")
	var tone: String = step.get("tone", "")
	speaking = who
	_name.text = NAMES.get(who, who.to_upper())
	_name.add_theme_color_override("font_color", COLORS.get(who, Color.WHITE))
	_text.text = text
	_text.visible_characters = 0
	_text.add_theme_font_size_override("font_size", 22 if tone == "quiet" or tone == "aside" else 26)
	_panel.visible = true
	_skip = false
	line_started.emit(step)
	var per_char := 0.045 if who == "socko" else (0.07 if who == "marta" else 0.05)
	if tone == "quiet" or tone == "aside": per_char *= 1.2
	var t := 0.0; var shown := 0; var next_syl := 0.0
	var n := text.length()
	while shown < n and g == _gen and not _skip:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		var want := mini(n, int(t / per_char))
		while shown < want:
			var ch := text[shown]
			shown += 1
			if t >= next_syl and ch not in " .,!?…-'\"":
				Sfx.syllable(who); syllable.emit(who)
				next_syl = t + (0.075 if who == "socko" else (0.2 if who == "marta" else 0.1))
			if ch in ".!?…" and shown < n and text[shown] == " ":
				t += 0.18   # a beat at the end of a sentence
		_text.visible_characters = shown
	_text.visible_characters = -1
	speaking = ""
	var hold: float = 0.9 + n * 0.022 + float(step.get("hold", 0.0))
	if not _skip:
		await _wait(hold, g)
	_skip = false
	line_finished.emit(step)

func _wait(secs: float, g: int) -> void:
	var t := 0.0
	while t < secs and g == _gen and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time()

func _build_ui() -> void:
	_layer = CanvasLayer.new(); _layer.layer = 40
	add_child(_layer)
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0, 0, 0, 0.55); sb.set_content_margin_all(12)
	sb.corner_radius_top_left = 4; sb.corner_radius_top_right = 4; sb.corner_radius_bottom_left = 4; sb.corner_radius_bottom_right = 4
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.anchor_left = 0.18; _panel.anchor_right = 0.82; _panel.anchor_top = 1.0; _panel.anchor_bottom = 1.0
	_panel.offset_top = -150; _panel.offset_bottom = -40
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	_layer.add_child(_panel)
	var v := VBoxContainer.new(); v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	_name = Label.new(); _name.add_theme_font_size_override("font_size", 18)
	_text = Label.new(); _text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_color_override("font_color", Color("ece6d6"))
	v.add_child(_name); v.add_child(_text)
	_choice_box = VBoxContainer.new()
	_choice_box.anchor_left = 0.18; _choice_box.anchor_right = 0.82; _choice_box.anchor_top = 1.0; _choice_box.anchor_bottom = 1.0
	_choice_box.offset_top = -260; _choice_box.offset_bottom = -40
	_choice_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_choice_box.alignment = BoxContainer.ALIGNMENT_END
	_choice_box.add_theme_constant_override("separation", 6)
	_choice_box.visible = false
	_layer.add_child(_choice_box)
