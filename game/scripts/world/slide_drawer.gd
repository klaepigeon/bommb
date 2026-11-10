extends Node3D
## A drawer from the exported flat: slides out along its local +Z when used.

var base_z := 0.0
var max_out := 0.3
var body: StaticBody3D
var out := false

func setup(ex: Dictionary) -> void:
	max_out = float(ex.get("max", 0.3))
	base_z = position.z
	var aabb := AABB()
	var first := true
	for m in find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (m as MeshInstance3D).get_aabb()
		a = (transform.affine_inverse() * _rel(m)) * a
		aabb = a if first else aabb.merge(a)
		first = false
	body = AnimatableBody3D.new()
	(body as AnimatableBody3D).sync_to_physics = false
	body.set_script(load("res://scripts/world/usable.gd"))
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new()
	b.size = aabb.size.max(Vector3(0.02, 0.02, 0.02)); cs.shape = b; cs.position = aabb.get_center()
	body.add_child(cs)
	add_child(body)
	body.set("prompt", "Open drawer")
	body.connect("used", _use)

## A mesh's transform relative to this node's parent (works before we're in the tree).
func _rel(n: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c := n
	while c != null and c != get_parent():
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t

func _use() -> void:
	out = not out
	create_tween().tween_property(self, "position:z", base_z + (max_out if out else 0.0), 0.35).set_trans(Tween.TRANS_SINE)
	body.set("prompt", "Close drawer" if out else "Open drawer")
	Sfx.play_at("scrape", global_position, -12.0, 1.8)
