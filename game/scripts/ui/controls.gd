class_name Controls
extends Control
## All input in one place, touch first: a floating stick on the left half, drag to look on the
## right, a USE button that appears when there's something to use, pause top right. Keyboard and
## mouse, and any gamepad, work too. The player reads `move` and `consume_look()`.

signal interact_pressed
signal pause_pressed
signal action(name: String)          ## fire, aim, reload, skills (touch buttons and keys/pad)

var move := Vector2.ZERO
var prompt := ""
var show_touch := false
var autopilot_move := Vector2.ZERO      ## tests drive the game through here
var autopilot := false

var _look := Vector2.ZERO
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_id := -1
var _look_last := Vector2.ZERO
var _use_id := -1
## Touch buttons shown besides USE and pause: name → visible. Labels below.
var buttons := {"fire": false, "aim": false, "reload": false, "skills": false, "swap": false}
var labels := {"fire": "FIRE", "aim": "AIM", "reload": "LOAD", "skills": "SKILLS", "swap": "SWAP"}
var aiming := false

const STICK_R := 90.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_touch = Settings.is_touch()

func consume_look() -> Vector2:
	var l := _look
	_look = Vector2.ZERO
	# gamepad right stick
	var rs := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if rs.length() > 0.15:
		l += rs * rs.length() * 2.6 * get_physics_process_delta_time()
	return l

func _use_rect() -> Rect2:
	var s := size
	return Rect2(s.x - 250, s.y - 250, 190, 190)

func _pause_rect() -> Rect2:
	return Rect2(size.x - 110, 20, 90, 90)

func _button_rect(name: String) -> Rect2:
	match name:
		"fire": return Rect2(size.x - 230, size.y - 470, 160, 160)
		"aim": return Rect2(size.x - 450, size.y - 210, 140, 140)
		"reload": return Rect2(size.x - 420, size.y - 400, 120, 120)
		"skills": return Rect2(24, 20, 170, 80)
		"swap": return Rect2(size.x - 560, size.y - 360, 110, 110)
	return Rect2()

func _hit_button(p: Vector2) -> String:
	for b in buttons:
		if buttons[b] and _button_rect(b).grow(16).has_point(p):
			return b
	return ""

func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventScreenTouch:
		show_touch = true
		var p: Vector2 = event.position
		if event.pressed:
			var b := _hit_button(p)
			if _pause_rect().has_point(p):
				pause_pressed.emit()
			elif b != "":
				if b == "aim":
					aiming = not aiming
				action.emit(b)
				queue_redraw()
			elif prompt != "" and _use_rect().grow(30).has_point(p):
				_use_id = event.index
				interact_pressed.emit()
			elif p.x < size.x * 0.45 and _stick_id == -1:
				_stick_id = event.index
				_stick_origin = p
				_stick_pos = p
			elif _look_id == -1:
				_look_id = event.index
				_look_last = p
		else:
			if event.index == _stick_id:
				_stick_id = -1
			elif event.index == _look_id:
				_look_id = -1
			elif event.index == _use_id:
				_use_id = -1
		queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == _stick_id:
			_stick_pos = event.position
			queue_redraw()
		elif event.index == _look_id:
			var d: Vector2 = event.position - _look_last
			_look_last = event.position
			_look += d * 0.0045
	elif event is InputEventMouseButton and event.pressed and not show_touch and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look += event.relative * 0.0025
	elif event.is_action_pressed("interact"):
		interact_pressed.emit()
	elif event.is_action_pressed("pause"):
		pause_pressed.emit()
	else:
		for a in ["fire", "reload", "skills", "swap"]:
			if event.is_action_pressed(a):
				action.emit(a)
		if event.is_action_pressed("aim"):
			aiming = true
		elif event.is_action_released("aim") and not show_touch:
			aiming = false
	if event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventKey:
		if show_touch and not (event is InputEventJoypadMotion and absf(event.axis_value) < 0.3):
			show_touch = false
			queue_redraw()

func _process(_d: float) -> void:
	var m := Vector2.ZERO
	if autopilot:
		m = autopilot_move
	elif _stick_id != -1:
		m = (_stick_pos - _stick_origin) / STICK_R
		m = m.limit_length(1.0)
		if m.length() < 0.12:
			m = Vector2.ZERO
	else:
		m = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var ls := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
		if ls.length() > 0.18:
			m = ls.limit_length(1.0)
	move = m

func show_buttons(d: Dictionary) -> void:
	for k in d:
		buttons[k] = d[k]
	if not buttons["aim"]:
		aiming = false
	queue_redraw()

func set_prompt(p: String) -> void:
	prompt = p
	queue_redraw()

func clear_touches() -> void:
	_stick_id = -1
	_look_id = -1
	_use_id = -1
	queue_redraw()

func _draw() -> void:
	if not show_touch:
		return
	var font := ThemeDB.fallback_font
	# stick
	var base := _stick_origin if _stick_id != -1 else Vector2(200, size.y - 200)
	draw_circle(base, STICK_R, Color(1, 1, 1, 0.06))
	draw_arc(base, STICK_R, 0, TAU, 40, Color(1, 1, 1, 0.25), 3.0)
	var knob := base
	if _stick_id != -1:
		knob = base + (_stick_pos - _stick_origin).limit_length(STICK_R)
	draw_circle(knob, 34, Color(1, 1, 1, 0.22))
	# use
	if prompt != "":
		var r := _use_rect()
		var c := r.get_center()
		draw_circle(c, r.size.x * 0.5, Color(0.1, 0.08, 0.06, 0.55))
		draw_arc(c, r.size.x * 0.5, 0, TAU, 48, Color(1, 0.9, 0.75, 0.8), 4.0)
		var fs := 30
		var w := font.get_string_size(prompt.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, c + Vector2(-w * 0.5, fs * 0.35), prompt.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.95, 0.85))
	# the rest
	for b in buttons:
		if not buttons[b]:
			continue
		var r := _button_rect(b)
		var c := r.get_center()
		var on: bool = b == "aim" and aiming
		if b == "skills":
			draw_rect(r, Color(0.1, 0.08, 0.06, 0.55))
			draw_rect(r, Color(1, 0.9, 0.75, 0.6), false, 3.0)
		else:
			draw_circle(c, r.size.x * 0.5, Color(0.45, 0.1, 0.08, 0.5) if on else Color(0.1, 0.08, 0.06, 0.5))
			draw_arc(c, r.size.x * 0.5, 0, TAU, 40, Color(1, 0.9, 0.75, 0.7), 3.0)
		var t: String = labels[b]
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		draw_string(font, c + Vector2(-w * 0.5, 9), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 0.95, 0.85))
	# pause
	var pr := _pause_rect()
	draw_rect(Rect2(pr.position + Vector2(28, 22), Vector2(12, 46)), Color(1, 1, 1, 0.45))
	draw_rect(Rect2(pr.position + Vector2(50, 22), Vector2(12, 46)), Color(1, 1, 1, 0.45))
