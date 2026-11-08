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
	# dread: time with the body drains the colour; leaving lets it back
	var dread: Node = main.dread
	var mat: ShaderMaterial = main.container.material
	p.global_position = Vector3(3.2, 0, 3.5)   # living room, with the body at the table
	for i in 80: dread._process(1.0)
	var grey: float = mat.get_shader_parameter("bw")
	p.global_position = Vector3(7.0, 0, 4.5)   # out in the hall
	for i in 10: dread._process(1.0)
	var back: float = mat.get_shader_parameter("bw")
	p.global_position = Vector3(5.0, 0, 6.5)   # Sonya's room: nothing here yet
	for i in 40: dread._process(1.0)
	var gone: float = mat.get_shader_parameter("bw")
	print("dread: 80 s with her ", snappedf(grey, 0.01), ", 10 s out ", snappedf(back, 0.01), ", 40 s more ", snappedf(gone, 0.01))
	ok = ok and grey > 0.99 and back < grey and back > 0.2 and gone < 0.01
	# lights: no mesh may be reached by more omni or spot lights than the Compatibility renderer
	# (Android) shades per object, or it drops some, differently as the camera moves (flicker)
	var cap := int(ProjectSettings.get_setting("rendering/limits/opengl/max_lights_per_object", 8))
	var worst := 0; var worst_omni := 0; var worst_spot := 0
	var lights := world.find_children("*", "Light3D", true, false).filter(func(l): return l.visible and not (l is DirectionalLight3D))
	for m in world.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = m.global_transform * m.get_aabb()
		var co := 0; var cs := 0
		for l in lights:
			var r: float = l.omni_range if l is OmniLight3D else l.spot_range
			if l.global_position.clamp(bb.position, bb.end).distance_to(l.global_position) < r:
				if l is OmniLight3D: co += 1
				else: cs += 1
		worst = maxi(worst, co + cs); worst_omni = maxi(worst_omni, co); worst_spot = maxi(worst_spot, cs)
	print("lights: worst mesh reached by %d omni, %d spot, %d together (cap %d)" % [worst_omni, worst_spot, worst, cap])
	# 8 of each is Godot's default; the project raises the cap so even both together fit
	ok = ok and worst <= cap and worst_omni <= 8 and worst_spot <= 8
	print("SMOKE ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
