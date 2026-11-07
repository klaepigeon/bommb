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


# --- REGISTRATION AND VALIDATION ------------------------------------------------------------
## Everything the presentation controller needs about a game, in one standard shape. It's
## assembled from GAMES (id, title, format, players, view, presentation), the game's own class
## (instructions, controls, gameplay, completion, results), ArenaWorld (its arena), MatchCore's
## payouts (rewards) and assets/data/minigames.json (description, special animations, timing
## overrides). validate() says what's missing; an incomplete game is never put in front of
## people (it's left out of the rotation and flagged).

const CATEGORY := {"ffa": "FREE-FOR-ALL", "2v2": "2 VS 2", "1v3": "1 VS 3", "duel": "DUEL", "coop": "CO-OP", "special": "ENCOUNTER"}
const CONTROL_KINDS := ["stick", "tap", "hold", "swipe", "timing", "trace", "pick"]
const REWARDS := {"ffa": "ffa", "2v2": "2v2", "1v3": "1v3_solo", "duel": "duel", "coop": "coop", "special": "special"}
const ARENAS := ["factory", "kitchen", "stage", "aquarium", "impossible", "clown", "carnival", "speedway", "hospital", "locker"]

static var _meta: Dictionary = {}
static var _checked: Dictionary = {}


static func meta(game_id: String) -> Dictionary:
	if _meta.is_empty():
		var f := FileAccess.get_file_as_string("res://assets/data/minigames.json")
		var j = JSON.parse_string(f) if f != "" else null
		_meta = j.get("games", {}) if j is Dictionary else {}
	return _meta.get(game_id, {})


static func category_of(game_id: String) -> String:
	var g: Dictionary = GAMES.get(game_id, {})
	if g.get("special", false):
		return "SPECIAL EVENT"
	return str(CATEGORY.get(str(g.get("format", "ffa")), "MINIGAME"))


static func arena_of(game_id: String) -> String:
	if game_id == "roulette":
		return "table"      # Russian Roulette is played on the board's own table
	return str(ArenaWorld.THEMES.get(game_id, ""))


## The registration. `mg` (an instance, for its instructions and controls) is optional.
static func registration(game_id: String, mg: Minigame = null) -> Dictionary:
	var g: Dictionary = GAMES.get(game_id, {})
	var m := meta(game_id)
	var instr: Array = mg.instructions() if mg else []
	var ctl: Array = mg.controls(mg.seats[0] if mg and not mg.seats.is_empty() else 0) if mg else []
	var fmt := str(g.get("format", ""))
	return {
		"id": game_id, "name": str(g.get("title", "")), "category": category_of(game_id), "format": fmt,
		"description": str(m.get("description", "")),
		"players": {"min": int(g.get("min", 2)), "max": int(g.get("max", 4))},
		"teams": fmt, "arena": arena_of(game_id), "instructions": instr,
		"controls": ["buttons"] if mg and mg.buttons_only() else ctl.map(func(c): return str(c.get("kind", ""))),
		"touch": ctl.map(func(c): return {"kind": str(c.get("kind", "")), "do": str(c.get("do", "")), "label": str(c.get("label", ""))}),
		"script": str(g.get("script", "")), "view": str(g.get("view", "")),
		"rewards": str(REWARDS.get(fmt, "")), "anims": m.get("anims", []), "pacing": m.get("pacing", {}),
		"presentation": presentation(game_id),
	}


## What's wrong with a game's registration ([] = complete). Needs an instance for the
## instructions and controls checks (MatchCore makes one); cached per game once it passes.
static func validate(game_id: String, mg: Minigame = null) -> Array:
	if _checked.has(game_id) and mg == null:
		return _checked[game_id]
	var r := registration(game_id, mg)
	var bad: Array = []
	if not GAMES.has(game_id):
		return ["not registered"]
	if r.name == "":
		bad.append("no display name")
	if r.description == "":
		bad.append("no description (assets/data/minigames.json)")
	if not CATEGORY.has(r.format):
		bad.append("unknown format/category '%s'" % r.format)
	if int(r.players.min) < 1 or int(r.players.max) < int(r.players.min) or int(r.players.max) > 4:
		bad.append("bad player counts %s" % str(r.players))
	if r.format == "2v2" and int(r.players.min) != 4:
		bad.append("2v2 needs exactly four")
	if r.format == "duel" and int(r.players.max) != 2:
		bad.append("a duel is two players")
	if r.arena == "" or not (r.arena in ARENAS or r.arena == "table"):
		bad.append("no arena (ArenaWorld.THEMES)")
	if not ResourceLoader.exists(r.script):
		bad.append("gameplay script missing")
	if not ResourceLoader.exists(r.view):
		bad.append("view script missing")
	if (r.anims as Array).is_empty():
		bad.append("no special animation references")
	if r.rewards == "":
		bad.append("no reward configuration")
	if mg:
		if (r.instructions as Array).is_empty():
			bad.append("no instructions")
		for line in r.instructions:
			if str(line).strip_edges() == "":
				bad.append("an empty instruction line")
		for c in r.touch:
			if not str(c.kind) in CONTROL_KINDS:
				bad.append("unknown control kind '%s'" % c.kind)
			elif c.kind != "stick" and c.kind != "pick" and str(c.do) == "":
				bad.append("a %s control with no action" % c.kind)
		if (r.controls as Array).is_empty():
			bad.append("no controls (declare controls() or buttons_only())")
		if mg.buttons_only() and not (ctl_kinds_ok(r.touch)):
			bad.append("buttons-only but declares pads")
		for fn in ["start", "tick", "action", "placings", "summary", "ai"]:
			if not mg.has_method(fn):
				bad.append("missing %s()" % fn)
	if mg:
		_checked[game_id] = bad
	return bad


static func ctl_kinds_ok(touch: Array) -> bool:
	return touch.is_empty()
