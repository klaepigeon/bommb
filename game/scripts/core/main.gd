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
	if Log.previous != "" and not args.has("autotest") and not args.has("views") and not args.has("gallery"):
		await _crash_report()
	if bool(Settings.get_v("safe_mode")): Log.mark("safe mode")
	_display()
	Log.mark("display ok")
	level = Level.new(); level.name = "Level"
	view.add_child(level)
	level.build()
	Log.mark("level built")
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
	Log.mark("story ready")
	_first_frames()
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

## Breadcrumbs for the first frames drawn (a crash in the GPU driver shows up as the last one).
func _first_frames() -> void:
	for i in [1, 2, 10, 60]:
		while Engine.get_process_frames() < i: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		Log.mark("frame %d drawn" % i)

## The game didn't end cleanly last time: say so before anything 3D is built, show the trail, and
## offer safe mode (no voices, low picture, no particles). The report can be copied to send.
func _crash_report() -> void:
	var layer := CanvasLayer.new(); layer.layer = 100; add_child(layer)
	var bg := ColorRect.new(); bg.color = Color(0.04, 0.04, 0.05); bg.set_anchors_preset(Control.PRESET_FULL_RECT); layer.add_child(bg)
	var m := MarginContainer.new(); m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + side, 48)
	layer.add_child(m)
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 14); m.add_child(vb)
	var title := Label.new(); title.text = "The game stopped last time without closing."; title.add_theme_font_size_override("font_size", 34); vb.add_child(title)
	var info := Label.new(); info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; info.add_theme_font_size_override("font_size", 20)
	info.text = "Copy the report and send it, so it can be fixed. Safe mode turns off voices, particles and dust, and lowers the picture."
	vb.add_child(info)
	var report := "HYSTERIA crash report\n" + Log.previous_full()
	var box := TextEdit.new(); box.text = report; box.editable = false; box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_font_size_override("font_size", 16); vb.add_child(box)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 16); vb.add_child(row)
	var done := [false]
	var mk := func(t: String, f: Callable):
		var b := Button.new(); b.text = t; b.custom_minimum_size = Vector2(260, 84); b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(f); row.add_child(b)
	mk.call("Copy report", func(): DisplayServer.clipboard_set(report); info.text = "Copied. Paste it into a message.")
	mk.call("Safe mode", func():
		Settings.set_v("safe_mode", true); Settings.set_v("voices", false); Settings.set_v("quality", "low"); done[0] = true)
	mk.call("Play normally", func(): Settings.set_v("safe_mode", false); done[0] = true)
	while not done[0]: await get_tree().process_frame
	Log.mark("report closed, safe_mode=%s" % str(Settings.get_v("safe_mode")))
	layer.queue_free()

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
