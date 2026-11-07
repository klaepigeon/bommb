class_name CageManager
extends RefCounted
## THE CAGE: per player, how far the Caller has stacked the odds against them (0..5).
## Every random system asks tip(seat, system) before it settles something: "does he lean
## on this one?" with the chance for that player's Cage level (assets/data/cage.json).
## Separate from suspicion: suspicion is what you did; the Cage is what he does about
## it, when he decides to. He tightens it at the thresholds, and at the end of a round
## if he feels like it; items, events and his file can loosen it.

var core: MatchCore
var table: Dictionary = {}
var levels: Array = []
var tighten_chance := 0.6
var log: Array = []       # [seat, system] each time he tipped something (tests, balance)


func _init(c: MatchCore) -> void:
	core = c
	var d := Assets.load_json("res://assets/data/cage.json")
	table = d.get("systems", {})
	levels = d.get("levels", [])
	tighten_chance = float(d.get("tighten_chance", 0.6))


func chance(seat: int, system: String) -> float:
	var row: Array = table.get(system, [])
	if row.is_empty():
		return 0.0
	return float(row[clampi(core.p(seat).cage, 0, row.size() - 1)])


## Does he tip this one against `seat`?
func tip(seat: int, system: String) -> bool:
	if seat < 0 or seat >= core.players.size():
		return false
	var hit := core.rng.randf() < chance(seat, system)
	if hit:
		log.append([seat, system])
		core.emit({"e": "cage_tip", "seat": seat, "system": system})
	return hit


func tighten(seat: int, why: String) -> void:
	var p := core.p(seat)
	if p.cage >= 5:
		return
	p.cage += 1
	core.emit({"e": "cage", "seat": seat, "value": p.cage, "why": why})
	core.say("cage_tighten", {"name": p.name, "level": level_name(p.cage)})


func loosen(seat: int, why: String) -> void:
	var p := core.p(seat)
	if p.cage <= 0:
		return
	p.cage -= 1
	core.emit({"e": "cage", "seat": seat, "value": p.cage, "why": why})


## End of a round: he looks over his files. Everyone past a threshold he hasn't acted on
## yet might get a turn of the screw (or might not; he likes to let it build).
func review() -> void:
	for s in core.living():
		var p := core.p(s)
		var want := 0
		for th in [25, 50, 75]:
			if p.suspicion >= th:
				want += 1
		if p.suspicion >= 90:
			want += 1
		if p.cage < want and core.rng.randf() < tighten_chance:
			tighten(s, "review")


func level_name(v: int) -> String:
	return str(levels[clampi(v, 0, levels.size() - 1)]) if not levels.is_empty() else str(v)


## A die roll for `seat`, with his thumb on it: when he tips it, two rolls, the lower.
func roll(seat: int, sides: int) -> int:
	var r := core.rng.randi_range(1, sides)
	if tip(seat, "dice"):
		r = mini(r, core.rng.randi_range(1, sides))
	return r


func to_save() -> Dictionary:
	return {}


func load_save(_d: Dictionary) -> void:
	pass
