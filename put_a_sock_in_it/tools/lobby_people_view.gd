extends SceneTree
## Chapter 2's inhabitants where they live, from Kurt's eye: the super as the conversation opens
## (talking), then each of the others, torch on, from a few metres.
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/lobby_people_view.gd -- out=<dir>
func _initialize() -> void:
	await process_frame
	var out := "user://lobby_people"
	for a in OS.get_cmdline_user_args(): if a.begins_with("out="): out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	var game = root.get_node("Game")
	game.new_game()
	var t1 := Time.get_ticks_msec()
	while game.busy and Time.get_ticks_msec() - t1 < 10000: await process_frame
	game.change_level("lobby", {"card": false, "fade": 0.01})
	var t0 := Time.get_ticks_msec()
	while (game.level == null or not game.level.has_method("set_power") or game.busy) and Time.get_ticks_msec() - t0 < 60000: await process_frame
	var L = game.level
	game._black.visible = false
	await _wait(4.0)
	for i in 4:
		root.get_viewport().get_texture().get_image().save_png(out.path_join("talk_%d.png" % i))
		await _wait(1.5)
	root.get_node("Dialogue").stop(); L.set_cutscene(false)
	L.set_power(true, L.player)
	var P = L.player
	P.torch_on = true
	for id in ["super", "laundress", "hunter", "cook", "listener", "rearranger", "crawler_f2", "caretaker"]:
		if not L.people.has(id): continue
		var n = L.people[id]
		n.set_physics_process(false)
		var fwd: Vector3 = -n.global_transform.basis.z
		var eye: Vector3 = n.global_position + fwd * 2.2 + Vector3(0.4, 0, 0)
		P.global_position = eye; P.velocity = Vector3.ZERO
		await _wait(0.3)
		var d: Vector3 = n.global_position + Vector3(0, 1.2 if id != "crawler_f2" else 0.6, 0) - P.cam.global_position
		P.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
		await _wait(0.6)
		root.get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % id))
	quit()

func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame
