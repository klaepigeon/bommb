extends Node
## Builds each level headless and reports what it made (and any script errors on the way).
func _ready() -> void:
	await get_tree().process_frame
	for lname in ["flat47", "backrooms", "flat48"]:
		var root := Node3D.new()
		get_tree().root.add_child(root)
		var lvl := Level.new()
		root.add_child(lvl)
		var t := Time.get_ticks_msec()
		var lay: Dictionary = {"flat47": Flat47Layout.layout(), "backrooms": BackroomsLayout.layout(), "flat48": Flat48Layout.layout()}[lname]
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
		if lname == "backrooms":
			for pair in [[Vector3(2.5, 0, 3), Vector3(15, 0, 2)], [Vector3(2.5, 0, 3), Vector3(5.75, 0, 11.5)], [Vector3(15, 0, 3), Vector3(15.5, 0, 9)]]:
				print("SMOKE backrooms path %s -> %s: %d" % [pair[0], pair[1], lvl.nav.path(pair[0], pair[1]).size()])
		root.queue_free()
		await get_tree().process_frame
	get_tree().quit()
