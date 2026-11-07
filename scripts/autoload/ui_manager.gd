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
