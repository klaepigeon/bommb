extends SceneTree
## Dumps every visible mesh in a level (world-space triangles, and each physics body's world AABB)
## for tools/geo_check.py, which finds coplanar overlapping faces (z-fighting) and things sunk
## into each other.
##   godot --headless --path . -s tools/geo_dump.gd -- level=flat47 out=<file.json>
func _initialize() -> void:
	await process_frame
	var lv := "flat47"; var out := "user://geo.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="): lv = a.substr(6)
		if a.begins_with("out="): out = a.substr(4)
	var game = root.get_node("Game")
	game.change_level(lv, {"card": false, "fade": 0.01, "checkpoint": lv != "flat47"})
	var t0 := Time.get_ticks_msec(); while Time.get_ticks_msec() - t0 < 3500: await process_frame
	var L = game.level
	var meshes := []
	for n in L.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null: continue
		if mi.get_parent() is Camera3D or _under(mi, "Player"): continue
		var xf := mi.global_transform
		var tris := PackedFloat32Array()
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			if arr.is_empty(): continue
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx = arr[Mesh.ARRAY_INDEX]
			var order: Array = []
			if idx != null and idx.size() > 0: order = Array(idx)
			else: order = range(v.size())
			for i in range(0, order.size() - 2, 3):
				for j in 3:
					var p: Vector3 = xf * v[order[i + j]]
					tris.append(p.x); tris.append(p.y); tris.append(p.z)
		if tris.size() == 0: continue
		meshes.append({"name": _path(mi, L), "obj": _owner_name(mi, L), "tris": Array(tris)})
	var bodies := []
	for n in L.find_children("*", "CollisionObject3D", true, false):
		var b := n as CollisionObject3D
		if _under(b, "Player"): continue
		for c in b.get_children():
			if c is CollisionShape3D and c.shape is BoxShape3D and not c.disabled:
				var sz: Vector3 = (c.shape as BoxShape3D).size
				var xf: Transform3D = (c as Node3D).global_transform
				var ab := xf * AABB(-sz * 0.5, sz)
				bodies.append({"name": _path(b, L), "kind": b.get_class(), "layer": b.collision_layer, "min": [ab.position.x, ab.position.y, ab.position.z], "max": [ab.end.x, ab.end.y, ab.end.z]})
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify({"meshes": meshes, "bodies": bodies}))
	f.close()
	printerr("GEO_DUMP meshes=%d bodies=%d" % [meshes.size(), bodies.size()])
	quit()

func _under(n: Node, cls: String) -> bool:
	var p := n.get_parent()
	while p:
		if p.is_in_group("player"): return true      # (by group: naming the class here would compile it before the autoloads)
		p = p.get_parent()
	return false

func _path(n: Node, L: Node) -> String:
	return String(L.get_path_to(n))

## The "thing" a mesh belongs to: its nearest ancestor that's a body or a named export node.
func _owner_name(n: Node, L: Node) -> String:
	var p := n
	while p and p != L:
		if p is CollisionObject3D or String(p.name).begins_with("prop_") or String(p.name).begins_with("pick_"): return String(L.get_path_to(p))
		p = p.get_parent()
	return String(L.get_path_to(n.get_parent()))
