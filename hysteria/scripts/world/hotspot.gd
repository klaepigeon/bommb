class_name Hotspot
extends StaticBody3D
## A small thing you can use or shoot that belongs to some bigger piece of logic (the bath's
## plug, the padlock, the keys in the silt): the logic hands it callables.

var prompt_text := ""
var on_use := Callable()
var on_shot := Callable()     # (point) -> bool

static func make(parent: Node, at: Vector3, size: Vector3, text: String, use := Callable(), shot_cb := Callable()) -> Hotspot:
	var h := Hotspot.new(); h.prompt_text = text; h.on_use = use; h.on_shot = shot_cb
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = size; cs.shape = b; h.add_child(cs)
	parent.add_child(h); h.global_position = at
	return h

func prompt() -> String:
	return prompt_text if on_use.is_valid() else ""

func interact(_player: Node) -> void:
	if on_use.is_valid(): on_use.call()

func shot(point: Vector3, _normal: Vector3, _headshot_kills: bool, _shape: int) -> bool:
	return on_shot.call(point) if on_shot.is_valid() else false
