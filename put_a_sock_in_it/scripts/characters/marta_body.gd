class_name MartaBody
extends Node3D
## Marta Sokolov's body, built in code on a joint hierarchy the way PS1 characters were: rigid
## low-poly parts on joints, posed by rotating the joints. Two forms:
##   seated  fused into her armchair: coral has grown out of her back and shoulders, through the
##           chair and into the floor; mould blooms through her skin and her housecoat. Head hung.
##   hunter  standing, and wrong: the neck too long, the forearms too long, one shoulder higher,
##           the coral on her back grown up past her head. She moves in jerks.
## She is still a person: the housecoat, the slippers, the hair in a clip. That's what's awful.
## Local frame: she faces -Z; the origin is the floor between her feet.

var form := "seated"
var joints := {}          # name -> Node3D
var pose := {}            # name -> Vector3 euler (radians), applied with smoothing
var snap := 12.0          # how fast joints reach their pose (high = jerky)
var _rng := RandomNumberGenerator.new()
var _skin: Material
var _coat: Material
var _coral: Material
var _mould: Material
var _dark: Material

const REST := {
	# joint: [parent, offset from parent]
	"hips": ["", Vector3(0, 0.92, 0)],
	"spine": ["hips", Vector3(0, 0.12, 0)],
	"chest": ["spine", Vector3(0, 0.26, 0)],
	"neck": ["chest", Vector3(0, 0.2, 0.0)],
	"head": ["neck", Vector3(0, 0.16, 0)],
	"jaw": ["head", Vector3(0, 0.0, -0.06)],
	"sh_l": ["chest", Vector3(-0.18, 0.16, 0)], "el_l": ["sh_l", Vector3(0, -0.28, 0)], "wr_l": ["el_l", Vector3(0, -0.34, 0)],
	"sh_r": ["chest", Vector3(0.18, 0.13, 0)], "el_r": ["sh_r", Vector3(0, -0.28, 0)], "wr_r": ["el_r", Vector3(0, -0.34, 0)],
	"hip_l": ["hips", Vector3(-0.1, -0.02, 0)], "kn_l": ["hip_l", Vector3(0, -0.44, 0)],
	"hip_r": ["hips", Vector3(0.1, -0.02, 0)], "kn_r": ["hip_r", Vector3(0, -0.44, 0)],
}

func _init(f := "seated") -> void:
	form = f

func _ready() -> void:
	_rng.seed = 47
	_skin = Tex.mat("skin", 3.0)
	_coat = Tex.mat("fabric_green", 3.0)
	_coral = Tex.mat("coral", 4.0, {"pulse": 0.004})
	_mould = Tex.mat("mould", 5.0)
	_dark = Tex.mat("black")
	_skeleton()
	_body()
	if form == "seated":
		_seated_pose(); _chair_growth()
	else:
		_hunter_growth()
	for k in pose: (joints[k] as Node3D).rotation = pose[k]

func _skeleton() -> void:
	for name in REST:
		var j := Node3D.new(); j.name = name
		var parent: String = REST[name][0]
		(joints[parent] if parent != "" else self).add_child(j)
		j.position = REST[name][1]
		joints[name] = j
		pose[name] = Vector3.ZERO

func _part(joint: String, draw: Callable, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	draw.call(st)
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = mat
	(joints[joint] as Node3D).add_child(mi)
	return mi

func _body() -> void:
	var neck_len := 0.16 if form == "seated" else 0.26
	var fore := 0.34 if form == "seated" else 0.46
	joints.head.position.y = neck_len
	joints.wr_l.position.y = -fore; joints.wr_r.position.y = -fore
	# torso: a housecoat over a sagging body
	_part("hips", func(st): MeshKit.blob(st, Vector3(0, 0.08, 0), Vector3(0.2, 0.2, 0.15), {"bumps": 0.05, "sag": 0.3}), _coat)
	_part("spine", func(st): MeshKit.blob(st, Vector3(0, 0.13, 0), Vector3(0.18, 0.24, 0.13), {"bumps": 0.06, "seed": 2.0}), _coat)
	_part("chest", func(st): MeshKit.blob(st, Vector3(0, 0.05, 0.0), Vector3(0.21, 0.2, 0.14), {"bumps": 0.08, "sag": 0.4, "seed": 3.0}), _coat)
	_part("neck", func(st): MeshKit.tube(st, [Vector3.ZERO, Vector3(0, neck_len * 0.5, -0.01), Vector3(0, neck_len, 0)], [0.05, 0.045, 0.05], {"sides": 7, "bumps": 0.15}), _skin)
	# head: long in the face, cheek slid down, hair pulled back into a clip
	_part("head", func(st): MeshKit.blob(st, Vector3(0, 0.1, -0.01), Vector3(0.085, 0.12, 0.1), {"bumps": 0.1, "slide": 0.35, "seed": 7.0}), _skin)
	_part("head", func(st): MeshKit.blob(st, Vector3(0, 0.15, 0.04), Vector3(0.09, 0.08, 0.09), {"bumps": 0.25, "seed": 9.0}), Tex.mat("wood", 6.0, {"tint": Color(0.6, 0.55, 0.5)}))
	# the eyes: sunk, dark; one has coral in it
	_part("head", func(st): MeshKit.blob(st, Vector3(-0.032, 0.12, -0.085), Vector3(0.018, 0.014, 0.01), {"rings": 4, "segs": 6}), _dark)
	_part("head", func(st): MeshKit.coral(st, Vector3(0.032, 0.12, -0.08), Vector3(0.3, 0.2, -1.0), 0.07, 0.012, _rng, 1), _coral)
	_part("jaw", func(st): MeshKit.blob(st, Vector3(0, 0.035, -0.03), Vector3(0.05, 0.025, 0.035), {"rings": 5, "segs": 8, "bumps": 0.1}), _skin)
	_part("jaw", func(st): MeshKit.blob(st, Vector3(0, 0.055, -0.045), Vector3(0.03, 0.01, 0.01), {"rings": 3, "segs": 6}), _dark)
	for s in ["l", "r"]:
		var sx := -1.0 if s == "l" else 1.0
		_part("sh_" + s, func(st): MeshKit.tube(st, [Vector3.ZERO, Vector3(0, -0.14, 0), Vector3(0, -0.28, 0)], [0.06, 0.055, 0.045], {"sides": 7, "bumps": 0.12}), _coat)
		_part("el_" + s, func(st): MeshKit.tube(st, [Vector3.ZERO, Vector3(0, -fore * 0.5, 0), Vector3(0, -fore, 0)], [0.042, 0.034, 0.03], {"sides": 6, "bumps": 0.2}), _skin)
		# hands: long fingers, too many knuckles
		_part("wr_" + s, func(st):
			MeshKit.blob(st, Vector3(0, -0.04, 0), Vector3(0.035, 0.05, 0.02), {"rings": 5, "segs": 7})
			for f in 4:
				var x := (f - 1.5) * 0.016
				MeshKit.tube(st, [Vector3(x, -0.08, 0), Vector3(x * 1.2, -0.14, -0.01), Vector3(x * 1.3, -0.2, -0.03)], [0.009, 0.007, 0.004], {"sides": 4}), _skin)
		_part("hip_" + s, func(st): MeshKit.tube(st, [Vector3.ZERO, Vector3(0, -0.22, 0), Vector3(0, -0.44, 0)], [0.08, 0.065, 0.05], {"sides": 7, "bumps": 0.08}), _coat)
		_part("kn_" + s, func(st):
			MeshKit.tube(st, [Vector3.ZERO, Vector3(0, -0.22, 0), Vector3(0, -0.42, 0)], [0.045, 0.04, 0.035], {"sides": 6, "bumps": 0.1})
			MeshKit.blob(st, Vector3(0, -0.45, -0.05), Vector3(0.05, 0.035, 0.1), {"rings": 4, "segs": 6}), _skin if form == "hunter" else Tex.mat("cloth_red", 4.0))
	# mould through the skin and the coat
	for j in ["chest", "neck", "head", "sh_l", "el_r"]:
		_part(j, func(st):
			for i in 3:
				MeshKit.lump(st, Vector3(_rng.randf_range(-0.06, 0.06), _rng.randf_range(0.0, 0.12), _rng.randf_range(-0.08, 0.08)), _rng.randf_range(0.02, 0.04), _rng), _mould)

func _seated_pose() -> void:
	joints.hips.position.y = 0.48
	pose.hip_l = Vector3(PI * 0.5, 0, 0.05); pose.hip_r = Vector3(PI * 0.5, 0, -0.05)
	pose.kn_l = Vector3(-PI * 0.5, 0, 0); pose.kn_r = Vector3(-PI * 0.5, 0, 0)
	pose.spine = Vector3(-0.15, 0, 0); pose.chest = Vector3(-0.2, 0, 0.05)
	pose.neck = Vector3(-0.7, 0, -0.15); pose.head = Vector3(-0.5, 0.2, -0.35)
	pose.sh_l = Vector3(0.6, 0, 0.12); pose.el_l = Vector3(0.9, 0, 0)
	pose.sh_r = Vector3(0.5, 0, -0.1); pose.el_r = Vector3(1.0, 0, 0)
	pose.jaw = Vector3(0.15, 0, 0)

## The chair is hers now: coral has come out of her back and down through it into the floor.
func _chair_growth() -> void:
	var g := Node3D.new(); g.name = "Growth"; add_child(g)
	Build.organic(g, func(st):
		for i in 9:
			var a := _rng.randf_range(-1.2, 1.2)
			MeshKit.coral(st, Vector3(sin(a) * 0.15, 0.85 + _rng.randf() * 0.25, 0.12), Vector3(sin(a) * 0.7, _rng.randf_range(0.2, 1.0), 0.7), _rng.randf_range(0.18, 0.32), _rng.randf_range(0.02, 0.035), _rng, 2)
		for i in 7:
			var x := _rng.randf_range(-0.45, 0.45)
			MeshKit.coral(st, Vector3(x, 0.3, _rng.randf_range(-0.1, 0.35)), Vector3(x * 1.5, -1.0, _rng.randf_range(-0.2, 0.6)), 0.35, 0.028, _rng, 1)
		for i in 10:
			MeshKit.lump(st, Vector3(_rng.randf_range(-0.7, 0.7), 0.0, _rng.randf_range(-0.3, 0.8)), _rng.randf_range(0.05, 0.13), _rng), _coral)
	Build.organic(g, func(st):
		for i in 14:
			MeshKit.lump(st, Vector3(_rng.randf_range(-0.8, 0.8), 0.0, _rng.randf_range(-0.6, 0.9)), _rng.randf_range(0.04, 0.1), _rng), _mould)
	# coral grown through her shoulders and up her neck, fusing her to the chair back
	_part("chest", func(st):
		for i in 5:
			MeshKit.coral(st, Vector3(_rng.randf_range(-0.15, 0.15), 0.12, 0.1), Vector3(_rng.randf_range(-0.6, 0.6), 0.8, 0.5), 0.2, 0.025, _rng, 1), _coral)
	_part("neck", func(st): MeshKit.coral(st, Vector3(0.03, 0.05, 0.03), Vector3(0.5, 0.6, 0.5), 0.15, 0.018, _rng, 1), _coral)

func _hunter_growth() -> void:
	_part("chest", func(st):
		for i in 6:
			MeshKit.coral(st, Vector3(_rng.randf_range(-0.14, 0.14), 0.1, 0.11), Vector3(_rng.randf_range(-0.5, 0.5), 1.0, 0.4), _rng.randf_range(0.25, 0.45), 0.03, _rng, 2), _coral)
	_part("el_l", func(st): MeshKit.coral(st, Vector3(0, -0.15, 0.03), Vector3(-0.4, -0.2, 0.6), 0.16, 0.018, _rng, 1), _coral)
	joints.sh_l.position.y += 0.05   # one shoulder hiked up

## Hit points for hits and line of sight: where her head is.
func head_pos() -> Vector3:
	return (joints.head as Node3D).global_position + Vector3(0, 0.1, 0)

## Turn her face toward a point (seated form: as much as a fused neck allows).
func face_toward(p: Vector3, k := 1.0) -> void:
	var local := to_local(p) - (joints.neck as Node3D).position - (joints.chest as Node3D).position
	var yaw := atan2(-local.x, -local.z)
	pose.neck = Vector3(lerpf(pose.neck.x, -0.1, k), clampf(yaw * 0.5, -0.8, 0.8), 0.0)
	pose.head = Vector3(lerpf(pose.head.x, 0.15, k), clampf(yaw * 0.5, -0.8, 0.8), lerpf(pose.head.z, -0.25, k))

func _process(delta: float) -> void:
	var k := 1.0 - exp(-snap * delta)
	for name in pose:
		var j: Node3D = joints[name]
		j.rotation = j.rotation.lerp(pose[name], k)
