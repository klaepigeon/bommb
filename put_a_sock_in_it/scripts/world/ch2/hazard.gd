class_name Hazard
extends Node3D
## Somewhere that hurts whoever is in it (docs/CHAPTER2.md): water with the mains in it, a burst
## steam pipe. A box (half-size `half`, around this node) that hurts at `dps` while `on()` says so.
## Inhabitants check it every frame (Inhabitant._hazards); Kurt too (the level). Nothing says
## it's there but what it looks and sounds like: the water fizzing, the steam.

var half := Vector3(1, 0.3, 1)
var dps := 40.0
var kind := "shock"            # "shock" | "steam"
var on: Callable               # () -> bool; unset = always

func _ready() -> void:
	add_to_group("hazard")

func live() -> bool:
	return not on.is_valid() or bool(on.call())

func hurts(p: Vector3) -> bool:
	if not live(): return false
	var l := p - global_position
	return absf(l.x) < half.x and absf(l.z) < half.z and l.y > -half.y - 0.2 and l.y < half.y + 1.2
