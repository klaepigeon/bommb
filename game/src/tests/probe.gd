extends Node
## Debug: what does Kurt's look ray hit from here? (run: godot --headless --path . res://src/tests/probe.tscn)
var main: Node
func _ready() -> void:
	main = load("res://src/main.tscn").instantiate()
	main.args = {"autotest": "none"}
	add_child(main)
	await get_tree().process_frame
	await main.load_level("flat47", "")
	for i in 30: await get_tree().physics_frame
	Speech.stop_all()
	var p: Player = main.player
	var lvl: Level = main.level
	var arm := lvl.find_children("Armchair", "Prop", true, false)[0] as Prop
	print("PROBE armchair at ", arm.global_position, " mass ", arm.mass, " frozen ", arm.freeze, " sleeping ", arm.sleeping)
	await _probe(p, Vector3(arm.global_position.x + 1.2, 0, arm.global_position.z - 0.4), arm.global_position + Vector3(0, 0.4, 0))
	var i := p.verbs.map(func(v): return v.id).find("pull")
	p.begin_verb(i)
	for k in 90:
		await get_tree().physics_frame
		if k % 10 == 0: print("PROBE k=", k, " hold=", p._hold_verb.get("id", ""), " t=", snappedf(p._hold_t, 0.01), " focus=", p.focus, " pos=", arm.global_position, " v=", arm.linear_velocity, " kurt=", p.global_position)
	get_tree().quit()

func _probe(p: Player, from: Vector3, at: Vector3):
	p.global_position = from
	var d := at - (from + Vector3(0, p._eye, 0))
	p.rotation.y = atan2(-d.x, -d.z)
	p._pitch = atan2(d.y, Vector2(d.x, d.z).length()); p.head.rotation.x = p._pitch
	for i in 4: await get_tree().physics_frame
	var cam := p.camera
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_transform.basis.z * 2.2, 1 | 2 | 8 | 32)
	q.exclude = [p.get_rid()]
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	print("PROBE from ", from, " cam ", cam.global_position, " -> ", at, ": hit ", (hit.collider.name + " in " + hit.collider.get_parent().name) if hit else "nothing", " at ", hit.get("position"), " focus=", p.focus, " verbs=", p.verbs.map(func(v): return v.id))
