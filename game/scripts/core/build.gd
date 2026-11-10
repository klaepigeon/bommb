class_name Build
extends RefCounted
## Builds static geometry fast and cheap for phones: boxes with world-space UVs, batched into one
## mesh per material, with box collision. Front faces wind clockwise (Godot's convention).

var root: Node3D
var body: StaticBody3D
var _st := {}
var _mats := {}

func _init(parent: Node, name: String) -> void:
	root = Node3D.new()
	root.name = name
	parent.add_child(root)
	body = StaticBody3D.new()
	body.name = "Solid"
	root.add_child(body)

func material(key: String, m: Material) -> void:
	_mats[key] = m

const _AXES := [
	[Vector3.RIGHT, Vector3.UP, Vector3.BACK],
	[Vector3.LEFT, Vector3.BACK, Vector3.UP],
	[Vector3.UP, Vector3.BACK, Vector3.RIGHT],
	[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
	[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
	[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
]

## A box from mn to mx (in xf's space). solid adds collision. uv: texture repeats per metre.
## skip: faces to leave out, as normals (e.g. [Vector3.DOWN]).
func box(key: String, mn: Vector3, mx: Vector3, xf := Transform3D.IDENTITY, solid := true, uv := 1.0, skip: Array = []) -> void:
	var st: SurfaceTool = _st.get(key)
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[key] = st
	var c := (mn + mx) * 0.5
	var h := (mx - mn) * 0.5
	for ax in _AXES:
		var n: Vector3 = ax[0]
		if skip.has(n):
			continue
		var u: Vector3 = ax[1]
		var v: Vector3 = ax[2]
		var fc := c + n * h
		var hu := u * h
		var hv := v * h
		var pts := [fc - hu - hv, fc + hu - hv, fc + hu + hv, fc - hu + hv]
		var wn := (xf.basis * n).normalized()
		var idx := [0, 2, 1, 0, 3, 2]
		for i in idx:
			var p: Vector3 = pts[i]
			var uvp: Vector2
			if absf(n.x) > 0.5:
				uvp = Vector2(p.z, -p.y)
			elif absf(n.y) > 0.5:
				uvp = Vector2(p.x, p.z)
			else:
				uvp = Vector2(p.x, -p.y)
			var wp := xf * p
			# cheap baked occlusion: darker toward the floor and the ceiling
			var shade := lerpf(0.62, 1.0, clampf(wp.y / 0.6, 0.0, 1.0)) * lerpf(0.8, 1.0, clampf((2.7 - wp.y) / 0.4, 0.0, 1.0))
			if n.y < -0.5:
				shade = 0.85
			st.set_color(Color(shade, shade, shade))
			st.set_normal(wn)
			st.set_uv(uvp * uv)
			st.add_vertex(wp)
	if solid:
		collide(mn, mx, xf)

func collide(mn: Vector3, mx: Vector3, xf := Transform3D.IDENTITY) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = (mx - mn).abs().max(Vector3(0.02, 0.02, 0.02))
	cs.shape = bs
	cs.transform = xf * Transform3D(Basis(), (mn + mx) * 0.5)
	body.add_child(cs)

func finish() -> void:
	for key in _st:
		var st: SurfaceTool = _st[key]
		var mi := MeshInstance3D.new()
		mi.name = "Mesh_" + key
		mi.mesh = st.commit()
		mi.material_override = _mats.get(key)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	_st.clear()

## Appends any mesh (a primitive, say) under its own key. Don't mix with box() on the same key.
func mesh(key: String, m: Mesh, xf: Transform3D) -> void:
	var st: SurfaceTool = _st.get(key)
	if st == null:
		st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_st[key] = st
	st.append_from(m, 0, xf)

## Basis whose +Y points along dir, scaled (r, len, r).
static func along(dir: Vector3, r: float, length: float) -> Basis:
	var d := dir.normalized()
	if d.dot(Vector3.UP) < -0.999:
		d = (d + Vector3(0.001, 0, 0.001)).normalized()
	return Basis(Quaternion(Vector3.UP, d)).scaled_local(Vector3(r, length, r))
