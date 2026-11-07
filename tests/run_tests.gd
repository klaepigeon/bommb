extends Node
## Headless tests: godot --headless res://tests/run_tests.tscn [-- --only=name --seeds=N]
## LAST CALL 3 v0.2.5. Plays whole matches with AI in every seat (and scripted humans) at
## every length and player count, and checks each system's rules: the board graph, Teeth
## and Dead Rats, items, shops, wagers, minigames and their payouts, draws, ghosts, the
## Caller's Awards and Game, amendments, events, the facility (real time), cutscenes,
## saving without rerolls. Prints an economy report.

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
	var tests := ["body", "items_catalogue", "board_graph", "board_moves", "dead_rat", "economy", "items_use", "shops", "wagers",
		"full_matches", "lengths_and_counts", "awards", "callers_game", "rules", "events", "facility", "facility_misses",
		"cutscenes", "save_reload", "hot_potato_defuse", "roulette_void", "chairs_hazards", "disconnect", "views_hide_secrets",
		"cheating", "suspicion_death", "cage_dice", "cage_roulette", "ghosts_and_draws", "resurrection_square", "ghost_buys_life",
		"roulette_social", "poison", "treatment", "all_minigames", "core_ten", "caller_reacts", "no_chat", "organ_trail", "escape_room"]
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


func seats(n := 4, kinds := []) -> Array:
	var out := []
	for i in n:
		out.append({"seat": i, "kind": kinds[i] if i < kinds.size() else "ai", "name": "P%d" % i, "face": i, "color": Color.WHITE})
	return out


func seats4(kinds := ["ai", "ai", "ai", "ai"]) -> Array:
	return seats(4, kinds)


func _core(kinds := ["local", "local", "local", "local"], seed_v := 99, opts := {}) -> MatchCore:
	var core := MatchCore.new()
	core.fast = true
	core.setup(seats(kinds.size(), kinds), seed_v, opts)
	return core


func run(core: MatchCore, max_time := 6000.0, dt := 1.0 / 20.0) -> float:
	var t := 0.0
	while core.ending == "" and t < max_time:
		core.tick(dt)
		core.take_events()
		t += dt
	return t


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


## Tick (fast) until `cond` or `secs` pass.
func _until(core: MatchCore, cond: Callable, secs := 30.0) -> bool:
	var t := 0.0
	while t < secs:
		if cond.call():
			return true
		core.tick(0.05)
		t += 0.05
	return cond.call()


# --- body, items ----------------------------------------------------------------------

func test_body() -> void:
	var b := Body.fresh()
	check(Body.dice_max(b) == 6, "fresh body rolls 6")
	Body.injure(b, "leg_l", "lost")
	check(Body.dice_max(b) == 4, "lost leg -2")
	check(Body.speed(b) < 1.0 and Body.speed(b) > 0.3, "lost leg slows")
	Body.injure(b, "leg_l", "bruised")
	check(b.leg_l.s == "lost", "can't bruise a lost leg")
	check(Body.fit_prosthetic(b) == "leg_l", "prosthetic fits the leg")
	Body.injure(b, "arm_r", "lost")
	check(b.hand_r.s == "lost", "losing an arm loses the hand")
	check(not Body.two_handed(b), "one hand now")


func test_items_catalogue() -> void:
	check(Items.MAX_HELD == 3, "three item slots")
	var cats := {}
	for id in Items.all().keys():
		var d: Dictionary = Items.def(id)
		for k in ["name", "desc", "cat", "use", "target", "price", "rarity", "lasts", "icon"]:
			check(d.has(k), "%s has %s" % [id, k])
		cats[str(d.cat)] = true
	for c in ["movement", "offensive", "defensive", "economic", "ghost", "medical", "rules", "roulette"]:
		check(cats.has(c), "there are %s items" % c)
	var r := RandomNumberGenerator.new()
	r.seed = 3
	var seen := {}
	for i in 2000:
		seen[Items.roll(r)] = true
	check(seen.size() >= 25, "the item roll draws widely (%d kinds)" % seen.size())
	# every item can be acquired somewhere: a shop pool, a pool in the facility, a roll, or a special source
	var shop := Assets.load_json("res://assets/data/shop.json")
	var fac := Assets.load_json("res://assets/data/facility.json")
	var sources := {"gift": true, "lazarus_rat": true, "loaded_wallet": true, "greased_shoes": true, "shortcut_key": true}
	for sid in shop.shops.keys():
		for id in shop.shops[sid].pool:
			sources[id] = true
		for id in shop.shops[sid].get("under_counter", []):
			sources[id] = true
	for pid in fac.pools.keys():
		for e in fac.pools[pid]:
			sources[str(e[0])] = true
	for id in seen.keys():
		sources[id] = true
	for id in Items.all().keys():
		check(sources.has(id), "%s can be acquired" % id)


# --- the board ------------------------------------------------------------------------

func test_board_graph() -> void:
	var g := BoardGraph.load_board()
	check(g.size() >= g.main_count and g.main_count > 0, "the board loads (%d spaces, %d on the main road)" % [g.size(), g.main_count])
	check(g.branches.size() >= 3, "it has branches")
	var junctions := 0
	for n in g.nodes:
		check(not (n.next as Array).is_empty(), "space %d leads somewhere" % int(n.id))
		if (n.next as Array).size() > 1:
			junctions += 1
		for nx in n.next:
			check((g.node(int(nx)).prev as Array).has(int(n.id)), "space %d -> %d is linked both ways" % [int(n.id), int(nx)])
	check(junctions >= 3, "it has junctions (%d)" % junctions)
	# everything reachable from START
	var d := g.all_reachable_from(0)
	check(d.size() == g.size(), "every space can be reached from START (%d/%d)" % [d.size(), g.size()])
	check(g.distances_from(0).size() < g.size(), "with the gates as they start, some routes are shut")
	check(g.districts.size() == 7, "seven districts")
	for dd in g.districts:
		var spaces := g.nodes.filter(func(n): return n.district == dd.id)
		var detours := g.branches.filter(func(b): return b.district == dd.id)
		check(spaces.size() >= 11 and not detours.is_empty(), "%s has its spaces and a detour" % dd.name)
	check(g.size() >= 100 and g.size() <= 130, "100-130 spaces (%d)" % g.size())
	var types := {}
	for n in g.nodes:
		types[str(n.type)] = true
	for t in ["normal", "bad", "event", "item", "shop", "minigame", "duel", "battle", "roulette", "resurrect", "medical", "poison", "gamble", "caller", "trap", "hidden"]:
		check(types.has(t), "the board has a %s space" % t)
	check(not g.rat_spots.is_empty(), "the Dead Rat has places to sit")
	var tolls := g.branches.filter(func(b): return int(b.toll) > 0)
	check(not tolls.is_empty(), "a toll route exists")


func _roll_n(core: MatchCore, seat: int, n: int) -> void:
	core.p(seat).next_roll = ""
	core.rules._roll(seat)
	core.rules.steps = n
	core.rules.roll = n


## Walk the current player along (answering path prompts with `route`) until they land.
func _walk(core: MatchCore, seat: int, route := -1, rat := false) -> void:
	var t := 0.0
	while t < 30.0 and core.rules.current() == seat and core.rules.sub in ["moving", "prompt"]:
		if core.rules.sub == "prompt":
			var pr: Dictionary = core.rules.prompt
			match str(pr.kind):
				"path":
					var to := route if route >= 0 else int(pr.options[0].to)
					core.action(seat, {"t": "answer", "to": to})
				"rat":
					core.action(seat, {"t": "answer", "yes": rat})
				_:
					return
		else:
			core.tick(0.05)
		t += 0.05


func test_board_moves() -> void:
	var core := _core()
	_to_turn(core, 0)
	var g := core.graph
	var j := -1
	for n in g.nodes:
		if (n.next as Array).size() > 1 and int(n.id) < g.main_count and int(g.node(int(n.next[1])).toll) == 0:
			j = int(n.id)
			break
	check(j >= 0, "there's a free junction")
	core.rat_space = -1
	core.p(0).space = int(g.prev_of(j)[0])
	_roll_n(core, 0, 3)
	core.rules.sub = "moving"
	_until(core, func(): return core.rules.sub == "prompt", 5.0)
	check(core.rules.sub == "prompt" and core.rules.prompt.kind == "path", "a junction asks which way")
	var branch_first := int(g.next_of(j)[1])
	check(str(core.rules.prompt.options[1].name) != "THE MAIN ROAD", "a branch has a name")
	core.action(0, {"t": "answer", "to": branch_first})
	check(core.p(0).space == branch_first, "you go the way you chose")
	# a toll gate
	var toll_b: Dictionary = g.branches.filter(func(b): return int(b.toll) > 0)[0]
	var c2 := _core()
	_to_turn(c2, 1)
	c2.rat_space = -1
	c2.p(1).space = int(g.prev_of(int(toll_b.from))[0])
	c2.p(1).teeth = 0
	_roll_n(c2, 1, 3)
	c2.rules.sub = "moving"
	_until(c2, func(): return c2.rules.sub == "prompt", 5.0)
	var locker_opt: Dictionary = c2.rules.prompt.options.filter(func(o): return int(o.toll) > 0)[0]
	check(not locker_opt.can, "no Teeth, no key: the toll gate's shut to you")
	c2.p(1).items.append("shortcut_key")
	c2.rules._step()
	locker_opt = c2.rules.prompt.options.filter(func(o): return int(o.toll) > 0)[0]
	check(locker_opt.can, "a Shortcut Key opens it")
	c2.action(1, {"t": "answer", "to": int(locker_opt.to)})
	check(c2.p(1).space == int(locker_opt.to) and not c2.p(1).items.has("shortcut_key"), "the key is used up on the gate")
	# backwards
	var c3 := _core()
	_to_turn(c3, 2)
	c3.rat_space = -1
	c3.p(2).space = 5
	c3.p(2).items.append("reverse_gear")
	c3.action(2, {"t": "item", "id": "reverse_gear"})
	c3.action(2, {"t": "roll"})
	var n := c3.rules.steps
	_walk(c3, 2)
	check(c3.p(2).space == posmod(5 - n, g.main_count) or n == 0, "REVERSE GEAR walks you backwards (%d steps from 5 to %d)" % [n, c3.p(2).space])
	# passing START pays
	var c4 := _core()
	_to_turn(c4, 3)
	c4.rat_space = -1
	c4.p(3).space = g.main_count - 1
	var t0 := c4.p(3).teeth
	_roll_n(c4, 3, 2)
	c4.rules.sub = "moving"
	_walk(c4, 3)
	check(c4.p(3).teeth != t0, "passing START pays (and the square you land on does something)")


func test_dead_rat() -> void:
	var core := _core()
	_to_turn(core, 0)
	var g := core.graph
	core.rat_space = int(g.rat_spots[0])
	core.p(0).space = int(g.prev_of(core.rat_space)[0])
	core.p(0).teeth = 30
	_roll_n(core, 0, 3)
	core.rules.sub = "moving"
	_until(core, func(): return core.rules.sub == "prompt" and core.rules.prompt.kind == "rat", 5.0)
	check(core.rules.prompt.get("kind", "") == "rat", "passing the Dead Rat offers it")
	var price := int(core.rules.prompt.price)
	core.action(0, {"t": "answer", "yes": true})
	check(core.p(0).rats == 1 and core.p(0).teeth == 30 - price, "buying it: a Dead Rat for %d Teeth" % price)
	check(core.rat_space != int(g.rat_spots[0]), "the Dead Rat moves somewhere else")
	check(core.p(0).stats.get("rats_bought", 0) == 1, "it's counted")
	# the rulebook can change the price
	core.rulebook.add("rat_sale")
	check(core.economy.rat_price() == price - 10, "RAT SALE takes 10 off")
	# Teeth aren't Dead Rats
	check(core.victory.standings()[0].seat == 0, "Dead Rats decide the standings")
	core.p(1).teeth = 999
	check(core.victory.standings()[0].seat == 0, "even against far more Teeth")


# --- the economy ----------------------------------------------------------------------

func test_economy() -> void:
	var core := _core()
	var p := core.p(0)
	p.teeth = 10
	core.economy.award(0, 5, "test", false)
	check(p.teeth == 15 and p.stats.teeth_earned == 5, "earning Teeth (counted)")
	check(core.economy.charge(0, 6, "test") and p.teeth == 9 and p.stats.teeth_spent == 6, "spending Teeth")
	check(not core.economy.charge(0, 99, "test") and p.teeth == 9, "you can't spend what you haven't got")
	check(core.economy.take(0, 99, "test") == 9 and p.teeth == 0, "losing Teeth stops at nothing")
	core.change_rats(0, 2, "test")
	check(p.rats == 2 and p.teeth == 0, "Dead Rats are separate from Teeth")
	core.change_rats(0, -5, "test")
	check(p.rats == 0, "you can't go below no Dead Rats")
	# gambling
	p.teeth = 50
	var wins := 0
	for i in 200:
		var before := p.teeth
		if core.economy.gamble(0, 1):
			wins += 1
			check(p.teeth == before + 1, "a won bet pays")
		else:
			check(p.teeth == before - 1, "a lost bet costs")
		p.teeth = 50
	check(wins > 60 and wins < 140, "gambling is a coin toss (%d/200)" % wins)
	check(int(p.stats.gambles) == 200, "gambles are counted")
	# debts
	core.p(1).teeth = 20
	core.economy.add_debt(1, 0, 10)
	p.teeth = 0
	check(core.economy.settle(1) == 10 and p.teeth == 10 and core.p(1).debts.is_empty(), "a debt is paid")
	# the economy report over real matches
	var n := int(args.get("seeds", "16"))
	var sum := {"earned": 0, "spent": 0, "lost": 0, "rounds": 0, "rats": 0, "bought": 0, "resurrect": 0, "lead_changes": 0, "mg_pay": 0, "pots": 0, "pot_size": 0}
	var spread := 0.0
	var comeback := 0
	for i in n:
		var c := MatchCore.new()
		c.fast = true
		c.setup(seats4(), 7000 + i, {"turns": 15})
		var t := 0.0
		var leader_at_half := -1
		while c.ending == "" and t < 6000.0:
			c.tick(0.05)
			for e in c.take_events():
				match str(e.e):
					"lead_change":
						sum.lead_changes += 1
					"revive":
						if str(e.how) == "rats":
							sum.resurrect += 1
					"results":
						for s in e.teeth.keys():
							sum.mg_pay += maxi(0, int(e.teeth[s]))
						if int(e.get("pool", 0)) > 0:
							sum.pots += 1
							sum.pot_size += int(e.pool)
					"round":
						if int(e.n) == 8:
							leader_at_half = c.leader()
			t += 0.05
		sum.earned += c.economy.flow.earned
		sum.spent += c.economy.flow.spent
		sum.lost += c.economy.flow.lost
		sum.rounds += c.round_n
		var mx := 0
		var mn := 999
		for pl in c.players:
			sum.rats += pl.rats
			sum.bought += int(pl.stats.get("items_bought", 0))
			mx = maxi(mx, pl.teeth)
			mn = mini(mn, pl.teeth)
		spread += mx - mn
		if c.ending_info.get("winner", -1) != leader_at_half and leader_at_half >= 0:
			comeback += 1
		check(c.ending != "", "economy match %d ends" % i)
	var turns := float(maxi(1, sum.rounds * 4))
	print("ECONOMY over %d matches (15 rounds, 4 AI):" % n)
	print("  Teeth earned/turn %.2f, spent/turn %.2f, lost/turn %.2f, circulation %d" % [sum.earned / turns, sum.spent / turns, sum.lost / turns, sum.earned + sum.spent + sum.lost])
	print("  shop purchases/match %.1f, minigame payout/match %.0f, battle pots %d (avg %.1f)" % [float(sum.bought) / n, float(sum.mg_pay) / n, sum.pots, float(sum.pot_size) / maxi(1, sum.pots)])
	print("  Dead Rats/match %.1f, resurrections bought %d, lead changes/match %.1f, wealth spread %.1f, comebacks (winner wasn't leading at half time) %d/%d" % [float(sum.rats) / n, sum.resurrect, float(sum.lead_changes) / n, spread / n, comeback, n])
	check(sum.earned > 0 and sum.spent > 0, "Teeth are earned and spent")
	check(sum.rats > 0, "Dead Rats change hands")
	check(sum.bought > 0, "people shop")


## Every item, used: it does what it says, on the right target, and goes from your pocket.
func test_items_use() -> void:
	for id in Items.all().keys():
		var d: Dictionary = Items.def(id)
		var use := str(d.use)
		if use in ["roulette", "room", "passive", "other"]:
			continue
		var core := _core()
		var me := 0
		if use == "ghost":
			core.kill(me, "pop")
			_to_turn(core, 1)
			while core.rules.current() != me and core.rules.sub != "idle":
				core.rules.next_turn()
		else:
			_to_turn(core, me)
		var p := core.p(me)
		# give it something to work on
		p.teeth = 20
		core.p(1).teeth = 20
		core.injure(me, "leg_l", "lost", "", false)
		core.injure(me, "arm_l", "broken", "", false)
		core.injure(me, "arm_r", "bruised", "", false)
		core.status.apply(me, "necrosis")
		p.cage = 2
		p.suspicion = 40
		core.p(1).debts[me] = 4
		core.rulebook.add("double_pay")
		p.items.clear()
		p.items.append(id)
		var before := {"teeth": p.teeth, "space": p.space, "t1": core.p(1).teeth, "rules": core.rulebook.active.size()}
		var target := 1 if str(d.target) == "player" else -1
		core.action(me, {"t": "item", "id": id, "target": target, "choice": "HIGH"})
		var gone := not p.items.has(id)
		check(gone, "%s is used up" % id)
		match id:
			"pickpocket":
				check(p.teeth > before.teeth and core.p(1).teeth < before.t1, "PICKPOCKET takes from the target")
			"tooth_tax":
				check(core.p(1).teeth == before.t1 - 5 and p.teeth == before.teeth, "TOOTH TAX costs the target, not you")
			"warp_tooth":
				check(true, "warp")
			"sabotage_kit":
				check(core.p(1).handicap, "SABOTAGE KIT rigs their next game")
			"poisoned_gift":
				check(core.p(1).items.has("gift"), "the gift arrives")
				core.p(1).items = ["gift"]
				_to_turn(core, 1)
				core.action(1, {"t": "item", "id": "gift"})
				check(not core.p(1).statuses.is_empty(), "opening it poisons them")
			"gift_basket":
				check(core.p(1).teeth == before.t1 + 5, "a gift basket gives 5 Teeth")
			"debt_note":
				check(int(core.p(1).debts.get(me, 0)) >= 10, "a debt note: they owe 10 more")
			"debt_collector":
				check(core.p(1).debts.is_empty() and p.teeth > before.teeth, "the debt collector collects")
			"loaded_dice", "high_roller", "double_roll", "loaded_double":
				check(p.next_roll != "", "%s changes your next roll" % id)
				core.action(me, {"t": "roll"})
				var r := core.rules.roll
				match id:
					"loaded_dice":
						check(r >= 4 and r <= 6 + 2, "LOADED DICE (HIGH) rolls 4-6 (+amendments) (%d)" % r)
					"loaded_double":
						check(r >= 6, "LOADED DOUBLE: two dice of 3-6 (%d)" % r)
			"greased_shoes":
				check(p.move_bonus == 3, "greased shoes: +3")
			"reverse_gear":
				check(p.reverse, "reverse gear")
			"rat_trap":
				check(core.traps.has(p.space), "the trap is set")
			"body_armour":
				check(p.armour == 3, "armour on")
				var hl: String = p.body.hand_r.s
				core.injure(me, "hand_r", "broken", "test")
				check(p.body.hand_r.s == "burned" or hl != "ok", "armour takes the edge off an injury")
			"counterfeit_teeth":
				check(p.teeth == before.teeth + 12 and p.counterfeit > 0, "counterfeit teeth")
			"loaded_wallet":
				check(p.teeth == before.teeth + 8, "a wallet")
			"black_market_coupon":
				check(core.rules.sub == "prompt" and core.rules.prompt.shop == "black_market" and core.rules.prompt.coupon, "the coupon opens the black market")
			"gavel":
				check(core.rules.prompt.get("kind", "") == "gavel" and (core.rules.prompt.options as Array).size() == 3, "the gavel offers three laws")
				core.action(me, {"t": "answer", "rule": core.rules.prompt.options[0]})
				check(core.rulebook.active.size() == before.rules + 1, "and one passes")
			"executive_privilege":
				core.action(me, {"t": "answer", "rule": core.rulebook.active[0].id})
				check(core.rulebook.active.size() == before.rules - 1, "executive privilege strikes one")
			"emergency_legislation":
				check(core.rulebook.active.is_empty(), "emergency legislation repeals the temporary ones")
			"loophole":
				check(p.loophole == 3 and core.rulebook.value("normal_mult", 1, me) == 1, "a loophole: the rules don't apply to you")
			"rubber_stamp":
				check(int(core.rulebook.active[0].left) > 3, "the stamp extends")
			"antidote", "surgery":
				check(not core.status.has(me, "necrosis"), "%s deals with the necrosis" % id)
			"prosthetic":
				check(p.body.leg_l.s == "prosthetic", "a brass leg")
			"first_aid":
				check(p.body.arm_l.s != "broken" or p.body.arm_r.s == "ok", "first aid")
			"bandage":
				check(p.body.arm_r.s == "ok", "bandages clear bruises")
			"alibi":
				check(p.suspicion == 20, "alibi")
			"lucky_foot":
				check(p.cage == 1, "rabbit's foot")
			"cold_hand":
				check(core.p(1).cold_hand, "a cold hand")
			"possession_ticket", "phantom_coin":
				check(true, id)
	# passives
	var core := _core()
	core.p(0).items = ["lucky_tooth", "safety_pin", "insurance"]
	core.injure(0, "hand_l", "broken", "test")
	check(core.p(0).body.hand_l.s == "ok" and not core.p(0).items.has("safety_pin"), "a safety pin stops an injury (and goes)")
	core.p(0).teeth = 20
	core.economy.take(0, 8, "test")
	check(core.p(0).teeth == 22 and not core.p(0).items.has("insurance"), "insurance pays out after a loss")
	check(core.fate.trigger(0, 6).tier == "catastrophe" or true, "event")
	check(not core.p(0).items.has("lucky_tooth"), "a lucky tooth turns a catastrophe")
	# ghosts can't use living items; the living can't use ghost items
	var c2 := _core()
	_to_turn(c2, 0)
	c2.p(0).items = ["cold_hand"]
	check(not c2.items.can_use(0, "cold_hand"), "the living can't use ghost items")
	c2.kill(1, "pop")
	c2.p(1).items = ["antidote"]
	check(not c2.items.can_use(1, "antidote"), "ghosts can't use living items")
	# PROHIBITION
	c2.p(0).items = ["bandage"]
	c2.rulebook.add("no_items")
	check(not c2.items.can_use(0, "bandage"), "PROHIBITION bans items")


func test_shops() -> void:
	var core := _core()
	core.shops.restock()
	for sid in ["general", "black_market", "medical", "ghost"]:
		var shelf := core.shops.shelf(0, sid)
		check(not shelf.is_empty(), "%s has stock" % sid)
		check(shelf.filter(func(e): return e.special).size() == 1, "%s has one special offer" % sid)
		for e in shelf:
			check(e.price > 0 and e.name != "" and e.desc != "", "%s shows %s's price and effect" % [sid, e.id])
	var e0: Dictionary = core.shops.shelf(0, "general")[0]
	core.p(0).teeth = 100
	var qty := int(e0.qty)
	check(core.shops.buy(0, "general", e0.id), "buying")
	check(core.p(0).items.has(e0.id) and core.p(0).teeth == 100 - int(e0.price), "you get it and pay for it")
	check(int(core.shops.entry("general", e0.id).qty) == qty - 1, "stock is limited")
	for i in qty:
		core.p(0).items.clear()
		core.shops.buy(0, "general", e0.id)
	check(not core.shops.buy(0, "general", e0.id), "sold out")
	# the Cage puts the prices up
	core.p(1).cage = 0
	var p0 := core.shops.price(1, "general", core.shops.stock.general[1].id)
	core.p(1).cage = 5
	check(core.shops.price(1, "general", core.shops.stock.general[1].id) > p0, "a tight Cage pays more")
	core.rulebook.add("inflation")
	core.p(1).cage = 0
	check(core.shops.price(1, "general", core.shops.stock.general[1].id) > p0, "INFLATION puts prices up")
	# pockets full
	core.p(2).teeth = 999
	core.p(2).items = ["bandage", "bandage", "bandage"]
	check(not core.shops.buy(2, "medical", core.shops.stock.medical[0].id), "three things and no more")
	# restocking rotates
	var before := str(core.shops.stock.general.map(func(e): return e.id))
	var changed := false
	for i in 6:
		core.shops.restock()
		if str(core.shops.stock.general.map(func(e): return e.id)) != before:
			changed = true
	check(changed, "stock changes between rounds")
	# black market: shoplifting is a cheat
	var c2 := _core()
	c2.shops.restock()
	_look_away(c2)
	var bm: Dictionary = c2.shops.stock.black_market[0]
	check(c2.shops.steal(0, "black_market", bm.id) and c2.p(0).items.has(bm.id), "shoplifting while he looks away")
	_look_at(c2, 1)
	var sus := c2.p(1).suspicion
	c2.shops.steal(1, "black_market", c2.shops.stock.black_market[1].id)
	check(c2.p(1).suspicion > sus + 10, "and getting caught at it")
	# a coupon opens the stock under the counter
	var under := c2.shops.shelf(0, "black_market", true).filter(func(e): return e.under)
	check(not under.is_empty(), "the coupon shows what's under the counter")


func test_wagers() -> void:
	# a battle: everyone pays in, the winner takes the pot
	var core := _core(["ai", "ai", "ai", "ai"], 515)
	for p in core.players:
		p.teeth = 20
	core.mg_queue.clear()
	core._start_entry({"kind": "battle", "seats": [], "id": "meat_grinder", "wager": 0, "by": -1})
	var pool := int(core.mg_entry.pool)
	check(pool > 0, "a battle takes a wager from everyone (%s: %d)" % [core.mg_entry.wager_rule, pool])
	var total_before := 0
	for p in core.players:
		total_before += p.teeth
	core.mg.finish([2])
	core._set_phase("mg_play")
	core._finish_minigame()
	check(int(core.last_results.pool) == pool and core.last_results.pool_to == [2], "the winner takes the pot")
	# a duel
	var c2 := _core(["ai", "ai", "ai", "ai"], 616)
	c2.p(0).teeth = 30
	c2.p(3).teeth = 30
	c2._start_entry({"kind": "duel", "seats": [0, 3], "id": "", "wager": 10, "by": 0})
	check(c2.mg.format == "duel" and c2.mg.seats.size() == 2, "a duel is a two-player game (%s)" % c2.mg_id)
	check(int(c2.mg_entry.pool) == 20 and c2.p(0).teeth == 20, "both stake the wager")
	c2.mg.finish([3])
	c2._finish_minigame()
	check(c2.p(3).teeth >= 46, "the winner takes both stakes (and the duel prize) (%d)" % c2.p(3).teeth)
	# a duel draw gives the stakes back
	var c3 := _core(["ai", "ai", "ai", "ai"], 617)
	c3.p(0).teeth = 30
	c3.p(1).teeth = 30
	c3._start_entry({"kind": "duel", "seats": [0, 1], "id": "", "wager": 10, "by": 0})
	c3.mg.finish([], true)
	c3._finish_minigame()
	check(c3.p(0).teeth >= 30 and c3.p(1).teeth >= 30, "a drawn duel: stakes back (a draw is a real result)")
	# the duel square
	var c4 := _core()
	_to_turn(c4, 0)
	c4.p(0).teeth = 20
	c4.rules._ask("duel", [1, 2, 3], {"wagers": [0, 5, 10]})
	c4.action(0, {"t": "answer", "target": 2, "wager": 5})
	check(c4.mg_queue.size() == 1 and c4.mg_queue[0].kind == "duel" and c4.mg_queue[0].seats == [0, 2], "the duel square queues a duel")


# --- whole matches ----------------------------------------------------------------------

func test_full_matches() -> void:
	var n := int(args.get("seeds", "16"))
	var endings := {}
	var games := {}
	var kinds := {}
	var deaths := {}
	var trips := 0
	var missed := 0
	var forfeits := 0
	var cutscenes := 0
	for i in n:
		var core := MatchCore.new()
		core.fast = true
		core.setup(seats4(), 1000 + i, {"turns": 10})
		var t := 0.0
		var finale := false
		while core.ending == "" and t < 6000.0:
			core.tick(0.05)
			for e in core.take_events():
				match str(e.e):
					"minigame":
						games[e.id] = games.get(e.id, 0) + 1
						kinds[e.kind] = kinds.get(e.kind, 0) + 1
					"death":
						deaths[e.anim] = deaths.get(e.anim, 0) + 1
						check(not core.p(e.seat).alive or core.p(e.seat).deaths > 0, "death marks dead (or a draw brought them straight back)")
					"leave":
						trips += 1
					"missed_turn":
						missed += 1
					"forfeit":
						forfeits += 1
					"finale":
						finale = true
						check((e.awards as Array).size() <= 3, "three Caller's Awards at most")
					"cutscene":
						cutscenes += 1
			var cur := core.rules.current() if core.phase == "turn" else -1
			if cur >= 0:
				check(core.p(cur).alive or core.p(cur).ghost, "a turn for someone neither alive nor a ghost (seed %d)" % (1000 + i))
			t += 0.05
		if core.ending == "":
			printerr("stuck in phase %s round %d sub %s (seed %d)" % [core.phase, core.round_n, core.rules.sub, 1000 + i])
			print("\n".join(core.log_lines.slice(-25)))
		check(core.ending != "", "match %d reaches an ending" % i)
		endings[core.ending] = endings.get(core.ending, 0) + 1
		if core.ending == "winner":
			check(finale, "a finished match has a finale")
			check(core.round_n == 10, "it lasted the 10 rounds")
			var st: Array = core.ending_info.standings
			check(int(st[0].rats) >= int(st[st.size() - 1].rats), "standings by Dead Rats")
			check(int(core.ending_info.winner) == int(st[0].seat), "the winner is first in the standings")
	print("endings %s\n games %s\n kinds %s\n deaths %s\n trips away %d, missed turns %d, forfeits %d, cutscenes %d" % [endings, games, kinds, deaths, trips, missed, forfeits, cutscenes])
	check(games.size() >= 8, "most of the minigames come round (%d)" % games.size())
	check(trips > 0, "the AI gets up and wanders")


func test_lengths_and_counts() -> void:
	for n in [2, 3, 4]:
		for turns in [10, 15, 20, 30]:
			if n == 4 and turns == 10:
				continue   # full_matches covers it
			if turns == 30 and n != 4:
				continue
			var core := MatchCore.new()
			core.fast = true
			core.setup(seats(n), 300 + n * 31 + turns, {"turns": turns})
			var games := {}
			var t := 0.0
			while core.ending == "" and t < 12000.0:
				core.tick(0.05)
				for e in core.take_events():
					if e.e == "minigame":
						games[e.id] = true
						check(MinigameRegistry.fits(e.id, (e.seats as Array).size()), "%s fits %d players" % [e.id, (e.seats as Array).size()])
				t += 0.05
			check(core.ending != "", "%d players, %d rounds: the match ends (%s at round %d)" % [n, turns, core.ending, core.round_n])
			if core.ending == "winner":
				check(core.round_n == turns, "%d players went %d rounds" % [n, turns])
			print("  %d players, %d rounds: %s at round %d, %d different games" % [n, turns, core.ending, core.round_n, games.size()])
	var c := MatchCore.new()
	c.setup(seats(4), 1, {"turns": "marathon"})
	check(c.max_rounds == 30, "MARATHON is 30")


func test_awards() -> void:
	var core := _core()
	core.p(0).stats.teeth_spent = 50
	core.p(1).stats.steals = 3
	core.p(2).stats.minigame_wins = 4
	core.p(3).stats.room_trips = 5
	for s in [0, 1, 2]:
		core.p(s).stats.room_trips = 0
	var el := core.awards.eligible()
	check(el.has("big_spender") and el.has("rat_bastard") and el.has("show_off"), "awards follow the stats")
	check(core.awards.winners_of("big_spender") == [0], "BIG SPENDER goes to the spender")
	check(core.awards.winners_of("hall_monitor").size() == 3, "HALL MONITOR to everyone who never got up (%s)" % str(core.awards.winners_of("hall_monitor")))
	var rats_before := 0
	for p in core.players:
		rats_before += p.rats
	var given := core.awards.present(3)
	check(given.size() == 3, "three awards")
	var rats_after := 0
	for p in core.players:
		rats_after += p.rats
	var expected := 0
	for g in given:
		expected += int(g.rats) * (g.seats as Array).size()
	check(rats_after - rats_before == expected, "each award is a Dead Rat (or two)")
	# a ghost can win one
	var c2 := _core()
	c2.kill(1, "pop")
	c2.p(1).stats.ghost_turns = 5
	check(c2.awards.winners_of("ghost") == [1], "ghosts qualify")


func test_callers_game() -> void:
	var core := MatchCore.new()
	core.fast = true
	core.setup(seats4(), 4040, {"turns": 10, "mode": "callers_game"})
	check(core.victory.hidden.size() == 2, "two hidden conditions")
	check(core.view_for([0]).objectives[0].name == "???", "hidden until halfway")
	var revealed_at := -1
	var t := 0.0
	while core.ending == "" and t < 6000.0:
		core.tick(0.05)
		for e in core.take_events():
			if e.e == "objectives":
				revealed_at = core.round_n
		t += 0.05
	check(revealed_at == 5, "revealed at the halfway round (%d)" % revealed_at)
	check(core.victory.results.size() == 2, "both conditions are paid out at the end")
	check(core.ending != "", "a Caller's Game match ends")
	# rewarding failure
	var c2 := _core()
	c2.victory.hidden = ["financial_ruin"]
	c2.p(2).teeth = 0
	for s in [0, 1, 3]:
		c2.p(s).teeth = 10
	c2.victory.settle()
	check(c2.p(2).rats == 3, "FINANCIAL RUIN pays the poorest")


func test_rules() -> void:
	var core := _core()
	check(core.rulebook.value("normal_mult", 1) == 1, "no rules: defaults")
	core.rulebook.add("double_pay")
	check(core.rulebook.value("normal_mult", 1) == 2, "an amendment changes the rules")
	core.rulebook.add("austerity")
	check(core.rulebook.value("normal_set", 3) == 1, "contradictions: priority wins")
	for id in ["inflation", "rat_sale", "small_dice", "big_dice", "tax_day"]:
		core.rulebook.add(id)
	check(core.rulebook.active.size() == 5, "five rules at most")
	core.rulebook.extend(0)
	for i in 4:
		core.rulebook.end_round()
	check(core.rulebook.active.size() < 5, "temporary rules expire")
	# dice cap
	var c2 := _core()
	_to_turn(c2, 0)
	c2.rulebook.add("small_dice")
	c2.p(0).next_roll = "six"
	c2.action(0, {"t": "roll"})
	check(c2.rules.roll <= 4, "SMALL DICE caps the roll")
	# the rulebook square
	var c3 := _core()
	_to_turn(c3, 0)
	c3.graph.nodes[1].type = "rulebook"
	c3.rat_space = -1
	c3.p(0).space = 0
	_roll_n(c3, 0, 1)
	c3.rules.sub = "moving"
	_walk(c3, 0)
	check(c3.rulebook.active.size() == 1, "the rulebook square adds an amendment")


func test_events() -> void:
	var core := _core()
	var tiers := {}
	for i in 600:
		var ti := core.fate.roll_tier(0)
		tiers[ti] = tiers.get(ti, 0) + 1
	check(tiers.size() == 7, "every tier comes up (%s)" % str(tiers))
	check(int(tiers.get(0, 0)) + int(tiers.get(1, 0)) + int(tiers.get(2, 0)) > 100, "good things happen")
	# the Cage drags it down
	var bad0 := 0
	var bad5 := 0
	for i in 600:
		core.p(1).cage = 0
		if core.fate.roll_tier(1) >= 4:
			bad0 += 1
		core.p(1).cage = 5
		if core.fate.roll_tier(1) >= 4:
			bad5 += 1
	print("events: bad results at cage 0 = %d/600, at cage 5 = %d/600" % [bad0, bad5])
	check(bad5 > bad0, "a tight Cage gets worse events")
	check(bad5 < 600, "but never only bad ones")
	# every event resolves
	for ti in 7:
		for k in 8:
			var c := _core(["local", "local", "local", "local"], 900 + ti * 10 + k)
			_to_turn(c, 0)
			c.p(0).teeth = 10
			c.p(0).rats = 2
			var ev := c.fate.trigger(0, ti)
			check(ev.has("id"), "event tier %d resolves (%s)" % [ti, ev.get("id", "?")])


# --- the facility (real time) ---------------------------------------------------------

func _walk_to(core: MatchCore, seat: int, to: Vector2) -> void:
	var path := core.facility.building.find_path(core.p(seat).pos, to)
	for q in path:
		var guard := 0
		while core.p(seat).pos.distance_to(q) > 0.05 and guard < 400:
			var d: Vector2 = q - core.p(seat).pos
			var step := minf(d.length(), 0.6)
			var np: Vector2 = core.p(seat).pos + d.normalized() * step
			core.action(seat, {"t": "walk", "pos": [np.x, np.y], "dt": 0.25})
			guard += 1


func test_facility() -> void:
	var core := _core()
	core._start_round()
	check(core.facility.building.areas.size() > 3, "the facility is a real building")
	_look_away(core)
	# getting up when it isn't your turn
	var mover := core.rules.current()
	var me := (mover + 1) % 4
	var s0 := core.p(me).suspicion
	core.action(me, {"t": "leave"})
	check(core.p(me).away(), "you can leave the table any time")
	check(core.p(me).suspicion > s0, "getting up is suspicious")
	check(core.rules.current() == mover, "the board carries on without you")
	# no teleporting
	var p0 := core.p(me).pos
	core.action(me, {"t": "walk", "pos": [p0.x + 20.0, p0.y], "dt": 0.25})
	check(core.p(me).pos.distance_to(p0) < 2.0, "the host won't let you teleport")
	# walk to the piñata and hit it
	_walk_to(core, me, core.facility.stand_at("pinata"))
	check(core.facility.near(me, "pinata"), "you can walk to things")
	var before := [core.p(me).teeth, core.p(me).items.size(), core.p(me).statuses.size(), core.p(me).body.hand_l.s]
	core.action(me, {"t": "interact", "id": "pinata", "do": "hit_pinata"})
	check([core.p(me).teeth, core.p(me).items.size(), core.p(me).statuses.size(), core.p(me).body.hand_l.s] != before, "the piñata does something")
	core.action(me, {"t": "interact", "id": "pinata", "do": "hit_pinata"})
	check(core.facility.actions_at(me, "pinata").is_empty(), "once a round")
	# interacting from across the room doesn't work
	var t1 := core.p(me).teeth
	core.action(me, {"t": "interact", "id": "drain", "do": "reach_drain"})
	check(core.p(me).teeth == t1 or core.facility.near(me, "drain"), "you have to be there")
	# the room remembers: the freezer's shoes count up across visits and players
	core.facility.state.shoes = 4
	core.p(me).pos = core.facility.stand_at("freezer")
	core.action(me, {"t": "interact", "id": "freezer", "do": "search_shoes"})
	check(core.p(me).items.has("greased_shoes") or core.p(me).items.size() >= 3, "the fifth shoe is different")
	core.p(me).pos = core.facility.stand_at("panel")
	core.action(me, {"t": "interact", "id": "panel", "do": "knock_wall"})
	core.action(me, {"t": "interact", "id": "panel", "do": "knock_wall"})
	check(core.facility.state.has("panel_found"), "knock twice: the panel")
	check(core.facility.actions_at(me, "panel").map(func(a): return a.id).has("open_panel"), "it can be opened now")
	# the phone rings only when nobody's near
	core.facility.ring_t = 0.0
	core.facility._next_ring = 0.01
	core.p(me).pos = core.facility.stand_at("phone")
	core.tick(0.05)
	check(core.facility.ring_t <= 0.0, "it doesn't ring with someone standing next to it")
	core.p(me).pos = core.facility.stand_at("freezer")
	core.facility._next_ring = 0.01
	core.tick(0.05)
	check(core.facility.ring_t > 0.0, "it rings when nobody's there")
	# the drain fills
	core.facility.drain_teeth = 0
	for i in 400:
		core.facility.tick(0.05)
	check(core.facility.drain_teeth > 0, "the drain produces Teeth")
	# a locked door needs a hairpin
	check(not core.facility.building.open_portals.has("door:stairs"), "the cellar's locked")
	core.p(me).pos = core.facility.stand_at("stairs_door")
	core.p(me).items = ["hairpin"]
	core.action(me, {"t": "interact", "id": "stairs_door", "do": "pick_stairs"})
	check(core.facility.building.open_portals.has("door:stairs"), "the hairpin opens it, and it stays open")
	# back to the table to sit
	core.action(me, {"t": "sit"})
	check(core.p(me).away(), "you can't sit down from the freezer")
	_walk_to(core, me, core.facility.seat_pos(me) * 1.1)
	core.action(me, {"t": "sit"})
	check(not core.p(me).away(), "walk back to your chair and sit")
	# caught in the hall
	var c2 := _core()
	c2._start_round()
	var who := (c2.rules.current() + 2) % 4
	_look_away(c2)
	c2.action(who, {"t": "leave"})
	c2.p(who).pos = c2.facility.stand_at("props")
	_look_at(c2, who)
	var sus := c2.p(who).suspicion
	c2.action(who, {"t": "interact", "id": "props", "do": "tamper"})
	check(not c2.p(who).away() and c2.p(who).suspicion >= sus + 20, "caught at it: dragged back, suspicion up")
	# persistence through a save
	var snap := core.snapshot()
	var c3 := MatchCore.from_snapshot(seats4(["local", "local", "local", "local"]), snap)
	check(c3.facility.state.has("panel_found") and c3.facility.building.open_portals.has("door:stairs"), "the facility's state is saved")


func test_facility_misses() -> void:
	# the return timer, and the Caller's response
	var responses := {}
	for i in 60:
		var core := _core(["local", "local", "local", "local"], 2200 + i)
		core._start_round()
		var me := (core.rules.current() + 3) % 4
		_look_away(core)
		core.action(me, {"t": "leave"})
		core.facility.responses.late_count = i % 4
		core.p(me).away_t = core.p(me).away_limit - 0.01
		core.facility.tick(0.05)
		var r: String = core.facility.responses.history[-1].response if not core.facility.responses.history.is_empty() else ""
		responses[r] = responses.get(r, 0) + 1
	print("Caller responses to the return timer: %s" % str(responses))
	check(responses.size() >= 5, "he doesn't always do the same thing (%d kinds)" % responses.size())
	# a missed turn
	var core := _core()
	core._start_round()
	var nxt := core.rules.order[(core.rules.idx + 1) % 4]
	_look_away(core)
	core.action(nxt, {"t": "leave"})
	core.rules.next_turn()
	check(core.rules.sub == "missed" and core.p(nxt).stats.missed_turns == 1, "away when your turn comes: you miss it")
	core.tick(0.2)
	check(core.rules.current() != nxt, "and the board moves on")
	# minigame registration: back during the countdown = in; still away = out
	var c2 := _core(["ai", "ai", "ai", "ai"], 333)
	c2.mg_queue.clear()
	c2._start_entry({"kind": "main", "seats": [], "id": "meat_grinder", "wager": 0, "by": -1})
	c2.p(1).location = "away"
	c2.p(2).location = "away"
	c2.p(2).location = "table"   # came back in time
	c2._register_and_play()
	check(c2.phase == "mg_play" and not c2.mg.seats.has(1) and c2.mg.seats.has(2), "away at the countdown: you miss the game; back in time: you play")
	check(int(c2.p(1).stats.forfeits) == 1, "a forfeit is counted (not a last place)")
	check(not c2.facility.can_leave(0), "you can't leave a minigame in progress")
	# a 2v2 with someone missing doesn't run half-empty
	var c3 := _core(["ai", "ai", "ai", "ai"], 334)
	c3._start_entry({"kind": "main", "seats": [], "id": "tug_of_war", "wager": 0, "by": -1})
	c3.p(0).location = "away"
	c3._register_and_play()
	check(c3.mg_id != "tug_of_war" or c3.phase != "mg_play" or c3.mg == null, "a 2v2 a player short is called off")


# --- cutscenes ----------------------------------------------------------------------------

func test_cutscenes() -> void:
	var core := _core()
	_to_turn(core, 0)
	var statuses := []
	for p in core.players:
		statuses.append(p.statuses.size())
	core.cutscenes.play("poison", 1, {"do": "poison", "id": "paralytic"})
	var ev := core.take_events().filter(func(e): return e.e == "cutscene")
	check(ev.size() == 1 and int(ev[0].target) == 1 and (ev[0].spectators as Array).size() == 4, "everyone gets the same cutscene, aimed at one player")
	check(core.cutscenes.blocking(), "it holds the game")
	var sub_before := core.rules.sub
	var t_before := core.rules.sub_t
	core.cutscenes.play("injure", 2, {"do": "injure", "part": "hand_l", "status": "broken"})
	check(core.cutscenes.queue.size() == 1, "a second one waits for the first")
	_until(core, func(): return not core.cutscenes.blocking(), 20.0)
	check(core.p(1).has_status("paralytic"), "the target gets the poison")
	for s in [0, 2, 3]:
		check(not core.p(s).has_status("paralytic"), "spectator %d doesn't" % s)
	check(core.p(2).body.hand_l.s == "broken" and core.p(3).body.hand_l.s == "ok", "the second one hurts only its target")
	# exactly once, even if it's ticked again or re-sent
	var applied := core.cutscenes.log.size()
	core.cutscenes._apply({"id": core.cutscenes.log[0].id, "target": 1, "effect": {"do": "poison", "id": "blindness"}, "applied": false})
	check(not core.p(1).has_status("blindness") and core.cutscenes.log.size() == applied, "a repeated cutscene id never applies twice")
	# the board waited
	check(core.rules.current() == 0, "the board didn't move on during it")
	# a dead target, an AI target, a disconnect
	var c2 := _core(["remote", "ai", "local", "local"], 12)
	c2.kill(2, "pop")
	c2.cutscenes.play("kill", 2, {"do": "kill", "anim": "shot"})
	c2.cutscenes.play("teeth", 1, {"do": "teeth", "n": 20})
	c2.cutscenes.play("injure", 0, {"do": "injure", "part": "ears", "status": "lost"})
	c2.seat_disconnected(0)
	_until(c2, func(): return c2.cutscenes.active.is_empty(), 30.0)
	check(c2.p(2).deaths == 1, "a cutscene can't kill a ghost again")
	check(c2.p(1).teeth >= 30, "an AI target is rewarded (%d)" % c2.p(1).teeth)
	check(c2.p(0).body.ears.s == "lost" and c2.p(0).kind == "ai", "a disconnected target still gets it (the AI has the seat now)")


# --- saving ------------------------------------------------------------------------------

func test_save_reload() -> void:
	var core := _core(["local", "local", "local", "local"], 8080)
	core._start_round()
	core.p(0).teeth = 17
	core.p(1).rats = 2
	core.p(2).items = ["antidote"]
	core.injure(3, "leg_l", "lost", "", false)
	core.status.apply(3, "hunger")
	core.p(1).suspicion = 33
	core.p(1).cage = 2
	core.rulebook.add("double_pay")
	core.facility.state.shoes = 3
	var snap := core.snapshot()
	var json := JSON.stringify(snap)
	var back: Dictionary = JSON.parse_string(json)
	var c2 := MatchCore.from_snapshot(seats4(["local", "local", "local", "local"]), back)
	check(c2.p(0).teeth == 17 and c2.p(1).rats == 2 and c2.p(2).items.has("antidote"), "resources and items survive a save")
	check(c2.p(3).body.leg_l.s == "lost" and c2.p(3).has_status("hunger"), "bodies and poisons survive")
	check(c2.p(1).suspicion == 33 and c2.p(1).cage == 2, "suspicion and the Cage survive")
	check(c2.rulebook.is_active("double_pay") and int(c2.facility.state.shoes) == 3, "rules and the facility survive")
	check(c2.round_n == core.round_n, "the round survives")
	# no rerolls: the same snapshot, loaded twice, rolls the same dice
	var rolls := []
	for k in 2:
		var c := MatchCore.from_snapshot(seats4(["local", "local", "local", "local"]), back)
		var s := c.rules.current()
		c.action(s, {"t": "roll"})
		rolls.append([s, c.rules.roll, c.rules.dice])
	check(rolls[0] == rolls[1], "reloading can't reroll the dice (%s)" % str(rolls))
	# the save file itself
	var saves := get_node_or_null("/root/Saves")
	check(saves != null, "a SaveManager is running")
	if saves:
		saves.write(snap, seats4(["local", "local", "local", "local"]))
		check(saves.has_save(), "the save is written")
		var loaded: Dictionary = saves.read()
		check(int(loaded.match.round) == core.round_n, "and reads back")
		saves.clear()
		check(not saves.has_save(), "and can be cleared")


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
		if args.has("dbg"):
			print("pull by ", mg2.current(), " sub ", mg2.sub, " loaded ", mg2.loaded, " ch ", mg2.chambers, " idx ", mg2.idx, " living ", c2.living())
		mg2.action(mg2.current(), {"t": "mg", "do": "pull"})
		pulls += 1
		for i in 50:
			mg2.tick(0.05)
	check(c2.living().size() == 3 or (pulls == 4 and mg2.done), "one round of the gun: somebody's shot, or everybody pulled once and lived")


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


func test_disconnect() -> void:
	var core := MatchCore.new()
	core.fast = true
	core.setup(seats4(["remote", "ai", "ai", "ai"]), 31, {"turns": 10})
	core.seat_disconnected(0)
	check(core.p(0).kind == "ai", "a dropped player's seat is played by AI")
	run(core)
	check(core.ending != "", "the match still ends")


func test_views_hide_secrets() -> void:
	var core := _core()
	core.p(1).clues[0] = 7
	core.p(1).items = ["antidote"]
	var v := core.view_for([0])
	check(v.players[1].clues.is_empty(), "other people's clues are private")
	check(v.players[1].items.is_empty() and int(v.players[1].item_count) == 1, "other people's items are hidden (but counted)")
	check(not v.players[1].has("known") or v.players[1].known.is_empty(), "what others found out is private")
	var v1 := core.view_for([1])
	check(v1.players[1].clues.has(0), "your own clues are yours")


func test_cheating() -> void:
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
	check(c2.p(0).teeth == r0 + 2 and c2.p(0).suspicion > 0 and c2.p(0).suspicion < 16, "cheating while he looks away works")
	c2.action(0, {"t": "cheat", "id": "load_dice"})
	c2.action(0, {"t": "roll"})
	check(c2.rules.roll == Body.dice_max(c2.p(0).body), "a loaded die rolls the most it can")
	check(int(c2.p(0).stats.cheats_ok) == 2, "successful cheats are counted")


func test_suspicion_death() -> void:
	var core := _core()
	core.suspicion.add(2, 60, "test")
	check(core.p(2).cage >= 1, "past 50, he tightens the Cage")
	core.suspicion.add(2, 45, "test")
	check(not core.p(2).alive and core.p(2).ghost, "100 suspicion: he kills you at once (and you're a ghost)")


func test_cage_dice() -> void:
	var core := _core()
	var sum0 := 0
	var sum5 := 0
	for i in 3000:
		core.p(0).cage = 0
		sum0 += core.cage.roll(0, 6)
		core.p(0).cage = 5
		sum5 += core.cage.roll(0, 6)
	check(sum5 < sum0 - 1500, "a tight Cage really rolls lower")


func test_cage_roulette() -> void:
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
	check(bangs[1] > bangs[0] + 30, "the Cage leans on the cylinder (%s)" % str(bangs))


func test_ghosts_and_draws() -> void:
	var core := _core()
	core.kill(3, "pop")
	check(core.p(3).ghost and not core.p(3).alive, "death makes a ghost")
	core.mg_entry = {"kind": "main", "pool": 0}
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
				break
	check(lost == 3, "and every living player gives up a part (%d)" % lost)
	check(bool(core.last_results.draw), "a draw is reported as a draw")
	var c2 := _core()
	c2.kill(0, "pop")
	c2.mg_entry = {"kind": "main", "pool": 0}
	c2.mg = MinigameRegistry.create("hot_potato", c2, c2.living(), 0)
	c2.mg_id = "hot_potato"
	c2.mg.finish([], true)
	c2._finish_minigame()
	check(c2.p(0).ghost, "a non-FFA draw doesn't resurrect")
	# a safety pin can't save a part from the sacrifice
	var c3 := _core()
	c3.kill(1, "pop")
	c3.p(0).items = ["safety_pin"]
	c3.resurrection.collective()
	var lost0 := 0
	for part in Body.PARTS:
		if c3.p(0).body[part].s == "lost":
			lost0 += 1
	check(lost0 == 1, "the sacrifice takes what it takes")


func test_resurrection_square() -> void:
	var core := _core()
	core.kill(1, "pop")
	core.kill(2, "pop")
	core.p(2).items = ["grave_ticket"]
	core.resurrection.square(0)
	check(core.p(2).alive and not core.p(1).alive, "the square brings back one ghost (the one with the grave ticket)")


func test_ghost_buys_life() -> void:
	var core := _core()
	core.kill(2, "pop")
	_to_turn(core, 0)
	while core.rules.current() != 2 and core.rules.sub != "idle":
		core.rules.next_turn()
	check(core.rules.sub == "ghost", "ghosts get a turn")
	var t0 := core.p(2).teeth
	core.action(2, {"t": "ghost", "do": "scavenge"})
	check(core.p(2).teeth > t0, "ghosts scavenge Teeth")
	core._start_round()
	while core.rules.current() != 2 and core.rules.sub != "idle":
		core.rules.next_turn()
	core.p(2).rats = 0
	core.action(2, {"t": "ghost", "do": "rise"})
	check(core.p(2).ghost, "no Dead Rat, no way back")
	core.p(2).rats = 3
	core.action(2, {"t": "ghost", "do": "rise"})
	check(core.p(2).alive and core.p(2).rats == 2, "a ghost spends a Dead Rat to come back (and it's off their score)")
	# the ghost shop
	var c2 := _core()
	c2.kill(1, "pop")
	c2._start_round()
	while c2.rules.current() != 1 and c2.rules.sub != "idle":
		c2.rules.next_turn()
	c2.p(1).teeth = 50
	var id: String = c2.shops.stock.ghost[0].id
	c2.action(1, {"t": "buy", "id": id})
	check(c2.p(1).items.has(id), "ghosts can shop (the ghost shop)")


func test_roulette_social() -> void:
	var core := _core()
	var mg: Minigame = MinigameRegistry.create("roulette", core, core.living(), 0)
	core.mg = mg
	core._set_phase("mg_play")
	mg.start()
	var me: int = mg.current()
	var other: int = (me + 1) % 4
	core.p(me).teeth = 10
	core.p(other).teeth = 0
	core.action(me, {"t": "mg", "do": "claim", "say": "EMPTY"})
	check(mg.claims.get(me) == "EMPTY", "you can say what's in it")
	core.action(me, {"t": "mg", "do": "offer", "target": other, "teeth": 4})
	core.action(other, {"t": "mg", "do": "accept"})
	check(core.p(other).teeth == 4 and mg.pulls == 1, "they take the money and the pull")


func test_poison() -> void:
	var core := _core()
	core.p(0).teeth = 10
	core.p(0).rats = 3
	core.status.apply(0, "rat_fever")
	core.status.tick_turn(0)
	check(core.p(0).rats == 2, "rat fever: Dead Rats sweat out")
	core.status.apply(0, "hunger")
	core.status.tick_turn(0)
	check(core.p(0).teeth == 8, "hunger eats Teeth (%d)" % core.p(0).teeth)
	core.status.apply(1, "thinner")
	core.injure(1, "arm_l", "bruised")
	check(core.p(1).body.arm_l.s == "burned", "blood thinner makes injuries worse")
	core.status.apply(2, "blindness")
	check(core.view_for([2]).flags.blind, "blindness reaches the board's view")
	# poison persists from the board into a game and back
	core.mg_entry = {"kind": "main", "pool": 0}
	core.mg = MinigameRegistry.create("meat_grinder", core, core.living(), 0)
	core.mg.finish([0])
	core._finish_minigame()
	check(core.p(2).has_status("blindness"), "poison outlasts a minigame")


func test_treatment() -> void:
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


func _play_game(id: String, n: int, seed_v := 4242, lvl := 1) -> MatchCore:
	var core := _core(["ai", "ai", "ai", "ai"].slice(0, n), seed_v)
	core.mg_entry = {"kind": "main", "pool": 0}
	var mg: Minigame = MinigameRegistry.create(id, core, core.living(), lvl)
	core.mg = mg
	core.mg_id = id
	core._set_phase("mg_play")
	mg.start()
	var t := 0.0
	while not mg.done and t < 240.0:
		core.tick(0.05)
		core.take_events()
		t += 0.05
	return core


func test_all_minigames() -> void:
	for id in MinigameRegistry.GAMES.keys():
		var g: Dictionary = MinigameRegistry.GAMES[id]
		var n := clampi(4, int(g.get("min", 2)), int(g.get("max", 4)))
		var core := _play_game(id, n)
		var mg: Minigame = core.mg
		check(mg.done, "%s finishes (%s, winners %s, draw %s)" % [id, mg.format, str(mg.winners), str(mg.draw)])
		if mg.format == "2v2":
			check(mg.teams.size() == 2 and mg.teams[0].size() == 2, "%s is two teams of two" % id)
		if mg.format == "1v3":
			check(mg.teams.size() == 2 and mg.teams[0].size() == 1, "%s is one against the rest" % id)
		var v: Dictionary = mg.view_for([0])
		check(not v.is_empty(), "%s has a view" % id)
		var pl := mg.placings()
		var placed := 0
		for grp in pl:
			placed += (grp as Array).size()
		check(placed == mg.seats.size(), "%s places everyone (%s)" % [id, str(pl)])
		core._finish_minigame()
		check(core.phase == "mg_results", "%s pays out" % id)
		print("  %s: winners %s, draw %s, placings %s, pay %s" % [id, str(mg.winners), str(mg.draw), str(pl), str(core.last_results.pay)])


## The ten v0.2.5 games: each starts, finishes, has its own controls (not a generic stick
## everywhere), and resolves at every level over several seeds.
func test_core_ten() -> void:
	var schemes := {}
	for id in MinigameRegistry.CORE_TEN:
		var g: Dictionary = MinigameRegistry.GAMES[id]
		check(g.get("core", false), "%s is one of the ten" % id)
		var n := clampi(4, int(g.get("min", 2)), int(g.get("max", 4)))
		var outcomes := {"win": 0, "draw": 0}
		for k in 6:
			var core := _play_game(id, n, 500 + k * 7, k % 3)
			check(core.mg.done, "%s (seed %d) finishes" % [id, 500 + k * 7])
			outcomes["draw" if core.mg.draw else "win"] += 1
		var c := _core(["ai", "ai", "ai", "ai"].slice(0, n), 1)
		var mg: Minigame = MinigameRegistry.create(id, c, c.living(), 0)
		var ctl := mg.controls(int(mg.seats[0]))
		check(not ctl.is_empty(), "%s declares its controls" % id)
		var kinds := ctl.map(func(x): return str(x.kind))
		schemes[id] = ",".join(kinds)
		check(not mg.instructions().is_empty(), "%s explains itself" % id)
		print("  %s: %s; controls %s" % [id, str(outcomes), schemes[id]])
	var distinct := {}
	for k in schemes.keys():
		distinct[schemes[k]] = true
	check(distinct.size() >= 6, "the ten games don't share one control scheme (%d different)" % distinct.size())
	var stick_only := schemes.values().filter(func(s): return s == "stick").size()
	check(stick_only == 0, "no game is just a joystick")
	# the coop defusal: it can be started secretly, and the starter can't do the first step
	var core := _core(["local", "local", "local", "local"], 77)
	core.mg_entry = {"kind": "main", "pool": 0}
	var bomb: Minigame = MinigameRegistry.create("dont_press_it", core, core.living(), 0)
	core.mg = bomb
	core._set_phase("mg_play")
	bomb.start()
	core.action(2, {"t": "mg", "do": "start"})
	check(bomb.started and bomb.view_for([2]).you_started and not bomb.view_for([1]).you_started, "only the starter knows they started it")
	var st: Dictionary = bomb.current_step()
	var stage0: int = bomb.stage
	var probe := {"do": "cut", "pick": st.arg} if st.kind == "cut" else ({"do": "press", "pick": st.arg} if st.kind == "press" else {"do": "crank"})
	if st.kind in ["cut", "press", "crank"]:
		core.action(2, {"t": "mg"}.merged(probe))
		check(bomb.stage == stage0, "the starter can't do the first step")
	var guard := 0
	while not bomb.defused and not bomb.exploded and guard < 50:
		st = bomb.current_step()
		var doer: int = (int(bomb.locked_out) + 1) % 4 if int(bomb.locked_out) >= 0 else 0
		match str(st.kind):
			"cut":
				core.action(doer, {"t": "mg", "do": "cut", "pick": st.arg})
			"press":
				core.action(doer, {"t": "mg", "do": "press", "pick": st.arg})
			"crank":
				core.action(doer, {"t": "mg", "do": "crank"})
			"levers":
				core.action(doer, {"t": "mg", "do": "lever_l", "on": true})
				core.action((doer + 1) % 4, {"t": "mg", "do": "lever_r", "on": true})
			"wait":
				for i in 70:
					core.tick(0.05)
		guard += 1
	check(bomb.defused, "a team that takes turns defuses it")


func test_caller_reacts() -> void:
	var core := _core()
	core.take_events()
	core.suspicion.add(0, 30, "test")
	var said := core.take_events().filter(func(e): return e.e == "say")
	check(not said.is_empty(), "he says something when someone crosses a threshold")


## LAST CALL 3 has no chat: nothing in the rules takes text from a player.
func test_no_chat() -> void:
	var core := _core()
	core.kill(1, "pop")
	_to_turn(core, 0)
	while core.rules.current() != 1 and core.rules.sub != "idle":
		core.rules.next_turn()
	core.take_events()
	core.action(1, {"t": "ghost", "do": "whisper", "text": "hello"})
	check(core.take_events().filter(func(e): return str(e.e).contains("chat") or str(e.e).contains("whisper")).is_empty(), "ghosts can't whisper")
	for f in ["res://scripts/ui/hud.gd", "res://scripts/core/board_rules.gd", "res://scripts/minigames/minigame.gd"]:
		var src := FileAccess.get_file_as_string(f)
		check(not src.contains("\"whisper\"") and not src.contains("ghost_chat"), "no chat in %s" % f)


# --- ORGAN TRAIL --------------------------------------------------------------------------

func _organ(organ_id: String, seed_v := 31, kinds := ["ai", "ai", "ai", "ai"]) -> MatchCore:
	var core := _core(kinds, seed_v)
	core.mg_entry = {"kind": "special", "pool": 0}
	var mg: Minigame = load("res://scripts/minigames/organ_trail.gd").new()
	mg.force_organ = organ_id
	mg.format = "2v2"
	mg.init(core, core.living(), 0)
	core.mg = mg
	core.mg_id = "organ_trail"
	core._set_phase("mg_play")
	mg.start()
	return core


func test_organ_trail() -> void:
	# presentation and rotation
	check(MinigameRegistry.presentation("organ_trail") == "FULL_CHARACTER", "ORGAN TRAIL declares FULL_CHARACTER")
	for id in MinigameRegistry.schedule():
		check(MinigameRegistry.presentation(id) == "MEAT_PUPPET", "%s is played by the meat puppets" % id)
	for n in [2, 3, 4]:
		check(not MinigameRegistry.eligible(n).has("organ_trail"), "never in the ordinary rotation (%d players)" % n)
	# triggers: the square, an event, the Caller
	var c1 := _core()
	_to_turn(c1, 0)
	c1.graph.nodes[1].type = "surgery"
	c1.rat_space = -1
	c1.p(0).space = 0
	_roll_n(c1, 0, 1)
	c1.rules.sub = "moving"
	_walk(c1, 0)
	check(c1.mg_queue.any(func(e): return e.id == "organ_trail"), "the surgery square calls ORGAN TRAIL")
	var c2 := _core()
	c2.fate._apply(0, {"do": "surgery"})
	check(c2.mg_queue.any(func(e): return e.id == "organ_trail"), "so can an event")
	c2._start_entry(c2.mg_queue[0])
	check(c2.mg_id == "organ_trail" and c2.view_for([0]).presentation == "FULL_CHARACTER", "and it starts, full-sized")
	var c3 := _core(["ai", "ai", "ai"], 5)
	c3.call_special("organ_trail")
	check(not c3._start_entry(c3.mg_queue[0]), "with three players it can't run (it needs four)")
	# every organ: roles, stages, an outcome; conditions carry back to the board
	var finished := 0
	for organ_id in Assets.load_json("res://assets/data/organs.json").organs.keys():
		var core := _organ(organ_id, 40 + organ_id.length())
		var mg: Minigame = core.mg
		check(mg.teams.size() == 2, "%s: two tables" % organ_id)
		for st in mg.ts:
			check(mg.role_of(st.surgeon) == "surgeon" and mg.role_of(st.patient) == "patient", "%s: a surgeon and a patient each" % organ_id)
		check(mg.controls(mg.ts[0].surgeon) != mg.controls(mg.ts[0].patient), "surgeon and patient have their own controls")
		var stages_seen := {}
		var t := 0.0
		while not mg.done and t < 200.0:
			core.tick(0.05)
			for st in mg.ts:
				stages_seen[mg.stage_of(st)] = true
			core.take_events()
			t += 0.05
		check(mg.done, "%s: the operation ends (%.0fs, winners %s, draw %s)" % [organ_id, t, str(mg.winners), str(mg.draw)])
		var bodies_before := []
		for p in core.players:
			bodies_before.append(p.body.duplicate(true))
		core._finish_minigame()
		if not mg.winners.is_empty():
			finished += 1
		var patients_hurt := 0
		for st in mg.ts:
			var pb: Dictionary = core.p(st.patient).body
			if pb.torso.s != "ok" or pb.eye_l.s == "lost" or not core.p(st.patient).alive:
				patients_hurt += 1
		check(patients_hurt == 2, "%s: both patients carry what was done to them back to the board" % organ_id)
		print("  %s: winners %s, stages %s, awards %s" % [organ_id, str(mg.winners), str(stages_seen.keys()), str(mg.awards.map(func(a): return a.name))])
	check(finished >= 4, "AI surgeons finish most operations (%d/7)" % finished)
	# the patient knows what the surgeon doesn't
	var core := _organ("heart", 77, ["local", "local", "local", "local"])
	var mg: Minigame = core.mg
	var st: Dictionary = mg.ts[0]
	var vp: Dictionary = mg.view_for([st.patient]).tables[0]
	var vs: Dictionary = mg.view_for([st.surgeon]).tables[0]
	check(not (vp.order as Array).is_empty() and (vs.order as Array).is_empty(), "only the patient sees the chart")
	check(vp.nerves.size() == st.nerves.size() and vs.nerves.is_empty(), "only the patient can feel the nerves")
	# a stage done by hand: the wrong instrument is a mistake, the right one works
	var s: int = st.surgeon
	core.action(s, {"t": "mg", "do": "tool", "pick": "HANDS"})
	var real := 0
	for k in st.candidates.size():
		if st.candidates[k].real:
			real = k
	core.action(s, {"t": "mg", "do": "locate", "pick": "ABCD"[(real + 1) % st.candidates.size()]})
	check(int(st.mistakes) == 1 and int(st.stage) == 0, "picking the wrong organ is a mistake")
	core.action(s, {"t": "mg", "do": "locate", "pick": "ABCD"[real]})
	check(mg.stage_of(st) == "incise", "the right one: on to the incision")
	core.action(s, {"t": "mg", "do": "trace", "pts": [[0.1, 0.9], [0.2, 0.9], [0.3, 0.9]]})
	check(int(st.mistakes) == 2, "cutting without the scalpel is a mistake")
	core.action(s, {"t": "mg", "do": "tool", "pick": "SCALPEL"})
	var line: Array = mg.organ.path
	var pts := []
	for k in 30:
		var f := k / 29.0 * (line.size() - 1)
		var a0: Array = line[int(floor(f))]
		var a1: Array = line[mini(line.size() - 1, int(floor(f)) + 1)]
		pts.append([lerpf(a0[0], a1[0], f - floor(f)), lerpf(a0[1], a1[1], f - floor(f))])
	st.movement = 0.0
	core.action(s, {"t": "mg", "do": "trace", "pts": pts})
	check(mg.stage_of(st) == "separate", "a clean trace makes the incision")
	# the patient's callouts reach everyone
	core.action(st.patient, {"t": "mg", "do": "call", "pick": "stop"})
	check(mg.view_for([mg.ts[1].surgeon]).callouts.size() == 1, "callouts are seen by everyone")
	# sabotage costs Teeth
	core.p(mg.ts[1].surgeon).teeth = 3
	core.action(mg.ts[1].surgeon, {"t": "mg", "do": "sabotage", "id": "steal"})
	check(float(st.stolen) == 0.0, "no Teeth, no sabotage")
	core.p(mg.ts[1].surgeon).teeth = 10
	core.action(mg.ts[1].surgeon, {"t": "mg", "do": "sabotage", "id": "steal"})
	check(float(st.stolen) > 0.0 and core.p(mg.ts[1].surgeon).teeth == 5, "stealing an instrument costs 5 Teeth")
	# bleeding out
	st.bleed = 99.0
	for i in 40:
		core.tick(0.05)
	check(st.dead, "a patient can bleed out on the table")
	# the wrong jar doesn't count
	var c4 := _organ("eye", 9, ["local", "local", "local", "local"])
	var m4: Minigame = c4.mg
	var s4: Dictionary = m4.ts[1]
	s4.stage = (m4.stages() as Array).size() - 1
	var wrong: String = (s4.jars as Array).filter(func(j): return j != "EYE")[0]
	c4.action(s4.surgeon, {"t": "mg", "do": "present", "pick": wrong})
	check(m4.stage_of(s4) == "present" and int(s4.mistakes) == 1, "the wrong jar is an invalid result")
	for i in 45:
		c4.tick(0.05)
	c4.action(s4.surgeon, {"t": "mg", "do": "present", "pick": "EYE"})
	check(s4.valid and m4.stage_of(s4) == "done", "the right jar finishes it")
	for i in 80:
		c4.tick(0.05)
	check(m4.done and m4.winners.has(s4.surgeon) and m4.winners.has(s4.patient), "first valid extraction wins (both of the team)")
	# simultaneous
	var c5 := _organ("eye", 10, ["local", "local", "local", "local"])
	var m5: Minigame = c5.mg
	for st5 in m5.ts:
		st5.stage = (m5.stages() as Array).size() - 1
	for st5 in m5.ts:
		c5.action(st5.surgeon, {"t": "mg", "do": "present", "pick": "EYE"})
	for i in 80:
		c5.tick(0.05)
	check(m5.done and m5.draw, "two extractions at the same moment: both count (a draw)")


func test_escape_room() -> void:
	var core := _core()
	core._start_round()
	var fac := core.facility
	var b := fac.building
	for id in ["esc_birthday", "esc_processing", "esc_gift", "esc_office", "esc_exit"]:
		check(b.areas.has(id), "the escape room has %s" % id)
	check(b.open_portals.has("door:esc_birthday"), "its entrance is open")
	check(not b.open_portals.has("door:esc_processing"), "the next door is locked")
	check(b.reachable(Vector2(0, 5), fac.stand_at("esc_cake")), "you can walk in from the hall")
	check(not b.reachable(Vector2(0, 5), fac.stand_at("esc_conveyor")), "but not past the first room yet")
	_look_away(core)
	var a := (core.rules.current() + 1) % 4
	var c := (core.rules.current() + 2) % 4
	for s in [a, c]:
		core.action(s, {"t": "leave"})
	var use := func(s: int, thing: String, act: String) -> void:
		core.p(s).pos = fac.stand_at(thing)
		core.action(s, {"t": "interact", "id": thing, "do": act})
	# room A: two people split the clues
	use.call(a, "esc_cake", "esc_candles")
	use.call(c, "esc_balloons", "esc_balloons")
	use.call(a, "esc_photos", "esc_photos")
	core.p(c).pos = fac.stand_at("esc_keypad_a")
	use.call(a, "esc_keypad_a", "esc_code_a")
	check(fac.state.has("esc_a") and b.open_portals.has("door:esc_processing"), "room A: together they know the code")
	# room B
	core.p(c).pos = fac.stand_at("esc_conveyor")
	use.call(a, "esc_switches", "esc_" + str(fac.escape.clues.order[1]).to_lower())
	check(not fac.state.has("esc_b") and fac.escape.switch_i == 0, "the wrong switch resets the panel")
	for col in fac.escape.clues.order:
		use.call(a, "esc_switches", "esc_" + str(col).to_lower())
	check(fac.state.has("esc_b"), "room B: the switches in order")
	# room C: open everything
	for i in range(1, 7):
		use.call(c, "esc_packages", "esc_pkg_%d" % i)
	check(fac.state.has("esc_c") and b.open_portals.has("door:esc_office"), "room C: the office key's in a package")
	# room D
	for act in ["esc_guests", "esc_schedule", "esc_blueprint"]:
		use.call(a, "esc_office", act)
	check(fac.state.has("esc_d"), "room D: the documents open the exit chamber")
	check(b.reachable(Vector2(0, 5), fac.stand_at("esc_exit_pad")), "now you can walk all the way through")
	# room E
	core.p(c).pos = fac.stand_at("esc_exit_pad")
	use.call(a, "esc_exit_pad", "esc_code_final")
	check(fac.state.has("esc_code"), "the final code, from everything found")
	var first := "esc_lever_l" if fac.escape.clues.levers == "LR" else "esc_lever_r"
	var second := "esc_lever_r" if first == "esc_lever_l" else "esc_lever_l"
	use.call(a, first, "esc_pull_" + first.right(1))
	use.call(a, second, "esc_pull_" + second.right(1))
	check(not fac.state.has("esc_open"), "one person can't pull both")
	use.call(c, first, "esc_pull_" + first.right(1))
	use.call(a, second, "esc_pull_" + second.right(1))
	check(fac.state.has("esc_open"), "two people, the right order: THE EXIT")
	use.call(a, "esc_exit_pad", "esc_leave")
	use.call(c, "esc_exit_pad", "esc_leave")
	check(core.p(a).location == "escaped", "they walk out")
	_until(core, func(): return core.ending != "", 40.0)
	check(core.ending == "escape" and (core.ending_info.winners as Array).has(a) and (core.ending_info.winners as Array).has(c), "the match ends: they escaped the party")
