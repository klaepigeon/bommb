extends Node
## Who is sitting where for the next match: four seats, each a local human (with an input
## device), a remote human (a network peer), an AI, or empty (filled by AI at launch).
## The lobby edits this; MatchCore copies it when the match begins.

signal changed

const MAX := 4
const COLORS := [Color("e8402a"), Color("2a8ae8"), Color("f0c020"), Color("40c060")]
const AI_NAMES := ["DORIS", "KEVIN", "MR. PLUM", "BABY TONY", "GAIL", "THE NEW GUY", "AUNTIE"]

## kind: "local" | "remote" | "ai" | "empty"
## device: -1 keyboard+mouse+touch (the primary local player), 0.. keyboard sets / pads
var seats: Array = []
var mode := "single"   # single | local | online


func _ready() -> void:
	reset("single")


func reset(m: String) -> void:
	mode = m
	seats.clear()
	for i in MAX:
		seats.append(_empty(i))
	changed.emit()


func _empty(i: int) -> Dictionary:
	return {"seat": i, "kind": "empty", "name": "", "peer": 0, "device": -1, "ready": false, "face": i, "color": COLORS[i]}


func set_seat(i: int, d: Dictionary) -> void:
	var s: Dictionary = _empty(i)
	s.merge(d, true)
	s.seat = i
	seats[i] = s
	changed.emit()


func clear_seat(i: int) -> void:
	seats[i] = _empty(i)
	changed.emit()


func first_free() -> int:
	for s in seats:
		if s.kind == "empty":
			return s.seat
	return -1


func add_ai(i: int) -> void:
	set_seat(i, {"kind": "ai", "name": AI_NAMES[(i * 3 + randi() % 3) % AI_NAMES.size()], "ready": true, "face": (i + 1) % 4})


## Empty seats become AI (at match launch).
func fill_with_ai() -> void:
	for s in seats:
		if s.kind == "empty":
			add_ai(s.seat)


func humans() -> int:
	var n := 0
	for s in seats:
		if s.kind in ["local", "remote"]:
			n += 1
	return n


func to_array() -> Array:
	return seats.duplicate(true)


func from_array(a: Array) -> void:
	seats = a.duplicate(true)
	changed.emit()
