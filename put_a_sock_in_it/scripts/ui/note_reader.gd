class_name NoteReader
extends CanvasLayer
## A piece of paper held up to read: the text on a lined sheet, a little crooked, in pencil.
## The level's controls are off while it's up; interact, Esc, a click or a tap puts it down.
##   NoteReader.open(level, text) -> await reader.closed

signal closed

var _level: Node
var _armed := false

static func open(level: Node, text: String, opts := {}) -> NoteReader:
	var r := NoteReader.new()
	r._level = level
	r.layer = 45
	level.add_child(r)
	r._build(text, opts)
	if level.has_method("set_cutscene"): level.set_cutscene(true)
	Sfx.play("paper", -6.0)
	r.get_tree().create_timer(0.35).timeout.connect(func(): r._armed = true)
	return r

func _build(text: String, opts: Dictionary) -> void:
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var paper := Panel.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = opts.get("paper", Color("efe8d2"))
	sb.shadow_color = Color(0, 0, 0, 0.5); sb.shadow_size = 12; sb.shadow_offset = Vector2(6, 8)
	paper.add_theme_stylebox_override("panel", sb)
	var size := Vector2(440, 560)
	paper.custom_minimum_size = size
	paper.pivot_offset = size * 0.5; paper.rotation = deg_to_rad(opts.get("tilt", -2.5))
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := CenterContainer.new(); holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder); holder.add_child(paper)
	# school paper: blue lines, a red margin
	for i in 16:
		var line := ColorRect.new(); line.color = Color(0.45, 0.6, 0.85, 0.35)
		line.position = Vector2(0, 70 + i * 30); line.size = Vector2(size.x, 1.5); paper.add_child(line)
	var margin := ColorRect.new(); margin.color = Color(0.85, 0.3, 0.3, 0.45)
	margin.position = Vector2(58, 0); margin.size = Vector2(1.5, size.y); paper.add_child(margin)
	var lb := Label.new(); lb.text = text
	lb.position = Vector2(72, 46); lb.size = Vector2(size.x - 100, size.y - 70)
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.add_theme_font_size_override("font_size", opts.get("font_size", 26))
	lb.add_theme_color_override("font_color", opts.get("ink", Color("4a4650")))
	lb.add_theme_constant_override("line_spacing", 4)
	paper.add_child(lb)
	var hint := Label.new(); hint.text = "[E] Put it down"
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6)); hint.add_theme_font_size_override("font_size", 16)
	add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM); hint.offset_top = -44; hint.offset_bottom = -20
	hint.offset_left = -80; hint.offset_right = 80; hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _input(e: InputEvent) -> void:
	if not _armed: return
	var down := e.is_action_pressed("interact") or e.is_action_pressed("ui_cancel") or e.is_action_pressed("ui_accept")
	down = down or (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)
	if down:
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	if not _armed: return
	_armed = false
	Sfx.play("paper", -8.0, 0.85)
	if is_instance_valid(_level) and _level.has_method("set_cutscene"): _level.set_cutscene(false)
	closed.emit()
	queue_free()
