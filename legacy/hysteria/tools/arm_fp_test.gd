extends SceneTree
## Kurt's right arm in first person, in the flat: idle, looking down, reaching to open a door,
## carrying something, nose to a wall. Saves a frame of each.
## xvfb-run godot --rendering-driver opengl3 --path hysteria -s tools/arm_fp_test.gd -- out=<dir>
var out := "user://arm"
var p

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame; await process_frame
	main.encounter.process_mode = Node.PROCESS_MODE_DISABLED
	p = main.player
	_at(Vector3(8.6, 0, 4.4), PI / 2, -0.12)
	await _shot("1_hall_idle", 1.2)
	_at(Vector3(8.6, 0, 4.4), PI / 2, -0.9)
	await _shot("2_looking_down", 0.8)
	# the bedroom door, closed: stand in front of it, face it and use it
	var door = main.world.find_child("door_dBed", true, false)
	door.target = 0.0
	await _wait(1.0)
	var along := Vector3(cos(door.psi0), 0, -sin(door.psi0))
	var mid: Vector3 = door.global_position + along * door.leaf_w * 0.5; mid.y = 0.0
	var across := Vector3(-along.z, 0, along.x)
	var stand := mid + across * 0.75
	if stand.z < 3.8: stand = mid - across * 0.75       # the hall side
	var d := mid - stand
	_at(stand, atan2(-d.x, -d.z), -0.12)
	await _wait(0.4)
	print("target before use: ", p.target)
	p.use()
	print("reach_t ", p._reach_t, " at ", p._reach_at)
	await _shot("3_reach_door", 0.22)
	await _shot("4_reach_door_late", 0.25)
	# carrying the lightest thing in the kitchen
	var best: RigidBody3D
	for n in main.world.find_children("*", "RigidBody3D", true, false):
		if n.liftable and n.global_position.distance_to(Vector3(8.5, 1, 2)) < 2.0 and (not best or n.mass < best.mass): best = n
	_at(Vector3(8.6, 0, 3.0), 0.0, -0.2)
	best.global_position = p.hold.global_position
	p.grab(best)
	await _shot("5_carrying_" + best.title.replace(" ", "_"), 1.2)
	p.drop()
	# nose to the hall wall
	_at(Vector3(8.0, 0, 3.98), 0.0, -0.1)
	await _shot("6_at_wall", 1.0)
	print("arm fp shots done")
	quit()

func _at(pos: Vector3, yaw: float, pitch: float) -> void:
	p.global_position = pos; p.velocity = Vector3.ZERO; p.yaw = yaw; p.pitch = pitch

func _wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame

func _shot(name: String, after: float) -> void:
	await _wait(after)
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("frame ", name)
