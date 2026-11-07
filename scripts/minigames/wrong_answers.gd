extends ChoiceGame
## WRONG ANSWERS ONLY (1v3). One of you is in the control room and can see the panel's
## wiring; the rest are at the panel. Each round the controller calls out which wire to
## cut (the truth, or not), then everyone at the panel cuts one. A wrong wire bites. The
## panel team wins if most of their cuts were right; the controller wins if they weren't.
## The controller can help, mislead, or keep quiet. Do you trust them?

const COLORS := ["RED", "BLUE", "GREEN", "YELLOW"]
var controller := -1
var safe := ""
var instruction := ""
var team_right := 0
var team_wrong := 0
var lied: Array = []          # rounds where the call was a lie (revealed at the end of each)


func id() -> String:
	return "wrong_answers"


func title() -> String:
	return "WRONG ANSWERS ONLY"


func instructions() -> Array:
	return ["One of you is the CONTROLLER: they can see which wire is safe.", "The controller calls a wire. True, or not.",
		"Everyone else cuts one. A wrong wire bites.", "Most cuts right: the panel wins. Otherwise the controller does."]


func setup() -> void:
	rounds = 3
	var best := -1
	for s in seats:
		if best < 0 or core.p(s).rats > core.p(best).rats:
			best = s
	controller = best
	teams = [[controller], seats.filter(func(s): return s != controller)]
	options = COLORS.duplicate()


func begin_round() -> void:
	safe = COLORS[rng.randi_range(0, COLORS.size() - 1)]
	instruction = ""
	prompt = "Cut a wire."
	core.toast("The safe wire this time is %s." % safe, controller)


func choosers() -> Array[int]:
	var out: Array[int] = []
	for s in living():
		if s != controller:
			out.append(s)
	return out


func action(seat: int, a: Dictionary) -> void:
	if seat == controller and sub == "choose" and str(a.get("do", "")) == "call":
		instruction = str(a.get("choice", ""))
		core.emit({"e": "mg", "k": "call", "choice": instruction})
		core.toast("CONTROL ROOM: \"Cut the %s.\"" % instruction)
		return
	super.action(seat, a)


func resolve(revealed: Dictionary) -> bool:
	if instruction != "" and instruction != safe:
		lied.append(round_i)
	for s in revealed.keys():
		if s == controller or not alive(s):
			continue
		if revealed[s] == safe:
			team_right += 1
		else:
			team_wrong += 1
			core.injure(s, ["hand_l", "hand_r"][rng.randi_range(0, 1)], "burned" if level == 0 else "broken", "the wrong wire")
			rats[controller] += 1
	core.toast("The safe wire was %s.%s" % [safe, " The control room said %s." % instruction if instruction != "" else ""])
	return false


func conclude() -> void:
	var team: Array = teams[1].filter(func(s): return alive(s))
	if team_right >= team_wrong:
		for s in team:
			rats[s] += 2
		finish(team, false)
	else:
		finish([controller] if alive(controller) else [], false)


func actions_for(seat: int) -> Array:
	if seat == controller:
		if sub != "choose":
			return []
		return COLORS.map(func(c): return {"do": "call", "choice": c, "name": "CALL: " + c, "picked": instruction == c})
	return super.actions_for(seat)


func view_for(viewers: Array) -> Dictionary:
	var v := super.view_for(viewers)
	v.merge({"controller": controller, "instruction": instruction, "score": [team_right, team_wrong],
		"safe": safe if viewers.has(controller) or sub == "reveal" else ""})
	if viewers.has(controller):
		v["prompt"] = "You're in the control room. The safe wire is %s. Call one." % safe
	return v


func ai(seat: int, brain: AiBrain, view: Dictionary, dt: float) -> void:
	if seat == controller:
		if sub == "choose" and instruction == "":
			brain.wait += dt
			if brain.wait > 1.5:
				brain.wait = 0.0
				var honest := brain.coop >= 0.45 or brain.rng.randf() < 0.4
				action(seat, {"t": "mg", "do": "call", "choice": safe if honest else COLORS[brain.rng.randi_range(0, 3)]})
		return
	if instruction == "" and sub_t < 6.0:
		return
	super.ai(seat, brain, view, dt)


func ai_choice(_seat: int, brain: AiBrain):
	# trust the call, unless they've lied before
	if instruction != "" and (lied.is_empty() or brain.rng.randf() < 0.3):
		return instruction
	return COLORS[brain.rng.randi_range(0, 3)]
