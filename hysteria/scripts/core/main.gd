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

	# the body at the dinner table (a marker until she's ported): stay in her room and the colour goes
	var body := Presence.new(); body.name = "TheBody"
	world.add_child(body); body.position = Vector3(2.4, 0.9, 1.9)
	dread = Dread.new(); dread.name = "Dread"
	add_child(dread)
	dread.setup(player, world.level.rooms, container.material)

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
		touch.visible = true; player.touch_ui = true
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
	elif e.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
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

func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for v in VIEWS:
		player.global_position = Vector3(v[1], 0, v[2]); player.velocity = Vector3.ZERO
		player.yaw = v[3]; player.pitch = v[4]
		player.torch.visible = v[5]
		for i in 20:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(dir.path_join(v[0] + ".png"))
		print("shot ", v[0], " ", player.global_position)
	get_tree().quit()
