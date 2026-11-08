class_name WeaponHud
extends CanvasLayer
## While the revolver is out: its seven chambers, bottom right, filled or empty, and the rounds
## in his pocket. On a touchscreen, FIRE, RELOAD and GUN buttons in the same style as the rest.

var player: Node
var marks: Control
var buttons := {}

func setup(p_player: Node) -> void:
	player = p_player

func _ready() -> void:
	layer = 6
	marks = Control.new(); marks.set_anchors_preset(Control.PRESET_FULL_RECT); marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.draw.connect(_draw_marks); add_child(marks)
	for b in [["fire", "FIRE", Vector2(-440, -110)], ["reload", "RELOAD", Vector2(-440, -250)], ["weapon", "GUN", Vector2(-300, -400)]]:
		var btn := Button.new(); btn.text = b[1]; btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 20)
		var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.05, 0.05, 0.05, 0.35); sb.border_color = Color(0.9, 0.88, 0.8, 0.35)
		sb.set_border_width_all(2); sb.set_corner_radius_all(60)
		for st in ["normal", "hover", "focus", "pressed"]: btn.add_theme_stylebox_override(st, sb)
		btn.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8, 0.8))
		btn.anchor_left = 1; btn.anchor_right = 1; btn.anchor_top = 1; btn.anchor_bottom = 1
		btn.offset_left = b[2].x - 55; btn.offset_right = b[2].x + 55; btn.offset_top = b[2].y - 55; btn.offset_bottom = b[2].y + 55
		btn.pressed.connect(_press.bind(b[0]))
		add_child(btn); buttons[b[0]] = btn

func _press(what: String) -> void:
	var g = player.get("gun")
	if not g: return
	match what:
		"fire": g.call("fire")
		"reload": g.call("reload")
		"weapon":
			if player.get("armory"): player.get("armory").call("cycle")
			else: g.call("toggle")

func _process(_d: float) -> void:
	var g = player.get("gun") if player else null
	var touch := DisplayServer.is_touchscreen_available() or bool(player.get("touch_ui")) if player else false
	buttons.weapon.visible = g != null and touch
	buttons.fire.visible = g != null and touch and bool(g.get("drawn"))
	buttons.reload.visible = buttons.fire.visible
	marks.queue_redraw()

func _draw_marks() -> void:
	var g = player.get("gun") if player else null
	if not g or not bool(g.get("drawn")): return
	var size := marks.size
	var c := Vector2(size.x - 84, size.y - 64)
	var loaded: int = g.get("loaded")
	var cap: int = int(g.get("capacity")) if g.get("capacity") != null else 7
	if cap == 2:
		# the shotgun: two shells side by side, as they sit in the breech
		for i in 2:
			var r := Rect2(c + Vector2(-16 + i * 18, -14), Vector2(12, 28))
			if i < loaded:
				marks.draw_rect(r, Color(0.7, 0.18, 0.12, 0.85))
				marks.draw_rect(Rect2(r.position + Vector2(0, 20), Vector2(12, 8)), Color(0.85, 0.75, 0.5, 0.9))
			else:
				marks.draw_rect(r, Color(0.85, 0.82, 0.75, 0.45), false, 1.5)
	else:
		for i in cap:
			var a := -PI * 0.5 + TAU * i / float(cap)
			var p := c + Vector2(cos(a), sin(a)) * 17.0
			if i < loaded: marks.draw_circle(p, 5.0, Color(0.85, 0.75, 0.5, 0.85))
			else: marks.draw_arc(p, 5.0, 0, TAU, 12, Color(0.85, 0.82, 0.75, 0.45), 1.5)
	marks.draw_string(ThemeDB.fallback_font, c + Vector2(30, 6), "+%d" % int(g.get("spare")), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.85, 0.82, 0.75, 0.7))
