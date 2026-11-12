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
		var mi := Build.box(w, Vector3(-0.8 + i * 0.3, 1.3 + (i % 2) * 0.2, -1.13), Vector3(0.21, 0.29, 0.004), Tex.mat("paper_boxes", 3.0), false)
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
	var v := VBoxContainer.new()
	v.anchor_left = 0.58; v.anchor_right = 0.95; v.anchor_top = 0.2; v.anchor_bottom = 0.9
	v.add_theme_constant_override("separation", 14)
	layer.add_child(v)
	var t := Label.new(); t.text = "PUT A SOCK\nIN IT"
	t.add_theme_font_size_override("font_size", 64); t.add_theme_color_override("font_color", Color("e2d6b8"))
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9)); t.add_theme_constant_override("shadow_offset_y", 4)
	v.add_child(t)
	var sub := Label.new(); sub.text = "Kerzhansk, 1996"
	sub.add_theme_font_size_override("font_size", 20); sub.add_theme_color_override("font_color", Color("8f8470"))
	v.add_child(sub)
	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 40); v.add_child(gap)
	if Game.has_save(): _btn(v, "Continue", func(): _go(Game.continue_game))
	_btn(v, "New game", func(): _go(func(): Game.reset_save(); Game.new_game()))
	_btn(v, "Quit", func(): get_tree().quit())

func _go(f: Callable) -> void:
	Sfx.stop_loops()
	f.call()

func _btn(v: VBoxContainer, t: String, cb: Callable) -> void:
	var b := Button.new(); b.text = t; b.custom_minimum_size = Vector2(0, 66)
	b.add_theme_font_size_override("font_size", 26)
	b.flat = true; b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_color_override("font_color", Color("cfc4a8")); b.add_theme_color_override("font_hover_color", Color("ffffff"))
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
