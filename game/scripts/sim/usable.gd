class_name Usable
extends StaticBody3D
## Something Kurt can do something to. It offers verbs (the first is what USE does, the second is
## ALT); whoever made it decides what they do. Verbs can depend on Kurt (what he holds, what he
## knows): `offer` is asked every time he looks at it.

signal acted(verb: String, kurt: Node)

var verbs: Array = []            ## [{id, label}] (static list) ...
var offer: Callable              ## ... or func(kurt) -> Array of {id, label}
var title := ""                  ## what it is (the look line)
var desc := ""
var enabled := true
var owner_node: Node             ## the thing this is the handle of (a door, a prop)
var socko_offer: Callable        ## func(kurt) -> [{id, label}]: what Socko can be asked to do to it
var socko_do: Callable           ## func(id, kurt, mind)

static func make(parent: Node, xf: Transform3D, size: Vector3, p_verbs: Array, solid := false) -> Usable:
	var u := Usable.new()
	u.verbs = p_verbs
	u.collision_layer = 1 if solid else 8
	u.collision_mask = 0
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = size; cs.shape = b
	u.add_child(cs)
	parent.add_child(u)
	u.global_transform = xf
	return u

func get_verbs(kurt: Node) -> Array:
	if not enabled: return []
	if offer.is_valid(): return offer.call(kurt)
	return verbs

func act(verb: String, kurt: Node) -> void:
	acted.emit(verb, kurt)

func socko_verbs(kurt: Node) -> Array:
	return socko_offer.call(kurt) if socko_offer.is_valid() and enabled else []

func socko_act(id: String, kurt: Node, mind) -> void:
	if socko_do.is_valid(): socko_do.call(id, kurt, mind)
