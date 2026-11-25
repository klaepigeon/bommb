extends Node
## Plays the first-playable milestone headless and checks it. Run: tools/test.sh
## The player is driven through the same paths as a person: movement input, focus, act().
## Prints "AUTOTEST PASS" / "AUTOTEST FAIL: ..." and quits with 0 / 1.

var main: Node
var player: Player
var failures: Array[String] = []

func check(ok: bool, what: String) -> void:
	print("AUTOTEST %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## Walk with the movement input toward `to` (straight line); true if reached.
func walk_to(to: Vector3, max_seconds := 20.0) -> bool:
	player.autopilot = true
	player.autopilot_target = to
	var t := 0.0
	while t < max_seconds:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		var d := player.global_position - to
		d.y = 0
		if d.length() < 0.35:
			break
	player.autopilot = false
	var d2 := player.global_position - to
	d2.y = 0
	return d2.length() < 0.5

func face(at: Vector3) -> void:
	var d := at - player.global_position
	player.yaw = rad_to_deg(atan2(-d.x, -d.z))
	player.pitch = -10
	await frames(12)

func npc(id: String) -> NPC:
	return World.npcs[id]

func fast_forward_to(hhmm: String, rate := 30.0) -> void:
	var target := Clock.parse(hhmm)
	Clock.minutes_per_second = rate
	await frames(2)
	var guard := 0
	while absf(Clock.minute_of_day() - target) > 1.0 and guard < 60 * 400:
		await get_tree().physics_frame
		guard += 1
	Clock.minutes_per_second = Clock.BASE_RATE
	await frames(30)

func run(m: Node) -> void:
	main = m
	player = m.player
	var route: String = m.args.get("route", "night")
	if route != "night":
		get_tree().create_timer(400.0, true, false, true).timeout.connect(func():
			print("AUTOTEST FAIL: watchdog (stuck at %s)" % Clock.text())
			get_tree().quit(1))
		await frames(10)
		await call("_route_" + route)
		_finish_test()
		return
	get_tree().create_timer(400.0, true, false, true).timeout.connect(func():
		print("AUTOTEST FAIL: watchdog (stuck at %s)" % Clock.text())
		get_tree().quit(1))
	await frames(10)
	# --- the world
	check(World.rooms.size() >= 20, "rooms registered: %d" % World.rooms.size())
	check(World.places.size() >= 60, "places registered: %d" % World.places.size())
	var nm: NavigationMesh = main.hood.navigation_mesh
	check(nm != null and nm.get_polygon_count() > 100, "navmesh baked: %d polygons" % (nm.get_polygon_count() if nm else 0))
	check(World.npcs.size() == 15, "15 people on the block: %d" % World.npcs.size())
	# --- everyone starts where their night has them (21:00)
	check(npc("abe").activity.do == "work" and npc("abe").global_position.distance_to(World.places["pawn.work"].pos) < 0.5, "Abe is behind the pawn counter at 21:00")
	check(npc("marv").activity.do == "work", "Marv is tending bar")
	check(npc("ida").activity.do == "home", "Ida is at home in 1C")
	check(npc("claudette").activity.do == "away", "Claudette hasn't arrived yet (21:30)")
	check(npc("doyle").activity.do == "patrol", "Doyle is on patrol")
	# --- touch: a thumb on the left half moves, a drag on the right half looks
	var c: Controls = main.controls
	var start_pos := player.global_position
	var start_yaw := player.yaw
	_touch(0, Vector2(200, 500), true)
	for i in 10:
		_drag(0, Vector2(200, 500 - i * 9))
		await frames(1)
	await frames(60)
	check(c.move.length() > 0.5 and player.global_position.distance_to(start_pos) > 0.5, "touch stick walks the player (%.1f m)" % player.global_position.distance_to(start_pos))
	_touch(0, Vector2(200, 410), false)
	_touch(1, Vector2(1000, 400), true)
	for i in 10:
		_drag(1, Vector2(1000 + i * 12, 400))
		await frames(1)
	_touch(1, Vector2(1120, 400), false)
	await frames(5)
	check(absf(player.yaw - start_yaw) > 5.0, "touch drag on the right turns the camera (%.0f°)" % (player.yaw - start_yaw))
	check(c.move.length() < 0.01, "lifting the thumb stops")
	player.global_position = start_pos
	player.yaw = start_yaw
	await frames(5)
	# --- walk to 218, open the street door, use the key on 1D
	var front: Door = main.hood.find_child("Door_t218_front", true, false)
	check(await walk_to(front.global_position + Vector3(0, 0, 1.4)), "walked along the sidewalk to 218's door")
	await face(front.global_position + Vector3.UP)
	check(player.focus == front, "focus settles on the door (got %s)" % (player.focus.label if player.focus else "nothing"))
	player.act(0)
	await frames(40)
	check(front.is_open, "the street door opens")
	var hall := front.global_position + Vector3(0, 0, -4.0)
	check(await walk_to(hall), "walked into the hallway")
	check(World.room_at(player.global_position + Vector3.UP * 0.5) == "t218_hall", "World knows the player is in 218's hallway")
	var d1d: Door = main.hood.find_child("Door_t218_1d", true, false)
	check(await walk_to(d1d.global_position + Vector3(1.0, 0, 0)), "walked to 1D's door")
	await face(d1d.global_position + Vector3.UP)
	check(player.focus == d1d and d1d.verbs(player)[0] == "Open", "1D offers Open (the player has the key)")
	player.act(0)
	await frames(40)
	check(d1d.is_open, "1D opens with the key")
	var d1c: Door = main.hood.find_child("Door_t218_1c", true, false)
	check(d1c.verbs(player)[0] == "Pick lock", "1C (Ida's) is locked to the player")
	# --- inside 1D: read the notebook, take the cash
	check(await walk_to(d1d.global_position + Vector3(-1.2, 0, 0)), "walked through 1D's door")
	check(await walk_to(d1d.global_position + Vector3(-2.6, 0, 4.2)), "walked into 1D")
	check(World.room_at(player.global_position + Vector3.UP * 0.5) == "t218_1d", "World knows the player is home")
	var notebook: Readable = null
	for r in get_tree().get_nodes_in_group("interactable"):
		if r is Readable and r.title == "Your notebook":
			notebook = r
	var read_text := [""]
	Events.read.connect(func(t, _x): read_text[0] = t, CONNECT_ONE_SHOT)
	notebook.perform(player, "Read")
	check(read_text[0] == "Your notebook", "the notebook can be read")
	main.hud._close_panels()
	var cash := _item("player_cash")
	cash.perform(player, "Take")
	check(player.cash == 35, "took own cash: $%d" % player.cash)
	# --- sound
	check(Sfx._loops.size() >= 14, "places have sound: %d loops" % Sfx._loops.size())
	await frames(20)
	check(Sfx.listener_room == "t218_1d", "sound knows the player is in 1D")
	var street_loop: Dictionary = Sfx._loops.filter(func(l): return l.room == "")[0]
	check((street_loop.player as AudioStreamPlayer3D).attenuation_filter_cutoff_hz < 1000.0, "the street is muffled from indoors")
	check(Sfx.surface_at(Vector3(0, 0.2, 7)) == "boots" and Sfx.surface_at(Vector3(-40, 0.2, 13)) == "tile" and Sfx.surface_at(Vector3(-12, 0.2, -27)) == "gravel", "footsteps know concrete, the diner's tiles and the yard's gravel")
	# --- shop hours: the pawn shop is open at 21:xx and the office isn't
	check(World.may_enter("player", "pawn_shop"), "the pawn shop is open to the public at %s" % Clock.text())
	check(not World.may_enter("player", "pawn_office"), "Abe's office is private")
	# --- a witnessed theft: the bar till, in front of Marv
	var marv := npc("marv")
	var till := _item("bar_till")
	player.global_position = till.global_position + Vector3(0, -1.0 + 0.15, 1.3)
	player.global_position.y = 0.2
	await frames(30)
	check(marv.can_see(player), "Marv can see the player at the bar")
	till.perform(player, "Take")
	await frames(5)
	check(marv.memory.knows("theft", "player"), "Marv witnessed the theft of the till")
	check(marv.memory.disposition("player") < -0.4, "Marv thinks less of the player: %.2f" % marv.memory.disposition("player"))
	var rita := npc("rita")
	check(not rita.memory.knows("theft"), "Rita (across the street) knows nothing about it")
	# --- an unwitnessed theft: Rita's tips from her empty apartment
	var tips := _item("rita_tips")
	player.global_position = tips.global_position + Vector3(0, 0, 1.0)
	player.global_position.y = 0.2
	await frames(20)
	tips.perform(player, "Take")
	check(World.missing.size() >= 2, "the game records what went missing (%d)" % World.missing.size())
	player.global_position = Vector3(30, 0.2, 7)      # away, on the south sidewalk
	await frames(20)
	# --- the night goes on: routines
	await fast_forward_to("00:50")
	check(npc("abe").activity.do in ["eat", "home", "drink", "social", "wander", "errand", "missing"], "after closing, Abe does something else: %s" % npc("abe").activity.do)
	check(npc("claudette").activity.do == "work" and not npc("claudette").hidden_away, "Claudette arrived for work at the Vesper")
	check(not World.may_enter("player", "pawn_shop"), "the pawn shop is closed to the public at %s" % Clock.text())
	var at_places := 0
	for n in World.npcs.values():
		if n.arrived and not n.hidden_away and n.activity.get("place", "") != "":
			at_places += 1
	check(at_places >= 6, "people are at their places at %s: %d" % [Clock.text(), at_places])
	await fast_forward_to("02:40")
	await _story_went()
	await fast_forward_to("06:15")
	check(rita.activity.do == "sleep" and World.room_at(rita.global_position + Vector3.UP * 0.5) == "t212_1a", "Rita went home to 1A")
	check(rita.memory.knows("theft", "unknown"), "Rita found her tips gone (culprit unknown)")
	check(not rita.memory.knows("theft", "player") or rita.memory.about("player", "theft").all(func(e): return e.source != Memory.Source.WITNESSED), "Rita doesn't magically know who did it")
	var told := 0
	for n in World.npcs.values():
		for e in n.memory.entries:
			if e.source == Memory.Source.TOLD:
				told += 1
	print("AUTOTEST info  memories passed on by gossip: %d" % told)
	print("AUTOTEST info  ledger: %d payments, e.g. %s" % [World.ledger.size(), str(World.ledger.slice(0, 2))])
	check(World.ledger.size() > 0, "money changed hands (meals, drinks)")
	_finish_test()

func _finish_test() -> void:
	if failures.is_empty():
		print("AUTOTEST PASS")
		get_tree().quit(0)
	else:
		print("AUTOTEST FAIL: %d checks: %s" % [failures.size(), ", ".join(failures)])
		get_tree().quit(1)

func _item(id: String) -> Item:
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is Item and n.data.id == id:
			return n
	return null

func _touch(i: int, at: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = _window(at)
	e.pressed = down
	Input.parse_input_event(e)

func _drag(i: int, at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = _window(at)
	Input.parse_input_event(e)

## Screen (canvas) position → window position, so a test finger lands where a real one would
## whatever size the (headless) window is.
func _window(at: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * at

# ------------------------------------------------------------------ The Missing Merchant

## Nobody interferes: Abe takes the box to the Vesper after closing and is gone. The world notices.
func _story_went() -> void:
	var abe := npc("abe")
	check(World.gone.has("abe") and abe.gone, "left alone, Abe went to the Vesper and is gone")
	check(_item("pawn_box") == null, "he took the tin box with him")
	var spectacles := _item("abe_spectacles")
	check(spectacles != null and World.room_at(spectacles.global_position + Vector3.UP * 0.3) == "club_back", "his spectacles lie in the Vesper's back room")
	check(not World.may_enter("player", "pawn_shop"), "the pawn shop can't open with Abe gone")
	var knows_missing := World.npcs.values().filter(func(n): return n.memory.knows("missing", "abe"))
	print("AUTOTEST info  know Abe is missing: %s" % ", ".join(knows_missing.map(func(n): return "%s(%s)" % [n.id, Memory.SOURCE_NAMES[n.memory.about("abe", "missing")[0].source]])))
	check(npc("rita").memory.knows("missing", "abe"), "Rita noticed: Abe never came in for his late meal")
	check(knows_missing.size() >= 2, "the news spread: %d people know" % knows_missing.size())
	check(not npc("claudette").memory.knows("saw_vesper"), "the Vesper's people keep it to themselves")
	# the player asks around, breaks in, finds the evidence, takes it to the police
	var rita := npc("rita")
	var ask_rita := (rita.talk as Interactable).verbs(player)
	print("AUTOTEST info  Rita's topics before: %s" % str(ask_rita))
	rita.ask("abe", player)
	check(Journal.knows("abe_gone_heard"), "asking Rita, the player learns Abe is missing")
	check("Ask about Abe" in (rita.talk as Interactable).verbs(player), "now the player can ask people about Abe")
	player.global_position = spectacles.global_position + Vector3(0.8, 0.0, 0.0)
	await frames(10)
	spectacles.perform(player, "Take")
	check(Journal.knows("spectacles_found") and player.has_item("abe_spectacles"), "the spectacles are found (and the journal says so)")
	var doyle := npc("doyle")
	check(not doyle.hidden_away, "Doyle is on his beat at %s" % Clock.text())
	player.global_position = doyle.global_position + Vector3(0, 0, 1.2)
	await frames(10)
	doyle.ask("show", player)
	await frames(5)
	check(Journal.knows("told_doyle"), "shown the spectacles, Doyle takes it seriously")
	check(doyle.mind.schedule.any(func(b): return b.get("at", "") == "street.vesper_watch"), "Doyle's nights are now spent watching the Vesper")
	print("AUTOTEST info  journal:\n" + Journal.quest_text())

## Prevention 1: steal the box before closing. No box, no meeting.
func _route_prevent() -> void:
	var box := _item("pawn_box")
	var abe := npc("abe")
	player.global_position = box.global_position + Vector3(0.0, -0.6, -0.9)
	await frames(20)
	check(not abe.can_see(player), "Abe, at the counter, can't see his office behind him")
	box.perform(player, "Take")
	check(Journal.knows("box_taken"), "the box is taken (journal)")
	player.global_position = Vector3(30, 0.2, 7)
	await frames(10)
	await fast_forward_to("02:10")
	check(not World.gone.has("abe"), "with no box to bring, Abe is still here")
	check(abe.memory.knows("theft", "unknown"), "Abe found the box gone, and doesn't know who took it")
	check(World.room_at(abe.global_position + Vector3.UP * 0.5) == "t209_2b", "Abe went home and stayed there")
	check(Journal.knows("abe_safe"), "the journal closes: Abe is alive")

## Prevention 2: read his letter, then talk him out of it.
func _route_warn() -> void:
	var letter: Readable = null
	for r in get_tree().get_nodes_in_group("interactable"):
		if r is Readable and r.clue == "letter_read":
			letter = r
	letter.perform(player, "Read")
	main.hud._close_panels()
	check(Journal.knows("letter_read"), "the letter is read")
	var abe := npc("abe")
	player.global_position = abe.global_position + Vector3(0, 0, 1.5)
	await frames(30)
	check("Warn him about the Vesper" in player.offered_verbs() or "Warn him about the Vesper" in (abe.talk as Interactable).verbs(player), "Abe can be warned once the letter has been read")
	abe.ask("warn", player)
	check(Journal.knows("abe_warned"), "Abe listens")
	player.global_position = Vector3(30, 0.2, 7)
	await fast_forward_to("02:10")
	check(not World.gone.has("abe") and _item("pawn_box") != null, "Abe didn't go; the box is still in his office")
	check(Journal.knows("abe_safe"), "the journal closes: Abe is alive")
