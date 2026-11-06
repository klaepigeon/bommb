class_name PlayerState
extends RefCounted
## One contestant, as the host keeps them. Serialised with to_view() for clients (and the
## AI), which hides what only this contestant should know.

var seat := 0
var name := ""
var kind := "ai"        # local | remote | ai
var peer := 0
var face := 0
var color := Color.WHITE
var alive := true
var space := 0
var tickets := 0
var items: Array[String] = []
var body: Dictionary = Body.fresh()
var painkillers := 0
var helmet := false
var has_key := false
var clues: Dictionary = {}      # clue index -> digit (private)
var at_door := false
var death := ""                 # how they died
var died_round := 0
var placings: Array[int] = []


static func from_seat(s: Dictionary) -> PlayerState:
	var p := PlayerState.new()
	p.seat = int(s.seat)
	p.name = str(s.name) if str(s.name) != "" else "CONTESTANT %d" % (p.seat + 1)
	p.kind = "ai" if s.kind == "empty" else str(s.kind)
	p.peer = int(s.get("peer", 0))
	p.face = int(s.get("face", p.seat))
	p.color = s.get("color", Color.WHITE)
	return p


func pk() -> bool:
	return painkillers > 0


func to_view(private: bool) -> Dictionary:
	return {
		"seat": seat, "name": name, "kind": kind, "face": face, "color": color, "alive": alive,
		"space": space, "tickets": tickets, "items": items.duplicate(),
		"item_count": items.size(), "body": body.duplicate(true), "painkillers": painkillers,
		"helmet": helmet, "has_key": has_key, "clues": clues.duplicate() if private else {},
		"clue_count": clues.size(), "at_door": at_door, "death": death,
	}
