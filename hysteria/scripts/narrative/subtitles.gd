class_name Subtitles
extends CanvasLayer
## Spoken lines, at the bottom of the screen inside the device's safe area: the speaker's name
## small and coloured, the line under it, wrapped to a readable width, on a soft dark band so it
## reads over white Flat 48 and black streets alike. One line at a time; the next replaces it.

var box: PanelContainer
var who: Label
var text: Label
var _t := 0.0

func _ready() -> void:
	layer = 8
	add_to_group("subtitles")
	box = PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0, 0, 0, 0.55); sb.set_corner_radius_all(6)
	sb.content_margin_left = 16; sb.content_margin_right = 16; sb.content_margin_top = 8; sb.content_margin_bottom = 10
	box.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 2); box.add_child(v)
	who = Label.new(); who.add_theme_font_size_override("font_size", 14); v.add_child(who)
	text = Label.new(); text.add_theme_font_size_override("font_size", 21)
	text.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(text)
	add_child(box)
	box.visible = false
	get_viewport().size_changed.connect(_place)

func show_line(speaker: String, line: String, seconds: float, color := Color(0.85, 0.82, 0.75)) -> void:
	who.text = speaker; who.add_theme_color_override("font_color", color); who.visible = speaker != ""
	text.text = line
	_t = seconds
	box.visible = true; box.modulate.a = 1.0
	_place()

func clear() -> void:
	_t = 0.0; box.visible = false

## Within the safe area (notches, rounded corners, the gesture bar), at most ~38 em wide.
func _place() -> void:
	var vp := get_viewport().get_visible_rect().size
	var safe := Rect2(Vector2.ZERO, vp)
	var ds := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if ds.size.x > 0 and win.x > 0:
		var k := vp / Vector2(win)
		safe = Rect2(Vector2(ds.position) * k, Vector2(ds.size) * k).intersection(Rect2(Vector2.ZERO, vp))
	var w := minf(safe.size.x - 48.0, 760.0)
	text.custom_minimum_size.x = w - 32.0
	box.size = Vector2(w, 0)
	box.reset_size()
	box.position = Vector2(safe.position.x + (safe.size.x - box.size.x) * 0.5, safe.end.y - box.size.y - 120.0)

func _process(delta: float) -> void:
	if _t <= 0.0: return
	_t -= delta
	if _t < 0.4: box.modulate.a = clampf(_t / 0.4, 0.0, 1.0)
	if _t <= 0.0: box.visible = false
