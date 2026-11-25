class_name Mind
extends RefCounted
## Decides what a person is doing. The schedule says what an hour is for (work, sleep, home,
## patrol, away, or free time); free time is spent by utility: each need (hunger, drink,
## company, shopping, restlessness) grows by the hour, is weighted by personality, and is only
## an option where a free place is open to this person. Activities pay for themselves: a meal,
## a drink or a purchase moves money from the person to the business's owner.

## Per game hour, how fast each need grows (0 = satisfied, 1 = urgent).
const GROWTH := {"eat": 0.10, "drink": 0.08, "social": 0.12, "shop": 0.04, "wander": 0.15}
const PLACE_TAGS := {"eat": ["eat"], "drink": ["drink"], "social": ["hangout"], "shop": ["shop"]}
const PRICE := {"eat": 3, "drink": 2, "shop": 5}
const DOING := {"work": "working", "sleep": "asleep", "home": "at home", "eat": "eating", "drink": "drinking",
	"social": "passing time", "shop": "shopping", "wander": "walking", "patrol": "on patrol", "away": "away"}

var who: String
var schedule: Array = []
var traits: Dictionary = {}
var needs := {"eat": 0.3, "drink": 0.3, "social": 0.4, "shop": 0.1, "wander": 0.2}
var home := ""
var bed := ""
var rng := RandomNumberGenerator.new()

func _init(def: Dictionary) -> void:
	who = def.id
	schedule = def.schedule
	traits = def.traits
	home = def.get("home", "")
	bed = def.get("bed", "")
	rng.seed = hash(who)
	for k in needs:
		needs[k] = rng.randf_range(0.1, 0.6)

func grow(hours: float) -> void:
	for k in needs:
		needs[k] = minf(1.0, needs[k] + GROWTH[k] * hours * (0.5 + float(traits.get(k, 0.5))))

## The schedule block in force now: {from, to, do, at?} with from/to as minutes of day.
func block() -> Dictionary:
	var m := Clock.minute_of_day()
	for b in schedule:
		var f := Clock.parse(b.from)
		var t := Clock.parse(b.to)
		if Clock.in_span(m, f, t):
			return {"from": f, "to": t, "do": b.do, "at": b.get("at", "")}
	return {"from": 0, "to": 0, "do": "free", "at": ""}

## Minutes from now until a minute-of-day comes round.
static func minutes_until(m_of_day: int) -> float:
	return fposmod(float(m_of_day) - Clock.minute_of_day(), 1440.0)

## A new activity: {do, place (id or ""), until (Clock.total_minutes), block_to}.
func decide(from: Vector3) -> Dictionary:
	var b := block()
	var end := Clock.total_minutes + minutes_until(b.to)
	match b.do:
		"work":
			return _act("work", b.at, end)
		"sleep":
			return _act("sleep", _home_place(["bed"], from), end)
		"home":
			var seat := _home_place(["seat"], from)
			return _act("home", seat if seat != "" else _home_place([], from), end)
		"patrol", "away":
			return _act(b.do, "", end)
		"eat", "drink", "social", "shop":
			var p := _find(PLACE_TAGS[b.do], from)
			if p != "":
				return _act(b.do, p, end)
	return _free(from, end)

func _free(from: Vector3, block_end: float) -> Dictionary:
	var best := "wander"
	var best_score: float = float(traits.get("wander", 0.3)) * float(needs.wander) * 0.6
	var best_place := ""
	for need in PLACE_TAGS:
		var w := float(traits.get(need, 0.5))
		if w <= 0.01:
			continue
		var p := _find(PLACE_TAGS[need], from)
		if p == "":
			continue
		var dist: float = World.places[p].pos.distance_to(from)
		var score: float = needs[need] * w - dist * 0.004 + rng.randf_range(0.0, 0.08)
		if score > best_score:
			best_score = score
			best = need
			best_place = p
	if best_score < 0.15 and home != "" and home != "offmap":
		var seat := _home_place(["seat"], from)
		if seat != "":
			return _act("home", seat, minf(block_end, Clock.total_minutes + 45.0))
	var length := rng.randf_range(25.0, 70.0)
	return _act(best, best_place, minf(block_end, Clock.total_minutes + length))

func _act(what: String, place: String, until: float) -> Dictionary:
	return {"do": what, "place": place, "until": until}

## Called when an activity is over: needs it met go down, and it is paid for.
func finish(act: Dictionary, npc: Node) -> void:
	var what: String = act.do
	if needs.has(what):
		needs[what] = 0.0
	if what in ["eat", "drink", "social"]:
		needs.social = maxf(0.0, needs.social - 0.3)
	if PRICE.has(what) and act.place != "" and World.places.has(act.place):
		var room: String = World.places[act.place].room
		if World.rooms.has(room) and not World.rooms[room].owners.is_empty():
			World.pay(npc, World.rooms[room].owners[0], PRICE[what], "%s at %s" % [what, World.rooms[room].name])

func _home_place(tags: Array, from: Vector3) -> String:
	if bed != "" and ("bed" in tags or tags.is_empty()):
		return bed
	if home == "" or home == "offmap":
		return ""
	var all_tags := ["home"] + tags
	for p in World.find_places(all_tags, from, who):
		if p.room == home:
			return p.id
	return ""

## Nearest free place with these tags that this person may enter right now.
func _find(tags: Array, from: Vector3) -> String:
	for p in World.find_places(tags, from, who):
		if World.may_enter(who, p.room):
			return p.id
	return ""
