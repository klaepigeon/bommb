extends SceneTree
## Marta across the chapter: at the table (hair over her face, then lifted and revealed), and on
## her feet at each stage of what she's becoming (0 the scare, 1 copy B, 2 copy C).
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/marta_stages.gd -- out=<dir>
func _initialize() -> void:
	await process_frame
	var out := "user://marta_stages"
	for a in OS.get_cmdline_user_args(): if a.begins_with("out="): out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	var Build = load("res://scripts/core/build.gd"); var Tex = load("res://scripts/core/tex.gd"); var M = load("res://scripts/characters/marta_seated.gd")
	var w := Node3D.new(); root.add_child(w); current_scene = w
	Build.room(w, -4, -3, 4, 3, Tex.mat("parquet"), null)
	var l := OmniLight3D.new(); l.position = Vector3(0.0, 2.4, -2.0); l.light_energy = 2.4; l.omni_range = 8.0; l.light_color = Color("ffd8a8"); w.add_child(l)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color("4a4038")
	w.add_child(env)
	var seated = M.new(false); w.add_child(seated); seated.position = Vector3(-2.4, 0, 0)
	var revealed = M.new(false); w.add_child(revealed); revealed.position = Vector3(-1.2, 0, 0)
	var s0 = M.new(true, 0); w.add_child(s0); s0.position = Vector3(0.0, 0, 0)
	var s1 = M.new(true, 1); w.add_child(s1); s1.position = Vector3(1.2, 0, 0)
	var s2 = M.new(true, 2); w.add_child(s2); s2.position = Vector3(2.5, 0, 0)
	var cam := Camera3D.new(); w.add_child(cam); cam.current = true
	await process_frame
	revealed.reveal(1.0, 0.01); revealed.face(Vector3(-1.2, 1.4, -2.0), 0.4); revealed.gaze = Vector3(-1.2, 1.4, -2.0)
	for b in [s0, s1, s2]:
		b.pose.sh_l = Vector3(0.1, 0.2, 0.2); b.pose.sh_r = Vector3(0.1, -0.2, -0.2); b.pose.spine = Vector3(-0.12, 0, 0)
	var hp: Vector3 = seated.head_pos()
	var fwd: Vector3 = -seated.global_basis.z
	for v in [["seated_head_front", hp + fwd * 0.55 + Vector3(0, 0.05, 0), hp], ["seated_head_side", hp + seated.global_basis.x * 0.6, hp], ["seated_head_high", hp + fwd * 0.45 + Vector3(0, 0.45, 0), hp]]:
		cam.position = v[1]; cam.look_at(v[2])
		var t1 := Time.get_ticks_msec(); while Time.get_ticks_msec() - t1 < 500: await process_frame
		root.get_viewport().get_texture().get_image().save_png(out.path_join(v[0] + ".png"))
	for v in [["front", Vector3(0.0, 1.3, -4.2), Vector3(0.0, 0.95, 0)], ["side", Vector3(-4.6, 1.3, -1.2), Vector3(0.0, 0.95, 0)],
			["seated_faces", Vector3(-1.8, 1.25, -1.1), Vector3(-1.8, 1.05, 0)]]:
		cam.position = v[1]; cam.look_at(v[2])
		var t0 := Time.get_ticks_msec(); while Time.get_ticks_msec() - t0 < 800: await process_frame
		root.get_viewport().get_texture().get_image().save_png(out.path_join(v[0] + ".png"))
	quit()
