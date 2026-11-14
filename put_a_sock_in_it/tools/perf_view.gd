extends SceneTree
## What a frame costs at a few places in a level: draw calls, objects, triangles (on this machine's
## GL; the counts are what matter for phones, not the times).
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/perf_view.gd -- level=cathedral
func _initialize() -> void:
	await process_frame
	var level := "cathedral"
	for a in OS.get_cmdline_user_args(): if a.begins_with("level="): level = a.substr(6)
	var game = root.get_node("Game")
	game.new_game()
	while game.busy: await process_frame
	game.flags["c27_loop_broken"] = true; game.flags["c27_entered"] = true; game.flags["ch2_talked"] = true
	game.change_level(level, {"card": false, "fade": 0.01})
	var t0 := Time.get_ticks_msec()
	while (game.level == null or game.busy or String(game.level_id) != level) and Time.get_ticks_msec() - t0 < 60000: await process_frame
	var L = game.level
	game._black.visible = false
	root.get_node("Dialogue").stop(); L.set_cutscene(false)
	var spots := {"cathedral": [[Vector3(0, 0, -3), 0.0, 0.05], [Vector3(0, 0, -20), 0.0, 0.3], [Vector3(0, 0, -50), 0.0, 0.1]],
		"lobby": [[Vector3(12, 0, 1.4), 0.0, 0.0], [Vector3(9, 0, 7), -1.57, 0.0], [Vector3(10, 3.2, 7), 1.57, 0.0]]}
	var meshes: int = L.find_children("*", "MeshInstance3D", true, false).size()
	printerr("PERF %s: %d MeshInstance3D in the level" % [level, meshes])
	for s in spots.get(level, []):
		L.player.global_position = s[0]; L.player.set_view(s[1], s[2])
		for i in 20: await process_frame
		var rs := RenderingServer
		var dc := rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var ob := rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		var pr := rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		printerr("PERF   at %s: %d draw calls, %d objects, %d primitives" % [s[0], dc, ob, pr])
	quit()
