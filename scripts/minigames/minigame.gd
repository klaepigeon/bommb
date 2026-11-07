class_name Minigame
extends RefCounted
## The base every minigame shares. A minigame is host-side rules only: it gets the
## contestants still alive, a difficulty level (how many times it has come round), and
## the MatchCore to report through (kill, injure, say, emit). Drawing it is a separate
## view scene (scripts/view/), chosen by id; AI plays it through the same action() a
## human's input arrives through, reading the same view_for() a human's screen gets.
##
## Life cycle: setup() (on creation) -> start() (after the instructions card) ->
## tick(dt) until done -> rats and summary() are read by MatchCore.

var core: MatchCore
var seats: Array[int] = []
var level := 0
var t := 0.0
var done := false
var rats: Dictionary = {}       # seat -> rats won (or lost) in this game
var rng := RandomNumberGenerator.new()
var notes: Array[String] = []      # what happened, for the results screen
## v0.2: the format, the teams in it, and how it came out. A free-for-all that ends in a
## draw (draw = true) makes MatchCore run the Collective Sacrifice.
var format := "ffa"                # ffa | 2v2 | 1v3 | coop | special
var teams: Array = []              # [[seats], [seats]] for team games
var winners: Array[int] = []
var draw := false


func init(c: MatchCore, participants: Array[int], lvl: int) -> void:
	core = c
	seats = participants.duplicate()
	level = lvl
	rng.seed = c.rng.randi()
	for s in seats:
		rats[s] = 0
	setup()


## Override these.
func id() -> String:
	return "base"


func title() -> String:
	return "A GAME"


func instructions() -> Array:
	return []


func setup() -> void:
	pass


func start() -> void:
	pass


func tick(dt: float) -> void:
	t += dt


func action(_seat: int, _a: Dictionary) -> void:
	pass


func view_for(_viewers: Array) -> Dictionary:
	return {}


## AI: choose and send actions for `seat` (via action()), from `view` only.
func ai(_seat: int, _brain: AiBrain, _view: Dictionary, _dt: float) -> void:
	pass


func summary() -> Array:
	return notes.duplicate()


## End it: who won, or that nobody did (or everybody did) and it's a draw.
func finish(win: Array, is_draw := false) -> void:
	winners.clear()
	for s in win:
		winners.append(int(s))
	draw = is_draw
	done = true
	if is_draw:
		notes.append("A DRAW.")


## What each seat can do right now, for the HUD and the AI alike: [{do, name, target?}].
## Joystick movement isn't listed (arena games take {"move": Vector2}).
func actions_for(_seat: int) -> Array:
	return []


## Cheats this game offers a seat right now: [{id, name}]. MatchCore runs the detection
## (CheatingManager) and calls apply_cheat only if he didn't see.
func cheat_options(_seat: int) -> Array:
	return []


func apply_cheat(_seat: int, _id: String) -> void:
	pass


## Ghosts may interfere, a little: every game gets at least a whisper (tell someone one
## thing) and, in arena games, a cold spot. Subclasses add their own.
func ghost_action(seat: int, a: Dictionary) -> void:
	if str(a.get("do", "")) == "whisper":
		var to := int(a.get("target", -1))
		if seats.has(to) and alive(to):
			var info := ghost_secret(to)
			core.toast("A cold voice in your ear: %s" % (info if info != "" else "\"they're lying.\""), to)
			core.emit({"e": "ghost_whisper", "seat": seat, "to": to})


func ghost_secret(_to: int) -> String:
	return ""


func ghost_ai(seat: int, brain: AiBrain, _view: Dictionary, _dt: float) -> void:
	brain.wait += _dt
	if brain.wait < 6.0:
		return
	brain.wait = 0.0
	var l := living()
	if not l.is_empty():
		ghost_action(seat, {"do": "whisper", "target": l[brain.rng.randi_range(0, l.size() - 1)]})


func tampered(seat: int) -> bool:
	return core.p(seat).tamper.get(id(), false)


## The Cage on this game's hazards.
func tip(seat: int, system := "hazard") -> bool:
	return core.cage.tip(seat, system)


func team_of(seat: int) -> int:
	for i in teams.size():
		if (teams[i] as Array).has(seat):
			return i
	return -1


## Split the participants into teams (shuffled with the game's RNG).
func make_teams(sizes: Array) -> void:
	var pool := seats.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var x = pool[i]
		pool[i] = pool[j]
		pool[j] = x
	teams.clear()
	var k := 0
	for n in sizes:
		teams.append(pool.slice(k, k + int(n)))
		k += int(n)


# --- shared helpers ---------------------------------------------------------------

func alive(seat: int) -> bool:
	return core.p(seat).alive


func living() -> Array[int]:
	var out: Array[int] = []
	for s in seats:
		if core.p(s).alive:
			out.append(s)
	return out


func body(seat: int) -> Dictionary:
	return core.p(seat).body


func base_view() -> Dictionary:
	return {"id": id(), "title": title(), "instructions": instructions(), "level": level, "t": t,
		"seats": seats, "done": done, "rats": rats.duplicate(), "format": format, "teams": teams.duplicate(true),
		"winners": winners.duplicate(), "draw": draw}


## base_view plus what the viewer can do (the HUD reads "actions" and "cheats").
func view_with_actions(v: Dictionary, viewers: Array) -> Dictionary:
	if not viewers.is_empty():
		var s := int(viewers[0])
		if seats.has(s) and alive(s):
			v["actions"] = actions_for(s)
			v["cheats"] = cheat_options(s)
	return v
