class_name MinigameRegistry
extends RefCounted
## Every minigame the game knows. To add one: write a Minigame subclass (rules; build on
## ArenaGame or ChoiceGame where it fits; declare its controls()), give it a view, and
## add a line here. Nothing else changes: selection, payouts, registration and results
## are MatchCore's and read this table.
##   format: ffa | 2v2 | 1v3 | duel | coop | special
##   min / max: living players it supports
##   core: one of the ten LAST CALL 3 v0.2.5 games (picked more often); the rest are the
##     extra catalogue from v0.2, still in the rotation.
##   encounter: only a board square calls it (Russian Roulette). retired: loads by id only.
##   presentation: MEAT_PUPPET (the default: every ordinary game) | FULL_CHARACTER | CINEMATIC | CUSTOM.

const GAMES := {
	# --- the ten -----------------------------------------------------------------------
	"meat_grinder": {"script": "res://scripts/minigames/meat_grinder.gd", "view": "res://scripts/view/mg_arena_view.gd", "format": "ffa", "min": 2, "core": true, "title": "MEAT GRINDER"},
	"floor_is_meat": {"script": "res://scripts/minigames/floor_is_meat.gd", "view": "res://scripts/view/mg_arena_view.gd", "format": "ffa", "min": 2, "core": true, "title": "FLOOR IS MEAT"},
	"last_seat": {"script": "res://scripts/minigames/last_seat.gd", "view": "res://scripts/view/mg_arena_view.gd", "format": "ffa", "min": 2, "core": true, "title": "THE LAST SEAT"},
	"hook_line_sinker": {"script": "res://scripts/minigames/hook_line_sinker.gd", "view": "res://scripts/view/mg_hook_view.gd", "format": "ffa", "min": 2, "core": true, "title": "HOOK, LINE AND SINKER"},
	"spin_cycle": {"script": "res://scripts/minigames/spin_cycle.gd", "view": "res://scripts/view/mg_spin_view.gd", "format": "ffa", "min": 2, "core": true, "title": "SPIN CYCLE"},
	"better_together": {"script": "res://scripts/minigames/better_together.gd", "view": "res://scripts/view/mg_arena_view.gd", "format": "2v2", "min": 4, "max": 4, "core": true, "title": "BETTER TOGETHER"},
	"tug_of_war": {"script": "res://scripts/minigames/tug_of_war.gd", "view": "res://scripts/view/mg_tug_view.gd", "format": "2v2", "min": 4, "max": 4, "core": true, "title": "TUG OF WAR"},
	"the_controller": {"script": "res://scripts/minigames/the_controller.gd", "view": "res://scripts/view/mg_arena_view.gd", "format": "1v3", "min": 3, "max": 4, "core": true, "title": "THE CONTROLLER"},
	"last_man_breathing": {"script": "res://scripts/minigames/last_man_breathing.gd", "view": "res://scripts/view/mg_breath_view.gd", "format": "duel", "min": 2, "max": 2, "core": true, "title": "LAST MAN BREATHING"},
	"dont_press_it": {"script": "res://scripts/minigames/dont_press_it.gd", "view": "res://scripts/view/mg_bomb_view.gd", "format": "coop", "min": 2, "core": true, "title": "DON'T PRESS IT"},
	# --- the extra catalogue (v0.2) -------------------------------------------------------
	"dead_weight": {"script": "res://scripts/minigames/dead_weight.gd", "view": "res://scripts/view/mg_arena_view.gd", "format": "ffa", "min": 2, "title": "DEAD WEIGHT"},
	"pick_your_poison": {"script": "res://scripts/minigames/pick_your_poison.gd", "view": "res://scripts/view/mg_choice_view.gd", "format": "ffa", "min": 2, "title": "PICK YOUR POISON"},
	"run_for_your_life": {"script": "res://scripts/minigames/run_for_your_life.gd", "view": "res://scripts/view/mg_arena_view.gd", "format": "ffa", "min": 2, "title": "RUN FOR YOUR LIFE"},
	"wrong_answers": {"script": "res://scripts/minigames/wrong_answers.gd", "view": "res://scripts/view/mg_choice_view.gd", "format": "1v3", "min": 3, "title": "WRONG ANSWERS ONLY"},
	"human_shield": {"script": "res://scripts/minigames/human_shield.gd", "view": "res://scripts/view/mg_arena_view.gd", "format": "2v2", "min": 4, "max": 4, "title": "HUMAN SHIELD"},
	"confession": {"script": "res://scripts/minigames/confession.gd", "view": "res://scripts/view/mg_choice_view.gd", "format": "ffa", "min": 3, "title": "CONFESSION"},
	"consensus": {"script": "res://scripts/minigames/consensus.gd", "view": "res://scripts/view/mg_choice_view.gd", "format": "ffa", "min": 2, "title": "THE CONSENSUS"},
	"hot_potato": {"script": "res://scripts/minigames/hot_potato.gd", "view": "res://scripts/view/mg_potato_view.gd", "format": "coop", "min": 2, "title": "HOT POTATO"},
	# --- special events (never in the rotation; a square, an event or the Caller calls them) ---
	"organ_trail": {"script": "res://scripts/minigames/organ_trail.gd", "view": "res://scripts/view/mg_organ_view.gd", "format": "2v2", "min": 4, "max": 4, "title": "ORGAN TRAIL", "encounter": true, "special": true, "presentation": "FULL_CHARACTER"},
	# --- encounters, retired ----------------------------------------------------------------
	"roulette": {"script": "res://scripts/minigames/roulette.gd", "view": "res://scripts/view/mg_roulette_view.gd", "format": "special", "min": 2, "title": "RUSSIAN ROULETTE", "encounter": true},
	"musical_chairs": {"script": "res://scripts/minigames/musical_chairs.gd", "view": "res://scripts/view/mg_chairs_view.gd", "format": "ffa", "min": 2, "title": "MUSICAL CHAIRS", "retired": true},
}

const CORE_TEN := ["meat_grinder", "floor_is_meat", "last_seat", "hook_line_sinker", "spin_cycle", "better_together", "tug_of_war",
	"the_controller", "last_man_breathing", "dont_press_it"]


static func schedule() -> Array:
	return GAMES.keys().filter(func(k): return not GAMES[k].get("retired", false) and not GAMES[k].get("encounter", false))


static func fits(game_id: String, n: int) -> bool:
	var g: Dictionary = GAMES.get(game_id, {})
	return not g.is_empty() and n >= int(g.get("min", 2)) and n <= int(g.get("max", 4))


## What can be played with n players (of a format, if asked: "duel" means a two-player game).
static func eligible(n: int, fmt := "") -> Array:
	return schedule().filter(func(k):
		if not fits(k, n):
			return false
		if fmt == "duel":
			return GAMES[k].format == "duel"
		if fmt == "ffa":
			return GAMES[k].format == "ffa"
		# the round's main game is never a duel unless there are only two of you
		return GAMES[k].format != "duel" or n == 2)


## How a game is shown: every ordinary minigame is played by the meat puppets; special
## events say otherwise (declared here, never guessed from the category).
static func presentation(game_id: String) -> String:
	return str(GAMES.get(game_id, {}).get("presentation", "MEAT_PUPPET"))


static func title_of(game_id: String) -> String:
	return str(GAMES.get(game_id, {}).get("title", game_id.to_upper()))


static func create(game_id: String, c: MatchCore, participants: Array[int], lvl: int) -> Minigame:
	var g: Minigame = load(GAMES[game_id].script).new()
	g.format = str(GAMES[game_id].get("format", "ffa"))
	g.init(c, participants, lvl)
	return g


static func view_script(game_id: String) -> Script:
	return load(GAMES[game_id].view)
