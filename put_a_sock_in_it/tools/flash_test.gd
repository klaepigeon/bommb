extends SceneTree
## Photosensitivity check. Renders scenes for several seconds and measures, per screen quadrant,
## the average brightness every frame. A "flash" is a pair of opposing brightness changes of at
## least 10% (WCAG / Harding's general-flash rule, simplified to quadrants). More than 3 flashes in
## any one second fails. Scenes: the landing's dying bulb, the kitchen's tube, the living room's
## TV, Marta chasing in the flesh flat (heartbeat, tearing, the failing torch).
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/flash_test.gd
var game
var fails := 0

func _initialize() -> void:
	await process_frame
	game = root.get_node("Game")
	game.settings.reduce_flashing = true
	game.change_level("flat47", {"card": false, "fade": 0.01})
	await _wait(1.5)
	var L = game.level
	root.get_node("Dialogue").stop(); game._black.visible = false; L.set_cutscene(false)
	await _scene(L, "landing (dying bulb)", Vector3(12.0, 0, 5.2), Vector3(10.06, 1.3, 4.56))
	await _scene(L, "kitchen (fluorescent)", Vector3(8.2, 0, 3.4), Vector3(9.0, 1.4, 1.0))
	await _scene(L, "living room (TV, lamp)", Vector3(4.1, 0, 3.6), Vector3(3.38, 1.0, 2.06))
	# the worst case: force the tube to restart and the bulb to dip, repeatedly
	for f in L.flat.fittings:
		if f.kind == "fluoro": f._startup = 2.0
	await _scene(L, "kitchen tube restarting", Vector3(8.2, 0, 3.4), Vector3(9.0, 1.4, 1.0))
	game.flags["flesh_stage"] = "B"; game.flags["met_marta_maze"] = true
	game.change_level("flesh47", {"card": false, "checkpoint": true, "fade": 0.01})
	await _wait(3.0)
	var F = game.level
	game._black.visible = false
	F.player.torch_on = true
	F.marta.active = false
	F.marta.global_position = F._p("B", Vector3(6.0, 0, 4.5))
	F.marta.set_state("chase")
	await _scene(F, "flesh flat, Marta chasing, torch failing", F._p("B", Vector3(8.4, 0, 4.5)), F._p("B", Vector3(6.0, 1.4, 4.5)))
	print("FLASH_TEST fails=%d" % fails)
	quit()

func _scene(L, name: String, pos: Vector3, at: Vector3) -> void:
	L.player.global_position = pos; L.player.velocity = Vector3.ZERO
	var d: Vector3 = at - (pos + Vector3(0, 1.62, 0))
	L.player.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	await _wait(0.6)
	var samples := []     # [time, [q0, q1, q2, q3]]
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000:
		await process_frame
		var img := root.get_viewport().get_texture().get_image()
		img.resize(32, 18, Image.INTERPOLATE_BILINEAR)
		var q := [0.0, 0.0, 0.0, 0.0]
		for y in 18:
			for x in 32:
				var c := img.get_pixel(x, y)
				q[(1 if x >= 16 else 0) + (2 if y >= 9 else 0)] += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
		for i in 4: q[i] /= 144.0
		samples.append([(Time.get_ticks_msec() - t0) / 1000.0, q])
	var worst := 0
	for qi in 4:
		# flashes: opposing swings of >= 0.1 (and the darker side below 0.8)
		var events := []
		var last_dir := 0; var ref: float = samples[0][1][qi]
		for s in samples:
			var v: float = s[1][qi]
			var dv := v - ref
			if absf(dv) >= 0.1 and minf(v, ref) < 0.8:
				var dir := 1 if dv > 0.0 else -1
				if last_dir != 0 and dir != last_dir: events.append(s[0])
				last_dir = dir; ref = v
			elif dv * last_dir > 0.0: ref = v     # keep tracking the extreme in the current direction
		# most flashes in any one-second window
		for i in events.size():
			var n := 0
			for e in events: if e >= events[i] and e < events[i] + 1.0: n += 1
			worst = maxi(worst, n)
	var ok := worst <= 3
	print(("  ok   " if ok else "  FAIL ") + "%s: at most %d flashes in a second (%d frames)" % [name, worst, samples.size()])
	if not ok: fails += 1

func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame
