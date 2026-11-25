class_name Item
extends Interactable
## A thing that can be picked up and carried, owned by someone. Taking it is announced as a
## world event; whether anyone notices is decided by who could see it (simulation/perception),
## and later by the owner finding it gone (World.missing).

var data: Dictionary = {}      ## {id, name, value, owner, quest?}

func setup(def: Dictionary) -> void:
	data = def.duplicate()
	label = def.name

func verbs(_actor: Node) -> Array[String]:
	return ["Take"]

func perform(actor: Node, verb: String) -> void:
	if verb != "Take" or not actor.has_method("give_item"):
		return
	actor.give_item(data)
	Sfx.play_at("coin" if data.get("cash", false) else "take", global_position)
	var place := World.room_at(global_position)
	if data.get("owner", "") != "" and data.owner != "player":
		World.missing.append({"item": data, "owner": data.owner, "room": place, "time": Clock.total_minutes})
	Events.world_event.emit({"kind": "take", "actor": actor, "item": data, "owner": data.get("owner", ""),
		"position": global_position, "place": place, "loudness": 0.0})
	queue_free()

func focus_point() -> Vector3:
	return global_position + Vector3.UP * 0.1
