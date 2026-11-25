extends Interactable
## Makes an NPC something the player can focus on and talk to.

var npc: NPC

func verbs(_actor: Node) -> Array[String]:
	if npc.hidden_away:
		return []
	return ["Talk"]

func perform(actor: Node, _verb: String) -> void:
	npc.talk_to(actor)

func activity_text() -> String:
	return npc.activity_text()

func focus_point() -> Vector3:
	return npc.global_position + Vector3.UP * 1.2
