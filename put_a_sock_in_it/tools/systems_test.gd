extends SceneTree
## The systems under the hunt (docs/SYSTEMS.md) and the feel (docs/FEEL.md), checked in the maze:
## his nerve rising at the sight of her and falling in a safe room; holding his breath, and the
## gasp when he can't; hiding in a wardrobe (she can't see in; seen getting in, she has him out;
## listening at the doors, his held breath saves him and his fear gives him away); the torch's
## battery; and the feel: the landing, the lean, the hit-stop.
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/systems_test.gd
var fails := 0
var game
func _initialize() -> void:
	await process_frame
	game = root.get_node("Game")
	game.flags["maze_safe"] = 0; game.flags["met_marta_maze"] = true
	game.change_level("flesh47", {"card": false, "checkpoint": true, "fade": 0.01})
	await _wait(3.0)
	var F = game.level
	F._encountered = true
	root.get_node("Dialogue").stop(); F.set_cutscene(false); game._black.visible = false
	var P = F.player
	var m = F.marta
	var space = F.get_world_3d().direct_space_state
	_check(F.nerve != null and F.hide_spots.size() >= 3, "the nerve is on him, and there are wardrobes in the maze (%d)" % F.hide_spots.size())
	# ---- nerve: she's in sight, 4 m off, standing still
	var run: Array = F.straight(3)
	_check(run.size() == 3, "a straight run of three cells to test in")
	m.set_physics_process(false)
	m.global_position = F.centre(run[2]); m.rotation.y = 0.0
	await _face(F, P, F.centre(run[0]), m.head())
	game.fear = 0.0
	await _wait(2.0)
	var risen: float = game.fear
	_check(risen > 0.3, "seeing her frightens him (fear %.2f after 2 s)" % risen)
	_check(P.tremor > 0.2, "and his hands shake (%.2f)" % P.tremor)
	# ...and a safe room calms him
	m.global_position = F.centre(F.maze.start) + Vector3(0.0, -30.0, 0.0)   # (out of the world)
	await _face(F, P, F.centre(F.maze.safe[0]), F.centre(F.maze.safe[0], 1.6) + Vector3(1, 0, 0))
	var f0: float = game.fear
	await _wait(2.0)
	_check(game.fear < f0 - 0.3, "a safe room calms him (%.2f -> %.2f)" % [f0, game.fear])
	# ---- holding his breath: silent, then the gasp
	game.fear = 0.0
	await _face(F, P, F.centre(run[0]), F.centre(run[1], 1.6))
	var heard := []
	var on_noise := func(_p, loud): heard.append(loud)
	game.noise.connect(on_noise)
	Input.action_press("hold_breath")
	await _wait(1.0)
	_check(F.nerve.holding and P.breath_held, "B holds his breath")
	_check(F.nerve.air < 0.95, "and the air goes down (%.2f)" % F.nerve.air)
	await _until(func(): return not F.nerve.holding, 10.0)
	Input.action_release("hold_breath")
	var gasp := false
	for l in heard: if l >= 0.4: gasp = true
	_check(gasp, "held too long, he gasps, and she can hear it")
	game.noise.disconnect(on_noise)
	await _wait(2.0)
	# ---- hiding
	var hs = F.hide_spots[0]
	await _face(F, P, hs.front(), hs.global_position + Vector3(0, 1.2, 0))
	_check(P.target == hs or P.prompt().contains("Hide"), "the wardrobe offers to hide him (%s)" % P.prompt())
	hs.interact(P)
	await _wait(0.4)
	_check(P.hidden_in == hs and not P.controls, "he's in the wardrobe")
	var cam_in: Vector3 = P.cam.global_position
	var inside: bool = hs.to_local(cam_in).z < hs.size.z * 0.5 and absf(hs.to_local(cam_in).x) < hs.size.x * 0.5
	_check(inside, "his eyes are inside it, behind the doors")
	# she, right in front with him in her cone, can't see him
	m.set_physics_process(true); m.active = true
	m.global_position = hs.front() + hs.global_basis.z * 1.5
	m.look_at(hs.global_position + Vector3(0, 0.0, 0), Vector3.UP)
	_check(not m.can_see_player(), "she can't see into a wardrobe")
	# listening: she stops at the doors; he holds his breath, keeps calm: she moves on
	m.set_state("search"); m._path = PackedVector3Array(); m._pi = 0; m._listened.clear()
	game.fear = 0.05
	F.nerve.air = 1.0; F.nerve._winded = false
	Input.action_press("hold_breath")
	await _until(func(): return m.state == "listen", 2.0)
	_check(m.state == "listen", "searching by a wardrobe he's in, she stops to listen (%s)" % m.state)
	await _until(func(): return m.state != "listen", 8.0)
	Input.action_release("hold_breath")
	_check(m.state != "fetch" and m.state != "caught" and P.hidden_in == hs, "he held his breath and kept calm: she moved on (%s)" % m.state)
	# again, but frightened and breathing: she hears him
	var caught := [false]
	F.marta.caught_player.disconnect(F._on_caught)
	m.caught_player.connect(func(): caught[0] = true)
	m.set_state("search"); m._path = PackedVector3Array(); m._pi = 0; m._listened.clear()
	m.global_position = hs.front() + hs.global_basis.z * 1.5
	game.fear = 0.9
	await _until(func(): return caught[0], 10.0)
	_check(caught[0] and P.hidden_in == null, "frightened and breathing, she hears him and has him out")
	# seen getting in: she comes straight for it
	caught[0] = false
	m.set_physics_process(false)          # (still, while he's put in front of the wardrobe)
	m.set_state("patrol"); m.active = true
	if P.hidden_in: P.leave_hiding(hs.front(), hs.global_basis.z)
	P.controls = true
	await _face(F, P, hs.front(), hs.global_position + Vector3(0, 1.2, 0))
	m.global_position = hs.front() + hs.global_basis.z * 4.0
	m._seen_ago = 0.0
	m.set_physics_process(true)
	hs.interact(P)
	await _wait(0.1)
	_check(m.state == "fetch", "seen getting in, she comes for the wardrobe (%s)" % m.state)
	await _until(func(): return caught[0], 8.0)
	_check(caught[0], "and has him out of it")
	m.active = false; m.set_physics_process(false)
	m.global_position = F.centre(F.maze.start) + Vector3(0.0, -30.0, 0.0)
	if P.hidden_in: P.leave_hiding(hs.front(), hs.global_basis.z)
	P.controls = true
	# ---- the torch's battery
	game.torch_charge = 1.0
	P.toggle_torch(true)
	await _wait(1.0)
	var e_full: float = P.torch.light_energy
	_check(game.torch_charge < 1.0, "the torch runs its battery down (%.4f)" % game.torch_charge)
	game.torch_charge = 0.05
	await _wait(1.0)
	_check(P.torch.light_energy < e_full * 0.6 and P.torch.light_energy > 0.0, "a flat battery browns the light down, not off (%.2f of %.2f)" % [P.torch.light_energy, e_full])
	var b = null
	for n in F.world.get_children(): if n.get("item") == "battery": b = n; break
	_check(b != null, "there are batteries in the maze")
	if b: b.interact(P)
	_check(is_equal_approx(game.torch_charge, 1.0), "a battery fills it again")
	P.toggle_torch(false)
	# ---- feel
	await _face(F, P, F.centre(run[1]), F.centre(run[2], 1.6))
	P.global_position += Vector3(0, 1.2, 0)
	var dip := [0.0]
	var watch := func(): dip[0] = minf(dip[0], P._land)
	process_frame.connect(watch)
	await _wait(1.5)
	process_frame.disconnect(watch)
	_check(dip[0] < -0.05, "a drop: the knees take the landing (dip %.2f)" % dip[0])
	var x0: float = P.head.position.x
	Input.action_press("lean_right")
	await _wait(0.6)
	var leaned: float = P.head.position.x - x0
	Input.action_release("lean_right")
	_check(leaned > 0.1, "he leans out (%.2f m)" % leaned)
	var fx = root.get_node("Fx")
	var slowed := [1.0]
	var watch2 := func(): slowed[0] = minf(slowed[0], Engine.time_scale)
	process_frame.connect(watch2)
	fx.hitstop(0.08)
	await _wait(0.3)
	process_frame.disconnect(watch2)
	_check(slowed[0] < 0.2 and is_equal_approx(Engine.time_scale, 1.0), "a hit-stop holds the world, then lets it go (%.2f)" % slowed[0])
	printerr("SYSTEMS_TEST fails=%d" % fails)
	quit()

func _face(lv, P, at: Vector3, look: Vector3) -> void:
	root.get_node("Dialogue").stop(); lv.set_cutscene(false)
	P.global_position = at; P.velocity = Vector3.ZERO
	await _wait(0.2)
	var d: Vector3 = look - P.cam.global_position
	P.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	await _wait(0.3)

func _until(f: Callable, secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not f.call() and Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame

func _check(ok: bool, what: String) -> void:
	printerr(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1

func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame
