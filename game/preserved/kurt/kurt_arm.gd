class_name KurtArm
extends Node3D
## Kurt's right arm in first person: the first build's anatomical arm (ArmRig: one skeleton,
## coat sleeve, cuff, jointed fingers), placed by IK from his shoulder to where the scene wants
## his hand. A pose is where the wrist is (camera space), where the fingers point, where the palm
## faces, and what the fingers do. Small procedural layers on top: rubbing, rattling.
## `wrist` follows the hand (things he holds hang off it): -Z along the fingers, -Y the palm.

const SHOULDER := Vector3(0.19, -0.26, 0.10)
const ELBOW_POLE := Vector3(0.7, -1.0, 0.25)

## name: [wrist (camera space), fingers, palm normal, finger pose]
const POSES := {
	"down":   [Vector3(0.15, -0.235, -0.3), Vector3(-0.22, -0.32, -1.0), Vector3(-0.88, -0.3, -0.12), "relaxed"],
	"push":   [Vector3(0.09, -0.1, -0.42), Vector3(0.05, 1.0, -0.25), Vector3(0, 0.15, -1), "flat"],
	"reach":  [Vector3(0.08, -0.17, -0.42), Vector3(-0.15, -0.05, -1), Vector3(0, -1, 0), "reach"],
	"rub":    [Vector3(0.1, 0.06, -0.24), Vector3(-0.65, 0.75, -0.15), Vector3(0, 0, 1), "open"],
	"handle": [Vector3(0.1, -0.25, -0.42), Vector3(-0.25, 0, -1), Vector3(-1, 0, 0), "grip"],
	"gun":    [Vector3(0.23, -0.2, -0.38), Vector3(0, -0.33, -1), Vector3(-1, -0.3, 0), "grip"],
	"aim":    [Vector3(0.055, -0.11, -0.36), Vector3(0, -0.36, -1), Vector3(-1, -0.05, 0), "grip"],
	"loading":[Vector3(0.07, -0.22, -0.32), Vector3(-0.5, 0.45, -0.75), Vector3(-0.6, -0.8, 0), "grip"],
	"hold":   [Vector3(0.12, -0.2, -0.36), Vector3(-0.35, 0.05, -1.0), Vector3(-0.3, 0.92, -0.25), "hold"],
	"note":   [Vector3(0.135, -0.235, -0.33), Vector3(-0.12, 0.95, -0.1), Vector3(-0.5, 0.05, 1.0), "pinch"],
	"throw":  [Vector3(0.2, 0.05, -0.15), Vector3(0, 1, 0.3), Vector3(0, 0, -1), "hold"],
	"brace":  [Vector3(0.12, -0.04, -0.34), Vector3(0.1, 1, -0.3), Vector3(0, 0, -1), "open"],
}

var rig: ArmRig
var wrist: Node3D
var pose := "down"
var rub := 0.0
var rattle := 0.0
var body: CollisionObject3D      ## Kurt (rays that look for walls leave him out)
var reach_extra := 0.0           ## how far what's in the hand sticks out past the fingers
var pull := 0.0                  ## how far the hand is drawn back from a wall right now
var _from := Transform3D.IDENTITY
var _to := Transform3D.IDENTITY
var _k := 1.0
var _dur := 0.0
var _t := 0.0

func build() -> void:
	rig = ArmRig.new()
	rig.name = "Arm"
	add_child(rig)
	wrist = Node3D.new()
	wrist.name = "Wrist"
	add_child(wrist)
	_to = _pose_xf("down")
	_from = _to
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _pose_xf(name: String) -> Transform3D:
	var p: Array = POSES[name]
	var palm: Vector3 = p[2]
	return Transform3D(ArmRig.frame(p[1], -palm), p[0])

func set_pose(name: String, seconds := 0.45) -> void:
	pose = name
	_from = _current()
	_to = _pose_xf(name)
	_dur = maxf(seconds, 0.0001)
	_k = 0.0 if seconds > 0.0 else 1.0
	rig.pose_name = POSES[name][3]

func _current() -> Transform3D:
	var e := _ease(_k)
	return Transform3D(_from.basis.slerp(_to.basis, e).orthonormalized(), _from.origin.lerp(_to.origin, e))

static func _ease(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)

func _process(delta: float) -> void:
	if rig == null:
		return
	_t += delta
	_k = minf(_k + delta / maxf(_dur, 0.0001), 1.0)
	var xf := _current()
	xf.origin += Vector3(sin(_t * 9.0) * 0.022 * rub, cos(_t * 18.0) * 0.01 * rub, 0)
	xf.origin += Vector3(sin(_t * 24.0) * 0.012 * rattle, 0, cos(_t * 24.0) * 0.01 * rattle)
	if rub > 0.0:
		xf.basis = xf.basis.rotated(Vector3.BACK, sin(_t * 9.0) * 0.15 * rub)
	xf = _clear_of_walls(xf)
	rig.idle = pose == "down"
	rig.solve_arm(SHOULDER, xf, ELBOW_POLE)
	# where things in his hand hang: the middle of the palm, in our old convention
	var h: Transform3D = rig.skeleton.get_bone_global_pose(rig.B.hand)
	var fingers := h.basis.y.normalized()
	var back := h.basis.z.normalized()
	var z := -fingers
	var y := back
	var x := y.cross(z).normalized()
	wrist.transform = Transform3D(Basis(x, y, z), h.origin + fingers * 0.05 - back * 0.02)

## Keep the hand (and what's in it) out of walls: if something solid is nearer than the hand
## reaches, draw it back along the line of sight to it, and down a little. Eased, so brushing past
## a door frame is a movement of the arm, not a jump.
func _clear_of_walls(xf: Transform3D) -> Transform3D:
	var cam := get_parent() as Node3D
	if cam == null or not is_inside_tree():
		return xf
	var tip := xf.origin + xf.basis.y * (0.19 + reach_extra)      # the rig's hand frame: +Y along the fingers
	var from := cam.global_position
	var to: Vector3 = cam.global_transform * tip
	var dir := (to - from).normalized()
	var q := PhysicsRayQueryParameters3D.create(from, to + dir * 0.06, 1)
	if body:
		q.exclude = [body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var over := 0.0
	if hit:
		over = clampf(from.distance_to(to) + 0.06 - from.distance_to(hit.position), 0.0, 0.3 + reach_extra)
	pull = lerpf(pull, over, 0.3 if over > pull else 0.1)
	if pull > 0.001:
		var back := tip.normalized() * pull
		xf.origin -= back
		xf.origin.y -= pull * 0.35
	return xf
