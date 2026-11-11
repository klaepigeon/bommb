class_name Kit
extends RefCounted
## Builds static geometry in buckets (one mesh per material) with UVs in metres, so a texture
## tiles at the same size everywhere. commit() adds the meshes under a node.

var _st := {}           ## mat key -> SurfaceTool
var _mats := {}         ## mat key -> Material
var uv_per_m := 1.0

func _bucket(mat: Material) -> SurfaceTool:
	var k := mat.get_instance_id()
	if not _st.has(k):
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[k] = st; _mats[k] = mat
	return _st[k]

## A quad a-b-c-d (counter-clockwise seen from the front), UVs from world metres along its edges.
func quad(mat: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col := Color.WHITE, uvk := 1.0) -> void:
	var st := _bucket(mat)
	var n := (b - a).cross(d - a).normalized()
	var an := n.abs()
	# both sides, each with its own normal: nothing built here can go missing to a winding or a driver
	for side in [1.0, -1.0]:
		var order := [a, c, b, a, d, c] if side > 0.0 else [a, b, c, a, c, d]
		for p in order:
			st.set_normal(n * side); st.set_color(col)
			var uvv: Vector2
			if an.y > an.x and an.y > an.z: uvv = Vector2(p.x, p.z)
			elif an.x > an.z: uvv = Vector2(p.z, -p.y)
			else: uvv = Vector2(p.x, -p.y)
			st.set_uv(uvv * uvk * uv_per_m)
			st.add_vertex(p)

## An axis-aligned box (all six faces, or `faces` mask: 1 +x, 2 -x, 4 +y, 8 -y, 16 +z, 32 -z).
func box(mat: Material, center: Vector3, size: Vector3, xf := Basis(), faces := 63, col := Color.WHITE) -> void:
	var h := size * 0.5
	var P := func(x, y, z): return center + xf * Vector3(x * h.x, y * h.y, z * h.z)
	if faces & 1: quad(mat, P.call(1, -1, 1), P.call(1, -1, -1), P.call(1, 1, -1), P.call(1, 1, 1), col)
	if faces & 2: quad(mat, P.call(-1, -1, -1), P.call(-1, -1, 1), P.call(-1, 1, 1), P.call(-1, 1, -1), col)
	if faces & 4: quad(mat, P.call(-1, 1, 1), P.call(1, 1, 1), P.call(1, 1, -1), P.call(-1, 1, -1), col)
	if faces & 8: quad(mat, P.call(-1, -1, -1), P.call(1, -1, -1), P.call(1, -1, 1), P.call(-1, -1, 1), col)
	if faces & 16: quad(mat, P.call(-1, -1, 1), P.call(1, -1, 1), P.call(1, 1, 1), P.call(-1, 1, 1), col)
	if faces & 32: quad(mat, P.call(1, -1, -1), P.call(-1, -1, -1), P.call(-1, 1, -1), P.call(1, 1, -1), col)

## A lumpy blob (coral, a body part): a squashed icosphere with noise.
func blob(mat: Material, center: Vector3, radius: Vector3, rng: RandomNumberGenerator, rough := 0.3, col := Color.WHITE) -> void:
	var st := _bucket(mat)
	var sm := SphereMesh.new(); sm.radius = 1.0; sm.height = 2.0; sm.radial_segments = 7; sm.rings = 4
	var arr := sm.get_mesh_arrays()
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var jitter := {}
	for i in idx.size():
		var p: Vector3 = vs[idx[i]]
		var k := p.snapped(Vector3.ONE * 0.01)
		if not jitter.has(k): jitter[k] = 1.0 + rng.randf_range(-rough, rough)
		var q := p * radius * float(jitter[k])
		st.set_normal(p.normalized()); st.set_color(col); st.set_uv(Vector2(p.x + p.y, p.z + p.y))
		st.add_vertex(center + q)

func commit(parent: Node, name := "Kit") -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for k in _st:
		var st: SurfaceTool = _st[k]
		var mi := MeshInstance3D.new(); mi.name = name
		mi.mesh = st.commit()
		mi.material_override = _mats[k]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		out.append(mi)
	_st.clear(); _mats.clear()
	return out
