extends SceneTree
## Renders fixed views of both levels at full resolution, for judging the look:
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/beauty.gd -- out=<dir>
var out := "user://beauty"
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
	await _view(L, "a_landing", Vector3(1.0, 0, 10.2), Vector3(1.96, 1.4, 8.0))
	L.front_door.set_open(true, 0.01)
	await _view(L, "b_hall", Vector3(1.9, 0, 7.6), Vector3(1.0, 1.2, 5.0))
	await _view(L, "c_living_marta", Vector3(4.0, 0, 6.8), Vector3(8.6, 0.9, 4.3))
	await _view(L, "d_marta_close", Vector3(7.6, 0, 4.4), Vector3(8.7, 1.0, 4.25), 1.0)
	await _view(L, "e_kitchen", Vector3(2.6, 0, 3.6), Vector3(1.0, 1.0, 0.5))
	L.player.torch_on = true
	await _view(L, "f_bathroom_torch", Vector3(1.2, 0, 4.6), Vector3(0.4, 0.8, 3.2))
	await _view(L, "g_boxroom_torch", Vector3(4.6, 0, 3.8), Vector3(4.2, 1.0, 1.0))
	L.player.torch_on = false
	L.socko.visible = true; L.socko.hold = "out"
	L.wardrobe.position.x -= 1.4; L._on_wardrobe_pushed(null)
	root.get_node("Dialogue").stop(); L.set_cutscene(false)
	await _view(L, "h_hole", Vector3(8.0, 0, 2.4), Vector3(8.4, 0.5, 0.0))
	game.change_level("flesh47", {"card": false, "checkpoint": true, "fade": 0.01})
	await _wait(3.0)
	var F = game.level
	F.marta.active = false
	game._black.visible = false
	await _view(F, "i_flesh", F.cell_pos(2, 3), F.cell_pos(8, 3, 1.2))
	F.player.torch_on = true
	await _view(F, "j_flesh_torch", F.cell_pos(9, 5), F.cell_pos(9, 9, 1.0))
	var mp: Vector3 = F.marta.global_position
	F.marta.body.pose.head = Vector3(0.3, 0.2, 0.4)
	await _view(F, "k_marta_torch", mp + Vector3(0.3, 0, -3.0) if not _blocked(F, mp + Vector3(0.3, 0, -3.0), mp) else mp + Vector3(3.0, 0, 0), mp + Vector3(0, 1.3, 0))
	print("BEAUTY done")
	quit()
func _blocked(L, a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a + Vector3(0, 1.6, 0), b + Vector3(0, 1.6, 0), 1)
	return not L.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
func _view(L, name: String, pos: Vector3, at: Vector3, crouch := 0.0) -> void:
	L.player.global_position = pos; L.player.velocity = Vector3.ZERO
	L.player.crouching = crouch > 0.0
	await _wait(0.4)
	var d: Vector3 = at - L.player.cam.global_position
	L.player.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	await _wait(1.2)
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame
