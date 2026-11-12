extends SceneTree
## Renders Socko's holds in first person to PNGs: godot --path . -s tools/socko_view.gd -- out=<dir>
func _initialize() -> void:
	await process_frame
	var Build = load("res://scripts/core/build.gd"); var Tex = load("res://scripts/core/tex.gd")
	var Player = load("res://scripts/player/player.gd"); var Socko = load("res://scripts/socko/socko.gd")
	var out := "user://socko_view"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	var w := Node3D.new(); root.add_child(w)
	Build.room(w, -3, -3, 3, 3, Tex.mat("parquet"), Tex.mat("plaster"))
	Build.wall(w, Vector2(-3, -3), Vector2(3, -3), Tex.mat("wallpaper"))
	Build.lamp(w, Vector3(0, 2.3, -1), Color("ffd8a8"), 1.6, 7.0)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.ambient_light_color = Color("403530"); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	w.add_child(env)
	var p = Player.new(); w.add_child(p); p.position = Vector3(0, 0, 1)
	var s = Socko.new(); w.add_child(s); s.attach(p); s.visible = true
	await process_frame
	for spec in [["out", "neutral", "ahead"], ["face", "happy", "kurt"], ["rub", "neutral", "ahead"], ["low", "neutral", "ahead"], ["out", "excited", "kurt"]]:
		s.hold = spec[0]; s.emotion = spec[1]; s.look = spec[2]
		for i in 90: await process_frame
		root.get_viewport().get_texture().get_image().save_png(out.path_join(spec[0] + "_" + spec[1] + ".png"))
		var hg = s.rig.head_global(); print(spec[0], " head in cam: ", p.cam.global_transform.affine_inverse() * hg.origin, " mouth faces: ", p.cam.global_transform.basis.inverse() * (-hg.basis.z))
	s.hold = "face"; s.cross_eyed = true
	for i in 60: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out.path_join("cross.png"))
	quit()
