extends Node
## Loads everything listed in data/asset_registry.json and hands it out ready to place:
## props scaled to metres, origin at the floor in the middle of their footprint, every
## material converted to the shared PS1 shader, optional box collision. Nothing else in the
## game loads asset files by path.

const REGISTRY := "res://data/asset_registry.json"
const PS1 := preload("res://render/ps1.gdshader")
const PS1_CUTOUT := preload("res://render/ps1_cutout.gdshader")
const TEX_DIR := "res://assets/textures/ambientcg/"

var registry: Dictionary = {}
var _scenes: Dictionary = {}          ## path → PackedScene
var _converted: Dictionary = {}       ## source Material → ShaderMaterial
var _surface_mats: Dictionary = {}    ## texture name + tint → ShaderMaterial

func _ready() -> void:
	registry = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))

## A PS1 material for one of the processed ambientCG textures. `metres` is how much world one
## repeat of the texture covers (generated geometry has UVs in metres).
func surface(tex: String, metres := 2.0, tint := Color.WHITE, emission := Color.BLACK) -> ShaderMaterial:
	var key := "%s|%s|%s|%s" % [tex, metres, tint.to_html(), emission.to_html()]
	if _surface_mats.has(key):
		return _surface_mats[key]
	var m := ShaderMaterial.new()
	m.shader = PS1
	if tex != "":
		m.set_shader_parameter("albedo_tex", load(TEX_DIR + tex + ".png"))
		m.set_shader_parameter("use_texture", true)
	m.set_shader_parameter("albedo", tint)
	m.set_shader_parameter("uv_scale", Vector2.ONE / metres)
	m.set_shader_parameter("emission", Vector3(emission.r, emission.g, emission.b))
	_surface_mats[key] = m
	return m

func has_prop(id: String) -> bool:
	return registry.props.has(id)

## A new instance of prop `id`. Collision ("box" in the registry) is a StaticBody3D on the
## world layer around the prop's bounds.
func prop(id: String) -> Node3D:
	var def: Dictionary = registry.props.get(id, {})
	if def.is_empty():
		push_error("unknown prop " + id)
		return Node3D.new()
	var root := Node3D.new()
	root.name = id
	var model := _instance(def.path)
	model.scale = Vector3.ONE * float(def.scale)
	root.add_child(model)
	var box := bounds(model, root)
	model.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	root.set_meta("size", box.size)
	if def.collision == "box":
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = box.size.max(Vector3.ONE * 0.05)
		shape.shape = b
		shape.position.y = box.size.y * 0.5
		body.add_child(shape)
		root.add_child(body)
	return root

## A character body (skinned mesh + AnimationPlayer), materials converted, 1 unit = 1 m.
func character(id: String) -> Node3D:
	var def: Dictionary = registry.characters.get(id, {})
	return _instance(def.path) if not def.is_empty() else Node3D.new()

func _instance(path: String) -> Node3D:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	var n: Node3D = (_scenes[path] as PackedScene).instantiate()
	convert_materials(n)
	return n

## Swap every StandardMaterial3D under `node` for the PS1 shader with the same colour/texture.
func convert_materials(node: Node) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var src := m.get_active_material(i)
			if src is StandardMaterial3D:
				m.set_surface_override_material(i, ps1_from(src))
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func ps1_from(src: StandardMaterial3D) -> ShaderMaterial:
	if _converted.has(src):
		return _converted[src]
	var m := ShaderMaterial.new()
	m.shader = PS1_CUTOUT if src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED else PS1
	m.set_shader_parameter("albedo", src.albedo_color)
	if src.albedo_texture:
		m.set_shader_parameter("albedo_tex", src.albedo_texture)
		m.set_shader_parameter("use_texture", true)
	m.set_shader_parameter("use_vertex_color", src.vertex_color_use_as_albedo)
	if src.emission_enabled:
		var e := src.emission * src.emission_energy_multiplier
		m.set_shader_parameter("emission", Vector3(e.r, e.g, e.b))
	_converted[src] = m
	return m

## Bounds of every mesh under `n`, in `space`'s coordinates.
func bounds(n: Node3D, space: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var t := _relative(m, space)
		var b := t * m.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out

func _relative(n: Node3D, space: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != space:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t
