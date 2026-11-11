class_name MB
extends RefCounted
## Mesh builder. Collects triangles per material key, then commits one ArrayMesh with a surface
## per material and vertex colours baked from a light function (the room's fixtures).
## Winding is fixed automatically from the given normal (Godot's front faces are clockwise).
## UVs are world-scaled: `uvm` metres per texture repeat.

var _s := {}        # mat key -> {v: PackedVector3Array, n: PackedVector3Array, uv: PackedVector2Array}
var xf := Transform3D.IDENTITY   ## applied to everything added (so pieces can be placed)

func _surf(mat: String) -> Dictionary:
	if not _s.has(mat):
		_s[mat] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array()}
	return _s[mat]

func is_empty() -> bool:
	return _s.is_empty()

func tri(mat: String, a: Vector3, b: Vector3, c: Vector3, n: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	a = xf * a; b = xf * b; c = xf * c
	n = (xf.basis * n).normalized()
	var s := _surf(mat)
	if (b - a).cross(c - a).dot(n) > 0.0:     # counter-clockwise from the front: flip
		var t := b; b = c; c = t
		var tu := ub; ub = uc; uc = tu
	s.v.append(a); s.v.append(b); s.v.append(c)
	s.n.append(n); s.n.append(n); s.n.append(n)
	s.uv.append(ua); s.uv.append(ub); s.uv.append(uc)

func quad(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, ua := Vector2(0, 1), ub := Vector2(1, 1), uc := Vector2(1, 0), ud := Vector2(0, 0)) -> void:
	tri(mat, a, b, c, n, ua, ub, uc)
	tri(mat, a, c, d, n, ua, uc, ud)

## A planar rectangle: origin o, edge vectors u (along) and v (up), subdivided into cells of at
## most `step` metres (so baked light has vertices to vary across). uvm: metres per texture tile.
## uv_off shifts the texture (walls keep their pattern continuous along a room).
func plane(mat: String, o: Vector3, u: Vector3, v: Vector3, n: Vector3, uvm := 1.0, step := 0.6, uv_off := Vector2.ZERO) -> void:
	var lu := u.length(); var lv := v.length()
	if lu < 0.001 or lv < 0.001:
		return
	var nu := maxi(1, ceili(lu / step)); var nv := maxi(1, ceili(lv / step))
	for i in nu:
		for j in nv:
			var u0 := float(i) / nu; var u1 := float(i + 1) / nu
			var v0 := float(j) / nv; var v1 := float(j + 1) / nv
			var p00 := o + u * u0 + v * v0; var p10 := o + u * u1 + v * v0
			var p11 := o + u * u1 + v * v1; var p01 := o + u * u0 + v * v1
			var t00 := Vector2(u0 * lu, -v0 * lv) / uvm + uv_off; var t10 := Vector2(u1 * lu, -v0 * lv) / uvm + uv_off
			var t11 := Vector2(u1 * lu, -v1 * lv) / uvm + uv_off; var t01 := Vector2(u0 * lu, -v1 * lv) / uvm + uv_off
			quad(mat, p00, p10, p11, p01, n, t00, t10, t11, t01)

## An oriented box: centre c, half-extents h, rotation b. faces: bitmask -X +X -Y +Y -Z +Z (1..32)
func box(mat: String, c: Vector3, h: Vector3, b := Basis.IDENTITY, uvm := 0.5, faces := 63, step := 10.0) -> void:
	for ax in 3:
		for sgi in 2:
			if not (faces & (1 << (ax * 2 + sgi))):
				continue
			var sg := -1.0 if sgi == 0 else 1.0
			var n := Vector3.ZERO; n[ax] = sg
			var ua := (ax + 1) % 3; var va := (ax + 2) % 3
			if ax == 1:
				ua = 0; va = 2
			var u := Vector3.ZERO; u[ua] = h[ua] * 2.0
			var v := Vector3.ZERO; v[va] = h[va] * 2.0
			if ax != 1:
				# keep "up" as the texture's v on vertical faces
				u = Vector3.ZERO; v = Vector3.ZERO
				var horiz := 2 if ax == 0 else 0
				u[horiz] = h[horiz] * 2.0
				v[1] = h[1] * 2.0
			var o := c + b * (n * h[ax] - u * 0.5 - v * 0.5)
			plane(mat, o, b * u, b * v, b * n, uvm, step)

## A cylinder along +Y from base, radius r (r_top for a cone), `sides` facets
func cyl(mat: String, base: Vector3, r: float, h: float, sides := 8, r_top := -1.0, caps := true, uvm := 0.5) -> void:
	if r_top < 0.0:
		r_top = r
	var circ := TAU * r
	for i in sides:
		var a0 := TAU * i / sides; var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0)); var d1 := Vector3(cos(a1), 0, sin(a1))
		var n := ((d0 + d1) * 0.5).normalized()
		var u0 := float(i) / sides * circ / uvm; var u1 := float(i + 1) / sides * circ / uvm
		quad(mat, base + d0 * r, base + d1 * r, base + d1 * r_top + Vector3(0, h, 0), base + d0 * r_top + Vector3(0, h, 0), n,
			Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, -h / uvm), Vector2(u0, -h / uvm))
		if caps:
			tri(mat, base + Vector3(0, h, 0), base + d0 * r_top + Vector3(0, h, 0), base + d1 * r_top + Vector3(0, h, 0), Vector3.UP,
				Vector2(0.5, 0.5), Vector2(0.5 + d0.x * 0.5, 0.5 + d0.z * 0.5), Vector2(0.5 + d1.x * 0.5, 0.5 + d1.z * 0.5))
			tri(mat, base, base + d1 * r, base + d0 * r, Vector3.DOWN,
				Vector2(0.5, 0.5), Vector2(0.5 + d1.x * 0.5, 0.5 + d1.z * 0.5), Vector2(0.5 + d0.x * 0.5, 0.5 + d0.z * 0.5))

## Build the mesh. light: Callable(world_pos: Vector3, normal: Vector3) -> Color, or null (white).
## to_world: transform from this builder's space to world, for light sampling.
func commit(mats: Dictionary, light = null, to_world := Transform3D.IDENTITY) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for key in _s:
		var s: Dictionary = _s[key]
		if s.v.is_empty():
			continue
		var cols := PackedColorArray(); cols.resize(s.v.size())
		var cache := {}
		for i in s.v.size():
			if light is Callable:
				var wp: Vector3 = to_world * s.v[i]
				var kk := Vector3i((wp * 50.0).round())    # shared corners: sample once
				var ck := [kk, Vector3i((s.n[i] * 10.0).round())]
				if not cache.has(ck):
					cache[ck] = light.call(wp, (to_world.basis * s.n[i]).normalized())
				cols[i] = cache[ck]
			else:
				cols[i] = Color.WHITE
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = s.v
		arr[Mesh.ARRAY_NORMAL] = s.n
		arr[Mesh.ARRAY_TEX_UV] = s.uv
		arr[Mesh.ARRAY_COLOR] = cols
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var m = mats.get(key)
		if m:
			mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	return mesh
