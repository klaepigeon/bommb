extends SceneTree
## The systems that make more than one way through: carrying things between the flat and the
## town, a thrown axe on the padlock, Sonya's shoes and Marta, things staying where you left them
## across a save, and the Memory skills. godot --headless --path hysteria -s tools/systems_test.gd

var ok := true

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

func prop_titled(main: Node, t: String) -> RigidBody3D:
	for b in main.world.find_children("*", "RigidBody3D", true, false):
		if String(b.get("title")).to_lower() == t: return b
	return null

func in_hand(p: Node, b: RigidBody3D) -> void:
	b.global_position = p.hold.global_position; b.linear_velocity = Vector3.ZERO
	p.grab(b)

func _initialize() -> void:
	var SG = load("res://scripts/core/save_game.gd")
	SG.wipe()
	var main: Node = await fresh()
	var G: Node = root.get_node("Game")
	var p = main.player
	main.encounter.skip(); main.socko_intro.skip(); G.flags["socko_intro_done"] = true

	# ---- a thrown axe on the padlock
	var axe := prop_titled(main, "axe")
	var pl: Node3D = main.escape.padlock
	for i in 3:
		if main.escape.free: break
		axe.sleeping = false
		axe.global_transform = Transform3D(Basis(), pl.global_position + Vector3(-0.55, 0.02, 0.0))
		axe.linear_velocity = Vector3(9.0, 0.5, 0.0); axe.thrown_by = p
		for f in 40: await physics_frame
	check(main.escape._strike > 0.0, "the thrown axe strikes the padlock (%.1f)" % main.escape._strike)
	check(main.escape.free and G.flags.get("escaped_by", "") == "thrown", "hard enough, and it gives")

	# ---- carrying the hall's red shoe through the gap
	main.wardrobe.restore_pushed(); G.flags["wardrobe_pushed"] = true
	var shoe := prop_titled(main, "child's shoe")
	check(shoe != null, "the red shoe in the hall")
	p.global_position = Vector3(3.55, 0.02, 4.45); p.yaw = PI
	await physics_frame
	in_hand(p, shoe)
	for i in 10: await physics_frame
	var gap: Node = main.wardrobe.gap
	check(gap.use_with_prompt(shoe) != "", "with it in hand, the gap still offers the way through")
	gap.use_with(p, shoe)
	await create_timer(1.5).timeout
	check(main.in_labyrinth, "through")
	check(p.held == shoe and shoe.global_position.distance_to(p.hold.global_position) < 0.6, "still holding the shoe on the other side")
	check(main.labyrinth.is_ancestor_of(shoe), "it belongs to the town now (shows and hides with it)")

	# ---- Marta, and the shoe
	var h = main.hunter
	h.wake(Vector2i(1, 1))
	h.position = main.labyrinth.to_local(p.global_position) + Vector3(0, 0, -0.9)
	h._enter(h.S.CHASE)
	for i in 6: await process_frame
	check(h.state == h.S.CALM and h.shoes.size() == 1, "she reaches him with it in his hand, and takes the shoe instead")
	check(p.held == null and not p.locked, "he's not grabbed; the shoe's in her hands")
	check(G.flags.get("marta_shoes", 0) == 1, "remembered")
	Noise_check(h, p)
	main.escape._drained(true)
	var right_pick: Node = main.world.find_child("Child's shoe (right)", true, false)
	var right: RigidBody3D = main.save_game._loosen("Child's shoe (right)")
	check(right != null, "the other shoe, from the bath")
	h.take_shoe(right)
	check(h.at_peace and G.flags.get("marta_at_peace", false), "the pair: she's at peace")
	check(not h._path.is_empty(), "and goes to the nursery")

	# ---- the Memory skills
	G.flags["skills"] = {"these_streets": true, "how_she_moves": true}
	await process_frame
	check(main.memory._chalk.size() == 3 and main.memory._chalk[0].visible, "These Streets: the chalk circle shows")
	await process_frame; await process_frame
	check(main.memory._sense.playing, "How She Moves: the pressure in the ears")

	# ---- walking into things: a chair kicked out of the way; a door pushed open
	main.leave_labyrinth(Transform3D(Basis(), Vector3(3.55, 0, 4.5)))
	var chair := prop_titled(main, "chair")
	var cpos: Vector3 = chair.global_position
	p.global_position = Vector3(cpos.x, 0.02, cpos.z) + Vector3(0, 0, 1.1); p.yaw = 0.0; p.velocity = Vector3.ZERO
	await physics_frame
	Input.action_press("move_forward")
	for i in 90: await physics_frame
	Input.action_release("move_forward")
	check(chair.global_position.distance_to(cpos) > 0.3, "walking into a chair, he kicks it out of the way (%.2f m)" % chair.global_position.distance_to(cpos))
	var dchild: Node3D = main.world.find_child("door_dChild", true, false)
	dchild.target = 0.0; dchild.angle = 0.0; dchild.call("_apply")
	for i in 5: await physics_frame
	p.global_position = Vector3(5.65, 0.02, 4.55); p.yaw = PI; p.velocity = Vector3.ZERO
	await physics_frame
	Input.action_press("move_forward")
	for i in 60: await physics_frame
	Input.action_release("move_forward")
	check(float(dchild.target) > 0.5, "walking into a closed door, he pushes it open")
	# ---- things stay where you left them, across a save
	var bottle := prop_titled(main, "bottle of mineral water")
	main.leave_labyrinth(Transform3D(Basis(), Vector3(3.55, 0, 4.5)))
	bottle.global_position = Vector3(5.0, 0.3, 3.0); bottle.sleeping = true
	await process_frame
	check(main.save_game.save(), "saved")
	main = await fresh()
	check(main.save_game.load_game(), "loaded")
	await process_frame
	var b2 := prop_titled(main, "bottle of mineral water")
	check(b2 != null and b2.global_position.distance_to(Vector3(5.0, 0.3, 3.0)) < 0.2, "the bottle's where he put it")
	check(main.hunter.at_peace and main.hunter.shoes.size() == 2, "Marta still has both shoes, at peace")
	check(main.escape.free, "the chain's still off")
	SG.wipe()
	print("SYSTEMS ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)

## calm, she doesn't come for noise
func Noise_check(h: Node, p: Node) -> void:
	h.hear(p.global_position, 1.0, "gunshot", p)
	check(h.state == h.S.CALM, "calm, she doesn't come for a gunshot")
