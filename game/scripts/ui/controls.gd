extends Node
## Every way of playing, turned into one set of intents the game reads: keyboard and mouse, a
## gamepad, and touch (a stick wherever the left thumb lands, drag-to-look on the right, and
## buttons that only show when they mean something). Buttons are labelled with what they'll do
## (the USE button says "Open", "Take", "Push"...), so nothing essential depends on Socko.

signal pressed(action: String)

var move := Vector2.ZERO           ## -1..1, y forward
var look := Vector2.ZERO           ## radians this frame
var held := {}                     ## action -> true while down
var touch_mode := false
var enabled := true                ## off during cutscene beats (look still works)
var labels := {"use": "", "alt": ""}
var show := {"fire": false, "reload": false, "jump": true, "crouch": true, "alt": false, "use": false, "bag": false, "socko": false, "aim": false, "torch": false, "skills": false}

const ACTIONS := {
	"forward": [KEY_W, KEY_UP], "back": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
	"use": [KEY_E, KEY_SPACE], "alt": [KEY_Q], "jump": [KEY_SPACE], "crouch": [KEY_C, KEY_CTRL], "run": [KEY_SHIFT],
	"fire": [], "aim": [], "reload": [KEY_R], "bag": [KEY_TAB, KEY_I], "socko": [KEY_T], "pause": [KEY_ESCAPE], "skills": [KEY_K],
	"torch": [KEY_F],
}
const PAD := {"use": JOY_BUTTON_A, "alt": JOY_BUTTON_X, "jump": JOY_BUTTON_B, "crouch": JOY_BUTTON_RIGHT_STICK,
	"run": JOY_BUTTON_LEFT_STICK, "reload": JOY_BUTTON_Y, "bag": JOY_BUTTON_BACK, "socko": JOY_BUTTON_DPAD_UP,
	"pause": JOY_BUTTON_START, "torch": JOY_BUTTON_DPAD_DOWN, "skills": JOY_BUTTON_DPAD_LEFT}

var _layer: CanvasLayer
var _root: Control
var _buttons := {}                 ## action -> Button-like Control
var _stick_base: Control
var _stick_knob: Control
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _look_id := -1
var _look_last := Vector2.ZERO
var _btn_touch := {}               ## touch index -> action
var _look_acc := Vector2.ZERO
var _mouse_captured := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in ACTIONS:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.2)
		for k in ACTIONS[a]:
			var e := InputEventKey.new(); e.physical_keycode = k
			InputMap.action_add_event(a, e)
		if PAD.has(a):
			var j := InputEventJoypadButton.new(); j.button_index = PAD[a]
			InputMap.action_add_event(a, j)
	var fire := InputEventMouseButton.new(); fire.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("fire", fire)
	var aim := InputEventMouseButton.new(); aim.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("aim", aim)
	var rt := InputEventJoypadMotion.new(); rt.axis = JOY_AXIS_TRIGGER_RIGHT; rt.axis_value = 1.0
	InputMap.action_add_event("fire", rt)
	var lt := InputEventJoypadMotion.new(); lt.axis = JOY_AXIS_TRIGGER_LEFT; lt.axis_value = 1.0
	InputMap.action_add_event("aim", lt)
	touch_mode = Settings.is_touch()
	_build_touch()
	Settings.changed.connect(_layout)

func _build_touch() -> void:
	_layer = CanvasLayer.new(); _layer.layer = 40
	add_child(_layer)
	_root = Control.new(); _root.name = "Touch"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_root)
	_stick_base = _circle(Color(1, 1, 1, 0.10), Color(1, 1, 1, 0.35), 1.0)
	_stick_knob = _circle(Color(1, 1, 1, 0.30), Color(1, 1, 1, 0.6), 0.42)
	_root.add_child(_stick_base); _root.add_child(_stick_knob)
	_stick_base.visible = false; _stick_knob.visible = false
	for a in ["use", "alt", "jump", "crouch", "fire", "aim", "reload", "bag", "socko", "pause", "skills", "torch"]:
		var b := _button(a)
		_buttons[a] = b
		_root.add_child(b)
	_layer.visible = touch_mode
	get_viewport().size_changed.connect(_layout)
	_layout()

class Disc extends Control:
	var fill := Color.WHITE
	var line := Color.WHITE
	var text := ""
	var font_size := 16
	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5
		draw_circle(size * 0.5, r, fill)
		draw_arc(size * 0.5, r - 1.0, 0, TAU, 40, line, 2.0, true)
		if text != "":
			var f := get_theme_default_font()
			var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
			draw_string(f, Vector2((size.x - w) * 0.5, size.y * 0.5 + font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.92))

func _circle(fill: Color, line: Color, _k: float) -> Control:
	var d := Disc.new(); d.fill = fill; d.line = line
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d

const NAMES := {"use": "USE", "alt": "", "jump": "JUMP", "crouch": "CROUCH", "fire": "FIRE", "aim": "AIM", "reload": "LOAD", "bag": "POCKETS", "socko": "SOCKO", "pause": "II", "skills": "GROW", "torch": "LIGHT"}

func _button(a: String) -> Control:
	var d := Disc.new()
	d.fill = Color(0.05, 0.05, 0.06, 0.38); d.line = Color(1, 1, 1, 0.45)
	d.text = NAMES.get(a, a)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.set_meta("action", a)
	return d

## Where the buttons go: a thumb's arc on the right (or left, for left-handed play), in the safe area.
func _layout() -> void:
	if _root == null: return
	var vp := get_viewport().get_visible_rect().size
	var u := clampf(vp.y / 10.0, 46.0, 140.0)        # one button unit
	var right := String(Settings.get_v("socko_side")) != "right"
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var win := Vector2(DisplayServer.window_get_size())
	var kx := vp.x / maxf(win.x, 1.0)
	var inset := 0.0
	if safe.size.x > 0:
		inset = maxf(safe.position.x, win.x - safe.end.x) * kx
	var edge := vp.x - inset - u * 0.4 if right else inset + u * 0.4
	var s := -1.0 if right else 1.0
	var spots := {
		"use": Vector2(edge + s * u * 1.25, vp.y - u * 1.6), "alt": Vector2(edge + s * u * 2.75, vp.y - u * 2.7),
		"jump": Vector2(edge + s * u * 0.7, vp.y - u * 3.2), "crouch": Vector2(edge + s * u * 2.7, vp.y - u * 0.85),
		"fire": Vector2(edge + s * u * 1.25, vp.y - u * 4.4), "aim": Vector2(edge + s * u * 2.7, vp.y - u * 4.0),
		"reload": Vector2(edge + s * u * 3.9, vp.y - u * 4.6),
		"socko": Vector2(inset + u * 0.9 if right else vp.x - inset - u * 0.9, u * 2.2),
		"bag": Vector2(inset + u * 0.9 if right else vp.x - inset - u * 0.9, u * 3.6),
		"skills": Vector2(inset + u * 0.9 if right else vp.x - inset - u * 0.9, u * 5.0),
		"pause": Vector2(vp.x - inset - u * 0.6 if right else inset + u * 0.6, u * 0.7),
		"torch": Vector2(edge + s * u * 3.9, vp.y - u * 1.6),
	}
	var sizes := {"use": 1.7, "alt": 1.15, "fire": 1.5, "pause": 0.8}
	for a in _buttons:
		var b: Disc = _buttons[a]
		var d: float = u * float(sizes.get(a, 1.05))
		b.size = Vector2(d, d)
		b.position = (spots[a] as Vector2) - b.size * 0.5
		b.font_size = int(u * (0.24 if a != "use" else 0.26))
		b.modulate.a = float(Settings.get_v("hud_opacity"))
		b.queue_redraw()
	_stick_base.size = Vector2(u * 2.2, u * 2.2)
	_stick_knob.size = Vector2(u * 0.95, u * 0.95)

func _visible_action(a: String) -> bool:
	if a in ["pause", "jump", "crouch"]: return true
	if a == "use": return show.use
	return bool(show.get(a, false))

func _process(_delta: float) -> void:
	# keyboard / pad movement (touch writes `move` itself)
	if _stick_id < 0:
		var k := Vector2(Input.get_action_strength("right") - Input.get_action_strength("left"), Input.get_action_strength("forward") - Input.get_action_strength("back"))
		var j := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), -Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
		if j.length() < 0.18: j = Vector2.ZERO
		move = (k + j).limit_length(1.0)
	var r := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if r.length() > 0.15:
		_look_acc += r * r.length() * 2.6 * get_process_delta_time()
	if touch_mode and _layer:
		_layer.visible = true
		var paused := get_tree().paused
		for a in _buttons:
			var b: Disc = _buttons[a]
			b.visible = _visible_action(a) and (not paused or a == "pause")
			var t := String(labels.get(a, "")) if a in ["use", "alt"] else String(NAMES.get(a, a))
			if a == "use" and t == "": t = "USE"
			if b.text != t: b.text = t; b.queue_redraw()
			var down := held.has(a)
			b.fill = Color(0.6, 0.55, 0.45, 0.45) if down else Color(0.05, 0.05, 0.06, 0.38)
			b.queue_redraw()

## The look input since the last physics step, used up (a 120 Hz screen gives two frames of input
## per 60 Hz step: none of it may be dropped).
func take_look() -> Vector2:
	var l := _look_acc * float(Settings.get_v("look_sensitivity"))
	if bool(Settings.get_v("invert_y")): l.y = -l.y
	_look_acc = Vector2.ZERO
	look = l
	return l

func is_down(a: String) -> bool:
	return held.has(a) or (not touch_mode and InputMap.has_action(a) and Input.is_action_pressed(a))

func _fire(a: String) -> void:
	if a == "pause" or enabled:
		pressed.emit(a)

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch or e is InputEventScreenDrag:
		if not touch_mode:
			touch_mode = true
			_layer.visible = true
		_touch(e)
		get_viewport().set_input_as_handled()
		return
	if e is InputEventMouseMotion and _mouse_captured:
		_look_acc += e.relative * 0.0025
	elif e is InputEventMouseButton and e.pressed and not touch_mode and not get_tree().paused:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_mouse_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	for a in ACTIONS:
		if e.is_action_pressed(a, false, true):
			if a == "pause" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_mouse_captured = false
			if touch_mode and not (e is InputEventScreenTouch):
				touch_mode = e is InputEventScreenTouch
				_layer.visible = false
			_fire(a)

func capture_mouse(on: bool) -> void:
	if DisplayServer.get_name() == "headless" or touch_mode: return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE
	_mouse_captured = on

func _hit_button(p: Vector2) -> String:
	for a in _buttons:
		var b: Disc = _buttons[a]
		if b.visible and b.get_global_rect().grow(b.size.x * 0.12).has_point(p):
			return a
	return ""

func _touch(e: InputEvent) -> void:
	var vp := get_viewport().get_visible_rect().size
	var right_handed := String(Settings.get_v("socko_side")) != "right"
	if e is InputEventScreenTouch:
		if e.pressed:
			var a := _hit_button(e.position)
			if a != "":
				_btn_touch[e.index] = a
				held[a] = true
				_fire(a)
				return
			var on_stick_side: bool = (e.position.x < vp.x * 0.45) if right_handed else (e.position.x > vp.x * 0.55)
			if on_stick_side and _stick_id < 0:
				_stick_id = e.index
				_stick_origin = e.position
				_stick_base.position = e.position - _stick_base.size * 0.5
				_stick_knob.position = e.position - _stick_knob.size * 0.5
				_stick_base.visible = true; _stick_knob.visible = true
			elif _look_id < 0:
				_look_id = e.index
				_look_last = e.position
		else:
			if _btn_touch.has(e.index):
				held.erase(_btn_touch[e.index])
				_btn_touch.erase(e.index)
			if e.index == _stick_id:
				_stick_id = -1; move = Vector2.ZERO
				held.erase("run")
				_stick_base.visible = false; _stick_knob.visible = false
			if e.index == _look_id:
				_look_id = -1
	elif e is InputEventScreenDrag:
		if e.index == _stick_id:
			var r := _stick_base.size.x * 0.5
			var d: Vector2 = e.position - _stick_origin
			if d.length() > r * 1.6:     # the stick follows a thumb that wanders off it
				_stick_origin = e.position - d.normalized() * r * 1.6
				_stick_base.position = _stick_origin - _stick_base.size * 0.5
			var v := d / r
			move = Vector2(v.x, -v.y).limit_length(1.0)
			if v.length() > 1.25: held["run"] = true
			else: held.erase("run")
			_stick_knob.position = _stick_origin + d.limit_length(r) - _stick_knob.size * 0.5
		elif e.index == _look_id:
			var d: Vector2 = e.position - _look_last
			_look_last = e.position
			_look_acc += d * (2.6 / maxf(vp.y, 1.0))
