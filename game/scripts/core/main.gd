extends Node
## Boot: a low-resolution 3D view (PS1 look, and cheap on phones) scaled up with nearest
## filtering, the HUD over it at full resolution, then Scene A.
##   -- --start=wake|door     jump to a beat     -- --autotest     play through and check
##   -- --shots=<dir>         save screenshots at each beat (needs a real display)

var view: SubViewport
var world: Node3D
var flat: Flat47
var marta: Marta
var player: Player
var hud: Hud
var scene: SceneA
var town: Town
var chapter: TownChapter
var weapon: Weapon
var env: Environment
var room_tone: AudioStreamPlayer3D
var args := {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	get_tree().set_auto_accept_quit(true)
	_build()

func _build() -> void:
	var container := SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.stretch_shrink = 2
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	view = SubViewport.new()
	view.audio_listener_enable_3d = true
	view.msaa_3d = Viewport.MSAA_DISABLED
	view.positional_shadow_atlas_size = 0
	container.add_child(view)
	world = Node3D.new(); world.name = "World"
	view.add_child(world)
	Sfx.world = world
	var world_env := WorldEnvironment.new()
	var e := Environment.new()
	env = e
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("050505")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("39404a")
	e.ambient_light_energy = 0.55
	e.fog_enabled = true
	e.fog_light_color = Color("0b0c0e")
	e.fog_density = 0.07
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.environment = e
	world.add_child(world_env)
	flat = Flat47.new(); flat.name = "Flat47"; world.add_child(flat); flat.build()
	marta = Marta.new(); marta.name = "Marta"; world.add_child(marta)
	marta.position = flat.marta_seat
	marta.rotation.y = deg_to_rad(90)
	marta.build()
	player = Player.new(); player.name = "Kurt"; world.add_child(player); player.build()
	hud = Hud.new(); add_child(hud); hud.build()
	player.controls = hud.controls
	weapon = Weapon.new(); weapon.name = "Weapon"; add_child(weapon); weapon.setup(player)
	player.focus_changed.connect(hud.set_prompt)
	hud.controls.interact_pressed.connect(player.try_interact)
	hud.controls.pause_pressed.connect(hud.toggle_pause)
	hud.restart_requested.connect(func(): get_tree().reload_current_scene())
	room_tone = Sfx.loop_at("room", Vector3(0, 1.5, -2.0), -14.0)
	scene = SceneA.new(); scene.name = "SceneA"
	scene.flat = flat; scene.marta = marta; scene.player = player; scene.hud = hud
	add_child(scene)
	scene.into_town.connect(go_to_town)
	if args.has("autotest") or args.has("shots"):
		var ap: Node = load("res://scripts/story/autopilot.gd").new()
		ap.main = self
		add_child(ap)
	Game.reset()
	if args.get("start", "") == "town":
		player.socko.visible = true
		player.socko.set_pose("low", 0.0)
		scene.stage = "town"
		go_to_town()
		return
	scene.start(args.get("start", ""))

## Through the hole: build the town (behind black), hide the flat, and hand over to the chapter.
func go_to_town() -> void:
	hud.fade.color.a = 1.0
	await get_tree().process_frame
	var t := Time.get_ticks_msec()
	town = Town.new(); town.name = "Town"
	world.add_child(town)
	town.position = Vector3(300, 0, 0)
	town.build()
	print("[town] built in %d ms" % (Time.get_ticks_msec() - t))
	flat.visible = false
	marta.visible = false
	flat.process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(room_tone):
		room_tone.queue_free()
	Sfx.loop_at("wind", town.to_global(Vector3(26, 6, 0)), -12.0)
	env.background_color = Color("101828")
	env.ambient_light_color = Color("5a6a8c")
	env.ambient_light_energy = 0.95
	env.fog_light_color = Color("26324a")
	env.fog_density = 0.04
	chapter = TownChapter.new(); chapter.name = "TownChapter"
	chapter.main = self; chapter.town = town; chapter.player = player; chapter.hud = hud; chapter.weapon = weapon
	add_child(chapter)
	chapter.setup()
	chapter.finished.connect(_the_end)
	chapter.arrive()

func _the_end(route: String) -> void:
	hud.end_card(route)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if hud and not hud.is_paused() and not args.has("autotest") and not args.has("shots"):
				hud.toggle_pause()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if hud:
				hud.toggle_pause()
