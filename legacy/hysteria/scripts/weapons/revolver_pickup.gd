extends StaticBody3D
## The revolver where it lies, before it's his: take it.

var gun: Node3D

func prompt() -> String:
	return "Take the revolver"

func interact(player: Node) -> void:
	gun.call("equip", player)
	Game.flags["has_revolver"] = true
	queue_free()
