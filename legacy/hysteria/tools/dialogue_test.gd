extends SceneTree
## The dialogue runtime, played: Kurt and Marta at Sonya's door. Intents picked, Kurt's lines
## said, Socko's hijack and interruption recorded as what they were, consequences in the world
## state, memory-gated options appearing only with the memory, subtitles with the speaker, ambient
## Socko held off while it runs, and it all in the save.
## godot --headless --path hysteria -s tools/dialogue_test.gd

var ok := true
var WS = load("res://scripts/narrative/world_state.gd")
func check(cond: bool, what: String) -> void:
	print(("  ok  " if cond else " FAIL ") + what)
	ok = ok and cond

func fresh() -> Node:
	for c in root.get_children():
		if c.name == "Main": c.free()
	await process_frame
	root.get_node("Game").flags.clear()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.name = "Main"; root.add_child(main)
	await process_frame; await process_frame
	main.encounter.process_mode = Node.PROCESS_MODE_DISABLED
	return main

func at_peace(main: Node) -> Node:
	var G := root.get_node("Game")
	main.encounter.skip(); main.socko_intro.skip(); G.flags["socko_intro_done"] = true
	main.enter_labyrinth()
	var h = main.hunter
	h.wake(Vector2i(1, 1)); h.at_peace = true; h._enter(h.S.CALM); h._path.clear()
	main.player.global_position = h.global_position + Vector3(0, 0, 1.4)
	return h

func run(main: Node, picks: Array) -> Array:
	var offered := []
	var c = load("res://scripts/narrative/conversation.gd").new(); c.name = "Conversation"; main.add_child(c)
	c.auto_choices = picks.duplicate(); c.pace = 25.0
	c.choice_offered.connect(func(o: Array): offered.append(o.map(func(x): return String(x.id))))
	c.start(main, "marta_nursery", {"marta": main.hunter})
	var t := 0
	while is_instance_valid(c) and t < 3000:
		await process_frame; t += 1
	return offered

func _initialize() -> void:
	var main: Node = await fresh()
	var G := root.get_node("Game")
	var h = await at_peace(main)
	check(h.prompt() == "Talk to her", "at peace by the door, she can be talked to")
	# a subtitle, with the speaker
	main.speech.say("marta", "«…buckle.»", "test.line")
	check(main.speech.subtitles.box.visible and main.speech.subtitles.who.text == "MARTA", "subtitles name who's speaking")
	# talk: what happened (Socko hijacks), her name, the boxes, Sonya (Socko interrupts), leave
	var seen := {"in_conv": false}         # (a lambda can't assign an outer local; it can fill a dictionary)
	main.speech.line_started.connect(func(_s, _t, _i): if main.speech.in_conversation(): seen.in_conv = true)
	var offered: Array = await run(main, ["what", "name", "boxes", "sonya", "leave"])
	check(seen.in_conv, "while it runs, it's a conversation (ambient Socko holds his tongue)")
	check(not main.speech.in_conversation() and not main.player.locked, "it ends; Kurt has his hands back")
	var st: Dictionary = G.flags.dialogue.marta_nursery
	var hist: Array = st.history
	var hijack: Dictionary = {}; var interrupt: Dictionary = {}
	for r in hist:
		if r.get("option", "") == "what": hijack = r
		if r.get("option", "") == "sonya": interrupt = r
	check(hijack.get("selected", "") == "What happened here, Marta?" and hijack.get("delivered", "") == "What did you do to her?" and hijack.get("by", "") == "kurt (socko)", "the hijack is recorded: what he chose, what came out of his mouth")
	check(interrupt.get("socko_mode", "") == "interrupt" and String(interrupt.get("delivered", "")).ends_with("—"), "the interruption is recorded: his line cut off")
	check(WS.rel("marta", "fear") == 1.0 and WS.rel("marta", "trust") == 0.0, "consequences: she's afraid of him now (fear 1, trust 1 − 1)")
	check(WS.knows("marta", "kurt_said_name") and WS.knows("marta", "asked_boxes") and not WS.knows("mama", "kurt_said_name"), "what she knows is hers; nobody else knows it")
	check(G.flags.get("promised_sonya", false) and G.flags.get("talked_to_marta", false), "he said he'd find her")
	var letter_ever := false
	for o in offered: if o.has("letter"): letter_ever = true
	check(not letter_ever, "the letter option isn't there without the memory")
	check(not offered[1].has("what"), "an option said once isn't offered again")
	# with the memory and the note read, it is
	G.flags["looked_note"] = true; G.flags["skills"] = {"handwriting": true}
	var offered2: Array = await run(main, ["letter", "leave"])
	check(offered2.size() > 0 and offered2[0].has("letter"), "with Her Handwriting and the note read, he can tell her about the letter")
	check(WS.knows("marta", "kurt_read_letter"), "and she knows he read it")
	# saved with the game
	check(main.save_game.save(), "saved")
	main = await fresh()
	check(main.save_game.load_game(), "loaded")
	check(WS.rel("marta", "fear") == 1.0 and (G.flags.dialogue.marta_nursery.history as Array).size() >= 6, "the conversation's consequences and history came back")
	load("res://scripts/core/save_game.gd").wipe()
	print("DIALOGUE ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
