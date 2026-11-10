extends CanvasLayer
## Crosshair dot, the interact prompt, and toasts (one-line messages at the bottom).

var prompt_label: Label
var toast_label: Label
var toast_t := 0.0
var black: ColorRect
var ticks: Control
var _tick_t := 0.0
var _tick_col := Color.WHITE

func _ready() -> void:
	black = ColorRect.new(); black.color = Color(0, 0, 0, 0); black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	Game.fade.connect(func(to, sec):
		var tw := create_tween(); tw.tween_property(black, "color:a", to, sec))
	var font_size := 18
	var dot := ColorRect.new(); dot.color = Color(0.85, 0.85, 0.8, 0.6); dot.size = Vector2(3, 3)
	dot.set_anchors_preset(Control.PRESET_CENTER); dot.position -= Vector2(1.5, 1.5); add_child(dot)
	# four short strokes round the crosshair when a round lands on something that takes it
	add_to_group("hud")
	ticks = Control.new(); ticks.set_anchors_preset(Control.PRESET_FULL_RECT); ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticks.draw.connect(_draw_ticks); add_child(ticks)
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

func hit_tick(head: bool, kill: bool) -> void:
	_tick_t = 0.22 if not kill else 0.4
	_tick_col = Color(0.95, 0.35, 0.3) if kill else (Color(1.0, 0.92, 0.75) if head else Color(0.9, 0.88, 0.82))
	ticks.queue_redraw()

func _draw_ticks() -> void:
	if _tick_t <= 0.0: return
	var c := ticks.size * 0.5
	var a := clampf(_tick_t / 0.12, 0.0, 1.0)
	var r0 := 7.0 + (0.22 - minf(_tick_t, 0.22)) * 30.0; var r1 := r0 + 7.0
	for i in 4:
		var d := Vector2.from_angle(PI * 0.25 + PI * 0.5 * i)
		ticks.draw_line(c + d * r0, c + d * r1, Color(_tick_col.r, _tick_col.g, _tick_col.b, a), 2.0)

func _process(delta: float) -> void:
	if _tick_t > 0.0:
		_tick_t -= delta / maxf(Engine.time_scale, 0.01)
		ticks.queue_redraw()
	if toast_t > 0.0:
		toast_t -= delta
		if toast_t < 1.0:
			toast_label.modulate.a = maxf(toast_t, 0.0)
