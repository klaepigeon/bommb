class_name HallStations
extends RefCounted
## The rest of the hall, for walking around in: reception, the prize counter, the stage with
## the old cage and the number board, the mask rack, the notice board, the trophy cabinet.
## Each interactable is an entry in Hall.stations: {id, name, pos (Vector3), cam, look, node}.

static func build(h: Hall) -> void:
	h.stations.clear()
	var wood := MB.mat(Tex.wood(Color("4a2e1c"), 51, 64, 4))
	var wood_l := MB.mat(Tex.wood(Color("6a4a2e"), 52, 64, 4))
	var paper := MB.mat(Tex.paper(Color("e0d4b0"), 53))
	var red := MB.mat(Tex.grime(Color("7a1a14"), Color("9a2a1e"), 32, 54, 0.2))
	var brass := MB.mat(Tex.brass())
	var dark := MB.mat(Tex.grime(Color("141010"), Color("2a2420"), 16, 55, 0.3))
	var glass := MB.mat(Tex.grime(Color("6a7a7a"), Color("8a9a98"), 16, 56, 0.3))
	var font: Font = load("res://assets/fonts/fell_sc.ttf")

	# --- reception desk, front left, with its red sign
	var rx := -5.2
	var rz := 5.2
	var mb := MB.new()
	mb.box("w", wood, Vector3(3.0, 1.05, 0.7), MB.T(Vector3(rx, 0.525, rz)), Color(1, 1, 1), 1.0)
	mb.box("w", wood_l, Vector3(3.1, 0.06, 0.8), MB.T(Vector3(rx, 1.08, rz)), Color(1, 1, 1), 1.0)
	mb.box("r", red, Vector3(1.6, 0.26, 0.02), MB.T(Vector3(rx, 0.55, rz - 0.36), Vector3(0, PI, 0.05)), Color(1, 1, 1))
	# ledger, a mug, the bell
	mb.box("p", paper, Vector3(0.5, 0.04, 0.34), MB.T(Vector3(rx + 0.7, 1.13, rz - 0.05), Vector3(0, 0.2, 0)), Color(1, 1, 1))
	mb.cyl("c", MB.mat(Tex.grime(Color("c8a050"), Color("e8c060"), 16, 57, 0.3)), 0.05, 0.05, 0.12, 6, MB.T(Vector3(rx - 0.8, 1.11, rz)), Color(1, 1, 1))
	_mi(h, mb.build())
	_sign(h, font, "RECEPTION", Vector3(rx, 0.56, rz - 0.38), PI, Color("c8a888"), 40)
	h.stations.append({"id": "reception", "name": "Reception", "pos": Vector3(rx, 1.1, rz), "cam": Vector3(rx, 1.55, rz - 1.9), "look": Vector3(rx, 1.5, rz), "caller_at": Vector3(rx, 0.2, rz + 0.75), "caller_rot": PI, "persona": "receptionist"})
	h.stations.append({"id": "ledger", "name": "The ledger", "pos": Vector3(rx + 0.7, 1.13, rz), "cam": Vector3(rx + 0.6, 1.6, rz - 0.9), "look": Vector3(rx + 0.7, 1.1, rz)})

	# --- prize counter, front right: a glass case and shelves of prizes
	var px := 5.2
	var pz := 5.2
	mb = MB.new()
	mb.box("w", wood, Vector3(3.0, 0.95, 0.7), MB.T(Vector3(px, 0.475, pz)), Color(1, 1, 1), 1.0)
	mb.box("g", glass, Vector3(2.9, 0.04, 0.68), MB.T(Vector3(px, 0.97, pz)), Color(1, 1, 1))
	mb.box("w", wood_l, Vector3(3.2, 0.06, 0.4), MB.T(Vector3(px, 1.9, pz + 0.95)), Color(1, 1, 1))
	mb.box("w", wood_l, Vector3(3.2, 0.06, 0.4), MB.T(Vector3(px, 2.4, pz + 0.95)), Color(1, 1, 1))
	var rr := RandomNumberGenerator.new()
	rr.seed = 9
	for i in range(14):
		var shelf := 1.93 if i < 7 else 2.43
		var cols := [Color("c83a2a"), Color("2a6aa8"), Color("e8c060"), Color("6a2a8a"), Color("2a8a4a")]
		var c: Color = cols[i % cols.size()]
		if i % 3 == 0:
			mb.sphere("t", MB.mat(Tex.solid(c)), 0.12, 3, 6, MB.T(Vector3(px - 1.3 + (i % 7) * 0.42, shelf + 0.13, pz + 0.95)), Color(1, 1, 1))
		else:
			mb.box("t", MB.mat(Tex.solid(c)), Vector3(0.22, rr.randf_range(0.18, 0.36), 0.2), MB.T(Vector3(px - 1.3 + (i % 7) * 0.42, shelf + 0.15, pz + 0.95)), Color(1, 1, 1))
	# the cassette on the counter
	mb.box("d", dark, Vector3(0.16, 0.03, 0.1), MB.T(Vector3(px - 0.9, 1.0, pz - 0.1)), Color(1, 1, 1))
	_mi(h, mb.build())
	_sign(h, font, "PRIZES", Vector3(px, 2.85, pz + 1.0), PI, Color("e8c060"), 44)
	h.stations.append({"id": "prize_counter", "name": "Prize counter", "pos": Vector3(px, 1.0, pz), "cam": Vector3(px, 1.6, pz - 1.9), "look": Vector3(px, 1.6, pz + 0.6), "caller_at": Vector3(px, 0.1, pz + 0.6), "caller_rot": PI, "persona": "prize_clerk"})
	h.stations.append({"id": "cassette", "name": "A cassette", "pos": Vector3(px - 0.9, 1.0, pz - 0.1), "cam": Vector3(px - 0.9, 1.5, pz - 0.9), "look": Vector3(px - 0.9, 1.0, pz - 0.1), "needs": "caller_tape"})

	# --- the stage: red curtains, the original cage on its stand, the number board
	var sz := -7.4
	mb = MB.new()
	var curtain := MB.mat(Tex.cached("curtain", func():
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in range(32):
			for x in range(32):
				var f = 0.55 + 0.45 * abs(sin(x * 0.55))
				img.set_pixel(x, y, Color("6a1410") * f + Color(0, 0, 0, 1) * (1 - f) * 0.0)
		return img))
	mb.box("c", curtain, Vector3(7.0, 3.0, 0.1), MB.T(Vector3(0, 1.8, sz)), Color(1, 1, 1), 0.5)
	mb.box("c", MB.mat(Tex.grime(Color("6a4a1a"), Color("a8802a"), 16, 58, 0.4)), Vector3(7.0, 0.25, 0.14), MB.T(Vector3(0, 3.25, sz + 0.02)), Color(1, 1, 1))
	# cage stand
	mb.box("b", brass, Vector3(0.05, 0.9, 0.05), MB.T(Vector3(-0.45, 0.75, -6.4), Vector3(0, 0, 0.15)), Color(1, 1, 1))
	mb.box("b", brass, Vector3(0.05, 0.9, 0.05), MB.T(Vector3(0.45, 0.75, -6.4), Vector3(0, 0, -0.15)), Color(1, 1, 1))
	for i in range(4):
		mb.ring("b", brass, 0.42, 0.018, 16, MB.T(Vector3(0, 1.45, -6.4), Vector3(PI / 2, 0, PI * i / 4.0)), Color(1, 1, 1))
	mb.box("b", brass, Vector3(1.0, 0.03, 0.03), MB.T(Vector3(0, 1.45, -6.4)), Color(1, 1, 1))
	# number board: B I N G O rows of dim numbers
	mb.box("d", dark, Vector3(2.4, 1.0, 0.06), MB.T(Vector3(2.6, 2.4, sz + 0.12)), Color(1, 1, 1))
	_mi(h, mb.build())
	var board_lbl := Label3D.new()
	board_lbl.font = font
	board_lbl.font_size = 16
	board_lbl.pixel_size = 0.0045
	board_lbl.text = "B 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15\nI 16 17 18 19 20 21 22 23 24 25 26 27\nN 31 32 33 34 35 36 37 38 39 40 41 42\nG 46 47 48 49 50 51 52 53 54 55 56 57\nO 61 62 63 64 65 66 67 68 69 70 71 72"
	board_lbl.modulate = Color("5a4a30")
	board_lbl.position = Vector3(2.6, 2.4, sz + 0.16)
	board_lbl.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	board_lbl.shaded = false
	h.add_child(board_lbl)
	h.stations.append({"id": "stage_cage", "name": "The old cage", "pos": Vector3(0, 1.45, -6.4), "cam": Vector3(0, 1.7, -3.9), "look": Vector3(0, 1.3, -6.4)})
	h.stations.append({"id": "number_board", "name": "The number board", "pos": Vector3(2.6, 2.4, sz), "cam": Vector3(2.3, 1.9, -4.4), "look": Vector3(2.6, 2.3, sz)})

	# --- the mask rack on the left wall: one peg empty for every face he is wearing
	var mx := -7.4
	var mz := 2.4
	mb = MB.new()
	mb.box("w", wood, Vector3(0.06, 0.1, 2.0), MB.T(Vector3(mx + 0.05, 2.0, mz)), Color(1, 1, 1))
	_mi(h, mb.build())
	var personas := ["receptionist", "auctioneer", "prize_clerk", "nurse", "drowned_king", "deacon", "foreman", "understudy"]
	for i in range(personas.size()):
		var pd := Content.db.get_def("personas", personas[i])
		var mq := MB.new()
		var tex := CallerFigure.mask_tex(pd)
		mq.quad("m", MB.mat(tex), Vector3(0, -0.2, -0.17), Vector3(0, -0.2, 0.17), Vector3(0, 0.2, 0.17), Vector3(0, 0.2, -0.17), Color(1, 1, 1))
		var mi := _mi(h, mq.build())
		mi.position = Vector3(mx + 0.12, 1.75 + (i % 2) * 0.05, mz - 0.9 + i * 0.26)
		mi.rotation = Vector3(0, 0, 0.05 * (i % 3 - 1))
	h.stations.append({"id": "masks", "name": "The mask rack", "pos": Vector3(mx, 1.8, mz), "cam": Vector3(mx + 2.2, 1.6, mz), "look": Vector3(mx, 1.75, mz)})

	# --- notice board, left wall further back
	mb = MB.new()
	mb.box("w", MB.mat(Tex.grime(Color("6a4a2a"), Color("8a6a3a"), 16, 59, 0.3)), Vector3(0.05, 1.0, 1.6), MB.T(Vector3(-7.45, 1.7, -2.0)), Color(1, 1, 1))
	for i in range(4):
		mb.box("p", paper, Vector3(0.02, 0.32, 0.26), MB.T(Vector3(-7.41, 1.5 + (i % 2) * 0.42, -2.5 + i * 0.32), Vector3(0.08 * (i - 1), 0, 0)), Color(1, 1, 1))
	_mi(h, mb.build())
	h.stations.append({"id": "notices", "name": "The notice board", "pos": Vector3(-7.4, 1.7, -2.0), "cam": Vector3(-5.4, 1.6, -2.0), "look": Vector3(-7.4, 1.7, -2.0)})

	# --- trophy cabinet, right wall
	mb = MB.new()
	mb.box("w", wood, Vector3(0.6, 2.2, 1.6), MB.T(Vector3(7.15, 1.1, -0.5)), Color(1, 1, 1), 1.0)
	mb.box("g", glass, Vector3(0.02, 1.7, 1.4), MB.T(Vector3(6.84, 1.2, -0.5)), Color(1, 1, 1))
	for i in range(3):
		mb.cyl("b", brass, 0.07, 0.12, 0.3, 6, MB.T(Vector3(7.1, 0.7 + i * 0.55, -0.9 + i * 0.4)), Color(1, 1, 1))
	_mi(h, mb.build())
	h.stations.append({"id": "cabinet", "name": "The trophy cabinet", "pos": Vector3(7.0, 1.2, -0.5), "cam": Vector3(5.0, 1.6, -0.5), "look": Vector3(7.0, 1.3, -0.5)})

	# --- the clock and the exit door (already in the room) become things to look at
	h.stations.append({"id": "clock", "name": "The clock", "pos": Vector3(5.0, 2.6, Hall.ROOM_BACK), "cam": Vector3(4.6, 1.8, Hall.ROOM_BACK + 3.0), "look": Vector3(5.0, 2.5, Hall.ROOM_BACK)})
	_lamp(h, Vector3(rx, 2.6, rz - 0.6), Color("e8d8b0"), 1.6)
	_lamp(h, Vector3(px, 2.6, pz - 0.6), Color("f0e0b0"), 1.6)
	_lamp(h, Vector3(0, 2.8, -5.5), Color("e86a4a"), 1.4)
	_lamp(h, Vector3(-6.0, 2.4, 0.5), Color("c8c8a0"), 1.0)
	_lamp(h, Vector3(6.0, 2.4, -0.5), Color("c8c8a0"), 1.0)
	h.stations.append({"id": "table", "name": "The table", "pos": Vector3(0, Hall.TABLE_Y, 0), "cam": Vector3(0, 1.6, 1.72), "look": Vector3(0, 0.74, -0.12)})

static func _lamp(h: Node3D, at: Vector3, col: Color, energy: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = 4.0
	l.position = at
	h.add_child(l)

static func _mi(h: Node3D, m: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	h.add_child(mi)
	return mi

static func _sign(h: Node3D, font: Font, text: String, pos: Vector3, rot_y: float, col: Color, size: int) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = col
	l.position = pos
	l.rotation.y = rot_y
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.double_sided = false
	h.add_child(l)
