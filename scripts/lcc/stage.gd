class_name Stage
extends Control
## The 3D view: renders the hall into a low-resolution SubViewport, upscales it with nearest
## filtering through the dither/colour-depth post shader, and owns the camera poses
## (table, look up, board) and screen-to-world picking.

signal pose_changed(pose: String)

const POSES := {
	"table": [Vector3(0, 1.62, 1.72), Vector3(0, 0.74, -0.12), 52.0],
	"board": [Vector3(0, 2.0, 1.12), Vector3(0, 0.74, -0.06), 54.0],
	"up":    [Vector3(0, 1.45, 1.72), Vector3(0, 2.0, -5.6), 50.0],
	"title": [Vector3(-0.6, 1.55, 2.4), Vector3(0.2, 1.95, -5.4), 52.0],
	"map":   [Vector3(-0.12, 1.85, 0.92), Vector3(-0.12, 0.76, -0.12), 50.0],
	"deal":  [Vector3(0, 1.62, 1.02), Vector3(0, 0.74, -0.22), 54.0],
	"walk":  [Vector3(0, 1.6, 3.5), Vector3(0, 1.4, -2.0), 64.0],
}

var container: SubViewportContainer
var viewport: SubViewport
var camera: Camera3D
var env: WorldEnvironment
var hall: Hall
var post: ShaderMaterial
var pose := "table"
var pose_tween: Tween
var board_pan := Vector3.ZERO
var board_zoom := 0.0
var internal_height := 360
var shake := 0.0
var _base_pos := Vector3.ZERO
var _look_at := Vector3.ZERO
var _fov := 52.0
var walk_mode := false
## Glancing round from your seat: a drag turns your head; let go and it comes back.
var glance := Vector2.ZERO
var _glance_target := Vector2.ZERO

func set_glance(g: Vector2) -> void:
	_glance_target = g.clamp(Vector2(-1.1, -0.35), Vector2(1.1, 0.6))

static var instance: Stage
## Things you read (cards, sheets, the map, chalk) are drawn on their own layer by a second
## camera at the screen's full resolution, over the chunky low-resolution room. They are still
## objects in the room; they just aren't blurred by it.
const SHARP_LAYER := 1 << 17
var sharp_vp: SubViewport
var sharp_cam: Camera3D
var sharp_rect: TextureRect
## Full-resolution layer over the low-resolution 3D view: anything you have to read (chalk
## notes over the board, the card held up to your face) is drawn here so it stays sharp.
var overlay: Control
var walk_yaw := 0.0
var walk_pitch := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	container = SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	post = ShaderMaterial.new()
	post.shader = load("res://shaders/post.gdshader")
	container.material = post
	add_child(container)
	viewport = SubViewport.new()
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.positional_shadow_atlas_size = 1024
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.handle_input_locally = false
	container.add_child(viewport)
	env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("0a0806")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("4a3e32")
	e.ambient_light_energy = 1.05
	e.fog_enabled = true
	e.fog_light_color = Color("14100c")
	e.fog_density = 0.05
	e.fog_sky_affect = 0.0
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	viewport.add_child(env)
	hall = Hall.new()
	hall.name = "Hall"
	viewport.add_child(hall)
	camera = Camera3D.new()
	camera.near = 0.05
	camera.far = 40.0
	camera.cull_mask = 0xFFFFF & ~SHARP_LAYER
	sharp_vp = SubViewport.new()
	sharp_vp.transparent_bg = true
	sharp_vp.msaa_3d = Viewport.MSAA_2X
	sharp_vp.handle_input_locally = false
	sharp_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sharp_vp)
	sharp_cam = Camera3D.new()
	sharp_cam.near = 0.05
	sharp_cam.far = 40.0
	sharp_cam.cull_mask = SHARP_LAYER
	sharp_vp.add_child(sharp_cam)
	sharp_cam.current = true
	sharp_rect = TextureRect.new()
	sharp_rect.texture = sharp_vp.get_texture()
	sharp_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sharp_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sharp_rect.stretch_mode = TextureRect.STRETCH_SCALE
	sharp_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sharp_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	viewport.add_child(camera)
	camera.current = true
	set_pose("table", 0.0)
	instance = self
	add_child(sharp_rect)
	overlay = Control.new()
	overlay.name = "ReadLayer"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	resized.connect(_apply_resolution)
	get_viewport().size_changed.connect(_fit)
	_fit()

func _fit() -> void:
	if not (get_parent() is Control):
		position = Vector2.ZERO
		size = get_viewport_rect().size
	_apply_resolution()

func set_internal_height(h: int) -> void:
	internal_height = clampi(h, 180, 1080)
	_apply_resolution()

func _apply_resolution() -> void:
	if container == null:
		return
	# the sharp layer renders at the real pixel size of the window
	if sharp_vp:
		var phys := Vector2(DisplayServer.window_get_size()) if not Engine.is_editor_hint() else get_viewport_rect().size
		if phys.x < 16:
			phys = get_viewport_rect().size
		sharp_vp.size = Vector2i(mini(int(phys.x), 3200), mini(int(phys.y), 1600))
	var sz := get_viewport_rect().size
	var shrink := maxi(1, int(round(sz.y / internal_height)))
	container.stretch_shrink = shrink
	post.set_shader_parameter("src_size", sz / shrink)

func set_pose(name: String, dur: float = 0.6) -> void:
	if not POSES.has(name):
		return
	pose = name
	var p: Array = POSES[name]
	var target_pos: Vector3 = p[0]
	var target_look: Vector3 = p[1]
	if name == "board":
		target_pos += board_pan + Vector3(0, board_zoom, -board_zoom * 0.4)
		target_look += board_pan
	if pose_tween and pose_tween.is_valid():
		pose_tween.kill()
	var reduced: bool = Settings.get_value("reduced_motion", false) if Engine.has_singleton("Settings") or get_node_or_null("/root/Settings") else false
	if dur <= 0.0 or reduced:
		_base_pos = target_pos
		_look_at = target_look
		_fov = p[2]
		_apply_camera()
		pose_changed.emit(name)
		return
	pose_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pose_tween.tween_method(func(k: float):
		_base_pos = _base_pos.lerp(target_pos, k)
		_look_at = _look_at.lerp(target_look, k)
		_fov = lerpf(_fov, p[2], k)
		_apply_camera(), 0.0, 1.0, dur)
	pose_tween.tween_callback(func(): pose_changed.emit(name))

func pan_board(delta: Vector3) -> void:
	board_pan = (board_pan + delta).clamp(Vector3(-0.6, 0, -0.5), Vector3(0.6, 0, 0.5))
	if pose == "board":
		var p: Array = POSES["board"]
		_base_pos = p[0] + board_pan + Vector3(0, board_zoom, -board_zoom * 0.4)
		_look_at = p[1] + board_pan
		_apply_camera()

func zoom_board(dz: float) -> void:
	board_zoom = clampf(board_zoom + dz, -0.75, 0.6)
	pan_board(Vector3.ZERO)

func _apply_camera() -> void:
	camera.fov = _fov
	var sh := Vector3.ZERO
	if shake > 0.0:
		sh = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.02
	if walk_mode:
		camera.position = _base_pos
		camera.rotation = Vector3(walk_pitch, walk_yaw, 0)
		_sync_sharp()
		return
	camera.position = _base_pos + sh
	if camera.position.distance_to(_look_at) > 0.01:
		camera.look_at(_look_at, Vector3.UP)
	if glance.length() > 0.001:
		camera.rotate_y(-glance.x)
		camera.rotate_object_local(Vector3.RIGHT, glance.y)
	_sync_sharp()

## A sharp label pinned to something in the 3D view (a node, or a fixed point), so you can
## always tell what a thing is, at any screen size. below: hang it under the point.
func pin(text: String, target, offset := Vector3.ZERO, col := Color("f0e6cc"), size := 22, below := false) -> Label:
	UIKit.fonts()
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UIKit.title_font)
	l.add_theme_font_size_override("font_size", int(size * float(Settings.get_value("text_size", 1.0))))
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if target is Node3D:
		l.set_meta("follow", target)
		l.set_meta("offset", offset)
		l.set_meta("world", target.global_position + offset)
	else:
		l.set_meta("world", Vector3(target) + offset)
	l.set_meta("below", below)
	overlay.add_child(l)
	l.reset_size()
	return l

func _sync_sharp() -> void:
	if sharp_cam and camera:
		sharp_cam.global_transform = camera.global_transform
		sharp_cam.fov = camera.fov

func _process(delta: float) -> void:
	if not walk_mode and (glance.distance_to(_glance_target) > 0.0005):
		glance = glance.lerp(_glance_target, minf(1.0, delta * 8.0))
		_apply_camera()
	_sync_sharp()
	# keep the sharp labels pinned over the 3D points they belong to
	for c in overlay.get_children():
		if c.has_meta("world"):
			var wp: Vector3 = c.get_meta("world")
			if c.has_meta("follow"):
				var follow = c.get_meta("follow")
				if is_instance_valid(follow):
					wp = follow.global_position + c.get_meta("offset", Vector3.ZERO)
			c.visible = not camera.is_position_behind(wp) and not walk_mode
			var sp := world_to_screen(wp) - global_position
			c.position = sp - Vector2(c.size.x / 2.0, 0.0 if c.get_meta("below", false) else c.size.y)
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 2.5)
		_apply_camera()

func add_shake(amount: float) -> void:
	if get_node_or_null("/root/Settings") and not Settings.get_value("screen_shake", true):
		return
	shake = maxf(shake, amount)

func flash(strength: float = 0.4) -> void:
	var tw := create_tween()
	post.set_shader_parameter("flash", strength)
	tw.tween_method(func(v): post.set_shader_parameter("flash", v), strength, 0.0, 0.35)

## Ray from a point on screen (window coordinates) into the 3D world.
func screen_ray(screen_pos: Vector2) -> Array:
	var local := screen_pos - container.global_position
	var vp_pos := local / float(container.stretch_shrink)
	return [camera.project_ray_origin(vp_pos), camera.project_ray_normal(vp_pos)]

## Intersect with a horizontal plane (the table top), or null.
func screen_to_plane(screen_pos: Vector2, y: float) -> Variant:
	var r := screen_ray(screen_pos)
	var o: Vector3 = r[0]
	var d: Vector3 = r[1]
	if abs(d.y) < 0.0001:
		return null
	var t := (y - o.y) / d.y
	if t < 0:
		return null
	return o + d * t

func world_to_screen(p: Vector3) -> Vector2:
	return camera.unproject_position(p) * float(container.stretch_shrink) + container.global_position

func is_behind(p: Vector3) -> bool:
	return camera.is_position_behind(p)

func set_fog(col: Color, density: float) -> void:
	env.environment.fog_light_color = col
	env.environment.fog_density = density

## LAST CALL 3 / MURDERLAND: the robot's party is bright. Lift the room out of the dark:
## warm pink ambient, a thin haze instead of fog, colour back in the picture, the pen
## hatching only in the deep shadows. (dread still creeps in with his unrest.)
## The look of the whole game: a filthy bathroom under one buzzing tube. Drained colour,
## bile-green mids, crushed blacks; blood keeps its red.
func saw_look() -> void:
	post.set_shader_parameter("saw", 0.4)
	post.set_shader_parameter("saturation", 0.95)
	post.set_shader_parameter("brightness", 1.02)
	post.set_shader_parameter("contrast", 1.15)
	post.set_shader_parameter("vignette", 0.55)
	post.set_shader_parameter("hatch", 0.25)
	post.set_shader_parameter("ink_lines", 0.7)
	post.set_shader_parameter("grain", 0.9)


func party_look() -> void:
	var e := env.environment
	e.background_color = Color("0b0d09")
	e.ambient_light_color = Color("a8b090")
	e.ambient_light_energy = 1.0
	e.fog_light_color = Color("1e2418")
	e.fog_density = 0.014
	saw_look()
	camera.far = 60.0
	if hall.lamp_light:
		hall.lamp_light.light_energy = 0.9
