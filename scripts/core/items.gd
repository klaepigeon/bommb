class_name Items
extends RefCounted
## The item catalogue: data, not code paths. `use` says where an item can be used: on
## the board before you roll, in a particular minigame, or automatically ("passive").
## Effects live in MatchCore.use_board_item and in the minigames that read them.

const CATALOGUE := {
	"first_aid": {"name": "FIRST AID TIN", "desc": "Clears bruises and burns and sets one broken bone.", "use": "board", "weight": 4},
	"painkillers": {"name": "PAINKILLERS", "desc": "For three rounds, injuries slow you less.", "use": "board", "weight": 3},
	"prosthetic": {"name": "PROSTHETIC", "desc": "A brass replacement for something you've lost.", "use": "board", "weight": 2},
	"helmet": {"name": "PARTY HELMET", "desc": "Wear it: the next thing that would kill you only maims you.", "use": "board", "weight": 2},
	"spinner": {"name": "SPINNER", "desc": "Popper Roulette: spin the cylinder again.", "use": "roulette", "weight": 3},
	"peeker": {"name": "PEEKER", "desc": "Popper Roulette: look into the next chamber (only you see).", "use": "roulette", "weight": 3},
	"skip": {"name": "SKIP CARD", "desc": "Popper Roulette: pass your turn without pulling.", "use": "roulette", "weight": 2},
	"mirror": {"name": "HAND MIRROR", "desc": "Popper Roulette: your pull goes off at someone else.", "use": "roulette", "weight": 1},
}

const MAX_HELD := 5


static func name_of(id: String) -> String:
	return CATALOGUE.get(id, {}).get("name", id.to_upper())


static func usable_on_board(id: String) -> bool:
	return CATALOGUE.get(id, {}).get("use", "") == "board"


static func roll(rng: RandomNumberGenerator, pool := "any") -> String:
	var total := 0
	var ids := []
	for k in CATALOGUE.keys():
		if pool == "any" or CATALOGUE[k].use == pool:
			ids.append(k)
			total += int(CATALOGUE[k].weight)
	var r := rng.randi_range(0, total - 1)
	for k in ids:
		r -= int(CATALOGUE[k].weight)
		if r < 0:
			return k
	return ids[0]
