extends SceneTree
## Renders the exported flat through ExportedFlat from fixed points (no story):
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/flat_view.gd -- out=<dir> flesh=0
func _initialize() -> void:
	await process_frame
	var out := "user://flat_view"; var flesh := 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
		if a.begins_with("flesh="): flesh = float(a.substr(6))
	DirAccess.make_dir_recursive_absolute(out)
	var EF = load("res://scripts/world/exported_flat.gd")
	var w := Node3D.new(); root.add_child(w); current_scene = w
	var env := WorldEnvironment.new(); env.environment = Environment.new(); var e := env.environment
	e.background_mode = Environment.BG_COLOR; e.background_color = Color("262a31")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color("46505e"); e.ambient_light_energy = 0.12
	e.tonemap_mode = Environment.TONE_MAPPER_ACES; e.tonemap_exposure = 1.15
	w.add_child(env)
	var t0 := Time.get_ticks_msec()
	var f = EF.new(flesh); w.add_child(f)
	print("flat built in ", Time.get_ticks_msec() - t0, " ms; doors ", f.doors.keys(), " drawers ", f.drawers.size(), " props ", f.props.size(), " lights ", f.fittings.size())
	var cam := Camera3D.new(); w.add_child(cam); cam.current = true; cam.fov = 72.0; cam.near = 0.03
	for v in [["hall", Vector3(9.4, 1.6, 4.5), Vector3(5, 1.2, 4.5)], ["living", Vector3(4.0, 1.6, 4.4), Vector3(1.5, 0.9, 1.0)],
			["table", Vector3(3.9, 1.5, 2.2), Vector3(2.4, 0.8, 1.4)], ["kitchen", Vector3(8.0, 1.6, 3.4), Vector3(9.5, 1.0, 0.8)],
			["bedroom", Vector3(7.0, 1.6, 3.4), Vector3(5.0, 1.0, 0.5)], ["landing", Vector3(12.8, 1.6, 4.4), Vector3(10.0, 1.2, 4.15)],
			["wardrobe", Vector3(2.0, 1.6, 2.5), Vector3(1.95, 1.0, 5.0)], ["balcony", Vector3(2.4, 1.6, -0.9), Vector3(2.4, 1.5, -6.0)]]:
		cam.position = v[1]; cam.look_at(v[2])
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 1500: await process_frame
		root.get_viewport().get_texture().get_image().save_png(out.path_join(v[0] + ".png"))
	print("FLAT_VIEW done")
	quit()
