extends AnimatableBody3D
## The wardrobe as something you use: from its side, you push it (WardrobeGap does the rest).
## From anywhere else near it, it says why it won't move, so it never just does nothing; with
## something in your hand, you put it down and push.

var gap: Node

func prompt() -> String:
	if not gap or gap.get("pushed") or float(gap.get("_t")) >= 0.0: return ""
	return "Push the wardrobe" if gap.call("can_push") else "Try to move the wardrobe"

func interact(_player: Node) -> void:
	if gap.call("can_push"):
		gap.call("push")
	elif not gap.get("pushed"):
		Game.say("It won't budge from here: its back is flat to the wall. From the side, where the bed ends, it might.", 4.5)

func use_with_prompt(_item: Node) -> String:
	return prompt()

func use_with(p: Node, _item: Node) -> bool:
	if prompt() == "": return false
	if gap.call("can_push"): p.call("drop")
	interact(p)
	return true
