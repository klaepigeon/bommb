extends Node
## Player settings (user://settings.cfg) and the input map, defined in code so it can't drift.
## Gameplay scripts read actions, never keys.

signal changed

const PATH := "user://settings.cfg"

var look_sensitivity := 1.0
## Height in pixels of the 3D image before it is scaled up (the PS1 look, and the main
## performance lever on phones). 240 = PS1, 360 = default, 480 = sharper.
var render_height := 360
var dither := true
## NPCs farther than this from every player stop running navigation/animation (tiered sim).
var npc_active_distance := 35.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	_bind("move_forward", [KEY_W, KEY_UP])
	_bind("move_back", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("sprint", [KEY_SHIFT], [JOY_BUTTON_LEFT_STICK])
	_bind("interact", [KEY_E, KEY_F], [JOY_BUTTON_A])
	_bind("attack", [KEY_X], [], [JOY_AXIS_TRIGGER_RIGHT], [MOUSE_BUTTON_LEFT])
	_bind("secondary", [KEY_Q], [], [JOY_AXIS_TRIGGER_LEFT], [MOUSE_BUTTON_RIGHT])
	_bind("inventory", [KEY_TAB, KEY_I], [JOY_BUTTON_Y])
	_bind("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	_bind("wait", [KEY_T], [JOY_BUTTON_BACK])
	_bind("more", [KEY_R], [JOY_BUTTON_RIGHT_SHOULDER])

func _bind(action: String, keys: Array, buttons: Array = [], axes: Array = [], mouse: Array = []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var j := InputEventJoypadButton.new()
		j.button_index = b
		InputMap.action_add_event(action, j)
	for a in axes:
		var m := InputEventJoypadMotion.new()
		m.axis = a
		m.axis_value = 1.0
		InputMap.action_add_event(action, m)
	for b in mouse:
		var mb := InputEventMouseButton.new()
		mb.button_index = b
		InputMap.action_add_event(action, mb)

func is_touch() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")

func save() -> void:
	var c := ConfigFile.new()
	c.set_value("game", "look_sensitivity", look_sensitivity)
	c.set_value("video", "render_height", render_height)
	c.set_value("video", "dither", dither)
	c.set_value("sim", "npc_active_distance", npc_active_distance)
	c.save(PATH)
	changed.emit()

func _load() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return
	look_sensitivity = c.get_value("game", "look_sensitivity", look_sensitivity)
	render_height = c.get_value("video", "render_height", render_height)
	dither = c.get_value("video", "dither", dither)
	npc_active_distance = c.get_value("sim", "npc_active_distance", npc_active_distance)
