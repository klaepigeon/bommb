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
	_bind("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	_bind("back", [], [JOY_BUTTON_B])
	_bind("fire", [KEY_F], [], [JOY_AXIS_TRIGGER_RIGHT], [MOUSE_BUTTON_LEFT])
	_bind("aim", [KEY_Q], [], [JOY_AXIS_TRIGGER_LEFT], [MOUSE_BUTTON_RIGHT])
	_bind("reload", [KEY_R], [JOY_BUTTON_X])
	_bind("skills", [KEY_TAB, KEY_K], [JOY_BUTTON_BACK, JOY_BUTTON_Y])
	_bind("swap", [KEY_V, KEY_1, KEY_2], [JOY_BUTTON_RIGHT_SHOULDER])

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
	c.set_value("game", "voices", voices)
	c.set_value("game", "look_sensitivity", look_sensitivity)
	c.set_value("game", "subtitle_scale", subtitle_scale)
	c.save(PATH)
	changed.emit()

func _load() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) == OK:
		voices = c.get_value("game", "voices", voices)
		look_sensitivity = c.get_value("game", "look_sensitivity", look_sensitivity)
		subtitle_scale = c.get_value("game", "subtitle_scale", subtitle_scale)
	# if the last run died starting a voice line, the voices go off (subtitles stay) until turned
	# back on in the pause menu: the same crash can't happen twice in a row
	if voices and Trail.died_in_voice():
		voices = false
		save()
		Trail.precaution = "It closed while starting a spoken line, so voices are now off (subtitles only). They can go back on in the pause menu."
		Trail.mark("voices off: the last run died in the voice")
