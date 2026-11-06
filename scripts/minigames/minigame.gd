class_name Minigame
extends RefCounted
## The base every minigame shares. A minigame is host-side rules only: it gets the
## contestants still alive, a difficulty level (how many times it has come round), and
## the MatchCore to report through (kill, injure, say, emit). Drawing it is a separate
## view scene (scripts/view/), chosen by id; AI plays it through the same action() a
## human's input arrives through, reading the same view_for() a human's screen gets.
##
## Life cycle: setup() (on creation) -> start() (after the instructions card) ->
## tick(dt) until done -> tickets and summary() are read by MatchCore.

var core: MatchCore
var seats: Array[int] = []
var level := 0
var t := 0.0
var done := false
var tickets: Dictionary = {}       # seat -> tickets won (or lost) in this game
var rng := RandomNumberGenerator.new()
var notes: Array[String] = []      # what happened, for the results screen


func init(c: MatchCore, participants: Array[int], lvl: int) -> void:
	core = c
	seats = participants.duplicate()
	level = lvl
	rng.seed = c.rng.randi()
	for s in seats:
		tickets[s] = 0
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
		"seats": seats, "done": done, "tickets": tickets.duplicate()}
