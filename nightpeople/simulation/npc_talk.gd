extends Interactable
## Makes an NPC something the player can focus on and talk to.

var npc: NPC

func verbs(actor: Node) -> Array[String]:
	if npc.hidden_away:
		return []
	var out: Array[String] = ["Talk"]
	for key in Journal.story.topics:
		var tp: Dictionary = Journal.story.topics[key]
		if tp.has("only") and not npc.id in tp.only:
			continue
		if tp.has("requires_any") and not Journal.knows_any(tp.requires_any):
			continue
		if tp.has("requires_item") and not (actor and actor.has_method("has_item") and actor.has_item(tp.requires_item)):
			continue
		if key == "warn" and (World.gone.has("abe") or Journal.knows("abe_warned")):
			continue
		out.append(tp.label)
	return out

func perform(actor: Node, verb: String) -> void:
	for key in Journal.story.topics:
		if Journal.story.topics[key].label == verb:
			npc.ask(key, actor)
			return
	npc.talk_to(actor)

func activity_text() -> String:
	return npc.activity_text()

func focus_point() -> Vector3:
	return npc.global_position + Vector3.UP * 1.2
