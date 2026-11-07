class_name Items
extends RefCounted
## The item catalogue: data, not code paths. `use` says where an item can be used: on
## the board before you roll ("board"), in Russian Roulette ("roulette"), in the room
## ("room"), on someone else ("other": a ghost, for the Lazarus Rat). Effects live in
## BoardRules.use_item, the roulette encounter and RoomInteractionManager.

const CATALOGUE := {
	"first_aid": {"name": "FIRST AID TIN", "desc": "Clears bruises and burns and sets one broken bone.", "use": "board", "weight": 4},
	"painkillers": {"name": "PAINKILLERS", "desc": "For three rounds, injuries slow you less.", "use": "board", "weight": 3},
	"prosthetic": {"name": "PROSTHETIC", "desc": "A brass replacement for something you've lost.", "use": "board", "weight": 2},
	"surgery": {"name": "SURGERY KIT", "desc": "Mends every broken part and cuts out necrosis.", "use": "board", "weight": 1},
	"antidote": {"name": "ANTIDOTE", "desc": "Cures every poison.", "use": "board", "weight": 3},
	"helmet": {"name": "PARTY HELMET", "desc": "Wear it: the next thing that would kill you only maims you.", "use": "board", "weight": 2},
	"alibi": {"name": "ALIBI", "desc": "Someone else did it. Twenty off your suspicion.", "use": "board", "weight": 1},
	"lucky_foot": {"name": "RABBIT'S FOOT", "desc": "Loosens your Cage a notch.", "use": "board", "weight": 1},
	"loaded_die": {"name": "LOADED DIE", "desc": "Contraband. Your next roll is a six (if he doesn't see you swap it in).", "use": "board", "weight": 1, "cheat": true},
	"hairpin": {"name": "HAIRPIN", "desc": "Picks a lock. Away from the table.", "use": "room", "weight": 1},
	"lazarus_rat": {"name": "LAZARUS RAT", "desc": "Give it to a ghost: they come back.", "use": "other", "weight": 0},
	"spinner": {"name": "SPINNER", "desc": "Russian Roulette: spin the cylinder again.", "use": "roulette", "weight": 3},
	"peeker": {"name": "PEEKER", "desc": "Russian Roulette: look into the next chamber (only you see).", "use": "roulette", "weight": 3},
	"skip": {"name": "SKIP CARD", "desc": "Russian Roulette: pass your turn without pulling.", "use": "roulette", "weight": 2},
	"mirror": {"name": "HAND MIRROR", "desc": "Russian Roulette: your shot goes at someone else.", "use": "roulette", "weight": 1},
	"bribe": {"name": "ENVELOPE OF RATS", "desc": "Russian Roulette: pay someone to take your turn (if they'll take it).", "use": "roulette", "weight": 1},
	"bullet": {"name": "A SPARE ROUND", "desc": "Contraband. Russian Roulette: load another chamber.", "use": "roulette", "weight": 0, "cheat": true},
}

const MAX_HELD := 6


static func name_of(id: String) -> String:
	return CATALOGUE.get(id, {}).get("name", id.to_upper())


static func usable_on_board(id: String) -> bool:
	return CATALOGUE.get(id, {}).get("use", "") == "board"


## A random item. `worse` (the Cage tipping it) draws from the least useful end.
static func roll(rng: RandomNumberGenerator, pool := "any", worse := false) -> String:
	var total := 0
	var ids := []
	for k in CATALOGUE.keys():
		var w := int(CATALOGUE[k].weight)
		if w <= 0:
			continue
		if pool == "any" or CATALOGUE[k].use == pool:
			ids.append(k)
			total += w
	if worse:
		return ["hairpin", "skip", "painkillers"][rng.randi_range(0, 2)]
	var r := rng.randi_range(0, total - 1)
	for k in ids:
		r -= int(CATALOGUE[k].weight)
		if r < 0:
			return k
	return ids[0]
