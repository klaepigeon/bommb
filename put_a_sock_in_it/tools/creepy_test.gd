extends SceneTree
## The lobby's new wrongness: the peepholes (a live fisheye view of the room beyond; something
## in there that hates him comes to the lens and the door takes a blow) and the chairs that move
## while he isn't looking (nearer, facing him, never while seen, never in a doorway).
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/creepy_test.gd -- out=<dir>
var fails := 0
var game
var D
var L
var P
var out := "user://creepy_test"

func _initialize() -> void:
	await process_frame
	for a in OS.get_cmdline_user_args(): if a.begins_with("out="): out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	game = root.get_node("Game"); D = root.get_node("Dialogue")
	await _fresh()
	var holes: Array = L.world.find_children("Peephole_*", "", false, false)
	_check(holes.size() >= 12, "a peephole in every flat's front door (%d)" % holes.size())
	# ---- a look into 14 (empty-ish): the view is the room beyond, live
	var ph = L.world.get_node("Peephole_flat14")
	P.global_position = ph.global_position + Vector3(0, -1.55, 0.5) * Vector3(1, 1, -1); P.velocity = Vector3.ZERO
	ph.interact(P)
	await _wait(0.6)
	var vp: SubViewport = L.find_children("*", "SubViewport", false, false)[0] if L.find_children("*", "SubViewport", false, false).size() else null
	var cam: Camera3D = vp.get_child(0) if vp else null
	_check(L.peeping == "flat14" and L.cutscene, "putting his eye to it: he's looking (and standing still)")
	_check(cam != null and load("res://scripts/levels/chapter2/lobby_build.gd").in_room("flat14", cam.global_position), "the lens looks from inside 14")
	root.get_viewport().get_texture().get_image().save_png(out.path_join("peephole_14.png"))
	L.peep_close = true
	await _wait(0.3)
	_check(L.peeping == "" and not L.cutscene and L.find_children("*", "SubViewport", false, false).is_empty(), "stepping back: the view's gone, he can move")
	# ---- 12, the cook's kitchen, with the cook after him: it comes to the lens
	var cook = L.people.cook
	cook.prof["hostile_to"] = ["kurt"]
	cook.global_position = Vector3(8.0, 3.2, 3.0)
	ph = L.world.get_node("Peephole_flat12")
	P.global_position = Vector3(ph.global_position.x, 3.2, 6.6); P.velocity = Vector3.ZERO
	await _wait(0.2)
	var f0: float = game.fear
	ph.interact(P)
	await _wait(1.8)
	root.get_viewport().get_texture().get_image().save_png(out.path_join("peephole_12_coming.png"))
	await _until(func(): return L.peeping == "", 20.0)
	_check(L.peeping == "" and game.fear > f0 + 0.3, "the cook notices, comes to the door, its face at the glass, the door takes a blow (fear %.2f -> %.2f)" % [f0, game.fear])
	# ---- the chairs, while he isn't looking
	await _fresh()
	var w: Array = L.watchers.filter(func(x): return x[1] == "flat2")[0]
	var chair: Node3D = w[0]
	var c0 := chair.global_position
	# he's in the corridor, his back to 2
	P.global_position = Vector3(9.0, 0, 7.0); P.set_view(0.0, 0.0)       # (looking -z: south, away from 2)
	await _wait(0.2)
	for i in 6: L._creep()
	var moved := chair.global_position.distance_to(c0)
	_check(moved > 0.3, "his back turned: the chair in 2 has moved (%.2f m)" % moved)
	_check(chair.global_position.distance_to(P.global_position) < c0.distance_to(P.global_position), "  nearer him")
	var r = load("res://scripts/levels/chapter2/lobby_build.gd").room("flat2")
	_check(chair.global_position.x > float(r[3]) and chair.global_position.x < float(r[4]) and chair.global_position.z > 8.0, "  and still in its room")
	# looking at it: it stays put
	var c1 := chair.global_position
	var d: Vector3 = chair.global_position + Vector3(0, 0.5, 0) - P.cam.global_position
	P.global_position = Vector3(9.5, 0, 9.0)
	await _wait(0.1)
	d = chair.global_position + Vector3(0, 0.5, 0) - P.cam.global_position
	P.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	await _wait(0.2)
	for i in 6: L._creep()
	_check(chair.global_position.distance_to(c1) < 0.01, "looking right at it: it doesn't move")
	# ---- 27: once the nave lets him through, they come down while he isn't looking
	await _until(func(): return not game.busy, 30.0)
	game.new_game()
	await _until(func(): return not game.busy, 10.0)
	game.flags["c27_loop_broken"] = true; game.flags["c27_entered"] = true
	var t1 := Time.get_ticks_msec()
	while not (game.level != null and is_instance_valid(game.level) and game.level.has_method("ring") and not game.busy) and Time.get_ticks_msec() - t1 < 60000:
		if not game.busy and not (game.level != null and is_instance_valid(game.level) and game.level.has_method("ring")):
			game.change_level("cathedral", {"card": false, "fade": 0.01})
		await process_frame
	var C = game.level; var CP = C.player
	D.stop(); C.set_cutscene(false); game._black.visible = false
	CP.global_position = Vector3(0, 0, -30.0); CP.set_view(0.0, 0.0)          # (facing the altar: they stay up)
	await _wait(2.0)
	_check(C._congregation.filter(func(f): return f.get_meta("down", false)).size() == 0, "watched, they stay up in the vault")
	CP.set_view(PI, 0.0)                                                        # (his back to the altar)
	await _wait(8.0)
	var down: Array = C._congregation.filter(func(f): return f.get_meta("down", false))
	_check(down.size() >= 6, "his back turned: they've come down (%d of %d)" % [down.size(), C._congregation.size()])
	_check(down.all(func(f): return f.global_position.z < -40.0 and f.global_position.y < 0.5), "  into the front pews")
	CP.set_view(0.0, 0.05)
	await _wait(0.5)
	root.get_viewport().get_texture().get_image().save_png(out.path_join("front_pews.png"))
	printerr("CREEPY_TEST fails=%d" % fails)
	quit()

func _fresh() -> void:
	await _until(func(): return not game.busy, 30.0)
	game.new_game()
	var t0 := Time.get_ticks_msec()
	while not (game.level != null and is_instance_valid(game.level) and game.level.has_method("set_power") and not game.busy) and Time.get_ticks_msec() - t0 < 60000:
		if not game.busy and not (game.level != null and is_instance_valid(game.level) and game.level.has_method("set_power")):
			game.flags["ch2_talked"] = true
			game.change_level("lobby", {"card": false, "fade": 0.01})
		await process_frame
	await _wait(0.5)
	L = game.level; P = L.player
	game._black.visible = false
	D.stop(); L.set_cutscene(false)
	game.fear = 0.0

func _until(f: Callable, secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not f.call() and Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame

func _check(ok: bool, what: String) -> void:
	printerr(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1

func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame
