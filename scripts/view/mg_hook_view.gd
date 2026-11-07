extends MgKitView
## HOOK, LINE AND SINKER in the Aquarium: a vat of offal in a glass tank, a crane per puppet
## along the back, each line and hook swinging over the vat; what's floating in it (Teeth,
## gold, jars, the jaws); the live cable's flicker across the surface.

var cranes: Dictionary = {}     # seat -> {arm, line, hook, catch}
var objs: Array = []
var surface: MeshInstance3D
var spark_lbl: Label3D
var W := 8.0
var D := 4.0


func setup(g: GameView, view: Dictionary) -> void:
	super.setup(g, view)
	var mg: Dictionary = view.mg
	W = float(mg.vat[0])
	D = float(mg.vat[1])
	part(func(mb: MB):
		mb.box("w", white, Vector3(W + 1.0, 0.4, 3.0), MB.T(Vector3(0, -0.2, 0)), Color("c9d1d9"))
		mb.box("w", white, Vector3(W + 1.0, 2.2, 0.2), MB.T(Vector3(0, 0.9, 1.6)), Color("bfe9ff"))
		mb.box("w", white, Vector3(0.2, 2.2, 3.2), MB.T(Vector3(-W / 2 - 0.5, 0.9, 0)), Color("bfe9ff"))
		mb.box("w", white, Vector3(0.2, 2.2, 3.2), MB.T(Vector3(W / 2 + 0.5, 0.9, 0)), Color("bfe9ff"))
		mb.box("w", white, Vector3(W + 1.0, 0.25, 0.4), MB.T(Vector3(0, 5.2, -1.6)), Color("ffd23f")))
	surface = part(func(mb: MB): mb.box("w", white, Vector3(W + 0.8, 0.05, 2.8), MB.T(), Color("8a1a24")))
	surface.position = Vector3(0, 1.9, 0)
	spark_lbl = label("", Vector3(0, 3.5, 1.0), 70, Color("6af0ff"))
	var k := 0
	for s in mg.seats:
		var arm := node(Vector3(0, 5.2, -1.5))
		part(func(mb: MB):
			mb.box("w", white, Vector3(0.5, 0.5, 0.5), MB.T(), PartyUi.seat_colour(int(s)))
			mb.box("w", white, Vector3(0.15, 0.6, 0.15), MB.T(Vector3(0, -0.5, 0.3)), Color("8a96a4")), arm)
		var line := node(Vector3.ZERO, self)
		var lm := part(func(mb: MB): mb.box("w", white, Vector3(0.04, 1.0, 0.04), MB.T(Vector3(0, -0.5, 0)), Color("e8eef2")), line)
		var hook := node(Vector3.ZERO, self)
		part(func(mb: MB): mb.ring("w", white, 0.18, 0.05, 6, MB.T(Vector3.ZERO, Vector3(0, PI / 2, 0)), Color("c9d1d9")), hook)
		cranes[int(s)] = {"arm": arm, "line": line, "lm": lm, "hook": hook}
		put(int(s), Vector3(-W / 2 + W * (k + 0.5) / mg.seats.size(), 0, -3.2), Vector3(0, 0, 0))
		k += 1
	Audio.music("potato")


func update_view(view: Dictionary, _dt: float) -> void:
	var mg: Dictionary = view.mg
	for s in mg.hooks.keys():
		var h: Dictionary = mg.hooks[s]
		var cr: Dictionary = cranes.get(int(s), {})
		if cr.is_empty():
			continue
		var x := float(h.x)
		(cr.arm as Node3D).position.x = x
		var depth := float(h.depth) / D * 3.2
		var top := Vector3(x, 4.6, -1.2)
		(cr.line as Node3D).position = top
		(cr.line as Node3D).scale = Vector3(1, maxf(0.05, depth + 0.6), 1)
		(cr.hook as Node3D).position = top - Vector3(0, depth + 0.6, 0)
		var c := fig(int(s))
		if not c.dead:
			c.walk_to(Vector3(x, 0, -3.2))
	for o in objs:
		o.queue_free()
	objs.clear()
	for o in mg.objs:
		var col := {"tooth": Color("fff4dc"), "gold": Color("ffd23f"), "jar": Color("bfe9ff"), "jaws": Color("3a3a3a")}.get(str(o.kind), Color.WHITE)
		var n := part(func(mb: MB):
			if str(o.kind) == "jaws":
				for k in 5:
					mb.box("w", white, Vector3(0.08, 0.25, 0.08), MB.T(Vector3(-0.2 + k * 0.1, 0.1, 0)), Color("e8eef2"))
				mb.box("w", white, Vector3(0.6, 0.1, 0.3), MB.T(), col)
			else:
				mb.sphere("w", white, 0.22 if str(o.kind) != "jar" else 0.32, 3, 6, MB.T(), col))
		n.position = Vector3(float(o.x), 1.85 - float(o.d) / D * 3.0, 0.2)
		objs.append(n)
	spark_lbl.text = "! LIVE !" if mg.spark_warn else ("ZZZT" if mg.spark else "")
	surface.visible = not mg.spark or int(Time.get_ticks_msec() / 60) % 2 == 0


func on_event(e: Dictionary) -> void:
	if e.e != "mg":
		return
	match str(e.k):
		"bank":
			act(int(e.seat), "cheer")
			Audio.sfx("bell", 0.0, -6.0, 1.5)
		"jaws", "shock":
			act(int(e.seat), "recoil")
			gv.shake(0.3)
			Audio.sfx("hurt", 0.1, -2.0)
		"jerk":
			act(int(e.seat), "taunt")
			act(int(e.target), "stagger")
		"spark":
			Audio.sfx("buzz", 0.0, -2.0)


func camera() -> Array:
	return [Vector3(0, 6, 10), Vector3(0, 2.0, 0), 0.95]
