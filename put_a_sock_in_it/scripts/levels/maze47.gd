extends Level
## Level 2: the maze. Flat 47 come apart and grown back wrong: its rooms, its wallpaper and tiles
## and parquet, its cupboards and its bath, rearranged into a labyrinth and gone to the blue meat
## of the hole. Kurt comes out of the hole in the wall at one corner; 48's door stands open at
## the other. Marta hunts it.
##
## The plan is a Maze (scripts/world/maze.gd): a grid of 3 m cells, each wearing one of the flat's
## rooms. Built here from the flat's own pieces (ExportedFlat in kit mode): every wall face wears
## its cell's room; doorways where one room gives on to another, with a casing and an open door;
## the flat's furniture as landmarks; steady lights.
##
## Safe rooms: three pockets of the flat as it was (no meat, a warm lamp, a chair). She won't go in
## and can't see in (MartaHunter.refuge); each is a checkpoint, and the first time he reaches one,
## the infection grows (a skill point). Caught: back to the last one reached.

const CELL := 3.0
const T := 0.14              # wall thickness
const H := 2.7               # ceiling
const DOOR_W := 1.0
const DOOR_H := 2.1
const SEED := 4747
const NAV := 0.5             # her grid
## The flat gone to meat the colour of the hole.
const BLUE := {"meat_dark": Color(0.05, 0.08, 0.26), "meat_light": Color(0.24, 0.42, 0.86), "meat_vein": Color(0.04, 0.02, 0.2),
	"meat_glow": Vector3(0.05, 0.12, 0.45), "paint_tint": Vector3(0.62, 0.72, 1.0), "glass": Color(0.5, 0.6, 1.0, 1.0)}
## Each zone wears one of the flat's rooms: [wall, floor, ceiling] from the export.
const ROOMS := {"hall": "hall", "living": "living", "kitchen": "kitchen", "bath": "bath", "child": "child",
	"bedroom": "bedroom", "storage": "storage", "safe": "bedroom"}
## The flat's furniture, by the room it lives in (names in the export).
const FURN := {
	"living": ["Node28", "Mesh448", "prop_9_Chair", "prop_36_Standard_lamp"],
	"kitchen": ["Node114", "Node109", "Node102", "prop_61_Stool"],
	"bath": ["Node141"],
	"child": ["Node135", "Node137", "prop_80_Chair"],
	"bedroom": ["prop_34_Wardrobe", "Mesh882"],
	"storage": ["Mesh892", "prop_10_Chair"],
	"hall": ["prop_34_Wardrobe"],
}

var maze := Maze.new()
var kits: Array = []            # the flat, fleshed: lightly near the hole, deep by 48's door
var kit: ExportedFlat           # (the middle one)
var _tier := {}                 # cell -> 0..2: which of the kits it wears
var kit_home: ExportedFlat      # the flat as it was (the safe rooms)
var marta: MartaHunter
var marta_head: Node3D
var exit_door: Door
var _chunks := {}               # [chunk, material] -> SurfaceTool
var _surf := {}                 # theme + part -> [material, uv]
var _solids: Array = []         # Rect2 in x/z: walls, posts, furniture (her grid)
var _walls: StaticBody3D
var _encountered := false
var _seen_evolved := false
var _evolved := false
var _ending := false
var _near := 0.0
var _visited := {}
var _since_new := 0.0
var _hints := 0
var _safe_reached := {}
var _in_safe := -1

# ------------------------------------------------------------------ build
func build() -> void:
	var e := env.environment
	e.background_mode = Environment.BG_COLOR; e.background_color = Color("03061a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("34406e"); e.ambient_light_energy = 0.35
	e.fog_enabled = true; e.fog_light_color = Color("0a1030"); e.fog_density = 0.04
	e.tonemap_mode = Environment.TONE_MAPPER_ACES; e.tonemap_exposure = 1.25
	for fl in [0.3, 0.55, 0.85]:
		var k := ExportedFlat.new(fl, [], true); k.meat = BLUE; world.add_child(k); kits.append(k)
	kit = kits[1]
	kit_home = ExportedFlat.new(0.0, [], true); world.add_child(kit_home)
	maze.generate_good(SEED)
	# how far each cell is from the hole, walking: the further, the deeper the meat
	var far := 1
	var dist := {}
	for y in maze.h:
		for x in maze.w:
			var c := Vector2i(x, y)
			dist[c] = maze.route(maze.start, c).size(); far = maxi(far, dist[c])
	for c in dist: _tier[c] = clampi(int(float(dist[c]) / float(far) * 3.0), 0, 2)
	_walls = StaticBody3D.new(); _walls.name = "MazeWalls"; world.add_child(_walls)
	_walls.set_meta("surface", "wood")
	_floors()
	_edges()
	_posts()
	_commit()
	_furniture()
	_lights()
	_safe_rooms()
	_arrival_hole()
	_exit()
	_ammo()
	_hiding()
	_batteries()
	_marta()
	Sfx.set_room(0.85, 0.38, 0.4)
	ambient([2.0, 5.0], func(): Sfx.play_at("drip", player.global_position + Vector3(randf_range(-3, 3), 2.3, randf_range(-3, 3)), -8.0, randf_range(0.6, 0.8)))
	ambient([12.0, 25.0], func(): Sfx.play_at("whisper", _behind_a_wall(), -4.0, randf_range(0.7, 1.0)), 8.0)
	ambient([20.0, 40.0], func(): Sfx.play_at("groan", _behind_a_wall(), -2.0, randf_range(0.6, 0.9)), 15.0)
	ambient([7.0, 15.0], func(): Sfx.play_at("squelch", _behind_a_wall(), -8.0, randf_range(0.5, 0.8)))

func ao_area() -> Array:
	return [Rect2(-1.0, -1.0, maze.w * CELL + 2.0, maze.h * CELL + 2.0), 0.0, H]

func ao_name() -> String: return "maze47"

func centre(c: Vector2i, y := 0.0) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, y, (c.y + 0.5) * CELL)

## (tests) `n` cells in a straight line, each open to the next, none of them safe.
func straight(n: int) -> Array:
	for y in maze.h:
		for x in maze.w:
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var run := [Vector2i(x, y)]
				while run.size() < n:
					var nx: Vector2i = run.back() + d
					if not maze.inside(nx) or not maze.is_open(run.back(), nx) or maze.safe.has(nx) or maze.safe.has(run.back()): break
					run.append(nx)
				if run.size() == n: return run
	return []

func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))

## In a safe room (and not just in its doorway)?
func in_safe(p: Vector3) -> bool:
	var c := cell_of(p)
	if not maze.safe.has(c): return false
	var lx := p.x - c.x * CELL; var lz := p.z - c.y * CELL
	return lx > 0.25 and lx < CELL - 0.25 and lz > 0.25 and lz < CELL - 0.25

# ------------------------------------------------------------------ surfaces
func _surface(th: String, part: String, tier := 1) -> Array:
	var k := th + "/" + part + "/" + str(tier)
	if _surf.has(k): return _surf[k]
	var src: ExportedFlat = kit_home if th == "safe" else kits[tier]
	var room: String = ROOMS[th]
	var name: String = room + String({"wall": "-n", "floor": "-floor", "ceiling": "-ceiling"}[part])
	var m := src.surface_material(name)
	var uv := src.surface_uv(name)
	if m == null: m = Tex.mat("plaster"); uv = Vector4(1, -1, 0, 0)
	_surf[k] = [m, uv]
	return _surf[k]

func _st(at: Vector3, m: Material, tag := "") -> SurfaceTool:
	var key := [Vector2i(floori(at.x / (CELL * 2.0)), floori(at.z / (CELL * 2.0))), m, tag]
	if not _chunks.has(key):
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); _chunks[key] = st
	return _chunks[key]

## A quad facing along n: corners a, b, c, d in order round it, UVs given.
func _quad(st: SurfaceTool, p: Array, uv: Array, n: Vector3) -> void:
	var order := [0, 2, 1, 0, 3, 2] if (p[1] - p[0]).cross(p[3] - p[0]).dot(n) > 0.0 else [0, 1, 2, 0, 2, 3]
	for i in order:
		st.set_normal(n); st.set_uv(uv[i]); st.add_vertex(p[i])

## A vertical face along a horizontal line from `a` to `b` (x/z), from y0 to y1, facing n, in
## theme `th`'s wallpaper.
func _wall_face(th: String, a: Vector3, b: Vector3, y0: float, y1: float, n: Vector3) -> void:
	# (the tier of the cell the face is in: a little way in from the face)
	var s := _surface(th, "wall", int(_tier.get(cell_of((a + b) * 0.5 + n * 0.3), 1)))
	var uv: Vector4 = s[1]
	var along := (b - a).normalized()
	var ua := a.dot(along) * uv.x + uv.z; var ub := b.dot(along) * uv.x + uv.z
	var v0 := y0 * uv.y + uv.w; var v1 := y1 * uv.y + uv.w
	var p := [Vector3(a.x, y0, a.z), Vector3(b.x, y0, b.z), Vector3(b.x, y1, b.z), Vector3(a.x, y1, a.z)]
	_quad(_st((a + b) * 0.5, s[0]), p, [Vector2(ua, v0), Vector2(ub, v0), Vector2(ub, v1), Vector2(ua, v1)], n)

func _flat_face(th: String, part: String, x0: float, z0: float, x1: float, z1: float, y: float, up: bool) -> void:
	var s := _surface(th, part, int(_tier.get(cell_of(Vector3((x0 + x1) * 0.5, 0, (z0 + z1) * 0.5)), 1)))
	var uv: Vector4 = s[1]
	var p := [Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)]
	var u := func(q: Vector3): return Vector2(q.x * uv.x + uv.z, q.z * uv.y + uv.w)
	_quad(_st(Vector3((x0 + x1) * 0.5, y, (z0 + z1) * 0.5), s[0], part), p, [u.call(p[0]), u.call(p[1]), u.call(p[2]), u.call(p[3])], Vector3.UP if up else Vector3.DOWN)

func _solid(centre_p: Vector3, size: Vector3, surface := "wood") -> void:
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = size; cs.shape = b
	_walls.add_child(cs); cs.position = centre_p
	_solids.append(Rect2(centre_p.x - size.x * 0.5, centre_p.z - size.z * 0.5, size.x, size.z))

func _floors() -> void:
	for y in maze.h:
		for x in maze.w:
			var c := Vector2i(x, y); var th: String = maze.theme[c]
			_flat_face(th, "floor", x * CELL, y * CELL, (x + 1) * CELL, (y + 1) * CELL, 0.0, true)
			_flat_face(th, "ceiling", x * CELL, y * CELL, (x + 1) * CELL, (y + 1) * CELL, H, false)
	var fl := StaticBody3D.new(); fl.name = "MazeFloor"; world.add_child(fl); fl.set_meta("surface", "wood")
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(maze.w * CELL + 4, 0.2, maze.h * CELL + 4); cs.shape = b
	fl.add_child(cs); cs.position = Vector3(maze.w * CELL * 0.5, -0.1, maze.h * CELL * 0.5)

# ------------------------------------------------------------------ walls
## Every edge between cells (and round the outside): a wall, a doorway, a cracked wall, the exit,
## or nothing.
func _edges() -> void:
	for y in maze.h:
		for x in maze.w:
			var c := Vector2i(x, y)
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var n: Vector2i = c + d
				if maze.inside(n): _edge(c, n)
			if x == 0: _edge(c, null, Vector2i(-1, 0))
			if y == 0: _edge(c, null, Vector2i(0, -1))
			if x == maze.w - 1: _edge(c, null, Vector2i(1, 0))
			if y == maze.h - 1: _edge(c, null, Vector2i(0, 1))

func _edge_kind(a: Vector2i, b) -> String:
	if b == null: return "exit" if a == maze.exit and _exit_dir() == Vector2i(1, 0) and a.x == maze.w - 1 else "wall"
	for pr in maze.cracked:
		if (pr[0] == a and pr[1] == b) or (pr[0] == b and pr[1] == a): return "crack"
	if not maze.is_open(a, b): return "wall"
	var ta: String = maze.theme[a]; var tb: String = maze.theme[b]
	if ta == "safe" or tb == "safe" or ta != tb: return "door"
	return "open"

func _exit_dir() -> Vector2i:
	return Vector2i(1, 0)

## The edge on side `dir` of `a` (towards `b`, or out of the maze).
func _edge(a: Vector2i, b, dir := Vector2i.ZERO) -> void:
	if b != null: dir = (b as Vector2i) - a
	var kind := _edge_kind(a, b)
	if kind == "open": return
	# the edge line, its two ends, and which way each side faces
	var along: Vector3; var p0: Vector3; var p1: Vector3
	if dir.x != 0:
		var ex := (a.x + (1 if dir.x > 0 else 0)) * CELL
		p0 = Vector3(ex, 0, a.y * CELL); p1 = Vector3(ex, 0, (a.y + 1) * CELL); along = Vector3(0, 0, 1)
	else:
		var ez := (a.y + (1 if dir.y > 0 else 0)) * CELL
		p0 = Vector3(a.x * CELL, 0, ez); p1 = Vector3((a.x + 1) * CELL, 0, ez); along = Vector3(1, 0, 0)
	var nrm_a := -Vector3(dir.x, 0, dir.y)           # a's face looks back into a
	var th_a: String = maze.theme[a]
	var th_b: String = maze.theme[b] if b != null else th_a
	var s0 := p0 + along * T * 0.5; var s1 := p1 - along * T * 0.5
	var mid := (p0 + p1) * 0.5
	var spans := []              # [from, to, y0, y1]
	if kind == "wall":
		spans.append([s0, s1, 0.0, H])
	else:
		var g0 := mid - along * DOOR_W * 0.5; var g1 := mid + along * DOOR_W * 0.5
		spans.append([s0, g0, 0.0, H]); spans.append([g1, s1, 0.0, H]); spans.append([g0, g1, DOOR_H, H])
		# the jambs and the soffit, in a's room
		for g in [[g0, along], [g1, -along]]:
			var gp: Vector3 = g[0]
			_wall_face(th_a, gp - nrm_a * T * 0.5, gp + nrm_a * T * 0.5, 0.0, DOOR_H, g[1])
		_soffit(th_a, g0, g1, nrm_a)
		_casing(g0, g1, nrm_a, b != null)
		match kind:
			"door": _open_door(g0, g1, nrm_a, a, b)
			"crack": _crack(mid, along, nrm_a)
			"exit": pass
	for sp in spans:
		var f: Vector3 = sp[0]; var t: Vector3 = sp[1]
		_wall_face(th_a, f + nrm_a * T * 0.5, t + nrm_a * T * 0.5, sp[2], sp[3], nrm_a)
		if b != null: _wall_face(th_b, t - nrm_a * T * 0.5, f - nrm_a * T * 0.5, sp[2], sp[3], -nrm_a)
		var len := (t - f).length()
		if len > 0.01:
			var size := Vector3(T, sp[3] - sp[2], len) if dir.x != 0 else Vector3(len, sp[3] - sp[2], T)
			_solid((f + t) * 0.5 + Vector3(0, (sp[2] + sp[3]) * 0.5, 0), size)

func _soffit(th: String, g0: Vector3, g1: Vector3, n: Vector3) -> void:
	var a := g0 - n * T * 0.5; var b := g1 - n * T * 0.5; var c := g1 + n * T * 0.5; var d := g0 + n * T * 0.5
	var s := _surface(th, "wall", int(_tier.get(cell_of(g0 + n * 0.3), 1))); var uv: Vector4 = s[1]
	var pts := [Vector3(a.x, DOOR_H, a.z), Vector3(b.x, DOOR_H, b.z), Vector3(c.x, DOOR_H, c.z), Vector3(d.x, DOOR_H, d.z)]
	var u := func(q: Vector3): return Vector2((q.x + q.z) * uv.x, 0.0)
	_quad(_st(g0, s[0]), pts, [u.call(pts[0]), u.call(pts[1]), u.call(pts[2]), u.call(pts[3])], Vector3.DOWN)

var _trim: Material
## A painted casing round a doorway, both sides.
func _casing(g0: Vector3, g1: Vector3, n: Vector3, both: bool) -> void:
	if not _trim: _trim = DoorLeaf.materials(kit.conv, {})["trim"]
	var along := (g1 - g0).normalized()
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in ([1.0, -1.0] if both else [1.0]):
		var off: Vector3 = n * (T * 0.5 + 0.012) * s
		for g in [g0 - along * 0.035, g1 + along * 0.035]:
			MeshKit.box(st, g + off + Vector3(0, DOOR_H * 0.5 + 0.035, 0), Vector3(0.07, DOOR_H + 0.07, 0.07) * (Vector3(1, 1, 0.35) if along.x != 0 else Vector3(0.35, 1, 1)))
		MeshKit.box(st, (g0 + g1) * 0.5 + off + Vector3(0, DOOR_H + 0.035, 0), (along.abs() * (DOOR_W + 0.14) + Vector3(0, 0.07, 0) + n.abs() * 0.025))
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = _trim; world.add_child(mi)

## An open panel door, swung back against the wall on a's side.
func _open_door(g0: Vector3, g1: Vector3, n: Vector3, a: Vector2i, b) -> void:
	var hinge := Node3D.new(); world.add_child(hinge)
	hinge.position = g0 + n * (T * 0.5)
	var along := (g1 - g0).normalized()
	# leaf local +x runs from the hinge; turned to lie along the wall, opened into a
	var yaw := atan2(-along.z, along.x)
	hinge.rotation.y = yaw + (PI * 0.5 + 0.15) * (1.0 if along.cross(n).y > 0.0 else -1.0)
	var src: ExportedFlat = kit_home if (maze.theme[a] == "safe" or (b != null and maze.theme[b] == "safe")) else kits[int(_tier[a])]
	DoorLeaf.build(hinge, DOOR_W - 0.06, DOOR_H - 0.03, "panel", src.conv, {})

func _crack(mid: Vector3, along: Vector3, n: Vector3) -> void:
	var w := CrackedWall.make(world, mid + Vector3(0, DOOR_H * 0.5, 0), Vector3(DOOR_W, DOOR_H, 0.1), atan2(-along.z, along.x))
	w.set_meta("in_maze", true)

## Posts at the corners where walls meet, covering their ends.
func _posts() -> void:
	for vy in maze.h + 1:
		for vx in maze.w + 1:
			var p := Vector3(vx * CELL, 0, vy * CELL)
			var th := ""
			for c in [Vector2i(vx - 1, vy - 1), Vector2i(vx, vy - 1), Vector2i(vx - 1, vy), Vector2i(vx, vy)]:
				if maze.inside(c): th = maze.theme[c]; break
			# a post wherever an edge meeting here isn't open
			var touched := false
			var cells := [Vector2i(vx - 1, vy - 1), Vector2i(vx, vy - 1), Vector2i(vx - 1, vy), Vector2i(vx, vy)]
			for pr in [[cells[0], cells[1]], [cells[2], cells[3]], [cells[0], cells[2]], [cells[1], cells[3]]]:
				var ia := maze.inside(pr[0]); var ib := maze.inside(pr[1])
				if ia != ib: touched = true
				elif ia and ib and _edge_kind(pr[0], pr[1]) != "open": touched = true
			if not touched: continue
			var hh := T * 0.5
			for f in [[Vector3(-hh, 0, hh), Vector3(hh, 0, hh), Vector3(0, 0, 1)], [Vector3(hh, 0, -hh), Vector3(-hh, 0, -hh), Vector3(0, 0, -1)],
					[Vector3(hh, 0, hh), Vector3(hh, 0, -hh), Vector3(1, 0, 0)], [Vector3(-hh, 0, -hh), Vector3(-hh, 0, hh), Vector3(-1, 0, 0)]]:
				_wall_face(th, p + f[0], p + f[1], 0.0, H, f[2])
			_solid(p + Vector3(0, H * 0.5, 0), Vector3(T, H, T))

func _commit() -> void:
	for key in _chunks:
		var st: SurfaceTool = _chunks[key]
		var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = key[1]
		if key[2] == "ceiling": mi.name = "Ceiling"; mi.add_to_group("maze_ceiling")
		world.add_child(mi)
	_chunks = {}

# ------------------------------------------------------------------ furniture, lights
func _furniture() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = SEED + 1
	for y in maze.h:
		for x in maze.w:
			var c := Vector2i(x, y)
			var th: String = maze.theme[c]
			if c == maze.start or c == maze.exit or th == "safe" or not FURN.has(th): continue
			if maze.exits_of(c) > 2 or rng.randf() > 0.7: continue
			var list: Array = FURN[th]
			_place_piece(kits[int(_tier[c])], String(list[rng.randi() % list.size()]), c, rng)

## A piece of the flat against one of the cell's walls.
func _place_piece(src: ExportedFlat, name: String, c: Vector2i, rng: RandomNumberGenerator, side = null) -> Node3D:
	var walls := []
	for d in Maze.DIRS:
		var n: Vector2i = c + d
		if not maze.inside(n) or _edge_kind(c, n) == "wall": walls.append(d)
	if walls.is_empty(): return null
	var d: Vector2i = side if side != null else walls[rng.randi() % walls.size()]
	var p := src.piece(name)
	if not p: return null
	var size: Vector3 = p.get_meta("size")
	# the long side along the wall
	var wall_along_x := d.y != 0
	var turn := (size.x < size.z) == wall_along_x
	p.rotation.y = PI * 0.5 if turn else 0.0
	var ext := Vector3(size.z, size.y, size.x) if turn else size
	var depth := ext.z if wall_along_x else ext.x
	var at := centre(c) + Vector3(d.x, 0, d.y) * (CELL * 0.5 - T * 0.5 - depth * 0.5 - 0.03)
	world.add_child(p); p.position = at
	if size.y > 0.2: _solid(at + Vector3(0, size.y * 0.5, 0), Vector3(ext.x, size.y, ext.z))
	return p

func _lights() -> void:
	for y in maze.h:
		for x in maze.w:
			var c := Vector2i(x, y)
			if maze.theme[c] == "safe" or (x + 2 * y) % 3 != 0: continue
			_bulb(centre(c, H - 0.32), Color("a9c2ff"), 1.1, 5.0)

func _bulb(at: Vector3, col: Color, energy: float, range_m: float) -> Fitting:
	var f := Fitting.make(world, at, col, energy, range_m, "steady", false)
	var g := Build.box(world, at, Vector3(0.05, 0.07, 0.05), Tex.mat("enamel", 1.0, {"emission": Vector3(col.r, col.g, col.b) * 1.3}), false)
	f.add_glow(g, Vector3(col.r, col.g, col.b) * 1.3)
	Build.box(world, at + Vector3(0, (H - at.y) * 0.5 + 0.035, 0), Vector3(0.01, H - at.y - 0.07, 0.01), Tex.mat("black"), false)
	return f

# ------------------------------------------------------------------ safe rooms
func _safe_rooms() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = SEED + 2
	for i in maze.safe.size():
		var c: Vector2i = maze.safe[i]
		_bulb(centre(c, H - 0.45), Color("ffcf8a"), 1.8, 5.0)
		_place_piece(kit_home, "prop_9_Chair", c, rng)
		_place_piece(kit_home, "prop_36_Standard_lamp", c, rng)
		var a := Pickup.new(); a.item = "ammo"; a.amount = 2; a.label = "box of rounds"
		world.add_child(a); a.position = centre(c, 0.05) + Vector3(0.6, 0, 0.6)
		var mi := MeshInstance3D.new(); mi.mesh = Build.box_mesh(Vector3(0.14, 0.08, 0.1)); mi.material_override = Tex.mat("cardboard", 8.0)
		a.add_child(mi)
		var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(0.3, 0.2, 0.3); cs.shape = sh; a.add_child(cs)

func _safe_index(c: Vector2i) -> int:
	return maze.safe.find(c)

# ------------------------------------------------------------------ the way in, the way out
func _arrival_hole() -> void:
	var c := maze.start
	var at := Vector3(T * 0.5 + 0.02, 0.95, centre(c).z)       # in the west wall of the first cell
	var m := ShaderMaterial.new(); m.shader = preload("res://shaders/ps1_double.gdshader")
	m.set_shader_parameter("albedo_tex", RotTextures.get_tex("gums")); m.set_shader_parameter("uv_scale", Vector2(3, 3))
	m.set_shader_parameter("pulse", 0.012); m.set_shader_parameter("emission", Vector3(0.2, 0.35, 1.0))
	m.set_shader_parameter("albedo_color", Color(0.5, 0.6, 1.4))
	Build.organic(world, func(st):
		for i in 26:
			var a := TAU * i / 26.0
			MeshKit.blob(st, at + Vector3(0, sin(a) * 0.9, cos(a) * 0.36), Vector3(0.1, 0.13, 0.11), {"bumps": 0.3, "seed": float(i)}), m)
	var goo := ShaderMaterial.new(); goo.shader = preload("res://shaders/goo.gdshader")
	Build.organic(world, func(st): MeshKit.blob(st, Vector3(0.75, 0.0, at.z), Vector3(0.6, 0.015, 0.8), {"bumps": 0.3, "freq": 3.0}), goo)
	Build.lamp(world, Vector3(0.6, 0.8, at.z), Color("5a7aff"), 1.0, 3.0)

## 48: its door, padded like 47's, standing open in the far wall, lit warm from inside.
func _exit() -> void:
	var c := maze.exit
	var ex := maze.w * CELL
	var z := centre(c).z
	exit_door = Door.new(); exit_door.width = DOOR_W - 0.06; exit_door.height = DOOR_H - 0.03; exit_door.locked = true
	exit_door.style = "padded"; exit_door.conv = kit_home.conv
	exit_door.leaf_opts = {"number": 48, "outside": 1.0, "vinyl": Color("4e3a2c")}
	exit_door.open_angle = -1.3; exit_door.is_open = true
	world.add_child(exit_door); exit_door.position = Vector3(ex + T * 0.5, 0, z + (DOOR_W - 0.06) * 0.5); exit_door.rotation.y = PI * 0.5
	Build.box(world, Vector3(ex + 1.6, 1.2, z), Vector3(0.1, 2.4, 1.8), Tex.mat("plaster", 1.0, {"emission": Vector3(2.0, 1.7, 1.2)}), false)
	Build.box(world, Vector3(ex + 0.8, -0.05, z), Vector3(1.6, 0.1, 1.4), Tex.mat("parquet", 1.0), true)
	Build.lamp(world, Vector3(ex + 0.9, 1.4, z), Color("ffe0b0"), 1.8, 5.0)
	var zone_a := Area3D.new(); zone_a.collision_layer = 0; zone_a.collision_mask = 2
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(1.0, 2.0, 1.4); cs.shape = sh
	zone_a.add_child(cs); world.add_child(zone_a); zone_a.position = Vector3(ex + 0.7, 1.0, z)
	zone_a.body_entered.connect(func(b): if b == player: _finale())

func _ammo() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = SEED + 3
	var dead := []
	for y in maze.h:
		for x in maze.w:
			var c := Vector2i(x, y)
			if maze.exits_of(c) == 1 and not maze.safe.has(c) and c != maze.start and c != maze.exit: dead.append(c)
	for i in mini(2, dead.size()):
		var c: Vector2i = dead[rng.randi() % dead.size()]
		dead.erase(c)
		var a := Pickup.new(); a.item = "ammo"; a.amount = 3; a.label = "box of rounds"
		world.add_child(a); a.position = centre(c, 0.05) + Vector3(-0.5, 0, 0.4)
		var mi := MeshInstance3D.new(); mi.mesh = Build.box_mesh(Vector3(0.14, 0.08, 0.1)); mi.material_override = Tex.mat("cardboard", 8.0, {"tint": Color(0.7, 0.8, 0.6)})
		a.add_child(mi)
		var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(0.3, 0.2, 0.3); cs.shape = sh; a.add_child(cs)

## Wardrobes to hide in (HideSpot), along corridors and in dead ends away from the safe rooms:
## one or two in each part of the maze, never in the cell next to a safe room (no point).
var hide_spots: Array = []
func _hiding() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = SEED + 5
	var cand := []
	for y in maze.h:
		for x in maze.w:
			var c := Vector2i(x, y)
			if maze.safe.has(c) or c == maze.start or c == maze.exit or maze.exits_of(c) > 2: continue
			var by_safe := false
			for d in Maze.DIRS: if maze.safe.has(c + d): by_safe = true
			if by_safe: continue
			cand.append(c)
	for i in range(cand.size() - 1, 0, -1):          # (shuffled, but the same every time: the AO map is baked)
		var j := rng.randi_range(0, i); var tmp = cand[i]; cand[i] = cand[j]; cand[j] = tmp
	var used := []
	for c in cand:
		if used.size() >= 5: break
		var close := false
		for u in used: if Vector2(u - c).length() < 2.5: close = true
		if close: continue
		# against a wall, with nothing already on it
		var walls := []
		for d in Maze.DIRS:
			var n: Vector2i = c + d
			if not maze.inside(n) or _edge_kind(c, n) == "wall": walls.append(d)
		if walls.is_empty(): continue
		var d: Vector2i = walls[rng.randi() % walls.size()]
		var at := centre(c) + Vector3(d.x, 0, d.y) * (CELL * 0.5 - T * 0.5 - 0.3 - 0.04)
		var clear := true
		for r in _solids: if (r as Rect2).grow(0.1).has_point(Vector2(at.x, at.z)): clear = false
		if not clear: continue
		var w := HideSpot.new()
		world.add_child(w)
		w.position = at; w.rotation.y = atan2(-float(d.x), -float(d.y))
		var ext := Vector3(1.3, 2.1, 0.6) if d.y != 0 else Vector3(0.6, 2.1, 1.3)
		# (her grid keeps off it; the wardrobe is its own collider, so the hand can find it)
		_solids.append(Rect2(at.x - ext.x * 0.5, at.z - ext.z * 0.5, ext.x, ext.z))
		hide_spots.append(w); used.append(c)

## Torch batteries, in dead ends: the light is worth going out of your way for.
func _batteries() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = SEED + 6
	var dead := []
	for y in maze.h:
		for x in maze.w:
			var c := Vector2i(x, y)
			if maze.exits_of(c) == 1 and not maze.safe.has(c) and c != maze.start and c != maze.exit: dead.append(c)
	for i in mini(3, dead.size()):
		var c: Vector2i = dead[rng.randi() % dead.size()]
		dead.erase(c)
		var a := Pickup.new(); a.item = "battery"; a.amount = 1; a.label = "torch battery"
		world.add_child(a); a.position = centre(c, 0.05) + Vector3(0.45, 0, -0.35)
		var mi := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.017; cy.bottom_radius = 0.017; cy.height = 0.06
		mi.mesh = cy; mi.material_override = Tex.mat("metal", 1.0, {"tint": Color(0.75, 0.45, 0.2)}); mi.rotation.z = PI * 0.5; mi.position.y = 0.017
		a.add_child(mi)
		var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(0.3, 0.2, 0.3); cs.shape = sh; a.add_child(cs)

# ------------------------------------------------------------------ her
func nav_grid() -> AStarGrid2D:
	var g := AStarGrid2D.new()
	var gw := int(ceil(maze.w * CELL / NAV)); var gh := int(ceil(maze.h * CELL / NAV))
	g.region = Rect2i(0, 0, gw, gh); g.cell_size = Vector2(NAV, NAV)
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.update()
	for y in gh:
		for x in gw:
			var p := Vector2((x + 0.5) * NAV, (y + 0.5) * NAV)
			var solid := maze.safe.has(Vector2i(floori(p.x / CELL), floori(p.y / CELL)))
			if not solid:
				for r in _solids:
					if (r as Rect2).grow(0.28).has_point(p): solid = true; break
			if solid: g.set_point_solid(Vector2i(x, y), true)
	return g

func _marta() -> void:
	marta = MartaHunter.new(); marta.player = player
	world.add_child(marta)
	marta_head = Node3D.new(); marta.add_child(marta_head); marta_head.position.y = 1.7
	marta.caught_player.connect(_on_caught)
	marta.listening.connect(func(_sp):
		hud.hint("She's at the doors. Hold your breath: hold BREATH." if Game.uses_touch() else "She's at the doors. Hold your breath: hold B.", 5.0))
	marta.spotted_player.connect(_on_spotted)
	marta.state_changed.connect(func(s): if s == "stunned": Game.run.stuns += 1)
	marta.state_changed.connect(func(s): if s == "stunned" and not Game.flag("first_stun"): Game.set_flag("first_stun"); Skills.award("infection", 1, "you hurt her"))
	marta.refuge = in_safe
	marta.grid = nav_grid(); marta.cell = NAV; marta.origin = Vector3.ZERO
	var tour := []
	var rng := RandomNumberGenerator.new(); rng.seed = SEED + 4
	var cells := []
	for y in maze.h:
		for x in maze.w:
			var c := Vector2i(x, y)
			if not maze.safe.has(c) and c != maze.start: cells.append(c)
	for i in 10: tour.append(centre(cells[rng.randi() % cells.size()]))
	marta.patrol = tour
	_place_marta()
	socko.points = {"marta": marta_head}

## Somewhere well away from him, out of sight.
func _place_marta() -> void:
	var far: Vector2i = maze.path[int(maze.path.size() * 0.6)]
	if player and player.global_position.distance_to(centre(far)) < CELL * 3.0: far = maze.path[maze.path.size() - 2]
	marta.global_position = centre(far)
	marta.revive()
	marta.active = true
	marta.set_state("patrol"); marta.go_to(marta.patrol[0])

func _behind_a_wall() -> Vector3:
	var a := randf() * TAU
	return player.global_position + Vector3(cos(a) * randf_range(3.0, 6.0), randf_range(0.5, 2.2), sin(a) * randf_range(3.0, 6.0))

# ------------------------------------------------------------------ the story
func begin() -> void:
	Sfx.loop("drone", "flesh_drone", -10.0)
	Sfx.loop("heart", "heart_loop", -26.0)
	Fx.reset({"grain": 0.08, "vignette": 0.62, "fringe": 0.2, "drain": 0.08})
	Fx.tint(Color(0.55, 0.7, 1.0, 0.25), 0.01)
	var at := int(Game.flags.get("maze_safe", -1)) if get_meta("from_checkpoint", false) else -1
	if at < 0:
		Game.flags.erase("maze_safe")
		player.global_position = centre(maze.start) + Vector3(-0.6, 0, 0)
		player.set_view(-PI * 0.5, 0.0)
		await _come_out()
	else:
		_encountered = Game.flag("met_marta_maze")
		var c: Vector2i = maze.safe[at]
		player.global_position = centre(c); player.set_view(_facing_door(c), 0.0)
		_safe_reached[at] = true
		Game.fade(0.0, 1.0)
	Game.checkpoint()
	random_talk = true
	set_cutscene(false)
	objective("Find the way out.")
	if at < 0: Dialogue.play("enter_maze")
	if not Game.flag("torch_hint"):
		Game.set_flag("torch_hint")
		hud.hint("LIGHT / F: torch. She'll see it too." if Game.uses_touch() else "F: torch. She'll see it too.")

func _facing_door(c: Vector2i) -> float:
	for n in maze.neighbours(c):
		var d: Vector3 = centre(n) - centre(c)
		return atan2(-d.x, -d.z)
	return 0.0

## He slides out of the hole in the wall, in goo, and gets up.
func _come_out() -> void:
	set_cutscene(true)
	socko.visible = true; socko.hold = "low"; socko.emotion = "nervous"
	var end := player.global_position
	player.global_position = Vector3(0.25, 0.1, end.z)
	player.head_override = 0.35
	player.set_view(-PI * 0.5, -0.3)
	Sfx.play("squelch", 2.0, 0.7)
	Game.fade(0.0, 2.5)
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(player, "global_position", end, 1.3)
	await tw.finished
	Sfx.play("thud", -6.0)
	player.shake(0.02, 0.3)
	await get_tree().create_timer(1.0).timeout
	player.head_override = -1.0
	await player.look_toward(centre(maze.path[1], 1.3), 1.6)
	socko.hold = "out"; socko.emotion = "neutral"

func _process(delta: float) -> void:
	super(delta)
	if not marta or _ending: return
	# safe rooms: where he is
	var c := cell_of(player.global_position)
	var si := _safe_index(c) if in_safe(player.global_position) else -1
	if si != _in_safe:
		_in_safe = si
		if si >= 0: _enter_safe(si)
	# getting lost: Socko knows which way smells better
	if not _visited.has(c): _visited[c] = true; _since_new = 0.0
	else: _since_new += delta
	if _since_new > 60.0 and _hints < 3 and not Dialogue.busy and not cutscene and marta.state != "chase":
		_since_new = 0.0; _hints += 1
		_point_the_way()
	# her
	if not _encountered and not cutscene and marta.state != "dead" and (player_sees(marta_head.global_position, 10.0, 0.55) or marta.state == "chase"):
		_encounter()
	if _encountered and _evolved and not _seen_evolved and not cutscene and player_sees(marta_head.global_position, 10.0, 0.55):
		_seen_evolved = true
		Dialogue.play("marta_evolved_c")
	if _encountered and not Dialogue.busy:
		if marta.state == "chase": socko.emotion = "nervous"; socko.look = "marta"
		elif socko.look == "marta" and marta.state == "patrol": socko.look = "ahead"; socko.emotion = "neutral"
	random_talk = marta.state == "patrol" or marta.state == "dead"
	var near := 0.0
	if marta.state != "dead":
		var d := marta.global_position.distance_to(player.global_position)
		near = clampf(1.0 - (d - 2.0) / 10.0, 0.0, 1.0)
		if marta.state == "chase": near = maxf(near, 0.7)
	_near = lerpf(_near, near, 1.0 - exp(-2.0 * delta))
	Sfx.set_loop_volume("heart", lerpf(-26.0, -4.0, _near))
	Fx.set_k("pulse", _near * 0.55)
	Fx.set_k("fringe", 0.2 + _near * 0.9)
	Fx.set_k("tear", 0.25 if marta.state == "chase" else _near * 0.08)
	player.torch_flicker = smoothstep(0.45, 1.0, _near)
	# Observant: her sounds tell him where she is
	if Skills.has("m_observe") and marta.state != "dead":
		_ping_t -= delta
		if _ping_t <= 0.0 and marta.global_position.distance_to(player.global_position) < 12.0 and not player_sees(marta_head.global_position, 12.0, 0.6):
			_ping_t = 2.5
			hud.ping(marta_head.global_position)
var _ping_t := 0.0

## Reaching a safe room: she can't follow; a checkpoint; the first time, the infection grows. The
## first time of all, Socko says what it is; if she was right behind him, he says so.
func _enter_safe(i: int) -> void:
	var chased := marta.state == "chase"
	if not _safe_reached.has(i):
		_safe_reached[i] = true
		Game.flags["maze_safe"] = i
		Skills.award("infection", 1, "the flesh")
		if marta.state == "dead" or (i >= 1 and marta.state != "chase"): _place_marta()
		if i == 1 and not _evolved and not player_sees(marta_head.global_position, 30.0, -1.0):
			_evolved = true; marta.evolve(2)
		Game.checkpoint()
		objective("Find the way out. The rooms that look like home are safe.")
		if i == 0 and not Dialogue.busy: Dialogue.play("safe_first")
	if chased and not Game.flag("safe_escape") and not Dialogue.busy:
		Game.set_flag("safe_escape"); Dialogue.play("safe_escape")

## Socko points the way: towards the next safe room he hasn't reached, or the way out.
func _point_the_way() -> void:
	var goal := maze.exit
	for i in maze.safe.size():
		if not _safe_reached.has(i): goal = maze.safe[i]; break
	var r := maze.route(cell_of(player.global_position), goal)
	if r.size() < 2: return
	socko.points["next"] = centre(r[1], 1.3)
	Dialogue.play("maze_hint_%d" % (1 + (_hints - 1) % 2))

func _on_spotted() -> void:
	if not _encountered: _encounter()

## The first time they see each other she stops, and looks at him, and clicks.
func _encounter() -> void:
	_encountered = true
	Game.set_flag("met_marta_maze")
	marta.active = true
	marta.set_state("encounter")
	Sfx.play("sting", -4.0, 0.9); nerve.spike(0.5)
	Fx.kick("tear", 0.8, 1.2); Fx.kick("drain", 0.5, 2.0)
	await Dialogue.play("marta_maze")
	if marta.state == "encounter":
		marta._last_seen = player.global_position
		marta.set_state("chase")
		marta.go_to(player.global_position)
	if not Dialogue.busy: Dialogue.play("marta_evolved_b")

func on_event(n: String, _step: Dictionary) -> void:
	if n == "marta_clicks":
		for i in 6:
			Sfx.play_at("click", marta.head(), 4.0, randf_range(0.55, 0.8))
			await get_tree().create_timer(randf_range(0.08, 0.2)).timeout

## She has him. Back to the last safe room reached.
func _on_caught() -> void:
	Game.run.caught += 1
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

## Through 48's door. The chapter ends.
func _finale() -> void:
	if _ending: return
	_ending = true
	marta.active = false
	set_cutscene(true)
	Dialogue.stop()
	socko.look = "ahead"; socko.emotion = "curious"
	var ex := maze.w * CELL
	await player.look_toward(Vector3(ex + 1.6, 1.4, centre(maze.exit).z), 1.2)
	var tw := create_tween(); tw.tween_property(player, "global_position", player.global_position + Vector3(0.8, 0, 0), 2.0)
	await get_tree().create_timer(1.6).timeout
	Game.set_flag("flat47_done")
	Game.checkpoint()
	Game.demo_over = bool(Game.demo.get("is_demo", false))
	await Game.end_chapter("Flat 48", "")
