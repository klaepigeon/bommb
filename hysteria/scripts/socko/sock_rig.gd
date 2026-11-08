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
## curl (-1 fingers stretched .. 1 a fist: the head folds in), squash (-1 tense .. 1 slumped).

enum B { FOREARM, HAND, FINGERS, FINGERTIPS, THUMB, THUMBTIP }
const BONE_NAMES := ["forearm", "hand", "fingers", "fingertips", "thumb", "thumbtip"]

const FOREARM_LEN := 0.27
const ZW := -0.27            # wrist
const ZC := -0.322           # back of the mouth: the web between thumb and index finger
const HEAD_LEN := 0.08       # from the mouth's corners to the tip of the nose
const A := 0.047             # half-width of the head
const H_UP := 0.040          # height of the upper jaw above the mouth line (fingers and knuckles)
const H_DN := 0.030          # depth of the lower jaw (the thumb)
const CUFF := -0.075         # where the sock's top ends on the forearm
const SLEEVE_END := -0.095   # the coat cuff, over the sock top
const MOUTH_DEPTH := 0.62    # how far the pocket folds in toward the throat

var skel: Skeleton3D
var sock: MeshInstance3D
var sleeve: MeshInstance3D
var eyes: Array = []         # {disc, pupil, p: Vector2, v: Vector2, last: Vector3, lastv: Vector3}

var wrist := Vector3.ZERO
var jaw := 0.0
var skew := 0.0
var curl := 0.0
var squash := 0.0
var gaze_world = null        # Vector3 the googly pupils drift toward (they're loose: it's a bias)
var gaze_pull := 0.0

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
	]
	var parents := [-1, 0, 1, 2, 1, 4]
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

## Where the head is (between the jaws, a little behind the nose), and which way the mouth faces.
func head_global() -> Transform3D:
	return bone_global(B.FINGERS).translated_local(Vector3(0, -0.012, -0.035))

func apply_pose() -> void:
	if not skel:
		return
	var rest := skel.get_bone_rest(B.HAND)
	var sq := clampf(squash, -1.0, 1.0)
	skel.set_bone_pose_rotation(B.HAND, Quaternion(Basis.from_euler(Vector3(wrist.x, wrist.y, wrist.z), EULER_ORDER_YXZ)))
	skel.set_bone_pose_position(B.HAND, rest.origin)
	# slump: the cloth sags lower and wider; tense: drawn in and taller
	skel.set_bone_pose_scale(B.HAND, Vector3(1.0 + sq * 0.07, 1.0 - sq * 0.13, 1.0 + sq * 0.03))
	var j := clampf(jaw, -0.1, 1.6)
	var c := clampf(curl, -1.0, 1.0)
	# fingers lift from the knuckles and bend at the middle joint; the thumb drops from the web.
	# The fingers do more of the work (a puppeteer's thumb mostly holds still).
	skel.set_bone_pose_rotation(B.FINGERS, Quaternion(Basis.from_euler(Vector3(j * 0.56 - c * 0.22, 0, skew * 0.3 * j))))
	skel.set_bone_pose_rotation(B.FINGERTIPS, Quaternion(Basis.from_euler(Vector3(j * 0.2 - c * 0.42, 0, 0))))
	skel.set_bone_pose_rotation(B.THUMB, Quaternion(Basis.from_euler(Vector3(-j * 0.4 + c * 0.1, 0, -skew * 0.2 * j))))
	skel.set_bone_pose_rotation(B.THUMBTIP, Quaternion(Basis.from_euler(Vector3(-j * 0.18 + c * 0.2, 0, 0))))

# ---------------------------------------------------------------- skin weights
## Bone weights for a point of cloth at rest position p. `shell`: 0 the tube (forearm, wrist,
## hand), 1 the upper half of the head, -1 the lower half. The same function weights every
## surface, so where two surfaces meet at the same point they move together (no cracks).
func weights(p: Vector3, shell: int) -> Dictionary:
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

	func add(p: Vector3, t: Vector2, w: Dictionary, outward: Vector3) -> int:
		var pairs := []
		for k in w:
			if w[k] > 0.0005: pairs.append([w[k], k])
		pairs.sort_custom(func(x, y): return x[0] > y[0])
		pairs = pairs.slice(0, 4)
		var sum := 0.0
		for pr in pairs: sum += pr[0]
		for i in 4:
			if i < pairs.size():
				bones.append(pairs[i][1]); wts.append(pairs[i][0] / sum)
			else:
				bones.append(0); wts.append(0.0)
		v.append(p); uv.append(t); out.append(outward)
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
			ring.append(sk.add(p, Vector2(u, (z - CUFF) / (ZC - HEAD_LEN - CUFF)), weights(p, 0), out))
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
				row.append(sk.add(p, t, weights(p, half), out))
			g.append(row)
		for ib in NB:
			for ia in NA:
				sk.quad(g[ib][ia], g[ib][ia + 1], g[ib + 1][ia + 1], g[ib + 1][ia])
	sk.commit(mesh, _cloth_mat())
	# ---- the inside of the mouth: a pocket from the upper lip, in toward the throat, out to the
	# lower lip. Shut, it's folded flat out of sight; open, it's the dark you see between the jaws.
	var pk := ClothSkin.new()
	const R := 6
	var pg := []
	for r in R + 1:
		var k := float(r) / R
		var d := MOUTH_DEPTH * sin(PI * k)
		var row := []
		for ia in NA + 1:
			var al := PI * (float(ia) / NA - 0.5)
			var e := Vector3(A * sin(al), 0.0, ZC - HEAD_LEN * cos(al))
			var p := Vector3(e.x * (1.0 - d), lerpf(0.0012, -0.0012, k), ZC + (e.z - ZC) * (1.0 - d))
			var w := mix_w(weights(e + Vector3(0, 0.0005, 0), 1), weights(e - Vector3(0, 0.0005, 0), -1), smoothstep(0.15, 0.85, k))
			row.append(pk.add(p, Vector2(float(ia) / NA, k), w, Vector3(0, 0.5 - k, 0) + (Vector3(0, 0, ZC) - p) * 4.0))
		pg.append(row)
	for r in R:
		for ia in NA:
			pk.quad(pg[r][ia], pg[r][ia + 1], pg[r + 1][ia + 1], pg[r + 1][ia])
	pk.commit(mesh, _felt_mat(Color("7a1c1c"), 0.15))
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

# ---------------------------------------------------------------- googly eyes
## Two googly eyes glued to the top of the head over the fingers, a little apart, a little wonky.
## The pupils are loose plastic discs: they fall, slide and rattle with the hand's movement.
func _eyes() -> void:
	var att := BoneAttachment3D.new(); att.name = "EyeMount"
	att.bone_name = "fingers"
	skel.add_child(att)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("f2f0ea"); white.roughness = 0.25
	white.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var black := StandardMaterial3D.new(); black.albedo_color = Color("0c0c0c"); black.roughness = 0.4
	var rim := StandardMaterial3D.new(); rim.albedo_color = Color("d8d8d0"); rim.roughness = 0.15
	rim.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; rim.albedo_color.a = 0.35
	var specs := [[-0.5, 0.98, 0.024, -0.07], [0.46, 1.02, 0.0228, 0.09]]   # alpha, beta, radius, wonk
	for sp in specs:
		var al: float = sp[0]; var be: float = sp[1]; var r: float = sp[2]
		var p := Vector3(A * sin(al) * cos(be), H_UP * sin(be), ZC - HEAD_LEN * cos(al) * cos(be))
		var nrm := Vector3(p.x / (A * A), p.y / (H_UP * H_UP), (p.z - ZC) / (HEAD_LEN * HEAD_LEN)).normalized()
		nrm = (nrm + Vector3(0, 0.1, -0.75)).normalized()   # glued facing forward and up
		var disc := Node3D.new()
		att.add_child(disc)
		var local_p := skel.get_bone_global_rest(B.FINGERS).affine_inverse() * p
		var local_n := skel.get_bone_global_rest(B.FINGERS).basis.inverse() * nrm
		var up := Vector3.FORWARD if absf(local_n.dot(Vector3.FORWARD)) < 0.9 else Vector3.UP
		disc.transform = Transform3D(Basis.looking_at(-local_n, up).rotated(local_n, sp[3]) * Basis(Vector3.RIGHT, PI / 2), local_p + local_n * 0.006)
		var face := MeshInstance3D.new(); var cm := CylinderMesh.new()
		cm.top_radius = r; cm.bottom_radius = r; cm.height = 0.004; cm.radial_segments = 12; cm.rings = 1
		face.mesh = cm; face.material_override = white; disc.add_child(face)
		var dome := MeshInstance3D.new(); var dm := SphereMesh.new()
		dm.radius = r * 1.02; dm.height = r * 0.9; dm.radial_segments = 12; dm.rings = 4; dm.is_hemisphere = true
		dome.mesh = dm; dome.material_override = rim; dome.position.y = 0.0015; dome.scale = Vector3(1, 0.45, 1)
		disc.add_child(dome)
		var pupil := MeshInstance3D.new(); var pm := CylinderMesh.new()
		pm.top_radius = r * 0.52; pm.bottom_radius = r * 0.52; pm.height = 0.0015; pm.radial_segments = 10; pm.rings = 1
		pupil.mesh = pm; pupil.material_override = black; pupil.position.y = 0.0025
		disc.add_child(pupil)
		for mi in [face, dome, pupil]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eyes.append({"disc": disc, "pupil": pupil, "r": r * 0.46, "p": Vector2(0, r * 0.3), "v": Vector2.ZERO, "last": Vector3.ZERO, "lastv": Vector3.ZERO, "init": false})

## Loose pupils: gravity and the hand's acceleration push them round inside the rim; they rattle
## against it and settle. `gaze_world` adds a pull, so his eyes seem to land on what he's after.
func update_eyes(delta: float) -> void:
	if delta <= 0.0:
		return
	for e in eyes:
		var disc: Node3D = e.disc
		var gt := disc.global_transform
		var pos := gt.origin
		if not e.init:
			e.last = pos; e.lastv = Vector3.ZERO; e.init = true
		var vel: Vector3 = (pos - e.last) / delta
		var acc: Vector3 = (vel - e.lastv) / delta
		e.last = pos; e.lastv = vel
		var force := Vector3(0, -9.8, 0) - acc.limit_length(60.0)
		var ax := gt.basis.x.normalized(); var az := gt.basis.z.normalized()
		var f2 := Vector2(force.dot(ax), force.dot(az)) * 0.03
		if gaze_world != null and gaze_pull > 0.0:
			var to: Vector3 = ((gaze_world as Vector3) - pos).normalized()
			f2 += Vector2(to.dot(ax), to.dot(az)) * gaze_pull * 0.5
		var v: Vector2 = e.v + f2 * delta
		v *= pow(0.02, delta)               # friction against the backing card
		var p: Vector2 = e.p + v * delta
		var r: float = e.r
		if p.length() > r:
			var nrm := p.normalized()
			p = nrm * r
			var vn := v.dot(nrm)
			if vn > 0.0: v -= nrm * vn * 1.45   # a little bounce off the rim
		e.p = p; e.v = v
		(e.pupil as Node3D).position = Vector3(p.x, 0.0025, p.y)
