extends SceneTree
## The maze: from above (ceilings off), and from Kurt's eyes at the start, along the way, in a
## safe room and at 48's door. Prints the plan as text too.
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/maze_view.gd -- out=<dir>
var out := "user://maze_view"
func _initialize() -> void:
	await process_frame
	for a in OS.get_cmdline_user_args(): if a.begins_with("out="): out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	var game = root.get_node("Game")
	game.change_level("flesh47", {"card": false, "fade": 0.01})
	await _wait(4.0)
	var L = game.level
	root.get_node("Dialogue").stop(); L.set_cutscene(false); game._black.visible = false
	L.marta.active = false; L.marta.global_position = Vector3(-50, 0, -50)
	var M = L.maze
	# the plan
	var lines := []
	for y in M.h:
		var row := ""; var below := ""
		for x in M.w:
			var c := Vector2i(x, y)
			var t := "S" if c == M.start else ("E" if c == M.exit else ("#" if M.safe.has(c) else ("*" if M.path.has(c) else ".")))
			row += t + (" " if x < M.w - 1 and M.is_open(c, c + Vector2i(1, 0)) else "|")
			below += (" " if y < M.h - 1 and M.is_open(c, c + Vector2i(0, 1)) else "-") + "+"
		lines.append(row); lines.append(below)
	printerr("MAZE\n" + "\n".join(lines))
	printerr("SAFE ", M.safe, " CRACKED ", M.cracked, " PATH ", M.path.size())
	# views
	var P = L.player
	P.torch_on = true
	await _view(L, "a_start", L.centre(M.start) + Vector3(-0.6, 0, 0), L.centre(M.path[1], 1.2))
	await _view(L, "b_route", L.centre(M.path[3]), L.centre(M.path[5], 1.2))
	await _view(L, "c_route2", L.centre(M.path[int(M.path.size() * 0.45)]), L.centre(M.path[int(M.path.size() * 0.45) + 2], 1.2))
	var s0: Vector2i = M.safe[0]
	var door: Vector2i = M.neighbours(s0)[0]
	await _view(L, "d_safe_from_outside", L.centre(door), L.centre(s0, 1.1))
	await _view(L, "e_safe_inside", L.centre(s0) + (L.centre(door) - L.centre(s0)) * 0.1, L.centre(s0, 0.8) - (L.centre(door) - L.centre(s0)) * 0.5)
	await _view(L, "f_exit", L.centre(M.exit) + Vector3(-1.0, 0, 0), Vector3(M.w * L.CELL + 1.5, 1.2, L.centre(M.exit).z))
	quit(); return
	# from above
	for n in root.get_tree().get_nodes_in_group("maze_ceiling"): n.visible = false
	P.torch_on = false
	var cam := Camera3D.new(); L.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = M.h * L.CELL + 2.0
	cam.position = Vector3(M.w * L.CELL * 0.5, 30, M.h * L.CELL * 0.5); cam.rotation = Vector3(-PI * 0.5, 0, 0)
	cam.current = true
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(-1.2, 0.4, 0); sun.light_energy = 0.8; L.add_child(sun)
	await _wait(1.0)
	root.get_viewport().get_texture().get_image().save_png(out.path_join("z_above.png"))
	quit()

func _view(L, name: String, pos: Vector3, at: Vector3) -> void:
	L.player.global_position = pos; L.player.velocity = Vector3.ZERO
	await _wait(0.4)
	var d: Vector3 = at - L.player.cam.global_position
	L.player.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	await _wait(1.0)
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame
