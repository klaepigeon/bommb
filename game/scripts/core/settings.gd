extends Node
## Player settings (saved to user://settings.cfg) and the input map, defined in code so it can't drift.

signal changed

const PATH := "user://settings.cfg"

var voices := true          ## speak lines with the device's text-to-speech
var look_sensitivity := 1.0
var subtitle_scale := 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	_bind("move_forward", [KEY_W, KEY_UP])
	_bind("move_back", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("interact", [KEY_E, KEY_SPACE], [JOY_BUTTON_A])
	_bind("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START, JOY_BUTTON_B])

func _bind(action: String, keys: Array, buttons: Array = []) -> void:
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

func is_touch() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")

func save() -> void:
	var c := ConfigFile.new()
	c.set_value("game", "voices", voices)
	c.set_value("game", "look_sensitivity", look_sensitivity)
	c.set_value("game", "subtitle_scale", subtitle_scale)
	c.save(PATH)
	changed.emit()

func _load() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return
	voices = c.get_value("game", "voices", voices)
	look_sensitivity = c.get_value("game", "look_sensitivity", look_sensitivity)
	subtitle_scale = c.get_value("game", "subtitle_scale", subtitle_scale)
