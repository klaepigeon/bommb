extends AnimatableBody3D
## The wardrobe as something you use: "Push the wardrobe" wherever you can see it from. It only
## moves from its side (its back is flat to the wall), so from anywhere else Kurt steps round to
## the side himself and puts his shoulder to it (WardrobeGap.approach_and_push). With something
## in hand, he puts it down first.

var gap: Node

func prompt() -> String:
	if not gap or gap.get("pushed") or float(gap.get("_t")) >= 0.0 or gap.get("_approaching"): return ""
	return "Push the wardrobe"

func interact(_player: Node) -> void:
	if prompt() == "": return
	if gap.call("can_push"): gap.call("push")
	else: gap.call("approach_and_push")

func use_with_prompt(_item: Node) -> String:
	return prompt()

func use_with(p: Node, _item: Node) -> bool:
	if prompt() == "": return false
	p.call("drop")
	interact(p)
	return true
