extends SceneTree
## Renders Marta's two forms: godot --path . -s tools/marta_view.gd -- out=<dir>
func _initialize() -> void:
	await process_frame
	var out := "user://marta_view"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	var Build = load("res://scripts/core/build.gd"); var Tex = load("res://scripts/core/tex.gd"); var MB = load("res://scripts/characters/marta_body.gd")
	var w := Node3D.new(); root.add_child(w)
	Build.room(w, -3, -3, 3, 3, Tex.mat("parquet"), null)
	Build.lamp(w, Vector3(1, 2.3, 1.5), Color("ffd8a8"), 2.0, 8.0)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.ambient_light_color = Color("504540"); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	w.add_child(env)
	var cam := Camera3D.new(); w.add_child(cam); cam.current = true
	var a = MB.new("seated"); w.add_child(a); a.position = Vector3(-0.8, 0, 0)
	var b = MB.new("hunter"); w.add_child(b); b.position = Vector3(0.8, 0, 0)
	for v in [["front", Vector3(0, 1.2, -2.6)], ["side", Vector3(-2.6, 1.2, -0.5)], ["close_seated", Vector3(-0.8, 1.0, -1.1)]]:
		cam.position = v[1]; cam.look_at(Vector3(v[1].x * 0.3 if v[0] != "close_seated" else -0.8, 0.8, 0))
		for i in 10: await process_frame
		root.get_viewport().get_texture().get_image().save_png(out.path_join(v[0] + ".png"))
	quit()
