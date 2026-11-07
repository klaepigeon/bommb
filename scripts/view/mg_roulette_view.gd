extends MgView
## RUSSIAN ROULETTE, drawn: a separate round card table, everyone seated, and the gun (a
## long-barrelled brass revolver, six chambers) passed to whoever's turn it is. A pull: the
## hammer falls, the cylinder turns, click... or the shot.

const R := 1.35
var table: Node3D
var popper: Node3D
var drum: Node3D
var _turn := -1
var _seats: Array = []


func setup(g: GameView, view: Dictionary) -> void:
	super.setup(g, view)
	var mb := LcMB.new()
	var felt := LcMB.mat(LcTex.grime(Color("1a5a3a"), Color("2a7a4a"), 16, 31, 0.3))
	var wood := LcMB.mat(LcTex.wood(Color("5a3020"), 5, 16, 2))
	mb.cyl("f", felt, 1.1, 1.1, 0.06, 12, LcMB.T(Vector3(0, 0.78, 0)), Color(1, 1, 1))
	mb.cyl("w", wood, 1.16, 1.16, 0.08, 12, LcMB.T(Vector3(0, 0.74, 0)), Color(1, 1, 1))
	mb.cyl("w", wood, 0.12, 0.16, 0.74, 6, LcMB.T(), Color(1, 1, 1))
	table = Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	table.add_child(mi)
	table.position = center
	add_child(table)
	popper = Node3D.new()
	drum = Node3D.new()
	popper.add_child(drum)
	var brass := LcMB.mat(LcTex.brass())
	var steel := LcMB.mat(LcTex.grime(Color("3a3a40"), Color("6a6a72"), 16, 3, 0.3))
	var wood2 := LcMB.mat(LcTex.wood(Color("5a2a14"), 6, 16, 1))
	var db := LcMB.new()
	db.cyl("c", steel, 0.1, 0.1, 0.16, 6, LcMB.T(Vector3(0, 0, -0.08), Vector3(PI / 2, 0, 0)), Color(1, 1, 1))
	for k in 6:
		var a := TAU * k / 6
		db.cyl("h", LcMB.mat(LcTex.solid(Color("101010"))), 0.025, 0.025, 0.01, 6, LcMB.T(Vector3(cos(a) * 0.06, sin(a) * 0.06, 0.085), Vector3(PI / 2, 0, 0)), Color(1, 1, 1))
	var dmi := MeshInstance3D.new()
	dmi.mesh = db.build()
	drum.add_child(dmi)
	var gb := LcMB.new()
	# barrel forward (+z: the muzzle), frame, grip, trigger guard
	gb.cyl("b", steel, 0.035, 0.035, 0.5, 6, LcMB.T(Vector3(0, 0.03, 0.08), Vector3(PI / 2, 0, 0)), Color(1, 1, 1))
	gb.box("f", brass, Vector3(0.06, 0.12, 0.26), LcMB.T(Vector3(0, 0.0, -0.02)), Color(1, 1, 1))
	gb.box("g", wood2, Vector3(0.06, 0.26, 0.1), LcMB.T(Vector3(0, -0.15, -0.16), Vector3(-0.35, 0, 0)), Color(1, 1, 1))
	gb.ring("t", brass, 0.05, 0.012, 8, LcMB.T(Vector3(0, -0.08, -0.04), Vector3(0, 0, PI / 2)), Color(1, 1, 1))
	gb.box("h", steel, Vector3(0.03, 0.06, 0.04), LcMB.T(Vector3(0, 0.08, -0.14)), Color(1, 1, 1))
	var fmi := MeshInstance3D.new()
	fmi.mesh = gb.build()
	popper.add_child(fmi)
	popper.position = center + Vector3(0, 0.95, 0)
	add_child(popper)
	_seats = view.mg.order
	for k in _seats.size():
		var s: int = _seats[k]
		var a := TAU * k / _seats.size()
		var c := fig(s)
		if c.dead:
			continue
		c.place(center + Vector3(sin(a), 0, cos(a)) * R)
		c.look_toward(center)
		c.rotation.y = c.face_dir
		c.sit(true)
		c.human.hips.position.y = 0.55
	Audio.music("roulette")


func _seat_pos(s: int) -> Vector3:
	var k := _seats.find(s)
	var a := TAU * k / maxi(_seats.size(), 1)
	return center + Vector3(sin(a), 0, cos(a)) * R


func update_view(view: Dictionary, dt: float) -> void:
	var mg: Dictionary = view.mg
	var t := int(mg.turn)
	if t != _turn:
		_turn = t
		var at := _seat_pos(t)
		var hand := center.lerp(at, 0.62) + Vector3(0, 1.15, 0)
		var tw := create_tween()
		tw.tween_property(popper, "position", hand, 0.5).set_trans(Tween.TRANS_QUAD)
		var dir := (at - center).normalized()
		# muzzle (the frill) faces whoever pulls it: it goes off at you
		tw.parallel().tween_property(popper, "rotation:y", atan2(dir.x, dir.z), 0.5)
	var aims: Dictionary = mg.get("aims", {})
	if aims.has(t):
		var dir2 := (_seat_pos(int(aims[t])) - popper.position)
		popper.rotation.y = lerp_angle(popper.rotation.y, atan2(dir2.x, dir2.z), minf(1.0, dt * 6.0))
	for s in _seats:
		if not fig(s).dead:
			fig(s).human.arm_r.rotation.x = -1.3 if s == t else -0.3


func on_event(e: Dictionary) -> void:
	if e.e != "mg":
		return
	match str(e.k):
		"pull":
			var tw := create_tween()
			tw.tween_property(popper, "position:y", popper.position.y + 0.08, 0.08)
			tw.tween_property(drum, "rotation:z", drum.rotation.z + TAU / 6.0, 0.15)
			tw.tween_property(popper, "position:y", popper.position.y, 0.1)
			if e.bang:
				tw.tween_callback(func():
					Audio.sfx("pop", 0.0, 6.0, 0.7)
					gv.shake(0.4))
			else:
				tw.tween_callback(func(): Audio.sfx("dice_clack", 0.05, 4.0, 0.7))
		"spin":
			var tw := create_tween()
			tw.tween_property(drum, "rotation:z", drum.rotation.z + TAU * 3.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			Audio.sfx("cage_spin", 0.05, -4.0)
		"lower":
			var tw := create_tween()
			tw.tween_property(popper, "position", center + Vector3(0, 0.9, 0), 0.4)
			Audio.sfx("land", 0.05, -6.0)
		"void":
			Audio.sfx("cage_shudder", 0.0, 0.0)


func camera() -> Array:
	return [center + Vector3(0, 6.2, 5.0), center + Vector3(0, 0.4, -0.3), 0.62]
