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
			var errs0 := ErrorLog.inst.count if ErrorLog.inst else 0
			await call("t_" + s)
			var errs := (ErrorLog.inst.count if ErrorLog.inst else 0) - errs0
			ok(s + "_no_errors", errs == 0, "%d engine/script errors, last: %s" % [errs, ErrorLog.inst.last if ErrorLog.inst else ""])
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

# ---------------------------------------------------------------------------------- touch (Android)

var _touch_idx := {}

func touch(i: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i; e.position = pos; e.pressed = pressed
	Input.parse_input_event(e)
	_touch_idx[i] = pos

func drag(i: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i; e.position = pos
	var last: Vector2 = _touch_idx.get(i, pos)
	e.relative = pos - last
	e.screen_relative = e.relative
	Input.parse_input_event(e)
	_touch_idx[i] = pos

## drag in steps, a frame apart, like a real finger
func swipe(i: int, from: Vector2, to: Vector2, steps := 10) -> void:
	for k in range(1, steps + 1):
		drag(i, from.lerp(to, float(k) / steps))
		await get_tree().process_frame

func tap(pos: Vector2, i := 0) -> void:
	touch(i, pos, true)
	await frames(2)
	touch(i, pos, false)
	await frames(3)

## a real Button somewhere in the UI, found by its text, pressed with a touch
func tap_button(text: String) -> bool:
	for b in main.hud.root.find_children("*", "Button", true, false):
		var bt := b as Button
		if bt.is_visible_in_tree() and bt.text.strip_edges() == text:
			await tap(bt.get_global_rect().get_center())
			return true
	print("AUTOTEST note: no visible button '%s'" % text)
	return false

func t_touch() -> void:
	fresh()
	await start("flat47")
	await until(func(): return main.director.state == "explore", 30.0)
	await skip_speech()
	var hud = main.hud
	var p: Player = main.player
	var vp: Vector2 = hud.root.get_viewport_rect().size
	await place(Vector3(6.5, 0, 8.6), Vector3(6.5, 1.5, 5.0))
	# the first touch switches the HUD to touch mode
	await tap(Vector2(vp.x * 0.7, vp.y * 0.3))
	ok("touch_mode", hud.touch_mode, "HUD didn't switch to touch")
	ok("touch_buttons_shown", hud._buttons["use"].shown and hud._buttons["crouch"].shown, "buttons not shown")
	# stick: thumb down on the left, pushed up = walk forward
	var start_pos := p.global_position
	touch(0, Vector2(vp.x * 0.15, vp.y * 0.7), true)
	await swipe(0, Vector2(vp.x * 0.15, vp.y * 0.7), Vector2(vp.x * 0.15, vp.y * 0.7 - 60))
	ok("stick_input", p.move_input.y > 0.5, "move_input %s" % p.move_input)
	await wait(1.0)
	# and a second finger looking around at the same time
	var yaw0 := p.rotation.y
	touch(1, Vector2(vp.x * 0.7, vp.y * 0.5), true)
	await swipe(1, Vector2(vp.x * 0.7, vp.y * 0.5), Vector2(vp.x * 0.7 + 120, vp.y * 0.5))
	ok("look_with_second_finger", absf(wrapf(p.rotation.y - yaw0, -PI, PI)) > 0.1, "yaw moved %.3f" % (p.rotation.y - yaw0))
	ok("stick_still_held", p.move_input.y > 0.5, "the look finger broke the stick")
	touch(1, _touch_idx[1], false)
	touch(0, _touch_idx[0], false)
	await frames(3)
	ok("stick_moves_kurt", p.global_position.distance_to(start_pos) > 0.6, "moved %.2f" % p.global_position.distance_to(start_pos))
	ok("stick_release_stops", p.move_input == Vector2.ZERO, "still moving %s" % p.move_input)
	# crouch button
	var c0 := p.crouching
	await tap(hud._buttons["crouch"].center)
	ok("crouch_button", p.crouching != c0, "crouch didn't toggle")
	await tap(hud._buttons["crouch"].center)
	# Use button: the bathroom door
	var bd := door("bath_door")
	await place(door_from("bath_door", -1), bd.ifocus())
	await frames(4)
	await tap(hud._buttons["use"].center)
	await wait(0.8)
	ok("use_button", bd.open_k > 0.5, "door open_k %.2f; verbs %s" % [bd.open_k, p.verbs])
	# tap on the view also uses what's under the crosshair
	await place(door_from("bath_door", -1), bd.ifocus())
	await frames(4)
	await tap(Vector2(vp.x * 0.7, vp.y * 0.45))
	await wait(0.8)
	ok("tap_to_use", bd.is_closed(), "door open_k %.2f" % bd.open_k)
	# chips: the front door from inside offers the chain as a second action
	var fd := door("front_door")
	fd.close()
	await wait(0.6)
	await place(door_from("front_door", -1), fd.ifocus())
	await frames(6)
	ok("chips_shown", hud._chips.size() >= 1, "no chips; verbs %s" % [p.verbs])
	if hud._chips.size() >= 1:
		var chain0 := fd.chain_on
		await tap((hud._chips[0] as Control).get_global_rect().get_center())
		await frames(4)
		ok("chip_does_its_verb", fd.chain_on != chain0, "chain unchanged")
	# pause menu, by touch; its Resume is an ordinary Button pressed by a touch
	await tap(hud._buttons["pause"].center)
	ok("pause_opens", hud.pause.visible and get_tree().paused, "pause not open")
	await tap_button("Resume")
	await frames(3)
	ok("menu_by_touch", not hud.pause.visible and not get_tree().paused, "Resume didn't work by touch")
	# a thumb resting on the stick (finger 0) while another finger works the menu
	touch(0, Vector2(vp.x * 0.15, vp.y * 0.7), true)
	await frames(2)
	await tap(hud._buttons["pause"].center, 1)
	ok("pause_with_thumb_down", hud.pause.visible, "pause didn't open")
	for b in hud.root.find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree() and (b as Button).text.strip_edges() == "Resume":
			await tap((b as Button).get_global_rect().get_center(), 2)
	await frames(3)
	ok("menu_with_second_finger", not hud.pause.visible, "Resume didn't work with a second finger")
	touch(0, Vector2(vp.x * 0.15, vp.y * 0.7), false)
	await frames(2)
	# inventory
	await tap(hud._buttons["inv"].center)
	ok("inventory_opens", hud.inventory.visible, "no inventory")
	await tap_button("Close")
	await frames(3)
	ok("inventory_closes", not hud.inventory.visible and not get_tree().paused, "still open")
	# arranging the controls
	hud.set_edit_layout(true)
	var u0: Vector2 = hud._buttons["use"].center
	touch(7, u0, true)
	await swipe(7, u0, u0 - Vector2(150, 80))
	touch(7, _touch_idx[7], false)
	await frames(3)
	ok("layout_edit_moves_button", (Settings.get_v("layout") as Dictionary).has("use") and hud._buttons["use"].center.distance_to(u0) > 50.0, "button didn't move")
	hud.set_edit_layout(false)
	Settings.reset_layout()
	await frames(3)
	ok("layout_reset", hud._buttons["use"].center.distance_to(u0) < 2.0, "reset didn't restore")
	# phone shapes: a tall 20:9 phone and a 4:3 tablet; buttons stay on screen
	for sz in [Vector2i(1600, 720), Vector2i(960, 720)]:
		get_window().size = sz
		await frames(6)
		var r: Rect2 = hud.root.get_viewport_rect()
		var inside := true
		for id in hud._buttons:
			var b: Dictionary = hud._buttons[id]
			if not r.grow(1).has_point(b.center):
				inside = false
		ok("layout_fits_%dx%d" % [sz.x, sz.y], inside, "a button is off screen")
	get_window().size = Vector2i(1280, 720)
	_completed = "touch"
