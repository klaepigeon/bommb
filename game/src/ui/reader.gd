extends Control
## Reading a document: the paper, big, and tap anywhere to put it down. Reading is recorded (a
## clue found), and a document that holds a memory gives Kurt that memory.

var hud: Node
var _paper: PanelContainer
var _title: Label
var _text: Label
var _docs := {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UIKit.fullscreen_dim(0.78))
	_paper = PanelContainer.new()
	var st := UIKit.panel_style(Color(0.8, 0.77, 0.66, 0.98), 4, Color(0.3, 0.25, 0.2, 0.6))
	st.content_margin_left = 36; st.content_margin_right = 36; st.content_margin_top = 28; st.content_margin_bottom = 28
	_paper.add_theme_stylebox_override("panel", st)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	_title = UIKit.label("", 26, Color(0.15, 0.12, 0.1))
	_title.remove_theme_color_override("font_outline_color")
	_title.add_theme_constant_override("outline_size", 0)
	_text = UIKit.label("", 24, Color(0.12, 0.1, 0.08))
	_text.add_theme_constant_override("outline_size", 0)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hint := UIKit.label("(tap to put it down)", 18, Color(0.3, 0.27, 0.22))
	hint.add_theme_constant_override("outline_size", 0)
	vb.add_child(_title); vb.add_child(_text); vb.add_child(hint)
	_paper.add_child(vb)
	add_child(_paper)
	var f := FileAccess.open("res://content/documents.json", FileAccess.READ)
	if f:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			_docs = d.get("docs", {})

func show_doc(id: String) -> void:
	var d: Dictionary = _docs.get(id, {"title": id, "text": "..."})
	_title.text = String(d.get("title", ""))
	var text := String(d.get("text", ""))
	# the infection reads over your shoulder
	if Infection.stage >= 2 and d.has("text"):
		text = text.replace("boxes", "doors").replace("box", "door") if randf() < 0.5 else text
	_text.text = text
	var vp := get_viewport_rect().size
	var w := minf(vp.x * 0.86, 900.0 * UIKit.unit(self))
	_paper.custom_minimum_size = Vector2(w, 0)
	_text.custom_minimum_size = Vector2(w - 72, 0)
	visible = true
	fit()
	await get_tree().process_frame
	_paper.position = (vp - _paper.size) * 0.5
	Story.record("clue.read:" + id)
	if d.has("memory") and not Story.has("memory:" + String(d.memory)):
		Story.add_memory(String(d.memory))
		if String(d.memory) == "trickshot":
			Speech.queue(["k_trickshot"])
		elif String(d.memory) == "hand":
			Speech.queue(["k_photo"])

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		hud.close_all()
		accept_event()

## overlays start hidden, and a hidden Control doesn't follow its parent's size: fit on open
func fit() -> void:
	var par := get_parent() as Control
	position = Vector2.ZERO
	size = par.size if par else get_viewport_rect().size
