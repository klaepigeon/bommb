class_name AwardManager
extends RefCounted
## THE CALLER'S AWARDS (assets/data/awards.json), the bonus stars: at the end, three
## awards drawn at random from the ones somebody qualifies for, a Dead Rat each (two for
## the rare ones) to whoever has the most (or the least) of that statistic. Every stat is
## tracked from the first turn (PlayerState.stats). Some reward doing terribly.

var core: MatchCore
var catalogue: Dictionary = {}
var given: Array = []      # [{id, name, desc, seats, rats}]


func _init(c: MatchCore) -> void:
	core = c
	catalogue = Assets.load_json("res://assets/data/awards.json").get("awards", {})


func stat_of(seat: int, k: String) -> int:
	var p := core.p(seat)
	match k:
		"teeth_now":
			return p.teeth
		"rats_now":
			return p.rats
		"deaths":
			return p.deaths
	return int(p.stats.get(k, 0))


## Who would win this award now ([] if nobody qualifies).
func winners_of(id: String) -> Array:
	var d: Dictionary = catalogue[id]
	var low: bool = d.get("low", false)
	var seats := []
	for pl in core.players:
		if pl.ghost and not d.get("ghosts", true):
			continue
		seats.append(pl.seat)
	if seats.is_empty():
		return []
	var best := 0
	var first := true
	for s in seats:
		var v := stat_of(s, d.stat)
		if first or (v < best if low else v > best):
			best = v
			first = false
	if not low and best < int(d.get("min", 1)):
		return []
	if low and d.has("max") and best > int(d.max):
		return []
	var out := []
	for s in seats:
		if stat_of(s, d.stat) == best:
			out.append(s)
	# an award everyone shares isn't an award
	if out.size() == core.players.size() and core.players.size() > 1:
		return []
	return out


func eligible() -> Array:
	var ids := catalogue.keys().filter(func(k): return not winners_of(k).is_empty())
	ids.sort()
	return ids


## The ceremony: pick three, hand out the Dead Rats.
func present(n := 3) -> Array:
	given.clear()
	var pool := eligible()
	while given.size() < n and not pool.is_empty():
		var id: String = pool.pop_at(core.rng.randi_range(0, pool.size() - 1))
		var d: Dictionary = catalogue[id]
		var ws := winners_of(id)
		var r := int(d.get("rats", 1))
		for s in ws:
			core.change_rats(s, r, "award: " + str(d.name))
		given.append({"id": id, "name": d.name, "desc": d.desc, "seats": ws, "rats": r})
		core.emit({"e": "award", "id": id, "name": d.name, "desc": d.desc, "seats": ws, "rats": r})
	return given
