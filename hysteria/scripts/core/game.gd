extends Node
## Global state for HYSTERIA: input actions, narrative flags, and small services the rest of
## the game shares (toasts, the current interact prompt). Autoloaded as `Game`.

signal toast(text: String, seconds: float)
signal prompt(text: String)
signal fade(to: float, seconds: float)    # 0 clear .. 1 black

var flags := {}

func _ready() -> void:
	_bind_inputs()

## Input actions are declared here rather than in project.godot so they're readable and diffable.
func _bind_inputs() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT], "crouch": [KEY_C, KEY_CTRL], "interact": [KEY_E],
		"torch": [KEY_F], "pause": [KEY_ESCAPE],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	var mouse := {"throw": MOUSE_BUTTON_LEFT, "inspect": MOUSE_BUTTON_RIGHT}
	for action in mouse:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var mb := InputEventMouseButton.new()
		mb.button_index = mouse[action]
		InputMap.action_add_event(action, mb)
	# triggers: right throws, left turns the held thing over
	for pair in [["throw", JOY_AXIS_TRIGGER_RIGHT], ["inspect", JOY_AXIS_TRIGGER_LEFT]]:
		var jm := InputEventJoypadMotion.new(); jm.axis = pair[1]; jm.axis_value = 1.0
		InputMap.action_add_event(pair[0], jm)
	var pad := {"interact": JOY_BUTTON_A, "torch": JOY_BUTTON_X, "crouch": JOY_BUTTON_Y, "sprint": JOY_BUTTON_LEFT_STICK, "pause": JOY_BUTTON_START, "throw": JOY_BUTTON_RIGHT_SHOULDER}
	for action in pad:
		var jb := InputEventJoypadButton.new()
		jb.button_index = pad[action]
		InputMap.action_add_event(action, jb)

func say(text: String, seconds := 4.0) -> void:
	toast.emit(text, seconds)

## A spoken line: subtitled, and voiced by the system's text-to-speech where there is one.
func speak(text: String, seconds := 4.0, pitch := 0.85, rate := 0.8) -> void:
	toast.emit(text, seconds)
	var v := _voice()
	if v != "":
		DisplayServer.tts_stop()
		DisplayServer.tts_speak(text.replace("“", "").replace("”", ""), v, 70, pitch, rate)

var _voice_id = null
## The first English system voice, looked up once ("" if there's no speech synthesiser).
func _voice() -> String:
	if _voice_id == null:
		_voice_id = ""
		if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH) and not (OS.has_feature("linuxbsd") and OS.get_environment("SPEECHD_ADDRESS") == "" and not FileAccess.file_exists("/usr/bin/speech-dispatcher")):
			var voices := DisplayServer.tts_get_voices_for_language("en")
			if voices.size() > 0:
				_voice_id = voices[0]
	return _voice_id
