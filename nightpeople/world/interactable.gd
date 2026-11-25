class_name Interactable
extends Node3D
## Anything a player can act on. The player's focus picks the nearest one in front of them
## (group "interactable") and offers its verbs; the first verb is the primary action.
## In multiplayer the client sends (target path, verb) to the host, which calls perform().

var label := ""

func _enter_tree() -> void:
	add_to_group("interactable")

## Verbs available to `actor` right now, e.g. ["Open", "Pick lock"]. Empty = not usable.
func verbs(_actor: Node) -> Array[String]:
	return []

func perform(_actor: Node, _verb: String) -> void:
	pass

## Where the player's focus measures distance to.
func focus_point() -> Vector3:
	return global_position + Vector3.UP
