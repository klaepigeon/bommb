extends Node
## Builds each level headless and reports what it made (and any script errors on the way).
func _ready() -> void:
	await get_tree().process_frame
	for lname in ["flat47", "backrooms", "ground_floor"]:
		var root := Node3D.new()
		get_tree().root.add_child(root)
		var lvl := Level.new()
		root.add_child(lvl)
		var t := Time.get_ticks_msec()
		var lay: Dictionary = {"flat47": Flat47Layout.layout(), "backrooms": BackroomsLayout.layout(), "ground_floor": GroundFloorLayout.layout()}[lname]
		lvl.build(lay, lname)
		var ms := Time.get_ticks_msec() - t
		var tris := 0
		var meshes := 0
		for mi in lvl.find_children("*", "MeshInstance3D", true, false):
			meshes += 1
			if mi.mesh:
				for s in mi.mesh.get_surface_count():
					tris += mi.mesh.surface_get_array_len(s) / 3
		print("SMOKE %s: built in %d ms, rooms %d, doors %d, meshes %d, tris %d, nav points %d, hides %d, props %d" % [
			lname, ms, lvl.rooms.size(), lvl.doors.size(), meshes, tris, lvl.nav.astar.get_point_count(), lvl.hides.size(),
			get_tree().get_nodes_in_group("props").size()])
		# every doorway must be passable by Kurt's capsule (static geometry only)
		await get_tree().physics_frame
		var space := lvl.get_world_3d().direct_space_state
		var cap := CapsuleShape3D.new(); cap.radius = 0.26; cap.height = 1.5
		var blocked := 0
		for o in lvl.data.openings:
			if o.get("window", "") != "" or float(o.get("sill", 0.0)) > 0.0 or float(o.get("w", 0.9)) < 0.75:
				continue
			var n := Vector3(0, 0, 1) if String(o.get("axis", "x")) == "x" else Vector3(1, 0, 0)
			var c := Vector3(o.p[0], 0.0, o.p[1])
			for side in [-1.0, 1.0]:
				var at: Vector3 = c + n * side * 0.55
				var room := lvl.room_at(at + Vector3(0, 1, 0))
				if room == "" or float(lvl.rooms[room].h) < 1.6:
					continue          # crawlspaces are for crouching
				at.y = lvl.room_floor(room) + 0.8
				var q := PhysicsShapeQueryParameters3D.new(); q.shape = cap
				q.transform = Transform3D(Basis.IDENTITY, at); q.collision_mask = 1
				for hit in space.intersect_shape(q, 4):
					if hit.collider is StaticBody3D:
						blocked += 1
						print("SMOKE BLOCKED doorway %s side %d in %s by %s" % [o.p, side, room, hit.collider.name])
						break
		print("SMOKE %s doorways blocked: %d" % [lname, blocked])
		if lname == "backrooms":
			for pair in [[Vector3(2.5, 0, 3), Vector3(15, 0, 2)], [Vector3(2.5, 0, 3), Vector3(5.75, 0, 11.5)], [Vector3(15, 0, 3), Vector3(15.5, 0, 9)]]:
				print("SMOKE backrooms path %s -> %s: %d" % [pair[0], pair[1], lvl.nav.path(pair[0], pair[1]).size()])
		root.queue_free()
		await get_tree().process_frame
	get_tree().quit()
