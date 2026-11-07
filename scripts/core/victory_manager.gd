class_name VictoryManager
extends RefCounted
## Who wins. Most Dead Rats, always (Teeth break ties, then fewest deaths); that can't be
## amended away. THE CALLER'S GAME (mode "callers_game") adds hidden victory conditions
## (assets/data/objectives.json): drawn at the start, revealed halfway, and at the end
## whoever meets each best is paid Dead Rats for it, so he can reward failure, poverty,
## death, avoidance, cooperation and betrayal. Every statistic counts from the first turn.

var core: MatchCore
var data: Dictionary = {}
var mode := "classic"
var hidden: Array = []          # objective ids
var revealed := false
var results: Array = []


func _init(c: MatchCore) -> void:
	core = c
	data = Assets.load_json("res://assets/data/objectives.json")


func setup(m: String) -> void:
	mode = m
	if mode != "callers_game":
		return
	var pool: Array = data.get("objectives", {}).keys()
	pool.sort()
	for i in int(data.get("reveal", 2)):
		if pool.is_empty():
			break
		hidden.append(pool.pop_at(core.rng.randi_range(0, pool.size() - 1)))


func reveal_round() -> int:
	return maxi(2, core.max_rounds / 2)


func on_round(n: int) -> void:
	if mode != "callers_game" or revealed or n < reveal_round():
		return
	revealed = true
	core.say("callers_game_reveal")
	core.emit({"e": "objectives", "list": view()})
	for o in view():
		core.toast("THE CALLER'S GAME: %s — %s" % [o.name, o.desc])
	# and the rulebook is his now: an amendment of his own
	core.rulebook.add_random(-1)


func objective_winners(id: String) -> Array:
	var d: Dictionary = data.objectives[id]
	var low: bool = d.get("low", false)
	var best := 0
	var first := true
	var cand := []
	for pl in core.players:
		if pl.ghost and not d.get("ghosts", true):
			continue
		cand.append(pl.seat)
	for s in cand:
		var v := core.awards.stat_of(s, d.stat)
		if first or (v < best if low else v > best):
			best = v
			first = false
	if not low and best <= 0:
		return []
	return cand.filter(func(s): return core.awards.stat_of(s, d.stat) == best)


## End of the match: pay out the hidden conditions.
func settle() -> void:
	results.clear()
	for id in hidden:
		var ws := objective_winners(id)
		for s in ws:
			core.change_rats(s, int(data.get("rats", 3)), "the Caller's Game")
		results.append({"id": id, "name": data.objectives[id].name, "seats": ws})
		core.emit({"e": "objective_paid", "id": id, "seats": ws})


## Final standings: [{seat, name, rats, teeth, place}]
func standings() -> Array:
	var lst := []
	for pl in core.players:
		lst.append({"seat": pl.seat, "name": pl.name, "rats": pl.rats, "teeth": pl.teeth, "deaths": pl.deaths, "alive": pl.alive,
			"death": pl.death, "stats": pl.stats.duplicate()})
	lst.sort_custom(func(a, b):
		if a.rats != b.rats:
			return a.rats > b.rats
		if a.teeth != b.teeth:
			return a.teeth > b.teeth
		if a.deaths != b.deaths:
			return a.deaths < b.deaths
		return a.seat < b.seat)
	var place := 1
	for i in lst.size():
		if i > 0 and (lst[i].rats != lst[i - 1].rats or lst[i].teeth != lst[i - 1].teeth or lst[i].deaths != lst[i - 1].deaths):
			place = i + 1
		lst[i].place = place
	return lst


func view() -> Array:
	if mode != "callers_game":
		return []
	var out := []
	for id in hidden:
		var d: Dictionary = data.objectives[id]
		out.append({"id": id, "name": d.name if revealed else "???", "desc": d.desc if revealed else "Revealed at round %d." % reveal_round()})
	return out


func to_save() -> Dictionary:
	return {"mode": mode, "hidden": hidden.duplicate(), "revealed": revealed}


func load_save(d: Dictionary) -> void:
	mode = str(d.get("mode", "classic"))
	hidden = d.get("hidden", []).duplicate()
	revealed = bool(d.get("revealed", false))
