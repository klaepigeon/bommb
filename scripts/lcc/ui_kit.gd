class_name UIKit
extends RefCounted
## The overlay look: aged paper, brown ink, cream buttons with a hard shadow, a gold primary
## button, and printed-playbill and typewriter fonts. Matches the LAST CALL menus (Continue / New Season ...).

const INK := Color("2a1a14")
const PAPER := Color("e4d8b8")
const PAPER_DARK := Color("c8b890")
const CREAM := Color("e8dcc0")
const GOLD := Color("c8a040")
const RED := Color("9a2a1e")
const DARK := Color(0.07, 0.05, 0.04, 0.88)
const AMBER := Color("e8c060")

static var _theme: Theme
static var title_font: Font   # IM Fell English SC: playbills, headings, buttons
static var body_font: Font    # Special Elite: the typewritten sheets and labels
static var voice_font: Font   # IM Fell English: what he says
static var ital_font: Font    # IM Fell English italic: asides, lore

static func fonts() -> void:
	if title_font == null:
		title_font = load("res://assets/fonts/fell_sc.ttf")
		body_font = load("res://assets/fonts/special_elite.ttf")
		voice_font = load("res://assets/fonts/fell.ttf")
		ital_font = load("res://assets/fonts/fell_italic.ttf")

static func scale() -> float:
	var s := 1.0
	if Engine.get_main_loop() and Engine.get_main_loop().root.has_node("Settings"):
		s = float(Engine.get_main_loop().root.get_node("Settings").get_value("text_size", 1.0))
	return s

static func px(n: float) -> int:
	return int(round(n * scale()))

static func box(bg: Color, border: Color, bw: int = 3, shadow: int = 4, radius: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(shadow, shadow)
	if shadow > 0:
		sb.shadow_size = 1
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.anti_aliasing = false
	return sb

## His card stock as a stylebox: the freehand border is part of the texture, so every panel
## and button looks like something he drew on, not a widget.
static func ink_box(path: String, tint := Color.WHITE, margin := 20.0, pad := 14.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	sb.modulate_color = tint
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_texture_margin(side, margin)
		sb.set_content_margin(side, pad)
	return sb

static func theme() -> Theme:
	if _theme != null:
		return _theme
	fonts()
	var t := Theme.new()
	t.default_font = body_font
	t.default_font_size = px(20)
	var card := "res://assets/ink/paper/button.png"
	t.set_stylebox("normal", "Button", ink_box(card, Color.WHITE, 10, 12))
	t.set_stylebox("hover", "Button", ink_box(card, Color(1.08, 1.04, 0.96), 10, 12))
	t.set_stylebox("pressed", "Button", ink_box(card, Color(0.85, 0.8, 0.74), 10, 12))
	t.set_stylebox("disabled", "Button", ink_box(card, Color(0.62, 0.6, 0.56), 10, 12))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Sketch.INK)
	t.set_color("font_hover_color", "Button", Color("a0140e"))
	t.set_color("font_pressed_color", "Button", Sketch.INK_DRY)
	t.set_color("font_focus_color", "Button", Sketch.INK)
	t.set_color("font_disabled_color", "Button", Color("4a4038"))
	t.set_font("font", "Button", title_font)
	t.set_font_size("font_size", "Button", px(18))
	t.set_color("font_color", "Label", Color("3a0e0a"))
	t.set_stylebox("panel", "Panel", ink_box("res://assets/ink/paper/sheet.png", Color.WHITE, 34, 36))
	t.set_stylebox("panel", "PanelContainer", ink_box("res://assets/ink/paper/sheet.png", Color.WHITE, 34, 36))
	t.set_stylebox("panel", "TooltipPanel", ink_box("res://assets/ink/paper/card_dark.png", Color.WHITE, 22, 12))
	t.set_color("font_color", "TooltipLabel", CREAM)
	t.set_font_size("font_size", "TooltipLabel", px(18))
	t.set_stylebox("grabber_area", "HSlider", box(Color("8a6a3a"), Color("5a3a24"), 2, 0))
	t.set_stylebox("slider", "HSlider", box(Color("5a4a3a"), Color("3a2a1a"), 2, 0))
	t.set_stylebox("normal", "LineEdit", box(Color("f4ead2"), Color("5a3a24"), 2, 0))
	t.set_color("font_color", "LineEdit", INK)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_color("font_color", "CheckBox", INK)
	t.set_color("font_hover_color", "CheckBox", INK)
	t.set_color("font_pressed_color", "CheckBox", INK)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font("normal_font", "RichTextLabel", body_font)
	t.set_font("bold_font", "RichTextLabel", title_font)
	t.set_font_size("normal_font_size", "RichTextLabel", px(19))
	t.set_font_size("bold_font_size", "RichTextLabel", px(17))
	t.set_stylebox("normal", "OptionButton", box(CREAM, Color("5a3a24"), 3, 3))
	t.set_stylebox("hover", "OptionButton", box(Color("f4ead2"), Color("5a3a24"), 3, 3))
	t.set_stylebox("pressed", "OptionButton", box(Color("cfc0a0"), Color("5a3a24"), 3, 1))
	t.set_color("font_color", "OptionButton", INK)
	t.set_color("font_hover_color", "OptionButton", INK)
	_theme = t
	return t

static func reset_theme() -> void:
	_theme = null

static func button(text: String, cb: Callable, primary := false, min_size := Vector2(0, 52)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_size.x, maxf(min_size.y, 48.0))
	b.focus_mode = Control.FOCUS_ALL
	if primary:
		# the one to press: his card, stained with something
		var card := "res://assets/ink/paper/button.png"
		b.add_theme_stylebox_override("normal", ink_box(card, Color(1.0, 0.8, 0.7), 10, 12))
		b.add_theme_stylebox_override("hover", ink_box(card, Color(1.06, 0.86, 0.76), 10, 12))
		b.add_theme_stylebox_override("pressed", ink_box(card, Color(0.85, 0.66, 0.58), 10, 12))
	b.pressed.connect(func():
		if Engine.get_main_loop().root.has_node("Sfx"):
			Engine.get_main_loop().root.get_node("Sfx").play("click", -4.0)
		cb.call())
	return b

## A square button with a pixel icon instead of words (the name is in the tooltip).
static func icon_button(icon: String, tip: String, cb: Callable, primary := false, side := 52) -> Button:
	var b := button("", cb, primary, Vector2(side, side))
	b.icon = Icons.tex(icon, INK, RED, 3)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = true
	b.tooltip_text = tip
	b.add_theme_constant_override("icon_max_width", int(side * 0.62))
	return b

static func label(text: String, size: int = 20, col: Color = INK, title := false, wrap := false) -> Label:
	fonts()
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", title_font if title else body_font)
	l.add_theme_font_size_override("font_size", px(size))
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func rich(bbcode: String, size: int = 19, col: Color = INK) -> RichTextLabel:
	fonts()
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = bbcode
	r.add_theme_font_size_override("normal_font_size", px(size))
	r.add_theme_font_size_override("bold_font_size", px(size - 2))
	r.add_theme_color_override("default_color", col)
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return r

static func paper(pad: int = 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ink_box("res://assets/ink/paper/sheet.png", Color.WHITE, 34, pad + 20))
	return p

static func dark(pad: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(DARK, Color(0, 0, 0, 0), 0, 0)
	sb.border_width_left = 4
	sb.border_color = Color("c8bca0")
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.7
	sb.content_margin_bottom = pad * 0.7
	p.add_theme_stylebox_override("panel", sb)
	return p

static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func icon_rect(name: String, size: int = 30, ink := INK, ink2 := RED) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Icons.tex(name, ink, ink2)
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return t

## Place an anchored control by offset from its anchor point (safe to call at any time,
## unlike setting position, which is absolute once the parent has a size).
static func at(c: Control, off: Vector2) -> void:
	var s := c.get_combined_minimum_size()
	c.offset_left = off.x
	c.offset_top = off.y
	c.offset_right = off.x + s.x
	c.offset_bottom = off.y + s.y

static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

## A full-screen dim layer that holds a centred panel; clicking outside does nothing.
static func modal(parent: Node, min_w: float = 640.0) -> Array:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var p := paper(22)
	p.custom_minimum_size = Vector2(min_w, 0)
	center.add_child(p)
	var v := vbox(12)
	p.add_child(v)
	return [dim, v]
