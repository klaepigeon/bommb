class_name CutsceneManager
extends RefCounted
## FORCED SPECTATOR CUTSCENES. The Caller stops the game and makes everyone watch one
## player: drink the poison, lose the hand, die, come back, get the jackpot. Everyone sees
## the same cinematic (an event every client plays); only the target gets the effect.
##
## Host-authoritative and exactly-once: each cutscene has a unique id, the effect is data
## ({do, ...}) applied by the host at `impact` seconds into the scene and then marked
## applied, so a resent event can't double it and a spectator never inherits it. A
## blocking cutscene freezes the board (MatchCore stops ticking the turn) until it's done;
## a second one asked for during a blocking one waits in the queue. If the target is gone
## (disconnected: an AI takes their seat; dead: the effect is skipped if it needs a living
## body) it still resolves. Presentation mode is the cutscene's own (MEAT_PUPPET: the
## board's puppets act it out; FULL_CHARACTER: the people at the table do; CINEMATIC).

const MODES := ["MEAT_PUPPET", "FULL_CHARACTER", "CINEMATIC", "CUSTOM"]

var core: MatchCore
var active: Dictionary = {}     # the one playing now
var queue: Array = []
var done_ids: Dictionary = {}   # id -> true once the effect is applied
var _n := 0
var log: Array = []             # [{id, target, effect, applied_to}] (tests)


func _init(c: MatchCore) -> void:
	core = c


func blocking() -> bool:
	return not active.is_empty() and bool(active.get("blocking", true))


## Ask for one. `effect`: {do: poison|status|injure|kill|teeth|rats|revive|heal|item|none, ...}.
func play(kind: String, target: int, effect: Dictionary, mode := "FULL_CHARACTER", blocking_ := true, length := 4.0, impact := 2.2) -> int:
	_n += 1
	var cs := {"id": "%d:%d" % [core.seed_value % 100000, _n], "kind": kind, "target": target, "effect": effect.duplicate(true),
		"mode": mode if MODES.has(mode) else "CINEMATIC", "blocking": blocking_, "length": length, "impact": impact, "t": 0.0,
		"applied": false, "spectators": _spectators(), "round": core.round_n}
	if active.is_empty():
		_begin(cs)
	else:
		queue.append(cs)
	return _n


func _spectators() -> Array:
	var out := []
	for p in core.players:
		out.append(p.seat)
	return out


func _begin(cs: Dictionary) -> void:
	active = cs
	core.emit({"e": "cutscene", "id": cs.id, "kind": cs.kind, "target": cs.target, "mode": cs.mode, "spectators": cs.spectators,
		"length": core._wait(float(cs.length)), "impact": core._wait(float(cs.impact)), "effect": str(cs.effect.get("do", "none"))})


func tick(dt: float) -> void:
	if active.is_empty():
		return
	active.t = float(active.t) + dt
	if not active.applied and float(active.t) >= core._wait(float(active.impact)):
		_apply(active)
	if float(active.t) >= core._wait(float(active.length)):
		if not active.applied:
			_apply(active)
		core.emit({"e": "cutscene_end", "id": active.id})
		active = {}
		if not queue.is_empty():
			_begin(queue.pop_front())


## The effect, once, on the target only.
func _apply(cs: Dictionary) -> void:
	cs.applied = true
	if done_ids.has(cs.id):
		return
	done_ids[cs.id] = true
	var s := int(cs.target)
	var fx: Dictionary = cs.effect
	log.append({"id": cs.id, "target": s, "do": str(fx.get("do", "none"))})
	if s < 0 or s >= core.players.size():
		return
	var p := core.p(s)
	match str(fx.get("do", "none")):
		"poison":
			if p.alive:
				core.status.apply(s, str(fx.get("id", core.status.random_poison(s))), str(fx.get("why", "the Caller")))
		"injure":
			if p.alive:
				var part := str(fx.get("part", ""))
				if part == "":
					part = Body.random_severable(p.body, core.rng)
				if part != "":
					core.injure(s, part, str(fx.get("status", "broken")), str(fx.get("why", "the Caller")))
		"kill":
			if p.alive:
				core.kill(s, str(fx.get("anim", "shot")), fx.get("fallback", []), bool(fx.get("forced", false)))
		"teeth":
			var n := int(fx.get("n", 0))
			if n > 0:
				core.economy.award(s, n, str(fx.get("why", "the Caller")), false)
			else:
				core.economy.take(s, -n, str(fx.get("why", "the Caller")))
		"rats":
			core.change_rats(s, int(fx.get("n", 1)), str(fx.get("why", "the Caller")))
		"revive":
			if p.ghost:
				core.resurrection.revive(s, str(fx.get("how", "square")))
		"heal":
			if p.alive:
				Body.heal_temporary(p.body)
				core.emit({"e": "heal", "seat": s})
		"item":
			if p.alive or p.ghost:
				core.give_item(s, str(fx.get("id", "bandage")), "the Caller")
	core.emit({"e": "cutscene_impact", "id": cs.id, "target": s})


func view() -> Dictionary:
	if active.is_empty():
		return {}
	return {"id": active.id, "kind": active.kind, "target": active.target, "mode": active.mode, "t": active.t,
		"length": core._wait(float(active.length)), "blocking": active.blocking}
