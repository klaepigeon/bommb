class_name UIKit
## Shared look for the UI: big, plain, legible on a phone at arm's length. Everything is sized
## from the screen height so a 6" phone and a 10" tablet get the same physical button sizes.

static func unit(node: Node) -> float:
	var h := node.get_viewport().get_visible_rect().size.y if node.is_inside_tree() else 720.0
	return h / 720.0

static func panel_style(bg := Color(0, 0, 0, 0.72), radius := 10, border := Color(1, 1, 1, 0.12)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(2)
	s.content_margin_left = 14; s.content_margin_right = 14
	s.content_margin_top = 10; s.content_margin_bottom = 10
	return s

static func circle_style(bg: Color, border := Color(1, 1, 1, 0.25)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(999)
	s.border_color = border
	s.set_border_width_all(2)
	return s

static func label(text: String, size := 22, color := Color(0.92, 0.9, 0.85)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	return l

## a menu button, big enough for a thumb
static func button(text: String, size := 26, min_h := 64.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, min_h)
	b.add_theme_stylebox_override("normal", panel_style(Color(0.12, 0.11, 0.1, 0.9)))
	b.add_theme_stylebox_override("hover", panel_style(Color(0.2, 0.18, 0.16, 0.95)))
	b.add_theme_stylebox_override("pressed", panel_style(Color(0.35, 0.25, 0.2, 0.95)))
	b.add_theme_stylebox_override("focus", panel_style(Color(0.2, 0.18, 0.16, 0.95), 10, Color(1, 0.8, 0.5, 0.6)))
	b.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
	return b

static func slider(minv: float, maxv: float, step: float, value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = minv; s.max_value = maxv; s.step = step; s.value = value
	s.custom_minimum_size = Vector2(320, 48)
	var grab := StyleBoxFlat.new(); grab.bg_color = Color(0.9, 0.7, 0.5); grab.set_corner_radius_all(20)
	s.add_theme_stylebox_override("grabber_area", grab)
	s.add_theme_stylebox_override("grabber_area_highlight", grab)
	return s

static func fullscreen_dim(alpha := 0.85) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0, 0, 0, alpha)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c
