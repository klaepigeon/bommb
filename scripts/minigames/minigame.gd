class_name Minigame
extends RefCounted
## The base every minigame shares. A minigame is host-side rules only: it gets the
## contestants still alive, a difficulty level (how many times it has come round), and
## the MatchCore to report through (kill, injure, say, emit). Drawing it is a separate
## view scene (scripts/view/), chosen by id; AI plays it through the same action() a
## human's input arrives through, reading the same view_for() a human's screen gets.
##
## Life cycle: setup() (on creation) -> start() (after the instructions card) ->
## tick(dt) until done -> teeth and summary() are read by MatchCore.

var core: MatchCore
var seats: Array[int] = []
var level := 0
var t := 0.0
var done := false
var teeth: Dictionary = {}       # seat -> teeth won (or lost) in this game
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
		teeth[s] = 0
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


## Ghosts may interfere, a little. Arena games add a cold spot; others their own. (No
## talking: there's no chat in LAST CALL 3, living or dead.)
## Every game: a ghost can CHILL someone (a cold breath down their neck: the game reads
## `chilled` and makes them clumsy for a few seconds, its own way).
var chilled: Dictionary = {}     # seat -> seconds left


func ghost_action(seat: int, a: Dictionary) -> void:
	if str(a.get("do", "")) == "chill":
		var to := int(a.get("target", -1))
		if seats.has(to) and alive(to) and float(chilled.get(to, 0.0)) <= 0.0:
			chilled[to] = 3.0
			core.emit({"e": "mg", "k": "chill", "seat": seat, "target": to})


func tick_chill(dt: float) -> void:
	for k in chilled.keys():
		chilled[k] = float(chilled[k]) - dt
		if chilled[k] <= 0.0:
			chilled.erase(k)


func is_chilled(s: int) -> bool:
	return float(chilled.get(s, 0.0)) > 0.0


func ghost_ai(seat: int, brain: AiBrain, _view: Dictionary, dt: float) -> void:
	brain.wait += dt
	if brain.wait < 7.0:
		return
	brain.wait = 0.0
	var l := living()
	if not l.is_empty():
		ghost_action(seat, {"do": "chill", "target": l[brain.rng.randi_range(0, l.size() - 1)]})


## Placings, best first, ties grouped: [[seats], [seats]...]. Games that rank people
## (FFA, survival) set `ranking`; otherwise winners first, then the living, then the dead.
var ranking: Array = []


func placings() -> Array:
	if not ranking.is_empty():
		return ranking.duplicate(true)
	var out := []
	if draw:
		return [seats.duplicate()]
	var w := winners.duplicate()
	if not w.is_empty():
		out.append(w)
	var alive_rest := []
	var dead := []
	for s in seats:
		if w.has(s):
			continue
		if core.p(s).alive:
			alive_rest.append(s)
		else:
			dead.append(s)
	if not alive_rest.is_empty():
		out.append(alive_rest)
	if not dead.is_empty():
		out.append(dead)
	return out


## Rank by a score (higher is better), ties grouped; the dead at the bottom.
func rank_by(score: Dictionary) -> void:
	var lst := seats.duplicate()
	lst.sort_custom(func(a, b):
		var da := 0 if core.p(a).alive else 1
		var db := 0 if core.p(b).alive else 1
		if da != db:
			return da < db
		return float(score.get(a, 0)) > float(score.get(b, 0)))
	ranking.clear()
	for s in lst:
		var key := [core.p(s).alive, float(score.get(s, 0))]
		if not ranking.is_empty():
			var prev: int = ranking[ranking.size() - 1][0]
			if [core.p(prev).alive, float(score.get(prev, 0))] == key:
				ranking[ranking.size() - 1].append(s)
				continue
		ranking.append([s])


## Someone sabotaged this seat's equipment (Sabotage Kit, the boiler room). Games read it.
var handicapped: Dictionary = {}


func handicap(seat: int) -> void:
	handicapped[seat] = true
	notes.append("%s's equipment had been tampered with." % core.p(seat).name)


## The control scheme the HUD builds for this game (each game's own): a list of widgets.
## kinds: "stick" (move), "tap" (a button: {do}), "hold" (press and hold: sends {do, on}),
## "swipe" (a pad: sends {do, dir}), "timing" (a ring: tap when it lines up: {do}),
## "pick" (buttons for each of `options`: {do, pick}).
func controls(_seat: int) -> Array:
	return [] if buttons_only() else [{"kind": "stick"}]


## Played entirely with the choice buttons the game puts up (no stick, no pads).
func buttons_only() -> bool:
	return false


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
		"seats": seats, "done": done, "teeth": teeth.duplicate(), "format": format, "teams": teams.duplicate(true),
		"winners": winners.duplicate(), "draw": draw, "handicapped": handicapped.keys(), "chilled": chilled.keys()}


## base_view plus what the viewer can do (the HUD reads "actions" and "cheats").
func view_with_actions(v: Dictionary, viewers: Array) -> Dictionary:
	if not viewers.is_empty():
		var s := int(viewers[0])
		if seats.has(s) and alive(s):
			v["actions"] = actions_for(s)
			v["cheats"] = cheat_options(s)
			v["controls"] = controls(s)
	return v
