extends SceneTree
## Opens every door and walks the player through the middle of each doorway, both ways.
## godot --headless --path hysteria -s tools/doors_test.gd

func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame; await process_frame
	main.encounter.process_mode = Node.PROCESS_MODE_DISABLED
	var p = main.player
	var ok := true
	for d in main.world.find_children("door_*", "", true, false):
		if not d.has_method("setup"): continue
		var open_ok: bool = d.locked == ""
		if open_ok:
			d.target = d.max_angle
		for i in 60: await physics_frame
		# the doorway: centre of the closed leaf, and the axis through it
		var along := Vector3(cos(d.psi0), 0, -sin(d.psi0))
		var mid: Vector3 = d.global_position + along * d.leaf_w * 0.5; mid.y = 0
		var across := Vector3(-along.z, 0, along.x)
		for side in [1.0, -1.0]:
			var a: Vector3 = mid + across * 0.9 * side; var b: Vector3 = mid - across * 0.9 * side
			p.global_position = a; p.velocity = Vector3.ZERO
			var dir: Vector3 = (b - a).normalized()
			p.yaw = atan2(-dir.x, -dir.z); p.pitch = 0.0
			Input.action_press("move_forward")
			var hits := {}
			for i in 200:
				await physics_frame
				for k in p.get_slide_collision_count():
					var c = p.get_slide_collision(k)
					var o = c.get_collider()
					var label: String = str(o.name) + ("/" + str(o.get_parent().name) if o.get_parent() else "")
					if o is StaticBody3D and o.name == "Collision":
						var sh = o.shape_owner_get_owner(o.shape_find_owner(c.get_collider_shape_index()))
						label = "wall shape at " + str(sh.global_position.snapped(Vector3(0.01, 0.01, 0.01))) + " size " + str(sh.shape.size.snapped(Vector3(0.01, 0.01, 0.01)))
					if c.get_normal().y < 0.7: hits[label] = true
				if p.global_position.distance_to(b) < 0.25: break
			Input.action_release("move_forward")
			var crossed: bool = (p.global_position - mid).dot(-across * side) > 0.3
			var expect := open_ok
			var good: bool = crossed == expect
			ok = ok and good
			print("%s %-10s %s  ended %s from the far mark%s" % ["  ok " if good else " FAIL", d.name, "crossed" if crossed else "BLOCKED", snappedf(p.global_position.distance_to(b), 0.01), "" if open_ok else "  (locked: should block)"])
			if not good: print("        hit: ", hits.keys())
	print("DOORS ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
