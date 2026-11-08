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
	# the eyes ride the cloth of the upper jaw (skinned seats): open the mouth and they go up with it
	rig.jaw = 0.0; rig.apply_pose()
	var e_shut: Vector3 = rig.eye_center(0); var gap_shut: float = rig.eye_gap()
	rig.jaw = 1.0; rig.apply_pose()
	var rise: float = (rig.eye_center(0) - e_shut).dot(rig.bone_global(rig.B.FINGERS).basis.y.normalized())
	var gap_open: float = rig.eye_gap()
	rig.jaw = 0.0; rig.apply_pose()
	ok = _check(rig.eyes.size() == 2 and gap_shut > 0.005 and gap_open > 0.005 and rise > 0.002,
		"ping-pong eyes ride the upper jaw's cloth, apart (gap %.1f / %.1f mm, rise %.1f mm)" % [gap_shut * 1000.0, gap_open * 1000.0, rise * 1000.0]) and ok

	# ---- wake: beat 9, the hand rises
	p.global_position = Vector3(3.55, 0, 1.6)
	intro.encounter = null
	game.flags["woke_in_47"] = true
	await _wait(0.5)
	ok = _check(s.visible and p.locked, "he's held on the floor; the hand comes") and ok
	await _shot("1_rising", 1.5)
	await _wait(2.9)
	await _shot("2_hi", 0.4)
	await _until(func(): return intro.state >= intro.S.HI, 4.0)
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

	# ---- the torch is his now: it comes out of his mouth
	ok = _check(not p.torch.visible and s.torch != null and p.torch_holder == s, "the torch went to Socko when he appeared") and ok
	p.global_position = Vector3(6.5, 0, 4.5); p.yaw = PI / 2; p.pitch = -0.1
	var was: bool = s.torch_on
	p.toggle_torch()
	await _wait(0.6)
	ok = _check(s.torch_on != was and s.torch.visible == s.torch_on and not p.torch.visible, "[F] switches the light in his mouth") and ok
	if not s.torch_on: p.toggle_torch(); await _wait(0.6)
	await _until(func(): return not s.talking, 15.0)
	await _wait(0.6)
	var md: float = s.torch.global_position.distance_to(rig.mouth_global().origin)
	ok = _check(md < 0.02 and s.rig.jaw > 0.25, "the beam starts between his jaws (%.3f m), mouth held open (%.2f)" % [md, s.rig.jaw]) and ok
	await _shot("8_mouth_torch", 0.3)

	# ---- googly eyes: held still, each pupil runs down to the lowest point it can reach
	# (wait for him to stop talking: a talking puppet bounces, and so do its pupils)
	await _until(func(): return not s.talking, 15.0)
	await _wait(1.2)
	var eyes_ok := true
	for e in rig.eyes:
		var gt: Transform3D = (e.disc as Node3D).global_transform
		var down := Vector2(Vector3.DOWN.dot(gt.basis.x.normalized()), Vector3.DOWN.dot(gt.basis.z.normalized()))
		var press := absf(Vector3.DOWN.dot(gt.basis.y.normalized()))
		if down.length() > 0.6 * press + 0.1:      # clearly steep (near the sticking slope a real googly eye can hang)
			var dotv := (e.p as Vector2).normalized().dot(down.normalized())
			var reach := (e.p as Vector2).length() / (e.r as float)
			if not (dotv > 0.9 and reach > 0.9): print("    pupil: toward the bottom %.2f, out to the rim %.2f" % [dotv, reach])
			eyes_ok = eyes_ok and dotv > 0.9 and reach > 0.9
	ok = _check(eyes_ok, "googly pupils fall to the bottom of the eye when he's still") and ok
	# a jerk of the arm sends them flying
	var before: Vector2 = rig.eyes[0].p
	p.yaw += 0.9
	var rattle := 0.0
	for i in 10:
		await process_frame
		rattle = maxf(rattle, (rig.eyes[0].p as Vector2).distance_to(before) / float(rig.eyes[0].r))
	ok = _check(rattle > 0.25, "…and a jerk of the hand rattles them (%.0f%% of their travel)" % (rattle * 100.0)) and ok

	# ---- the right hand does the doing
	p.global_position = Vector3(5.2, 0, 4.5); p.yaw = PI / 2; p.pitch = -0.15   # facing Sonya's room door?
	var best: RigidBody3D
	for n in main.world.find_children("*", "RigidBody3D", true, false):
		if n.liftable and (not best or n.mass < best.mass): best = n
	best.global_position = p.hold.global_position
	p.grab(best)
	await _wait(0.6)
	var palm: Vector3 = p.global_transform * p.arm.palm_point()
	var grip: float = palm.distance_to(best.global_position)
	var side: float = (p.cam.global_transform.affine_inverse() * palm).x
	ok = _check(grip < 0.2 and side > 0.0, "carrying: Kurt's right hand holds it (%.2f m off, on the right)" % grip) and ok
	await _shot("9_right_hand_carry", 0.2)
	p.throw()
	await _wait(0.15)
	await _shot("10_throw", 0.0)
	await _wait(0.8)
	var lw: Vector3 = s.rig.bone_global(rig.B.HAND).origin
	ok = _check((p.cam.global_transform.affine_inverse() * lw).x < 0.0, "Socko stays on the left hand throughout") and ok

	# ---- teaching: walk, pick up, throw (noise), crouch
	var tut = main.socko_tutorial
	ok = _check(main.socko_hud.header.text.begins_with("S O C K O") and main.socko_hud.text.text == "Find a way out of Flat 47.", "top left: SOCKO SAYS · Find a way out of Flat 47.") and ok
	await _until(func(): return not s.talking, 12.0)
	p.global_position = Vector3(6.0, 0, 4.5)
	await _wait(0.2)
	p.global_position = Vector3(8.6, 0, 4.5)
	await _until(func(): return _said(s, "Walk it off"), 10.0)
	ok = _check(_said(s, "Walk it off"), "walking: \"Walk it off. Slow…\"") and ok
	await _until(func(): return not s.talking, 12.0)
	var prop: RigidBody3D
	for n in main.world.find_children("*", "RigidBody3D", true, false):
		if n.liftable and n.mass > 0.3 and n.mass < 3.0: prop = n; break
	prop.global_position = p.hold.global_position
	p.grab(prop)
	await _until(func(): return _said(s, "Heavy end first"), 10.0)
	ok = _check(_said(s, "Heavy end first"), "first pickup: \"Heavy end first… On her.\"") and ok
	await _until(func(): return not s.talking, 15.0)
	p.yaw = -PI / 2; p.pitch = 0.1   # at the front door
	p.throw()
	await _until(func(): return Noises.last.get("what", "") == "impact" and Noises.last.get("source") == p, 4.0)
	ok = _check(Noises.last.get("source") == p, "the throw lands with a noise (%.2f loud)" % float(Noises.last.get("loud", 0.0))) and ok
	await _until(func(): return _said(s, "Hear that"), 10.0)
	ok = _check(_said(s, "Hear that"), "…and Socko: \"Hear that? She hears it too.\"") and ok
	await _shot("11_hear_that", 0.3)
	await _until(func(): return not s.talking, 12.0)
	p.toggle_crouch()
	await _until(func(): return _said(s, "There you go"), 10.0)
	ok = _check(_said(s, "There you go"), "crouching: \"There you go — you've done this before, huh?\"") and ok
	print("SOCKO ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func _aim(p, at: Vector3) -> void:
	var d: Vector3 = at - p.cam.global_position
	p.yaw = atan2(-d.x, -d.z); p.pitch = atan2(d.y, Vector2(d.x, d.z).length())

func _said(s, start: String) -> bool:
	for l in s.history:
		if String(l).begins_with(start): return true
	return false

func _until(cond: Callable, limit: float) -> void:
	var waited := 0.0
	while not cond.call() and waited < limit:
		await _wait(0.05); waited += 0.05

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
