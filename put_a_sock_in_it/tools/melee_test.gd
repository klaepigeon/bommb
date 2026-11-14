extends SceneTree
## Melee, through the real inputs (the "fire" / "throw" / "holster" actions): a punch shoves a
## loose thing; a hammer wears with every blow; a jar breaks on the first and leaves a shard in
## his hand; a chair breaks into a leg; with the pistol drawn "fire" shoots, holstered it punches;
## in the flesh flat, blows take Marta's poise and enough of them stun her. Saves frames of the
## arm in view (out=<dir>).
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/melee_test.gd -- out=<dir>
var game
var fails := 0
var out := "user://melee_test"

func _initialize() -> void:
	await process_frame
	for a in OS.get_cmdline_user_args(): if a.begins_with("out="): out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	game = root.get_node("Game")
	game.change_level("flat47", {"card": false, "fade": 0.01})
	await _wait(2.0)
	var L = game.level
	root.get_node("Dialogue").stop(); L.set_cutscene(false); game._black.visible = false
	var P = L.player
	var H = L.hands
	_check(H != null and H.arm != null, "the hands exist, with the rigged arm")

	# ---- punch a loose thing
	# (out in the hall, room behind it to be shoved into)
	load("res://scripts/core/build.gd").box(L.world, Vector3(7.0, 0.45, 4.5), Vector3(0.3, 0.9, 0.4), load("res://scripts/core/tex.gd").mat("wood"), true)
	var box = load("res://scripts/world/prop.gd").make(L.world, Vector3(7.0, 1.05, 4.5), Vector3(0.25, 0.25, 0.25), load("res://scripts/core/tex.gd").mat("cardboard"), "Box", 0.5, 0.3)
	await _face(P, Vector3(6.35, 0, 4.5), Vector3(7.0, 1.05, 4.5))
	var before: Vector3 = box.global_position
	await _attack(H, 0.05, "punch1")
	await _wait(0.4)
	_check(box.global_position.distance_to(before) > 0.05, "a punch shoves a box (moved %.2f m)" % box.global_position.distance_to(before))
	P.stamina = P.STAMINA_MAX
	var spent := [0.0]
	var watch := func(): spent[0] = maxf(spent[0], P.STAMINA_MAX - P.stamina)
	process_frame.connect(watch)
	await _attack(H, 0.5, "haymaker")
	_check(H.heavy, "a held blow is a heavy one")
	process_frame.disconnect(watch)
	_check(spent[0] > 0.1, "blows cost stamina (%.2f s of it)" % spent[0])
	box.queue_free()
	# ---- a hammer against the wall: it wears
	var hammer = _prop(L, "Hammer")
	_check(hammer != null, "there's a hammer")
	await _take(P, hammer)
	_check(P.held == hammer, "holding the hammer")
	var W = load("res://scripts/combat/weapons.gd")
	var d0: int = W.durability(hammer)
	await _face(P, Vector3(5.6, 0, 4.4), Vector3(5.6, 1.2, 3.8))
	await _attack(H, 0.05, "hammer_swing")
	await _attack(H, 0.05)
	_check(W.durability(hammer) == d0 - 2, "the hammer wears a hit at a time against the wall (%d -> %d)" % [d0, W.durability(hammer)])
	P.drop_held()
	# ---- a jar: breaks on the first blow, leaves a shard in his hand
	var jar = _prop(L, "Empty_jar")
	await _take(P, jar)
	await _face(P, Vector3(5.6, 0, 4.4), Vector3(5.6, 1.2, 3.8))
	await _attack(H, 0.05, "jar_swing")
	await _wait(0.2)
	_check(not is_instance_valid(jar), "the jar broke")
	_check(P.held != null and String(P.held.label) == "Broken glass", "he's left holding broken glass (%s)" % (String(P.held.label) if P.held else "nothing"))
	_check(P.held != null and W.profile(P.held)["class"] == "shard", "and it cuts (class shard)")
	P.drop_held()
	# ---- a chair: heavy blows, it comes apart into a leg
	var chair = _prop(L, "Chair")
	await _take(P, chair)
	await _face(P, Vector3(5.6, 0, 4.4), Vector3(5.6, 1.2, 3.8))
	for i in 2: await _attack(H, 0.5, "chair_heavy" if i == 0 else "")
	await _wait(0.2)
	_check(not is_instance_valid(chair), "two heavy blows break a chair")
	_check(P.held != null and String(P.held.label) == "Chair leg", "he's left holding a chair leg (%s)" % (String(P.held.label) if P.held else "nothing"))
	# ---- throw
	var leg = P.held
	P.set_view(P.get_yaw() + PI, 0.0)          # (away from the wall, into the hall)
	await _wait(0.2)
	var from: Vector3 = leg.global_position
	game.level.set_cutscene(false); _press("throw", true); await _wait(0.2); _press("throw", false); await _wait(0.3)
	# (how far it went, not how fast it's still going: it can have landed already)
	_check(P.held == null and is_instance_valid(leg) and leg.global_position.distance_to(from) > 0.6, "'throw' throws it (%.2f m)" % (leg.global_position.distance_to(from) if is_instance_valid(leg) else 0.0))
	# ---- pistol: drawn it shoots, holstered he punches
	game.pistol.have = true; game.pistol.drawn = true; game.pistol.mag = 4
	await _wait(0.6)
	game.level.set_cutscene(false); _press("fire", true); await _wait(0.2); _press("fire", false); await _wait(0.4)
	_check(int(game.pistol.mag) == 3 and H.state == "idle", "with the pistol drawn, fire shoots")
	game.level.set_cutscene(false); _press("holster", true); await _wait(0.2); _press("holster", false); await _wait(0.2)
	_check(not game.pistol.drawn, "'holster' puts it away")
	await _attack(H, 0.05, "holstered_punch")
	_check(int(game.pistol.mag) == 3, "holstered, fire punches (no shot)")
	_press("holster", true); await _wait(0.05); _press("holster", false)
	# ---- Marta: blows take her poise; enough of them stun her
	game.flags["maze_safe"] = 0; game.flags["met_marta_maze"] = true
	game.change_level("flesh47", {"card": false, "checkpoint": true, "fade": 0.01})
	await _wait(3.0)
	var F = game.level
	game._black.visible = false; root.get_node("Dialogue").stop(); F.set_cutscene(false)
	var M = F.marta
	M.active = false          # (held still: her hunting is tools/hunt_test.gd; this is what a blow does)
	M.set_state("patrol"); M._path = PackedVector3Array()
	var run: Array = F.straight(2)
	var dir: Vector3 = (F.centre(run[1]) - F.centre(run[0])).normalized()
	M.global_position = F.centre(run[0])
	await _face(F.player, F.centre(run[0]) + dir * 0.85, M.head() + Vector3(0, -0.5, 0))
	var axe = load("res://scripts/world/prop.gd").make(F.world, F.player.global_position + Vector3(0, 1, 0), Vector3(0.15, 0.73, 0.03), load("res://scripts/core/tex.gd").mat("wood"), "Axe", 1.5, 0.5)
	F.player.pick_up(axe)
	F.player.stamina = F.player.STAMINA_MAX
	var p0: float = M.poise
	await _attack(F.hands, 0.05, "marta_hit")
	_check(M.poise < p0, "a blow takes her poise (%.0f -> %.0f)" % [p0, M.poise])
	_check(M.state == "chase", "and she comes for him (%s)" % M.state)
	F.player.stamina = F.player.STAMINA_MAX
	M.global_position = F.centre(run[0]); M._path = PackedVector3Array()
	await _attack(F.hands, 0.5, "marta_heavy")
	_check(M.state == "stunned", "a heavy axe blow on top leaves her reeling (%s)" % M.state)
	print("MELEE_TEST fails=%d" % fails)
	quit()

# ------------------------------------------------------------------ helpers
func _attack(H, hold: float, shot := "") -> void:
	game.level.set_cutscene(false)       # (the level's opening sequence can take control back)
	await process_frame
	_press("fire", true)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < hold * 1000.0: await process_frame
	_press("fire", false)
	var t1 := Time.get_ticks_msec()
	var saved := false
	# (the press is only handled at the next frame's input flush: wait for the blow to start)
	while H.state == "idle" and Time.get_ticks_msec() - t1 < 1000: await process_frame
	while H.state != "idle" and Time.get_ticks_msec() - t1 < 5000:
		await process_frame
		if shot != "" and not saved and H.state == "strike":
			saved = true
			root.get_viewport().get_texture().get_image().save_png(out.path_join(shot + ".png"))
	await _wait(0.1)

func _press(action: String, down: bool) -> void:
	var ev := InputEventAction.new(); ev.action = action; ev.pressed = down; ev.strength = 1.0 if down else 0.0
	Input.parse_input_event(ev)

func _prop(L, name_part: String):
	for k in L.flat.props:
		var p = L.flat.props[k]
		if is_instance_valid(p) and String(k).contains(name_part): return p
	return null

func _take(P, p) -> void:
	P.drop_held()
	p.global_position = P.cam.global_position + (-P.cam.global_transform.basis.z) * 0.7
	P.pick_up(p)
	await _wait(0.4)

func _face(P, at: Vector3, look: Vector3) -> void:
	root.get_node("Dialogue").stop(); game.level.set_cutscene(false)
	P.global_position = at; P.velocity = Vector3.ZERO
	await _wait(0.2)
	var d: Vector3 = look - P.cam.global_position
	P.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	await _wait(0.3)

func _check(ok: bool, what: String) -> void:
	printerr(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1

func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame
