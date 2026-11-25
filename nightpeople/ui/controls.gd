class_name Controls
extends Control
## All input, touch first. Left half: a floating stick under the thumb. Right half: drag to
## look. Buttons appear for what can be done now: USE (the focused thing's main verb), a second
## verb when there is one, BAG, WAIT, and pause. Keyboard + mouse and gamepads go through the
## InputMap (core/settings.gd). The player reads `move`, `sprinting()` and `consume_look()`.

signal use_pressed(index: int)
signal button(name: String)       ## "bag", "wait", "pause"

const STICK_R := 90.0

var move := Vector2.ZERO
var show_touch := false
var verbs: Array[String] = []     ## set by the HUD from the player's focus

var _look := Vector2.ZERO
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_id := -1
var _look_last := Vector2.ZERO
var _font: Font

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_touch = Settings.is_touch()
	_font = ThemeDB.fallback_font

func sprinting() -> bool:
	return Input.is_action_pressed("sprint")

func consume_look() -> Vector2:
	var l := _look
	_look = Vector2.ZERO
	var rs := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if rs.length() > 0.15:
		l += rs * rs.length() * 180.0 * get_physics_process_delta_time()
	return l

func _rects() -> Dictionary:
	var s := size
	var r := {"pause": Rect2(s.x - 100, 16, 84, 84), "bag": Rect2(s.x - 200, 16, 84, 84),
		"wait": Rect2(s.x - 300, 16, 84, 84)}
	if verbs.size() > 0:
		r["use0"] = Rect2(s.x - 230, s.y - 230, 180, 180)
	if verbs.size() > 1:
		r["use1"] = Rect2(s.x - 400, s.y - 170, 140, 140)
	return r

func _hit(p: Vector2) -> String:
	var r := _rects()
	for k in r:
		if (r[k] as Rect2).grow(12).has_point(p):
			return k
	return ""

func _press(k: String) -> void:
	match k:
		"use0": use_pressed.emit(0)
		"use1": use_pressed.emit(1)
		_: button.emit(k)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		show_touch = true
		var p: Vector2 = event.position
		if event.pressed:
			var k := _hit(p)
			if k != "":
				_press(k)
			elif p.x < size.x * 0.45 and _stick_id < 0:
				_stick_id = event.index
				_stick_origin = p
				_stick_pos = p
			elif _look_id < 0:
				_look_id = event.index
				_look_last = p
		else:
			if event.index == _stick_id:
				_stick_id = -1
				move = Vector2.ZERO
			elif event.index == _look_id:
				_look_id = -1
		queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == _stick_id:
			_stick_pos = event.position
			var v: Vector2 = (_stick_pos - _stick_origin) / STICK_R
			move = v.limit_length(1.0)
			queue_redraw()
		elif event.index == _look_id:
			_look += (event.position - _look_last) * 0.25
			_look_last = event.position
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look += event.relative * 0.15
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not show_touch:
		if not get_tree().paused:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("interact"):
		use_pressed.emit(0)
	elif event.is_action_pressed("secondary"):
		use_pressed.emit(1)
	elif event.is_action_pressed("inventory"):
		button.emit("bag")
	elif event.is_action_pressed("wait"):
		button.emit("wait")
	elif event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		button.emit("pause")

func _process(_delta: float) -> void:
	if _stick_id < 0:
		var k := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var j := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
		move = k if k.length() > 0.0 else (j if j.length() > 0.2 else Vector2.ZERO)
		if k.length() > 0.0 and not sprinting():
			move = move.limit_length(0.9)    # keyboard walks; Shift runs
	queue_redraw()

func _draw() -> void:
	if not show_touch:
		return
	var white := Color(1, 1, 1, 0.5)
	if _stick_id >= 0:
		draw_arc(_stick_origin, STICK_R, 0, TAU, 32, white, 3.0)
		draw_circle(_stick_origin + move * STICK_R, 34, Color(1, 1, 1, 0.35))
	var r := _rects()
	for k in r:
		var rect: Rect2 = r[k]
		var label: String = {"pause": "II", "bag": "BAG", "wait": "WAIT"}.get(k, "")
		if k == "use0":
			label = verbs[0].to_upper()
		elif k == "use1":
			label = verbs[1].to_upper()
		draw_circle(rect.get_center(), rect.size.x * 0.5, Color(0, 0, 0, 0.35))
		draw_arc(rect.get_center(), rect.size.x * 0.5, 0, TAU, 40, white, 3.0)
		var fs := 22 if label.length() < 7 else 16
		var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(_font, rect.get_center() + Vector2(-w * 0.5, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
