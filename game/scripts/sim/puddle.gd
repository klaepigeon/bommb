class_name Puddle
extends RefCounted
## Spilt water: a dark round stain on the floor that splashes underfoot and conducts.

static func spill(parent: Node, at: Vector3, litres: float) -> WaterBody:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.3, 0), at + Vector3(0, -3, 0), 1)
	var hit := (parent as Node3D).get_world_3d().direct_space_state.intersect_ray(q) if parent is Node3D else {}
	var fy: float = (hit.position as Vector3).y if hit else at.y
	var r := clampf(sqrt(litres) * 0.6, 0.25, 1.4)
	var w := WaterBody.new()
	w.colour = Color(0.05, 0.05, 0.045, 0.55)
	parent.add_child(w)
	w.setup("puddle%d" % w.get_instance_id(), Rect2(at.x - r, at.z - r, r * 2.0, r * 2.0), fy + 0.004, fy + 0.012, 0.006)
	return w
