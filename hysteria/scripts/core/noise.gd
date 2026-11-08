class_name Noises
## Sounds things can hear: an impact, a footstep, a shot. Anything in the "listener" group with a
## `hear(pos: Vector3, loud: float, what: String, source: Node)` method gets every one. Socko turns
## to them; Marta, hunting by sound, will follow them. loud: 0 (barely) .. 1 (a gunshot).

static var last := {}          # the most recent noise, for tests and debugging

static func make(tree: SceneTree, pos: Vector3, loud: float, what: String, source: Node = null) -> void:
	last = {"pos": pos, "loud": loud, "what": what, "source": source, "time": Time.get_ticks_msec()}
	for n in tree.get_nodes_in_group("listener"):
		if n.has_method("hear"):
			n.call("hear", pos, loud, what, source)
