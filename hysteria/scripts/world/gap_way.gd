extends StaticBody3D
## The hole behind the wardrobe, from either side: squeeze through.

var gap: Node
var inward := true

func prompt() -> String:
	return "Squeeze through the gap" if inward else "Squeeze back through"

## Whatever's in the hand comes too.
func use_with_prompt(_item: Node) -> String:
	return prompt()

func use_with(p: Node, _item: Node) -> bool:
	interact(p); return true

func interact(_player: Node) -> void:
	_player.set("crouched", true)
	gap.call("go_through", inward)
