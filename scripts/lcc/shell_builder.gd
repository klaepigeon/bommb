class_name ShellBuilder
extends RefCounted
## Floors, walls and ceilings for the building's areas, with real holes where the doors and
## windows are, so a door in the hall wall is the same hole as the door in the kitchen wall.

## Walls of an area into mb. Each wall is cut around the openings that Building finds in it.
static func walls(mb: MB, b: Building, area_id: String, wall_m: Material, height: float, shade := [0.9, 0.8, 0.75, 0.8], bottom := 0.0) -> void:
	var a: Dictionary = b.areas[area_id]
	var r: Rect2 = a["rect"]
	var fl: float = a["floor"]
	for e in range(4):
		var seg := Building.edge_segment(r, e)
		var p0: Vector2 = seg[0]
		var p1: Vector2 = seg[1]
		var length := p0.distance_to(p1)
		var dir := (p1 - p0) / length
		var c := Color(1, 1, 1) * float(shade[e])
		c.a = 1.0
		# a room's wall that shares a line with its neighbour's would fight it for the same
		# pixels (both are double-sided): pull every room's walls in a hair; the hall's stay put
		if area_id != "hall":
			var n := Vector2(-dir.y, dir.x)
			if (r.get_center() - p0).dot(n) < 0.0:
				n = -n
			p0 += n * 0.025
		var t := 0.0
		for o in b.openings(area_id, e):
			var o0: float = o["t"] - o["width"] / 2.0
			var o1: float = o["t"] + o["width"] / 2.0
			_piece(mb, wall_m, p0, dir, t, o0, fl + bottom, fl + height, c)
			# below a window, above any opening
			if o["bottom"] > bottom + 0.01:
				_piece(mb, wall_m, p0, dir, o0, o1, fl + bottom, fl + o["bottom"], c)
			if o["top"] < height:
				_piece(mb, wall_m, p0, dir, o0, o1, fl + o["top"], fl + height, c)
			t = o1
		_piece(mb, wall_m, p0, dir, t, length, fl + bottom, fl + height, c)

## One rectangle of wall from t0 to t1 along an edge, facing into the area (edges run so the
## inside is on the left).
static func _piece(mb: MB, m: Material, p0: Vector2, dir: Vector2, t0: float, t1: float, y0: float, y1: float, c: Color) -> void:
	if t1 - t0 < 0.005 or y1 - y0 < 0.005:
		return
	var a := p0 + dir * t0
	var b := p0 + dir * t1
	# uv: one texture repeat per 2 m, measured along the wall so pieces line up
	var u0 := t0 / 2.0
	var u1 := t1 / 2.0
	var v0 := y0 / 2.6
	var v1 := y1 / 2.6
	mb.quad_uv("w", m, Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y), c,
		Vector2(u0, 1.0 - v0), Vector2(u1, 1.0 - v0), Vector2(u1, 1.0 - v1), Vector2(u0, 1.0 - v1))

static func floor_and_ceiling(mb: MB, r: Rect2, y: float, height: float, floor_m: Material, ceil_m: Material, uv_per := 2.0) -> void:
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y
	var z1 := r.end.y
	mb.quad_uv("f", floor_m, Vector3(x0, y, z1), Vector3(x1, y, z1), Vector3(x1, y, z0), Vector3(x0, y, z0), Color(1, 1, 1),
		Vector2(x0, z1) / uv_per, Vector2(x1, z1) / uv_per, Vector2(x1, z0) / uv_per, Vector2(x0, z0) / uv_per)
	if ceil_m != null:
		var h := y + height
		mb.quad_uv("c", ceil_m, Vector3(x0, h, z0), Vector3(x1, h, z0), Vector3(x1, h, z1), Vector3(x0, h, z1), Color(0.7, 0.7, 0.7),
			Vector2(x0, z0) / 1.5, Vector2(x1, z0) / 1.5, Vector2(x1, z1) / 1.5, Vector2(x0, z1) / 1.5)

## A door frame (both faces of the wall) around a portal: posts and a lintel, a threshold.
static func frame(mb: MB, p: Dictionary, frame_m: Material, floor_y: float) -> void:
	var at: Vector2 = p["at"]
	var w: float = p["width"]
	var h: float = p["height"]
	var along := Vector3(0, 0, 1) if p["axis"] == "x" else Vector3(1, 0, 0)
	var across := Vector3(1, 0, 0) if p["axis"] == "x" else Vector3(0, 0, 1)
	var base := Vector3(at.x, floor_y, at.y)
	var basis := Basis(along, Vector3.UP, across)
	var thick := 0.22
	mb.box("fr", frame_m, Vector3(0.1, h + 0.1, thick), Transform3D(basis, base + along * (w / 2 + 0.05) + Vector3(0, (h + 0.1) / 2, 0)), Color(1, 1, 1))
	mb.box("fr", frame_m, Vector3(0.1, h + 0.1, thick), Transform3D(basis, base - along * (w / 2 + 0.05) + Vector3(0, (h + 0.1) / 2, 0)), Color(1, 1, 1))
	mb.box("fr", frame_m, Vector3(w + 0.2, 0.1, thick), Transform3D(basis, base + Vector3(0, h + 0.05, 0)), Color(0.9, 0.9, 0.9))
	# the reveal: the inside faces of the hole, so the wall reads as thick
	var rev := MB.mat(Tex.grime(Color("2a2420"), Color("3a3028"), 16, 71, 0.2))
	mb.box("rv", rev, Vector3(w, 0.02, thick - 0.02), Transform3D(basis, base + Vector3(0, 0.01, 0)), Color(0.8, 0.8, 0.8))

## Cut a mesh's triangles into separate meshes by where they sit (cells of the given size),
## so lamps light only the pieces near them.
static func split(mesh: ArrayMesh, cell: float) -> Array:
	var buckets := {}
	for si in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(si)
		var mat := mesh.surface_get_material(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var col: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		var idx = arr[Mesh.ARRAY_INDEX]
		var count: int = idx.size() if idx != null else v.size()
		for t in range(0, count, 3):
			var ia: int = idx[t] if idx != null else t
			var ib: int = idx[t + 1] if idx != null else t + 1
			var ic: int = idx[t + 2] if idx != null else t + 2
			var c: Vector3 = (v[ia] + v[ib] + v[ic]) / 3.0
			var key := "%d,%d,%d|%d" % [int(floor(c.x / cell)), int(floor(c.z / cell)), si, 0]
			if not buckets.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				buckets[key] = [st, mat]
			var stb: SurfaceTool = buckets[key][0]
			for k in [ia, ib, ic]:
				if col.size() > k:
					stb.set_color(col[k])
				stb.set_normal(n[k])
				stb.set_uv(uv[k])
				stb.add_vertex(v[k])
	var out: Array = []
	for key in buckets.keys():
		var m := ArrayMesh.new()
		buckets[key][0].commit(m)
		m.surface_set_material(0, buckets[key][1])
		out.append(m)
	return out

## Break up any mesh under `root` (not its descendants' descendants) that spans more than
## `cell` metres. The renderer only lights each object with a limited number of lights, so
## one huge mesh (every chair in the hall, say) loses some of them, and which ones changes
## as you walk: the whole lot flickers. Small pieces each see only the lights near them.
static func split_big(root: Node3D, cell: float) -> void:
	for c in root.get_children():
		if not (c is MeshInstance3D) or not (c.mesh is ArrayMesh) or c.get_child_count() > 0:
			continue
		var ab: AABB = c.mesh.get_aabb()
		if maxf(ab.size.x, ab.size.z) <= cell * 1.25:
			continue
		var pieces := split(c.mesh, cell)
		if pieces.size() < 2:
			continue
		for pm in pieces:
			var mi := MeshInstance3D.new()
			mi.mesh = pm
			mi.transform = c.transform
			mi.layers = c.layers
			mi.cast_shadow = c.cast_shadow
			mi.material_override = c.material_override
			root.add_child(mi)
		root.remove_child(c)
		c.queue_free()
