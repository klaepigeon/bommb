class_name AiBrain
extends RefCounted
## An AI contestant. It plays through MatchCore.action() like anyone else and decides
## from MatchCore.view_for([its seat]): what a human in that seat would see, no more
## (it knows a hidden objective only if it read the minutes or answered the phone).
##
## Personality (each 0..1, rolled per seat): greed (Teeth and Dead Rats over safety), coop
## (helping; kindness seen raises it, being wronged lowers it), nerve (risks, holding on),
## perception (noticing tells), explore (getting up to look round the facility), crook
## (cheating, sabotage). From those, a style: cautious, reckless, selfish, cooperative,
## cheat, explorer, saboteur. Difficulty (skill) changes how well it chooses, never the dice.

var seat := 0
var rng := RandomNumberGenerator.new()
var greed := 0.5
var coop := 0.3
var nerve := 0.5
var perception := 0.6
var explore := 0.4
var crook := 0.3
var skill := 0.7
var think_time := 1.2
var hold_time := 1.5
var wait := 0.0
var _tried_door_round := -1
var _turn_key := ""
var _tried := {}
# the facility
var _walk: Array = []
var _goal := ""
var _away_plan := 0.0
var _fac_t := 0.0
var _leave_cd := 20.0


func setup(s: int, seed_v: int, over := {}) -> void:
	seat = s
	rng.seed = seed_v
	greed = rng.randf_range(0.2, 0.9)
	coop = rng.randf_range(0.12, 0.6)
	nerve = rng.randf_range(0.2, 0.9)
	perception = rng.randf_range(0.35, 0.85)
	explore = rng.randf_range(0.1, 0.8)
	crook = rng.randf_range(0.05, 0.7)
	think_time = rng.randf_range(0.8, 1.6)
	_leave_cd = rng.randf_range(15.0, 40.0)
	for k in over.keys():
		set(k, over[k])


func style() -> String:
	if crook > 0.55:
		return "cheat" if greed > 0.5 else "saboteur"
	if explore > 0.6:
		return "explorer"
	if coop > 0.5:
		return "cooperative"
	if nerve > 0.7:
		return "reckless"
	if nerve < 0.35:
		return "cautious"
	return "selfish"


func saw_kindness(from: int, amount: float) -> void:
	if from != seat:
		coop = minf(1.0, coop + amount * 0.5)


func wronged_by(_from: int, amount: float) -> void:
	coop = maxf(0.0, coop - amount)


func saw_cheat(_from: int, _caught: bool) -> void:
	coop = maxf(0.0, coop - 0.03)


func safe_moment(core: MatchCore) -> bool:
	var a := core.suspicion.view()
	return not a.watching and not a.turning


func to_save() -> Dictionary:
	return {"greed": greed, "coop": coop, "nerve": nerve, "perception": perception, "explore": explore, "crook": crook, "skill": skill}


func load_save(d: Dictionary) -> void:
	for k in d.keys():
		set(k, float(d[k]))


## Whoever's winning (Dead Rats, then Teeth), among the living others.
func rival(core: MatchCore, me: int) -> int:
	var best := -1
	var bt := -1
	for s in core.living():
		if s == me:
			continue
		var v := core.p(s).rats * 1000 + core.p(s).teeth
		if v > bt:
			bt = v
			best = s
	return best


func minigame(_core: MatchCore, mg: Minigame, dt: float) -> void:
	var v: Dictionary = mg.view_for([seat])
	mg.ai(seat, self, v, dt)


func ghost_minigame(_core: MatchCore, mg: Minigame, dt: float) -> void:
	mg.ghost_ai(seat, self, {}, dt)


func door(core: MatchCore) -> void:
	if coop >= 0.25 or rng.randf() < 0.02:
		core.action(seat, {"t": "push"})


# --- a ghost's turn -----------------------------------------------------------------

func ghost_turn(core: MatchCore, dt: float) -> void:
	wait += dt
	if wait < think_time * (0.05 if core.fast else 1.0):
		return
	wait = 0.0
	var v := core.view_for([seat])
	var me: Dictionary = v.players[seat]
	if int(me.rats) >= core.economy.resurrect_cost() and (nerve > 0.3 or core.round_n < core.max_rounds - 2):
		core.action(seat, {"t": "ghost", "do": "rise"})
		return
	# ghost items
	for it in me.items:
		if Items.use_of(it) == "ghost":
			var t := rival(core, seat) if coop < 0.5 else _poorest(core)
			core.action(seat, {"t": "item", "id": it, "target": t, "choice": "CURSE" if coop < 0.5 else "BLESS"})
			if not core.p(seat).items.has(it):
				return
	# the ghost shop
	if int(me.teeth) >= 6 and me.items.size() < Items.MAX_HELD:
		for e in v.shelves.get("ghost", []):
			if e.can and rng.randf() < 0.5:
				core.action(seat, {"t": "buy", "id": e.id})
				break
	var living := core.living()
	var r := rng.randf()
	if r < 0.6 or living.is_empty():
		core.action(seat, {"t": "ghost", "do": "scavenge"})
	elif r < 0.85:
		var t: int = living[rng.randi_range(0, living.size() - 1)]
		core.action(seat, {"t": "ghost", "do": "bless" if coop >= 0.5 else "haunt", "target": t})
	else:
		core.action(seat, {"t": "ghost", "do": "distract"})


func _poorest(core: MatchCore) -> int:
	return core.trailer(true)


# --- the board ----------------------------------------------------------------------

func board(core: MatchCore, dt: float) -> void:
	wait += dt
	if wait < think_time * (0.05 if core.fast else 1.0):
		return
	wait = 0.0
	var v := core.view_for([seat])
	var turn: Dictionary = v.turn
	if int(turn.seat) != seat:
		return
	var me: Dictionary = v.players[seat]
	if turn.sub == "prompt":
		_answer(core, v, me, turn.prompt)
		return
	if turn.sub != "pre":
		return
	if _turn_key != "%d/%d" % [v.round, seat]:
		_turn_key = "%d/%d" % [v.round, seat]
		_tried.clear()
	var it := _item_to_use(core, v, me)
	if it.size() > 0:
		_tried[it.id] = true
		core.action(seat, it)
		return
	if me.at_door:
		var everyone := true
		for o in v.players:
			if o.alive and not o.at_door:
				everyone = false
		if everyone and _tried_door_round != v.round:
			_tried_door_round = v.round
			core.action(seat, {"t": "try_door"})
			return
		if _wants_door(v):
			core.action(seat, {"t": "stay"})
			return
	if me.items.has("lazarus_rat"):
		for g in core.ghosts():
			core.action(seat, {"t": "give", "id": "lazarus_rat", "target": g})
			return
	if safe_moment(core) and int(me.suspicion) < 55 and rng.randf() < 0.5 * crook and not _tried.has("cheat"):
		_tried["cheat"] = true
		var opts: Array = core.cheats.available(seat, "board")
		if not opts.is_empty():
			core.action(seat, {"t": "cheat", "id": opts[rng.randi_range(0, opts.size() - 1)], "target": rival(core, seat)})
			return
	if coop >= 0.6 and not _tried.has("give"):
		_tried["give"] = true
		for x in me.items:
			for o in v.players:
				if o.seat == seat or not o.alive:
					continue
				if (x == "prosthetic" and Body.any_lost(o.body)) or (x == "first_aid" and Body.treatable(o.body) and Body.worst(o.body) >= 3):
					core.action(seat, {"t": "give", "id": x, "target": o.seat})
					return
	var unshared := false
	for i in me.clues.keys():
		if not v.shared_code.has(i):
			unshared = true
	if unshared and (coop >= 0.45 or v.shared_code.size() > 0 and coop >= 0.3) and not _tried.has("share"):
		_tried["share"] = true
		core.action(seat, {"t": "share"})
		return
	core.action(seat, {"t": "roll"})


## Which item, if any, is worth using now. A good AI (skill) picks the right one more often.
func _item_to_use(core: MatchCore, v: Dictionary, me: Dictionary) -> Dictionary:
	var b: Dictionary = me.body
	var dist_rat := _dist_to(core, int(me.space), int(v.rat_space))
	var can_afford_rat := int(me.teeth) >= int(v.rat_price)
	for it in me.items:
		if _tried.has(it) or not core.items.can_use(seat, it):
			continue
		if rng.randf() > 0.5 + skill * 0.5:
			continue
		var r := rival(core, seat)
		match it:
			"prosthetic":
				if Body.any_lost(b):
					return {"t": "item", "id": it}
			"first_aid", "bandage":
				if Body.treatable(b):
					return {"t": "item", "id": it}
			"surgery":
				if Body.worst(b) >= 3:
					return {"t": "item", "id": it}
			"helmet", "body_armour":
				if not me.helmet or it == "body_armour":
					return {"t": "item", "id": it}
			"painkillers":
				if Body.legs(b) < 0.7 and int(me.painkillers) == 0:
					return {"t": "item", "id": it}
			"antidote":
				if not me.statuses.is_empty():
					return {"t": "item", "id": it}
			"alibi":
				if int(me.suspicion) >= 40:
					return {"t": "item", "id": it}
			"lucky_foot":
				if int(me.cage) >= 2:
					return {"t": "item", "id": it}
			"loaded_dice":
				if can_afford_rat and dist_rat >= 1 and dist_rat <= 6:
					return {"t": "item", "id": it, "choice": "LOW" if dist_rat <= 3 else "HIGH"}
			"high_roller", "double_roll", "loaded_double", "greased_shoes":
				if can_afford_rat and dist_rat > 4 or nerve > 0.6:
					return {"t": "item", "id": it}
			"reverse_gear":
				var back := _dist_back(core, int(me.space), int(v.rat_space))
				if can_afford_rat and back > 0 and back <= 6 and back < dist_rat:
					return {"t": "item", "id": it}
			"warp_tooth":
				if r >= 0 and can_afford_rat and _dist_to(core, core.p(r).space, int(v.rat_space)) < dist_rat - 3:
					return {"t": "item", "id": it, "target": r}
			"pickpocket", "tooth_tax", "sabotage_kit":
				if r >= 0 and coop < 0.5:
					return {"t": "item", "id": it, "target": r}
			"poisoned_gift":
				if r >= 0 and crook > 0.4:
					return {"t": "item", "id": it, "target": r}
			"rat_trap":
				if coop < 0.5:
					return {"t": "item", "id": it}
			"gift_basket":
				if coop > 0.5:
					var poor := core.trailer(true)
					if poor >= 0 and poor != seat:
						return {"t": "item", "id": it, "target": poor}
			"debt_note":
				if greed > 0.5 and int(me.teeth) >= 6 and r >= 0:
					return {"t": "item", "id": it, "target": r}
			"debt_collector":
				for o in v.players:
					if int(o.debts.get(seat, 0)) > 0:
						return {"t": "item", "id": it}
			"counterfeit_teeth", "loaded_wallet", "black_market_coupon":
				return {"t": "item", "id": it}
			"loophole", "rubber_stamp":
				if not v.rules.is_empty():
					return {"t": "item", "id": it}
			"emergency_legislation", "executive_privilege":
				if v.rules.size() >= 2:
					return {"t": "item", "id": it}
			"gavel":
				return {"t": "item", "id": it}
			"gift":
				if rng.randf() < 0.5:
					return {"t": "item", "id": it}
			"loaded_die":
				if safe_moment(core):
					return {"t": "item", "id": it}
	return {}


## Squares forward to `to` (BFS over the board graph), or 99.
func _dist_to(core: MatchCore, from: int, to: int) -> int:
	if to < 0:
		return 99
	return int(core.graph.distances_from(from).get(to, 99))


func _dist_back(core: MatchCore, from: int, to: int) -> int:
	var at := from
	for k in 8:
		at = int(core.graph.prev_of(at)[0])
		if at == to:
			return k + 1
	return 99


func _answer(core: MatchCore, v: Dictionary, me: Dictionary, pr: Dictionary) -> void:
	match str(pr.kind):
		"door_stop":
			core.action(seat, {"t": "answer", "yes": _wants_door(v)})
		"rat":
			core.action(seat, {"t": "answer", "yes": true})
		"path":
			core.action(seat, {"t": "answer", "to": _choose_path(core, v, me, pr.options)})
		"shop":
			var want := _shopping(core, v, me, pr)
			if want != "":
				core.action(seat, {"t": "answer", "buy": want})
			core.action(seat, {"t": "answer", "done": true})
		"gamble":
			var w := 0
			if greed > 0.5 and nerve > 0.4:
				for x in pr.options:
					if int(x) <= int(me.teeth) / 3:
						w = int(x)
			core.action(seat, {"t": "answer", "wager": w})
		"hidden":
			core.action(seat, {"t": "answer", "yes": nerve > 0.3})
		"poison":
			core.action(seat, {"t": "answer", "yes": nerve > 0.7 and me.statuses.is_empty()})
		"duel":
			var target: int = rival(core, seat) if pr.options.has(rival(core, seat)) else pr.options[0]
			var ws: Array = pr.get("wagers", [0])
			var w: int = ws[mini(ws.size() - 1, int(greed * nerve * ws.size()))]
			core.action(seat, {"t": "answer", "target": target, "wager": w})
		"gavel":
			# the kind of law that suits me
			var pick := ""
			for r in pr.get("rules", []):
				if (str(r.id) == "rat_sale" and int(me.teeth) >= 10) or (str(r.id) == "double_pay") or (str(r.id) == "big_dice" and nerve > 0.5):
					pick = str(r.id)
			if pick == "" and not (pr.options as Array).is_empty():
				pick = str(pr.options[rng.randi_range(0, pr.options.size() - 1)])
			core.action(seat, {"t": "answer", "rule": pick})
		"veto":
			var pick := ""
			for r in pr.get("rules", []):
				if str(r.id) in ["rat_tax", "inflation", "austerity", "bad_luck", "small_dice", "no_items", "short_leash"]:
					pick = str(r.id)
			if pick == "" and not (pr.options as Array).is_empty():
				pick = str(pr.options[0])
			core.action(seat, {"t": "answer", "rule": pick})
		_:
			var r := rival(core, seat)
			core.action(seat, {"t": "answer", "target": r if pr.options.has(r) else pr.options[0]})


## At a junction: which way. The rat if it's reachable and affordable; else what suits me
## (the greedy and the brave take the abattoir; the hurt take the chapel; the locker if
## it's a shortcut worth paying for).
func _choose_path(core: MatchCore, v: Dictionary, me: Dictionary, opts: Array) -> int:
	var best := int(opts[0].to)
	var best_score := -INF
	for o in opts:
		if not o.can:
			continue
		var to := int(o.to)
		var sc := 0.0
		var d := _dist_to(core, to, int(v.rat_space))
		if int(me.teeth) >= int(v.rat_price) + int(o.toll):
			sc += 10.0 - d * 0.8
		var name := str(o.name)
		if name == "THE ABATTOIR":
			sc += (greed + nerve - 1.0) * 3.0
		elif name == "THE CHAPEL":
			sc += (2.0 if Body.worst(me.body) >= 3 or not core.ghosts().is_empty() else -0.5) + (1.0 - nerve)
		elif name == "THE MEAT LOCKER":
			sc += 1.5 - float(o.toll) * 0.2 + greed
		sc += rng.randf() * (1.0 - skill) * 3.0
		if sc > best_score:
			best_score = sc
			best = to
	return best


func _shopping(core: MatchCore, v: Dictionary, me: Dictionary, pr: Dictionary) -> String:
	var shelf: Array = pr.get("shelf", [])
	if me.items.size() >= Items.MAX_HELD:
		return ""
	var b: Dictionary = me.body
	var wants := []
	if Body.any_lost(b):
		wants.append("prosthetic")
	if not me.statuses.is_empty():
		wants.append("antidote")
	if Body.treatable(b):
		wants.append_array(["first_aid", "bandage"])
	if int(me.suspicion) >= 50:
		wants.append("alibi")
	if not core.ghosts().is_empty() and coop >= 0.6:
		wants.append("lazarus_rat")
	if crook > 0.4:
		wants.append_array(["loaded_die", "sabotage_kit", "poisoned_gift", "counterfeit_teeth"])
	wants.append_array(["double_roll", "loaded_dice", "warp_tooth", "high_roller", "lucky_tooth", "safety_pin", "shortcut_key", "helmet"])
	# save up for the rat if it's close: don't spend what it costs
	var keep := int(v.rat_price) if _dist_to(core, int(me.space), int(v.rat_space)) < 12 and greed > 0.4 else 0
	for w in wants:
		for e in shelf:
			if e.id == w and e.can and int(me.teeth) - int(e.price) >= keep:
				return w
	return ""


## Worth waiting at the door? Only the cooperative, once the numbers are known.
func _wants_door(v: Dictionary) -> bool:
	if coop < 0.4:
		return false
	var key_seen := false
	for o in v.players:
		if o.alive and o.has_key:
			key_seen = true
	var known: Dictionary = v.shared_code.duplicate()
	known.merge(v.players[seat].clues)
	return known.size() >= 3 and (key_seen or coop >= 0.7)


# --- the facility -------------------------------------------------------------------

## Every frame, whatever's going on: maybe get up; if up, walk somewhere, do something,
## come back (or don't, if the timer doesn't frighten it).
func facility(core: MatchCore, dt: float) -> void:
	var me := core.p(seat)
	var fac := core.facility
	if not me.away():
		_leave_cd -= dt
		if _leave_cd > 0.0:
			return
		_leave_cd = rng.randf_range(12.0, 30.0) / maxf(0.2, explore)
		if core.fast:
			_leave_cd *= 0.3
		# not when it's nearly my turn, unless I'm reckless; not when I'm already watched
		var turns_away := _turns_until_mine(core)
		if me.suspicion >= 60 or rng.randf() > explore * 0.7:
			return
		if turns_away <= 1 and nerve < 0.7:
			return
		if not fac.can_leave(seat):
			return
		_pick_goal(core)
		if _goal == "":
			return
		core.action(seat, {"t": "leave"})
		_walk = fac.building.find_path(me.pos, fac.stand_at(_goal))
		_away_plan = me.away_limit * (0.55 + nerve * 0.6)
		_fac_t = 0.0
		return
	# away
	_fac_t += dt
	var heading_back := _goal == "" or me.away_t > _away_plan or (_turns_until_mine(core) == 0 and nerve < 0.6) or core.phase == "mg_intro"
	if heading_back and _goal != "back":
		_goal = "back"
		_walk = fac.building.find_path(me.pos, fac.seat_pos(seat) * 1.2)
	var speed := fac.walk_speed * 0.8 * Body.speed(me.body, me.pk())
	var step := speed * dt
	var pos := me.pos
	while step > 0.0 and not _walk.is_empty():
		var nxt: Vector2 = _walk[0]
		var d := pos.distance_to(nxt)
		if d <= step:
			pos = nxt
			step -= d
			_walk.pop_front()
		else:
			pos += (nxt - pos) / d * step
			step = 0.0
	if pos != me.pos:
		core.action(seat, {"t": "walk", "pos": [pos.x, pos.y], "dt": dt, "yaw": atan2(-(pos - me.pos).x, -(pos - me.pos).y)})
	if not _walk.is_empty():
		return
	if _goal == "back":
		core.action(seat, {"t": "sit", "force": not fac.at_table(me.pos)})
		_goal = ""
		return
	# at the thing: do something (when he's not looking, if careful)
	if fac.near(seat, _goal):
		if not safe_moment(core) and fac.things[_goal].get("area", "hall") == "hall" and rng.randf() < 1.0 - nerve:
			return
		var acts := fac.actions_at(seat, _goal)
		acts = acts.filter(func(a): return str(a.get("needs", "")) == "" or me.items.has(str(a.needs)))
		acts = acts.filter(func(a): return int(a.get("cost", 0)) <= me.teeth)
		if acts.is_empty() or _tried.has("fac:" + _goal + str(core.round_n)):
			_pick_goal(core, _goal)
			_walk = fac.building.find_path(me.pos, fac.stand_at(_goal)) if _goal != "" else []
			return
		var a: Dictionary = acts[rng.randi_range(0, acts.size() - 1)]
		if a.id == "arcade_play":
			core.action(seat, {"t": "interact", "id": _goal, "do": a.id})
			return
		if a.id == "arcade_hit":
			if rng.randf() < 0.4 + perception * 0.5:
				core.action(seat, {"t": "interact", "id": _goal, "do": a.id})
			return
		core.action(seat, {"t": "interact", "id": _goal, "do": a.id, "target": rival(core, seat)})
		if rng.randf() < 0.5:
			_tried["fac:" + _goal + str(core.round_n)] = true
	else:
		_walk = fac.building.find_path(me.pos, fac.stand_at(_goal))
		if _walk.is_empty():
			_goal = ""


func _pick_goal(core: MatchCore, not_this := "") -> void:
	var fac := core.facility
	var me := core.p(seat)
	var pref := []
	if crook > 0.5:
		pref.append_array(["booth", "props", "boiler_door", "boiler", "cistern", "lockers"])
	if greed > 0.5:
		pref.append_array(["drain", "vending", "till", "nest", "van", "coats"])
	if explore > 0.5:
		pref.append_array(["freezer", "panel", "phone", "arcade", "office", "stairs_door", "kitchen", "pinata"])
	if pref.is_empty():
		pref = fac.things.keys()
	var from := me.pos if me.away() else fac.seat_pos(seat) * 1.25
	var ok := []
	for id in pref:
		if id != not_this and fac.things.has(id) and not fac.actions_at(seat, id).is_empty() and fac.building.reachable(from, fac.stand_at(id)):
			ok.append(id)
	_goal = ok[rng.randi_range(0, ok.size() - 1)] if not ok.is_empty() else ""


func _turns_until_mine(core: MatchCore) -> int:
	if core.phase != "turn":
		return 9
	var r := core.rules
	var k := r.order.find(seat)
	if k < 0:
		return 9
	return k - r.idx if k >= r.idx else 9
