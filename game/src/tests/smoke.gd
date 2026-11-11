extends Node
## Builds each level headless and reports what it made (and any script errors on the way).
func _ready() -> void:
	await get_tree().process_frame
	for lname in ["flat47"]:
		var root := Node3D.new()
		get_tree().root.add_child(root)
		var lvl := Level.new()
		root.add_child(lvl)
		var t := Time.get_ticks_msec()
		lvl.build(Flat47Layout.layout(), lname)
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
		var p := lvl.nav.path(Vector3(6.5, 0, 9.0), Vector3(11.0, 0, 3.5))
		print("SMOKE path entrance->bedroom: %d points" % p.size())
	get_tree().quit()
