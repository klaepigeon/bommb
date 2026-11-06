class_name LcMB
extends RefCounted
## (Ported from LAST CALL: The Campaign.) Low-poly mesh builder. Parts are added in model space with a transform, a colour and a
## material key; build() returns one ArrayMesh with one surface per material. Geometry is
## deliberately faceted (flat normals, 6-8 sided cylinders) to read as late-90s models.

var surfaces: Dictionary = {}   # mat key -> SurfaceTool
var mats: Dictionary = {}       # mat key -> Material

static var _mat_cache: Dictionary = {}
static var _two_sided: Shader

## The ink shader drawn from both sides (the campaign's models were made for a shader with
## culling off, and some of their faces wind the other way).
static func shader() -> Shader:
	if _two_sided == null:
		_two_sided = Shader.new()
		_two_sided.code = (load("res://assets/shaders/ink.gdshader") as Shader).code.replace("cull_back", "cull_disabled")
	return _two_sided

## The campaign's materials, remade on RATFORMER's ink shader so the house's lamps light
## them: the texture is blown up with hard pixels and the Caller's pen-work (the blood-red
## ink sheets) is baked over it, as his PS1 shader drew it. `unlit` glows (eyes, bulbs).
static func mat(tex: Texture2D, tint: Color = Color.WHITE, uv_scale := Vector2.ONE, unlit := false, _snap := -1.0) -> ShaderMaterial:
	var key := "%s|%s|%s|%s" % [str(tex.get_instance_id() if tex else 0), tint.to_html(), str(uv_scale), str(unlit)]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = shader()
	var t: Texture2D = tex if tex else LcTex.solid(Color.WHITE)
	if not unlit:
		t = inked(t)
	m.set_shader_parameter("albedo_tex", t)
	m.set_shader_parameter("tint", tint if not unlit else Color.BLACK)
	m.set_shader_parameter("emission_color", tint if unlit else Color.BLACK)
	m.set_shader_parameter("world_uv", false)
	m.set_shader_parameter("uv_scale", uv_scale)
	m.set_shader_parameter("edge_ink", 0.0)
	m.set_shader_parameter("bump", 0.0)
	m.set_shader_parameter("rim", 0.15)
	_mat_cache[key] = m
	return m


## The same surface, for the zone's boxes: projected in world space, `per_m` repeats a unit.
static func world_mat(tex: Texture2D, per_m: float, tint := Color.WHITE) -> ShaderMaterial:
	var key := "w|%s|%s|%s" % [str(tex.get_instance_id()), str(per_m), tint.to_html()]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/ink.gdshader")
	m.set_shader_parameter("albedo_tex", inked(tex))
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("tiles_per_meter", per_m)
	m.set_shader_parameter("bump", 0.0)
	m.set_shader_parameter("object_uv", true)
	_mat_cache[key] = m
	return m


static var _inked: Dictionary = {}

## Hard pixels at 4x, then his pen over them.
static func inked(tex: Texture2D) -> Texture2D:
	var id := tex.get_instance_id()
	if _inked.has(id):
		return _inked[id]
	var kind := LcTex.ink_kind(tex)
	var img := tex.get_image()
	if img == null:
		return tex
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var size := clampi(img.get_width() * 4, 16, 256)
	img.resize(size, size, Image.INTERPOLATE_NEAREST)
	var sheet: Texture2D = LcTex.ink_sheet(kind) if kind != "" else null
	if sheet:
		var ink := sheet.get_image().duplicate()
		if ink.is_compressed():
			ink.decompress()
		ink.resize(size, size, Image.INTERPOLATE_BILINEAR)
		var amount: float = INK_AMOUNT.get(kind, 0.6)
		var red := Color(0.30, 0.04, 0.03)
		for y in size:
			for x in size:
				var c := img.get_pixel(x, y)
				var k := clampf(ink.get_pixel(x, y).r * amount, 0.0, 1.0)
				var dark := Color(red.r * (0.55 + 0.45 * c.r), red.g * (0.55 + 0.45 * c.g), red.b * (0.55 + 0.45 * c.b), c.a)
				img.set_pixel(x, y, c.lerp(dark, k))
	var out := ImageTexture.create_from_image(img)
	_inked[id] = out
	return out

## How heavily he has been over each kind of surface.
const INK_AMOUNT := {"wood": 0.7, "plaster": 0.6, "hatch": 0.55, "ceiling": 0.5, "metal": 0.5, "fabric": 0.55,
	"paper": 0.6, "stone": 0.6, "tiles4": 0.75, "tiles8": 0.75}

func _st(key: String, material: Material) -> SurfaceTool:
	if not surfaces.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces[key] = st
		mats[key] = material
	return surfaces[key]

func tri(key: String, material: Material, a: Vector3, b: Vector3, c: Vector3, col: Color, ua := Vector2(0, 0), ub := Vector2(1, 0), uc := Vector2(1, 1)) -> void:
	var st := _st(key, material)
	var n := (c - a).cross(b - a).normalized()
	for p in [[a, ua], [b, ub], [c, uc]]:
		st.set_color(col)
		st.set_normal(n)
		st.set_uv(p[1])
		st.add_vertex(p[0])

func quad(key: String, material: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, uv0 := Vector2(0, 0), uv1 := Vector2(1, 1)) -> void:
	# a b c d counter-clockwise when seen from the front
	tri(key, material, a, b, c, col, Vector2(uv0.x, uv1.y), Vector2(uv1.x, uv1.y), Vector2(uv1.x, uv0.y))
	tri(key, material, a, c, d, col, Vector2(uv0.x, uv1.y), Vector2(uv1.x, uv0.y), Vector2(uv0.x, uv0.y))

## A quad with a uv given for every corner (a b c d counter-clockwise from the front).
func quad_uv(key: String, material: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	tri(key, material, a, b, c, col, ua, ub, uc)
	tri(key, material, a, c, d, col, ua, uc, ud)

## Axis-aligned box centred at the origin of xf. uv_world scales UVs by face size (for tiling).
func box(key: String, material: Material, size: Vector3, xf: Transform3D, col: Color, uv_world := 0.0, shade := true) -> void:
	var h := size / 2.0
	var c := [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]
	for i in range(8):
		c[i] = xf * c[i]
	var faces := [[4, 5, 6, 7, Vector2(size.x, size.y)], [1, 0, 3, 2, Vector2(size.x, size.y)], [5, 1, 2, 6, Vector2(size.z, size.y)],
		[0, 4, 7, 3, Vector2(size.z, size.y)], [7, 6, 2, 3, Vector2(size.x, size.z)], [0, 1, 5, 4, Vector2(size.x, size.z)]]
	var tones := [1.0, 0.8, 0.9, 0.85, 1.08, 0.6]
	for i in range(6):
		var f = faces[i]
		var uv1 = Vector2.ONE if uv_world <= 0.0 else f[4] * uv_world
		var cc := col
		if shade:
			cc = Color(col.r * tones[i], col.g * tones[i], col.b * tones[i], col.a)
		quad(key, material, c[f[0]], c[f[1]], c[f[2]], c[f[3]], cc, Vector2.ZERO, uv1)

## Faceted cylinder / cone / frustum along +Y from y=0 to y=h.
func cyl(key: String, material: Material, r0: float, r1: float, h: float, sides: int, xf: Transform3D, col: Color, caps := true, uv_v := 1.0) -> void:
	for i in range(sides):
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var p1 := Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var q0 := Vector3(cos(a0) * r1, h, sin(a0) * r1)
		var q1 := Vector3(cos(a1) * r1, h, sin(a1) * r1)
		var tone := 0.75 + 0.25 * (0.5 + 0.5 * cos(a0 - 0.8))
		var cc := Color(col.r * tone, col.g * tone, col.b * tone, col.a)
		var u0 := float(i) / sides
		var u1 := float(i + 1) / sides
		quad(key, material, xf * p1, xf * p0, xf * q0, xf * q1, cc, Vector2(u1, 0), Vector2(u0, uv_v))
		if caps:
			if r1 > 0.0:
				tri(key, material, xf * Vector3(0, h, 0), xf * q1, xf * q0, col)
			if r0 > 0.0:
				tri(key, material, xf * Vector3(0, 0, 0), xf * p0, xf * p1, Color(col.r * 0.6, col.g * 0.6, col.b * 0.6))

## Low sphere (rings x segments), centred on xf origin.
func sphere(key: String, material: Material, r: float, rings: int, segs: int, xf: Transform3D, col: Color, squash := Vector3.ONE) -> void:
	for ri in range(rings):
		var t0 := PI * ri / rings
		var t1 := PI * (ri + 1) / rings
		for si in range(segs):
			var p0 := TAU * si / segs
			var p1 := TAU * (si + 1) / segs
			var a := _sp(r, t0, p0) * squash
			var b := _sp(r, t0, p1) * squash
			var c := _sp(r, t1, p1) * squash
			var d := _sp(r, t1, p0) * squash
			var tone := 0.7 + 0.3 * (1.0 - float(ri) / rings)
			var cc := Color(col.r * tone, col.g * tone, col.b * tone, col.a)
			var uv0 := Vector2(float(si) / segs, float(ri) / rings)
			var uv1 := Vector2(float(si + 1) / segs, float(ri + 1) / rings)
			if ri == 0:
				tri(key, material, xf * a, xf * c, xf * d, cc, uv0, uv1, Vector2(uv0.x, uv1.y))
			elif ri == rings - 1:
				tri(key, material, xf * a, xf * b, xf * c, cc, uv0, Vector2(uv1.x, uv0.y), uv1)
			else:
				tri(key, material, xf * a, xf * b, xf * c, cc, uv0, Vector2(uv1.x, uv0.y), uv1)
				tri(key, material, xf * a, xf * c, xf * d, cc, uv0, uv1, Vector2(uv0.x, uv1.y))

static func _sp(r: float, theta: float, phi: float) -> Vector3:
	return Vector3(sin(theta) * cos(phi) * r, cos(theta) * r, sin(theta) * sin(phi) * r)

## A ring of thin bars approximating a torus (the cage head is made of these).
func ring(key: String, material: Material, radius: float, thick: float, segs: int, xf: Transform3D, col: Color) -> void:
	for i in range(segs):
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var p0 := Vector3(cos(a0), 0, sin(a0)) * radius
		var p1 := Vector3(cos(a1), 0, sin(a1)) * radius
		var mid := (p0 + p1) * 0.5
		var length := p0.distance_to(p1) * 1.05
		var basis := Basis.looking_at((p1 - p0).normalized(), Vector3.UP)
		box(key, material, Vector3(thick, thick, length), xf * Transform3D(basis, mid), col)

func build() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for k in surfaces.keys():
		var st: SurfaceTool = surfaces[k]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats[k])
	return mesh

static func T(pos := Vector3.ZERO, rot := Vector3.ZERO, scale := Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(rot).scaled(scale)
	return Transform3D(b, pos)
