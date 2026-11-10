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
var flat48: Flat48
var chapter48: Flat48Chapter
var place := "flat47"           ## where Kurt is: flat47 (and its landing), town, flat48
var wind: AudioStreamPlayer3D
var weapon: Weapon
var env: Environment
var room_tone: AudioStreamPlayer3D
var args := {}
var _screen: ShaderMaterial
var _grain_t := 0.0
const SHRINK := 2

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	get_tree().set_auto_accept_quit(true)
	_build()

func _build() -> void:
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.stretch_shrink = SHRINK
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen = ShaderMaterial.new()
	_screen.shader = load("res://shaders/ps1_screen.gdshader")
	container.material = _screen
	add_child(container)
	get_window().size_changed.connect(_fit_screen)
	_fit_screen()
	view = SubViewport.new()
	view.audio_listener_enable_3d = true
	view.msaa_3d = Viewport.MSAA_DISABLED
	view.positional_shadow_atlas_size = 1024       # one shadow light at a time (the stairwell's bulb)
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
	flat.apply_environment(e)
	marta = Marta.new(); marta.name = "Marta"; world.add_child(marta)
	marta.position = flat.marta_seat
	marta.rotation.y = flat.marta_yaw
	marta.build()
	flat.hide_near(Vector3(3.02, 0.45, 1.45), 0.34, 1.0)      # the chair she's grown into replaces the flat's
	player = Player.new(); player.name = "Kurt"; world.add_child(player); player.build()
	hud = Hud.new(); add_child(hud); hud.build()
	player.controls = hud.controls
	weapon = Weapon.new(); weapon.name = "Weapon"; add_child(weapon); weapon.setup(player)
	player.focus_changed.connect(hud.set_prompt)
	hud.controls.interact_pressed.connect(player.try_interact)
	hud.controls.pause_pressed.connect(hud.toggle_pause)
	hud.controls.action.connect(_on_action)
	flat.door48_spot.used.connect(go_to_flat48)
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
	var start: String = args.get("start", "")
	if start in ["town", "landing", "flat48"]:
		player.socko.visible = true
		player.socko.set_pose("low", 0.0)
		scene.stage = start
		marta.vanish()
		match start:
			"town": go_to_town()
			"landing": to_landing()
			"flat48": go_to_flat48()
		return
	scene.start(args.get("start", ""))

## Through the hole: build the town (behind black), hide the flat, and hand over to the chapter.
func go_to_town() -> void:
	hud.fade.color.a = 1.0
	await get_tree().process_frame
	var t := Time.get_ticks_msec()
	town = Town.new(); town.name = "Town"
	town.position = Vector3(300, 0, 0)
	world.add_child(town)        # it builds itself
	print("[town] built in %d ms" % (Time.get_ticks_msec() - t))
	flat.visible = false
	marta.visible = false
	flat.process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(room_tone):
		room_tone.queue_free()
	wind = Sfx.loop_at("wind", town.to_global(Vector3(30, 6, 20)), -12.0)
	place = "town"
	var te: Environment = town.env
	for prop in ["background_color", "background_energy_multiplier", "ambient_light_color", "ambient_light_energy", "fog_light_color", "fog_density", "tonemap_mode", "tonemap_exposure"]:
		env.set(prop, te.get(prop))
	chapter = TownChapter.new(); chapter.name = "TownChapter"
	chapter.main = self; chapter.town = town; chapter.player = player; chapter.hud = hud; chapter.weapon = weapon
	add_child(chapter)
	chapter.setup()
	chapter.finished.connect(_the_end)
	chapter.arrive()

## Out of the town's gate, into white, and he's on the landing outside 47. The door he went in by
## is shut. Across the landing, 48's peephole lights, and its door comes off the latch.
func _the_end(_route: String) -> void:
	to_landing()

func to_landing() -> void:
	if town:
		town.visible = false
		town.process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(wind):
		wind.queue_free()
	if flat48:
		flat48.visible = false
		flat48.process_mode = Node.PROCESS_MODE_DISABLED
		chapter48.active = false
	flat.visible = true
	flat.process_mode = Node.PROCESS_MODE_INHERIT
	flat.apply_environment(env)
	flat.front_door.set_angle(0.0)
	flat.front_door.locked = true
	flat.front_door.set_usable(true)
	if not is_instance_valid(room_tone):
		room_tone = Sfx.loop_at("room", Vector3(11.5, 1.5, 5.5), -14.0)
	place = "flat47"
	scene.stage = "landing"
	var from_48 := flat48 != null
	player.global_position = Vector3(12.9, 0, 4.56) if from_48 else Vector3(11.2, 0, 6.0)
	player.face(Vector3(10.4, 1.4, 4.56) if from_48 else Vector3(14.0, 1.45, 4.56))
	player.head.position.y = Player.EYE
	hud.fade_to(0.0, 0.8)
	await hud.white_to(0.0, 2.5 if not from_48 else 0.6).finished
	player.can_move = true
	player.can_look = true
	hud.set_crosshair(true)
	if not from_48:
		flat.open_door48()
	_super_rounds(from_48)

## The Super walks the building from the moment Kurt is out on the landing. (Tests of other
## things run without him: --super puts him in.)
func _super_rounds(from_48: bool) -> void:
	if args.has("autotest") and not args.has("super"):
		return
	var b := flat.building
	if b.the_super == null:
		Game.set_flag("goal_sonya")
		hud.caption("Find Sonya.", 5.0)       # what the game is about, from here
		b.spawn_super(player).caught.connect(_super_caught)
	elif from_48 and absf(b.the_super.global_position.y - player.global_position.y) < Building.STOREY * 1.5:
		b.the_super.send_away(4)       # coming out of 48, he isn't standing at the door

## He has hold of Kurt. Black; then Kurt on his own landing, later, and the Super gone off again.
func _super_caught(_m: Monster) -> void:
	var sup := flat.building.the_super
	player.can_move = false
	player.can_look = false
	hud.set_crosshair(false)
	player.look_toward(sup.head.global_position, 0.35)
	player.shake(0.05, 0.9)
	Sfx.play("gasp", -2.0)
	await get_tree().create_timer(0.9, false).timeout
	Sfx.play("thud", 2.0, 0.6)
	hud.fade.color.a = 1.0
	Sfx.play("tinnitus", -10.0)
	await get_tree().create_timer(3.2, false).timeout
	sup.send_away(Building.floor_of(player.global_position.y))
	player.global_position = Vector3(11.2, 0, 6.6)
	player.face(Vector3(14.0, 1.2, 4.56))
	await hud.fade_to(0.0, 2.5).finished
	player.can_move = true
	player.can_look = true
	hud.set_crosshair(true)

## Through 48's door: the same flat, drawn from memory.
func go_to_flat48() -> void:
	player.can_move = false
	await hud.white_to(1.0, 0.5).finished
	if flat48 == null:
		var t := Time.get_ticks_msec()
		flat48 = Flat48.new()
		world.add_child(flat48)
		flat48.build(flat, weapon, hud)
		print("[flat48] built in %d ms" % (Time.get_ticks_msec() - t))
		chapter48 = Flat48Chapter.new(); chapter48.name = "Flat48Chapter"
		chapter48.flat = flat48; chapter48.player = player; chapter48.weapon = weapon; chapter48.hud = hud
		add_child(chapter48)
		chapter48.setup()
		chapter48.left.connect(func():
			player.can_move = false
			await hud.white_to(1.0, 0.4).finished
			to_landing())
	flat48.visible = true
	flat48.process_mode = Node.PROCESS_MODE_INHERIT
	flat.visible = false
	flat.process_mode = Node.PROCESS_MODE_DISABLED
	if town:
		town.visible = false
		town.process_mode = Node.PROCESS_MODE_DISABLED
	flat48.apply_environment(env)
	place = "flat48"
	scene.stage = "flat48"
	var sp := flat48.global_transform * flat48.spawn
	player.global_position = sp.origin
	player.face(sp.origin - sp.basis.z * 3.0 + Vector3(0, 1.5, 0))
	hud.fade.color.a = 0.0
	await hud.white_to(0.0, 1.2).finished
	chapter48.active = true
	player.can_move = true
	player.can_look = true
	hud.set_crosshair(true)

## What's in his hands, on the screen: nuggets, rounds; the buttons that go with what he's holding.
func _update_hud() -> void:
	var t := ""
	if Game.nuggets > 0 or Game.skills.size() > 0:
		t += "Nuggets  %d" % Game.nuggets
	if Game.has_gun and weapon.held != "shotgun":
		t += ("\n" if t != "" else "") + "Nagant  %d / %d" % [Game.ammo_loaded, Game.ammo_spare]
	if Game.has_shotgun and (weapon.held == "shotgun" or not Game.has_gun):
		t += ("\n" if t != "" else "") + "IZh-43  %d / %d" % [Game.shells_loaded, Game.shells_spare]
	hud.set_status(t)
	var gun := weapon.held in ["gun", "shotgun"]
	hud.controls.show_buttons({"fire": gun or weapon.held == "rock", "aim": gun, "reload": gun,
		"skills": Game.nuggets > 0 or Game.skills.size() > 0,
		"swap": gun and Game.has_gun and Game.has_shotgun})
	hud.controls.labels["fire"] = "THROW" if weapon.held == "rock" else "FIRE"

func _on_action(name: String) -> void:
	if not player.can_move:
		return
	match name:
		"fire": weapon.fire()
		"reload": weapon.reload()
		"skills": hud.skills.open()
		"swap": weapon.swap()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:        # really in the background (not a moment of lost focus)
			if hud and not hud.is_paused() and not args.has("autotest") and not args.has("shots"):
				hud.toggle_pause()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if hud:
				hud.toggle_pause()

## The screen pass (dither, grain, vignette) works in physical pixels: tell it how big a
## low-resolution pixel is on this screen.
func _fit_screen() -> void:
	var win := Vector2(get_window().size)
	var scale := minf(win.x / 1280.0, win.y / 720.0)
	_screen.set_shader_parameter("shrink", SHRINK * maxf(scale, 0.5))

func _process(delta: float) -> void:
	if weapon and hud:
		weapon.set_aim(hud.controls.aiming and weapon.held in ["gun", "shotgun"])
		_update_hud()
	_grain_t += delta
	if _grain_t > 1.0 / 12.0:
		_grain_t = 0.0
		_screen.set_shader_parameter("grain_seed", randf())
