class_name UiKit
extends RefCounted
## MEAT PARTY's screens in LAST CALL: The Campaign's hand: his card stock (the ink-bordered
## paper from assets/ink/paper), IM Fell English for what he says and for headings, Special
## Elite for the typewritten bits. A thin layer over the campaign's own UIKit.

const INK := Color("3a0e0a")       # dried blood, on paper
const HOT := Color("9a1a12")       # fresh red ink
const GOLD := Color("8a6420")      # brass, on paper
const CREAM := Color("f0e6cc")     # for text over the dark room
const TEAL := Color("1e4a3a")      # what only you know
const DIM := Color("6a5a4a")
const BG := Color("0a0806")


static func font() -> Font:
	UIKit.fonts()
	return UIKit.body_font


static func title_font() -> Font:
	UIKit.fonts()
	return UIKit.title_font


static func voice_font() -> Font:
	UIKit.fonts()
	return UIKit.voice_font


static func theme() -> Theme:
	return UIKit.theme()


static func button(text: String, cb: Callable, min_h := 40, min_w := 120) -> Button:
	var b := UIKit.button(text, cb, false, Vector2(min_w * 1.5, min_h * 1.3))
	return b


static func primary(text: String, cb: Callable, min_h := 48, min_w := 160) -> Button:
	return UIKit.button(text, cb, true, Vector2(min_w * 1.5, min_h * 1.3))


static func label(text: String, size := 14, color := INK, title := false) -> Label:
	var l := UIKit.label(text, int(size * 1.45), color, title, true)
	return l


## What he says: IM Fell, cream, outlined, over the room.
static func voice(text: String, size := 34) -> Label:
	UIKit.fonts()
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UIKit.voice_font)
	l.add_theme_font_size_override("font_size", UIKit.px(size))
	l.add_theme_color_override("font_color", CREAM)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.02, 0.95))
	l.add_theme_constant_override("outline_size", 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func panel() -> PanelContainer:
	return UIKit.paper(10)


## A small card (a character sheet, a note).
static func card() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.ink_box("res://assets/ink/paper/card.png", Color.WHITE, 18, 12))
	return p


static func dark() -> PanelContainer:
	return UIKit.dark(14)


static func vbox(sep := 6) -> VBoxContainer:
	return UIKit.vbox(sep)


static func hbox(sep := 6) -> HBoxContainer:
	return UIKit.hbox(sep)


static func bg(parent: Control) -> ColorRect:
	var r := ColorRect.new()
	r.color = BG
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r
