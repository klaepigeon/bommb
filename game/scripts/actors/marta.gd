class_name Marta
extends Node3D
## Marta Sokolova at her dinner table: mould, coral grown out of her and into the chair, the
## floor, the wall. Alive: she breathes. Faces +Z in her own space (the node is turned to face
## the doorway). Built from primitives, PS1-snapped.

var chest: Node3D
var head: Node3D
var mouth: MeshInstance3D
var arm: Node3D           ## her right arm, from the shoulder (the one that takes hold of him)
var forearm: Node3D
var body_parts: Array[Node3D] = []
var spot: Hotspot
var breathing := true
var head_lift := 0.0      ## 0 = chin on her chest, 1 = looking at him
var look_target := Vector3.ZERO

var _t := 0.0
var _breath: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()
var _skin: Material
var _dress: Material
var _hair: Material
var _black: Material
var _coral: Material
var _mould: Material
var _wood: Material
var _teeth: Material

func build() -> void:
	_rng.seed = 14
	_skin = Look.mat(Look.get_tex("skin"))
	_dress = Look.mat(Look.get_tex("cloth"), Color("3a4c48"))
	_hair = Look.mat(Look.get_tex("cloth"), Color("2a241f"))
	_black = Look.mat(Look.get_tex("white"), Color("050404"))
	_coral = Look.mat(Look.get_tex("coral"))
	_mould = Look.mat(Look.get_tex("mould"))
	_wood = Look.mat(Look.get_tex("wood"))
	_teeth = Look.mat(Look.get_tex("paper"), Color("e8dcc0"))
	# her chair, fused to her and to the floor
	_part(self, _box(Vector3(0.46, 0.05, 0.46)), _wood, Vector3(0, 0.44, 0))
	_part(self, _box(Vector3(0.46, 0.55, 0.05)), _wood, Vector3(0, 0.73, -0.22))
	for c in [Vector3(-0.2, 0.21, -0.2), Vector3(0.2, 0.21, -0.2), Vector3(-0.2, 0.21, 0.2), Vector3(0.2, 0.21, 0.2)]:
		_part(self, _box(Vector3(0.04, 0.42, 0.04)), _wood, c)
	# hips and legs
	var legs := Node3D.new(); add_child(legs); body_parts.append(legs)
	_part(legs, _box(Vector3(0.36, 0.14, 0.34)), _dress, Vector3(0, 0.53, 0))
	for s in [-1.0, 1.0]:
		_part(legs, _box(Vector3(0.14, 0.13, 0.42)), _dress, Vector3(0.1 * s, 0.53, 0.2))
		_part(legs, _box(Vector3(0.1, 0.46, 0.11)), _skin, Vector3(0.1 * s, 0.26, 0.42))
		_part(legs, _box(Vector3(0.1, 0.07, 0.22)), _black, Vector3(0.1 * s, 0.035, 0.48))
	# the torso, slumped forward
	chest = Node3D.new(); chest.position = Vector3(0, 0.58, -0.02); add_child(chest); body_parts.append(chest)
	var torso := _part(chest, _capsule(0.17, 0.62), _dress, Vector3(0, 0.27, 0))
	torso.scale = Vector3(1.0, 1.0, 0.72)
	# head on the neck
	var neck := _part(chest, _cyl(0.05, 0.12), _skin, Vector3(0, 0.56, 0.0))
	neck.name = "Neck"
	head = Node3D.new(); head.position = Vector3(0, 0.6, 0.0); chest.add_child(head)
	var skull := _part(head, _sphere(0.11), _skin, Vector3(0, 0.11, 0.01))
	skull.scale = Vector3(0.92, 1.1, 1.0)
	for s in [-1.0, 1.0]:
		_part(head, _sphere(0.026), _black, Vector3(0.042 * s, 0.135, 0.092))      # eyes gone dark
	mouth = _part(head, _box(Vector3(0.15, 0.03, 0.02)), _black, Vector3(0, 0.055, 0.1))   # the grin, ear to ear
	for i in 7:
		_part(head, _box(Vector3(0.012, 0.016, 0.01)), _teeth, Vector3(-0.054 + i * 0.018, 0.07, 0.108))
	var hair := _part(head, _sphere(0.118), _hair, Vector3(0, 0.14, -0.025))
	hair.scale = Vector3(1.0, 1.0, 0.95)
	for i in 6:
		_part(head, _box(Vector3(0.02, 0.22, 0.02)), _hair, Vector3(_rng.randf_range(-0.1, 0.1), 0.02, -0.07 + _rng.randf_range(-0.02, 0.03)))
	# left arm, forearm laid along the table
	_part(chest, _capsule(0.045, 0.3), _dress, Vector3(0.21, 0.36, 0.04)).rotation = Vector3(0.5, 0, 0.12)
	_part(chest, _capsule(0.04, 0.3), _skin, Vector3(0.24, 0.17, 0.27)).rotation = Vector3(1.45, 0, 0.0)
	# right arm, hanging; it's the one that moves
	arm = Node3D.new(); arm.position = Vector3(-0.21, 0.48, 0.0); chest.add_child(arm)
	_part(arm, _capsule(0.045, 0.3), _dress, Vector3(0, -0.14, 0))
	forearm = Node3D.new(); forearm.position = Vector3(0, -0.29, 0); arm.add_child(forearm)
	_part(forearm, _capsule(0.04, 0.28), _skin, Vector3(0, -0.13, 0))
	var hand := _part(forearm, _box(Vector3(0.07, 0.12, 0.03)), _skin, Vector3(0, -0.31, 0))
	hand.name = "Hand"
	for i in 4:
		_part(forearm, _box(Vector3(0.012, 0.07, 0.012)), _skin, Vector3(-0.026 + i * 0.017, -0.4, 0.0))
	arm.rotation = Vector3(0.35, 0, 0.12)
	forearm.rotation = Vector3(-0.7, 0, 0)
	# mould on her and the chair; coral out of her shoulders, her back, her legs, into the chair
	var b := Build.new(chest, "Growth")
	b.material("coral", _coral); b.material("mould", _mould)
	for i in 8:
		var p := Vector3(_rng.randf_range(-0.16, 0.16), _rng.randf_range(0.15, 0.6), _rng.randf_range(-0.12, -0.05))
		_grow(b, p, Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(0.2, 0.9), -1), 0.18, 0.025, 2)
	for s in [-1.0, 1.0]:
		_grow(b, Vector3(0.17 * s, 0.52, 0), Vector3(s, 1.0, -0.2), 0.16, 0.025, 2)
	for i in 10:
		var p := Vector3(_rng.randf_range(-0.15, 0.15), _rng.randf_range(0.05, 0.55), _rng.randf_range(-0.12, 0.12))
		var n := Vector3(p.x, 0, p.z).normalized()
		b.box("mould", Vector3(-0.05, -0.04, 0), Vector3(0.05, 0.04, 0.01), Transform3D(Basis(Quaternion(Vector3.BACK, n if n.length() > 0.1 else Vector3.BACK)), p + n * 0.15), false)
	b.finish()
	var g := Build.new(self, "Fused")
	g.material("coral", _coral)
	for i in 7:
		var p := Vector3(_rng.randf_range(-0.2, 0.2), 0.45, _rng.randf_range(-0.2, 0.2))
		_grow(g, p, Vector3(_rng.randf_range(-1, 1), -1.2, _rng.randf_range(-1, 1)), 0.25, 0.03, 2)
	for i in 4:
		_grow(g, Vector3(_rng.randf_range(-0.2, 0.2), 0.75, -0.24), Vector3(_rng.randf_range(-0.5, 0.5), 0.3, -1), 0.25, 0.03, 2)
	for s in [-1.0, 1.0]:
		_grow(g, Vector3(0.1 * s, 0.1, 0.42), Vector3(s * 0.5, -0.3, 0.6), 0.2, 0.025, 2)
	g.finish()
	g.body.queue_free()
	# what you use
	spot = Hotspot.make(self, global_transform * Transform3D(Basis(), Vector3(0, 0.9, 0.05)), Vector3(0.6, 1.0, 0.6), "Examine")
	spot.enabled = false
	_breath = Sfx.loop_at("breath", global_transform * Vector3(0, 1.1, 0.1), -10.0, 0.95)

func _grow(b: Build, p: Vector3, dir: Vector3, length: float, r: float, depth: int) -> void:
	var d := dir.normalized()
	b.mesh("coral", Flat47._cyl(), Transform3D(Build.along(d, r, length), p + d * length * 0.5))
	b.mesh("coral", Flat47._ball(), Transform3D(Basis().scaled(Vector3.ONE * r * 1.3), p + d * length))
	if depth > 0:
		for k in _rng.randi_range(1, 2):
			var nd := (d + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.5, 1), _rng.randf_range(-1, 1)) * 0.8).normalized()
			_grow(b, p + d * length * 0.8, nd, length * 0.7, r * 0.7, depth - 1)

func _part(parent: Node3D, m: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _box(s: Vector3) -> BoxMesh:
	var m := BoxMesh.new(); m.size = s; return m
func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new(); m.radius = r; m.height = r * 2.0; m.radial_segments = 8; m.rings = 6; return m
func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new(); m.radius = r; m.height = h; m.radial_segments = 8; m.rings = 2; return m
func _cyl(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new(); m.top_radius = r; m.bottom_radius = r; m.height = h; m.radial_segments = 8; m.rings = 1; return m

func _process(delta: float) -> void:
	_t += delta
	if breathing:
		var b := sin(_t * TAU / 4.2) * 0.5 + 0.5
		chest.scale = Vector3(1.0 + b * 0.025, 1.0 + b * 0.015, 1.0 + b * 0.04)
	# chin on her chest → lifted toward him (look_target), with a tremor
	var slump := Vector3(0.75, 0.0, 0.08)
	var lifted := slump
	if look_target != Vector3.ZERO:
		var local := (chest.global_transform.affine_inverse() * look_target) - head.position
		lifted = Vector3(-atan2(local.y - 0.1, Vector2(local.x, local.z).length()) * 0.8, atan2(local.x, local.z) * 0.8, -0.18)
	var tremor := Vector3(sin(_t * 13.0), sin(_t * 9.0), 0) * 0.01 * head_lift
	head.rotation = slump.lerp(lifted, head_lift) + tremor
	var m := Speech.mouth("marta")
	mouth.scale.y = 1.0 + m * 2.5
	chest.rotation.x = lerpf(0.28, 0.05, head_lift)

## She takes hold of him: the arm comes up and out at the camera, fast.
func grab(target: Vector3, seconds := 0.22) -> void:
	var d: Vector3 = (arm.get_parent().to_local(target) - arm.position).normalized()
	var q := Quaternion(Vector3.DOWN, d)       # the arm hangs along -Y; point that at him
	var tw := create_tween().set_parallel(true)
	tw.tween_property(arm, "quaternion", q, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(forearm, "rotation", Vector3(0.05, 0, 0), seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "head_lift", 1.0, seconds * 0.5)

## Gone: the coral she sat in stays, in the shape of her.
func vanish() -> void:
	breathing = false
	for p in body_parts:
		p.visible = false
	spot.enabled = false
	if is_instance_valid(_breath):
		_breath.queue_free()
