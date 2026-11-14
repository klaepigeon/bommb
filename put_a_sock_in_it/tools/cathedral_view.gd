extends SceneTree
## Flat 27 from Kurt's eye: the hallway into it, the nave, the vault (the congregation), the west
## wall behind him (the windows, the words), the altar from the dais steps, him close.
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/cathedral_view.gd -- out=<dir>
func _initialize() -> void:
	await process_frame
	var out := "user://cathedral_view"
	for a in OS.get_cmdline_user_args(): if a.begins_with("out="): out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	var game = root.get_node("Game")
	game.new_game()
	var t1 := Time.get_ticks_msec()
	while game.busy and Time.get_ticks_msec() - t1 < 10000: await process_frame
	game.flags["c27_loop_broken"] = true
	game.flags["c27_entered"] = true
	game.change_level("cathedral", {"card": false, "fade": 0.01})
	var t0 := Time.get_ticks_msec()
	while (game.level == null or not game.level.has_method("ring") or game.busy) and Time.get_ticks_msec() - t0 < 60000: await process_frame
	var L = game.level
	game._black.visible = false
	root.get_node("Dialogue").stop(); L.set_cutscene(false)
	var P = L.player
	var shots := [["a_hall", Vector3(0, 0, 1.6), 0.0, 0.0], ["b_nave", Vector3(0, 0, -3.0), 0.0, 0.08], ["c_vault", Vector3(0.0, 0, -13.0), 0.0, 1.35], ["c2_vault", Vector3(0.0, 0, -8.0), 0.0, 0.75],
		["d_west", Vector3(0, 0, -12.0), PI, 0.35], ["e_altar", Vector3(0, 0, -50.0), 0.0, 0.12], ["f_him", Vector3(0.4, 0.6, -57.6), 0.08, 0.38],
		["g_aisle", Vector3(6.8, 0, -14.0), 0.15, 0.1]]
	for s in shots:
		P.global_position = s[1]; P.velocity = Vector3.ZERO
		P.set_view(s[2], s[3])
		await _wait(0.8)
		root.get_viewport().get_texture().get_image().save_png(out.path_join("%s.png" % s[0]))
	quit()

func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame
