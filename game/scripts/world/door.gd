class_name Door
extends Node3D
## A hinged door leaf with collision that moves with it. The node sits at the hinge; the leaf
## runs along +X from it (rotate the node to place it). Positive angle swings toward -Z.

var leaf: AnimatableBody3D
var width := 0.9
var angle := 0.0
var _tween: Tween

func setup(w: float, h: float, mat: Material, thickness := 0.06) -> void:
	width = w
	leaf = AnimatableBody3D.new()
	leaf.sync_to_physics = false
	add_child(leaf)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w - 0.02, h - 0.02, thickness)
	mi.mesh = bm
	mi.material_override = mat
	mi.position = Vector3(w * 0.5, h * 0.5, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	leaf.add_child(mi)
	var handle := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.12, 0.03, thickness + 0.08)
	handle.mesh = hm
	handle.material_override = Look.mat(Look.get_tex("white"), Color("8c7a4a"), 0.0)
	handle.position = Vector3(w - 0.1, 1.0, 0)
	leaf.add_child(handle)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, h, thickness + 0.02)
	cs.shape = bs
	cs.position = mi.position
	leaf.add_child(cs)

## Where the handle is, in world space (hands reach for it).
func handle_position() -> Vector3:
	return leaf.global_transform * Vector3(width - 0.1, 1.0, 0)

func swing(to_degrees: float, seconds: float, trans := Tween.TRANS_SINE) -> Tween:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(leaf, "rotation:y", deg_to_rad(to_degrees), seconds).set_trans(trans).set_ease(Tween.EASE_OUT)
	angle = to_degrees
	return _tween

func set_angle(deg: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	leaf.rotation.y = deg_to_rad(deg)
	angle = deg
