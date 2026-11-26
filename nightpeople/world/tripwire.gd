extends Interactable
## Bottles on a wire across a doorway: walk into it and they smash, loud enough to wake things.
## Seen in time, the wire can be cut.

var armed := true
var _area: Area3D

func setup(def: Dictionary) -> void:
	label = "Bottles strung on a wire"
	var w: float = def.get("width", 1.8)
	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(w, 0.6, 0.4)
	cs.shape = b
	cs.position.y = 0.3
	_area.add_child(cs)
	add_child(_area)
	_area.body_entered.connect(_tripped)
	for i in 4:
		var bottle := Assets.prop("bottle")
		bottle.position = Vector3(-w * 0.5 + 0.2 + i * (w - 0.4) / 3.0, 0.0, 0.15)
		add_child(bottle)
	var wire := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(w, 0.01, 0.01)
	m.material = Assets.surface("", 1.0, Color(0.7, 0.7, 0.6), Color(0.1, 0.1, 0.1))
	wire.mesh = m
	wire.position.y = 0.25
	add_child(wire)

func _tripped(body: Node) -> void:
	if not armed or not body.is_in_group("player"):
		return
	armed = false
	for i in 3:
		get_tree().create_timer(i * 0.12).timeout.connect(func(): Sfx.play_at("glass", global_position, 14.0, 0.2))
	Events.world_event.emit({"kind": "noise", "actor": body, "position": global_position, "place": "", "loudness": 22.0})
	Events.notice.emit("Bottles smash across the floor. That was loud.")

func verbs(_actor: Node) -> Array[String]:
	if not armed:
		return []
	return ["Cut the wire"]

func perform(_actor: Node, _verb: String) -> void:
	armed = false
	Sfx.play_at("keys", global_position, -4.0)
	Events.notice.emit("You ease the bottles down one by one and cut the wire.")

func focus_point() -> Vector3:
	return global_position + Vector3.UP * 0.3
