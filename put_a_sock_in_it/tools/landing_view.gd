extends SceneTree
## The stairwell and the doors, from several angles, for judging the look:
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/landing_view.gd -- out=<dir>
var out := "user://landing_view"
var game
func _initialize() -> void:
	await process_frame
	for a in OS.get_cmdline_user_args(): if a.begins_with("out="): out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	game = root.get_node("Game")
	game.change_level("flat47", {"card": false, "fade": 0.01})
	await _wait(2.0)
	var L = game.level
	root.get_node("Dialogue").stop()
	L.set_cutscene(false); game._black.visible = false
	await _view(L, "a_front_47", Vector3(12.6, 0, 5.2), Vector3(10.2, 1.2, 4.56))
	await _view(L, "b_from_47", Vector3(10.7, 0, 4.56), Vector3(13.6, 1.0, 6.4))
	await _view(L, "c_door_48", Vector3(11.6, 0, 5.4), Vector3(12.1, 1.2, 8.0))
	await _view(L, "d_stair_down", Vector3(12.4, 0, 4.0), Vector3(13.6, -0.6, 6.4))
	await _view(L, "e_up_corner", Vector3(10.8, 0, 7.4), Vector3(13.8, 2.2, 3.6))
	L.front_door.set_open(true)
	await _view(L, "f_hall_doors", Vector3(9.6, 0, 4.5), Vector3(5.5, 1.1, 4.0))
	await _view(L, "g_bath_door", Vector3(8.6, 0, 4.3), Vector3(9.1, 1.1, 5.2))
	await _view(L, "h_child_bed_doors", Vector3(6.0, 0, 4.5), Vector3(6.6, 1.0, 3.8))
	await _view(L, "i_living_door", Vector3(5.4, 0, 4.4), Vector3(4.4, 1.2, 5.0))
	await _view(L, "j_entry_inside", Vector3(8.4, 0, 4.56), Vector3(10.2, 1.2, 4.56))
	quit()

func _view(L, name: String, pos: Vector3, at: Vector3) -> void:
	L.player.global_position = pos; L.player.velocity = Vector3.ZERO
	await _wait(0.4)
	var d: Vector3 = at - L.player.cam.global_position
	L.player.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	await _wait(1.2)
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame
