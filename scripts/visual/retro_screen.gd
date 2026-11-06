class_name RetroScreen
extends CanvasLayer
## The low-resolution screen: the 3D world is drawn into a small picture (240 lines like
## a PlayStation, or 480 like an early PS2) and blown up with hard pixel edges, while the
## HUD and menus stay sharp on top. It shares the main viewport's world and copies its
## camera every frame, so nothing else in the game needs to know it exists. Fewer pixels
## also means far less work for a phone's GPU.

## Lines tall (0 = draw at full resolution, no pixels).
static var lines: int = 0
var _sub: SubViewport
var _rect: TextureRect
var _cam: Camera3D


static func install(owner_node: Node) -> RetroScreen:
	var r := RetroScreen.new()
	r.name = "RetroScreen"
	owner_node.add_child(r)
	return r


func _ready() -> void:
	layer = -100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sub = SubViewport.new()
	_sub.name = "Screen"
	_sub.world_3d = get_viewport().world_3d
	_sub.msaa_3d = Viewport.MSAA_DISABLED
	_sub.gui_disable_input = true
	_sub.audio_listener_enable_3d = false
	_sub.positional_shadow_atlas_size = 0
	# The house leans on occlusion culling (solid walls hide whole rooms): keep it.
	_sub.use_occlusion_culling = get_viewport().use_occlusion_culling
	_sub.mesh_lod_threshold = get_viewport().mesh_lod_threshold
	add_child(_sub)
	_cam = Camera3D.new()
	_sub.add_child(_cam)
	_cam.current = true
	_rect = TextureRect.new()
	_rect.texture = _sub.get_texture()
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)
	RenderingServer.frame_pre_draw.connect(_sync)
	get_viewport().size_changed.connect(apply)
	apply()


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync):
		RenderingServer.frame_pre_draw.disconnect(_sync)
	var vp := get_viewport()
	if vp:
		vp.disable_3d = false


## Applies `lines` (call again after changing it).
func apply() -> void:
	var on := lines > 0
	var vp := get_viewport()
	vp.disable_3d = on
	_rect.visible = on
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if on:
		var full := Vector2(vp.get_visible_rect().size)
		var h := mini(lines, int(full.y))
		_sub.size = Vector2i(maxi(int(round(h * full.x / maxf(full.y, 1.0))), 1), h)


## Copies the main viewport's camera (whichever is current: the follow camera, photo
## mode, a cutscene) just before the frame is drawn.
func _sync() -> void:
	if lines <= 0 or not is_inside_tree():
		return
	var c := get_viewport().get_camera_3d()
	if c == null or c == _cam:
		return
	_cam.global_transform = c.get_global_transform_interpolated()
	_cam.projection = c.projection
	_cam.fov = c.fov
	_cam.size = c.size
	_cam.near = c.near
	_cam.far = c.far
	_cam.h_offset = c.h_offset
	_cam.v_offset = c.v_offset
	_cam.keep_aspect = c.keep_aspect
	_cam.cull_mask = c.cull_mask
	_cam.environment = c.environment
	_cam.attributes = c.attributes


## The picture the world is drawn into (for screenshots of just the 3D).
func picture() -> Texture2D:
	return _sub.get_texture()
