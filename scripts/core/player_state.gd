class_name PlayerState
extends RefCounted
## One contestant, as the host keeps them. Serialised with to_view() for clients (and the
## AI), which hides what only this contestant should know; to_save()/load_save() for the
## save file.
##
## Two currencies, never interchangeable: TEETH (spend them: shops, wagers, bribes, tolls)
## and DEAD RATS (the score: most Dead Rats wins; a ghost can spend one to come back, and
## it's gone from their score). Alive, or a ghost. Suspicion (0..100, at 100 he kills you);
## the Cage (0..5). Away from the table: walking the facility in real time (`location`
## "away"), with a position, while the board carries on.

var seat := 0
var name := ""
var kind := "ai"        # local | remote | ai
var peer := 0
var face := 0
var color := Color.WHITE
var alive := true
var ghost := false
var space := 0
var teeth := 0           # spendable
var rats := 0            # Dead Rats: victory
var items: Array[String] = []
var body: Dictionary = Body.fresh()
var painkillers := 0
var helmet := false
var armour := 0                 # body armour: hits left
var has_key := false
var clues: Dictionary = {}      # clue index -> digit (private)
var at_door := false
var death := ""
var died_round := 0
var deaths := 0
var suspicion := 0
var cage := 0
var statuses: Array = []        # [{id, turns, t}]
var location := "table"         # "table" | "away"
var pos := Vector2.ZERO         # away: where they're standing (hall metres, x/z)
var yaw := 0.0
var away_t := 0.0               # seconds since they got up
var away_limit := 45.0          # the return timer
var away_late := false          # the timer ran out (he's been told)
var room_actions := 0           # unused since 0.2.5 (kept for old views)
var roll_bonus := 0             # next roll only (cheats, ghosts, items)
var next_roll := ""             # "low" | "high" | "d10" | "double" | "loaded_double" | "six"
var move_bonus := 0             # greased shoes: this turn
var reverse := false            # reverse gear: this turn
var cold_hand := false          # a ghost's hand on you: your next square does nothing
var event_shift := 0            # phantom coin: the next event tier shift (+ better)
var loophole := 0               # turns the amendments don't apply to you
var handicap := false           # sabotage kit: your next minigame
var counterfeit := 0            # plaster Teeth still in circulation
var debts: Dictionary = {}      # creditor seat -> Teeth owed
var tamper: Dictionary = {}
var known: Dictionary = {}      # private discoveries
var placings: Array[int] = []
var stats: Dictionary = {}      # for the Caller's Awards and the Caller's Game


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


func away() -> bool:
	return location != "table"


func has_status(id: String) -> bool:
	for st in statuses:
		if st.id == id:
			return true
	return false


func stat(k: String, n := 1) -> void:
	stats[k] = int(stats.get(k, 0)) + n


func stat_max(k: String, v: int) -> void:
	stats[k] = maxi(int(stats.get(k, 0)), v)


func owed_total() -> int:
	var n := 0
	for k in debts.keys():
		n += int(debts[k])
	return n


func to_view(private: bool) -> Dictionary:
	return {
		"seat": seat, "name": name, "kind": kind, "face": face, "color": color, "alive": alive, "ghost": ghost,
		"space": space, "teeth": teeth, "rats": rats, "items": items.duplicate() if private else [],
		"item_count": items.size(), "body": body.duplicate(true), "painkillers": painkillers,
		"helmet": helmet, "armour": armour, "has_key": has_key, "clues": clues.duplicate() if private else {},
		"clue_count": clues.size(), "at_door": at_door, "death": death, "deaths": deaths,
		"suspicion": suspicion, "cage": cage, "statuses": statuses.duplicate(true), "location": location,
		"pos": [pos.x, pos.y], "yaw": yaw, "away_t": away_t, "away_limit": away_limit,
		"roll_bonus": roll_bonus if private else 0, "next_roll": next_roll if private else "",
		"move_bonus": move_bonus, "reverse": reverse, "loophole": loophole,
		"debts": debts.duplicate(), "known": known.duplicate(true) if private else {},
		"stats": stats.duplicate(),
	}


const SAVE_KEYS := ["seat", "name", "kind", "face", "alive", "ghost", "space", "teeth", "rats", "painkillers", "helmet",
	"armour", "has_key", "at_door", "death", "died_round", "deaths", "suspicion", "cage", "statuses", "location",
	"away_t", "away_limit", "away_late", "roll_bonus", "next_roll", "move_bonus", "reverse", "cold_hand", "event_shift",
	"loophole", "handicap", "counterfeit", "tamper", "known", "stats", "yaw"]


func to_save() -> Dictionary:
	var d := {}
	for k in SAVE_KEYS:
		d[k] = get(k)
	d.items = Array(items)
	d.body = body.duplicate(true)
	d.clues = {}
	for k in clues.keys():
		d.clues[str(k)] = clues[k]
	d.debts = {}
	for k in debts.keys():
		d.debts[str(k)] = debts[k]
	d.pos = [pos.x, pos.y]
	d.color = color.to_html()
	d.placings = Array(placings)
	return d


func load_save(d: Dictionary) -> void:
	for k in SAVE_KEYS:
		if d.has(k):
			var v = d[k]
			if typeof(get(k)) == TYPE_INT and typeof(v) == TYPE_FLOAT:
				v = int(v)
			set(k, v)
	items.clear()
	for it in d.get("items", []):
		items.append(str(it))
	body = d.get("body", Body.fresh())
	for part in body.keys():
		if body[part].has("t"):
			body[part].t = int(body[part].t)
	clues.clear()
	for k in d.get("clues", {}).keys():
		clues[int(k)] = int(d.clues[k])
	debts.clear()
	for k in d.get("debts", {}).keys():
		debts[int(k)] = int(d.debts[k])
	var pp: Array = d.get("pos", [0, 0])
	pos = Vector2(float(pp[0]), float(pp[1]))
	color = Color.html(str(d.get("color", "ffffff")))
	placings.clear()
	for x in d.get("placings", []):
		placings.append(int(x))
	for st in statuses:
		st.turns = int(st.turns)
		st.t = int(st.t)
	for k in stats.keys():
		stats[k] = int(stats[k])
