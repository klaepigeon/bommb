class_name MinigameValidation
extends RefCounted
## Checks one minigame against the shared presentation framework: its registration (via
## MinigameRegistry.validate), and, with `play`, a real run with AI players through
## MinigamePresenter from BOARD FREEZE to RETURN: every stage visited in order, the board
## frozen meanwhile, results and rewards through the shared system, back on the board.
## Used by tools/validate_minigames.gd and the tests.

static func check(id: String, play := false) -> Dictionary:
	var g: Dictionary = MinigameRegistry.GAMES[id]
	var n := clampi(int(g.get("max", 4)), int(g.get("min", 2)), 4)
	var core := _core(n)
	var parts: Array[int] = []
	for i in n:
		parts.append(i)
	var mg := MinigameRegistry.create(id, core, parts, 0)
	var problems: Array = MinigameRegistry.validate(id, mg)
	var reg := MinigameRegistry.registration(id, mg)
	var run := {}
	if play and problems.is_empty():
		run = run_through(id, n)
		problems.append_array(run.problems)
	return {"problems": problems, "reg": reg, "run": run}


static func _core(n: int, kinds := []) -> MatchCore:
	var core := MatchCore.new()
	core.fast = true
	core.slow_flow = true
	var seats := []
	for i in n:
		seats.append({"seat": i, "kind": kinds[i] if i < kinds.size() else "ai", "name": "P%d" % (i + 1)})
	core.setup(seats, 7 + n, {"turns": 10})
	return core


## Play `id` from the board through the whole presentation and back. Returns what was seen.
static func run_through(id: String, n: int, kinds := [], kind := "") -> Dictionary:
	var core := _core(n, kinds)
	var problems: Array = []
	# a round's board play happens first, so there's a board to freeze and return to
	core._start_round()
	var w := 0.0
	while core.phase != "turn" and w < 30.0:
		core.tick(0.05)
		w += 0.05
	# everyone's had their turn (skip them: the board's own tests cover turns): the round ends
	core.flow.goto("TURN_END")
	core.rules.sub = "idle"
	core.board_round_done()
	core.mg_queue.clear()
	core.take_events()
	var space_before: Array = core.players.map(func(p): return p.space)
	var k := kind if kind != "" else ("special" if MinigameRegistry.GAMES[id].get("special", false) else ("roulette" if id == "roulette" else "battle"))
	var started := core._start_entry({"kind": k, "seats": [], "id": id, "wager": 0, "by": -1})
	if not started:
		return {"problems": ["couldn't start"], "stages": []}
	var stages_seen: Array = []
	var flows: Array = []
	var frozen_ok := true
	var why_moved := ""
	var title_seen := false
	var t := 0.0
	var results_seen := false
	var shown: Dictionary = {}     # stage -> what the view had to show then
	var rewards_seen := false
	while t < 900.0:
		var v := core.view_for([0])
		if core.presenter.active and (stages_seen.is_empty() or stages_seen.back() != core.presenter.stage):
			stages_seen.append(core.presenter.stage)
		if flows.is_empty() or flows.back() != core.flow.state:
			flows.append(core.flow.state)
		if core.presenter.active:
			if core.phase == "turn":
				frozen_ok = false
				why_moved = "phase turn at %s" % core.presenter.stage
			if str(v.get("registration", {}).get("name", "")) != "":
				title_seen = true
			if not shown.has(core.presenter.stage):
				shown[core.presenter.stage] = v.get("registration", {}).duplicate(true)
			# people press NEXT and READY when they're asked to
			for s in core.presenter.waiting_for():
				core.action(s, {"t": "mg_next" if core.presenter.stage == "instructions" else "ready"})
			# nobody on the board may move while it's frozen
			if core.players.map(func(p): return p.space) != space_before and core.presenter.stage != "":
				frozen_ok = false
				why_moved = "spaces %s -> %s at %s" % [space_before, core.players.map(func(p): return p.space), core.presenter.stage]
		for e in core.take_events():
			if str(e.e) == "results":
				results_seen = true
			if str(e.e) == "rewards":
				rewards_seen = true
			if str(e.e) == "turn" and core.presenter.active:
				frozen_ok = false
				why_moved = "a turn started at %s" % core.presenter.stage
		if not core.presenter.active and stages_seen.size() > 1:
			break
		core.tick(0.05)
		t += 0.05
	for s in MinigamePresenter.STAGES:
		if not stages_seen.has(s):
			problems.append("never reached stage '%s'" % s)
	if stages_seen != MinigamePresenter.STAGES.filter(func(x): return stages_seen.has(x)):
		problems.append("stages out of order: %s" % str(stages_seen))
	if not frozen_ok:
		problems.append("the board moved during the minigame (%s)" % why_moved)
	if not title_seen:
		problems.append("no title in the view")
	if not results_seen:
		problems.append("no results through the shared system")
	if not rewards_seen:
		problems.append("no rewards through the shared system")
	if core.presenter.active:
		problems.append("never finished (stuck at '%s': %s)" % [core.presenter.stage, core.flow.waiting_on])
	if core.ending == "" and not core.phase in ["turn", "round_start", "finale", "mg_intro"]:
		problems.append("didn't return to the board (phase %s)" % core.phase)
	if not core.flow.invalid.is_empty():
		problems.append("invalid flow changes: %s" % str(core.flow.invalid))
	for st in ["title", "instructions", "controls", "arena_preview"]:
		var rg: Dictionary = shown.get(st, {})
		if rg.is_empty():
			problems.append("nothing to show at %s" % st)
	if str(shown.get("title", {}).get("description", "")) == "":
		problems.append("no description on the title card")
	if (shown.get("instructions", {}).get("instructions", []) as Array).is_empty():
		problems.append("no instructions on the instructions screen")
	if (shown.get("controls", {}).get("touch", []) as Array).is_empty() and not MinigameRegistry.registration(id).get("controls", []).is_empty() and not (MinigameRegistry.validate(id) as Array).is_empty():
		problems.append("no controls on the controls screen")
	if str(shown.get("arena_preview", {}).get("arena", "")) == "":
		problems.append("no arena to preview")
	return {"problems": problems, "stages": stages_seen, "flows": flows, "core": core, "shown": shown}
