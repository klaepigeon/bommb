class_name Ps1Human
extends Node3D
## A human, the way a late-90s PlayStation or N64 game would do one (Resident Evil, Silent
## Hill, Harry Potter on PS1): six-sided tapering limbs, an eight-sided torso that narrows
## to the waist, mitten hands, a faceted head with a photo of a face wrapped across its
## front facets, and a jagged shell of hair. Every human in the game has the
## same face (assets/textures/faces/, made by tools/make_faces.py): there are four
## photos of it, so they don't all pull the same expression.
##
## Built in metres, 1.8 tall, then scaled to `height` (house units). Joints are nodes to
## pose: hips, upper (the torso), head, arm_l/arm_r (shoulders) with fore_l/fore_r
## (elbows), leg_l/leg_r (hips) with shin_l/shin_r (knees). Front is +Z.
##
## Drawn as one skinned mesh (two surfaces: the cloth, and the face photo) on a skeleton
## whose bones follow the joints: pose the joints as ever, and the skeleton copies them when
## they change (checked every frame up close, less often far off or once a figure's been
## still a while). A person was eleven meshes and twenty draw calls; now it's two.
##
## spec: {"face": 0..3, "skin", "hair", "shirt", "trousers", "shoes": Color,
##        "coat": Color (a long coat over the shirt), "glasses": bool, "long_hair": bool,
##        "bald": bool, "tie": Color, "height": float}

const FACES := 4

var spec: Dictionary
var hips: Node3D
var upper: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var fore_l: Node3D
var fore_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var shin_l: Node3D
var shin_r: Node3D
var hand_l: Node3D
var hand_r: Node3D
## MEAT PARTY: each joint's own parts, kept (unmerged) so a death can throw them about.
var part_meshes: Dictionary = {}   # joint name -> Array[ArrayMesh]

static var _cloth: Dictionary = {}


static func make(s: Dictionary) -> Ps1Human:
	var h := Ps1Human.new()
	h.spec = s
	h._build()
	h.scale = Vector3.ONE * (float(s.get("height", 1.8)) / 1.8)
	return h


static func face_texture(i: int) -> Texture2D:
	# MEAT PARTY: faces come from the replaceable face library (Assets.face_texture).
	return Assets.face_texture(i)


## A flat colour with a little weave in it, 16 px, hard pixels (no pen-work over it).
static func cloth(c: Color, s: int = 1) -> Texture2D:
	var key := c.to_html() + str(s)
	if not _cloth.has(key):
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			for x in 16:
				var n := LcTex.fbm(x * 0.4, y * 0.4, s + 31) * 0.18 + ((x + y) % 2) * 0.03
				img.set_pixel(x, y, Color(c.r * (0.9 + n), c.g * (0.9 + n), c.b * (0.9 + n)))
		_cloth[key] = ImageTexture.create_from_image(img)
	return _cloth[key]


func _m(c: Color) -> Material:
	var m := LcMB.mat(cloth(c, int(c.r * 97 + c.g * 13)))
	_cloth_colour[m.get_instance_id()] = c
	return m


func _mesh(mb: LcMB, parent: Node3D) -> void:
	var m := mb.build()
	_parts.append([m, parent])
	if not part_meshes.has(String(parent.name)):
		part_meshes[String(parent.name)] = []
	part_meshes[String(parent.name)].append(m)


var _parts: Array = []        # [ArrayMesh, joint] while building
var _skel: Skeleton3D
var _joints: Array[Node3D] = []
var _last: Array = []         # each joint's transform when the skeleton last copied it
var _quiet: int = 0
var _tick: int = 0


## The skeleton (a bone per joint, at rest as built) and the one mesh, every vertex weighted
## to the joint it was built on.
func _skin() -> void:
	_joints = [hips, leg_l, shin_l, leg_r, shin_r, upper, arm_l, fore_l, arm_r, fore_r, head, hand_l, hand_r]
	_skel = Skeleton3D.new()
	_skel.name = "Skeleton"
	add_child(_skel)
	for i in _joints.size():
		var j := _joints[i]
		_skel.add_bone(String(j.name) if j.name != "" else "j%d" % i)
		var parent := _joints.find(j.get_parent())
		if parent >= 0:
			_skel.set_bone_parent(i, parent)
		_skel.set_bone_rest(i, j.transform)
		_skel.set_bone_pose(i, j.transform)
		_last.append(j.transform)
	# Merge every part's surfaces by material, in the model's space at rest.
	var groups := {}
	var order := []
	for part in _parts:
		var mesh: ArrayMesh = flatten(part[0], spec.get("skin_tex") if spec.get("skin_tex") is Texture2D else null)
		var joint: Node3D = part[1]
		var bone := _joints.find(joint)
		var xf := Transform3D.IDENTITY
		var q: Node = joint
		while q != self and q != null:
			xf = (q as Node3D).transform * xf
			q = q.get_parent()
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s)
			var key := m.get_instance_id() if m else 0
			if not groups.has(key):
				groups[key] = {"mat": m, "v": PackedVector3Array(), "n": PackedVector3Array(), "u": PackedVector2Array(),
					"c": PackedColorArray(), "b": PackedInt32Array(), "w": PackedFloat32Array(), "i": PackedInt32Array()}
				order.append(key)
			var g: Dictionary = groups[key]
			var a := mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var nv: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var base: int = (g.v as PackedVector3Array).size()
			for k in v.size():
				g.v.append(xf * v[k])
				g.n.append((xf.basis * nv[k]).normalized())
				g.b.append_array(PackedInt32Array([bone, 0, 0, 0]))
				g.w.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
			g.u.append_array(a[Mesh.ARRAY_TEX_UV])
			g.c.append_array(a[Mesh.ARRAY_COLOR])
			var ix: Variant = a[Mesh.ARRAY_INDEX]
			if ix == null or (ix as PackedInt32Array).is_empty():
				for k in v.size():
					g.i.append(base + k)
			else:
				for k in ix:
					g.i.append(base + k)
	var out := ArrayMesh.new()
	for key in order:
		var g: Dictionary = groups[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = g.v
		arrays[Mesh.ARRAY_NORMAL] = g.n
		arrays[Mesh.ARRAY_TEX_UV] = g.u
		arrays[Mesh.ARRAY_COLOR] = g.c
		arrays[Mesh.ARRAY_BONES] = g.b
		arrays[Mesh.ARRAY_WEIGHTS] = g.w
		arrays[Mesh.ARRAY_INDEX] = g.i
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1, g.mat)
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = out
	add_child(mi)
	mi.skeleton = mi.get_path_to(_skel)
	mi.skin = _skel.create_skin_from_rest_transforms()
	# Posed (sat, bent double, an arm up) it reaches further than it does at rest.
	mi.custom_aabb = AABB(Vector3(-1.0, -0.2, -1.0), Vector3(2.0, 2.6, 2.0))
	_parts.clear()


func _process(_delta: float) -> void:
	if _skel == null:
		return
	_tick += 1
	var every := 30
	if _quiet < 20:
		var cam := get_viewport().get_camera_3d()
		every = 1
		if cam:
			var d := cam.global_position.distance_squared_to(global_position)
			every = 1 if d < 1600.0 else (2 if d < 6400.0 else 4)
	if _tick < every:
		return
	_tick = 0
	if not is_visible_in_tree():
		return
	var changed := false
	for i in _joints.size():
		var t := _joints[i].transform
		if t != _last[i]:
			_last[i] = t
			_skel.set_bone_pose(i, t)
			changed = true
	_quiet = 0 if changed else _quiet + 1


## The colour each cloth material was made for (by material instance).
static var _cloth_colour: Dictionary = {}


## One surface for all of a part's cloth (skin, shirt, trousers, shoes, hair...): each was a
## flat colour on the same little weave, so the colour goes into the vertex colours (the ink
## shader multiplies by them) and they share one material. Anything else (the face photo)
## keeps its own surface. A person was ~20 draw calls; this makes it ~12.
static func flatten(mesh: ArrayMesh, skin_tex: Texture2D = null) -> ArrayMesh:
	var out := ArrayMesh.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var index := PackedInt32Array()
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		if m == null or not _cloth_colour.has(m.get_instance_id()):
			continue
		var c: Color = _cloth_colour[m.get_instance_id()]
		var a := mesh.surface_get_arrays(i)
		var base := verts.size()
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		verts.append_array(v)
		normals.append_array(a[Mesh.ARRAY_NORMAL])
		uvs.append_array(a[Mesh.ARRAY_TEX_UV])
		var col: PackedColorArray = a[Mesh.ARRAY_COLOR]
		for k in col.size():
			col[k] = Color(col[k].r * c.r, col[k].g * c.g, col[k].b * c.b, col[k].a)
		colors.append_array(col)
		var ix: Variant = a[Mesh.ARRAY_INDEX]
		if ix == null or (ix as PackedInt32Array).is_empty():
			for k in v.size():
				index.append(base + k)
		else:
			for k in ix:
				index.append(base + k)
	if not verts.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = index
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1, LcMB.mat(skin_tex if skin_tex else cloth(Color.WHITE, 1)))
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		if m != null and _cloth_colour.has(m.get_instance_id()):
			continue
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(i))
		out.surface_set_material(out.get_surface_count() - 1, m)
	return out


## A limb: a six-sided prism tapering from `top_r` at the joint down to `bot_r`, `length`
## long, a bit flatter front to back (the way PS1 limbs were).
func _limb(mb: LcMB, key: String, m: Material, top_r: float, bot_r: float, length: float, at := Vector3.ZERO, flat := 0.85) -> void:
	mb.cyl(key, m, bot_r, top_r, length, 6, LcMB.T(at + Vector3(0, -length, 0), Vector3(0, PI / 6.0, 0), Vector3(1, 1, flat)), Color(1, 1, 1))


## The head: a faceted lathe, eight sides round, with the photo of the face wrapped across
## the three front facets (that's how Silent Hill and Resident Evil did faces), skin
## round the back, and a cap on top. y is up from the jaw.
const HEAD_RINGS := [[0.0, 0.055], [0.05, 0.095], [0.13, 0.118], [0.22, 0.122], [0.29, 0.104], [0.335, 0.06], [0.35, 0.0]]
const HEAD_SEGS := 8


func _head_mesh(mb: LcMB, skin: Material, face: Material) -> void:
	var face_half := PI * 0.42          # the face covers this far either side of the front
	var face_top := 0.31
	for r in HEAD_RINGS.size() - 1:
		var y0: float = HEAD_RINGS[r][0]
		var r0: float = HEAD_RINGS[r][1]
		var y1: float = HEAD_RINGS[r + 1][0]
		var r1: float = HEAD_RINGS[r + 1][1]
		for i in HEAD_SEGS:
			var a0 := TAU * i / HEAD_SEGS - PI / HEAD_SEGS
			var a1 := a0 + TAU / HEAD_SEGS
			var p00 := Vector3(sin(a0) * r0, y0, cos(a0) * r0 * 1.05)
			var p01 := Vector3(sin(a1) * r0, y0, cos(a1) * r0 * 1.05)
			var p10 := Vector3(sin(a0) * r1, y1, cos(a0) * r1 * 1.05)
			var p11 := Vector3(sin(a1) * r1, y1, cos(a1) * r1 * 1.05)
			var mid := (a0 + a1) * 0.5
			var shade := Color(1, 1, 1) * (0.86 + 0.14 * cos(mid))
			shade.a = 1.0
			if absf(wrapf(mid, -PI, PI)) < face_half and y1 <= face_top + 0.001:
				# Three facets wide; the picture's right is the model's -x (its right cheek).
				var span := 3.0 * TAU / HEAD_SEGS
				var u0 := 0.5 - a0 / span
				var u1 := 0.5 - a1 / span
				var v0 := 1.0 - y0 / face_top
				var v1 := 1.0 - y1 / face_top
				mb.tri("f", face, p00, p11, p01, shade, Vector2(u0, v0), Vector2(u1, v1), Vector2(u1, v0))
				mb.tri("f", face, p00, p10, p11, shade, Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1))
			else:
				mb.tri("s", skin, p00, p11, p01, shade)
				mb.tri("s", skin, p00, p10, p11, shade)
	# Underneath the jaw.
	for i in HEAD_SEGS:
		var a0 := TAU * i / HEAD_SEGS - PI / HEAD_SEGS
		var a1 := a0 + TAU / HEAD_SEGS
		var r0: float = HEAD_RINGS[0][1]
		mb.tri("s", skin, Vector3.ZERO, Vector3(sin(a0) * r0, 0, cos(a0) * r0 * 1.05), Vector3(sin(a1) * r0, 0, cos(a1) * r0 * 1.05), Color(0.7, 0.7, 0.7))


## Hair: a shell over the crown, a fringe line across the forehead, and (long hair) a
## curtain down the back and sides to the shoulders, cut in a jagged edge.
func _hair_mesh(mb: LcMB, hair: Material, long: bool) -> void:
	var low_back := -0.2 if long else 0.1
	var low_side := -0.1 if long else 0.16
	for i in HEAD_SEGS:
		var a0 := TAU * i / HEAD_SEGS - PI / HEAD_SEGS
		var a1 := a0 + TAU / HEAD_SEGS
		var mid := absf(wrapf((a0 + a1) * 0.5, -PI, PI))
		var bottom := 0.29 if mid < PI * 0.3 else (low_side if mid < PI * 0.6 else low_back)
		var jag := 0.03 * float(i % 2)
		var pts := [[0.37, 0.0], [0.345, 0.075], [0.3, 0.118], [0.22, 0.132], [maxf(bottom + 0.04, -1.0), 0.136], [bottom - jag, 0.14]]
		for k in pts.size() - 1:
			var y0: float = pts[k][0]
			var y1: float = pts[k + 1][0]
			if y1 >= y0:
				continue
			var r0: float = pts[k][1]
			var r1: float = pts[k + 1][1]
			var q00 := Vector3(sin(a0) * r0, y0, cos(a0) * r0 * 1.08)
			var q01 := Vector3(sin(a1) * r0, y0, cos(a1) * r0 * 1.08)
			var q10 := Vector3(sin(a0) * r1, y1, cos(a0) * r1 * 1.08)
			var q11 := Vector3(sin(a1) * r1, y1, cos(a1) * r1 * 1.08)
			var sh := Color(1, 1, 1) * (0.8 + 0.2 * float(k) / pts.size())
			sh.a = 1.0
			mb.tri("r", hair, q00, q01, q11, sh)
			mb.tri("r", hair, q00, q11, q10, sh)


func _build() -> void:
	var skin_c: Color = spec.get("skin", Color(0.86, 0.68, 0.58))
	var hair_c: Color = spec.get("hair", Color(0.55, 0.4, 0.22))
	var shirt_c: Color = spec.get("shirt", Color(0.2, 0.3, 0.75))
	var legs_c: Color = spec.get("trousers", Color(0.22, 0.24, 0.3))
	var shoe_c: Color = spec.get("shoes", Color(0.12, 0.1, 0.1))
	var skin := _m(skin_c)
	var shirt := _m(shirt_c)
	var legs := _m(legs_c)
	var shoe := _m(shoe_c)
	var coat: Material = _m(spec.coat) if spec.has("coat") else null
	var body: Material = coat if coat else shirt
	hips = Node3D.new()
	hips.name = "Hips"
	part_meshes.clear()
	hips.position = Vector3(0, 0.92, 0)
	add_child(hips)
	# Legs: tapering thighs and shins, a shoe with a toe.
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.name = "LegL" if side < 0.0 else "LegR"
		leg.position = Vector3(0.095 * side, 0, 0)
		hips.add_child(leg)
		var lb := LcMB.new()
		_limb(lb, "l", legs, 0.09, 0.065, 0.45)
		_mesh(lb, leg)
		var shin := Node3D.new()
		shin.name = "ShinL" if side < 0.0 else "ShinR"
		shin.position = Vector3(0, -0.44, 0)
		leg.add_child(shin)
		var sb := LcMB.new()
		_limb(sb, "l", legs, 0.064, 0.048, 0.42)
		sb.box("s", shoe, Vector3(0.1, 0.07, 0.16), LcMB.T(Vector3(0, -0.445, 0.0)), Color(1, 1, 1))
		sb.box("s", shoe, Vector3(0.09, 0.05, 0.1), LcMB.T(Vector3(0, -0.455, 0.11)), Color(0.9, 0.9, 0.9))
		_mesh(sb, shin)
		if side < 0.0:
			leg_l = leg
			shin_l = shin
		else:
			leg_r = leg
			shin_r = shin
	# Pelvis, a torso that narrows to the waist and squares off at the shoulders, a neck.
	upper = Node3D.new()
	upper.name = "Upper"
	hips.add_child(upper)
	var pb := LcMB.new()
	pb.cyl("l", legs, 0.15, 0.155, 0.16, 8, LcMB.T(Vector3(0, -0.07, 0), Vector3(0, PI / 8.0, 0), Vector3(1, 1, 0.68)), Color(1, 1, 1))
	_mesh(pb, hips)
	var tb := LcMB.new()
	tb.cyl("b", body, 0.15, 0.165, 0.2, 8, LcMB.T(Vector3(0, 0.08, 0), Vector3(0, PI / 8.0, 0), Vector3(1, 1, 0.66)), Color(1, 1, 1))
	tb.cyl("b", body, 0.165, 0.215, 0.26, 8, LcMB.T(Vector3(0, 0.28, 0), Vector3(0, PI / 8.0, 0), Vector3(1, 1, 0.6)), Color(1, 1, 1))
	tb.cyl("b", body, 0.215, 0.09, 0.07, 8, LcMB.T(Vector3(0, 0.54, 0), Vector3(0, PI / 8.0, 0), Vector3(1, 1, 0.62)), Color(0.95, 0.95, 0.95))
	tb.cyl("k", skin, 0.05, 0.045, 0.1, 6, LcMB.T(Vector3(0, 0.58, 0)), Color(0.9, 0.9, 0.9))
	if not coat:
		tb.cyl("t", _m(Color(0.1, 0.08, 0.07)), 0.157, 0.157, 0.03, 8, LcMB.T(Vector3(0, 0.07, 0), Vector3(0, PI / 8.0, 0), Vector3(1.02, 1, 0.7)), Color(1, 1, 1))  # belt
	else:
		# Open down the front over the shirt, and long: the tails hang to the knees.
		tb.box("s", shirt, Vector3(0.1, 0.4, 0.02), LcMB.T(Vector3(0, 0.34, 0.125)), Color(1, 1, 1))
		tb.cyl("b", coat, 0.2, 0.16, 0.5, 8, LcMB.T(Vector3(0, -0.42, 0), Vector3(0, PI / 8.0, 0), Vector3(1, 1, 0.72)), Color(0.92, 0.92, 0.92))
		if spec.has("tie"):
			tb.box("t", _m(spec.tie), Vector3(0.045, 0.28, 0.02), LcMB.T(Vector3(0, 0.38, 0.135)), Color(1, 1, 1))
	_mesh(tb, upper)
	# Arms from the shoulders: a round shoulder, a tapering upper arm and forearm, a hand.
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.name = "ArmL" if side < 0.0 else "ArmR"
		arm.position = Vector3(0.235 * side, 0.5, 0)
		upper.add_child(arm)
		var ab := LcMB.new()
		ab.sphere("a", body, 0.07, 3, 6, LcMB.T(), Color(1, 1, 1))
		_limb(ab, "a", body, 0.062, 0.05, 0.3)
		_mesh(ab, arm)
		var fore := Node3D.new()
		fore.name = "ForeL" if side < 0.0 else "ForeR"
		fore.position = Vector3(0, -0.3, 0)
		arm.add_child(fore)
		var fb := LcMB.new()
		_limb(fb, "a", body, 0.05, 0.04, 0.24)
		_mesh(fb, fore)
		# MEAT PARTY: the hand is its own joint, so it can be lost (and replaced).
		var hand := Node3D.new()
		hand.name = "HandL" if side < 0.0 else "HandR"
		hand.position = Vector3(0, -0.25, 0)
		fore.add_child(hand)
		var hb2 := LcMB.new()
		hb2.box("h", skin, Vector3(0.075, 0.1, 0.035), LcMB.T(Vector3(0, -0.05, 0.0)), Color(1, 1, 1))
		hb2.box("h", skin, Vector3(0.065, 0.06, 0.03), LcMB.T(Vector3(0, -0.12, 0.006), Vector3(0.25, 0, 0)), Color(0.92, 0.92, 0.92))
		hb2.box("h", skin, Vector3(0.025, 0.055, 0.03), LcMB.T(Vector3(-0.045 * side, -0.04, 0.02), Vector3(0, 0, 0.5 * side)), Color(0.88, 0.88, 0.88))
		_mesh(hb2, hand)
		if side < 0.0:
			hand_l = hand
		else:
			hand_r = hand
		arm.rotation.z = 0.1 * side
		fore.rotation.x = -0.15
		if side < 0.0:
			arm_l = arm
			fore_l = fore
		else:
			arm_r = arm
			fore_r = fore
	# The head, the face on it, the hair, glasses.
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.66, 0)
	upper.add_child(head)
	var hb := LcMB.new()
	var ftex: Texture2D = spec.get("face_tex") if spec.get("face_tex") is Texture2D else face_texture(int(spec.get("face", 0)))
	# (a photograph: it catches the light more than cloth does)
	_head_mesh(hb, skin, LcMB.mat(ftex, Color(1.0, 1.0, 1.0) * float(spec.get("face_gain", 1.0))))
	for side in [-1.0, 1.0]:
		hb.box("s", skin, Vector3(0.025, 0.06, 0.04), LcMB.T(Vector3(0.122 * side, 0.15, -0.005)), Color(0.85, 0.85, 0.85))    # ears
	if not spec.get("bald", false):
		_hair_mesh(hb, _m(hair_c), spec.get("long_hair", true))
	if spec.get("glasses", false):
		var rim := _m(Color(0.08, 0.08, 0.1))
		for side in [-1.0, 1.0]:
			hb.box("g", rim, Vector3(0.075, 0.01, 0.01), LcMB.T(Vector3(0.048 * side, 0.205, 0.138)), Color(1, 1, 1))
			hb.box("g", rim, Vector3(0.075, 0.01, 0.01), LcMB.T(Vector3(0.048 * side, 0.16, 0.138)), Color(1, 1, 1))
			hb.box("g", rim, Vector3(0.01, 0.055, 0.01), LcMB.T(Vector3(0.087 * side, 0.183, 0.135)), Color(1, 1, 1))
			hb.box("g", rim, Vector3(0.01, 0.01, 0.12), LcMB.T(Vector3(0.12 * side, 0.2, 0.08)), Color(1, 1, 1))
	_mesh(hb, head)
	_skin()


## A walk at `phase` (radians), `amount` 0..1: stiff, swinging, like it was keyframed
## at 15 frames a second.
func walk(phase: float, amount: float) -> void:
	var p := floorf(phase / (PI / 6.0)) * (PI / 6.0)
	var s := sin(p) * 0.55 * amount
	leg_l.rotation.x = s
	leg_r.rotation.x = -s
	shin_l.rotation.x = maxf(0.0, -sin(p)) * 0.7 * amount
	shin_r.rotation.x = maxf(0.0, sin(p)) * 0.7 * amount
	arm_l.rotation.x = -s * 0.8
	arm_r.rotation.x = s * 0.8
	hips.position.y = 0.92 + absf(cos(p)) * 0.03 * amount


## Stood still: breathing, a slow sway.
func idle(t: float) -> void:
	upper.rotation.x = sin(t * 1.3) * 0.02
	head.rotation.y = sin(t * 0.4) * 0.15
	for l in [leg_l, leg_r, shin_l, shin_r]:
		(l as Node3D).rotation.x = lerpf((l as Node3D).rotation.x, 0.0, 0.1)


## Sat down (on whatever is under him): thighs forward, shins down.
func sit() -> void:
	hips.position.y = 0.5
	for l in [leg_l, leg_r]:
		(l as Node3D).rotation.x = -PI / 2
	for s in [shin_l, shin_r]:
		(s as Node3D).rotation.x = PI / 2
