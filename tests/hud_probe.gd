extends Node
## HUD controls, by touch, in a real match: the menu (≡) and everything in it, LOOK UP,
## leaving. Each one reports PASS/FAIL. Run at a phone size:
## xvfb-run -a -s "-screen 0 1600x720x24" godot --rendering-driver opengl3 --resolution 1600x720 res://tests/hud_probe.tscn
var fails := 0


func _ready() -> void:
	var main: Node = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _wait(30)
	Seats.reset("single")
	Seats.set_seat(0, {"kind": "local", "name": "YOU", "device": "primary"})
	Net.start_offline()
	Net.launch()
	while Net.core == null or Net.core.phase != "turn":
		Net.send_action(0, {"t": "ready"})
		await _wait(10)
	await _wait(30)
	var hud: Hud = get_tree().root.find_children("*", "Hud", true, false)[0]
	var gv = get_tree().root.find_children("*", "GameView", true, false)[0]
	# the menu
	var mb := _btn("≡")
	var hits := [0]
	mb.pressed.connect(func(): hits[0] += 1)
	await _tap(mb)
	print("  (≡ pressed %d times; menu_open=%s, modal.visible=%s)" % [hits[0], hud._menu_open, hud.modal.visible])
	var lb := _btn("LOOK UP")
	var lh := [0]
	lb.pressed.connect(func(): lh[0] += 1)
	await _wait(60)
	print("  (after 1s: menu_open=%s, modal.visible=%s)" % [hud._menu_open, hud.modal.visible])
	_check(hud.modal.visible and _btn("BACK TO THE PARTY") != null, "≡ opens the menu, and it stays open for a second")
	var before := float(Settings.get_v("ui_scale", 1.0))
	await _tap(_btn("UI BIGGER"))
	await _wait(20)
	_check(float(Settings.get_v("ui_scale", 1.0)) > before, "UI BIGGER makes the UI bigger")
	_check(hud.modal.visible, "...and the menu is still open")
	await _tap(_btn("UI SMALLER"))
	await _wait(20)
	var fx := bool(Settings.get_v("reduced_fx", false))
	await _tap(_btn("REDUCED EFFECTS"))
	await _wait(20)
	_check(bool(Settings.get_v("reduced_fx", false)) != fx, "REDUCED EFFECTS toggles")
	await _tap(_btn("REDUCED EFFECTS"))
	await _wait(20)
	var ts := float(Settings.get_v("text_size", 1.0))
	await _tap(_btn("TEXT BIGGER"))
	await _wait(20)
	_check(float(Settings.get_v("text_size", 1.0)) > ts, "TEXT BIGGER")
	await _tap(_btn("TEXT SMALLER"))
	await _wait(20)
	var bb := _btn("BACK TO THE PARTY")
	var bh := [0]
	if bb:
		bb.pressed.connect(func(): bh[0] += 1)
		print("  (BACK at %s, top there: %s)" % [bb.get_global_rect(), "?"])
	await _tap(bb)
	await _wait(20)
	print("  (BACK pressed %d; menu_open=%s; still a BACK button: %s)" % [bh[0], hud._menu_open, _btn("BACK TO THE PARTY") != null])
	_check(not hud.modal.visible or _btn("BACK TO THE PARTY") == null, "BACK TO THE PARTY closes it")
	# look up
	var lm: String = gv.look_mode
	await _tap(_btn("LOOK UP"))
	await _wait(20)
	print("  (LOOK UP pressed %d)" % lh[0])
	_check(gv.look_mode != lm, "LOOK UP changes the view (%s -> %s)" % [lm, gv.look_mode])
	# the Android back button: opens the menu
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _wait(20)
	_check(_btn("PAUSED") != null or hud.modal.visible, "Android's back button opens the menu")
	var t0 := float(Net.core.phase_t)
	await _wait(60)
	_check(absf(float(Net.core.phase_t) - t0) < 0.001, "the offline match is paused while it's open")
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _wait(20)
	_check(not hud.modal.visible and not Net.paused, "back again closes it and play resumes")
	await _tap(_btn("≡"))
	await _wait(20)
	# leave
	if _btn("BACK TO THE PARTY") == null:
		await _tap(_btn("≡"))
		await _wait(20)
	await _tap(_btn("LEAVE THE MATCH"))
	await _wait(60)
	_check(get_tree().root.find_children("*", "GameView", true, false).is_empty(), "LEAVE THE MATCH leaves")
	print("HUD PROBE: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _btn(prefix: String) -> Button:
	for b in get_tree().root.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and (b as Button).text.begins_with(prefix):
			return b
	return null


func _tap(b: Button) -> void:
	if b == null:
		print("  (no such button)")
		return
	var p: Vector2 = get_viewport().get_final_transform() * b.get_global_rect().get_center()
	for down in [true, false]:
		var t := InputEventScreenTouch.new()
		t.position = p
		t.pressed = down
		Input.parse_input_event(t)
		await _wait(3)
