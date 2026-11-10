extends SceneTree
## Plays the Marta encounter with a scripted player and saves a frame at each beat.
## xvfb-run godot --rendering-driver opengl3 --path hysteria -s tools/marta_test.gd -- out=<dir>

var out := "user://marta"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame; await process_frame
	var p = main.player
	var enc = main.encounter
	var ok := true
	p.torch.visible = true
	# walk round to her side and lean in toward her face, from the table side
	p.global_position = Vector3(2.65, 0, 1.95)
	await _wait(0.3)
	_aim(p, enc.head_pos())
	await _wait(0.1)
	await _shot("1_leaning_in", 0.0)
	ok = _check(enc.state_name() == "STILL", "still before looking long enough") and ok
	await _wait(0.75)
	await _shot("2_snap", 0.0)
	ok = _check(enc.state_name() in ["SNAP", "STARE"], "she snapped awake") and ok
	await _wait(0.6)
	await _shot("3_stare", 0.0)
	await _wait(1.6)
	ok = _check(root.get_node("Game").flags.get("heard_boxes_question", false), "she asked about the boxes") and ok
	# step in, within reach
	p.global_position = Vector3(2.7, 0, 1.85); _aim(p, enc.head_pos())
	var waited := 0.0
	while enc.state_name() != "GRAB" and waited < 8.0:
		await _wait(0.1); waited += 0.1
	ok = _check(enc.state_name() == "GRAB", "she grabbed (%.1f s after stepping into reach)" % waited) and ok
	await _shot("4_grab", 0.25)
	await _shot("5_pulled", 0.55)
	await _shot("5b_held", 0.5)
	await _wait(3.0)
	ok = _check(enc.state_name() == "BLACK", "blackout") and ok
	await _wait(7.0)
	await _shot("6_waking", 0.0)
	await _wait(2.5)
	ok = _check(enc.state_name() == "AWAKE" and not main.marta.joints.hips.visible, "awake, and she's gone") and ok
	p.global_position = Vector3(3.6, 0, 1.0); _aim(p, Vector3(3.0, 0.5, 1.42))
	await _shot("7_empty_chair", 0.5)
	print("MARTA ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func _aim(p, at: Vector3) -> void:
	var d: Vector3 = at - (p.global_position + Vector3(0, 1.62, 0))
	p.yaw = atan2(-d.x, -d.z); p.pitch = atan2(d.y, Vector2(d.x, d.z).length())

func _wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame

func _shot(name: String, after: float) -> void:
	await _wait(after)
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("frame ", name)

func _check(c: bool, what: String) -> bool:
	print(("  ok  " if c else "  FAIL ") + what)
	return c
