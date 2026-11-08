extends SceneTree
## The revolver: lying in the square, taken, held in Kurt's right hand, fired, reloaded, put away.
## xvfb-run godot --rendering-driver opengl3 --path hysteria -s tools/gun_test.gd -- out=<dir>
var out := "user://gun"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame; await process_frame
	main.enter_labyrinth()
	var lab = main.labyrinth
	var p = main.player
	var ok := true
	var gun_pos: Vector3 = lab.to_global(lab.fight.gun_at.origin)
	p.global_position = gun_pos + Vector3(-0.2, 0, -0.85); _aim(p, gun_pos)
	await _wait(0.6)
	await _shot("1_lying_there")
	var pr: String = p.target.call("prompt") if p.target else ""
	ok = _check(pr == "Take the revolver", "it's there to take: \"%s\"" % pr) and ok
	p.use()
	await _wait(0.8)
	ok = _check(p.gun != null and p.gun.drawn, "in his hand") and ok
	p.pitch = 0.05
	await _wait(0.8)
	await _shot("2_in_hand")
	var palm: Vector3 = p.global_transform * p.arm.palm_point()
	var grip: Vector3 = p.gun.grip_global().origin
	ok = _check(palm.distance_to(grip) < 0.06, "his palm is on the grip (%.3f m)" % palm.distance_to(grip)) and ok
	p.gun.fire()
	await _wait(0.05)
	await _shot("3_fire")
	ok = _check(p.gun.loaded == 6 and Noises.last.get("what", "") == "gunshot", "one round fired, and heard") and ok
	await _wait(0.8)
	p.gun.reload()
	await _wait(0.4)
	await _shot("4_reloading")
	await _wait(1.5)
	ok = _check(p.gun.loaded == 7 and p.gun.spare == 6, "reloaded a round at a time (7 in, %d spare)" % p.gun.spare) and ok
	p.gun.toggle()
	await _wait(0.4)
	ok = _check(not p.gun.drawn and not p.gun.visible, "put away") and ok
	print("GUN ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func _aim(p, at: Vector3) -> void:
	var d: Vector3 = at - (p.global_position + Vector3(0, 1.62, 0))
	p.yaw = atan2(-d.x, -d.z); p.pitch = atan2(d.y, Vector2(d.x, d.z).length())

func _wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame

func _shot(name: String) -> void:
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))

func _check(c: bool, what: String) -> bool:
	print(("  ok  " if c else "  FAIL ") + what)
	return c
