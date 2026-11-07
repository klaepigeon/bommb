class_name BoardMachines
extends RefCounted
## THE MURDERLAND CONTROL SYSTEM: the robot's console in the middle of the board, and the
## machines it runs (the board's gates, BoardGraph.gates): the signposts in the Wishing
## Woods, the rotating platform at the Funhouse, the floodgates of the Sunken Kingdom, the
## Giggleworks conveyors, the Big Top, the Royal Invitation; and the Welcome Parade.
##
## Readable, never arbitrary: every scheduled change is announced a round before it happens
## (the console lights up: "NEXT ROUND: THE FLOODGATES OPEN"), the rotating platform turns
## every round on the beat, and the parade moves the same three spaces every round. Players
## change things too: SIGNPOST, FLOODGATE, SWITCH and CONTROL squares let the lander pull a
## lever; the CARNIVAL WHEEL spins one of its attractions.

const PARADE_STEP := 3

var core: MatchCore
var parade_at := 0               # index into graph.parade
var planned: Dictionary = {}     # {gate, value, round} announced for next round
var history: Array = []


func _init(c: MatchCore) -> void:
	core = c


func g() -> BoardGraph:
	return core.graph


func active() -> bool:
	return not g().gates.is_empty()


## A gate changes, with the machine's own announcement (the view animates it).
func set_gate(gate: String, value: String, by := -1, why := "") -> bool:
	if not g().set_gate(gate, value):
		return false
	history.append({"round": core.round_n, "gate": gate, "value": value, "by": by})
	core.emit({"e": "gate", "gate": gate, "value": value, "by": by, "name": str(g().gate_defs[gate].get("name", gate)), "why": why})
	core.say("gate_" + gate + "_" + value, {"name": core.p(by).name if by >= 0 else "the robot"})
	core.toast("%s: %s." % [g().gate_defs[gate].get("name", gate), _describe(gate, value)])
	return true


func toggle(gate: String, by := -1, why := "") -> void:
	var vals := g().gate_values(gate)
	if vals.is_empty():
		return
	var i := vals.find(g().gates[gate])
	set_gate(gate, str(vals[(i + 1) % vals.size()]), by, why)


func _describe(gate: String, v: String) -> String:
	match gate + ":" + v:
		"woods_sign:left":
			return "the signposts point under the mushrooms"
		"woods_sign:right":
			return "the signposts point down the main road"
		"rotator:maze":
			return "the platform turns to the mirror maze"
		"rotator:coaster":
			return "the platform turns to the coaster"
		"flood:low":
			return "the water drains: the river walk is open, the ferry's aground"
		"flood:high":
			return "the floodgates open: the river walk's under water, the ferry's running"
		"big_top:open":
			return "the Big Top is open"
		"big_top:shut":
			return "the Big Top is shut"
		"royal:open":
			return "the Royal Road is open: an invitation to the palace"
		"royal:shut":
			return "the palace gates close"
		"conveyor:forward":
			return "the production line runs forward"
		"conveyor:back":
			return "the production line runs backwards"
	return v


## The start of each round: the platform turns, the parade moves, last round's announced
## change happens, and the next one's announced.
func round_start() -> void:
	if not active():
		return
	if g().gates.has("rotator"):
		toggle("rotator", -1, "it turns every round")
	if not planned.is_empty() and int(planned.round) == core.round_n:
		set_gate(str(planned.gate), str(planned.value), -1, "scheduled")
		planned = {}
	# the royal invitation: the last third of the match, the palace opens
	if g().gates.has("royal") and core.round_n >= int(ceil(core.max_rounds * 0.66)) and g().gates.royal != "open":
		set_gate("royal", "open", -1, "the final stretch")
	_parade()
	if core.round_n % 3 == 0 and core.round_n < core.max_rounds:
		_plan()


func _plan() -> void:
	var opts := ["flood", "big_top", "woods_sign", "conveyor"].filter(func(x): return g().gates.has(x))
	if opts.is_empty():
		return
	var gate: String = opts[core.rng.randi_range(0, opts.size() - 1)]
	var vals := g().gate_values(gate).filter(func(v): return v != g().gates[gate])
	if vals.is_empty():
		return
	planned = {"gate": gate, "value": str(vals[0]), "round": core.round_n + 1}
	core.emit({"e": "machine_warn", "gate": gate, "value": planned.value, "round": planned.round, "name": str(g().gate_defs[gate].get("name", gate))})
	core.toast("THE CONTROL SYSTEM, NEXT ROUND: %s." % _describe(gate, str(planned.value)).to_upper())
	core.say("machine_warn")


## The Welcome Parade: three spaces along its route every round, throwing Teeth to anyone
## it passes (and shoving them a space on, out of its way).
func _parade() -> void:
	if g().parade.is_empty():
		return
	var route: Array = g().parade
	var passed := []
	for k in PARADE_STEP:
		parade_at = (parade_at + 1) % route.size()
		passed.append(int(route[parade_at]))
	core.emit({"e": "parade", "at": int(route[parade_at]), "passed": passed})
	for p in core.players:
		if p.alive and not p.away() and passed.has(p.space):
			core.economy.award(p.seat, 3, "the parade", false)
			core.toast("The Welcome Parade goes over %s. A float throws them 3 Teeth." % p.name)


func parade_space() -> int:
	return int(g().parade[parade_at]) if not g().parade.is_empty() else -1


## Landing on a machine square.
func land(seat: int, kind: String) -> bool:
	var p := core.p(seat)
	match kind:
		"signpost":
			core.rules.ask_lever(seat, "woods_sign")
			return true
		"floodgate":
			core.rules.ask_lever(seat, "flood")
			return true
		"switch":
			toggle("conveyor", seat, "a switch")
		"rotator":
			toggle("rotator", seat, "%s gave it a push" % p.name)
		"control":
			core.rules.ask_lever(seat, "")
			return true
		"conveyor":
			var n := 3 if str(g().gates.get("conveyor", "forward")) == "forward" else -3
			core.toast("The conveyor carries %s %s." % [p.name, "on three squares" if n > 0 else "back three squares"])
			core.rules.slide(seat, n)
			core.emit({"e": "conveyor", "seat": seat, "n": n})
		"wheel":
			wheel(seat)
		"death":
			# the trapdoor lottery: everyone watches
			var odds := 0.4 if core.cage.tip(seat, "encounter") else 1.0 / 6.0
			if core.rng.randf() < odds:
				core.cutscenes.play("death_square", seat, {"do": "kill", "anim": "trapdoor", "fallback": [["leg_l", "broken"], ["leg_r", "broken"]]}, "MEAT_PUPPET")
			else:
				core.cutscenes.play("death_square", seat, {"do": "teeth", "n": 10, "why": "the trapdoor didn't open"}, "MEAT_PUPPET", true, 3.0, 2.0)
		"bonus":
			core.economy.award(seat, 6 * (3 if core.final_round() else 1), "bonus square")
			core.say("space_bonus", {"name": p.name})
	return false


## THE CARNIVAL WHEEL: one of its attractions, and you see which.
func wheel(seat: int) -> void:
	var p := core.p(seat)
	var opts := ["big_top", "ferris", "gallery", "fortune", "coaster"]
	var pick: String = opts[core.rng.randi_range(0, opts.size() - 1)]
	core.emit({"e": "wheel", "seat": seat, "pick": pick})
	match pick:
		"big_top":
			toggle("big_top", seat, "the wheel")
		"ferris":
			# round the big wheel and off somewhere else on the board
			var to := int(g().rat_spots[core.rng.randi_range(0, g().rat_spots.size() - 1)]) if not g().rat_spots.is_empty() else p.space
			p.space = to
			core.emit({"e": "move", "seat": seat, "space": to, "slide": true})
			core.toast("THE FERRIS WHEEL takes %s up, round, and drops them somewhere else." % p.name)
		"gallery":
			core.economy.award(seat, 8, "the shooting gallery")
			core.toast("THE SHOOTING GALLERY: %s hits everything. 8 Teeth." % p.name)
		"fortune":
			core.toast("THE FORTUNE TELLER turns a card over for %s." % p.name)
			core.fate.trigger(seat)
		"coaster":
			if g().gates.has("rotator"):
				set_gate("rotator", "coaster", seat, "the wheel")


func view() -> Dictionary:
	return {"gates": g().gates.duplicate(), "parade": parade_space(), "parade_route": g().parade.duplicate(), "planned": planned.duplicate()}


func to_save() -> Dictionary:
	return {"gates": g().gates.duplicate(), "parade_at": parade_at, "planned": planned.duplicate()}


func load_save(d: Dictionary) -> void:
	for k in d.get("gates", {}).keys():
		g().gates[k] = str(d.gates[k])
	g()._refresh()
	parade_at = int(d.get("parade_at", 0))
	planned = d.get("planned", {}).duplicate()
	if planned.has("round"):
		planned.round = int(planned.round)
