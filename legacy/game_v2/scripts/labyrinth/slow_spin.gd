extends Node3D
## Things that have come up off the floor and go slowly round, as if on a current nobody feels.
var _t := 0.0
func _process(delta: float) -> void:
	_t += delta
	rotation.y += delta * 0.11
	position.y += sin(_t * 0.7) * 0.0006
