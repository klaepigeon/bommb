class_name MinigameRegistry
extends RefCounted
## Every minigame the game knows. To add one: write a Minigame subclass (rules) and a
## view (scripts/view/mg_<id>_view.gd), then add a line here. `rotation` is the order
## they come round in a match; anything registered but not in it can still be loaded by id.
##
## Design target is ten games: four conventional competitive, three escalating survival,
## two psychological/social, one hidden cooperative. The vertical slice has three.

const GAMES := {
	"musical_chairs": {"script": "res://scripts/minigames/musical_chairs.gd", "view": "res://scripts/view/mg_chairs_view.gd",
		"category": "survival", "style": ["timed", "persistent", "escalating", "elimination"]},
	"roulette": {"script": "res://scripts/minigames/roulette.gd", "view": "res://scripts/view/mg_roulette_view.gd",
		"category": "psychological", "style": ["turn_based", "elimination", "items"]},
	"hot_potato": {"script": "res://scripts/minigames/hot_potato.gd", "view": "res://scripts/view/mg_potato_view.gd",
		"category": "hidden_cooperative", "style": ["timed", "elimination", "cooperative"]},
}

const ROTATION := ["musical_chairs", "roulette", "hot_potato"]


static func schedule() -> Array:
	return ROTATION.filter(func(k): return GAMES.has(k))


static func create(game_id: String, c: MatchCore, participants: Array[int], lvl: int) -> Minigame:
	var g: Minigame = load(GAMES[game_id].script).new()
	g.init(c, participants, lvl)
	return g


static func view_script(game_id: String) -> Script:
	return load(GAMES[game_id].view)
