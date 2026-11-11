class_name SockRig
extends Node3D
## Socko's body: the protagonist's left forearm and hand, and the sock over them, as one skinned
## mesh on one skeleton. There is no separate puppet: the sock's vertices are weighted to the
## bones of the hand inside it, so whatever the hand does, the fabric does.
##
##   forearm ── hand (wrist) ─┬─ fingers ── fingertips     upper jaw: the four fingers together
##                            └─ thumb ──── thumbtip       lower jaw: the thumb under them
##
## The mouth is the gap between fingers and thumb. The sock's toe is pushed into it, so the upper
## and lower halves of the head are one piece of cloth that splits along a line from the web of
## the thumb round the front; the cloth between them folds into the mouth as a dark pocket that
## stretches open when the hand does. Near the corners the fabric is weighted to both jaws, so a
## wide mouth pulls the cheeks in instead of hinging like a toy's. Rig space: the forearm runs
## along -Z from the elbow at the origin, palm down, +Y up.
##
## Pose inputs (set every frame by Socko, the controller): wrist (pitch, yaw, roll in radians),
## jaw (0 shut .. 1 wide; above 1 is more than a hand can do), skew (one side of the mouth wider),
## curl (-1 fingers stretched .. 1 a fist: the head folds in), squash (-1 tense .. 1 slumped),
## stretch (-1 pulled short .. 1 drawn out long and tall), twist (-1..1 the head wrung round the
## arm), and the corners of the mouth: smile_l / smile_r (-1 down .. 1 up, his left and right),
## wide (corners pulled back) and pucker (corners pursed in). The corners are two small bones in the
## cheeks (the puppeteer's knuckles pushing the cloth), so a smile is geometry, not a texture.
##
## The eyes are two ping-pong balls glued on top, each with a craft-store googly eye (a black rim,
## a clear dome, a loose pupil) stuck on it. The balls ride the cloth exactly: their seat on the
## head is skinned on the CPU with the same weights as the sock's vertices there, so they follow
## squash, stretch and the jaw without drifting, sinking in or sliding into each other. Each googly
## eye turns on its ball on its own (eye_targets / eye_rates): two eyes, two opinions.

enum B { FOREARM, HAND, FINGERS, FINGERTIPS, THUMB, THUMBTIP, CORNER_L, CORNER_R }
const BONE_NAMES := ["forearm", "hand", "fingers", "fingertips", "thumb", "thumbtip", "corner_l", "corner_r"]

const FOREARM_LEN := 0.27
const ZW := -0.27            # wrist
const ZC := -0.322           # back of the mouth: the web between thumb and index finger
const HEAD_LEN := 0.08       # from the mouth's corners to the tip of the nose
const A := 0.047             # half-width of the head
const H_UP := 0.040          # height of the upper jaw above the mouth line (fingers and knuckles)
const H_DN := 0.030          # depth of the lower jaw (the thumb)
const CUFF := -0.075         # where the sock's top ends on the forearm
const SLEEVE_END := -0.095   # the coat cuff, over the sock top

var skel: Skeleton3D
var sock: MeshInstance3D
var sleeve: MeshInstance3D
var mouth_mat: ShaderMaterial   # the inside of the mouth (it glows when the torch is in there)
var eyes: Array = []         # see _eyes(): root, ball, disc (the googly eye), pupil, p, v, ...
var sock_mat: ShaderMaterial   # the sock's cloth (its stain layers are set here)

var wrist := Vector3.ZERO
var jaw := 0.0
var skew := 0.0
var curl := 0.0
var squash := 0.0
var stretch := 0.0
var twist := 0.0
var smile_l := 0.0
var smile_r := 0.0
var wide := 0.0
var pucker := 0.0
# the eyes: where each googly eye looks (a world point, or null for straight ahead) and how fast it
# gets there (1/s). `eye_hold` 0..1 per eye: the pupil holds dead centre against gravity (wrong:
# layer D, no googly eye can do it). `pupil_gain` scales the loose pupils' inertia (test bench).
var eye_targets: Array = [null, null]
var eye_rates: Array = [14.0, 11.0]
var eye_hold: Array = [0.0, 0.0]
var pupil_gain := 1.0

const CLOTH := preload("res://shaders/ps1_cloth.gdshader")

func _ready() -> void:
	_skeleton()
	sock = _skinned("Sock")
	sock.mesh = _build_sock()
	sleeve = _skinned("Sleeve")
	sleeve.mesh = _build_sleeve()
	_eyes()
	apply_pose()

# ---------------------------------------------------------------- skeleton
func _skeleton() -> void:
	skel = Skeleton3D.new(); skel.name = "Skeleton"
	add_child(skel)
	var rests := [
		Transform3D(Basis(), Vector3.ZERO),
		Transform3D(Basis(), Vector3(0, 0, ZW)),
		Transform3D(Basis(), Vector3(0, 0.009, ZC - ZW)),
		Transform3D(Basis(), Vector3(0, 0, -0.042)),
		Transform3D(Basis(), Vector3(0, -0.011, ZC - ZW + 0.012)),
		Transform3D(Basis(), Vector3(0, 0, -0.036)),
		Transform3D(Basis(), Vector3(-A, 0, ZC - ZW)),     # his left mouth corner
		Transform3D(Basis(), Vector3(A, 0, ZC - ZW)),      # his right
	]
	var parents := [-1, 0, 1, 2, 1, 4, 1, 1]
	for i in BONE_NAMES.size():
		skel.add_bone(BONE_NAMES[i])
		skel.set_bone_parent(i, parents[i])
		skel.set_bone_rest(i, rests[i])
		skel.set_bone_pose(i, rests[i])

func _skinned(n: String) -> MeshInstance3D:
	var m := MeshInstance3D.new(); m.name = n
	skel.add_child(m)
	m.skeleton = NodePath("..")
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # it's at the lens: no shadow to cast onto anything you'd see
	return m

func bone_global(b: int) -> Transform3D:
	return skel.global_transform * skel.get_bone_global_pose(b)

## Between the jaws, just inside the lips, facing out of the mouth: where light comes from.
func mouth_global() -> Transform3D:
	var f := bone_global(B.FINGERS); var t := bone_global(B.THUMB)
	var o := f.origin.lerp(t.origin, 0.5)
	var b := Basis(f.basis.get_rotation_quaternion().slerp(t.basis.get_rotation_quaternion(), 0.5))
	return Transform3D(b, o + b * Vector3(0, 0, -0.03))

## Where the head is (between the jaws, a little behind the nose), and which way the mouth faces.
func head_global() -> Transform3D:
	return bone_global(B.FINGERS).translated_local(Vector3(0, -0.012, -0.035))

func apply_pose() -> void:
	if not skel:
		return
	var rest := skel.get_bone_rest(B.HAND)
	var sq := clampf(squash, -1.0, 1.0)
	var st := clampf(stretch, -1.0, 1.0)
	var tw := clampf(twist, -1.0, 1.0)
	skel.set_bone_pose_rotation(B.HAND, Quaternion(Basis.from_euler(Vector3(wrist.x, wrist.y, wrist.z + tw * 0.3), EULER_ORDER_YXZ)))
	skel.set_bone_pose_position(B.HAND, rest.origin)
	# slump: the cloth sags lower and wider; tense: drawn in and taller. Stretch: the hand reaches
	# out inside the sock, long and thin (volume roughly kept: what cloth over a hand can do)
	var sc_sq := Vector3(1.0 + sq * 0.07, 1.0 - sq * 0.13, 1.0 + sq * 0.03)
	var sc_st := Vector3(1.0 - st * 0.09, 1.0 + st * 0.1, 1.0 + st * 0.16) if st >= 0.0 else Vector3(1.0 - st * 0.08, 1.0 + st * 0.05, 1.0 + st * 0.12)
	skel.set_bone_pose_scale(B.HAND, sc_sq * sc_st)
	var j := clampf(jaw, -0.1, 1.6)
	var c := clampf(curl, -1.0, 1.0)
	# fingers lift from the knuckles and bend at the middle joint; the thumb drops from the web.
	# The fingers do more of the work (a puppeteer's thumb mostly holds still). Twist wrings the
	# two jaws against each other, a little.
	skel.set_bone_pose_rotation(B.FINGERS, Quaternion(Basis.from_euler(Vector3(j * 0.36 - c * 0.22, tw * 0.1, skew * 0.3 * j - tw * 0.22))))
	skel.set_bone_pose_rotation(B.FINGERTIPS, Quaternion(Basis.from_euler(Vector3(j * 0.1 - c * (0.3 if c > 0.0 else 0.42), 0, 0))))
	skel.set_bone_pose_rotation(B.THUMB, Quaternion(Basis.from_euler(Vector3(-j * 0.27 + c * 0.1, -tw * 0.08, -skew * 0.2 * j + tw * 0.2))))
	skel.set_bone_pose_rotation(B.THUMBTIP, Quaternion(Basis.from_euler(Vector3(-j * 0.08 + c * 0.2, 0, 0))))
	# the corners of the mouth: up (smile), down (frown), back (wide), in (pursed). Each side on
	# its own, so a smile can be lopsided.
	for side in [-1, 1]:
		var b: int = B.CORNER_L if side < 0 else B.CORNER_R
		var sm := clampf(smile_l if side < 0 else smile_r, -1.0, 1.0)
		var wd := clampf(wide, -1.0, 1.0); var rd := clampf(pucker, -1.0, 1.0)
		var off := Vector3(side * (wd * 0.007 - rd * 0.011 + absf(sm) * 0.002), sm * (0.017 if sm > 0.0 else 0.013) + wd * 0.002, wd * 0.006 - rd * 0.004 - absf(sm) * 0.004)
		skel.set_bone_pose_position(b, skel.get_bone_rest(b).origin + off)
	_place_eyes()

# ---------------------------------------------------------------- skin weights
## Bone weights for a point of cloth at rest position p. `shell`: 0 the tube (forearm, wrist,
## hand), 1 the upper half of the head, -1 the lower half. The same function weights every
## surface, so where two surfaces meet at the same point they move together (no cracks).
func _base_weights(p: Vector3, shell: int) -> Dictionary:
	var z := p.z
	var to_hand := smoothstep(ZW + 0.035, ZW - 0.03, z)
	var up_tube := smoothstep(-H_DN * 0.85, H_UP * 0.85, p.y)
	var split := smoothstep(ZC, ZC - 0.022, z)            # 0 at the corners: both halves agree
	var up := lerpf(up_tube, 1.0 if shell > 0 else (0.0 if shell < 0 else up_tube), split)
	var jaws := 0.5 * smoothstep(ZC + 0.045, ZC, z) + 0.5 * smoothstep(ZC, ZC - 0.02, z)
	var tip := smoothstep(ZC - 0.024, ZC - 0.066, z)
	var w := {}
	w[B.FOREARM] = 1.0 - to_hand
	w[B.HAND] = to_hand * (1.0 - jaws)
	var jw := to_hand * jaws
	w[B.FINGERS] = jw * up * (1.0 - tip)
	w[B.FINGERTIPS] = jw * up * tip
	w[B.THUMB] = jw * (1.0 - up) * (1.0 - tip)
	w[B.THUMBTIP] = jw * (1.0 - up) * tip
	return w

## The cloth's weights, plus the cheeks: around each corner of the mouth the cloth is pulled by
## that corner's bone (falling off over ~2 cm), so smiles and frowns move the fabric round it.
func weights(p: Vector3, shell: int) -> Dictionary:
	var w := _base_weights(p, shell)
	var cw := {}
	var total := 0.0
	for side in [-1, 1]:
		var d := p.distance_to(Vector3(side * A, 0.0, ZC))
		var k := 0.9 * exp(-pow(d / 0.022, 2.0)) * smoothstep(ZW - 0.005, ZW - 0.03, p.z)
		cw[B.CORNER_L if side < 0 else B.CORNER_R] = k
		total += k
	total = minf(total, 0.85)
	for key in w: w[key] = w[key] * (1.0 - total)
	for key in cw: w[key] = cw[key]
	return w

## The same top-four, normalised weights the mesh stores (so CPU skinning matches the GPU).
static func top4(w: Dictionary) -> Dictionary:
	var pairs := []
	for k in w:
		if w[k] > 0.0005: pairs.append([w[k], k])
	pairs.sort_custom(func(x, y): return x[0] > y[0])
	pairs = pairs.slice(0, 4)
	var sum := 0.0
	for pr in pairs: sum += pr[0]
	var out := {}
	for pr in pairs: out[pr[1]] = pr[0] / sum
	return out

## Where a point of cloth at rest position p (rig space) is now, in the world: linear blend
## skinning, exactly as the GPU does it for the sock.
func skin_point(p: Vector3, w: Dictionary) -> Vector3:
	var acc := Vector3.ZERO
	for b in w:
		acc += (skel.get_bone_global_pose(b) * (skel.get_bone_global_rest(b).affine_inverse() * p)) * float(w[b])
	return skel.global_transform * acc

static func mix_w(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var w := {}
	for key in a: w[key] = a[key] * (1.0 - k)
	for key in b: w[key] = w.get(key, 0.0) + b[key] * k
	return w

# ---------------------------------------------------------------- mesh building
class ClothSkin:
	var v := PackedVector3Array(); var uv := PackedVector2Array(); var bones := PackedInt32Array()
	var wts := PackedFloat32Array(); var idx := PackedInt32Array(); var out := []
	var nrm := PackedVector3Array()
	var uv2 := PackedVector2Array(); var col := PackedColorArray()   # stain map and stain hints

	func add(p: Vector3, t: Vector2, w: Dictionary, outward: Vector3, t2 := Vector2.ZERO, c := Color(0, 0, 0, 1)) -> int:
		var tw := SockRig.top4(w)
		var keys := tw.keys()
		for i in 4:
			if i < keys.size():
				bones.append(keys[i]); wts.append(tw[keys[i]])
			else:
				bones.append(0); wts.append(0.0)
		v.append(p); uv.append(t); out.append(outward); uv2.append(t2); col.append(c)
		return v.size() - 1

	## Quad a-b-c-d, wound so its front faces along the vertices' outward hint (Godot: clockwise).
	func quad(a: int, b: int, c: int, d: int) -> void:
		tri(a, b, c); tri(a, c, d)

	func tri(a: int, b: int, c: int) -> void:
		var n := (v[b] - v[a]).cross(v[c] - v[a])
		var o: Vector3 = out[a] + out[b] + out[c]
		if n.length_squared() < 1e-14:
			return
		if n.dot(o) > 0.0:
			idx.append_array([a, c, b])
		else:
			idx.append_array([a, b, c])

	func commit(mesh: ArrayMesh, material: Material) -> void:
		# smooth normals per surface, pointing the way the hints say is out
		nrm.resize(v.size())
		for i in v.size(): nrm[i] = Vector3.ZERO
		for i in range(0, idx.size(), 3):
			var a := idx[i]; var b := idx[i + 1]; var c := idx[i + 2]
			var n := (v[c] - v[a]).cross(v[b] - v[a])
			nrm[a] += n; nrm[b] += n; nrm[c] += n
		for i in v.size():
			nrm[i] = nrm[i].normalized() if nrm[i].length_squared() > 0.0 else (out[i] as Vector3).normalized()
		var arr := []; arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_NORMAL] = nrm; arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_BONES] = bones; arr[Mesh.ARRAY_WEIGHTS] = wts; arr[Mesh.ARRAY_INDEX] = idx
		arr[Mesh.ARRAY_TEX_UV2] = uv2; arr[Mesh.ARRAY_COLOR] = col
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)

## Cross-section of the tube at z: half-width, height above and depth below the axis.
func _profile(z: float) -> Vector3:
	const K := [  # z, half-width, up, down
		[0.0, 0.036, 0.033, 0.033], [ZW + 0.06, 0.032, 0.029, 0.029], [ZW, 0.029, 0.025, 0.026],
		[ZW - 0.022, 0.039, 0.030, 0.027], [ZC + 0.012, 0.0465, 0.039, 0.030], [ZC, A, H_UP, H_DN]]
	for i in K.size() - 1:
		var a: Array = K[i]; var b: Array = K[i + 1]
		if z <= a[0] and z >= b[0]:
			var k := smoothstep(0.0, 1.0, (a[0] - z) / (a[0] - b[0]))
			return Vector3(lerpf(a[1], b[1], k), lerpf(a[2], b[2], k), lerpf(a[3], b[3], k))
	return Vector3(A, H_UP, H_DN)

## Cloth isn't a tube: it bunches at the wrist and creases over the knuckles. Folds as a function
## of rest position, uneven on purpose.
func _fold(p: Vector3, th: float) -> float:
	var n := MeshKit.noise()
	var wrist_k := exp(-pow((p.z - (ZW + 0.01)) / 0.02, 2.0))
	var f := wrist_k * 0.0028 * (sin(th * 5.0 + p.z * 140.0) + 0.6 * sin(th * 9.0 - 1.3))
	f += 0.0012 * n.get_noise_3d(p.x * 60.0, p.y * 60.0, p.z * 60.0)
	return f

func _build_sock() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var sk := ClothSkin.new()
	const NB := 5                 # dome rows from mouth line to the top (and to the bottom)
	const SIDES := NB * 4         # tube sides: every dome row lands on a tube vertex at the corners
	const NA := 12                # around the mouth, corner to corner
	# ---- the tube, cuff to the corners of the mouth
	var zs := []
	var steps := 16
	for i in steps + 1:
		zs.append(lerpf(CUFF, ZC, pow(float(i) / steps, 0.85)))
	var rings := []
	for i in zs.size():
		var z: float = zs[i]
		var pr := _profile(z)
		var ring := []
		var flare := 0.003 * (1.0 - smoothstep(CUFF, CUFF - 0.012, z))   # the top's elastic, rolled
		for s in SIDES + 1:
			var th := TAU * float(s) / SIDES
			var cy := sin(th)
			var p := Vector3(pr.x * cos(th), (pr.y if cy > 0.0 else pr.z) * cy, z)
			var out := Vector3(p.x, p.y, 0.0).normalized()
			if i < zs.size() - 1:
				p += out * (_fold(p, th) + flare)
			var u := float(s) / SIDES
			var vv := (z - CUFF) / (ZC - HEAD_LEN - CUFF)
			ring.append(sk.add(p, Vector2(u, vv), weights(p, 0), out, Vector2(u, vv), _stain_hint(p, out)))
		rings.append(ring)
	for i in rings.size() - 1:
		for s in SIDES:
			sk.quad(rings[i][s], rings[i][s + 1], rings[i + 1][s + 1], rings[i + 1][s])
	# ---- the head: the front half of an ellipsoid split along the mouth line. Its back opening is
	# exactly the tube's last ring, so the two meet without a gap.
	var vtip := 1.0
	for half in [1, -1]:
		var h: float = H_UP if half > 0 else H_DN
		var g := []
		for ib in NB + 1:
			var beta := PI * 0.5 * float(ib) / NB
			var row := []
			for ia in NA + 1:
				var al := PI * (float(ia) / NA - 0.5)
				var p := Vector3(A * sin(al) * cos(beta), half * h * sin(beta), ZC - HEAD_LEN * cos(al) * cos(beta))
				var out := Vector3(p.x / A, p.y / h, (p.z - ZC) / HEAD_LEN).normalized()
				# a softer, rounder nose; the fingertips press a slight ridge into the top
				if half > 0:
					p.y += 0.003 * sin(beta * 2.0) * cos(al) * cos(al)
				var tz := (ZC - p.z) / HEAD_LEN
				var t := Vector2(0.5 + 0.5 * sin(al) * cos(beta), lerpf((ZC - CUFF) / (ZC - HEAD_LEN - CUFF), vtip, tz))
				# the stain map is wrapped round the arm's axis like the tube's, so it runs on over
				# the head without a seam
				var th2 := fposmod(atan2(p.y / h, p.x / A), TAU) / TAU if (absf(p.x) + absf(p.y)) > 1e-6 else (0.25 if half > 0 else 0.75)
				var t2 := Vector2(th2, (p.z - CUFF) / (ZC - HEAD_LEN - CUFF))
				row.append(sk.add(p, t, weights(p, half), out, t2, _stain_hint(p, out)))
			g.append(row)
		for ib in NB:
			for ia in NA:
				sk.quad(g[ib][ia], g[ib][ia + 1], g[ib + 1][ia + 1], g[ib + 1][ia])
	sock_mat = _cloth_mat()
	sock_mat.set_shader_parameter("stain_tex", _stain_tex())
	sock_mat.set_shader_parameter("stain_amount", 1.0)
	sk.commit(mesh, sock_mat)
	# ---- the inside of the mouth: a felt mouth plate glued under the upper jaw (the palate) and
	# another over the lower jaw (the floor), folded together at the hinge between the corners, like
	# a real sock puppet's. Each plate is skinned to its own jaw, so opening the mouth shows a felt
	# mouth (palate, floor, tongue) and not a membrane sagging between the jaws into a pit. The
	# palate arches up into the head a little and the floor cups down into the chin, both inside
	# the shells. Shut, the two lie flat on each other out of sight.
	var pk := ClothSkin.new()
	const R := 8
	const HALF := R / 2
	var pg := []
	for r in R + 1:
		var k := float(r) / R                       # 0 upper lip .. 0.5 the hinge .. 1 lower lip
		var upper := r <= HALF
		var sgn := 1.0 if upper else -1.0
		var s := float(r) / HALF if upper else float(R - r) / HALF   # 0 at the lip .. 1 at the hinge
		var row := []
		for ia in NA + 1:
			var al := PI * (float(ia) / NA - 0.5)
			var e := Vector3(A * sin(al), 0.0, ZC - HEAD_LEN * cos(al))
			var h: float = H_UP if upper else H_DN
			var arch := (0.2 if upper else 0.17) * h * cos(al) * sin(PI * 0.5 * s)
			var p := Vector3(e.x, sgn * (0.0012 * (1.0 - s) + arch), ZC + (e.z - ZC) * (1.0 - s))
			var w := weights(p, 1 if upper else -1)
			var n := Vector3(0, -sgn, 0) + Vector3(0, 0, ZC - p.z) * 3.0
			row.append(pk.add(p, Vector2(float(ia) / NA, k), w, n.normalized()))
		pg.append(row)
	for r in R:
		for ia in NA:
			pk.quad(pg[r][ia], pg[r][ia + 1], pg[r + 1][ia + 1], pg[r + 1][ia])
	mouth_mat = _mouth_mat()
	pk.commit(mesh, mouth_mat)
	# ---- the red felt tongue, stitched to the lower jaw
	var tg := ClothSkin.new()
	var tc := Vector3(0, -0.0035, ZC - 0.036); var tr := Vector3(0.02, 0.0045, 0.03)
	var tw := weights(tc + Vector3(0, -0.01, 0), -1)
	var tgrid := []
	for i in 7:
		var ph := PI * float(i) / 6
		var row := []
		for j in 11:
			var th := TAU * float(j) / 10
			var dir := Vector3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th))
			var p := tc + dir * tr
			p.y -= 0.002 * pow(dir.z, 2.0)   # it curls down at the tip
			row.append(tg.add(p, Vector2(float(j) / 10, float(i) / 6), tw, dir))
		tgrid.append(row)
	for i in 6:
		for j in 10:
			tg.quad(tgrid[i][j], tgrid[i][j + 1], tgrid[i + 1][j + 1], tgrid[i + 1][j])
	tg.commit(mesh, _felt_mat(Color("d0402e"), 0.3))
	return mesh

## Per-vertex hints for the stain layers (they skin with the cloth): r how much the cloth faces
## down at rest (what soaks and drips gathers there: urine), g how near a seam or fold it is (the
## cuff, the wrist's bunching, the mouth line, where mould starts).
func _stain_hint(p: Vector3, outward: Vector3) -> Color:
	var lower := smoothstep(0.15, -0.75, outward.normalized().y)
	var seam := exp(-pow((p.z - CUFF) / 0.012, 2.0))
	seam = maxf(seam, 0.7 * exp(-pow((p.z - (ZW + 0.01)) / 0.014, 2.0)))
	seam = maxf(seam, smoothstep(ZC + 0.01, ZC - 0.01, p.z) * exp(-pow(p.y / 0.006, 2.0)))
	return Color(lower, seam, 0.0, 1.0)

func _build_sleeve() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var sk := ClothSkin.new()
	const SIDES := 12
	var zs := [0.09, 0.0, -0.06, SLEEVE_END, SLEEVE_END + 0.002]
	var rs := [0.058, 0.054, 0.05, 0.047, 0.04]   # last ring: the cuff turns in
	var rings := []
	for i in zs.size():
		var ring := []
		for s in SIDES + 1:
			var th := TAU * float(s) / SIDES
			var p := Vector3(rs[i] * cos(th) * 1.05, rs[i] * sin(th) * 0.95, zs[i])
			p += Vector3(cos(th), sin(th), 0) * 0.002 * sin(th * 3.0 + i)
			var w := {B.FOREARM: 1.0}
			ring.append(sk.add(p, Vector2(float(s) / SIDES, float(i) / zs.size()), w, Vector3(cos(th), sin(th), 0)))
		rings.append(ring)
	for i in rings.size() - 1:
		for s in SIDES:
			sk.quad(rings[i][s], rings[i][s + 1], rings[i + 1][s + 1], rings[i + 1][s])
	var m := _cloth_mat(); m.set_shader_parameter("albedo_tex", _wool_tex()); m.set_shader_parameter("fuzz", 0.08)
	sk.commit(mesh, m)
	return mesh

# ---------------------------------------------------------------- materials (procedural, PS1-sized)
func _cloth_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = CLOTH
	m.set_shader_parameter("albedo_tex", _sock_tex())
	m.set_shader_parameter("fuzz", 0.16)
	return m

## The mouth's lining: muted red felt at the lips, deepening toward the hinge (v: upper lip 0 →
## hinge 0.5 → lower lip 1), so an open mouth reads as a felt mouth, not a hole or a lamp.
func _mouth_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = CLOTH
	var img := Image.create(8, 16, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new(); rng.seed = 77
	for y in 16:
		var k := absf((y + 0.5) / 16.0 - 0.5) * 2.0          # 1 at the lips, 0 in the throat
		var c := Color("3a1214").lerp(Color("7a2a27"), smoothstep(0.0, 0.85, k))
		for x in 8:
			img.set_pixel(x, y, c * (0.9 + rng.randf() * 0.2))
	m.set_shader_parameter("albedo_tex", ImageTexture.create_from_image(img))
	m.set_shader_parameter("fuzz", 0.12)
	return m

func _felt_mat(c: Color, fuzz: float) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = CLOTH
	var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new(); rng.seed = int(c.r * 1000)
	for y in 8:
		for x in 8:
			img.set_pixel(x, y, c * (0.85 + rng.randf() * 0.3))
	m.set_shader_parameter("albedo_tex", ImageTexture.create_from_image(img))
	m.set_shader_parameter("fuzz", fuzz)
	return m

static var _sock_cache: Texture2D
## A grubby off-white tube sock: ribbed, greyer at the heel of the hand where it's been handled,
## brown at the toe, two stripes (red, blue) at the top. 32 x 64.
static func _sock_tex() -> Texture2D:
	if _sock_cache: return _sock_cache
	const W := 32; const HH := 64
	var img := Image.create(W, HH, false, Image.FORMAT_RGB8)
	var n := MeshKit.noise()
	var base := Color("b9b19b")
	for y in HH:
		for x in W:
			var c := base
			if x % 2 == 0: c = c.darkened(0.07)            # rib
			var d := n.get_noise_2d(x * 0.35, y * 0.25) * 0.5 + 0.5
			c = c.lerp(Color("675d49"), smoothstep(0.45, 0.9, d) * 0.6)   # grime
			var v := float(y) / HH
			c = c.lerp(Color("5c5040"), smoothstep(0.82, 1.0, v) * 0.5)   # the toe, dirtiest
			if y >= 4 and y < 6: c = Color("9a2620")       # red stripe
			elif y >= 7 and y < 9: c = Color("2a3a78")     # blue stripe
			elif y < 3: c = c.darkened(0.12)               # the top's elastic
			img.set_pixel(x, y, c)
	_sock_cache = ImageTexture.create_from_image(img)
	return _sock_cache

static func _wool_tex() -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	var n := MeshKit.noise()
	for y in 16:
		for x in 16:
			var k := n.get_noise_2d(x * 0.9 + 40.0, y * 0.9) * 0.5 + 0.5
			img.set_pixel(x, y, Color("2b2925").lerp(Color("3d3a33"), k))
	return ImageTexture.create_from_image(img)

# ---------------------------------------------------------------- stains
static var _stain_cache: Texture2D
## The stain layers, in the stain map (UV2: round the arm, cuff to nose), 64 x 128:
##   r  old blood: faded reddish-brown blotches with irregular, absorbed edges and darker cores
##      (round the mouth and chin, a washed-out wash under the forearm, a run back from the chin,
##      a few flecks by his right eye)
##   g  mould: patchy, grows from the seams and folds (the shader adds the seam hint), speckled
##   b  urine: broad, uneven, tide-marked patches, under the arm and the chin (the shader keeps it
##      to the faces that point down)
##   a  fine speckle noise, for the mould's spotting
## Deterministic (fixed seed), so the same sock every run.
static func _stain_tex() -> Texture2D:
	if _stain_cache: return _stain_cache
	const W := 64; const HH := 128
	var img := Image.create(W, HH, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new(); n.seed = 4747; n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_type = FastNoiseLite.FRACTAL_FBM; n.fractal_octaves = 4; n.frequency = 1.0
	var rng := RandomNumberGenerator.new(); rng.seed = 1947
	# blotches: [u, v, half-width u, half-height v, strength]
	var blood := [[0.75, 0.88, 0.12, 0.07, 0.95], [0.46, 0.79, 0.035, 0.03, 0.9], [0.70, 0.43, 0.11, 0.13, 0.5],
		[0.92, 0.95, 0.05, 0.035, 0.7], [0.05, 0.62, 0.05, 0.06, 0.4]]
	var urine := [[0.76, 0.33, 0.17, 0.2, 0.8], [0.68, 0.84, 0.13, 0.08, 0.6], [0.88, 0.62, 0.08, 0.1, 0.55]]
	for y in HH:
		for x in W:
			var u := (x + 0.5) / W; var v := (y + 0.5) / HH
			# noise on a cylinder, so it wraps round the arm without a seam
			var cx := cos(u * TAU) * 1.6; var cy := sin(u * TAU) * 1.6; var cz := v * 6.0
			var warp := n.get_noise_3d(cx * 1.3, cy * 1.3, cz * 1.3)
			var b := 0.0
			for bl in blood:
				var du := _wrap_d(u - float(bl[0])) / float(bl[2]); var dv := (v - float(bl[1])) / float(bl[3])
				var d := sqrt(du * du + dv * dv) + warp * 0.45
				var a := (1.0 - smoothstep(0.55, 1.0, d)) * float(bl[4])
				# dried blood: a darker tide line at the edge and dark clots inside
				var tide := exp(-pow((d - 0.82) / 0.09, 2.0)) * 0.35
				var clot := smoothstep(0.35, 0.75, n.get_noise_3d(cx * 4.0 + 9.0, cy * 4.0, cz * 4.0)) * (1.0 - smoothstep(0.3, 0.8, d))
				b = maxf(b, clampf(a * 0.62 + (tide + clot * 0.5) * float(bl[4]) * (1.0 if d < 1.0 else 0.0), 0.0, 1.0))
			# the run back from the chin along the underside, fading
			var run := exp(-pow(_wrap_d(u - 0.77 - 0.01 * sin(v * 40.0)) / 0.012, 2.0)) * smoothstep(0.58, 0.8, v) * (1.0 - smoothstep(0.8, 0.86, v)) * 0.55
			b = maxf(b, run)
			# flecks by his right eye
			if v > 0.84 and v < 0.94 and absf(_wrap_d(u - 0.17)) < 0.06 and rng.randf() < 0.05: b = maxf(b, 0.55 + rng.randf() * 0.35)
			# mould: patches where the slow noise is high, more near the cuff, the wrist and the nose
			var mz := n.get_noise_3d(cx * 2.2 + 31.0, cy * 2.2, cz * 2.2) * 0.5 + 0.5
			var near := maxf(1.0 - smoothstep(0.0, 0.16, v), maxf(exp(-pow((v - 0.6) / 0.06, 2.0)), smoothstep(0.93, 1.0, v)))
			var m := smoothstep(0.58 - near * 0.18, 0.82, mz) * (0.55 + near * 0.45)
			# urine: broad patches with a darker dried rim
			var ur := 0.0
			for bl in urine:
				var du2 := _wrap_d(u - float(bl[0])) / float(bl[2]); var dv2 := (v - float(bl[1])) / float(bl[3])
				var d2 := sqrt(du2 * du2 + dv2 * dv2) + n.get_noise_3d(cx * 0.9 - 7.0, cy * 0.9, cz * 0.9) * 0.55
				var a2 := (1.0 - smoothstep(0.4, 1.0, d2)) * 0.6 + exp(-pow((d2 - 0.9) / 0.08, 2.0)) * 0.4
				ur = maxf(ur, a2 * float(bl[4]) * (1.0 if d2 < 1.05 else 0.0))
			var sp := rng.randf()
			img.set_pixel(x, y, Color(clampf(b, 0.0, 1.0), clampf(m, 0.0, 1.0), clampf(ur, 0.0, 1.0), sp))
	_stain_cache = ImageTexture.create_from_image(img)
	return _stain_cache

static func _wrap_d(d: float) -> float:
	return d - round(d)

## Fresh blood coming through the cloth, 0..1 (Kurt's health; SockoVitals).
var _wound_set := -1.0
func set_wound(w: float) -> void:
	if sock_mat and absf(w - _wound_set) > 0.004:
		_wound_set = w
		sock_mat.set_shader_parameter("wound", w)

## Stain controls (the test bench's inspection sliders): overall amount and each layer's.
func set_stains(amount: float, blood := 1.0, mould := 1.0, urine := 1.0) -> void:
	if sock_mat:
		sock_mat.set_shader_parameter("stain_amount", amount)
		sock_mat.set_shader_parameter("stain_mix", Vector3(blood, mould, urine))

# ---------------------------------------------------------------- the eyes: ping-pong balls
## Each eye is a white ping-pong ball glued to the top of the head (the fingers), well apart, a
## little wonky, with a googly eye stuck on it: a black plastic rim, a cream card, a clear raised
## dome and a loose black pupil between card and dome.
##
## Why they used to overlap: the old eyes were flat discs of radius 0.024 glued at ±0.5 rad on the
## narrow top of the head, where that put their centres only ~0.025 m apart (the radii alone
## needed 0.047). Now each ball has a seat on the cloth chosen so the balls stand clear of each
## other with a gap (EYE_GAP_MIN, checked at build), and the seat is skinned like the cloth there
## (see skin_point), so squash, stretch, twist and the jaw carry the ball without changing its size.
const EYE_R := 0.0185          # ping-pong ball, at the puppet's scale
const EYE_SEAT := 0.76         # ball centre out from the cloth along its normal, in radii: sunk into the felt, glued in a nest of it
const EYE_GAP_MIN := 0.008     # the least clear space between the two balls, at rest
const IRIS_K := 0.56           # googly eye radius / ball radius
const EYE_REACH := 1.0         # how far a googly eye turns on its ball from straight ahead (rad)
const EYE_MAX_FROM_UP := 1.95  # and never further than this from the seat's normal (it'd go into the felt)
# alpha (round the head), beta (up from the mouth line), radius scale, spin of the ball (its seam)
const EYE_SPECS := [[-0.7, 0.74, 1.0, 0.5], [0.7, 0.76, 1.03, -1.2]]

func _eyes() -> void:
	var white := StandardMaterial3D.new()
	white.albedo_texture = _ball_tex(); white.roughness = 0.2; white.metallic_specular = 0.7
	white.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var card := StandardMaterial3D.new(); card.albedo_color = Color("000000"); card.roughness = 0.9; card.metallic_specular = 0.05   # filled in: all black
	var rimm := StandardMaterial3D.new(); rimm.albedo_color = Color("161616"); rimm.roughness = 0.3; rimm.metallic_specular = 0.6
	var black := StandardMaterial3D.new(); black.albedo_color = Color("000000"); black.roughness = 0.9; black.metallic_specular = 0.05   # matte black, no grey sheen
	var dome_m := StandardMaterial3D.new(); dome_m.albedo_color = Color(0.95, 0.97, 1.0, 0.05); dome_m.roughness = 0.1
	dome_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; dome_m.metallic_specular = 0.35
	var mounts := []
	for i in EYE_SPECS.size():
		var sp: Array = EYE_SPECS[i]
		var al: float = sp[0]; var be: float = sp[1]
		var r: float = EYE_R * float(sp[2])
		var p := Vector3(A * sin(al) * cos(be), H_UP * sin(be), ZC - HEAD_LEN * cos(al) * cos(be))
		p.y += 0.003 * sin(be * 2.0) * cos(al) * cos(al)          # the same ridge the head mesh has
		var nrm := Vector3(p.x / (A * A), p.y / (H_UP * H_UP), (p.z - ZC) / (HEAD_LEN * HEAD_LEN)).normalized()
		mounts.append([p, nrm, r])
		var root := Node3D.new(); root.name = "Eye%s" % ["L", "R"][i]; root.top_level = true
		add_child(root)
		var ball := MeshInstance3D.new(); ball.name = "Ball"
		var bm := SphereMesh.new(); bm.radius = r; bm.height = r * 2.0; bm.radial_segments = 16; bm.rings = 8
		ball.mesh = bm; ball.material_override = white
		ball.basis = Basis(Vector3.RIGHT, PI / 2).rotated(Vector3.UP, float(sp[3]))   # the seam runs round it, not across the face
		root.add_child(ball)
		var ra := r * IRIS_K
		var disc := Node3D.new(); disc.name = "Googly"
		root.add_child(disc)
		var cmi := MeshInstance3D.new(); var cm := CylinderMesh.new()
		cm.top_radius = ra * 0.97; cm.bottom_radius = ra * 0.97; cm.height = 0.0008; cm.radial_segments = 14; cm.rings = 1
		cmi.mesh = cm; cmi.material_override = card; cmi.position.y = 0.0004; disc.add_child(cmi)
		var rim := MeshInstance3D.new(); var tm := TorusMesh.new()
		tm.inner_radius = ra * 0.86; tm.outer_radius = ra * 1.04; tm.rings = 14; tm.ring_segments = 4
		rim.mesh = tm; rim.material_override = rimm; rim.position.y = 0.0002; rim.scale = Vector3(1, 3.2, 1); disc.add_child(rim)
		var dome := MeshInstance3D.new(); var dm := SphereMesh.new()
		dm.radius = ra * 0.9; dm.height = ra * 0.9; dm.radial_segments = 14; dm.rings = 4; dm.is_hemisphere = true
		dome.mesh = dm; dome.material_override = dome_m; dome.position.y = 0.0008; dome.scale = Vector3(1, 0.55, 1); disc.add_child(dome)
		var pupil := MeshInstance3D.new(); var pm := CylinderMesh.new()
		var rp := ra * 0.74
		pm.top_radius = rp; pm.bottom_radius = rp; pm.height = 0.0012; pm.radial_segments = 12; pm.rings = 1
		pupil.mesh = pm; pupil.material_override = black; pupil.position.y = 0.0016
		disc.add_child(pupil)
		for mi in [ball, cmi, rim, dome, pupil]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var side := -1.0 if i == 0 else 1.0
		eyes.append({"root": root, "ball": ball, "disc": disc, "pupil": pupil, "radius": r, "ra": ra,
			"rest_p": p, "rest_n": nrm, "w": SockRig.top4(weights(p, 1)),
			"look_rest": Vector3(side * 0.14, 0.42, -1.0).normalized(),   # in the seat's frame: ahead, a little up and out
			"dir": Vector3(side * 0.14, 0.42, -1.0).normalized(),
			# the loose pupil (googly physics, in the googly eye's plane)
			"r": ra * 0.86 - rp, "p": Vector2(0, (ra * 0.86 - rp) * 0.5), "v": Vector2.ZERO,
			"last": Vector3.ZERO, "lastv": Vector3.ZERO, "acc": Vector3.ZERO, "init": false,
			# no two craft-store eyes are the same: each pupil slides and bounces a little differently
			"mu_k": 0.22 if i == 0 else 0.18, "mu_s": 0.32 if i == 0 else 0.28, "bounce": 0.35 if i == 0 else 0.45})
	# the gap between the balls at rest: they must stand clear of each other
	var c0: Vector3 = mounts[0][0] + mounts[0][1] * mounts[0][2] * EYE_SEAT
	var c1: Vector3 = mounts[1][0] + mounts[1][1] * mounts[1][2] * EYE_SEAT
	var gap: float = c0.distance_to(c1) - mounts[0][2] - mounts[1][2]
	if gap < EYE_GAP_MIN:
		push_error("SockRig: the eyes' seats leave %.4f m between the balls (want %.3f)" % [gap, EYE_GAP_MIN])

## The seat of eye i on the cloth as it is now: where it is, which way the cloth faces there, and
## which way the head faces (for the seat's frame).
func eye_seat(i: int) -> Transform3D:
	var e: Dictionary = eyes[i]
	var p: Vector3 = e.rest_p; var n: Vector3 = e.rest_n
	var at := skin_point(p, e.w)
	var up := (skin_point(p + n * 0.006, e.w) - at).normalized()
	var fwd := -bone_global(B.FINGERS).basis.z.normalized()
	var z := -(fwd - up * fwd.dot(up))
	if z.length_squared() < 1e-8:
		z = bone_global(B.FINGERS).basis.y.normalized()
	z = z.normalized()
	var x := up.cross(z).normalized()
	return Transform3D(Basis(x, up, z), at)

## Ball i's centre in the world.
func eye_center(i: int) -> Vector3:
	var st := eye_seat(i)
	return st.origin + st.basis.y * float(eyes[i].radius) * EYE_SEAT

## Put the balls on their seats and the googly eyes where they look (no physics: for poses).
func _place_eyes() -> void:
	if eyes.is_empty() or not is_inside_tree():
		return
	for i in eyes.size():
		var e: Dictionary = eyes[i]
		var st := eye_seat(i)
		var r: float = e.radius
		(e.root as Node3D).global_transform = Transform3D(st.basis, st.origin + st.basis.y * r * EYE_SEAT)
		var d: Vector3 = e.dir
		var ra: float = e.ra
		# the googly eye's flat back touches the ball at its centre (the ball's curve mustn't poke
		# through the black); its rim, 1-2 mm off the curve at the edge, is hidden by the rim's lip
		var lift := r - 0.0003
		# turn the googly eye from where it was by the shortest arc, so it never spins in its own
		# plane (the pupil would see "down" jump and fall for no reason)
		var prev: Basis = e.get("basis", Basis())
		var py := prev.y.normalized()
		var q := Quaternion(py, d) if py.dot(d) > -0.999 else Quaternion(prev.x.normalized(), PI)
		var nb := (Basis(q) * prev).orthonormalized()
		e.basis = nb
		(e.disc as Node3D).transform = Transform3D(nb, d * lift)

## Which way eye i's googly eye should face (in its seat's frame) to look at a world point,
## within what turning it on the ball allows.
func _eye_want(i: int, seat: Transform3D, center: Vector3) -> Vector3:
	var e: Dictionary = eyes[i]
	var rest: Vector3 = e.look_rest
	var t = eye_targets[i] if i < eye_targets.size() else null
	if t == null:
		return rest
	var to: Vector3 = (t as Vector3) - center
	if to.length_squared() < 1e-8:
		return rest
	var d := (seat.basis.inverse() * to.normalized()).normalized()
	var ang := rest.angle_to(d)
	if ang > EYE_REACH:
		d = rest.slerp(d, EYE_REACH / ang).normalized()
	var from_up := acos(clampf(d.y, -1.0, 1.0))
	if from_up > EYE_MAX_FROM_UP:
		var hz := Vector3(d.x, 0.0, d.z).normalized()
		d = (hz * sin(EYE_MAX_FROM_UP) + Vector3.UP * cos(EYE_MAX_FROM_UP)).normalized()
	return d

## Each frame: turn each googly eye toward its target at its own rate, seat the balls, then the
## loose pupils. Real googly eyes: a loose black disc between a card and a clear dome. Gravity (and
## the eye's own acceleration, felt as a push the other way) slides it across the card; it catches
## on the card and stays put when the slope is gentle, rattles off the rim when the hand jerks or
## the head snaps round, and runs round the rim to the lowest point. Real units (metres,
## 9.8 m/s²), substepped so it's the same at 20 fps as at 120. Each eye's pupil has its own
## friction and bounce, so they settle separately. `eye_hold` (layer D) holds a pupil centred
## against all that, which no googly eye can do.
func update_eyes(delta: float) -> void:
	if delta <= 0.0 or eyes.is_empty():
		return
	for i in eyes.size():
		var e: Dictionary = eyes[i]
		var st := eye_seat(i)
		var c := st.origin + st.basis.y * float(e.radius) * EYE_SEAT
		var want := _eye_want(i, st, c)
		var rate: float = eye_rates[i] if i < eye_rates.size() else 12.0
		e.dir = (e.dir as Vector3).slerp(want, 1.0 - exp(-rate * delta)).normalized()
	_place_eyes()
	var n := int(ceil(delta / (1.0 / 240.0))); var h := delta / n
	for i in eyes.size():
		var e: Dictionary = eyes[i]
		var disc: Node3D = e.disc
		var gt := disc.global_transform
		var pos := gt.origin
		if not e.init:
			e.last = pos; e.lastv = Vector3.ZERO; e.acc = Vector3.ZERO; e.init = true
		var vel: Vector3 = (pos - e.last) / delta
		var acc: Vector3 = ((vel - e.lastv) / delta).limit_length(90.0)
		e.acc = (e.acc as Vector3).lerp(acc * pupil_gain, 0.6)      # finite differences are noisy frame to frame
		e.last = pos; e.lastv = vel
		var ax := gt.basis.x.normalized(); var az := gt.basis.z.normalized(); var ny := gt.basis.y.normalized()
		var geff: Vector3 = Vector3(0, -9.8, 0) - (e.acc as Vector3)
		var f := Vector2(geff.dot(ax), geff.dot(az))
		var press := absf(geff.dot(ny))                  # against the card, or up into the dome
		var hold: float = eye_hold[i] if i < eye_hold.size() else 0.0
		if hold > 0.0:
			e.p = (e.p as Vector2).lerp(Vector2.ZERO, 1.0 - pow(0.001, delta * hold))
			e.v = Vector2.ZERO
			(e.pupil as Node3D).position = Vector3(e.p.x, 0.0016, e.p.y)
			continue
		var v: Vector2 = e.v; var p: Vector2 = e.p; var r: float = e.r
		var mu_k: float = e.mu_k; var mu_s: float = e.mu_s; var bounce: float = e.bounce
		for k in n:
			var sp := v.length()
			# resting against the rim, the rim pushes back: what's left is the push along it, and
			# the rim's own friction (it's sitting in the corner between card and rim)
			var at_rim := p.length() >= r * 0.999
			var fn := 0.0; var ft := f
			if at_rim:
				var rn := p.normalized()
				fn = maxf(0.0, f.dot(rn)); ft = f - rn * fn
			var grip := mu_s * (press + fn * 0.35)
			if sp < 0.004 and ft.length() <= grip:
				v = Vector2.ZERO                         # stuck (on the card, or in the corner at the rim)
			else:
				v += (ft if at_rim else f) * h
				var drop := mu_k * (press + fn * 0.35) * h
				var sp2 := v.length()
				v = v - v / sp2 * minf(drop, sp2) if sp2 > 0.0 else v
			p += v * h
			if p.length() > r:
				var nrm := p.normalized()
				p = nrm * r
				var vn := v.dot(nrm)
				if vn > 0.0:
					# a real knock bounces; a nudge just stops against the rim (no chatter)
					v -= nrm * vn * ((1.0 + bounce) if vn > 0.03 else 1.0)
		e.v = v; e.p = p
		(e.pupil as Node3D).position = Vector3(p.x, 0.0016, p.y)

## Clear space between the two balls right now (negative: they overlap).
func eye_gap() -> float:
	return eye_center(0).distance_to(eye_center(1)) - float(eyes[0].radius) - float(eyes[1].radius)

static var _ball_cache: Texture2D
## A cheap ping-pong ball: white, a faint moulding seam round the middle, a half-worn printed star,
## a scuff, and yellowed on one side from years on a sweaty hand. 32 x 16.
static func _ball_tex() -> Texture2D:
	if _ball_cache: return _ball_cache
	var img := Image.create(32, 16, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new(); rng.seed = 40
	for y in 16:
		for x in 32:
			var c := Color("f3f1ea")
			c = c.lerp(Color("d9cfa8"), smoothstep(0.55, 1.0, float(y) / 15.0) * 0.45)      # yellowed underneath
			if y == 7 or y == 8: c = c.darkened(0.08)                                       # the seam
			if x >= 20 and x <= 22 and y >= 3 and y <= 5 and rng.randf() < 0.6: c = Color("c8a24a").lerp(c, 0.5)   # the worn star
			if x >= 5 and x <= 8 and y == 11: c = c.darkened(0.12)                         # a scuff
			c = c.darkened(rng.randf() * 0.04)
			img.set_pixel(x, y, c)
	_ball_cache = ImageTexture.create_from_image(img)
	return _ball_cache
