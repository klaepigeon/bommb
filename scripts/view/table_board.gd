class_name TableBoard
extends Node3D
## The game board on the Caller's table, in puppet units (the node it's built under is
## scaled down to the table). LAST CALL 3: a drawing of a place, like a children's board
## game: a road of coloured squares winding through a sweet little land made of meat
## (BoardArt), and beside the road, numbered, the drawings of a story that's always a bad
## one (assets/data/board_stories.json, picked by the match). At the top, where the road
## passes nearest him, a little wooden door in a frame, with three brass dials. He says
## it's painted on.

const SIZE := Vector2(21.0, 14.4)
const DOOR := Vector3(0, 0, -6.4)

const INK_RED := Color("8a1a12")
const RING := {"start": Color("2a6a3a"), "tickets": Color("b08a2a"), "item": Color("2a4a8a"), "hazard": Color("8a1a12"),
	"note": Color("6a5a4a"), "clue": Color("6a5a4a"), "caller": Color("5a2a6a"), "steal": Color("a05a1a"),
	"medic": Color("8a1a12"), "door": Color("3a2416")}
const GLYPH := {"start": "GO", "tickets": "$", "item": "?", "hazard": "!", "caller": "C", "steal": "&", "medic": "+"}

var board: Array = []
var path: Array[Vector2] = []    # each space's (x, z) on the sheet
var story: Dictionary = {}
var art_seed := 1
var tiles: Array[Node3D] = []
var door_node: Node3D
var key_marker: Node3D
var _fell: Font


## The road: a closed loop that winds (the rules walk it in order and wrap round), from
## the start nearest you, up the right, across the top past the door, and back down the left.
const ROAD := [Vector2(0, 5.6), Vector2(4.2, 5.0), Vector2(8.6, 5.7), Vector2(9.1, 2.6), Vector2(5.4, 1.4),
	Vector2(5.8, -1.6), Vector2(9.1, -3.0), Vector2(7.6, -5.9), Vector2(3.2, -5.0), Vector2(0, -6.0),
	Vector2(-3.2, -5.0), Vector2(-7.6, -5.9), Vector2(-9.1, -3.0), Vector2(-5.8, -1.6), Vector2(-5.4, 1.4),
	Vector2(-9.1, 2.6), Vector2(-8.6, 5.7), Vector2(-4.2, 5.0)]


func build(spaces: Array, match_seed: int = 1) -> void:
	board = spaces
	art_seed = match_seed
	_fell = load("res://assets/fonts/fell_sc.ttf")
	path = _road(spaces.size())
	var stories: Array = Assets.load_json("res://assets/data/board_stories.json").get("stories", [])
	if not stories.is_empty():
		story = stories[posmod(match_seed, stories.size())]
	_sheet()
	_tiles()
	_door()
	_your_candle()
	key_marker = Node3D.new()
	var km := LcMB.new()
	km.ring("k", LcMB.mat(LcTex.brass()), 0.12, 0.035, 8, LcMB.T(Vector3.ZERO, Vector3(PI / 2, 0, 0)), Color(1, 1, 1))
	km.box("k", LcMB.mat(LcTex.brass()), Vector3(0.05, 0.05, 0.34), LcMB.T(Vector3(0, 0, 0.25)), Color(1, 1, 1))
	_mesh(km, key_marker)
	key_marker.visible = false
	add_child(key_marker)


func _mesh(mb: LcMB, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	parent.add_child(mi)
	return mi


func _label(text: String, at: Vector3, size: int, col: Color, flat := true, parent: Node3D = self) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = _fell
	l.font_size = size
	l.pixel_size = 0.01
	l.modulate = col
	l.outline_size = 0
	l.position = at
	if flat:
		l.rotation.x = -PI / 2
	l.double_sided = false
	parent.add_child(l)
	return l


## Catmull-Rom round the ROAD's points, then spaced evenly by length into n spaces.
func _road(n: int) -> Array[Vector2]:
	var dense: Array[Vector2] = []
	var m := ROAD.size()
	for i in m:
		var p0: Vector2 = ROAD[(i - 1 + m) % m]
		var p1: Vector2 = ROAD[i]
		var p2: Vector2 = ROAD[(i + 1) % m]
		var p3: Vector2 = ROAD[(i + 2) % m]
		for k in 20:
			var t := k / 20.0
			var t2 := t * t
			var t3 := t2 * t
			dense.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	var total := 0.0
	for i in dense.size():
		total += dense[i].distance_to(dense[(i + 1) % dense.size()])
	var out: Array[Vector2] = []
	var step := total / n
	var want := 0.0
	var acc := 0.0
	for i in dense.size():
		var a := dense[i]
		var b := dense[(i + 1) % dense.size()]
		var d := a.distance_to(b)
		while want <= acc + d and out.size() < n:
			out.append(a.lerp(b, (want - acc) / maxf(d, 0.0001)))
			want += step
		acc += d
	return out


func _sheet() -> void:
	var art := BoardArt.new(SIZE, art_seed)
	var beat_spaces := []
	for k in 8:
		beat_spaces.append(1 + k * 3)
	var captions := art.paint(story, path, beat_spaces)
	var mb := LcMB.new()
	var paper := LcMB.mat(art.texture(), Color(0.78, 0.72, 0.66))
	mb.box("p", paper, Vector3(SIZE.x, 0.1, SIZE.y), LcMB.T(Vector3(0, -0.04, 0)), Color(1, 1, 1))
	_mesh(mb)
	for cap in captions:
		var l := _label(str(cap.text), Vector3(cap.at.x, 0.03, cap.at.y), 44, Color("3a0a08"))
		l.font = load("res://assets/fonts/fell_italic.ttf")
		l.width = 320.0
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.pixel_size = 0.011
	# the story's title, in his hand, over the middle of the land
	var t := _label(str(story.get("title", "")), Vector3(0, 0.03, -0.2), 96, INK_RED)
	t.pixel_size = 0.011
	var sub := _label("a game for four, and him", Vector3(0, 0.03, 0.9), 48, Color("3a1a10"))
	sub.font = load("res://assets/fonts/fell_italic.ttf")


const SQUARE := {"start": Color("2a8a4a"), "tickets": Color("e0a820"), "item": Color("3a6ac8"), "hazard": Color("c82a2a"),
	"note": Color("a07a5a"), "clue": Color("8a6ac0"), "caller": Color("7a2a8a"), "steal": Color("e07020"),
	"medic": Color("e8e0d8"), "door": Color("5a3a24")}


func _tiles() -> void:
	for i in board.size():
		var sp: Dictionary = board[i]
		var t := Node3D.new()
		t.position = space_pos(i)
		var d := path[(i + 1) % path.size()] - path[(i - 1 + path.size()) % path.size()]
		t.rotation.y = atan2(d.x, d.y)
		add_child(t)
		var col: Color = SQUARE.get(sp.type, Color("8a7a6a"))
		var mb := LcMB.new()
		# a card square, a little proud of the drawing, inked round the edge
		mb.box("e", LcMB.mat(LcTex.solid(Color("2a0e0a"))), Vector3(1.0, 0.05, 0.86), LcMB.T(Vector3(0, -0.04, 0)), Color(1, 1, 1))
		mb.box("t", LcMB.mat(LcTex.grime(col.darkened(0.12), col.lightened(0.08), 16, 40 + i, 0.4)), Vector3(0.9, 0.06, 0.76), LcMB.T(Vector3(0, -0.02, 0)), Color(1, 1, 1))
		_mesh(mb, t)
		if GLYPH.has(sp.type):
			var g := _label(GLYPH[sp.type], Vector3(0, 0.02, 0.0), 80, Color("f8f0e0") if sp.type != "medic" else INK_RED, true, t)
			g.outline_size = 10
			g.outline_modulate = Color("2a0e0a")
		if sp.type in ["clue", "note"]:
			# a scrap of wallpaper on the square, something written on it
			var s2 := LcMB.new()
			s2.box("s", LcMB.mat(LcTex.paper(Color("e0d0a8"), i, 16)), Vector3(0.5, 0.01, 0.34), LcMB.T(Vector3(0.0, 0.015, 0.0), Vector3(0, 0.4, 0)), Color(1, 1, 1))
			for k in 3:
				s2.box("w", LcMB.mat(LcTex.solid(Color("3a1810"))), Vector3(0.3 - k * 0.06, 0.012, 0.025), LcMB.T(Vector3(-0.02, 0.025, -0.08 + k * 0.08), Vector3(0, 0.4, 0)), Color(1, 1, 1))
			_mesh(s2, t)
		tiles.append(t)


func _door() -> void:
	var di := -1
	for i in board.size():
		if board[i].type == "door":
			di = i
	var at := DOOR if di < 0 else space_pos(di) + Vector3(0, 0, -1.0)
	var frame := LcMB.new()
	var dark := LcMB.mat(LcTex.wood(Color("2a1810"), 12, 16, 1))
	frame.box("f", dark, Vector3(0.14, 2.2, 0.16), LcMB.T(at + Vector3(-0.66, 1.1, 0)), Color(1, 1, 1))
	frame.box("f", dark, Vector3(0.14, 2.2, 0.16), LcMB.T(at + Vector3(0.66, 1.1, 0)), Color(1, 1, 1))
	frame.box("f", dark, Vector3(1.46, 0.14, 0.16), LcMB.T(at + Vector3(0, 2.2, 0)), Color(1, 1, 1))
	frame.box("f", LcMB.mat(LcTex.solid(Color("0a0604"))), Vector3(1.2, 2.1, 0.02), LcMB.T(at + Vector3(0, 1.05, -0.06)), Color(1, 1, 1))
	_mesh(frame)
	door_node = Node3D.new()
	door_node.position = at + Vector3(-0.6, 0, 0.02)
	add_child(door_node)
	var d := LcMB.new()
	d.box("w", LcMB.mat(LcTex.wood(Color("6a3a20"), 11, 32, 2)), Vector3(1.2, 2.06, 0.06), LcMB.T(Vector3(0.6, 1.03, 0)), Color(1, 1, 1))
	for k in 3:
		d.cyl("k", LcMB.mat(LcTex.brass()), 0.07, 0.07, 0.04, 8, LcMB.T(Vector3(0.38 + k * 0.2, 1.3, 0.04), Vector3(PI / 2, 0, 0)), Color(1, 1, 1))
	d.box("k", LcMB.mat(LcTex.brass()), Vector3(0.1, 0.1, 0.06), LcMB.T(Vector3(1.0, 1.0, 0.05)), Color(1, 1, 1))
	_mesh(d, door_node)
	var exit_l := _label("EXIT", at + Vector3(0, 2.5, 0.0), 64, Color("2a8a3a"), false)
	exit_l.billboard = BaseMaterial3D.BILLBOARD_DISABLED


## Your side of the table has a candle too, so you can see their faces.
func _your_candle() -> void:
	var at := Vector3(SIZE.x * 0.5 + 1.2, 0, SIZE.y * 0.5 + 0.6)
	var mb := LcMB.new()
	mb.cyl("w", LcMB.mat(LcTex.solid(Color("e8e0c8"))), 0.35, 0.3, 2.6, 8, LcMB.T(at), Color(1, 1, 1))
	mb.cyl("d", LcMB.mat(LcTex.solid(Color("c8b890"))), 0.6, 0.6, 0.12, 8, LcMB.T(at), Color(1, 1, 1))
	_mesh(mb)
	var flame := LcMB.new()
	flame.sphere("f", LcMB.mat(LcTex.solid(Color("ffd070")), Color("ffd070"), Vector2.ONE, true), 0.16, 3, 6, LcMB.T(at + Vector3(0, 2.85, 0)), Color(1, 1, 1), Vector3(1, 1.8, 1))
	_mesh(flame)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.72, 0.42)
	l.light_energy = 1.6
	l.position = at + Vector3(-2.0, 6.0, 2.0)
	l.omni_attenuation = 1.2
	add_child(l)
	_candle_light = l
	l.omni_range = 2.2


var _candle_light: OmniLight3D


func space_pos(i: int) -> Vector3:
	var p: Vector2 = path[posmod(i, path.size())]
	return Vector3(p.x, 0.05, p.y)


## Where seat `s`'s doll stands on space i (four can share a space).
func stand_pos(i: int, s: int) -> Vector3:
	var o: Vector2 = [Vector2(-0.3, -0.24), Vector2(0.3, -0.24), Vector2(-0.3, 0.26), Vector2(0.3, 0.26)][s % 4]
	return space_pos(i) + Vector3(o.x, 0.05, o.y)


func show_key(space: int) -> void:
	key_marker.visible = space >= 0
	if space >= 0:
		key_marker.position = space_pos(space) + Vector3(0, 0.3, 0)


func open_door() -> void:
	var tw := create_tween()
	tw.tween_property(door_node, "rotation:y", -1.8, 2.5).set_trans(Tween.TRANS_QUAD)
	# daylight on the other side of it
	var mb := LcMB.new()
	mb.box("d", LcMB.mat(LcTex.solid(Color("fffbe8")), Color("fffbe8"), Vector2.ONE, true), Vector3(1.2, 2.06, 0.02), LcMB.T(door_node.position + Vector3(0.6, 1.03, -0.07)), Color(1, 1, 1))
	_mesh(mb)
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.96, 0.85)
	l.light_energy = 3.0
	l.omni_range = 4.0 * global_transform.basis.get_scale().x
	l.position = door_node.position + Vector3(0.6, 1.2, 0.8)
	add_child(l)


func _process(delta: float) -> void:
	if _candle_light:
		_candle_light.light_energy = 1.6 + sin(Time.get_ticks_msec() * 0.011) * 0.08 + randf() * 0.06
	if key_marker and key_marker.visible:
		key_marker.rotation.y += delta * 2.0
