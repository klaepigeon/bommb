class_name Drawer
extends Node3D
## A drawer: slides out along its local +Z.
var base := Vector3.ZERO
var max_out := 0.3
var out := false
var body: AnimatableBody3D

func setup(m: float) -> void:
	max_out = m
	base = position
	var aabb := AABB(); var first := true
	for mi in find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (global_transform.affine_inverse() * (mi as Node3D).global_transform) * (mi as MeshInstance3D).get_aabb()
		aabb = a if first else aabb.merge(a); first = false
	body = AnimatableBody3D.new(); body.sync_to_physics = false
	body.collision_layer = 8
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new()
	b.size = aabb.size.max(Vector3(0.03, 0.03, 0.03)); cs.shape = b; cs.position = aabb.get_center()
	body.add_child(cs); add_child(body)
	body.set_meta("actor", self)

func get_verbs(_k) -> Array:
	return [{"id": "drawer", "label": "Close" if out else "Open"}]

func act(_v: String, k) -> void:
	out = not out
	create_tween().tween_property(self, "position", base + transform.basis.z.normalized() * (max_out if out else 0.0), 0.35).set_trans(Tween.TRANS_SINE)
	Audio.play("scrape", global_position, -12.0, 1.8)
	Noises.make(global_position, 3.0, "drawer", k)
