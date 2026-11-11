extends Node
## Lines: subtitles, the voice (the phone's text-to-speech, or synthesised babble where the line is
## "gibberish": Socko's chatter and Marta's snarls), and each speaker's mouth. One line at a time;
## `await Speech.say_id("door_1")` returns when it's done. Barks wait their turn or are dropped.

signal line_started(speaker: String, text: String)
signal line_finished(speaker: String)
signal line_cue(id: String, line: Dictionary)

var characters := {}
var lines := {}
var speaking := ""
var history: Array[String] = []
var fast := false                    ## tests: lines take a tenth of the time
var _layer: CanvasLayer
var _panel: PanelContainer
var _label: RichTextLabel
var _elapsed := 0.0
var _duration := 1.0
var _sched: PackedFloat32Array       ## syllable times (s) for the mouth
var _gib_next := 0.0
var _gib_kind := ""
var _gen := 0
var _tts_ok := -1
var _tts_done := true
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	characters = _json("res://content/characters.json")
	var d := _json("res://content/dialogue.json")
	for k in d:
		if k.begins_with("_"): continue
		for id in d[k]:
			lines[id] = d[k][id]
	_build_ui()
	Settings.changed.connect(_apply_size)
	fast = OS.get_cmdline_user_args().has("--fast")

static func _json(p: String) -> Dictionary:
	if not FileAccess.file_exists(p): return {}
	var v = JSON.parse_string(FileAccess.get_file_as_string(p))
	return v if v is Dictionary else {}

func _build_ui() -> void:
	_layer = CanvasLayer.new(); _layer.layer = 50
	add_child(_layer)
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	var box := VBoxContainer.new(); box.alignment = BoxContainer.ALIGNMENT_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	var center := CenterContainer.new(); center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(center)
	_panel = PanelContainer.new(); _panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0, 0, 0, 0.55)
	sb.content_margin_left = 14; sb.content_margin_right = 14; sb.content_margin_top = 6; sb.content_margin_bottom = 6
	sb.corner_radius_top_left = 3; sb.corner_radius_top_right = 3; sb.corner_radius_bottom_left = 3; sb.corner_radius_bottom_right = 3
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)
	_label = RichTextLabel.new(); _label.bbcode_enabled = true; _label.fit_content = true
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _label.scroll_active = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)
	_panel.visible = false
	root.set_meta("box", box)
	_root = root
	get_viewport().size_changed.connect(_apply_size)
	_apply_size()

var _root: MarginContainer

## Margins from the display's safe area (notches, rounded corners), and a width the text wraps at.
func _apply_size() -> void:
	var vp := get_viewport().get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var k := vp.x / maxf(win.x, 1.0)
	var left := maxf(safe.position.x * k, 0.0) if safe.size.x > 0 else 0.0
	var right := maxf((win.x - safe.end.x) * k, 0.0) if safe.size.x > 0 else 0.0
	_root.add_theme_constant_override("margin_left", int(left + vp.x * 0.06))
	_root.add_theme_constant_override("margin_right", int(right + vp.x * 0.06))
	_root.add_theme_constant_override("margin_bottom", int(vp.y * 0.07))
	var size := int(clampf(vp.y * 0.036, 18, 64) * float(Settings.get_v("subtitle_size")))
	_label.add_theme_font_size_override("normal_font_size", size)
	_label.custom_minimum_size.x = minf(vp.x * 0.72, size * 34.0)

func _tts_available() -> bool:
	if not bool(Settings.get_v("voices")) or bool(Settings.get_v("safe_mode")): return false   # don't even wake the TTS engine
	if _tts_ok < 0:
		_tts_ok = 0
		Log.mark("tts init")
		if OS.has_feature("mobile") or OS.get_name() in ["Windows", "macOS"]:
			var v := DisplayServer.tts_get_voices()
			_tts_ok = 1 if v.size() > 0 else 0
			if _tts_ok == 1:
				DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED, func(_id): _tts_done = true)
				DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_CANCELED, func(_id): _tts_done = true)
	return _tts_ok == 1 and bool(Settings.get_v("voices")) and not bool(Settings.get_v("safe_mode"))

func has_line(id: String) -> bool:
	return lines.has(id)

func say_id(id: String) -> void:
	var l: Dictionary = lines.get(id, {})
	if l.is_empty():
		push_warning("Speech: no line " + id)
		return
	line_cue.emit(id, l)
	history.append(id)
	await say(String(l.get("speaker", "kurt")), String(l.get("text", "")), l)

## Says a line and returns when it's over. opts: style (quiet), gibberish (true), silent (no voice).
func say(speaker: String, text: String, opts := {}) -> void:
	_gen += 1
	var gen := _gen
	var ch: Dictionary = characters.get(speaker, {"name": speaker.to_upper(), "color": "#dddddd"})
	speaking = speaker
	history.append(speaker + ": " + text)
	Log.mark("say %s: %s" % [speaker, text.left(60)])
	var style := String(opts.get("style", ""))
	var gib := bool(opts.get("gibberish", false))
	var col := Color(String(ch.get("color", "#ddd")))
	var body := text if not gib else "[i]" + text + "[/i]"
	if style == "quiet": body = "[color=#b0b0b0]" + body + "[/color]"
	_label.text = "[color=#%s]%s[/color]  %s" % [col.to_html(false), String(ch.get("name", "?")), body]
	_panel.visible = bool(Settings.get_v("subtitles")) or gib
	var words := text.split(" ", false).size()
	_duration = clampf(0.55 + words * 0.36 + text.count(".") * 0.15, 1.0, 12.0)
	if bool(opts.get("silent", false)): _duration = 1.0
	if fast: _duration *= 0.1
	_sched = _syllables(text, _duration)
	_elapsed = 0.0
	_tts_done = true
	_gib_kind = ""
	if gib:
		_gib_kind = "snarl" if speaker == "marta" else "blip"
		_gib_next = 0.0
	elif not bool(opts.get("silent", false)) and _tts_available() and not fast:
		var voices := DisplayServer.tts_get_voices_for_language("en")
		var v := voices[0] if voices.size() > 0 else ""
		_tts_done = false
		Log.mark("tts")
		DisplayServer.tts_speak(text.replace("...", ", "), v, int(ch.get("volume", 90)) * (60 if style == "quiet" else 100) / 100, float(ch.get("pitch", 1.0)), float(ch.get("rate", 1.0)), gen, true)
	line_started.emit(speaker, text)
	while gen == _gen and (_elapsed < _duration or not _tts_done):
		await get_tree().process_frame
		if _elapsed > _duration + 8.0: break
	if gen == _gen:
		_panel.visible = false
		speaking = ""
		_gib_kind = ""
		line_finished.emit(speaker)
		await get_tree().create_timer(0.25 if not fast else 0.02, false).timeout

## Cuts whatever's being said (a scream, a door slam).
func stop() -> void:
	_gen += 1
	if _tts_ok == 1: DisplayServer.tts_stop()
	if speaking != "":
		var s := speaking
		speaking = ""
		_panel.visible = false
		line_finished.emit(s)

func _syllables(text: String, dur: float) -> PackedFloat32Array:
	var t := PackedFloat32Array()
	var vowels := 0
	for c in text.to_lower():
		if c in "aeiouy": vowels += 1
	vowels = maxi(vowels, 1)
	for i in vowels:
		t.append(dur * (float(i) + 0.3) / vowels)
	return t

## How open a speaker's mouth is right now (0..1).
func mouth(speaker: String) -> float:
	if speaker != speaking or _sched.is_empty():
		return 0.0
	var best := 1.0
	for s in _sched:
		best = minf(best, absf(_elapsed - s))
	return clampf(1.0 - best / 0.09, 0.0, 1.0) * (0.6 + 0.4 * sin(_elapsed * 9.0) * sin(_elapsed * 9.0))

func _process(delta: float) -> void:
	if speaking == "":
		return
	_elapsed += delta
	if _gib_kind != "" and _elapsed >= _gib_next and _elapsed < _duration - 0.1:
		if _gib_kind == "blip":
			Audio.play("blip", null, -4.0, _rng.randf_range(1.1, 2.1))
			_gib_next = _elapsed + _rng.randf_range(0.07, 0.13)
		else:
			Audio.play("snarl", null, -2.0, _rng.randf_range(0.7, 1.15))
			_gib_next = _elapsed + _rng.randf_range(0.5, 0.9)
