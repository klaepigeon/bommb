extends SceneTree
## The threat manager, and Marta behaving by it: no skills is the baseline; Survival makes her
## hear and see further, press harder, search longer, commit faster and keep tracking him after
## losing him; Memory the other way; a gunshot keys her up for a while; and the levers really
## change what she does (the beat before she comes, how long she searches).
## godot --headless --path hysteria -s tools/threat_test.gd

var ok := true
func check(cond: bool, what: String) -> void:
	print(("  ok  " if cond else " FAIL ") + what)
	ok = ok and cond

func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate(); main.name = "Main"
	root.add_child(main)
	await process_frame; await process_frame
	main.encounter.process_mode = Node.PROCESS_MODE_DISABLED
	var G := root.get_node("Game")
	var TM = load("res://scripts/progress/threat.gd")
	TM.forget_recent()
	G.flags["skills"] = {}
	var base: Dictionary = TM.levers()
	check(is_equal_approx(TM.score(), 1.0), "no skills: the baseline (%.2f)" % TM.score())
	G.flags["skills"] = {"headshot": true, "steady": true, "quick_reload": true}
	var surv: Dictionary = TM.levers()
	check(surv.hearing > base.hearing and surv.sight > base.sight and surv.pace > base.pace, "Survival: she hears, sees and presses harder")
	check(surv.persistence > base.persistence and surv.alertness < base.alertness and surv.recovery > base.recovery, "Survival: she searches longer, commits faster, tracks him after losing him")
	G.flags["skills"] = {"handwriting": true, "how_she_moves": true, "these_streets": true}
	var mem: Dictionary = TM.levers()
	check(mem.hearing < base.hearing and mem.alertness > base.alertness and mem.recovery < base.recovery, "Memory: the other way")
	check(TM.breakdown().has("skill:how_she_moves") and TM.breakdown()["skill:how_she_moves"] < -0.15, "How She Moves counts for more than a default memory")
	G.flags["skills"] = {}
	load("res://scripts/core/noise.gd").make(self, Vector3.ZERO, 1.0, "gunshot", null)
	check(TM.score() > 1.2, "a gunshot keys her up (%.2f)" % TM.score())
	TM.forget_recent()
	# the levers in her behaviour: the beat before she comes
	main.enter_labyrinth()
	var h = main.hunter; var p = main.player
	h.wake(Vector2i(6, 4))
	p.global_position = main.labyrinth.to_global(h.position + Vector3(0, 0, 6.0)); p.velocity = Vector3.ZERO
	h._yaw = 0.0; h._enter(h.S.SEARCH)
	var seen_at := -1.0; var chase_at := -1.0; var t := 0.0
	while t < 3.0:
		await process_frame
		var dt := get_root().get_process_delta_time()
		t += dt
		if seen_at < 0.0 and h._notice >= 0.0: seen_at = t
		if h.state == h.S.CHASE: chase_at = t; break
	check(seen_at >= 0.0 and chase_at > seen_at + 0.3, "baseline: she sees him, holds a beat (%.2f s), then comes" % (chase_at - seen_at))
	h._enter(h.S.SEARCH); h._notice = -1.0
	G.flags["skills"] = {"headshot": true, "steady": true, "quick_reload": true, "deep_pockets": true, "second_wind": true}
	seen_at = -1.0; chase_at = -1.0; t = 0.0
	while t < 3.0:
		await process_frame
		t += get_root().get_process_delta_time()
		if seen_at < 0.0 and h._notice >= 0.0: seen_at = t
		if h.state == h.S.CHASE: chase_at = t; break
	check(chase_at > 0.0 and chase_at - seen_at < 0.3, "with Survival she commits almost at once (%.2f s)" % (chase_at - seen_at))
	print("THREAT ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
