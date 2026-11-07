class_name MinigamePresenter
extends RefCounted
## THE MINIGAME PRESENTATION CONTROLLER. Every minigame, whatever it is, is presented by
## this, in this order; none can skip a stage (a game only supplies its registration:
## title, category, description, instructions, controls, arena, its own timings):
##
##   1 board_freeze    the board stops: no board logic, no board input
##   2 selection       "MINIGAME!" + the category (free-for-all, 2v2, 1v3, duel, special...)
##   3 title           the game's title and description
##   4 arena_preview   a look at its arena
##   5 teams           who's playing, which side
##   6 instructions    HOW TO PLAY (mandatory: a minimum read time; everyone presses NEXT)
##   7 controls        the controls as bound on your device, PRACTICE, READY (everyone)
##   8 arena_intro     into the arena (players who aren't here forfeit now)
##   9 positioning     the puppets take their places
##  10 countdown       3, 2, 1, GO
##  11 play            the game itself
##  12 play_freeze     it stops
##  13 results         who won, how everyone did
##  14 rewards         Teeth, the pot, prizes, consequences, applied now
##  15 return          back to the board
##
## Timings come from Pacing (a game may override some, never remove a stage). A stage that
## waits for people or for the game treats its time as a minimum. AI players "read" for the
## minimum time and then acknowledge. With debug stepping on, nothing advances until
## someone sends {"t": "flow_next"}.

const STAGES := ["board_freeze", "selection", "title", "arena_preview", "teams", "instructions", "controls",
	"arena_intro", "positioning", "countdown", "play", "play_freeze", "results", "rewards", "return"]
const FLOW := {
	"board_freeze": "MINIGAME_SELECTION", "selection": "MINIGAME_SELECTION",
	"title": "MINIGAME_INTRO", "arena_preview": "MINIGAME_INTRO", "teams": "MINIGAME_INTRO",
	"instructions": "MINIGAME_INSTRUCTIONS", "controls": "MINIGAME_INSTRUCTIONS",
	"arena_intro": "MINIGAME_ARENA_INTRO", "positioning": "MINIGAME_ARENA_INTRO",
	"countdown": "MINIGAME_COUNTDOWN", "play": "MINIGAME_ACTIVE",
	"play_freeze": "MINIGAME_RESULTS", "results": "MINIGAME_RESULTS", "rewards": "MINIGAME_RESULTS",
	"return": "MINIGAME_RETURN"}
const PACE := {
	"board_freeze": "mg_freeze", "selection": "mg_select", "title": "mg_title", "arena_preview": "mg_arena_preview",
	"teams": "mg_teams", "instructions": "mg_instructions", "controls": "mg_instructions", "arena_intro": "mg_arena_intro",
	"positioning": "mg_positioning", "countdown": "mg_countdown", "play_freeze": "mg_play_freeze",
	"results": "mg_results", "rewards": "mg_rewards", "return": "mg_return"}
## The stages where every person at the table confirms (AI: after reading).
const CONFIRM := {"instructions": "next", "controls": "ready"}

var core: MatchCore
var stage := ""
var t := 0.0
var active := false
var visited: Array = []           # stages this game went through (the tests read it)
var confirmed: Dictionary = {}    # seat -> true, for the current confirm stage
var debug_step := false
var _step_ok := false


func _init(c: MatchCore) -> void:
	core = c


func begin() -> void:
	active = true
	visited = []
	_enter("board_freeze")


func _enter(s: String) -> void:
	stage = s
	t = 0.0
	confirmed = {}
	_step_ok = false
	visited.append(s)
	core.flow.goto(FLOW[s])
	core.emit({"e": "mg_stage", "stage": s, "id": core.mg_id})
	# what each stage does to the match
	match s:
		"board_freeze":
			core.phase_to("mg_intro")
		"arena_intro":
			if not core.mg_register():
				return     # cancelled: the core has moved on
		"play":
			core.phase_to("mg_play")
			core.mg.start()
		"play_freeze":
			core.phase_to("mg_results")
		"results":
			core.mg_results()
		"rewards":
			core.mg_rewards()
		"return":
			core.phase_to("mg_return")


func duration() -> float:
	if not PACE.has(stage):
		return 0.0
	return core.pace(PACE[stage])


## Who still has to confirm this stage (people only; AI reads, then confirms by itself).
func waiting_for() -> Array:
	if not CONFIRM.has(stage):
		return []
	var out: Array = []
	for s in core.mg.seats if core.mg else []:
		var pl := core.p(s)
		if not core.is_ai(s) and pl.alive and not confirmed.has(s):
			out.append(s)
	# ghosts watch too, but nobody waits for them
	return out


func confirm(seat: int, what: String) -> void:
	if CONFIRM.get(stage, "") == what:
		confirmed[seat] = true


func tick(dt: float) -> void:
	if not active or core.ending != "":
		return
	t += dt
	var done := false
	match stage:
		"play":
			done = core.mg != null and core.mg.done
			core.flow.waiting_on = "the game to finish"
		"instructions", "controls":
			var min_t := duration()
			var wf := waiting_for()
			var max_t := core.pace("mg_instructions_max")
			done = (t >= min_t and wf.is_empty()) or t >= max_t
			if not done:
				core.flow.waiting_on = "reading time (%.0fs)" % maxf(0.0, min_t - t) if t < min_t else \
					"%s from %s" % ["NEXT" if stage == "instructions" else "READY", ", ".join(wf.map(func(s): return core.p(s).name))]
		_:
			done = t >= duration()
			core.flow.waiting_on = "%s (%.1fs)" % [stage, maxf(0.0, duration() - t)]
	if done and debug_step and not _step_ok:
		core.flow.waiting_on = "DEBUG STEP: send flow_next to leave '%s'" % stage
		return
	if done:
		_advance()


func step() -> void:
	_step_ok = true


func _advance() -> void:
	var i := STAGES.find(stage)
	if stage == "return":
		active = false
		stage = ""
		core.mg_finished()
		return
	_enter(STAGES[i + 1])


## A game that can't go ahead (not enough of you at the table): drop it.
func cancel() -> void:
	active = false
	stage = ""


func view() -> Dictionary:
	return {"stage": stage, "t": t, "length": duration(), "waiting": waiting_for(), "confirmed": confirmed.keys(),
		"index": STAGES.find(stage), "count": STAGES.size(), "debug_step": debug_step}
