class_name FPArm
extends Node3D
## Kurt's free arm in first person (Socko's on the other): the ArmRig placed by two-bone IK in the
## camera's space. Most of the time it's down out of sight. It comes up when he does something:
## out to whatever he's using (open, then closing on it), round whatever he's carrying, up onto a
## sill when he climbs. The revolver has its own hand, so the arm stands down while it's out.
## Socko on the right (Settings: socko_side) mirrors it to the left.

const SHOULDER := Vector3(0.21, -0.33, 0.14)
const POLE := Vector3(1.0, -1.3, 0.5)          ## the elbow goes out and down
const REST := Vector3(0.27, -0.56, -0.2)        ## below the bottom of the screen
const REACH_TIME := 0.5

var rig: ArmRig
var kurt
var _w := REST
var _reach_t := -1.0
var _reach_to := Vector3.ZERO
var _reach_verb := ""
var _t := 0.0

func setup(k) -> void:
	kurt = k
	rig = ArmRig.new(); rig.name = "ArmRig"
	add_child(rig)
	rig.idle = true
	_side()
	Settings.changed.connect(_side)
	_light_it(rig)
	k.reached.connect(_on_reach)
	visible = false

func _side() -> void:
	scale.x = -1.0 if String(Settings.get_v("socko_side")) == "right" else 1.0

## Close to the eye: no vertex snap, and enough ambient to read in the dark, like the revolver.
func _light_it(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.get_surface_override_material_count():
			var m := mi.get_active_material(i)
			if m is ShaderMaterial:
				var mm := (m as ShaderMaterial).duplicate() as ShaderMaterial
				mm.set_shader_parameter("snap", 0.0); mm.set_shader_parameter("ambient", Vector3(0.24, 0.22, 0.21))
				mi.set_surface_override_material(i, mm)
		if mi.material_override is ShaderMaterial:
			var mo := (mi.material_override as ShaderMaterial).duplicate() as ShaderMaterial
			mo.set_shader_parameter("snap", 0.0); mo.set_shader_parameter("ambient", Vector3(0.24, 0.22, 0.21))
			mi.material_override = mo
	for c in n.get_children(): _light_it(c)

func _on_reach(at: Vector3, verb: String) -> void:
	if kurt.gun_out: return
	_reach_to = get_parent().to_local(at)
	if scale.x < 0.0: _reach_to.x = -_reach_to.x
	_reach_verb = verb
	_reach_t = 0.0

## A hand frame: fingers along `fingers`, the back of the hand toward `back`.
static func hand(fingers: Vector3, back: Vector3) -> Basis:
	var y := fingers.normalized()
	var z := (back - y * back.dot(y)).normalized()
	return Basis(y.cross(z), y, z)

func _process(delta: float) -> void:
	if kurt == null: return
	_t += delta
	var want := REST
	var b := hand(Vector3(-0.1, -0.2, -1), Vector3(0.3, 1, 0))
	var pose := "relaxed"
	if kurt.gun_out:
		visible = false; _w = REST; _reach_t = -1.0
		return
	if kurt.climbing:
		want = Vector3(0.17, -0.1 + sin(_t * 9.0) * 0.015, -0.44)
		b = hand(Vector3(-0.15, 0.25, -1), Vector3(0, 1, 0.2))
		pose = "flat"
	elif kurt.held:
		var hp: Vector3 = kurt.hand_anchor.position
		want = hp + Vector3(0.05, -0.04, 0.14)
		b = hand(Vector3(-0.35, 0.1, -1), Vector3(1, 0.4, 0))
		pose = "grip" if kurt.held.mass > 3.0 else "hold"
	elif kurt.rail_axis != Vector3.ZERO:
		# on the ledge: a hand flat on the wall beside him
		want = Vector3(0.2, -0.16 + sin(_t * 0.9) * 0.01, -0.36)
		b = hand(Vector3(0.2, 0.3, -1), Vector3(-1, 0.2, 0))
		pose = "flat"
	if _reach_t >= 0.0:
		_reach_t += delta / REACH_TIME
		var out := sin(clampf(_reach_t, 0.0, 1.0) * PI)
		var to := _reach_to
		var from_sh := to - SHOULDER
		if from_sh.length() > 0.56: to = SHOULDER + from_sh.normalized() * 0.56
		to -= from_sh.normalized() * 0.07                       # the wrist stops short; the fingers arrive
		want = want.lerp(to, out)
		b = b.slerp(hand(from_sh, Vector3(0.25, 1, 0.1)), out)
		pose = "reach" if _reach_t < 0.45 else ("grip" if _reach_verb in ["lift", "pocket", "take", "pick"] else "flat")
		if _reach_t >= 1.0: _reach_t = -1.0
	_w = _w.lerp(want, minf(1.0, delta * 11.0))
	visible = _w.distance_to(REST) > 0.04
	if not visible: return
	rig.pose_name = pose
	rig.solve_arm(SHOULDER, Transform3D(b.orthonormalized(), _w), POLE)
