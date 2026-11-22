extends SceneTree
## The Lab (docs/LAB.md): each experiment loads; the sandbox spawns every type and they come for
## him; Echo's click washes light and the listener hears it; the mirror's camera is his reflected,
## the one in it is only in it, and it comes nearer each time he looks away.
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/lab_test.gd -- out=<dir>
var fails := 0
var game
var D
var out := "user://lab_test"

func _initialize() -> void:
	await process_frame
	for a in OS.get_cmdline_user_args(): if a.begins_with("out="): out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	game = root.get_node("Game"); D = root.get_node("Dialogue")
	# ---- the hub
	var L = await _go("lab")
	for ex in ["lab_sandbox", "lab_echo", "lab_mirror"]:
		_check(L.world.get_node_or_null("Go_" + ex) != null, "the Lab has a door to " + ex)
	_shot("lab.png")
	# ---- the sandbox
	L = await _go("lab_sandbox")
	var P = L.player
	var i := 0
	for t in L.TYPES:
		L.spawn(t, Vector3(-8.0 + i * 2.2, 0, -6.0)); i += 1
	await _wait(1.0)
	_check(L.people.size() == 8 and L.people.all(func(n): return is_instance_valid(n) and n.body != null), "every type spawns, with its body (%d)" % L.people.size())
	P.global_position = Vector3(0, 0, -3.0); P.set_view(0.0, 0.0)
	L.god = true
	var noticed := func(): return L.people.filter(func(n): return n.state in ["hunt", "attack", "investigate"] or n.awareness > 0.3).size()
	await _until(func(): return noticed.call() >= 4, 10.0)
	var on_him: int = noticed.call()
	_check(on_him >= 3, "set on him, they notice and come (%d of 8)" % on_him)
	_shot("sandbox.png")
	L.set_hostile(false)
	await _wait(0.2)
	_check(L.people.all(func(n): return n.prof["hostile_to"].is_empty()), "J: they leave him be")
	for n in L.people: n.die()
	await _wait(0.3)
	_check(L.people.all(func(n): return n.dead), "U: all dead")
	L.set_lights(false)
	_check(not L.lit(Vector3.ZERO), "L: lights off, nowhere's lit")
	# ---- echo
	L = await _go("lab_echo")
	P = L.player
	var w0: int = L.washes
	L._recent.clear()
	var heard := [0.0]
	var cb := func(pos, loud): heard[0] = maxf(heard[0], loud)
	game.noise.connect(cb)
	_check(L.click(), "a click")
	_check(not L.click(), "  and not another straight away (1.2 s apart)")
	_check(L.washes == w0 + 1 and heard[0] >= 0.3, "  it washes light, and it's a sound (%.2f)" % heard[0])
	game.noise.disconnect(cb)
	await _wait(0.4)
	_shot("echo_click.png")
	await _wait(2.2)
	_check(not is_instance_valid(L.last_click), "  and it fades away, slowly (gone after 2.6 s)")
	_check(not P.torch_on, "no torch in here")
	var lis = L.listener
	lis.global_position = P.global_position + Vector3(4.0, 0, 0)
	L.click() if L._click_t <= 0.0 else null
	await _wait(1.5)
	_check(lis.awareness > 0.0 or lis.state != "patrol", "the listener heard it (state %s, awareness %.2f)" % [lis.state, lis.awareness])
	# ---- mirror
	L = await _go("lab_mirror")
	P = L.player
	P.global_position = Vector3(0, 0, 0.4); P.set_view(0.0, 0.0)
	await _wait(0.5)
	var mc: Camera3D = L.mirror_cam
	var pc: Camera3D = P.cam
	_check(absf(mc.global_position.z - (2.0 * L.MZ - pc.global_position.z)) < 0.05 and absf(mc.global_position.x - pc.global_position.x) < 0.01, "the mirror's camera is his, reflected across the glass")
	_check((mc.cull_mask & L.L_MIRROR) == 0 and (mc.cull_mask & L.L_KURT) == 0 and (mc.cull_mask & L.L_GHOST) != 0, "  it sees through the wall, not him, and the one in it")
	_check((pc.cull_mask & L.L_GHOST) == 0, "he can't see the one in it in the room")
	_check(L.looking_at_glass(), "looking at the glass")
	_shot("mirror_0.png")
	var d0: float = L.ghost.position.distance_to(P.global_position * Vector3(1, 0, 1))
	var ds := []
	for k in 2:
		P.set_view(PI, 0.0); await _wait(0.2)
		P.set_view(0.0, 0.0); await _wait(0.3)
		ds.append(L.ghost.position.distance_to(P.global_position * Vector3(1, 0, 1)))
	_check(L.steps == 2 and ds[0] < d0 - 0.3 and ds[1] < ds[0] - 0.2, "each look away, it's nearer (%.2f -> %.2f -> %.2f m)" % [d0, ds[0], ds[1]])
	for k in 4:
		if L._close_seen: break
		P.set_view(PI, 0.0); await _wait(0.2)
		P.set_view(0.0, 0.0); await _wait(0.3)
	_check(L._close_seen and L.ghost.position.distance_to(P.global_position * Vector3(1, 0, 1)) < 0.6, "  until it's right behind him, and he's seen it (%d looks)" % L.steps)
	_shot("mirror_near.png")
	P.set_view(PI, 0.0); await _wait(0.2)
	_check(L.steps == 0 and L.ghost.position.distance_to(L.START) < 0.01, "the next look away, it's back by the far wall")
	printerr("LAB_TEST fails=%d" % fails)
	quit()

func _go(id: String):
	await _until(func(): return not game.busy, 30.0)
	var t0 := Time.get_ticks_msec()
	while not (game.level != null and is_instance_valid(game.level) and game.level_id == id and not game.busy) and Time.get_ticks_msec() - t0 < 60000:
		if not game.busy and game.level_id != id: game.change_level(id, {"card": false, "fade": 0.01})
		await process_frame
	await _wait(0.6)
	var L = game.level
	game._black.visible = false
	D.stop(); L.set_cutscene(false)
	_check(L != null and game.level_id == id, id + " loads")
	return L

func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name))

func _until(f: Callable, secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not f.call() and Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame

func _check(ok: bool, what: String) -> void:
	printerr(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1

func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame
