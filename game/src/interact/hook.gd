class_name Hook
extends Interactable
## Forwards the interaction contract to an owner object, so doors, drawers, furniture and props
## can implement iverbs(p) / iverb(id, p) / iprogress(id, k, p) without each being an Interactable.

var target: Object

static func attach(collider: CollisionObject3D, p_target: Object, p_name := "", p_persist := "") -> Hook:
	var h := Hook.new()
	h.name = "Hook"
	h.target = p_target
	h.display_name = p_name
	h.persist_id = p_persist
	collider.add_child(h)
	return h

func get_verbs(p: Node) -> Array:
	if target and is_instance_valid(target) and target.has_method("iverbs"):
		return target.iverbs(p)
	return []

func do_verb(id: String, p: Node) -> void:
	if target and is_instance_valid(target) and target.has_method("iverb"):
		target.iverb(id, p)
	used.emit(id)

func verb_progress(id: String, k: float, p: Node) -> void:
	if target and is_instance_valid(target) and target.has_method("iprogress"):
		target.iprogress(id, k, p)

func focus_point() -> Vector3:
	if target and is_instance_valid(target) and target.has_method("ifocus"):
		return target.ifocus()
	return super.focus_point()

func get_state() -> Dictionary:
	if target and is_instance_valid(target) and target.has_method("get_state"):
		return target.get_state()
	return {}

func set_state(d: Dictionary) -> void:
	if target and is_instance_valid(target) and target.has_method("set_state"):
		target.set_state(d)
