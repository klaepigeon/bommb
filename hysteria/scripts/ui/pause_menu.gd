class_name PauseMenu
extends CanvasLayer
## Pause: Esc, Start on a pad, Android's back button, or the ‖ button in the top right on a
## touchscreen. Stops the game (and Socko's voice), frees the mouse, and offers: resume, look
## sensitivity, volume, invert look, restart the chapter, quit. Settings are kept in
## user://settings.cfg. Big targets for thumbs; a pad moves through it with the D-pad / stick.

const SETTINGS := "user://settings.cfg"

var player: Node
var panel: PanelContainer
var pause_btn: Button
var sens: HSlider
var vol: HSlider
var invert: CheckButton
var resume_btn: Button
var skill_menu: Node
var save_game: Node
var save_note: Label
var open := false
var _was_captured := false

func setup(p_player: Node) -> void:
	player = p_player

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_load()
	panel.visible = false
	pause_btn.visible = DisplayServer.is_touchscreen_available()

func _style(bg: Color, border: Color, radius := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new(); sb.bg_color = bg; sb.border_color = border
	sb.set_border_width_all(2); sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18; sb.content_margin_right = 18; sb.content_margin_top = 10; sb.content_margin_bottom = 10
	return sb

func _button(text: String) -> Button:
	var b := Button.new(); b.text = text
	b.custom_minimum_size = Vector2(380, 64)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_stylebox_override("normal", _style(Color(0.08, 0.08, 0.08, 0.9), Color(0.85, 0.82, 0.74, 0.35)))
	b.add_theme_stylebox_override("hover", _style(Color(0.16, 0.15, 0.13, 0.95), Color(0.85, 0.82, 0.74, 0.6)))
	b.add_theme_stylebox_override("focus", _style(Color(0.16, 0.15, 0.13, 0.95), Color(0.95, 0.85, 0.55, 0.9)))
	b.add_theme_stylebox_override("pressed", _style(Color(0.3, 0.28, 0.24, 0.95), Color(0.95, 0.85, 0.55, 0.9)))
	b.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	return b

func _row(label: String, control: Control) -> HBoxContainer:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 16)
	var l := Label.new(); l.text = label; l.custom_minimum_size = Vector2(170, 0)
	l.add_theme_font_size_override("font_size", 20); l.add_theme_color_override("font_color", Color(0.8, 0.78, 0.72))
	h.add_child(l); h.add_child(control)
	return h

func _slider(lo: float, hi: float, step: float) -> HSlider:
	var s := HSlider.new(); s.min_value = lo; s.max_value = hi; s.step = step
	s.custom_minimum_size = Vector2(240, 56)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.add_theme_stylebox_override("grabber_area", _style(Color(0.6, 0.55, 0.42, 0.8), Color(0, 0, 0, 0), 4))
	s.add_theme_stylebox_override("slider", _style(Color(0.2, 0.2, 0.2, 0.9), Color(0, 0, 0, 0), 4))
	s.value_changed.connect(func(_v): _apply(); _save())
	return s

func _build() -> void:
	# the ‖ button for touch, top right, clear of the objective (top left) and the buttons (bottom right)
	pause_btn = Button.new(); pause_btn.text = "II"; pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.add_theme_font_size_override("font_size", 26)
	var sb := _style(Color(0.05, 0.05, 0.05, 0.35), Color(0.9, 0.88, 0.8, 0.35), 40)
	for st in ["normal", "hover", "focus", "pressed"]: pause_btn.add_theme_stylebox_override(st, sb)
	pause_btn.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8, 0.8))
	pause_btn.anchor_left = 1; pause_btn.anchor_right = 1
	pause_btn.offset_left = -110; pause_btn.offset_right = -30; pause_btn.offset_top = 24; pause_btn.offset_bottom = 104
	pause_btn.pressed.connect(toggle)
	add_child(pause_btn)

	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.55); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(dim)
	var center := CenterContainer.new(); center.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var title := Label.new(); title.text = "P A U S E D"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22); title.add_theme_color_override("font_color", Color(0.72, 0.6, 0.38))
	box.add_child(title)
	resume_btn = _button("Resume"); resume_btn.pressed.connect(toggle); box.add_child(resume_btn)
	var save_btn := _button("Save game"); save_btn.pressed.connect(_save_game); box.add_child(save_btn)
	save_note = Label.new(); save_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_note.add_theme_font_size_override("font_size", 18); save_note.add_theme_color_override("font_color", Color(0.72, 0.6, 0.38))
	box.add_child(save_note)
	sens = _slider(0.3, 3.0, 0.05); box.add_child(_row("Look speed", sens))
	vol = _slider(0.0, 1.0, 0.05); box.add_child(_row("Volume", vol))
	invert = CheckButton.new(); invert.add_theme_font_size_override("font_size", 20)
	invert.custom_minimum_size = Vector2(120, 56)
	invert.scale = Vector2(2.0, 2.0); invert.pivot_offset = Vector2(0, 28)   # thumb-sized
	invert.toggled.connect(func(_v): _apply(); _save())
	box.add_child(_row("Invert look", invert))
	var skills := _button("Skills"); skills.pressed.connect(func():
		toggle()
		if skill_menu: skill_menu.call("toggle"))
	box.add_child(skills)
	var restart := _button("Restart chapter"); restart.pressed.connect(_restart); box.add_child(restart)
	var quit := _button("Quit"); quit.pressed.connect(func(): get_tree().quit()); box.add_child(quit)
	add_child(panel)

func toggle() -> void:
	open = not open
	panel.visible = open
	get_tree().paused = open
	if open:
		_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if save_game: save_game.call("save")
		save_note.text = ""
		if Game._voice() != "": DisplayServer.tts_pause()
		resume_btn.grab_focus()
	else:
		if _was_captured: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if Game._voice() != "": DisplayServer.tts_resume()

func _input(e: InputEvent) -> void:
	if e.is_action_pressed("pause") or (open and e.is_action_pressed("ui_cancel")):
		toggle(); get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	# Android's back button pauses (it used to quit the game outright)
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		toggle()
	elif what == NOTIFICATION_APPLICATION_PAUSED and not open:
		toggle()    # switched away from the app: come back paused

func _save_game() -> void:
	if not save_game: return
	if save_game.call("save"):
		save_note.text = "Saved."
	else:
		save_note.text = save_game.call("why_not")

func _restart() -> void:
	get_tree().paused = false
	if Game._voice() != "": DisplayServer.tts_stop()
	Game.flags.clear()
	SaveGame.wipe()            # restarting is starting over: the saved game goes too
	get_tree().reload_current_scene()

# ---------------------------------------------------------------- settings
func _apply() -> void:
	if player:
		player.set("look_sens", 0.0022 * sens.value)
		player.set("pad_sens", 2.6 * sens.value)
		player.set("invert_y", invert.button_pressed)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(vol.value, 0.0001)))

func _save() -> void:
	var c := ConfigFile.new()
	c.set_value("controls", "look", sens.value); c.set_value("controls", "invert", invert.button_pressed)
	c.set_value("audio", "volume", vol.value)
	c.save(SETTINGS)

func _load() -> void:
	var c := ConfigFile.new()
	c.load(SETTINGS)
	sens.set_value_no_signal(float(c.get_value("controls", "look", 1.0)))
	invert.set_pressed_no_signal(bool(c.get_value("controls", "invert", false)))
	vol.set_value_no_signal(float(c.get_value("audio", "volume", 0.9)))
	_apply()
