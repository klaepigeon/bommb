class_name Hall
extends Node3D
## The bingo hall: checkered floor, sickly green walls, rows of empty chairs and tables that
## go on a little too far, a scoreboard behind the Caller, hanging lamps, and the game table
## with its candles, book, chips, deck box, dice tray and the PASS box.

const TABLE_Y := 0.78
const TABLE_W := 2.9
const TABLE_D := 2.3
const ROOM_W := 15.0
const ROOM_FRONT := 7.0
const ROOM_BACK := -10.0
const ROOM_H := 3.6

var caller: CallerFigure
var board_root: Node3D       # tactical board, map and event cards are placed under this
var props: Dictionary = {}   # name -> Node3D (pickable props)
var flashboard: Flashboard
var candle_lights: Array = []
var stations: Array = []
var building: Building
var wrong_chair_at := Vector3(-1.1, 0, -3.4)
var world: WorldView
var lamp_light: SpotLight3D
var t := 0.0
var font: Font

func _ready() -> void:
	font = load("res://assets/fonts/fell_sc.ttf")
	build()

func build() -> void:
	building = Building.new(Content.db)
	_room()
	_furniture()
	_table()
	_scoreboard()
	_lights()
	HallStations.build(self)
	ShellBuilder.split_big(self, 3.0)
	world = WorldView.new()
	world.name = "World"
	add_child(world)
	world.setup(self, building)
	caller = CallerFigure.new()
	caller.name = "Caller"
	caller.position = Vector3(0, 0.0, -1.75)
	add_child(caller)
	board_root = Node3D.new()
	board_root.name = "BoardRoot"
	board_root.position = Vector3(0, TABLE_Y + 0.005, -0.05)
	add_child(board_root)

func _mi(m: Mesh, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	parent.add_child(mi)
	return mi

func _room() -> void:
	var mb := MB.new()
	var floor_m := MB.mat(Tex.checker(Color("1e1a18"), Color("4a3a30"), 64, 4, 2, 0.35), Color.WHITE, Vector2.ONE)
	var w := ROOM_W
	var d := ROOM_FRONT - ROOM_BACK
	var wall_m := MB.mat(Tex.wall_panel(), Color.WHITE)
	var hgt := ROOM_H
	var ceil_m := MB.mat(Tex.ceiling(), Color.WHITE)
	# The floor, ceiling and walls are cut into pieces a few metres across: the renderer only
	# lights each object with a handful of lamps, so one huge floor would have lamps popping
	# on and off as you move. Small pieces each see only the lamps near them.
	var cx := 4
	var cz := 5
	for i in range(cx):
		for j in range(cz):
			var x0 := -w / 2 + w * i / cx
			var x1 := -w / 2 + w * (i + 1) / cx
			var z0 := ROOM_BACK + d * j / cz
			var z1 := ROOM_BACK + d * (j + 1) / cz
			var fm := MB.new()
			fm.quad_uv("f", floor_m, Vector3(x0, 0, z1), Vector3(x1, 0, z1), Vector3(x1, 0, z0), Vector3(x0, 0, z0), Color(1, 1, 1),
				Vector2(x0, z1) / 2.0, Vector2(x1, z1) / 2.0, Vector2(x1, z0) / 2.0, Vector2(x0, z0) / 2.0)
			fm.quad_uv("c", ceil_m, Vector3(x0, hgt, z0), Vector3(x1, hgt, z0), Vector3(x1, hgt, z1), Vector3(x0, hgt, z1), Color(0.8, 0.8, 0.8),
				Vector2(x0, z0) / 1.2, Vector2(x1, z0) / 1.2, Vector2(x1, z1) / 1.2, Vector2(x0, z1) / 1.2)
			_mi(fm.build())
	# walls, with real holes where the doors and the booth window are, one piece per stretch
	var wb := MB.new()
	ShellBuilder.walls(wb, building, "hall", wall_m, hgt, [0.9, 0.8, 0.7, 0.8])
	for piece in ShellBuilder.split(wb.build(), 4.0):
		_mi(piece)
	# fluorescent fittings (dead, mostly) and pillars
	var metal := MB.mat(Tex.grime(Color("6a6a62"), Color("8a8a80"), 16, 6, 0.3))
	for z in [-8.0, -4.5, -1.0, 3.0]:
		for x in [-4.5, 4.5]:
			mb.box("m", metal, Vector3(1.4, 0.06, 0.22), MB.T(Vector3(x, hgt - 0.05, z)), Color(0.9, 0.9, 0.9))
	for z in [-7.2, 4.0]:
		for x in [-5.6, 5.6]:
			mb.box("m", metal, Vector3(0.18, hgt, 0.18), MB.T(Vector3(x, hgt / 2, z)), Color(0.7, 0.7, 0.68))
	# a stage step behind the Caller
	var wood_dark := MB.mat(Tex.wood(Color("3a2416"), 4), Color.WHITE)
	mb.box("s", wood_dark, Vector3(7.0, 0.3, 3.0), MB.T(Vector3(0, 0.15, -6.0)), Color(1, 1, 1), 0.5)
	_mi(mb.build())
	# posters, clock and an exit sign: environmental storytelling, no exposition
	_poster(Vector3(-ROOM_W / 2 + 0.02, 1.7, -8.0), PI / 2, "DOWN", "AT 7", Color("d8c8a0"))
	_poster(Vector3(ROOM_W / 2 - 0.02, 1.8, -7.0), -PI / 2, "LOST", "ONE DIE", Color("c8b890"))
	_poster(Vector3(-ROOM_W / 2 + 0.02, 1.6, 1.5), PI / 2, "NO", "RE-ROLLS", Color("c8a890"))
	_poster(Vector3(3.0, 2.2, ROOM_BACK + 0.02), 0.0, "HOUSE", "RULES", Color("b8a888"))
	var clock := MB.new()
	clock.cyl("c", MB.mat(Tex.paper(Color("d8d0b8"))), 0.28, 0.28, 0.05, 12, MB.T(Vector3.ZERO, Vector3(PI / 2, 0, 0)), Color(1, 1, 1))
	# stopped at two minutes to twelve (the fire door's padlock knows why)
	clock.box("h", MB.mat(Tex.solid(Color("1a1a1a"))), Vector3(0.022, 0.13, 0.02), MB.T(Vector3(-sin(0.017) * 0.055, cos(0.017) * 0.055, 0.03), Vector3(0, 0, 0.017)), Color(1, 1, 1))
	clock.box("h", MB.mat(Tex.solid(Color("1a1a1a"))), Vector3(0.014, 0.22, 0.02), MB.T(Vector3(-sin(0.21) * 0.095, cos(0.21) * 0.095, 0.035), Vector3(0, 0, 0.21)), Color(1, 1, 1))
	var cm := _mi(clock.build())
	cm.position = Vector3(5.0, 2.6, ROOM_BACK + 0.05)
	var exit_sign := MB.new()
	exit_sign.box("e", MB.mat(Tex.solid(Color("3aa85a")), Color.WHITE, Vector2.ONE, true), Vector3(0.5, 0.18, 0.06), MB.T(), Color(1, 1, 1))
	var es := _mi(exit_sign.build())
	es.position = Vector3(5.8, 2.9, ROOM_BACK + 0.06)
	var exit_l := Label3D.new()
	exit_l.text = "EXIT"
	exit_l.font = font
	exit_l.font_size = 24
	exit_l.pixel_size = 0.004
	exit_l.modulate = Color("0a2a10")
	exit_l.position = Vector3(5.8, 2.9, ROOM_BACK + 0.1)
	exit_l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(exit_l)

func _poster(pos: Vector3, rot_y: float, a: String, b: String, col: Color) -> void:
	var mb := MB.new()
	mb.box("p", MB.mat(Tex.paper(col, 12)), Vector3(0.6, 0.8, 0.01), MB.T(), Color(1, 1, 1))
	var mi := _mi(mb.build())
	mi.position = pos
	mi.rotation.y = rot_y
	for i in range(2):
		var l := Label3D.new()
		l.text = [a, b][i]
		l.font = font
		l.font_size = 28 if i == 0 else 16
		l.pixel_size = 0.004
		l.modulate = Color("2a1a14")
		l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		l.position = Vector3(0, 0.15 - i * 0.2, 0.01)
		l.double_sided = false
		mi.add_child(l)

func _furniture() -> void:
	# rows of chairs and little tables, as multimeshes: one draw call each
	var chair := MB.new()
	var seat_m := MB.mat(Tex.wood(Color("7a4a2a"), 7, 32, 2))
	var leg_m := MB.mat(Tex.grime(Color("4a4a48"), Color("6a6a66"), 16, 8, 0.4))
	chair.box("s", seat_m, Vector3(0.42, 0.05, 0.42), MB.T(Vector3(0, 0.45, 0)), Color(1, 1, 1))
	chair.box("s", seat_m, Vector3(0.42, 0.42, 0.04), MB.T(Vector3(0, 0.72, -0.2), Vector3(-0.08, 0, 0)), Color(0.95, 0.95, 0.95))
	for p in [Vector3(-0.18, 0.22, -0.18), Vector3(0.18, 0.22, -0.18), Vector3(-0.18, 0.22, 0.18), Vector3(0.18, 0.22, 0.18)]:
		chair.box("l", leg_m, Vector3(0.03, 0.45, 0.03), MB.T(p), Color(1, 1, 1))
	var chair_mesh := chair.build()
	var tbl := MB.new()
	tbl.box("t", MB.mat(Tex.wood(Color("5a3a24"), 9, 32, 3)), Vector3(1.6, 0.05, 0.7), MB.T(Vector3(0, 0.74, 0)), Color(1, 1, 1))
	for p in [Vector3(-0.72, 0.37, -0.28), Vector3(0.72, 0.37, -0.28), Vector3(-0.72, 0.37, 0.28), Vector3(0.72, 0.37, 0.28)]:
		tbl.box("l", leg_m, Vector3(0.05, 0.74, 0.05), MB.T(p), Color(1, 1, 1))
	var tbl_mesh := tbl.build()
	var chairs: Array = []
	var tables: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# little tables down both sides (building.json has them as obstacles: keep the two in step)
	for side in [-1, 1]:
		for z in [3.0, 0.6, -1.8]:
			var tx: float = side * 4.6
			tables.append(Transform3D(Basis(), Vector3(tx, 0, z)))
			for k in range(3):
				var cx := tx - 0.5 + k * 0.5
				var jitter := rng.randf_range(-0.12, 0.12)
				chairs.append(Transform3D(Basis.from_euler(Vector3(0, PI + jitter, 0)), Vector3(cx, 0, z - 0.55)))
				chairs.append(Transform3D(Basis.from_euler(Vector3(0, jitter, 0)), Vector3(cx, 0, z + 0.55)))
	# the empty front row facing the stage, behind the Caller
	for k in range(8):
		var x := -2.6 + k * 0.75
		if k == 2:
			wrong_chair_at = Vector3(x, 0, -3.4)
			continue
		chairs.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf_range(-0.1, 0.1), 0)), Vector3(x, 0, -3.4)))
	_multi(chair_mesh, chairs)
	_multi(tbl_mesh, tables)

func _multi(mesh: Mesh, xforms: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)

func _table() -> void:
	var mb := MB.new()
	var top := MB.mat(Tex.wood(Color("6a4a2e"), 3, 64, 4), Color.WHITE)
	var ty := TABLE_Y
	mb.box("t", top, Vector3(TABLE_W, 0.06, TABLE_D), MB.T(Vector3(0, ty - 0.03, 0)), Color(1, 1, 1), 1.3)
	# apron and legs
	var dark := MB.mat(Tex.wood(Color("4a2e1c"), 5, 32, 2))
	mb.box("a", dark, Vector3(TABLE_W - 0.2, 0.12, 0.05), MB.T(Vector3(0, ty - 0.12, TABLE_D / 2 - 0.12)), Color(1, 1, 1))
	mb.box("a", dark, Vector3(TABLE_W - 0.2, 0.12, 0.05), MB.T(Vector3(0, ty - 0.12, -TABLE_D / 2 + 0.12)), Color(1, 1, 1))
	for p in [Vector3(-1.3, ty / 2, -1.0), Vector3(1.3, ty / 2, -1.0), Vector3(-1.3, ty / 2, 1.0), Vector3(1.3, ty / 2, 1.0)]:
		mb.box("a", dark, Vector3(0.1, ty, 0.1), MB.T(p - Vector3(0, 0.03, 0)), Color(1, 1, 1))
	# the player's chair back, glimpsed when looking down
	_mi(mb.build())
	# your left: the character sheets (the fight lays them out); behind them the candles
	_candles(Vector3(-1.18, ty, -0.68))
	_book(Vector3(1.22, ty, 0.5))
	_chips(Vector3(1.28, ty, -0.12))
	_deck_box(Vector3(1.22, ty, -0.85))
	_pass_box(Vector3(1.0, ty, 0.08))
	_dice_tray(Vector3(1.0, ty, 0.78))
	_rule_rack(Vector3(0.0, ty, -0.92))
	_bell(Vector3(1.02, ty, -0.42))

func _candles(at: Vector3) -> void:
	var wax := MB.mat(Tex.grime(Color("c8b898"), Color("e8dcc0"), 16, 21, 0.3), Color(1, 0.92, 0.8), Vector2.ONE, true)
	var brass := MB.mat(Tex.brass())
	var flame_m := MB.mat(Tex.solid(Color("ffd070")), Color.WHITE, Vector2.ONE, true)
	var offs := [Vector3(-0.08, 0, -0.06), Vector3(0.06, 0, -0.1), Vector3(0.0, 0, 0.06), Vector3(0.14, 0, 0.04)]
	var hts := [0.34, 0.3, 0.26, 0.36]
	var root := Node3D.new()
	root.position = at
	add_child(root)
	for i in range(offs.size()):
		var mb := MB.new()
		mb.cyl("b", brass, 0.06, 0.035, 0.03, 8, MB.T(offs[i]), Color(1, 1, 1))
		mb.cyl("w", wax, 0.022, 0.02, hts[i], 6, MB.T(offs[i] + Vector3(0, 0.03, 0)), Color(1, 1, 1))
		_mi(mb.build(), root)
		var fl := MB.new()
		fl.cyl("f", flame_m, 0.012, 0.0, 0.05, 4, MB.T(Vector3.ZERO), Color(1, 1, 1))
		var fm := _mi(fl.build(), root)
		fm.position = offs[i] + Vector3(0, 0.03 + hts[i] + 0.005, 0)
		fm.set_meta("flame", true)
	var light := OmniLight3D.new()
	light.light_color = Color("ffb060")
	light.light_energy = 1.4
	light.omni_range = 2.2
	light.omni_attenuation = 1.4
	light.position = Vector3(0.03, 0.45, 0)
	light.shadow_enabled = false
	root.add_child(light)
	candle_lights.append(light)
	props["candles"] = root

func _book(at: Vector3) -> void:
	var mb := MB.new()
	var cover := MB.mat(Tex.grime(Color("7a1a14"), Color("9a2a1e"), 16, 22, 0.3))
	var pages := MB.mat(Tex.paper(Color("e0d4b0"), 3, 16))
	mb.box("c", cover, Vector3(0.36, 0.015, 0.46), MB.T(Vector3(0, 0.008, 0)), Color(1, 1, 1))
	mb.box("p", pages, Vector3(0.34, 0.05, 0.44), MB.T(Vector3(0.0, 0.04, 0)), Color(1, 1, 1))
	mb.box("c", cover, Vector3(0.36, 0.015, 0.46), MB.T(Vector3(0, 0.072, 0)), Color(1, 1, 1))
	mb.box("c", cover, Vector3(0.02, 0.08, 0.46), MB.T(Vector3(-0.18, 0.04, 0)), Color(0.8, 0.8, 0.8))
	var mi := _mi(mb.build())
	mi.position = at
	mi.rotation.y = 0.25
	props["book"] = mi

func _chips(at: Vector3) -> void:
	var gold := MB.mat(Tex.grime(Color("a8802a"), Color("d8b04a"), 16, 23, 0.4))
	var root := Node3D.new()
	root.position = at
	add_child(root)
	props["chips"] = root

## Show the party's gold as stacks of chips: one chip per 5 gold, stacks of 8.
func set_chips(gold: int) -> void:
	var root: Node3D = props["chips"]
	for c in root.get_children():
		c.queue_free()
	var n := clampi(int(ceil(gold / 5.0)), 0, 48)
	var mb := MB.new()
	var gold_m := MB.mat(Tex.grime(Color("a8802a"), Color("d8b04a"), 16, 23, 0.4))
	for i in range(n):
		var stack := i / 8
		var h := i % 8
		var p := Vector3((stack % 3) * 0.075, 0.006 + h * 0.012, (stack / 3) * 0.075)
		mb.cyl("g", gold_m, 0.032, 0.032, 0.011, 8, MB.T(p + Vector3(randf_range(-0.003, 0.003), 0, 0)), Color(1, 1, 1) if h % 2 == 0 else Color(0.85, 0.82, 0.75))
	if n > 0:
		_mi(mb.build(), root)

func _deck_box(at: Vector3) -> void:
	var mb := MB.new()
	var red := MB.mat(Tex.grime(Color("5a1612"), Color("7a2018"), 16, 24, 0.3))
	mb.box("r", red, Vector3(0.38, 0.12, 0.26), MB.T(Vector3(0, 0.06, 0)), Color(1, 1, 1))
	mb.box("r", red, Vector3(0.38, 0.2, 0.03), MB.T(Vector3(0, 0.2, -0.13), Vector3(-0.5, 0, 0)), Color(0.9, 0.9, 0.9))
	var mi := _mi(mb.build())
	mi.position = at
	mi.rotation.y = 0.35
	props["deck"] = mi

## The pint. You end your turn by taking a sip; the level drops with every turn and he
## pours you another between fights. props["pass"] is its root (that's what you tap).
var beer_level := 1.0
var _beer_liquid: Node3D
var _beer_foam: Node3D
var _beer_rest: Transform3D
const GLASS_H := 0.2

func _pass_box(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Beer"
	root.position = at
	add_child(root)
	# the glass: a faceted, slightly flared pint, see-through
	var glass := StandardMaterial3D.new()
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.85, 0.92, 0.88, 0.22)
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gm := MB.new()
	gm.cyl("g", glass, 0.052, 0.064, GLASS_H, 10, MB.T(), Color(1, 1, 1), false)
	gm.cyl("g", glass, 0.054, 0.054, 0.018, 10, MB.T(), Color(1, 1, 1), true)
	var rim := MB.mat(Tex.solid(Color("d8e4dc")), Color.WHITE, Vector2.ONE, true)
	gm.ring("r", rim, 0.064, 0.005, 12, MB.T(Vector3(0, GLASS_H, 0)), Color(1, 1, 1))
	var glass_mi := _mi(gm.build(), root)
	glass_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the beer: a column that scales from the bottom, with a head of foam on top
	_beer_liquid = Node3D.new()
	_beer_liquid.position = Vector3(0, 0.018, 0)
	root.add_child(_beer_liquid)
	var lm := MB.new()
	var amber := MB.mat(Tex.grime(Color("a8641a"), Color("d89a2a"), 16, 41, 0.4), Color.WHITE, Vector2.ONE, true)
	lm.cyl("l", amber, 0.05, 0.06, 1.0, 10, MB.T(), Color(1, 1, 1), true)
	_mi(lm.build(), _beer_liquid)
	_beer_foam = Node3D.new()
	root.add_child(_beer_foam)
	var fm := MB.new()
	var foam := MB.mat(Tex.grime(Color("e8dcc0"), Color("fff4e0"), 16, 42, 0.5), Color.WHITE, Vector2.ONE, false)
	fm.cyl("f", foam, 0.061, 0.058, 0.02, 10, MB.T(), Color(1, 1, 1), true)
	_mi(fm.build(), _beer_foam)
	# a beer mat under it, with a ring stain
	var mat_mb := MB.new()
	var coaster := MB.mat(Tex.cached("coaster", func():
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in range(32):
			for x in range(32):
				var d := Vector2(x - 15.5, y - 15.5).length()
				var c := Color("c8b890") if d < 15 else Color(0, 0, 0, 0)
				if d < 15 and d > 13:
					c = Color("8a2a1e")
				if abs(d - 9.5) < 0.8:
					c = c.darkened(0.25)
				img.set_pixel(x, y, c)
		return img))
	mat_mb.quad("c", coaster, Vector3(-0.09, 0.002, 0.09), Vector3(0.09, 0.002, 0.09), Vector3(0.09, 0.002, -0.09), Vector3(-0.09, 0.002, -0.09), Color(1, 1, 1))
	_mi(mat_mb.build(), root)
	props["pass"] = root
	_beer_rest = root.transform
	set_beer(1.0)

func set_beer(level: float) -> void:
	beer_level = clampf(level, 0.0, 1.0)
	var h := maxf(0.001, (GLASS_H - 0.03) * beer_level)
	_beer_liquid.scale = Vector3(1, h, 1)
	_beer_foam.position = Vector3(0, 0.018 + h, 0)
	_beer_foam.visible = beer_level > 0.02
	_beer_liquid.visible = beer_level > 0.01

## Lift it, tip it, put it down a little emptier. Awaitable.
func sip(amount: float = 0.12, speed: float = 1.0) -> void:
	var root: Node3D = props["pass"]
	var cam := get_viewport().get_camera_3d()
	var mouth := root.global_position + Vector3(-0.25, 0.42, 0.55)
	if cam:
		mouth = cam.global_position + cam.global_transform.basis * Vector3(0.08, -0.16, -0.3)
	var local_mouth: Vector3 = (root.get_parent() as Node3D).to_local(mouth) if root.get_parent() is Node3D else mouth
	var tw := create_tween()
	tw.tween_property(root, "position", local_mouth, 0.35 / speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(root, "rotation", Vector3(-0.15, 0.3, 0), 0.35 / speed)
	tw.tween_property(root, "rotation", Vector3(-1.15, 0.3, 0), 0.3 / speed)
	tw.tween_callback(func():
		if has_node("/root/Sfx"):
			Sfx.play("gulp", -4.0, 0.1))
	tw.tween_method(func(v: float): set_beer(v), beer_level, beer_level - amount, 0.45 / speed)
	tw.tween_property(root, "rotation", Vector3(-0.1, 0, 0), 0.25 / speed)
	tw.tween_property(root, "transform", _beer_rest, 0.3 / speed).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		if has_node("/root/Sfx"):
			Sfx.play("glass_down", -6.0, 0.1))
	await tw.finished

## Another round: he tops you up.
func refill() -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float): set_beer(v), beer_level, 1.0, 0.8)
	if has_node("/root/Sfx"):
		Sfx.play("pour", -6.0, 0.05)

## Blocky 5x7 capitals for baked-in labels.
static func _text(img: Image, s: String, x0: int, y0: int, scale: int, col: Color) -> void:
	var glyphs := {
		"P": ["1110", "1001", "1001", "1110", "1000", "1000", "1000"],
		"A": ["0110", "1001", "1001", "1111", "1001", "1001", "1001"],
		"S": ["0111", "1000", "1000", "0110", "0001", "0001", "1110"],
		"R": ["1110", "1001", "1001", "1110", "1010", "1001", "1001"],
		"U": ["1001", "1001", "1001", "1001", "1001", "1001", "0110"],
		"L": ["1000", "1000", "1000", "1000", "1000", "1000", "1111"],
		"E": ["1111", "1000", "1000", "1110", "1000", "1000", "1111"],
	}
	var x := x0
	for ch in s:
		if glyphs.has(ch):
			var g: Array = glyphs[ch]
			for gy in range(7):
				for gx in range(4):
					if g[gy][gx] == "1":
						for sy in range(scale):
							for sx in range(scale):
								img.set_pixel(clampi(x + gx * scale + sx, 0, img.get_width() - 1), clampi(y0 + gy * scale + sy, 0, img.get_height() - 1), col)
		x += 5 * scale

func _dice_tray(at: Vector3) -> void:
	var mb := MB.new()
	var felt := MB.mat(Tex.grime(Color("1e3a26"), Color("2a4a30"), 32, 26, 0.3))
	var wood := MB.mat(Tex.wood(Color("5a3a22"), 27, 32, 2))
	mb.box("f", felt, Vector3(0.44, 0.01, 0.34), MB.T(Vector3(0, 0.005, 0)), Color(1, 1, 1))
	mb.box("w", wood, Vector3(0.48, 0.05, 0.02), MB.T(Vector3(0, 0.025, 0.18)), Color(1, 1, 1))
	mb.box("w", wood, Vector3(0.48, 0.05, 0.02), MB.T(Vector3(0, 0.025, -0.18)), Color(1, 1, 1))
	mb.box("w", wood, Vector3(0.02, 0.05, 0.38), MB.T(Vector3(0.23, 0.025, 0)), Color(1, 1, 1))
	mb.box("w", wood, Vector3(0.02, 0.05, 0.38), MB.T(Vector3(-0.23, 0.025, 0)), Color(1, 1, 1))
	var mi := _mi(mb.build())
	mi.position = at
	mi.rotation.y = -0.2
	props["tray"] = mi

func _rule_rack(at: Vector3) -> void:
	# a long wooden rack where the Caller stands his rule cards (like the ball rack in LAST CALL)
	var mb := MB.new()
	var wood := MB.mat(Tex.wood(Color("5a3420"), 28, 32, 2))
	mb.box("w", wood, Vector3(1.3, 0.06, 0.12), MB.T(Vector3(0, 0.03, 0)), Color(1, 1, 1))
	mb.box("w", wood, Vector3(1.3, 0.1, 0.02), MB.T(Vector3(0, 0.08, -0.05)), Color(0.85, 0.85, 0.85))
	var mi := _mi(mb.build())
	mi.position = at
	props["rack"] = mi

func _bell(at: Vector3) -> void:
	# the brass service bell: rings when the Caller wants your attention
	var mb := MB.new()
	var brass := MB.mat(Tex.brass())
	mb.cyl("b", brass, 0.08, 0.08, 0.015, 8, MB.T(), Color(0.7, 0.7, 0.7))
	mb.cyl("b", brass, 0.06, 0.02, 0.06, 8, MB.T(Vector3(0, 0.015, 0)), Color(1, 1, 1))
	mb.cyl("b", brass, 0.01, 0.01, 0.02, 4, MB.T(Vector3(0, 0.075, 0)), Color(1, 1, 1))
	var mi := _mi(mb.build())
	mi.position = at
	props["bell"] = mi

## The desk bell: a ding, and his head snaps to the door.
func ring_bell() -> void:
	var bell: Node3D = props.get("bell", null)
	if bell == null:
		return
	if has_node("/root/Sfx"):
		Sfx.play("bell", -3.0, 0.05)
	var tw := create_tween()
	var p := bell.position
	tw.tween_property(bell, "position", p - Vector3(0, 0.012, 0), 0.05)
	tw.tween_property(bell, "position", p, 0.12)

func _scoreboard() -> void:
	flashboard = Flashboard.new()
	flashboard.name = "Flashboard"
	flashboard.position = Vector3(0, 3.02, -3.3)
	flashboard.scale = Vector3.ONE * 0.8
	add_child(flashboard)

func _label(parent: Node3D, text: String, pos: Vector3, size: int, col: Color, align: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = col
	l.outline_size = 0
	l.horizontal_alignment = align
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.position = pos
	l.shaded = false
	parent.add_child(l)
	return l

## The flashboard: left window (label, value) and the FILE (his suspicion, 0-100).
func set_score(left_label: String, left_value: String, suspicion: int = 0) -> void:
	if flashboard == null:
		return
	flashboard.set_left(left_label, left_value)
	flashboard.set_right("FILE", "%02d" % clampi(suspicion, 0, 99), suspicion >= 70)

func _lights() -> void:
	# the hanging green lamp over the table (the key light), a white one over the Caller
	var lamp := MB.new()
	var green := MB.mat(Tex.grime(Color("1e4a2a"), Color("2a5a34"), 16, 33, 0.3))
	var bulb := MB.mat(Tex.solid(Color("fff2c8")), Color.WHITE, Vector2.ONE, true)
	lamp.cyl("g", green, 0.55, 0.08, 0.28, 8, MB.T(Vector3(0, 0, 0)), Color(1, 1, 1), false)
	lamp.sphere("b", bulb, 0.07, 3, 6, MB.T(Vector3(0, 0.02, 0)), Color(1, 1, 1))
	lamp.box("c", green, Vector3(0.015, 1.0, 0.015), MB.T(Vector3(0, 0.75, 0)), Color(0.4, 0.4, 0.4))
	var lm := _mi(lamp.build())
	lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lm.position = Vector3(-0.1, 2.72, 0.35)
	lamp_light = SpotLight3D.new()
	lamp_light.light_color = Color("ffe0a8")
	lamp_light.light_energy = 3.0
	lamp_light.spot_range = 4.5
	lamp_light.spot_angle = 60.0
	lamp_light.spot_attenuation = 0.8
	lamp_light.shadow_enabled = false
	lamp_light.position = Vector3(-0.1, 2.62, 0.35)
	lamp_light.rotation = Vector3(-PI / 2, 0, 0)
	add_child(lamp_light)
	# dust turning slowly in the lamp's light, and the light itself, faintly, in the smoke
	var dust := CPUParticles3D.new()
	dust.amount = 90
	dust.lifetime = 14.0
	dust.preprocess = 14.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(1.4, 1.0, 1.2)
	dust.position = Vector3(-0.1, 1.6, 0.2)
	dust.direction = Vector3(0, -1, 0)
	dust.spread = 180.0
	dust.gravity = Vector3(0, -0.004, 0)
	dust.initial_velocity_min = 0.004
	dust.initial_velocity_max = 0.02
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.0
	var dq := QuadMesh.new()
	dq.size = Vector2(0.006, 0.006)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(1.0, 0.92, 0.75, 0.5)
	dq.material = dm
	dust.mesh = dq
	add_child(dust)
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 1.25
	cm.height = 1.85
	cm.radial_segments = 12
	cm.cap_top = false
	cm.cap_bottom = false
	var cmat := StandardMaterial3D.new()
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cmat.albedo_color = Color(1.0, 0.8, 0.5, 0.012)
	cm.material = cmat
	cone.mesh = cm
	cone.position = Vector3(-0.1, 2.62 - 0.93, 0.35)
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cone)
	var lamp2 := MB.new()
	var shade := MB.mat(Tex.grime(Color("c8c0a8"), Color("e8e0c8"), 16, 34, 0.3))
	lamp2.cyl("s", shade, 0.42, 0.12, 0.18, 8, MB.T(), Color(1, 1, 1), false)
	lamp2.sphere("b", bulb, 0.06, 3, 6, MB.T(Vector3(0, 0.02, 0)), Color(1, 1, 1))
	lamp2.box("c", shade, Vector3(0.015, 0.8, 0.015), MB.T(Vector3(0, 0.55, 0)), Color(0.4, 0.4, 0.4))
	var lm2 := _mi(lamp2.build())
	lm2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lm2.position = Vector3(0, 3.05, -1.55)
	var top := SpotLight3D.new()
	top.light_color = Color("f0e8d0")
	top.light_energy = 2.2
	top.spot_range = 4.0
	top.spot_angle = 38.0
	top.position = Vector3(0, 3.0, -1.55)
	top.rotation = Vector3(-PI / 2, 0, 0)
	add_child(top)
	# no hall-wide fill lights (they lit every piece of the room at once); the ambient does it


func _process(delta: float) -> void:
	t += delta
	for l in candle_lights:
		l.light_energy = 1.25 + 0.18 * sin(t * 11.0) * sin(t * 4.3 + 1.0) + randf_range(-0.04, 0.04)

## Send the Caller somewhere else in the hall (he is always wherever you are going).
func place_caller(at: Vector3, rot_y: float) -> void:
	caller.position = at
	caller.rotation.y = rot_y

func reset_caller() -> void:
	caller.position = Vector3(0, 0.0, -1.75)
	caller.rotation.y = 0.0

func setting_mood(pal: Dictionary) -> void:
	# each Book tints the lamp a little; the hall itself stays the same room
	if lamp_light:
		lamp_light.light_color = Color("ffe0a8").lerp(Color(pal.get("light", "#ffe0a8")), 0.35)
