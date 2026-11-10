extends SceneTree
## Gunplay, felt: the view kicks and comes back (with a little drift left to correct), the time
## held on a hit and slowed on a kill comes back to normal, a round a little off goes into her
## anyway (magnetism, head first), a hit throws debris and ticks the crosshair, and a mouse never
## gets its aim nudged. godot --headless --path hysteria -s tools/gunfeel_test.gd

var ok := true
func check(cond: bool, what: String) -> void:
	print(("  ok  " if cond else " FAIL ") + what)
	ok = ok and cond

func wait_real(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end: await process_frame

func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate(); main.name = "Main"; root.add_child(main)
	await process_frame; await process_frame
	main.encounter.skip(); main.socko_intro.skip(); root.get_node("Game").flags["socko_intro_done"] = true
	var p = main.player; var feel = main.gun_feel
	check(feel != null, "the gun feel layer is there")
	main.enter_labyrinth()
	for n in main.labyrinth.find_children("*", "StaticBody3D", true, false):
		if n.get_script() and String(n.get_script().resource_path).ends_with("revolver_pickup.gd"): n.interact(p)
	var g = p.gun
	await wait_real(0.3)
	# the kick, and the recovery
	var pitch0: float = p.pitch
	g.fire()
	var peak := 0.0
	var t_end := Time.get_ticks_msec() + 250
	while Time.get_ticks_msec() < t_end:
		await process_frame
		peak = maxf(peak, p.pitch - pitch0)
	await wait_real(0.6)
	var after: float = p.pitch - pitch0
	check(peak > 0.02, "the shot kicks the view up (%.3f rad)" % peak)
	check(after < peak * 0.6 and after > 0.0, "and most of it comes back by itself (%.3f left to correct)" % after)
	# magnetism: aim a little to the side of her and she still takes it
	var h = main.hunter
	h.wake(Vector2i(6, 4)); h._enter(h.S.SEARCH)
	for i in 4: await process_frame
	h.set_process(false)                     # hold her still where she is
	var head: Vector3 = h._head_shape.global_position
	p.global_position = main.labyrinth.to_global(h.position + Vector3(0, 0, 6.0)); p.velocity = Vector3.ZERO
	await physics_frame
	var to: Vector3 = (head + Vector3(0.25, 0.05, 0)) - p.cam.global_position      # a quarter-metre off at 6 m
	p.yaw = atan2(-to.x, -to.z); p.pitch = atan2(to.y, Vector2(to.x, to.z).length())
	await process_frame; await process_frame
	var aim: Dictionary = feel.resolve_aim(p.cam.global_position, -p.cam.global_basis.z, 40.0)
	check(aim.target == h and aim.head, "a round a little off her head goes to her head (magnetism)")
	var hp0: int = h.hp
	g.headshot_kills = true
	g._next_shot = 0
	g.fire()
	await process_frame
	h.set_process(true)
	check(h.state == h.S.DEAD, "one headshot with Headshot: down, for good")
	check(Engine.time_scale < 0.5, "a kill: time slows (%.2f)" % Engine.time_scale)
	var hud := root.find_child("HUD", true, false)
	var ticked: bool = (hud != null and float(hud.get("_tick_t")) > 0.0) or get_first_node_in_group_ticked()
	check(ticked, "the crosshair ticks")
	var debris := false
	for c in p.get_parent().get_children(): if c is CPUParticles3D: debris = true
	check(debris, "coral and smoke where the round went in")
	await wait_real(1.0)
	check(is_equal_approx(Engine.time_scale, 1.0) and is_equal_approx(AudioServer.playback_speed_scale, 1.0), "and time comes back to normal")
	# a mouse hand is left alone
	feel._pad_active = false; p.touch_ui = false
	var y0: float = p.yaw
	for i in 20: await process_frame
	check(absf(p.yaw - y0) < 0.0005 or DisplayServer.is_touchscreen_available(), "no aim nudging for a mouse")
	print("GUNFEEL ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func get_first_node_in_group_ticked() -> bool:
	var h := get_first_node_in_group("hud")
	return h != null and float(h.get("_tick_t")) > 0.0
