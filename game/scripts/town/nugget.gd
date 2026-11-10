class_name Nugget
extends Node3D
## A gutterspace nugget: a floating shard that looks like a missing texture, pink and black.
## Walk into it and it's yours.

var taken := false
var _mesh: MeshInstance3D
var _t := randf() * 10.0

func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var pm := PrismMesh.new(); pm.size = Vector3(0.14, 0.22, 0.05)
	_mesh.mesh = pm
	_mesh.material_override = Look.mat(Look.get_tex("nugget"), Color.WHITE, 0.0, true, Color(0.9, 0.9, 0.9))
	add_child(_mesh)

func _process(delta: float) -> void:
	if taken:
		return
	_t += delta
	_mesh.rotation.y += delta * 1.6
	_mesh.position.y = sin(_t * 2.0) * 0.05

func take() -> void:
	taken = true
	Trail.mark("nugget take")
	Sfx.play("pop", -4.0, 1.6)
	Trail.mark("nugget popped")
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.2)
	tw.tween_callback(func(): visible = false)
