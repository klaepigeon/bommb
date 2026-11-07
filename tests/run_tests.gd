extends Node
## Headless tests: godot --headless res://tests/run_tests.tscn [-- --only=name --seeds=N]
## Plays whole matches with AI in every seat (and scripted humans), checks the rules.

var failures := 0
var passes := 0
var args := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=")
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	Audio.muted = true
	var t0 := Time.get_ticks_msec()
	var tests := ["body", "items", "full_matches", "hot_potato_defuse", "roulette_void", "chairs_hazards", "escape_path", "disconnect", "views_hide_secrets",
		"v2_leave_table", "v2_cheating", "v2_suspicion_death", "v2_cage_dice", "v2_cage_roulette", "v2_ghosts_and_draws", "v2_resurrection_square",
		"v2_ghost_buys_life", "v2_roulette_social", "v2_poison", "v2_treatment", "v2_all_minigames", "v2_caller_reacts"]
	if args.has("only") and not tests.has(args.only):
		tests = [args.only]
	for t in tests:
		if args.has("only") and args.only != t:
			continue
		call("test_" + t)
	print("\n%d passed, %d failed (%d ms)" % [passes, failures, Time.get_ticks_msec() - t0])
	get_tree().quit(1 if failures > 0 else 0)


func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
	else:
		failures += 1
		printerr("FAIL: " + what)


func seats4(kinds := ["ai", "ai", "ai", "ai"]) -> Array:
	var out := []
	for i in 4:
		out.append({"seat": i, "kind": kinds[i], "name": "P%d" % i, "face": i, "color": Color.WHITE})
	return out


func run(core: MatchCore, max_time := 3000.0, dt := 1.0 / 20.0) -> float:
	var t := 0.0
	while core.ending == "" and t < max_time:
		core.tick(dt)
		core.take_events()
		t += dt
	return t


func test_body() -> void:
	var b := Body.fresh()
	check(Body.dice_max(b) == 6, "fresh body rolls 6")
	Body.injure(b, "leg_l", "lost")
	check(Body.dice_max(b) == 4, "lost leg -2")
	check(Body.speed(b) < 1.0 and Body.speed(b) > 0.3, "lost leg slows")
	Body.injure(b, "leg_l", "bruised")
	check(b.leg_l.s == "lost", "can't bruise a lost leg")
	check(Body.fit_prosthetic(b) == "leg_l", "prosthetic fits the leg")
	check(b.leg_l.s == "prosthetic", "prosthetic status")
	Body.injure(b, "arm_r", "lost")
	check(b.hand_r.s == "lost", "losing an arm loses the hand")
	check(not Body.two_handed(b), "one hand now")
	Body.injure(b, "eye_l", "burned")
	Body.tick_round(b)
	Body.tick_round(b)
	check(b.eye_l.s == "ok", "burns heal in two rounds")
	Body.injure(b, "leg_r", "broken")
	check(Body.dice_max(b, true) == 5, "painkillers ignore the broken leg (prosthetic still -1)")


func test_items() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 3
	var seen := {}
	for i in 400:
		seen[Items.roll(r)] = true
	check(seen.size() == Items.CATALOGUE.keys().filter(func(k): return int(Items.CATALOGUE[k].weight) > 0).size(), "every drawable item can be drawn")


func test_full_matches() -> void:
	var n := int(args.get("seeds", "40"))
	var endings := {}
	var rounds := 0
	var games := {}
	var defusals := 0
	var deaths := {}
	for i in n:
		var core := MatchCore.new()
		core.fast = true
		core.setup(seats4(), 1000 + i)
		var stuck := false
		var t := 0.0
		var last_phase := ""
		while core.ending == "" and t < 4000.0:
			core.tick(0.05)
			for e in core.take_events():
				if e.e == "minigame":
					games[e.id] = games.get(e.id, 0) + 1
				if e.e == "mg" and e.k == "defused":
					defusals += 1
				if e.e == "death":
					deaths[e.anim] = deaths.get(e.anim, 0) + 1
					check(not core.p(e.seat).alive, "death marks dead")
			# a turn belongs to the living, or (after them) to a ghost; never to anyone else
			var cur := core.rules.current() if core.phase == "turn" else -1
			if cur >= 0:
				check(core.p(cur).alive or core.p(cur).ghost, "a turn for someone neither alive nor a ghost (seed %d)" % (1000 + i))
				if core.rules.sub == "ghost":
					check(core.p(cur).ghost, "a living player got a ghost's turn")
			if core.mg and core.phase == "mg_play":
				for s in core.mg.seats:
					pass
			t += 0.05
		if core.ending == "":
			stuck = true
			printerr("stuck in phase %s round %d sub %s (seed %d)" % [core.phase, core.round_n, core.rules.sub, 1000 + i])
		check(not stuck, "match %d reaches an ending" % i)
		endings[core.ending] = endings.get(core.ending, 0) + 1
		rounds += core.round_n
		if core.ending == "dead":
			check(core.living().is_empty(), "total elimination leaves nobody alive")
	print("endings %s, avg rounds %.1f, games %s, defusals %d, deaths %s" % [endings, float(rounds) / n, games, defusals, deaths])
	check(games.size() >= 8, "most of the minigames come round in %d matches (%d)" % [n, games.size()])


func test_hot_potato_defuse() -> void:
	# Scripted humans in every seat: the holder fiddles, then each step is done by
	# whoever holds it next, passing between steps.
	var core := MatchCore.new()
	core.fast = true
	core.setup(seats4(["local", "local", "local", "local"]), 77)
	core.mg = MinigameRegistry.create("hot_potato", core, core.living(), 0)
	core.mg_id = "hot_potato"
	core._set_phase("mg_play")
	var mg: Minigame = core.mg
	mg.start()
	var h: int = mg.holder
	core.action(h, {"t": "mg", "do": "fiddle"})
	for i in 40:
		core.tick(0.05)
	check(mg.step_i == 1, "fiddling starts the sequence")
	check(not mg.can_step(h), "the one who did the last step can't do the next")
	var steps_done := 1
	for k in 10:
		if mg.step_i >= mg.n_steps or mg.sub != "play":
			break
		var cur: int = mg.holder
		if cur < 0:
			core.tick(0.05)
			continue
		if mg.can_step(cur):
			core.action(cur, {"t": "mg", "do": "step"})
			for i in 60:
				core.tick(0.05)
			steps_done += 1
		else:
			core.action(cur, {"t": "mg", "do": "pass", "target": (cur + 1) % 4})
			for i in 30:
				core.tick(0.05)
	check(mg.sub == "defused" or mg.done, "the toy is defused (sub=%s step=%d)" % [mg.sub, mg.step_i])
	var key_holders := core.players.filter(func(p): return p.has_key)
	check(key_holders.size() == 1, "defusing gives up the key")
	check(core.living().size() == 4, "nobody died")


func test_roulette_void() -> void:
	var core := MatchCore.new()
	core.fast = true
	core.setup(seats4(["local", "local", "local", "local"]), 5)
	core.mg = MinigameRegistry.create("roulette", core, core.living(), 0)
	core._set_phase("mg_play")
	var mg: Minigame = core.mg
	mg.start()
	for k in 4:
		var s: int = mg.current()
		core.action(s, {"t": "mg", "do": "lower"})
		for i in 50:
			mg.tick(0.05)
	check(mg.voided and mg.done, "everyone putting it down voids the game")
	check(core.unrest >= 1.0, "the Caller is rattled")
	check(core.living().size() == 4, "nobody died")
	# and the probability state: a chamber goes off within six pulls with one loaded
	var c2 := MatchCore.new()
	c2.fast = true
	c2.setup(seats4(["local", "local", "local", "local"]), 9)
	c2.mg = MinigameRegistry.create("roulette", c2, c2.living(), 0)
	c2._set_phase("mg_play")
	var mg2: Minigame = c2.mg
	mg2.start()
	var pulls := 0
	while not mg2.done and pulls < 10:
		mg2.action(mg2.current(), {"t": "mg", "do": "pull"})
		pulls += 1
		for i in 50:
			mg2.tick(0.05)
	check(c2.living().size() == 3, "one loaded chamber pops within six pulls")


func test_chairs_hazards() -> void:
	var core := MatchCore.new()
	core.fast = true
	core.setup(seats4(), 21)
	var mg: Minigame = MinigameRegistry.create("musical_chairs", core, core.living(), 0)
	mg.start()
	check(mg.chairs.size() == 5, "one more chair than players")
	var bad: int = mg.chairs.filter(func(c): return c.hazard != "").size()
	check(bad == 1, "first sub-round has one rigged chair")
	var v: Dictionary = mg.view_for([0])
	var leaks := false
	for c in v.chairs:
		if c.has("hazard"):
			leaks = true
	check(not leaks, "the view never says what a chair is")
	mg.round_i = 2
	mg._begin_round()
	check(mg.chairs.filter(func(c): return c.hazard != "").size() == 3, "more rigged chairs each round, same chair count")
	check(mg.chairs.size() == 5, "chair count never drops")


func test_escape_path() -> void:
	# Everyone cooperative: the escape should be reachable by the AI on its own.
	var escapes := 0
	var n := maxi(40, int(args.get("seeds", "40")))   # seeded: the same 40 tables every run
	for i in n:
		var core := MatchCore.new()
		core.fast = true
		var s := seats4()
		for k in 4:
			s[k].ai = {"coop": 0.95, "perception": 0.9}
		core.setup(s, 5000 + i)
		run(core)
		if core.ending == "escape":
			escapes += 1
		if i == 0 and args.has("trace"):
			print("\n".join(core.log_lines))
	print("cooperative AI tables escaped %d/%d" % [escapes, n])
	check(escapes > 0, "a cooperative table can escape")


func test_disconnect() -> void:
	var core := MatchCore.new()
	core.fast = true
	core.setup(seats4(["remote", "ai", "ai", "ai"]), 31)
	core.seat_disconnected(0)
	check(core.p(0).kind == "ai", "a dropped player's seat is played by AI")
	run(core)
	if core.ending == "":
		print("\n".join(core.log_lines.slice(-30)))
		print("phase ", core.phase, " sub ", core.rules.sub)
	check(core.ending != "", "the match still ends")


func test_views_hide_secrets() -> void:
	var core := MatchCore.new()
	core.setup(seats4(), 8)
	core.p(1).clues[0] = 7
	var v := core.view_for([0])
	check(v.players[1].clues.is_empty(), "other people's clues are private")
	check(int(v.players[1].clue_count) == 1, "but you can see that they found something")
	var v1 := core.view_for([1])
	check(v1.players[1].clues.has(0), "your own clues are yours")


## Where cooperative tables get stuck on the way out (diagnostic: --only=escape_funnel).
func test_escape_funnel() -> void:
	var n := int(args.get("seeds", "40"))
	var st := {"defused": 0, "code_shared": 0, "key_alive": 0, "all_at_door": 0, "door_phase": 0, "escape": 0}
	for i in n:
		var core := MatchCore.new()
		core.fast = true
		var s := seats4()
		for k in 4:
			s[k].ai = {"coop": 0.95, "perception": 0.9}
		core.setup(s, 5000 + i)
		var seen := {}
		var t := 0.0
		while core.ending == "" and t < 3000.0:
			core.tick(0.05)
			for e in core.take_events():
				if e.e == "mg" and e.get("k", "") == "defused":
					seen.defused = true
				if e.e == "door":
					seen.door_phase = true
			if core.shared_code.size() == 3:
				seen.code_shared = true
			for p in core.players:
				if p.alive and p.has_key:
					seen.key_alive = true
			var everyone := core.living().size() >= 2
			for q in core.living():
				if not core.p(q).at_door:
					everyone = false
			if everyone:
				seen.all_at_door = true
			t += 0.05
		if core.ending == "escape":
			seen.escape = true
		for k in seen:
			st[k] += 1
	print("escape funnel over %d cooperative tables: %s" % [n, st])



# --- v0.2 -----------------------------------------------------------------------------

func _core(kinds := ["local", "local", "local", "local"], seed_v := 99) -> MatchCore:
	var core := MatchCore.new()
	core.fast = true
	core.setup(seats4(kinds), seed_v)
	return core


func _look_away(core: MatchCore) -> void:
	core.suspicion.distract(30.0)
	core.suspicion.turning = false
	core.suspicion.distracted = 30.0


func _look_at(core: MatchCore, seat: int) -> void:
	core.suspicion.distracted = 0.0
	core.suspicion.watching = true
	core.suspicion.turning = false
	core.suspicion.watch_target = seat
	core.suspicion._dur = 999.0


func _to_turn(core: MatchCore, seat: int) -> void:
	core._start_round()
	while core.rules.current() != seat and core.rules.sub != "idle":
		core.rules.next_turn()


func test_v2_leave_table() -> void:
	var core := _core()
	_to_turn(core, 0)
	_look_away(core)
	var before := core.p(0).suspicion
	core.action(0, {"t": "leave"})
	check(core.rules.sub == "room" and core.p(0).location == "up", "leaving the table puts you in the room")
	check(core.p(0).suspicion > before, "getting up is suspicious")
	core.action(0, {"t": "go", "where": "pinata"})
	check(core.p(0).location == "pinata", "you can go to a hotspot")
	var rats_before := core.p(0).teeth
	var items_before := core.p(0).items.size()
	core.action(0, {"t": "room_act", "id": "hit_pinata"})
	check(core.p(0).teeth != rats_before or core.p(0).items.size() != items_before or not core.p(0).statuses.is_empty() or core.p(0).body.hand_l.s != "ok", "the piñata does something")
	core.action(0, {"t": "go", "where": "booth"})
	core.action(0, {"t": "room_act", "id": "read_file"})
	check(core.p(0).known.has("file"), "his files can be read")
	check(core.p(0).location == "table", "two actions, then you're back in your chair")
	# caught in the room: fined and sat down
	var c2 := _core()
	_to_turn(c2, 1)
	_look_away(c2)
	c2.action(1, {"t": "leave"})
	c2.action(1, {"t": "go", "where": "coats"})
	_look_at(c2, 1)
	var sus := c2.p(1).suspicion
	c2.action(1, {"t": "room_act", "id": "search_coats"})
	check(c2.p(1).location == "table" and c2.p(1).suspicion >= sus + 10, "caught in the room: sat back down, suspicion up")


func test_v2_cheating() -> void:
	var core := _core()
	_to_turn(core, 0)
	_look_at(core, 0)
	var s0 := core.p(0).suspicion
	core.action(0, {"t": "cheat", "id": "palm_rats"})
	check(core.p(0).suspicion >= s0 + 16, "cheating while he watches: caught")
	var c2 := _core()
	_to_turn(c2, 0)
	_look_away(c2)
	var r0 := c2.p(0).teeth
	c2.action(0, {"t": "cheat", "id": "palm_rats"})
	check(c2.p(0).teeth == r0 + 2 and c2.p(0).suspicion > 0 and c2.p(0).suspicion < 16, "cheating while he looks away works (a little suspicion)")
	c2.action(0, {"t": "cheat", "id": "load_dice"})
	c2.action(0, {"t": "roll"})
	check(c2.rules.roll == Body.dice_max(c2.p(0).body), "a loaded die rolls the most it can")


func test_v2_suspicion_death() -> void:
	var core := _core()
	core.suspicion.add(2, 60, "test")
	check(core.p(2).cage >= 1, "past 50, he tightens the Cage")
	core.suspicion.add(2, 45, "test")
	check(not core.p(2).alive and core.p(2).ghost and core.p(2).death == "audit", "100 suspicion: he kills you (and you're a ghost)")


func test_v2_cage_dice() -> void:
	var core := _core()
	var sum0 := 0
	var sum5 := 0
	for i in 3000:
		core.p(0).cage = 0
		sum0 += core.cage.roll(0, 6)
		core.p(0).cage = 5
		sum5 += core.cage.roll(0, 6)
	print("cage dice: average roll at cage 0 = %.2f, at cage 5 = %.2f" % [sum0 / 3000.0, sum5 / 3000.0])
	check(sum5 < sum0 - 1500, "a tight Cage really rolls lower")


func test_v2_cage_roulette() -> void:
	var bangs := [0, 0]
	for k in 2:
		for i in 300:
			var core := _core(["local", "local", "local", "local"], 700 + i)
			core.p(0).cage = 0 if k == 0 else 5
			var mg: Minigame = MinigameRegistry.create("roulette", core, core.living(), 0)
			mg.start()
			mg.cur = mg.order.find(0)
			mg.action(0, {"t": "mg", "do": "pull"})
			if mg.last.get("bang", false):
				bangs[k] += 1
	print("roulette first pull: shot %d/300 at cage 0, %d/300 at cage 5" % bangs)
	check(bangs[1] > bangs[0] + 30, "the Cage leans on the cylinder")


func test_v2_ghosts_and_draws() -> void:
	var core := _core()
	core.kill(3, "pop")
	check(core.p(3).ghost and not core.p(3).alive, "death makes a ghost")
	var parts_before := 0
	for s in core.living():
		for part in Body.PARTS:
			if core.p(s).body[part].s == "lost":
				parts_before += 1
	core.mg = MinigameRegistry.create("consensus", core, core.living(), 0)
	core.mg_id = "consensus"
	core.mg.finish(core.living(), true)
	core._finish_minigame()
	check(core.p(3).alive and not core.p(3).ghost, "an FFA draw brings the dead back")
	var lost := 0
	for s in [0, 1, 2]:
		for part in Body.PARTS:
			if core.p(s).body[part].s == "lost":
				lost += 1
	check(lost - parts_before == 3, "and every living player gives up a part (%d)" % (lost - parts_before))
	# a team game's draw doesn't
	var c2 := _core()
	c2.kill(0, "pop")
	c2.mg = MinigameRegistry.create("hot_potato", c2, c2.living(), 0)
	c2.mg_id = "hot_potato"
	c2.mg.finish([], true)
	c2._finish_minigame()
	check(c2.p(0).ghost, "a non-FFA draw doesn't resurrect")


func test_v2_resurrection_square() -> void:
	var core := _core()
	core.kill(1, "pop")
	core.kill(2, "pop")
	core.resurrection.square(0)
	var back := int(core.p(1).alive) + int(core.p(2).alive)
	check(back == 1, "the resurrection square revives exactly one ghost")


func test_v2_ghost_buys_life() -> void:
	var core := _core()
	core.kill(2, "pop")
	_to_turn(core, 0)
	# run the round until the ghost's turn
	while core.rules.current() != 2 and core.rules.sub != "idle":
		core.rules.next_turn()
	check(core.rules.sub == "ghost", "ghosts get a turn")
	core.action(2, {"t": "ghost", "do": "scavenge"})
	check(core.p(2).teeth > 0, "ghosts scavenge Dead Rats")
	core.p(2).teeth = 12
	core._start_round()
	while core.rules.current() != 2 and core.rules.sub != "idle":
		core.rules.next_turn()
	core.action(2, {"t": "ghost", "do": "rise"})
	check(core.p(2).alive and core.p(2).teeth == 2, "a ghost with enough Dead Rats buys their way back")


func test_v2_roulette_social() -> void:
	var core := _core()
	var mg: Minigame = MinigameRegistry.create("roulette", core, core.living(), 0)
	core.mg = mg
	core._set_phase("mg_play")
	mg.start()
	var me: int = mg.current()
	var other: int = (me + 1) % 4
	core.p(me).teeth = 10
	core.action(me, {"t": "mg", "do": "claim", "say": "EMPTY"})
	check(mg.claims.get(me) == "EMPTY", "you can say what's in it")
	core.action(me, {"t": "mg", "do": "offer", "target": other, "teeth": 4})
	check(not mg.offer.is_empty(), "you can offer someone teeth to take your turn")
	core.action(other, {"t": "mg", "do": "accept"})
	check(core.p(other).teeth == 4 and mg.pulls == 1, "they take the money and the pull")
	check(mg.last.get("target", -1) == other, "the shot was at the one who took the money")
	# a cheat while he looks away
	var c2 := _core()
	var m2: Minigame = MinigameRegistry.create("roulette", c2, c2.living(), 0)
	c2.mg = m2
	c2._set_phase("mg_play")
	m2.start()
	_look_away(c2)
	var cur: int = m2.current()
	c2.action(cur, {"t": "mg", "do": "cheat", "id": "pocket_round"})
	check(m2.loaded == 0 and c2.p(cur).items.has("bullet"), "pocketing the round empties the gun (and you keep the round)")


func test_v2_poison() -> void:
	var core := _core()
	core.p(0).teeth = 10
	core.status.apply(0, "rat_fever")
	core.status.apply(0, "hunger")
	core.status.tick_turn(0)
	check(core.p(0).teeth == 6, "rat fever and hunger together eat four teeth a turn (%d)" % core.p(0).teeth)
	core.status.apply(1, "thinner")
	core.injure(1, "arm_l", "bruised")
	check(core.p(1).body.arm_l.s == "burned", "blood thinner makes injuries worse")
	core.status.apply(2, "blindness")
	check(core.view_for([2]).flags.blind, "blindness reaches the board's view")


func test_v2_treatment() -> void:
	var core := _core()
	_to_turn(core, 0)
	core.status.apply(0, "necrosis")
	core.p(0).items.append("antidote")
	core.action(0, {"t": "item", "id": "antidote"})
	check(core.p(0).statuses.is_empty(), "an antidote cures")
	core.injure(0, "leg_l", "lost")
	core.p(0).items.append("prosthetic")
	core.action(0, {"t": "item", "id": "prosthetic"})
	check(core.p(0).body.leg_l.s == "prosthetic", "a replacement limb")


func test_v2_all_minigames() -> void:
	for id in MinigameRegistry.GAMES.keys():
		var core := _core(["ai", "ai", "ai", "ai"], 4242)
		var mg: Minigame = MinigameRegistry.create(id, core, core.living(), 1)
		core.mg = mg
		core.mg_id = id
		core._set_phase("mg_play")
		mg.start()
		var t := 0.0
		while not mg.done and t < 240.0:
			core.tick(0.05)
			core.take_events()
			t += 0.05
		var v: Dictionary = mg.view_for([0])
		check(mg.done, "%s finishes (format %s, %.0fs, winners %s, draw %s)" % [id, mg.format, t, str(mg.winners), str(mg.draw)])
		if mg.format == "2v2":
			check(mg.teams.size() == 2 and mg.teams[0].size() == 2, "%s is two teams of two" % id)
		if mg.format == "1v3":
			check(mg.teams.size() == 2 and mg.teams[0].size() == 1 and mg.teams[1].size() == 3, "%s is one against three" % id)
		check(not v.is_empty(), "%s has a view" % id)
		print("  %s: done in %.1fs, winners %s, draw %s" % [id, t, str(mg.winners), str(mg.draw)])


func test_v2_caller_reacts() -> void:
	var core := _core()
	core.take_events()
	core.suspicion.add(0, 30, "test")
	var said := core.take_events().filter(func(e): return e.e == "say")
	check(not said.is_empty(), "he says something when someone crosses a threshold")
	core.p(1).suspicion = 80
	core.p(1).cage = 0
	var tightened := false
	for i in 10:
		core.cage.review()
		if core.p(1).cage > 0:
			tightened = true
	check(tightened, "at the end of a round he tightens the Cage on the suspicious")


func test_escape_trace() -> void:
	var core := MatchCore.new()
	core.fast = true
	var s := seats4()
	for k in 4:
		s[k].ai = {"coop": 0.95, "perception": 0.9}
	core.setup(s, int(args.get("seed", "5003")))
	var t := 0.0
	var last_round := 0
	while core.ending == "" and t < 3000.0:
		core.tick(0.05)
		for e in core.take_events():
			if e.e in ["door_stop", "door", "key", "share", "stay", "revive", "death", "minigame", "sacrifice"] or (e.e == "toast" and str(e.text).contains("door")):
				print("  r%d %s" % [core.round_n, str(e).left(140)])
		if core.round_n != last_round:
			last_round = core.round_n
			var st := []
			for p in core.players:
				st.append("%s:%s%s%s sp%d" % [p.name, "A" if p.alive else "G", "D" if p.at_door else "", "K" if p.has_key else "", p.space])
			print("round %d shared=%s %s" % [core.round_n, str(core.shared_code), " ".join(st)])
		t += 0.05
	print("ending ", core.ending)
