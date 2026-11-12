extends SceneTree
## Marta at the table and Marta on her feet, side by side, front and side:
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/marta_view.gd -- out=<dir>
func _initialize() -> void:
	await process_frame
	var out := "user://marta_view"
	for a in OS.get_cmdline_user_args(): if a.begins_with("out="): out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	var Build = load("res://scripts/core/build.gd"); var Tex = load("res://scripts/core/tex.gd"); var M = load("res://scripts/characters/marta_seated.gd")
	var w := Node3D.new(); root.add_child(w); current_scene = w
	Build.room(w, -3, -3, 3, 3, Tex.mat("parquet"), null)
	var l := OmniLight3D.new(); l.position = Vector3(0.5, 2.2, -1.6); l.light_energy = 2.2; l.omni_range = 6.0; l.light_color = Color("ffd8a8"); w.add_child(l)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color("4a4038")
	w.add_child(env)
	var a = M.new(false); w.add_child(a); a.position = Vector3(-0.7, 0, 0)
	var b = M.new(true); w.add_child(b); b.position = Vector3(0.7, 0, 0)
	var cam := Camera3D.new(); w.add_child(cam); cam.current = true
	for v in [["front", Vector3(0, 1.2, -2.6), Vector3(0, 0.9, 0)], ["side", Vector3(-2.4, 1.2, -0.6), Vector3(0, 0.9, 0)], ["face", Vector3(0.7, 1.65, -0.8), Vector3(0.7, 1.6, 0)]]:
		cam.position = v[1]; cam.look_at(v[2])
		var t0 := Time.get_ticks_msec(); while Time.get_ticks_msec() - t0 < 800: await process_frame
		root.get_viewport().get_texture().get_image().save_png(out.path_join(v[0] + ".png"))
	quit()
