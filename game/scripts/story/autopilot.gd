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
	if main.args.get("start", "") == "town":
		_town.call_deferred()
	else:
		_run()

func _fail(why: String) -> void:
	var st: String = main.scene.stage
	print("AUTOTEST FAIL: ", why, "  (stage ", st, ", at ", main.player.global_position, ")")
	print("lines said: ", Speech.history)
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
	if not await _stage("explore"):
		return
	if shots != "":
		_shot_later("01_hallway_entry", 0.2)
	if not await _walk([Vector3(0.0, 0, -0.9), Vector3(-0.35, 0, -2.5), Vector3(-0.35, 0, -3.95)]):
		return
	main.player.face(Vector3(-3.0, 1.1, -3.9))
	await get_tree().create_timer(0.5).timeout
	if not await _walk([Vector3(-1.6, 0, -3.8)]):
		return
	while not Speech.history.has("see_marta") or main.scene.busy:
		main.player.face(main.marta.head.global_position)
		await get_tree().physics_frame
	if shots != "":
		_shot_later("02_marta", 0.1)
		await get_tree().create_timer(0.5).timeout
	if not await _walk([Vector3(-2.3, 0, -2.85), Vector3(-2.95, 0, -2.85)]):
		return
	if not await _use(main.marta.head.global_position, "Examine"):
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
	if not await _walk([Vector3(-2.0, 0, -2.8), Vector3(-1.6, 0, -3.95)]):
		return
	if not await _use(Vector3(-1.0, 1.0, -3.95), "Open"):
		return
	if not await _stage("scene_a_done"):
		return
	if absf(main.flat.room_door.angle) > 0.1:
		_fail("the living room door isn't shut")
		return
	# nuggets in the room
	for n in main.flat.flat_nuggets:
		main.player.global_position = Vector3(n.global_position.x, 0, n.global_position.z)
		await _idle(0.2)
	if Game.nuggets != 2:
		_fail("expected 2 nuggets in the flat, have %d" % Game.nuggets)
		return
	# the wardrobe: three shoves
	main.player.global_position = Vector3(-1.6, 0, -3.95)
	if not await _walk([Vector3(-1.7, 0, -4.5), Vector3(-2.1, 0, -4.85)]):
		return
	for i in 3:
		if not await _use(main.flat.wardrobe.global_position + Vector3(0, 1.0, 0), "Push"):
			return
		await _idle(1.4)
	if not await _stage("hole_open"):
		return
	if Speech.history != EXPECTED_A:
		_fail("Scene A lines out of order or missing:\n  expected %s\n  got      %s" % [EXPECTED_A, Speech.history])
		return
	print("AUTOTEST: Scene A ok, %d lines in order" % Speech.history.size())
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

func _town() -> void:
	if main.chapter == null:
		if not await _until(func(): return main.chapter != null and not main.chapter.busy, 30.0, "the town"):
			return
	var ch: TownChapter = main.chapter
	var town: Town = main.town
	if shots != "":
		await _shot("10_town_arrival")
	# all the nuggets
	for n in town.nuggets:
		await _tp(town.to_local(n.global_position) - Vector3(0, 0.6, 0))
		await _idle(0.15)
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
	await _tp(Vector3(26, 0, -25.5))
	main.player.face(_g(Vector3(26, 1.6, -40)))
	main.hud.controls.autopilot_move = Vector2(0, -1)
	if not await _until(func(): return ch.route != "", 20.0, "leaving by the gate"):
		return
	main.hud.controls.autopilot_move = Vector2.ZERO
	if ch.route != route:
		_fail("went out by '%s', expected '%s'" % [ch.route, route])
		return
	await _idle(4.0)
	print("AUTOTEST PASS: Scene A, then out of the town by '%s' (%d lines)" % [route, Speech.history.size()])
	await _shot("99_end")
	get_tree().quit(0)

func _route_talk(ch: TownChapter, town: Town) -> void:
	for id in ["handwriting", "these_streets", "old_name"]:
		if not Game.buy(id):
			_fail("couldn't buy " + id)
			return
	# the register, then the porter (his back to the door), who now has a name for Kurt
	await _tp(Vector3(12.5, 0, 4.8))
	if not await _use(_g(Vector3(12.55, 1.2, 5.85)), "Read"):
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
	await _tp(Vector3(51.5, 0, 0.0))
	main.player.face(_g(Vector3(60, 1.6, 0)))
	main.hud.controls.autopilot_move = Vector2(0, -1)
	if not await _until(func(): return Game.flag("looped"), 30.0, "the street to come round"):
		return
	main.hud.controls.autopilot_move = Vector2.ZERO
	await _idle(4.0)
	var ll: Monster = ch.lamplighter
	var behind := ll.global_transform.basis.z * 1.7
	await _until(func(): return main.player.can_move and not ch.busy, 60.0, "Kurt to be free to move")
	main.player.global_position = ll.global_position + behind
	await get_tree().physics_frame
	if not await _use(ll.head.global_position, "Talk"):
		return
	if not await _until(func(): return ll.state == Monster.S.CALM, 30.0, "the lamplighter to calm"):
		return
	# the poster: who he was
	await _tp(Vector3(17.4, 0, -10.1))
	if not await _use(_g(Vector3(16.3, 1.9, -10.1)), "Look"):
		return
	await _idle(0.3)
	main.hud.reader.close()
	await _idle(3.0)
	# Marta, by the gate, head down. He tells her who he is.
	await _tp(Vector3(26, 0, -19.2))
	if not await _use(ch.marta.head.global_position, "Talk"):
		return
	if not await _until(func(): return ch.marta.state == Monster.S.CALM, 30.0, "Marta to calm"):
		return
	if shots != "":
		await _shot("12_marta_calm")
	await _idle(1.0)
	await _tp(Vector3(28.6, 0, -22.2))
	await _use(_g(Vector3(29.4, 1.3, -23.3)), "Pull")

func _route_kill(ch: TownChapter, town: Town) -> void:
	if not Game.buy("headshot"):
		_fail("couldn't buy headshot")
		return
	# rounds from the hotel desk
	await _tp(Vector3(13.5, 0, 4.8))
	if not await _use(_g(Vector3(13.5, 1.2, 5.8)), "Take"):
		return
	await _tp(Vector3(26, 0, -11.8))
	if not await _use(_g(Vector3(26.0, 0.17, -13.0)), "Take"):
		return
	await _idle(4.0)
	if shots != "":
		await _shot("11_gun")
	var m: MartaHunter = ch.marta
	if not m.awake:
		_fail("taking the revolver didn't wake her")
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
		if shots_fired > 30:
			_fail("30 shots and she's still up")
			return
	main.hud.controls.aiming = false
	print("AUTOTEST: Marta down in %d shots" % shots_fired)
	await _idle(4.0)
	await _tp(Vector3(28.6, 0, -22.2))
	await _use(_g(Vector3(29.4, 1.3, -23.3)), "Pull")

func _route_sneak(ch: TownChapter, town: Town) -> void:
	var m: MartaHunter = ch.marta
	await _tp(Vector3(20.2, 0, -19.6))
	if not await _use(_g(Vector3(21.0, 0.2, -20.5)), "Take"):
		return
	if main.weapon.held != "rock":
		_fail("didn't pick the cobble up")
		return
	# throw it far down the square, away from the gate
	main.player.face(_g(Vector3(19.5, 3.0, -6.0)))
	await _idle(0.2)
	main.weapon.fire()
	if not await _until(func(): return m.state == Monster.S.LISTEN, 6.0, "Marta to hear the cobble"):
		return
	if not await _until(func(): return m.global_position.distance_to(town.lever_spot.global_position) > 9.0, 20.0, "Marta to drift off"):
		return
	await _tp(Vector3(28.6, 0, -22.2))
	await _use(_g(Vector3(29.4, 1.3, -23.3)), "Pull")

func _shot_later(name: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	await _shot(name)

func _shot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shots.path_join(name + ".png"))
