extends SceneTree
## Kurt's body, for looking down: there, the right size, standing on the floor under him, its
## feet stepping in turn when he walks, the knees forward when he crouches, the left sleeve
## reaching Socko's elbow, and gone while he lies on the floor.
## godot --headless --path hysteria -s tools/body_test.gd

var ok := true
func check(cond: bool, what: String) -> void:
	print(("  ok  " if cond else " FAIL ") + what)
	ok = ok and cond

func foot(b: Node, s: String) -> Vector3:
	return (b.parts["foot_" + s] as Node3D).position

func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate(); root.add_child(main)
	await process_frame; await process_frame
	main.encounter.skip(); main.socko_intro.skip()
	var p = main.player; var b = p.body
	p.global_position = Vector3(5.6, 0.02, 3.2); p.velocity = Vector3.ZERO
	for i in 30: await process_frame
	check(b != null and b.visible, "he has a body")
	var fl := foot(b, "l"); var fr := foot(b, "r")
	check(absf(fl.y - 0.069) < 0.02 and absf(fr.y - 0.069) < 0.02, "standing: both feet on the floor (ankles %.3f, %.3f)" % [fl.y, fr.y])
	check(fl.x < 0.0 and fr.x > 0.0 and fl.distance_to(fr) > 0.15 and fl.distance_to(fr) < 0.4, "a natural stance, feet %.2f m apart" % fl.distance_to(fr))
	var hipy: float = (b.parts.thigh_l as Node3D).transform * Vector3(0, 1, 0) .y if false else ((b.parts.thigh_l as Node3D).transform * Vector3(0, 1, 0)).y
	check(absf(hipy - 0.53 * 1.778) < 0.08, "the hips at his height's 53%% (%.2f m)" % hipy)
	# walking, down the hall: the feet take turns in front
	p.global_position = Vector3(9.3, 0.02, 4.55); p.yaw = PI * 0.5; p.velocity = Vector3.ZERO
	await physics_frame
	var leads := {}
	Input.action_press("move_forward")
	for i in 120:
		await physics_frame
		if i > 30: leads[foot(b, "l").z < foot(b, "r").z] = true
	Input.action_release("move_forward")
	check(leads.has(true) and leads.has(false), "walking: each foot takes its turn in front")
	# crouched: the knees come forward of the hips
	p.velocity = Vector3.ZERO; p.crouched = true
	for i in 60: await process_frame
	var knee: Vector3 = (b.parts.shank_l as Node3D).transform * Vector3(0, 1, 0)
	var hip: Vector3 = (b.parts.thigh_l as Node3D).transform * Vector3(0, 1, 0)
	check(knee.z < hip.z - 0.1 and hip.y < 0.7, "crouched: the hips down (%.2f m), the knees forward" % hip.y)
	p.crouched = false
	# the left sleeve reaches Socko's elbow
	for i in 30: await process_frame
	var up: MeshInstance3D = b.parts.upper_l
	var elbow_local: Vector3 = p.global_transform.affine_inverse() * main.socko.global_position
	check(up.visible and up.transform.origin.distance_to(elbow_local) < 0.01, "the left sleeve runs to Socko's elbow")
	# lying on the floor: no body to see
	p.eye_override = 0.25
	await process_frame; await process_frame
	check(not b.visible, "lying on the floor, it isn't drawn")
	print("BODY ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
