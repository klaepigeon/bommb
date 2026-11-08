extends StaticBody3D
## Something you can take that sits still until you do (in a drawer, on a shelf). Taking it
## turns it into a physics prop in your hand.

var target_node: Node3D
var ex := {}

static func make(n: Node3D, extras: Dictionary) -> void:
	var sb := StaticBody3D.new(); sb.set_script(load("res://scripts/world/pickable.gd"))
	sb.target_node = n; sb.ex = extras
	var aabb := AABB(); var first := true
	var meshes: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		meshes.append(n)
	for m in meshes:
		var a: AABB = (m as MeshInstance3D).get_aabb()
		a = (n.global_transform.affine_inverse() * (m as Node3D).global_transform) * a
		aabb = a if first else aabb.merge(a); first = false
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = aabb.size.max(Vector3(0.03, 0.03, 0.03)); cs.shape = b
	cs.position = aabb.get_center(); sb.add_child(cs)
	n.add_child(sb)

func prompt() -> String:
	return ("Read " if ex.get("read", false) else "Take ") + str(ex.get("name", "it")).to_lower()

func interact(player: Node) -> void:
	if ex.get("read", false):
		Game.say(str(ex.get("desc", "")) if ex.get("desc", "") != "" else str(ex.get("name", "")), 6.0)
		return
	var n := target_node
	var size := Vector3.ONE * 0.1
	var e := {"name": ex.get("name", "thing"), "desc": ex.get("desc", ""), "mass": ex.get("mass", 0.2), "size": [size.x, size.y, size.z], "centre": [0, 0, 0]}
	queue_free()
	var body: RigidBody3D = load("res://scripts/world/prop.gd").make(n, e)
	player.call("grab", body)
