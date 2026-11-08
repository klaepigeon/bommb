extends SceneTree
## Walks the player from the door down the hall and into the living room, saving a frame every
## 0.25 s: for checking that lighting holds steady in motion.
## xvfb-run godot --rendering-driver opengl3 --path hysteria -s tools/walk_frames.gd -- out=<dir>
func _initialize() -> void:
	var out := "user://walk"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame; await process_frame
	main.encounter.process_mode = Node.PROCESS_MODE_DISABLED
	var p = main.player
	p.global_position = Vector3(9.35, 0, 4.55); p.yaw = PI / 2; p.pitch = -0.05
	main.world.find_child("door_dLiving", true, false).target = 1.5
	Input.action_press("move_forward")
	var n := 0
	var end := Time.get_ticks_msec() + 9000
	var next := 0
	while Time.get_ticks_msec() < end:
		await process_frame
		Input.action_press("move_forward")     # a window losing focus releases held actions
		if p.global_position.x < 4.6 and p.yaw > 0.5:
			p.yaw = lerpf(p.yaw, 0.2, 0.05)
		if Time.get_ticks_msec() >= next:
			next = Time.get_ticks_msec() + 250
			root.get_viewport().get_texture().get_image().save_png(out.path_join("f%02d.png" % n)); n += 1
	Input.action_release("move_forward")
	print("frames ", n, " ended at ", p.global_position)
	quit()
