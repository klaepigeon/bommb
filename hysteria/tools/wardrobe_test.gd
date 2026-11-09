extends SceneTree
## The bedroom wardrobe and the gap: push it from the side, see the hole, go through, come back.
## xvfb-run godot --rendering-driver opengl3 --path hysteria -s tools/wardrobe_test.gd -- out=<dir>
var out := "user://wardrobe"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame; await process_frame
	var p = main.player
	var ok := true
	p.torch.visible = true
	p.global_position = Vector3(5.9, 0, 1.9); _aim(p, Vector3(7.25, 1.0, 0.9))
	await _wait(0.5)
	await _shot("1_wardrobe_before")
	var front: String = p.target.call("prompt") if p.target else ""
	ok = _check(front == "Push the wardrobe", "from the front, it offers: \"%s\"" % front) and ok
	ok = _check(not main.wardrobe.can_push(), "(but it only moves from its side)") and ok
	p.global_position = Vector3(7.05, 0, 2.15); _aim(p, Vector3(7.2, 1.1, 1.3))
	await _wait(0.4)
	var pr: String = p.target.call("prompt") if p.target else ""
	ok = _check(pr == "Push the wardrobe", "from its side: \"%s\"" % pr) and ok
	p.use()
	await _wait(0.2)
	ok = _check(Noises.last.get("what", "") in ["scrape", "impact"], "it's loud (%s %.2f)" % [Noises.last.get("what", ""), float(Noises.last.get("loud", 0.0))]) and ok
	await _wait(3.0)
	ok = _check(main.wardrobe.pushed and not p.locked, "it's moved, and he's free again") and ok
	p.global_position = Vector3(6.45, 0, 2.35); _aim(p, Vector3(7.55, 0.9, 1.25))
	await _wait(0.6)
	await _shot("2_the_hole")
	p.global_position = Vector3(6.85, 0, 1.4); _aim(p, Vector3(7.55, 0.8, 1.25))
	await _wait(0.4)
	pr = p.target.call("prompt") if p.target else ""
	print("ray hits ", p.ray.get_collider(), " at ", p.ray.get_collision_point() if p.ray.is_colliding() else "-", " cam ", p.cam.global_position)
	ok = _check(pr == "Squeeze through the gap", "at the hole: \"%s\"" % pr) and ok
	p.use()
	await _wait(1.6)
	ok = _check(main.in_labyrinth, "through: in the labyrinth") and ok
	await _shot("3_arrived")
	p.yaw += PI
	await _wait(0.6)
	await _shot("4_the_way_back")
	pr = p.target.call("prompt") if p.target else ""
	ok = _check(pr == "Squeeze back through", "the way back: \"%s\"" % pr) and ok
	p.use()
	await _wait(1.6)
	ok = _check(not main.in_labyrinth and p.global_position.distance_to(Vector3(7.05, 0, 1.25)) < 0.6, "and back in the bedroom") and ok
	# a fresh flat: pushed from in front, with the axe in hand: he puts it down, steps round, pushes
	main.queue_free(); await process_frame
	root.get_node("Game").flags.clear()
	main = load("res://scenes/main.tscn").instantiate(); root.add_child(main)
	await process_frame; await process_frame
	p = main.player
	var axe: RigidBody3D = null
	for b in main.world.find_children("*", "RigidBody3D", true, false):
		if String(b.get("title")).to_lower() == "axe": axe = b
	p.global_position = Vector3(6.6, 0, 0.95); _aim(p, Vector3(7.0, 1.1, 0.95))
	await _wait(0.3)
	axe.global_position = p.hold.global_position; p.grab(axe)
	await _wait(0.3)
	p._aim()
	pr = p.target.call("use_with_prompt", axe) if p.target and p.target.has_method("use_with_prompt") else ""
	ok = _check(pr == "Push the wardrobe", "in front of it, the axe in hand: \"%s\"" % pr) and ok
	p.use()
	await _wait(4.5)
	ok = _check(p.held == null and main.wardrobe.pushed and not p.locked, "he put the axe down, stepped round, and pushed it") and ok
	print("WARDROBE ", "PASS" if ok else "FAIL")
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
