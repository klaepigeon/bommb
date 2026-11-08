extends Node3D
## A drawer that slides out along its local +Z. A moving body on its front is what you aim at.

var base_z := 0.0
var out := 0.0
var target := 0.0
var max_out := 0.3

func setup(ex: Dictionary) -> void:
	set_physics_process(true)
	max_out = ex.get("max", 0.3)
	base_z = position.z
	var aabb := AABB()
	var first := true
	for m in find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (m as MeshInstance3D).get_aabb()
		a = (global_transform.affine_inverse() * (m as Node3D).global_transform) * a
		aabb = a if first else aabb.merge(a)
		first = false
	var body := AnimatableBody3D.new(); body.sync_to_physics = false   # follows the moving parent (see door.gd)
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new()
	b.size = aabb.size.max(Vector3(0.02, 0.02, 0.02)); cs.shape = b; cs.position = aabb.get_center()
	body.add_child(cs); add_child(body)

func _physics_process(delta: float) -> void:
	if absf(target - out) > 0.0005:
		out = move_toward(out, target, delta * 1.2)
		position.z = base_z + out

func prompt() -> String:
	return "Close drawer" if target > 0.0 else "Open drawer"

func interact(_player: Node) -> void:
	target = 0.0 if target > 0.0 else max_out
