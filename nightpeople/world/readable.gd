class_name Readable
extends Interactable
## Writing that can be read where it lies (notes, books, letters).

var title := ""
var text := ""

func verbs(_actor: Node) -> Array[String]:
	return ["Read"]

func perform(_actor: Node, _verb: String) -> void:
	Sfx.play_at("paper", global_position)
	Events.read.emit(title, text)

func focus_point() -> Vector3:
	return global_position + Vector3.UP * 0.1
