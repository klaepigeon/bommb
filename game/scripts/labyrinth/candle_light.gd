extends OmniLight3D
## A candle (or an icon lamp): a soft, slow unsteadiness, never a flicker.
var _base := -1.0
var _t := randf() * 10.0
func _process(delta: float) -> void:
	if _base < 0.0: _base = light_energy
	_t += delta
	light_energy = _base * (0.9 + 0.06 * sin(_t * 2.3) + 0.04 * sin(_t * 5.7 + 1.0))
