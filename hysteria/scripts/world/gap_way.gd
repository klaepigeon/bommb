extends StaticBody3D
## The hole behind the wardrobe, from either side: squeeze through.

var gap: Node
var inward := true

func prompt() -> String:
	return "Squeeze through the gap" if inward else "Squeeze back through"

func interact(_player: Node) -> void:
	_player.set("crouched", true)
	gap.call("go_through", inward)
