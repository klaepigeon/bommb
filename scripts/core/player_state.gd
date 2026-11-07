class_name PlayerState
extends RefCounted
## One contestant, as the host keeps them. Serialised with to_view() for clients (and the
## AI), which hides what only this contestant should know.
##
## Alive, or a ghost: a dead contestant stays in the match as a ghost, collects Dead Rats
## and looks for a way back (ResurrectionManager). Suspicion (0..100, at 100 he kills you)
## measures what you've done; the Cage (0..5) is how far he has stacked the odds against
## you, and he tightens it when he chooses (CageManager).

var seat := 0
var name := ""
var kind := "ai"        # local | remote | ai
var peer := 0
var face := 0
var color := Color.WHITE
var alive := true
var ghost := false
var space := 0
var rats := 0           # Dead Rats: the collectible and the currency
var items: Array[String] = []
var body: Dictionary = Body.fresh()
var painkillers := 0
var helmet := false
var has_key := false
var clues: Dictionary = {}      # clue index -> digit (private)
var at_door := false
var death := ""                 # how they died (last time)
var died_round := 0
var deaths := 0
var suspicion := 0
var cage := 0
var statuses: Array = []        # [{id, turns, t}] poisons and other lasting effects
var location := "table"         # "table", or the room hotspot they're at
var room_actions := 0           # actions left while away from the table
var roll_bonus := 0             # cheats, stimulants, ghosts' curses and blessings (next roll only)
var tamper: Dictionary = {}     # minigame id -> true: you've rigged its equipment
var known: Dictionary = {}      # things only you have found out (private): file, next game...
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


func has_status(id: String) -> bool:
	for st in statuses:
		if st.id == id:
			return true
	return false


func to_view(private: bool) -> Dictionary:
	return {
		"seat": seat, "name": name, "kind": kind, "face": face, "color": color, "alive": alive, "ghost": ghost,
		"space": space, "rats": rats, "items": items.duplicate(),
		"item_count": items.size(), "body": body.duplicate(true), "painkillers": painkillers,
		"helmet": helmet, "has_key": has_key, "clues": clues.duplicate() if private else {},
		"clue_count": clues.size(), "at_door": at_door, "death": death, "deaths": deaths,
		"suspicion": suspicion, "cage": cage, "statuses": statuses.duplicate(true), "location": location,
		"room_actions": room_actions, "roll_bonus": roll_bonus if private else 0,
		"known": known.duplicate(true) if private else {},
	}
