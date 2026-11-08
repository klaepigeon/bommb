extends SceneTree
## Flat 48: the white blocks, the note wall, a wrong note that won't stay, a right one that makes
## the thing, GUN SAFE and the sawn-off in it, a figure shot, the reload, and all of it surviving
## a save. godot --headless --path hysteria -s tools/flat48_test.gd

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

func note(main: Node, word: String) -> Node:
	for n in main.flat48.get_children():
		if n.get("word") == word: return n
	return null

func block(main: Node, identity: String) -> Node:
	for b in main.flat48.blocks:
		if b.identity == identity: return b
	return null

func _initialize() -> void:
	var SG = load("res://scripts/core/save_game.gd")
	SG.wipe()
	var main: Node = await fresh()
	var G: Node = root.get_node("Game")
	var p = main.player
	main.encounter.skip(); main.socko_intro.skip(); G.flags["socko_intro_done"] = true; G.flags["chapter_1_done"] = true
	main.enter_flat48()
	await process_frame
	var f = main.flat48
	check(main.in_flat48 and f.visible and not main.world.get_node("Apartment").visible, "in Flat 48; 47 hidden")
	check(f.blocks.size() >= 30 and f.figures.size() == 3, "white blocks where 47's furniture is (%d), three figures" % f.blocks.size())
	check(p.global_position.distance_to(f.global_transform * f.spawn.origin) < 0.3, "standing inside its front door")
	# a wrong note
	note(main, "GUN SAFE").interact(p)
	await process_frame
	check(p.held != null and p.held.get_meta("identity") == "GUN SAFE", "a note off the wall, in hand")
	var sofa = block(main, "SOFA")
	check(sofa.use_with_prompt(p.held) == "Stick the note on it", "the sofa block offers to take it")
	var wrong = p.held
	sofa.use_with(p, wrong)
	check(sofa.real == null and p.held == null, "the wrong word won't stay on")
	# the right one
	note(main, "SOFA").interact(p)
	await process_frame
	sofa.use_with(p, p.held)
	await process_frame
	check(sofa.real != null and sofa.real.get_child_count() > 0, "SOFA: the block is 47's sofa now (%d meshes)" % (sofa.real.get_child_count() if sofa.real else 0))
	check(not sofa.mesh.visible, "the white block is gone")
	# the gun safe
	var safe = f.safe
	wrong.sleeping = false
	wrong.global_position = p.hold.global_position
	p.grab(wrong)
	safe.use_with(p, wrong)
	check(safe.real, "GUN SAFE: the block is a safe")
	safe.interact(p)
	check(safe.open, "it opens; it isn't locked")
	var gh = safe.get_node_or_null("GunHotspot")
	check(gh != null and gh.collision_layer == 1, "the shotgun's in it, within reach")
	gh.interact(p)
	await process_frame
	check(p.gun != null and p.gun.kind == "shotgun" and p.gun.drawn, "the sawn-off, in his hand")
	check(G.flags.get("has_shotgun", false) and main.armory.weapons.size() == 1, "carried")
	safe.get_node("ShellsHotspot").interact(p)
	check(p.gun.spare == 10, "the shells: ten (%d)" % p.gun.spare)
	# Papa, at the window
	var papa = f.figures[1]
	var at: Vector3 = papa.global_position + Vector3(0, 1.2, 0)
	p.global_position = papa.global_position + Vector3(0.0, 0.0, 2.2); await physics_frame
	var d: Vector3 = at - p.cam.global_position
	p.yaw = atan2(-d.x, -d.z); p.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	await process_frame; await process_frame
	p.gun.fire()
	check(papa.down and G.flags.get("f48_shot_papa", false), "a barrel at Papa: down, for good")
	check(p.gun.loaded == 1, "one barrel left")
	check(main.socko_48.said.has("shot1"), "Socko approves")
	p.gun.reload()
	await create_timer(1.6).timeout
	check(p.gun.loaded == 2 and p.gun.spare == 9 and not p.gun.reloading, "broken open, a shell in, shut")
	main.armory.cycle()
	check(not p.gun.drawn, "put away")
	main.armory.cycle()
	check(p.gun.drawn, "out again")
	# saved and loaded
	check(main.save_game.save(), "saved in Flat 48")
	main = await fresh()
	check(main.save_game.load_game(), "loaded")
	await process_frame
	f = main.flat48; p = main.player
	check(main.in_flat48, "back in Flat 48")
	check(block(main, "SOFA").real != null and f.safe.real and f.safe.open and f.safe.gun_taken, "the sofa, the safe, open and empty")
	check(p.gun != null and p.gun.kind == "shotgun" and p.gun.loaded == 2 and p.gun.spare == 9, "the shotgun, with what was left")
	check(f.figures[1].down and not f.figures[0].down, "Papa still down; Mama standing")
	check(note(main, "GUN SAFE") == null and note(main, "SOFA") == null and note(main, "BED") != null, "the notes he took are gone from the wall")
	SG.wipe()
	print("FLAT48 ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
