extends MgKitView
## SPIN CYCLE in the Impossible Room: a giant drum seen from the front, its paddles turning,
## the puppets running on the inside of it at their angles; bricks' shadows on the drum
## before they fall; the lights stutter before it reverses; the REVERSE LEVER.

const R := 3.6
var drum: Node3D
var bricks: Array = []
var rev_lbl: Label3D
var drum_ang := 0.0


func setup(g: GameView, view: Dictionary) -> void:
	super.setup(g, view)
	part(func(mb: MB):
		mb.box("w", white, Vector3(10, 10, 0.4), MB.T(Vector3(0, R + 0.5, -1.6)), Color("e8eef2"))
		mb.cyl("w", white, R + 0.6, R + 0.6, 0.3, 24, MB.T(Vector3(0, R + 0.5, -1.4), Vector3(PI / 2, 0, 0)), Color("c9d1d9"))
		mb.cyl("w", white, R + 0.5, R + 0.5, 0.3, 24, MB.T(Vector3(0, R + 0.5, 1.4), Vector3(PI / 2, 0, 0)), Color("8a96a4")))
	drum = node(Vector3(0, R + 0.5, 0))
	part(func(mb: MB):
		for k in 24:
			var a := TAU * k / 24.0
			mb.box("w", white, Vector3(0.95, 0.15, 2.6), MB.T(Vector3(cos(a), sin(a), 0) * R, Vector3(0, 0, a + PI / 2)), Color("bfe9ff") if k % 2 == 0 else Color("2ec4c6"))
		for k in 4:
			var a := TAU * k / 4.0
			mb.box("w", white, Vector3(0.25, 0.7, 2.4), MB.T(Vector3(cos(a), sin(a), 0) * (R - 0.4), Vector3(0, 0, a)), Color("ff5fa2")), drum)
	rev_lbl = label("", Vector3(0, R * 2 + 1.5, 1.0), 80, Color("ff3b3b"))
	Audio.music("potato")


func update_view(view: Dictionary, dt: float) -> void:
	var mg: Dictionary = view.mg
	drum_ang += float(mg.omega) * dt
	drum.rotation.z = drum_ang
	for s in mg.seats:
		var c := fig(int(s))
		if c.dead or c.is_ghost:
			continue
		var a := float(mg.ang.get(s, 0.0))
		var out: bool = (mg.out as Array).has(s)
		var p := Vector3(sin(a) * (R - 0.2), R + 0.5 - cos(a) * (R - 0.2), 0.0) if not out else Vector3(5.5, 0, 2.0)
		c.position = p
		c.target = p
		c.rotation.z = a
		c.rotation.y = 0.0 if float(mg.run.get(s, 0.0)) >= 0.0 else PI
	for b in bricks:
		b.queue_free()
	bricks.clear()
	for b in mg.bricks:
		var a := float(b.a)
		var warn := float(b.warn) > 0.0
		var y := lerpf(R * 2.0, 0.6, 1.0 - clampf(float(b.warn) / 1.2, 0.0, 1.0)) if warn else 0.6
		var n := part(func(mb: MB): mb.box("w", white, Vector3(0.6, 0.35, 0.8), MB.T(), Color("b0503a")))
		n.position = Vector3(sin(a) * (R - 0.4), R + 0.5 - cos(a) * (R - 0.4), 0.6) if not warn else Vector3(sin(a) * (R - y), R + 0.5 - cos(a) * (R - y), 0.6)
		bricks.append(n)
		if warn:
			var sh := part(func(mb: MB): mb.box("w", white, Vector3(0.7, 0.05, 1.0), MB.T(), Color("1a0b14")))
			sh.position = Vector3(sin(a) * (R - 0.12), R + 0.5 - cos(a) * (R - 0.12), 0.6)
			sh.rotation.z = a
			bricks.append(sh)
	rev_lbl.text = "REVERSING!" if mg.rev_warn else ""


func on_event(e: Dictionary) -> void:
	if e.e != "mg":
		return
	match str(e.k):
		"fall":
			act(int(e.seat), "fall")
			Audio.sfx("hurt", 0.1, -2.0)
			gv.shake(0.25)
		"lever":
			act(int(e.seat), "push")
			Audio.sfx("door", 0.0, -2.0)
		"reverse":
			Audio.sfx("slam", 0.0, -6.0, 0.7)


func camera() -> Array:
	return [Vector3(0, 5, 12), Vector3(0, R + 0.3, 0), 1.25]
