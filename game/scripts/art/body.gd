class_name Body
extends Node3D
## A person, built from a spec, never quite right: every proportion is a parameter, and every
## character's are a little (or a lot) off a person's. One skeleton, one skinned low-poly mesh
## (tubes lofted along the bones, joints blended), a painted face, and things that grow out of it
## (coral, flaps of skin, hair) riding on bones. Posed by code every frame (pose()).
##
## Spec keys (metres unless said): height, shoulder, hip, neck (length), head (radius), arm (length
## factor), leg (factor), girth (factor), stoop (rad), skin (tex name), cloth (Color or null),
## cloth_to ("chest"/"hips"/"knee": how much is covered), face ("grin"/"none"/"old"/"blank"/"mask"),
## eyes (Color), growths ([[bone, count, size, tex]]), hair (Color or null), flaps (count).

const BONES := ["hips", "spine", "chest", "neck", "head",
	"shoulder_l", "arm_l", "forearm_l", "hand_l", "shoulder_r", "arm_r", "forearm_r", "hand_r",
	"thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]
const PARENT := {"spine": "hips", "chest": "spine", "neck": "chest", "head": "neck",
	"shoulder_l": "chest", "arm_l": "shoulder_l", "forearm_l": "arm_l", "hand_l": "forearm_l",
	"shoulder_r": "chest", "arm_r": "shoulder_r", "forearm_r": "arm_r", "hand_r": "forearm_r",
	"thigh_l": "hips", "shin_l": "thigh_l", "foot_l": "shin_l", "thigh_r": "hips", "shin_r": "thigh_r", "foot_r": "shin_r"}

var spec := {}
var skel: Skeleton3D
var mesh: MeshInstance3D
var mats: Array[ShaderMaterial] = []
var bone := {}                     ## name -> index
var head_pos := Vector3.ZERO       ## world, refreshed by pose()
var _rest := {}                    ## name -> rest position (model space)
var _len := {}                     ## name -> bone length
var _rng := RandomNumberGenerator.new()

func build(p_spec: Dictionary) -> void:
	spec = p_spec
	_rng.seed = String(spec.get("name", "body")).hash()
	_skeleton()
	_mesh()
	_extras()

func _f(k: String, d: float) -> float:
	return float(spec.get(k, d))

# ------------------------------------------------------------------------------ the skeleton
func _skeleton() -> void:
	var h := _f("height", 1.7)
	var k := h / 1.7
	var leg := _f("leg", 1.0)
	var arm := _f("arm", 1.0)
	var neck := _f("neck", 0.1) * k
	var sh := _f("shoulder", 0.19) * k
	var hip := _f("hip", 0.1) * k
	var hips_y := 0.92 * k * leg
	var P := {
		"hips": Vector3(0, hips_y, 0), "spine": Vector3(0, hips_y + 0.12 * k, 0), "chest": Vector3(0, hips_y + 0.33 * k, 0),
		"neck": Vector3(0, hips_y + 0.55 * k, 0), "head": Vector3(0, hips_y + 0.55 * k + neck, 0),
		"shoulder_l": Vector3(-0.04 * k, hips_y + 0.52 * k, 0), "arm_l": Vector3(-sh, hips_y + 0.5 * k, 0),
		"forearm_l": Vector3(-sh - 0.02, hips_y + 0.5 * k - 0.29 * k * arm, 0), "hand_l": Vector3(-sh - 0.03, hips_y + 0.5 * k - 0.54 * k * arm, 0.02),
		"thigh_l": Vector3(-hip, hips_y - 0.04 * k, 0), "shin_l": Vector3(-hip, hips_y * 0.52, 0.01), "foot_l": Vector3(-hip, 0.08 * k, 0),
	}
	for side in ["arm", "forearm", "hand", "shoulder", "thigh", "shin", "foot"]:
		var p: Vector3 = P[side + "_l"]
		P[side + "_r"] = Vector3(-p.x, p.y, p.z)
	skel = Skeleton3D.new(); skel.name = "Skeleton"
	add_child(skel)
	skel.rotation.y = PI          # built facing +Z (toes, jaw, face); the game's forward is -Z
	for b in BONES:
		var i := skel.add_bone(b)
		bone[b] = i
		_rest[b] = P[b]
		if PARENT.has(b):
			skel.set_bone_parent(i, bone[PARENT[b]])
			skel.set_bone_rest(i, Transform3D(Basis(), P[b] - P[PARENT[b]]))
		else:
			skel.set_bone_rest(i, Transform3D(Basis(), P[b]))
	var tails := {"hips": "spine", "spine": "chest", "chest": "neck", "neck": "head", "shoulder_l": "arm_l", "arm_l": "forearm_l", "forearm_l": "hand_l",
		"shoulder_r": "arm_r", "arm_r": "forearm_r", "forearm_r": "hand_r", "thigh_l": "shin_l", "shin_l": "foot_l", "thigh_r": "shin_r", "shin_r": "foot_r"}
	for b in BONES:
		_len[b] = (P[tails[b]] - P[b]).length() if tails.has(b) else 0.1
	skel.reset_bone_poses()

# ------------------------------------------------------------------------------ the skin
## Segments: [bone, from, to, r0, r1, part] (from/to in model space; part picks the material).
func _segments() -> Array:
	var g := _f("girth", 1.0) * _f("height", 1.7) / 1.7
	var R := _rest
	var hr := _f("head", 0.11) * _f("height", 1.7) / 1.7
	var s := [
		["hips", R.hips + Vector3(0, -0.08, 0), R.spine, 0.17 * g, 0.15 * g, "cloth_low"],
		["spine", R.spine, R.chest, 0.15 * g, 0.17 * g, "cloth_top"],
		["chest", R.chest, R.neck + Vector3(0, -0.04, 0), 0.19 * g, 0.13 * g, "cloth_top"],
		["chest", R.arm_l + Vector3(0.03, 0.02, 0), R.arm_r + Vector3(-0.03, 0.02, 0), 0.075 * g, 0.075 * g, "cloth_top"],
		["neck", R.neck + Vector3(0, -0.03, 0), R.head, 0.06 * g, 0.05 * g, "skin"],
	]
	for side in ["l", "r"]:
		s.append(["arm_" + side, R["arm_" + side], R["forearm_" + side], 0.068 * g, 0.052 * g, "cloth_arm"])
		s.append(["forearm_" + side, R["forearm_" + side], R["hand_" + side], 0.052 * g, 0.04 * g, "skin" if spec.get("bare_arms", false) else "cloth_arm"])
		s.append(["hand_" + side, R["hand_" + side], R["hand_" + side] + Vector3(0, -0.17 * _f("hands", 1.0), 0.015), 0.045 * g, 0.026 * g, "skin"])
		s.append(["thigh_" + side, R["thigh_" + side], R["shin_" + side], 0.095 * g, 0.068 * g, "cloth_leg"])
		s.append(["shin_" + side, R["shin_" + side], R["foot_" + side], 0.064 * g, 0.044 * g, "cloth_shin"])
		s.append(["foot_" + side, R["foot_" + side] + Vector3(0, 0.02, -0.03), R["foot_" + side] + Vector3(0, -0.05, 0.2), 0.05 * g, 0.042 * g, "foot"])
	# the head: a skull, a jaw coming forward and down under it, a nose
	s.append(["head", R.head + Vector3(0, -hr * 0.1, 0), R.head + Vector3(0, hr * 1.9, 0), hr, hr * 0.75, "head"])
	s.append(["head", R.head + Vector3(0, hr * 0.15, hr * 0.05), R.head + Vector3(0, -hr * 0.25, hr * 0.75 * _f("jaw", 1.0)), hr * 0.62, hr * 0.38, "head"])
	s.append(["head", R.head + Vector3(0, hr * 0.75, hr * 0.7), R.head + Vector3(0, hr * 0.55, hr * 1.05), hr * 0.16, hr * 0.08, "skin"])
	# what's worn: a skirt from the hips to the knee, a long coat to the shin or the floor
	var hem := String(spec.get("hem", ""))
	if hem != "":
		var to: float = R.shin_l.y + 0.02 if hem == "knee" else (R.foot_l.y + 0.12 if hem == "shin" else R.foot_l.y + 0.02)
		var flare := float(spec.get("flare", 1.35))
		s.append(["hips", R.hips + Vector3(0, 0.06, 0), Vector3(0, to, 0.02), 0.18 * g, 0.18 * g * flare, "cloth_low"])
	return s

func _mat_for(part: String) -> int:
	var cloth = spec.get("cloth", null)
	var to := String(spec.get("cloth_to", "knee"))
	match part:
		"head": return 2
		"skin": return 0
		"foot": return 0 if not spec.get("shoes", false) else 1
		"cloth_low", "cloth_top": return 1 if cloth != null else 0
		"cloth_arm": return 1 if cloth != null and to != "chest_bare_arms" else 0
		"cloth_leg": return 1 if cloth != null and to in ["knee", "foot"] else 0
		"cloth_shin": return 1 if cloth != null and to == "foot" else 0
	return 0

func _mesh() -> void:
	var sts := [SurfaceTool.new(), SurfaceTool.new(), SurfaceTool.new()]
	for st in sts: st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var counts := [0, 0, 0]
	const RING := 7
	const SEG := 4
	for sg in _segments():
		var b: String = sg[0]
		var a: Vector3 = sg[1]; var e: Vector3 = sg[2]
		var r0: float = sg[3]; var r1: float = sg[4]
		var mi := _mat_for(sg[5])
		var st: SurfaceTool = sts[mi]
		var axis := (e - a).normalized()
		var side := axis.cross(Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var up := side.cross(axis).normalized()
		var is_head: bool = sg[5] == "head"
		var rings := []
		for j in SEG + 1:
			var t := float(j) / SEG
			var r := lerpf(r0, r1, t)
			if is_head: r = r0 * sin(lerpf(0.12, PI - 0.1, t)) * (1.0 + 0.15 * sin(t * PI))
			var ring := []
			for i in RING:
				var ang := TAU * i / RING
				var o := (side * cos(ang) + up * sin(ang)) * r
				if is_head: o.z *= _f("face_flat", 1.0)
				ring.append([a.lerp(e, t) + o, (side * cos(ang) + up * sin(ang)).normalized(), Vector2(float(i) / RING, t), t])
			rings.append(ring)
		var parent := String(PARENT.get(b, b))
		for j in SEG:
			for i in RING:
				var q := [rings[j][i], rings[j][(i + 1) % RING], rings[j + 1][(i + 1) % RING], rings[j + 1][i]]
				for vi in [0, 1, 2, 0, 2, 3]:
					var v: Array = q[vi]
					var t: float = v[3]
					var w := clampf(t / 0.3, 0.0, 1.0) * 0.5 + 0.5 if parent != b else 1.0
					st.set_bones(PackedInt32Array([bone[b], bone[parent], 0, 0]))
					st.set_weights(PackedFloat32Array([w, 1.0 - w, 0.0, 0.0]))
					st.set_normal(v[1]); st.set_uv(v[2]); st.set_color(Color.WHITE)
					st.add_vertex(v[0])
				counts[mi] += 6
		# caps
		for end in [0, SEG]:
			var c: Vector3 = a if end == 0 else e
			for i in RING:
				var p0: Array = rings[end][i]; var p1: Array = rings[end][(i + 1) % RING]
				var tri := [c, p0[0], p1[0]] if end == SEG else [c, p1[0], p0[0]]
				for p in tri:
					st.set_bones(PackedInt32Array([bone[b], 0, 0, 0])); st.set_weights(PackedFloat32Array([1, 0, 0, 0]))
					st.set_normal(axis * (1.0 if end == SEG else -1.0)); st.set_uv(Vector2(0.5, 0.5)); st.set_color(Color.WHITE)
					st.add_vertex(p)
				counts[mi] += 3
	var am := ArrayMesh.new()
	var mat_list := [_skin_mat(), _cloth_mat(), _face_mat()]
	for i in 3:
		if counts[i] == 0: continue
		sts[i].generate_normals()
		var arr: Array = sts[i].commit_to_arrays()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS * 0)
		am.surface_set_material(am.get_surface_count() - 1, mat_list[i])
		mats.append(mat_list[i])
	mesh = MeshInstance3D.new(); mesh.name = "Skin"; mesh.mesh = am
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skel.add_child(mesh)
	mesh.skeleton = NodePath("..")
	mesh.skin = skel.create_skin_from_rest_transforms()

func _skin_mat() -> ShaderMaterial:
	var m := Mats.tex(Tex.get_tex(String(spec.get("skin", "skin_grey"))), -1, spec.get("skin_tint", Color.WHITE)).duplicate() as ShaderMaterial
	m.set_shader_parameter("snap", 0.6)
	return m

func _cloth_mat() -> ShaderMaterial:
	var c: Color = spec.get("cloth", Color(0.3, 0.3, 0.32)) if spec.get("cloth", null) != null else Color.WHITE
	var m := Mats.tex(Tex.get_tex(String(spec.get("cloth_tex", "cloth"))), -1, c).duplicate() as ShaderMaterial
	m.set_shader_parameter("snap", 0.6)
	return m

## The face, painted: wrong in a different way for each of them.
func _face_mat() -> ShaderMaterial:
	const S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var skin := Tex.get_tex(String(spec.get("skin", "skin_grey"))).get_image()
	skin.decompress()
	var tint: Color = spec.get("skin_tint", Color.WHITE)
	for y in S:
		for x in S:
			img.set_pixel(x, y, skin.get_pixel(x % skin.get_width(), y % skin.get_height()) * tint)
	var face := String(spec.get("face", "blank"))
	var eye: Color = spec.get("eyes", Color(0.85, 0.85, 0.8))
	# u runs round the head (front is u≈0.75 for the ring's +up... the front is where up*sin = -Z), v up it
	var fx := int(S * 0.75)
	var hair = spec.get("hair", null)
	for y in S:
		for x in S:
			var v := 1.0 - float(y) / S       # 0 chin .. 1 crown
			var du := absf(fposmod(float(x) / S - 0.75 + 0.5, 1.0) - 0.5)   # distance round from the front
			if hair != null and (v > 0.72 or (du > 0.22 and v > 0.3)):
				img.set_pixel(x, y, (hair as Color) * (0.8 + 0.2 * sin(x * 2.3)))
				continue
			match face:
				"grin":
					if absf(v - 0.36) < 0.035 and du < 0.24: img.set_pixel(x, y, Color(0.08, 0.02, 0.02))
					elif absf(v - 0.36) < 0.06 and du < 0.24 and (x % 3 == 0): img.set_pixel(x, y, Color(0.85, 0.8, 0.7))
					elif absf(v - 0.55) < 0.04 and absf(du - 0.07) < 0.035: img.set_pixel(x, y, eye)
				"old":
					if absf(v - 0.33) < 0.015 and du < 0.07: img.set_pixel(x, y, Color(0.25, 0.1, 0.1))
					elif absf(v - 0.53) < 0.025 and absf(du - 0.06) < 0.022: img.set_pixel(x, y, eye)
					elif absf(v - 0.6) < 0.01 and absf(du - 0.06) < 0.04: img.set_pixel(x, y, Color(0.3, 0.25, 0.2))
				"mask":
					if absf(v - 0.55) < 0.06 and du < 0.13: img.set_pixel(x, y, Color(0.05, 0.05, 0.06))
					if absf(v - 0.55) < 0.025 and absf(du - 0.06) < 0.02: img.set_pixel(x, y, eye)
				"lamp":
					if absf(v - 0.55) < 0.05 and absf(du - 0.06) < 0.035: img.set_pixel(x, y, eye)
					if absf(v - 0.3) < 0.08 and du < 0.05: img.set_pixel(x, y, Color(0.12, 0.08, 0.06))
				"blank": pass
	img.generate_mipmaps()
	var m := Mats.tex(ImageTexture.create_from_image(img), -1).duplicate() as ShaderMaterial
	m.set_shader_parameter("snap", 0.6)
	if spec.has("eye_glow"): m.set_shader_parameter("emission", Vector3(0.0, 0.0, 0.0))
	return m

## Growths that ride on bones: coral, flaps of skin, a cap, a lamp-pole: [bone, count, size, tex]
func _extras() -> void:
	for g in spec.get("growths", []):
		var ba := BoneAttachment3D.new(); ba.bone_name = String(g[0])
		skel.add_child(ba)
		var kit := Kit.new()
		var mat := Mats.tex(Tex.get_tex(String(g[3])), -1).duplicate() as ShaderMaterial
		mats.append(mat)
		var L: float = _len.get(String(g[0]), 0.2)
		for i in int(g[1]):
			var p := Vector3(_rng.randf_range(-0.08, 0.08), _rng.randf_range(0.0, L), _rng.randf_range(-0.08, 0.08))
			p += Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized() * float(g[2]) * 0.8
			var sz := float(g[2]) * _rng.randf_range(0.5, 1.3)
			kit.blob(mat, p, Vector3(sz * 0.6, sz * (1.0 + _rng.randf() * 1.5), sz * 0.6), _rng, 0.4)
		var meshes := kit.commit(ba, "Growth")
		# the attachment is in bone space: move the blobs from the bone's head
		for m in meshes: m.position = Vector3.ZERO
		ba.set_meta("rest_origin", _rest[String(g[0])])
	if int(spec.get("flaps", 0)) > 0:
		for i in int(spec.flaps):
			var bn: String = ["chest", "spine", "arm_l", "arm_r", "thigh_l", "thigh_r", "neck"][i % 7]
			var ba := BoneAttachment3D.new(); ba.bone_name = bn
			skel.add_child(ba)
			var kit := Kit.new()
			var mat := Mats.tex(Tex.get_tex(String(spec.get("skin", "skin_pale"))), -1, Color(0.85, 0.8, 0.78)).duplicate() as ShaderMaterial
			mats.append(mat)
			kit.blob(mat, Vector3(_rng.randf_range(-0.1, 0.1), _rng.randf_range(-0.05, 0.1), _rng.randf_range(0.05, 0.12)), Vector3(0.09, 0.16, 0.04), _rng, 0.25)
			kit.commit(ba, "Flap")

## Every material's zone (the room it's in), so the right lamps light it.
func set_zone(z: int) -> void:
	for m in mats:
		m.set_shader_parameter("zone", float(z))

func set_glow(c: Color) -> void:
	for m in mats:
		m.set_shader_parameter("emission", Vector3(c.r, c.g, c.b))

# ------------------------------------------------------------------------------ posing
## Sets a bone's rotation (Euler XYZ, radians) relative to its rest.
func rot(b: String, e: Vector3) -> void:
	skel.set_bone_pose_rotation(bone[b], Quaternion.from_euler(e))

func offset(b: String, p: Vector3) -> void:
	skel.set_bone_pose_position(bone[b], skel.get_bone_rest(bone[b]).origin + p)

## The standard poses, blended by the caller's numbers. phase: walk cycle (radians); stride 0..1;
## reach 0..1 (arms out in front); sit 0..1 (seated); stoop (rad); look (yaw, pitch for the head);
## twitch 0..1 (wrongness); float_y.
func pose(p: Dictionary) -> void:
	var ph := float(p.get("phase", 0.0)); var st := float(p.get("stride", 0.0))
	var reach := float(p.get("reach", 0.0)); var sit := float(p.get("sit", 0.0))
	var stoop := float(p.get("stoop", _f("stoop", 0.0))); var tw := float(p.get("twitch", 0.0))
	var look: Vector2 = p.get("look", Vector2.ZERO)
	var t := Time.get_ticks_msec() / 1000.0
	var jit := Vector3(sin(t * 13.0 + 1.0), sin(t * 17.0), sin(t * 11.0 + 2.0)) * 0.25 * tw * (1.0 if fmod(t, 2.3) < 0.25 else 0.15)
	offset("hips", Vector3(0, -absf(sin(ph)) * 0.03 * st - sit * 0.42 + float(p.get("float_y", 0.0)), 0))
	rot("hips", Vector3(0, sin(ph) * 0.12 * st, 0))
	rot("spine", Vector3(stoop * 0.5 + sit * 0.05, 0, 0))
	rot("chest", Vector3(stoop * 0.5, -sin(ph) * 0.15 * st, 0) + jit * 0.3)
	rot("neck", Vector3(look.y * 0.4 - stoop * 0.6, look.x * 0.5, 0) + jit)
	rot("head", Vector3(look.y * 0.6 - stoop * 0.3, look.x * 0.5, float(p.get("tilt", 0.0))) + jit)
	for side in ["l", "r"]:
		var s := 1.0 if side == "l" else -1.0
		var swing := sin(ph + (0.0 if side == "l" else PI)) * 0.5 * st
		rot("thigh_" + side, Vector3(-swing - sit * 1.5, 0, 0))
		rot("shin_" + side, Vector3(maxf(0.0, -cos(ph + (0.0 if side == "l" else PI))) * 0.7 * st + sit * 1.5, 0, 0))
		rot("foot_" + side, Vector3(-sit * 0.1, 0, 0))
		var arm_swing := -swing * 0.7 * (1.0 - reach)
		rot("shoulder_" + side, Vector3(0, 0, 0))
		rot("arm_" + side, Vector3(arm_swing - reach * 1.45 - sit * 0.4, 0, s * (0.08 + reach * -0.05)))
		rot("forearm_" + side, Vector3(-0.15 - reach * 0.1 - sit * 0.9, 0, 0))
		rot("hand_" + side, Vector3(sin(t * 3.0 + s) * 0.1 * tw, 0, 0))
	if is_inside_tree():
		head_pos = (skel.global_transform * skel.get_bone_global_pose(bone["head"])).origin + Vector3(0, _f("head", 0.11) * 0.6, 0)
