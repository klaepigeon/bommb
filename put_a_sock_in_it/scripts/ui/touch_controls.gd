class_name TouchControls
extends Control
## The phone controls, drawn and handled here so several fingers work at once: a floating stick
## on the left half (put your thumb down anywhere there), drag anywhere on the right half to look,
## and buttons that press the same input actions the keyboard does. Buttons can be resized,
## faded and dragged somewhere else (Pause > Controls > Move buttons); the layout is saved.

const DEFAULT := {
	# name: [action, x (0..1 of width), y (0..1 of height), radius px, label]
	"use": ["interact", 0.88, 0.62, 58.0, "USE"],
	"fire": ["fire", 0.76, 0.78, 54.0, "FIRE"],
	"reload": ["reload", 0.93, 0.42, 38.0, "RLD"],
	"crouch": ["crouch", 0.93, 0.85, 40.0, "DUCK"],
	"run": ["sprint", 0.07, 0.42, 40.0, "RUN"],
	"look_at": ["inspect", 0.8, 0.45, 36.0, "TURN"],
	"skip": ["skip", 0.5, 0.94, 30.0, "»"],
	"pause": ["pause", 0.96, 0.07, 30.0, "II"],
}

var player: Player
var editing := false
var layout := {}
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_id := -1
var _look_last := Vector2.ZERO
var _pressed := {}            # touch index -> button name
var _drag_btn := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout = DEFAULT.duplicate(true)
	var saved = Game.settings.get("touch_layout", {})
	if typeof(saved) == TYPE_DICTIONARY:
		for k in saved:
			if layout.has(k): layout[k][1] = float(saved[k][0]); layout[k][2] = float(saved[k][1])

func _visible_btn(name: String) -> bool:
	match name:
		"fire", "reload": return Game.pistol.have
		"look_at": return player != null and player.held != null
		"skip": return Dialogue.busy
	return true

func _btn_at(p: Vector2) -> String:
	var s: float = Game.settings.touch_scale
	for k in layout:
		if not _visible_btn(k) and not editing: continue
		var c := Vector2(layout[k][1], layout[k][2]) * size
		if p.distance_to(c) <= layout[k][3] * s * 1.15: return k
	return ""

func _input(e: InputEvent) -> void:
	if not visible: return
	if e is InputEventScreenTouch:
		if e.pressed:
			var b := _btn_at(e.position)
			if editing:
				if b == "pause":
					editing = false; _save_layout(); return
				_drag_btn = b; return
			if b != "":
				_pressed[e.index] = b
				_press(b, true)
			elif e.position.x < size.x * 0.45 and _stick_id < 0:
				_stick_id = e.index; _stick_origin = e.position; _stick_pos = e.position
			elif _look_id < 0:
				_look_id = e.index; _look_last = e.position
		else:
			if editing:
				_drag_btn = ""; _save_layout(); return
			if _pressed.has(e.index):
				_press(_pressed[e.index], false); _pressed.erase(e.index)
			if e.index == _stick_id:
				_stick_id = -1; _set_move(Vector2.ZERO)
			if e.index == _look_id: _look_id = -1
		get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag:
		if editing and _drag_btn != "":
			layout[_drag_btn][1] = clampf(e.position.x / size.x, 0.03, 0.97)
			layout[_drag_btn][2] = clampf(e.position.y / size.y, 0.05, 0.95)
			queue_redraw(); return
		if e.index == _stick_id:
			_stick_pos = e.position
			var r: float = 70.0 * Game.settings.touch_scale
			var v: Vector2 = (_stick_pos - _stick_origin) / r
			if v.length() > 1.0:
				_stick_origin = _stick_pos - v.normalized() * r   # the stick follows a thumb that strays
				v = v.normalized()
			_set_move(v)
		elif e.index == _look_id:
			var d: Vector2 = e.position - _look_last; _look_last = e.position
			var s: float = 0.0045 * float(Game.settings.sensitivity)
			if player: player.add_look(Vector2(-d.x * s, -d.y * s * (-1.0 if Game.settings.invert_y else 1.0)))
		get_viewport().set_input_as_handled()

func _press(b: String, down: bool) -> void:
	var action: String = layout[b][0]
	var ev := InputEventAction.new(); ev.action = action; ev.pressed = down; ev.strength = 1.0 if down else 0.0
	Input.parse_input_event(ev)
	if down and action == "skip": Dialogue.skip_line()

func _set_move(v: Vector2) -> void:
	for pair in [["move_left", -v.x], ["move_right", v.x], ["move_forward", -v.y], ["move_back", v.y]]:
		if pair[1] > 0.05: Input.action_press(pair[0], pair[1])
		else: Input.action_release(pair[0])

func _save_layout() -> void:
	var d := {}
	for k in layout: d[k] = [layout[k][1], layout[k][2]]
	Game.settings.touch_layout = d
	Game.save_settings()

func reset_layout() -> void:
	layout = DEFAULT.duplicate(true); _save_layout(); queue_redraw()

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	var a: float = Game.settings.touch_opacity
	var s: float = Game.settings.touch_scale
	if _stick_id >= 0:
		draw_circle(_stick_origin, 70.0 * s, Color(1, 1, 1, a * 0.15))
		draw_circle(_stick_pos, 30.0 * s, Color(1, 1, 1, a * 0.4))
	var font := ThemeDB.fallback_font
	for k in layout:
		if not _visible_btn(k) and not editing: continue
		var c := Vector2(layout[k][1], layout[k][2]) * size
		var r: float = layout[k][3] * s
		var down: bool = _pressed.values().has(k) or _drag_btn == k
		draw_circle(c, r, Color(0, 0, 0, a * (0.55 if down else 0.3)))
		draw_arc(c, r, 0, TAU, 32, Color(1, 1, 1, a * (0.9 if editing else 0.6)), 2.0)
		var fs := int(18 * s)
		var tw := font.get_string_size(layout[k][4], HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(font, c + Vector2(-tw * 0.5, fs * 0.35), layout[k][4], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, a))
	if editing:
		draw_string(font, Vector2(size.x * 0.5 - 220, 60), "Drag buttons to move them. Tap PAUSE when done.", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
