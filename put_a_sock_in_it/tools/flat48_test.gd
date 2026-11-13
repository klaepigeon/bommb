extends SceneTree
## Flat 48 (docs/FLAT48.md), played through its rules: the blocks hide 47's furniture; a note off
## the wall; the wrong word falls off, the right one makes the thing real; GUN SAFE, the safe, the
## sawn-off and its shells; the figures move only unseen, and stop when he looks; the shotgun
## puts one down; MARTA dresses MAMA, KURT dresses PAPA, SONYA won't stay on the child; and with
## every name tried, 48 ends.
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/flat48_test.gd
var fails := 0
var game
func _initialize() -> void:
	await process_frame
	game = root.get_node("Game")
	game.shotgun = {"have": false, "loaded": 0, "drawn": false}; game.inventory = {}
	game.change_level("flat48", {"card": false, "fade": 0.01})
	await _until(func(): return game.level != null and game.level_id == "flat48" and not game.busy, 30.0)
	await _wait(1.5)
	var L = game.level
	var D = root.get_node("Dialogue")
	D.stop(); L.set_cutscene(false); game._black.visible = false
	var P = L.player
	_check(L.blocks.size() >= 30 and L.figures.size() == 3, "48 is built: %d blocks, %d figures" % [L.blocks.size(), L.figures.size()])
	var sofa = _block(L, "SOFA")
	var hid_ok: bool = sofa != null and sofa.real_nodes.size() > 0
	if hid_ok:
		for n in sofa.real_nodes: if n.visible: hid_ok = false
	_check(hid_ok, "the sofa block hides 47's sofa (%d pieces)" % (sofa.real_nodes.size() if sofa else 0))
	for f in L.figures: f.set_physics_process(false)
	# ---- a note, the wrong word, the right word
	L.front_door.set_open(true)
	await _take(L, P, "PIANO")
	_check(P.held != null and P.held.get_meta("word", "") == "PIANO", "a note comes off the wall into his hand (PIANO)")
	await _face(L, P, sofa)
	_check(P.prompt().contains("PIANO"), "on the sofa block, the prompt offers the note (%s)" % P.prompt())
	P._interact()
	await _wait(0.5)
	_check(not sofa.is_real and P.held == null, "the wrong word won't stay on")
	await _take(L, P, "SOFA")
	await _face(L, P, sofa)
	P._interact()
	await _wait(0.6)
	var shown := true
	for n in sofa.real_nodes: if is_instance_valid(n) and not n.visible: shown = false
	_check(sofa.is_real and shown, "SOFA on the sofa: it's real, 47's own sofa")
	# ---- the safe
	await _take(L, P, "GUN SAFE")
	await _face(L, P, L.safe_block)
	P._interact()
	await _wait(0.6)
	_check(L.safe_block.is_real, "GUN SAFE: Papa's cabinet")
	var opener = _hotspot(L, "Open it")
	_check(opener != null, "the cabinet can be opened")
	if opener: opener.interact(P)
	await _wait(1.3)
	var gun = null; var shells = null
	for n in L.world.get_children():
		if n.get("item") == "shotgun": gun = n
		if n.get("item") == "shells": shells = n
	_check(gun != null and shells != null, "in it, the sawn-off and a box of shells")
	if gun: gun.interact(P)
	if shells: shells.interact(P)
	_check(game.shotgun.have and game.gun_out() == "shotgun" and int(game.shotgun.loaded) == 2 and game.count("shells") == 10, "he has it, out, both barrels loaded, ten shells")
	# ---- the figures: only when he isn't looking
	var mama = _fig(L, "mama")
	for f in L.figures: f.set_physics_process(true)
	var stand: Vector3 = Vector3(8.6, 0, 1.0)
	_tp(P, stand)
	await _wait(0.3)
	_look_at(P, mama.global_position + Vector3(0, 1.4, 0))
	await _wait(0.4)
	var p0: Vector3 = mama.global_position
	await _wait(1.5)
	_check(mama.is_seen() and mama.global_position.distance_to(p0) < 0.02, "looked at, it doesn't move")
	_look_at(P, P.cam.global_position * 2.0 - mama.global_position)     # away from it
	await _wait(0.3)
	var p1: Vector3 = mama.global_position
	await _wait(2.5)
	var crept: float = mama.global_position.distance_to(p1)
	_check(not mama.is_seen() and crept > 0.2, "unseen, it comes nearer (%.2f m)" % crept)
	_look_at(P, mama.global_position + Vector3(0, 1.4, 0))
	await _wait(0.3)
	for f in L.figures: f.set_physics_process(false)
	# ---- names: MARTA dresses MAMA
	await _take(L, P, "MARTA")
	await _face_fig(L, P, mama)
	P._interact()
	await _wait(0.5)
	_check(mama.dressed == "MARTA", "MARTA on MAMA: a mannequin dressed as her")
	# the shotgun puts her down (dressed, they can still be shot)
	await _face_fig(L, P, mama, 1.6)
	game.shotgun.drawn = true; game.pistol.drawn = false
	await _wait(0.6)
	L.shotgun.fire()
	await _wait(1.0)
	_check(mama.down, "the sawn-off puts one down for good")
	_check(int(game.shotgun.loaded) == 1, "one barrel spent (%d left)" % int(game.shotgun.loaded))
	L.shotgun.reload()
	await _wait(2.0)
	_check(int(game.shotgun.loaded) == 2 and game.count("shells") == 9, "break-open reload: both barrels again, a shell from the box")
	# KURT on PAPA, SONYA on the child
	var papa = _fig(L, "papa"); var child = _fig(L, "child")
	await _take(L, P, "KURT")
	await _face_fig(L, P, papa)
	P._interact()
	await _wait(0.5)
	_check(papa.dressed == "KURT", "KURT on PAPA: a mannequin dressed as Kurt")
	await _take(L, P, "SONYA")
	await _face_fig(L, P, child)
	P._interact()
	await _wait(0.5)
	_check(child.dressed == "" and P.held == null, "SONYA won't stay on the child")
	await _until(func(): return game.flag("lobby_unveiled"), 25.0)
	_check(game.flag("lobby_unveiled") and _hotspot(L, "Take the note: LOBBY") != null, "every name tried: a note that wasn't there, LOBBY")
	_check(L.door47 != null and L.door47.enabled, "and the door across the landing (47) opens")
	# ---- LOBBY across the landing to 47
	D.stop(); L.set_cutscene(false)
	await _take(L, P, "LOBBY")
	_check(P.held != null and P.held.get_meta("word", "") == "LOBBY", "he takes LOBBY")
	_tp(P, L.door47.global_position + Vector3(0, -1.0, -0.9))
	await _wait(0.2)
	_look_at(P, L.door47.global_position)
	await _wait(0.3)
	_check(P.prompt() == "Flat 47", "at 47's door, the prompt (%s)" % P.prompt())
	P._interact()
	await _until(func(): return game.level != null and game.level_id == "flat47" and not game.busy, 30.0)
	await _wait(2.0)
	var L7 = game.level
	var P7 = L7.player
	D.stop()
	_check(game.level_id == "flat47" and L7.outside.visible and not L7.marta.joints.hips.visible, "47, as he left it: her gone, the white outside")
	_check(P7.held != null and P7.held.get_meta("word", "") == "LOBBY", "LOBBY still in his hand")
	# ---- the balcony
	L7.set_cutscene(false)
	L7.balcony_door.set_open(true)
	_tp(P7, Vector3(2.25, 0, -0.9))
	await _wait(0.3)
	_look_at(P7, L7.sticky_at)
	await _wait(0.4)
	D.stop(); L7.set_cutscene(false)
	await _wait(0.3)
	_check(P7.prompt().contains("LOBBY"), "on the balcony, looking out: %s" % P7.prompt())
	P7._interact()
	await _until(func(): return game.flag("lobby_made"), 20.0)
	_check(game.flag("lobby_made") and L7.lobby != null and not L7.outside.visible, "LOBBY on outside: outside is the lobby")
	# he can step off the balcony into it
	D.stop(); L7.set_cutscene(false)
	_look_at(P7, Vector3(2.25, 1.6, -8.0))
	Input.action_press("move_forward")
	await _until(func(): return P7.global_position.z < -3.8, 10.0)
	Input.action_release("move_forward")
	_check(P7.global_position.z < -3.8, "and walks out into it (z %.2f)" % P7.global_position.z)
	await _until(func(): return game.flag("lobby_done"), 10.0)
	_check(game.flag("lobby_done"), "into the lobby: as far as it goes, for now")
	printerr("FLAT48_TEST fails=%d" % fails)
	quit()

func _block(L, word: String):
	for b in L.blocks: if b.identity == word: return b
	return null

func _fig(L, id: String):
	for f in L.figures: if f.id == id: return f
	return null

func _hotspot(L, prompt: String):
	for n in L.world.find_children("*", "StaticBody3D", true, false):
		if n.has_method("get_prompt") and n.get("prompt") == prompt and n.get("enabled"): return n
	return null

func _take(L, P, word: String) -> void:
	var h = _hotspot(L, "Take the note: %s" % word)
	if h == null: printerr("  (no note %s on the wall)" % word); return
	P.global_position = Vector3(h.global_position.x, 0, h.global_position.z + 0.8); P.velocity = Vector3.ZERO
	await _wait(0.2)
	_look_at(P, h.global_position)
	await _wait(0.3)
	P._interact()
	await _wait(0.3)

## Stand in front of a block, looking at its middle.
func _face(L, P, b) -> void:
	var space = P.get_world_3d().direct_space_state
	var best := Vector3.ZERO
	for j in 16:
		var a := j * TAU / 16.0
		var at: Vector3 = b.global_position + Vector3(cos(a), 0, sin(a)) * (maxf(b.half.x, b.half.z) + 0.7)
		at.y = 0.0
		var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 1.0, 0), b.global_position, 1, [])
		var h: Dictionary = space.intersect_ray(q)
		var pq := PhysicsPointQueryParameters3D.new(); pq.position = at + Vector3(0, 0.9, 0); pq.collision_mask = 1 | 32
		if h.is_empty() and space.intersect_point(pq).is_empty(): best = at; break
	_tp(P, best)
	await _wait(0.2)
	_look_at(P, b.global_position)
	await _wait(0.3)

func _face_fig(L, P, f, dist := 1.2) -> void:
	var dir: Vector3 = (P.global_position - f.global_position) * Vector3(1, 0, 1)
	dir = dir.normalized() if dir.length() > 0.1 else Vector3(1, 0, 0)
	_tp(P, f.global_position + dir * dist)
	await _wait(0.2)
	_look_at(P, f.global_position + Vector3(0, f.tall * 0.7, 0))
	await _wait(0.3)

## (a teleport: what's in his hand comes with him, as it would walking)
func _tp(P, at: Vector3) -> void:
	P.global_position = at; P.velocity = Vector3.ZERO
	if P.held: P.held.global_position = at + Vector3(0, 1.45, 0)

func _look_at(P, p: Vector3) -> void:
	var d: Vector3 = p - P.cam.global_position
	P.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))

func _until(f: Callable, secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not f.call() and Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame

func _check(ok: bool, what: String) -> void:
	printerr(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1

func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame
