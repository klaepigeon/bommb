class_name RightHand
extends Node3D
## Kurt's right arm and hand: the one that does things. It reaches for whatever he uses (door
## handles, drawers, switches, Marta's face), takes hold of what he carries and keeps it gripped,
## flicks forward to throw, and is where a weapon goes (`hold_weapon`). The left hand is Socko's
## and never does any of this.
##
## Built PS1-style, like Marta: rigid low-poly segments on a joint hierarchy (forearm in the coat
## sleeve → wrist → palm → three joints a finger, two and a base for the thumb), posed by curl. An
## old man's hand: big knuckles, thick fingers, a little stiff (the fingers never quite straighten).
## Out of the way, it drops below the frame; it comes up into view to be used.

const FOREARM := 0.26
const SHOULDER := Vector3(0.24, -0.42, 0.12)     # where the arm comes from, in the camera's frame
const REST := Vector3(0.24, -0.62, -0.22)        # wrist, lowered out of sight

var cam: Camera3D
var player: Node
var arm: Node3D            # elbow; the forearm runs along -Z
var wrist: Node3D
var fingers: Array = []    # [[j0, j1, j2], ...] index, middle, ring, little
var thumb: Array = []      # [base, j1, j2]
var curl := 0.35           # 0 open .. 1 a fist (current)
var spread := 0.0
var weapon: Node3D = null

var _want_curl := 0.35
var _reach_t := -1.0; var _reach_at := Vector3.ZERO
var _throw_t := -1.0
var _w_pos := Vector3.ZERO; var _w_vel := Vector3.ZERO
var _w_rot := Quaternion.IDENTITY
var _started := false

func setup(p_cam: Camera3D, p_player: Node) -> void:
	cam = p_cam; player = p_player

func _ready() -> void:
	top_level = true
	_build()

# ---------------------------------------------------------------- what he does with it
## Reach out to a point (what he's using) and come back.
func reach(p: Vector3) -> void:
	_reach_t = 0.0; _reach_at = p

func throw_flick() -> void:
	_throw_t = 0.0

## A weapon in the right hand: parented to the palm, gripped. null puts it away.
func hold_weapon(w: Node3D) -> void:
	if weapon and weapon.get_parent() == wrist:
		wrist.remove_child(weapon)
	weapon = w
	if w:
		if w.get_parent(): w.get_parent().remove_child(w)
		wrist.add_child(w)
		w.transform = Transform3D(Basis(), Vector3(0, -0.035, -0.06))

func busy() -> bool:
	return _reach_t >= 0.0 or _throw_t >= 0.0 or (player and player.get("held") != null) or weapon != null

# ---------------------------------------------------------------- the frame
func _process(delta: float) -> void:
	if not cam or delta <= 0.0:
		return
	delta = minf(delta, 0.1)
	var cx := cam.global_transform
	var held: Node3D = player.get("held") if player else null
	var target := cx * REST
	var palm := Basis.looking_at(Vector3(-0.15, 0.1, -1.0).normalized(), Vector3.UP)   # in the camera frame
	_want_curl = 0.4
	var follow := 14.0
	if held and is_instance_valid(held):
		# grip it from the right-hand side and a little underneath, palm in toward it
		var r := _radius(held)
		var c := held.global_position
		target = c + cx.basis.x * (r * 0.75 + 0.02) - cx.basis.y * (r * 0.35)
		palm = Basis.looking_at(Vector3(-0.35, 0.05, -1.0).normalized(), Vector3.UP).rotated(Vector3.FORWARD, -1.1)
		_want_curl = 0.72
		follow = 30.0
	elif weapon:
		target = cx * Vector3(0.12, -0.2, -0.38)
		palm = Basis.looking_at(Vector3(-0.05, 0.02, -1.0).normalized(), Vector3.UP).rotated(Vector3.FORWARD, -1.5)
		_want_curl = 0.85
	if _reach_t >= 0.0:
		# out, a touch, back: anticipation is the elbow lifting first
		_reach_t += delta
		var u := _reach_t / 0.62
		var k := smoothstep(0.0, 0.32, u) * (1.0 - smoothstep(0.55, 1.0, u))
		var at := _reach_at
		var from := cx.origin
		if from.distance_to(at) > 0.62:      # he can't reach further than his arm
			at = from + (at - from).normalized() * 0.62
		at -= (at - from).normalized() * 0.04   # fingertips touch, not the wrist
		target = target.lerp(at, k)
		palm = palm.slerp(Basis.looking_at((at - from).normalized() * cx.basis, Vector3.UP).rotated(Vector3.FORWARD, -0.6), k)
		_want_curl = lerpf(_want_curl, 0.15, k)
		follow = 22.0
		if u >= 1.0: _reach_t = -1.0
	if _throw_t >= 0.0:
		_throw_t += delta
		var u2 := _throw_t / 0.45
		var back := sin(PI * minf(u2 / 0.35, 1.0)) * (1.0 if u2 < 0.35 else 0.0)
		var fwd := sin(PI * clampf((u2 - 0.3) / 0.7, 0.0, 1.0))
		target = cx * (Vector3(0.22, -0.18, -0.25) + Vector3(0.03, 0.06, 0.12) * back + Vector3(-0.06, 0.02, -0.25) * fwd)
		_want_curl = lerpf(0.75, 0.05, smoothstep(0.35, 0.5, u2))
		follow = 40.0
		if u2 >= 1.0: _throw_t = -1.0
	if not _started:
		_w_pos = target; _w_rot = (cx.basis * palm).get_rotation_quaternion(); _started = true
	# the wrist on a stiff spring (substepped), the hand turning after it
	var n := int(ceil(delta / (1.0 / 240.0))); var h := delta / n
	for i in n:
		_w_vel += ((target - _w_pos) * follow * follow - _w_vel * 2.0 * 0.85 * follow) * h
		_w_pos += _w_vel * h
	_w_rot = _w_rot.slerp((cx.basis * palm).get_rotation_quaternion(), 1.0 - pow(0.0005, delta))
	curl = lerpf(curl, _want_curl, 1.0 - pow(0.002, delta))
	_place(cx)
	_pose_fingers()

## Elbow from the shoulder toward the wrist, so the forearm always meets the hand.
func _place(cx: Transform3D) -> void:
	var sh := cx * SHOULDER
	var dir := (_w_pos - sh)
	if dir.length() < 0.05: dir = -cx.basis.z
	dir = dir.normalized()
	# the forearm comes up at the wrist from below and to the right
	var fdir := (dir + cx.basis.y * 0.25 - cx.basis.x * 0.1).normalized()
	var elbow := _w_pos - fdir * FOREARM
	arm.global_transform = Transform3D(Basis.looking_at(fdir, cx.basis.y), elbow)
	wrist.global_transform = Transform3D(Basis(_w_rot), _w_pos)

func _radius(b: Node3D) -> float:
	var r := 0.06
	for mi in b.find_children("*", "MeshInstance3D", true, false):
		var aabb: AABB = (mi as MeshInstance3D).get_aabb()
		r = maxf(r, aabb.size.length() * 0.5 * (mi as Node3D).global_transform.basis.get_scale().x)
	return minf(r, 0.25)

# ---------------------------------------------------------------- the hand
var _skin: StandardMaterial3D
var _knuckle: StandardMaterial3D

func _seg(parent: Node3D, length: float, r0: float, r1: float, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = r1; cm.bottom_radius = r0; cm.height = length
	cm.radial_segments = 6; cm.rings = 1
	m.mesh = cm; m.material_override = mat
	m.rotation.x = -PI / 2; m.position.z = -length * 0.5     # along -Z
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m

func _ball(parent: Node3D, r: float, mat: Material, at := Vector3.ZERO) -> void:
	var m := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0
	sm.radial_segments = 6; sm.rings = 3
	m.mesh = sm; m.material_override = mat; m.position = at
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = 0.85
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m

func _build() -> void:
	_skin = _mat(Color("b08a70")); _knuckle = _mat(Color("9a7460"))
	var wool := _mat(Color("2e2b26"))
	arm = Node3D.new(); arm.name = "Forearm"; add_child(arm)
	_seg(arm, FOREARM - 0.06, 0.05, 0.045, wool)                       # the coat sleeve
	var cuff := _seg(arm, 0.03, 0.047, 0.047, _mat(Color("24221e"))); cuff.position.z = -(FOREARM - 0.075)
	var wr := _seg(arm, 0.07, 0.029, 0.026, _skin); wr.position.z = -(FOREARM - 0.035)   # the wrist out of the cuff
	wrist = Node3D.new(); wrist.name = "Wrist"; add_child(wrist)
	# palm: a flattened, slightly cupped block, wider at the knuckles
	var palm := MeshInstance3D.new()
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshKit.blob(st, Vector3(0, 0, -0.045), Vector3(0.042, 0.016, 0.05), {"rings": 5, "segs": 8, "bumps": 0.06, "seed": 3.0})
	st.generate_normals(); palm.mesh = st.commit(); palm.material_override = _skin
	palm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wrist.add_child(palm)
	# fingers: index, middle, ring, little; across the knuckles; three segments each
	var lens := [0.074, 0.08, 0.075, 0.06]
	var xs := [-0.028, -0.009, 0.01, 0.027]
	for i in 4:
		var base := Node3D.new(); base.position = Vector3(xs[i], 0.002, -0.088 + absf(xs[i]) * 0.25)
		base.rotation.y = -xs[i] * 0.8
		wrist.add_child(base)
		var chain := [base]
		var parts := [0.45, 0.3, 0.25]
		var node := base
		for j in 3:
			var L: float = lens[i] * parts[j]
			var r := 0.0098 - j * 0.0012 - (0.0015 if i == 3 else 0.0)
			_ball(node, r * 1.12, _knuckle)                                  # the knuckle
			_seg(node, L, r, r * 0.92, _skin)
			if j < 2:
				var nx := Node3D.new(); nx.position = Vector3(0, 0, -L); node.add_child(nx)
				chain.append(nx); node = nx
		fingers.append(chain)
	# thumb: from the heel of the palm, out to the side and forward
	var tb := Node3D.new(); tb.position = Vector3(-0.034, -0.008, -0.02); tb.rotation = Vector3(0, 0.75, 0.5)
	wrist.add_child(tb)
	_seg(tb, 0.035, 0.013, 0.011, _skin)
	var t1 := Node3D.new(); t1.position = Vector3(0, 0, -0.035); tb.add_child(t1)
	_ball(t1, 0.012, _knuckle); _seg(t1, 0.03, 0.011, 0.01, _skin)
	var t2 := Node3D.new(); t2.position = Vector3(0, 0, -0.03); t1.add_child(t2)
	_ball(t2, 0.0105, _knuckle); _seg(t2, 0.024, 0.01, 0.0085, _skin)
	thumb = [tb, t1, t2]
	for mi in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).layers = 1 | 2      # Socko's spill light catches it too

func _pose_fingers() -> void:
	var c := clampf(curl, 0.0, 1.0)
	for i in fingers.size():
		var ch: Array = fingers[i]
		var stiff := 0.12 + i * 0.03            # he can't quite straighten them, the little one least
		var k := c + stiff * (1.0 - c) + i * 0.04 * c
		(ch[0] as Node3D).rotation.x = -k * 1.35
		(ch[1] as Node3D).rotation.x = -k * 1.55
		(ch[2] as Node3D).rotation.x = -k * 1.05
	(thumb[0] as Node3D).rotation = Vector3(-c * 0.35, 0.75 - c * 0.45, 0.5 + c * 0.25)
	(thumb[1] as Node3D).rotation.x = -c * 0.6
	(thumb[2] as Node3D).rotation.x = -c * 0.75
