class_name Socko
extends Node3D
## Socko: a grubby striped sock on Kurt's left hand. The hand is the puppet: the fingers are his
## upper jaw, the thumb his lower; the wrist turns his head. Googly eyes with loose pupils that
## each have their own spring and their own idea of where to look.
##
## Layers, added in order: pose (where the hand is held) → intention (face Kurt or not, emotion)
## → gestures (nod, tilt, bounce, startle; additive, decaying) → speech (jaw and head bob from
## Speech.mouth) → secondary motion (pupils, squash).

const POSES := {
	"hidden": [Vector3(-0.3, -0.75, -0.3), Vector3(0.1, 0.4, -1)],
	"low":    [Vector3(-0.24, -0.3, -0.4), Vector3(0.2, 0.25, -1)],
	"up":     [Vector3(-0.15, -0.15, -0.38), Vector3(0.25, 0.5, -1)],
	"talk":   [Vector3(-0.11, -0.12, -0.34), Vector3(0.35, 0.75, -0.5)],
}

var face_kurt := 0.0          ## 0: looks where the hand points; 1: turned round to Kurt
var emotion := "neutral"      ## neutral, happy, proud, curious, sly
var gaze_override := [null, null]   ## per eye: a world point to look at instead
var rig: Node3D
var head: Node3D
var upper: Node3D
var lower: Node3D
var eyes: Array[GooglyEye] = []

var _t := 0.0
var _g := {"nod": 0.0, "tilt": 0.0, "bounce": 0.0, "startle": 0.0, "wiggle": 0.0}
var _tween: Tween
var _squash := 1.0
var _cross := false
var _point := Vector3.INF

## Both googly eyes on the end of his own nose.
func cross_eyes(on: bool) -> void:
	_cross = on
	if not on:
		gaze_override = [null, null]

## Point the whole hand (and his nose) at a world position. Vector3.INF to stop.
func point_at(world: Vector3) -> void:
	_point = world
	if world != Vector3.INF:
		if _tween and _tween.is_valid():
			_tween.kill()
		face_kurt = 0.0

func build() -> void:
	var lift := Color(0.18, 0.18, 0.18)
	var sock := Look.mat(Look.get_tex("sock"), Color.WHITE, 0.0, true, lift)
	var sock_head := Look.mat(Look.get_tex("sock_head"), Color.WHITE, 0.0, true, lift)
	var felt := Look.mat(Look.get_tex("felt"), Color.WHITE, 0.0, true, lift)
	var coat := Look.mat(Look.get_tex("cloth"), Color("3b3128"), 0.0)
	rig = Node3D.new(); add_child(rig)
	# the coat sleeve, the sock's cuff (stripes) and its body over the hand
	_mesh(rig, _cyl(0.05, 0.058, 0.5), coat, Vector3(0, 0, 0.3), Vector3(PI * 0.5, 0, 0))
	_mesh(rig, _cyl(0.046, 0.05, 0.16), sock, Vector3(0, 0, -0.03), Vector3(-PI * 0.5, 0, 0))
	head = Node3D.new(); head.position = Vector3(0, 0, -0.1); rig.add_child(head)
	# upper jaw = the fingers: a long dome; lower jaw = the thumb: a flatter one
	upper = Node3D.new(); upper.position = Vector3(0, 0.0, 0.0); head.add_child(upper)
	var dome := _mesh(upper, _hemi(0.052), sock_head, Vector3(0, 0, -0.045), Vector3.ZERO)
	dome.scale = Vector3(1.0, 0.95, 1.45)
	_mesh(upper, _disc(0.05), felt, Vector3(0, -0.001, -0.045), Vector3.ZERO).scale = Vector3(0.98, 1, 1.42)
	lower = Node3D.new(); lower.position = Vector3(0, -0.004, 0.0); head.add_child(lower)
	var jaw := _mesh(lower, _hemi(0.05), sock_head, Vector3(0, 0, -0.04), Vector3(PI, 0, 0))
	jaw.scale = Vector3(0.96, 0.5, 1.35)
	_mesh(lower, _disc(0.048), felt, Vector3(0, 0.001, -0.04), Vector3.ZERO).scale = Vector3(0.95, 1, 1.3)
	var tongue := _mesh(lower, _hemi(0.03), felt, Vector3(0, 0.0, -0.05), Vector3.ZERO)
	tongue.scale = Vector3(0.9, 0.25, 1.3)
	# eyes: set apart on top of the head, not touching, each its own spring
	for s in [-1.0, 1.0]:
		var e := GooglyEye.new()
		upper.add_child(e)
		e.position = Vector3(0.027 * s, 0.045, -0.06)
		e.rotation = Vector3(-0.25, 0.22 * s, 0)
		e.build(0.019)
		eyes.append(e)
	set_pose("hidden", 0.0)
	visible = false

func _mesh(p: Node3D, m: Mesh, mat: Material, at: Vector3, rot: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m; mi.material_override = mat; mi.position = at; mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mi)
	return mi

func _cyl(r_top: float, r_bot: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new(); m.top_radius = r_top; m.bottom_radius = r_bot; m.height = h; m.radial_segments = 10; m.rings = 3; return m
func _hemi(r: float) -> SphereMesh:
	var m := SphereMesh.new(); m.radius = r; m.height = r; m.is_hemisphere = true; m.radial_segments = 12; m.rings = 5; return m
func _disc(r: float) -> CylinderMesh:
	var m := CylinderMesh.new(); m.top_radius = r; m.bottom_radius = r; m.height = 0.002; m.radial_segments = 12; m.rings = 1; return m

func set_pose(name: String, seconds := 0.6, trans := Tween.TRANS_SINE) -> Tween:
	var p: Array = POSES[name]
	var dir: Vector3 = (p[1] as Vector3).normalized()
	var xf := Transform3D(Basis.looking_at(dir, Vector3.UP), p[0])
	if _tween and _tween.is_valid():
		_tween.kill()
	if seconds <= 0.0:
		rig.transform = xf
		return null
	_tween = create_tween().set_trans(trans).set_ease(Tween.EASE_OUT)
	_tween.tween_property(rig, "transform", xf, seconds)
	return _tween

## He comes up into view from below, overshoots, settles.
func enter() -> void:
	visible = true
	set_pose("hidden", 0.0)
	set_pose("up", 0.9, Tween.TRANS_BACK)
	Sfx.play("pop", -6.0)
	gesture("bounce", 1.0)

## Additive gestures that decay by themselves: nod, tilt (signed), bounce, startle, wiggle.
func gesture(name: String, amount := 1.0) -> void:
	_g[name] = amount

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	for k in _g:
		_g[k] = move_toward(float(_g[k]), 0.0, delta * (1.2 if k != "tilt" else 0.6))
	var m := Speech.mouth("socko")
	var talking := Speech.speaking == "socko"
	# head orientation: toward Kurt (the camera, at the origin of our parent) or along the hand
	var cam_local := rig.transform.affine_inverse() * Vector3(0, 0.02, 0)
	var to_kurt := (cam_local - head.position).normalized()
	var up_local := (rig.transform.basis.inverse() * Vector3.UP).normalized()   # Kurt's up, so his head stays upright to Kurt
	var face := Basis.looking_at(to_kurt, up_local)
	var rest := Basis()
	var b := rest.slerp(face, face_kurt)
	# emotion and gesture offsets
	var tilt: float = _g["tilt"] * 0.45 + (0.18 if emotion == "curious" else 0.0) + (-0.1 if emotion == "sly" else 0.0)
	var nod: float = sin(_t * 9.0) * _g["nod"] * 0.35
	var bounce: float = absf(sin(_t * 11.0)) * _g["bounce"] * 0.03
	var startle: float = _g["startle"]
	var wig: float = sin(_t * 17.0) * _g["wiggle"] * 0.25
	var idle := sin(_t * 1.7) * 0.05 + sin(_t * 0.63) * 0.04
	var talk_bob := m * 0.12 if talking else 0.0
	var proud := 0.15 if emotion == "proud" or emotion == "happy" else 0.0
	b = b * Basis.from_euler(Vector3(-talk_bob - proud + nod + startle * 0.4 + idle * 0.5, wig + idle, tilt + idle * 0.4))
	head.basis = b
	head.position = Vector3(0, bounce + talk_bob * 0.02, -0.1 + startle * 0.03)
	# jaws: fingers lift, thumb drops; a little open when happy
	var open: float = m * 0.9 + (0.12 if emotion == "happy" else 0.0) + startle * 0.6
	upper.rotation.x = open * 0.55
	lower.rotation.x = -open * 0.22
	# squash and stretch: talking stretches, settling squashes
	var target: float = 1.0 + m * 0.08 - startle * 0.05 + bounce * 2.0
	_squash = lerpf(_squash, target, delta * 10.0)
	head.scale = Vector3(1.0 / sqrt(_squash), _squash, 1.0)
	if _point != Vector3.INF:
		var dir_local := to_local(_point) - rig.position
		if dir_local.length() > 0.01:
			var want := Basis.looking_at(dir_local.normalized(), Vector3.UP)
			rig.basis = rig.basis.slerp(want, minf(delta * 6.0, 1.0)).orthonormalized()
			rig.position = rig.position.lerp(Vector3(-0.1, -0.13, -0.42), minf(delta * 5.0, 1.0))
	if _cross and eyes.size() == 2:
		var mid := (eyes[0].global_position + eyes[1].global_position) * 0.5 - head.global_transform.basis.z * 0.02
		gaze_override = [mid, mid]
	# eyes: both on Kurt when facing him, else ahead; per-eye overrides win
	var kurt_world := get_viewport().get_camera_3d().global_position if get_viewport().get_camera_3d() else global_position
	for i in eyes.size():
		var e := eyes[i]
		var target_pt: Vector3
		if gaze_override[i] != null:
			target_pt = gaze_override[i]
		elif face_kurt > 0.5:
			target_pt = kurt_world
		else:
			target_pt = e.global_position - e.global_transform.basis.z * 2.0 + Vector3(sin(_t * 0.4 + i) * 0.3, 0, 0)
		e.look(target_pt)

## The sympathetic-listening trick: one eye stays on Kurt, the other slides off to something.
func divided_glance(at: Vector3, seconds := 1.4) -> void:
	gaze_override[1] = at
	await get_tree().create_timer(seconds, false).timeout
	gaze_override[1] = null
