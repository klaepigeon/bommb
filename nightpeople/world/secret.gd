extends Interactable
## Something hidden in plain sight: loose tiles, a false panel. Prying it reveals what's behind
## (a readable), once.

var reveal: Dictionary = {}

func verbs(_actor: Node) -> Array[String]:
	return ["Pry at it"]

func perform(actor: Node, _verb: String) -> void:
	Sfx.play_at("knock", global_position, -4.0)
	var r := Readable.new()
	r.title = reveal.title
	r.text = reveal.text
	r.clue = reveal.get("clue", "")
	r.label = reveal.title
	get_parent().add_child(r)
	r.global_position = global_position + Vector3(0.3, -0.4, 0)
	Events.notice.emit("Behind the tiles, a hollow. Something wrapped in oilcloth.")
	r.perform(actor, "Read")
	queue_free()
