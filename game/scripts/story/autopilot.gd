extends Node
## Plays the game by itself through the same controls and hotspots a player uses, then checks it.
##   Scene A: walks the flat, every line in the owner's order, the door shut, the wardrobe, the hole.
##   The town (--route=talk|kill|sneak): one of the ways out, start to finish, and that it was
##   that way out. Movement in the town is by teleport between spots (the walking is tested in
##   the flat); every action goes through the real hotspots, weapon and skill purchases.
## With --shots=<dir>, saves a frame per line and at each beat.

var main
var shots := ""
var route := "talk"

const EXPECTED_A := ["door_1", "door_2", "see_flat", "see_marta", "examine", "boxes", "marta_q",
	"little_bird", "gasp", "smarts", "hey_buddy", "wtf", "who_me", "who_are_you", "im_socko",
	"kurt_sounds", "dont_know", "got_nothing", "too_fast", "wont_open", "locked", "thanks",
	"welcome", "like_helping", "what_is_that", "dunno", "know_anything", "can_do_this", "smell"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     # keeps going while a document's open (that pauses)
	shots = main.args.get("shots", "")
	route = main.args.get("route", "talk")
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
		Speech.line_started.connect(func(_s, _t): _shot_later("line_%02d" % Speech.history.size(), 0.6))
	main.hud.controls.autopilot = true
	if main.args.has("fast"):
		Engine.time_scale = 4.0
	if main.args.has("touch"):
		_touch()
	elif main.args.has("spin"):
		_spin()
	elif main.args.has("super"):
		_super()
	elif main.args.has("poses"):
		_poses()
	elif main.args.get("start", "") in ["flat48", "landing"]:
		_flat48.call_deferred()
	elif main.args.get("start", "") == "town":
		_town.call_deferred()
	else:
		_run()

func _fail(why: String) -> void:
	var st: String = main.scene.stage
	print("AUTOTEST FAIL: ", why, "  (stage ", st, ", at ", main.player.global_position, ")")
	print("lines said: ", Speech.history)
	if main.flat.building.the_super:
		var su: Super = main.flat.building.the_super
		print("super at ", su.global_position, " mode ", su.mode, " t ", su.mode_t, " vel ", su.velocity, " floor ", su.is_on_floor(), " next ", su.building.next_step(su.global_position, su.building.landing_point(su.patrol_to)), " proc ", su.can_process())
	print("paused ", get_tree().paused, " can_move ", main.player.can_move, " busy ", main.chapter.busy if main.chapter else null, " nuggets ", Game.nuggets, " flags ", Game.flags)
	if main.chapter:
		for m in [main.chapter.porter, main.chapter.lamplighter, main.chapter.marta]:
			print("  ", m.id, " state ", m.state, " at ", m.global_position)
	get_tree().quit(1)

func _until(cond: Callable, seconds: float, what: String) -> bool:
	var t := 0.0
	while not cond.call():
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if t > seconds:
			_fail("timed out waiting for " + what)
			return false
	return true

func _stage(s: String) -> bool:
	return await _until(func(): return main.scene.stage == s, 150.0, "stage " + s)

func _walk(points: Array) -> bool:
	var p: Player = main.player
	for target in points:
		var t := 0.0
		while true:
			await get_tree().physics_frame
			var d: Vector3 = target - p.global_position
			d.y = 0
			if d.length() < 0.3:
				break
			if not p.can_move:
				main.hud.controls.autopilot_move = Vector2.ZERO
				continue
			p.rotation.y = lerp_angle(p.rotation.y, atan2(-d.x, -d.z), 0.5)
			main.hud.controls.autopilot_move = Vector2(0, -1)
			t += get_physics_process_delta_time()
			if t > 25.0:
				main.hud.controls.autopilot_move = Vector2.ZERO
				_fail("stuck walking to %s" % target)
				return false
	main.hud.controls.autopilot_move = Vector2.ZERO
	return true

## Aim at a point and press USE once the crosshair finds something usable.
func _use(point: Vector3, want_prompt := "") -> bool:
	var p: Player = main.player
	for i in 300:
		await get_tree().physics_frame
		if not p.can_move:
			continue
		p.face(point)
		if p.focus and p.focus.enabled and (want_prompt == "" or p.focus.prompt.begins_with(want_prompt)):
			p.try_interact()
			return true
	_fail("couldn't use the thing at %s (want '%s', focus %s)" % [point, want_prompt, p.focus.prompt if p.focus else "none"])
	return false

func _idle(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout

# --- Scene A -------------------------------------------------------------------------------------

func _run() -> void:
	var P := Flat47.POINTS
	if not await _stage("explore"):
		return
	if shots != "":
		_shot_later("01_hallway_entry", 0.2)
	if not await _walk([Vector3(9.4, 0, 4.5), P["hall"], P["hall_west"], P["living_in"]]):
		return
	while not Speech.history.has("see_marta") or main.scene.busy:
		main.player.face(main.marta.head.global_position)
		await get_tree().physics_frame
	if shots != "":
		_shot_later("02_marta", 0.1)
		await get_tree().create_timer(0.5).timeout
	if not await _walk([P["approach"], P["near_marta"]]):
		return
	if not await _use(main.marta.head.global_position + Vector3(0, -0.2, 0), "Examine"):
		return
	if not await _stage("wake"):
		return
	if not await _stage("explore"):
		return
	if shots != "":
		main.player.face(main.player.global_position + Vector3(0, -1.0, -0.6))
		await get_tree().create_timer(0.3).timeout
		await _shot("03_look_down")
	# the door they came in by is shut now
	if not await _walk([P["near_marta"], P["approach"], P["by_door"]]):
		return
	if not await _use(main.flat.room_door.handle_position(), "Open"):
		return
	if not await _stage("scene_a_done"):
		return
	if absf(main.flat.room_door.angle) > 0.1:
		_fail("the living room door isn't shut")
		return
	for n in main.flat.flat_nuggets:
		main.player.global_position = Vector3(n.global_position.x, 0, n.global_position.z)
		await _idle(0.2)
	if Game.nuggets != 2:
		_fail("expected 2 nuggets in the flat, have %d" % Game.nuggets)
		return
	main.player.global_position = Vector3(3.35, 0, 3.8)
	await _idle(0.2)
	for i in 3:
		if not await _use(main.flat.wardrobe.global_position + Vector3(0, 1.0, -0.3), "Push"):
			return
		await _idle(1.4)
	if not await _stage("hole_open"):
		return
	if Speech.history != EXPECTED_A:
		_fail("Scene A lines out of order or missing:\n  expected %s\n  got      %s" % [EXPECTED_A, Speech.history])
		return
	print("AUTOTEST: Scene A ok, %d lines in order" % Speech.history.size())
	main.player.global_position = Vector3(3.55, 0, 4.3)
	await _idle(0.2)
	if not await _use(main.flat.hole_center, "Crawl"):
		return
	if not await _until(func(): return main.chapter != null and not main.chapter.busy and main.player.can_move, 30.0, "the town"):
		return
	await _town()

# --- the town ------------------------------------------------------------------------------------

func _tp(local: Vector3) -> void:
	await _until(func(): return main.player.can_move and not main.chapter.busy, 60.0, "Kurt to be free to move")
	main.player.global_position = main.town.to_global(local)
	await get_tree().physics_frame
	await get_tree().physics_frame

func _g(local: Vector3) -> Vector3:
	return main.town.to_global(local)

## The town thing to look at with this title.
func _thing(title: String) -> Node3D:
	for e in get_tree().get_nodes_in_group("examine"):
		if String(e.get("title")) == title:
			return e
	_fail("no '%s' in the town" % title)
	return null

## Stand a step from a world point, on the side toward `toward` (town-local), and use it.
func _go_use(target: Vector3, toward_local: Vector3, prompt: String, dist := 1.1) -> bool:
	var tl: Vector3 = main.town.to_local(target)
	var d := Vector3(toward_local.x - tl.x, 0, toward_local.z - tl.z).normalized()
	await _tp(Vector3(tl.x, toward_local.y, tl.z) + d * dist)
	return await _use(target, prompt)

func _town() -> void:
	if main.chapter == null:
		if not await _until(func(): return main.chapter != null and not main.chapter.busy, 30.0, "the town"):
			return
	var ch: TownChapter = main.chapter
	var town: Town = main.town
	if shots != "":
		await _shot("10_town_arrival")
	# all the nuggets (the monsters hold still meanwhile: teleporting past them isn't the test)
	for m in [ch.porter, ch.lamplighter, ch.marta]:
		m.process_mode = Node.PROCESS_MODE_DISABLED
	for n in town.nuggets:
		await _tp(town.to_local(n.global_position) - Vector3(0, 0.6, 0))
		await _idle(0.15)
	for m in [ch.porter, ch.lamplighter, ch.marta]:
		m.process_mode = Node.PROCESS_MODE_INHERIT
	print("AUTOTEST: town nuggets collected, have %d" % Game.nuggets)
	match route:
		"talk": await _route_talk(ch, town)
		"kill": await _route_kill(ch, town)
		"sneak": await _route_sneak(ch, town)
	if not get_tree():
		return
	# out of the gate
	if not await _until(func(): return town.gate_open, 10.0, "the gate to open"):
		return
	await _tp(Vector3(42, 0, Town.GATE_Z + 0.8))
	main.player.face(_g(Vector3(42, 1.6, 76)))
	main.hud.controls.autopilot_move = Vector2(0, -1)
	if not await _until(func(): return ch.route != "", 20.0, "leaving by the gate"):
		return
	main.hud.controls.autopilot_move = Vector2.ZERO
	if ch.route != route:
		_fail("went out by '%s', expected '%s'" % [ch.route, route])
		return
	print("AUTOTEST: out of the town by '%s'" % route)
	await _flat48()

func _route_talk(ch: TownChapter, town: Town) -> void:
	for id in ["handwriting", "these_streets", "old_name"]:
		if not Game.buy(id):
			_fail("couldn't buy " + id)
			return
	# the photo strip in the hotel room, then the porter (his back to the door): now Kurt knows
	var strip := _thing("Photo strip")
	if strip == null or not await _go_use(strip.global_position, Vector3(55.3, 0.45, 38.0), "Look", 1.0):
		return
	await _idle(0.3)
	main.hud.reader.close()
	await _idle(0.5)
	var porter: Monster = ch.porter
	await _tp(town.to_local(porter.global_position) + Vector3(-1.7, 0, 0))
	if not await _use(porter.head.global_position, "Talk"):
		return
	if not await _until(func(): return porter.state == Monster.S.CALM, 30.0, "the porter to calm"):
		return
	if shots != "":
		await _shot("11_porter_calm")
	# round the seam once, and the lamplighter
	await _tp(Vector3(55.0, 0, 20.0))
	main.player.face(_g(Vector3(70, 1.6, 20)))
	main.hud.controls.autopilot_move = Vector2(0, -1)
	if not await _until(func(): return Game.flag("looped"), 30.0, "the street to come round"):
		return
	main.hud.controls.autopilot_move = Vector2.ZERO
	await _idle(4.0)
	var ll: Monster = ch.lamplighter
	await _until(func(): return main.player.can_move and not ch.busy, 60.0, "Kurt to be free to move")
	main.player.global_position = ll.global_position + ll.global_transform.basis.z * 1.7
	await get_tree().physics_frame
	if not await _use(ll.head.global_position, "Talk"):
		return
	if not await _until(func(): return ll.state == Monster.S.CALM, 30.0, "the lamplighter to calm"):
		return
	# the poster: who he was
	var poster := _thing("Poster")
	if poster == null or not await _go_use(poster.global_position, Vector3(42, 0, 40), "Look", 1.3):
		return
	await _idle(0.3)
	main.hud.reader.close()
	await _idle(3.0)
	# Marta, by the gate, head down. He tells her who he is.
	await _tp(town.marta_post + Vector3(0, 0, -1.8))
	if not await _use(ch.marta.head.global_position, "Talk"):
		return
	if not await _until(func(): return ch.marta.state == Monster.S.CALM, 30.0, "Marta to calm"):
		return
	if shots != "":
		await _shot("12_marta_calm")
	await _idle(1.0)
	await _go_use(town.lever_spot.global_position, town.lever.position + Vector3(0, -1.25, -1.2), "Pull", 1.0)

func _route_kill(ch: TownChapter, town: Town) -> void:
	if not Game.buy("headshot"):
		_fail("couldn't buy headshot")
		return
	# rounds from the hotel room
	var ammo: Hotspot = town.pickups[0][0]
	if not await _go_use(ammo.global_position, Vector3(54.4, 0.45, 35.4), "Take", 0.9):
		return
	if not await _go_use(town.to_global(town.revolver_at + Vector3(0, 0.1, 0)), town.revolver_at + Vector3(1.0, 0, 0.3), "Take", 1.0):
		return
	await _idle(4.0)
	if shots != "":
		await _shot("11_gun")
	var m: MartaHunter = ch.marta
	if not m.awake:
		_fail("taking the revolver didn't wake her")
		return
	# she's coming: wait until she's in sight, then take her
	if not await _until(func(): return m.global_position.distance_to(main.player.global_position) < 12.0 and m.can_see_player(), 60.0, "Marta to come into sight"):
		return
	var shots_fired := 0
	while m.state != Monster.S.DEAD:
		await get_tree().physics_frame
		if not main.player.can_move:
			continue
		if Game.ammo_loaded == 0:
			main.weapon.reload()
			await _until(func(): return not main.weapon.busy, 10.0, "reload")
		main.player.face(m.head.global_position + Vector3(0, 0.1, 0))
		main.hud.controls.aiming = true
		await _idle(0.25)
		main.weapon.fire()
		shots_fired += 1
		if shots_fired > 40:
			_fail("40 shots and she's still up")
			return
	main.hud.controls.aiming = false
	print("AUTOTEST: Marta down in %d shots" % shots_fired)
	await _idle(4.0)
	await _go_use(town.lever_spot.global_position, town.lever.position + Vector3(0, -1.25, -1.2), "Pull", 1.0)

func _route_sneak(ch: TownChapter, town: Town) -> void:
	var m: MartaHunter = ch.marta
	var rock: Hotspot = town.pickups[7][0]       # the cobble in the middle of the plaza
	if not await _go_use(rock.global_position, Vector3(39.0, 0, 59.6), "Take", 1.0):
		return
	if main.weapon.held != "rock":
		_fail("didn't pick the cobble up")
		return
	# throw it up the lane toward the square, away from the gate
	main.player.face(_g(Vector3(41.0, 3.0, 48.0)))
	await _idle(0.2)
	main.weapon.fire()
	await _idle(0.4)
	await _tp(Vector3(31.0, 0, 64.5))          # out of her way: she comes up the lane to look
	if not await _until(func(): return m.state == Monster.S.LISTEN, 6.0, "Marta to hear the cobble"):
		return
	if not await _until(func(): return m.global_position.distance_to(town.lever_spot.global_position) > 9.0, 25.0, "Marta to drift off"):
		return
	await _go_use(town.lever_spot.global_position, town.lever.position + Vector3(0, -1.25, -1.2), "Pull", 1.0)

## Fixed views of Kurt himself (start with --start=door): looking down, the gun held and aimed.
func _poses() -> void:
	if not await _stage("explore"):
		return
	var p: Player = main.player
	p.global_position = Vector3(3.4, 0, 3.4)
	var views := [["body_down", Vector3(3.4, 0.0, 3.1)], ["body_down_ahead", Vector3(3.4, 0.4, 2.2)], ["ahead", Vector3(3.0, 1.4, 1.4)]]
	for v in views:
		p.face(v[1])
		await _idle(0.8)
		await _shot(v[0])
	# right up against a wall: nothing of his should go into it
	p.global_position = Vector3(7.6, 0, 4.7)
	p.socko.set_pose("up", 0.0)
	for k in 40:
		p.face(Vector3(7.6, 1.45, 6.0))
		main.hud.controls.autopilot_move = Vector2(0, -1)
		await get_tree().physics_frame
	main.hud.controls.autopilot_move = Vector2.ZERO
	await _idle(0.8)
	await _shot("wall_hands")
	main.weapon.give_gun()
	await _idle(0.8)
	await _shot("wall_gun")
	p.socko.set_pose("low", 0.0)
	p.global_position = Vector3(3.4, 0, 3.4)
	p.face(Vector3(2.0, 1.4, 1.0))
	await _idle(0.8)
	await _shot("gun_hold")
	main.hud.controls.aiming = true
	main.weapon.set_aim(true)
	await _idle(0.8)
	await _shot("gun_aim")
	get_tree().quit(0)

# --- Flat 48 ----------------------------------------------------------------------------------------

func _g48(local: Vector3) -> Vector3:
	return main.flat48.to_global(local)

## Stand `dist` from a point in 48 (local), on the side toward `toward`, and use it.
func _use48(target: Vector3, toward: Vector3, prompt: String, dist := 1.0) -> bool:
	if not await _until(func(): return main.player.can_move, 30.0, "Kurt to be free to move"):
		return false
	var d := Vector3(toward.x - target.x, 0, toward.z - target.z).normalized()
	main.player.global_position = _g48(Vector3(target.x, 0, target.z) + d * dist)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return await _use(_g48(target), prompt)

## Use this very thing in 48 (not whatever's in front of it): try standing round it until the
## crosshair has it.
func _use_thing48(thing: Object, target: Vector3, prompt: String) -> bool:
	if not await _until(func(): return main.player.can_move, 30.0, "Kurt to be free to move"):
		return false
	var p: Player = main.player
	for dist in [1.0, 0.8, 1.3]:
		for i in 12:
			var a := TAU * i / 12.0
			p.global_position = _g48(Vector3(target.x + cos(a) * dist, 0, target.z + sin(a) * dist))
			p.velocity = Vector3.ZERO
			for k in 4:
				await get_tree().physics_frame
				p.face(_g48(target))
			if p.focus == thing and String(thing.get("prompt")).begins_with(prompt):
				p.try_interact()
				return true
	_fail("couldn't get at %s to '%s' (focus %s)" % [thing, prompt, p.focus])
	return false

func _note48(word: String) -> bool:
	var f: Flat48 = main.flat48
	for id in f.slots:
		var s: Dictionary = f.slots[id]
		if s["word"] == word and s["node"] != null:
			return await _use48(s["pos"], Vector3(s["pos"].x, 0, 4.9), "Take", 0.75)
	_fail("no '%s' note on the wall" % word)
	return false

func _block48(index: int) -> Flat48.Placeholder:
	for b in main.flat48.blocks:
		if b.index == index:
			return b
	return null

func _flat48() -> void:
	# on the landing: 48's door comes off the latch; through it
	if main.args.get("start", "") != "flat48":
		if not await _until(func(): return main.place == "flat47" and main.flat.door48_spot.enabled and main.player.can_move, 40.0, "48's door to open"):
			return
		if shots != "":
			await _shot("20_landing")
		main.player.global_position = Vector3(12.9, 0, 4.56)
		await _idle(0.2)
		if not await _use(main.flat.door48_spot.global_position, "Go in"):
			return
	if not await _until(func(): return main.place == "flat48" and main.chapter48 != null and main.chapter48.active and main.player.can_move, 30.0, "Flat 48"):
		return
	var f: Flat48 = main.flat48
	var w: Weapon = main.weapon
	if shots != "":
		await _idle(1.0)
		await _shot("21_flat48_hall")
	# a block: look at it, the wrong word, the right word, peel it, stick it again
	var sofa := _block48(23)
	var top := sofa.position + Vector3(0, sofa.half.y, 0)
	if not await _use48(top, Vector3(2.2, 0, 2.6), "Look", 1.2):
		return
	if not main.hud.last_caption.contains("the green one with the burn"):
		_fail("looking at the sofa block didn't read its tag: '%s'" % main.hud.last_caption)
		return
	if not await _note48("PIANO"):
		return
	if w.held != "note" or w.note_word != "PIANO":
		_fail("the PIANO note isn't in his hand")
		return
	if shots != "":
		await _idle(0.5)
		await _shot("22_note_in_hand")
	if not await _use48(top, Vector3(2.2, 0, 2.6), "Stick", 1.2):
		return
	await _idle(1.2)
	if sofa.real != null or w.note_word != "PIANO":
		_fail("the wrong word stayed on the sofa block")
		return
	if not await _use48(Vector3(5.5, 1.1, Flat48.WALL_Z), Vector3(5.5, 0, 4.9), "Put the note back", 0.8):
		return
	if w.held == "note" or f.slots[17]["node"] == null:
		_fail("the PIANO note didn't go back on the wall")
		return
	if not await _note48("SOFA"):
		return
	if not await _use48(top, Vector3(2.2, 0, 2.6), "Stick", 1.2):
		return
	await _idle(0.8)
	if sofa.real == null or int(sofa.real.get_meta("count", 0)) < 1 or w.held == "note":
		_fail("SOFA on the sofa block didn't make it real")
		return
	if shots != "":
		await _shot("23_sofa_real")
	if not await _use(sofa.note.global_position, "Peel"):
		return
	await _idle(0.3)
	if sofa.real != null or w.note_word != "SOFA":
		_fail("peeling the note didn't give the block back")
		return
	if not await _use48(top, Vector3(2.2, 0, 2.6), "Stick", 1.2):
		return
	await _idle(0.6)
	if sofa.real == null:
		_fail("the sofa wouldn't come back")
		return
	# the gun safe: the note, the door, the shotgun on its pegs, the shells
	if not await _note48("GUN SAFE"):
		return
	var safe_front := Flat48.SAFE_AT + Vector3(0.1, 1.05, -Flat48.SAFE_HALF.z)
	if not await _use48(safe_front, Vector3(1.35, 0, 6.0), "Stick", 1.0):
		return
	await _idle(0.6)
	if not f.safe.real:
		_fail("GUN SAFE didn't make the safe")
		return
	if not await _use48(safe_front, Vector3(1.35, 0, 6.0), "Open the safe", 1.0):
		return
	await _idle(1.0)
	if shots != "":
		main.player.global_position = _g48(Vector3(1.25, 0, 6.75))
		main.player.face(_g48(Flat48.SAFE_AT + Vector3(-0.03, 0.75, 0)))
		await _idle(7.5)
		await _shot("24_safe_open")
	if f.safe.gun == null:
		_fail("there's no shotgun to see in the safe")
		return
	if not await _use48(f.to_local(f.safe.gun_spot.global_position), Vector3(1.35, 0, 6.0), "Take the shotgun", 1.0):
		return
	await _idle(0.5)
	if not Game.has_shotgun or w.held != "shotgun" or Game.shells_loaded != 2:
		_fail("the shotgun isn't in his hand, loaded")
		return
	if not await _use48(f.to_local(f.safe.shells_spot.global_position), Vector3(1.35, 0, 6.0), "Take the shells", 1.0):
		return
	if Game.shells_spare != 10:
		_fail("the shells didn't come")
		return
	# the three of them: MARTA, KURT, and SONYA, who isn't here
	var names := {"mama": "MARTA", "papa": "KURT"}
	for g in f.figures:
		var chest: Vector3 = g.position + Vector3(0, g.tall * 0.55, 0)
		if not await _use_thing48(g, chest, "Look"):
			return
		if g.id == "child":
			continue
		if not await _note48(names[g.id]):
			return
		if not await _use_thing48(g, chest, "Stick"):
			return
		await _idle(0.8)
		if not g.dressed:
			_fail("%s didn't take the name %s" % [g.id, names[g.id]])
			return
		if shots != "":
			await _shot("25_dressed_" + g.id)
	var child = f.figures[2]
	if not await _note48("SONYA"):
		return
	if not await _use_thing48(child, child.position + Vector3(0, child.tall * 0.55, 0), "Stick"):
		return
	await _idle(1.0)
	if child.dressed or w.note_word != "SONYA" or not Game.flag("f48_child_refused_sonya"):
		_fail("SONYA stayed on the child")
		return
	if not await _use48(Vector3(5.5, 1.1, Flat48.WALL_Z), Vector3(5.5, 0, 4.9), "Put the note back", 0.8):
		return
	if w.held != "shotgun":
		_fail("the shotgun didn't come back to his hand after the note")
		return
	# the gun is real, and so is the choice: only the gun route takes it
	if route == "kill":
		var mama = f.figures[0]
		main.player.global_position = _g48(Vector3(8.75, 0, 1.25))
		await _idle(0.3)
		main.player.face(mama.global_position + Vector3(0, mama.tall * 0.6, 0))
		main.hud.controls.aiming = true
		await _idle(1.5)
		w.fire()
		main.hud.controls.aiming = false
		await _idle(1.5)
		if not mama.down or not Game.flag("f48_shot_mama") or Game.shells_loaded != 1:
			var cam: Camera3D = main.player.camera
			var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_transform.basis.z * 20.0, 1 | 4, [(main.player as Player).get_rid()])
			q.collide_with_areas = true
			var hit: Dictionary = (main.player as Player).get_world_3d().direct_space_state.intersect_ray(q)
			_fail("the shot didn't put her down (held %s, shells %d, busy %s, down %s, centre ray hits %s)" % [w.held, Game.shells_loaded, w.busy, mama.down, hit.get("collider")])
			return
		if f.figures[1].down or f.figures[2].down:
			_fail("one shot put more than one of them down")
			return
		if shots != "":
			await _shot("26_shot")
	else:
		for g in f.figures:
			if g.down:
				_fail("%s is down and nobody shot it" % g.id)
				return
	# and out again, by the door he came in by
	main.player.global_position = _g48(Vector3(9.3, 0, 4.56))
	await _idle(0.3)
	if not await _use(f.entry.handle_position(), "Leave"):
		return
	if not await _until(func(): return main.place == "flat47" and main.player.can_move, 20.0, "the landing again"):
		return
	await _idle(1.0)
	print("AUTOTEST PASS: Scene A, the town by '%s', Flat 48 (%d lines)" % [route, Speech.history.size()])
	await _shot("99_end")
	get_tree().quit(0)

func _shot_later(name: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	await _shot(name)

func _shot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shots.path_join(name + ".png"))


## Fingers on glass: real touch events through the engine's input, as a phone sends them.
## Walks with the stick, turns with a drag, taps USE, opens the pause menu and taps Resume.
func _tap(index: int, at: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index; e.position = at; e.pressed = down
	Input.parse_input_event(e)

func _drag(index: int, from: Vector2, to: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index; e.position = to; e.relative = to - from
	Input.parse_input_event(e)

func _touch() -> void:
	var c: Controls = main.hud.controls
	var p: Player = main.player
	c.autopilot = false
	if not await _until(func(): return p.can_move, 120.0, "control"): return
	var size := c.size
	var start := p.global_position
	var a := Vector2(200, size.y - 200)
	_tap(0, a, true)
	await get_tree().process_frame
	_drag(0, a, a + Vector2(0, -80))
	for i in 90:
		await get_tree().physics_frame
	var walked := p.global_position.distance_to(start)
	if walked < 0.5:
		print("DBG move ", c.move, " stick ", c._stick_id, " origin ", c._stick_origin, " pos ", c._stick_pos, " size ", c.size, " vel ", p.velocity, " floor ", p.is_on_floor(), " paused ", get_tree().paused)
		_fail("the stick didn't move him (%.2f m)" % walked); return
	# a second finger turns him while the first still walks
	var yaw := p.rotation.y
	var b := Vector2(size.x * 0.7, size.y * 0.5)
	_tap(1, b, true)
	await get_tree().process_frame
	_drag(1, b, b + Vector2(120, 0))
	for i in 10:
		await get_tree().physics_frame
	_tap(1, b + Vector2(120, 0), false)
	_tap(0, a + Vector2(0, -80), false)
	if absf(angle_difference(p.rotation.y, yaw)) < 0.2:
		_fail("the drag didn't turn him"); return
	for i in 30:
		await get_tree().physics_frame
	# losing focus for a moment (a notification, the voice engine starting) must not stop the game
	main.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	main.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await get_tree().process_frame
	if get_tree().paused:
		_fail("a moment's lost focus paused the game"); return
	# pause, and out of it again, by touch alone
	var pr := c._pause_rect().get_center()
	_tap(0, pr, true); _tap(0, pr, false)
	await get_tree().process_frame
	if not get_tree().paused:
		_fail("the pause button didn't pause"); return
	var rb: Button = main.hud._first_btn
	var at := rb.get_global_rect().get_center()
	_tap(0, at, true)
	await get_tree().process_frame
	_tap(0, at, false)
	for i in 5:
		await get_tree().process_frame
	if get_tree().paused:
		_fail("Resume can't be tapped"); return
	# and he still walks afterwards
	start = p.global_position
	_tap(0, a, true)
	await get_tree().process_frame
	_drag(0, a, a + Vector2(0, 80))
	for i in 60:
		await get_tree().physics_frame
	_tap(0, a + Vector2(0, 80), false)
	if p.global_position.distance_to(start) < 0.3:
		_fail("no walking after the pause menu"); return
	print("AUTOTEST PASS: touch (stick, look, pause, resume)")
	get_tree().quit(0)


## Looks all the way round from where he stands, and up the stairs: a frame each (for the eye).
func _spin() -> void:
	var p: Player = main.player
	if not await _until(func(): return p.can_move, 120.0, "control"): return
	if main.args.has("at"):
		var v: PackedStringArray = String(main.args["at"]).split(",")
		p.global_position = Vector3(float(v[0]), float(v[1]), float(v[2]))
	for i in 8:
		p.rotation.y = i * TAU / 8.0
		p._set_pitch(0.25 if i % 2 else -0.1)
		for k in 20:
			await get_tree().process_frame
		await _shot("spin_%d" % i)
	get_tree().quit(0)


## The Super: he's there, he walks the stairs, Kurt can climb them, bullets don't stop him, he
## catches Kurt and Kurt wakes on his landing. With --shots, pictures of him.
func _super() -> void:
	var p: Player = main.player
	if not await _until(func(): return p.can_move, 120.0, "control"): return
	main.scene.busy = true
	main.to_landing()
	if not await _until(func(): return main.flat.building.the_super != null and p.can_move, 30.0, "the Super"): return
	var b: Building = main.flat.building
	var sup: Super = b.the_super
	# Kurt climbs to the fifth floor on his own feet
	var up: Array = []
	var i0 := b.nearest(b.landing_point(4)); var i1 := b.nearest(b.landing_point(5))
	for i in range(i0, i1 + 1):
		up.append(b.chain[i])
	sup.wait_for = 9999.0
	if not await _walk(up): return
	if absf(p.global_position.y - Building.floor_y(5)) > 0.3:
		_fail("the stairs didn't take him to the fifth floor (y %.2f)" % p.global_position.y); return
	print("AUTOTEST: climbed to the fifth floor")
	# the Super does his round: from the second floor up to where Kurt is
	if shots != "":
		p.global_position = b.landing_point(4) + Vector3(-0.9, 0, 1.6)
		sup.place_at(b.landing_point(4) + Vector3(0.6, 0, -1.0))
		sup.rotation.y = PI
		p.can_move = false
		p.face(sup.global_position + Vector3(0, 1.75, 0))
		for k in 30: await get_tree().physics_frame
		await _shot("super_front")
		p.global_position = sup.global_position + Vector3(-0.25, 0, 1.5)
		p.face(sup.global_position + Vector3(0, 1.5, 0))
		for k in 20: await get_tree().physics_frame
		await _shot("super_body")
		p.global_position = sup.global_position + Vector3(1.3, 0, -1.0)
		p.face(sup.global_position + Vector3(0, 1.5, 0))
		for k in 20: await get_tree().physics_frame
		await _shot("super_back")
		p.global_position = main.flat.building.landing_point(4) + Vector3(-0.9, 0, 1.6)
		p.face(sup.global_position + Vector3(0, 1.75, 0))
		sup.rotation.y = PI * 0.5
		for k in 20: await get_tree().physics_frame
		await _shot("super_side")
		p.global_position = sup.global_position + Vector3(0.3, 0, 1.25)
		p.face(sup.head.global_position + Vector3(0, 0.05, 0))
		sup.rotation.y = PI
		for k in 20: await get_tree().physics_frame
		await _shot("super_head")
		p.global_position = b.landing_point(5)
		p.can_move = true
		sup.place_at(b.landing_point(Building.LOW))
	sup.wait_for = 0.0
	var y0 := sup.global_position.y
	if not await _until(func(): return sup.global_position.y > y0 + 2.5, 60.0, "the Super to climb a storey"): return
	print("AUTOTEST: the Super climbs")
	if shots != "":
		p.global_position = b.landing_point(4) + Vector3(0.9, 0, 1.2)
		p.face(Vector3(11.2, 0.6, 3.6))
		if not await _until(func(): return sup.global_position.y > -1.2, 60.0, "him coming up"): return
		await _shot("super_coming")
	# shoot him: he staggers and keeps existing
	main.weapon.give_gun()
	Game.ammo_loaded = 6; Game.ammo_spare = 12
	p.global_position = b.landing_point(5) + Vector3(0, 0, 1.5)
	if not await _until(func(): return sup.mode == Super.Mode.HUNT and sup.global_position.distance_to(p.global_position) < 6.0 and absf(sup.global_position.y - p.global_position.y) < 0.4, 90.0, "him to come for Kurt"): return
	for n in 6:
		p.face(sup.head.global_position)
		for k in 4: await get_tree().physics_frame
		main.weapon.fire()
		for k in 30: await get_tree().physics_frame
	if sup.shots_taken < 3:
		_fail("the shots didn't land on him (%d)" % sup.shots_taken); return
	if not is_instance_valid(sup) or sup.state == Monster.S.DEAD:
		_fail("the Super died"); return
	print("AUTOTEST: %d shots in him; still coming" % sup.shots_taken)
	if not await _until(func(): return sup.catches > 0, 60.0, "him to catch Kurt"): return
	if not await _until(func(): return p.can_move, 30.0, "Kurt to come round"): return
	if absf(p.global_position.y) > 0.3 or absf(sup.global_position.y) < 3.0:
		_fail("after the grab: Kurt at y %.1f, the Super at y %.1f" % [p.global_position.y, sup.global_position.y]); return
	print("AUTOTEST PASS: the Super (stairs, rounds, bullets, the grab)")
	get_tree().quit(0)
