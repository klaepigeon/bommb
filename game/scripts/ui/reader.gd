class_name Reader
extends Control
## The reading view: a sheet of paper over a dimmed screen. With Her Handwriting, the margin note
## shows under the text. Tap / Use / Back closes it.

signal closed

var _title: Label
var _body: Label
var _more: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(func(e): if e is InputEventScreenTouch and e.pressed or e is InputEventMouseButton and e.pressed: close())
	add_child(bg)
	var paper := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("d8cfb4")
	sb.set_content_margin_all(34)
	paper.add_theme_stylebox_override("panel", sb)
	paper.anchor_left = 0.2; paper.anchor_right = 0.8; paper.anchor_top = 0.1; paper.anchor_bottom = 0.9
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paper)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	paper.add_child(box)
	_title = _label(box, 30, Color("2a2018"))
	_body = _label(box, 26, Color("2a2018"))
	_more = _label(box, 26, Color("5a1d14"))

func _label(p: Control, size: int, c: Color) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	p.add_child(l)
	return l

func open(doc: Dictionary) -> void:
	_title.text = doc.get("title", "")
	_body.text = doc.get("text", "")
	var more: String = doc.get("handwriting", "")
	_more.visible = more != "" and Game.owned("handwriting")
	_more.text = more
	visible = true

func close() -> void:
	if visible:
		visible = false
		closed.emit()

func _unhandled_input(e: InputEvent) -> void:
	if visible and (e.is_action_pressed("interact") or e.is_action_pressed("back") or e.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()
