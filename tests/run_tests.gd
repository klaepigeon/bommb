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
	var tests := ["body", "items", "full_matches", "hot_potato_defuse", "roulette_void", "chairs_hazards", "escape_path", "disconnect", "views_hide_secrets"]
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
	check(seen.size() == Items.CATALOGUE.size(), "every item can be drawn")


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
			# a dead contestant never has the turn
			var cur := core.rules.current() if core.phase == "turn" else -1
			if cur >= 0:
				check(core.p(cur).alive, "dead contestant took a turn (seed %d)" % (1000 + i))
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
	check(games.size() == 3, "all three minigames come round")


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
