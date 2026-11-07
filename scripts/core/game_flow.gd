class_name GameFlow
extends RefCounted
## THE GAME-FLOW CONTROLLER: the one explicit state the match is in, the way a party board
## game runs. Every change goes through goto(); a change the table below doesn't allow is
## refused (and counted: the tests require zero). The turn loop, the round and the minigame
## presentation all report here, so the view, the HUD, the AI and the debug overlay read
## one thing: what phase are we in, how long has it been, and what is it waiting for.
##
##   ROUND_START -> TURN_ANNOUNCEMENT -> PLAYER_MOVEMENT -> LANDING_EVENT -> EVENT_RESOLUTION
##   -> TURN_END -> (next player: TURN_ANNOUNCEMENT ...) -> ROUND_END -> MINIGAME_SELECTION
##   -> MINIGAME_INTRO -> MINIGAME_INSTRUCTIONS -> MINIGAME_ARENA_INTRO -> MINIGAME_COUNTDOWN
##   -> MINIGAME_ACTIVE -> MINIGAME_RESULTS -> MINIGAME_RETURN -> (another game:
##   MINIGAME_SELECTION, or) ROUND_CONTINUE -> ROUND_START ... -> GAME_END
## Side states the board can step into and back out of: SEARCH (everyone searches the room),
## DOOR (the way out), and an encounter or special event is a minigame like any other.

const STATES := ["MATCH_INTRO", "ROUND_START", "TURN_ANNOUNCEMENT", "PLAYER_MOVEMENT", "LANDING_EVENT", "EVENT_RESOLUTION",
	"TURN_END", "ROUND_END", "MINIGAME_SELECTION", "MINIGAME_INTRO", "MINIGAME_INSTRUCTIONS", "MINIGAME_ARENA_INTRO",
	"MINIGAME_COUNTDOWN", "MINIGAME_ACTIVE", "MINIGAME_RESULTS", "MINIGAME_RETURN", "ROUND_CONTINUE", "SEARCH", "DOOR",
	"FINALE", "GAME_END"]

const ALLOWED := {
	"": ["MATCH_INTRO", "ROUND_START"],
	"MATCH_INTRO": ["ROUND_START", "GAME_END"],
	"ROUND_START": ["TURN_ANNOUNCEMENT", "ROUND_END", "GAME_END"],
	"TURN_ANNOUNCEMENT": ["PLAYER_MOVEMENT", "TURN_END", "GAME_END", "DOOR"],
	"PLAYER_MOVEMENT": ["LANDING_EVENT", "EVENT_RESOLUTION", "TURN_END", "GAME_END", "DOOR"],
	"LANDING_EVENT": ["EVENT_RESOLUTION", "TURN_END", "SEARCH", "GAME_END", "DOOR"],
	"EVENT_RESOLUTION": ["PLAYER_MOVEMENT", "TURN_END", "SEARCH", "GAME_END", "DOOR", "EVENT_RESOLUTION"],
	"SEARCH": ["TURN_END", "GAME_END"],
	"DOOR": ["TURN_END", "TURN_ANNOUNCEMENT", "ROUND_END", "GAME_END"],
	"TURN_END": ["TURN_ANNOUNCEMENT", "ROUND_END", "GAME_END"],
	"ROUND_END": ["MINIGAME_SELECTION", "ROUND_CONTINUE", "GAME_END"],
	"MINIGAME_SELECTION": ["MINIGAME_INTRO", "MINIGAME_SELECTION", "ROUND_CONTINUE", "GAME_END"],
	"MINIGAME_INTRO": ["MINIGAME_INSTRUCTIONS", "GAME_END"],
	"MINIGAME_INSTRUCTIONS": ["MINIGAME_ARENA_INTRO", "MINIGAME_SELECTION", "ROUND_CONTINUE", "GAME_END"],
	"MINIGAME_ARENA_INTRO": ["MINIGAME_COUNTDOWN", "MINIGAME_SELECTION", "ROUND_CONTINUE", "GAME_END"],
	"MINIGAME_COUNTDOWN": ["MINIGAME_ACTIVE", "GAME_END"],
	"MINIGAME_ACTIVE": ["MINIGAME_RESULTS", "GAME_END"],
	"MINIGAME_RESULTS": ["MINIGAME_RETURN", "GAME_END"],
	"MINIGAME_RETURN": ["MINIGAME_SELECTION", "ROUND_CONTINUE", "GAME_END"],
	"ROUND_CONTINUE": ["ROUND_START", "FINALE", "GAME_END"],
	"FINALE": ["GAME_END"],
	"GAME_END": [],
}

var state := ""
var t := 0.0
var history: Array = []        # [state, ...] (the last 200)
var invalid: Array = []        # refused changes: [from, to]
var waiting_on := ""           # what's holding it up, for the debug overlay
var report := true             # push_error on a refused change (tests that poke internals turn it off)


## Change state. Returns false (and changes nothing) if that isn't a legal next state.
func goto(to: String) -> bool:
	if not STATES.has(to):
		invalid.append([state, to])
		if report:
			push_error("GameFlow: unknown state " + to)
		return false
	if to != state and not (ALLOWED.get(state, []) as Array).has(to):
		invalid.append([state, to])
		if report:
			push_error("GameFlow: %s -> %s is not allowed" % [state, to])
		return false
	if to == state:
		return true
	state = to
	t = 0.0
	waiting_on = ""
	history.append(to)
	if history.size() > 200:
		history.pop_front()
	return true


func tick(dt: float) -> void:
	t += dt


func is_board() -> bool:
	return state in ["TURN_ANNOUNCEMENT", "PLAYER_MOVEMENT", "LANDING_EVENT", "EVENT_RESOLUTION", "TURN_END"]


## The board is frozen: no board logic, no board input (minigames, the round's end, the finale).
func board_frozen() -> bool:
	return state.begins_with("MINIGAME") or state in ["ROUND_END", "ROUND_CONTINUE", "FINALE", "GAME_END", "MATCH_INTRO"]


func view() -> Dictionary:
	return {"state": state, "t": t, "waiting_on": waiting_on, "invalid": invalid.size()}
