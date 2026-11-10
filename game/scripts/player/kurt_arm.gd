class_name KurtArm
extends Node3D
## Kurt's right arm in first person: coat sleeve, hand, fingers that curl. Posed by name, eased
## between poses; small procedural motion on top (rubbing, rattling, a tremor after the blow).
## A pose is where the wrist is (camera space), where the fingers point and where the palm faces.

const POSES := {
	"down":   [Vector3(0.28, -0.62, -0.25), Vector3(0, 0, -1), Vector3(0, -1, 0), 0.3],
	"push":   [Vector3(0.1, -0.14, -0.42), Vector3(0, 1, -0.15), Vector3(0, 0, -1), 0.05],
	"reach":  [Vector3(0.1, -0.2, -0.42), Vector3(-0.15, -0.1, -1), Vector3(0, -1, 0), 0.25],
	"rub":    [Vector3(0.1, 0.04, -0.31), Vector3(-0.65, 0.75, -0.15), Vector3(0, 0, 1), 0.35],
	"handle": [Vector3(0.12, -0.3, -0.42), Vector3(-0.2, 0, -1), Vector3(-1, 0, 0), 0.85],
	"brace":  [Vector3(0.14, -0.06, -0.3), Vector3(0.1, 1, -0.3), Vector3(0, 0, -1), 0.0],
}

var wrist: Node3D
var pose := "down"
var curl := 0.3
var rub := 0.0          ## 0..1: rubbing his head
var rattle := 0.0       ## 0..1: trying a handle
var _fingers: Array[Node3D] = []
var _t := 0.0
var _tween: Tween

func build() -> void:
	var lift := Color(0.22, 0.22, 0.22)   # a little self-light so the hands read in the dark, on a phone
	var skin := Look.mat(Look.get_tex("skin_kurt"), Color.WHITE, 0.0, false, lift)
	var coat := Look.mat(Look.get_tex("cloth"), Color("3b3128"), 0.0, false, lift)
	var cuff := Look.mat(Look.get_tex("cloth"), Color("bfb7a6"), 0.0)
	wrist = Node3D.new(); add_child(wrist)
	_mesh(wrist, _cyl(0.042, 0.5), coat, Vector3(0, 0, 0.27), Vector3(PI * 0.5, 0, 0))
	_mesh(wrist, _cyl(0.034, 0.03), cuff, Vector3(0, 0, 0.02), Vector3(PI * 0.5, 0, 0))
	_mesh(wrist, _box(Vector3(0.085, 0.028, 0.095)), skin, Vector3(0, 0, -0.045), Vector3.ZERO)
	for i in 4:
		var x := -0.03 + i * 0.02
		var f := Node3D.new(); f.position = Vector3(x, 0, -0.092); wrist.add_child(f)
		var length: float = [0.045, 0.05, 0.047, 0.037][i]
		_mesh(f, _box(Vector3(0.017, 0.017, length)), skin, Vector3(0, 0, -length * 0.5), Vector3.ZERO)
		var tip := Node3D.new(); tip.position = Vector3(0, 0, -length); f.add_child(tip)
		_mesh(tip, _box(Vector3(0.016, 0.016, length * 0.8)), skin, Vector3(0, 0, -length * 0.4), Vector3.ZERO)
		_fingers.append(f)
	var thumb := Node3D.new(); thumb.position = Vector3(-0.045, -0.006, -0.03); thumb.rotation = Vector3(0, 0.7, 0)
	wrist.add_child(thumb)
	_mesh(thumb, _box(Vector3(0.02, 0.02, 0.06)), skin, Vector3(0, 0, -0.03), Vector3.ZERO)
	set_pose("down", 0.0)

func _mesh(p: Node3D, m: Mesh, mat: Material, at: Vector3, rot: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m; mi.material_override = mat; mi.position = at; mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mi)

func _box(s: Vector3) -> BoxMesh:
	var m := BoxMesh.new(); m.size = s; return m
func _cyl(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new(); m.top_radius = r; m.bottom_radius = r * 1.15; m.height = h; m.radial_segments = 8; m.rings = 1; return m

static func _basis(fingers: Vector3, palm: Vector3) -> Basis:
	var z := -fingers.normalized()
	var y := -palm.normalized()
	var x := y.cross(z).normalized()
	y = z.cross(x).normalized()
	return Basis(x, y, z)

func set_pose(name: String, seconds := 0.45) -> Tween:
	pose = name
	var p: Array = POSES[name]
	var xf := Transform3D(_basis(p[1], p[2]), p[0])
	if _tween and _tween.is_valid():
		_tween.kill()
	if seconds <= 0.0:
		wrist.transform = xf
		curl = p[3]
		return null
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(wrist, "transform", xf, seconds)
	_tween.tween_property(self, "curl", p[3], seconds)
	return _tween

func _process(delta: float) -> void:
	_t += delta
	for i in _fingers.size():
		var c := curl + sin(_t * 1.3 + i) * 0.03
		_fingers[i].rotation.x = -c * 1.3
		(_fingers[i].get_child(1) as Node3D).rotation.x = -c * 1.5
	# procedural layers on top of the pose
	position = Vector3(sin(_t * 9.0) * 0.022 * rub, cos(_t * 18.0) * 0.008 * rub, 0)
	position += Vector3(sin(_t * 24.0) * 0.012 * rattle, 0, cos(_t * 24.0) * 0.01 * rattle)
	rotation.z = sin(_t * 9.0) * 0.15 * rub
