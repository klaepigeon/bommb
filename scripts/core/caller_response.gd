class_name CallerResponseManager
extends RefCounted
## When somebody's return timer runs out, the Caller decides what to do about it, and
## the same thing never gets the same answer twice running: the first one to stay out
## might get twenty Teeth and a polite escort back; the next one to try it, copying them,
## might be shot. The more people have pushed it this match (late_count), and the more
## suspicious you are, the worse it gets. A Bribe Token buys a pardon.

const RESPONSES := ["pardon", "forced", "reward", "advantage", "humiliation", "confiscation", "missed", "injury", "execution", "miracle"]
const BASE := {"pardon": 14.0, "forced": 18.0, "reward": 10.0, "advantage": 7.0, "humiliation": 12.0, "confiscation": 12.0,
	"missed": 10.0, "injury": 8.0, "execution": 1.5, "miracle": 2.0}

var core: MatchCore
var late_count := 0
var history: Array = []        # [{seat, response, round}]


func _init(c: MatchCore) -> void:
	core = c


func pick(seat: int) -> String:
	var p := core.p(seat)
	var k := float(late_count)
	var w := BASE.duplicate()
	w.pardon /= 1.0 + k
	w.reward /= 1.0 + k * 1.5
	w.miracle /= 1.0 + k
	w.injury *= 1.0 + k * 0.6
	w.confiscation *= 1.0 + k * 0.3
	w.execution *= (1.0 + k * 2.5) * (1.0 + p.suspicion / 25.0)
	if core.cage.tip(seat, "encounter"):
		w.execution *= 2.0
		w.injury *= 1.5
	# what he did last time, he doesn't do again
	if not history.is_empty():
		w[str(history[history.size() - 1].response)] *= 0.25
	var total := 0.0
	for r in RESPONSES:
		total += w[r]
	var x := core.rng.randf() * total
	for r in RESPONSES:
		x -= w[r]
		if x <= 0.0:
			return r
	return "forced"


func respond(seat: int) -> String:
	var p := core.p(seat)
	var r := pick(seat)
	if core.items.consume_passive(seat, "bribe_token", "the Caller's temper"):
		r = "pardon"
	late_count += 1
	history.append({"seat": seat, "response": r, "round": core.round_n})
	core.emit({"e": "caller_response", "seat": seat, "response": r})
	core.say("late_" + r, {"name": p.name})
	match r:
		"pardon":
			core.toast("\"%s. Take your time, darling.\" He gives you another thirty seconds." % p.name)
			p.away_limit = p.away_t + 30.0
			p.away_late = false
		"forced":
			core.toast("Two men in aprons bring %s back to the table." % p.name)
			core.facility.sit(seat, true, "forced")
		"reward":
			core.economy.award(seat, 20, "the Caller", false)
			core.toast("\"Initiative!\" He pays %s 20 Teeth. Then they're carried back to their chair." % p.name)
			core.facility.sit(seat, true, "reward")
		"advantage":
			p.roll_bonus += 3
			core.toast("\"A wanderer. I like a wanderer.\" %s's next roll gets three more. Sit down." % p.name)
			core.facility.sit(seat, true, "advantage")
		"humiliation":
			core.suspicion.add(seat, 6, "humiliated")
			core.toast("The PA plays a fanfare and a spotlight follows %s all the way back to the table." % p.name)
			core.facility.sit(seat, true, "humiliation")
		"confiscation":
			if not p.items.is_empty():
				var it: String = p.items.pop_at(core.rng.randi_range(0, p.items.size() - 1))
				core.toast("Confiscated: %s's %s." % [p.name, Items.name_of(it).to_lower()])
				core.items.claim_insurance(seat, "confiscation")
			else:
				core.economy.take(seat, 8, "confiscated")
				core.toast("Confiscated: 8 of %s's Teeth." % p.name)
			core.facility.sit(seat, true, "confiscation")
		"missed":
			p.stat("missed_turns")
			p.next_roll = ""
			p.roll_bonus -= 99
			core.toast("\"You like it out there? Stay.\" %s sits back down and won't move on their next turn." % p.name)
			core.facility.sit(seat, true, "missed")
		"injury":
			var part := Body.random_severable(p.body, core.rng)
			if part != "":
				core.injure(seat, part, "broken", "the Caller")
			core.toast("Something heavy, swung from behind. %s is dragged back." % p.name)
			core.facility.sit(seat, true, "injury")
		"execution":
			core.toast("The lights in that part of the building go out. A single shot.")
			if not core.kill(seat, "shot", [["torso", "broken"]]):
				core.facility.sit(seat, true, "execution")
		"miracle":
			core.change_rats(seat, 1, "a miracle")
			core.toast("In the dark, %s finds a Dead Rat with a bow on it. \"Well, well.\"" % p.name)
			core.facility.sit(seat, true, "miracle")
	return r
