class_name Use
extends StaticBody3D
## Something you can use whose prompt depends on the world (docs/CHAPTER2.md): a fuse slot, a
## valve, a lift button, a vent. `prompt_fn` returns what the prompt says right now ("" = nothing
## to do here); `act` is called with the player when used. On the hotspot layer (4).

var prompt_fn: Callable
var act: Callable

static func make(parent: Node3D, at: Vector3, size: Vector3, prompt: Callable, action: Callable) -> Use:
	var u := Use.new(); u.prompt_fn = prompt; u.act = action
	u.collision_layer = 4; u.collision_mask = 0
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size; cs.shape = sh; u.add_child(cs)
	parent.add_child(u); u.global_position = at
	return u

func get_prompt() -> String:
	return String(prompt_fn.call()) if prompt_fn.is_valid() else ""

func interact(p = null) -> void:
	if get_prompt() == "": return
	if act.is_valid(): act.call(p)
