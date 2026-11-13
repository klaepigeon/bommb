extends SceneTree
## The sculpted inhabitants (assets/people), lit like the building, from the front, three-quarter,
## the side, the back, and the face close; then posed (walking, the attack's windup, talking).
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/people_view.gd -- model=super out=<dir> [light=torch|room]
func _initialize() -> void:
	await process_frame
	var out := "user://people_view"
	var model := "super"
	var light := "room"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
		if a.begins_with("model="): model = a.substr(6)
		if a.begins_with("light="): light = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	var w := Node3D.new(); root.add_child(w)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.03, 0.03, 0.035)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.25, 0.24, 0.22)
	env.environment.ambient_light_energy = 0.5
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	w.add_child(env)
	var floor := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(8, 8); floor.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(0.25, 0.23, 0.2); floor.material_override = fm; w.add_child(floor)
	var bulb := OmniLight3D.new(); bulb.position = Vector3(0.6, 2.6, -1.2); bulb.light_color = Color(1.0, 0.85, 0.6); bulb.light_energy = 2.2; bulb.omni_range = 7.0; bulb.shadow_enabled = true
	w.add_child(bulb)
	var cam := Camera3D.new(); cam.fov = 50; w.add_child(cam); cam.current = true
	var torch := SpotLight3D.new(); torch.light_energy = 3.0 if light == "torch" else 0.8; torch.spot_range = 9.0; torch.spot_angle = 30; torch.shadow_enabled = true
	cam.add_child(torch)
	if light == "torch": bulb.light_energy = 0.25
	var FB = load("res://scripts/ai/flesh_body.gd")
	var b = FB.new({"model": model, "height": 1.8, "keys": model == "super", "girth": 1.45})
	w.add_child(b)
	await process_frame
	var h: float = 1.0 if model == "crawler" else 2.0
	var shots := [["front", Vector3(0, h * 0.55, -2.6 * h / 2.0), Vector3(0, h * 0.48, 0)],
		["three", Vector3(1.6, h * 0.6, -2.0) * Vector3(h / 2.0, 1, h / 2.0), Vector3(0, h * 0.48, 0)],
		["side", Vector3(2.6 * h / 2.0, h * 0.55, 0), Vector3(0, h * 0.48, 0)],
		["back", Vector3(0.6, h * 0.6, 2.4 * h / 2.0), Vector3(0, h * 0.48, 0)]]
	var head: Vector3 = b.at("head") + Vector3(0, 0.12, 0)
	shots.append(["face", head + Vector3(0.12, 0.02, -0.55), head])
	shots.append(["face_low", head + Vector3(-0.25, -0.25, -0.4), head])
	for s in shots:
		cam.global_position = s[1]; cam.look_at(s[2])
		await _frames(4)
		root.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s.png" % [model, s[0]]))
	# posed
	var poses := {
		"walk": {"hip_l": Vector3(0.45, 0, 0), "hip_r": Vector3(-0.4, 0, 0), "kn_l": Vector3(-0.2, 0, 0), "kn_r": Vector3(-0.7, 0, 0), "sh_l": Vector3(-0.3, 0, 0.08), "sh_r": Vector3(0.3, 0, -0.08), "spine": Vector3(-0.15, 0, 0)},
		"windup": {"sh_l": Vector3(-1.4, 0, 0.5), "sh_r": Vector3(-1.4, 0, -0.5), "el_l": Vector3(-0.9, 0, 0), "el_r": Vector3(-0.9, 0, 0), "spine": Vector3(0.3, 0, 0), "jaw": Vector3(0.9, 0, 0)},
		"reach": {"sh_l": Vector3(1.5, 0, 0.1), "sh_r": Vector3(1.4, 0, -0.1), "spine": Vector3(-0.4, 0, 0), "jaw": Vector3(1.1, 0, 0), "head": Vector3(0.3, 0, 0)},
		"sit": {"hip_l": Vector3(1.4, 0, 0), "hip_r": Vector3(1.4, 0, 0), "kn_l": Vector3(-1.5, 0, 0), "kn_r": Vector3(-1.5, 0, 0), "sh_r": Vector3(0.6, 0, 0), "el_r": Vector3(-1.0, 0, 0)}}
	for pn in poses:
		for k in b.pose: b.pose[k] = poses[pn].get(k, Vector3.ZERO)
		b.snap = 40.0
		await _frames(30)
		cam.global_position = Vector3(1.4, h * 0.6, -2.0) * Vector3(h / 2.0, 1, h / 2.0); cam.look_at(Vector3(0, h * 0.45, 0))
		await _frames(3)
		root.get_viewport().get_texture().get_image().save_png(out.path_join("%s_pose_%s.png" % [model, pn]))
	quit()

func _frames(n: int) -> void:
	for i in n: await process_frame
