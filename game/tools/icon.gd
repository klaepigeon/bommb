extends Node
## Renders the app icon's subject: Socko, turned to face you, grinning, on nothing (transparent).
## Needs a display:  godot --path . --rendering-driver opengl3 res://tools/icon.tscn -- --out=<dir>
## tools/make_icon.sh runs this and composes the launcher icons from it.

var out := "user://"
var vp: SubViewport
var cam: Camera3D
var socko: Socko
var _frames := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	vp = SubViewport.new()
	vp.size = Vector2i(1024, 1024)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.52, 0.5)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	vp.add_child(we)
	# He looks at whoever wears him: an "eye" at the origin stands in for Kurt, and the lens sits there too.
	var eye := Node3D.new()
	vp.add_child(eye)
	socko = Socko.new()
	eye.add_child(socko)
	socko.build()
	socko.visible = true
	socko.set_pose("talk", 0.0)
	socko.face_kurt = 1.0
	socko.expression = "wide_smile"
	socko.idle_clip = "Idle_Observing"
	cam = Camera3D.new()
	cam.fov = 44.0     # his head inside the launcher mask's safe zone, his arm running off the edge
	cam.near = 0.02
	vp.add_child(cam)
	cam.make_current()
	for spec in [[Vector3(0.25, 0.3, 0.1), Color(1.0, 0.86, 0.68), 1.6], [Vector3(-0.35, 0.05, 0.0), Color(0.6, 0.72, 1.0), 0.7], [Vector3(0.0, -0.3, -0.1), Color(1.0, 0.6, 0.45), 0.35]]:
		var l := OmniLight3D.new()
		l.light_color = spec[1]; l.light_energy = spec[2]; l.omni_range = 2.0; l.shadow_enabled = false
		vp.add_child(l)
		l.position = spec[0]

func _process(_d: float) -> void:
	_frames += 1
	if _frames == 90:
		# frame his head: the lens stays where his eyes are looking, and turns to him
		var head: Vector3 = socko.rig.head_global().origin
		cam.look_at(head + Vector3(0.0, 0.012, 0.0), Vector3.UP)
	if _frames == 110:
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png(out.path_join("socko_raw.png"))
		print("icon: wrote ", out.path_join("socko_raw.png"))
		get_tree().quit()
