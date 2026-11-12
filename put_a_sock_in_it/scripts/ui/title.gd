extends Node3D
## The title: a dark corner of the flat under a bulb on its way out, dust in its light, and
## Socko on a hand, held up to you, looking about, and now and then at you. Behind the
## choices, the knocking at a door.

var socko: Socko
var cam: Camera3D
var _t := 0.0
var _next := 3.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Fx.reset({"grain": 0.07, "vignette": 0.7})
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	var e := env.environment
	e.background_mode = Environment.BG_COLOR; e.background_color = Color.BLACK
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color("1e1a17")
	e.fog_enabled = true; e.fog_light_color = Color("0c0a09"); e.fog_density = 0.12
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var w := Node3D.new(); add_child(w)
	Build.room(w, -2, -2, 2, 2, Tex.mat("parquet", 1.2), Tex.mat("plaster", 0.7))
	Build.wall(w, Vector2(-2, -1.2), Vector2(2, -1.2), Tex.mat("wallpaper"))
	Build.wall(w, Vector2(-1.4, -2), Vector2(-1.4, 2), Tex.mat("wallpaper"))
	for i in 5:
		var mi := Build.box(w, Vector3(-1.15 + i * 0.27, 1.3 + (i % 2) * 0.2, -1.13), Vector3(0.21, 0.29, 0.004), Tex.mat("paper_boxes", 3.0), false)
		mi.rotation.z = randf_range(-0.15, 0.15)
	Build.box(w, Vector3(0.9, 0.25, -0.9), Vector3(0.5, 0.5, 0.5), Tex.mat("cardboard", 3.0), false, 0.3)
	Build.box(w, Vector3(0.95, 0.68, -0.95), Vector3(0.36, 0.36, 0.36), Tex.mat("cardboard", 3.0), false, -0.2)
	var bulb := Fitting.make(w, Vector3(0.1, 2.2, 0.2), Color("ffcf8a"), 1.4, 5.0, "dying", false)
	var b := Build.box(w, Vector3(0.1, 2.2, 0.2), Vector3(0.05, 0.07, 0.05), Tex.mat("enamel", 1.0, {"emission": Vector3(1.4, 1.2, 0.8)}), false)
	bulb.add_glow(b, Vector3(1.4, 1.2, 0.8))
	Build.box(w, Vector3(0.1, 2.48, 0.2), Vector3(0.01, 0.5, 0.01), Tex.mat("black"), false)
	Air.dust(w, Vector3(0, 1.3, 0), Vector3(1.4, 1.2, 1.2), 500)
	cam = Camera3D.new(); cam.fov = 60.0; cam.near = 0.02; w.add_child(cam)
	cam.position = Vector3(0.2, 1.45, 0.9); cam.rotation = Vector3(-0.05, 0.12, 0)
	cam.current = true
	var mount := Node3D.new(); cam.add_child(mount); mount.position = Vector3(-0.02, 0.06, -0.06)
	socko = Socko.new(); mount.add_child(socko)
	socko.visible = true; socko.hold = "face"; socko.look = "kurt"; socko.emotion = "neutral"
	Sfx.set_room(0.4, 0.18)
	Sfx.loop("drone", "drone", -22.0)
	_ui()

func _ui() -> void:
	var layer := CanvasLayer.new(); layer.layer = 20; add_child(layer)
	# a soft dark band behind the words, so they read over the papers on the wall
	var back := TextureRect.new()
	var g := Gradient.new(); g.set_color(0, Color(0, 0, 0, 0.0)); g.set_color(1, Color(0, 0, 0, 0.62))
	g.add_point(0.25, Color(0, 0, 0, 0.45))
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(0.5, 0); gt.width = 256; gt.height = 4
	back.texture = gt; back.stretch_mode = TextureRect.STRETCH_SCALE; back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.anchor_left = 0.48; back.anchor_right = 1.0; back.anchor_top = 0.0; back.anchor_bottom = 1.0
	layer.add_child(back)
	var v := VBoxContainer.new()
	var ending: bool = Game.demo_over
	v.anchor_left = 0.58; v.anchor_right = 0.97; v.anchor_top = 0.06 if ending else 0.2; v.anchor_bottom = 0.97
	v.add_theme_constant_override("separation", 6 if ending else 14)
	layer.add_child(v)
	var t := Label.new(); t.text = "PUT A SOCK\nIN IT"
	t.add_theme_font_size_override("font_size", 44 if ending else 64); t.add_theme_color_override("font_color", Color("e2d6b8"))
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9)); t.add_theme_constant_override("shadow_offset_y", 4)
	v.add_child(t)
	var sub := Label.new(); sub.text = "Kerzhansk, 1996"
	sub.add_theme_font_size_override("font_size", 20); sub.add_theme_color_override("font_color", Color("8f8470"))
	v.add_child(sub)
	if Game.demo.get("is_demo", false):
		var tag := Label.new(); tag.text = "DEMO"
		tag.add_theme_font_size_override("font_size", 18); tag.add_theme_color_override("font_color", Color("b0322a"))
		v.add_child(tag)
	if Game.demo_over:
		Game.demo_over = false
		_end_panel(v)
		return
	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 40); v.add_child(gap)
	if Game.has_save(): _btn(v, "Continue", func(): _go(Game.continue_game))
	_btn(v, "New game", func(): _go(func(): Game.reset_save(); Game.new_game()))
	_btn(v, "Quit", func(): get_tree().quit())

## The end of the demo: thanks, how his night went (an invitation to go again and do it
## differently), and where to follow the game. Links come from data/demo.json.
func _end_panel(v: VBoxContainer) -> void:
	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 10); v.add_child(gap)
	var th := Label.new(); th.text = "Thanks for playing the demo."
	th.add_theme_font_size_override("font_size", 28); th.add_theme_color_override("font_color", Color("e2d6b8"))
	v.add_child(th)
	var r: Dictionary = Game.run
	var mins := int(r.time) / 60; var secs := int(r.time) % 60
	var lines := [
		"Time  %d:%02d" % [mins, secs],
		"Caught  %d" % int(r.caught),
		"Hid from her  %d" % int(r.hid),
		"Put her down  %d" % int(r.stuns),
		"Memories found  %d of 3" % int(r.memories),
		"Secrets  %d of 1" % (1 if Game.flag("read_pembis") else 0),
	]
	var grid := GridContainer.new(); grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28); grid.add_theme_constant_override("v_separation", 2)
	for ln in lines:
		var st := Label.new(); st.text = ln
		st.add_theme_font_size_override("font_size", 18); st.add_theme_color_override("font_color", Color("a39780"))
		grid.add_child(st)
	v.add_child(grid)
	var gap2 := Control.new(); gap2.custom_minimum_size = Vector2(0, 14); v.add_child(gap2)
	var d: Dictionary = Game.demo
	if String(d.get("store_url", "")) != "":
		_btn(v, String(d.get("store_label", "Wishlist")), func(): OS.shell_open(String(d.store_url)), true)
	if String(d.get("follow_url", "")) != "":
		_btn(v, String(d.get("follow_label", "Follow")), func(): OS.shell_open(String(d.follow_url)))
	_btn(v, "Play again", func(): _go(func(): Game.reset_save(); Game.new_game()))
	_btn(v, "Quit", func(): get_tree().quit())
	socko.look = "kurt"; socko.emotion = "happy"; socko.gesture("tilt")

func _go(f: Callable) -> void:
	Sfx.stop_loops()
	f.call()

func _btn(v: VBoxContainer, t: String, cb: Callable, loud := false) -> void:
	var b := Button.new(); b.text = t; b.custom_minimum_size = Vector2(0, 52 if v.get_child_count() > 6 else 66)
	b.add_theme_font_size_override("font_size", 30 if loud else 26)
	if loud: b.add_theme_color_override("font_color", Color("f0c060"))
	b.flat = true; b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if not loud: b.add_theme_color_override("font_color", Color("cfc4a8"))
	b.add_theme_color_override("font_hover_color", Color("ffffff"))
	b.pressed.connect(cb); v.add_child(b)

## He looks about the room, and at you, and back; now and then something more.
func _process(delta: float) -> void:
	_t += delta; _next -= delta
	if _next <= 0.0:
		_next = randf_range(2.5, 5.5)
		match randi() % 6:
			0: socko.look = "kurt"; socko.emotion = "happy"; socko.gesture("tilt")
			1: socko.look = "away"; socko.emotion = "neutral"
			2: socko.look = "kurt"; socko.emotion = "curious"
			3: socko.look = "kurt"; socko.emotion = "uncanny"
			4: socko.look = "away"; socko.emotion = "curious"; socko.gesture("nod")
			5:
				for i in 3:
					Sfx.play("knock", -16.0, randf_range(0.95, 1.05)); await get_tree().create_timer(0.32).timeout
				socko.look = "away"; socko.emotion = "nervous"; socko.gesture("recoil")
