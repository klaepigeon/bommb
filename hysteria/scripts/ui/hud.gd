extends CanvasLayer
## Crosshair dot, the interact prompt, and toasts (one-line messages at the bottom).

var prompt_label: Label
var toast_label: Label
var toast_t := 0.0
var black: ColorRect

func _ready() -> void:
	black = ColorRect.new(); black.color = Color(0, 0, 0, 0); black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	Game.fade.connect(func(to, sec):
		var tw := create_tween(); tw.tween_property(black, "color:a", to, sec))
	var font_size := 18
	var dot := ColorRect.new(); dot.color = Color(0.85, 0.85, 0.8, 0.6); dot.size = Vector2(3, 3)
	dot.set_anchors_preset(Control.PRESET_CENTER); dot.position -= Vector2(1.5, 1.5); add_child(dot)
	prompt_label = _label(font_size, Control.PRESET_CENTER, Vector2(0, 40)); add_child(prompt_label)
	toast_label = _label(font_size, Control.PRESET_CENTER_BOTTOM, Vector2(0, -70)); add_child(toast_label)
	Game.prompt.connect(func(t): prompt_label.text = t)
	Game.toast.connect(func(t, s): toast_label.text = t; toast_t = s; toast_label.modulate.a = 1.0)

func _label(sz: int, preset: int, off: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", Color(0.86, 0.84, 0.78))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2); l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(preset)
	l.size = Vector2(900, 30); l.position = l.position - Vector2(450, 15) + off
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	return l

func _process(delta: float) -> void:
	if toast_t > 0.0:
		toast_t -= delta
		if toast_t < 1.0:
			toast_label.modulate.a = maxf(toast_t, 0.0)
