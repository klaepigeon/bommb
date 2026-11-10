extends Node3D
## The cradle on its spring pole, rocking by itself: slowly, as if a hand had just let go of it.
var _t := 0.0
func _process(delta: float) -> void:
	_t += delta
	rotation.x = sin(_t * 1.05) * 0.16
	position.y += sin(_t * 2.1) * 0.0004
