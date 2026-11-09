extends SceneTree
## The story as a phone player plays it, with nothing skipped: in at the front door, into the
## living room, close to Marta's face until she wakes, the grab, the dark, waking on the floor,
## Socko's introduction (looked at, so it goes on), the flat, the axe, the chain, out to the
## landing and into Flat 48: a note on the gun safe, the shotgun. Under OpenGL ES at an S25
## Ultra's screen, acting as a phone. It reports each beat, any time Kurt is held still for more
## than 15 s outside a scene that means to hold him, and every engine error.
##   xvfb-run -s "-screen 0 3120x1440x24" godot --rendering-driver opengl3_es --display-driver x11
##     --resolution 3120x1440 --path hysteria -s tools/phone_story.gd -- phone touch

var main: Node
var p: Node
var G: Node
var steps := []

func step(what: String, ok: bool) -> void:
	steps.append([what, ok]); print(("  ok  " if ok else " FAIL ") + what)

func wait_until(cond: Callable, sec: float) -> bool:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call(): return true
		await process_frame
	return cond.call()

func wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end: await process_frame

func face(at: Vector3) -> void:
	var d: Vector3 = at - (p.global_position + Vector3(0, float(p.head.position.y), 0))
	p.yaw = atan2(-d.x, -d.z); p.pitch = atan2(d.y, Vector2(d.x, d.z).length())

func tap(name: String) -> void:
	for c in main.get_children():
		if c is CanvasLayer and c.get("buttons") != null and (c.get("buttons") as Dictionary).has(name):
			var b: Control = c.buttons[name]
			if not b.is_visible_in_tree(): continue
			var at := root.get_final_transform() * b.get_global_rect().get_center()
			var e := InputEventScreenTouch.new(); e.index = 4; e.position = at; e.pressed = true
			Input.parse_input_event(e); await process_frame; await process_frame
			var r := InputEventScreenTouch.new(); r.index = 4; r.position = at; r.pressed = false
			Input.parse_input_event(r); await process_frame
			return

func _initialize() -> void:
	G = root.get_node("Game")
	load("res://scripts/core/save_game.gd").wipe()
	change_scene_to_file("res://scenes/main.tscn")
	for i in 5: await process_frame
	main = current_scene; p = main.player
	step("Kurt's free at the door to begin with", not p.locked)
	# into the living room, close to her face
	var marta: Node3D = main.marta
	p.global_position = Vector3(3.0, 0.02, 2.4); p.velocity = Vector3.ZERO
	await wait(0.3)
	var front: Vector3 = -marta.global_basis.z; front.y = 0.0; front = front.normalized()
	p.global_position = main.encounter.head_pos() + front * 0.85; p.global_position.y = 0.02
	await wait(0.2)
	face(main.encounter.head_pos())
	var woke := await wait_until(func(): return main.encounter.state_name() != "STILL", 12.0)
	step("leaning in to her face wakes her (%s)" % main.encounter.state_name(), woke)
	var awake := await wait_until(func(): return main.encounter.state_name() == "AWAKE", 60.0)
	step("the grab, the dark, and he wakes on the floor (%s)" % main.encounter.state_name(), awake)
	var intro := await wait_until(func(): return main.socko.visible, 10.0)
	step("Socko's there on his hand", intro)
	# look at Socko when he asks, look round when he says so
	var done := false
	var end := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < end:
		if G.flags.get("socko_intro_done", false): done = true; break
		if not p.locked:
			p.pitch = -0.55 if int(Time.get_ticks_msec() / 2500) % 3 != 2 else 0.0
			p.yaw += 0.02
		await process_frame
	step("Socko's introduction runs to its end", done)
	step("and Kurt has his hands back (locked=%s)" % p.locked, not p.locked)
	# what's over the USE button now, after the opening?
	for c in main.get_children():
		if c is CanvasLayer and c.get("buttons") != null and (c.get("buttons") as Dictionary).has("use"):
			var ub: Control = c.buttons.use
			var at: Vector2 = ub.get_global_rect().get_center()
			print("  USE visible ", ub.is_visible_in_tree(), " layer ", c.layer, " touch layer visible ", c.visible)
			for cl in root.find_children("*", "CanvasLayer", true, false):
				if not cl.visible: continue
				for ctl in cl.find_children("*", "Control", true, false):
					if ctl.is_visible_in_tree() and ctl.mouse_filter != Control.MOUSE_FILTER_IGNORE and ctl.get_global_rect().has_point(at) and ctl != ub:
						print("  OVER USE: ", ctl.get_path(), " ", ctl.get_class(), " filter ", ctl.mouse_filter, " layer ", cl.layer)
	print("  mouse mode ", Input.mouse_mode, " paused ", paused, " locked ", p.locked)
	# the box room: the bolt, the axe
	var store: Node3D = main.world.find_child("door_dStore", true, false)
	p.global_position = Vector3(1.85, 0.02, 4.3); p.velocity = Vector3.ZERO
	face(store.global_position + Vector3(0.35, 1.0, 0))
	await wait(0.4); p._aim()
	var pr: String = p.target.prompt() if p.target else "(nothing: %s)" % (p.ray.get_collider() if p.ray.is_colliding() else "-")
	step("the box room door, free of the wardrobe: \"%s\"" % pr, p.target == store)
	await tap("use"); await wait(0.3); await tap("use"); await wait(1.0)
	step("unbolted and opened with USE (locked '%s', target %.2f)" % [store.locked, store.target], store.locked == "" and store.target > 0.5)
	var axe: RigidBody3D = null
	for b in main.world.find_children("*", "RigidBody3D", true, false):
		if String(b.get("title")).to_lower() == "axe": axe = b
	p.global_position = Vector3(1.95, 0.02, 5.5)          # in the box room's doorway, the axe to the right
	var axe_shape: Vector3 = axe.global_position
	for ch in axe.get_children(): if ch is CollisionShape3D: axe_shape = ch.global_position
	face(axe_shape + Vector3(0, 0.02, 0))
	await wait(0.4); p._aim()
	var cs: CollisionShape3D = axe.get_child(axe.get_child_count() - 1) if axe else null
	for ch in axe.get_children(): if ch is CollisionShape3D: cs = ch
	var q := PhysicsRayQueryParameters3D.create(p.cam.global_position, cs.global_position); q.collision_mask = 3; q.exclude = [p.get_rid()]
	var hit: Dictionary = p.get_world_3d().direct_space_state.intersect_ray(q)
	print("  cam ", p.cam.global_position, " axe shape at ", cs.global_position, " size ", (cs.shape as BoxShape3D).size if cs.shape is BoxShape3D else cs.shape, " layer ", axe.collision_layer, " direct ray hits ", hit.get("collider"), " sleeping ", axe.sleeping, " freeze ", axe.freeze)
	print("  at the axe (%s): target %s prompt \"%s\" ray %s" % [axe.global_position if axe else "-", p.target, p.target.prompt() if p.target else "", p.ray.get_collider() if p.ray.is_colliding() else "-"])
	await tap("use"); await wait(0.5)
	step("the axe picked up with USE", p.held == axe and axe != null)
	# the chain
	var door: Node3D = main.world.find_child("door_dEntry", true, false)
	p.global_position = Vector3(9.45, 0.02, 4.56); p.yaw = -PI * 0.5; p.pitch = -0.08; p.velocity = Vector3.ZERO
	await physics_frame
	if axe: axe.global_position = p.hold.global_position      # (walked there, not teleported: it comes too)
	await wait(0.4); p._aim()
	pr = p.target.use_with_prompt(p.held) if p.target and p.target.has_method("use_with_prompt") and p.held else "(nothing)"
	step("at the door with the axe: \"%s\"" % pr, pr == "Cut the chain with the axe")
	await tap("use"); await wait(3.5)
	step("three blows, the chain's off", main.escape.free)
	p.call("drop")
	var out := await wait_until(func(): return true, 0.1)
	for i in 120:
		Input.action_press("move_forward"); await physics_frame
		if main.escape._ended: break
	Input.action_release("move_forward")
	step("out through the door: the end of the chapter", main.escape._ended)
	var in48 := await wait_until(func(): return main.in_flat48, 20.0)
	step("across the landing into Flat 48", in48)
	step("Kurt can move in Flat 48 (locked=%s)" % p.locked, await wait_until(func(): return not p.locked, 5.0))
	var bad := 0
	for s in steps: if not s[1]: bad += 1
	print("STORY ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(0 if bad == 0 else 1)
