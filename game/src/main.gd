extends Node
## Boot, the render pipeline, level loading and transitions.
##
## Render pipeline: the 3D world renders into a SubViewport at 1/render_div of the screen (PS1
## pixels, and the single biggest saving on a phone), shown nearest-neighbour through a
## SubViewportContainer whose material is the post pass (dither, grain, infection). The UI renders
## above it at full resolution.
##
## Command line (after `--`):  --autotest[=name]  --fast  --start=flat47|backrooms|flat48
##                             --shots=DIR  --skip-intro

const POST := preload("res://shaders/post.gdshader")

var container: SubViewportContainer
var viewport: SubViewport
var world: Node3D
var post: ShaderMaterial
var hud: Node
var level: Level
var player: Player
var director: Node
var args := {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else true
	if args.has("fast"):
		Speech.fast = true
	_pipeline()
	Perf.quality_changed.connect(_apply_quality)
	_apply_quality(Perf.current)
	hud = load("res://src/ui/hud.gd").new()
	hud.name = "HUD"
	add_child(hud)
	Events.request_level.connect(func(n, s): load_level(n, s))
	var start := String(args.get("start", "flat47"))
	if args.has("autotest"):
		var t: Node = load("res://src/tests/autotest.gd").new()
		t.name = "Autotest"
		add_child(t)
		t.begin(self, String(args.autotest) if args.autotest is String else "all")
		return
	if args.has("load") and SaveGame.exists():
		SaveGame.load_game(self)
		return
	load_level(start, "")

func _pipeline() -> void:
	container = SubViewportContainer.new()
	container.name = "View"
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	post = ShaderMaterial.new()
	post.shader = POST
	container.material = post
	add_child(container)
	viewport = SubViewport.new()
	viewport.name = "World"
	viewport.handle_input_locally = false
	viewport.audio_listener_enable_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.positional_shadow_atlas_size = 1024
	container.add_child(viewport)
	world = Node3D.new()
	world.name = "WorldRoot"
	viewport.add_child(world)

func _apply_quality(q: Dictionary) -> void:
	container.stretch_shrink = int(q.get("render_div", 3))
	# keep PS1 vertex snapping matched to the actual render resolution
	var size := get_viewport().get_visible_rect().size / float(container.stretch_shrink)
	for m in Mats._tex.keys():
		pass
	RenderingServer.global_shader_parameter_set("infection", Infection.effective())
	post.set_shader_parameter("grain", float(Settings.get_v("grain")))
	post.set_shader_parameter("brightness", float(Settings.get_v("brightness")))
	size = size

## Load a level by name ("flat47", "backrooms", "flat48") and put Kurt at a spawn.
func load_level(name: String, spawn: String) -> void:
	var keep_inv: Dictionary = player.inv.to_dict() if player else {}
	var keep_inj: int = player.injury if player else 0
	var had_gun := player != null and player.gun != null
	var gun_state: Dictionary = player.gun.get_state() if had_gun else {}
	if director:
		director.queue_free()
		director = null
	if level:
		level.queue_free()
		level = null
		await get_tree().process_frame
	var layout: Dictionary
	match name:
		"flat47": layout = Flat47Layout.layout()
		"backrooms": layout = load("res://src/levels/backrooms.gd").layout()
		"flat48": layout = load("res://src/levels/flat48.gd").layout()
	level = Level.new()
	level.name = "Level_" + name
	world.add_child(level)
	level.build(layout, name)
	Sfx.attach_world(level)
	if not player:
		player = Player.new()
		player.name = "Kurt"
		world.add_child(player)
	player.level = level
	level.player = player
	if not keep_inv.is_empty():
		player.inv.from_dict(keep_inv)
		player.injury = keep_inj
	var sp := spawn if spawn != "" else "start"
	if level.spawns.has(sp):
		player.global_transform = level.spawns[sp]
	Story.chapter = name
	hud.bind(player, self)
	var dpath: String = {"flat47": "res://src/story/scene_a.gd", "backrooms": "res://src/story/backrooms_chapter.gd", "flat48": "res://src/story/flat48_chapter.gd"}.get(name, "")
	if dpath != "" and ResourceLoader.exists(dpath):
		director = load(dpath).new()
		director.name = "Director"
		add_child(director)
		director.begin(self, sp)
	if had_gun and player.gun:
		player.gun.set_state(gun_state)
	Events.level_ready.emit(name)

func set_blackout(k: float, sec := 0.0) -> void:
	if sec <= 0.0:
		post.set_shader_parameter("blackout", k)
		return
	var from: float = post.get_shader_parameter("blackout")
	var t := create_tween()
	t.tween_method(func(v): post.set_shader_parameter("blackout", v), from, k, sec)
	await t.finished

func set_post(param: String, v: float, sec := 0.0) -> void:
	if sec <= 0.0:
		post.set_shader_parameter(param, v)
		return
	var from = post.get_shader_parameter(param)
	if from == null:
		from = 0.0
	var t := create_tween()
	t.tween_method(func(x): post.set_shader_parameter(param, x), float(from), v, sec)

func _process(_delta: float) -> void:
	if level:
		post.set_shader_parameter("wrong", float(level.data.get("wrong_grade", 0.0)))
	if player:
		post.set_shader_parameter("hurt", clampf(player.injury / 3.0, 0.0, 1.0) * 0.6)
