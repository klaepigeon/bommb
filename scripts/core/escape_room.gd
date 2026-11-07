class_name EscapeRoom
extends RefCounted
## THE GUEST EXPERIENCE: "CAN YOU ESCAPE BEFORE THE PARTY ENDS?" The robot's escape room,
## five rooms off the front of the hall (data/hall/escape_rooms.json), each door shut until
## the room before it is solved (facility.json 'locks'). Walked in real time like the rest
## of the facility, and cooperative: whatever one of you has found out, anyone standing in
## the escape rooms with you can use (you're in there together; you can point).
##   A THE BIRTHDAY SUITE: three things in the room are wrong (unlit candles, wrong-coloured
##     balloons, a photograph with too many guests). Three numbers; the keypad.
##   B THE PROCESSING FLOOR: watch the conveyor for the colour order, pull the switches in it.
##     Wrong, and the machine has a go at you.
##   C THE GIFT ROOM: six packages. One holds the office key, one a number, some help, some bite.
##   D THE HOST'S OFFICE: the guest list and the schedule (numbers), the blueprint (which lever
##     first), and his diagrams of what humans enjoy.
##   E THE EXIT CHAMBER: the final code, then both levers, in the right order, by two people,
##     within three seconds. Then the EXIT. Whoever walks out has escaped the party; a few
##     seconds later the doors shut and the match is over.

const COLOURS := ["RED", "BLUE", "YELLOW", "GREEN"]
const ESCAPE_WINDOW := 15.0

var core: MatchCore
var fac: FacilityManager
var clues: Dictionary = {}       # a b c x y z: digits; order: colours; levers: "LR"|"RL"
var packages: Array = []
var switch_i := 0
var lever_pulls: Array = []      # [{side, seat, t}]
var escaped: Dictionary = {}     # seat -> time
var close_t := -1.0              # counting down once someone's out


func _init(c: MatchCore, f: FacilityManager) -> void:
	core = c
	fac = f
	for k in ["a", "b", "c", "x", "y", "z"]:
		clues[k] = core.rng.randi_range(1, 9)
	var order := COLOURS.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j := core.rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	clues.order = order
	clues.levers = "LR" if core.rng.randf() < 0.5 else "RL"
	packages = ["key", "clue", "teeth", "snake", "cake", "shoes"]
	for i in range(packages.size() - 1, 0, -1):
		var j := core.rng.randi_range(0, i)
		var t = packages[i]
		packages[i] = packages[j]
		packages[j] = t


func in_rooms(seat: int) -> bool:
	var p := core.p(seat)
	return p.away() and fac.area_of(p.pos).begins_with("esc_")


## What the people in the escape rooms know between them.
func known_together(seat: int) -> Dictionary:
	var out: Dictionary = (core.p(seat).known.get("esc", {}) as Dictionary).duplicate()
	for p in core.players:
		if p.seat != seat and p.alive and in_rooms(p.seat) and in_rooms(seat):
			out.merge(p.known.get("esc", {}))
	return out


func _learn(seat: int, k: String, v) -> void:
	var p := core.p(seat)
	if not p.known.has("esc"):
		p.known["esc"] = {}
	p.known.esc[k] = v
	p.stat("room_found")


func effect(seat: int, a: Dictionary) -> void:
	var p := core.p(seat)
	match str(a.effect):
		"esc_clue":
			var k := str(a.clue)
			_learn(seat, k, clues[k])
			match k:
				"a":
					core.toast("Twelve candles on the cake. %d of them have never been lit. Somebody's counted them before you: there are scratches in the icing." % clues.a, seat)
				"b":
					core.toast("All the balloons are pink. All but %d. They're the colour of the inside of something." % clues.b, seat)
				"c":
					core.toast("Every photo is of the same party. In one of them there are %d more guests than chairs. They're all looking at the camera." % clues.c, seat)
				"order":
					core.toast("Down the line, in bins, over and over: %s." % ", ".join(clues.order), seat)
				"x":
					core.toast("THE GUEST LIST. Your name is on it, at number %d. Your name is on it several times." % clues.x, seat)
				"y":
					core.toast("THE PARTY SCHEDULE. 'The party ends at %d o'clock. Then the guests are processed.'" % clues.y, seat)
				"levers":
					var first := "LEFT" if clues.levers == "LR" else "RIGHT"
					core.toast("THE BLUEPRINT: the EXIT, two levers. In the margin: '%s ONE FIRST. TWO PEOPLE. NOBODY LEAVES ALONE.'" % first, seat)
			_check_office()
		"esc_lore":
			core.toast("Diagrams of humans, labelled. 'SCREAMING = HAPPY'. 'CRYING = VERY HAPPY'. 'STILL = FINISHED'.", seat)
		"esc_code":
			var know := known_together(seat)
			for k in a.clues:
				if not know.has(str(k)):
					core.toast("You don't know all of it. (Nobody in here does yet.)", seat)
					return
			fac.state[str(a.flag)] = true
			fac._open_doors()
			core.emit({"e": "escape_progress", "flag": a.flag, "seat": seat})
			core.toast("%s: the code's right. Something unlocks with a party-popper bang." % p.name)
		"esc_switch":
			var col := str(a.colour)
			if col == str(clues.order[switch_i]):
				switch_i += 1
				core.emit({"e": "escape_switch", "n": switch_i})
				if switch_i >= 4:
					fac.state["esc_b"] = true
					fac._open_doors()
					core.emit({"e": "escape_progress", "flag": "esc_b", "seat": seat})
					core.toast("The line stops. The bins tip. The door to the Gift Room opens.")
			else:
				switch_i = 0
				core.injure(seat, ["hand_l", "hand_r", "arm_l", "arm_r"][core.rng.randi_range(0, 3)], "bruised", "machinery")
				core.toast("Wrong switch. A press comes down beside your hand. Then on it. The panel resets.", seat)
		"esc_package":
			var what: String = packages[int(a.n)]
			match what:
				"key":
					fac.state["esc_c"] = true
					fac._open_doors()
					core.emit({"e": "escape_progress", "flag": "esc_c", "seat": seat})
					core.toast("A key on a ribbon: HOST'S OFFICE.", seat)
				"clue":
					_learn(seat, "z", clues.z)
					core.toast("A birthday card. 'YOU ARE %d TODAY!' You aren't." % clues.z, seat)
				"teeth":
					core.economy.award(seat, 6, "a package", false)
					core.toast("Teeth. A box of them, sorted by size.", seat)
				"snake":
					core.injure(seat, "hand_l", "burned", "a package")
					core.status.apply(seat, "paralytic", "a package")
					core.toast("Something in the tissue paper bites, and you can't feel your hand.", seat)
				"cake":
					core.status.apply(seat, core.status.random_poison(seat), "a slice of cake")
					core.toast("A slice of cake. You eat it before you think about it.", seat)
				"shoes":
					core.give_item(seat, "greased_shoes", "a package")
					core.toast("A pair of shoes. Your size. Your shoes. You're wearing them.", seat)
		"esc_lever":
			lever_pulls.append({"side": str(a.side), "seat": seat, "t": core.phase_t + core.round_n * 1000.0})
			lever_pulls = lever_pulls.slice(maxi(0, lever_pulls.size() - 2))
			if lever_pulls.size() == 2:
				var l0: Dictionary = lever_pulls[0]
				var l1: Dictionary = lever_pulls[1]
				var ok: bool = int(l0.seat) != int(l1.seat) and str(l0.side) + str(l1.side) == str(clues.levers) and absf(float(l1.t) - float(l0.t)) <= 3.0
				if ok:
					fac.state["esc_open"] = true
					core.emit({"e": "escape_progress", "flag": "esc_open", "seat": seat})
					core.say("escape_open")
					core.toast("THE EXIT OPENS. Daylight, or something like it. \"Leaving so soon?\"")
				else:
					if int(l0.seat) == int(l1.seat):
						core.toast("It won't move for one person. 'NOBODY LEAVES ALONE.'", seat)
					else:
						core.toast("The levers clunk back. Wrong way round, or not together.", seat)
					# the last pull can still be the first of the next pair
					lever_pulls = [l1]
		"esc_escape":
			escaped[seat] = core.phase_t
			p.location = "escaped"
			p.stat("escaped")
			core.emit({"e": "escaped", "seat": seat})
			core.toast("%s WALKS OUT OF THE PARTY." % p.name)
			if close_t < 0.0:
				close_t = ESCAPE_WINDOW
				core.toast("The exit will close in %d seconds." % int(ESCAPE_WINDOW))


func _check_office() -> void:
	var anyone := {}
	for p in core.players:
		for k in p.known.get("esc", {}).keys():
			anyone[k] = true
	if anyone.has("x") and anyone.has("y") and anyone.has("levers") and not fac.state.has("esc_d"):
		fac.state["esc_d"] = true
		fac._open_doors()
		core.emit({"e": "escape_progress", "flag": "esc_d"})
		core.toast("A door behind the blueprint swings open: THE EXIT CHAMBER.")


func tick(dt: float) -> void:
	if close_t < 0.0:
		return
	close_t -= dt
	if close_t <= 0.0 and core.ending == "":
		core._end("escape")


func to_save() -> Dictionary:
	return {"clues": clues.duplicate(true), "packages": packages.duplicate(), "switch_i": switch_i}


func load_save(d: Dictionary) -> void:
	if d.is_empty():
		return
	clues = d.get("clues", clues).duplicate(true)
	for k in ["a", "b", "c", "x", "y", "z"]:
		clues[k] = int(clues[k])
	packages = d.get("packages", packages).duplicate()
	switch_i = int(d.get("switch_i", 0))
