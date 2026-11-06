class_name PaperProp
extends Node3D
## A piece of paper (or card) lying in the world whose face is a Control drawn into a little
## viewport: character sheets on the table, the encounter card in the rule rack. Redraw it
## with refresh(); find out if the player pointed at it with hit().

var vp: SubViewport
var face: Control
var size := Vector2(0.4, 0.2)
var mi: MeshInstance3D

func setup(face_control: Control, tex_size: Vector2i, world_size: Vector2, lit := true) -> PaperProp:
	size = world_size
	vp = SubViewport.new()
	vp.size = tex_size * 3
	vp.size_2d_override = tex_size
	vp.size_2d_override_stretch = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	face = face_control
	face.size = Vector2(tex_size)
	vp.add_child(face)
	mi = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = world_size
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = MB.PSX if lit else MB.PSX_UNLIT
	m.set_shader_parameter("albedo_tex", vp.get_texture())
	m.set_shader_parameter("albedo", Color(1, 1, 1))
	m.set_shader_parameter("snap_res", 0.0)
	m.set_shader_parameter("affine", 0.0)
	mi.material_override = m
	mi.layers = Stage.SHARP_LAYER
	add_child(mi)
	return self

func refresh() -> void:
	if face:
		face.queue_redraw()
	if vp:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE

## Is this screen point on the paper?
func hit(stage: Stage, screen_pos: Vector2) -> bool:
	if not is_visible_in_tree():
		return false
	var pts: Array = []
	for p in [Vector3(-size.x / 2, -size.y / 2, 0), Vector3(size.x / 2, -size.y / 2, 0), Vector3(size.x / 2, size.y / 2, 0), Vector3(-size.x / 2, size.y / 2, 0)]:
		var w = mi.global_transform * p
		if stage.is_behind(w):
			return false
		pts.append(stage.world_to_screen(w))
	return Geometry2D.is_point_in_polygon(screen_pos, PackedVector2Array(pts))
