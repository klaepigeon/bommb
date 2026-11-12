extends SceneTree
## Marta's hunting AI, checked in the flesh flat: hearing, investigating, sight (worse crouched),
## the pistol's stun, losing him and searching, giving up and patrolling again.
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/hunt_test.gd
var fails := 0
func _initialize() -> void:
	await process_frame
	var game = root.get_node("Game")
	game.change_level("flesh47", {"card": false, "checkpoint": true, "fade": 0.01})
	await _wait(3.0)
	var F = game.level
	F._encountered = true
	var m = F.marta
	_check(m.state == "patrol", "starts on patrol")
	# park Kurt somewhere far away and out of sight: the start room
	F.player.global_position = F.cell_pos(1, 1); F.player.velocity = Vector3.ZERO
	await _wait(0.5)
	# a noise two cells from her: she goes to look
	var near: Vector3 = m.global_position + Vector3(2.8, 0, 0)
	game.make_noise(near, 0.6)
	await _wait(0.2)
	_check(m.state == "investigate", "hears a noise and investigates (" + m.state + ")")
	await _wait(10.0)
	_check(m.state == "patrol", "gives up on the noise and patrols (" + m.state + ")")
	# sight: standing in front of her at 8 m she sees him; crouched she doesn't
	var mc: Vector2i = m.to_cell(m.global_position)
	var spot := Vector3.ZERO
	for d in range(5, 8):
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var c: Vector2i = mc + dir * d
			if not m.grid.is_in_boundsv(c) or m.grid.is_point_solid(c): continue
			var p: Vector3 = m.cell_center(c)
			var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.6, 0), m.global_position + Vector3(0, 1.6, 0), 1)
			if F.get_world_3d().direct_space_state.intersect_ray(q).is_empty(): spot = p
	if spot != Vector3.ZERO:
		m.active = false
		m.look_at(Vector3(spot.x, m.global_position.y, spot.z), Vector3.UP)
		F.player.global_position = spot
		F.player.crouching = false
		await _wait(0.4)
		_check(m.can_see_player(), "sees him standing at %.1f m" % spot.distance_to(m.global_position))
		F.player.crouching = true
		await _wait(0.6)
		var far: bool = spot.distance_to(m.global_position) > 13.0 * 0.55
		_check(m.can_see_player() != far, "crouched: seen only up close (far=%s)" % far)
		F.player.crouching = false
		m.active = true
	else:
		_check(false, "found an open line to test sight")
	# the pistol: stunned, backs off, then comes back hunting
	m.set_state("chase")
	m.shot(m.head(), Vector3(1, 0, 0))
	_check(m.state == "stunned", "a bullet stuns her")
	F.player.global_position = F.cell_pos(1, 1)
	await _wait(3.6)
	_check(m.state in ["search", "chase"], "after the stun she hunts again (" + m.state + ")")
	_check(m.suspicion > 0.0, "and she's more suspicious (%.2f)" % m.suspicion)
	await _wait(30.0)
	_check(m.state == "patrol", "loses him, searches, returns to patrol (" + m.state + ")")
	print("HUNT_TEST fails=%d" % fails)
	quit()
func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1
func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0 / Engine.time_scale:
		await process_frame
