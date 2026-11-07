extends MgView
## The secret-choice games, drawn: the puppets round a little table; on it, what's being
## chosen between (bottles, wires on a panel, three doors, name cards). A slip over a
## puppet's head when they've chosen; what they SAY floats up beside them; on the reveal,
## everyone's pick shows over their heads.

var props: Dictionary = {}      # option name -> Node3D
var tags: Dictionary = {}       # seat -> Label3D
var _id := ""


func setup(g: GameView, view: Dictionary) -> void:
	super.setup(g, view)
	_id = str(view.mg.get("id", ""))
	var mb := LcMB.new()
	mb.cyl("t", LcMB.mat(LcTex.wood(Color("4a2a18"), 9, 16, 2)), 1.6, 1.6, 0.1, 12, LcMB.T(Vector3(0, 0.75, 0)), Color(1, 1, 1))
	mb.cyl("l", LcMB.mat(LcTex.wood(Color("3a2010"), 9, 16, 1)), 0.15, 0.2, 0.75, 6, LcMB.T(), Color(1, 1, 1))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	mi.position = center
	add_child(mi)
	var seats: Array = view.mg.seats
	for k in seats.size():
		var s: int = seats[k]
		var a := TAU * k / seats.size() + 0.3
		var c := fig(s)
		if not c.dead:
			c.sit(false)
			c.walk_to(center + Vector3(sin(a), 0, cos(a)) * 2.6)
		var l := Label3D.new()
		l.font = load("res://assets/fonts/fell_sc.ttf")
		l.font_size = 40
		l.pixel_size = 0.008
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.outline_size = 8
		add_child(l)
		tags[s] = l
	Audio.music("roulette")


func _prop(name: String, i: int, n: int) -> Node3D:
	var a := PI * (i + 0.5) / n - PI / 2
	var at := center + Vector3(sin(a) * 0.9, 0.8, cos(a) * 0.5 - 0.2)
	var mb := LcMB.new()
	var col := Color.from_hsv(float(i) / maxf(n, 1), 0.6, 0.8)
	match _id:
		"pick_your_poison":
			mb.cyl("g", LcMB.mat(LcTex.solid(col)), 0.12, 0.12, 0.4, 8, LcMB.T(), Color(1, 1, 1))
			mb.cyl("n", LcMB.mat(LcTex.solid(col.darkened(0.3))), 0.05, 0.05, 0.18, 6, LcMB.T(Vector3(0, 0.4, 0)), Color(1, 1, 1))
		"consensus":
			mb.box("d", LcMB.mat(LcTex.wood(col, i, 16, 2)), Vector3(0.35, 0.6, 0.04), LcMB.T(Vector3(0, 0.3, 0)), Color(1, 1, 1))
		"wrong_answers":
			mb.box("w", LcMB.mat(LcTex.solid(col)), Vector3(0.06, 0.06, 0.6), LcMB.T(Vector3(0, 0.03, 0)), Color(1, 1, 1))
		_:
			mb.box("c", LcMB.mat(LcTex.paper(Color("e8dcc0"), i, 16)), Vector3(0.3, 0.02, 0.4), LcMB.T(), Color(1, 1, 1))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	mi.position = at
	add_child(mi)
	var l := Label3D.new()
	l.text = name
	l.font = load("res://assets/fonts/fell_sc.ttf")
	l.font_size = 36
	l.pixel_size = 0.007
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(0, 0.75, 0)
	l.outline_size = 8
	mi.add_child(l)
	return mi


func update_view(view: Dictionary, _dt: float) -> void:
	var mg: Dictionary = view.mg
	var opts: Array = mg.get("options", [])
	var names := opts.map(func(o): return str(o.name))
	for k in props.keys():
		if not names.has(k):
			props[k].queue_free()
			props.erase(k)
	for i in opts.size():
		var nm := str(opts[i].name)
		if not props.has(nm):
			props[nm] = _prop(nm, i, opts.size())
	var revealed: Dictionary = mg.get("revealed", {})
	var chosen: Array = mg.get("chosen", [])
	var mine: Dictionary = mg.get("mine", {})
	for s in tags.keys():
		var l: Label3D = tags[s]
		var c := fig(s)
		l.position = c.position + Vector3(0, 2.7, 0)
		var txt := ""
		if revealed.has(s):
			txt = _name(revealed[s], opts)
			l.modulate = Color("ffd070")
		elif mine.has(s):
			txt = "(you: %s)" % _name(mine[s], opts)
			l.modulate = Color("a0e0a0")
		elif chosen.has(s):
			txt = "chosen"
			l.modulate = Color("c0c0c0")
		elif mg.get("claims", {}).has(s):
			txt = "says: %s" % _name(mg.claims[s], opts)
			l.modulate = Color("e0c0ff")
		l.text = txt
		if not c.dead and not c.is_ghost:
			c.look_toward(center)


func _name(v, opts: Array) -> String:
	for o in opts:
		if o.value == v:
			return str(o.name)
	return str(v)


func on_event(e: Dictionary) -> void:
	if e.e == "mg" and str(e.k) == "reveal":
		Audio.sfx("bell", 0.0, -4.0)


func camera() -> Array:
	return [center + Vector3(0, 6, 6), center + Vector3(0, 0.6, 0), 0.75]
