extends SceneTree
## Plays the whole chapter through the real game, checking each beat happens, and saves
## screenshots of the important moments. Steps the player by teleporting him and calling the
## same interact() a key press would.
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/playthrough.gd -- out=<dir>

var out := "user://playthrough"
var game
var fails := 0
var shots := 0

func _initialize() -> void:
	await process_frame
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	game = root.get_node("Game")
	var dlg = root.get_node("Dialogue")
	Engine.time_scale = 1.6
	game.new_game()
	await _until(func(): return game.level != null and game.level_id == "flat47", 20.0, "flat47 loads")
	var L = game.level
	await _until(func(): return L.player.controls and not dlg.busy and not game.busy, 40.0, "knocking ends, control given")
	await _shot("01_landing")
	_check(not L.socko.visible, "no Socko before the attack")
	L.front_door.interact(L.player)
	await _wait(1.2)
	_check(L.front_door.is_open, "front door opens")
	_tp(L, Vector3(1.9, 0, 7.0), Vector3(1.9, 1.5, 5.5))
	await _until(func(): return dlg.speaking == "kurt", 5.0, "'Christ...' on entering")
	await _shot("02_hall")
	await _until(func(): return not dlg.busy, 10.0, "line ends")
	_tp(L, Vector3(4.3, 0, 6.2), L.marta.head_pos())
	await _until(func(): return L.marta_spot.enabled, 5.0, "seeing Marta enables 'Look closer'")
	await _shot("03_marta_seen")
	await _until(func(): return not dlg.busy, 10.0, "'Oh... oh no.' ends")
	L.marta_spot.interact(L.player)
	await _until(func(): return dlg.speaking == "marta", 20.0, "Marta speaks")
	await _wait(1.5)
	await _shot("04_marta_boxes")
	await _until(func(): return L.player.global_position.x < 4.2, 40.0, "she throws him across the room")
	await _until(func(): return L.socko.visible, 30.0, "wakes; Socko appears")
	await _until(func(): return dlg.speaking == "socko", 15.0, "Socko's first line")
	await _wait(0.8)
	await _shot("05_socko_hello")
	await _until(func(): return L._woke, 60.0, "wake conversation finishes")
	_check(not L.marta.visible, "Marta is gone from the chair")
	await _shot("06_awake")
	_tp(L, Vector3(1.96, 0, 7.2), Vector3(1.96, 1.2, 8.0))
	L.front_door.interact(L.player)
	await _until(func(): return dlg.busy, 5.0, "door convo starts")
	await _until(func(): return dlg.speaking == "socko", 10.0, "'Maybe it's locked?'")
	await _shot("07_door_locked")
	await _until(func(): return not dlg.busy, 20.0, "door convo ends")
	_check(not L.front_door.is_open, "front door stays shut")
	_tp(L, Vector3(8.4, 0, 2.0), Vector3(8.4, 1.0, 0.4))
	L.wardrobe.interact(L.player)
	await _until(func(): return L.wardrobe.moved, 10.0, "wardrobe pushed aside")
	await _until(func(): return L.socko.cross_eyed, 25.0, "Socko goes cross-eyed")
	await _wait(0.5)
	await _shot("08_cross_eyed")
	await _until(func(): return not dlg.busy and L.player.controls, 20.0, "hole convo ends")
	await _shot("09_hole")
	_check(L.hole_spot.enabled, "'Crawl in' is offered")
	_tp(L, Vector3(2.2, 0, 1.25), Vector3(2.2, 0.7, 0.3))
	L.gun_drawer.interact(L.player)
	await _wait(1.0)
	var gun = null
	for c in L.gun_drawer.get_children(): if "item" in c: gun = c
	_check(gun != null, "pistol is in the drawer")
	if gun: gun.interact(L.player)
	await _wait(0.6)
	_check(game.pistol.have and game.pistol.mag == 4, "pistol taken, 4 rounds")
	await _shot("10_pistol")
	L.pistol.fire()
	await _wait(0.4)
	_check(game.pistol.mag == 3, "firing spends a round")
	L.balcony_door.interact(L.player)
	await _wait(1.2)
	_tp(L, Vector3(10.7, 0, 5.8), Vector3(13, 1.4, 5.8))
	await _until(func(): return dlg.speaking == "kurt", 8.0, "balcony convo")
	await _wait(2.0)
	await _shot("11_sticky_note")
	await _until(func(): return not dlg.busy, 25.0, "balcony convo ends")
	dlg.play("random_c")
	await _until(func(): return not dlg.busy, 40.0, "random C plays")
	_tp(L, Vector3(8.4, 0, 1.3), Vector3(8.4, 0.5, 0.0))
	L.hole_spot.interact(L.player)
	await _wait(3.0)
	await _shot("12_crawling")
	await _until(func(): return game.level_id == "flesh47" and game.level != L and is_instance_valid(game.level), 40.0, "crawl loads Flat 47 (flesh)")
	var F = game.level
	await _until(func(): return F.player.controls, 30.0, "arrival cutscene ends")
	await _shot("13_flesh_arrive")
	# meet her: stand where she can be seen
	var mp: Vector3 = F.marta.global_position
	var spot := mp
	var best := -1.0
	var mc: Vector2i = F.marta.to_cell(mp)
	for dx in range(-4, 5):
		for dy in range(-4, 5):
			var c := mc + Vector2i(dx, dy)
			if not F.marta.grid.is_in_boundsv(c) or F.marta.grid.is_point_solid(c): continue
			var p: Vector3 = F.marta.cell_center(c)
			var d := p.distance_to(mp)
			if d < 2.5 or d > 6.0: continue
			var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.6, 0), mp + Vector3(0, 1.6, 0), 1)
			if F.get_world_3d().direct_space_state.intersect_ray(q).is_empty() and d > best:
				best = d; spot = p
	_check(best > 0.0, "found a spot in sight of her")
	_tp(F, spot, mp + Vector3(0, 1.6, 0))
	await _until(func(): return F._encountered, 6.0, "the encounter triggers")
	await _until(func(): return dlg.speaking == "socko", 15.0, "'What?'")
	await _shot("14_marta_maze")
	await _until(func(): return F.marta.state == "chase", 25.0, "she hunts after the encounter")
	# a noise elsewhere: she should go and look (once the chase is broken off)
	await _wait(1.0)
	await _shot("15_chase")
	for i in 12:
		await _wait(1.0)
		if game.level != F or F.cutscene: break
		print("    marta ", F.marta.state, " dist ", snappedf(F.marta.global_position.distance_to(F.player.global_position), 0.1))
	await _until(func(): return game.level != F or F.cutscene, 30.0, "she catches him (standing still)")
	await _until(func(): return game.level != F and game.level != null and game.level_id == "flesh47", 20.0, "caught: back to checkpoint")
	var F2 = game.level
	await _until(func(): return F2.player.controls, 15.0, "control after restart")
	_check(game.pistol.have, "pistol kept through the restart")
	# the way out
	F2.marta.active = false
	var ex: Vector3 = F2.exit_door.global_position + Vector3(0.475, 0, -1.0)
	_tp(F2, ex, ex + Vector3(0, 1.2, 2.0))
	F2.exit_door.interact(F2.player)
	await _wait(1.2)
	_check(F2.exit_door.is_open, "the real front door opens")
	_tp(F2, ex + Vector3(0, 0, 3.0), ex + Vector3(0, 1.4, 6.0))
	await _wait(2.0)
	await _shot("16_landing_48")
	await _until(func(): return root.get_children().any(func(n): return n.name == "Title") or (current_scene != null and current_scene.name == "Title"), 40.0, "finale returns to title")
	print("PLAYTHROUGH fails=%d shots=%d" % [fails, shots])
	quit()

func _tp(L, pos: Vector3, look_at_p: Vector3) -> void:
	L.player.global_position = pos
	L.player.velocity = Vector3.ZERO
	var d: Vector3 = look_at_p - (pos + Vector3(0, 1.62, 0))
	L.player.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))

func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1

func _until(cond: Callable, secs: float, what: String) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0:
		if cond.call():
			_check(true, what); return
		await process_frame
	_check(false, what + " (timed out)")

func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0 / Engine.time_scale:
		await process_frame

func _shot(name: String) -> void:
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	shots += 1
