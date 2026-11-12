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
## The subtitles are part of this node, so every scene gets them without wiring.

signal line_started(step: Dictionary)
signal line_finished(step: Dictionary)
signal event(name: String, step: Dictionary)
signal syllable(who: String)

const NAMES := {"kurt": "KURT", "socko": "SOCKO", "marta": "MARTA"}
const COLORS := {"kurt": Color("d6cbb3"), "socko": Color("f2c94c"), "marta": Color("9fc7b8")}

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
				for k in d: data[k] = d[k]
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
	for step in data[id]:
		if g != _gen: return false
		if step.has("if") and not test(step["if"]): continue
		var p: float = step.get("pause", 0.0)
		if p > 0.0:
			await _wait(p, g)
		if g != _gen: return false
		if step.has("event"):
			event.emit(step.event, step)
			if step.has("wait"): await _wait(float(step.wait), g)
			continue
		await _say(step, g)
	if g == _gen:
		busy = false
		_panel.visible = false
	return g == _gen

## Stop whatever is being said (a cutscene took over, the level changed).
func stop() -> void:
	_gen += 1
	busy = false; speaking = ""
	if _panel: _panel.visible = false

## Hurry the current line (the player tapped / pressed the skip key).
func skip_line() -> void:
	_skip = true

func test(cond: String) -> bool:
	var e := Expression.new()
	if e.parse(cond, ["memories", "flags"]) != OK:
		push_error("dialogue: bad condition " + cond); return false
	var r = e.execute([Game.memories, Game.flags])
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
				next_syl = t + (0.075 if who == "socko" else 0.1)
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
