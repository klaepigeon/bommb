class_name KurtBody
extends Node3D
## The rest of Kurt, for when you look down: chest, belly, hips, the coat to mid-thigh, legs, knees,
## shoes. One body with the right arm (KurtArm) and Socko's forearm: the torso's right shoulder is
## the arm's shoulder, and the left upper sleeve runs from the torso to wherever Socko's elbow is.
## (Master document §6; docs/KURT.md: canon height 177.8 cm.)
##
## Proportions after standard segment ratios of stature H (Drillis & Contini; Winter): hip joint
## 0.53 H, knee 0.285 H, ankle 0.039 H, thigh and shank each ~0.245 H, foot 0.152 H, hip joints
## 0.09 m either side of the midline. The eye is at the player's eye height; the trunk hangs a
## little behind it (the eyes are in front of the neck), so it never comes into the forward view.
##
## Gait: the feet step with his speed and direction (stance, swing, a heel-lift), the knees solve to
## them by two-bone IK, the pelvis rolls and counter-rotates with the stride and bobs. Standing, the
## weight is on the right leg, the left a little forward and turned out, the hip dropped on the
## free side (an older man's way of standing, not a soldier's). Crouched, the knees come forward
## and the trunk leans. Clothes are ordinary dress: the same dark wool coat as the sleeve, dark
## trousers, black shoes.

const H := 1.778
const HIP_Y := 0.53 * H
const KNEE_Y := 0.285 * H
const ANKLE_Y := 0.039 * H
const THIGH := 0.245 * H
const SHANK := 0.246 * H
const FOOT := 0.152 * H
const HIP_X := 0.09
const BACK := 0.13          # the trunk sits this far behind the eye
const STRIDE := 1.3         # a full walking cycle, metres

var player: Node
var parts := {}
var _phase := 0.0
var _speed := 0.0
var _dir := Vector3(0, 0, -1)
var _crouch := 0.0
var _t := 0.0
var _mats := {}
var _kick_t := -1.0          # into a kick (the right foot out and back), or -1

## the right foot out at something in the way, and back: about a third of a second
func kick() -> void:
	_kick_t = 0.0

func setup(p_player: Node) -> void:
	player = p_player

func _ready() -> void:
	for spec in [["coat", "coat", 0.95, 0.15, Vector2(3, 2)], ["trousers", "coat", 0.95, 0.12, Vector2(4, 4)], ["shoe", "", 0.35, 0.6, Vector2.ONE], ["shirt", "cuff", 0.85, 0.2, Vector2.ONE]]:
		var m := ShaderMaterial.new(); m.shader = load("res://shaders/ps1_lit.gdshader")
		m.set_shader_parameter("albedo_tex", KurtTextures.get_tex(spec[1]) if spec[1] != "" else TownKit._white())
		m.set_shader_parameter("roughness", spec[2]); m.set_shader_parameter("specular", spec[3])
		m.set_shader_parameter("uv_scale", spec[4]); m.set_shader_parameter("snap_res", Vector2(640, 480))
		if spec[0] == "trousers": m.set_shader_parameter("albedo_color", Color(0.42, 0.42, 0.46))
		if spec[0] == "shoe": m.set_shader_parameter("albedo_color", Color(0.05, 0.045, 0.045))
		m.set_shader_parameter("emission", Vector3(0.03, 0.027, 0.024))     # readable in the dark on a phone
		_mats[spec[0]] = m
	# segments are unit-length along +Y from 0 to 1, oriented and stretched each frame
	_seg("abdomen", "coat", 0.14, 0.155, 0.62)
	_seg("chest", "coat", 0.155, 0.17, 0.55)
	_seg("skirt", "coat", 0.165, 0.2, 0.75)
	for s in ["l", "r"]:
		_seg("thigh_" + s, "trousers", 0.072, 0.052, 1.0)
		_seg("shank_" + s, "trousers", 0.05, 0.04, 1.0)
		_foot("foot_" + s)
	_seg("upper_l", "coat", 0.05, 0.047, 1.0)        # the left upper sleeve, to Socko's elbow
	for p in parts.values():
		(p as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(p as MeshInstance3D).layers = 1 | 2          # Socko's soft spill (cull mask 2) finds him, as it does the hand

## a tapered tube along +Y, 0..1, flattened front to back by `flat`
func _seg(name: String, mat: String, r0: float, r1: float, flat: float) -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const N := 10
	for i in N:
		var a0 := TAU * i / N; var a1 := TAU * (i + 1) / N
		var p := [Vector3(cos(a0) * r0, 0, sin(a0) * r0 * flat), Vector3(cos(a1) * r0, 0, sin(a1) * r0 * flat),
			Vector3(cos(a1) * r1, 1, sin(a1) * r1 * flat), Vector3(cos(a0) * r1, 1, sin(a0) * r1 * flat)]
		var n0 := Vector3(cos(a0), 0, sin(a0)); var n1 := Vector3(cos(a1), 0, sin(a1))
		for k in [[0, n0, 0.0, 0.0], [2, n1, 1.0, 1.0], [1, n1, 1.0, 0.0], [0, n0, 0.0, 0.0], [3, n0, 0.0, 1.0], [2, n1, 1.0, 1.0]]:
			st.set_normal(k[1]); st.set_uv(Vector2(float(i + k[2]) / N, k[3])); st.add_vertex(p[k[0]])
	# caps
	for y in [0.0, 1.0]:
		var r: float = r0 if y == 0.0 else r1
		for i in N:
			var a0 := TAU * i / N; var a1 := TAU * (i + 1) / N
			var nrm := Vector3(0, -1 if y == 0.0 else 1, 0)
			var tri := [Vector3(0, y, 0), Vector3(cos(a0) * r, y, sin(a0) * r * flat), Vector3(cos(a1) * r, y, sin(a1) * r * flat)]
			if y == 0.0: tri = [tri[0], tri[1], tri[2]]
			else: tri = [tri[0], tri[2], tri[1]]
			for v in tri: st.set_normal(nrm); st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(v)
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = _mats[mat]; mi.name = name
	add_child(mi); parts[name] = mi

## a shoe: toe box, heel, sole; origin at the ankle, toe along -Z
func _foot(name: String) -> void:
	var mi := MeshInstance3D.new(); mi.name = name
	var k := TownKit.new(mi)
	k.box("iron", Vector3(0, -ANKLE_Y + 0.035, -0.06), Vector3(0.048, 0.035, 0.1))
	k.box("iron", Vector3(0, -ANKLE_Y + 0.03, -0.17), Vector3(0.044, 0.028, 0.035))
	k.box("iron", Vector3(0, -ANKLE_Y + 0.008, -0.07), Vector3(0.052, 0.008, 0.135))
	k.box("iron", Vector3(0, -ANKLE_Y + 0.07, 0.02), Vector3(0.042, 0.04, 0.05))
	k.finish()
	for c in mi.get_children():
		(c as MeshInstance3D).material_override = _mats.shoe; (c as MeshInstance3D).layers = 1 | 2
		(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi); parts[name] = mi

## a segment from a to b (body space), its front facing `fwd`
func _place(name: String, a: Vector3, b: Vector3, fwd := Vector3(0, 0, -1)) -> void:
	var mi: MeshInstance3D = parts[name]
	var y := b - a
	var l := y.length()
	if l < 0.001: return
	var yn := y / l
	var x := yn.cross(fwd).normalized()
	if x.length() < 0.5: x = Vector3.RIGHT
	var z := x.cross(yn).normalized()
	mi.transform = Transform3D(Basis(x, y, z), a)

## two-bone leg: hip, foot target (ankle), knee bending forward along `fwd`
func _leg(s: String, hip: Vector3, ankle: Vector3, fwd: Vector3) -> void:
	var d := ankle - hip
	var L := clampf(d.length(), 0.05, THIGH + SHANK - 0.002)
	var dn := d.normalized()
	ankle = hip + dn * L
	var a := (THIGH * THIGH + L * L - SHANK * SHANK) / (2.0 * L)
	var h := sqrt(maxf(0.0, THIGH * THIGH - a * a))
	var bend := (fwd - dn * fwd.dot(dn)).normalized()
	var knee := hip + dn * a + bend * h
	_place("thigh_" + s, knee, hip, fwd)
	_place("shank_" + s, ankle, knee, fwd)
	var foot: MeshInstance3D = parts["foot_" + s]
	var yaw := atan2(-fwd.x, -fwd.z) + (0.18 if s == "l" else -0.06)
	foot.transform = Transform3D(Basis(Vector3.UP, yaw), ankle)

func _process(delta: float) -> void:
	if not player: return
	_t += delta
	var lying: bool = (player.get("head") as Node3D).position.y < 1.1
	visible = not lying
	if lying: return
	var head: Node3D = player.get("head")
	var vel: Vector3 = player.get("velocity")
	var vl: Vector3 = (player as Node3D).global_transform.basis.inverse() * Vector3(vel.x, 0, vel.z)
	_speed = lerpf(_speed, vl.length(), 1.0 - exp(-delta * 10.0))
	if vl.length() > 0.2: _dir = _dir.lerp(vl.normalized(), 1.0 - exp(-delta * 8.0)).normalized()
	_crouch = lerpf(_crouch, 0.0, 1.0 - exp(-delta * 8.0))
	_phase = fposmod(_phase + delta * _speed / STRIDE, 1.0)
	if _kick_t >= 0.0:
		_kick_t += delta
		if _kick_t > 0.32: _kick_t = -1.0
	var moving := smoothstep(0.15, 0.6, _speed)
	var fwd := Vector3(0, 0, -1)
	# the pelvis: under the eye, a little behind; it bobs twice a cycle, rolls and counter-turns
	var drop := 1.62 - head.position.y           # how far the eye is below standing (crouch)
	var pel := Vector3(0, HIP_Y - drop * 0.82 - 0.02 * moving * abs(cos(_phase * TAU)), BACK + 0.04 * _crouch)
	var idle_shift := (1.0 - moving) * 0.035      # weight on the right leg when he stands
	pel.x += idle_shift * 0.6
	var roll := sin(_phase * TAU) * 0.05 * moving + (1.0 - moving) * -0.045
	var turn := sin(_phase * TAU) * 0.08 * moving
	var pb := Basis(Vector3.UP, turn) * Basis(Vector3.BACK, roll)
	# the trunk: from the hips to where the arm's shoulders hang off the neck, leaning when crouched
	var neck := head.position + Vector3(0, -0.21, BACK + 0.035)
	var waist := pel + pb * Vector3(0, 0.2, 0) + Vector3(0, 0, -0.06 * _crouch)
	var breath := 1.0 + 0.012 * sin(_t * 1.4)
	_place("abdomen", pel + pb * Vector3(0, -0.04, 0), waist, pb * fwd)
	_place("chest", waist, neck + Vector3(0, -0.04, 0), fwd)
	(parts.chest as MeshInstance3D).scale.x = breath
	_place("skirt", pel + pb * Vector3(0, -0.3 + 0.08 * _crouch, 0.01), pel + pb * Vector3(0, 0.12, 0), pb * fwd)
	# the legs
	for s in ["l", "r"]:
		var side := -1.0 if s == "l" else 1.0
		var hip := pel + pb * Vector3(side * HIP_X, -0.02, 0)
		var ph := fposmod(_phase + (0.5 if s == "l" else 0.0), 1.0)
		# stance (first half): the foot planted, sliding back under him at his speed; swing: forward, lifted
		var along := 0.0; var lift := 0.0
		if ph < 0.5: along = lerpf(STRIDE * 0.25, -STRIDE * 0.25, ph / 0.5)
		else:
			var u := (ph - 0.5) / 0.5
			along = lerpf(-STRIDE * 0.25, STRIDE * 0.25, smoothstep(0.0, 1.0, u)); lift = sin(u * PI) * 0.09 * moving
		var step := _dir * along * moving
		# standing: the left a little forward and turned out, the weight on the right
		var stance := Vector3(side * (0.03 if s == "l" else 0.01), 0, (-0.09 if s == "l" else 0.03)) * (1.0 - moving)
		var ankle := Vector3(side * HIP_X * 1.05, ANKLE_Y + lift, BACK - 0.1) + step + stance
		ankle.z -= 0.18 * _crouch * (1.0 if s == "l" else 0.4)
		if s == "r" and _kick_t >= 0.0:
			var k := sin(clampf(_kick_t / 0.32, 0.0, 1.0) * PI)
			ankle = ankle.lerp(Vector3(HIP_X * 0.6, 0.32, BACK - 0.6), k)
		_leg(s, hip, ankle, fwd)
	# the left upper sleeve, from the shoulder to Socko's elbow
	var socko = player.get("socko")
	var up: MeshInstance3D = parts.upper_l
	up.visible = socko != null and socko.visible
	if up.visible:
		var elbow: Vector3 = (player as Node3D).global_transform.affine_inverse() * (socko as Node3D).global_position
		var sh := head.position + Vector3(-0.19, -0.26, 0.10)
		_place("upper_l", elbow, sh, fwd)
