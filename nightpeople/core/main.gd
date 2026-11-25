extends Node
## Boots the game: a low-resolution 3D view scaled up with nearest filtering and the PS1 post
## shader, the night environment, the neighbourhood, the player, the people, the UI.
## Command line (after `--`):
##   --shots=DIR        render the fixed camera views in tests/shots.gd to DIR and quit
##   --autotest         play the headless test in tests/autotest.gd and quit with its result
##   --at=x,z           start the player here

const NeighbourhoodScript := preload("res://world/neighbourhood.gd")
const POST := preload("res://render/ps1_post.gdshader")

var args: Dictionary = {}
var container: SubViewportContainer
var viewport: SubViewport
var world: Node3D
var hood: Neighbourhood
var env: WorldEnvironment
var ui: CanvasLayer

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	_view()
	_environment()
	hood = NeighbourhoodScript.new()
	hood.name = "Neighbourhood"
	world.add_child(hood)
	hood.build()
	Events.notice.emit("%s, %s." % [Clock.START_DATE, Clock.text()])
	_start_game()

var player: Player
var society: Society
var controls: Controls
var hud: Hud

func _start_game() -> void:
	player = Player.new()
	player.name = "Player"
	world.add_child(player)
	var st: Array = hood.street.player_start
	player.global_position = Vector3(st[0], NeighbourhoodScript.FLOOR_Y + 0.05, st[1])
	if args.has("at"):
		var at: PackedStringArray = args.at.split(",")
		player.global_position = Vector3(float(at[0]), 0.3, float(at[1]))
	player.yaw = float(hood.street.player_yaw)
	player.give_item({"id": "key_t218_1d", "name": "Key to 218 Ellery, apartment 1D", "value": 0, "owner": "player"})
	society = Society.new()
	society.name = "Society"
	add_child(society)
	society.spawn(world)
	ui = CanvasLayer.new()
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui)
	controls = Controls.new()
	hud = Hud.new()
	ui.add_child(hud)
	ui.add_child(controls)
	player.controls = controls
	hud.bind(player, controls)
	if args.has("autotest"):
		var t := preload("res://tests/autotest.gd").new()
		add_child(t)
		t.run(self)
	elif args.has("shots"):
		var shots := preload("res://tests/shots.gd").new()
		add_child(shots)
		shots.run(self, args.shots)

func _view() -> void:
	container = SubViewportContainer.new()
	container.name = "View"
	container.stretch = true
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = POST
	container.material = mat
	add_child(container)
	viewport = SubViewport.new()
	viewport.name = "Viewport"
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.positional_shadow_atlas_size = 0
	viewport.audio_listener_enable_3d = true
	container.add_child(viewport)
	world = Node3D.new()
	world.name = "World"
	viewport.add_child(world)
	_apply_settings()
	Settings.changed.connect(_apply_settings)
	get_viewport().size_changed.connect(_apply_settings)

func _apply_settings() -> void:
	var h := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	container.stretch_shrink = maxi(1, roundi(h / float(Settings.render_height)))
	(container.material as ShaderMaterial).set_shader_parameter("dither", Settings.dither)

func _environment() -> void:
	env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.025, 0.05)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.16, 0.15, 0.22)
	e.ambient_light_energy = 1.0
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	e.fog_light_color = Color(0.06, 0.05, 0.08)
	e.fog_density = 0.035
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	world.add_child(env)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.45, 0.5, 0.8)
	moon.light_energy = 0.25
	moon.shadow_enabled = false
	moon.rotation_degrees = Vector3(-55, 30, 0)
	world.add_child(moon)
