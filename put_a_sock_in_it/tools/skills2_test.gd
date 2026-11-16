extends SceneTree
## The trees in Chapter 2 (docs/SKILLS.md), in the lobby: the one pool (earned from her letters,
## from a kill); Read People in the super's conversation; the Telekinetic Shove on one of the
## building's people; Telepathy showing them through the walls; Throw Voice drawing the listener;
## Coup de Grace on a reeling one, and Feed; Locksmith on maintenance's door; Regrowth and First
## Aid healing faster; Shade.
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/skills2_test.gd
var fails := 0
var game
var D
var S
var L
var P

func _initialize() -> void:
	await process_frame
	game = root.get_node("Game"); D = root.get_node("Dialogue")
	S = load("res://scripts/core/skills.gd")
	# ---- Read People: the conversation
	await _fresh({})
	game.points = 10; S.unlock("m_1"); S.unlock("m_talk"); S.unlock("m_people")
	await _until(func(): return D.choosing(), 30.0)
	var texts := []
	for b in D._choice_box.get_children(): texts.append(String(b.text))
	_check(texts.size() > 0 and texts.all(func(t): return t.contains("(")), "Read People: each answer says how it'll land (%s)" % (texts[0] if texts.size() else "-"))
	_check(texts.any(func(t): return t.contains("(a lie)")), "  and the lie is marked as a lie")
	D.stop()
	# ---- the pool: earned from her letters
	await _fresh({"ch2_talked": true})
	var p0: int = game.points
	L._letters()
	await _wait(0.3)
	D.stop()
	_check(game.points == p0 + 1, "her sister's letters: a point (%d -> %d)" % [p0, game.points])
	# ---- powers on the building's people
	game.points = 20
	for id in ["s_sinew", "s_tk", "s_sinew2", "s_shove", "s_telepathy", "s_voice", "s_reaper", "s_feed", "s_lungs", "s_quiet", "s_shade", "s_regrow"]: S.unlock(id)
	_check(S.has("s_reaper") and S.has("s_voice") and S.has("s_feed"), "the infection tree bought out of the one pool")
	var cook = L.people.cook
	cook.set_physics_process(false)
	await _place(Vector3(7.0, 3.2, 3.6), cook, Vector3(7.0, 3.2, 1.6))
	game.strain = 0.0
	var did: String = L.powers.use()
	_check(did == "shove" and cook._stagger > 0.0, "Telekinetic Shove on the cook: reeling (%s, %.1f)" % [did, cook._stagger])
	# Coup de Grace: a heavy blow with an edge on something reeling
	var H = L.hands
	H.heavy = true; H._prof = {"kind": "sharp", "dmg": 10.0, "knock": 1.0, "reach": 1.5}
	P.health = 0.4
	var p1: int = game.points
	cook.melee_hit(10.0, P.global_position, 1.0, H)
	await _wait(0.3)
	_check(cook.dead, "Coup de Grace: a heavy blade blow finishes it")
	_check(game.points == p1 + 1, "  it feeds: a point (%d -> %d)" % [p1, game.points])
	_check(P.health > 0.6, "  Feed: and it gives him back some of himself (health %.2f)" % P.health)
	H.heavy = false
	# Telepathy: them, through the walls
	P.set_view(0.0, 1.4)
	game.strain = 0.0
	did = L.powers.use()
	await _wait(0.1)
	var lit := 0
	for n in L.people.values():
		if not n.dead and n.global_position.distance_to(P.global_position) < 25.0:
			for mi in n.body.find_children("*", "MeshInstance3D", true, false):
				if (mi as MeshInstance3D).material_overlay != null: lit += 1; break
	_check(did == "listen" and lit > 0, "Telepathy: %d of them show through the walls" % lit)
	# Throw Voice: the listener goes to where he threw it
	var li = L.people.listener
	li.global_position = Vector3(19.5, 3.2, 7.0)
	await _place(Vector3(10.0, 3.2, 7.0), null, Vector3(14.5, 3.6, 7.0))
	P.crouching = true
	game.strain = 0.0
	did = L.powers.use()
	var heard := [false]
	await _until(func(): heard[0] = heard[0] or li._noise_t > 0.0; return li.objective == "investigate", 3.0)
	_check(did == "voice" and (li.objective == "investigate" or heard[0]), "Throw Voice: the listener hears it and goes to look (%s, %s, heard %s)" % [did, li.objective, heard[0]])
	P.crouching = false
	# Shade, Regrowth
	_check(is_equal_approx(game.stat("seen_dark"), 0.5), "Shade: seen half as far in the dark")
	P.health = 0.5; P._hurt_t = 20.0
	await _wait(1.0)
	var regrow: float = P.health - 0.5
	_check(regrow > 0.07, "Regrowth: heals 2.5x (%.3f a second)" % regrow)
	# ---- Locksmith
	await _fresh({"ch2_talked": true})
	game.points = 10
	for id in ["m_1", "m_2", "m_training", "m_locks", "m_aid"]: S.unlock(id)
	var md = L.built.doors.maint
	_check(md.locked, "maintenance is locked")
	await _place(Vector3(19.15, 0, 6.8), null, Vector3(19.15, 1.2, 6.0))
	md.interact(P)
	await _until(func(): return not md.locked, 10.0)
	await _wait(1.0)
	_check(not md.locked and md.is_open and game.flag("ch2_unlocked_maint"), "Locksmith: he works maintenance's lock open, no key, no crowbar")
	# First Aid: crouched and still, out of it
	L.set_cutscene(false)
	P.health = 0.5; P._hurt_t = 20.0; P.crouching = true; P.velocity = Vector3.ZERO
	await _wait(1.0)
	_check(P.health - 0.5 > 0.12, "First Aid: crouched and still, he heals four times as fast (%.3f a second)" % (P.health - 0.5))
	printerr("SKILLS2_TEST fails=%d" % fails)
	quit()

func _fresh(flags: Dictionary) -> void:
	await _until(func(): return not game.busy, 30.0)
	game.new_game()
	await _until(func(): return not game.busy, 10.0)
	for k in game.flags.keys(): game.flags.erase(k)
	for k in flags: game.flags[k] = flags[k]
	game.rel = {}; game.inventory = {}; game.skills = {}; game.points = 0; game.memories = 0; S.apply()
	game.change_level("lobby", {"card": false, "fade": 0.01})
	await _until(func(): return game.level != null and is_instance_valid(game.level) and game.level.has_method("set_power") and not game.busy, 30.0)
	await _wait(0.5)
	L = game.level; P = L.player
	game._black.visible = false

func _place(at: Vector3, who, look: Vector3) -> void:
	D.stop(); L.set_cutscene(false)
	P.global_position = at; P.velocity = Vector3.ZERO
	if who: who.global_position = look - Vector3(0, look.y - at.y, 0)
	await _wait(0.2)
	var tgt: Vector3 = (who.eye() - Vector3(0, 0.3, 0)) if who else look
	var d: Vector3 = tgt - P.cam.global_position
	P.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	await _wait(0.2)

func _until(f: Callable, secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not f.call() and Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame

func _check(ok: bool, what: String) -> void:
	printerr(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1

func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame
