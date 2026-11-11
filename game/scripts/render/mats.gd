class_name Mats
extends RefCounted
## Materials, all on the game's own lighting (world.gdshader). The flat's exported materials are
## converted once per (material, room) and cached.

const WORLD := preload("res://shaders/world.gdshader")
const ALPHA := preload("res://shaders/world_alpha.gdshader")
static var _cache := {}

static func flat(c: Color, zone := -1, self_lit := 0.0) -> ShaderMaterial:
	var key := "flat%s|%d|%f" % [c.to_html(), zone, self_lit]
	if _cache.has(key): return _cache[key]
	var m := ShaderMaterial.new(); m.shader = WORLD
	m.set_shader_parameter("albedo_color", c)
	m.set_shader_parameter("zone", float(zone))
	m.set_shader_parameter("self_lit", self_lit)
	_cache[key] = m
	return m

static func tex(t: Texture2D, zone := -1, tint := Color.WHITE, uv := Vector2.ONE) -> ShaderMaterial:
	var key := "tex%d|%d|%s|%s" % [t.get_instance_id() if t else 0, zone, tint.to_html(), str(uv)]
	if _cache.has(key): return _cache[key]
	var m := ShaderMaterial.new(); m.shader = WORLD
	m.set_shader_parameter("albedo_tex", t)
	m.set_shader_parameter("albedo_color", tint)
	m.set_shader_parameter("zone", float(zone))
	m.set_shader_parameter("uv_scale", uv)
	_cache[key] = m
	return m

## The exported flat's StandardMaterial3D, on our lighting, for one room.
static func convert(src: Material, zone: int) -> Material:
	if not (src is BaseMaterial3D): return src
	var key := "%d|%d" % [src.get_instance_id(), zone]
	if _cache.has(key): return _cache[key]
	var std := src as BaseMaterial3D
	var m := ShaderMaterial.new()
	var see_through := std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and std.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.shader = ALPHA if see_through else WORLD
	m.set_shader_parameter("albedo_color", std.albedo_color)
	if std.albedo_texture: m.set_shader_parameter("albedo_tex", std.albedo_texture)
	m.set_shader_parameter("zone", float(zone))
	if std.emission_enabled:
		var e := std.emission * std.emission_energy_multiplier
		m.set_shader_parameter("emission", Vector3(e.r, e.g, e.b))
		if std.emission_texture and not see_through: m.set_shader_parameter("emission_tex", std.emission_texture)
	if not see_through:
		if std.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR: m.set_shader_parameter("alpha_cut", std.alpha_scissor_threshold)
		if std.cull_mode == BaseMaterial3D.CULL_DISABLED: m.set_shader_parameter("two_sided", true)
	_cache[key] = m
	return m

## Sets the zone (room) on every one of a node's materials, giving it its own copies. For things
## that move between rooms (people, things being carried).
static func own_zone(root: Node, zone: int) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false) + ([root] if root is MeshInstance3D else []):
		var m := mi as MeshInstance3D
		for i in m.get_surface_override_material_count():
			var mat := m.get_surface_override_material(i)
			if mat is ShaderMaterial:
				if not mat.has_meta("own"):
					mat = mat.duplicate(); mat.set_meta("own", true); m.set_surface_override_material(i, mat)
				(mat as ShaderMaterial).set_shader_parameter("zone", float(zone))
		if m.material_override is ShaderMaterial:
			var mo := m.material_override as ShaderMaterial
			if not mo.has_meta("own"):
				mo = mo.duplicate(); mo.set_meta("own", true); m.material_override = mo
			mo.set_shader_parameter("zone", float(zone))
