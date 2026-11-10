class_name Hotspot
extends Area3D
## Something the player can use: the crosshair finds it, the prompt names it, interact fires.

signal used

var prompt := "Use"
var enabled := true

static func make(parent: Node, at: Transform3D, size: Vector3, prompt_text: String) -> Hotspot:
	var h := Hotspot.new()
	h.prompt = prompt_text
	h.collision_layer = 2
	h.collision_mask = 0
	h.monitoring = false
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	h.add_child(cs)
	parent.add_child(h)
	h.global_transform = at
	return h
