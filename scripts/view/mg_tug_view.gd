extends MgKitView
## TUG OF WAR at the Carnival: a rope over a pit of hooks, two puppets on each end, the
## knot in the middle showing who's winning, the beat ring pulsing over the pit.

var rope: Node3D
var knot: Node3D
var beat: MeshInstance3D
var grease: Array = []


func setup(g: GameView, view: Dictionary) -> void:
	super.setup(g, view)
	part(func(mb: MB):
		mb.box("w", white, Vector3(3.0, 0.3, 4.0), MB.T(Vector3(0, -0.6, 0)), Color("1a0b14"))
		for k in 12:
			mb.cyl("w", white, 0.04, 0.0, 0.8, 4, MB.T(Vector3(-1.2 + (k % 4) * 0.8, -0.1, -1.2 + (k / 4) * 1.2)), Color("c9d1d9"))
		for s in [-1.0, 1.0]:
			mb.box("w", white, Vector3(6.0, 0.4, 4.0), MB.T(Vector3(s * 4.5, -0.2, 0)), Color("ff5fa2") if s < 0 else Color("2ec4c6")))
	rope = part(func(mb: MB): mb.box("w", white, Vector3(14.0, 0.12, 0.12), MB.T(), Color("c89a6a")))
	rope.position = Vector3(0, 0.9, 0)
	knot = part(func(mb: MB): mb.sphere("w", white, 0.3, 3, 6, MB.T(), Color("ff3b3b")))
	beat = part(func(mb: MB): mb.ring("w", glow, 1.0, 0.08, 16, MB.T(Vector3.ZERO, Vector3(PI / 2, 0, 0)), Color("ffd23f")))
	beat.position = Vector3(0, 0.1, 0)
	var mg: Dictionary = view.mg
	for t in 2:
		var tm: Array = mg.teams[t]
		for k in tm.size():
			var side := -1.0 if t == 0 else 1.0
			put(int(tm[k]), Vector3(side * (3.0 + k * 1.6), 0, 0), Vector3(0, 0, 0))
	Audio.music("potato")


func update_view(view: Dictionary, _dt: float) -> void:
	var mg: Dictionary = view.mg
	var r := float(mg.rope)
	rope.position.x = r
	knot.position = Vector3(r, 0.9, 0)
	beat.scale = Vector3.ONE * (1.0 + (1.0 - float(mg.beat)) * 1.2)
	for t in 2:
		var tm: Array = mg.teams[t]
		for k in tm.size():
			var s := int(tm[k])
			var c := fig(s)
			if c.dead:
				continue
			var side := -1.0 if t == 0 else 1.0
			var at := Vector3(side * (3.0 + k * 1.6) + r, 0, 0)
			if absf(r) >= float(mg.limit) and ((r > 0 and t == 0) or (r < 0 and t == 1)):
				at = Vector3(r * 0.2, -0.4, 0)
			c.walk_to(at)
			c.rotation.x = -0.25 * side if mg.dig.get(s, false) else 0.0


func on_event(e: Dictionary) -> void:
	if e.e != "mg":
		return
	match str(e.k):
		"heave":
			act(int(e.seat), "surgeon_pull")
			Audio.sfx("kick", 0.1, -10.0, 0.8)
		"slip":
			act(int(e.seat), "stagger")


func camera() -> Array:
	return [Vector3(0, 6, 9), Vector3(0, 0.5, 0), 1.05]
