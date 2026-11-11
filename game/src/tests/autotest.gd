extends Node
## Automated play. Drives the real game through the player's own verbs (no shortcuts into the
## systems), so a pass means the thing works the way a player would do it.
##   --autotest=shots   --shots=DIR      a rendered tour of each level (needs a display: xvfb)
##   --autotest=scene_a                 the opening, from the knocks to the crawl
##   --autotest=routes                  every route through the Backrooms to Flat 48
##   --autotest=systems                 unit checks of the systems (doors, locks, props, power, nav, AI senses)
##   --autotest=all                     everything but the shots
## Prints "AUTOTEST PASS <name>" / "AUTOTEST FAIL <name>: why"; exits 0 only if all passed.

var main: Node
var failures: Array = []
var passes: Array = []
var shots_dir := ""
var _shot_n := 0
var _completed := ""

func begin(p_main: Node, which: String) -> void:
	main = p_main
	process_mode = Node.PROCESS_MODE_ALWAYS
	shots_dir = String(main.args.get("shots", ""))
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)
	await get_tree().process_frame
	var suites := ["systems", "scene_a", "routes"] if which == "all" else [which]
	for s in suites:
		if has_method("t_" + s):
			print("AUTOTEST begin ", s)
			_completed = ""
			await call("t_" + s)
			# a script error inside a suite stops it silently: catch that here
			ok(s + "_ran_to_end", _completed == s, "the suite stopped early (script error above?)")
		else:
			fail(s, "no such suite")
	print("AUTOTEST SUMMARY: %d passed, %d failed" % [passes.size(), failures.size()])
	for f in failures:
		print("AUTOTEST FAIL ", f)
	if failures.is_empty():
		print("AUTOTEST PASS all")
	get_tree().quit(0 if failures.is_empty() else 1)

func ok(name: String, cond: bool, why := "") -> bool:
	if cond:
		passes.append(name)
		print("AUTOTEST PASS ", name)
	else:
		fail(name, why)
	return cond

func fail(name: String, why: String) -> void:
	failures.append("%s: %s" % [name, why])
	print("AUTOTEST FAIL %s: %s" % [name, why])

func wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return cond.call()

func shot(name: String) -> void:
	if shots_dir == "":
		return
	await frames(4)
	var img := get_viewport().get_texture().get_image()
	_shot_n += 1
	img.save_png("%s/%02d_%s.png" % [shots_dir, _shot_n, name])

## put Kurt somewhere, looking at something
func place(pos: Vector3, look_at_point: Vector3) -> void:
	var p: Player = main.player
	p.global_position = pos
	p.velocity = Vector3.ZERO
	var d := look_at_point - (pos + Vector3(0, p._eye, 0))
	p.rotation.y = atan2(-d.x, -d.z)
	p._pitch = atan2(d.y, Vector2(d.x, d.z).length())
	p.head.rotation.x = p._pitch
	await frames(3)

## aim at a point and use the verb whose id matches (through the player's own focus)
func use_on(point: Vector3, verb_id: String, from := Vector3.INF) -> bool:
	var p: Player = main.player
	if from != Vector3.INF:
		await place(from, point)
	else:
		await place(p.global_position, point)
	await frames(3)
	for i in p.verbs.size():
		if String(p.verbs[i].id) == verb_id:
			var t := float(p.verbs[i].get("time", 0.0))
			p.begin_verb(i)
			if t > 0.0:
				await until(func(): return p._hold_verb.is_empty(), t + 3.0)
			await frames(2)
			return true
	print("AUTOTEST note: no verb '%s' at %s; have %s" % [verb_id, point, p.verbs.map(func(v): return v.id)])
	return false

func walk_to(target: Vector3, timeout := 12.0, run := false) -> bool:
	var p: Player = main.player
	var t := 0.0
	while t < timeout:
		var d := target - p.global_position
		d.y = 0
		if d.length() < 0.35:
			p.move_input = Vector2.ZERO
			p.running = false
			return true
		p.rotation.y = atan2(-d.x, -d.z)
		p.move_input = Vector2(0, 1)
		p.running = run
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	p.move_input = Vector2.ZERO
	return false

func skip_speech() -> void:
	await until(func(): return not Speech.busy(), 60.0)

# ---------------------------------------------------------------------------------- shots

## load a level the way the game does, wait until it's running
func start(level: String, spawn := "") -> void:
	await main.load_level(level, spawn)
	await until(func(): return main.level != null and main.director != null, 10.0)
	await frames(5)

func t_shots() -> void:
	await start("flat47")
	await wait(4.0)
	main.set_blackout(0.0)
	await shot("landing_front_door")
	var tour := [
		["entrance", Vector3(6.5, 0, 9.2), Vector3(6.5, 1.2, 6.0)],
		["corridor_west", Vector3(8.0, 0, 5.8), Vector3(0.5, 1.3, 5.8)],
		["living_marta", Vector3(2.5, 0, 4.6), Vector3(2.5, 0.9, 1.3)],
		["living_wardrobe", Vector3(3.5, 0, 2.6), Vector3(0.4, 1.0, 3.4)],
		["kitchen", Vector3(7.0, 0, 4.4), Vector3(7.0, 1.0, 0.3)],
		["bedroom", Vector3(10.3, 0, 4.4), Vector3(12.0, 0.8, 0.8)],
		["sonya", Vector3(4.3, 0, 7.2), Vector3(0.6, 0.7, 8.6)],
		["bathroom", Vector3(9.9, 0, 7.0), Vector3(8.4, 0.5, 9.2)],
		["boxroom", Vector3(11.8, 0, 6.9), Vector3(11.5, 0.6, 9.3)],
	]
	for t in tour:
		await place(t[1], t[2])
		await wait(0.5)
		await shot(t[0])
	var p: Player = main.player
	p.inv.add("torch")
	p.toggle_torch()
	await place(Vector3(9.9, 0, 7.0), Vector3(8.4, 0.5, 9.2))
	await shot("bathroom_torch")
	main.level.power.set_fuse("C", true)
	await wait(0.3)
	await shot("bathroom_fused")

# ---------------------------------------------------------------------------------- helpers

func fresh() -> void:
	Story.reset()
	Infection.reset()
	Speech.stop_all()
	get_tree().paused = false
	if main.player:
		main.player.inv = Inventory.new()
		main.player.injury = 0
		if main.player.gun:
			main.player.gun.queue_free()
			main.player.gun = null
		main.player.locked = false
		main.player.look_locked = false
		main.player.set_mode("normal")
		main.player.crouching = false

func node_named(n: String) -> Node:
	return main.level.find_child(n, true, false)

func prop_item(item: String) -> Prop:
	for p in get_tree().get_nodes_in_group("props"):
		if p is Prop and (p as Prop).item_id == item and main.level.is_ancestor_of(p):
			return p
	return null

func take_item(item: String) -> bool:
	var p := prop_item(item)
	if not p:
		print("AUTOTEST note: no prop for ", item)
		return false
	var at := p.global_position
	var from := at + Vector3(0.7, 0, 0.7)
	from.y = main.level.room_floor(main.level.room_at(at + Vector3(0, 0.5, 0)))
	# stand where the item's visible: try four sides
	for off in [Vector3(0.8, 0, 0), Vector3(-0.8, 0, 0), Vector3(0, 0, 0.8), Vector3(0, 0, -0.8)]:
		var f: Vector3 = Vector3(at.x, 0, at.z) + off
		f.y = from.y
		if await use_on(at, "take", f):
			return main.player.inv.has(item)
	return false

func door(id: String) -> Door:
	return main.level.doors.get(id)

func door_from(id: String, side: int) -> Vector3:
	var d := door(id)
	var p := d.global_position + d.global_transform.basis.z * 0.75 * side
	p.y = d.global_position.y
	return p

# ---------------------------------------------------------------------------------- systems

func t_systems() -> void:
	await start("flat47")
	await until(func(): return main.director.state == "explore", 30.0)
	await skip_speech()
	fresh()
	var p: Player = main.player
	var lvl: Level = main.level
	p.inv.add("telegram")
	# doors: open and close
	var bd := door("bath_door")
	await use_on(bd.ifocus(), "toggle", door_from("bath_door", -1))
	await wait(0.8)
	ok("door_opens", bd.open_k > 0.8, "open_k %.2f" % bd.open_k)
	await use_on(bd.ifocus(), "toggle", door_from("bath_door", -1))
	await wait(0.8)
	ok("door_closes", bd.is_closed(), "open_k %.2f" % bd.open_k)
	# a bolt only works from its side
	await use_on(bd.ifocus(), "bolt", door_from("bath_door", 1))
	ok("bolt_from_inside", bd.bolt_on, "bolt not on")
	var tried := []
	bd.tried.connect(func(_d, why): tried.append(why))
	await use_on(bd.ifocus(), "toggle", door_from("bath_door", -1))
	ok("bolted_from_outside", bd.is_closed() and "bolted" in tried, "tried %s" % [tried])
	await use_on(bd.ifocus(), "bolt", door_from("bath_door", 1))
	# keys and locks: lock the front door with the keys, try it from outside, unlock
	p.inv.add("key_flat47")
	var fd := door("front_door")
	fd.close()
	await wait(0.8)
	await use_on(fd.ifocus(), "lock", door_from("front_door", -1))
	ok("lock_with_key", fd.locked, "not locked")
	p.inv.remove("key_flat47")
	await use_on(fd.ifocus(), "toggle", door_from("front_door", 1))
	ok("locked_holds", fd.is_closed(), "it opened")
	p.inv.add("hairpin")
	await use_on(fd.ifocus(), "pick", door_from("front_door", 1))
	ok("pick_lock", not fd.locked, "still locked")
	# the chain: put on from inside, from outside the door opens a hand's width
	await use_on(fd.ifocus(), "chain", door_from("front_door", -1))
	ok("chain_on", fd.chain_on, "no chain")
	await use_on(fd.ifocus(), "toggle", door_from("front_door", 1))
	await wait(0.6)
	ok("chain_holds", fd.open_k > 0.05 and fd.open_k < 0.2, "open_k %.2f" % fd.open_k)
	# drawers and what's in them
	var torch := prop_item("torch")
	var drawer_pos := torch.global_position + Vector3(0.2, 0.05, 0)
	p.crouching = true
	await wait(0.4)
	await use_on(drawer_pos, "open", Vector3(6.1, 0, 9.5))
	await wait(0.6)
	ok("drawer_take", await take_item("torch"), "torch not taken")
	p.crouching = false
	# pick up, throw: the landing makes a noise that carries
	var heard := []
	var cb := func(pos, r, kind, _src): heard.append([kind, r])
	Events.noise.connect(cb)
	var cup := lvl.find_children("cup", "Prop", true, false)[0] as Prop
	var cf := Vector3(cup.global_position.x + 0.7, 0, cup.global_position.z + 0.7)
	if not await use_on(cup.global_position, "hold", cf):
		await use_on(cup.global_position, "hold", Vector3(cup.global_position.x - 0.7, 0, cup.global_position.z + 0.7))
	ok("hold", p.held != null, "not holding")
	p.throw()
	await wait(1.5)
	Events.noise.disconnect(cb)
	ok("throw_noise", heard.any(func(h): return h[0] in ["impact", "break"]), "heard %s" % [heard])
	# heavy things get pushed
	var arm := lvl.find_children("Armchair", "Prop", true, false)[0] as Prop
	var a0 := arm.global_position
	await use_on(arm.global_position + Vector3(0, 0.4, 0), "pull", Vector3(arm.global_position.x - 1.2, 0, arm.global_position.z))
	await wait(0.6)
	ok("pull_heavy", arm.global_position.distance_to(a0) > 0.15, "moved %.2f" % arm.global_position.distance_to(a0))
	# electricity: the bathroom's fuse
	ok("bath_dark", not lvl.power.room_lit("bathroom"), "lit already")
	p.inv.add("fuse")
	await use_on(Vector3(7.9, 1.6, 7.4), "fuse:C", Vector3(7.1, 0, 7.4))
	ok("fuse_fixes_light", lvl.power.room_lit("bathroom"), "still dark")
	# hiding
	var hs: Node = null
	for h in lvl.hides:
		if h.spot_id == "wardrobe_bedroom": hs = h
	var hfrom: Vector3 = (hs as Node3D).global_transform * (hs.exit_pos as Vector3)
	hfrom.y = 0.0
	await use_on((hs as Node3D).global_position + Vector3(0, -0.6, 0), "hide", hfrom)
	await wait(0.6)
	ok("hide", p.is_hidden(), "not hidden; verbs %s" % [p.verbs])
	p.unhide()
	ok("unhide", not p.is_hidden(), "still hidden")
	# breakables: the boards over Sonya's window, with a hammer
	p.inv.add("hammer")
	var boards: Node = null
	for b in lvl.breakables:
		if b.break_id == "sonya_window_boards": boards = b
	await use_on((boards as Node3D).global_position, "strike", Vector3(2.5, 0, 9.0))
	ok("smash_boards", boards.done, "boards still there")
	# save / load: a moved armchair, an open drawer, the inventory, the ledger
	var arm_pos := arm.global_position
	var saved := SaveGame.save_game(main, "test")
	ok("save", saved, "save failed")
	p.inv.remove("hammer")
	arm.global_position += Vector3(1, 0, 0)
	await SaveGame.load_game(main)
	await frames(10)
	var arm2 := main.level.find_children("Armchair", "Prop", true, false)[0] as Prop
	ok("load_inventory", main.player.inv.has("hammer") and main.player.inv.has("torch"), "inv %s" % [main.player.inv.list()])
	ok("load_object_state", arm2.global_position.distance_to(arm_pos) < 0.2 and main.level.doors["front_door"].chain_on, "armchair %.2f off" % arm2.global_position.distance_to(arm_pos))
	ok("load_power", main.level.power.room_lit("bathroom"), "bathroom dark after load")
	_completed = "systems"
