class_name Build
## Geometry for levels: boxes with world-scaled UVs (a texture covers the same area on every
## face, so nothing stretches), walls with door and window openings cut out, and a static body
## for whatever should be solid.

## A box mesh `size` centred on the origin, UVs in metres (the material's density scales them).
static func box_mesh(size: Vector3, y_world := 0.0) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := size * 0.5
	# each face: normal, its two in-plane axes (u right, v down) for UVs
	# [normal, u]; v = n x u (so the triangles wind the way Godot's front faces do)
	var faces := [[Vector3.RIGHT, Vector3.FORWARD], [Vector3.LEFT, Vector3.BACK], [Vector3.UP, Vector3.RIGHT],
		[Vector3.DOWN, Vector3.RIGHT], [Vector3.BACK, Vector3.RIGHT], [Vector3.FORWARD, Vector3.LEFT]]
	for f in faces:
		var n: Vector3 = f[0]; var u: Vector3 = f[1]; var v: Vector3 = n.cross(u)
		var c := n * h
		var hu := absf(u.dot(h)); var hv := absf(v.dot(h))
		var corners := [c - u * hu - v * hv, c + u * hu - v * hv, c + u * hu + v * hv, c - u * hu + v * hv]
		var uvs := []
		for p in corners:
			# vertical faces: v runs from the top down in metres, so wallpaper's floor end is at the
			# bottom of the wall; floors use world x/z
			uvs.append(Vector2(p.dot(u), 0.999 - (p.y + y_world) if absf(n.y) < 0.5 else p.dot(v)))
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n); st.set_uv(uvs[idx]); st.add_vertex(corners[idx])
	return st.commit()

## A solid box in the level. Returns the MeshInstance3D (its StaticBody3D is a child).
static func box(parent: Node, pos: Vector3, size: Vector3, material: Material, solid := true, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh(size, pos.y)
	mi.material_override = material
	mi.position = pos; mi.rotation.y = rot_y
	parent.add_child(mi)
	if solid:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size
		cs.shape = sh; sb.add_child(cs); mi.add_child(sb)
	return mi

## A wall from a to b (x,z on the floor), `h` tall, `t` thick, with openings: each
## {"at": metres from a to the opening's centre, "w": width, "bottom": sill height, "top": head
## height}. Fills above and below every opening.
static func wall(parent: Node, a: Vector2, b: Vector2, mat: Material, openings := [], h := 2.7, t := 0.12, y0 := 0.0) -> void:
	var dir := (b - a); var L := dir.length(); dir /= L
	var rot := -atan2(dir.y, dir.x)
	var cuts := openings.duplicate(); cuts.sort_custom(func(p, q): return p.at < q.at)
	var s := 0.0
	var seg := func(s0: float, s1: float, yb: float, yt: float):
		if s1 - s0 < 0.01 or yt - yb < 0.01: return
		var mid: Vector2 = a + dir * (s0 + s1) * 0.5
		box(parent, Vector3(mid.x, y0 + (yb + yt) * 0.5, mid.y), Vector3(s1 - s0, yt - yb, t), mat, true, rot)
	for o in cuts:
		var o0: float = o.at - o.w * 0.5; var o1: float = o.at + o.w * 0.5
		seg.call(s, o0, 0.0, h)
		seg.call(o0, o1, 0.0, o.get("bottom", 0.0))
		seg.call(o0, o1, o.get("top", 2.05), h)
		s = o1
	seg.call(s, L, 0.0, h)

## Floor and ceiling over a rectangle.
static func room(parent: Node, x0: float, z0: float, x1: float, z1: float, floor_mat: Material, ceil_mat: Material, h := 2.7, y0 := 0.0) -> void:
	box(parent, Vector3((x0 + x1) * 0.5, y0 - 0.05, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.1, z1 - z0), floor_mat)
	if ceil_mat:
		box(parent, Vector3((x0 + x1) * 0.5, y0 + h + 0.05, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.1, z1 - z0), ceil_mat)

## A mesh from a SurfaceTool-drawing callable (MeshKit blobs, coral), with normals generated.
static func organic(parent: Node, draw: Callable, material: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	draw.call(st)
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi

## A light that doesn't cost much on a phone: no shadow, limited range.
static func lamp(parent: Node, pos: Vector3, color: Color, energy: float, range_m: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos; l.light_color = color; l.light_energy = energy; l.omni_range = range_m
	l.omni_attenuation = 1.2; l.shadow_enabled = false
	parent.add_child(l)
	return l
