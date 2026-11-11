extends Node
## Boot. The 3D world renders into a small viewport (about 270 lines tall, the PS1's kind of
## resolution, and cheap on a phone) which is scaled up unfiltered, with the finishing pass
## (screen.gdshader). The interface draws over it at the screen's own resolution.
##
## Command line (after --): --start=knock|wake|door|wardrobe|maze|gun  --autotest --route=NAME
##   --shots=DIR  --phone (behave as a phone: touch, its resolution)  --fresh (ignore the save)

var view: SubViewport
var container: SubViewportContainer
var screen_mat: ShaderMaterial
var level: Level
var kurt: Kurt
var hud: Hud
var story: Story
var args := {}
var env: Environment

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else true
	Log.mark("boot " + str(args))
	_display()
	level = Level.new(); level.name = "Level"
	view.add_child(level)
	level.build()
	kurt = Kurt.new(); kurt.name = "Kurt"
	view.add_child(kurt)
	kurt.build()
	kurt.level = level
	hud = Hud.new(); hud.name = "Hud"
	add_child(hud)
	hud.setup(self)
	story = Story.new(); story.name = "Story"
	add_child(story)
	story.setup(self)
	var save := {} if args.has("fresh") or args.has("autotest") or args.has("start") else World.read_save()
	if not save.is_empty():
		hud.offer_continue(func(): World.restore(save); story.resume(), func(): World.wipe(); story.begin(String(args.get("start", "knock"))))
	else:
		story.begin(String(args.get("start", "knock")))
	if args.has("autotest") or args.has("views") or args.has("gallery"):
		var t: Node = load("res://tools/%s.gd" % ("shot" if args.has("views") or args.has("gallery") else "autotest")).new()
		t.name = "Autotest"
		add_child(t)
		t.run(self)

func _display() -> void:
	container = SubViewportContainer.new(); container.name = "Screen"
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(container)
	view = SubViewport.new(); view.name = "World"
	view.msaa_3d = Viewport.MSAA_DISABLED
	view.positional_shadow_atlas_size = 0
	view.audio_listener_enable_3d = true
	view.handle_input_locally = false
	container.add_child(view)
	screen_mat = ShaderMaterial.new(); screen_mat.shader = load("res://shaders/screen.gdshader")
	container.material = screen_mat
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.93, 0.94, 0.95) if not args.has("bg") else Color(1, 0, 1)      # there's no outside: only white
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new(); we.environment = env
	view.add_child(we)
	get_viewport().size_changed.connect(_resize)
	_resize()
	Settings.changed.connect(_resize)

## About 270 lines high whatever the screen: 1080p phones render at a quarter, 720p at a third.
func _resize() -> void:
	var h := get_viewport().get_visible_rect().size.y
	var q := String(Settings.get_v("quality"))
	var lines := 270.0 if q != "high" else 400.0
	if q == "low": lines = 220.0
	container.stretch_shrink = maxi(1, int(round(h / lines)))
	var px := Vector2(get_viewport().get_visible_rect().size) / float(container.stretch_shrink)
	RenderingServer.global_shader_parameter_set("snap_res", px * 0.75)
	screen_mat.set_shader_parameter("gamma", float(Settings.get_v("brightness")))

func _process(_delta: float) -> void:
	screen_mat.set_shader_parameter("time_s", Time.get_ticks_msec() / 1000.0)
	if kurt:
		screen_mat.set_shader_parameter("hurt", clampf((70.0 - kurt.hp) / 70.0, 0.0, 1.0))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if World.flag("socko_on") and not args.has("autotest"):
			World.save_game()
