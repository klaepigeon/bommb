class_name LcDice3D
extends Node3D
## A physical polyhedral die. The result is decided by the simulation; this node tumbles in
## the tray and comes to rest with exactly that face up, its number upright to the player.

const SHAPES := {}

var sides := 20
var faces: Array = []     # [{normal, u, v, center}]
var mesh_inst: MeshInstance3D
var rolling := false

static var _geo_cache: Dictionary = {}

static func polyhedron(n: int) -> Array:
	var phi := (1.0 + sqrt(5.0)) / 2.0
	var v: Array = []
	match n:
		4:
			v = [Vector3(1, 1, 1), Vector3(1, -1, -1), Vector3(-1, 1, -1), Vector3(-1, -1, 1)]
		6:
			for x in [-1, 1]:
				for y in [-1, 1]:
					for z in [-1, 1]:
						v.append(Vector3(x, y, z))
		8:
			v = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
		10:
			v = [Vector3(0, 1, 0), Vector3(0, -1, 0)]
			var hh := (1.0 - cos(PI / 5.0)) / (1.0 + cos(PI / 5.0))
			for i in range(10):
				var a := TAU * i / 10.0
				v.append(Vector3(cos(a), hh * (1 if i % 2 == 0 else -1), sin(a)))
		12:
			for x in [-1, 1]:
				for y in [-1, 1]:
					for z in [-1, 1]:
						v.append(Vector3(x, y, z))
			for a in [-1, 1]:
				for b in [-1, 1]:
					v.append(Vector3(0, a / phi, b * phi))
					v.append(Vector3(a / phi, b * phi, 0))
					v.append(Vector3(a * phi, 0, b / phi))
		_:
			for a in [-1, 1]:
				for b in [-1, 1]:
					v.append(Vector3(0, a, b * phi))
					v.append(Vector3(a, b * phi, 0))
					v.append(Vector3(a * phi, 0, b))
	var m := 0.0
	for p in v:
		m = max(m, p.length())
	return v.map(func(p): return p / m)

## Convex hull faces by brute force: fine for <= 20 vertices, cached per die type.
static func hull_faces(verts: Array) -> Array:
	var out: Array = []
	var seen_normals: Array = []
	var nv := verts.size()
	for i in range(nv):
		for j in range(i + 1, nv):
			for k in range(j + 1, nv):
				var a: Vector3 = verts[i]
				var n = (verts[j] - a).cross(verts[k] - a)
				if n.length() < 1e-6:
					continue
				n = n.normalized()
				var d = n.dot(a)
				var pos := false
				var neg := false
				for p in verts:
					var s: float = n.dot(p) - d
					if s > 1e-4: pos = true
					elif s < -1e-4: neg = true
				if pos and neg:
					continue
				if pos:
					n = -n
					d = -d
				var dup := false
				for sn in seen_normals:
					if sn.dot(n) > 0.9999:
						dup = true
						break
				if dup:
					continue
				seen_normals.append(n)
				var poly: Array = []
				for p in verts:
					if abs(n.dot(p) - d) < 1e-4:
						poly.append(p)
				var c := Vector3.ZERO
				for p in poly:
					c += p
				c /= poly.size()
				var u = (poly[0] - c).normalized()
				var w = n.cross(u)
				poly.sort_custom(func(p1, p2): return atan2((p1 - c).dot(w), (p1 - c).dot(u)) < atan2((p2 - c).dot(w), (p2 - c).dot(u)))
				out.append({"normal": n, "center": c, "poly": poly})
	# a stable, pleasant numbering: sort faces top-to-bottom, then around
	out.sort_custom(func(f1, f2):
		if abs(f1["normal"].y - f2["normal"].y) > 0.01:
			return f1["normal"].y > f2["normal"].y
		return atan2(f1["normal"].z, f1["normal"].x) < atan2(f2["normal"].z, f2["normal"].x))
	return out

static func build_mesh(n: int, body: Color, ink: Color, size: float, eye := Color(0, 0, 0, 0)) -> Array:
	var key := "%d%s%s%f%s" % [n, body.to_html(), ink.to_html(), size, eye.to_html()]
	if _geo_cache.has(key):
		return _geo_cache[key]
	var fcs := hull_faces(polyhedron(n))
	var cols := 5
	var rows := int(ceil(fcs.size() / float(cols)))
	var atlas := LcTex.die_atlas(fcs.size(), body, ink, "%d" % n)
	if n == 6 and eye.a > 0.0:
		atlas = LcTex.pip_atlas(body, ink, eye)
	var mat := LcMB.mat(atlas, Color.WHITE)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var face_info: Array = []
	for fi in range(fcs.size()):
		var f: Dictionary = fcs[fi]
		var nrm: Vector3 = f["normal"]
		var c: Vector3 = f["center"]
		var poly: Array = f["poly"]
		# face axes: v points toward the "top" of the printed number
		var ref := Vector3.UP if abs(nrm.y) < 0.9 else Vector3.FORWARD
		var v_ax := (ref - nrm * ref.dot(nrm)).normalized()
		var u_ax := v_ax.cross(nrm).normalized()
		v_ax = nrm.cross(u_ax).normalized()
		var rmax := 0.0
		for p in poly:
			rmax = max(rmax, (p - c).length())
		var cell_c := Vector2(((fi % cols) + 0.5) / cols, ((fi / cols) + 0.5) / rows)
		var half := Vector2(0.5 / cols, 0.5 / rows) * 0.98
		var uvs: Array = []
		for p in poly:
			var d: Vector3 = p - c
			uvs.append(cell_c + Vector2(d.dot(u_ax) / rmax * half.x, -d.dot(v_ax) / rmax * half.y))
		var cuv := cell_c
		for i in range(poly.size()):
			var a: Vector3 = poly[i] * size
			var b: Vector3 = poly[(i + 1) % poly.size()] * size
			for pr in [[c * size, cuv], [b, uvs[(i + 1) % poly.size()]], [a, uvs[i]]]:
				st.set_color(Color(1, 1, 1))
				st.set_normal(nrm)
				st.set_uv(pr[1])
				st.add_vertex(pr[0])
		face_info.append({"normal": nrm, "u": u_ax, "v": v_ax})
	var mesh := ArrayMesh.new()
	st.commit(mesh)
	mesh.surface_set_material(0, mat)
	var res := [mesh, face_info]
	_geo_cache[key] = res
	return res

func setup(n: int, body: Color = Color("e8dcc0"), ink: Color = Color("8a1a12"), size: float = 0.032) -> void:
	sides = n
	var r := build_mesh(n, body, ink, size)
	if mesh_inst == null:
		mesh_inst = MeshInstance3D.new()
		add_child(mesh_inst)
	mesh_inst.mesh = r[0]
	faces = r[1]

## Rotation that puts face `value` up with its number upright as seen from +Z (the player).
func rest_basis(value: int, yaw: float = 0.0) -> Basis:
	var f: Dictionary = faces[clampi(value - 1, 0, faces.size() - 1)]
	var bf := Basis(f["u"], f["normal"], f["v"])
	var bt := Basis(Vector3(1, 0, 0), Vector3.UP, Vector3(0, 0, -1))
	if sides == 4:
		# a d4 leans on an edge with its result tilted toward the player, so it can be read
		bt = Basis(Vector3(1, 0, 0), Vector3(0, 0.6, 0.8), Vector3(0, 0.8, -0.6))
	return Basis(Vector3.UP, yaw) * bt * bf.inverse()

## Tumble from `from` to `to` (local to parent) and land on `value`. Returns the tween.
func roll_to(value: int, from: Vector3, to: Vector3, duration: float = 0.9) -> Tween:
	rolling = true
	position = from
	var spin := Vector3(randf_range(8, 14), randf_range(6, 12), randf_range(5, 10))
	var start_b := Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU))
	var end_b := rest_basis(value, randf_range(-0.35, 0.35))
	var tw := create_tween()
	var bounce_h := 0.12
	tw.tween_method(func(k: float):
		var p := from.lerp(to, 1.0 - pow(1.0 - k, 2.0))
		var hop = abs(sin(k * PI * 2.5)) * bounce_h * (1.0 - k)
		position = p + Vector3(0, hop, 0)
		var tumble := Basis.from_euler(spin * (1.0 - k) * (1.0 - k) * 1.0)
		var q := Quaternion(start_b * tumble).slerp(Quaternion(end_b), clampf((k - 0.55) / 0.45, 0.0, 1.0))
		basis = Basis(q.normalized()) if k < 0.999 else end_b, 0.0, 1.0, duration)
	tw.tween_callback(func():
		basis = end_b
		position = to
		rolling = false)
	return tw

## The face currently pointing up (for tests: must equal the rolled value at rest).
func face_up() -> int:
	var best := 1
	var bd := -2.0
	for i in range(faces.size()):
		var n: Vector3 = (global_transform.basis * faces[i]["normal"]).normalized()
		if n.y > bd:
			bd = n.y
			best = i + 1
	return best
