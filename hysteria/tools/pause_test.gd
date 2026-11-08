extends SceneTree
## The pause menu: Esc / Start, Android's back button, the touch ‖ button; it stops the game and
## comes back; settings apply. Saves a frame of the menu.
## xvfb-run godot --rendering-driver opengl3 --path hysteria -s tools/pause_test.gd -- out=<dir>

var out := "user://pause"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame; await process_frame
	var pm = main.pause_menu
	var p = main.player
	var ok := true
	var ev := InputEventAction.new(); ev.action = "pause"; ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame; await process_frame
	ok = _check(paused and pm.panel.visible, "Esc / Start pauses") and ok
	var y0: Vector3 = p.global_position
	for i in 10: await physics_frame
	ok = _check(p.global_position == y0, "nothing moves while paused") and ok
	pm.pause_btn.visible = true
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(out.path_join("pause_menu.png"))
	pm.sens.value = 2.0
	ok = _check(is_equal_approx(p.look_sens, 0.0044), "look speed applies") and ok
	pm.invert.button_pressed = true
	ok = _check(p.invert_y, "invert look applies") and ok
	pm.sens.value = 1.0; pm.invert.button_pressed = false
	pm.toggle()
	await process_frame
	ok = _check(not paused and not pm.panel.visible, "Resume") and ok
	pm.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await process_frame
	ok = _check(paused and pm.panel.visible, "Android back button pauses (doesn't quit)") and ok
	ok = _check(not ProjectSettings.get_setting("application/config/quit_on_go_back", true), "back doesn't quit the app") and ok
	pm.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await process_frame
	ok = _check(not paused, "…and back again resumes") and ok
	print("PAUSE ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func _check(c: bool, what: String) -> bool:
	print(("  ok  " if c else "  FAIL ") + what)
	return c
