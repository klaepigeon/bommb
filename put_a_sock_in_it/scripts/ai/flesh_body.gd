class_name FleshBody
extends Node3D
## A body for the building's inhabitants (docs/CHAPTER2.md): jointed, built from the numbers in
## `p`, and never quite human: the proportions are off in a way you notice before you know why.
## Joints (Node3D, rotated each frame toward `pose` with springs, like Marta's):
##   hips  spine  chest  neck  head  jaw   sh_l/sh_r  el_l/el_r  hip_l/hip_r  kn_l/kn_r
## p (all optional):
##   height 1.75   girth 1.0 (width)   belly 0.0 (0..1: how far it hangs)   arm 1.0 (length)
##   neck 1.0   head 1.0 (size)   hunch 0.0   skin "skin"   tint Color   wet 0.0 (sheen)
##   mouth 1.0 (width: the super's goes round)   eyes "normal" | "none" | "sewn" | "many"
##   fingers 1.0 (length)   naked false   apron/dress/coat Color   keys false   lumps 0.0 (growths)
##   extra_joint false (the arms bend twice)   barefoot true

var p := {}
var pose := {}                  # joint -> Vector3 (euler), the target
var snap := 10.0                # how fast joints go to the pose
var J := {}                     # joint name -> Node3D
var _rest := {}

func _init(params := {}) -> void:
	p = params

func _ready() -> void:
	var path := "res://assets/people/%s.glb" % String(g("model", ""))
	if p.has("model") and ResourceLoader.exists(path): _build_model(path)
	else: _build()
	for k in J: pose[k] = Vector3.ZERO

func g(k: String, d):
	return p.get(k, d)

func _mat(name: String, tint: Color, extra := {}) -> Material:
	var o := {"tint": tint}
	for k in extra: o[k] = extra[k]
	return Tex.mat(name, 2.0, o)

## A piece of body. Placed as written with +z as the front, and mirrored here so the body faces
## -Z (forward in Godot, where everything that walks looks). Long pieces are capsules, bulky ones
## ellipsoids: flesh, not boxes (low-poly, as everything here is). Only small details stay boxes.
func _part(parent: Node3D, at: Vector3, size: Vector3, m: Material, ball := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var thick := minf(size.x, size.z)
	if ball or (size.y <= 1.6 * maxf(size.x, size.z) and thick > 0.07 and size.y > 0.07):
		var sp := SphereMesh.new(); sp.radius = 0.5; sp.height = 1.0; sp.radial_segments = 9; sp.rings = 6
		mi.mesh = sp; mi.scale = size
	elif size.y > 1.6 * maxf(size.x, size.z) and thick > 0.02:
		var cp := CapsuleMesh.new(); cp.radius = thick * 0.5; cp.height = maxf(size.y, thick * 1.01); cp.radial_segments = 8; cp.rings = 2
		mi.mesh = cp; mi.scale = Vector3(size.x / thick, 1.0, size.z / thick)
	else:
		mi.mesh = Build.box_mesh(size)
	mi.material_override = m; mi.position = Vector3(at.x, at.y, -at.z); parent.add_child(mi)
	return mi

func _joint(name: String, parent: Node3D, at: Vector3) -> Node3D:
	var j := Node3D.new(); j.name = name; parent.add_child(j); j.position = at
	J[name] = j
	return j

func _build() -> void:
	var h: float = g("height", 1.75); var k := h / 1.75
	var gw: float = g("girth", 1.0); var belly: float = g("belly", 0.0)
	var arm: float = g("arm", 1.0); var neckl: float = g("neck", 1.0); var headk: float = g("head", 1.0)
	# skin: pallid and close-grained (plaster's grain, tinted), not the camouflage of the old skin map
	var skin := _mat(String(g("skin", "plaster")), g("tint", Color(0.9, 0.82, 0.72)) * Color(0.78, 0.74, 0.7), {"rough": lerpf(0.9, 0.2, float(g("wet", 0.0)))})
	var dark := _mat("black", Color(1, 1, 1))
	var leg := 0.86 * k; var torso := 0.56 * k
	var hips := _joint("hips", self, Vector3(0, leg, 0))
	# legs
	for s in [-1, 1]:
		var side := "l" if s < 0 else "r"
		var hj := _joint("hip_" + side, hips, Vector3(s * 0.1 * gw * k, 0, 0))
		_limb(hj, leg * 0.5, [0.085 * gw * k, 0.075 * gw * k, 0.058 * k], _cloth("legs", skin))
		var kn := _joint("kn_" + side, hj, Vector3(0, -leg * 0.5, 0))
		_limb(kn, leg * 0.5, [0.058 * k, 0.05 * k, 0.034 * k], skin)
		_part(kn, Vector3(0, -leg * 0.5 + 0.03, 0.06), Vector3(0.09, 0.05, 0.24) * k, skin if g("barefoot", true) else dark)
	var spine := _joint("spine", hips, Vector3(0, 0.02, 0))
	var torso_m := _cloth("dress", skin)
	_blob(spine, Vector3(0, torso * 0.52, 0.0), Vector3(0.2 * gw, torso * 0.58, 0.13 * gw) * Vector3(k, 1, k),
		{"sag": 0.15 + belly * 0.25, "bumps": 0.1 + float(g("lumps", 0.0)) * 0.2, "seed": h}, torso_m)
	if belly > 0.01:
		# the belly: hangs, and hangs over
		var b := _blob(spine, Vector3(0, torso * 0.2 - belly * 0.06, (0.08 + belly * 0.1) * k),
			Vector3(0.2 * gw + belly * 0.07, 0.15 + belly * 0.12, 0.12 + belly * 0.14) * k, {"sag": 0.4 + belly * 0.5, "bumps": 0.06, "seed": h + 1.0}, skin)
		b.set_meta("belly", true)
	var chest := _joint("chest", spine, Vector3(0, torso * 0.5, 0))
	if float(g("belly", 0.0)) > 0.3:
		for s in [-1, 1]: _blob(chest, Vector3(s * 0.1 * gw * k, torso * 0.02, 0.1 * gw * k), Vector3(0.06, 0.08, 0.05) * gw * k, {"sag": 1.8, "bumps": 0.05}, skin)   # sagging
	if g("keys", false):
		var cord := _part(chest, Vector3(0, torso * 0.2, 0.12 * gw * k), Vector3(0.01, torso * 0.6, 0.01), dark)
		cord.rotation.x = -0.15
		for i in 6: _part(chest, Vector3(randf_range(-0.03, 0.03), -0.02 - i * 0.012, 0.15 * gw * k), Vector3(0.012, 0.05, 0.004), Tex.mat("brass"))
	if float(g("lumps", 0.0)) > 0.0:
		var lm := _mat("coral", Color(0.9, 0.85, 0.8))
		var rng := RandomNumberGenerator.new(); rng.seed = int(h * 1000.0)
		for i in int(float(g("lumps", 0.0)) * 8.0):
			var parent: Node3D = [spine, chest][i % 2]
			_part(parent, Vector3(rng.randf_range(-0.18, 0.18) * gw, rng.randf_range(0.0, torso * 0.5), rng.randf_range(-0.12, 0.13) * gw) * Vector3(k, 1, k), Vector3.ONE * rng.randf_range(0.05, 0.12), lm, true)
	# arms
	for s in [-1, 1]:
		var side := "l" if s < 0 else "r"
		var sh := _joint("sh_" + side, chest, Vector3(s * 0.22 * gw * k, torso * 0.45, 0))
		var up := 0.32 * k * arm
		_limb(sh, up, [0.055 * gw * k, 0.048 * gw * k, 0.042 * k], _cloth("dress", skin))
		var el := _joint("el_" + side, sh, Vector3(0, -up, 0))
		var lo := 0.3 * k * arm
		_limb(el, lo, [0.042 * k, 0.036 * k, 0.03 * k], skin)
		if g("extra_joint", false):
			var ex := _joint("ex_" + side, el, Vector3(0, -lo, 0))
			_limb(ex, lo * 0.8, [0.03 * k, 0.028 * k, 0.025 * k], skin)
			_hand(ex, Vector3(0, -lo * 0.8, 0), skin, k)
		else:
			_hand(el, Vector3(0, -lo, 0), skin, k)
	# neck, head, jaw
	var nl := 0.11 * k * neckl
	var neck := _joint("neck", chest, Vector3(0, torso * 0.5, 0))
	_part(neck, Vector3(0, nl * 0.5, 0), Vector3(0.09, nl, 0.09) * k, skin)
	var head := _joint("head", neck, Vector3(0, nl, 0))
	var hs := 0.22 * k * headk
	_blob(head, Vector3(0, hs * 0.5, 0), Vector3(hs * 0.4, hs * 0.5, hs * 0.45), {"bumps": 0.08, "slide": float(g("slide", 0.0)), "seed": h + 2.0}, skin)
	var jaw := _joint("jaw", head, Vector3(0, hs * 0.3, hs * 0.2))
	var mw := 0.07 * k * float(g("mouth", 1.0))
	_part(jaw, Vector3(0, -0.02, 0.06 * k), Vector3(mw * 1.2, 0.03, 0.1 * k), skin)
	_part(head, Vector3(0, hs * 0.3, hs * 0.44), Vector3(mw * 1.15, 0.012, 0.01), _mat("cloth_red", Color(0.35, 0.05, 0.06)))   # the mouth's line
	match String(g("eyes", "normal")):
		"normal":
			for s in [-1, 1]: _part(head, Vector3(s * hs * 0.18, hs * 0.58, hs * 0.42), Vector3(0.025, 0.018, 0.01) * k, dark)
		"sewn":
			for s in [-1, 1]:
				for i in 3: _part(head, Vector3(s * hs * 0.18 + (i - 1) * 0.01, hs * 0.58, hs * 0.43), Vector3(0.004, 0.03, 0.004), dark)
		"many":
			for i in 7: _part(head, Vector3(randf_range(-0.3, 0.3) * hs, randf_range(0.45, 0.8) * hs, hs * 0.43), Vector3(0.018, 0.014, 0.01) * k, dark)
		_:
			pass
	if g("repugnant", false): _repugnant(spine, chest, head, hs, torso, gw, k, belly)
	if g("hair", false):
		_part(head, Vector3(0, hs * 0.9, -0.01), Vector3(hs * 0.8, hs * 0.35, hs * 0.85), _mat("fabric", g("hair_tint", Color(0.2, 0.17, 0.14))), true)
	for k2 in J: _rest[k2] = J[k2].rotation

## The super: everything about the body that makes you not want to look, and not able not to.
## Liver spots and sores across the front of him, hair in patches (the chest, a line down the gut,
## a dark mat where the belly hangs over), a few yellow teeth in the wide wet mouth, small eyes that
## catch the light. Nothing sexual about any of it: it's a body, and that's the horror.
func _repugnant(spine: Node3D, chest: Node3D, head: Node3D, hs: float, torso: float, gw: float, k: float, belly: float) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 1993
	var spot := _mat("plaster", Color(0.38, 0.28, 0.18))
	var sore := _mat("cloth_red", Color(0.55, 0.12, 0.1), {"rough": 0.15})
	var hair := _mat("fabric", Color(0.12, 0.1, 0.09))
	var tooth := _mat("enamel", Color(0.75, 0.68, 0.4))
	var eye := _mat("enamel", Color(0.05, 0.05, 0.04), {"rough": 0.05})
	for i in 16:
		var parent: Node3D = spine if i % 2 else chest
		_part(parent, Vector3(rng.randf_range(-0.16, 0.16) * gw * k, rng.randf_range(0.0, torso * 0.45), (0.11 * gw + belly * 0.18) * k), Vector3.ONE * rng.randf_range(0.015, 0.035), spot if i % 4 else sore, true)
	for i in 10:
		_part(chest, Vector3(rng.randf_range(-0.08, 0.08) * k, rng.randf_range(torso * 0.1, torso * 0.35), 0.12 * gw * k), Vector3(rng.randf_range(0.02, 0.05), rng.randf_range(0.01, 0.03), 0.01), hair)
	for i in 6:
		_part(spine, Vector3(rng.randf_range(-0.02, 0.02), torso * 0.4 - i * 0.05, (0.13 + belly * 0.32) * k), Vector3(0.015, 0.03, 0.01), hair)
	# where the gut hangs over: a dark mat of hair, and shadow
	_part(spine, Vector3(0, -torso * 0.12, (0.08 + belly * 0.12) * k), Vector3(0.16 * gw, 0.07, 0.05) * k, hair, true)
	for i in 4:
		_part(head, Vector3(-0.025 + i * 0.016, hs * 0.29, hs * 0.45), Vector3(0.011, 0.016, 0.006), tooth)
	for s2 in [-1, 1]:
		_part(head, Vector3(s2 * hs * 0.16, hs * 0.6, hs * 0.43), Vector3(0.02, 0.016, 0.012) * k, eye, true)

## A lumpy, sagging piece of flesh (MeshKit.blob), mirrored to face -Z like everything else.
func _blob(parent: Node3D, c: Vector3, r: Vector3, opts: Dictionary, m: Material) -> MeshInstance3D:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var o := opts.duplicate(); o["rings"] = 8; o["segs"] = 12
	MeshKit.blob(st, Vector3.ZERO, r, o)
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = m
	mi.position = Vector3(c.x, c.y, -c.z); mi.rotation.y = PI      # (its slide and sag face the front)
	parent.add_child(mi)
	return mi

## A limb hanging from its joint: a tube tapering through radii [top, middle, bottom].
func _limb(parent: Node3D, length: float, radii: Array, m: Material) -> MeshInstance3D:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshKit.tube(st, [Vector3(0, 0.02, 0), Vector3(0, -length * 0.45, 0), Vector3(0, -length - 0.02, 0)], radii, {"sides": 7, "bumps": 0.08})
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = m
	parent.add_child(mi)
	return mi

## Clothes, if they wear any: a colour for apron/dress/coat, or skin.
func _cloth(where: String, skin: Material) -> Material:
	if g("naked", false): return skin
	if where == "dress" and p.has("dress"): return _mat("fabric", p.dress)
	if where == "legs" and p.has("trousers"): return _mat("fabric", p.trousers)
	if where == "dress" and p.has("apron"): return _mat("fabric", p.apron)
	return skin

func _hand(parent: Node3D, at: Vector3, skin: Material, k: float) -> void:
	var f: float = g("fingers", 1.0)
	_part(parent, at + Vector3(0, -0.04, 0), Vector3(0.08, 0.08, 0.04) * k, skin)
	for i in 4:
		_part(parent, at + Vector3(-0.03 + i * 0.02, -0.08 - 0.05 * f, 0), Vector3(0.012, 0.1 * f, 0.012) * k, skin)

## Joint name -> world position (attacks, gaze, the hit point).
func at(j: String) -> Vector3:
	return (J[j] as Node3D).global_position if J.has(j) else global_position

func _process(delta: float) -> void:
	var t := 1.0 - exp(-snap * delta)
	if skel:
		_process_model(delta, t)
		return
	for k in J:
		var want: Vector3 = _rest[k] + pose.get(k, Vector3.ZERO)
		var jn: Node3D = J[k]
		jn.rotation = jn.rotation.lerp(want, t)

# ------------------------------------------------------------------ sculpted bodies
## A sculpted, rigged body (tools/sculpt, docs/PEOPLE.md): one skinned mesh, its bones the joints
## above, at rest with no rotation, so `pose` means the same here. J holds a BoneAttachment3D per
## bone (at(), and anything hung on a joint). The jaw talks with the voice (Dialogue.syllable),
## the belly and the jowls swing on springs, and the skin shows the wounds as the hp goes.
const FLESH := preload("res://shaders/flesh.gdshader")
var skel: Skeleton3D
var flesh_mat: ShaderMaterial
var _bone := {}                   # joint -> bone index
var _cur := {}                    # joint -> current euler
var _talk := 0.0                  # the jaw's opening from speech
var _last_pos := Vector3.ZERO
var _vel := Vector3.ZERO
var _jig := Vector3.ZERO           # the belly's spring
var _jig_v := Vector3.ZERO
var _belly_rest := Vector3.ZERO

func _build_model(path: String) -> void:
	var scene: Node3D = (load(path) as PackedScene).instantiate()
	scene.name = "Model"
	add_child(scene)
	skel = scene.find_children("*", "Skeleton3D", true, false)[0]
	flesh_mat = ShaderMaterial.new(); flesh_mat.shader = FLESH
	flesh_mat.set_shader_parameter("tint", g("model_tint", Color(1, 1, 1)))
	flesh_mat.set_shader_parameter("wet_gain", float(g("wet_gain", 1.0)))
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = flesh_mat
	for i in skel.get_bone_count():
		var n := skel.get_bone_name(i)
		_bone[n] = i
		var a := BoneAttachment3D.new(); a.name = n; a.bone_name = n
		skel.add_child(a)
		J[n] = a
		_cur[n] = Vector3.ZERO
		_rest[n] = Vector3.ZERO
	if _bone.has("belly"): _belly_rest = skel.get_bone_rest(_bone.belly).origin
	if g("keys", false) and J.has("chest"): _keys(J.chest)
	if Engine.has_singleton("Dialogue") or get_node_or_null("/root/Dialogue"):
		var d := get_node_or_null("/root/Dialogue")
		if d: d.syllable.connect(_on_syllable)
	_last_pos = global_position if is_inside_tree() else Vector3.ZERO

func _keys(chest: Node3D) -> void:
	# the keys on a cord round his neck, lying on his chest
	var k: float = float(g("height", 1.75)) / 1.75
	var front := 0.27 * k * float(g("girth", 1.0)) / 1.45
	var dark := _mat("black", Color(1, 1, 1))
	var cord := MeshInstance3D.new(); cord.mesh = Build.box_mesh(Vector3(0.004, 0.3, 0.004)); cord.material_override = _mat("fabric", Color(0.3, 0.25, 0.2))
	cord.position = Vector3(0, 0.12, -front + 0.05); cord.rotation.x = 0.3; chest.add_child(cord)
	for i in 7:
		var key := MeshInstance3D.new(); key.mesh = Build.box_mesh(Vector3(0.014, 0.055, 0.004)); key.material_override = Tex.mat("brass")
		key.position = Vector3(randf_range(-0.035, 0.035), -0.03 - i * 0.01, -front - 0.01); key.rotation.z = randf_range(-0.5, 0.5)
		chest.add_child(key)

func _on_syllable(who: String) -> void:
	if who == String(g("speaker", g("model", ""))): _talk = randf_range(0.18, 0.4)

func _process_model(delta: float, t: float) -> void:
	_talk = maxf(0.0, _talk - delta * 1.6)
	for k in _bone:
		var want: Vector3 = pose.get(k, Vector3.ZERO)
		if k == "jaw":
			# (pose: + opens. On this rig + would shut it: the chin's in front of the hinge)
			want = Vector3(-(maxf(want.x, 0.0) * 0.45 + _talk + float(g("slack", 0.0))), want.y, want.z)
		var c: Vector3 = _cur[k].lerp(want, t)
		_cur[k] = c
		skel.set_bone_pose_rotation(_bone[k], Quaternion.from_euler(c))
	# the belly swings: a spring behind the body's movement
	var pos := global_position
	var v := (pos - _last_pos) / maxf(delta, 0.001)
	_last_pos = pos
	var acc := (v - _vel) / maxf(delta, 0.001)
	_vel = v
	if _bone.has("belly"):
		var local_acc := global_transform.basis.inverse() * acc
		local_acc.y -= 0.0
		_jig_v += (-_jig * 90.0 - _jig_v * 9.0 - local_acc.limit_length(30.0) * 0.6) * delta
		_jig += _jig_v * delta
		_jig = _jig.limit_length(0.06)
		var bob := sin(Time.get_ticks_msec() * 0.0021) * 0.003      # breathing
		skel.set_bone_pose_position(_bone.belly, _belly_rest + _jig + Vector3(0, bob, -bob))
	var host := get_parent()
	if host and "hp" in host and "prof" in host:
		var mx: float = float(host.prof.get("hp", 60.0))
		flesh_mat.set_shader_parameter("hurt", clampf(1.0 - float(host.hp) / maxf(mx, 1.0), 0.0, 1.0))
