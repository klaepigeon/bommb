class_name InfectedBody
extends Node3D
## An infected person's body, built from their genome (InfectedGenome): a real skeleton (hips,
## spine, chest, neck, head, jaw, and a chain of bones for every limb they have, extras included,
## two or three joints each) and one skinned mesh over it: skin, clothes and growth as separate
## surfaces on the same skeleton, every vertex weighted to the bones near it (blended across the
## joints), so it bends where a body bends. Growths ride the bone they grew from. Missing limbs
## leave a scar; stumps end in a cut; a limb shot off collapses into its joint and falls away.
##
## Animated procedurally from what they have (animate()): the gait comes from their locomotion
## (walk, limp, skitter, hop, lurch on an arm, crawl, drag), plus the habit they kept (rocking,
## knocking, counting, searching, folding, standing still), twitches, the head turning to what it
## wants, reaching to grab, flinching, and the collapse when they die.
##
## Rig space: origin on the floor under them, +Y up, they face -Z. `s` scales a 1.75 m body.

const PS1 := preload("res://shaders/ps1_lit.gdshader")

var genome: Dictionary
var s := 1.0
var skel: Skeleton3D
var mesh_inst: MeshInstance3D
var bones := {}               # name -> index
var limb_bones := {}          # limb id -> [bone indices from the root of the limb out]
var limb_len := {}            # limb id -> [segment lengths]
var anchor_bone := {}         # limb id -> the body bone it grows from
var hit_parts: Array = []     # {bone, a, b (rest, rig space), r, part: "head" | "torso" | limb id}
var severed := {}             # limb id -> true
var _mats := {}
var _rng := RandomNumberGenerator.new()

# animation state
var _phase := 0.0
var _t := 0.0
var _twitch := {}             # bone -> [offset Vector3, velocity Vector3]
var _flinch := Vector3.ZERO; var _flinch_v := Vector3.ZERO
var dead_k := 0.0             # 0 alive .. 1 collapsed
var locomotion := "walk"

func build(g: Dictionary) -> void:
	genome = g.duplicate(true)
	s = float(genome.height) / 1.75
	_rng.seed = int(genome.seed) * 7 + 3
	locomotion = genome.locomotion
	_skeleton()
	_mesh()

func mat(tex: String, rough := 0.85, spec := 0.4, tint := 1.0) -> ShaderMaterial:
	var key := "%s/%s/%s/%s" % [tex, rough, spec, tint]
	if _mats.has(key): return _mats[key]
	var m := ShaderMaterial.new(); m.shader = PS1
	m.set_shader_parameter("albedo_tex", InfectedTextures.get_tex(tex))
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("specular", spec)
	m.set_shader_parameter("albedo_color", Color(tint, tint, tint))
	_mats[key] = m
	return m

# ================================================================ skeleton
func _add_bone(name: String, parent: String, at: Vector3) -> int:
	var i := skel.get_bone_count()
	skel.add_bone(name)
	var parent_at := Vector3.ZERO
	if parent != "":
		skel.set_bone_parent(i, bones[parent])
		parent_at = skel.get_bone_global_rest(bones[parent]).origin
	skel.set_bone_rest(i, Transform3D(Basis(), at - parent_at))
	skel.set_bone_pose(i, Transform3D(Basis(), at - parent_at))
	bones[name] = i
	return i

func rest_pos(b: int) -> Vector3:
	return skel.get_bone_global_rest(b).origin

func _bw() -> float:
	return 1.0 + float(genome.build) * 0.4

func _skeleton() -> void:
	skel = Skeleton3D.new(); skel.name = "Skeleton"
	add_child(skel)
	_add_bone("hips", "", Vector3(0, 0.93 * s, 0))
	_add_bone("spine", "hips", Vector3(0, 1.08 * s, 0.005))
	_add_bone("chest", "spine", Vector3(0, 1.26 * s, 0.01))
	_add_bone("neck", "chest", Vector3(0, 1.45 * s, 0.0))
	_add_bone("head", "neck", Vector3(0, 1.53 * s, -0.005))
	_add_bone("jaw", "head", Vector3(0, 1.585 * s, -0.005))
	var bw := _bw()
	for l in genome.limbs:
		var side := float(l.side)
		var anchor := ""; var at := Vector3.ZERO
		match String(l.anchor):
			"shoulder": anchor = "chest"; at = Vector3(side * 0.19 * s * bw, 1.40 * s, 0.0)
			"back": anchor = "chest"; at = Vector3(side * 0.1 * s, (1.3 + float(l.pos) * 0.08) * s, 0.12 * s * bw)
			"ribs": anchor = "spine"; at = Vector3(side * 0.16 * s * bw, (1.14 + float(l.pos) * 0.1) * s, -0.02 * s)
			"hip": anchor = "hips"; at = Vector3(side * 0.1 * s * bw, 0.9 * s, 0.0)
			"belly": anchor = "spine"; at = Vector3(side * 0.07 * s, 1.0 * s, -0.12 * s * bw)
		anchor_bone[l.id] = bones[anchor]
		var lens: Array
		var k := float(l.length)
		if l.kind == "arm": lens = [0.3, 0.27, 0.17]
		else: lens = [0.44, 0.43]
		if int(l.joints) == 3: lens = [lens[0] * 0.6, lens[0] * 0.55, lens[1]] + (lens.slice(2) if lens.size() > 2 else [])
		if l.state == "stump": lens = [float(lens[0]) * k * s]
		elif l.state == "missing": lens = []
		else: lens = lens.map(func(x): return x * k * s)
		var chain := []
		var dir: Vector3 = l.out
		var p := at
		var prev := anchor
		# the limb's root: at the anchor, then each segment along `out` (legs end in a foot pointing forward)
		var root := _add_bone(l.id + "_0", prev, p)
		chain.append(root); prev = l.id + "_0"
		for i in lens.size():
			p += dir * float(lens[i])
			var b := _add_bone("%s_%d" % [l.id, i + 1], prev, p)
			chain.append(b); prev = "%s_%d" % [l.id, i + 1]
		if l.kind == "leg" and l.state in ["whole", "short", "long", "fused"]:
			var foot := _add_bone(l.id + "_foot", prev, p + Vector3(0, 0, -0.17 * s))
			chain.append(foot)
		limb_bones[l.id] = chain
		limb_len[l.id] = lens

# ================================================================ mesh
class SkinB:
	var v := PackedVector3Array(); var uv := PackedVector2Array(); var bones := PackedInt32Array()
	var wts := PackedFloat32Array(); var idx := PackedInt32Array(); var out := []
	func add(p: Vector3, t: Vector2, w: Dictionary, outward: Vector3) -> int:
		var pairs := []
		for k in w:
			if w[k] > 0.001: pairs.append([w[k], k])
		pairs.sort_custom(func(a, b): return a[0] > b[0])
		pairs = pairs.slice(0, 4)
		var sum := 0.0
		for pr in pairs: sum += pr[0]
		for i in 4:
			if i < pairs.size(): bones.append(pairs[i][1]); wts.append(pairs[i][0] / sum)
			else: bones.append(0); wts.append(0.0)
		v.append(p); uv.append(t); out.append(outward)
		return v.size() - 1
	func tri(a: int, b: int, c: int) -> void:
		var n := (v[b] - v[a]).cross(v[c] - v[a])
		if n.length_squared() < 1e-14: return
		if n.dot(out[a] + out[b] + out[c]) > 0.0: idx.append_array([a, c, b])
		else: idx.append_array([a, b, c])
	func quad(a: int, b: int, c: int, d: int) -> void:
		tri(a, b, c); tri(a, c, d)
	func commit(mesh: ArrayMesh, m: Material) -> void:
		if idx.is_empty(): return
		var nrm := PackedVector3Array(); nrm.resize(v.size())
		for i in range(0, idx.size(), 3):
			var a := idx[i]; var b := idx[i + 1]; var c := idx[i + 2]
			var n := (v[c] - v[a]).cross(v[b] - v[a])
			nrm[a] += n; nrm[b] += n; nrm[c] += n
		for i in v.size(): nrm[i] = nrm[i].normalized() if nrm[i].length_squared() > 0.0 else (out[i] as Vector3).normalized()
		var arr := []; arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_NORMAL] = nrm; arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_BONES] = bones; arr[Mesh.ARRAY_WEIGHTS] = wts; arr[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)

var _skins := {}              # material key -> Skin
var _skin_mat := {}
func _sk(tex: String, rough := 0.85, spec := 0.4) -> SkinB:
	var key := "%s/%s/%s" % [tex, rough, spec]
	if not _skins.has(key):
		_skins[key] = SkinB.new(); _skin_mat[key] = mat(tex, rough, spec)
	return _skins[key]

## A frame around a direction (for the rings of a tube).
static func _frame(d: Vector3) -> Array:
	var up := Vector3.FORWARD if absf(d.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := up.cross(d).normalized(); var y := d.cross(x).normalized()
	return [x, y]

## A tube through points p[0..n], radius r[i] at each, segment i weighted to bones b[i] blending
## into b[i-1] near its start and b[i+1] near its end (joints bend smoothly). `lump` roughens it.
func _tube(sk: SkinB, p: Array, r: Array, b: Array, prev_bone: int, sides := 8, rings := 4, lump := 0.15, cap_start := false, cap_end := false, cap_sk: SkinB = null) -> void:
	var grid := []
	var n := p.size() - 1
	var noise := MeshKit.noise()
	for i in n:
		var a: Vector3 = p[i]; var c: Vector3 = p[i + 1]
		var d := (c - a).normalized()
		var fr := _frame(d)
		for k in rings + (1 if i == n - 1 else 0):
			var t := float(k) / rings
			var c0 := a.lerp(c, t)
			var rad := lerpf(float(r[i]), float(r[i + 1]), t)
			var w := {}
			var mine: int = b[i]
			var before: int = b[i - 1] if i > 0 else prev_bone
			var after: int = b[i + 1] if i + 1 < b.size() else mine
			var wb := 0.5 * (1.0 - smoothstep(0.0, 0.3, t)) if before >= 0 else 0.0
			var wa := 0.5 * smoothstep(0.7, 1.0, t) if after != mine else 0.0
			w[mine] = 1.0 - wb - wa
			if before >= 0: w[before] = w.get(before, 0.0) + wb
			if wa > 0.0: w[after] = w.get(after, 0.0) + wa
			var ring := []
			for j in sides + 1:
				var th := TAU * float(j) / sides
				var o: Vector3 = fr[0] * cos(th) + fr[1] * sin(th)
				var q := c0 + o * rad * (1.0 + lump * noise.get_noise_3d(c0.x * 40.0 + th, c0.y * 40.0, c0.z * 40.0))
				ring.append(sk.add(q, Vector2(float(j) / sides, (i + t) * 0.5), w, o))
			grid.append(ring)
	for i in grid.size() - 1:
		for j in sides:
			sk.quad(grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j])
	var cs := cap_sk if cap_sk else sk
	if cap_end: _cap(cs, p[n], (p[n] - p[n - 1]).normalized(), float(r[n]), b[n - 1] if n - 1 < b.size() else b.back(), sides)
	if cap_start: _cap(cs, p[0], (p[0] - p[1]).normalized(), float(r[0]), b[0], sides)

func _cap(sk: SkinB, c: Vector3, d: Vector3, rad: float, bone: int, sides: int) -> void:
	var fr := _frame(d)
	var w := {bone: 1.0}
	var mid := sk.add(c + d * rad * 0.25, Vector2(0.5, 0.5), w, d)
	var ring := []
	for j in sides + 1:
		var th := TAU * float(j) / sides
		var o: Vector3 = fr[0] * cos(th) + fr[1] * sin(th)
		ring.append(sk.add(c + o * rad, Vector2(0.5 + 0.5 * cos(th), 0.5 + 0.5 * sin(th)), w, d))
	for j in sides: sk.tri(mid, ring[j], ring[j + 1])

## An ellipsoid (head, blobs), weighted by `wf(p) -> Dictionary`.
func _ellipsoid(sk: SkinB, c: Vector3, r: Vector3, wf: Callable, rows := 6, cols := 10, lump := 0.0) -> void:
	var noise := MeshKit.noise()
	var g := []
	for i in rows + 1:
		var ph := PI * float(i) / rows
		var row := []
		for j in cols + 1:
			var th := TAU * float(j) / cols
			var dir := Vector3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th))
			var p := c + dir * r * (1.0 + lump * noise.get_noise_3d(dir.x * 5.0 + c.x * 30.0, dir.y * 5.0, dir.z * 5.0))
			row.append(sk.add(p, Vector2(float(j) / cols, float(i) / rows), wf.call(p), dir))
		g.append(row)
	for i in rows:
		for j in cols:
			sk.quad(g[i][j], g[i][j + 1], g[i + 1][j + 1], g[i + 1][j])

func _mesh() -> void:
	var skin_tex: String = genome.skin
	var flesh := _sk(skin_tex, 0.6 if skin_tex == "bloat" else 0.85, 0.7 if skin_tex == "bloat" else 0.35)
	var raw := _sk("raw", 0.5, 0.7)
	var bw := _bw()
	var bl := float(genome.build)
	# ---- the trunk: rings up the spine, weighted between the spine bones by height
	var levels := _levels()
	var chain := [bones.hips, bones.spine, bones.chest, bones.neck, bones.head]
	var ys := [0.93, 1.08, 1.26, 1.45, 1.53]
	var trunk := []
	var sides := 10
	var noise := MeshKit.noise()
	for lv in levels:
		var y: float = float(lv[0]) * s
		var w := _trunk_w(y, chain, ys)
		var ring := []
		for j in sides + 1:
			var th := TAU * float(j) / sides
			var o := Vector3(cos(th), 0.0, sin(th))
			var rx: float = float(lv[1]) * s * bw; var rz: float = float(lv[2]) * s * bw
			var bump := 1.0 + 0.08 * noise.get_noise_3d(cos(th) * 3.0, y * 20.0, sin(th) * 3.0 + float(genome.seed % 97))
			var p := Vector3(o.x * rx * bump, y, o.z * rz * bump)
			ring.append(flesh.add(p, Vector2(float(j) / sides, y), w, o))
		trunk.append(ring)
	for i in trunk.size() - 1:
		for j in sides: flesh.quad(trunk[i][j], trunk[i][j + 1], trunk[i + 1][j + 1], trunk[i + 1][j])
	_cap(flesh, Vector3(0, 0.86 * s, 0), Vector3.DOWN, 0.13 * s * bw, bones.hips, sides)
	# ---- the head
	_head(flesh)
	# ---- limbs
	for l in genome.limbs:
		_limb(l, flesh, raw)
	# ---- clothes, growth
	_clothes()
	_growth()
	var m := ArrayMesh.new()
	for key in _skins: (_skins[key] as SkinB).commit(m, _skin_mat[key])
	mesh_inst = MeshInstance3D.new(); mesh_inst.name = "Body"; mesh_inst.mesh = m
	skel.add_child(mesh_inst)
	mesh_inst.skeleton = NodePath("..")
	# hit parts: trunk and head
	hit_parts.append({"bone": bones.chest, "a": Vector3(0, 0.95 * s, 0), "b": Vector3(0, 1.4 * s, 0), "r": 0.17 * s * bw, "part": "torso"})
	hit_parts.append({"bone": bones.head, "a": Vector3(0, 1.58 * s, -0.01), "b": Vector3(0, 1.7 * s, -0.01), "r": 0.1 * s, "part": "head"})

## The trunk's cross-section by height (y in a 1.75 m body): half-width, half-depth.
func _levels() -> Array:
	var bl := float(genome.build)
	return [[0.86, 0.15, 0.1], [0.93, 0.17, 0.11], [1.02, 0.15 + bl * 0.06, 0.11 + bl * 0.1], [1.1, 0.145 + bl * 0.06, 0.11 + bl * 0.11],
		[1.2, 0.16 + bl * 0.03, 0.115 + bl * 0.05], [1.32, 0.18, 0.12], [1.4, 0.19, 0.11], [1.45, 0.08, 0.07], [1.53, 0.055, 0.055]]

func _trunk_r(y: float) -> Vector2:
	var lv := _levels()
	if y <= float(lv[0][0]): return Vector2(lv[0][1], lv[0][2])
	for i in lv.size() - 1:
		var a: Array = lv[i]; var b: Array = lv[i + 1]
		if y <= float(b[0]):
			var k := (y - float(a[0])) / (float(b[0]) - float(a[0]))
			return Vector2(lerpf(a[1], b[1], k), lerpf(a[2], b[2], k))
	return Vector2(lv.back()[1], lv.back()[2])

func _trunk_w(y: float, chain: Array, ys: Array) -> Dictionary:
	var w := {}
	for i in ys.size() - 1:
		var a: float = float(ys[i]) * s; var b: float = float(ys[i + 1]) * s
		if y <= a: w[chain[i]] = 1.0; return w
		if y < b:
			var k := (y - a) / (b - a)
			w[chain[i]] = 1.0 - k; w[chain[i + 1]] = k
			return w
	w[chain.back()] = 1.0
	return w

func _head(flesh: SkinB) -> void:
	var h: Dictionary = genome.head
	var st := String(h.state)
	var c := Vector3(0, 1.64 * s, -0.015 * s)
	var r := Vector3(0.085, 0.11, 0.1) * s
	if st == "overgrown": r *= 0.8
	var jaw_line := c.y - 0.03 * s
	var hb: int = bones.head; var jb: int = bones.jaw
	var sunk := st == "sunk"
	var side := 1.0 if int(genome.seed) % 2 == 0 else -1.0
	var wf := func(p: Vector3) -> Dictionary:
		# the lower front of the head is the jaw: below the mouth line, in front of the ear
		var k := smoothstep(jaw_line + 0.01 * s, jaw_line - 0.02 * s, p.y) * smoothstep(c.z + 0.02 * s, c.z - 0.03 * s, p.z)
		return {hb: 1.0 - k, jb: k}
	var noise := MeshKit.noise()
	var g := []
	var rows := 7; var cols := 12
	for i in rows + 1:
		var ph := PI * float(i) / rows
		var row := []
		for j in cols + 1:
			var th := TAU * float(j) / cols
			var dir := Vector3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th))
			var p := c + dir * r * (1.0 + 0.06 * noise.get_noise_3d(dir.x * 4.0, dir.y * 4.0 + float(genome.seed % 31), dir.z * 4.0))
			if sunk and dir.x * side > 0.2: p.x -= (dir.x * side - 0.2) * side * 0.05 * s       # one side caved in
			if st == "split" and absf(p.y - jaw_line) < 0.012 * s and dir.z < 0.2: p.z += 0.012 * s   # the grin torn back
			row.append(flesh.add(p, Vector2(float(j) / cols, float(i) / rows), wf.call(p), dir))
		g.append(row)
	for i in rows:
		for j in cols: flesh.quad(g[i][j], g[i][j + 1], g[i + 1][j + 1], g[i + 1][j])
	# the mouth: a dark inside, teeth along the jaw
	var black := _sk("black", 1.0, 0.0)
	var grin := 1.6 if st == "split" else 1.0
	_ellipsoid(black, Vector3(0, jaw_line, c.z - r.z * 0.72), Vector3(0.035 * grin, 0.012, 0.02) * s, func(p): return {hb: 0.5, jb: 0.5}, 3, 8)
	var teeth := _sk("teeth", 0.5, 0.6)
	for i in (10 if st == "split" else 6):
		var x := (float(i) / (9.0 if st == "split" else 5.0) - 0.5) * 0.06 * grin * s
		var z := c.z - r.z * 0.85 + absf(x) * 0.6
		_ellipsoid(teeth, Vector3(x, jaw_line - 0.005 * s, z), Vector3(0.006, 0.008, 0.005) * s, func(p): return {jb: 1.0}, 2, 5)
		_ellipsoid(teeth, Vector3(x, jaw_line + 0.006 * s, z + 0.002), Vector3(0.006, 0.007, 0.005) * s, func(p): return {hb: 1.0}, 2, 5)
	# the eyes (sunk, filmed); or none, if the growth has the face
	var eye := _sk("eye", 0.3, 0.8)
	var eyes := int(h.eyes)
	for i in eyes:
		var ex := (0.032 * s) * (1.0 if (i == 0) != (eyes == 1 and side < 0) else -1.0)
		_ellipsoid(eye, Vector3(ex, c.y + 0.025 * s, c.z - r.z * 0.86), Vector3(0.014, 0.012, 0.01) * s, func(p): return {hb: 1.0}, 3, 6)

func _limb(l: Dictionary, flesh: SkinB, raw: SkinB) -> void:
	var chain: Array = limb_bones[l.id]
	var ab: int = anchor_bone[l.id]
	var pts := []
	for b in chain: pts.append(rest_pos(b))
	var st := String(l.state)
	var th := float(l.thick) * s
	var arm := String(l.kind) == "arm"
	if st == "missing":
		# a scar where it was: puckered, raw
		_ellipsoid(raw, pts[0], Vector3(0.05, 0.05, 0.05) * th, func(p): return {ab: 1.0}, 3, 6)
		return
	var feet := String(l.kind) == "leg" and st != "stump"
	var bone_pts := pts.slice(0, pts.size() - (1 if feet else 0))
	var radii := []
	for i in bone_pts.size():
		var k := float(i) / maxf(1.0, bone_pts.size() - 1)
		radii.append(lerpf(0.055 if arm else 0.085, 0.032 if arm else 0.045, k) * th)
	var bseg := chain.slice(0, chain.size() - (1 if feet else 0))
	if st == "stump":
		_tube(flesh, bone_pts, radii, bseg, ab, 8, 3, 0.15, false, true, raw)
		hit_parts.append({"bone": chain[0], "a": bone_pts[0], "b": bone_pts.back(), "r": radii[0], "part": l.id})
		return
	_tube(flesh, bone_pts, radii, bseg, ab, 8, 3, 0.15)
	for i in bone_pts.size() - 1:
		hit_parts.append({"bone": bseg[i], "a": bone_pts[i], "b": bone_pts[i + 1], "r": maxf(0.05 * s, float(radii[i]) * 1.3), "part": l.id})
	var end: Vector3 = bone_pts.back(); var eb: int = bseg.back()
	if arm:
		# a hand: a flattened palm and three or four fingers, curled a little
		var d: Vector3 = (end - bone_pts[bone_pts.size() - 2]).normalized()
		var fr := _frame(d)
		_ellipsoid(flesh, end + d * 0.04 * s, Vector3(0.035, 0.045, 0.02) * s, func(p): return {eb: 1.0}, 3, 6)
		var nf := 3 + int(genome.seed + bone_pts.size()) % 2
		for f in nf:
			var off: Vector3 = fr[0] * ((float(f) / (nf - 1) - 0.5) * 0.05 * s)
			var a := end + d * 0.07 * s + off
			_tube(flesh, [a, a + d * 0.06 * s + fr[1] * 0.012 * s, a + d * 0.09 * s + fr[1] * 0.035 * s], [0.011 * s, 0.009 * s, 0.006 * s], [eb, eb], -1, 5, 1, 0.0, false, true)
	else:
		# a foot, pointing forward
		var fb: int = chain.back()
		var heel := end
		var toe: Vector3 = pts.back()
		_tube(flesh, [heel + Vector3(0, -0.02, 0.04) * s, toe + Vector3(0, -0.035, 0) * s], [0.045 * s, 0.035 * s], [fb], eb, 6, 2, 0.1, true, true)
	if st == "fused":
		# the growth has gone through the joint and set it: a crust along the limb
		var gs := _growth_skin()
		for i in bone_pts.size() - 1:
			var mid: Vector3 = (bone_pts[i] as Vector3).lerp(bone_pts[i + 1], 0.5)
			_growth_piece(gs, mid, (bone_pts[i + 1] - bone_pts[i]).normalized().cross(Vector3.FORWARD).normalized(), bseg[i], 0.7)

func _growth_skin() -> SkinB:
	match String(genome.growth):
		"coral": return _sk("coral", 0.8, 0.3)
		"fungus": return _sk("fungus", 0.9, 0.1)
		"bone": return _sk("bone", 0.7, 0.4)
	return _sk("tumour", 0.35, 0.9)

## One growth where it came out of them (at p, facing n), riding bone b.
func _growth_piece(gs: SkinB, p: Vector3, n: Vector3, b: int, size := 1.0) -> void:
	var w := {b: 1.0}
	var k := size * s
	match String(genome.growth):
		"coral":
			var d := (n + Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(0.0, 0.6), _rng.randf_range(-0.4, 0.4))).normalized()
			var a := p - n * 0.01 * k
			var m := a + d * 0.07 * k
			_tube(gs, [a, m, m + (d + Vector3(_rng.randf_range(-0.5, 0.5), 0.3, 0)).normalized() * 0.06 * k], [0.018 * k, 0.012 * k, 0.004 * k], [b, b], -1, 5, 2, 0.2, false, true)
			_tube(gs, [m, m + (d + Vector3(_rng.randf_range(-0.6, 0.6), 0.5, _rng.randf_range(-0.6, 0.6))).normalized() * 0.05 * k], [0.009 * k, 0.003 * k], [b], -1, 4, 2, 0.2, false, true)
		"fungus":
			# a shelf: a flattened half-disc jutting out, gills under
			var fr := _frame(n)
			var c := p + n * 0.02 * k
			var mid := gs.add(c, Vector2(0.5, 0.0), w, Vector3.UP)
			var rim := []
			for j in 9:
				var th := PI * float(j) / 8.0
				var o: Vector3 = (n * sin(th) + fr[0] * cos(th)) * 0.07 * k
				rim.append(gs.add(c + o + Vector3(0, -0.01 * k * sin(th), 0), Vector2(float(j) / 8.0, 1.0), w, Vector3.UP))
			for j in 8: gs.tri(mid, rim[j], rim[j + 1])
		"bone":
			_tube(gs, [p - n * 0.005, p + n * 0.09 * k + Vector3(0, 0.02, 0) * k], [0.016 * k, 0.001], [b], -1, 5, 1, 0.0)
		_:
			for i in 3 + _rng.randi() % 3:
				var o := (n + Vector3(_rng.randf_range(-0.7, 0.7), _rng.randf_range(-0.7, 0.7), _rng.randf_range(-0.7, 0.7))).normalized()
				_ellipsoid(gs, p + o * 0.025 * k, Vector3.ONE * _rng.randf_range(0.015, 0.032) * k, func(q): return w, 4, 6, 0.1)

func _growth() -> void:
	var gs := _growth_skin()
	var n := int(lerpf(4.0, 16.0, float(genome.growth_amount)))
	var bw := _bw()
	for i in n:
		var where := _rng.randf()
		if where < 0.55:
			# the back and shoulders, mostly (it comes out where Marta's did)
			var th := _rng.randf_range(0.2, PI - 0.2) if _rng.randf() < 0.75 else _rng.randf_range(0.0, TAU)
			var y := _rng.randf_range(1.0, 1.42) * s
			var o := Vector3(cos(th), 0, sin(th))
			var p := Vector3(o.x * 0.17 * s * bw, y, o.z * 0.12 * s * bw)
			_growth_piece(gs, p, o, bones.chest if y > 1.2 * s else bones.spine)
		elif where < 0.75:
			var dir := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.0, 1.0), _rng.randf_range(-0.2, 1.0)).normalized()
			_growth_piece(gs, Vector3(0, 1.64 * s, -0.015 * s) + dir * 0.1 * s, dir, bones.head, 0.8)
		else:
			# on a limb
			var l: Dictionary = genome.limbs[_rng.randi() % genome.limbs.size()]
			var ch: Array = limb_bones[l.id]
			if ch.size() < 2: continue
			var i0 := _rng.randi() % (ch.size() - 1)
			var a := rest_pos(ch[i0]); var b := rest_pos(ch[i0 + 1])
			var p := a.lerp(b, _rng.randf_range(0.2, 0.8))
			var nn := (b - a).normalized().cross(Vector3(_rng.randf_range(-1, 1), 0.3, _rng.randf_range(-1, 1))).normalized()
			_growth_piece(gs, p + nn * 0.04 * s, nn, ch[i0], 0.7)
	if String(genome.head.state) == "overgrown":
		for i in 7:
			var dir := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.3, 1.0), _rng.randf_range(-1, 0.3)).normalized()
			_growth_piece(gs, Vector3(0, 1.64 * s, -0.015 * s) + dir * 0.07 * s, dir, bones.head, 1.3)

func _clothes() -> void:
	var kind := String(genome.clothes)
	if kind == "none":
		return
	var cl := _sk("cloth_%s_%d" % [kind, int(genome.palette)], 0.95, 0.1)
	var bw := _bw(); var bl := float(genome.build)
	var chain := [bones.hips, bones.spine, bones.chest, bones.neck, bones.head]
	var ys := [0.93, 1.08, 1.26, 1.45, 1.53]
	var top := 1.43
	var bottom := 0.8 if kind in ["coat", "dress"] else 0.86
	var hem := 0.55 if kind == "coat" else (0.5 if kind == "dress" else bottom)
	var sides := 10
	var rings := []
	var noise := MeshKit.noise()
	var levels := []
	var y := top
	while y > hem - 0.001:
		levels.append(y); y -= 0.07
	for yy_v in levels:
		var yy: float = yy_v
		var yy_s := yy * s
		var skirt := yy < 0.86
		# the cloth follows the body a finger's width off it; below the hips it hangs and flares
		var tr := _trunk_r(maxf(yy, 0.86))
		var flare := (0.86 - yy) * (0.32 if kind == "dress" else 0.16) if skirt else 0.0
		var rx := (tr.x * 1.08 + 0.012 + flare) * s * bw
		var rz := (tr.y * 1.1 + 0.012 + flare * 0.8) * s * bw
		var w: Dictionary
		if skirt:
			# the skirt of a coat or dress follows the hips, a little the thighs
			w = {bones.hips: 1.0}
		else:
			w = _trunk_w(yy_s, chain, ys)
		var ring := []
		for j in sides + 1:
			var th := TAU * float(j) / sides
			var o := Vector3(cos(th), 0, sin(th))
			var ragged := -0.03 * s * absf(noise.get_noise_2d(th * 4.0, float(genome.seed % 89))) if yy == levels.back() else 0.0
			ring.append(cl.add(Vector3(o.x * rx, yy_s + ragged, o.z * rz), Vector2(float(j) / sides, yy), w, o))
		rings.append(ring)
	for i in rings.size() - 1:
		for j in sides: cl.quad(rings[i][j], rings[i][j + 1], rings[i + 1][j + 1], rings[i + 1][j])
	# sleeves and legs on the limbs they were born with
	for l in genome.limbs:
		if l.extra or l.state == "missing": continue
		var ch: Array = limb_bones[l.id]
		var arm := String(l.kind) == "arm"
		if arm and kind in ["overalls"] and int(genome.palette) == 0: continue     # rolled up / sleeveless
		if not arm and kind in ["coat", "dress"]: continue
		var n := mini(ch.size(), (2 if l.state == "stump" else (3 if arm else 3)))
		var pts := []; var radii := []; var bs := []
		for i in n:
			pts.append(rest_pos(ch[i]))
			radii.append((0.068 if arm else 0.1) * float(l.thick) * s * (1.0 - 0.3 * float(i) / n))
		if pts.size() < 2: continue
		bs = ch.slice(0, pts.size())
		_tube(cl, pts, radii, bs, anchor_bone[l.id], 8, 2, 0.1)

# ================================================================ posing
func _rot(b: int, e: Vector3) -> void:
	var tw: Array = _twitch.get(b, [Vector3.ZERO, Vector3.ZERO])
	skel.set_bone_pose_rotation(b, Quaternion(Basis.from_euler(e + tw[0], EULER_ORDER_YXZ)))

## A limb's chain posed by the angle of its root (pitch forward +, roll out +side) and the bend at
## each joint after (positive bends a leg's knee back / an arm's elbow forward).
func _pose_limb(l: Dictionary, swing: float, out: float, bends: Array, extra := Vector3.ZERO) -> void:
	var ch: Array = limb_bones[l.id]
	if ch.is_empty() or severed.has(l.id): return
	var side := float(l.side)
	_rot(ch[0], Vector3(swing, extra.y, out * side + extra.z))
	var leg := String(l.kind) == "leg"
	var fused := String(l.state) == "fused"
	for i in range(1, ch.size()):
		var bnd := float(bends[i - 1]) if i - 1 < bends.size() else 0.0
		if fused: bnd *= 0.1
		_rot(ch[i], Vector3(-bnd if leg else bnd, 0, 0))

## The body for this frame. ctx: speed (m/s), mode ("idle" | "move" | "attack" | "hurt" |
## "dead"), look (a point in rig space, or null), attack (0..1 how far into a grab).
func animate(delta: float, ctx: Dictionary) -> void:
	_t += delta
	var speed: float = ctx.get("speed", 0.0)
	var mode: String = ctx.get("mode", "idle")
	var attack: float = ctx.get("attack", 0.0)
	_phase += delta * (speed / (1.1 * s) * TAU if speed > 0.02 else 0.0)
	if mode == "dead": dead_k = minf(1.0, dead_k + delta * 1.1)
	_update_twitch(delta, mode)
	# flinch spring
	_flinch_v += (-_flinch * 160.0 - _flinch_v * 12.0) * delta
	_flinch += _flinch_v * delta
	var hunch := float(genome.hunch)
	var lean := float(genome.lean)
	var moving := clampf(speed / 0.6, 0.0, 1.0)
	var ph := _phase
	var root_pos := Vector3.ZERO
	var root_rot := Vector3.ZERO
	var spine := Vector3(-0.12 * hunch, 0, lean * 0.08)
	var chest := Vector3(-0.15 * hunch, 0, 0)
	var neck := Vector3(0.1 * hunch, 0, 0)
	var head := Vector3(0.12 * hunch, 0, float(genome.head.tilt))
	# the legs they stand on
	var legs := []; var arms := []
	for l in genome.limbs:
		if severed.has(l.id) or String(l.state) in ["missing", "stump"]: continue
		if String(l.kind) == "leg": legs.append(l)
		else: arms.append(l)
	var leg_std := 0.87 * s
	# they stand on their longest leg (a shorter one hangs and only touches in the stride: a limp)
	var avg_len := 0.0
	for l in legs: avg_len = maxf(avg_len, float(l.length))
	var crawling := locomotion in ["crawl", "drag"]
	# ---------------- the gait
	match locomotion:
		"walk", "limp":
			root_pos.y = (avg_len - 1.0) * leg_std - absf(cos(ph)) * 0.025 * s * moving
			for l in legs:
				var o := 0.0 if float(l.side) < 0.0 else PI
				var sw := sin(ph + o) * 0.42 * moving
				var knee := maxf(0.0, cos(ph + o)) * 0.85 * moving + 0.04
				var bad := String(l.state) in ["short", "fused", "long"] and locomotion == "limp"
				if bad:
					sw *= 0.6; root_rot.z += float(l.side) * (0.08 + 0.06 * sin(ph + o) * moving) * (1.0 if String(l.state) == "short" else -1.0)
				_pose_limb(l, sw, 0.03, [knee, -sw * 0.5])
			var ai := 0
			for l in arms:
				var o2 := PI if float(l.side) < 0.0 else 0.0
				_pose_limb(l, sin(ph + o2) * 0.35 * moving + (0.15 if l.extra else 0.0), 0.08 + (0.4 if l.extra else 0.0), [0.25 + 0.15 * moving, 0.1])
				ai += 1
			spine.x -= 0.06 * moving
		"skitter":
			root_pos.y = (avg_len - 1.0) * leg_std - 0.12 * s
			spine.x -= 0.25; neck.x += 0.2
			var n := legs.size()
			for i in n:
				var l: Dictionary = legs[i]
				var o := TAU * float(i) / n
				var ph2 := ph * 1.8 + o
				_pose_limb(l, sin(ph2) * 0.35 * moving, 0.35 + 0.15 * maxf(0.0, cos(ph2)) * moving, [0.5 + maxf(0.0, cos(ph2)) * 0.5 * moving, -0.2])
			for l in arms:
				_pose_limb(l, 0.6 + sin(ph * 1.8 + float(l.side)) * 0.25 * moving, 0.5, [0.8, 0.3])
		"hop":
			var hop := absf(sin(ph * 0.8)) * moving
			root_pos.y = (avg_len - 1.0) * leg_std + hop * 0.09 * s - 0.04 * s
			root_rot.z += float(legs[0].side) * -0.15 if legs.size() > 0 else 0.0
			spine.x -= 0.15
			for l in legs: _pose_limb(l, -0.1 + 0.2 * hop, 0.0, [0.5 - 0.45 * hop, 0.2])
			for l in arms: _pose_limb(l, 0.4 * hop, 0.5, [0.6, 0.3])
		"lurch":
			# the one leg and an arm used as a crutch, in turn; the body swung over between
			var crutch: Dictionary = arms[0] if arms.size() > 0 else {}
			var leg: Dictionary = legs[0] if legs.size() > 0 else {}
			var k := sin(ph * 0.9)
			root_pos.y = (avg_len - 1.0) * leg_std - 0.08 * s - absf(k) * 0.04 * s
			root_rot.z = float(leg.get("side", 1)) * -0.25
			spine.x -= 0.35; spine.z += float(crutch.get("side", 1)) * 0.2
			if not leg.is_empty(): _pose_limb(leg, 0.35 * k * moving, 0.05, [0.3 + 0.4 * maxf(0.0, -k) * moving, 0.1])
			if not crutch.is_empty(): _pose_limb(crutch, 0.5 - 0.6 * k * moving, 0.25, [0.1, 0.0])
			for l in arms.slice(1): _pose_limb(l, 0.2, 0.4, [0.5, 0.2])
		"crawl", "drag":
			# down on the floor, face first, pulling with whatever arms they have
			root_rot.x = -1.35
			root_pos.y = -0.93 * s + 0.16 * s * _bw()
			root_pos.z = 0.55 * s
			neck.x += 0.75; head.x += 0.35
			var writhe := sin(ph * 0.9) * (0.25 if locomotion == "drag" else 0.08) * maxf(moving, 0.3)
			spine.y += writhe; chest.y += writhe
			var ai2 := 0
			for l in arms:
				var o := 0.0 if float(l.side) < 0.0 else PI
				var reach := sin(ph + o) * moving
				_pose_limb(l, 2.5 + 0.45 * reach, 0.35, [0.5 - 0.4 * reach, 0.2])
				ai2 += 1
			for l in legs: _pose_limb(l, -0.2, 0.1, [0.2, 0.0])
	# ---------------- the habit, when still
	if moving < 0.2 and not crawling and mode == "idle":
		var q := 1.0 - moving * 5.0
		match String(genome.quirk):
			"rocking": spine.x += sin(_t * 1.7) * 0.12 * q; root_rot.z += sin(_t * 0.85) * 0.04 * q
			"searching": head.y += sin(_t * 0.6) * 0.8 * q; chest.y += sin(_t * 0.6 - 0.4) * 0.25 * q
			"counting":
				var beat := fposmod(_t, 4.0)
				if beat < 2.4: head.x -= 0.18 * absf(sin(beat * PI / 0.6)) * q
			"knocking":
				if arms.size() > 0:
					var beat := fposmod(_t, 3.2)
					var knock := 0.35 * absf(sin(beat * PI * 3.0)) if beat < 1.0 else 0.0
					_pose_limb(arms[0], (1.15 + knock * 0.3) * q, 0.1, [1.3 - knock, 0.2])
			"folding":
				for l in arms.slice(0, 2): _pose_limb(l, 0.6 * q, -0.35 * q, [1.4 * q, 0.3 + 0.1 * sin(_t * 2.0)])
	# ---------------- the head turns to what it wants
	var look = ctx.get("look")
	if look != null and dead_k <= 0.0:
		var hp := rest_pos(bones.head) + root_pos
		var d: Vector3 = (look as Vector3) - hp
		var yaw := clampf(atan2(-d.x, -d.z), -1.3, 1.3)
		var pitch := clampf(atan2(d.y, Vector2(d.x, d.z).length()), -0.7, 0.6)
		head.y += yaw * 0.7; neck.y += yaw * 0.3
		head.x += pitch * (0.4 if crawling else 0.7)
	# ---------------- reaching to grab
	if attack > 0.0:
		var a := sin(clampf(attack, 0.0, 1.0) * PI * 0.5)
		spine.x -= 0.3 * a; chest.x -= 0.2 * a
		for l in arms:
			_pose_limb(l, (2.9 if crawling else 1.5) * a + (0.0 if crawling else 0.0), 0.15, [0.15, 0.0])
	# ---------------- dying: everything lets go
	if dead_k > 0.0:
		var k := smoothstep(0.0, 1.0, dead_k)
		root_rot.x = lerpf(root_rot.x, -1.5 if not crawling else -1.55, k)
		root_pos.y = lerpf(root_pos.y, -0.93 * s + 0.12 * s, k)
		root_pos.z = lerpf(root_pos.z, 0.7 * s, k)
		spine = spine.lerp(Vector3(0.1, 0.2, 0.1), k); head = head.lerp(Vector3(0.3, 0.9, 0.2), k)
		for l in arms: _pose_limb(l, lerpf(0.0, 2.6, k), 0.6, [0.4 * k, 0.2])
		for l in legs: _pose_limb(l, lerpf(0.0, -0.1, k), 0.2, [0.6 * k, 0.1])
	root_rot += _flinch
	skel.set_bone_pose_position(bones.hips, skel.get_bone_rest(bones.hips).origin + root_pos)
	_rot(bones.hips, root_rot)
	_rot(bones.spine, spine)
	_rot(bones.chest, chest)
	_rot(bones.neck, neck)
	_rot(bones.head, head)
	var jaw := float(genome.head.jaw) + (0.5 * attack if attack > 0.0 else 0.0) + (0.4 * dead_k)
	_rot(bones.jaw, Vector3(-jaw, 0, 0))

## A flinch from a hit (rig-space direction it came from).
func flinch(from_dir: Vector3, k := 1.0) -> void:
	_flinch_v += Vector3(-from_dir.z, 0.0, from_dir.x) * 6.0 * k

func _update_twitch(delta: float, mode: String) -> void:
	var rate := float(genome.twitch) * (0.0 if mode == "dead" else 1.0)
	if _rng.randf() < delta * rate * 1.5:
		var b := _rng.randi() % skel.get_bone_count()
		var tw: Array = _twitch.get(b, [Vector3.ZERO, Vector3.ZERO])
		tw[1] += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * 5.0
		_twitch[b] = tw
	for b in _twitch.keys():
		var tw: Array = _twitch[b]
		tw[1] += (-(tw[0] as Vector3) * 220.0 - (tw[1] as Vector3) * 16.0) * delta
		tw[0] += (tw[1] as Vector3) * delta
		if (tw[0] as Vector3).length() < 1e-4 and (tw[1] as Vector3).length() < 1e-3: _twitch.erase(b)

# ================================================================ limbs lost
## Shoot a limb off: it collapses into the joint it hung from (a cut there), falls away as a
## piece, and the gait is worked out again from what's left. Returns the piece (or null).
func sever(id: String) -> RigidBody3D:
	if severed.has(id) or not limb_bones.has(id): return null
	var l: Dictionary
	for x in genome.limbs:
		if x.id == id: l = x
	if l.is_empty() or String(l.state) == "missing": return null
	severed[id] = true
	var ch: Array = limb_bones[id]
	var at := skel.global_transform * skel.get_bone_global_pose(ch[0])
	var tip := skel.global_transform * skel.get_bone_global_pose(ch.back())
	for b in ch: skel.set_bone_pose_scale(b, Vector3.ONE * 0.001)
	# the cut, on the body
	var cap := MeshInstance3D.new(); var cm := CylinderMesh.new()
	cm.top_radius = 0.05 * s * float(l.thick); cm.bottom_radius = cm.top_radius; cm.height = 0.02; cm.radial_segments = 8
	cap.mesh = cm; cap.material_override = mat("raw", 0.5, 0.7)
	var ba := BoneAttachment3D.new(); ba.bone_name = skel.get_bone_name(ch[0]); skel.add_child(ba)
	ba.add_child(cap)
	cap.rotation = Vector3(PI / 2, 0, 0) if String(l.kind) != "leg" else Vector3.ZERO
	# what fell
	var piece := RigidBody3D.new(); piece.name = "Severed_" + id; piece.mass = 3.0 if String(l.kind) == "leg" else 1.5
	var len := at.origin.distance_to(tip.origin) + 0.1 * s
	var mi := MeshInstance3D.new(); var caps := CapsuleMesh.new()
	caps.radius = 0.045 * s * float(l.thick); caps.height = maxf(len, caps.radius * 2.2); caps.radial_segments = 8; caps.rings = 2
	mi.mesh = caps; mi.material_override = mat(String(genome.skin)); piece.add_child(mi)
	var cs := CollisionShape3D.new(); var sh := CapsuleShape3D.new(); sh.radius = caps.radius; sh.height = caps.height; cs.shape = sh; piece.add_child(cs)
	var root := get_tree().current_scene if get_tree().current_scene else get_tree().root
	root.add_child(piece)
	var mid := at.origin.lerp(tip.origin, 0.5)
	var dir := (tip.origin - at.origin).normalized()
	piece.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, dir if dir.length() > 0.5 else Vector3.UP)), mid)
	piece.linear_velocity = Vector3(_rng.randf_range(-1, 1), 1.5, _rng.randf_range(-1, 1))
	piece.angular_velocity = Vector3(_rng.randf_range(-4, 4), _rng.randf_range(-4, 4), _rng.randf_range(-4, 4))
	# how they move now
	var left := []
	for x in genome.limbs:
		var y: Dictionary = x.duplicate()
		if severed.has(y.id): y.state = "missing"
		left.append(y)
	locomotion = InfectedGenome.locomotion_of(left)
	return piece

## The limbs they still have, of a kind.
func working(kind: String) -> int:
	var n := 0
	for l in genome.limbs:
		if String(l.kind) == kind and not severed.has(l.id) and String(l.state) in ["whole", "short", "long", "fused"]: n += 1
	return n
