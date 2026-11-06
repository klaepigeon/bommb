class_name TableBoard
extends Node3D
## The game board on the Caller's table, in doll units (the node it's built under is
## scaled down to the table). A sheet of his card stock with the loop of spaces inked on
## it, a line of dots between them, scraps of wallpaper where the clues are, and at the
## top, where the loop passes nearest him, a little wooden door in a frame, with three
## brass dials. He says it's painted on.

const SIZE := Vector2(21.0, 14.4)
const DOOR := Vector3(0, 0, -6.4)

const INK_RED := Color("8a1a12")
const RING := {"start": Color("2a6a3a"), "tickets": Color("b08a2a"), "item": Color("2a4a8a"), "hazard": Color("8a1a12"),
	"note": Color("6a5a4a"), "clue": Color("6a5a4a"), "caller": Color("5a2a6a"), "steal": Color("a05a1a"),
	"medic": Color("8a1a12"), "door": Color("3a2416")}
const GLYPH := {"start": "GO", "tickets": "$", "item": "?", "hazard": "!", "caller": "C", "steal": "&", "medic": "+"}

var board: Array = []
var tiles: Array[Node3D] = []
var door_node: Node3D
var key_marker: Node3D
var _fell: Font


func build(spaces: Array) -> void:
	board = spaces
	_fell = load("res://assets/fonts/fell_sc.ttf")
	_sheet()
	_path()
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


func _sheet() -> void:
	var mb := LcMB.new()
	var paper := LcMB.mat(load("res://assets/ink/paper/map.png"), Color(0.6, 0.53, 0.43))
	mb.box("p", paper, Vector3(SIZE.x, 0.1, SIZE.y), LcMB.T(Vector3(0, -0.04, 0)), Color(1, 1, 1))
	_mesh(mb)
	_label("MEAT  PARTY", Vector3(-1.6, 0.03, 1.3), 140, INK_RED)
	_label("a game for four, and him", Vector3(-1.6, 0.03, 2.4), 64, Color("4a2a1a"))


func _path() -> void:
	var mb := LcMB.new()
	var dot := LcMB.mat(LcTex.solid(Color("5a1a10")))
	for i in board.size():
		var a := space_pos(i)
		var b := space_pos(i + 1)
		for k in range(1, 4):
			var p := a.lerp(b, k / 4.0)
			mb.cyl("d", dot, 0.07, 0.07, 0.02, 6, LcMB.T(Vector3(p.x, 0.01, p.z)), Color(1, 1, 1))
	_mesh(mb)


func _tiles() -> void:
	for i in board.size():
		var sp: Dictionary = board[i]
		var t := Node3D.new()
		t.position = space_pos(i)
		add_child(t)
		var ring: Color = RING.get(sp.type, Color("4a3a2a"))
		var mb := LcMB.new()
		mb.cyl("e", LcMB.mat(LcTex.solid(ring)), 0.66, 0.66, 0.04, 10, LcMB.T(Vector3(0, -0.06, 0)), Color(1, 1, 1))
		mb.cyl("t", LcMB.mat(LcTex.paper(Color("b8aa88"), i + 3, 32)), 0.58, 0.56, 0.06, 10, LcMB.T(Vector3(0, -0.05, 0)), Color(1, 1, 1))
		_mesh(mb, t)
		if GLYPH.has(sp.type):
			_label(GLYPH[sp.type], Vector3(0, 0.02, 0.05), 96, ring.darkened(0.2), true, t)
		if sp.type in ["clue", "note"]:
			# a scrap of wallpaper with something written on it
			var s := LcMB.new()
			s.box("s", LcMB.mat(LcTex.paper(Color("d8c8a0"), i, 16)), Vector3(0.5, 0.01, 0.36), LcMB.T(Vector3(0.0, 0.02, 0.0), Vector3(0, 0.4, 0)), Color(1, 1, 1))
			for k in 3:
				s.box("w", LcMB.mat(LcTex.solid(Color("3a1810"))), Vector3(0.3 - k * 0.06, 0.012, 0.025), LcMB.T(Vector3(-0.02, 0.03, -0.08 + k * 0.08), Vector3(0, 0.4, 0)), Color(1, 1, 1))
			_mesh(s, t)
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
	var p: Array = board[posmod(i, board.size())].pos
	return Vector3(float(p[0]), 0.05, float(p[1]))


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
