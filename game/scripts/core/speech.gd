extends CanvasLayer
## Everything anyone says: subtitles (always), the device's text-to-speech (if on and available),
## and a mouth value per speaker that Socko's jaws and Marta's head read while a line plays.
## Lines are data: content/scene_a.json; speakers: content/characters.json.

signal line_started(speaker: String, text: String)
signal line_finished(speaker: String)
signal line_cue(id: String, line: Dictionary)     ## a line from content, with its cues (Socko's face...)

var characters := {}
var lines := {}
var speaking := ""                     ## the speaker of the line now playing, or ""
var history: Array[String] = []        ## every line id/text said, in order (tests read this)

var _panel: PanelContainer
var _label: RichTextLabel
var _text := ""
var _style := ""
var _elapsed := 0.0
var _duration := 1.0
var _tts_id := -1
var _tts_done := true
var _tts_voice := ""
var _mouth := {}

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	characters = _read_json("res://content/characters.json")
	lines = _read_json("res://content/scene_a.json").get("lines", {})
	lines.merge(_read_json("res://content/town.json").get("lines", {}))
	lines.merge(_read_json("res://content/flat48.json").get("lines", {}))
	_build_ui()
	if DisplayServer.get_name() != "headless" and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED, _on_tts_end)
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_CANCELED, _on_tts_end)

func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("missing " + path)
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}

var _tts_ok := -1
func _tts_available() -> bool:
	# Android's TTS engine binds asynchronously: until it lists voices, keep asking (each line).
	if _tts_ok == -1 or (_tts_ok == 0 and OS.has_feature("mobile")):
		_tts_ok = 0
		if DisplayServer.get_name() != "headless" and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
			if DisplayServer.tts_get_voices().size() > 0:
				_tts_ok = 1
	return _tts_ok == 1

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 18; sb.content_margin_right = 18
	sb.content_margin_top = 8; sb.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 0.12; _panel.anchor_right = 0.88
	_panel.anchor_top = 1.0; _panel.anchor_bottom = 1.0
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_bottom = -34
	_panel.visible = false
	root.add_child(_panel)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	var slant := FontVariation.new()
	slant.base_font = ThemeDB.fallback_font
	slant.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.22, 1), Vector2.ZERO)
	_label.add_theme_font_override("italics_font", slant)
	_panel.add_child(_label)
	_apply_size()
	Settings.changed.connect(_apply_size)

func _apply_size() -> void:
	var s := int(30 * Settings.subtitle_scale)
	for k in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		_label.add_theme_font_size_override(k, s)

## Says the line with this id from content/scene_a.json. Await it: returns when it's done.
func say_id(id: String) -> void:
	var l: Dictionary = lines.get(id, {})
	if l.is_empty():
		push_error("no line " + id)
		return
	history.append(id)
	line_cue.emit(id, l)
	await say(l.get("speaker", "kurt"), l.get("text", ""), l.get("style", ""), l.get("silent", false))

var _gen := 0

func say(speaker: String, text: String, style := "", silent := false) -> void:
	_gen += 1
	var gen := _gen
	var c: Dictionary = characters.get(speaker, {})
	_text = text
	_style = style
	_elapsed = 0.0
	var words := text.split(" ", false).size()
	_duration = 0.5 + words * 0.34 / float(c.get("rate", 1.0)) + text.count("...") * 0.45
	if style == "quiet":
		_duration *= 0.9
	speaking = speaker
	var col: String = c.get("color", "#ffffff")
	var name: String = c.get("name", speaker.to_upper())
	var body := text
	if style == "quiet":
		body = "[i][color=#bfb0a0]%s[/color][/i]" % text
		col = Color(col).darkened(0.25).to_html(false)
	_label.text = "[color=%s][b]%s[/b][/color]   %s" % [col, name, body]
	_panel.visible = true
	_tts_done = true
	if not silent and Settings.voices and _tts_available():
		_tts_done = false
		_tts_id += 1
		if _tts_voice == "":
			var voices := DisplayServer.tts_get_voices_for_language("en")
			if voices.size() > 0:
				_tts_voice = voices[0]
		var vol := int(c.get("volume", 100))
		if style == "quiet":
			vol = int(vol * 0.6)
		DisplayServer.tts_speak(text, _tts_voice, vol, float(c.get("pitch", 1.0)), float(c.get("rate", 1.0)), _tts_id, true)
	line_started.emit(speaker, text)
	# Wait for the line (counting only unpaused time), and for the voice if it's still going.
	while true:
		await get_tree().process_frame
		if gen != _gen:
			return          # a newer line took over
		if get_tree().paused:
			continue
		_elapsed += get_process_delta_time()
		if _elapsed >= _duration and (_tts_done or _elapsed > _duration * 2.0 + 1.5):
			break
	_mouth[speaker] = 0.0
	speaking = ""
	_panel.visible = false
	line_finished.emit(speaker)
	await get_tree().create_timer(0.25, false).timeout

func _on_tts_end(id: int) -> void:
	if id == _tts_id:
		_tts_done = true

func stop() -> void:
	if _tts_available():
		DisplayServer.tts_stop()
	_tts_done = true

func pause_voice(p: bool) -> void:
	if not _tts_available():
		return
	if p:
		DisplayServer.tts_pause()
	else:
		DisplayServer.tts_resume()

## 0..1: how open this speaker's mouth is right now (syllable shapes from the text).
func mouth(speaker: String) -> float:
	return _mouth.get(speaker, 0.0)

func _process(delta: float) -> void:
	for s in _mouth.keys():
		if s != speaking:
			_mouth[s] = move_toward(_mouth[s], 0.0, delta * 8.0)
	if speaking == "" or get_tree().paused:
		return
	var target := 0.0
	var body := _duration - 0.4
	if _elapsed < body and _text.length() > 0:
		var i := clampi(int(_elapsed / body * _text.length()), 0, _text.length() - 1)
		var ch := _text[i].to_lower()
		if "aeiouy".contains(ch):
			target = 0.85 + 0.15 * sin(_elapsed * 31.0)
		elif ch == " " or ".,!?-".contains(ch):
			target = 0.0
		else:
			target = 0.35
	if _style == "quiet":
		target *= 0.45
	var m: float = _mouth.get(speaking, 0.0)
	_mouth[speaking] = move_toward(m, target, delta * 14.0)
