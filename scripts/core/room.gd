class_name RoomInteractionManager
extends RefCounted
## Leaving the table. On your turn, instead of rolling, you can get up: two actions out
## in the hall (assets/data/room.json: the coat rack, the kitchen, the cellar door, his
## booth, the piñata, the props cupboard, the fuse box, and somewhere that isn't on the
## list until you've looked around), then you sit back down. Everything out there is a
## risk: getting up is suspicious, and anything he sees you do is worse. What you get is
## what the board can't give you: contraband, medicine, his files, a looser Cage, rigged
## equipment, a look at what's coming.

var core: MatchCore
var hotspots: Dictionary = {}
var pools: Dictionary = {}
var leave_suspicion := 4
var actions_per_visit := 2
var unlocked: Dictionary = {}       # "cellar", "hatch"
var used_once: Dictionary = {}      # action id -> true
var visits: Dictionary = {}         # seat -> distinct hotspots looked at
var spiked := false                 # the punch (everyone else drinks it at the next round)
var spiker := -1


func _init(c: MatchCore) -> void:
	core = c
	var d := Assets.load_json("res://assets/data/room.json")
	hotspots = d.get("hotspots", {})
	pools = d.get("pools", {})
	leave_suspicion = int(d.get("leave_suspicion", 4))
	actions_per_visit = int(d.get("actions_per_visit", 2))


## Hotspots this player knows about (the hidden one turns up once you've had a look round).
func known_hotspots(seat: int) -> Array:
	var out := []
	for id in hotspots.keys():
		if hotspots[id].get("hidden", false) and (visits.get(seat, {}) as Dictionary).size() < 3 and not unlocked.has("hatch"):
			continue
		out.append(id)
	return out


func leave(seat: int) -> void:
	var p := core.p(seat)
	p.location = "up"
	p.room_actions = actions_per_visit
	var amount := leave_suspicion * (2 if core.suspicion.watching else 1)
	core.suspicion.add(seat, amount, "left the table")
	core.emit({"e": "leave", "seat": seat})
	core.say("leave_table", {"name": p.name})


func go(seat: int, where: String) -> void:
	var p := core.p(seat)
	if not hotspots.has(where) or not known_hotspots(seat).has(where):
		return
	p.location = where
	if not visits.has(seat):
		visits[seat] = {}
	visits[seat][where] = true
	core.emit({"e": "go", "seat": seat, "where": where, "pos": hotspots[where].pos})


func actions_at(seat: int) -> Array:
	var p := core.p(seat)
	if not hotspots.has(p.location):
		return []
	var out := []
	for a in hotspots[p.location].actions:
		if a.get("once", false) and used_once.has(a.id):
			continue
		if a.has("needs_unlocked") and not unlocked.has(a.needs_unlocked):
			continue
		out.append(a)
	return out


func act(seat: int, action_id: String, target := -1) -> void:
	var p := core.p(seat)
	var a: Dictionary = {}
	for x in actions_at(seat):
		if x.id == action_id:
			a = x
	if a.is_empty() or p.room_actions <= 0:
		return
	if a.has("needs") and not p.items.has(a.needs):
		core.toast("You need a %s for that." % Items.name_of(a.needs).to_lower(), seat)
		return
	p.room_actions -= 1
	if a.get("once", false):
		used_once[a.id] = true
	if core.suspicion.sees(seat):
		core.emit({"e": "caught", "seat": seat, "cheat": a.id, "what": a.name})
		core.say("caught_room", {"name": p.name})
		core.toast("CAUGHT: %s, at %s." % [p.name, str(hotspots[p.location].name).to_lower()])
		core.suspicion.add(seat, int(a.get("caught", 15)), "caught: " + a.id)
		core.economy.take(seat, 2, "fined")
		sit(seat, true)
		return
	core.suspicion.add(seat, int(a.get("ok", 4)), a.id)
	_effect(seat, a, target)
	if p.room_actions <= 0 and p.location != "table":
		sit(seat, false)


func sit(seat: int, forced: bool) -> void:
	var p := core.p(seat)
	if p.location == "table":
		return
	p.location = "table"
	p.room_actions = 0
	core.emit({"e": "sit", "seat": seat, "forced": forced})
	if forced:
		core.say("forced_sit", {"name": p.name})
	core.rules.room_done(seat)


func _effect(seat: int, a: Dictionary, target: int) -> void:
	var p := core.p(seat)
	match str(a.effect):
		"find":
			_find(seat, str(a.pool))
		"rob":
			var opts := core.living().filter(func(o): return o != seat)
			if target < 0 or not opts.has(target):
				target = opts[core.rng.randi_range(0, opts.size() - 1)] if not opts.is_empty() else -1
			if target < 0:
				return
			var t := core.p(target)
			if not t.items.is_empty() and p.items.size() < Items.MAX_HELD:
				var it: String = t.items.pop_at(core.rng.randi_range(0, t.items.size() - 1))
				p.items.append(it)
				core.toast("In %s's coat: a %s. It's yours now." % [t.name, Items.name_of(it)], seat)
			else:
				var n := core.economy.take(target, 3, "robbed")
				p.rats += n
				core.toast("%d Dead Rats out of %s's coat." % [n, t.name], seat)
			core.brains[target].wronged_by(seat, 0.1)
		"spike":
			spiked = true
			spiker = seat
			core.toast("You tip a little bottle into the punch.", seat)
		"unlock":
			unlocked["cellar"] = true
			p.items.erase("hairpin")
			core.toast("The cellar lock gives. It smells of rats down there. A lot of rats.", seat)
		"nest":
			if core.cage.tip(seat, "environment"):
				core.injure(seat, "hand_r", "broken", "rat bite")
				core.status.apply(seat, "rat_fever", "rat bite")
				core.toast("Something in the nest is still alive.", seat)
			else:
				var n := core.economy.award(seat, 4, "the nest")
				core.toast("You pull %d Dead Rats out of the nest." % n, seat)
		"read_file":
			var file := {}
			for o in core.players:
				file[o.seat] = {"suspicion": o.suspicion, "cage": o.cage}
			p.known["file"] = file
			core.toast("His files. Everyone's in here. He's very thorough.", seat)
		"doctor_file":
			core.suspicion.add(seat, -18, "doctored the file")
			core.toast("You rub out a page of yourself.", seat)
		"loosen_cage":
			core.cage.loosen(seat, "tampered")
			core.toast("A notch on your Cage, eased. He'll notice. Eventually.", seat)
		"pinata":
			if core.cage.tip(seat, "environment"):
				core.injure(seat, "hand_l", "burned", "pinata")
				core.status.apply(seat, "rat_fever", "pinata")
				core.toast("It splits. What comes out isn't sweets.", seat)
			else:
				match core.rng.randi_range(0, 2):
					0:
						core.economy.award(seat, 3, "pinata")
						core.toast("Dead Rats rain out of it.", seat)
					1:
						core.give_item(seat, Items.roll(core.rng), "pinata")
					2:
						core.give_item(seat, "painkillers", "pinata")
		"tamper":
			var nxt := core.next_minigame()
			p.tamper[nxt] = true
			core.toast("You fix something in the box for %s. It'll go your way." % MinigameRegistry.title_of(nxt), seat)
		"look_ahead":
			var nxt := core.next_minigame()
			p.known["next_game"] = nxt
			core.toast("Set out for later: %s." % MinigameRegistry.title_of(nxt), seat)
		"distract":
			core.suspicion.distract(8.0)
			core.toast("The lights go. He looks up at them.", seat)
		"reveal_hatch":
			unlocked["hatch"] = true
			core.toast("A catch. A hatch under the stage swings in. There's a room under there.", seat)


func _find(seat: int, pool: String) -> void:
	var entries: Array = pools.get(pool, [])
	if entries.is_empty():
		return
	var pick: String = ""
	if core.cage.tip(seat, "environment"):
		pick = "nothing" if core.rng.randf() < 0.6 else "bite"
	else:
		var total := 0
		for e in entries:
			total += int(e[1])
		var r := core.rng.randi_range(0, total - 1)
		for e in entries:
			r -= int(e[1])
			if r < 0:
				pick = str(e[0])
				break
	var p := core.p(seat)
	match pick:
		"nothing":
			core.toast("Nothing. Lint. A ticket stub from last year.", seat)
		"rats":
			core.economy.award(seat, 2, "found")
			core.toast("Two Dead Rats, stiff, in a pocket.", seat)
		"rats_big":
			core.economy.award(seat, 5, "found")
			core.toast("A whole crate of Dead Rats.", seat)
		"bite":
			core.injure(seat, "hand_l", "bruised", "something bit")
			core.toast("Something in there bites.", seat)
		"poison":
			var id := core.status.random_poison(seat)
			core.status.apply(seat, id, "tasted something")
		_:
			if Items.CATALOGUE.has(pick):
				core.give_item(seat, pick, "found")
				core.toast("You find a %s." % Items.name_of(pick), seat)


func view_for(seat: int) -> Dictionary:
	var hs := {}
	for id in known_hotspots(seat):
		hs[id] = {"name": hotspots[id].name, "pos": hotspots[id].pos}
	var acts := []
	for a in actions_at(seat):
		acts.append({"id": a.id, "name": a.name, "target": a.get("target", false), "needs": a.get("needs", "")})
	return {"hotspots": hs, "actions": acts, "unlocked": unlocked.keys()}
