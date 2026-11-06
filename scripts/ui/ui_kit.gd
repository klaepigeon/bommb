class_name UiKit
extends RefCounted
## One look for every screen: the pixel fonts from the series, a party palette on a dark
## plum ground, and big buttons (touch first: nothing a thumb can't hit).

const BG := Color("1e1028")
const PANEL := Color("2e1a3a")
const INK := Color("f8ecd8")
const HOT := Color("e8402a")
const GOLD := Color("f0c020")
const TEAL := Color("2ac0b0")
const DIM := Color("8a7a90")

static var _theme: Theme
static var _font: Font
static var _title: Font


static func font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/pixelify-sans.ttf")
	return _font


static func title_font() -> Font:
	if _title == null:
		_title = load("res://assets/fonts/silkscreen.ttf")
	return _title


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 14
	var sb := func(c: Color, border: Color, bw := 2) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = c
		s.border_color = border
		s.set_border_width_all(bw)
		s.set_corner_radius_all(0)
		s.content_margin_left = 8
		s.content_margin_right = 8
		s.content_margin_top = 4
		s.content_margin_bottom = 4
		s.shadow_color = Color(0, 0, 0, 0.5)
		s.shadow_size = 0
		s.shadow_offset = Vector2(3, 3)
		return s
	t.set_stylebox("normal", "Button", sb.call(Color("4a2058"), GOLD))
	t.set_stylebox("hover", "Button", sb.call(Color("6a2a78"), GOLD))
	t.set_stylebox("pressed", "Button", sb.call(HOT, GOLD))
	t.set_stylebox("focus", "Button", sb.call(Color("6a2a78"), Color.WHITE, 3))
	t.set_stylebox("disabled", "Button", sb.call(Color("2a1a30"), DIM))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_font_size("font_size", "Button", 16)
	t.set_stylebox("panel", "PanelContainer", sb.call(Color(PANEL, 0.94), Color("8a4aa0")))
	t.set_stylebox("panel", "Panel", sb.call(Color(PANEL, 0.94), Color("8a4aa0")))
	t.set_color("font_color", "Label", INK)
	t.set_stylebox("normal", "LineEdit", sb.call(Color("140a1a"), GOLD))
	t.set_color("font_color", "LineEdit", INK)
	t.set_font_size("font_size", "LineEdit", 18)
	t.set_stylebox("slider", "HSlider", sb.call(Color("140a1a"), DIM, 1))
	_theme = t
	return t


static func button(text: String, cb: Callable, min_h := 40, min_w := 120) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, min_h)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func():
		Audio.sfx("tick", 0.05, -6.0, 1.3)
		cb.call())
	return b


static func label(text: String, size := 14, color := INK, title := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if title:
		l.add_theme_font_override("font", title_font())
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func panel() -> PanelContainer:
	return PanelContainer.new()


static func vbox(sep := 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 6) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func bg(parent: Control) -> ColorRect:
	var r := ColorRect.new()
	r.color = BG
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r
