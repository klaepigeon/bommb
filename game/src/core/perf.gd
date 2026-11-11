extends Node
## Performance: applies the graphics preset, watches frame time and steps quality down when the
## phone can't hold its target (sustained long frames = thermal throttling or a weak GPU), and back
## up after a long stretch of headroom. Draws an optional overlay (frame time graph, draw calls,
## objects, memory) for on-device testing.

signal quality_changed(q: Dictionary)

const ORDER := ["low", "medium", "high"]

var current := {}             ## the preset in effect (may differ from the setting: the governor)
var current_name := "medium"
var _hist := PackedFloat32Array()
var _over_t := 0.0
var _under_t := 0.0
var _overlay: Label
var _layer: CanvasLayer
var stepped_down := 0         ## how many steps the governor has taken (for the dev doc / overlay)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hist.resize(120)
	apply_setting()
	Settings.changed.connect(func(k):
		if k in ["preset", "fps_target"]: apply_setting()
		if k == "show_perf": _toggle_overlay())
	_layer = CanvasLayer.new(); _layer.layer = 120; add_child(_layer)
	_overlay = Label.new(); _overlay.position = Vector2(8, 4)
	_overlay.add_theme_font_size_override("font_size", 14)
	_overlay.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_overlay.add_theme_color_override("font_outline_color", Color.BLACK)
	_overlay.add_theme_constant_override("outline_size", 4)
	_layer.add_child(_overlay)
	_toggle_overlay()

func _toggle_overlay() -> void:
	if _overlay:
		_overlay.visible = Settings.get_v("show_perf")

func apply_setting() -> void:
	stepped_down = 0
	_set_preset(Settings.preset_name())
	Engine.max_fps = int(Settings.get_v("fps_target"))

func _set_preset(n: String) -> void:
	current_name = n
	current = Settings.PRESETS[n].duplicate()
	quality_changed.emit(current)

func target_ms() -> float:
	return 1000.0 / float(Settings.get_v("fps_target"))

func _process(delta: float) -> void:
	var ms := delta * 1000.0
	_hist.remove_at(0); _hist.append(ms)
	if Settings.get_v("governor") and not get_tree().paused:
		var budget := target_ms() * 1.18
		if ms > budget: _over_t += delta
		else: _over_t = maxf(0.0, _over_t - delta * 0.5)
		if ms < target_ms() * 0.7: _under_t += delta
		else: _under_t = 0.0
		if _over_t > 4.0:
			_over_t = 0.0
			_step(-1)
		elif _under_t > 45.0 and stepped_down > 0:
			_under_t = 0.0
			_step(1)
	if _overlay and _overlay.visible:
		var p95 := _p95()
		_overlay.text = "%s%s  %.1f ms (p95 %.1f)  fps %d\ndraw %d  obj %d  prim %dk\nmem %.0f MB  vram %.0f MB" % [
			current_name, (" (-%d)" % stepped_down) if stepped_down > 0 else "", ms, p95, Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000),
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0]

func _p95() -> float:
	var s := _hist.duplicate(); s.sort()
	return s[int(s.size() * 0.95)]

## one step of quality: render resolution first (cheapest to lose), then lights and shadows
func _step(dir: int) -> void:
	var i := ORDER.find(current_name)
	if dir < 0:
		if current.render_div < 5:
			current.render_div += 1
		elif i > 0:
			_set_preset(ORDER[i - 1]); current.render_div = Settings.PRESETS[ORDER[i - 1]].render_div
		else:
			return
		stepped_down += 1
	else:
		var base: Dictionary = Settings.PRESETS[Settings.preset_name()]
		if current.render_div > base.render_div:
			current.render_div -= 1
		elif current_name != Settings.preset_name():
			_set_preset(ORDER[mini(i + 1, ORDER.size() - 1)])
		stepped_down = maxi(0, stepped_down - 1)
	quality_changed.emit(current)
