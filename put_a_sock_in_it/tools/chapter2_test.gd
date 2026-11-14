extends SceneTree
## Chapter 2 (docs/CHAPTER2.md), checked:
##   the super's conversation through each approach, and what it leaves (disposition, the key,
##   what he does afterwards); maintenance, the breaker, the first floor's lights; the fuse box,
##   the lift to the second floor; the crowbar and the hatch; the meat on the stairs; the boiler
##   and the heat letting go of 27's door; the thing in the bath, the other way; 27; the
##   inhabitants on their own (the hunter after a resident, the listener after a noise, the
##   water taking what walks in it); a checkpoint bringing the building back as he left it.
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/chapter2_test.gd
var fails := 0
var game
var D
var L
var P
func _initialize() -> void:
	await process_frame
	game = root.get_node("Game"); D = root.get_node("Dialogue")
	# ---- the conversation, five ways
	for plan in [["cooperative", "cooperative", "cooperative", "cooperative"], ["neutral", "neutral", "neutral", "neutral"],
			["suspicious", "suspicious", "suspicious", "suspicious"], ["hostile", "hostile", "hostile", "hostile"], ["deceptive", "deceptive", "deceptive", "deceptive"]]:
		await _fresh()
		await _until(func(): return D.choosing(), 25.0)
		for a in plan:
			await _until(func(): return D.choosing() or not D.busy, 25.0)
			if not D.choosing(): break
			_pick(a)
			await _wait(0.4)
		await _until(func(): return not D.busy and game.flag("ch2_talked"), 30.0)
		var disp: String = game.disposition("super")
		printerr("  (rel ", game.rel.get("super"), ")")
		var want: String = {"cooperative": "cooperative", "neutral": "neutral", "suspicious": "suspicious", "hostile": "hostile", "deceptive": "deceived"}[plan[0]]
		_check(disp == want, "talking %s: he's %s (%s)" % [plan[0], want, disp])
		var has_key: bool = game.count("maint_key") > 0
		_check(has_key == (want in ["cooperative", "deceived"]), "  and the maintenance key: %s" % has_key)
		if plan[0] == "suspicious": _check(game.rel_of("kurt").get("known", []).has("wife_tula"), "  asked about his wife: 'at her sister's, in Tula'")
		await _wait(3.0)
		var s = L.super_npc
		match want:
			"hostile":
				_check(s.hates(P) and s.objective in ["hunt_kurt", "attack", "sabotage"], "  hostile: he comes for Kurt (%s)" % s.objective)
				s.set_physics_process(false)
			"suspicious": _check(s.objective in ["follow", "relock", "investigate"], "  suspicious: he keeps Kurt in sight (%s)" % s.objective)
			_: _check(not s.hates(P) and s.objective in ["work", "relock", ""], "  %s: he goes about his business (%s)" % [want, s.objective])
	# ---- the way up (the cooperative run's key, carried in by flag)
	await _fresh({"ch2_talked": true})
	game.rel_of("super").trust = 4.0; game.disposition("super"); L._super_react()
	game.add_item("maint_key")
	var md = L.built.doors.maint
	await _go(Vector3(19.15, 0, 6.8), Vector3(19.15, 1.2, 6.0))
	md.interact(P)
	await _wait(1.2)
	_check(not md.locked and md.is_open, "the super's key opens maintenance")
	L.set_power(true, P)
	await _wait(0.5)
	_check(L.power_on and L.lit(Vector3(10.0, FH + 1.5, 7.0)), "the breaker on: the first floor's lights come on")
	# the crawler in the water in 15 (it hides in the dark; the water's live now)
	await _until(func(): return game.flag("ch2_dead_crawler_f1") or not L.people.has("crawler_f1") or L.people.crawler_f1.dead, 12.0)
	var c1 = L.people.get("crawler_f1")
	_check(c1 == null or c1.dead, "the thing that lives in the dark in 15 didn't like the mains in the water")
	# fuses: LIGHT's into LIFT, the lift up to the second floor
	L._fuse_use("LIGHT")
	_check(game.count("fuse") == 1 and not L.lit(Vector3(10.0, FH + 1.5, 7.0)), "the LIGHT fuse out: the first floor goes dark")
	L._fuse_use("LIFT")
	_check(L.lift.is_powered(), "in LIFT: the lift has power")
	P.global_position = L.lift.car.global_position + Vector3(0, 0.1, 0)
	await _wait(0.4)
	await L._ride(2)
	await _wait(0.5)
	_check(absf(P.global_position.y - FH * 2.0) < 0.6, "the lift takes him to the second floor (y %.2f)" % P.global_position.y)
	# the boiler: BOILER needs a good fuse (the office drawer's), the mains, then lighting
	L._fuse_use("BOILER")          # the burnt one out
	game.add_item("fuse")          # (the drawer)
	L._fuse_use("BOILER")
	_check(L.fuses.BOILER == "good", "a good fuse in BOILER")
	L.light_boiler()
	await _until(func(): return L.door27 == null or L.door27.gone, 40.0)
	_check(L.door27 == null or L.door27.gone, "the boiler lit, the heat lets the meat go of 27's door")
	_check(game.flag("ch2_defy_bath"), "  (the way Socko didn't want)")
	# save and load: what he did stays done
	game.checkpoint()
	game.restart_level()
	await _until(func(): return game.level != null and game.level != L and not game.busy, 30.0)
	await _wait(1.5)
	L = game.level; P = L.player
	_check(L.power_on and L.fuses.LIFT == "good" and L.boiler_on and (L.door27 == null), "after a checkpoint: the mains, the fuses, the boiler, 27's door, as he left them")
	_check(game.disposition("super") == "cooperative" and game.count("maint_key") > 0, "  and the super, and the key (%s, %s, inv %s)" % [game.disposition("super"), game.rel.get("super"), game.inventory])
	# 27
	var d27 = L.built.doors.flat27
	d27.set_open(true)
	await _until(func(): return game.level != L and game.level != null and game.level.has_method("ring") and not game.busy, 40.0)
	_check(game.flag("ch2_reached_27") and game.level.has_method("ring"), "into 27: the cathedral (tools/cathedral_test.gd goes on from there)")
	# ---- the other ways: the crowbar and the hatch; the meat on the stairs; the bath
	await _fresh({"ch2_talked": true})
	_check(L.built.closet_doors[0].locked, "the ladder's closet on the ground floor is locked")
	_check(L._ladder_up_prompt(1) == "", "the hatch to the second floor: bolted, and nothing to open it with")
	L.get_node("World/Take_crowbar").interact(P)
	_check(game.count("crowbar") == 1, "the crowbar, from the cook's kitchen")
	L._climb(1, 2)
	_check(L.hatch_open, "the crowbar pries the hatch open: the ladder goes up to the second floor")
	var before: int = _reachable(Vector3(12.0, 0.0, 7.0), load("res://scripts/levels/chapter2/lobby_build.gd").centre("flat24"))
	for i in 12: L.barricade.shot(L.barricade.global_position + Vector3(0, 1.2, 0), Vector3.FORWARD)
	await _wait(2.0)
	var after: int = _reachable(Vector3(12.0, 0.0, 7.0), load("res://scripts/levels/chapter2/lobby_build.gd").centre("flat24"))
	var pth: PackedVector3Array = NavigationServer3D.map_get_path(L.get_world_3d().navigation_map, Vector3(12.0, 0.0, 7.0), load("res://scripts/levels/chapter2/lobby_build.gd").centre("flat24"), true)
	printerr("  (path ends ", pth[pth.size() - 1] if pth.size() else "none", "; barricade ", L.barricade, ")")
	_check(before == 0 and after == 1, "shot through, the meat on the stairs lets the second floor be walked to (%d -> %d)" % [before, after])
	for i in 8: L.bath.shot(L.bath.global_position, Vector3.FORWARD)
	await _until(func(): return L.door27 == null or L.door27.gone, 8.0)
	_check(L.bath.dead and (L.door27 == null or L.door27.gone), "the thing in the bath killed: 27's door lets go")
	_check(game.flag("ch2_obey_bath"), "  (the way Socko wanted)")
	# ---- on their own
	await _fresh({"ch2_talked": true})
	var hu = L.people.hunter; var lw = L.people.laundress
	var hit := [false]
	hu.attacked.connect(func(_w, t): if t == lw: hit[0] = true)
	_check(hu.asleep, "the hunter starts asleep (the lobby is somewhere to begin)")
	hu.wake()
	hu.global_position = Vector3(4.2, 0, 8.8)
	await _until(func(): return hit[0], 20.0)
	_check(hit[0], "the hunter goes for the laundress, Kurt or no Kurt")
	var li = L.people.listener; var ra = L.people.rearranger
	li.global_position = Vector3(11.0, FH, 7.0)
	game.make_noise(Vector3(12.0, FH, 4.0), 0.5)
	await _wait(0.8)
	_check(li.objective == "investigate", "the listener goes to a noise it didn't make (%s)" % li.objective)
	P.crouching = true
	P.global_position = Vector3(3.0, FH, 7.0)
	await _wait(1.0)
	_check(not li.sees(P), "it can't see him (it has no eyes)")
	print(L.find_children("*", "DevOverlay", true, false).size() > 0)
	printerr("CHAPTER2_TEST fails=%d" % fails)
	quit()

const FH := 3.2

## A fresh chapter: no flags but `flags`, the level loaded, the conversation running (or not).
func _fresh(flags := {}) -> void:
	game.new_game()
	for k in game.flags.keys(): game.flags.erase(k)
	for k in flags: game.flags[k] = flags[k]
	game.rel = {}; game.inventory = {}
	await _until(func(): return not game.busy, 10.0)
	game.change_level("lobby", {"card": false, "fade": 0.01})
	await _until(func(): return game.level != null and is_instance_valid(game.level) and game.level.has_method("set_power") and not game.busy, 30.0)
	await _wait(0.5)
	L = game.level; P = L.player
	game._black.visible = false

func _pick(approach: String) -> void:
	var i := 0
	for o in D._options:
		if String(o.get("approach", "")) == approach and not (D._choice_box.get_child(i) as Button).disabled: D.pick(i); return
		i += 1
	D.pick(0)

func _go(at: Vector3, look: Vector3) -> void:
	D.stop(); L.set_cutscene(false)
	P.global_position = at; P.velocity = Vector3.ZERO
	await _wait(0.2)
	var d: Vector3 = look - P.cam.global_position
	P.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	await _wait(0.2)

func _reachable(a: Vector3, b: Vector3) -> int:
	var map = L.get_world_3d().navigation_map
	var p: PackedVector3Array = NavigationServer3D.map_get_path(map, a, b, true)
	if p.is_empty(): return 0
	var e: Vector3 = p[p.size() - 1]
	return 1 if Vector2(e.x - b.x, e.z - b.z).length() < 1.5 and absf(e.y - b.y) < 0.8 else 0

func _until(f: Callable, secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not f.call() and Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame

func _check(ok: bool, what: String) -> void:
	printerr(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1

func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame
