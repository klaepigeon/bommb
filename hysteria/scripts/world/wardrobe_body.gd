extends AnimatableBody3D
## The wardrobe as something you use: from its side, you push it (WardrobeGap does the rest).

var gap: Node

func prompt() -> String:
	return "Push the wardrobe" if gap and gap.call("can_push") else ""

func interact(_player: Node) -> void:
	gap.call("push")
