extends SceneTree
## Flat 27, the cathedral (docs/CATHEDRAL.md), checked:
##   the nave loops (facing the altar past the middle: back two bays); the bells rung wrong (dead,
##   starts again) and right (feet, hand, side: the loop lets go); walking it backwards (through);
##   meeting him; each thing Kurt can do: drive the nail (the hammer, three strikes), pull the
##   nails (he comes down), walk away; the door behind the altar ends the chapter.
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/cathedral_test.gd
var fails := 0
var game
var D
var L
var P

func _initialize() -> void:
	await process_frame
	game = root.get_node("Game"); D = root.get_node("Dialogue")
	# ---- the loop
	await _fresh()
	_check(not L.loop_broken, "the nave starts looping")
	P.set_view(0.0, 0.0)
	P.global_position = Vector3(0.0, 0.0, -25.0)
	await _wait(0.2)
	P.global_position = Vector3(0.0, 0.0, -27.0)
	await _wait(0.2)
	_check(P.global_position.z > -20.0, "facing the altar past the middle: back two bays (z %.1f)" % P.global_position.z)
	# ---- the bells: wrong, then right
	L.ring("MANUS")
	_check(L._bells.is_empty() and not L.loop_broken, "MANUS first: the bell clanks dead, nothing")
	L.ring("PEDES"); L.ring("MANUS")
	_check(not L.loop_broken and L._bells.size() == 2, "feet, hand: two rung")
	L.ring("LATUS")
	_check(L.loop_broken and game.flag("c27_broken_bells"), "feet, hand, side: the loop lets go")
	D.stop()
	P.global_position = Vector3(0.0, 0.0, -27.0); P.set_view(0.0, 0.0)
	await _wait(0.2)
	_check(P.global_position.z < -26.5, "and now the nave goes on (z %.1f)" % P.global_position.z)
	# ---- backwards
	await _fresh()
	P.set_view(PI, 0.0)
	P.global_position = Vector3(0.0, 0.0, -27.0)
	await _wait(0.2)
	_check(P.global_position.z < -26.5, "facing the door, it doesn't send him back")
	P.global_position = Vector3(0.0, 0.0, -41.0)
	await _wait(0.2)
	_check(L.loop_broken and game.flag("c27_broken_backwards"), "walked backwards past the middle: through")
	# ---- him: the nail
	await _meet_and_choose(["cooperative", "cooperative"])
	_check(L._decided == "nail", "asked what he wants, took the nail")
	L._strike()
	_check(L._strikes == 0, "no hammer: Socko says use the hammer")
	D.stop()
	L.world.get_node("Take_hammer").interact(P)
	_check(game.count("hammer") == 1, "the hammer, at his feet")
	for i in 3:
		L._strike()
		await _wait(0.4)
	await _until(func(): return game.flag("c27_nailed"), 5.0)
	_check(game.flag("c27_nailed") and game.flag("ch2_obey_nail"), "three strikes: the last nail in (and Socko's way)")
	D.stop()
	await _until(func(): return not L.cutscene, 30.0)
	L._leave()
	await _until(func(): return game.flag("ch2_done"), 30.0)
	_check(game.flag("ch2_done"), "the door behind the altar: the chapter ends")
	# ---- him: getting him down
	await _fresh({"c27_loop_broken": true})
	await _meet_and_choose(["cooperative", "hostile"])
	_check(L._decided == "free", "chose to get him down")
	game.add_item("hammer")
	L._pull("hand")
	L._pull("feet")
	await _until(func(): return game.flag("c27_freed"), 5.0)
	await _wait(1.6)
	_check(game.flag("c27_freed") and game.flag("ch2_defy_nail") and L.stig.position.y < 0.9, "both nails out: he comes down (y %.2f)" % L.stig.position.y)
	# ---- him: walking away
	await _fresh({"c27_loop_broken": true})
	await _meet_and_choose(["cooperative", "neutral"])
	_check(L._decided == "leave", "chose to go")
	D.stop(); L.set_cutscene(false)
	L._leave()
	await _until(func(): return game.flag("ch2_done"), 30.0)
	_check(game.flag("c27_left") and game.flag("ch2_done"), "walked away: kept, and the chapter ends")
	printerr("CATHEDRAL_TEST fails=%d" % fails)
	quit()

func _fresh(flags := {}) -> void:
	await _until(func(): return not game.busy, 30.0)
	game.new_game()
	await _until(func(): return not game.busy, 10.0)
	for k in game.flags.keys(): game.flags.erase(k)
	for k in flags: game.flags[k] = flags[k]
	game.inventory = {}
	game.change_level("cathedral", {"card": false, "fade": 0.01})
	await _until(func(): return game.level != null and is_instance_valid(game.level) and game.level.has_method("ring") and not game.busy, 30.0)
	await _wait(0.5)
	L = game.level; P = L.player
	game._black.visible = false
	D.stop(); L.set_cutscene(false)

func _meet_and_choose(plan: Array) -> void:
	D.stop(); L.set_cutscene(false)
	P.global_position = Vector3(0.0, 0.0, -54.0); P.set_view(0.0, 0.0)
	await _wait(0.3)
	P.global_position = Vector3(0.0, 0.0, -55.2)
	await _until(func(): return D.choosing(), 40.0)
	for a in plan:
		await _until(func(): return D.choosing(), 40.0)
		_pick(a)
		await _wait(0.5)
	await _until(func(): return L._decided != "", 40.0)

func _pick(approach: String) -> void:
	var i := 0
	for o in D._options:
		if String(o.get("approach", "")) == approach: D.pick(i); return
		i += 1
	D.pick(0)

func _until(f: Callable, secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not f.call() and Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame

func _check(ok: bool, what: String) -> void:
	printerr(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1

func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame
