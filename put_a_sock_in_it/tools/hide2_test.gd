extends SceneTree
## Hiding in Chapter 2 (docs/CHAPTER2.md): the wardrobes in the building; getting in with the
## hunter after him and watching (it has him out); getting in out of its sight (it loses him and
## goes to look where he was, and doesn't hit the wardrobe); the listener stood by his wardrobe
## (he breathes, it hears; he holds his breath, it doesn't).
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/hide2_test.gd
var fails := 0
var game
var D
var L
var P

func _initialize() -> void:
	await process_frame
	game = root.get_node("Game"); D = root.get_node("Dialogue")
	await _fresh()
	_check(L.hide_spots.size() == 6, "six wardrobes to hide in, across the floors (%d)" % L.hide_spots.size())
	var on_floors := {}
	for w in L.hide_spots: on_floors[int(round(w.global_position.y / 3.2))] = true
	_check(on_floors.size() == 3, "on all three floors")
	# ---- seen getting in: it has him out
	var spot = L.hide_spots[0]          # the laundry
	var hu = L.people.hunter
	hu.wake(); hu.prof["hostile_to"] = ["kurt", "residents"]
	hu.global_position = spot.front() + Vector3(0, 0, -4.0)
	hu.look_at(spot.front() + Vector3(0, 1.0, 0), Vector3.UP); hu.rotation.x = 0.0
	hu.awareness = 1.0; hu.target = P; hu.objective = "attack"
	P.global_position = spot.front(); P.velocity = Vector3.ZERO
	await _wait(0.1)
	spot.interact(P)
	_check(P.hidden_in == spot and hu.saw_hide == spot, "in, with the hunter watching: it saw")
	await _until(func(): return P.hidden_in == null, 12.0)
	_check(P.hidden_in == null, "and it has him out")
	# ---- unseen: it loses him
	await _fresh()
	spot = L.hide_spots[0]
	hu = L.people.hunter
	hu.wake(); hu.prof["hostile_to"] = ["kurt", "residents"]
	hu.global_position = Vector3(15.0, 0, 11.0)          # (in 3, through the walls)
	hu.awareness = 1.0; hu.target = P; hu.objective = "attack"
	P.global_position = spot.front(); P.velocity = Vector3.ZERO
	await _wait(0.1)
	var h0: float = P.health
	spot.interact(P)
	_check(P.hidden_in == spot and hu.saw_hide == null, "in, out of its sight: it didn't see")
	await _wait(6.0)
	_check(P.hidden_in == spot and P.health >= h0, "it loses him: he's still in there, unhurt (%.2f)" % P.health)
	_check(hu.objective != "attack" or hu.target != P, "and it's not after him any more (%s)" % hu.objective)
	spot.interact(P)
	# ---- the listener by his wardrobe
	await _fresh()
	spot = L.hide_spots[2]                # the first floor, 11
	var li = L.people.listener
	P.global_position = spot.front(); P.velocity = Vector3.ZERO
	await _wait(0.1)
	spot.interact(P)
	li.global_position = spot.front() + Vector3(0.3, 0, 0.2); li.set_physics_process(true)
	li.objective = "investigate"; li._noise_at = spot.front(); li._noise_t = 30.0
	game.fear = 0.0
	Input.action_press("hold_breath")          # (the real input: Nerve keeps his breath)
	var held_ok := true
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000:
		await process_frame
		li.global_position = spot.front() + Vector3(0.3, 0, 0.2)
		if li.saw_hide != null or P.hidden_in != spot: held_ok = false
	_check(held_ok and P.hidden_in == spot, "holding his breath, the listener stood right there doesn't hear him")
	Input.action_release("hold_breath")
	game.fear = 1.0
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000 and P.hidden_in == spot:
		await process_frame
		if P.hidden_in == spot: li.global_position = spot.front() + Vector3(0.3, 0, 0.2)
	_check(P.hidden_in == null, "breathing, scared, it hears him in there, and has him out")
	printerr("HIDE2_TEST fails=%d" % fails)
	quit()

func _fresh() -> void:
	await _until(func(): return not game.busy, 30.0)
	game.new_game()
	await _until(func(): return not game.busy, 10.0)
	for k in game.flags.keys(): game.flags.erase(k)
	game.flags["ch2_talked"] = true
	game.rel = {}; game.inventory = {}
	# (until it's the lobby: a change asked for while the last is still loading is ignored)
	var t0 := Time.get_ticks_msec()
	while not (game.level != null and is_instance_valid(game.level) and game.level.has_method("set_power") and not game.busy) and Time.get_ticks_msec() - t0 < 60000:
		if not game.busy and not (game.level != null and is_instance_valid(game.level) and game.level.has_method("set_power")):
			game.change_level("lobby", {"card": false, "fade": 0.01})
		await process_frame
	await _wait(0.5)
	L = game.level; P = L.player
	game._black.visible = false
	D.stop(); L.set_cutscene(false)

func _until(f: Callable, secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not f.call() and Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame

func _check(ok: bool, what: String) -> void:
	printerr(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1

func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame
