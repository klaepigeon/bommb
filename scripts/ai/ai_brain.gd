class_name AiBrain
extends RefCounted
## An AI contestant. It plays through MatchCore.action() like anyone else and decides
## from MatchCore.view_for([its seat]): what a human in that seat would see, no more.
##
## Personality: greed (rats over safety), coop (willingness to help the others; it
## moves: kindness seen raises it, being wronged lowers it), nerve (holds on longer, takes
## risks), perception (how likely it is to notice a tell).

var seat := 0
var rng := RandomNumberGenerator.new()
var greed := 0.5
var coop := 0.3
var nerve := 0.5
var perception := 0.6
var think_time := 1.2
var hold_time := 1.5
var wait := 0.0
var _tried_door_round := -1
var _turn_key := ""
var _tried := {}


func setup(s: int, seed_v: int, over := {}) -> void:
	seat = s
	rng.seed = seed_v
	greed = rng.randf_range(0.2, 0.9)
	coop = rng.randf_range(0.12, 0.5)
	nerve = rng.randf_range(0.2, 0.9)
	perception = rng.randf_range(0.35, 0.85)
	think_time = rng.randf_range(0.8, 1.6)
	for k in over.keys():
		set(k, over[k])


func saw_kindness(from: int, amount: float) -> void:
	if from != seat:
		coop = minf(1.0, coop + amount * 0.5)


func wronged_by(_from: int, amount: float) -> void:
	coop = maxf(0.0, coop - amount)


## Saw someone cheat (or get caught at it): the honest ones trust a little less.
func saw_cheat(_from: int, _caught: bool) -> void:
	coop = maxf(0.0, coop - 0.03)


## Is now a good moment to do something he shouldn't see? (from what's visible: his cage)
func safe_moment(core: MatchCore) -> bool:
	var a := core.suspicion.view()
	return not a.watching and not a.turning


## A ghost's board turn: come back if you can afford it; otherwise scavenge, mostly, and
## sometimes help (or haunt) the living.
func ghost_turn(core: MatchCore, dt: float) -> void:
	wait += dt
	if wait < think_time * (0.05 if core.fast else 1.0):
		return
	wait = 0.0
	var me := core.p(seat)
	if me.rats >= core.economy.resurrect_cost():
		core.action(seat, {"t": "ghost", "do": "rise"})
		return
	var living := core.living()
	var r := rng.randf()
	if r < 0.65 or living.is_empty():
		core.action(seat, {"t": "ghost", "do": "scavenge"})
	elif r < 0.85:
		var t: int = living[rng.randi_range(0, living.size() - 1)]
		core.action(seat, {"t": "ghost", "do": "bless" if coop >= 0.5 else "haunt", "target": t})
	else:
		core.action(seat, {"t": "ghost", "do": "distract"})


func ghost_minigame(core: MatchCore, mg: Minigame, dt: float) -> void:
	mg.ghost_ai(seat, self, {}, dt)


## Whoever's winning (most rats), among the living others.
func rival(core: MatchCore, me: int) -> int:
	var best := -1
	var bt := -1
	for s in core.living():
		if s != me and core.p(s).rats > bt:
			bt = core.p(s).rats
			best = s
	return best


func minigame(core: MatchCore, mg: Minigame, dt: float) -> void:
	var v: Dictionary = mg.view_for([seat])
	mg.ai(seat, self, v, dt)


func door(core: MatchCore) -> void:
	# The push. Most do. The ones who never trusted anyone might not.
	if coop >= 0.25 or rng.randf() < 0.02:
		core.action(seat, {"t": "push"})


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
	if turn.sub == "room":
		_room(core, v)
		return
	if turn.sub == "prompt":
		var pr: Dictionary = turn.prompt
		if pr.kind == "door_stop":
			core.action(seat, {"t": "answer", "yes": _wants_door(v)})
		elif pr.kind == "shop":
			var want := _shopping(core, me, str(pr.shop))
			if want != "":
				core.action(seat, {"t": "answer", "buy": want})
			core.action(seat, {"t": "answer", "done": true})
		elif pr.kind == "gamble":
			core.action(seat, {"t": "answer", "wager": 3 if greed > 0.5 and me.rats >= 3 else 0})
		elif pr.kind == "hidden":
			core.action(seat, {"t": "answer", "yes": nerve > 0.3})
		else:
			core.action(seat, {"t": "answer", "target": rival(core, seat) if pr.options.has(rival(core, seat)) else pr.options[0]})
		return
	if turn.sub != "pre":
		return
	# Patch yourself up (each item tried once a turn: never loop on one that does nothing).
	var b: Dictionary = me.body
	if _turn_key != "%d/%d" % [v.round, seat]:
		_turn_key = "%d/%d" % [v.round, seat]
		_tried.clear()
	for it in me.items:
		if _tried.has(it):
			continue
		_tried[it] = true
		match it:
			"prosthetic":
				if Body.any_lost(b):
					core.action(seat, {"t": "item", "id": it})
					return
			"first_aid":
				if Body.treatable(b):
					core.action(seat, {"t": "item", "id": it})
					return
			"helmet":
				if not me.helmet:
					core.action(seat, {"t": "item", "id": it})
					return
			"painkillers":
				if Body.legs(b) < 0.7 and int(me.painkillers) == 0:
					core.action(seat, {"t": "item", "id": it})
					return
			"antidote":
				if not me.statuses.is_empty():
					core.action(seat, {"t": "item", "id": it})
					return
			"surgery":
				if Body.worst(b) >= 3:
					core.action(seat, {"t": "item", "id": it})
					return
			"alibi":
				if int(me.suspicion) >= 40:
					core.action(seat, {"t": "item", "id": it})
					return
			"lucky_foot":
				if int(me.cage) >= 2:
					core.action(seat, {"t": "item", "id": it})
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
	# A ghost who was kind to us: bring them back.
	if me.items.has("lazarus_rat"):
		for g in core.ghosts():
			core.action(seat, {"t": "give", "id": "lazarus_rat", "target": g})
			return
	# Cheat at the table, when he's looking away and the file isn't too fat yet.
	if safe_moment(core) and int(me.suspicion) < 55 and rng.randf() < 0.45 * (1.0 - coop) and not _wants_door(v):
		var opts: Array = core.cheats.available(seat, "board")
		if not opts.is_empty():
			core.action(seat, {"t": "cheat", "id": opts[rng.randi_range(0, opts.size() - 1)], "target": rival(core, seat)})
			return
	# Get up from the table now and then (the curious, the greedy).
	if int(me.suspicion) < 50 and rng.randf() < 0.12 + 0.12 * greed and core.round_n > 1 and not _wants_door(v):
		core.action(seat, {"t": "leave"})
		return
	# Help someone else.
	if coop >= 0.6:
		for it in me.items:
			for o in v.players:
				if o.seat == seat or not o.alive:
					continue
				if (it == "prosthetic" and Body.any_lost(o.body)) or (it == "first_aid" and Body.treatable(o.body) and Body.worst(o.body) >= 3):
					core.action(seat, {"t": "give", "id": it, "target": o.seat})
					return
	# Tell what you know.
	var unshared := false
	for i in me.clues.keys():
		if not v.shared_code.has(i):
			unshared = true
	if unshared and (coop >= 0.45 or v.shared_code.size() > 0 and coop >= 0.3):
		core.action(seat, {"t": "share"})
		return
	core.action(seat, {"t": "roll"})


func _shopping(core: MatchCore, me: Dictionary, which: String) -> String:
	var prices: Dictionary = core.economy.prices(which)
	var b: Dictionary = me.body
	var wants := []
	if Body.any_lost(b):
		wants.append("prosthetic")
	if not me.statuses.is_empty():
		wants.append("antidote")
	if Body.treatable(b):
		wants.append("first_aid")
	if int(me.suspicion) >= 50:
		wants.append("alibi")
	if not core.ghosts().is_empty() and coop >= 0.6:
		wants.append("lazarus_rat")
	if greed > 0.6:
		wants.append("loaded_die")
	for w in wants:
		if prices.has(w) and int(me.rats) >= int(prices[w]) + 2:
			return w
	return ""


## Out of the chair: go somewhere, do something, sit back down.
func _room(core: MatchCore, v: Dictionary) -> void:
	var me: Dictionary = v.players[seat]
	var room: Dictionary = v.room
	if int(me.room_actions) <= 0:
		core.action(seat, {"t": "sit"})
		return
	if str(me.location) == "up" or room.actions.is_empty():
		var spots: Array = room.hotspots.keys()
		var pref := ["booth", "cellar", "coats", "kitchen", "props", "pinata", "under_stage", "fusebox"]
		if int(me.suspicion) >= 40:
			pref = ["booth", "kitchen", "coats"]
		var pick: String = spots[rng.randi_range(0, spots.size() - 1)]
		for p in pref:
			if spots.has(p) and rng.randf() < 0.5 and p != str(me.location):
				pick = p
				break
		if pick == str(me.location):
			core.action(seat, {"t": "sit"})
		else:
			core.action(seat, {"t": "go", "where": pick})
		return
	# wait for him to look away (a careful one), then act
	if not safe_moment(core) and rng.randf() < 0.7:
		return
	var acts: Array = room.actions
	var a: Dictionary = acts[rng.randi_range(0, acts.size() - 1)]
	if str(a.get("needs", "")) != "" and not me.items.has(a.needs):
		core.action(seat, {"t": "go", "where": "coats"})
		return
	if a.id == "doctor_file" or (a.id == "loosen_cage" and int(me.cage) > 0):
		pass
	core.action(seat, {"t": "room_act", "id": a.id, "target": rival(core, seat)})


## Worth waiting at the door? Only for the cooperative, and only once there's a reason:
## the numbers are known (by someone who told everyone) and the key is out there.
func _wants_door(v: Dictionary) -> bool:
	if coop < 0.4:
		return false
	var key_seen := false
	var waiting := 0
	for o in v.players:
		if o.alive and o.has_key:
			key_seen = true
		if o.alive and o.at_door:
			waiting += 1
	var known: Dictionary = v.shared_code.duplicate()
	known.merge(v.players[seat].clues)
	# keep looking for numbers until all three are known; then everyone to the door
	return known.size() >= 3 and (key_seen or coop >= 0.7)
