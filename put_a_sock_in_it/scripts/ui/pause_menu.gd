class_name PauseMenu
extends CanvasLayer
## Pause: resume, settings (look speed, volume, invert, the touch controls' size, opacity and
## layout), restart from the last checkpoint, back to the title. Big touch-friendly rows.

var touch: TouchControls
var _root: Control
var _box: VBoxContainer

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = ColorRect.new(); (_root as ColorRect).color = Color(0, 0, 0, 0.72)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var sc := ScrollContainer.new(); sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.offset_left = 80; sc.offset_right = -80; sc.offset_top = 40; sc.offset_bottom = -40
	_root.add_child(sc)
	_box = VBoxContainer.new(); _box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 12)
	sc.add_child(_box)
	_title("PAUSED")
	_button("Resume", close)
	_slider("Look sensitivity", 0.2, 3.0, "sensitivity")
	_slider("Volume", 0.0, 1.0, "volume")
	_check("Invert look", "invert_y")
	_check("Touch controls", "force_touch")
	_slider("Button size", 0.6, 1.8, "touch_scale")
	_slider("Button opacity", 0.15, 1.0, "touch_opacity")
	_button("Move buttons", func(): close(); if touch: touch.editing = true)
	_button("Reset buttons", func(): if touch: touch.reset_layout())
	_button("Restart from checkpoint", func(): close(); Game.restart_level())
	_button("Quit to title", func(): close(); Game.to_title())
	var help := Label.new()
	help.text = "Keyboard: WASD move · mouse look · E use · Shift run · C crouch · LMB fire / throw · RMB or Q turn over · R reload · Space hurry dialogue · Esc pause\nGamepad: sticks · A use · B crouch · X reload · Y hurry · RT fire / throw · LT turn over · L3 run · Start pause"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 16); help.add_theme_color_override("font_color", Color("9a917e"))
	_box.add_child(help)
	visible = false

func _title(t: String) -> void:
	var l := Label.new(); l.text = t; l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", Color("d8cdb4")); _box.add_child(l)

func _button(t: String, cb: Callable) -> void:
	var b := Button.new(); b.text = t; b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb); _box.add_child(b)

func _slider(t: String, lo: float, hi: float, key: String) -> void:
	var h := HBoxContainer.new()
	var l := Label.new(); l.text = t; l.custom_minimum_size = Vector2(260, 0); l.add_theme_font_size_override("font_size", 22)
	var s := HSlider.new(); s.min_value = lo; s.max_value = hi; s.step = 0.01; s.value = float(Game.settings[key])
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL; s.custom_minimum_size = Vector2(0, 48)
	s.value_changed.connect(func(v): Game.settings[key] = v; Game.save_settings())
	h.add_child(l); h.add_child(s); _box.add_child(h)

func _check(t: String, key: String) -> void:
	var c := CheckButton.new(); c.text = t; c.button_pressed = bool(Game.settings[key])
	c.add_theme_font_size_override("font_size", 22); c.custom_minimum_size = Vector2(0, 52)
	c.toggled.connect(func(v): Game.settings[key] = v; Game.save_settings())
	_box.add_child(c)

func open() -> void:
	if Game.busy: return
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	visible = false
	get_tree().paused = false

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
		if touch and touch.editing: touch.editing = false; touch._save_layout(); return
		if visible: close()
		else: open()
		get_viewport().set_input_as_handled()
