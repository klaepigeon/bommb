class_name PartyUi
extends RefCounted
## MURDERLAND's house style for everything on the glass: the robot's idea of a children's
## party. Fat rounded panels with a black outline and a drop shadow, bubblegum pink,
## yellow, turquoise, mint, purple, orange, cream; Titan One for anything shouted, Baloo 2
## for everything read. Big touch targets (UiManager.button). Readable over any background:
## every panel is opaque, every loose label is outlined.

const PINK := Color("ff5fa2")
const RED := Color("ff3b3b")
const YELLOW := Color("ffd23f")
const TURQ := Color("2ec4c6")
const ORANGE := Color("ff8c2e")
const PURPLE := Color("8e5cf0")
const MINT := Color("6fe3a5")
const CREAM := Color("fff4dc")
const SILVER := Color("c9d1d9")
const BLOOD := Color("8a0f1a")
const INK := Color("1a0b14")
const DIM := Color("8a7a88")
const SEAT := [Color("ff5fa2"), Color("2ec4c6"), Color("ffd23f"), Color("8e5cf0")]
const SPACE := {
	"start": Color("ffffff"), "normal": Color("2e8bff"), "bonus": Color("ffd23f"), "bad": Color("ff3b3b"), "event": Color("6fe3a5"),
	"item": Color("8e5cf0"), "shop": Color("ff8c2e"), "black_market": Color("2a1a2e"), "medical": Color("f8f8ff"), "minigame": Color("ff5fa2"),
	"duel": Color("c0392b"), "battle": Color("e67e22"), "roulette": Color("111111"), "resurrect": Color("bfe9ff"), "poison": Color("7bd64a"),
	"gamble": Color("f1c40f"), "caller": Color("b03a8a"), "trap": Color("6b4a2a"), "hidden": Color("4a4a5a"), "rulebook": Color("e8dcc0"),
	"veto": Color("c8b080"), "death": Color("2b0008"), "surgery": Color("e8fff4"), "signpost": Color("3ac060"), "rotator": Color("ff6ad5"),
	"floodgate": Color("2a7ab0"), "switch": Color("a0a0b0"), "conveyor": Color("707080"), "wheel": Color("ff9f1c"), "control": Color("ff2e63"),
	"clue": Color("d8c8a0"), "door": Color("6a4a2e"), "note": Color("d8c8a0")}
const GLYPH := {"start": "GO", "normal": "+3", "bonus": "★", "bad": "−3", "event": "!", "item": "?", "shop": "$", "black_market": "££",
	"medical": "+", "minigame": "▶", "duel": "VS", "battle": "⚔", "roulette": "●", "resurrect": "↑", "poison": "☠", "gamble": "×2",
	"caller": "C", "trap": "▲", "hidden": "…", "rulebook": "§", "veto": "✕", "death": "✝", "surgery": "✚", "signpost": "⇆",
	"rotator": "↻", "floodgate": "≈", "switch": "⇄", "conveyor": "»", "wheel": "✺", "control": "◎", "clue": "#", "door": "▯", "note": "~"}

static var _title: Font
static var _body: Font
static var _theme: Theme


static func title_font() -> Font:
	if _title == null:
		_title = load("res://assets/fonts/titan_one.ttf")
	return _title


static func body_font() -> Font:
	if _body == null:
		var f: FontVariation = FontVariation.new()
		f.base_font = load("res://assets/fonts/baloo2.ttf")
		f.variation_opentype = {"wght": 700}
		_body = f
	return _body


static func k() -> float:
	var ui: Node = Engine.get_main_loop().root.get_node_or_null("Ui") if Engine.get_main_loop() is SceneTree else null
	return float(ui.text) if ui else 1.0


static func bk() -> float:
	var ui: Node = Engine.get_main_loop().root.get_node_or_null("Ui") if Engine.get_main_loop() is SceneTree else null
	return float(ui.button) / 64.0 if ui else 1.0


static func box(bg: Color, border := INK, radius := 18, bw := 4, shadow := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = shadow
	sb.shadow_offset = Vector2(0, shadow * 0.6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.anti_aliasing = true
	return sb


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = int(22 * k())
	t.set_stylebox("normal", "Button", box(CREAM))
	t.set_stylebox("hover", "Button", box(YELLOW))
	t.set_stylebox("pressed", "Button", box(ORANGE, INK, 18, 4, 2))
	t.set_stylebox("disabled", "Button", box(Color("d8cfc0"), DIM))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), PINK, 18, 4, 0))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_stylebox("panel", "PanelContainer", box(CREAM))
	t.set_color("font_color", "Label", INK)
	_theme = t
	return t


static func panel(bg := CREAM, border := INK, radius := 22) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, radius))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


static func label(text: String, size := 22, color := INK, title := false, outline := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", title_font() if title else body_font())
	l.add_theme_font_size_override("font_size", int(size * k()))
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", int(10 * k()))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## A shout: Titan One, outlined, centred (headlines over the board).
static func shout(text: String, size := 48, color := YELLOW) -> Label:
	var l := label(text, size, color, true, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", int(16 * k()))
	return l


static func button(text: String, cb: Callable, colour := CREAM, min_w := 180.0, size := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", title_font())
	b.add_theme_font_size_override("font_size", int(size * k()))
	b.add_theme_stylebox_override("normal", box(colour))
	b.add_theme_stylebox_override("hover", box(colour.lightened(0.25)))
	b.add_theme_stylebox_override("pressed", box(colour.darkened(0.2), INK, 18, 4, 2))
	b.add_theme_stylebox_override("disabled", box(colour.lerp(Color("bbbbbb"), 0.7), DIM))
	b.add_theme_color_override("font_color", INK if colour.get_luminance() > 0.45 else CREAM)
	b.add_theme_color_override("font_hover_color", INK if colour.get_luminance() > 0.35 else CREAM)
	b.add_theme_color_override("font_disabled_color", DIM)
	b.custom_minimum_size = Vector2(min_w * bk(), 64.0 * bk())
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.focus_mode = Control.FOCUS_NONE
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


static func primary(text: String, cb: Callable, min_w := 220.0) -> Button:
	return button(text, cb, YELLOW, min_w, 26)


static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(sep * k()))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(sep * k()))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


static func flow(sep := 8) -> HFlowContainer:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", int(sep * k()))
	h.add_theme_constant_override("v_separation", int(sep * k()))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


## A little coloured badge (a stat, a status).
static func chip(text: String, bg: Color, size := 16) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(bg, INK, 12, 3, 0)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, size, INK if bg.get_luminance() > 0.45 else CREAM, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	p.add_child(l)
	return p


## A meter: a fat rounded bar, `frac` 0..1.
static func meter(frac: float, col: Color, w := 160.0, h := 16.0, label_text := "") -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h) * k()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", box(Color("2a1a26"), INK, int(h * 0.5), 3, 0))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(bg)
	var fg := Panel.new()
	fg.add_theme_stylebox_override("panel", box(col, Color(0, 0, 0, 0), int(h * 0.5), 0, 0))
	fg.anchor_right = clampf(frac, 0.0, 1.0)
	fg.anchor_bottom = 1.0
	fg.offset_left = 3
	fg.offset_top = 3
	fg.offset_bottom = -3
	fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(fg)
	if label_text != "":
		var l := label(label_text, int(h * 0.8), CREAM, true, true)
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		c.add_child(l)
	return c


static func space_colour(t: String) -> Color:
	return SPACE.get(t, Color("2e8bff"))


static func seat_colour(s: int) -> Color:
	return SEAT[posmod(s, SEAT.size())]
