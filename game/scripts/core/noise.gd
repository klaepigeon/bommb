extends Node
## Sounds that things can hear. Every footstep, impact, door, gunshot, splash, radio and scream
## is made here with a loudness (metres it carries in the open). Listeners (monsters, Socko, the
## residents) are told; walls between halve it, a closed door between quarters it.
signal made(n: Dictionary)

var recent: Array = []           ## [{pos, loud, kind, t, src}] for the last few seconds
var _t := 0.0

func make(pos: Vector3, loud: float, kind: String, src: Object = null) -> void:
	if loud <= 0.05:
		return
	var n := {"pos": pos, "loud": loud, "kind": kind, "t": _t, "src": src}
	recent.append(n)
	made.emit(n)

## How loud a noise is where a listener stands (0 = can't hear it). Walls on the straight line
## between muffle it; `space` is the physics space to test (null: open air).
func heard_at(n: Dictionary, at: Vector3, space: PhysicsDirectSpaceState3D = null, hearing := 1.0) -> float:
	var d: float = (n.pos as Vector3).distance_to(at)
	var loud: float = float(n.loud) * hearing
	if d > loud:
		return 0.0
	if space and d > 1.0:
		var q := PhysicsRayQueryParameters3D.create(n.pos + Vector3(0, 0.3, 0), at + Vector3(0, 0.3, 0), 1)
		var walls := 0
		var from: Vector3 = q.from
		for i in 3:
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				break
			walls += 1
			from = hit.position + (at - from).normalized() * 0.3
			q.from = from
		loud *= pow(0.5, walls)
		if d > loud:
			return 0.0
	return 1.0 - d / loud

func _process(delta: float) -> void:
	_t += delta
	while recent.size() > 0 and _t - float(recent[0].t) > 6.0:
		recent.pop_front()

func now() -> float:
	return _t
