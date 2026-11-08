extends SceneTree
## Headless smoke test: loads the game, counts behaviours, opens a door, carries and throws a prop.
## godot --headless --path hysteria -s tools/smoke.gd

func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame; await process_frame
	var world: Node = main.world
	var doors := 0; var drawers := 0; var props := 0; var picks := 0
	for n in world.find_children("*", "", true, false):
		var s: Script = n.get_script()
		if not s: continue
		match s.resource_path.get_file():
			"door.gd": doors += 1
			"drawer.gd": drawers += 1
			"prop.gd": props += 1
			"pickable.gd": picks += 1
	print("doors=%d drawers=%d props=%d pickables=%d" % [doors, drawers, props, picks])
	var ok := doors > 5 and props > 50
	# a door opens
	var door: Node = world.find_children("door_dBath*", "", true, false)[0] if world.find_children("door_dBath*", "", true, false).size() else null
	if door:
		var y0: float = door.rotation.y
		door.interact(main.player)
		for i in 90: await physics_frame
		print("door ", door.name, " turned ", snappedf(door.rotation.y - y0, 0.01))
		ok = ok and absf(door.rotation.y - y0) > 0.5
	# the chained front door won't open past the chain
	var front: Node = world.find_child("door_dEntry", true, false)
	if front:
		front.interact(main.player)
		for i in 60: await physics_frame
		print("front door angle ", snappedf(front.angle, 0.01), " (chain)")
		ok = ok and front.angle < 0.2
	# carry and throw the lightest prop
	var best: RigidBody3D
	for n in world.find_children("*", "RigidBody3D", true, false):
		if n.liftable and (not best or n.mass < best.mass): best = n
	var p: CharacterBody3D = main.player
	best.global_position = p.hold.global_position + Vector3(0, 0, 0.1)
	p.grab(best)
	for i in 30: await physics_frame
	var d := best.global_position.distance_to(p.hold.global_position)
	print("carrying ", best.title, " offset ", snappedf(d, 0.01))
	ok = ok and d < 0.25
	var start := best.global_position
	p.throw()
	for i in 20: await physics_frame
	print("thrown ", snappedf(best.global_position.distance_to(start), 0.01), " m")
	ok = ok and best.global_position.distance_to(start) > 0.3
	print("SMOKE ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
