extends Node
## Noises things can hear. Anything that makes a sound worth hearing calls make(); anything that
## listens connects to `heard`. Loudness is the radius in metres it carries.

signal heard(pos: Vector3, radius: float, source: String)

var last := {}

func make(pos: Vector3, radius: float, source := "") -> void:
	last = {"pos": pos, "radius": radius, "source": source, "t": Time.get_ticks_msec()}
	heard.emit(pos, radius, source)
