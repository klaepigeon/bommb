class_name SockoHud
extends CanvasLayer
## Top left: what you're meant to be doing. Before Socko it's the job ("OBJECTIVE · Find Marta
## Sokolova."); once he's on your hand it's what he says ("SOCKO SAYS · Find a way out of Flat
## 47."), as in the JS build. Under it, briefly, a control hint the first time he teaches
## something. Minimal on purpose: he does the teaching out loud.

var header: Label
var text: Label
var hint: Label
var _hint_t := 0.0
var socko := false

func _ready() -> void:
	layer = 5
	var box := VBoxContainer.new(); box.position = Vector2(24, 18); box.add_theme_constant_override("separation", 2)
	add_child(box)
	header = _label(11, Color(0.72, 0.6, 0.38)); box.add_child(header)
	text = _label(15, Color(0.88, 0.86, 0.8)); box.add_child(text)
	hint = _label(13, Color(0.7, 0.7, 0.66)); box.add_child(hint)
	set_objective("Find Marta Sokolova.")

func _label(sz: int, c: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1); l.add_theme_constant_override("shadow_offset_y", 1)
	return l

func set_objective(t: String, from_socko := false) -> void:
	socko = socko or from_socko
	header.text = " ".join(("SOCKO SAYS" if socko else "OBJECTIVE").split(""))   # spaced small caps
	text.text = t
	header.visible = t != ""

func show_hint(t: String, seconds := 6.0) -> void:
	hint.text = t; _hint_t = seconds; hint.modulate.a = 1.0

func _process(delta: float) -> void:
	if _hint_t > 0.0:
		_hint_t -= delta
		hint.modulate.a = clampf(_hint_t, 0.0, 1.0)
