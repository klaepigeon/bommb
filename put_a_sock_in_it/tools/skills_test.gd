extends SceneTree
## The two skill trees, the powers and the dialogue choices (docs/SKILLS.md):
## points, prerequisites, what each node changes; telekinesis pulling a thing into his hand;
## telepathy; the choice UI (locked options greyed, tagged options opening up as he earns them);
## Breach through a cracked wall (not without it); the shove; Coup de Grace, and her coming back
## in the next copy; the skills screen.
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/skills_test.gd -- out=<dir>
var game
var fails := 0
var out := "user://skills_test"

func _initialize() -> void:
	await process_frame
	for a in OS.get_cmdline_user_args(): if a.begins_with("out="): out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	game = root.get_node("Game")
	var S = load("res://scripts/core/skills.gd")
	var D = root.get_node("Dialogue")
	game.skills = {}; game.memory_points = 0; game.skill_points = 0; game.memories = 0; S.apply()
	_check(not S.can_unlock("m_1"), "nothing without points")
	game.memory_points = 3; game.skill_points = 20
	_check(not S.can_unlock("m_talk"), "a node needs the one before it")
	_check(S.unlock("m_1") and game.memories == 1 and game.memory_points == 2, "Memory I: a memory (memories 1, 2 points left)")
	_check(D.test("memories >= 1"), "the dialogue's memory branches open")
	_check(S.unlock("s_sinew") and is_equal_approx(game.stat("strength"), 1.25), "Sinew: strength 1.25")
	_check(S.unlock("s_lungs") and is_equal_approx(game.stat("stamina_max"), 1.5), "Lungs: half as much stamina again")
	_check(S.unlock("s_tk"), "Telekinesis")
	# ---- in the flat
	game.change_level("flat47", {"card": false, "fade": 0.01})
	await _wait(2.0)
	var L = game.level
	D.stop(); L.set_cutscene(false); game._black.visible = false
	# (the level's scripted scenes start when he walks into places or sees her: keep them out of it)
	L._seen_marta = true
	for a in L.world.find_children("*", "Area3D", true, false): a.set_meta("armed", false)
	var P = L.player
	_check(is_equal_approx(P.stamina_max(), P.STAMINA_MAX * 1.5), "Lungs shows in his stamina (%.2f)" % P.stamina_max())
	# telekinesis: a book across the room flies to his hand
	# (any loose thing he can see from 2.5 m off: stand there)
	var space = P.get_world_3d().direct_space_state
	var book = null
	var spot := Vector3.ZERO
	for k in L.flat.props:
		var b = L.flat.props[k]
		if not (b is RigidBody3D) or not b.get("liftable") or b.mass > 6.0: continue
		for j in 16:
			var a := j * TAU / 16.0
			var at: Vector3 = b.global_position + Vector3(cos(a), 0, sin(a)) * 2.5
			at.y = 0.0
			var eye := at + Vector3(0, 1.62, 0)
			var q := PhysicsRayQueryParameters3D.create(eye, b.global_position + Vector3(0, 0.05, 0), 1 | 32, [b.get_rid()])
			var h: Dictionary = space.intersect_ray(q)
			if h.is_empty() and space.intersect_point(_pt(at + Vector3(0, 0.9, 0))).is_empty() \
				and space.intersect_point(_pt(at + Vector3(0, 0.3, 0))).is_empty() and not space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.5, 0), at + Vector3(0, -0.2, 0), 1)).is_empty():
				book = b; spot = at; break
		if book: break
	printerr("  (pulling ", book.name if book else "nothing", " from ", spot, ")")
	await _face(L, P, spot, book.global_position)
	var did: String = L.powers.use()
	await _wait(1.8)
	_check(did == "pull" and P.held == book, "telekinesis pulls a book %.1f m into his hand (%s)" % [2.5, did])
	_check(game.strain > 0.0, "and it costs strain (%.2f)" % game.strain)
	P.drop_held()
	# ---- choices
	var pick := [-1]
	D.chose.connect(func(i, _o): pick[0] = i)
	D.play("_example_choices")
	await _until(func(): return D.choosing(), 30.0)
	_check(D.choosing(), "the choice comes up")
	var buttons: Array = D._choice_box.get_children()
	var enabled := buttons.filter(func(b): return not b.disabled).size()
	_check(buttons.size() == 4 and enabled == 3, "four options, the telepathy one greyed (%d shown, %d open)" % [buttons.size(), enabled])
	_check(buttons.size() >= 3 and String(buttons[1].text).contains("[Memory]") and String(buttons[2].text).contains("[Telepathy]"), "tagged [Memory] and [Telepathy]")
	_check(not P.controls, "he stands still while he chooses")
	root.get_viewport().get_texture().get_image().save_png(out.path_join("choices.png"))
	D.pick(2)
	await _wait(0.2)
	_check(pick[0] == -1, "a greyed option can't be picked")
	D.pick(1)
	await _until(func(): return not D.busy, 60.0)
	_check(pick[0] == 1 and not D.busy, "the [Memory] option is picked and the conversation plays out")
	_check(S.unlock("s_telepathy"), "Telepathy")
	D.play("_example_choices")
	await _until(func(): return D.choosing(), 30.0)
	enabled = D._choice_box.get_children().filter(func(b): return not b.disabled).size()
	_check(enabled == 4, "with Telepathy, its option opens (%d open)" % enabled)
	D.stop()
	L.set_cutscene(false)
	P.set_view(0.0, 1.2)       # nothing in front of him
	game.strain = 0.0
	_check(L.powers.use() == "listen", "with nothing in reach, POWER listens (telepathy)")
	# ---- the skills screen
	L.set_cutscene(false)
	L.skills_menu.open()
	_check(L.skills_menu.visible and paused, "the skills screen opens and pauses")
	game.memory_points = 1
	L.skills_menu._select("m_talk"); L.skills_menu._try_buy()
	_check(S.has("m_talk") and is_equal_approx(game.stat("talk_rate"), 2.0), "buying Talkative from the screen")
	root.get_viewport().get_texture().get_image().save_png(out.path_join("skills_screen.png"))
	L.skills_menu.close()
	_check(not paused, "and closes")
	# ---- the flesh flat: breach, shove, coup de grace
	game.flags["maze_safe"] = 0; game.flags["met_marta_maze"] = true
	game.change_level("flesh47", {"card": false, "checkpoint": true, "fade": 0.01})
	await _wait(3.0)
	var F = game.level
	game._black.visible = false; D.stop(); F.set_cutscene(false)
	var FP = F.player
	var wall = null
	for c in F.world.get_children():
		if c.has_method("punched") and c.has_signal("breached"): wall = c     # (by duck type: naming the class here would compile it before the autoloads exist)
	_check(wall != null, "a cracked wall in copy B")
	F.marta.active = false; F.marta.global_position = Vector3(-40, 0, -40)
	var wn: Vector3 = wall.global_basis.z; wn.y = 0
	await _face(F, FP, Vector3(wall.global_position.x, 0, wall.global_position.z) + wn.normalized() * 0.6, wall.global_position + Vector3(0, 0.45, 0))
	await _attack(F, 0.6)
	_check(is_instance_valid(wall), "without Breach a heavy punch doesn't go through")
	_check(S.unlock("s_breach"), "Breach")
	FP.stamina = FP.stamina_max()
	await _attack(F, 0.6)
	await _wait(0.3)
	_check(not is_instance_valid(wall), "with Breach a heavy punch goes through the cracked wall")
	# shove
	_check(S.unlock("s_sinew2") and S.unlock("s_shove"), "Sinew II, Telekinetic Shove")
	var M = F.marta
	var run: Array = F.straight(2)
	var dir: Vector3 = (F.centre(run[1]) - F.centre(run[0])).normalized()
	M.global_position = F.centre(run[0]); M.set_state("patrol"); M.poise = M.POISE_MAX
	await _face(F, FP, F.centre(run[1]), M.head())
	game.strain = 0.0
	var p0: float = M.poise
	_check(F.powers.use() == "shove" and M.poise < p0, "POWER at her shoves her (poise %.0f -> %.0f)" % [p0, M.poise])
	# coup de grace: stunned, a heavy blow with a knife
	_check(S.unlock("s_reaper"), "Coup de Grace")
	M.global_position = F.centre(run[0])
	await _face(F, FP, F.centre(run[0]) + dir * 0.9, M.head() + Vector3(0, -0.4, 0))
	var knife = load("res://scripts/world/prop.gd").make(F.world, FP.global_position + Vector3(0, 1, 0), Vector3(0.03, 0.02, 0.25), load("res://scripts/core/tex.gd").mat("metal"), "Kitchen knife", 0.15, 0.3)
	FP.pick_up(knife)
	M.shot(M.head(), Vector3(1, 0, 0))
	_check(M.state == "stunned", "shot, she reels")
	M.global_position = F.centre(run[0]); M._path = PackedVector3Array()
	FP.stamina = FP.stamina_max()
	await _attack(F, 0.6)
	_check(M.state == "dead", "a heavy knife blow while she reels kills her (%s)" % M.state)
	root.get_viewport().get_texture().get_image().save_png(out.path_join("coup.png"))
	F._enter_safe(1)
	_check(M.state == "patrol" and M.active and M.evolution == 2, "at the next safe room she's back, further along")
	print("SKILLS_TEST fails=%d" % fails)
	quit()

func _attack(lv, hold: float) -> void:
	lv.set_cutscene(false); await process_frame
	var ev := InputEventAction.new(); ev.action = "fire"; ev.pressed = true; Input.parse_input_event(ev)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < hold * 1000.0: await process_frame
	var ev2 := InputEventAction.new(); ev2.action = "fire"; ev2.pressed = false; Input.parse_input_event(ev2)
	var t1 := Time.get_ticks_msec()
	while lv.hands.state == "idle" and Time.get_ticks_msec() - t1 < 1000: await process_frame
	while lv.hands.state != "idle" and Time.get_ticks_msec() - t1 < 5000: await process_frame
	await _wait(0.1)

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

func _pt(p: Vector3) -> PhysicsPointQueryParameters3D:
	var q := PhysicsPointQueryParameters3D.new(); q.position = p; q.collision_mask = 1 | 32
	return q

func _check(ok: bool, what: String) -> void:
	printerr(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1

func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame
