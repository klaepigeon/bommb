extends SceneTree
## Does the picture hold still when nothing moves? In several places in both levels, the camera
## held still for 3 s (post effects off): the share of pixels whose brightness changes by more
## than 6% from the first frame. Lights, shadows and textures that flicker show up here; dust
## motes drifting are a fraction of a percent. Fails above 1.5% (4% in the flesh, which breathes).
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/stability_test.gd
var game
var fails := 0

func _initialize() -> void:
	await process_frame
	game = root.get_node("Game")
	game.settings.post_fx = false
	game.change_level("flat47", {"card": false, "fade": 0.01})
	await _wait(5.0)          # (the level fades in from black over its first 3 s)
	var L = game.level
	root.get_node("Dialogue").stop(); L.set_cutscene(false); game._black.visible = false
	root.get_node("Fx").visible = false if root.get_node("Fx").get("visible") != null else null
	L._seen_marta = true
	for a in L.world.find_children("*", "Area3D", true, false): a.set_meta("armed", false)
	for v in [["landing", Vector3(12.6, 0, 5.2), Vector3(10.2, 1.2, 4.56)], ["stair well", Vector3(12.4, 0, 4.0), Vector3(13.6, -0.6, 6.4)],
			["hall", Vector3(9.5, 0, 4.5), Vector3(5.0, 1.2, 4.5)], ["living room", Vector3(4.1, 0, 4.4), Vector3(2.0, 1.0, 1.5)],
			["kitchen", Vector3(8.2, 0, 3.4), Vector3(9.5, 0.9, 0.6)], ["bathroom", Vector3(8.6, 0, 5.6), Vector3(8.0, 0.6, 7.6)],
			["Sonya's room", Vector3(5.6, 0, 6.0), Vector3(3.4, 0.6, 7.4)]]:
		if OS.get_cmdline_user_args().has("flesh_only"): break
		await _hold(L, v[0], v[1], v[2])
	game.flags["maze_safe"] = 0; game.flags["met_marta_maze"] = true
	game.change_level("flesh47", {"card": false, "checkpoint": true, "fade": 0.01})
	await _wait(3.0)
	var F = game.level
	game._black.visible = false; root.get_node("Dialogue").stop(); F.set_cutscene(false)
	F.marta.active = false; F.marta.global_position = Vector3(-40, 0, -40)
	var r: Array = F.maze.path
	var s0: Vector2i = F.maze.safe[0]
	for v in [["flesh: the maze", F.centre(r[2]), F.centre(r[4], 1.2)], ["flesh: deep in", F.centre(r[r.size() - 4]), F.centre(r[r.size() - 2], 1.2)], ["safe room", F.centre(s0), F.centre(s0, 0.6) + Vector3(1, 0, 0)]]:
		await _hold(F, v[0], v[1], v[2])
	print("STABILITY_TEST fails=%d" % fails)
	quit()

func _hold(L, name: String, pos: Vector3, at: Vector3) -> void:
	# (the world only: the HUD's fading objective and the subtitles aren't flicker)
	L.hud.visible = false
	root.get_node("Dialogue").stop(); root.get_node("Dialogue")._layer.visible = false
	L.player.global_position = pos; L.player.velocity = Vector3.ZERO
	await _wait(0.3)
	var d: Vector3 = at - L.player.cam.global_position
	L.player.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	await _wait(1.0)
	var first := _lum()
	var worst := 0.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		await _wait(0.2)
		var now := _lum()
		var changed := 0
		for i in now.size():
			if absf(now[i] - first[i]) > 0.06: changed += 1
		worst = maxf(worst, float(changed) / now.size())
	# (the flesh breathes: its walls move their edges a pixel, slowly; that's motion, not flicker)
	var limit := 0.04 if name.begins_with("flesh") else 0.015
	var ok := worst <= limit
	printerr(("  ok   " if ok else "  FAIL ") + "%s: %.2f%% of the picture changed while nothing moved" % [name, worst * 100.0])
	if not ok: fails += 1

func _lum() -> PackedFloat32Array:
	var img := root.get_viewport().get_texture().get_image()
	img.resize(320, 180, Image.INTERPOLATE_BILINEAR)
	var out := PackedFloat32Array(); out.resize(320 * 180)
	for y in 180:
		for x in 320:
			var c := img.get_pixel(x, y)
			out[y * 320 + x] = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	return out

func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame
