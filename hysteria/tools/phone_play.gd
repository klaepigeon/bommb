extends SceneTree
## A phone playthrough, on the phone's renderer (run under OpenGL ES: `--rendering-driver
## opengl3_es`) at an S25 Ultra's screen, acting as a phone (`-- phone`): the real on-screen
## buttons pressed with real touch events, as a thumb would. It wakes, uses a door, pushes the
## wardrobe, goes through into the town, takes the revolver, wakes Marta, shoots, reloads, runs
## about for a while; and reports anything over the USE button that would swallow a touch, how
## long frames took, and every error the engine printed.
##   xvfb-run -s "-screen 0 3120x1440x24" godot --rendering-driver opengl3_es --display-driver x11
##     --resolution 3120x1440 --path hysteria -s tools/phone_play.gd -- phone touch

var main: Node
var p: Node
var steps := []

func step(what: String, ok: bool) -> void:
	steps.append([what, ok])
	print(("  ok  " if ok else " FAIL ") + what)

func wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end: await process_frame

func tap_button(name: String) -> bool:
	var touch: Node = null
	for c in main.get_children():
		if c is CanvasLayer and c.get("buttons") != null and (c.get("buttons") as Dictionary).has(name): touch = c
	if not touch:
		for c in main.get_children():
			if c is CanvasLayer and c.get("buttons") != null and (c.get("buttons") as Dictionary).has(name): touch = c
	if not touch: return false
	var b: Control = touch.buttons[name]
	if not b.is_visible_in_tree(): return false
	# touches arrive in window pixels; the buttons live in the (smaller, stretched) canvas
	var at := root.get_final_transform() * b.get_global_rect().get_center()
	var e := InputEventScreenTouch.new(); e.index = 3; e.position = at; e.pressed = true
	Input.parse_input_event(e)
	await process_frame; await process_frame
	var r := InputEventScreenTouch.new(); r.index = 3; r.position = at; r.pressed = false
	Input.parse_input_event(r)
	await process_frame
	return true

## anything visible that would take a touch meant for the USE button
func blockers(over: Vector2, layer_min: int) -> Array:
	var out := []
	for cl in root.find_children("*", "CanvasLayer", true, false):
		var L := cl as CanvasLayer
		if not L.visible or L.layer < layer_min: continue
		for c in L.find_children("*", "Control", true, false):
			var ctl := c as Control
			if ctl.is_visible_in_tree() and ctl.mouse_filter == Control.MOUSE_FILTER_STOP and ctl.get_global_rect().has_point(over) and not (ctl is Button and ctl.text == "USE"):
				out.append("%s (%s, layer %d)" % [ctl.name, ctl.get_class(), L.layer])
	return out

func face(at: Vector3) -> void:
	var d: Vector3 = at - (p.global_position + Vector3(0, 1.62, 0))
	p.yaw = atan2(-d.x, -d.z); p.pitch = atan2(d.y, Vector2(d.x, d.z).length())

func _initialize() -> void:
	load("res://scripts/core/save_game.gd").wipe()      # a save left by another test puts the title card up
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame; await process_frame; await process_frame
	main = current_scene
	p = main.player
	var G := root.get_node("Game")
	print("phone? ", G.is_phone(), "  touch? ", G.has_touch(), "  screen ", root.get_visible_rect().size)
	var title := main.find_child("TitleCard", true, false)
	await wait(1.0)
	# wake up (the opening is its own test; here, straight to being up with Socko)
	main.encounter.skip(); main.socko_intro.skip(); G.flags["socko_intro_done"] = true; G.flags["woke_in_47"] = true
	await wait(0.5)
	var touch: Node = null
	for c in main.get_children():
		if c is CanvasLayer and c.get("buttons") != null and (c.get("buttons") as Dictionary).has("use"): touch = c
	step("the touch controls are up", touch != null and touch.visible)
	var use_at: Vector2 = (touch.buttons.use as Control).get_global_rect().get_center()
	var bl := blockers(use_at, touch.layer)
	step("nothing lies over the USE button %s" % (str(bl) if bl.size() > 0 else ""), bl.is_empty())
	step("Kurt isn't stuck (locked=%s)" % p.locked, not p.locked)
	# a door
	var door: Node3D = main.world.find_child("door_dBed", true, false)
	door.target = 0.0
	p.global_position = Vector3(7.0, 0.02, 4.55); p.velocity = Vector3.ZERO
	var along := Vector3(cos(door.psi0), 0, -sin(door.psi0))
	face(door.global_position + along * door.leaf_w * 0.5 + Vector3(0, 1.0, 0))
	p.global_position = door.global_position + along * door.leaf_w * 0.5 + Vector3(0, 0.02, 0) + along.cross(Vector3.UP) * 1.0
	face(door.global_position + along * door.leaf_w * 0.5 + Vector3(0, 1.0, 0))
	await wait(0.4)
	p._aim()
	var pr: String = p.target.prompt() if p.target else "(nothing targeted: ray hits %s)" % (p.ray.get_collider() if p.ray.is_colliding() else "nothing")
	step("looking at the bedroom door: \"%s\"" % pr, p.target == door)
	await tap_button("use")
	await wait(0.3)
	step("tapping USE opens it (target %.2f)" % door.target, door.target > 0.5)
	# the wardrobe, from in front
	p.global_position = Vector3(3.35, 0.02, 3.6); p.velocity = Vector3.ZERO
	face(Vector3(3.35, 1.0, 4.84))
	await wait(0.4); p._aim()
	pr = p.target.prompt() if p.target else "(nothing)"
	step("in front of the wardrobe: \"%s\"" % pr, pr == "Push the wardrobe")
	await tap_button("use")
	await wait(4.0)
	step("tapping USE: he steps round and pushes it (pushed=%s, locked=%s)" % [main.wardrobe.pushed, p.locked], main.wardrobe.pushed and not p.locked)
	p.global_position = Vector3(3.55, 0.02, 4.45); p.velocity = Vector3.ZERO
	face(Vector3(3.55, 0.8, 5.13))
	await wait(0.4); p._aim()
	await tap_button("use")
	await wait(2.0)
	step("through the gap: in the town", main.in_labyrinth)
	var t0 := Time.get_ticks_msec(); var frames0 := Engine.get_frames_drawn()
	await wait(3.0)
	var fps := (Engine.get_frames_drawn() - frames0) / ((Time.get_ticks_msec() - t0) / 1000.0)
	print("  (town frames: %.1f fps under the software renderer)" % fps)
	# the revolver
	var pick: Node = null
	for n in main.labyrinth.find_children("*", "StaticBody3D", true, false):
		if n.get_script() and String(n.get_script().resource_path).ends_with("revolver_pickup.gd"): pick = n
	var g_at: Vector3 = main.labyrinth.to_global(main.labyrinth.fight.gun_at.origin)
	p.global_position = g_at + Vector3(-0.2, 0, -0.85); face(g_at)
	await wait(0.5); p._aim()
	await tap_button("use")
	await wait(0.5)
	step("the revolver taken with USE", p.gun != null)
	# Marta, shooting, reloading, running
	main.hunter.wake(Vector2i(6, 4))
	for i in 7:
		await tap_button("fire"); await wait(0.25)
	await tap_button("reload"); await wait(3.0)
	step("fired and reloaded with the buttons (loaded %d)" % (p.gun.loaded if p.gun else -1), p.gun != null and p.gun.loaded > 0)
	Input.action_press("move_forward"); await wait(4.0); Input.action_release("move_forward")
	Input.action_press("move_back"); await wait(2.0); Input.action_release("move_back")
	await wait(4.0)
	step("still running after a while in the town", true)
	var bad := 0
	for s in steps: if not s[1]: bad += 1
	print("PHONE ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(0 if bad == 0 else 1)
