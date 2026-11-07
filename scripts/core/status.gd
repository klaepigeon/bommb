class_name StatusEffectManager
extends RefCounted
## Poisons and other lasting effects (assets/data/poisons.json). They're carried by the
## player (PlayerState.statuses) from game to board and back, tick at the start of each of
## their board turns, and are read by whoever cares: the dice (paralytic, stimulant), the
## board's view (blindness, hallucinogen), injuries (blood thinner), minigame previews
## (memory loss). Some combine.

var core: MatchCore
var catalogue: Dictionary = {}


func _init(c: MatchCore) -> void:
	core = c
	catalogue = Assets.load_json("res://assets/data/poisons.json").get("poisons", {})


func harmful_ids() -> Array:
	return catalogue.keys().filter(func(k): return catalogue[k].get("harm", false))


func name_of(id: String) -> String:
	return str(catalogue.get(id, {}).get("name", id.to_upper()))


func apply(seat: int, id: String, why := "") -> void:
	var p := core.p(seat)
	if not catalogue.has(id) or not p.alive:
		return
	core.emit({"e": "status", "seat": seat, "id": id, "why": why})
	if id == "cure":
		core.toast("%s drank THE CURE. Nothing happens. It tasted of strawberries." % p.name)
		return
	for st in p.statuses:
		if st.id == id:
			st.turns = maxi(st.turns, int(catalogue[id].turns))
			return
	p.statuses.append({"id": id, "turns": int(catalogue[id].turns), "t": 0})
	core.toast("%s: %s. %s" % [p.name, name_of(id), str(catalogue[id].desc)], seat)


## A poison off the shelf, the Cage deciding whether it's a bad one.
func random_poison(seat: int) -> String:
	var ids: Array = catalogue.keys()
	if core.cage.tip(seat, "poison"):
		ids = harmful_ids()
	return ids[core.rng.randi_range(0, ids.size() - 1)]


func cure_all(seat: int) -> int:
	var p := core.p(seat)
	var n := p.statuses.size()
	p.statuses.clear()
	if n > 0:
		core.emit({"e": "status_clear", "seat": seat})
	return n


func cure(seat: int, id: String) -> void:
	var p := core.p(seat)
	p.statuses = p.statuses.filter(func(st): return st.id != id)


func has(seat: int, id: String) -> bool:
	return core.p(seat).has_status(id)


## The start of `seat`'s board turn: everything they're carrying does its thing.
func tick_turn(seat: int) -> void:
	var p := core.p(seat)
	if p.statuses.is_empty():
		return
	if has(seat, "rat_fever"):
		var lose := 1 + (2 if has(seat, "hunger") else 0)
		p.rats = maxi(0, p.rats - lose)
		core.toast("%s sweats out %d Dead Rat%s (rat fever)." % [p.name, lose, "" if lose == 1 else "s"])
	if has(seat, "hunger"):
		if p.rats > 0:
			p.rats -= 1
			core.toast("%s eats a Dead Rat (hunger)." % p.name)
		else:
			var part := Body.random_severable(p.body, core.rng)
			if part != "":
				core.injure(seat, part, "bruised", "hunger")
				core.toast("%s has nothing to eat, so bites themself." % p.name)
	for st in p.statuses:
		st.t += 1
		if st.id == "necrosis" and st.t % 2 == 0:
			var part := Body.random_severable(p.body, core.rng)
			if part != "":
				var cur: String = p.body[part].s
				var next := {"ok": "bruised", "bruised": "burned", "burned": "broken", "broken": "lost"}.get(cur, "")
				if next != "":
					core.injure(seat, part, next, "necrosis")
		st.turns -= 1
	p.statuses = p.statuses.filter(func(st): return st.turns > 0)


## How the dice are for them this turn: [max change, can't move at all].
func dice_mod(seat: int) -> Array:
	var p := core.p(seat)
	var delta := 0
	var stuck := false
	if has(seat, "paralytic"):
		stuck = core.rng.randf() < 0.35
		if has(seat, "necrosis"):
			delta -= 2
	if has(seat, "stimulant"):
		for st in p.statuses:
			if st.id == "stimulant":
				delta += 3 if st.t == 0 else -3
	return [delta, stuck]


## Blood thinner: everything bleeds more. An injury comes in one worse.
func worsen(seat: int, status: String) -> String:
	if not has(seat, "thinner"):
		return status
	return {"bruised": "burned", "burned": "broken"}.get(status, status)


func view_flags(seat: int) -> Dictionary:
	return {"blind": has(seat, "blindness"), "hallucinating": has(seat, "hallucinogen"),
		"unreliable": has(seat, "hallucinogen") and has(seat, "memory"), "memory": has(seat, "memory")}
