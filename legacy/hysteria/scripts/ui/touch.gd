extends CanvasLayer
## Touch controls for phones and tablets: drag on the left half to walk (a stick appears where you
## put your thumb; push it to the rim to run), drag on the right half to look, and buttons on the
## right. Hidden when there's no touchscreen, and again whenever a gamepad is being used.

var player: Node
var move_id := -1
var look_id := -1
var move_origin := Vector2.ZERO
var move_vec := Vector2.ZERO
var stick_base: Panel
var stick_knob: Panel
var buttons := {}
const STICK_R := 90.0
const LOOK_K := 0.0045 / 0.0022     # the player's look() expects mouse pixels at its sensitivity

func _ready() -> void:
	layer = 5
	stick_base = _circle(STICK_R * 2.0, Color(1, 1, 1, 0.07)); stick_knob = _circle(70.0, Color(1, 1, 1, 0.16))
	add_child(stick_base); add_child(stick_knob)
	stick_base.visible = false; stick_knob.visible = false
	# right-hand buttons, bottom-right anchored: [action, label, offset from bottom-right]
	for b in [["use", "USE", Vector2(-150, -170)], ["throw", "THROW", Vector2(-290, -110)], ["torch", "TORCH", Vector2(-150, -320)], ["crouch", "CROUCH", Vector2(-300, -260)]]:
		var btn := Button.new()
		btn.text = b[1]; btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 22)
		var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.05, 0.05, 0.05, 0.35); sb.border_color = Color(0.9, 0.88, 0.8, 0.35)
		sb.set_border_width_all(2); sb.set_corner_radius_all(60)
		for st in ["normal", "hover", "focus"]: btn.add_theme_stylebox_override(st, sb)
		var sp := sb.duplicate() as StyleBoxFlat; sp.bg_color = Color(0.9, 0.88, 0.8, 0.3); btn.add_theme_stylebox_override("pressed", sp)
		btn.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8, 0.8))
		btn.size = Vector2(120, 120)
		btn.anchor_left = 1; btn.anchor_right = 1; btn.anchor_top = 1; btn.anchor_bottom = 1
		btn.offset_left = b[2].x - 60; btn.offset_right = b[2].x + 60; btn.offset_top = b[2].y - 60; btn.offset_bottom = b[2].y + 60
		btn.button_down.connect(_pressed.bind(b[0]))
		btn.button_up.connect(_released.bind(b[0]))
		add_child(btn); buttons[b[0]] = btn
	visible = Game.has_touch()

func _circle(d: float, col: Color) -> Panel:
	var p := Panel.new(); var sb := StyleBoxFlat.new(); sb.bg_color = col; sb.set_corner_radius_all(int(d))
	sb.border_color = Color(1, 1, 1, col.a * 1.6); sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb); p.size = Vector2(d, d); p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _pressed(what: String) -> void:
	match what:
		"use": player.use()
		"throw": player.throw()
		"torch": player.toggle_torch()
		"crouch": player.toggle_crouch()

func _released(_what: String) -> void:
	pass

func _over_button(pos: Vector2) -> bool:
	for b in buttons.values():
		if (b as Control).get_global_rect().has_point(pos):
			return true
	return false

func _input(e: InputEvent) -> void:
	if e is InputEventJoypadButton or (e is InputEventJoypadMotion and absf(e.axis_value) > 0.4):
		visible = false; _release_move(); return
	if not (e is InputEventScreenTouch or e is InputEventScreenDrag):
		return
	if not visible:
		visible = true
	player.touch_ui = true
	var half := get_viewport().get_visible_rect().size.x * 0.5
	if e is InputEventScreenTouch:
		if e.pressed:
			if e.position.x < half and move_id < 0:
				move_id = e.index; move_origin = e.position; move_vec = Vector2.ZERO
				stick_base.visible = true; stick_knob.visible = true
				stick_base.position = e.position - stick_base.size * 0.5; stick_knob.position = e.position - stick_knob.size * 0.5
			elif e.position.x >= half and look_id < 0 and not _over_button(e.position):
				look_id = e.index
		else:
			if e.index == move_id: _release_move()
			if e.index == look_id: look_id = -1
	elif e is InputEventScreenDrag:
		if e.index == move_id:
			var d: Vector2 = (e.position - move_origin).limit_length(STICK_R)
			move_vec = d / STICK_R
			stick_knob.position = move_origin + d - stick_knob.size * 0.5
			_apply_move()
		elif e.index == look_id:
			player.look(e.relative * LOOK_K)

func _apply_move() -> void:
	var v := move_vec
	for pair in [["move_left", -v.x], ["move_right", v.x], ["move_forward", -v.y], ["move_back", v.y]]:
		if pair[1] > 0.05: Input.action_press(pair[0], pair[1])
		else: Input.action_release(pair[0])
	if v.length() > 0.92 and v.y < -0.5: Input.action_press("sprint")
	else: Input.action_release("sprint")

func _release_move() -> void:
	move_id = -1; move_vec = Vector2.ZERO
	stick_base.visible = false; stick_knob.visible = false
	for a in ["move_left", "move_right", "move_forward", "move_back", "sprint"]:
		Input.action_release(a)
