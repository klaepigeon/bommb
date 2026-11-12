extends SceneTree
## Plays the chapter like a person: walks with the move key, turns to face things, presses the
## interact key only when the crosshair is on the thing and the prompt says what's expected, opens
## doors it walks into. No teleporting. Routes are planned on the flat's walkable grid. A step
## that can't be done (stuck, nothing to press) fails and says where.
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/walkthrough.gd -- out=<dir>

var game
var dlg
var out := "user://walkthrough"
var fails := 0
var L
var grid: AStarGrid2D
var grid_origin := Vector3.ZERO
var _tried: Array = []     # doors already tried on the way (a jammed one stays 'Open')
const CELL := 0.2

func _initialize() -> void:
	await process_frame
	for a in OS.get_cmdline_user_args(): if a.begins_with("out="): out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	game = root.get_node("Game"); dlg = root.get_node("Dialogue")
	game.settings.post_fx = true
	game.reset_save()
	game.new_game()
	await _until(func(): return game.level != null and game.level_id == "flat47", 20.0, "Flat 47 loads")
	L = game.level
	_use_grid(L.flat, Vector3.ZERO)
	await _until(func(): return L.player.controls and not dlg.busy, 60.0, "the knocking ends")
	await _shot("w01_landing")
	# ---- in through the front door
	await _walk_to(Vector3(11.0, 0, 4.56), "to the front door", true)
	if not L.front_door.is_open: await _use(L.FRONT + Vector3(0.0, 1.1, 0.0), "Open door", "open the front door")
	_check(L.front_door.is_open, "the front door is open")
	await _walk_to(Vector3(9.2, 0, 4.5), "into the hall")
	await _until(func(): return dlg.busy, 4.0, "'Christ...'")
	await _shot("w02_hall")
	await _until(func(): return not dlg.busy, 10.0, "line ends")
	# ---- to the living room; see her; look at her
	await _walk_to(Vector3(3.6, 0, 3.4), "into the living room")
	await _face(L._face())
	await _until(func(): return L.marta_spot.enabled, 6.0, "seeing her offers 'Look at her'")
	await _until(func(): return not dlg.busy, 10.0, "'Oh... oh no.' ends")
	await _walk_to(Vector3(3.6, 0, 2.2), "up to her")
	await _use(L._face(), "Look at her", "look at Marta")
	await _until(func(): return dlg.speaking == "marta", 30.0, "she speaks")
	await _shot("w03_marta")
	await _until(func(): return L._woke and L.player.controls, 120.0, "grab, blackout, waking, Socko")
	await _shot("w04_awake")
	# ---- the front door won't open
	await _walk_to(Vector3(9.4, 0, 4.56), "back to the front door")
	await _use(L.FRONT + Vector3(0.0, 1.1, 0.0), "Open door", "try the front door")
	await _until(func(): return Game_flag("door_tried") and not dlg.busy, 30.0, "'It won't open.' conversation")
	# ---- the wardrobe
	await _walk_to(Vector3(2.0, 0, 3.9), "to the wardrobe")
	await _use(L.wardrobe.global_position + Vector3(0, 1.0, -0.2), "Push wardrobe", "push the wardrobe")
	await _until(func(): return L.hole_parts.visible, 15.0, "the hole")
	await _until(func(): return L.player.controls and not dlg.busy, 40.0, "the hole conversation")
	await _shot("w05_hole")
	# ---- the pistol in the kitchen drawer
	var dpos: Vector3 = L.gun_drawer.global_position
	var front: Vector3 = dpos + L.gun_drawer.global_basis.z * 0.8
	await _walk_to(Vector3(front.x, 0, front.z), "to the kitchen drawer")
	await _use(dpos, "Open drawer", "open the drawer")
	await _wait(1.0)
	await _use(L.gun_drawer.global_position + Vector3(0, 0.08, 0), "Take pistol", "take the pistol")
	_check(game.pistol.have, "has the pistol")
	await _shot("w06_pistol")
	# ---- the balcony
	await _walk_to(Vector3(3.2, 0, 0.45), "to the balcony door")
	if not L.balcony_door.is_open: await _use(Vector3(3.15, 1.0, -0.1), "Open balcony door", "open the balcony door")
	_check(L.balcony_door.is_open, "the balcony door is open")
	await _wait(1.0)
	await _walk_to(Vector3(3.17, 0, -0.45), "through the balcony doorway", false, true)
	await _walk_to(Vector3(2.4, 0, -0.9), "out onto the balcony", false, true)
	await _until(func(): return dlg.busy, 6.0, "'You seeing this?'")
	await _shot("w07_balcony")
	await _until(func(): return not dlg.busy and L.player.controls, 30.0, "balcony conversation ends")
	# ---- into the hole
	await _walk_to(Vector3(1.82, 0, 4.2), "to the hole")
	await _use(L.HOLE + Vector3(0, 0.9, 0), "Crawl in", "crawl in")
	await _until(func(): return game.level_id == "flesh47" and game.level != L, 40.0, "crawling in loads level 2")
	L = game.level
	await _until(func(): return L.player.controls, 40.0, "out of the hole into copy A")
	await _shot("w08_copy_a")
	L.marta.active = false; L._encountered = true     # (her hunting is tested on its own: tools/hunt_test.gd)
	L.marta.global_position = Vector3(-40, 0, -40)
	# ---- the maze: the way through, cell to cell, through its doorways
	var route: Array = L.maze.path
	for i in range(1, route.size()):
		var c: Vector2i = route[i]
		if L.maze.cracked.any(func(pr): return (pr[0] == route[i - 1] and pr[1] == c) or (pr[1] == route[i - 1] and pr[0] == c)): continue
		await _walk_line(L.centre(c), "maze: cell %d of %d %s" % [i, route.size() - 1, c], i % 6 == 0 or i == route.size() - 1)
		if L.maze.safe.has(c): pass
	await _shot("w09_maze_end")
	# ---- through 48's door
	await _walk_dir(Vector3(L.maze.w * L.CELL + 0.9, 0, L.centre(L.maze.exit).z), 4.0)
	await _shot("w11_exit")
	await _until(func(): return current_scene != null and current_scene.name == "Title", 40.0, "through 48's door: the chapter ends")
	print("WALKTHROUGH fails=%d" % fails)
	quit()

func Game_flag(k: String) -> bool:
	return game.flag(k)

# ------------------------------------------------------------------ moving like a player
func _use_grid(flat, offset: Vector3) -> void:
	grid = flat.nav_grid(CELL, 0.26, 0.2, true)
	grid_origin = offset + Vector3(-0.5, 0, -2.0)

func _cell(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - grid_origin.x) / CELL), floori((p.z - grid_origin.z) / CELL))

func _centre(c: Vector2i) -> Vector3:
	return grid_origin + Vector3((c.x + 0.5) * CELL, 0, (c.y + 0.5) * CELL)

func _free(c: Vector2i) -> Vector2i:
	if grid.is_in_boundsv(c) and not grid.is_point_solid(c): return c
	for r in range(1, 6):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if grid.is_in_boundsv(n) and not grid.is_point_solid(n): return n
	return c

## Walk to a point along a planned route, holding the move key, steering by turning. Doors in
## the way get opened (interact, when the crosshair's on one that says "Open"). `direct`: no grid
## (outside the flat). Fails if no progress for 4 s.
func _walk_to(target: Vector3, what: String, direct := false, straight := false) -> void:
	var p = L.player
	if L.has_method("_push_wardrobe"): _use_grid(L.flat, Vector3.ZERO)
	var pts := []
	if direct or straight:
		pts = [target]
	else:
		var a := _free(_cell(p.global_position)); var b := _free(_cell(target))
		var ids := grid.get_id_path(a, b, false)
		if ids.is_empty():
			print("    no route from ", a, " to ", b, ":")
			for y in grid.region.size.y:
				var row := ""
				for x in grid.region.size.x:
					var c := Vector2i(x, y)
					row += "S" if c == a else ("T" if c == b else ("#" if grid.is_point_solid(c) else "."))
				print("    ", row)
		for i in range(0, ids.size(), 2): pts.append(_centre(ids[i]))
		pts.append(target)
	var best := INF; var last_gain := Time.get_ticks_msec()
	var t_start := Time.get_ticks_msec()
	var i := 0
	while i < pts.size():
		var goal: Vector3 = pts[i]
		var d: Vector3 = goal - p.global_position; d.y = 0
		if d.length() < (0.25 if i < pts.size() - 1 else 0.35):
			i += 1; best = INF; last_gain = Time.get_ticks_msec(); continue
		p.set_view(atan2(-d.x, -d.z), -0.1)
		Input.action_press("move_forward")
		await physics_frame
		# a closed door in the way: open it
		if p.target and p.target.has_method("get_prompt") and String(p.target.get_prompt()).begins_with("Open") and not _tried.has(p.target):
			_tried.append(p.target)
			Input.action_release("move_forward")
			_press("interact")
			await _wait(0.9)
		var dist: float = (goal - p.global_position).length()
		if dist < best - 0.02:
			best = dist; last_gain = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - last_gain > 4000:
			Input.action_release("move_forward")
			var hits := []
			for k in p.get_slide_collision_count():
				var c = p.get_slide_collision(k)
				if absf(c.get_normal().y) < 0.7: hits.append("%s/%s" % [c.get_collider().get_parent().name, c.get_collider().name])
			_check(false, "%s: stuck at %s (heading for %s) against %s; vel %s controls %s target %s" % [what, _v(p.global_position), _v(goal), hits, p.velocity, p.controls, p.target])
			return
		if Time.get_ticks_msec() - t_start > 60000:
			Input.action_release("move_forward"); _check(false, what + ": took too long"); return
	Input.action_release("move_forward")
	_check(true, "%s (%.1f s)" % [what, (Time.get_ticks_msec() - t_start) / 1000.0])

## Walk straight at a point for a while (through a doorway into the dark).
## Straight there, the move key held, checking he gets there (the maze's doorways line up with
## the cell centres; its furniture stands against the walls).
func _walk_line(target: Vector3, what: String, report := true) -> void:
	var p = L.player
	var t0 := Time.get_ticks_msec(); var last: Vector3 = p.global_position; var stuck := 0.0
	while Time.get_ticks_msec() - t0 < 12000 and p.controls:
		var d: Vector3 = target - p.global_position; d.y = 0
		if d.length() < 0.35: break
		p.set_view(atan2(-d.x, -d.z), -0.1)
		Input.action_press("move_forward")
		await physics_frame
		if p.global_position.distance_to(last) < 0.004: stuck += 1.0 / 60.0
		else: stuck = 0.0
		last = p.global_position
		if stuck > 1.5: break
	Input.action_release("move_forward")
	var ok: bool = Vector2(target.x - p.global_position.x, target.z - p.global_position.z).length() < 0.5
	if report or not ok: _check(ok, what + ("" if ok else " (stuck at %s)" % _v(p.global_position)))

func _walk_dir(target: Vector3, secs: float) -> void:
	var p = L.player
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0 and L == game.level and p.controls:
		var d: Vector3 = target - p.global_position; d.y = 0
		if d.length() < 0.3: break
		p.set_view(atan2(-d.x, -d.z), -0.1)
		Input.action_press("move_forward")
		await physics_frame
	Input.action_release("move_forward")

func _face(at: Vector3) -> void:
	var p = L.player
	var d: Vector3 = at - p.cam.global_position
	p.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	await _wait(0.3)

## Look at something; if the prompt is what a player would see, press interact.
func _use(at: Vector3, prompt: String, what: String) -> void:
	await _face(at)
	var p = L.player
	var t0 := Time.get_ticks_msec()
	# sweep the view a little if the crosshair is just off it
	var offsets := [Vector2.ZERO, Vector2(0.05, 0), Vector2(-0.05, 0), Vector2(0, 0.06), Vector2(0, -0.06), Vector2(0.1, 0.05), Vector2(-0.1, 0.05), Vector2(0, -0.12)]
	var y0: float = p.get_yaw(); var pi0: float = p.get_pitch()
	for o in offsets:
		p.set_view(y0 + o.x, pi0 + o.y)
		await _wait(0.12)
		if String(p.prompt()).contains(prompt) or (prompt.begins_with("Open") and String(p.prompt()).contains(prompt.replace("Open", "Close"))):
			_press("interact")
			await _wait(0.3)
			_check(true, what)
			return
	p.set_view(y0, pi0); await _wait(0.1)
	p.ray.force_raycast_update()
	var rc = p.ray.get_collider()
	_check(false, "%s: no '%s' prompt (saw '%s', at %s; crosshair on %s at %s)" % [what, prompt, p.prompt(), _v(p.global_position), ("%s/%s" % [rc.get_parent().name, rc.name]) if rc else "nothing", p.ray.get_collision_point() if rc else ""])

func _press(action: String) -> void:
	var e := InputEventAction.new(); e.action = action; e.pressed = true
	Input.parse_input_event(e)
	var r := InputEventAction.new(); r.action = action; r.pressed = false
	Input.parse_input_event(r)

# ------------------------------------------------------------------ test plumbing
func _v(v: Vector3) -> String: return "(%.2f, %.2f)" % [v.x, v.z]

func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1

func _until(cond: Callable, secs: float, what: String) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0:
		if cond.call():
			_check(true, what); return
		await process_frame
	_check(false, what + " (timed out)")

func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame

func _shot(name: String) -> void:
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
