class_name ArmRig
extends Node3D
## Kurt Federov's right arm, shoulder to fingertips: one Skeleton3D (21 bones) and one skinned
## mesh, built in code to the measurements in docs/KURT.md §3 (177.8 cm man). A coat sleeve and
## shirt cuff are skinned to the same skeleton.
##
## Skeleton space ("arm space"): the wrist joint at the origin, fingers toward -Z, the back of the
## hand +Y, the little finger +X (a right hand, palm down). The elbow is at +Z 0.265 and the
## shoulder at +Z 0.595 in the rest pose. Every bone's own frame: +Y along the bone, +Z toward the
## nail side, +X across, so flexion is always about the bone's X (negative curls to the palm).
##
## Posing: `pose_name` selects a pose from POSES; it is blended in at `blend_speed`. `wrist`
## (flex, deviation) and `pronation` are separate. `idle` adds the drift, tremor and the periodic
## slow flex-and-release of a stiff hand. In first person, `solve_arm()` places the arm by IK.

const PS1 := preload("res://shaders/world.gdshader")

# ------------------------------------------------------------------ anatomy (metres)
const FOREARM := 0.265
const UPPER := 0.33
const FINGERS := {
	"index":  {"base": Vector3(-0.016, 0.006, -0.030), "mcp": Vector3(-0.027, 0.003, -0.094), "len": [0.042, 0.025, 0.019], "r": 0.0095, "splay": -4.0, "cup": 0.0},
	"middle": {"base": Vector3(-0.004, 0.007, -0.030), "mcp": Vector3(-0.008, 0.004, -0.097), "len": [0.046, 0.029, 0.020], "r": 0.0098, "splay": 0.0, "cup": 0.0},
	"ring":   {"base": Vector3(0.008, 0.006, -0.028), "mcp": Vector3(0.012, 0.002, -0.092), "len": [0.043, 0.027, 0.020], "r": 0.0090, "splay": 3.0, "cup": 0.12},
	"little": {"base": Vector3(0.019, 0.004, -0.026), "mcp": Vector3(0.031, -0.002, -0.083), "len": [0.034, 0.019, 0.017], "r": 0.0080, "splay": 8.0, "cup": 0.20},
}
const FINGER_ORDER := ["index", "middle", "ring", "little"]
const THUMB_CMC := Vector3(-0.022, -0.008, -0.020)
const THUMB_MCP := Vector3(-0.049, -0.013, -0.054)
const THUMB_LEN := [0.032, 0.025]
const THUMB_R := 0.0112
const THUMB_NAIL_UP := Vector3(-0.72, 0.62, 0.05)   # at rest the thumbnail faces out and up

# ------------------------------------------------------------------ limits (degrees), docs/KURT.md §3.3
const LIM := {"mcp": [-20.0, 85.0], "pip": [0.0, 100.0], "dip": [0.0, 70.0], "spread": [-16.0, 16.0],
	"t_flex": [-10.0, 40.0], "t_abd": [-5.0, 55.0], "t_mcp": [-10.0, 50.0], "t_ip": [-15.0, 70.0],
	"w_flex": [-60.0, 70.0], "w_dev": [-18.0, 28.0], "pron": [-80.0, 80.0]}

# ------------------------------------------------------------------ poses
# finger: [MCP flex, PIP flex, DIP flex, spread]; thumb: [CMC flex (across the palm),
# CMC abduction (away from the palm), MCP flex, IP flex]
const POSES := {
	"relaxed": {"index": [18, 26, 12, -2], "middle": [22, 32, 16, 0], "ring": [28, 38, 20, 2], "little": [34, 44, 24, 5], "thumb": [6, 14, 10, 12]},
	"open":    {"index": [0, 2, 0, -9], "middle": [0, 2, 0, -2], "ring": [0, 3, 0, 5], "little": [2, 4, 2, 13], "thumb": [-8, 6, 0, -5]},
	"flat":    {"index": [-12, 0, 0, -3], "middle": [-12, 0, 0, 0], "ring": [-10, 0, 0, 2], "little": [-8, 2, 0, 4], "thumb": [-4, 2, 0, -10]},
	"fist":    {"index": [80, 98, 55, 0], "middle": [84, 100, 60, 0], "ring": [85, 100, 62, 2], "little": [85, 100, 64, 4], "thumb": [34, 26, 40, 34]},
	"grip":    {"index": [52, 62, 34, -2], "middle": [58, 66, 38, 0], "ring": [62, 70, 40, 2], "little": [66, 72, 42, 5], "thumb": [18, 42, 16, 20]},
	"hold":    {"index": [34, 40, 20, -4], "middle": [38, 44, 24, 0], "ring": [42, 48, 26, 3], "little": [46, 52, 30, 7], "thumb": [10, 34, 8, 10]},
	"point":   {"index": [0, 4, 2, -2], "middle": [80, 100, 58, 0], "ring": [84, 100, 62, 2], "little": [85, 100, 64, 4], "thumb": [30, 24, 36, 30]},
	"pinch":   {"index": [42, 48, 22, 0], "middle": [30, 38, 18, 2], "ring": [36, 46, 24, 4], "little": [42, 52, 28, 7], "thumb": [24, 44, 22, 20]},
	"reach":   {"index": [6, 10, 4, -6], "middle": [8, 12, 6, -1], "ring": [12, 16, 8, 4], "little": [16, 20, 10, 9], "thumb": [-4, 18, 4, 4]},
	"stiff_flex": {"index": [66, 84, 46, 0], "middle": [70, 88, 50, 0], "ring": [72, 90, 52, 2], "little": [74, 92, 54, 4], "thumb": [26, 24, 30, 26]},
}

@export var pose_name := "relaxed"
@export var blend_speed := 7.0
@export var idle := true
@export var wrist := Vector2.ZERO        # degrees: x = flexion (+ toward the palm), y = ulnar deviation
@export var pronation := 0.0             # degrees: + pronates (palm turns down/inward)

var skeleton: Skeleton3D
var mesh_instance: MeshInstance3D
var cur := {}                            # current blended pose values
var B := {}                              # bone name -> index
var rest_g := {}                         # bone name -> rest global (arm space)
var _t := 0.0
var _flex_t := -1.0                      # time into an idle flex-and-release, or -1
var _next_flex := 6.0
var _mat_skin: ShaderMaterial

func _ready() -> void:
	_build_skeleton()
	_build_mesh()
	for k in POSES.relaxed:
		cur[k] = (POSES.relaxed[k] as Array).duplicate()
	_apply_pose(cur)

# ================================================================== skeleton
static func frame(dir: Vector3, up: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(up).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)

func _bone(name: String, parent: String, origin: Vector3, dir: Vector3, up: Vector3) -> void:
	var t := Transform3D(frame(dir, up), origin)
	var i := skeleton.get_bone_count()
	skeleton.add_bone(name)
	var pg := Transform3D.IDENTITY
	if parent != "":
		skeleton.set_bone_parent(i, B[parent])
		pg = rest_g[parent]
	skeleton.set_bone_rest(i, pg.affine_inverse() * t)
	B[name] = i
	rest_g[name] = t

func finger_dir(name: String) -> Vector3:
	var f: Dictionary = FINGERS[name]
	return Vector3(0, 0, -1).rotated(Vector3.UP, deg_to_rad(-float(f.splay)))

func thumb_dirs() -> Array:
	var d1 := (THUMB_MCP - THUMB_CMC).normalized()
	var d2 := (d1 + Vector3(0.1, 0.0, -0.5)).normalized()
	return [d1, d2]

func _build_skeleton() -> void:
	skeleton = Skeleton3D.new(); skeleton.name = "Skeleton"
	add_child(skeleton)
	var back := Vector3.UP
	_bone("upper_arm", "", Vector3(0, 0, FOREARM + UPPER), Vector3(0, 0, -1), back)
	_bone("forearm", "upper_arm", Vector3(0, 0, FOREARM), Vector3(0, 0, -1), back)
	_bone("forearm_twist", "forearm", Vector3(0, 0, FOREARM * 0.5), Vector3(0, 0, -1), back)
	_bone("hand", "forearm_twist", Vector3.ZERO, Vector3(0, 0, -1), back)
	for n in FINGER_ORDER:
		var f: Dictionary = FINGERS[n]
		var d := finger_dir(n)
		_bone(n + "_meta", "hand", f.base, (f.mcp as Vector3) - (f.base as Vector3), back)
		var p: Vector3 = f.mcp
		var prev: String = n + "_meta"
		for k in 3:
			var bn := "%s_%d" % [n, k + 1]
			_bone(bn, prev, p, d, back)
			p += d * float(f.len[k])
			prev = bn
	var td := thumb_dirs()
	_bone("thumb_1", "hand", THUMB_CMC, td[0], THUMB_NAIL_UP)
	_bone("thumb_2", "thumb_1", THUMB_MCP, td[1], THUMB_NAIL_UP)
	_bone("thumb_3", "thumb_2", THUMB_MCP + td[1] * THUMB_LEN[0], td[1], THUMB_NAIL_UP)
	skeleton.reset_bone_poses()

# ================================================================== mesh
## Vertex helper: up to four bone influences, normalised.
var _st: SurfaceTool
var _nv := 0

func _v(p: Vector3, uv: Vector2, w: Dictionary, col: Color) -> int:
	var pairs := []
	for k in w:
		if w[k] > 0.0001:
			pairs.append([k, w[k]])
	pairs.sort_custom(func(a, b): return a[1] > b[1])
	pairs = pairs.slice(0, 4)
	var sum := 0.0
	for pr in pairs: sum += pr[1]
	var bones := PackedInt32Array([0, 0, 0, 0]); var ws := PackedFloat32Array([0, 0, 0, 0])
	for i in pairs.size():
		bones[i] = B[pairs[i][0]]; ws[i] = pairs[i][1] / sum
	_st.set_color(col); _st.set_uv(uv); _st.set_bones(bones); _st.set_weights(ws)
	_st.add_vertex(p)
	_nv += 1
	return _nv - 1

## Lofts closed rings into a tube (rings[i][j]: points; wts/cols the same shape). Ring j runs
## from the bone's +X toward its palm side, which with i running along the bone gives outward
## faces in Godot's winding. Caps the ends with a fan where asked.
func _loft(rings: Array, wts: Array, cols: Array, v_scale: float, cap_start: bool, cap_end: bool) -> void:
	var m: int = rings[0].size()
	var idx := []
	for i in rings.size():
		var row := []
		for j in m + 1:
			var jj := j % m
			row.append(_v(rings[i][jj], Vector2(float(j) / m, i * v_scale), wts[i][jj], cols[i][jj]))
		idx.append(row)
	for i in rings.size() - 1:
		for j in m:
			var a: int = idx[i][j]; var b: int = idx[i][j + 1]; var c: int = idx[i + 1][j + 1]; var d: int = idx[i + 1][j]
			_st.add_index(a); _st.add_index(c); _st.add_index(b)
			_st.add_index(a); _st.add_index(d); _st.add_index(c)
	for end in [[cap_start, 0], [cap_end, rings.size() - 1]]:
		if not end[0]:
			continue
		var i: int = end[1]
		var ctr := Vector3.ZERO
		for p in rings[i]: ctr += p
		ctr /= m
		if i > 0:
			ctr += (ctr - _ring_centre(rings[i - 1])).normalized() * 0.002
		else:
			ctr += (ctr - _ring_centre(rings[1])).normalized() * 0.002
		var c := _v(ctr, Vector2(0.5, i * v_scale), wts[i][0], cols[i][0])
		for j in m:
			var a: int = idx[i][j]; var b: int = idx[i][j + 1]
			if i == 0:
				_st.add_index(c); _st.add_index(a); _st.add_index(b)
			else:
				_st.add_index(c); _st.add_index(b); _st.add_index(a)

func _ring_centre(r: Array) -> Vector3:
	var c := Vector3.ZERO
	for p in r: c += p
	return c / r.size()

## A superellipse cross-section around `c` in the plane of `x_axis` and `y_axis`
## (y_axis toward the back of the hand). `up_h`/`down_h` are the half-heights above/below.
func _section(c: Vector3, x_axis: Vector3, y_axis: Vector3, half_w: float, up_h: float, down_h: float, n: int, e := 2.4) -> Array:
	var out := []
	for j in n:
		var th := TAU * float(j) / n
		var cx := cos(th); var sy := -sin(th)          # j: +X first, then toward the palm side
		var x := signf(cx) * pow(absf(cx), 2.0 / e) * half_w
		var y := signf(sy) * pow(absf(sy), 2.0 / e) * (up_h if sy > 0.0 else down_h)
		out.append(c + x_axis * x + y_axis * y)
	return out

func _skin_col(dorsal: float) -> Color:
	# back of the hand: weathered, a little ruddy; palm: paler and pinker
	return Color(1.0, 0.96, 0.93).lerp(Color(1.06, 0.9, 0.86), clampf(-dorsal * 1.4, 0.0, 1.0))

func _build_mesh() -> void:
	_st = SurfaceTool.new(); _st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_nv = 0
	_arm_and_palm()
	for n in FINGER_ORDER:
		_finger(n)
	_thumb()
	_st.generate_normals()
	var skin_mesh := _st.commit()
	_mat_skin = _material("skin", 0.62, 0.35, Vector2(2, 1))
	skin_mesh.surface_set_material(0, _mat_skin)

	# nails, then the sleeve and cuff, as further surfaces
	_st = SurfaceTool.new(); _st.begin(Mesh.PRIMITIVE_TRIANGLES); _nv = 0
	for n in FINGER_ORDER:
		var f: Dictionary = FINGERS[n]
		var L: Array = f.len
		_nail(n + "_3", f.mcp + finger_dir(n) * (L[0] + L[1]), finger_dir(n), Vector3.UP, L[2], f.r * 0.82)
	var td := thumb_dirs()
	_nail("thumb_3", THUMB_MCP + td[1] * THUMB_LEN[0], td[1], THUMB_NAIL_UP, THUMB_LEN[1], THUMB_R * 0.8)
	_st.generate_normals()
	_st.commit(skin_mesh)
	skin_mesh.surface_set_material(1, _material("nail", 0.3, 0.6))

	_st = SurfaceTool.new(); _st.begin(Mesh.PRIMITIVE_TRIANGLES); _nv = 0
	_sleeve()
	_st.generate_normals()
	_st.commit(skin_mesh)
	skin_mesh.surface_set_material(2, _material("coat", 0.95, 0.15, Vector2(5, 3)))

	_st = SurfaceTool.new(); _st.begin(Mesh.PRIMITIVE_TRIANGLES); _nv = 0
	_cuff()
	_st.generate_normals()
	_st.commit(skin_mesh)
	skin_mesh.surface_set_material(3, _material("cuff", 0.85, 0.2))

	mesh_instance = MeshInstance3D.new(); mesh_instance.name = "ArmMesh"
	mesh_instance.mesh = skin_mesh
	skeleton.add_child(mesh_instance)
	mesh_instance.skeleton = NodePath("..")
	mesh_instance.skin = skeleton.create_skin_from_rest_transforms()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _material(tex: String, rough: float, spec: float, uvs := Vector2.ONE) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = PS1
	m.set_shader_parameter("albedo_tex", KurtTextures.get_tex(tex))
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("specular", spec)
	m.set_shader_parameter("use_vertex_color", true)
	m.set_shader_parameter("snap", 0.0)     # close to the eye: no wobble
	m.set_shader_parameter("uv_scale", uvs)
	return m

# ------------------------------------------------------------------ forearm, wrist and palm: one loft
func _arm_and_palm() -> void:
	var rings := []; var wts := []; var cols := []
	var N := 16
	# forearm: elbow to wrist (most of it under the sleeve)
	var fz := [FOREARM + 0.03, FOREARM, 0.21, 0.16, 0.11, 0.07, 0.04, 0.018]
	for z in fz:
		var k := clampf(z / FOREARM, 0.0, 1.0)
		var hw := lerpf(0.030, 0.043, smoothstep(0.0, 0.8, k))
		var hh := lerpf(0.020, 0.036, smoothstep(0.0, 0.8, k))
		var ring := _section(Vector3(0, -0.002, z), Vector3.RIGHT, Vector3.UP, hw, hh, hh * 1.05, N, 2.2)
		rings.append(ring)
		var w := {}
		if z > FOREARM - 0.02:
			w = {"forearm": 1.0 - smoothstep(FOREARM - 0.02, FOREARM + 0.03, z), "upper_arm": smoothstep(FOREARM - 0.02, FOREARM + 0.03, z)}
		else:
			var tw := 1.0 - smoothstep(0.03, 0.22, z)       # the twist spreads along the forearm
			w = {"forearm": 1.0 - tw, "forearm_twist": tw}
		var rw := []; var rc := []
		for p in ring: rw.append(w); rc.append(_skin_col((p.y + 0.002) / hh))
		wts.append(rw); cols.append(rc)
	# palm: wrist (v=0) to the knuckle line (v=1)
	var PV := 10
	for i in PV + 1:
		var v := float(i) / PV
		var zc := lerpf(0.0, -0.088, v)
		var hw := lerpf(0.031, 0.043, smoothstep(0.0, 0.55, v))
		var cx := lerpf(-0.001, 0.002, v)
		var up_h := lerpf(0.017, 0.012, v)
		var dn_h := lerpf(0.019, 0.015, v)
		var ring := _section(Vector3(cx, 0, zc), Vector3.RIGHT, Vector3.UP, hw, up_h, dn_h, N, 2.6)
		var rw := []; var rc := []
		for j in ring.size():
			var p: Vector3 = ring[j]
			var u := (p.x - (cx - hw)) / (2.0 * hw)            # 0 thumb side .. 1 little-finger side
			var dorsal := p.y > 0.0
			# follow the knuckle arc near the knuckles
			p.z += pow(v, 3.0) * (_knuckle_z(p.x) + 0.088)
			if dorsal:
				# knuckles stand out; tendons run down the back of the hand toward them
				for n in FINGER_ORDER:
					var mx: float = (FINGERS[n].mcp as Vector3).x
					p.y += 0.0036 * smoothstep(0.78, 1.0, v) * exp(-pow((p.x - mx) / 0.0065, 2.0))
					var tx: float = lerpf((FINGERS[n].base as Vector3).x, mx, v)
					p.y += 0.0011 * smoothstep(0.25, 0.6, v) * (1.0 - smoothstep(0.85, 1.0, v)) * exp(-pow((p.x - tx) / 0.003, 2.0))
			else:
				# thenar (thumb side) and hypothenar (little-finger side) pads
				var th := sin(clampf((v - 0.08) / 0.62, 0.0, 1.0) * PI) * (1.0 - smoothstep(0.0, 0.45, u))
				p.y -= 0.009 * th; p.x -= 0.004 * th
				var hy := sin(clampf((v - 0.1) / 0.75, 0.0, 1.0) * PI) * smoothstep(0.6, 1.0, u)
				p.y -= 0.005 * hy; p.x += 0.002 * hy
			ring[j] = p
			# weights: forearm twist at the wrist, the hand, then the metacarpals toward the knuckles
			var w := {}
			var wm := smoothstep(0.45, 0.95, v)
			var wh := 1.0 - wm
			var wt := 1.0 - smoothstep(0.0, 0.18, v)
			w["forearm_twist"] = wt * 0.5
			w["hand"] = wh * (1.0 - wt * 0.5)
			var tot := 0.0; var g := {}
			for n in FINGER_ORDER:
				var gx := exp(-pow((p.x - (FINGERS[n].mcp as Vector3).x) / 0.012, 2.0))
				g[n] = gx; tot += gx
			for n in FINGER_ORDER:
				w[n + "_meta"] = wm * g[n] / maxf(tot, 0.0001)
			if u < 0.25 and not dorsal:
				w["thumb_1"] = 0.35 * sin(clampf((v - 0.08) / 0.62, 0.0, 1.0) * PI) * (1.0 - u / 0.25)
			rw.append(w)
			var col := _skin_col((p.y) / (up_h if dorsal else dn_h))
			if not dorsal:
				# palm creases: distal transverse, proximal, and the thenar crease
				var crease := exp(-pow((v - 0.82 + u * 0.06) / 0.025, 2.0)) + exp(-pow((v - 0.6 + (1.0 - u) * 0.05) / 0.025, 2.0)) * (1.0 - u)
				col = col.darkened(0.12 * minf(crease, 1.0))
			else:
				# veins, faintly blue, over the back of the hand; a few age spots
				var vein := exp(-pow((p.x + 0.004 - sin(v * 5.0) * 0.006) / 0.0025, 2.0)) * smoothstep(0.1, 0.5, v) * (1.0 - smoothstep(0.7, 0.9, v))
				col = col.lerp(Color(0.82, 0.86, 0.98), 0.35 * vein)
				if (i * 7 + j * 3) % 23 == 0 and v > 0.2 and v < 0.85:
					col = col * Color(0.86, 0.74, 0.62)
			rc.append(col)
		rings.append(ring); wts.append(rw); cols.append(rc)
	_loft(rings, wts, cols, 0.25, true, true)

func _knuckle_z(x: float) -> float:
	# the knuckle arc, interpolated across the four MCP positions
	var pts := []
	for n in FINGER_ORDER:
		pts.append(FINGERS[n].mcp)
	if x <= pts[0].x: return pts[0].z
	for i in pts.size() - 1:
		if x <= pts[i + 1].x:
			return lerpf(pts[i].z, pts[i + 1].z, (x - pts[i].x) / (pts[i + 1].x - pts[i].x))
	return pts[-1].z

# ------------------------------------------------------------------ fingers
## A finger is one tube from inside the palm to the tip, its rings skinned across the joints so
## the skin bends over a knuckle instead of breaking at it.
func _finger(n: String) -> void:
	var f: Dictionary = FINGERS[n]
	var L: Array = f.len
	var d := finger_dir(n)
	var bas := frame(d, Vector3.UP)
	_digit(n + "_meta", [n + "_1", n + "_2", n + "_3"], f.mcp, d, bas.x, bas.z, L, f.r, 0.012)

func _thumb() -> void:
	var td := thumb_dirs()
	var b1 := frame(td[0], THUMB_NAIL_UP)
	var b2 := frame(td[1], THUMB_NAIL_UP)
	# the metacarpal: a fleshy tube from inside the thenar pad to the MCP joint
	var rings := []; var wts := []; var cols := []
	var mlen := (THUMB_MCP - THUMB_CMC).length()
	for s in [-0.006, 0.006, mlen * 0.45, mlen - 0.006]:
		var r := lerpf(0.016, 0.0122, clampf(s / mlen, 0.0, 1.0))
		var ring := _section(THUMB_CMC + td[0] * s, b1.x, b1.z, r * 1.05, r * 0.85, r * 1.05, 10, 2.2)
		rings.append(ring)
		var rw := []; var rc := []
		for p in ring:
			rw.append({"thumb_1": 1.0 if s > 0.0 else 0.6, "hand": 0.0 if s > 0.0 else 0.4})
			rc.append(_skin_col((p - (THUMB_CMC + td[0] * s)).dot(b1.z) / r))
		wts.append(rw); cols.append(rc)
	_loft(rings, wts, cols, 0.25, true, false)
	_digit("thumb_1", ["thumb_2", "thumb_3"], THUMB_MCP, td[1], b2.x, b2.z, THUMB_LEN, THUMB_R, 0.008)

## Shared by fingers and thumb. `chain` are the phalanx bones after `root`; `start` is where the
## first phalanx begins; the tube starts `inset` back inside the hand.
func _digit(root: String, chain: Array, start: Vector3, d: Vector3, x_axis: Vector3, nail_axis: Vector3, L: Array, r0: float, inset: float) -> void:
	var joints := [0.0]
	for k in L.size(): joints.append(joints[-1] + float(L[k]))
	var total: float = joints[-1]
	var samples := [-inset, -0.003, 0.004]
	for k in L.size():
		var a: float = joints[k]; var b: float = joints[k + 1]
		samples.append_array([lerpf(a, b, 0.35), lerpf(a, b, 0.7), b - 0.003])
		if k < L.size() - 1:
			samples.append_array([b, b + 0.003])
	samples.append_array([total - 0.0035, total - 0.0012])
	var bones := [root] + chain
	var rings := []; var wts := []; var cols := []
	for s in samples:
		# radius: tapering toward the tip, a little fuller at the knuckles, closing over the tip
		var taper := lerpf(1.0, 0.8, clampf(s / total, 0.0, 1.0))
		var knuckle := 0.0
		for k in range(1, joints.size() - 1):
			knuckle += 0.06 * exp(-pow((s - joints[k]) / 0.0035, 2.0))
		var r := r0 * (taper + knuckle)
		if s > total - 0.005:
			r *= sqrt(clampf((total - s) / 0.005, 0.12, 1.0))
		var pad := 1.0 + 0.12 * smoothstep(joints[-2], joints[-2] + float(L[-1]) * 0.5, s)   # the fleshy fingertip pad
		var c: Vector3 = start + d * s
		var ring := _section(c, x_axis, nail_axis, r * 1.05, r * 0.86, r * 0.98 * pad, 9, 2.3)
		rings.append(ring)
		# weights: across the nearest joint, a blend over ±5 mm between the bone before it and the
		# bone after it (joint k sits between bones[k] and bones[k+1]); away from joints, one bone
		var jj := 0
		for k in L.size():
			if absf(s - float(joints[k])) < absf(s - float(joints[jj])):
				jj = k
		var t := smoothstep(-0.005, 0.005, s - float(joints[jj]))
		var w := {}
		w[bones[jj]] = 1.0 - t
		w[bones[jj + 1]] = t
		var rw := []; var rc := []
		for p in ring:
			rw.append(w)
			var dorsal: float = (p - c).dot(nail_axis) / r
			var col := _skin_col(dorsal)
			# knuckle creases: darker over the back of each joint, lines across the palm side
			for k in range(1, joints.size() - 1):
				var near := exp(-pow((s - joints[k]) / 0.0025, 2.0))
				col = col.darkened((0.14 if dorsal > 0.0 else 0.18) * near)
			rc.append(col)
		wts.append(rw); cols.append(rc)
	_loft(rings, wts, cols, 0.25, false, true)

## A nail: a slightly curved plate on the back of the last phalanx, ridged and yellowed with age.
func _nail(bone: String, joint: Vector3, d: Vector3, up: Vector3, seg_len: float, half_w: float) -> void:
	var bas := frame(d, up)
	var grid := []
	var NU := 4; var NV := 3
	for i in NV + 1:
		var row := []
		var s := lerpf(seg_len * 0.38, seg_len * 0.98, float(i) / NV)
		for j in NU + 1:
			var u := lerpf(-1.0, 1.0, float(j) / NU)
			var p := joint + bas.y * s + bas.x * u * half_w + bas.z * (half_w * 0.95 - u * u * half_w * 0.35 + 0.0007)
			row.append(_v(p, Vector2(float(j) / NU, float(i) / NV), {bone: 1.0}, Color(1, 1, 1)))
		grid.append(row)
	for i in NV:
		for j in NU:
			var a: int = grid[i][j]; var b: int = grid[i][j + 1]; var c: int = grid[i + 1][j + 1]; var e: int = grid[i + 1][j]
			_st.add_index(a); _st.add_index(b); _st.add_index(c)
			_st.add_index(a); _st.add_index(c); _st.add_index(e)

# ------------------------------------------------------------------ clothing
func _sleeve() -> void:
	# a wool coat sleeve from the shoulder to a hand's width above the wrist, with a turned edge
	var rings := []; var wts := []; var cols := []
	var zs := [FOREARM + UPPER + 0.02, FOREARM + UPPER * 0.6, FOREARM + 0.06, FOREARM, FOREARM - 0.05, 0.16, 0.1, 0.062, 0.05]
	for z in zs:
		var k := clampf(z / FOREARM, 0.0, 2.3)
		var hw := 0.05 + 0.012 * minf(k, 1.6)
		var hh := 0.046 + 0.010 * minf(k, 1.6)
		var ring := _section(Vector3(0, -0.003, z), Vector3.RIGHT, Vector3.UP, hw, hh, hh * 1.08, 14, 2.1)
		# folds at the elbow, bunching above the cuff
		for j in ring.size():
			var p: Vector3 = ring[j]
			p += (p - Vector3(0, -0.003, z)).normalized() * (0.004 * sin(j * 2.2 + z * 60.0) * (exp(-pow((z - FOREARM) / 0.04, 2.0)) + 0.5 * exp(-pow((z - 0.08) / 0.03, 2.0))))
			ring[j] = p
		rings.append(ring)
		var w := _arm_weights(z)
		var rw := []; var rc := []
		for p in ring: rw.append(w); rc.append(Color(1, 1, 1).darkened(0.12 * float(p.y < -0.02)))
		wts.append(rw); cols.append(rc)
	# the turned edge: back in along the inside so the opening has thickness
	var last: Array = rings[-1]
	var inner := []
	for p in last:
		inner.append(Vector3(p.x * 0.86, -0.003 + (p.y + 0.003) * 0.86, 0.058))
	rings.append(inner); wts.append(wts[-1]); cols.append(cols[-1].map(func(c): return c.darkened(0.5)))
	_loft(rings, wts, cols, 0.5, true, false)

func _cuff() -> void:
	var rings := []; var wts := []; var cols := []
	for z in [0.07, 0.044, 0.036]:
		var ring := _section(Vector3(0, -0.002, z), Vector3.RIGHT, Vector3.UP, 0.036, 0.026, 0.028, 14, 2.3)
		rings.append(ring)
		var rw := []; var rc := []
		for p in ring: rw.append(_arm_weights(z)); rc.append(Color(1, 1, 1))
		wts.append(rw); cols.append(rc)
	_loft(rings, wts, cols, 0.3, false, false)

func _arm_weights(z: float) -> Dictionary:
	if z > FOREARM - 0.02:
		var t := smoothstep(FOREARM - 0.02, FOREARM + 0.04, z)
		return {"upper_arm": t, "forearm": 1.0 - t}
	var tw := 1.0 - smoothstep(0.03, 0.22, z)
	return {"forearm": 1.0 - tw, "forearm_twist": tw}

# ================================================================== posing
func _process(delta: float) -> void:
	_t += delta
	var want: Dictionary = POSES.get(pose_name, POSES.relaxed)
	var k := minf(1.0, delta * blend_speed)
	for key in want:
		var a: Array = cur[key]; var b: Array = want[key]
		for i in a.size():
			# the ring and little fingers follow a beat behind (they share tendons and stiffen first)
			var kk := k * (0.75 if key in ["ring", "little"] else 1.0)
			a[i] = lerpf(a[i], float(b[i]), kk)
	var p := cur
	if idle:
		p = _idle_layer(delta)
	_apply_pose(p)

## Idle on top of the pose: slow drift, a fine tremor, and now and then the stiff hand being
## worked: closed most of the way, held, opened again, the last two fingers lagging.
func _idle_layer(delta: float) -> Dictionary:
	var out := {}
	var flex_amt := 0.0
	if _flex_t < 0.0:
		_next_flex -= delta
		if _next_flex <= 0.0 and pose_name == "relaxed":
			_flex_t = 0.0
	else:
		_flex_t += delta
		flex_amt = smoothstep(0.0, 1.3, _flex_t) * (1.0 - smoothstep(1.9, 3.6, _flex_t))
		if _flex_t > 3.8:
			_flex_t = -1.0; _next_flex = randf_range(9.0, 16.0)
	for key in cur:
		var a: Array = cur[key]
		var o := a.duplicate()
		var phase := float(hash(key) % 100) * 0.13
		for i in o.size():
			var drift := sin(_t * 0.31 + phase + i) * 2.2 + sin(_t * 0.73 + phase * 2.0) * 1.1
			var tremor := sin(_t * 57.0 + phase * 9.0 + i) * 0.25
			o[i] = float(o[i]) + (drift + tremor) * (0.0 if i == 3 else 1.0)
			if flex_amt > 0.0 and POSES.stiff_flex.has(key):
				var lag := 0.82 if key in ["ring", "little"] else 1.0
				o[i] = lerpf(o[i], float(POSES.stiff_flex[key][i]), flex_amt * lag)
		out[key] = o
	return out

func _q(axis: Vector3, deg: float) -> Quaternion:
	return Quaternion(axis, deg_to_rad(deg))

func _rest_q(bone: String) -> Quaternion:
	return skeleton.get_bone_rest(B[bone]).basis.get_rotation_quaternion()

func _clamp(v: float, lim: String) -> float:
	return clampf(v, LIM[lim][0], LIM[lim][1])

func _apply_pose(p: Dictionary) -> void:
	for n in FINGER_ORDER:
		var a: Array = p[n]
		var mcp := _clamp(a[0], "mcp"); var pip := _clamp(a[1], "pip"); var dip := _clamp(a[2], "dip"); var spr := _clamp(a[3], "spread")
		var cup: float = FINGERS[n].cup
		skeleton.set_bone_pose_rotation(B[n + "_meta"], _rest_q(n + "_meta") * _q(Vector3.RIGHT, -mcp * cup))
		skeleton.set_bone_pose_rotation(B[n + "_1"], _rest_q(n + "_1") * _q(Vector3.BACK, -spr) * _q(Vector3.RIGHT, -mcp * (1.0 - cup)))
		skeleton.set_bone_pose_rotation(B[n + "_2"], _rest_q(n + "_2") * _q(Vector3.RIGHT, -pip))
		skeleton.set_bone_pose_rotation(B[n + "_3"], _rest_q(n + "_3") * _q(Vector3.RIGHT, -dip))
	var t: Array = p.thumb
	# CMC, in the hand's frame (that's how the joint moves): flexion sweeps the thumb across the
	# palm toward the little finger (about the hand's up axis); palmar abduction lifts it out of
	# the palm's plane (about the hand's long axis). Opposition rolls the thumb on its own axis
	# as it comes round, so the pad turns to face the fingers.
	var to_local := rest_g.thumb_1.basis.inverse() as Basis
	var flex := _clamp(t[0], "t_flex"); var abd := _clamp(t[1], "t_abd")
	var q_hand := _q(to_local * Vector3.BACK, abd) * _q(to_local * Vector3.UP, -flex)
	skeleton.set_bone_pose_rotation(B.thumb_1, _rest_q("thumb_1") * q_hand * _q(Vector3.UP, -(abd * 0.35 + flex * 0.4)))
	skeleton.set_bone_pose_rotation(B.thumb_2, _rest_q("thumb_2") * _q(Vector3.RIGHT, -_clamp(t[2], "t_mcp")))
	skeleton.set_bone_pose_rotation(B.thumb_3, _rest_q("thumb_3") * _q(Vector3.RIGHT, -_clamp(t[3], "t_ip")))
	# wrist and forearm (when the arm isn't being placed by IK)
	if not _ik_driven:
		skeleton.set_bone_pose_rotation(B.forearm_twist, _rest_q("forearm_twist") * _q(Vector3.UP, _clamp(pronation, "pron")))
		skeleton.set_bone_pose_rotation(B.hand, _rest_q("hand") * _q(Vector3.BACK, -_clamp(wrist.y, "w_dev")) * _q(Vector3.RIGHT, -_clamp(wrist.x, "w_flex")))

# ================================================================== first person: two-bone IK
var _ik_driven := false

## Places the whole arm (in this node's space) so the hand's wrist sits at `wrist_xf.origin` with
## the hand oriented by `wrist_xf.basis` (Y toward the fingers, Z out of the back of the hand),
## the shoulder at `shoulder`, and the elbow bending toward `pole`. Lengths are the anatomical
## ones; out-of-reach targets are pulled back onto the reachable sphere.
func solve_arm(shoulder: Vector3, wrist_xf: Transform3D, pole: Vector3) -> void:
	_ik_driven = true
	var w := wrist_xf.origin
	var to := w - shoulder
	var dist := clampf(to.length(), 0.12, UPPER + FOREARM - 0.004)
	var dir := to.normalized()
	w = shoulder + dir * dist
	var cos_a := clampf((UPPER * UPPER + dist * dist - FOREARM * FOREARM) / (2.0 * UPPER * dist), -1.0, 1.0)
	var bend := (pole - dir * pole.dot(dir)).normalized()
	var elbow := shoulder + dir * (UPPER * cos_a) + bend * (UPPER * sqrt(1.0 - cos_a * cos_a))
	var hand_back := wrist_xf.basis.z
	var f_dir := (w - elbow).normalized()
	var f_up := (hand_back - f_dir * hand_back.dot(f_dir)).normalized()
	var u_dir := (elbow - shoulder).normalized()
	var u_up := (f_up - u_dir * f_up.dot(u_dir)).normalized()
	skeleton.set_bone_global_pose(B.upper_arm, Transform3D(frame(u_dir, u_up), shoulder))
	skeleton.set_bone_global_pose(B.forearm, Transform3D(frame(f_dir, f_up), elbow))
	skeleton.set_bone_global_pose(B.forearm_twist, Transform3D(frame(f_dir, f_up), elbow.lerp(w, 0.5)))
	skeleton.set_bone_global_pose(B.hand, Transform3D(frame(wrist_xf.basis.y, hand_back), w))

## The middle of the palm in arm space, on the palm side: where a held thing sits.
func palm_point() -> Vector3:
	var h := skeleton.get_bone_global_pose(B.hand)
	return h * Vector3(0.004, 0.058, -0.03)      # bone frame: Y along the fingers, -Z the palm side
