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
	await _view(L, "a_landing", Vector3(12.6, 0, 5.2), Vector3(10.06, 1.3, 4.15))
	L.front_door.set_open(true)
	await _view(L, "b_hall", Vector3(9.5, 0, 4.5), Vector3(5.0, 1.2, 4.5))
	await _view(L, "c_living_marta", Vector3(4.1, 0, 4.4), L._face() + Vector3(0, -0.3, 0))
	await _view(L, "d_marta_close", L.marta.to_global(Vector3(0.0, 0, -1.25)), L._face(), 1.0)
	L.marta.face(L.player.cam.global_position, 0.38)
	L._reach(0.85)
	await _wait(2.4)
	root.get_viewport().get_texture().get_image().save_png(out.path_join("d2_marta_reach.png"))
	if L.hand: L.hand.visible = false
	await _view(L, "e_kitchen", Vector3(8.2, 0, 3.4), Vector3(9.5, 0.9, 0.6))
	L.player.torch_on = true
	await _view(L, "f_bath_torch", Vector3(8.6, 0, 5.6), Vector3(8.0, 0.6, 7.6))
	L.player.torch_on = false
	L.socko.visible = true; L.socko.hold = "out"; L._woke = true
	L.wardrobe.position.x += 1.35; L._wardrobe_moved = true
	L.player.global_position = Vector3(2.3, 0, 3.4)
	L._on_wardrobe_pushed()
	await _wait(1.2)
	root.get_node("Dialogue").stop(); L.set_cutscene(false)
	await _view(L, "g_hole", Vector3(2.3, 0, 3.4), L.HOLE + Vector3(0, 0.9, 0))
	L.outside.visible = true; L.env.environment.background_color = Color(1, 1, 1); L.env.environment.background_energy_multiplier = 1.6
	L.balcony_door.locked = false; L.balcony_door.set_open(true)
	await _view(L, "h_balcony", Vector3(2.3, 0, -0.6), L.sticky_at)
	game.change_level("flesh47", {"card": false, "checkpoint": true, "fade": 0.01})
	await _wait(3.0)
	var F = game.level
	F.marta.active = false
	game._black.visible = false
	await _view(F, "i_copy_a", F._p("A", Vector3(1.9, 0, 4.2)), F._p("A", Vector3(3.0, 1.0, 1.4)))
	F._place("B"); F.marta.active = false
	await _view(F, "j_copy_b_hall", F._p("B", Vector3(9.3, 0, 4.5)), F._p("B", Vector3(5.0, 1.2, 4.5)))
	F.player.torch_on = true
	F.marta.global_position = F._p("B", Vector3(2.2, 0, 3.3))
	await _view(F, "k_marta_torch", F._p("B", Vector3(4.0, 0, 4.4)), F.marta_head.global_position + Vector3(0, -0.2, 0))
	F._place("C"); F.marta.active = false; F.player.torch_on = false
	await _view(F, "l_copy_c", F._p("C", Vector3(6.5, 0, 4.4)), F._p("C", Vector3(9.9, 1.2, 4.2)))
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
