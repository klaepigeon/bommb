extends Interactable
## The hatch in the Vesper's back room: bolted from below. The way down (Location B) is here.

func _ready() -> void:
	var lid := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(1.1, 0.04, 1.1)
	m.material = Assets.surface("diamond_plate", 1.0, Color(0.55, 0.5, 0.45))
	lid.mesh = m
	lid.position.y = 0.02
	add_child(lid)
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.06
	t.outer_radius = 0.09
	t.material = Assets.surface("rust", 0.5)
	ring.mesh = t
	ring.position = Vector3(0.35, 0.05, 0.0)
	add_child(ring)

func verbs(_actor: Node) -> Array[String]:
	return ["Listen at the hatch", "Try the hatch"]

func perform(_actor: Node, verb: String) -> void:
	if verb.begins_with("Listen"):
		Events.notice.emit("Cold air through the boards. Far below, something like a train that isn't a train.")
	else:
		Sfx.play_at("knock", global_position, -6.0)
		Events.notice.emit("It doesn't move. It's bolted from the other side.")

func focus_point() -> Vector3:
	return global_position + Vector3.UP * 0.2
