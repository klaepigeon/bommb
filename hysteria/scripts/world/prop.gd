extends RigidBody3D
## A physics prop: knocked over, kicked, carried, thrown, turned over in the hand.

var title := "thing"
var desc := ""
var liftable := true

static func make(n: Node3D, ex: Dictionary) -> RigidBody3D:
	var parent := n.get_parent()
	var body := RigidBody3D.new()
	body.set_script(load("res://scripts/world/prop.gd"))
	body.name = n.name + "_body"
	parent.add_child(body)
	body.global_transform = n.global_transform
	n.reparent(body, true)
	var size: Array = ex.get("size", [0.2, 0.2, 0.2])
	var centre: Array = ex.get("centre", [0, 0, 0])
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new()
	b.size = Vector3(maxf(size[0], 0.02), maxf(size[1], 0.02), maxf(size[2], 0.02)); cs.shape = b
	cs.position = Vector3(centre[0], centre[1], centre[2])
	body.add_child(cs)
	body.mass = maxf(0.05, float(ex.get("mass", 1.0)))
	body.title = ex.get("name", "thing"); body.desc = ex.get("desc", "")
	body.liftable = body.mass <= 12.0
	body.can_sleep = true; body.sleeping = true
	body.continuous_cd = body.mass < 1.0
	return body

func prompt() -> String:
	return ("Pick up " + title.to_lower()) if liftable else ""

func interact(player: Node) -> void:
	if liftable:
		player.call("grab", self)
	else:
		Game.say("Too heavy to lift. You could push it.")
