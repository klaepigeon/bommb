class_name Venue
extends Node3D
## The function room: bright, colourful and strangely inviting. A checked dance floor,
## striped wallpaper, bunting and balloons, the Caller's pulpit, and the door at the far
## end that he says is painted on. Built from the LAST CALL textures and mesh builder, lit
## by the ink shader's drawn lamps (no real lights: cheap on phones).
##
## Also the board: a tile for every space in board.json, coloured by type.

const HALF := Vector2(11.5, 8.0)
const WALL_H := 5.0
const PULPIT := Vector3(5.6, 0, -3.6)
const DOOR := Vector3(0, 0, -HALF.y)

const TILE_COLORS := {"start": Color("40c060"), "tickets": Color("f0c020"), "item": Color("2a8ae8"), "hazard": Color("e8402a"),
	"note": Color("b8a890"), "clue": Color("c8b8a0"), "caller": Color("a040c0"), "steal": Color("e88020"),
	"medic": Color("f0f0f0"), "door": Color("6a4a30")}
const TILE_GLYPH := {"start": "GO", "tickets": "$", "item": "?", "hazard": "!", "note": "", "clue": "",
	"caller": "C", "steal": "&", "medic": "+", "door": ""}

var tiles: Array[Node3D] = []
var board: Array = []
var door_node: Node3D
var key_marker: Node3D
var lamps: Array = []


func build(spaces: Array) -> void:
	board = spaces
	RenderingServer.global_shader_parameter_set("ambient_color", Color(0.78, 0.62, 0.7))
	RenderingServer.global_shader_parameter_set("moon_color", Color(0.55, 0.5, 0.6))
	RenderingServer.global_shader_parameter_set("moon_dir", Vector3(0.3, -0.85, 0.4).normalized())
	_room()
	_decor()
	_pulpit()
	_board()
	for p in [Vector3(-6, 4.4, -3), Vector3(6, 4.4, -3), Vector3(-6, 4.4, 4), Vector3(6, 4.4, 4), Vector3(0, 4.4, 0)]:
		lamps.append(Lamp.create(self, p, Color(1.0, 0.82, 0.6), 0.55, 9.0))
	lamps.append(Lamp.create(self, PULPIT + Vector3(0, 3.5, 1.0), Color(1.0, 0.45, 0.6), 0.7, 5.0))


func _add(mb: LcMB, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	parent.add_child(mi)
	return mi


func _room() -> void:
	var floor_m := LcMB.mat(LcTex.checker(Color("e8d8c0"), Color("c83a5a"), 32, 4, 3, 0.15), Color.WHITE, Vector2(12, 8))
	var mb := LcMB.new()
	mb.box("f", floor_m, Vector3(HALF.x * 2, 0.2, HALF.y * 2), LcMB.T(Vector3(0, -0.1, 0)), Color(1, 1, 1))
	_add(mb)
	var paper := LcMB.mat(_wallpaper(), Color.WHITE, Vector2(8, 2))
	var dado := LcMB.mat(LcTex.wood(Color("5a3020"), 7, 32, 4), Color.WHITE, Vector2(8, 1))
	var w := LcMB.new()
	# back, left, right walls (the front stays open for the camera)
	w.box("p", paper, Vector3(HALF.x * 2, WALL_H, 0.3), LcMB.T(Vector3(0, WALL_H / 2, -HALF.y - 0.15)), Color(1, 1, 1))
	w.box("p", paper, Vector3(0.3, WALL_H, HALF.y * 2), LcMB.T(Vector3(-HALF.x - 0.15, WALL_H / 2, 0)), Color(1, 1, 1))
	w.box("p", paper, Vector3(0.3, WALL_H, HALF.y * 2), LcMB.T(Vector3(HALF.x + 0.15, WALL_H / 2, 0)), Color(1, 1, 1))
	w.box("d", dado, Vector3(HALF.x * 2, 1.0, 0.36), LcMB.T(Vector3(0, 0.5, -HALF.y - 0.12)), Color(1, 1, 1))
	w.box("d", dado, Vector3(0.36, 1.0, HALF.y * 2), LcMB.T(Vector3(-HALF.x - 0.12, 0.5, 0)), Color(1, 1, 1))
	w.box("d", dado, Vector3(0.36, 1.0, HALF.y * 2), LcMB.T(Vector3(HALF.x + 0.12, 0.5, 0)), Color(1, 1, 1))
	_add(w)
	# the door: a real one (it opens), in a frame, with EXIT painted over it badly
	door_node = Node3D.new()
	door_node.position = DOOR + Vector3(-0.8, 0, 0.05)
	add_child(door_node)
	var d := LcMB.new()
	d.box("w", LcMB.mat(LcTex.wood(Color("7a4a2a"), 11, 32, 2)), Vector3(1.6, 2.8, 0.1), LcMB.T(Vector3(0.8, 1.4, 0)), Color(1, 1, 1))
	d.box("k", LcMB.mat(LcTex.brass()), Vector3(0.12, 0.12, 0.08), LcMB.T(Vector3(1.4, 1.3, 0.06)), Color(1, 1, 1))
	for i in 3:
		d.box("k", LcMB.mat(LcTex.brass()), Vector3(0.1, 0.1, 0.06), LcMB.T(Vector3(1.1 + i * 0.13, 1.55, 0.06)), Color(0.8, 0.8, 0.8))
	_add(d, door_node)
	var fr := LcMB.new()
	var frame_m := LcMB.mat(LcTex.wood(Color("3a2014"), 12, 16, 1))
	fr.box("f", frame_m, Vector3(0.15, 3.0, 0.2), LcMB.T(DOOR + Vector3(-0.88, 1.5, 0.1)), Color(1, 1, 1))
	fr.box("f", frame_m, Vector3(0.15, 3.0, 0.2), LcMB.T(DOOR + Vector3(0.88, 1.5, 0.1)), Color(1, 1, 1))
	fr.box("f", frame_m, Vector3(1.9, 0.15, 0.2), LcMB.T(DOOR + Vector3(0, 3.0, 0.1)), Color(1, 1, 1))
	_add(fr)
	var exit_sign := Label3D.new()
	exit_sign.text = "E X I T"
	exit_sign.font_size = 64
	exit_sign.pixel_size = 0.008
	exit_sign.modulate = Color("40e060")
	exit_sign.position = DOOR + Vector3(0, 3.35, 0.2)
	add_child(exit_sign)
	var lie := Label3D.new()
	lie.text = "(painted on)"
	lie.font_size = 28
	lie.pixel_size = 0.006
	lie.modulate = Color("f0e0c0")
	lie.position = DOOR + Vector3(0.2, 2.2, 0.18)
	lie.rotation.z = 0.12
	add_child(lie)


func _wallpaper() -> Texture2D:
	return LcTex.cached("mp_wallpaper", func():
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var stripe := (x / 4) % 2 == 0
				var c := Color("f0b8c8") if stripe else Color("f8e8d0")
				if (x % 8 == 2) and (y % 8 == 4):
					c = Color("f0c020")
				c = c.darkened(LcTex.fbm(x * 0.2, y * 0.2, 5) * 0.12)
				img.set_pixel(x, y, c)
		return img)


func _decor() -> void:
	# bunting along the back and sides
	var colors := [Color("e8402a"), Color("f0c020"), Color("2a8ae8"), Color("40c060"), Color("e040c0")]
	var bunt := LcMB.new()
	var mats := []
	for c in colors:
		mats.append(LcMB.mat(LcTex.solid(c)))
	var k := 0
	for side in [[Vector3(-HALF.x, 4.3, -HALF.y + 0.3), Vector3(HALF.x, 4.3, -HALF.y + 0.3)],
			[Vector3(-HALF.x + 0.3, 4.3, -HALF.y), Vector3(-HALF.x + 0.3, 4.3, HALF.y)],
			[Vector3(HALF.x - 0.3, 4.3, -HALF.y), Vector3(HALF.x - 0.3, 4.3, HALF.y)]]:
		var a: Vector3 = side[0]
		var b: Vector3 = side[1]
		var n := int(a.distance_to(b) / 0.7)
		for i in n:
			var p := a.lerp(b, (i + 0.5) / n)
			p.y -= sin(PI * (i + 0.5) / n) * 0.5
			var dir := (b - a).normalized()
			var m: Material = mats[k % mats.size()]
			k += 1
			bunt.tri("b%d" % (k % 5), m, p - dir * 0.25, p + dir * 0.25, p + Vector3(0, -0.45, 0), Color(1, 1, 1))
	_add(bunt)
	# balloons in clumps, on strings
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var bl := LcMB.new()
	for clump in [Vector3(-10.4, 0, -7.0), Vector3(10.4, 0, -7.0), Vector3(-10.4, 0, 6.5), Vector3(10.4, 0, 6.5), Vector3(-3.0, 0, -7.4)]:
		for i in 5:
			var c: Color = colors[rng.randi_range(0, 4)]
			var at: Vector3 = clump + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(2.2, 3.4), rng.randf_range(-0.4, 0.4))
			bl.sphere("b%d" % colors.find(c), mats[colors.find(c)], 0.32, 4, 8, LcMB.T(at), Color(1, 1, 1), Vector3(1, 1.2, 1))
			bl.box("s", LcMB.mat(LcTex.solid(Color("e0e0e0"))), Vector3(0.01, at.y - 0.4, 0.01), LcMB.T(Vector3(at.x, (at.y - 0.4) / 2, at.z)), Color(1, 1, 1))
	_add(bl)
	# a banner
	var banner := Label3D.new()
	banner.text = "~ MEAT PARTY ~"
	banner.font_size = 96
	banner.pixel_size = 0.012
	banner.modulate = Color("f0c020")
	banner.outline_modulate = Color("801030")
	banner.outline_size = 16
	banner.position = Vector3(-5.5, 4.0, -HALF.y + 0.2)
	add_child(banner)
	# the snack table nobody eats from
	var st := LcMB.new()
	var cloth := LcMB.mat(LcTex.checker(Color("f0f0f0"), Color("e8402a"), 16, 4, 9, 0.1))
	st.box("c", cloth, Vector3(3.0, 0.9, 0.9), LcMB.T(Vector3(-7.5, 0.45, -7.1)), Color(1, 1, 1))
	for i in 5:
		st.cyl("p", LcMB.mat(LcTex.solid(Color("f0e8d8"))), 0.16, 0.18, 0.04, 8, LcMB.T(Vector3(-8.7 + i * 0.6, 0.9, -7.1)), Color(1, 1, 1))
		st.sphere("m", LcMB.mat(LcTex.grime(Color("8a2a2a"), Color("c86a5a"), 16, 50 + i, 0.3)), 0.1, 3, 6, LcMB.T(Vector3(-8.7 + i * 0.6, 0.97, -7.1)), Color(1, 1, 1))
	_add(st)


func _pulpit() -> void:
	var mb := LcMB.new()
	var brass := LcMB.mat(LcTex.brass())
	var red := LcMB.mat(LcTex.grime(Color("801828"), Color("a82838"), 16, 61, 0.3))
	mb.cyl("r", red, 1.3, 1.25, 0.35, 10, LcMB.T(PULPIT), Color(1, 1, 1))
	mb.cyl("b", brass, 1.32, 1.32, 0.05, 10, LcMB.T(PULPIT + Vector3(0, 0.35, 0)), Color(1, 1, 1))
	# a row of light bulbs round the edge
	for i in 14:
		var a := TAU * i / 14
		mb.sphere("l", LcMB.mat(LcTex.solid(Color("fff0a0")), Color("fff0a0"), Vector2.ONE, true), 0.05, 2, 4,
			LcMB.T(PULPIT + Vector3(cos(a) * 1.28, 0.25, sin(a) * 1.28)), Color(1, 1, 1))
	_add(mb)


func caller_spot() -> Vector3:
	return PULPIT + Vector3(0, 0.38, 0)


func _board() -> void:
	for i in board.size():
		var sp: Dictionary = board[i]
		var t := Node3D.new()
		t.position = space_pos(i)
		add_child(t)
		var mb := LcMB.new()
		var c: Color = TILE_COLORS.get(sp.type, Color.GRAY)
		var top := LcMB.mat(LcTex.flagstone(c, i + 3, 16, 0.0))
		mb.cyl("t", top, 0.62, 0.6, 0.08, 8, LcMB.T(Vector3(0, 0.0, 0)), Color(1, 1, 1))
		mb.cyl("e", LcMB.mat(LcTex.solid(c.darkened(0.5))), 0.66, 0.66, 0.04, 8, LcMB.T(Vector3(0, -0.01, 0)), Color(1, 1, 1))
		_add(mb, t)
		var g: String = TILE_GLYPH.get(sp.type, "")
		if g != "":
			var l := Label3D.new()
			l.text = g
			l.font_size = 64
			l.pixel_size = 0.008
			l.rotation.x = -PI / 2
			l.position.y = 0.09
			l.modulate = c.darkened(0.6) if sp.type in ["medic", "tickets"] else Color.WHITE
			t.add_child(l)
		if sp.type == "clue" or sp.type == "note":
			# a scrap of torn wallpaper on the floor, scrawled on
			var s := LcMB.new()
			s.box("s", LcMB.mat(LcTex.paper(Color("e8dcc0"), i, 16)), Vector3(0.36, 0.01, 0.26), LcMB.T(Vector3(0.05, 0.09, 0.0), Vector3(0, 0.4, 0)), Color(1, 1, 1))
			s.box("s", LcMB.mat(LcTex.solid(Color("301810"))), Vector3(0.2, 0.012, 0.02), LcMB.T(Vector3(0.05, 0.095, -0.02), Vector3(0, 0.4, 0)), Color(1, 1, 1))
			_add(s, t)
		tiles.append(t)
	# the key, when one is dropped
	key_marker = Node3D.new()
	var km := LcMB.new()
	km.ring("k", LcMB.mat(LcTex.brass()), 0.1, 0.03, 8, LcMB.T(Vector3(0, 0, 0), Vector3(PI / 2, 0, 0)), Color(1, 1, 1))
	km.box("k", LcMB.mat(LcTex.brass()), Vector3(0.04, 0.04, 0.3), LcMB.T(Vector3(0, 0, 0.22)), Color(1, 1, 1))
	_add(km, key_marker)
	key_marker.visible = false
	add_child(key_marker)


func space_pos(i: int) -> Vector3:
	var p: Array = board[posmod(i, board.size())].pos
	return Vector3(float(p[0]), 0.1, float(p[1]))


## Where seat `s` stands on space i (four can share a tile).
func stand_pos(i: int, s: int) -> Vector3:
	var o: Vector2 = [Vector2(-0.28, -0.22), Vector2(0.28, -0.22), Vector2(-0.28, 0.24), Vector2(0.28, 0.24)][s % 4]
	return space_pos(i) + Vector3(o.x, 0.0, o.y)


func show_key(space: int) -> void:
	key_marker.visible = space >= 0
	if space >= 0:
		key_marker.position = space_pos(space) + Vector3(0, 0.3, 0)


func open_door() -> void:
	var tw := create_tween()
	tw.tween_property(door_node, "rotation:y", -1.7, 2.5).set_trans(Tween.TRANS_QUAD)
	# daylight behind it
	var mb := LcMB.new()
	mb.box("d", LcMB.mat(LcTex.solid(Color("fffbe8")), Color("fffbe8"), Vector2.ONE, true), Vector3(1.6, 2.8, 0.02), LcMB.T(DOOR + Vector3(0, 1.4, -0.02)), Color(1, 1, 1))
	_add(mb)
	Lamp.create(self, DOOR + Vector3(0, 1.5, 1.0), Color(1, 1, 0.9), 1.5, 8.0)


func _process(_delta: float) -> void:
	if key_marker and key_marker.visible:
		key_marker.rotation.y += _delta * 2.0
