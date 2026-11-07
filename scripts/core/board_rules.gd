class_name BoardRules
extends RefCounted
## The board half of a round. Everyone alive takes a turn (use items, give, share, cheat,
## roll), walks the board graph (BoardGraph: at a junction you choose the way, a toll gate
## wants Teeth or a Shortcut Key, the Dead Rat can be bought as you pass it), and lands;
## then the ghosts take theirs. What each square type does is _land(). Anyone who's away
## from the table when their turn comes misses it: the board doesn't wait.

const STEP_TIME := 0.42
const AFTER_TIME := 1.8
const PROMPT_LIMIT := 20.0
const MISSED_TIME := 1.6
const LIMBS := ["hand_l", "hand_r", "arm_l", "arm_r", "leg_l", "leg_r"]
const NORMAL_PAY := 3
const BAD_TAKE := 3

var core: MatchCore
var order: Array[int] = []
var idx := 0
var sub := "idle"      # pre | moving | prompt | after | ghost | missed | idle
var sub_t := 0.0
var roll := 0
var dice: Array = []    # what the dice showed (for the view)
var steps := 0
var dir := 1
var prompt := {}
var walked := []        # this turn's path (for the view)


func _init(c: MatchCore) -> void:
	core = c


func begin_round() -> void:
	order = core.living()
	if order.is_empty():
		return
	var shift := (core.round_n - 1) % order.size()
	order = order.slice(shift) + order.slice(0, shift)
	order.append_array(core.ghosts())
	idx = 0
	_start_turn()


func current() -> int:
	return order[idx] if sub != "idle" and idx < order.size() else -1


func _start_turn() -> void:
	while idx < order.size() and not (core.p(order[idx]).alive or core.p(order[idx]).ghost):
		idx += 1
	if idx >= order.size():
		sub = "idle"
		core.board_round_done()
		return
	sub_t = 0.0
	roll = 0
	dice = []
	steps = 0
	dir = 1
	prompt = {}
	walked = []
	var s := order[idx]
	var pl := core.p(s)
	if pl.ghost:
		sub = "ghost"
		core.emit({"e": "turn", "seat": s, "ghost": true})
		core.say("ghost_turn", {"name": pl.name})
		return
	if pl.away():
		_missed(s)
		return
	sub = "pre"
	core.emit({"e": "turn", "seat": s})
	core.say("turn", {"name": pl.name})
	core.status.tick_turn(s)
	if pl.loophole > 0:
		pl.loophole -= 1


## They're not at the table. The board goes on without them.
func _missed(s: int) -> void:
	var pl := core.p(s)
	sub = "missed"
	sub_t = 0.0
	pl.stat("missed_turns")
	core.emit({"e": "missed_turn", "seat": s})
	core.say("missed_turn", {"name": pl.name})
	core.toast("%s's turn. %s isn't in their chair. Skipped." % [pl.name, pl.name])


func next_turn() -> void:
	idx += 1
	_start_turn()


func tick(dt: float) -> void:
	sub_t += dt
	var s := current()
	match sub:
		"pre":
			if core.p(s).away():
				_missed(s)
			elif not core.is_ai(s) and sub_t > core._wait(MatchCore.HUMAN_TURN_LIMIT):
				core.toast("%s took too long. The Caller rolls for them." % core.p(s).name)
				action(s, {"t": "roll"})
		"ghost":
			if not core.is_ai(s) and sub_t > core._wait(MatchCore.HUMAN_TURN_LIMIT):
				action(s, {"t": "ghost", "do": "scavenge"})
		"moving":
			if sub_t >= core._wait(STEP_TIME):
				sub_t = 0.0
				_step()
		"prompt":
			if prompt.is_empty():
				push_warning("empty prompt: " + str(walked) + " " + str(core.log_lines.slice(-4)))
				_after()
				return
			if not core.is_ai(s) and sub_t > core._wait(PROMPT_LIMIT):
				action(s, default_answer())
		"missed":
			if sub_t >= core._wait(MISSED_TIME):
				next_turn()
		"after":
			if sub_t >= core._wait(AFTER_TIME):
				next_turn()


## What a prompt does if nobody answers it.
func default_answer() -> Dictionary:
	match str(prompt.get("kind", "")):
		"door_stop", "rat", "hidden", "poison":
			return {"t": "answer", "yes": false}
		"path":
			return {"t": "answer", "to": int(prompt.options[0].to)}
		"shop", "gamble", "gavel", "veto", "lever":
			return {"t": "answer", "done": true}
		"duel":
			return {"t": "answer", "target": prompt.options[0], "wager": 0}
	return {"t": "answer", "target": prompt.get("options", [-1])[0]}


func action(seat: int, a: Dictionary) -> void:
	if seat != current():
		return
	var pl := core.p(seat)
	var t := str(a.get("t", ""))
	match sub:
		"ghost":
			_ghost_action(seat, a)
		"pre":
			match t:
				"roll":
					_roll(seat)
				"cheat":
					_board_cheat(seat, str(a.get("id", "")), int(a.get("target", -1)))
				"item":
					core.items.use(seat, str(a.get("id", "")), int(a.get("target", -1)), str(a.get("choice", "")))
				"give":
					_give(seat, str(a.get("id", "")), int(a.get("target", -1)))
				"share":
					_share(seat)
				"stay":
					if pl.at_door:
						core.toast("%s waits by the door." % pl.name)
						core.emit({"e": "stay", "seat": seat})
						_after()
				"try_door":
					if pl.at_door:
						core.try_door(seat)
						if core.phase == "door":
							sub = "idle"
		"prompt":
			if t == "answer":
				_answer(seat, a)


# --- dice -------------------------------------------------------------------------------

func _roll(seat: int) -> void:
	var pl := core.p(seat)
	var dmax := Body.dice_max(pl.body, pl.pk())
	var mod := core.status.dice_mod(seat)
	dmax = clampi(dmax + int(mod[0]), 1, 12)
	dice = []
	match pl.next_roll:
		"low":
			dice = [core.rng.randi_range(1, 4)]
		"high":
			dice = [core.rng.randi_range(6, 9)]
		"d10":
			dice = [core.cage.roll(seat, 10)]
		"double":
			var a := core.cage.roll(seat, dmax)
			var b := core.cage.roll(seat, dmax)
			dice = [a, b]
			roll = maxi(a, b)
		"loaded_double":
			dice = [core.rng.randi_range(5, 9), core.rng.randi_range(5, 9)]
		"six":
			dice = [dmax]
		_:
			dice = [core.cage.roll(seat, dmax)]
	if pl.next_roll == "double":
		roll = maxi(int(dice[0]), int(dice[1]))
	else:
		roll = 0
		for d in dice:
			roll += int(d)
	pl.next_roll = ""
	roll = maxi(0, roll + pl.roll_bonus + int(core.rulebook.value("dice_bonus", 0, seat)))
	var cap = core.rulebook.value("dice_cap", null, seat)
	if cap != null:
		roll = mini(roll, int(cap))
	pl.roll_bonus = 0
	if mod[1]:
		roll = 0
		core.toast("%s can't make their legs move (paralytic)." % pl.name)
	steps = roll + (pl.move_bonus if roll > 0 else 0)
	pl.move_bonus = 0
	dir = -1 if (pl.reverse or core.rulebook.value("reverse", false, seat)) else 1
	pl.reverse = false
	pl.at_door = false
	core.emit({"e": "roll", "seat": seat, "n": roll, "max": dmax, "dice": dice.duplicate(), "steps": steps, "dir": dir})
	core.say("roll", {"n": roll})
	if steps <= 0:
		_after()
		return
	sub = "moving"
	sub_t = -1.0   # let the block land and the number sink in


func _after() -> void:
	sub = "after"
	sub_t = 0.0
	prompt = {}


func _ask(kind: String, options: Array, extra := {}, resume := "after") -> void:
	var s := current()
	sub = "prompt"
	sub_t = 0.0
	prompt = {"kind": kind, "seat": s, "options": options, "resume": resume}
	prompt.merge(extra, true)
	core.emit({"e": "prompt", "seat": s, "kind": kind})


## A prompt is answered: carry on with whatever was happening.
func _resume() -> void:
	var r := str(prompt.get("resume", "after"))
	prompt = {}
	sub = "resolving"
	match r:
		"move":
			if steps > 0:
				sub = "moving"
				sub_t = 0.0
			else:
				_land()
		"land":
			_land()
		"pre":
			sub = "pre"
			sub_t = 0.0
		_:
			_after()


# --- walking ----------------------------------------------------------------------------

func _step() -> void:
	var s := current()
	var pl := core.p(s)
	var outs: Array = core.graph.next_of(pl.space) if dir > 0 else core.graph.prev_of(pl.space)
	if outs.size() > 1 and dir > 0:
		var opts := []
		for to in outs:
			var toll := int(core.graph.node(to).toll)
			opts.append({"to": int(to), "name": core.graph.route_name(int(to)), "toll": toll,
				"can": toll <= 0 or pl.teeth >= toll or pl.items.has("shortcut_key"), "desc": core.graph.route_desc(int(to))})
		_ask("path", opts, {}, "move")
		return
	_arrive(int(outs[0]))


func _arrive(to: int) -> void:
	var s := current()
	var pl := core.p(s)
	pl.space = to
	steps -= 1
	walked.append(to)
	pl.stat("spaces_moved")
	core.emit({"e": "move", "seat": s, "space": pl.space, "left": steps})
	var sp: Dictionary = core.graph.node(pl.space)
	if core.key_space == pl.space:
		core.key_space = -1
		pl.has_key = true
		core.emit({"e": "key", "seat": s})
		core.toast("%s picks up a small brass winding key." % pl.name)
	# walking past the wallpaper, a sharp eye catches what's under it
	if sp.type == "clue" and steps > 0 and not pl.clues.has(int(sp.get("clue", 0))):
		if core.rng.randf() < 0.5 * Body.sight(pl.body):
			var ci := int(sp.get("clue", 0))
			pl.clues[ci] = core.code[ci]
			core.toast("Walking past, you notice: %s The number is %d." % [str(sp.get("text", "")), core.code[ci]], s)
			core.emit({"e": "clue", "seat": s, "index": ci})
	if sp.type == "start" and steps > 0:
		_pass_start(s)
	# the Dead Rat: passing or landing, you can buy it
	if pl.space == core.rat_space:
		var price := core.economy.rat_price()
		if pl.teeth >= price:
			_ask("rat", [true, false], {"price": price}, "move")
			return
		core.toast("The Dead Rat. %d Teeth. %s has %d." % [price, pl.name, pl.teeth], s)
	if steps <= 0:
		_land()
	elif sp.type == "door":
		_ask("door_stop", [true, false], {}, "move")


func _pass_start(s: int) -> void:
	var pl := core.p(s)
	var pay := int(core.rulebook.value("start_pay", 3, s))
	if pay >= 0:
		core.economy.award(s, pay, "payday")
	else:
		if not core.items.consume_passive(s, "lucky_tooth", "the tax"):
			core.economy.take(s, -pay, "tax day")
	core.say("pass_start", {"name": pl.name})
	# debts come due
	if not pl.debts.is_empty():
		var k := core.economy.settle(s)
		if k > 0:
			core.toast("%s pays %d Teeth of what they owe." % [pl.name, k])


## Moved by something (an event, a cheat): no squares on the way count.
func slide(seat: int, n: int) -> void:
	var pl := core.p(seat)
	for i in absi(n):
		var outs: Array = core.graph.next_of(pl.space) if n > 0 else core.graph.prev_of(pl.space)
		pl.space = int(outs[0])
	pl.at_door = false
	core.emit({"e": "move", "seat": seat, "space": pl.space, "slide": true})


func swap_places(a: int, b: int) -> void:
	var pa := core.p(a)
	var pb := core.p(b)
	var x := pa.space
	pa.space = pb.space
	pb.space = x
	var d := pa.at_door
	pa.at_door = pb.at_door
	pb.at_door = d
	core.emit({"e": "swap", "a": a, "b": b})
	core.say("caller_swap", {"name": pa.name, "target": pb.name})


# --- landing ----------------------------------------------------------------------------

func _land() -> void:
	var s := current()
	var pl := core.p(s)
	var sp: Dictionary = core.graph.node(pl.space)
	var name := pl.name
	var kind := str(sp.type)
	core.emit({"e": "land", "seat": s, "space": pl.space, "type": kind})
	# somebody's rat trap
	if core.traps.has(pl.space) and int(core.traps[pl.space]) != s:
		var by := int(core.traps[pl.space])
		core.traps.erase(pl.space)
		core.emit({"e": "trap_sprung", "seat": s, "space": pl.space, "by": by})
		core.toast("SNAP. %s steps in %s's rat trap." % [name, core.p(by).name])
		var k := core.economy.take(s, 8, "rat trap")
		core.p(by).teeth += k / 2
		core.injure(s, ["hand_l", "hand_r"][core.rng.randi_range(0, 1)], "bruised", "trap")
		pl.stat("traps_hit")
		pl.stat("victimised")
	if pl.cold_hand:
		pl.cold_hand = false
		core.toast("A cold hand holds %s back. The square does nothing." % name)
		_after()
		return
	# his thumb on the board: a good square goes bad
	if kind in ["normal", "item", "medical", "gamble", "hidden", "event"] and core.cage.tip(s, "board_event"):
		core.say("cage_board", {"name": name})
		kind = "punish"
	var mult := 3 if core.final_round() else 1
	if kind in ["signpost", "floodgate", "switch", "rotator", "control", "conveyor", "wheel", "death", "bonus"]:
		core.say("space_" + kind, {"name": name})
		core.machines.land(s, kind)
		if sub != "prompt":
			_after()
		return
	match kind:
		"search":
			sub = "search"
			core.search.start(s)
			return
		"start":
			core.economy.award(s, 3 * mult, "start")
			core.say("pass_start", {"name": name})
		"normal":
			var n := int(core.rulebook.value("normal_set", NORMAL_PAY * int(core.rulebook.value("normal_mult", 1, s)), s)) * mult
			n = core.economy.award(s, n, "square")
			core.say("space_normal", {"name": name, "n": n})
		"bad":
			pl.stat("bad_spaces")
			if core.items.consume_passive(s, "lucky_tooth", "a bad square"):
				pass
			elif core.rng.randf() < 0.75:
				var n := core.economy.take(s, BAD_TAKE * int(core.rulebook.value("bad_mult", 1, s)) * mult + core.round_n / 5, "bad square")
				core.say("space_bad", {"name": name, "n": n})
			else:
				var part: String = LIMBS[core.rng.randi_range(0, LIMBS.size() - 1)]
				core.injure(s, part, "bruised", "bad square")
				core.say("space_bad_hurt", {"name": name})
		"event":
			core.say("space_event", {"name": name})
			core.fate.trigger(s)
		"item":
			var id := Items.roll(core.rng, "any", core.cage.tip(s, "items"))
			if core.give_item(s, id, "square"):
				core.say("space_item", {"name": name, "item": Items.name_of(id)})
		"shop":
			core.say("space_shop", {"name": name})
			open_shop(s, "general")
		"black_market":
			core.say("space_black_market", {"name": name})
			open_shop(s, "black_market")
		"medical":
			Body.heal_temporary(pl.body)
			core.emit({"e": "heal", "seat": s})
			core.say("space_medic", {"name": name})
			open_shop(s, "medical")
		"minigame":
			core.say("space_minigame", {"name": name})
			core.queue_minigame("bonus", core.living(), "", 0, s)
			core.toast("BONUS GAME after the turns: pays double.")
		"duel":
			var opps := core.living().filter(func(o): return o != s)
			if not opps.is_empty():
				core.say("space_duel", {"name": name})
				_ask("duel", opps, {"wagers": _duel_wagers(s)})
				return
		"battle":
			if core.pending_encounter == "":
				core.pending_encounter = "battle"
				core.say("space_battle", {"name": name})
				core.toast("BATTLE! This round's game is for a pot: everyone pays in, the winner takes it all.")
				core.emit({"e": "encounter", "id": "battle"})
		"roulette":
			core.pending_encounter = "roulette"
			core.say("space_roulette", {"name": name})
			core.emit({"e": "encounter", "id": "roulette"})
		"resurrect":
			core.say("space_resurrect", {"name": name})
			core.resurrection.square(s)
		"poison":
			core.say("space_poison", {"name": name})
			_ask("poison", [true, false], {"pay": 6})
			return
		"gamble":
			if pl.teeth > 0:
				core.say("space_gamble", {"name": name})
				offer_gamble(s)
				return
		"caller":
			caller_choice(s)
		"trap":
			core.say("space_trap", {"name": name})
			if core.rng.randf() < 0.6:
				var part: String = LIMBS[core.rng.randi_range(0, LIMBS.size() - 1)]
				var st := "bruised" if core.round_n < 4 else ("burned" if core.round_n < 8 else "broken")
				core.injure(s, part, st, "trap")
			else:
				core.economy.take(s, 5, "trap")
		"punish":
			punish(s)
		"hidden":
			_ask("hidden", [true, false])
			return
		"surgery":
			core.say("space_surgery", {"name": name})
			core.call_special("organ_trail", s)
		"rulebook":
			core.say("space_rulebook", {"name": name})
			core.rulebook.add_random(s)
		"veto":
			if core.rulebook.active.is_empty():
				core.toast("THE VETO. Nothing in the rulebook to strike; %s gets 4 Teeth for civic duty." % name)
				core.economy.award(s, 4, "veto")
			else:
				core.say("space_veto", {"name": name})
				open_rule_prompt(s, "veto", "after")
				return
		"hazard":
			var part: String = LIMBS[core.rng.randi_range(0, LIMBS.size() - 1)]
			core.injure(s, part, "bruised", "party favour")
		"note":
			core.toast(str(sp.get("text", "")))
			core.say("space_note", {"name": name})
		"clue":
			var i := int(sp.get("clue", 0))
			pl.clues[i] = core.code[i]
			core.toast("%s The number is %d." % [str(sp.get("text", "")), core.code[i]], s)
			core.toast("%s is picking at the wallpaper." % name)
			core.emit({"e": "clue", "seat": s, "index": i})
			core.say("space_clue", {"name": name})
		"steal":
			var opts := core.living().filter(func(o): return o != s and (not core.p(o).items.is_empty() or core.p(o).teeth > 0))
			if not opts.is_empty():
				core.say("space_steal", {"name": name})
				_ask("steal", opts)
				return
		"door":
			pl.at_door = true
			core.emit({"e": "door_stop", "seat": s})
			core.say("door_stop", {"name": name})
			_check_gather()
	if sub != "prompt":
		_after()


func _duel_wagers(s: int) -> Array:
	var out := [0]
	for w in [5, 10, 20]:
		if core.p(s).teeth >= w:
			out.append(w)
	return out


func open_shop(s: int, which: String, coupon := false) -> void:
	var resume := "pre" if sub == "pre" else "after"
	_ask("shop", [], {"shop": which, "coupon": coupon, "name": core.shops.name_of(which)}, resume)


func open_rule_prompt(s: int, kind: String, resume := "") -> void:
	if resume == "":
		resume = "pre" if sub == "pre" else "after"
	var opts := core.rulebook.offer(3) if kind == "gavel" else core.rulebook.active.map(func(r): return str(r.id))
	var named := []
	for id in opts:
		named.append({"id": id, "name": core.rulebook.catalogue[id].name, "desc": core.rulebook.catalogue[id].desc})
	_ask(kind, opts, {"rules": named}, resume)


## Pull a lever on the Control System (or a signpost, a floodgate): which way.
func ask_lever(s: int, gate: String) -> void:
	var gs: Array = [gate] if gate != "" else core.graph.gates.keys().filter(func(x): return x != "rotator")
	var opts := []
	for gname in gs:
		if not core.graph.gates.has(gname):
			continue
		for v in core.graph.gate_values(gname):
			opts.append({"gate": gname, "value": str(v), "name": str(core.graph.gate_defs[gname].get("name", gname)), "now": str(core.graph.gates[gname]) == str(v),
				"desc": core.machines._describe(gname, str(v))})
	if opts.is_empty():
		return
	_ask("lever", opts)


func offer_gamble(s: int) -> void:
	var opts := [1, 3, 5, 10].filter(func(w): return w <= core.p(s).teeth)
	if opts.is_empty():
		return
	_ask("gamble", opts)


# --- answers ----------------------------------------------------------------------------

func _answer(seat: int, a: Dictionary) -> void:
	var pl := core.p(seat)
	match str(prompt.kind):
		"door_stop":
			if a.get("yes", false):
				steps = 0
				pl.at_door = true
				core.emit({"e": "door_stop", "seat": seat})
				core.say("door_stop", {"name": pl.name})
				_check_gather()
				prompt.resume = "after"
			else:
				core.say("door_pass", {"name": pl.name})
			_resume()
		"path":
			var to := int(a.get("to", -1))
			var opt := {}
			for o in prompt.options:
				if int(o.to) == to:
					opt = o
			if opt.is_empty() or not opt.can:
				opt = prompt.options[0]
			var toll := int(opt.toll)
			if toll > 0:
				if core.items.consume_passive(seat, "shortcut_key", "the toll"):
					core.toast("%s turns the Shortcut Key in the gate." % pl.name)
				elif not core.economy.charge(seat, toll, "toll"):
					opt = prompt.options[0]
			core.emit({"e": "path", "seat": seat, "to": int(opt.to), "name": opt.name})
			if str(opt.name) != "THE MAIN ROAD":
				core.say("path_branch", {"name": pl.name, "route": str(opt.name)})
			prompt = {}
			sub = "moving"
			sub_t = 0.0
			_arrive(int(opt.to))
		"rat":
			if a.get("yes", false) and core.economy.charge(seat, int(prompt.price), "the Dead Rat"):
				core.change_rats(seat, 1, "bought")
				pl.stat("rats_bought")
				core.say("rat_bought", {"name": pl.name})
				core.emit({"e": "rat_bought", "seat": seat, "space": core.rat_space})
				core.move_rat(-1)
			if steps <= 0:
				prompt.resume = "land"
			_resume()
		"steal":
			var target := int(a.get("target", -1))
			if not prompt.options.has(target):
				target = prompt.options[0]
			_steal(seat, target)
			_resume()
		"shop":
			if a.has("buy"):
				core.shops.buy(seat, str(prompt.shop), str(a.buy), bool(prompt.get("coupon", false)))
			elif a.has("steal") and str(prompt.shop) == "black_market":
				core.shops.steal(seat, str(prompt.shop), str(a.steal))
			if a.get("done", false) or pl.items.size() >= Items.MAX_HELD:
				_resume()
		"gamble":
			var w := int(a.get("wager", 0))
			if w > 0 and pl.teeth > 0:
				core.economy.gamble(seat, w)
			_resume()
		"hidden":
			if a.get("yes", false):
				_hidden(seat)
			_resume()
		"poison":
			if a.get("yes", false):
				core.status.apply(seat, core.status.random_poison(seat), "the poison square")
				core.economy.award(seat, int(prompt.get("pay", 6)), "drank it")
				pl.stat("poisoned")
			else:
				core.suspicion.add(seat, 4, "refused a drink")
				core.toast("%s refuses the drink. He writes something down." % pl.name)
			_resume()
		"duel":
			var target := int(a.get("target", -1))
			if not prompt.options.has(target):
				target = prompt.options[0]
			var w := int(a.get("wager", 0))
			if not (prompt.wagers as Array).has(w):
				w = 0
			w = mini(w, core.p(target).teeth)
			core.queue_minigame("duel", [seat, target], "", w, seat)
			core.toast("%s challenges %s to a DUEL (%d Teeth each) after the turns." % [pl.name, core.p(target).name, w])
			core.emit({"e": "duel", "seat": seat, "target": target, "wager": w})
			_resume()
		"gavel":
			var id := str(a.get("rule", ""))
			if not (prompt.options as Array).has(id):
				id = str(prompt.options[0]) if not (prompt.options as Array).is_empty() else ""
			if id != "":
				core.rulebook.add(id, seat)
			_resume()
		"veto":
			var id := str(a.get("rule", ""))
			if (prompt.options as Array).has(id):
				core.rulebook.repeal(id, "vetoed by " + pl.name)
			elif not a.get("done", false) and not (prompt.options as Array).is_empty():
				core.rulebook.repeal(str(prompt.options[0]), "vetoed by " + pl.name)
			_resume()
		"lever":
			var gname := str(a.get("gate", ""))
			var v := str(a.get("value", ""))
			var ok := false
			for o in prompt.options:
				if o.gate == gname and o.value == v:
					ok = true
			if ok:
				core.machines.set_gate(gname, v, seat, "a lever")
			_resume()
		"caller":
			_resume()


## A punishment square: the Caller chooses, and the Cage chooses for him.
func punish(s: int) -> void:
	var pl := core.p(s)
	pl.stat("punishments")
	core.say("space_punish", {"name": pl.name})
	if core.items.consume_passive(s, "bribe_token", "the punishment"):
		core.toast("An envelope changes hands. He lets it go.")
		return
	var roll_p := core.rng.randi_range(0, 3)
	if core.cage.tip(s, "encounter"):
		roll_p = 0
	match roll_p:
		0:
			var part := Body.random_severable(pl.body, core.rng)
			if part != "":
				core.injure(s, part, "broken", "punishment")
		1:
			var n := core.economy.take(s, 4 + core.round_n / 3, "punishment")
			core.toast("He takes %d Teeth off %s." % [n, pl.name])
		2:
			core.suspicion.add(s, 8, "punishment")
		3:
			core.status.apply(s, core.status.random_poison(s), "punishment")


func _hidden(s: int) -> void:
	var pl := core.p(s)
	if core.cage.tip(s, "environment"):
		core.injure(s, "hand_r", "bruised", "trap")
		core.toast("A mousetrap under the square. A big one.", s)
		return
	pl.stat("room_found")
	match core.rng.randi_range(0, 3):
		0:
			core.economy.award(s, 6, "hidden")
			core.toast("Under the square: a nest of Teeth.", s)
		1:
			core.give_item(s, ["shortcut_key", "alibi", "lucky_foot", "lazarus_rat", "gavel"][core.rng.randi_range(0, 4)], "hidden")
		2:
			core.suspicion.add(s, -10, "hidden")
			core.toast("Under the square: a page from his file. Yours. You eat it.", s)
		3:
			core.move_rat(core.graph.ahead(pl.space, core.rng.randi_range(2, 5)))
			core.toast("Under the square: a map. The Dead Rat isn't where you thought.", s)


## Cheats at the table (assets/data/cheats.json, context "board").
func _board_cheat(seat: int, id: String, target: int) -> void:
	var pl := core.p(seat)
	if not core.cheats.available(seat, "board").has(id):
		return
	var others := core.living().filter(func(o): return o != seat)
	if core.cheats.catalogue[id].get("target", false) and not others.has(target):
		target = others[core.rng.randi_range(0, others.size() - 1)] if not others.is_empty() else -1
		if target < 0:
			return
	if not core.cheats.attempt(seat, id):
		if id == "palm_rats":
			core.economy.take(seat, 3, "caught palming")
		_after()   # caught: that's your turn
		return
	match id:
		"load_dice":
			pl.next_roll = "six"
		"palm_rats":
			var n := mini(2, core.economy.house_pile)
			core.economy.house_pile -= n
			pl.teeth += n
		"pick_pocket":
			var t := core.p(target)
			if not t.items.is_empty() and pl.items.size() < Items.MAX_HELD:
				var it: String = t.items.pop_at(core.rng.randi_range(0, t.items.size() - 1))
				pl.items.append(it)
				core.items.claim_insurance(target, "pickpocketed")
			else:
				core.economy.transfer(target, seat, 3, "pickpocketed")
			pl.stat("steals")
			t.stat("victimised")
			core.brains[target].wronged_by(seat, 0.05)
		"nudge":
			slide(seat, 1)
		"shove":
			slide(target, -2)
			core.p(target).stat("victimised")
			core.brains[target].wronged_by(seat, 0.05)


## A ghost's turn: one thing, then it's over. Ghosts can't be caged; they're not his any more.
func _ghost_action(seat: int, a: Dictionary) -> void:
	var pl := core.p(seat)
	var t := str(a.get("t", ""))
	if t == "item":
		if core.items.use(seat, str(a.get("id", "")), int(a.get("target", -1)), str(a.get("choice", ""))):
			_after()
		return
	if t == "buy":
		core.shops.buy(seat, "ghost", str(a.get("id", "")))
		return   # shopping isn't your turn
	if t != "ghost":
		return
	var target := int(a.get("target", -1))
	var living := core.living()
	match str(a.get("do", "")):
		"scavenge":
			var n := core.rng.randi_range(1, 3) * int(core.rulebook.value("scavenge_mult", 1))
			core.economy.award(seat, n, "scavenged", false)
			core.toast("%s's ghost finds %d Tooth%s in the walls." % [pl.name, n, "" if n == 1 else "s"])
		"haunt":
			if not living.has(target):
				return
			core.p(target).roll_bonus -= 2
			core.toast("Something cold sits on %s's shoulder." % core.p(target).name)
		"bless":
			if not living.has(target):
				return
			core.p(target).roll_bonus += 2
			core.toast("%s feels a hand on their back, pushing." % core.p(target).name)
		"distract":
			core.suspicion.distract(8.0)
			core.toast("The neon fizzes and dies for a moment. He turns to look.")
		"rise":
			if not core.resurrection.buy(seat):
				return
		_:
			return
	_after()


func _check_gather() -> void:
	var n := 0
	for o in core.living():
		if core.p(o).at_door:
			n += 1
	if n >= 2:
		core.say("door_gather")


## The Caller square: he decides. A bribe token makes him kinder.
func caller_choice(s: int) -> void:
	var pl := core.p(s)
	core.say("space_caller", {"name": pl.name})
	core.emit({"e": "caller_table", "seat": s})
	var r := core.rng.randi_range(0, 4)
	if core.rng.randf() < 0.12 and core.living().size() >= 4:
		r = 5
	if core.items.consume_passive(s, "bribe_token", "his mood"):
		r = [0, 3, 4][core.rng.randi_range(0, 2)]
	match r:
		0:
			var id := Items.roll(core.rng)
			if core.give_item(s, id, "caller"):
				core.say("caller_gift", {"name": pl.name, "item": Items.name_of(id)})
		1:
			var others := core.living().filter(func(o): return o != s)
			if not others.is_empty():
				swap_places(s, others[core.rng.randi_range(0, others.size() - 1)])
		2:
			var n := core.economy.take(s, 5, "the Caller")
			core.say("caller_tax", {"name": pl.name, "n": n})
		3:
			var n := core.economy.award(s, 6, "the Caller")
			core.say("caller_bonus", {"name": pl.name, "n": n})
		4:
			core.toast("He leans over the table and looks at %s for a long time. Then: 'An amendment.'" % pl.name)
			core.rulebook.add_random(-1)
		5:
			core.toast("He looks at %s, and then at the operating theatre." % pl.name)
			core.call_special("organ_trail", -1)


func _steal(s: int, o: int) -> void:
	var a := core.p(s)
	var b := core.p(o)
	if not b.items.is_empty() and a.items.size() < Items.MAX_HELD:
		var id: String = b.items.pop_at(core.rng.randi_range(0, b.items.size() - 1))
		a.items.append(id)
		core.items.claim_insurance(o, "robbed")
		core.emit({"e": "steal", "seat": s, "from": o, "item": id})
	else:
		var n := core.economy.transfer(o, s, 5, "stolen")
		core.emit({"e": "steal", "seat": s, "from": o, "teeth": n})
	a.stat("steals")
	b.stat("victimised")
	core.say("steal", {"name": a.name, "target": b.name})
	core.brains[o].wronged_by(s, 0.15)


func _give(seat: int, id: String, target: int) -> void:
	var pl := core.p(seat)
	if id == "lazarus_rat" and pl.items.has(id) and target >= 0 and target < core.players.size() and core.p(target).ghost:
		pl.items.erase(id)
		pl.stat("revived_others")
		core.say("lazarus", {"name": pl.name, "target": core.p(target).name})
		core.resurrection.revive(target, "lazarus")
		for o in core.living():
			core.brains[o].saw_kindness(seat, 0.3)
		return
	if not pl.items.has(id) or target == seat or target < 0 or target >= core.players.size() or not core.p(target).alive:
		return
	if core.p(target).items.size() >= Items.MAX_HELD:
		core.toast("%s can't carry any more." % core.p(target).name, seat)
		return
	pl.items.erase(id)
	core.p(target).items.append(id)
	pl.stat("gifts_given")
	core.p(target).stat("gifts_received")
	core.emit({"e": "give", "seat": seat, "to": target, "item": id})
	core.say("give", {"name": pl.name, "item": Items.name_of(id), "target": core.p(target).name})
	for o in core.living():
		core.brains[o].saw_kindness(seat, 0.1 if o != target else 0.25)


func _share(seat: int) -> void:
	var pl := core.p(seat)
	if pl.clues.is_empty():
		core.toast("You don't know anything worth telling.", seat)
		return
	var new := false
	for i in pl.clues.keys():
		if not core.shared_code.has(i):
			core.shared_code[i] = pl.clues[i]
			new = true
	if not new:
		core.toast("They already know.", seat)
		return
	var parts := []
	for i in 3:
		parts.append(str(core.shared_code[i]) if core.shared_code.has(i) else "_")
	core.toast("%s tells everyone what they found: %s" % [pl.name, " ".join(parts)])
	core.emit({"e": "share", "seat": seat, "code": core.shared_code.duplicate()})
	core.say("share", {"name": pl.name})
	core.add_unrest("share", 0.34)
	for o in core.living():
		core.brains[o].saw_kindness(seat, 0.2)


func view() -> Dictionary:
	var pr := prompt.duplicate(true)
	if str(pr.get("kind", "")) == "shop":
		pr.shelf = core.shops.shelf(int(pr.seat), str(pr.shop), bool(pr.get("coupon", false)))
	return {"seat": current(), "sub": sub, "sub_t": sub_t, "roll": roll, "dice": dice, "steps": steps, "dir": dir, "prompt": pr,
		"order": order, "walked": walked.duplicate(), "limit": MatchCore.HUMAN_TURN_LIMIT}
