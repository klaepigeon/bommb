class_name MinigameRegistry
extends RefCounted
## Every minigame the game knows. To add one: write a Minigame subclass (rules; build on
## ArenaGame or ChoiceGame where it fits), give it a view (most use the shared arena or
## choice views), and add a line here. `min` is how many living players it needs.
##
## LAST CALL 3 v0.2: ten death games (five free-for-all, three team, two social), plus Hot
## Potato (the hidden cooperative one) in the rotation. Russian Roulette is not in the
## rotation: a board square calls it. Musical Chairs is retired (THE LAST SEAT replaced it)
## but still loads by id.

const WIN_RATS := 4

const GAMES := {
	"last_seat": {"script": "res://scripts/minigames/last_seat.gd", "view": "res://scripts/view/mg_arena_view.gd", "format": "ffa", "min": 2, "title": "THE LAST SEAT"},
	"meat_grinder": {"script": "res://scripts/minigames/meat_grinder.gd", "view": "res://scripts/view/mg_arena_view.gd", "format": "ffa", "min": 2, "title": "MEAT GRINDER"},
	"dead_weight": {"script": "res://scripts/minigames/dead_weight.gd", "view": "res://scripts/view/mg_arena_view.gd", "format": "ffa", "min": 2, "title": "DEAD WEIGHT"},
	"pick_your_poison": {"script": "res://scripts/minigames/pick_your_poison.gd", "view": "res://scripts/view/mg_choice_view.gd", "format": "ffa", "min": 2, "title": "PICK YOUR POISON"},
	"run_for_your_life": {"script": "res://scripts/minigames/run_for_your_life.gd", "view": "res://scripts/view/mg_arena_view.gd", "format": "ffa", "min": 2, "title": "RUN FOR YOUR LIFE"},
	"better_together": {"script": "res://scripts/minigames/better_together.gd", "view": "res://scripts/view/mg_arena_view.gd", "format": "2v2", "min": 4, "title": "BETTER TOGETHER"},
	"wrong_answers": {"script": "res://scripts/minigames/wrong_answers.gd", "view": "res://scripts/view/mg_choice_view.gd", "format": "1v3", "min": 3, "title": "WRONG ANSWERS ONLY"},
	"human_shield": {"script": "res://scripts/minigames/human_shield.gd", "view": "res://scripts/view/mg_arena_view.gd", "format": "2v2", "min": 4, "title": "HUMAN SHIELD"},
	"confession": {"script": "res://scripts/minigames/confession.gd", "view": "res://scripts/view/mg_choice_view.gd", "format": "ffa", "min": 3, "title": "CONFESSION"},
	"consensus": {"script": "res://scripts/minigames/consensus.gd", "view": "res://scripts/view/mg_choice_view.gd", "format": "ffa", "min": 2, "title": "THE CONSENSUS"},
	"hot_potato": {"script": "res://scripts/minigames/hot_potato.gd", "view": "res://scripts/view/mg_potato_view.gd", "format": "coop", "min": 2, "title": "HOT POTATO"},
	"roulette": {"script": "res://scripts/minigames/roulette.gd", "view": "res://scripts/view/mg_roulette_view.gd", "format": "special", "min": 2, "title": "RUSSIAN ROULETTE", "encounter": true},
	"musical_chairs": {"script": "res://scripts/minigames/musical_chairs.gd", "view": "res://scripts/view/mg_chairs_view.gd", "format": "ffa", "min": 2, "title": "MUSICAL CHAIRS", "retired": true},
}


static func schedule() -> Array:
	return GAMES.keys().filter(func(k): return not GAMES[k].get("retired", false) and not GAMES[k].get("encounter", false))


## What can be played with n living contestants.
static func eligible(n: int) -> Array:
	return schedule().filter(func(k): return n >= int(GAMES[k].get("min", 2)))


static func title_of(game_id: String) -> String:
	return str(GAMES.get(game_id, {}).get("title", game_id.to_upper()))


static func create(game_id: String, c: MatchCore, participants: Array[int], lvl: int) -> Minigame:
	var g: Minigame = load(GAMES[game_id].script).new()
	g.format = str(GAMES[game_id].get("format", "ffa"))
	g.init(c, participants, lvl)
	return g


static func view_script(game_id: String) -> Script:
	return load(GAMES[game_id].view)
