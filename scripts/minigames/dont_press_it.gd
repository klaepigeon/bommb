extends Minigame
## DON'T PRESS IT (cooperative). A machine in the middle of the table: wires, buttons, two
## levers, a crank, and a big red button marked DON'T PRESS IT. Somebody (nobody else
## knows who) can secretly START the defusal; that starts the countdown and lights up the
## first instruction. Every instruction has to be done by someone who isn't the last
## person to touch the machine: the machine won't let the same hands do two steps running
## (and it won't tell anyone whose hands those were). Wrong wire, wrong button, a lever
## alone, touching it during a WAIT: a STRIKE. Too many strikes, or the clock: it goes off.
## Get through every stage and everyone's paid. No talking in LAST CALL 3: you've got
## REACH (put your hand up for a step) and your eyes.

const STEP_KINDS := ["cut", "press", "levers", "crank", "wait"]
const WIRES := ["RED", "BLUE", "YELLOW", "GREEN"]
const BUTTONS := ["CIRCLE", "SQUARE", "TRIANGLE"]

var started := false
var starter := -1
var locked_out := -1          # the last hands on it
var steps: Array = []         # [{kind, arg, n}]
var stage := 0
var clock := 0.0
var strikes := 0
var max_strikes := 3
var cut: Array = []
var levers: Dictionary = {}   # seat -> "L"|"R" while holding
var crank_n := 0
var wait_t := 0.0
var reach: Dictionary = {}    # seat -> seconds left with their hand up
var exploded := false
var defused := false
var _idle := 0.0
var _end_t := 0.0


func id() -> String:
	return "dont_press_it"


func title() -> String:
	return "DON'T PRESS IT"


func instructions() -> Array:
	return ["Anyone can secretly START the defusal (the panel at the back). Then the clock runs.", "Each step lights up. Whoever did the last step can't do the next one.",
		"Wrong move, or touching it during a WAIT: a STRIKE. Too many and it goes off.", "LEVERS need two people at once. REACH to show you'll take a step.", "Defuse it together: everyone gets paid."]


func controls(seat: int) -> Array:
	var out: Array = []
	if not started:
		out.append({"kind": "tap", "do": "start", "label": "START IT (SECRETLY)"})
		return out
	if done or exploded or defused:
		return out
	out.append({"kind": "pick", "do": "cut", "label": "CUT", "options": WIRES.filter(func(w): return not cut.has(w))})
	out.append({"kind": "pick", "do": "press", "label": "PRESS", "options": BUTTONS + ["DON'T PRESS IT"]})
	out.append({"kind": "hold", "do": "lever_l", "label": "LEFT LEVER"})
	out.append({"kind": "hold", "do": "lever_r", "label": "RIGHT LEVER"})
	out.append({"kind": "tap", "do": "crank", "label": "CRANK"})
	out.append({"kind": "tap", "do": "reach", "label": "REACH"})
	return out


func setup() -> void:
	var n := 3 + level
	var wires := WIRES.duplicate()
	var last := ""
	for i in n:
		var kind: String = STEP_KINDS[rng.randi_range(0, STEP_KINDS.size() - 1)]
		if kind == last:
			kind = STEP_KINDS[(STEP_KINDS.find(kind) + 1) % STEP_KINDS.size()]
		if kind == "levers" and seats.size() < 3:
			kind = "crank"
		last = kind
		match kind:
			"cut":
				var w: String = wires.pop_at(rng.randi_range(0, wires.size() - 1)) if not wires.is_empty() else "RED"
				steps.append({"kind": "cut", "arg": w, "text": "CUT THE %s WIRE" % w})
			"press":
				var b: String = BUTTONS[rng.randi_range(0, BUTTONS.size() - 1)]
				steps.append({"kind": "press", "arg": b, "text": "PRESS %s" % b})
			"levers":
				steps.append({"kind": "levers", "arg": "", "text": "PULL BOTH LEVERS AT ONCE"})
			"crank":
				var k := 4 + rng.randi_range(0, 3)
				steps.append({"kind": "crank", "arg": str(k), "text": "CRANK IT %d TIMES" % k})
			"wait":
				steps.append({"kind": "wait", "arg": "3", "text": "DON'T TOUCH ANYTHING (3 SECONDS)"})
	max_strikes = 3 if level == 0 else 2
	clock = 45.0 - level * 5.0


func current_step() -> Dictionary:
	return steps[stage] if stage < steps.size() else {}


func action(seat: int, a: Dictionary) -> void:
	if not seats.has(seat) or not alive(seat) or done or exploded or defused:
		return
	var d := str(a.get("do", ""))
	if d == "start":
		if not started:
			started = true
			starter = seat
			locked_out = seat
			core.emit({"e": "mg", "k": "started"})
			core.toast("You turn the key at the back. Something inside starts ticking.", seat)
			core.toast("The machine starts ticking. Somebody started it.")
		return
	if not started:
		return
	if d == "reach":
		reach[seat] = 2.5
		core.emit({"e": "mg", "k": "reach", "seat": seat})
		return
	var st := current_step()
	if st.is_empty():
		return
	if d == "lever_l" or d == "lever_r":
		if bool(a.get("on", true)):
			levers[seat] = "L" if d == "lever_l" else "R"
		else:
			levers.erase(seat)
		if st.kind != "levers":
			if bool(a.get("on", true)):
				_strike(seat, "a lever")
			return
		_check_levers()
		return
	if st.kind == "wait" and d in ["cut", "press", "crank"]:
		_strike(seat, "touching it")
		return
	# the same hands can't do two steps running
	if seat == locked_out:
		core.toast("It won't move for you. Not again. Not yet.", seat)
		core.emit({"e": "mg", "k": "refuse", "seat": seat})
		return
	match d:
		"cut":
			var w := str(a.get("pick", ""))
			if cut.has(w) or not WIRES.has(w):
				return
			cut.append(w)
			if st.kind == "cut" and st.arg == w:
				_advance(seat)
			else:
				_strike(seat, "the %s wire" % w.to_lower())
		"press":
			var b := str(a.get("pick", ""))
			if b == "DON'T PRESS IT":
				_boom(seat)
				return
			if st.kind == "press" and st.arg == b:
				_advance(seat)
			else:
				_strike(seat, b.to_lower())
		"crank":
			if st.kind != "crank":
				_strike(seat, "the crank")
				return
			crank_n += 1
			core.emit({"e": "mg", "k": "crank", "seat": seat, "n": crank_n})
			if crank_n >= int(st.arg):
				_advance(seat)


func _check_levers() -> void:
	var l := -1
	var r := -1
	for s in levers.keys():
		if s == locked_out:
			continue
		if levers[s] == "L":
			l = s
		elif levers[s] == "R":
			r = s
	if l >= 0 and r >= 0 and l != r:
		levers.clear()
		_advance(r)


func _advance(seat: int) -> void:
	locked_out = seat
	stage += 1
	crank_n = 0
	wait_t = 0.0
	core.emit({"e": "mg", "k": "step", "stage": stage})
	if stage >= steps.size():
		defused = true
		core.emit({"e": "mg", "k": "defused"})
		core.say("hp_defused")
		notes.append("Defused with %.0f seconds left." % clock)
		_end_t = 0.0


func _strike(seat: int, what: String) -> void:
	strikes += 1
	core.emit({"e": "mg", "k": "strike", "seat": seat, "n": strikes})
	core.toast("STRIKE %d: %s." % [strikes, what])
	clock = maxf(1.0, clock - 5.0)
	if strikes >= max_strikes:
		_boom(seat)


func _boom(seat: int) -> void:
	exploded = true
	core.emit({"e": "mg", "k": "boom", "seat": seat})
	core.say("hp_boom")
	notes.append("It went off.")
	for s in living():
		var close := s == seat or rng.randf() < 0.35
		if close and (level >= 2 or tip(s)) and core.kill(s, "boom", [["hand_l", "lost"], ["head", "burned"]]):
			continue
		core.injure(s, ["hand_l", "hand_r", "arm_l", "arm_r", "ears", "eye_l", "eye_r"][rng.randi_range(0, 6)], "lost" if close else "burned", "the bomb")
	_end_t = 0.0


func tick(dt: float) -> void:
	t += dt
	tick_chill(dt)
	for s in reach.keys():
		reach[s] = float(reach[s]) - dt
		if float(reach[s]) <= 0.0:
			reach.erase(s)
	if exploded or defused:
		_end_t += dt
		if _end_t > 2.0 and not done:
			for s in living():
				if defused:
					teeth[s] += 2
			if defused:
				finish(living())
			else:
				finish([])
		return
	if not started:
		_idle += dt
		if _idle > 15.0:
			# nobody dared: it starts itself, and it's in a hurry
			started = true
			starter = -1
			locked_out = -1
			clock *= 0.7
			core.toast("Nobody started it. It starts itself.")
			core.emit({"e": "mg", "k": "started"})
		return
	clock -= dt * (1.3 if handicapped.size() > 0 else 1.0)
	var st := current_step()
	if not st.is_empty() and st.kind == "wait":
		wait_t += dt
		if wait_t >= float(st.arg):
			_advance(locked_out)
	if clock <= 0.0:
		_boom(-1)


func cheat_options(seat: int) -> Array:
	if started and not exploded and not defused and alive(seat):
		return [{"id": "read_manual", "name": "read the back of the manual"}]
	return []


func apply_cheat(_seat: int, _cid: String) -> void:
	clock += 10.0


func view_for(viewers: Array) -> Dictionary:
	var v := base_view()
	var me := int(viewers[0]) if not viewers.is_empty() else -1
	var st := current_step()
	v.merge({"started": started, "you_started": me >= 0 and me == starter, "locked_you": me >= 0 and me == locked_out,
		"stage": stage, "stages": steps.size(), "step": st.get("text", ""), "step_kind": st.get("kind", ""), "clock": clock, "strikes": strikes,
		"max_strikes": max_strikes, "cut": cut.duplicate(), "levers": levers.duplicate(), "crank": crank_n, "reach": reach.keys(),
		"exploded": exploded, "defused": defused, "idle": _idle})
	return view_with_actions(v, viewers)


func ai(seat: int, brain: AiBrain, _view: Dictionary, dt: float) -> void:
	brain.wait += dt
	if brain.wait < 0.6 + (1.0 - brain.nerve) * 0.6:
		return
	brain.wait = 0.0
	if not started:
		if brain.nerve > 0.55 and brain.rng.randf() < 0.25:
			action(seat, {"do": "start"})
		return
	var st := current_step()
	if st.is_empty() or exploded or defused:
		return
	if st.kind == "levers":
		# grab whichever lever's free (unless it was my hands last)
		if seat != locked_out and not levers.has(seat):
			var taken := levers.values()
			action(seat, {"do": "lever_l" if not taken.has("L") else "lever_r", "on": true})
		return
	if st.kind == "wait":
		return
	if seat == locked_out:
		return
	# someone else has their hand up: let them (if I'm the cooperative sort)
	for o in reach.keys():
		if o != seat and brain.coop > 0.3:
			return
	if not reach.has(seat):
		action(seat, {"do": "reach"})
		return
	# a careless one sometimes gets it wrong
	var careful := brain.rng.randf() < 0.85 + brain.perception * 0.15
	match str(st.kind):
		"cut":
			var w: String = st.arg if careful else WIRES[brain.rng.randi_range(0, WIRES.size() - 1)]
			action(seat, {"do": "cut", "pick": w})
		"press":
			action(seat, {"do": "press", "pick": st.arg if careful else BUTTONS[brain.rng.randi_range(0, BUTTONS.size() - 1)]})
		"crank":
			action(seat, {"do": "crank"})
