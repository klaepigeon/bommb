extends SceneTree
## Marta in the labyrinth: she comes after the revolver's taken, sees him, takes hold of him,
## is hurt by body and head shots, and dies to a headshot once Headshot is bought. Nuggets,
## the skill tree, Socko's lines along the way. Saves frames.
## xvfb-run godot --rendering-driver opengl3 --path hysteria -s tools/hunt_test.gd -- out=<dir>
var out := "user://hunt"

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
	var lab = main.labyrinth
	var h = main.hunter
	var ok := true
	# skip the flat: Socko's on, the intro's done
	game.flags["woke_in_47"] = true; main.socko_intro.encounter = null
	await _until(func(): return game.flags.get("socko_intro_done", false), 70.0)
	main.enter_labyrinth()
	await _wait(1.5)
	# a nugget, picked up by walking into it
	var nug: Node3D = null
	for c in lab.get_children():
		if c.has_method("take") and is_instance_valid(c) and not c.is_queued_for_deletion() and c.global_position.distance_to(p.global_position) > 3.0: nug = c; break
	var before: int = Skills.nuggets()
	p.global_position = nug.global_position - Vector3(0, 0.9, 0)
	await _wait(0.6)
	ok = _check(Skills.nuggets() == before + 1, "a gutterspace nugget, taken by walking into it") and ok
	# the revolver; then she comes
	var gun_pos: Vector3 = lab.to_global(lab.fight.gun_at.origin)
	p.global_position = gun_pos + Vector3(-0.2, 0, -0.85); _aim(p, gun_pos)
	await _wait(0.5)
	p.use()
	await _wait(0.4)
	ok = _check(p.gun != null, "the revolver taken") and ok
	await _until(func(): return h.awake, 8.0)
	ok = _check(h.awake and h.visible, "and she's come into the town") and ok
	# look at her down the square
	p.global_position = lab.to_global(lab.center(10, 9)); 
	await _wait(0.2)
	_aim(p, lab.to_global(h.position + Vector3(0, 1.4, 0)))
	await _until(func(): return h.state == h.S.CHASE, 10.0)
	ok = _check(h.state == h.S.CHASE, "she sees him, and comes") and ok
	_aim(p, lab.to_global(h.position + Vector3(0, 1.3, 0)))
	await _shot("1_she_comes")
	# a body shot, then a head shot without the skill: hurt, not dead
	_aim(p, lab.to_global(h.position + Vector3(0, 0.95, 0)))
	await process_frame
	p.gun.fire()
	ok = _check(h.hp == h.MAX_HP - 1, "a body shot hurts her (%d)" % h.hp) and ok
	await _wait(0.3)
	_aim(p, h._head_shape.global_position)
	await process_frame
	p.gun.fire()
	ok = _check(h.hp == h.MAX_HP - 4 and h.state != h.S.DEAD, "a head shot hurts her more (%d), but she's still up" % h.hp) and ok
	# she reaches him: he comes to by the hole
	await _until(func(): return h.state == h.S.HOLD, 12.0)
	ok = _check(h.state == h.S.HOLD, "she takes hold of him") and ok
	await _shot("2_held")
	await _wait(4.0)
	var at_hole: bool = p.global_position.distance_to((lab.global_transform * lab.arrive).origin) < 1.0
	ok = _check(at_hole and not p.locked, "he comes to by the hole") and ok
	# buy Headshot (Socko's pick) and finish it
	game.flags["nuggets"] = 12
	main.skill_menu.toggle()
	await process_frame
	main.skill_menu._buy("headshot")
	main.skill_menu.toggle()
	ok = _check(Skills.owned("headshot") and p.gun.headshot_kills, "Headshot bought; the revolver kills with one") and ok
	h.position = lab.center(6, 4); h._path.clear(); h._enter(h.S.SEARCH)
	p.global_position = lab.to_global(lab.center(6, 2))
	await _wait(0.4)
	_aim(p, h._head_shape.global_position)
	await process_frame
	p.gun.reload(); await _wait(2.5)
	_aim(p, h._head_shape.global_position)
	await process_frame
	p.gun.fire()
	ok = _check(h.state == h.S.DEAD and game.flags.get("marta_dead", false), "one headshot: she's dead, for good") and ok
	await _wait(1.0)
	await _shot("3_dead")
	await _until(func(): return _said(s, "Trickshot"), 8.0)
	ok = _check(_said(s, "Trickshot's still got it"), "Socko: \"Trickshot's still got it!\"") and ok
	for k in ["Don't stop. Don't look", "Ooh. Now we're talking", "There she is", "Ooh, shiny"]:
		ok = _check(_said(s, k), "Socko said: \"%s…\"" % k) and ok
	print("HUNT ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func _said(s, start: String) -> bool:
	for l in s.history:
		if String(l).begins_with(start): return true
	return false

func _aim(p, at: Vector3) -> void:
	var d: Vector3 = at - p.cam.global_position
	p.yaw = atan2(-d.x, -d.z); p.pitch = atan2(d.y, Vector2(d.x, d.z).length())

func _until(cond: Callable, limit: float) -> void:
	var waited := 0.0
	while not cond.call() and waited < limit:
		await _wait(0.05); waited += 0.05

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
