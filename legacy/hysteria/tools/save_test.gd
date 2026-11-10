extends SceneTree
## Save and continue: play a little way in, save, throw the scene away, build a new one, load,
## and check the world came back as it was left. godot --headless --path hysteria -s tools/save_test.gd

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
	return main

func _initialize() -> void:
	var SG = load("res://scripts/core/save_game.gd")
	SG.wipe()
	var main: Node = await fresh()
	var G: Node = root.get_node("Game")
	check(not main.save_game.save(), "no saving before Socko")
	# play a little way in: the opening done, the wardrobe pushed, a nugget, the bath half drained,
	# the revolver, Marta dead, a line said; then into the labyrinth
	main.encounter.skip(); main.socko_intro.skip(); G.flags["woke_in_47"] = true; G.flags["socko_intro_done"] = true
	main.wardrobe.restore_pushed(); G.flags["wardrobe_pushed"] = true
	main.world.get_node("NuggetF2").take()
	main.labyrinth.get_node("NuggetL5").take()
	main.escape.pull_plug(); main.escape._level = 0.3
	main.enter_labyrinth()
	for n in main.labyrinth.find_children("*", "StaticBody3D", true, false):
		if n.get_script() and String(n.get_script().resource_path).ends_with("revolver_pickup.gd"): n.interact(main.player)
	main.player.gun.loaded = 2; main.player.gun.spare = 4
	main.hunter.wake(); main.hunter._die()
	main.socko_lab.said["gun"] = true
	var spot: Vector3 = main.labyrinth.to_global(Vector3(26.0, 0.0, 9.0))
	main.player.global_position = spot; main.player.yaw = 1.0
	await process_frame
	check(main.save_game.save(), "saved")
	check(SG.exists(), "the slot is on disk")

	main = await fresh()
	check(not G.flags.get("socko_intro_done", false), "a fresh scene knows nothing")
	check(main.save_game.load_game(), "loaded")
	await process_frame; await process_frame
	var p = main.player
	check(G.flags.get("socko_intro_done", false) and main.socko.visible, "Socko's on the hand")
	check(p.torch_holder == main.socko, "the light comes out of his mouth")
	check(main.encounter.state_name() == "AWAKE", "the opening doesn't replay")
	check(main.wardrobe.pushed, "the wardrobe's pushed aside")
	check(main.world.get_node_or_null("NuggetF2") == null and main.labyrinth.get_node_or_null("NuggetL5") == null, "taken nuggets stay taken")
	check(main.world.get_node_or_null("NuggetF3") != null, "the others are still there")
	check(Skills.nuggets() == 2, "two nuggets in the pocket (%d)" % Skills.nuggets())
	check(main.escape.draining and absf(main.escape._level - 0.3) < 0.01, "the bath carries on draining from where it was")
	check(p.gun != null and p.gun.loaded == 2 and p.gun.spare == 4, "the revolver, with what was left in it")
	check(main.hunter.state == main.hunter.S.DEAD, "Marta stays dead")
	check(main.socko_lab.said.has("gun"), "Socko doesn't repeat himself")
	check(main.in_labyrinth and p.global_position.distance_to(spot) < 0.3, "back where he stood, behind the wardrobe")
	SG.wipe()
	check(not SG.exists(), "developer reset wipes the slot")
	print("SAVE ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
