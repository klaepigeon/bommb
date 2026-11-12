extends Level
## Level 2: Flat 47 again, as something that has grown it. The same rooms (her wallpaper, her
## armchair, her wardrobe, her front door), in the wrong order and the wrong number, with the
## walls gone to meat and breathing. Marta is in here, on her feet, and she hunts.
##
## Kurt comes out of the throat he crawled into, onto the floor of a room that is nearly the
## bedroom. Somewhere in the maze is the flat's front door, the real one, the one that opens.
##
## The map is a grid of CELL-metre squares: # wall, . floor, + doorway, S start, E the way out
## (its door is in the wall south of it), M Marta, p her patrol, A a box of rounds, b a bottle,
## c armchair, k kitchen counter, T table, w wardrobe, d one of her front doors (it doesn't open).

const CELL := 1.4
const H := 2.7
const MAP := """##########################
#S...#.......#......d#...#
#.c..#..k....#..b....#.p.#
#....+..k....+.......+...#
###+####..####...w..###+##
#......p.....#.......#...#
#.w..#.......##+######.c.#
#....#...b...#.......#...#
#.####.#######..p....+...#
#......#.....#.......###+#
#.k..p.#..c..##+#####....#
#.k....+.............+.A.#
####+###########..#..#...#
#..........b...#..#..##+##
#.T..p.....##..+..p......#
#....M.....##..#.........#
#..d.......#E..#....w....#
##########################"""

var rows: PackedStringArray
var marta: MartaHunter
var marta_head: Node3D
var exit_door: Door
var _encountered := false
var _near := 0.0
var drips: Array = []
var fake_doors: Array = []
var _ending := false

func cell_pos(x: int, y: int, h := 0.0) -> Vector3:
	return Vector3((x + 0.5) * CELL, h, (y + 0.5) * CELL)

func build() -> void:
	rows = MAP.split("\n")
	var e := env.environment
	e.ambient_light_color = Color("6a3436"); e.ambient_light_energy = 1.8; e.fog_light_color = Color("2a0c0e"); e.fog_density = 0.035
	var W := rows[0].length(); var Hh := rows.size()
	var floor_m := Tex.mat("flesh", 0.6, {"pulse": 0.004, "tint": Color(0.75, 0.6, 0.6)})
	var walls := [Tex.mat("wallpaper", 1.0, {"tint": Color(0.85, 0.75, 0.72)}), Tex.mat("wallpaper_flesh", 0.8, {"pulse": 0.006}), Tex.mat("flesh", 0.6, {"pulse": 0.012})]
	var ceil_m := Tex.mat("flesh", 0.5, {"pulse": 0.01})
	Build.box(world, Vector3(W * CELL * 0.5, -0.05, Hh * CELL * 0.5), Vector3(W * CELL, 0.1, Hh * CELL), floor_m)
	Build.box(world, Vector3(W * CELL * 0.5, H + 0.05, Hh * CELL * 0.5), Vector3(W * CELL, 0.1, Hh * CELL), ceil_m)
	# walls: runs of # along each row become one box each
	for y in Hh:
		var x := 0
		while x < W:
			if rows[y][x] == "#" and not (rows[y][x] == "#" and y == Hh - 1 and _is_exit_wall(x)):
				var x0 := x
				while x < W and rows[y][x] == "#" and not (y == Hh - 1 and _is_exit_wall(x)): x += 1
				# her wallpaper near where he came in; further on, it's gone to meat
				var k := clampf((x0 + y * 0.8) / 30.0 + randf_range(-0.25, 0.25), 0.0, 0.999)
				Build.box(world, Vector3((x0 + x) * 0.5 * CELL, H * 0.5, (y + 0.5) * CELL), Vector3((x - x0) * CELL, H, CELL), walls[int(k * 3.0)])
			else:
				x += 1
	# grid for Marta's path-finding: walls and big furniture are solid
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, W, Hh); grid.cell_size = Vector2(CELL, CELL)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var patrol := []
	var lights := 0
	for y in Hh:
		for x in W:
			var c: String = rows[y][x]
			if c in "#wkTcd": grid.set_point_solid(Vector2i(x, y), true)
			var p := cell_pos(x, y)
			match c:
				"S": _arrival(x, y)
				"E": _exit(x, y)
				"M": _spawn_marta(p)
				"p": patrol.append(p); lights += 1; _light(p, lights)
				"A": _ammo(p)
				"b": Prop.make(world, p + Vector3(0.2, 0.15, -0.1), Vector3(0.08, 0.2, 0.08), Tex.mat("glass", 1.0, {"tint": Color(0.4, 0.6, 0.4)}), "bottle", 0.4, 0.9)
				"c": _armchair(p, x, y)
				"k": Build.box(world, p + Vector3(0, 0.45, 0), Vector3(CELL * 0.9, 0.9, CELL * 0.6), Tex.mat("wood_light", 2.0, {"tint": Color(1.0, 0.7, 0.7)}))
				"T": Build.box(world, p + Vector3(0, 0.38, 0), Vector3(CELL * 0.9, 0.06, CELL * 0.7), Tex.mat("cloth_red", 4.0))
				"w": _wardrobe(p, x, y)
				"d": _fake_door(x, y)
	marta.grid = grid; marta.cell = CELL; marta.origin = Vector3.ZERO
	# patrol in a sensible loop: nearest-neighbour from her start
	var tour := []; var left := patrol.duplicate(); var at: Vector3 = marta.global_position
	while not left.is_empty():
		var bi := 0
		for i in left.size(): if (left[i] as Vector3).distance_to(at) < (left[bi] as Vector3).distance_to(at): bi = i
		at = left[bi]; tour.append(at); left.remove_at(bi)
	marta.patrol = tour
	marta.go_to(tour[0])
	# the meat between the rooms: lumps and coral on the walls, here and there
	var r := RandomNumberGenerator.new(); r.seed = 48
	Build.organic(world, func(st):
		for i in 70:
			var x := r.randi_range(1, W - 2); var y := r.randi_range(1, Hh - 2)
			if rows[y][x] != ".": continue
			var p := cell_pos(x, y)
			MeshKit.lump(st, p + Vector3(r.randf_range(-0.6, 0.6), r.randf_range(0.0, 2.4) if r.randf() < 0.5 else 0.0, r.randf_range(-0.6, 0.6)), r.randf_range(0.05, 0.14), r), Tex.mat("coral", 4.0, {"pulse": 0.004}))
	socko.points = {"marta": marta_head}
	_growth()
	Air.dust(world, Vector3(W * CELL * 0.5, 1.3, Hh * CELL * 0.5), Vector3(W * CELL * 0.5, 1.2, Hh * CELL * 0.5), 3000, Color(1.0, 0.8, 0.8))
	Sfx.set_room(0.85, 0.38, 0.4)
	ambient([2.0, 5.0], func(): Sfx.play_at("drip", (drips.pick_random() as Vector3) + Vector3(0, 0.1, 0), -8.0, randf_range(0.6, 0.8)))
	ambient([12.0, 25.0], func(): Sfx.play_at("whisper", _behind_a_wall(), -4.0, randf_range(0.7, 1.0)), 8.0)
	ambient([20.0, 40.0], func(): Sfx.play_at("groan", _behind_a_wall(), -2.0, randf_range(0.6, 0.9)), 15.0)
	ambient([7.0, 15.0], func(): Sfx.play_at("squelch", _behind_a_wall(), -8.0, randf_range(0.5, 0.8)))
	ambient([30.0, 60.0], func(): _knocking((fake_doors.pick_random() as Vector3) if not fake_doors.is_empty() else _behind_a_wall()), 20.0)

func _is_exit_wall(x: int) -> bool:
	return rows[rows.size() - 2][x] == "E"

## A light in the meat: a swollen gland in the ceiling, glowing, beating with all the others.
func _light(p: Vector3, i: int) -> void:
	var c: Color = [Color("ff6a5a"), Color("c05aff"), Color("ff8a6a"), Color("5a8aff")][i % 4]
	var f := Fitting.make(world, p + Vector3(0, 2.3, 0), c, 2.4, 8.0, "pulse", i % 3 == 0)
	f.mains = false
	var gland := Build.organic(world, func(st): MeshKit.blob(st, p + Vector3(0, H - 0.1, 0), Vector3(0.14, 0.11, 0.14), {"bumps": 0.3}), Tex.mat("flesh", 2.0, {"emission": Vector3(c.r, c.g, c.b) * 2.0}))
	f.add_glow(gland, Vector3(c.r, c.g, c.b) * 2.5)
	var cone := Air.beam(f, 2.3, 1.1, c, 0.015); cone.rotation.x = -PI * 0.5
	# goo dripping from it
	var drip := CPUParticles3D.new(); world.add_child(drip); drip.position = p + Vector3(0.05, H - 0.15, 0)
	drip.amount = 3; drip.lifetime = 1.2; drip.gravity = Vector3(0, -9.8, 0); drip.initial_velocity_max = 0.0
	var dm := SphereMesh.new(); dm.radius = 0.012; dm.height = 0.03; dm.radial_segments = 5; dm.rings = 3; dm.material = _goo(); drip.mesh = dm
	drips.append(p)

func _arrival(x: int, y: int) -> void:
	var p := cell_pos(x, y)
	player.position = p + Vector3(0, 0, 0.1)
	# the throat he came out of, in the north wall, still dribbling goo
	var flesh := Tex.mat("flesh", 3.0, {"pulse": 0.012, "double": true})
	var hole := Vector3(p.x, 0, y * CELL)
	Build.organic(world, func(st):
		for i in 18:
			var a := TAU * i / 18.0
			MeshKit.blob(st, hole + Vector3(cos(a) * 0.5, 0.5 + sin(a) * 0.45, 0.05), Vector3(0.13, 0.13, 0.1), {"bumps": 0.3, "seed": float(i)}), flesh)
	Build.organic(world, func(st): MeshKit.blob(st, hole + Vector3(0, 0.0, 0.7), Vector3(0.7, 0.015, 0.6), {"bumps": 0.3, "freq": 3.0}), _goo())
	Build.box(world, hole + Vector3(0, 0.5, -0.02), Vector3(0.8, 0.8, 0.02), Tex.mat("black"), false)
	Build.lamp(world, p + Vector3(0, 1.0, 0.0), Color("3a6aff"), 0.7, 4.0)

func _goo() -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = preload("res://shaders/goo.gdshader"); return m

func _armchair(p: Vector3, _x: int, _y: int) -> void:
	# her armchair, empty: the coral she tore out of is still in it
	var cm := Tex.mat("fabric", 3.0, {"tint": Color(1.0, 0.75, 0.75)})
	Build.box(world, p + Vector3(0, 0.22, 0), Vector3(0.8, 0.44, 0.7), cm)
	Build.box(world, p + Vector3(0, 0.7, 0.3), Vector3(0.8, 0.9, 0.16), cm)
	var r := RandomNumberGenerator.new(); r.seed = int(p.x * 10 + p.z)
	Build.organic(world, func(st):
		for i in 5: MeshKit.coral(st, p + Vector3(r.randf_range(-0.3, 0.3), 0.45, r.randf_range(-0.2, 0.2)), Vector3(r.randf_range(-0.5, 0.5), 1.0, r.randf_range(-0.5, 0.5)), 0.3, 0.03, r, 1), Tex.mat("coral", 4.0))

func _wardrobe(p: Vector3, _x: int, _y: int) -> void:
	var w := Wardrobe.new(); w.size = Vector3(1.2, 2.1, 0.6); world.add_child(w); w.position = p

func _fake_door(x: int, y: int) -> void:
	# her front door, set into the wall, again: padded, numbered, locked. Try it, and something on
	# the other side knocks.
	var p := cell_pos(x, y)
	var d := Door.new(); d.material = Tex.mat("door_padded", 2.0); d.width = 0.95; d.locked = true
	fake_doors.append(p + Vector3(0, 1.3, CELL * 0.5))
	d.tried.connect(func(_dd):
		await get_tree().create_timer(randf_range(1.2, 2.2)).timeout
		_knocking(p + Vector3(0, 1.3, CELL * 0.5 + 0.3)))
	world.add_child(d); d.position = p + Vector3(-0.475, 0, CELL * 0.5 - 0.02)
	var num := Label3D.new(); num.text = "47"; num.font_size = 48; num.pixel_size = 0.002; num.modulate = Color("c8b878")
	d.panel.add_child(num); num.position = Vector3(0.47, 1.62, 0.035)

func _ammo(p: Vector3) -> void:
	var a := Pickup.new(); a.item = "ammo"; a.amount = 6; a.label = "box of rounds"
	world.add_child(a); a.position = p + Vector3(0, 0.05, 0)
	var mi := MeshInstance3D.new(); mi.mesh = Build.box_mesh(Vector3(0.14, 0.08, 0.1)); mi.material_override = Tex.mat("cardboard", 8.0, {"tint": Color(0.7, 0.8, 0.6)})
	a.add_child(mi)
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(0.3, 0.2, 0.3); cs.shape = sh; a.add_child(cs)

func _spawn_marta(p: Vector3) -> void:
	marta = MartaHunter.new(); marta.player = player
	world.add_child(marta); marta.global_position = p
	marta_head = Node3D.new(); marta.add_child(marta_head); marta_head.position.y = 1.7
	marta.caught_player.connect(_on_caught)
	marta.spotted_player.connect(_on_spotted)

## The way out: the flat's own front door, in the south wall. Beyond it, the landing.
func _exit(x: int, y: int) -> void:
	var p := cell_pos(x, y)
	var z := (y + 1) * CELL
	exit_door = Door.new(); exit_door.material = Tex.mat("door_padded", 2.0); exit_door.width = 0.95; exit_door.open_angle = -1.6
	world.add_child(exit_door); exit_door.position = Vector3(p.x - 0.475, 0, z + CELL * 0.5)
	var num := Label3D.new(); num.text = "47"; num.font_size = 48; num.pixel_size = 0.002; num.modulate = Color("c8b878")
	exit_door.panel.add_child(num); num.position = Vector3(0.47, 1.62, -0.035); num.rotation.y = PI
	# the wall cell either side of the door
	Build.box(world, Vector3(p.x - 0.475 - (CELL * 0.5 - 0.475) * 0.5 - 0.0, H * 0.5, z + CELL * 0.5), Vector3(CELL * 0.5 - 0.475, H, CELL), Tex.mat("wallpaper_flesh", 0.8))
	Build.box(world, Vector3(p.x + 0.475 + (CELL * 0.5 - 0.475) * 0.5, H * 0.5, z + CELL * 0.5), Vector3(CELL * 0.5 - 0.475, H, CELL), Tex.mat("wallpaper_flesh", 0.8))
	Build.box(world, Vector3(p.x, 2.05 + (H - 2.05) * 0.5, z + CELL * 0.5), Vector3(0.95, H - 2.05, CELL), Tex.mat("wallpaper_flesh", 0.8))
	# the landing beyond: the stairwell, gone soft. Across it, 48, open, with light inside
	var lz := z + CELL
	var sw := Tex.mat("stairwell", 0.5, {"tint": Color(1.0, 0.7, 0.7), "pulse": 0.006})
	Build.room(world, p.x - 3.0, lz, p.x + 3.0, lz + 3.0, Tex.mat("concrete", 1.5, {"tint": Color(1, 0.7, 0.7)}), Tex.mat("plaster", 0.7), 2.9)
	Build.wall(world, Vector2(p.x - 3.0, lz), Vector2(p.x - 3.0, lz + 3.0), sw, [], 2.9)
	Build.wall(world, Vector2(p.x + 3.0, lz), Vector2(p.x + 3.0, lz + 3.0), sw, [], 2.9)
	Build.wall(world, Vector2(p.x - 3.0, lz + 3.0), Vector2(p.x + 3.0, lz + 3.0), sw, [{"at": 3.0, "w": 0.95}], 2.9)
	var d48 := Door.new(); d48.material = Tex.mat("door_padded", 2.0); d48.width = 0.95; d48.open_angle = 1.2; d48.is_open = true; d48.locked = true
	world.add_child(d48); d48.position = Vector3(p.x - 0.475, 0, lz + 3.0)
	var n48 := Label3D.new(); n48.text = "48"; n48.font_size = 48; n48.pixel_size = 0.002; n48.modulate = Color("c8b878")
	d48.panel.add_child(n48); n48.position = Vector3(0.47, 1.62, -0.035); n48.rotation.y = PI
	Build.box(world, Vector3(p.x, 1.2, lz + 4.0), Vector3(1.6, 2.4, 0.1), Tex.mat("plaster", 1.0, {"emission": Vector3(2.0, 1.7, 1.2)}), false)
	Build.lamp(world, Vector3(p.x, 1.4, lz + 3.3), Color("ffe0b0"), 1.6, 5.0)
	zone(Vector3(p.x, 1.0, lz + 1.2), Vector3(5.0, 2.0, 1.2), _finale)

# ------------------------------------------------------------------ the story
## What the flat has grown: ribs arching over the corridors, veins climbing the walls, strands
## hanging from the ceiling, goo pooled on the floor. Batched into a few meshes.
func _growth() -> void:
	var W := rows[0].length(); var Hh := rows.size()
	var r := RandomNumberGenerator.new(); r.seed = 471
	var solid := func(x: int, y: int) -> bool: return x < 0 or y < 0 or x >= W or y >= Hh or rows[y][x] == "#"
	var ribs := []; var veins := []; var strands := []; var pools := []
	for y in Hh:
		for x in W:
			if rows[y][x] == "#": continue
			var p := cell_pos(x, y)
			var ns: bool = solid.call(x, y - 1) and solid.call(x, y + 1)
			var ew: bool = solid.call(x - 1, y) and solid.call(x + 1, y)
			if (ns or ew) and r.randf() < 0.55: ribs.append([p, ns])
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if solid.call(x + d.x, y + d.y) and r.randf() < 0.3: veins.append([p, d])
			if r.randf() < 0.25: strands.append(p)
			if r.randf() < 0.07 and rows[y][x] == ".": pools.append(p)
	Build.organic(world, func(st):
		for rb in ribs:
			var p: Vector3 = rb[0]; var across: Vector3 = Vector3(0, 0, 1) if rb[1] else Vector3(1, 0, 0)
			var pts := []; var rs := []
			for i in 9:
				var a := PI * i / 8.0
				pts.append(p + across * cos(a) * CELL * 0.5 + Vector3(0, H - 0.05 - sin(a) * 0.35 - (1.0 - sin(a)) * 0.9, 0) + Vector3(r.randf_range(-0.03, 0.03), 0, r.randf_range(-0.03, 0.03)))
				rs.append(0.07 - sin(a) * 0.025)
			MeshKit.tube(st, pts, rs, {"sides": 6, "bumps": 0.3, "seed": r.randf() * 50.0}), Tex.mat("coral", 3.0, {"tint": Color(1.0, 0.75, 0.7)}))
	Build.organic(world, func(st):
		for v in veins:
			var p: Vector3 = v[0]; var d: Vector2i = v[1]
			var wall := p + Vector3(d.x, 0, d.y) * (CELL * 0.5 - 0.03)
			var side := Vector3(-d.y, 0, d.x)
			var pts := []; var rs := []; var o := r.randf_range(-0.5, 0.5)
			for i in 7:
				var k := i / 6.0
				pts.append(wall + side * (o + sin(k * 5.0 + o * 3.0) * 0.15) + Vector3(0, k * H, 0)); rs.append(0.025 * (1.0 - k * 0.5))
			MeshKit.tube(st, pts, rs, {"sides": 5, "bumps": 0.3, "cap": false}), Tex.mat("flesh_dark", 3.0, {"emission": Vector3(0.5, 0.1, 0.4), "pulse": 0.01}))
	Build.organic(world, func(st):
		for p in strands:
			var o := Vector3(r.randf_range(-0.5, 0.5), 0, r.randf_range(-0.5, 0.5))
			var L := r.randf_range(0.3, 1.1)
			MeshKit.tube(st, [p + o + Vector3(0, H, 0), p + o + Vector3(0.02, H - L * 0.5, 0), p + o + Vector3(0, H - L, 0.02)], [0.02, 0.008, 0.012], {"sides": 4})
			MeshKit.blob(st, p + o + Vector3(0, H - L - 0.02, 0.02), Vector3.ONE * 0.025, {"rings": 3, "segs": 5}), _goo())
	Build.organic(world, func(st):
		for p in pools:
			MeshKit.blob(st, p + Vector3(r.randf_range(-0.3, 0.3), 0.0, r.randf_range(-0.3, 0.3)), Vector3(r.randf_range(0.3, 0.6), 0.012, r.randf_range(0.3, 0.6)), {"bumps": 0.3, "freq": 3.0}), _goo())

## Knocking, as Kurt knocked on her door: three, then four.
func _knocking(at: Vector3) -> void:
	for i in 3:
		Sfx.play_at("knock", at, -2.0, randf_range(0.85, 0.95), 25.0); await get_tree().create_timer(0.36).timeout
	await get_tree().create_timer(1.6).timeout
	for i in 4:
		Sfx.play_at("knock", at, 0.0, randf_range(0.8, 0.9), 25.0); await get_tree().create_timer(0.3).timeout

## Somewhere a few metres off, on the other side of the meat.
func _behind_a_wall() -> Vector3:
	var a := randf() * TAU
	return player.global_position + Vector3(cos(a) * randf_range(3.0, 6.0), randf_range(0.5, 2.2), sin(a) * randf_range(3.0, 6.0))

func begin() -> void:
	Sfx.loop("drone", "flesh_drone", -10.0)
	Sfx.loop("heart", "heart_loop", -26.0)
	Fx.reset({"grain": 0.08, "vignette": 0.62, "fringe": 0.25, "drain": 0.08})
	if not get_meta("from_checkpoint", false):
		await _come_out()
	else:
		player.set_view(PI, 0.0)
		Game.fade(0.0, 1.0)
	Game.checkpoint()
	random_talk = true
	set_cutscene(false)
	objective("Find the way out.")
	if not Game.flag("torch_hint"):
		Game.set_flag("torch_hint")
		hud.hint("LIGHT / F: torch. She'll see it too." if Game.uses_touch() else "F: torch. She'll see it too.")

## He slides out of the wall onto the floor, in goo, and gets up.
func _come_out() -> void:
	set_cutscene(true)
	socko.visible = true; socko.hold = "low"; socko.emotion = "nervous"
	var end := player.position
	player.position = end + Vector3(0, 0.1, -1.2)
	player.head_override = 0.35
	player.set_view(PI, -0.3)
	Sfx.play("squelch", 2.0, 0.7)
	Game.fade(0.0, 2.5)
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(player, "position", end, 1.3)
	await tw.finished
	Sfx.play("thud", -6.0)
	player.shake(0.02, 0.3)
	await get_tree().create_timer(1.0).timeout
	player.head_override = -1.0
	await player.look_toward(cell_pos(3, 3, 1.4), 1.6)
	socko.hold = "out"; socko.emotion = "neutral"

func _process(delta: float) -> void:
	super(delta)
	if not marta: return
	if not _encountered and not cutscene and (player_sees(marta_head.global_position, 10.0, 0.55) or marta.state == "chase"):
		_encounter()
	# Socko follows her, and is afraid of her
	if _encountered and not Dialogue.busy:
		if marta.state == "chase": socko.emotion = "nervous"; socko.look = "marta"
		elif socko.look == "marta" and marta.state == "patrol": socko.look = "ahead"; socko.emotion = "neutral"
	random_talk = marta.state == "patrol" and not _ending
	# how near she is: the heartbeat, the edges of the picture, the torch
	var d := marta.global_position.distance_to(player.global_position)
	var near := clampf(1.0 - (d - 2.0) / 12.0, 0.0, 1.0)
	if marta.state == "chase": near = maxf(near, 0.7)
	_near = lerpf(_near, near, 1.0 - exp(-2.0 * delta))
	Sfx.set_loop_volume("heart", lerpf(-26.0, -4.0, _near))
	Fx.set_k("pulse", _near * 0.55)
	Fx.set_k("fringe", 0.25 + _near * 0.9)
	Fx.set_k("tear", 0.25 if marta.state == "chase" else _near * 0.08)
	player.torch_flicker = smoothstep(0.45, 1.0, _near)

func _on_spotted() -> void:
	if not _encountered: _encounter()

## The first time they see each other she stops, and looks at him, and clicks.
func _encounter() -> void:
	_encountered = true
	Game.set_flag("met_marta_maze")
	marta.set_state("encounter")
	Sfx.play("sting", -4.0, 0.9)
	Fx.kick("tear", 0.8, 1.2); Fx.kick("drain", 0.5, 2.0)
	await Dialogue.play("marta_maze")
	if marta.state == "encounter":
		marta._last_seen = player.global_position
		marta.set_state("chase")
		marta.go_to(player.global_position)

func on_event(n: String, _step: Dictionary) -> void:
	if n == "marta_clicks":
		for i in 6:
			Sfx.play_at("click", marta.head(), 4.0, randf_range(0.55, 0.8))
			await get_tree().create_timer(randf_range(0.08, 0.2)).timeout

## She has him. Back to the start of this place.
func _on_caught() -> void:
	set_cutscene(true)
	Dialogue.stop()
	random_talk = false
	socko.emotion = "nervous"; socko.gesture("recoil")
	await player.look_toward(marta.head(), 0.25)
	Sfx.play("gasp", 2.0, 0.9)
	player.shake(0.05, 0.6)
	var tw := create_tween(); tw.tween_property(player, "global_position", marta.global_position, 0.5)
	await get_tree().create_timer(0.45).timeout
	Sfx.play("thud", 4.0, 0.7)
	await Game.fade(1.0, 0.1)
	await get_tree().create_timer(1.2).timeout
	Game.restart_level()

## Through her front door, onto the landing. 48 is open.
func _finale() -> void:
	if _ending: return
	_ending = true
	marta.active = false
	set_cutscene(true)
	Dialogue.stop()
	socko.look = "ahead"; socko.emotion = "curious"
	await player.look_toward(Vector3(exit_door.global_position.x + 0.475, 1.5, exit_door.global_position.z + CELL + 3.5), 1.5)
	var tw := create_tween(); tw.tween_property(player, "global_position", player.global_position + Vector3(0, 0, 1.2), 2.5)
	await get_tree().create_timer(2.0).timeout
	Game.set_flag("flat47_done")
	Game.checkpoint()
	await Game.end_chapter("Flat 48", "")
