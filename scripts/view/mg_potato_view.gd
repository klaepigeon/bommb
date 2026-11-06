extends MgView
## HOT POTATO, drawn: everyone in a ring, and the toy: a tin clockwork head with a big
## nose, a winding key, a ribbon and two button eyes. It ticks faster as it gets closer.
## Once somebody has fiddled with it, the part it wants touched next lights up (and the
## card on its forehead says what), for anyone who's looking.

const R := 2.6
var toy: Node3D
var parts: Dictionary = {}     # step id -> MeshInstance3D (lit when wanted)
var face_card: Label3D
var _tick := 0.0
var _seats: Array = []
var _flight := {}
var _holder := -1


func setup(g: GameView, view: Dictionary) -> void:
	super.setup(g, view)
	_seats = view.mg.seats
	for k in _seats.size():
		var s: int = _seats[k]
		var c := fig(s)
		if c.dead:
			continue
		c.sit(false)
		c.walk_to(_pos(s))
	toy = Node3D.new()
	add_child(toy)
	var tin := LcMB.mat(LcTex.grime(Color("c8c0a8"), Color("e8e0c8"), 16, 71, 0.3))
	var red := LcMB.mat(LcTex.solid(Color("c82a2a")))
	var mb := LcMB.new()
	mb.sphere("t", tin, 0.24, 4, 8, LcMB.T(), Color(1, 1, 1), Vector3(1, 0.9, 1))
	mb.box("m", red, Vector3(0.16, 0.03, 0.02), LcMB.T(Vector3(0, -0.08, 0.22)), Color(1, 1, 1))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	toy.add_child(mi)
	_part("nose", func(b: LcMB, m): b.cyl("n", m, 0.05, 0.0, 0.14, 6, LcMB.T(Vector3(0, 0.0, 0.22), Vector3(PI / 2, 0, 0)), Color(1, 1, 1)), Color("e8402a"))
	_part("ribbon", func(b: LcMB, m): b.box("r", m, Vector3(0.36, 0.06, 0.02), LcMB.T(Vector3(0, 0.17, 0.1), Vector3(0.4, 0, 0)), Color(1, 1, 1)), Color("2a8ae8"))
	_part("key", func(b: LcMB, m):
		b.box("k", m, Vector3(0.03, 0.03, 0.14), LcMB.T(Vector3(0, 0, -0.28)), Color(1, 1, 1))
		b.box("k", m, Vector3(0.18, 0.1, 0.02), LcMB.T(Vector3(0, 0, -0.36)), Color(1, 1, 1)), Color("c8a040"))
	_part("eyes", func(b: LcMB, m):
		b.cyl("e", m, 0.04, 0.04, 0.02, 8, LcMB.T(Vector3(-0.08, 0.07, 0.21), Vector3(PI / 2, 0, 0)), Color(1, 1, 1))
		b.cyl("e", m, 0.04, 0.04, 0.02, 8, LcMB.T(Vector3(0.08, 0.07, 0.21), Vector3(PI / 2, 0, 0)), Color(1, 1, 1)), Color("202020"))
	_part("hush", func(b: LcMB, m): b.box("h", m, Vector3(0.1, 0.06, 0.02), LcMB.T(Vector3(0, -0.12, 0.215)), Color(1, 1, 1)), Color("802020"))
	face_card = Label3D.new()
	face_card.font_size = 36
	face_card.pixel_size = 0.005
	face_card.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	face_card.position = Vector3(0, 0.45, 0)
	face_card.modulate = Color("fff080")
	face_card.outline_size = 8
	toy.add_child(face_card)
	toy.position = center + Vector3(0, 1.2, 0)
	toy.scale = Vector3.ONE * 1.8
	Audio.music("potato")


func _part(id: String, make: Callable, c: Color) -> void:
	var b := LcMB.new()
	make.call(b, LcMB.mat(LcTex.solid(c)))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	toy.add_child(mi)
	parts[id] = {"node": mi, "color": c}


func _pos(s: int) -> Vector3:
	var k := _seats.find(s)
	var a := TAU * k / maxi(_seats.size(), 1) + 0.4
	return center + Vector3(sin(a), 0, cos(a)) * R


func _hands(s: int) -> Vector3:
	var c := fig(s)
	return c.position + (center - c.position).normalized() * 0.45 + Vector3(0, 1.15, 0)


func update_view(view: Dictionary, dt: float) -> void:
	var mg: Dictionary = view.mg
	for s in _seats:
		if not fig(s).dead:
			fig(s).look_toward(toy.global_position)
	var fl: Dictionary = mg.flight
	if not fl.is_empty():
		var k := clampf(float(fl.t) / maxf(float(fl.dur), 0.01), 0.0, 1.0)
		var a := _hands(int(fl.from))
		var b := _hands(int(fl.to))
		toy.position = a.lerp(b, k) + Vector3(0, sin(k * PI) * 1.2, 0)
		toy.rotation.x += dt * 12.0
	elif int(mg.holder) >= 0:
		toy.position = toy.position.lerp(_hands(int(mg.holder)), minf(1.0, dt * 12.0))
		toy.rotation.x = lerpf(toy.rotation.x, 0.0, minf(1.0, dt * 8.0))
		var h := int(mg.holder)
		if not fig(h).dead:
			fig(h).human.arm_l.rotation.x = -1.2
			fig(h).human.arm_r.rotation.x = -1.2
	if _holder != int(mg.holder):
		if _holder >= 0 and not fig(_holder).dead:
			fig(_holder).human.arm_l.rotation.x = 0.0
			fig(_holder).human.arm_r.rotation.x = 0.0
		_holder = int(mg.holder)
	if not mg.busy.is_empty():
		toy.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.02
	# the ticking gets quicker
	var urg := float(mg.urgency)
	_tick -= dt
	if _tick <= 0.0 and mg.sub == "play":
		_tick = lerpf(0.55, 0.09, urg * urg)
		Audio.sfx("tick", 0.02, -4.0 + urg * 6.0, 1.0 + urg * 0.5)
	# what it wants next (visible to anyone looking at it)
	var want := ""
	var step := int(mg.step)
	if step >= 1 and step < int(mg.n_steps):
		want = HotPotatoSteps.ID[step]
	for id in parts.keys():
		var lit: bool = id == want and fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.3
		var m: MeshInstance3D = parts[id].node
		m.material_override = LcMB.mat(LcTex.solid(Color("fff060")), Color("fff060"), Vector2.ONE, true) if lit else null
	face_card.text = str(mg.next) if want != "" and gv.viewer_sight() > 0.3 else ""


func on_event(e: Dictionary) -> void:
	if e.e != "mg":
		return
	match str(e.k):
		"pass":
			Audio.sfx("whoosh", 0.1, -6.0)
		"catch":
			Audio.sfx("land", 0.1, -10.0, 1.4)
		"doing":
			Audio.sfx("zip", 0.1, -6.0)
		"step_done":
			Audio.sfx("unlock", 0.05, -4.0)
		"defused":
			Audio.music("")
			Audio.sfx("heal", 0.0, 0.0, 0.7)
			face_card.text = ""
		"boom":
			toy.visible = false
			Audio.music("")
			gv.shake(0.8)


func camera() -> Array:
	return [center + Vector3(0, 7.0, 7.0), center + Vector3(0, 0.8, 0)]
