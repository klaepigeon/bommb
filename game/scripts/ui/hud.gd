class_name Hud
extends CanvasLayer
## Crosshair, the use prompt (keyboard/pad), the controls, the black that scenes fade through,
## and the pause menu.

signal restart_requested

var controls: Controls
var fade: ColorRect
var white: ColorRect            ## the other fade: the town's gate, 48's door
var reader: Reader
var skills: SkillMenu
var _status: Label
var _caption: Label
var _caption_n := 0
var _dot: ColorRect
var _prompt: Label
var _menu: Control
var _voices_btn: Button
var _look_lbl: Label
var _sub_lbl: Label
var _first_btn: Button

func build() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	controls = Controls.new()
	controls.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(controls)
	_dot = ColorRect.new()
	_dot.color = Color(1, 1, 1, 0.5)
	_dot.size = Vector2(4, 4)
	_dot.set_anchors_preset(Control.PRESET_CENTER)
	_dot.position = -_dot.size * 0.5
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dot)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-200, 26)
	_prompt.size = Vector2(400, 40)
	_prompt.add_theme_font_size_override("font_size", 24)
	_prompt.add_theme_constant_override("outline_size", 5)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)
	_status = Label.new()
	_status.position = Vector2(30, 110)
	_status.add_theme_font_size_override("font_size", 24)
	_status.add_theme_constant_override("outline_size", 5)
	_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status)
	_caption = Label.new()
	_caption.anchor_left = 0.14; _caption.anchor_right = 0.86
	_caption.anchor_top = 0.62; _caption.anchor_bottom = 0.62
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_size_override("font_size", 24)
	_caption.add_theme_color_override("font_color", Color(0.86, 0.84, 0.78))
	_caption.add_theme_constant_override("outline_size", 6)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.modulate.a = 0.0
	add_child(_caption)
	reader = Reader.new()
	add_child(reader)
	skills = SkillMenu.new()
	add_child(skills)
	white = ColorRect.new()
	white.color = Color(1, 1, 1, 0)
	white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(white)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	_build_menu()

func set_prompt(p: String) -> void:
	controls.set_prompt(p)
	if p == "" or controls.show_touch:
		_prompt.text = ""
		_dot.color.a = 0.35
		return
	var key := "A" if Input.get_connected_joypads().size() > 0 else "E"
	_prompt.text = "[%s]  %s" % [key, p]
	_dot.color.a = 0.9

## Top left: nuggets once he has any; rounds once he has the gun.
func set_status(text: String) -> void:
	_status.text = text

## What Kurt sees when he looks at something: a quiet line above the subtitles, then gone.
func caption(text: String, seconds := 4.5) -> void:
	_caption_n += 1
	var n := _caption_n
	_caption.text = text
	last_caption = text
	create_tween().tween_property(_caption, "modulate:a", 1.0, 0.15)
	await get_tree().create_timer(seconds, false).timeout
	if n == _caption_n:
		create_tween().tween_property(_caption, "modulate:a", 0.0, 0.5)

var last_caption := ""

func set_crosshair(on: bool) -> void:
	_dot.visible = on
	_prompt.visible = on

func white_to(alpha: float, seconds: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(white, "color:a", alpha, seconds)
	return tw

func fade_to(alpha: float, seconds: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", alpha, seconds)
	return tw

# --- pause -------------------------------------------------------------------------------------

func _build_menu() -> void:
	_menu = Control.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.visible = false
	add_child(_menu)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.78)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(560, 0)
	box.position = Vector2(-280, -280)
	box.add_theme_constant_override("separation", 14)
	_menu.add_child(box)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	box.add_child(title)
	_first_btn = _button(box, "Resume", toggle_pause)
	_voices_btn = _button(box, "", func():
		Settings.voices = not Settings.voices
		if not Settings.voices:
			Speech.stop()
		Settings.save()
		_refresh())
	_look_lbl = _stepper(box, func(d):
		Settings.look_sensitivity = clampf(Settings.look_sensitivity + d * 0.1, 0.3, 2.5)
		Settings.save(); _refresh())
	_sub_lbl = _stepper(box, func(d):
		Settings.subtitle_scale = clampf(Settings.subtitle_scale + d * 0.1, 0.7, 1.6)
		Settings.save(); _refresh())
	_button(box, "Restart scene", func():
		toggle_pause()
		restart_requested.emit())
	if not OS.has_feature("mobile"):
		_button(box, "Quit", func(): get_tree().quit())
	_refresh()

func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 72)
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _stepper(parent: Control, cb: Callable) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var minus := _button(row, "−", func(): cb.call(-1))
	minus.custom_minimum_size = Vector2(90, 72)
	var l := Label.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 28)
	row.add_child(l)
	var plus := _button(row, "+", func(): cb.call(1))
	plus.custom_minimum_size = Vector2(90, 72)
	return l

func _refresh() -> void:
	_voices_btn.text = "Voices: " + ("On" if Settings.voices else "Off (subtitles only)")
	_look_lbl.text = "Look speed  %.1f" % Settings.look_sensitivity
	_sub_lbl.text = "Subtitle size  %.1f" % Settings.subtitle_scale

func is_paused() -> bool:
	return _menu.visible

func toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	_menu.visible = p
	Speech.pause_voice(p)
	controls.clear_touches()
	if p:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_first_btn.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if _menu.visible and event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()

## Out of the town. What's past the gate is still to be written.
func end_card(route: String) -> void:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var bg := ColorRect.new(); bg.color = Color.WHITE; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.position = Vector2(-300, -120)
	v.custom_minimum_size = Vector2(600, 0)
	v.add_theme_constant_override("separation", 24)
	c.add_child(v)
	var t := Label.new()
	t.text = "HYSTERIA"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 64)
	t.add_theme_color_override("font_color", Color("1a1410"))
	v.add_child(t)
	var b := Button.new()
	b.text = "Play again"
	b.custom_minimum_size = Vector2(0, 80)
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(func(): get_tree().reload_current_scene())
	v.add_child(b)
	b.grab_focus()
	controls.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
