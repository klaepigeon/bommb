extends SceneTree
## The opening scare, frame by frame: first sight from the doorway, a tell (look away, look
## back), then the whole investigation as it plays, a frame every 0.3 s until the blackout.
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/scare_view.gd -- out=<dir>
var out := "user://scare_view"
var game
func _initialize() -> void:
	await process_frame
	for a in OS.get_cmdline_user_args(): if a.begins_with("out="): out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	game = root.get_node("Game")
	game.change_level("flat47", {"card": false, "fade": 0.01})
	await _wait(2.0)
	var L = game.level
	root.get_node("Dialogue").stop(); L.set_cutscene(false); game._black.visible = false
	L.front_door.set_open(true)
	await _view(L, "a_first_sight", Vector3(4.2, 0, 4.4), L._face())
	await _wait(0.6)
	printerr("SCARE seen=", L._seen_marta)
	root.get_node("Dialogue").stop(); L.set_cutscene(false)
	# look away for a while, then back: she's changed
	await _view(L, "b_look_away", Vector3(3.6, 0, 3.4), Vector3(6.0, 1.2, 3.4))
	await _wait(2.0)
	await _view(L, "c_look_back", Vector3(3.6, 0, 3.4), L._face())
	printerr("SCARE tells=", L._tells)
	await _view(L, "c2_look_away_again", Vector3(3.6, 0, 3.4), Vector3(6.0, 1.2, 3.4))
	await _wait(2.0)
	await _view(L, "c3_look_back_again", Vector3(3.6, 0, 3.4), L._face())
	printerr("SCARE tells=", L._tells)
	L._investigate()
	var t0 := Time.get_ticks_msec(); var i := 0
	while Time.get_ticks_msec() - t0 < 150000 and not L._woke:
		await _wait(0.25)
		var img := root.get_viewport().get_texture().get_image(); img.resize(480, 270)
		img.save_png(out.path_join("s_%03d.png" % i)); i += 1
	printerr("SCARE frames=", i)
	quit()

func _view(L, name: String, pos: Vector3, at: Vector3) -> void:
	L.player.global_position = pos; L.player.velocity = Vector3.ZERO
	await _wait(0.3)
	var d: Vector3 = at - L.player.cam.global_position
	L.player.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	await _wait(0.8)
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame
