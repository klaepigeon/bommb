extends CanvasLayer
## At launch, when there's a saved game: Continue, or start again. The game waits behind it.

signal chosen(cont: bool)

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new(); bg.color = Color(0, 0, 0, 0.92); bg.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var c := CenterContainer.new(); c.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(c)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 18); c.add_child(v)
	var t := Label.new(); t.text = "H Y S T E R I A"; t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 34); t.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75)); v.add_child(t)
	var sub := Label.new(); sub.text = "Flat 47"; sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18); sub.add_theme_color_override("font_color", Color(0.72, 0.6, 0.38)); v.add_child(sub)
	var cont := _button("Continue"); cont.pressed.connect(_pick.bind(true)); v.add_child(cont)
	var fresh := _button("New game"); fresh.pressed.connect(_pick.bind(false)); v.add_child(fresh)
	cont.grab_focus.call_deferred()

func _button(text: String) -> Button:
	var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(380, 64)
	b.add_theme_font_size_override("font_size", 24)
	for st in ["normal", "hover", "focus", "pressed"]:
		var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.08, 0.08, 0.08, 0.9) if st == "normal" else Color(0.18, 0.16, 0.13, 0.95)
		sb.border_color = Color(0.95, 0.85, 0.55, 0.9) if st == "focus" else Color(0.85, 0.82, 0.74, 0.35)
		sb.set_border_width_all(2); sb.set_corner_radius_all(6)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	return b

func _pick(cont: bool) -> void:
	get_tree().paused = false
	if not DisplayServer.is_touchscreen_available(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	chosen.emit(cont)
	queue_free()
