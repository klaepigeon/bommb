class_name ExportDrawer
extends Node3D
## A drawer from the exported flat: slides out along its local +Z; what's in it rides along.

signal opened(d)
var base_z := 0.0
var out := 0.0
var target := 0.0
var max_out := 0.3
var is_open := false

func setup(ex: Dictionary) -> void:
	max_out = ex.get("max", 0.3)
	base_z = position.z
	var aabb := AABB(); var first := true
	for m in find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (global_transform.affine_inverse() * (m as Node3D).global_transform) * (m as MeshInstance3D).get_aabb()
		aabb = a if first else aabb.merge(a); first = false
	var body := AnimatableBody3D.new(); body.sync_to_physics = false
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new()
	b.size = aabb.size.max(Vector3(0.02, 0.02, 0.02)); cs.shape = b; cs.position = aabb.get_center()
	body.add_child(cs); add_child(body)

func _physics_process(delta: float) -> void:
	if absf(target - out) > 0.0005:
		out = move_toward(out, target, delta * 1.2)
		position.z = base_z + out

func get_prompt() -> String:
	return "Close drawer" if is_open else "Open drawer"

func interact(_p = null) -> void:
	is_open = not is_open
	target = max_out if is_open else 0.0
	Sfx.play_at("drawer", global_position, -6.0)
	if is_open: opened.emit(self)
