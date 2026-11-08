class_name PartyUi
extends RefCounted
## MEAT PARTY's look on the glass: LAST CALL's hand-inked card stock, dyed. Every panel and
## button is a sheet of his paper (freehand ink border, coffee rings, specks) tinted from
## one palette; IM Fell English SC for anything he prints, Special Elite for anything
## typed. Readable over any background: panels are opaque, loose labels are inked round.
##
## The palette, by colour theory: a dark neutral (dried blood) and a light one (bone) carry
## everything; one dominant accent (blood red) for danger and the big action; its split
## complements (bile green, verdigris) for "good"/"go"; a warm highlight (nicotine yellow)
## for what's selected or yours. Saturation is kept a notch below clean, so it reads gross,
## not candy. The four seats are spaced round the wheel at matched value.

const PINK := Color("c2263a")      # wound pink-red: headings, the title
const RED := Color("b3201a")       # blood: danger, the main action
const YELLOW := Color("e0b43c")    # nicotine: highlight, selected, primary buttons
const TURQ := Color("3f9488")      # verdigris: go, safe, info
const ORANGE := Color("cc6a24")    # rust: shops, money
const PURPLE := Color("7e4f96")    # bruise: items, the uncanny
const MINT := Color("9bbd3c")      # bile: good news
const CREAM := Color("e6d9b5")     # bone: the paper itself
const SILVER := Color("9aa39c")
const BLOOD := Color("7a0d14")
const INK := Color("1e120e")       # dried-blood ink
const DIM := Color("6e6152")
const SEAT := [Color("c8322a"), Color("2f9a8e"), Color("d9a92e"), Color("8a5aa8")]
const SPACE := {
	"start": Color("ffffff"), "normal": Color("2e8bff"), "bonus": Color("ffd23f"), "bad": Color("ff3b3b"), "event": Color("6fe3a5"),
	"item": Color("8e5cf0"), "shop": Color("ff8c2e"), "black_market": Color("2a1a2e"), "medical": Color("f8f8ff"), "minigame": Color("ff5fa2"),
	"duel": Color("c0392b"), "battle": Color("e67e22"), "roulette": Color("111111"), "resurrect": Color("bfe9ff"), "poison": Color("7bd64a"),
	"gamble": Color("f1c40f"), "caller": Color("b03a8a"), "trap": Color("6b4a2a"), "hidden": Color("4a4a5a"), "rulebook": Color("e8dcc0"),
	"veto": Color("c8b080"), "death": Color("2b0008"), "surgery": Color("e8fff4"), "signpost": Color("3ac060"), "rotator": Color("ff6ad5"),
	"floodgate": Color("2a7ab0"), "switch": Color("a0a0b0"), "conveyor": Color("707080"), "wheel": Color("ff9f1c"), "control": Color("ff2e63"),
	"clue": Color("d8c8a0"), "door": Color("6a4a2e"), "note": Color("d8c8a0"), "search": Color("e8d27a")}
const GLYPH := {"start": "GO", "normal": "+3", "bonus": "★", "bad": "−3", "event": "!", "item": "?", "shop": "$", "black_market": "££",
	"medical": "+", "minigame": "▶", "duel": "VS", "battle": "⚔", "roulette": "●", "resurrect": "↑", "poison": "☠", "gamble": "×2",
	"caller": "C", "trap": "▲", "hidden": "…", "rulebook": "§", "veto": "✕", "death": "✝", "surgery": "✚", "signpost": "⇆",
	"rotator": "↻", "floodgate": "≈", "switch": "⇄", "conveyor": "»", "wheel": "✺", "control": "◎", "clue": "#", "door": "▯", "note": "~", "search": "?!"}

## What every square is, for the landing panel: its name, and what it does to you.
const SPACE_INFO := {
	"start": ["THE START", "Pass it: +3 Teeth."], "normal": ["A TEETH SQUARE", "+3 Teeth."], "bad": ["A BAD SQUARE", "-3 Teeth."],
	"bonus": ["A BONUS SQUARE", "Something good from the machines."], "event": ["AN EVENT", "Something happens. To someone."],
	"item": ["AN ITEM SQUARE", "Something for your pockets."], "shop": ["THE SHOP", "Spend your Teeth."], "black_market": ["THE BLACK MARKET", "Spend them on worse things."],
	"medical": ["THE MEDIC", "Treatment, for a price."], "minigame": ["A MINIGAME SQUARE", "A game, right now."], "duel": ["A DUEL", "Pick someone. Wager. Play."],
	"battle": ["A BATTLE", "Everyone puts Teeth in a pot. One game."], "roulette": ["THE REVOLVER", "Russian Roulette at the round's end."],
	"resurrect": ["THE RESURRECTION SQUARE", "Someone dead comes back."], "poison": ["A POISON SQUARE", "Drink it?"], "gamble": ["A GAMBLE", "Double or nothing."],
	"caller": ["HIS SQUARE", "The Caller decides."], "trap": ["A TRAP", "It goes off."], "hidden": ["A HIDDEN SQUARE", "Something's under it."],
	"rulebook": ["THE RULEBOOK", "A new rule for everyone."], "veto": ["THE VETO", "Strike a rule out."], "death": ["THE DEATH MACHINE", "It might kill you."],
	"surgery": ["THE OPERATING THEATRE", "ORGAN TRAIL, after the turns."], "signpost": ["A SIGNPOST", "Point the road the other way."],
	"rotator": ["THE ROTATING PLATFORM", "Turn it."], "floodgate": ["THE FLOODGATES", "Open or shut."], "switch": ["A SWITCH", "Flip a path."],
	"conveyor": ["A CONVEYOR", "It carries you."], "wheel": ["THE WHEEL", "Spin it."], "control": ["THE CONTROL DESK", "Pull a lever."],
	"search": ["SEARCH THE ROOM", "Everyone gets up and searches."],
}

static var _title: Font
static var _body: Font
static var _theme: Theme


static func title_font() -> Font:
	if _title == null:
		_title = load("res://assets/fonts/fell_sc.ttf")
	return _title


static func body_font() -> Font:
	if _body == null:
		_body = load("res://assets/fonts/special_elite.ttf")
	return _body


static func k() -> float:
	var ui: Node = Engine.get_main_loop().root.get_node_or_null("Ui") if Engine.get_main_loop() is SceneTree else null
	return float(ui.text) if ui else 1.0


static func bk() -> float:
	var ui: Node = Engine.get_main_loop().root.get_node_or_null("Ui") if Engine.get_main_loop() is SceneTree else null
	return float(ui.button) / 64.0 if ui else 1.0


## A sheet of his card stock dyed `bg`: light colours on the white stock (the ink border stays
## dark), dark colours on the dark stock (the border comes out pale). `radius` picks the cut:
## small = a button strip, large = a sheet. `border`/`bw`/`shadow` are kept for callers but the
## ink border is drawn into the paper.
static func box(bg: Color, border := INK, radius := 18, bw := 4, shadow := 6) -> StyleBox:
	var dark := bg.get_luminance() < 0.22
	var path := "res://assets/ink/party/dark.png" if dark else ("res://assets/ink/party/button.png" if radius < 20 else "res://assets/ink/party/card.png")
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	var base := 0.25 if dark else 0.94
	sb.modulate_color = Color(bg.r / base, bg.g / base, bg.b / base, bg.a)
	var m := 10.0 if radius < 20 else 22.0
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_texture_margin(side, m)
	var cm := 14.0 if radius < 20 else 30.0
	sb.content_margin_left = cm
	sb.content_margin_right = cm
	sb.content_margin_top = 8.0 if radius < 20 else 24.0
	sb.content_margin_bottom = 8.0 if radius < 20 else 24.0
	return sb


## A plain flat fill (meters, thin bars: too small for paper).
static func flat_box(bg: Color, border := INK, bw := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.anti_aliasing = false
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
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
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
		# a touch screen sends the touch AND a mouse click made from it: one press, once
		b.pressed.connect(func():
			var now := Time.get_ticks_msec()
			if now - int(b.get_meta("_last", -1000)) < 150:
				return
			if b.get_meta("_long", false):
				b.set_meta("_long", false)
				return     # that was a long-press to read it, not to use it
			b.set_meta("_last", now)
			cb.call())
	# respond on touch-down, unless it's in a list you might be scrolling
	b.tree_entered.connect(func():
		var n: Node = b.get_parent()
		var in_scroll := false
		while n:
			if n is ScrollContainer:
				in_scroll = true
				break
			n = n.get_parent()
		# something you can long-press to read about acts on release, so holding doesn't use it
		b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE if in_scroll or b.tooltip_text != "" else BaseButton.ACTION_MODE_BUTTON_PRESS)
	b.button_down.connect(func():
		b.set_meta("_held_at", Time.get_ticks_msec())
		if b.tooltip_text != "":
			b.get_tree().create_timer(0.5).timeout.connect(func():
				if is_instance_valid(b) and b.is_pressed() and Time.get_ticks_msec() - int(b.get_meta("_held_at", 0)) >= 480:
					b.set_meta("_long", true)
					var ui = b.get_tree().root.get_node_or_null("Ui")
					if ui:
						ui.show_tip(b.tooltip_text))
		var ui2 = b.get_tree().root.get_node_or_null("Ui")
		if ui2:
			ui2.buzz(8, 0.2)
		Sfx.play("blip", -10.0, 0.08)
		b.pivot_offset = b.size * 0.5
		b.scale = Vector2(0.94, 0.94)
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
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
	var sb := flat_box(bg, INK, 2)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, size, INK if bg.get_luminance() > 0.45 else CREAM, false)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	p.add_child(l)
	return p


## A meter: a fat rounded bar, `frac` 0..1.
static func meter(frac: float, col: Color, w := 160.0, h := 16.0, label_text := "") -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h) * k()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", flat_box(Color("2a1a14"), INK, 2))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(bg)
	var fg := Panel.new()
	fg.add_theme_stylebox_override("panel", flat_box(col, Color(0, 0, 0, 0), 0))
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
