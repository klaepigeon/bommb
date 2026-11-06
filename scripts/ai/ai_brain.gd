class_name AiBrain
extends RefCounted
## An AI contestant. It plays through MatchCore.action() like anyone else and decides
## from MatchCore.view_for([its seat]): what a human in that seat would see, no more.
##
## Personality: greed (tickets over safety), coop (willingness to help the others; it
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


## Whoever's winning (most tickets), among the living others.
func rival(core: MatchCore, me: int) -> int:
	var best := -1
	var bt := -1
	for s in core.living():
		if s != me and core.p(s).tickets > bt:
			bt = core.p(s).tickets
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
	if turn.sub == "prompt":
		var pr: Dictionary = turn.prompt
		if pr.kind == "door_stop":
			core.action(seat, {"t": "answer", "yes": _wants_door(v)})
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
	core.action(seat, {"t": "roll"})


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
	if known.size() >= 3 and (key_seen or coop >= 0.7):
		return true
	return key_seen and waiting >= 1 and coop >= 0.6 and known.size() >= 2
