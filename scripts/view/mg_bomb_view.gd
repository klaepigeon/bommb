extends MgKitView
## DON'T PRESS IT in the Meat Locker: the machine in the middle (wires, three buttons, the
## big red one, two levers, a crank, a countdown face), the puppets round it. Every step
## lights up on its screen; strikes flash; if it goes off, it goes off.

var screen: Label3D
var clock: Label3D
var wires: Dictionary = {}
var levers: Dictionary = {}
var crank: Node3D
var hands: Dictionary = {}


func setup(g: GameView, view: Dictionary) -> void:
	super.setup(g, view)
	part(func(mb: MB):
		mb.box("w", white, Vector3(3.6, 2.2, 2.6), MB.T(Vector3(0, 1.1, 0)), Color("8e5cf0"))
		mb.box("w", white, Vector3(3.0, 1.2, 0.1), MB.T(Vector3(0, 2.6, -0.8)), Color("1a1a1a"))
		for k in 3:
			mb.cyl("w", white, 0.22, 0.22, 0.15, 10, MB.T(Vector3(-0.9 + k * 0.6, 2.25, 0.6)), [Color("2ec4c6"), Color("ffd23f"), Color("6fe3a5")][k])
		mb.cyl("w", white, 0.4, 0.4, 0.2, 12, MB.T(Vector3(1.1, 2.25, 0.5)), Color("ff3b3b")))
	var cols := {"RED": Color("ff3b3b"), "BLUE": Color("2e8bff"), "YELLOW": Color("ffd23f"), "GREEN": Color("3ac060")}
	var k := 0
	for w in cols.keys():
		var n := part(func(mb: MB): mb.box("w", white, Vector3(0.08, 0.08, 1.4), MB.T(), cols[w]))
		n.position = Vector3(-1.4 + k * 0.4, 1.3, 1.32)
		wires[w] = n
		k += 1
	for side in ["L", "R"]:
		var piv := node(Vector3(-1.95 if side == "L" else 1.95, 1.0, 0))
		part(func(mb: MB): mb.box("w", white, Vector3(0.12, 1.2, 0.12), MB.T(Vector3(0, 0.6, 0)), Color("c9d1d9")), piv)
		levers[side] = piv
	crank = node(Vector3(0, 1.0, -1.35))
	part(func(mb: MB):
		mb.box("w", white, Vector3(0.1, 0.1, 0.6), MB.T(Vector3(0, 0, -0.3)), Color("c9d1d9"))
		mb.box("w", white, Vector3(0.5, 0.1, 0.1), MB.T(Vector3(0.25, 0, -0.6)), Color("c9d1d9")), crank)
	screen = label("", Vector3(0, 2.75, -0.7), 40, Color("6fe3a5"))
	clock = label("", Vector3(0, 3.8, 0), 90, Color("ff3b3b"))
	var mg: Dictionary = view.mg
	var n: int = mg.seats.size()
	for i in n:
		var a: float = TAU * i / n + PI / 4
		put(int(mg.seats[i]), Vector3(sin(a) * 3.4, 0, cos(a) * 3.4), Vector3(0, 1.0, 0))
	Audio.music("potato")


func update_view(view: Dictionary, _dt: float) -> void:
	var mg: Dictionary = view.mg
	if not mg.started:
		screen.text = "WAITING..."
		clock.text = ""
	elif mg.exploded:
		screen.text = "!!!"
		clock.text = "BOOM"
	elif mg.defused:
		screen.text = "DEFUSED"
		clock.text = "0:00"
	else:
		screen.text = "STEP %d/%d\n%s\nSTRIKES %d/%d" % [int(mg.stage) + 1, int(mg.stages), str(mg.step), int(mg.strikes), int(mg.max_strikes)]
		clock.text = "%d" % int(ceil(float(mg.clock)))
		if mg.get("locked_you", false):
			screen.text += "\n(not you)"
	for w in wires.keys():
		(wires[w] as Node3D).scale = Vector3(1, 1, 0.3 if (mg.cut as Array).has(w) else 1.0)
	for side in levers.keys():
		var held := false
		for s in mg.levers.keys():
			if mg.levers[s] == side:
				held = true
		(levers[side] as Node3D).rotation.x = -0.9 if held else 0.0
	crank.rotation.z = float(mg.crank) * 0.9
	for s in mg.reach:
		if not hands.has(s):
			act(int(s), "point")
			hands[s] = true
	for s in hands.keys():
		if not (mg.reach as Array).has(s):
			hands.erase(s)


func on_event(e: Dictionary) -> void:
	if e.e != "mg":
		return
	match str(e.k):
		"step":
			Audio.sfx("bell", 0.0, -6.0, 1.4)
		"strike":
			Audio.sfx("alarm", 0.0, -4.0)
			gv.shake(0.2)
			act(int(e.seat), "flinch")
		"boom":
			Audio.sfx("slam", 0.0, 4.0, 0.5)
			gv.shake(1.0)
			gv.stage.flash(0.8)
			for s in gv.view.mg.seats:
				act(int(s), "fall")
		"defused":
			for s in gv.view.mg.seats:
				act(int(s), "celebrate")
		"refuse":
			act(int(e.seat), "shake_head")


func camera() -> Array:
	return [Vector3(0, 7, 7), Vector3(0, 1.5, 0), 0.95]
