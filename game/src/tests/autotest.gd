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
	var suites := ["systems", "touch", "scene_a", "routes", "ai", "stealth", "soak"] if which == "all" else [which]
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
	var cam := p.camera
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_transform.basis.z * 2.2, 0xFFFF)
	q.exclude = [p.get_rid()]
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	print("AUTOTEST note: no verb '%s' at %s; have %s; kurt %s cam %s mode %s; ray hit %s" % [verb_id, point, p.verbs.map(func(v): return v.id), p.global_position, cam.global_position, p.mode, (str(hit.collider.name) + " in " + str(hit.collider.get_parent().name)) if hit else "nothing"])
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

func t_shots_ground() -> void:
	await ground(true)
	var su: SuperHunter = main.director.super_
	su.reset_to(Vector3(6.0, 0, 9.0)); su.set_state("patrol")
	await wait(2.5)
	main.set_blackout(0.0)
	for t in [["lobby_super", Vector3(6.0, 0, 12.6)], ["super_close", su.global_position + Vector3(0.4, 0, 2.6)], ["corridor_13", Vector3(14.0, 0, 9.0)]]:
		su.velocity = Vector3.ZERO
		await place(t[1], su.eye() - Vector3(0, 0.9, 0) if t[0] != "corridor_13" else Vector3(26.5, 1.4, 8.0))
		await wait(0.4)
		await shot(t[0])
	main.player.inv.add("torch"); main.player.toggle_torch()
	await place(su.global_position + Vector3(0.0, 0, 2.2), su.eye() - Vector3(0, 0.9, 0))
	await wait(0.3)
	await shot("super_torch")

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

## the HUD works in game (viewport) coordinates; Android delivers screen pixels, which the engine
## scales. Inject what Android would send.
func _to_screen(pos: Vector2) -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return pos * Vector2(get_window().size) / vp

func touch(i: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i; e.position = _to_screen(pos); e.pressed = pressed
	Input.parse_input_event(e)
	_touch_idx[i] = pos

func drag(i: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i; e.position = _to_screen(pos)
	var last: Vector2 = _touch_idx.get(i, pos)
	e.relative = _to_screen(pos) - _to_screen(last)
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

# ---------------------------------------------------------------------------------- scene A

func t_scene_a() -> void:
	fresh()
	await start("flat47")
	var d: Node = main.director
	var p: Player = main.player
	ok("intro_runs", await until(func(): return d.state == "explore", 40.0), "state %s" % d.state)
	ok("intro_lines", Story.play_time > 0.0, "")
	await place(Vector3(2.5, 0, 4.4), Vector3(2.5, 1.1, 1.3))
	ok("sees_marta", await until(func(): return d.state == "seen", 3.0), "state %s" % d.state)
	await skip_speech()
	ok("examine", await use_on(Vector3(2.5, 1.0, 1.3), "examine", Vector3(3.3, 0, 2.95)), "no examine verb")
	ok("wakes", await until(func(): return d.state == "awake", 90.0), "state %s" % d.state)
	ok("socko_appears", p.socko.visible and SockoDirector.inst.awake, "no Socko")
	ok("player_has_control", not p.locked and p.mode == "normal", "locked %s mode %s" % [p.locked, p.mode])
	# the door he came through won't open
	await use_on(door("living_door").ifocus(), "toggle", door_from("living_door", -1))
	ok("door_wont_open", await until(func(): return d._tried_door, 3.0) and door("living_door").is_closed(), "")
	await skip_speech()
	# the balcony: a sticky note where the world should be
	await use_on(door("balcony_door").ifocus(), "toggle", door_from("balcony_door", 1))
	await wait(0.8)
	await place(Vector3(2.5, 0, -0.7), Vector3(2.5, 1.4, -2.4))
	ok("balcony_scene", await until(func(): return d._balcony_done, 3.0), "")
	await skip_speech()
	# the wardrobe: shove it along the wall
	var w: Prop = d.wardrobe
	for i in 5:
		if d.state == "revealed": break
		await use_on(w.global_position + Vector3(0, 1.0, 0), "push", Vector3(0.45, 0, w.global_position.z - 1.1))
		await place(Vector3(1.6, 0, 2.6), Vector3(0.0, 0.7, 3.4))
		await wait(0.5)
	ok("wardrobe_reveals", await until(func(): return d.state == "revealed", 8.0), "wardrobe moved %.2f" % w.global_position.distance_to(d._wardrobe_start))
	await skip_speech()
	await use_on(Vector3(0.0, 0.7, 3.4), "crawl", Vector3(0.9, 0, 3.4))
	ok("crawl_to_backrooms", await until(func(): return main.level != null and main.level.level_name == "backrooms" and main.director != null, 15.0), "level %s" % (main.level.level_name if main.level else "none"))
	ok("backrooms_from_flat47_inventory", main.player.inv.has("telegram"), "inventory lost")
	await skip_speech()
	_completed = "scene_a"

# ---------------------------------------------------------------------------------- routes

func backrooms(quiet := true) -> void:
	fresh()
	await main.load_level("backrooms", "arrival")
	await until(func(): return main.director != null, 10.0)
	if quiet:
		main.director.encounter_done = true       # she stays where she is: these are route tests
	await until(func(): return not main.player.locked and not main.player.crouching, 10.0)
	await wait(0.5)
	await skip_speech()

func open_container_of(item: String) -> bool:
	var pr := prop_item(item)
	if not pr:
		return false
	var n: Node = pr.get_parent()
	while n and not (n is Fixtures.Drawer) and not (n is Door) and n != main.level:
		n = n.get_parent()
	var p: Player = main.player
	if n is Fixtures.Drawer:
		var dr := n as Fixtures.Drawer
		var front := -dr.global_transform.basis.z
		var stand := dr.global_position + front * 0.8
		stand.y = main.level.room_floor(main.level.room_at(dr.global_position + Vector3(0, 0.3, 0)))
		p.crouching = true
		await wait(0.4)
		return await use_on(dr.ifocus(), "open", stand)
	# loose in a cupboard / wardrobe: open the nearest cabinet door to it
	var best: Door = null
	var bd := INF
	for dd in main.level.find_children("Cab_*", "Node3D", true, false):
		var dist := (dd as Node3D).global_position.distance_to(pr.global_position)
		if dist < bd: bd = dist; best = dd
	if best and bd < 1.5:
		var stand: Vector3 = best.global_position + best.global_transform.basis.z * 0.9 * best.swing
		stand.y = main.level.room_floor(main.level.room_at(best.global_position + Vector3(0, 0.3, 0)))
		if best.height < 1.0:
			p.crouching = true
			await wait(0.4)
		return await use_on(best.ifocus(), "toggle", stand)
	return true

## every way out of the maze: down the stairs and in through the building's front door
func to_ground(name: String, route_flag: String) -> void:
	ok("out_" + name, await until(func(): return main.level != null and main.level.level_name == "ground_floor" and main.director != null, 20.0), "level %s" % (main.level.level_name if main.level else "none"))
	ok("route_recorded_" + name, String(Story.flag("route_out", "")).begins_with(route_flag), "route_out = %s" % Story.flag("route_out", ""))
	await until(func(): return not main.player.locked, 10.0)
	ok("walked_in_" + name, main.level.room_at(main.player.global_position + Vector3(0, 1, 0)) == "vestibule", "at %s" % main.player.global_position)
	await skip_speech()

func t_routes() -> void:
	var p: Player
	# --- 1. the key: kitchen B's drawer (circuit C off first: the water's live), the box room, the jar, the padlock
	await backrooms()
	p = main.player
	await use_on(Vector3(7.9, 1.6, 7.4), "brk:C", Vector3(7.1, 0, 7.4))
	ok("route_key_power_off", not main.level.power.is_live("C"), "C still live")
	await open_container_of("key_storage")
	await wait(0.6)
	ok("route_key_storage_key", await take_item("key_storage"), "no storage key")
	p.crouching = false
	await use_on(door("b_box").ifocus(), "unlock", door_from("b_box", -1))
	await wait(0.6)
	ok("route_key_box_open", not door("b_box").locked, "box room still locked")
	var jar: Prop = null
	for x in get_tree().get_nodes_in_group("props"):
		if x is Prop and (x as Prop).persist_id == "key_jar": jar = x
	await use_on(jar.global_position, "hold", Vector3(12.1, 0, jar.global_position.z))
	ok("route_key_hold_jar", p.held == jar, "not holding the jar")
	p._pitch = deg_to_rad(-60); p.head.rotation.x = p._pitch
	await frames(2)
	p.throw()
	await wait(1.5)
	ok("route_key_jar_breaks", prop_item("key_padlock") != null, "no key fell out")
	ok("route_key_padlock_key", await take_item("key_padlock"), "couldn't take it")
	await _through_front_door()
	var lock = door("flat48_door").padlock
	await use_on((lock as Node3D).global_position, "unlock", Vector3(7.2, 0, 11.6))
	ok("route_key_unlocks", not lock.is_locked(), "padlock still locked")
	await _into_48()
	await to_ground("door_key", "door:key")
	# --- 2. the bolt cutters (quiet)
	await backrooms()
	p = main.player
	await open_container_of("bolt_cutters")
	await wait(0.6)
	ok("route_cut_cutters", await take_item("bolt_cutters"), "no cutters")
	p.crouching = false
	await _through_front_door()
	lock = door("flat48_door").padlock
	await use_on((lock as Node3D).global_position, "cut", Vector3(7.2, 0, 11.6))
	ok("route_cut_padlock", not lock.is_locked(), "padlock still locked")
	await _into_48()
	await to_ground("door_cut", "door:cut")
	# --- 3. the gun (loud)
	await backrooms()
	p = main.player
	ok("route_gun_take", await take_item("revolver"), "couldn't take the revolver")
	await skip_speech()
	ok("route_gun_given", p.gun != null and p.gun.loaded == 2, "gun %s" % p.gun)
	p.gun.toggle_equip()
	await _through_front_door()
	lock = door("flat48_door").padlock
	var heard := []
	var cb := func(_pos, r, kind, _s): if kind == "gunshot": heard.append(r)
	Events.noise.connect(cb)
	await place(Vector3(7.0, 0, 11.6), (lock as Node3D).global_position)
	p.gun.set_aim(true)
	await wait(0.3)
	p.gun.fire()
	await wait(0.3)
	Events.noise.disconnect(cb)
	ok("route_gun_shot_lock", not lock.is_locked(), "padlock survived")
	ok("route_gun_noise", not heard.is_empty() and heard[0] >= 25.0, "gunshot noise %s" % [heard])
	ok("route_gun_ammo_spent", p.gun.loaded == 1, "loaded %d" % p.gun.loaded)
	await _into_48()
	await to_ground("door_shot", "door:shot")
	# --- 4. the vent (unscrew the panel, crawl)
	await backrooms()
	p = main.player
	p.inv.add("screwdriver")
	var vent: Node = null
	for b in main.level.breakables:
		if b.break_id == "vent": vent = b
	await use_on((vent as Node3D).global_position, "unscrew", Vector3(9.6, 0, 9.2))
	ok("route_vent_panel_off", vent.done, "panel still on")
	await use_on((vent as Node3D).global_position, "crawl", Vector3(9.6, 0, 9.3))
	await to_ground("vent", "vent")
	# --- 5. the plank across to 48's balcony
	await backrooms()
	p = main.player
	var plank: Prop = main.director._plank
	await use_on(door("b_living2").ifocus(), "toggle", door_from("b_living2", -1))
	await use_on(door("b_balcony").ifocus(), "toggle", Vector3(15.5, 0, 10.3))
	await wait(0.6)
	await use_on(plank.global_position, "hold", Vector3(plank.global_position.x, 0, 9.6))
	ok("route_plank_hold", p.held == plank, "not holding the plank")
	# carry it, walking, out through the balcony door
	for wp in [Vector3(15.5, 0, 9.9), Vector3(15.5, 0, 10.5), Vector3(15.5, 0, 12.0)]:
		await walk_to(wp, 10.0)
	ok("route_plank_carried", p.held == plank and p.global_position.z > 11.5, "held %s at %s" % [p.held, p.global_position])
	p.rotation.y = PI          # facing south, over the gap
	await wait(0.8)
	p.drop()
	ok("route_plank_bridge", await until(func(): return main.director.bridged, 4.0), "plank at %s" % plank.global_position)
	await wait(0.5)
	await walk_to(Vector3(15.5, 0, 14.5), 8.0)
	ok("route_plank_walk", main.level.level_name == "ground_floor" or Story.has("route.balcony"), "couldn't cross; at %s" % p.global_position)
	await to_ground("balcony", "balcony")
	_completed = "routes"

func _through_front_door() -> void:
	var fd := door("b_front")
	await use_on(fd.ifocus(), "chain", door_from("b_front", -1))
	await use_on(fd.ifocus(), "toggle", door_from("b_front", -1))
	await wait(0.8)
	await place(Vector3(6.5, 0, 11.0), Vector3(8.0, 1.2, 11.6))

func _into_48() -> void:
	var d := door("flat48_door")
	await use_on(d.ifocus(), "toggle", Vector3(7.2, 0, 11.6))
	await wait(0.9)
	ok("door48_opens", d.open_k > 0.5, "open_k %.2f; verbs %s" % [d.open_k, main.player.verbs])
	await place(Vector3(8.6, 0, 11.6), Vector3(10, 1.2, 11.6))

# ---------------------------------------------------------------------------------- AI

func t_ai() -> void:
	await backrooms(false)
	var p: Player = main.player
	var m: MartaHunter = main.director.marta
	# the encounter: she's at the far end of the corridor, Kurt sees her
	await place(Vector3(3.0, 0, 5.8), Vector3(21.0, 1.3, 5.8))
	await wait(0.5)
	await place(Vector3(14.0, 0, 5.8), Vector3(21.0, 1.3, 5.8))
	main.level.trigger_entered.emit("corridor_first")
	ok("ai_encounter", await until(func(): return main.director.encounter_done, 3.0), "no encounter")
	ok("ai_wakes", await until(func(): return m.state != "dormant", 30.0), "still dormant")
	# a quiet noise behind closed doors goes unheard; a gunshot is heard
	m.reset_to(Vector3(7.0, 0, 2.6))
	m.suspicion = 0.0
	m.set_state("patrol")
	m._ids = PackedInt64Array()
	await place(Vector3(2.5, 0, 8.3), Vector3(2.5, 1.2, 6.0))       # Sonya's room, door shut
	door("b_sonya").close(); door("b_kitchen_a").close()
	await wait(0.6)
	m.suspicion = 0.0
	Events.noise.emit(p.global_position, 4.5, "footstep", p)
	await frames(2)
	ok("ai_no_hearing_through_walls", m.suspicion < 0.2 and m.state != "investigate", "suspicion %.2f state %s" % [m.suspicion, m.state])
	Events.noise.emit(p.global_position, 30.0, "gunshot", p)
	await frames(2)
	ok("ai_hears_gunshot", m.state == "investigate" or m.state == "chase", "state %s" % m.state)
	# sight: lit and in the open, she sees him; crouched in the dark, at the same distance, she doesn't
	m.reset_to(Vector3(4.0, 0, 5.8)); m.set_state("patrol"); m.suspicion = 0.0
	m.rotation.y = -PI * 0.5; m._yaw = m.rotation.y           # facing east
	await place(Vector3(10.0, 0, 5.8), Vector3(4.0, 1.4, 5.8))
	p.crouching = false
	m._ids = PackedInt64Array(); m.velocity = Vector3.ZERO
	ok("ai_sees_in_light", m._visibility() > 0.0, "she can't see him in the lit corridor")
	main.level.power.set_live("A", false)
	p.crouching = true
	await wait(0.5)
	ok("ai_blind_in_dark", m._visibility() == 0.0, "visibility %.2f in the dark" % m._visibility())
	main.level.power.set_live("A", true)
	p.crouching = false
	# a chase, and a catch: injury, she goes elsewhere, Kurt wakes up
	var inj0 := p.injury
	m.reset_to(p.global_position + Vector3(-0.8, 0, 0))
	m._start_chase()
	ok("ai_catches", await until(func(): return Story.count("caught") >= 1, 5.0), "never caught")
	ok("ai_caught_hurts", await until(func(): return p.injury > inj0 and not p.locked, 10.0), "injury %d locked %s" % [p.injury, p.locked])
	await skip_speech()
	# a bolted door: she can't open it, she pounds it, it gives
	var ad := door("b_arrival")
	await place(Vector3(2.5, 0, 3.8), Vector3(2.5, 1.0, 5.0))
	ad.close()
	await wait(0.5)
	await use_on(ad.ifocus(), "bolt", door_from("b_arrival", -1))
	ok("ai_bolt_on", ad.bolt_on, "no bolt")
	door("b_side").close(); door("b_side").locked = true       # (or she just goes round through the kitchen)
	door("b_side").state_changed.emit(door("b_side"))
	m.reset_to(Vector3(2.5, 0, 6.0))
	m._start_chase()
	m.last_known = p.global_position
	m._repath = 0.0
	ok("ai_pounds_secured_door", await until(func(): return m.state == "pound", 6.0), "state %s at %s pound_door %s ids %d last_known %s grace %.1f door at %s secured %s" % [m.state, m.global_position, m._pound_door, m._ids.size(), m.last_known, m._grace, ad.global_position, main.level.ai_secured(ad)])
	var hp0 := ad.hp
	await wait(3.0)
	ok("ai_pounding_damages", ad.hp < hp0, "door hp %.0f" % ad.hp)
	# distraction: the radio, switched on in another room; she goes and silences it
	m.reset_to(Vector3(12.0, 0, 5.8)); m.set_state("patrol"); m.suspicion = 0.0
	await place(Vector3(14.0, 0, 9.0), Vector3(15.5, 1.0, 8.8))
	var radio: Prop = null
	for x in get_tree().get_nodes_in_group("props"):
		if x is Prop and x.name == "radio": radio = x
	radio.behaviour.set_on(true)
	ok("ai_goes_to_radio", await until(func(): return m.state == "investigate", 6.0), "state %s" % m.state)
	ok("ai_silences_radio", await until(func(): return not radio.behaviour.on, 30.0), "radio still on; she's %s at %s" % [m.state, m.global_position])
	# the music box: she stops, and sits
	m.reset_to(Vector3(12.0, 0, 5.8)); m._start_chase()
	p.inv.add("music_box")
	await place(Vector3(6.0, 0, 5.8), Vector3(12.0, 1.2, 5.8))
	p.use_item("music_box")
	ok("ai_pacified", await until(func(): return m.state == "pacified", 5.0), "state %s" % m.state)
	ok("ai_pacified_recorded", Story.has("stealth.pacified"), "")
	# the gun: shot, she staggers, then pulls back; shot enough, she dies
	main.director.give_gun(false)
	p.inv.add("ammo", 5)
	p.gun.loaded = 7
	p.gun.toggle_equip()
	m.reset_to(Vector3(10.0, 0, 5.8)); m._start_chase()
	m.velocity = Vector3.ZERO
	await place(Vector3(6.0, 0, 5.8), m.global_position + Vector3(0, 0.9, 0))
	p.gun.set_aim(true)
	await wait(0.3)
	await place(Vector3(6.0, 0, 5.8), m.global_position + Vector3(0, 0.9, 0))
	p.gun.fire()
	await frames(3)
	ok("ai_shot_stuns", m.state == "stunned" and m.hp < 100.0, "state %s hp %.0f" % [m.state, m.hp])
	ok("ai_shot_recorded", Story.has("violence.shot_marta"), "")
	for i in 6:
		if m.state == "dead": break
		await wait(0.8)
		await place(Vector3(6.0, 0, 5.8), m.global_position + Vector3(0, 0.9, 0))
		p.gun.fire()
		await frames(3)
	ok("ai_can_die", m.state == "dead" and Story.has("violence.killed_marta"), "state %s hp %.0f" % [m.state, m.hp])
	ok("ai_killing_infects", Infection.level > 0.2, "infection %.2f" % Infection.level)
	_completed = "ai"

# ---------------------------------------------------------------------------------- soak (crash safety)

## random thumbs on the glass for a while in every level, Marta hunting: nothing may error
func t_soak() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 47
	for lv in ["flat47", "backrooms", "ground_floor"]:
		fresh()
		if lv == "backrooms":
			await main.load_level("backrooms", "arrival")
			await until(func(): return main.director != null, 10.0)
			main.director.marta.wake()
			main.director.give_gun(false)
			main.player.inv.add("ammo", 3)
		elif lv == "ground_floor":
			await main.load_level("ground_floor", "entrance")
		else:
			await start("flat47")
		var vp: Vector2 = main.hud.root.get_viewport_rect().size
		var t := 0.0
		while t < 25.0:
			var r := rng.randf()
			if r < 0.35:
				touch(0, Vector2(vp.x * 0.15, vp.y * 0.7), true)
				await swipe(0, Vector2(vp.x * 0.15, vp.y * 0.7), Vector2(vp.x * 0.15, vp.y * 0.7) + Vector2(rng.randf_range(-80, 80), rng.randf_range(-80, 80)), 6)
				touch(0, _touch_idx[0], false)
			elif r < 0.6:
				touch(1, Vector2(vp.x * 0.7, vp.y * 0.5), true)
				await swipe(1, Vector2(vp.x * 0.7, vp.y * 0.5), Vector2(vp.x * 0.7 + rng.randf_range(-200, 200), vp.y * 0.5 + rng.randf_range(-60, 60)), 6)
				touch(1, _touch_idx[1], false)
			elif r < 0.85:
				var ids: Array = main.hud._buttons.keys()
				var id: String = ids[rng.randi() % ids.size()]
				if main.hud._buttons[id].shown and id != "pause" and id != "inv":
					await tap(main.hud._buttons[id].center, 2)
			else:
				await tap(Vector2(vp.x * rng.randf_range(0.5, 0.95), vp.y * rng.randf_range(0.2, 0.8)), 3)
			if get_tree().paused:
				main.hud.close_all()
			await frames(2)
			t += 0.12
		ok("soak_" + lv, true)
	_completed = "soak"

# ---------------------------------------------------------------------------------- the ground floor (stealth)

func ground(quiet := true) -> void:
	fresh()
	Story.set_flag("route_out", "test")
	await main.load_level("ground_floor", "entrance")
	await until(func(): return main.director != null and not main.player.locked, 10.0)
	await skip_speech()
	if quiet:
		main.director.super_.set_state("dormant")
		main.director.super_.velocity = Vector3.ZERO

func t_stealth() -> void:
	# --- walking in; Socko already knows it's 13; the Super is up and about
	await ground(false)
	var p: Player = main.player
	var su: SuperHunter = main.director.super_
	ok("gf_walk_in", main.level.room_at(p.global_position + Vector3(0, 1, 0)) == "vestibule", "at %s" % p.global_position)
	ok("gf_street_door_shut", main.level.doors["street_door"].is_closed(), "street door open")
	ok("gf_knows_13", Story.flag("knows_13", false), "Socko doesn't know 13")
	ok("gf_super_awake", await until(func(): return su.state != "dormant", 5.0), "the Super never woke")
	ok("gf_super_body", su.rig != null and su.rig.skel != null, "no rig")
	# he moves (his skin, and the rest, swing with it)
	var p0 := su.global_position
	await wait(3.0)
	ok("gf_super_patrols", su.global_position.distance_to(p0) > 0.5, "he hasn't moved")
	# seeing him: Kurt's line
	su.reset_to(Vector3(6.0, 0, 9.0)); su.set_state("dormant"); su.velocity = Vector3.ZERO
	await place(Vector3(6.0, 0, 12.5), su.eye() - Vector3(0, 0.6, 0))
	ok("gf_sees_super", await until(func(): return main.director.seen_super, 3.0), "no sighting")
	await skip_speech()
	# he hears better than he sees: a footstep across the lobby, in the dark, carries to him
	su.set_state("patrol"); su.suspicion = 0.0; su._ids = PackedInt64Array()
	main.level.power.set_live("A", false)
	p.crouching = true
	await place(Vector3(6.0, 0, 12.0), Vector3(6.0, 1.0, 13.0))   # facing away from him
	await wait(0.3)
	ok("gf_super_half_blind", su._visibility() == 0.0, "he saw a crouched man in the dark")
	Events.noise.emit(p.global_position, 4.5, "footstep", p)
	await frames(2)
	ok("gf_super_hears", su.suspicion > 0.2 or su.state in ["investigate", "suspicious"], "suspicion %.2f" % su.suspicion)
	main.level.power.set_live("A", true)
	p.crouching = false
	# caught by him: thrown back to the street door, hurt
	var inj0 := p.injury
	su.reset_to(p.global_position + Vector3(0, 0, -0.9))
	su._start_chase()
	ok("gf_super_catches", await until(func(): return Story.count("caught") >= 1, 5.0), "never caught")
	ok("gf_caught_back_at_door", await until(func(): return not p.locked and p.injury > inj0, 10.0) and main.level.room_at(p.global_position + Vector3(0, 1, 0)) == "vestibule", "at %s injury %d" % [p.global_position, p.injury])
	await skip_speech()
	# --- the key from mailbox 13, then the door, then 13
	await ground()
	p = main.player
	var mb: Door = main.level.find_child("Cab_mailbox13", true, false)
	ok("gf_mailbox13", mb != null, "no mailbox 13")
	await use_on(mb.ifocus(), "toggle", Vector3(1.1, 0, 9.4))
	await wait(0.5)
	ok("gf_mailbox_key", await take_item("key_apt13"), "couldn't take the key")
	await use_on(door("apt13_door").ifocus(), "unlock", door_from("apt13_door", 1))
	await wait(0.8)
	ok("gf_13_open", not door("apt13_door").locked and door("apt13_door").open_k > 0.5, "13 locked %s open %.2f" % [door("apt13_door").locked, door("apt13_door").open_k])
	await place(Vector3(26.5, 0, 6.2), Vector3(26.5, 1.2, 3.0))
	ok("gf_arrive13", await until(func(): return Story.has("arrived13"), 30.0), "no arrival")
	ok("gf_end_card", await until(func(): return get_tree().paused, 30.0), "no end card")
	ok("gf_way_in_key", main.director._way_in() == "key", "way in %s" % main.director._way_in())
	get_tree().paused = false
	if main.director._card: main.director._card.queue_free()
	# --- his key board instead (his own room)
	await ground()
	p = main.player
	ok("gf_keyboard_key", await take_item("key_apt13") and p.inv.has("key_apt13"), "no key from the board")
	# --- or pick 13's lock, quietly, with nothing but hairpins
	await ground()
	p = main.player
	p.inv.add("hairpin")
	await use_on(door("apt13_door").ifocus(), "pick", door_from("apt13_door", 1))
	ok("gf_13_picked", not door("apt13_door").locked, "still locked")
	_completed = "stealth"
