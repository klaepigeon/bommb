extends Node
## UI MANAGER (AccessibilityManager): how big things are on this screen. Works out a
## layout profile from the real screen (phone portrait/landscape, tablet, desktop, by the
## physical size where the OS tells us), the safe area (notches, rounded corners, the
## gesture bar), and the player's own settings (UI size, text size, button size, left-
## handed, reduced effects, reduced gore), and hands every screen the numbers: `scale`,
## `text`, `button` (a minimum touch target in pixels), `margins` (the safe insets) and
## `profile`. Not a uniform zoom: screens ask for the profile and rearrange (the HUD
## stacks the player cards on a phone in portrait, puts them in a row in landscape).

signal changed

var profile := "desktop"        # phone_portrait | phone_landscape | tablet | desktop
var scale := 1.0
var text := 1.0
var button := 64.0
var margins := Rect2()          # left, top, right, bottom insets (as position/size)
var reduced_fx := false
var reduced_gore := false
var left_handed := false
var _last_size := Vector2.ZERO


func _ready() -> void:
	ensure_actions()
	apply_power()
	Settings.changed.connect(func(_k = null, _v = null): apply_power())
	Settings.changed.connect(refresh)
	get_viewport().size_changed.connect(refresh)
	refresh()


func refresh() -> void:
	var vp := get_viewport().get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size()) if DisplayServer.get_name() != "headless" else vp
	var dpi := float(DisplayServer.screen_get_dpi()) if DisplayServer.get_name() != "headless" else 96.0
	var inches := win.length() / maxf(72.0, dpi)
	var mobile := OS.has_feature("mobile") or OS.get_name() in ["Android", "iOS"]
	var portrait := vp.y > vp.x
	if mobile:
		if inches >= 7.5:
			profile = "tablet"
		else:
			profile = "phone_portrait" if portrait else "phone_landscape"
	else:
		profile = "phone_portrait" if portrait else "desktop"
	# the game renders at 1280x720 (or 720x1280) and stretches: scale so a finger fits
	var base: float = {"phone_portrait": 1.25, "phone_landscape": 1.15, "tablet": 1.0, "desktop": 0.9}[profile]
	scale = base * float(Settings.get_v("ui_scale", 1.0))
	text = scale * float(Settings.get_v("text_size", 1.0))
	button = 64.0 * scale * float(Settings.get_v("button_size", 1.0))
	reduced_fx = bool(Settings.get_v("reduced_fx", false)) or bool(Settings.get_v("reduced_motion", false))
	reduced_gore = bool(Settings.get_v("reduced_gore", false))
	left_handed = bool(Settings.get_v("left_handed", false))
	margins = _safe(vp, win)
	if vp != _last_size:
		_last_size = vp
	changed.emit()


## The safe area, in viewport pixels.
func _safe(vp: Vector2, win: Vector2) -> Rect2:
	if DisplayServer.get_name() == "headless" or win.x <= 0.0:
		return Rect2(12, 12, 12, 12)
	var safe := DisplayServer.get_display_safe_area()
	var screen := Vector2(DisplayServer.screen_get_size())
	if safe.size == Vector2i.ZERO or screen.x <= 0.0:
		return Rect2(12, 12, 12, 12)
	var k := vp / screen
	var l := float(safe.position.x) * k.x
	var t := float(safe.position.y) * k.y
	var r := (screen.x - float(safe.end.x)) * k.x
	var b := (screen.y - float(safe.end.y)) * k.y
	return Rect2(maxf(12.0, l), maxf(12.0, t), maxf(12.0, r), maxf(12.0, b))


func px(n: float) -> int:
	return int(round(n * text))


func is_phone() -> bool:
	return profile.begins_with("phone")



# --- INPUT BINDINGS --------------------------------------------------------------------------
## The game's real input actions (keyboard and controller), defined once, here. The minigame
## HUD answers to these actions, and the instruction screens read them back to show what to
## press, so what's shown is always what's bound. Touch is the on-screen controls themselves.
##   mg_move     WASD / arrows / left stick          (a game with a stick)
##   mg_tap      Space / pad A        mg_tap2  E / pad X        mg_tap3  R / pad Y
##   mg_hold     Shift / pad RB       mg_hold2 Q / pad LB
##   mg_swipe_*  arrows / d-pad       (a swipe pad)
##   mg_timing   Space / pad A        (a timing ring: the same as mg_tap)
##   board_roll  Space / pad A        board_ok  Enter / pad A

signal device_changed(device: String)

const ACTIONS := {
	"mg_tap": [KEY_SPACE, JOY_BUTTON_A], "mg_tap2": [KEY_E, JOY_BUTTON_X], "mg_tap3": [KEY_R, JOY_BUTTON_Y],
	"mg_hold": [KEY_SHIFT, JOY_BUTTON_RIGHT_SHOULDER], "mg_hold2": [KEY_Q, JOY_BUTTON_LEFT_SHOULDER],
	"mg_swipe_left": [KEY_LEFT, JOY_BUTTON_DPAD_LEFT], "mg_swipe_right": [KEY_RIGHT, JOY_BUTTON_DPAD_RIGHT],
	"mg_swipe_up": [KEY_UP, JOY_BUTTON_DPAD_UP], "mg_swipe_down": [KEY_DOWN, JOY_BUTTON_DPAD_DOWN],
	"mg_timing": [KEY_SPACE, JOY_BUTTON_A], "board_roll": [KEY_SPACE, JOY_BUTTON_A], "board_ok": [KEY_ENTER, JOY_BUTTON_A],
}
const PAD_NAMES := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_DPAD_LEFT: "D-PAD ◀", JOY_BUTTON_DPAD_RIGHT: "D-PAD ▶", JOY_BUTTON_DPAD_UP: "D-PAD ▲",
	JOY_BUTTON_DPAD_DOWN: "D-PAD ▼", JOY_BUTTON_START: "START"}

var device := "touch" if (OS.has_feature("mobile") or OS.get_name() in ["Android", "iOS"]) else "keyboard"


func ensure_actions() -> void:
	for a in ACTIONS.keys():
		if InputMap.has_action(a):
			continue
		InputMap.add_action(a, 0.4)
		var k := InputEventKey.new()
		k.physical_keycode = ACTIONS[a][0]
		InputMap.action_add_event(a, k)
		var j := InputEventJoypadButton.new()
		j.button_index = ACTIONS[a][1]
		InputMap.action_add_event(a, j)
	# WASD as well as the arrows, for the swipes and moving
	for pair in [["mg_swipe_left", KEY_A], ["mg_swipe_right", KEY_D], ["mg_swipe_up", KEY_W], ["mg_swipe_down", KEY_S]]:
		var k2 := InputEventKey.new()
		k2.physical_keycode = pair[1]
		if not InputMap.action_has_event(pair[0], k2):
			InputMap.action_add_event(pair[0], k2)


## The last thing the player touched decides how controls are shown.
func _input(ev: InputEvent) -> void:
	var d := device
	if ev is InputEventScreenTouch or ev is InputEventScreenDrag:
		d = "touch"
	elif ev is InputEventKey or ev is InputEventMouseButton:
		d = "keyboard"
	elif ev is InputEventJoypadButton or (ev is InputEventJoypadMotion and absf(ev.axis_value) > 0.5):
		d = "pad"
	if d != device:
		device = d
		device_changed.emit(d)


## What to press for an action on a device, read back from the InputMap.
func binding(action: String, dev := "") -> String:
	dev = device if dev == "" else dev
	if not InputMap.has_action(action):
		return "?"
	var keys: Array = []
	for ev in InputMap.action_get_events(action):
		if dev == "pad" and ev is InputEventJoypadButton:
			keys.append(PAD_NAMES.get(ev.button_index, "BUTTON %d" % ev.button_index))
		elif dev == "keyboard" and ev is InputEventKey:
			keys.append(OS.get_keycode_string(ev.physical_keycode).to_upper())
	return " / ".join(keys) if not keys.is_empty() else "?"


## How one minigame control is worked on a device: the n-th of its kind (0, 1, 2).
func control_binding(kind: String, n := 0, dev := "") -> String:
	dev = device if dev == "" else dev
	if dev == "touch":
		return {"stick": "the stick (bottom left)", "tap": "its button", "hold": "press and hold its button", "swipe": "swipe across the pad",
			"timing": "tap the ring", "trace": "trace on the pad", "pick": "tap an option", "buttons": "tap a choice"}.get(kind, kind)
	match kind:
		"stick":
			return "WASD / ARROWS" if dev == "keyboard" else "LEFT STICK"
		"tap":
			return binding(["mg_tap", "mg_tap2", "mg_tap3"][mini(n, 2)], dev)
		"hold":
			return "hold " + binding(["mg_hold", "mg_hold2"][mini(n, 1)], dev)
		"swipe":
			return "%s %s %s %s" % [binding("mg_swipe_up", dev), binding("mg_swipe_left", dev), binding("mg_swipe_down", dev), binding("mg_swipe_right", dev)] if dev == "keyboard" else "D-PAD"
		"timing":
			return binding("mg_timing", dev)
		"trace":
			return "the mouse (drag)" if dev == "keyboard" else "the touch screen"
		"pick", "buttons":
			return "click a choice" if dev == "keyboard" else "D-PAD + A"
	return kind



# --- ANDROID QUALITY OF LIFE -----------------------------------------------------------------

signal tip(text: String)

## A buzz in the hand (Settings: VIBRATION). `ms` long; `amp` 0..1 where the phone supports it.
func buzz(ms := 30, amp := 0.5) -> void:
	if not bool(Settings.get_v("vibration", true)):
		return
	if OS.has_feature("mobile") or OS.get_name() in ["Android", "iOS"]:
		Input.vibrate_handheld(ms, amp)
	for j in Input.get_connected_joypads():
		Input.start_joy_vibration(j, amp * 0.6, amp, ms / 1000.0)


## The screen stays on during a match (nobody wants it dimming mid-minigame).
func keep_awake(on: bool) -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.screen_set_keep_on(on)


## BATTERY SAVER: 30 frames a second and a lighter picture.
func apply_power() -> void:
	var saver := bool(Settings.get_v("battery_saver", false))
	Engine.max_fps = 30 if saver else 60


## A long-press on something with a description: say what it is.
func show_tip(text: String) -> void:
	tip.emit(text)
	buzz(15, 0.3)
