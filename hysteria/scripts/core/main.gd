extends Node
## Entry point. The world renders into a low-resolution SubViewport (a third of the window) with
## nearest-neighbour upscaling and a 15-bit dithered palette: the PS1 presentation.
## Command line (after `--`): `shots=<dir>` renders a fixed set of views to PNGs and quits.

const SHRINK := 3

var world: Node3D
var player: CharacterBody3D
var container: SubViewportContainer
var viewport: SubViewport
var dread: Dread
var marta: Marta
var encounter: MartaEncounter
var socko: Socko
var socko_intro: SockoIntro
var socko_hud: SockoHud
var pause_menu: PauseMenu
var socko_tutorial: SockoTutorial

func _ready() -> void:
	container = SubViewportContainer.new()
	container.stretch = true
	container.stretch_shrink = SHRINK
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new(); mat.shader = preload("res://shaders/ps1_screen.gdshader")
	container.material = mat
	add_child(container)
	get_window().size_changed.connect(_rescale); _rescale.call_deferred()
	viewport = SubViewport.new()
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.physics_object_picking = false
	container.add_child(viewport)

	world = preload("res://scripts/world/flat47.gd").new()
	world.name = "Flat47"
	viewport.add_child(world)
	player = preload("res://scenes/player.tscn").instantiate()
	viewport.add_child(player)
	player.place(world.spawn)

	add_child(preload("res://scripts/ui/hud.gd").new())
	var touch: CanvasLayer = preload("res://scripts/ui/touch.gd").new()
	touch.player = player
	add_child(touch)

	# Marta, at her place at the dinner table: stay in her room and the colour goes
	marta = Marta.new(); marta.name = "Marta"
	world.add_child(marta)
	marta.position = Vector3(3.0, 0, 1.42); marta.rotation.y = PI / 2
	world.hide_near(Vector3(3.02, 0.45, 1.45), 0.34, 1.0)      # the chair she replaces
	var presence := Presence.new(); marta.add_child(presence); presence.position = Vector3(0, 1.2, -0.1)
	dread = Dread.new(); dread.name = "Dread"
	add_child(dread)
	dread.setup(player, world.level.rooms, container.material)
	encounter = MartaEncounter.new(); encounter.name = "MartaEncounter"
	add_child(encounter)
	encounter.setup(marta, player, presence, dread)
	# Socko: on his left hand, from the moment he comes to (story bible beats 9-10), not before
	socko = Socko.new(); socko.name = "Socko"
	socko.setup(player.cam, player)
	viewport.add_child(socko)
	socko_intro = SockoIntro.new(); socko_intro.name = "SockoIntro"
	add_child(socko_intro)
	socko_intro.setup(socko, player, encounter)
	pause_menu = PauseMenu.new(); pause_menu.name = "PauseMenu"; pause_menu.setup(player); add_child(pause_menu)
	socko_hud = SockoHud.new(); socko_hud.name = "SockoHud"; add_child(socko_hud)
	socko_tutorial = SockoTutorial.new(); socko_tutorial.name = "SockoTutorial"; add_child(socko_tutorial)
	socko_tutorial.setup(socko, player, socko_hud)

	var args := _args()
	if args.has("torch_exp"):
		player.torch.spot_angle_attenuation = float(args.torch_exp)
	if args.has("torch_k"):
		player.torch.light_energy = float(args.torch_k)
	if args.has("torch_shadow"):
		player.torch.shadow_enabled = args.torch_shadow == "1"
	if args.has("dread"):
		dread.level = float(args.dread)
	if args.has("touch"):
		touch.visible = true; player.touch_ui = true; pause_menu.pause_btn.visible = true
	if args.has("shots"):
		_shots(args.shots)
	else:
		if DisplayServer.is_touchscreen_available():
			Game.say("Left thumb: walk (push to the rim to run). Right thumb: look.", 6.0)
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			Game.say("Flat 47. [WASD] move  [Shift] run  [C] crouch  [E] use  [F] torch", 6.0)

## The screen pass works in physical pixels; the low-res grid is SHRINK canvas pixels, which the
## stretch mode scales up on high-density screens.
func _rescale() -> void:
	var k := float(get_window().size.y) / float(get_viewport().get_visible_rect().size.y)
	(container.material as ShaderMaterial).set_shader_parameter("shrink", SHRINK * k)

func _args() -> Dictionary:
	var d := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		d[kv[0]] = kv[1] if kv.size() > 1 else ""
	return d

func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.look(e.relative)
	elif e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ---------------------------------------------------------------- screenshot tour
const VIEWS := [   # the JS build's tools/smoke.mjs views: name, x, z, yaw, pitch, torch
	["bath", 9.1, 5.6, PI * 0.75, -0.2, true],
	["bedroom", 7.0, 3.3, PI * 0.25, -0.1, false],
	["child", 5.6, 5.6, PI - 0.3, -0.1, false],
	["kitchen", 8.5, 3.5, -0.5, -0.1, false],
	["living_from_door", 4.15, 4.7, PI / 2 - 0.35, -0.08, false],
	["spawn", 9.35, 4.55, PI / 2 + 0.25, -0.05, false],
	["storage", 1.8, 5.6, PI, -0.2, true],
]

const MARTA_VIEWS := [   # free camera: name, eye, looking at, torch (her head is at about (2.91, 1.28, 1.42), facing -X)
	["m1_doorway", Vector3(4.3, 1.62, 4.4), Vector3(2.9, 1.0, 1.4), false],
	["m2_behind", Vector3(3.85, 1.55, 2.25), Vector3(2.95, 1.0, 1.42), false],
	["m3_side", Vector3(3.0, 1.45, 0.4), Vector3(2.9, 1.0, 1.42), false],
	["m4_across", Vector3(1.75, 1.5, 1.5), Vector3(2.9, 1.1, 1.42), false],
	["m5_face", Vector3(2.4, 1.3, 1.15), Vector3(2.92, 1.18, 1.42), true],
	["m6_close", Vector3(2.55, 1.08, 1.42), Vector3(2.92, 1.2, 1.42), true],
	["m7_standing", Vector3(2.75, 1.62, 1.95), Vector3(2.9, 1.15, 1.42), false],
	["m8_awake", Vector3(2.62, 1.6, 1.85), Vector3(2.9, 1.28, 1.42), true],
	["m9_awake_front", Vector3(2.4, 1.4, 1.3), Vector3(2.9, 1.27, 1.42), true],
	["m11_awake_reach", Vector3(2.62, 1.36, 1.38), Vector3(2.9, 1.28, 1.42), true],
	["m10_awake_dark", Vector3(2.4, 1.4, 1.3), Vector3(2.9, 1.27, 1.42), false],
]

func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var views: Array = MARTA_VIEWS if _args().get("views", "") == "marta" else VIEWS
	var free := views == MARTA_VIEWS
	if free:
		player.set_physics_process(false)
		encounter.process_mode = Node.PROCESS_MODE_DISABLED     # a camera tour mustn't wake her
	for v in views:
		if free:
			var eye: Vector3 = v[1]; var d: Vector3 = v[2] - eye
			player.global_position = eye - Vector3(0, 1.62, 0)
			player.rotation.y = atan2(-d.x, -d.z); player.head.position.y = 1.62
			player.head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
			player.torch.visible = v[3]
			if String(v[0]).contains("awake"):
				marta.face(eye)
		else:
			player.global_position = Vector3(v[1], 0, v[2]); player.velocity = Vector3.ZERO
			player.yaw = v[3]; player.pitch = v[4]
			player.torch.visible = v[5]
		for i in 20:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(dir.path_join(v[0] + ".png"))
		print("shot ", v[0], " ", player.global_position)
	get_tree().quit()
