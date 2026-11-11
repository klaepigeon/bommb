extends Node
var main: Node
func _ready() -> void:
	main = load("res://src/main.tscn").instantiate()
	main.args = {"autotest": "none"}
	add_child(main)
	await get_tree().process_frame
	await main.load_level("backrooms", "arrival")
	for i in 150: await get_tree().physics_frame
	var p: Player = main.player
	print("PROBE player at ", p.global_position, " eye ", p._eye, " mode ", p.mode, " locked ", p.locked)
	var fb = main.level.power.fuse_box
	print("PROBE fusebox ", fb, " at ", fb.global_position if fb else null)
	for test in [[Vector3(7.1, 0, 7.4), Vector3(7.9, 1.6, 7.4)], [Vector3(6.5, 0, 9.3), Vector3(6.875, 1.0, 10.0)], [Vector3(7.2, 0, 11.6), Vector3(7.93, 1.05, 12.0)]]:
		p.global_position = test[0]
		var d: Vector3 = test[1] - (test[0] + Vector3(0, p._eye, 0))
		p.rotation.y = atan2(-d.x, -d.z)
		p._pitch = atan2(d.y, Vector2(d.x, d.z).length()); p.head.rotation.x = p._pitch
		for i in 4: await get_tree().physics_frame
		var cam := p.camera
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_transform.basis.z * 2.2, 0xFFFF)
		q.exclude = [p.get_rid()]
		var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
		print("PROBE at ", p.global_position, " cam ", cam.global_position, " -> hit ", (str(hit.collider.get_path()) + " layer " + str(hit.collider.collision_layer)) if hit else "nothing", " @", hit.get("position"), " verbs ", p.verbs.map(func(v): return v.id))
	get_tree().quit()
