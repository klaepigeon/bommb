extends Control
## The title: the name, and the choices. Behind it, the knocking at a door.

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new(); bg.color = Color("0c0a09"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var v := VBoxContainer.new(); v.set_anchors_preset(Control.PRESET_CENTER)
	v.custom_minimum_size = Vector2(520, 0); v.position -= Vector2(260, 220)
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	var t := Label.new(); t.text = "PUT A SOCK IN IT"; t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 58); t.add_theme_color_override("font_color", Color("e2d6b8"))
	v.add_child(t)
	var sub := Label.new(); sub.text = "Kerzhansk, 1996"; sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20); sub.add_theme_color_override("font_color", Color("7f7564"))
	v.add_child(sub)
	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 30); v.add_child(gap)
	if Game.has_save(): _btn(v, "Continue", Game.continue_game)
	_btn(v, "New game", func(): Game.reset_save(); Game.new_game())
	_btn(v, "Quit", func(): get_tree().quit())
	var knock_t := Timer.new(); knock_t.wait_time = 7.0; knock_t.autostart = true; add_child(knock_t)
	knock_t.timeout.connect(func():
		for i in 3:
			Sfx.play("knock", -18.0, randf_range(0.95, 1.05)); await get_tree().create_timer(0.32).timeout)

func _btn(v: VBoxContainer, t: String, cb: Callable) -> void:
	var b := Button.new(); b.text = t; b.custom_minimum_size = Vector2(0, 66)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(cb); v.add_child(b)
