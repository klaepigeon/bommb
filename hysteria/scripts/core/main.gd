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
var labyrinth: Labyrinth
var in_labyrinth := false
var wardrobe: WardrobeGap
var hunter: MartaHunter
var skill_menu: SkillMenu
var socko_lab: SockoLabyrinth
var escape: FlatEscape
var save_game: SaveGame
var memory: MemoryEffects
var flat48: Flat48
var socko_48: SockoFlat48
var in_flat48 := false
var armory: Armory
var gun_feel: GunFeel
var speech: Speech
var crash: CrashReport
## gutterspace nuggets: where they hang (the flat, then the labyrinth in its own space)
const NUGGETS_FLAT := [Vector3(3.4, 1.1, 4.2), Vector3(1.2, 0.9, 1.0), Vector3(8.2, 1.3, 2.6), Vector3(9.3, 0.8, 6.9),
	Vector3(6.1, 1.0, 0.7), Vector3(5.2, 1.2, 6.6), Vector3(1.6, 1.4, 6.8), Vector3(7.6, 1.5, 4.6)]
const NUGGETS_LAB := [Vector3(26.0, 1.3, 7.0), Vector3(26.0, 1.0, 13.5), Vector3(14.0, 1.2, 17.2), Vector3(35.0, 1.6, 22.8),
	Vector3(46.5, 1.1, 22.6), Vector3(9.0, 1.0, 20.0), Vector3(42.0, 1.2, 27.0), Vector3(42.0, 1.4, 30.5),
	Vector3(34.0, 1.0, 46.5), Vector3(50.5, 2.2, 33.5), Vector3(37.0, 3.1, 44.0), Vector3(42.0, 1.1, 50.5),
	Vector3(31.0, 1.2, 57.5), Vector3(52.0, 1.0, 63.5), Vector3(42.0, 1.6, 65.0), Vector3(22.0, 1.0, 62.0),
	Vector3(15.5, 0.9, 61.0), Vector3(16.0, 1.1, 27.0), Vector3(20.8, 1.5, 29.0), Vector3(54.0, 1.1, 40.6),
	Vector3(57.8, 1.2, 35.4), Vector3(8.5, 0.9, 63.6), Vector3(10.8, 1.0, 59.9), Vector3(28.0, 1.2, 21.0)]
const LAB_AT := Vector3(400, 0, 0)      # far from the flat; each is hidden while you're in the other
var socko_tutorial: SockoTutorial

func _ready() -> void:
	add_to_group("main")
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
	labyrinth = Labyrinth.new(); labyrinth.name = "Labyrinth"; labyrinth.position = LAB_AT
	viewport.add_child(labyrinth); labyrinth.visible = false; labyrinth.process_mode = Node.PROCESS_MODE_DISABLED
	wardrobe = WardrobeGap.new(); wardrobe.name = "WardrobeGap"; add_child(wardrobe)
	wardrobe.setup(world, player, self)
	# the way back, at the lane's dead end
	var back := StaticBody3D.new(); back.name = "GapBack"; back.set_script(load("res://scripts/world/gap_way.gd"))
	back.set("gap", wardrobe); back.set("inward", false)
	var bcs := CollisionShape3D.new(); var bbox := BoxShape3D.new(); bbox.size = Vector3(1.0, 1.6, 0.2); bcs.shape = bbox; back.add_child(bcs)
	labyrinth.add_child(back); back.position = labyrinth.hole_at + Vector3(0, 0, 0.2)
	hunter = MartaHunter.new(); hunter.name = "MartaHunter"; hunter.setup(labyrinth, player); labyrinth.add_child(hunter)
	for p in NUGGETS_FLAT:
		var n := Nugget.new(); n.position = p; n.name = "NuggetF%d" % NUGGETS_FLAT.find(p); world.add_child(n)        # placed before it's added: it keeps its place
	for p in NUGGETS_LAB:
		var n := Nugget.new(); n.position = p; n.name = "NuggetL%d" % NUGGETS_LAB.find(p); labyrinth.add_child(n)
	var whud := WeaponHud.new(); whud.name = "WeaponHud"; whud.setup(player); add_child(whud)
	pause_menu = PauseMenu.new(); pause_menu.name = "PauseMenu"; pause_menu.setup(player); add_child(pause_menu)
	crash = CrashReport.new(); crash.name = "CrashReport"; add_child(crash)
	speech = Speech.new(); speech.name = "Speech"; add_child(speech); speech.setup(self)
	socko_hud = SockoHud.new(); socko_hud.name = "SockoHud"; add_child(socko_hud)
	socko_tutorial = SockoTutorial.new(); socko_tutorial.name = "SockoTutorial"; add_child(socko_tutorial)
	socko_tutorial.setup(socko, player, socko_hud)
	skill_menu = SkillMenu.new(); skill_menu.name = "SkillMenu"; skill_menu.setup(player, socko); add_child(skill_menu)
	pause_menu.skill_menu = skill_menu
	socko_lab = SockoLabyrinth.new(); socko_lab.name = "SockoLabyrinth"; add_child(socko_lab)
	socko_lab.setup(socko, player, self, socko_hud, hunter, skill_menu)
	_flat_detail()
	escape = FlatEscape.new(); escape.name = "FlatEscape"; add_child(escape)
	escape.setup(world, player, self)
	memory = MemoryEffects.new(); memory.name = "MemoryEffects"; add_child(memory); memory.setup(self)
	armory = Armory.new(); armory.name = "Armory"; add_child(armory); armory.setup(player)
	gun_feel = GunFeel.new(); gun_feel.name = "GunFeel"; add_child(gun_feel); gun_feel.setup(self)
	flat48 = Flat48.new(); add_child(flat48); flat48.build(self)
	socko_48 = SockoFlat48.new(); socko_48.name = "SockoFlat48"; add_child(socko_48); socko_48.setup(self)
	save_game = SaveGame.new(); save_game.name = "SaveGame"; save_game.setup(self); add_child(save_game)
	pause_menu.save_game = save_game

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
	if args.has("fresh"):
		SaveGame.wipe()          # developer reset
	if args.has("lab"):
		enter_labyrinth()
	if args.has("f48"):
		Game.flags["socko_intro_done"] = true
		encounter.skip(); socko_intro.skip()
		enter_flat48()
	if not args.has("shots") and not args.has("lab") and not args.has("f48"):
		_continue.call_deferred()
	if args.has("shots"):
		_shots(args.shots)
	else:
		if Game.has_touch():
			Game.say("Left thumb: walk (push to the rim to run). Right thumb: look.", 6.0)
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			Game.say("Flat 47. [WASD] move  [Shift] run  [C] crouch  [E] use  [F] torch", 6.0)

## Skirting, coving and ceiling roses in Flat 47 (FlatDetail finds the walls with rays, so it
## waits a physics frame for the walls to be in the physics world)
func _flat_detail() -> void:
	await get_tree().physics_frame
	var lv: Dictionary = world.get("level")
	var n := FlatDetail.build(world, lv.get("rooms", {}), lv.get("lights", []))
	print("flat detail: %d runs" % n)

## Launching the game continues the saved one (only as the real main scene: not under the tests,
## which make their own).
func _continue() -> void:
	if get_tree().current_scene != self or not SaveGame.exists(): return
	var card: CanvasLayer = load("res://scripts/ui/title_card.gd").new()
	card.chosen.connect(func(cont: bool):
		if cont: save_game.load_game()
		else: SaveGame.wipe())
	add_child(card)

## Through the gap behind the wardrobe and back. Only one of the two places exists at a time.
func enter_labyrinth() -> void:
	in_labyrinth = true
	if crash: crash.note("into the town")
	labyrinth.visible = true; labyrinth.process_mode = Node.PROCESS_MODE_INHERIT
	world.get_node("Apartment").visible = false
	(world.get_node("Environment") as WorldEnvironment).environment = labyrinth.env
	player.global_transform = labyrinth.global_transform * labyrinth.arrive
	player.yaw = player.global_transform.basis.get_euler().y; player.pitch = 0.0
	player.velocity = Vector3.ZERO

## Across the landing into Flat 48 (47 and the town hidden; one place at a time).
func enter_flat48() -> void:
	if in_labyrinth: leave_labyrinth(Transform3D.IDENTITY)
	in_flat48 = true
	if crash: crash.note("into flat 48")
	flat48.visible = true; flat48.process_mode = Node.PROCESS_MODE_INHERIT
	world.get_node("Apartment").visible = false
	(world.get_node("Environment") as WorldEnvironment).environment = flat48.env
	player.global_transform = flat48.global_transform * flat48.spawn
	player.yaw = player.global_transform.basis.get_euler().y; player.pitch = 0.0
	player.velocity = Vector3.ZERO
	Game.flags["in_flat48"] = true

func leave_labyrinth(to: Transform3D) -> void:
	in_labyrinth = false
	labyrinth.visible = false; labyrinth.process_mode = Node.PROCESS_MODE_DISABLED
	world.get_node("Apartment").visible = true
	(world.get_node("Environment") as WorldEnvironment).environment = world.environment
	player.global_position = to.origin; player.yaw = to.basis.get_euler().y; player.velocity = Vector3.ZERO

## the screen grain's frame: 12 a second, like film (the shader's comment says why)
var _grain_t := 0.0
func _process(delta: float) -> void:
	_grain_t += delta
	if container and container.material:
		(container.material as ShaderMaterial).set_shader_parameter("grain_seed", float(int(_grain_t * 12.0) % 64))

func _physics_process(_d: float) -> void:
	if Skills.owned("second_wind") and not Input.is_action_pressed("sprint"):
		player.stamina = minf(1.0, player.stamina + _d * 0.06)
	if in_labyrinth:
		var local := labyrinth.to_local(player.global_position)
		var w := labyrinth.wrap(local)
		if w != local:
			player.global_position = labyrinth.to_global(w)

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
		# a click captures the mouse for looking, on a computer. Never on a phone: there every touch
		# also arrives as a pretend mouse press, and a captured mouse stops the on-screen buttons
		# (USE, FIRE, everything) from getting their presses at all.
		if not Game.has_touch() and e.device != InputEvent.DEVICE_ID_EMULATION:
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
