class_name TownKit
extends RefCounted
## Geometry for the old town: boxes, quads and prisms with UVs in world metres (so every texture
## keeps the same texel density however big the surface), collected by material into 8 m
## chunks. A chunk is one draw call per material and is touched by only the few lamps near it,
## which keeps the Compatibility renderer (phones) under its per-mesh light limit.

const CHUNK := 8.0
const PS1 := preload("res://shaders/ps1.gdshader")

## material name -> [texture set, metres per texture repeat, roughness, specular, extra]
const MATS := {
	"cobbles": ["cobbles", 2.0, 1.0, 0.45, {}],
	"stucco_ochre": ["stucco_ochre", 2.6, 0.95, 0.25, {}],
	"stucco_cream": ["stucco_cream", 2.6, 0.95, 0.25, {}],
	"stucco_rose": ["stucco_rose", 2.6, 0.95, 0.25, {}],
	"stucco_green": ["stucco_green", 2.6, 0.95, 0.25, {}],
	"rustic_ochre": ["rustic_ochre", 2.0, 0.95, 0.25, {}],
	"rustic_cream": ["rustic_cream", 2.0, 0.95, 0.25, {}],
	"trim": ["trim", 1.0, 0.9, 0.3, {}],
	"wood": ["wood", 2.0, 0.95, 0.2, {}],
	"carved_white": ["carved_white", 0.6, 0.9, 0.3, {"alpha": true}],
	"carved_blue": ["carved_blue", 0.6, 0.9, 0.3, {"alpha": true}],
	"tin": ["tin", 1.0, 0.6, 0.6, {}],
	"glass": ["glass", 1.0, 0.15, 0.9, {}],
	"shop": ["shop", 2.4, 1.0, 0.2, {"glow": 1.1}],
	"shop_bakery": ["shop_bakery", 2.4, 1.0, 0.2, {"glow": 1.1}],
	"shop_photo": ["shop_photo", 2.4, 1.0, 0.2, {"glow": 1.0}],
	"shop_clock": ["shop_clock", 2.4, 1.0, 0.2, {"glow": 1.0}],
	"shop_tavern": ["shop_tavern", 2.4, 1.0, 0.2, {"glow": 1.2}],
	"shop_hotel": ["shop_hotel", 2.4, 1.0, 0.2, {"glow": 1.0}],
	"gold": ["gold", 0.8, 0.35, 0.9, {}],
	"plaster_in": ["plaster_in", 2.0, 0.95, 0.2, {}],
	"parquet": ["parquet", 2.0, 0.7, 0.4, {}],
	"brick": ["brick", 2.0, 0.95, 0.25, {"color": Color(0.78, 0.74, 0.72)}],
	"iron": ["", 1.0, 0.55, 0.6, {"color": Color(0.08, 0.08, 0.085)}],
	"paint_green": ["", 1.0, 0.7, 0.4, {"color": Color(0.12, 0.22, 0.17)}],
	"paint_door": ["wood", 1.2, 0.8, 0.3, {"color": Color(0.55, 0.3, 0.22)}],
	"lamp_glass": ["glass", 1.0, 0.2, 0.5, {"color": Color(1.0, 0.85, 0.6), "emit": Vector3(1.15, 0.72, 0.32)}],
	"window_glow": ["glass", 1.0, 0.3, 0.5, {"emit": Vector3(0.9, 0.55, 0.22)}],
	"stone": ["trim", 1.5, 0.95, 0.3, {"color": Color(0.62, 0.6, 0.56)}],
	"sand": ["", 1.0, 1.0, 0.1, {"color": Color(0.16, 0.13, 0.1)}],
	"awning_red": ["paper", 1.0, 0.95, 0.15, {"color": Color(0.62, 0.16, 0.12)}],
	"awning_white": ["paper", 1.0, 0.95, 0.15, {"color": Color(0.95, 0.92, 0.85)}],
	"trail": ["", 1.0, 1.0, 0.0, {"blend": Color(0.75, 0.85, 1.0, 0.16)}],
	"blued": ["", 1.0, 0.32, 0.85, {"color": Color(0.09, 0.1, 0.12)}],
	"walnut": ["wood", 0.12, 0.6, 0.4, {"color": Color(0.62, 0.38, 0.22)}],
	"paper": ["paper", 0.84, 1.0, 0.1, {}],
	"paper_old": ["paper_old", 0.84, 1.0, 0.1, {"alpha": true}],
	"leaves": ["leaves", 0.6, 1.0, 0.1, {"alpha": true}],
}

var parent: Node3D
var tools := {}          # Vector3i chunk -> {mat: SurfaceTool}
var _mat_cache := {}

func _init(p_parent: Node3D) -> void:
	parent = p_parent

func _st(mat: String, at: Vector3) -> SurfaceTool:
	var key := Vector3i(floori(at.x / CHUNK), floori(at.y / 12.0), floori(at.z / CHUNK))
	if not tools.has(key): tools[key] = {}
	var d: Dictionary = tools[key]
	if not d.has(mat):
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		d[mat] = st
	return d[mat]

## A flat quad a-b-c-d (any winding: it's fixed so the front faces `normal`). UVs from the
## world position projected on the quad's own axes, in metres / repeat.
func quad(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, uv_origin := Vector3.INF) -> void:
	var rep: float = MATS[mat][1]
	var ax := (b - a).normalized()
	var ay := normal.cross(ax).normalized()
	var o := a if uv_origin == Vector3.INF else uv_origin
	var st := _st(mat, (a + c) * 0.5)
	var n := (b - a).cross(c - a)
	var pts := [a, b, c, a, c, d]
	if n.dot(normal) > 0.0:              # Godot fronts are clockwise seen from the front
		pts = [a, c, b, a, d, c]
	for p in pts:
		var q: Vector3 = p - o
		st.set_normal(normal)
		st.set_uv(Vector2(q.dot(ax), -q.dot(ay)) / rep)
		st.add_vertex(p)

## An oriented box: centre, half-size, basis. `faces` skips sides that can't be seen (a bitmask:
## 1 +x, 2 -x, 4 +y, 8 -y, 16 +z, 32 -z).
func box(mat: String, c: Vector3, h: Vector3, b := Basis(), faces := 63) -> void:
	var X := b.x * h.x; var Y := b.y * h.y; var Z := b.z * h.z
	var bx := b.x.normalized(); var by := b.y.normalized(); var bz := b.z.normalized()
	if faces & 1:  quad(mat, c + X - Y + Z, c + X - Y - Z, c + X + Y - Z, c + X + Y + Z, bx)
	if faces & 2:  quad(mat, c - X - Y - Z, c - X - Y + Z, c - X + Y + Z, c - X + Y - Z, -bx)
	if faces & 4:  quad(mat, c - X + Y + Z, c + X + Y + Z, c + X + Y - Z, c - X + Y - Z, by)
	if faces & 8:  quad(mat, c - X - Y - Z, c + X - Y - Z, c + X - Y + Z, c - X - Y + Z, -by)
	if faces & 16: quad(mat, c - X - Y + Z, c + X - Y + Z, c + X + Y + Z, c - X + Y + Z, bz)
	if faces & 32: quad(mat, c + X - Y - Z, c - X - Y - Z, c - X + Y - Z, c + X + Y - Z, -bz)

## A cylinder along +Y (posts, pipes, drums), low-poly.
func cyl(mat: String, base: Vector3, r: float, h: float, sides := 8, r_top := -1.0) -> void:
	var rt := r if r_top < 0.0 else r_top
	for i in sides:
		var a0 := TAU * i / sides; var a1 := TAU * (i + 1) / sides
		var p0 := Vector3(cos(a0), 0, sin(a0)); var p1 := Vector3(cos(a1), 0, sin(a1))
		var n := (p0 + p1).normalized()
		quad(mat, base + p0 * r, base + p1 * r, base + p1 * rt + Vector3(0, h, 0), base + p0 * rt + Vector3(0, h, 0), n)
	if rt > 0.0:
		for i in sides:
			var a0 := TAU * i / sides; var a1 := TAU * (i + 1) / sides
			var top := base + Vector3(0, h, 0)
			_tri(mat, top, top + Vector3(cos(a1), 0, sin(a1)) * rt, top + Vector3(cos(a0), 0, sin(a0)) * rt, Vector3.UP)

## a cylinder from a to b (any direction), capped at both ends
func cyl_axis(mat: String, a: Vector3, b: Vector3, r: float, sides := 8, r_b := -1.0) -> void:
	var rb := r if r_b < 0.0 else r_b
	var ax := (b - a).normalized()
	var u := ax.cross(Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := ax.cross(u)
	for i in sides:
		var a0 := TAU * i / sides; var a1 := TAU * (i + 1) / sides
		var d0 := u * cos(a0) + v * sin(a0); var d1 := u * cos(a1) + v * sin(a1)
		quad(mat, a + d0 * r, a + d1 * r, b + d1 * rb, b + d0 * rb, (d0 + d1).normalized())
		_tri(mat, a, a + d1 * r, a + d0 * r, -ax)
		_tri(mat, b, b + d0 * rb, b + d1 * rb, ax)

func _tri(mat: String, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	var rep: float = MATS[mat][1]
	var st := _st(mat, (a + b + c) / 3.0)
	var pts := [a, b, c]
	if (b - a).cross(c - a).dot(normal) > 0.0: pts = [a, c, b]
	var ax := (b - a).normalized(); var ay := normal.cross(ax).normalized()
	for p in pts:
		var q: Vector3 = p - a
		st.set_normal(normal); st.set_uv(Vector2(q.dot(ax), -q.dot(ay)) / rep); st.add_vertex(p)

func tri(mat: String, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	_tri(mat, a, b, c, normal)

## Build it: one MeshInstance per chunk and material.
func finish() -> int:
	var n := 0
	for key in tools:
		var d: Dictionary = tools[key]
		for mat in d:
			var st: SurfaceTool = d[mat]
			st.generate_tangents()
			var mi := MeshInstance3D.new()
			mi.mesh = st.commit()
			mi.material_override = material(mat)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if not (mat in ["glass", "lamp_glass", "window_glow"] or mat.begins_with("shop")) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mi)
			n += 1
	tools.clear()
	return n

func material(mat: String) -> Material:
	if _mat_cache.has(mat):
		return _mat_cache[mat]
	var spec: Array = MATS[mat]
	if (spec[4] as Dictionary).has("blend"):
		# see-through, unlit: frozen motion streaks
		var sm := StandardMaterial3D.new(); sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; sm.albedo_color = spec[4].blend
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED; sm.no_depth_test = false
		_mat_cache[mat] = sm
		return sm
	var m := ShaderMaterial.new(); m.shader = PS1
	var ex: Dictionary = spec[4]
	if spec[0] != "":
		var t: Dictionary = RomanovTextures.get_set(spec[0])
		m.set_shader_parameter("albedo_tex", t.albedo)
		if t.has("normal"):
			m.set_shader_parameter("normal_tex", t.normal); m.set_shader_parameter("use_normal_tex", true)
			m.set_shader_parameter("normal_depth", 1.0)
		if t.has("rough"):
			m.set_shader_parameter("roughness_tex", t.rough); m.set_shader_parameter("use_roughness_tex", true)
	else:
		m.set_shader_parameter("albedo_tex", _white())
	m.set_shader_parameter("albedo_color", ex.get("color", Color.WHITE))
	m.set_shader_parameter("roughness", spec[2])
	m.set_shader_parameter("specular", spec[3])
	m.set_shader_parameter("snap_res", Vector2(426, 240))
	if ex.get("alpha", false): m.set_shader_parameter("use_alpha_cut", true)
	if ex.has("emit"): m.set_shader_parameter("emission", ex.emit)
	if ex.has("glow"):
		m.set_shader_parameter("emission", Vector3.ONE * float(ex.glow))
		m.set_shader_parameter("emission_tex", RomanovTextures.get_set(spec[0]).albedo); m.set_shader_parameter("use_emission_tex", true)
	_mat_cache[mat] = m
	return m

static var _white_tex: Texture2D
static func _white() -> Texture2D:
	if not _white_tex:
		var img := Image.create(2, 2, false, Image.FORMAT_RGB8); img.fill(Color.WHITE)
		_white_tex = ImageTexture.create_from_image(img)
	return _white_tex
