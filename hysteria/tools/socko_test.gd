extends SceneTree
## Socko in the flat: the rig's mechanics, then beats 9-10 (the hand, the introduction) played
## with a scripted player, saving a frame at each beat.
## xvfb-run godot --rendering-driver opengl3 --path hysteria -s tools/socko_test.gd -- out=<dir>
## (Marta's encounter is skipped: the test starts from "he's come to", flag woke_in_47.)

var out := "user://socko"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame; await process_frame
	var game: Node = root.get_node("Game")
	var p = main.player
	var s = main.socko
	var intro = main.socko_intro
	var ok := true
	ok = _check(not s.visible and not s.is_processing(), "no Socko before he wakes") and ok

	# ---- the rig: the mouth is the hand
	var rig = s.rig
	rig.jaw = 0.0; rig.apply_pose()
	var shut: float = rig.bone_global(rig.B.FINGERTIPS).origin.distance_to(rig.bone_global(rig.B.THUMBTIP).origin)
	rig.jaw = 1.0; rig.apply_pose()
	var open: float = rig.bone_global(rig.B.FINGERTIPS).origin.distance_to(rig.bone_global(rig.B.THUMBTIP).origin)
	rig.jaw = 0.0; rig.apply_pose()
	ok = _check(open - shut > 0.03, "fingers and thumb part to open the mouth (%.3f -> %.3f m)" % [shut, open]) and ok
	ok = _check(rig.sock.mesh.get_surface_count() == 3, "sock, mouth pocket and tongue are one skinned mesh") and ok
	var eyes_on_hand := true
	for e in rig.eyes:
		eyes_on_hand = eyes_on_hand and (e.disc as Node).get_parent() is BoneAttachment3D
	ok = _check(eyes_on_hand and rig.eyes.size() == 2, "googly eyes ride the finger bone") and ok

	# ---- wake: beat 9, the hand rises
	p.global_position = Vector3(3.55, 0, 1.6)
	intro.encounter = null
	game.flags["woke_in_47"] = true
	await _wait(0.5)
	ok = _check(s.visible and p.locked, "he's held on the floor; the hand comes") and ok
	await _shot("1_rising", 1.5)
	await _wait(2.9)
	await _shot("2_hi", 0.4)
	ok = _check(intro.state >= intro.S.HI, "\"…Hi.\"") and ok
	# mouth moves with speech, shuts after
	var max_jaw := 0.0
	var waited := 0.0
	while intro.state < intro.S.SIT and waited < 15.0:
		max_jaw = maxf(max_jaw, s.rig.jaw); await _wait(0.03); waited += 0.03
	ok = _check(max_jaw > 0.3, "the mouth works while he talks (peak %.2f)" % max_jaw) and ok
	ok = _check(not p.locked, "he sits up anyway") and ok
	await _shot("3_wince", 0.3)
	# look at Socko
	waited = 0.0
	while intro.state < intro.S.LOOK_AT_ME and waited < 15.0:
		await _wait(0.1); waited += 0.1
	p.pitch = -0.55   # look down at the hand
	await _wait(1.6)
	await _shot("4_its_me", 0.6)
	ok = _check(intro.state >= intro.S.ITS_ME, "looking at him starts \"It's me. Socko.\"") and ok
	# look round the room
	waited = 0.0
	while intro.state < intro.S.ROOM and waited < 15.0:
		await _wait(0.1); waited += 0.1
	await _wait(2.5)
	p.yaw += 1.4   # look round the room
	waited = 0.0
	while intro.state < intro.S.GONE and waited < 12.0:
		await _wait(0.1); waited += 0.1
	await _shot("5_dont_look", 1.2)
	ok = _check(intro.state >= intro.S.GONE, "looking round: \"Don't look at the chair, bud.\"") and ok
	# his head stays on Kurt while Kurt looks at the chair
	ok = _check(s.gaze_point.distance_to(p.cam.global_position) < 0.3, "…and he keeps looking at Kurt, not the chair") and ok
	waited = 0.0
	while intro.state < intro.S.DOOR and waited < 15.0:
		await _wait(0.1); waited += 0.1
	await _shot("6_door", 0.8)
	waited = 0.0
	while intro.state < intro.S.DONE and waited < 15.0:
		max_jaw = 0.0; await _wait(0.1); waited += 0.1
	ok = _check(game.flags.get("socko_intro_done", false), "introduction done") and ok
	await _wait(1.0)
	ok = _check(s.rig.jaw < 0.2, "mouth at rest when quiet (%.2f)" % s.rig.jaw) and ok

	# ---- attached: whip the view round and walk; the hand never leaves the arm
	var worst := 0.0
	for i in 90:
		p.yaw += 0.09
		p.pitch = sin(i * 0.2) * 0.8
		await process_frame
		var d: float = rig.bone_global(rig.B.HAND).origin.distance_to(p.cam.global_position)
		worst = maxf(worst, d)
	ok = _check(worst < 0.62, "fast turns: the hand stays on the arm (max %.2f m from the eye)" % worst) and ok
	p.global_position = Vector3(9.6, 0, 4.5); p.yaw = -PI / 2; p.pitch = 0.0   # nose to the front door
	await _wait(0.8)
	var tip: Vector3 = rig.bone_global(rig.B.FINGERTIPS).origin
	var q := PhysicsRayQueryParameters3D.create(p.cam.global_position, tip); q.exclude = [p.get_rid()]
	ok = _check(p.get_world_3d().direct_space_state.intersect_ray(q).is_empty(), "face to the door: the hand pulls in, not through it") and ok
	await _shot("7_at_the_door", 0.2)
	print("SOCKO ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func _aim(p, at: Vector3) -> void:
	var d: Vector3 = at - p.cam.global_position
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
