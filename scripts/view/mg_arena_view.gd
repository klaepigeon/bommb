extends MgView
## Every arena game, drawn from its view (ArenaGame.arena_view): a metal plate on the table
## for the floor, and each object by kind: chairs, the belt and the grinder and its presses,
## pressure plates and crates, the corridor with its blades, doors, vent and the hooks,
## holes and saws and chains, dart lanes and barriers, Teeth to pick up, ghosts' cold
## spots. The puppets walk where the view says.

var nodes: Dictionary = {}      # key -> Node3D
var floor_node: MeshInstance3D
var _id := ""
var _music := ""


func setup(g: GameView, view: Dictionary) -> void:
	super.setup(g, view)
	_id = str(view.mg.get("id", ""))
	var b: Array = view.mg.get("bounds", [-6, -4.5, 12, 9])
	var mb := LcMB.new()
	var plate := LcMB.mat(LcTex.grime(Color("3a3a40"), Color("5a5a62"), 32, 91, 0.4))
	mb.box("f", plate, Vector3(float(b[2]) + 0.6, 0.12, float(b[3]) + 0.6), LcMB.T(Vector3(float(b[0]) + float(b[2]) / 2.0, 0.0, float(b[1]) + float(b[3]) / 2.0)), Color(1, 1, 1))
	floor_node = MeshInstance3D.new()
	floor_node.mesh = mb.build()
	floor_node.position = center
	add_child(floor_node)
	_music = {"meat_grinder": "potato", "run_for_your_life": "potato", "last_seat": "chairs"}.get(_id, "roulette")
	Audio.music(_music)
	for s in view.mg.seats:
		var c := fig(int(s))
		if not c.dead:
			c.sit(false)


func _node(key: String, make: Callable) -> Node3D:
	if not nodes.has(key):
		var n: Node3D = make.call()
		add_child(n)
		nodes[key] = n
	var n: Node3D = nodes[key]
	n.visible = true
	n.set_meta("seen", true)
	return n


func _box(size: Vector3, col: Color, unlit := false) -> Node3D:
	var mb := LcMB.new()
	mb.box("b", LcMB.mat(LcTex.grime(col.darkened(0.2), col, 16, int(col.r * 50 + col.b * 20), 0.4), Color.WHITE, Vector2.ONE, unlit), size, LcMB.T(Vector3(0, size.y / 2.0, 0)), Color(1, 1, 1))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	return mi


func _disc(r: float, col: Color, alpha := 1.0) -> Node3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.03
	cm.radial_segments = 12
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.material = m
	mi.mesh = cm
	return mi


func _label(text: String, col := Color("f0e6cc")) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = load("res://assets/fonts/fell_sc.ttf")
	l.font_size = 48
	l.pixel_size = 0.008
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = col
	l.outline_size = 10
	l.no_depth_test = true
	return l


func _at(p: Vector2, y := 0.06) -> Vector3:
	return center + Vector3(p.x, y, p.y)


func update_view(view: Dictionary, _dt: float) -> void:
	var mg: Dictionary = view.mg
	for k in nodes.keys():
		nodes[k].set_meta("seen", false)
	var counts := {}
	for o in mg.get("objects", []):
		var kind := str(o.kind)
		var i: int = counts.get(kind, 0)
		counts[kind] = i + 1
		var key := "%s%d" % [kind, i]
		var p: Vector2 = o.get("pos", Vector2.ZERO)
		var size: Array = o.get("size", [1, 1])
		match kind:
			"chair":
				var n := _node(key, func():
					var c := _box(Vector3(0.6, 0.55, 0.6), Color("8a4a2a"))
					var back := _box(Vector3(0.6, 0.6, 0.08), Color("6a3420"))
					back.position = Vector3(0, 0.55, -0.26)
					c.add_child(back)
					return c)
				n.position = _at(p)
				n.scale = Vector3.ONE * (0.8 if o.get("locked", false) else 1.0)
			"belt", "corridor":
				var n := _node(key, func(): return _box(Vector3(float(size[0]), 0.06, float(size[1])), Color("2a2a2a") if kind == "belt" else Color("4a3a30")))
				n.position = _at(p, 0.0)
			"grinder", "hooks":
				var n := _node(key, func():
					var g := _box(Vector3(float(size[0]), 0.9, float(size[1])), Color("6a1010") if kind == "grinder" else Color("8a8a90"))
					return g)
				n.position = _at(p, 0.0)
			"press":
				var n := _node(key, func(): return _box(Vector3(float(size[0]), 0.25, float(size[1])), Color("7a7a80")))
				n.position = _at(p, 0.15 if o.get("closed", false) else 1.4)
				if o.get("closed", false) and not n.get_meta("was_closed", false):
					Audio.sfx("slam", 0.1, -10.0, 1.4)
				n.set_meta("was_closed", o.get("closed", false))
			"rat":
				var n := _node(key, func():
					var mi := MeshInstance3D.new()
					mi.mesh = DeadRat.mesh()
					mi.scale = Vector3.ONE * 0.8
					return mi)
				n.position = _at(p)
			"plate":
				var n := _node(key, func():
					var pl := _box(Vector3(1.4, 0.08, 1.4), Color("b08a3a"))
					var l := _label("")
					l.name = "L"
					l.position = Vector3(0, 0.8, 0)
					pl.add_child(l)
					return pl)
				n.position = _at(p, 0.0)
				(n.get_node("L") as Label3D).text = "%d / %d" % [int(o.count), int(o.target)]
				(n.get_node("L") as Label3D).modulate = Color("8ae08a") if int(o.count) == int(o.target) else Color("ff8a6a")
			"crate":
				var n := _node(key, func(): return _box(Vector3(0.45, 0.45, 0.45), Color("8a6a40")))
				n.position = _at(p, 0.06 + (1.0 if int(o.get("held", -1)) >= 0 else 0.0))
			"finish":
				var n := _node(key, func(): return _box(Vector3(float(size[0]), 0.04, float(size[1])), Color("e0e0e0"), true))
				n.position = _at(p, 0.0)
			"vent":
				var n := _node(key, func(): return _box(Vector3(0.7, 0.05, 0.4), Color("1a1a1a")))
				n.position = _at(p, 0.0)
			"blade":
				var n := _node(key, func():
					var bl := _box(Vector3(0.1, 0.9, 0.8), Color("d0d0d8"))
					return bl)
				n.position = _at(p, 0.0)
				n.rotation.y += 0.4
			"door":
				var n := _node(key, func(): return _box(Vector3(0.15, 1.4, 3.2), Color("5a3a20")))
				n.position = _at(p, 0.0)
				n.scale.y = 1.0 if o.get("shut", false) else 0.08
			"hole":
				var n := _node(key, func(): return _box(Vector3(float(size[0]), 0.02, float(size[1])), Color("050303"), true))
				n.position = _at(p, 0.065)
			"saw":
				var n := _node(key, func():
					var mi := MeshInstance3D.new()
					var mb := LcMB.new()
					mb.cyl("s", LcMB.mat(LcTex.grime(Color("9a9aa0"), Color("d8d8e0"), 16, 5, 0.3)), 0.45, 0.45, 0.05, 10, LcMB.T(Vector3.ZERO, Vector3(PI / 2, 0, 0)), Color(1, 1, 1))
					mi.mesh = mb.build()
					return mi)
				n.position = _at(p, 0.4)
				if not o.get("stopped", false):
					n.rotation.z += 0.5
			"lane":
				var n := _node(key, func(): return _disc(0.15, Color("ff2020"), 0.6))
				n.position = _at(p, 0.08)
				n.scale = Vector3(1.0, 1.0, float(size[1]) / 0.3)
			"barrier":
				var n := _node(key, func(): return _box(Vector3(0.2, 1.2, float(size[1])), Color("6a8ab0")))
				n.position = _at(p, 0.0)
			"chain":
				var a: Vector2 = mg.pos.get(int(o.a), Vector2.ZERO)
				var b2: Vector2 = mg.pos.get(int(o.b), Vector2.ZERO)
				var n := _node(key, func(): return _box(Vector3(0.06, 0.06, 1.0), Color("6a6a70")))
				var mid := (a + b2) / 2.0
				n.position = _at(mid, 0.3)
				n.scale = Vector3(1, 1, maxf(0.05, a.distance_to(b2)))
				n.rotation.y = atan2(b2.x - a.x, b2.y - a.y)
	var ci := 0
	for c in mg.get("cold", []):
		var n := _node("cold%d" % ci, func(): return _disc(1.0, Color("a0d0ff"), 0.3))
		n.position = _at(c.pos, 0.09)
		n.scale = Vector3(c.r, 1, c.r)
		ci += 1
	for k in nodes.keys():
		if not nodes[k].get_meta("seen", false):
			nodes[k].visible = false
	for s in mg.seats:
		var c: Contestant = fig(int(s))
		if c.dead or c.is_ghost:
			continue
		var p: Vector2 = mg.pos.get(s, Vector2.ZERO)
		var seated: Dictionary = mg.get("seated", {})
		if seated.has(s):
			c.position = _at(p, 0.05)
			c.target = c.position
			c.sit(true)
		else:
			c.sit(false)
			c.walk_to(_at(p, 0.05))


func on_event(e: Dictionary) -> void:
	if e.e != "mg":
		return
	match str(e.k):
		"push":
			Audio.sfx("kick", 0.1, -6.0)
		"alarm":
			Audio.music_halt(true)
			Audio.sfx("alarm", 0.0, 0.0)
		"press", "blade", "saw", "dart":
			Audio.sfx("hit_heavy" if false else "hurt", 0.1, 0.0)
			gv.shake(0.3)
		"spring":
			Audio.sfx("spring", 0.05, 0.0)
		"collapse":
			Audio.sfx("break", 0.05, 0.0)
		"slam":
			Audio.sfx("door", 0.05, 0.0)
		"finish":
			Audio.sfx("bell", 0.0, -2.0)


func camera() -> Array:
	return [center + Vector3(0, 9.5, 8.5), center, 1.15]


func _exit_tree() -> void:
	Audio.music_halt(false)
