class_name Hotspot
extends StaticBody3D
## Something you can use that isn't a door or a drawer: Marta, the hole, a note. The level gives
## it a prompt and a callable. An empty prompt (or enabled = false) hides it.

signal used(h: Hotspot)
var prompt := ""
var action: Callable
## Disabled, it stops catching the crosshair too (it would hide whatever is behind it).
var enabled := true:
	set(v):
		enabled = v
		collision_layer = 4 if v else 0

static func make(parent: Node, pos: Vector3, size: Vector3, prompt_text: String, act: Callable) -> Hotspot:
	var h := Hotspot.new()
	h.prompt = prompt_text; h.action = act
	h.collision_layer = 4; h.collision_mask = 0
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size; cs.shape = sh
	h.add_child(cs)
	parent.add_child(h); h.global_position = pos
	return h

func get_prompt() -> String:
	return prompt if enabled else ""

func interact(p = null) -> void:
	if not enabled: return
	used.emit(self)
	if action.is_valid(): action.call()
