class_name Town
extends Node3D
## Behind the wardrobe: Flat 47, gone wrong. Its rooms, over and over: the same faded mustard
## damask, the same parquet, the same plaster ceiling, a grid of rooms that goes on much further
## than the flat could, lit by panels that hum. Doorways where there shouldn't be, walls missing,
## the wardrobe again, the armchair again. A corridor along the top that comes round on itself
## (thirteen lights, and then the first one again).
##
## What the chapter needs is all here: the hole he came through (the corridor's north wall), the
## revolver (a room deep in the east), the flat's front door at the far south (bolted: the only
## way out), Room 4 (the porter), Sonya's door (the south-west corner), the Trickshot poster, rounds,
## loose bricks to throw, nuggets, and a table of ways through for anything that hunts him.
##
## Built to be light on a phone: one simple shader for everything (the flat's: no normal or
## roughness maps), the whole maze in sixteen-metre chunks of one mesh per material, a fixed budget
## of lit panels (the nearest few; the rest are emissive and cost nothing), fog, and nothing created
## or freed while he walks about. Local coordinates (the node sits far from the flat).

const CELL := 4.0                 ## a room
const W := 13                     ## rooms across
const H := 14                     ## rooms down (row 0 is the corridor that loops)
const WALL_H := 2.7
const DOOR_W := 1.1
const DOOR_H := 2.1
const THICK := 0.16
const CHUNK := 16.0
const LOOP := W * CELL

## The way out: the front door, in the south wall of room (EXIT_COL, H - 1).
const EXIT_COL := 6
const GATE_Z := H * CELL
const GATE_X0 := EXIT_COL * CELL + (CELL - 1.2) * 0.5
const GATE_X1 := GATE_X0 + 1.2
const EXIT_X := (GATE_X0 + GATE_X1) * 0.5

## Lit panels at once (the rest just glow): a phone keeps every mesh well under 8 lights.
const LAMPS_PHONE := 4
const LAMPS_DESKTOP := 9
const LAMP_RANGE := 14.0
const LIGHT_EVERY := 0.25

## Wall kinds between two rooms.
enum { SOLID, DOOR, OPEN }

var revolver_at := Vector3.ZERO
var revolver_mesh: Node3D
var revolver_spot: Hotspot
var marta_post := Vector3(EXIT_X, 0, GATE_Z - 1.8)
var marta_away := Vector3(2.0 * CELL + 2.0, 0, 6.0 * CELL + 2.0)
var marta_patrol: Array[Vector3] = []
var gate: Node3D
var gate_body: StaticBody3D
var gate_open := false
var gate_glow: OmniLight3D
var lever: Node3D
var lever_spot: Hotspot
var chalk: Array[Node3D] = []
var pickups: Array = []
var nuggets: Array[Node3D] = []
const NURSERY_CELL := Vector2i(0, 13)
var nursery := Rect2(NURSERY_CELL.x * CELL, NURSERY_CELL.y * CELL, CELL, CELL)
var nursery_center := Vector3(NURSERY_CELL.x * CELL + 2.0, 1.2, NURSERY_CELL.y * CELL + 2.0)
const PORTER_CELL := Vector2i(2, 8)
var porter_home := Vector3(PORTER_CELL.x * CELL + 2.6, 0.0, PORTER_CELL.y * CELL + 1.4)
var porter_bounds := Rect2(PORTER_CELL.x * CELL + 0.3, PORTER_CELL.y * CELL + 0.3, CELL - 0.6, CELL - 0.6)
var lamplighter_path: Array[Vector3] = [Vector3(1.5 * CELL, 0, 2.0), Vector3((W - 1.5) * CELL, 0, 2.0)]
var lamplighter_bounds := Rect2(0.3, 0.3, LOOP - 0.6, CELL - 0.6)
var maze_bounds := Rect2(0.4, CELL + 0.4, LOOP - 0.8, (H - 1) * CELL - 0.8)
const REVOLVER_CELL := Vector2i(11, 6)
const POSTER_CELL := Vector2i(9, 12)
const ARRIVE_CELL := Vector2i(6, 0)
var arrive := Transform3D.IDENTITY
var hole_at := Vector3.ZERO
var env: Environment
var lamps: Array[OmniLight3D] = []
var built := false

## walls: _v[r][c] the wall on the west side of room (c, r) (c = 0..W), _h[r][c] the north side of
## room (c, r) (r = 0..H)
var _v := []
var _h := []
var _rng := RandomNumberGenerator.new()
var _tools := {}                 ## Vector2i chunk -> {material: SurfaceTool}
var _mats := {}
var _colliders: StaticBody3D
var _t := 0.0
var _light_t := 0.0
var _lit: Array[OmniLight3D] = []
var _hop := PackedInt32Array()

# --- building ---------------------------------------------------------------------------------------

func build_steps() -> Array[Callable]:
	var steps: Array[Callable] = []
	steps.append(func():
		_rng.seed = 47
		_materials()
		_colliders = StaticBody3D.new(); _colliders.name = "Walls"; add_child(_colliders)
		var floor_cs := CollisionShape3D.new(); var fb := BoxShape3D.new(); fb.size = Vector3(LOOP + 40.0, 1, H * CELL + 30.0)
		floor_cs.shape = fb; floor_cs.position = Vector3(LOOP * 0.5, -0.5, H * CELL * 0.5); _colliders.add_child(floor_cs)
		var ceil_cs := CollisionShape3D.new(); var cb := BoxShape3D.new(); cb.size = fb.size
		ceil_cs.shape = cb; ceil_cs.position = Vector3(LOOP * 0.5, WALL_H + 0.5, H * CELL * 0.5); _colliders.add_child(ceil_cs)
		_layout()
		return true)
	for r in H:
		steps.append(func():
			_build_row(r)
			return true)
	steps.append(func():
		_exit_lane()
		_hole()
		_corridor_ends()
		return true)
	steps.append(func():
		_furnish()
		_rooms()
		return true)
	steps.append(func():
		_revolver()
		_gate()
		_chalk()
		_pickups()
		return true)
	steps.append(func(): return _commit_some(24))
	steps.append(func():
		_environment()
		_route_table()
		var e := center(ARRIVE_CELL.x, ARRIVE_CELL.y)
		arrive = Transform3D(Basis(Vector3.UP, PI), e + Vector3(0, 0, -0.9))
		hole_at = e + Vector3(0, 0.9, -CELL * 0.5)
		built = true
		if OS.is_debug_build(): print("maze: ", _committed, " meshes, ", lamps.size(), " panels")
		return true)
	return steps

## Builds the maze a step a frame (the owner awaits this, behind the black).
func build_async() -> void:
	var steps := build_steps()
	var i := 0
	for step in steps:
		i += 1
		while not (step as Callable).call():
			await get_tree().process_frame
		if i % 5 == 0:
			Trail.mark("maze: built %d/%d" % [i, steps.size()])
		await get_tree().process_frame

## All at once (tests, tools).
func build() -> void:
	for step in build_steps():
		while not (step as Callable).call():
			pass

# --- the plan -----------------------------------------------------------------------------------------

func center(c: int, r: int) -> Vector3:
	return Vector3((c + 0.5) * CELL, 0, (r + 0.5) * CELL)

func cell_of(local: Vector3) -> Vector2i:
	return Vector2i(floori(local.x / CELL), floori(local.z / CELL))

func in_maze(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < W and c.y >= 0 and c.y < H

## Can you get from room a to the room next to it (one step n/s/e/w)?
func passable(a: Vector2i, b: Vector2i) -> bool:
	if not in_maze(a) or not in_maze(b):
		return false
	var d := b - a
	if d == Vector2i(1, 0): return _v[a.y][b.x] != SOLID
	if d == Vector2i(-1, 0): return _v[a.y][a.x] != SOLID
	if d == Vector2i(0, 1): return _h[b.y][a.x] != SOLID
	if d == Vector2i(0, -1): return _h[a.y][a.x] != SOLID
	return false

func _layout() -> void:
	_v = []; _h = []
	for r in H:
		var row := []
		for c in W + 1: row.append(SOLID)
		_v.append(row)
	for r in H + 1:
		var row := []
		for c in W: row.append(SOLID)
		_h.append(row)
	# the corridor: open end to end (and past both ends, where it comes round)
	for c in W + 1:
		_v[0][c] = OPEN
	# the maze below it: a winding tree of rooms (depth first), then walls knocked through
	var seen := {}
	var stack: Array[Vector2i] = [Vector2i(6, 7)]
	seen[stack[0]] = true
	while not stack.is_empty():
		var cur: Vector2i = stack.back()
		var next: Array[Vector2i] = []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if n.x >= 0 and n.x < W and n.y >= 1 and n.y < H and not seen.has(n):
				next.append(n)
		if next.is_empty():
			stack.pop_back()
			continue
		var n: Vector2i = next[_rng.randi() % next.size()]
		seen[n] = true
		_set_wall(cur, n, DOOR if _rng.randf() < 0.7 else OPEN)
		stack.append(n)
	# extra ways through (it should loop: something hunting him can come round behind)
	for r in range(1, H):
		for c in W:
			if c + 1 < W and _v[r][c + 1] == SOLID and _rng.randf() < 0.2:
				_v[r][c + 1] = DOOR if _rng.randf() < 0.6 else OPEN
			if r + 1 < H and _h[r + 1][c] == SOLID and _rng.randf() < 0.2:
				_h[r + 1][c] = DOOR if _rng.randf() < 0.6 else OPEN
	# a big room in the middle where the walls have gone
	for r in range(4, 7):
		for c in range(4, 8):
			if c > 4: _v[r][c] = OPEN
			if r > 4: _h[r][c] = OPEN
	# the corridor opens into the maze in three places only (well away from where it comes round)
	for c in [3, ARRIVE_CELL.x, 9]:
		_h[1][c] = DOOR
	# the rooms that matter have a door each, and the way out is a door
	_h[H][EXIT_COL] = DOOR
	# where Marta walks: a round of the southern rooms and back past the door
	marta_patrol = [marta_post, center(3, 11), center(2, 9), center(5, 9), center(9, 9), center(10, 11), center(8, 12)]

func _set_wall(a: Vector2i, b: Vector2i, kind: int) -> void:
	var d := b - a
	if d == Vector2i(1, 0): _v[a.y][b.x] = kind
	elif d == Vector2i(-1, 0): _v[a.y][a.x] = kind
	elif d == Vector2i(0, 1): _h[b.y][a.x] = kind
	elif d == Vector2i(0, -1): _h[a.y][a.x] = kind

# --- materials: the flat's ---------------------------------------------------------------------------

func _materials() -> void:
	_mats["wallpaper"] = Look.mat(Look.get_tex("wallpaper"), Color(1.0, 0.96, 0.82), 160.0)
	_mats["floor"] = Look.mat(Look.get_tex("parquet"), Color(0.78, 0.7, 0.58), 160.0)
	_mats["ceiling"] = Look.mat(Look.get_tex("plaster"), Color(0.86, 0.84, 0.74), 160.0)
	_mats["wood"] = Look.mat(Look.get_tex("wood"), Color.WHITE, 160.0)
	_mats["wood_light"] = Look.mat(Look.get_tex("wood_light"), Color.WHITE, 160.0)
	_mats["leather"] = Look.mat(Look.get_tex("leather"), Color.WHITE, 160.0)
	_mats["iron"] = Look.mat(Look.get_tex("iron"), Color(1.6, 1.6, 1.6), 160.0)
	_mats["paper"] = Look.mat(Look.get_tex("paper"), Color.WHITE, 160.0)
	_mats["panel"] = Look.mat(Look.get_tex("white"), Color(0.9, 0.88, 0.72), 160.0, false, Color(1.25, 1.2, 0.9))
	_mats["brick"] = Look.mat(Look.get_tex("rubble"), Color(0.8, 0.55, 0.45), 160.0)

func material(name: String) -> Material:
	return _mats[name]

## How many metres one repeat of each material's texture covers.
const REPEAT := {"wallpaper": 1.6, "floor": 1.6, "ceiling": 2.4, "wood": 1.2, "wood_light": 1.2, "leather": 0.8,
	"iron": 1.0, "paper": 0.6, "panel": 2.0, "brick": 0.6}

func _st(mat: String, at: Vector3) -> SurfaceTool:
	var key := Vector2i(floori(at.x / CHUNK), floori(at.z / CHUNK))
	if not _tools.has(key): _tools[key] = {}
	var d: Dictionary = _tools[key]
	if not d.has(mat):
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		d[mat] = st
	return d[mat]

## A quad a-b-c-d facing `n`, UVs in world metres; `lo` and `hi` darken toward the floor (a cheap
## bake of the grime that collects low on a wall).
func _quad(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, lo := 1.0, hi := 1.0) -> void:
	var st := _st(mat, (a + c) * 0.5)
	var rep: float = REPEAT.get(mat, 1.0)
	var ax := (b - a).normalized()
	var ay := n.cross(ax).normalized()
	var pts := [a, b, c, a, c, d]
	if (b - a).cross(c - a).dot(n) > 0.0:
		pts = [a, c, b, a, d, c]
	for p in pts:
		var q: Vector3 = p - Vector3.ZERO
		var k := lerpf(lo, hi, clampf(p.y / WALL_H, 0.0, 1.0))
		st.set_color(Color(k, k, k))
		st.set_normal(n)
		st.set_uv(Vector2(q.dot(ax), -q.dot(ay)) / rep)
		st.add_vertex(p)

## An axis-aligned box, centre and half size; faces as TownKit's (1 +x, 2 -x, 4 +y, 8 -y, 16 +z, 32 -z).
func box(mat: String, c: Vector3, h: Vector3, faces := 63, lo := 0.8, hi := 1.0) -> void:
	var x0 := c.x - h.x; var x1 := c.x + h.x; var y0 := c.y - h.y; var y1 := c.y + h.y; var z0 := c.z - h.z; var z1 := c.z + h.z
	if faces & 1: _quad(mat, Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3.RIGHT, lo, hi)
	if faces & 2: _quad(mat, Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3.LEFT, lo, hi)
	if faces & 4: _quad(mat, Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3.UP, hi, hi)
	if faces & 8: _quad(mat, Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3.DOWN, lo, lo)
	if faces & 16: _quad(mat, Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3.BACK, lo, hi)
	if faces & 32: _quad(mat, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3.FORWARD, lo, hi)

func _solid(c: Vector3, h: Vector3) -> void:
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = h * 2.0
	cs.shape = b; cs.position = c
	_colliders.add_child(cs)

## A box you can see and walk into.
func block(mat: String, c: Vector3, h: Vector3, faces := 63) -> void:
	box(mat, c, h, faces)
	_solid(c, h)

var _committed := 0
var _pending: Array = []
var _listed := false

func _commit_some(budget: int) -> bool:
	if not _listed:
		_listed = true
		for key in _tools:
			for mat in _tools[key]:
				_pending.append([key, mat])
	var n := 0
	while n < budget and not _pending.is_empty():
		var job: Array = _pending.pop_back()
		var st: SurfaceTool = _tools[job[0]][job[1]]
		st.index()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _mats[job[1]]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 40.0 if Game.is_phone() else 60.0
		add_child(mi)
		_tools[job[0]].erase(job[1])
		n += 1
		_committed += 1
	if _pending.is_empty():
		_tools.clear()
		return true
	return false

# --- the rooms -----------------------------------------------------------------------------------------

func _build_row(r: int) -> void:
	var cols := range(W)
	if r == 0:
		cols = range(-3, W + 3)      # the corridor runs on past both ends (where it comes round)
	for c in cols:
		var o := Vector3(c * CELL, 0, r * CELL)
		# floor and ceiling
		_quad("floor", o, o + Vector3(CELL, 0, 0), o + Vector3(CELL, 0, CELL), o + Vector3(0, 0, CELL), Vector3.UP, 0.85, 0.85)
		_quad("ceiling", o + Vector3(0, WALL_H, 0), o + Vector3(CELL, WALL_H, 0), o + Vector3(CELL, WALL_H, CELL), o + Vector3(0, WALL_H, CELL), Vector3.DOWN, 0.8, 0.8)
		# a light panel (most rooms), and the light that goes with it when he's near
		var dark := r > 0 and _rng.randf() < 0.14 and Vector2i(c, r) not in [REVOLVER_CELL, PORTER_CELL, NURSERY_CELL, POSTER_CELL, Vector2i(EXIT_COL, H - 1)]
		if not dark:
			var pc := o + Vector3(CELL * 0.5, WALL_H - 0.012, CELL * 0.5)
			_quad("panel", pc + Vector3(-0.6, 0, -0.3), pc + Vector3(0.6, 0, -0.3), pc + Vector3(0.6, 0, 0.3), pc + Vector3(-0.6, 0, 0.3), Vector3.DOWN)
			if c >= 0 and c < W:
				_panel_light(pc + Vector3(0, -0.25, 0))
		# walls: each room builds its west and north walls (the last column and row add the east
		# and south)
		var cc: int = c if (c >= 0 and c < W) else posmod(c, W)
		var kw: int = _v[r][cc] if (c >= 0 and c < W) else OPEN
		var kn: int = _h[r][cc] if (c >= 0 and c < W) else SOLID
		if r == 0 and (c < 0 or c >= W):
			kn = SOLID
		_wall_z(o.x, o.z, o.z + CELL, kw)                # west wall (runs along z)
		_wall_x(o.z, o.x, o.x + CELL, kn)                # north wall (runs along x)
		if c == W - 1 and r > 0:
			_wall_z(o.x + CELL, o.z, o.z + CELL, SOLID)  # the maze's east edge
		if r == H - 1:
			_wall_x(o.z + CELL, o.x, o.x + CELL, _h[H][c])
		if r == 0 and (c < 0 or c >= W):
			_wall_x(o.z + CELL, o.x, o.x + CELL, SOLID)  # under the corridor's runs past the ends

## A wall along z at x, from z0 to z1.
func _wall_z(x: float, z0: float, z1: float, kind: int) -> void:
	if kind == OPEN:
		box("wallpaper", Vector3(x, WALL_H - 0.15, (z0 + z1) * 0.5), Vector3(THICK * 0.5, 0.15, (z1 - z0) * 0.5), 1 | 2 | 8)
		return
	var segs := [[z0, z1]] if kind == SOLID else [[z0, (z0 + z1 - DOOR_W) * 0.5], [(z0 + z1 + DOOR_W) * 0.5, z1]]
	for s in segs:
		var cz: float = (s[0] + s[1]) * 0.5; var hz: float = (s[1] - s[0]) * 0.5
		block("wallpaper", Vector3(x, WALL_H * 0.5, cz), Vector3(THICK * 0.5, WALL_H * 0.5, hz), 1 | 2 | 16 | 32)
		box("wood", Vector3(x, 0.06, cz), Vector3(THICK * 0.5 + 0.015, 0.06, hz), 1 | 2 | 4)
	if kind == DOOR:
		var zc := (z0 + z1) * 0.5
		block("wallpaper", Vector3(x, (DOOR_H + WALL_H) * 0.5, zc), Vector3(THICK * 0.5, (WALL_H - DOOR_H) * 0.5, DOOR_W * 0.5), 1 | 2 | 8)
		for s in [-1.0, 1.0]:
			box("wood_light", Vector3(x, DOOR_H * 0.5, zc + s * (DOOR_W * 0.5 + 0.03)), Vector3(THICK * 0.5 + 0.02, DOOR_H * 0.5, 0.04))
		box("wood_light", Vector3(x, DOOR_H + 0.04, zc), Vector3(THICK * 0.5 + 0.02, 0.04, DOOR_W * 0.5 + 0.07))

## A wall along x at z, from x0 to x1.
func _wall_x(z: float, x0: float, x1: float, kind: int) -> void:
	if kind == OPEN:
		box("wallpaper", Vector3((x0 + x1) * 0.5, WALL_H - 0.15, z), Vector3((x1 - x0) * 0.5, 0.15, THICK * 0.5), 16 | 32 | 8)
		return
	var segs := [[x0, x1]] if kind == SOLID else [[x0, (x0 + x1 - DOOR_W) * 0.5], [(x0 + x1 + DOOR_W) * 0.5, x1]]
	for s in segs:
		var cx: float = (s[0] + s[1]) * 0.5; var hx: float = (s[1] - s[0]) * 0.5
		block("wallpaper", Vector3(cx, WALL_H * 0.5, z), Vector3(hx, WALL_H * 0.5, THICK * 0.5), 1 | 2 | 16 | 32)
		box("wood", Vector3(cx, 0.06, z), Vector3(hx, 0.06, THICK * 0.5 + 0.015), 16 | 32 | 4)
	if kind == DOOR:
		var xc := (x0 + x1) * 0.5
		block("wallpaper", Vector3(xc, (DOOR_H + WALL_H) * 0.5, z), Vector3(DOOR_W * 0.5, (WALL_H - DOOR_H) * 0.5, THICK * 0.5), 16 | 32 | 8)
		for s in [-1.0, 1.0]:
			box("wood_light", Vector3(xc + s * (DOOR_W * 0.5 + 0.03), DOOR_H * 0.5, z), Vector3(0.04, DOOR_H * 0.5, THICK * 0.5 + 0.02))
		box("wood_light", Vector3(xc, DOOR_H + 0.04, z), Vector3(DOOR_W * 0.5 + 0.07, 0.04, THICK * 0.5 + 0.02))

func _panel_light(at: Vector3) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.93, 0.72); l.light_energy = 1.1; l.light_specular = 0.0
	l.omni_range = 6.5; l.omni_attenuation = 1.4; l.shadow_enabled = false
	l.visible = false
	add_child(l); l.position = at
	lamps.append(l)

## Past the front door: a few metres of the landing's own floor, and then white.
func _exit_lane() -> void:
	var z0 := GATE_Z
	for x in [GATE_X0 - 0.9, GATE_X1 + 0.9]:
		block("wallpaper", Vector3(x, WALL_H * 0.5, z0 + 3.0), Vector3(0.6, WALL_H * 0.5, 3.0), 1 | 2)
	_quad("floor", Vector3(GATE_X0 - 0.3, 0, z0), Vector3(GATE_X1 + 0.3, 0, z0), Vector3(GATE_X1 + 0.3, 0, z0 + 6.0), Vector3(GATE_X0 - 0.3, 0, z0 + 6.0), Vector3.UP)
	var white := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(3.0, WALL_H); white.mesh = qm
	var wm := StandardMaterial3D.new(); wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.albedo_color = Color(1.4, 1.4, 1.45); wm.disable_fog = true
	white.material_override = wm
	add_child(white)
	white.position = Vector3(EXIT_X, WALL_H * 0.5, z0 + 5.8)
	white.rotation.y = PI
	gate_glow = OmniLight3D.new(); gate_glow.light_color = Color(0.9, 0.93, 1.0); gate_glow.light_energy = 1.0
	gate_glow.omni_range = 5.0; gate_glow.shadow_enabled = false
	add_child(gate_glow); gate_glow.position = Vector3(EXIT_X, 1.8, z0 + 4.8)

## The hole he came through: a ragged gap low in the corridor's north wall, black behind.
func _hole() -> void:
	var e := center(ARRIVE_CELL.x, ARRIVE_CELL.y)
	var z := e.z - CELL * 0.5 + THICK * 0.5 + 0.005
	var black := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(1.0, 1.4); black.mesh = qm
	var bm := StandardMaterial3D.new(); bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; bm.albedo_color = Color.BLACK
	black.material_override = bm; add_child(black)
	black.position = Vector3(e.x, 0.75, z)
	for i in 8:
		var s := _rng.randf_range(0.04, 0.09)
		box("brick", Vector3(e.x + _rng.randf_range(-0.8, 0.8), s * 0.5, z + _rng.randf_range(0.1, 0.7)), Vector3(s, s * 0.5, s * 0.7))

## The corridor's two ends are where it comes round: chalk on the floor there (with These Streets).
func _corridor_ends() -> void:
	pass

# --- what's in the rooms ---------------------------------------------------------------------------------

## The flat's furniture, again and again: the wardrobe, the armchair, a radiator, a chair.
func _furnish() -> void:
	for r in range(1, H):
		for c in W:
			var cell := Vector2i(c, r)
			if cell in [REVOLVER_CELL, PORTER_CELL, NURSERY_CELL, POSTER_CELL, Vector2i(EXIT_COL, H - 1)]:
				continue
			if r >= 4 and r <= 6 and c >= 4 and c <= 7:
				continue            # the big room stays empty
			var roll := _rng.randf()
			var o := Vector3(c * CELL, 0, r * CELL)
			# against whichever wall is solid
			var side := -1
			for s in 4:
				var k: int = [_v[r][c], _v[r][c + 1], _h[r][c], _h[r + 1][c]][s]
				if k == SOLID:
					side = s
					break
			if side < 0:
				continue
			var inward: Vector3 = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)][side]
			var wall_at := o + Vector3(CELL * 0.5, 0, CELL * 0.5) - inward * (CELL * 0.5 - THICK * 0.5)
			var along := Vector3(absf(inward.z), 0, absf(inward.x))
			var off := along * _rng.randf_range(-0.9, 0.9)
			if roll < 0.12:
				# the wardrobe
				var d := 0.3
				var hs := along * 0.5 + inward.abs() * d + Vector3(0, 1.0, 0)
				block("wood", wall_at + inward * d + off + Vector3(0, 1.0, 0), hs.abs())
			elif roll < 0.24:
				# the armchair
				var p := wall_at + inward * 0.5 + off
				block("leather", p + Vector3(0, 0.22, 0), Vector3(0.4, 0.22, 0.4))
				box("leather", p + Vector3(0, 0.55, 0) - inward * 0.32, (along * 0.4 + inward.abs() * 0.08 + Vector3(0, 0.33, 0)).abs())
			elif roll < 0.36:
				# a radiator under where a window would be
				var hs := (along * 0.5 + inward.abs() * 0.06 + Vector3(0, 0.3, 0)).abs()
				block("iron", wall_at + inward * 0.1 + off + Vector3(0, 0.42, 0), hs)
			elif roll < 0.42:
				# a chair, on its side
				var p := wall_at + inward * 1.2 + off
				box("wood_light", p + Vector3(0, 0.2, 0), Vector3(0.22, 0.2, 0.22))

## The rooms the chapter needs.
func _rooms() -> void:
	# Room 4: the porter's (a "4" on its door side), the photo strip on the wall
	var pr := center(PORTER_CELL.x, PORTER_CELL.y)
	_label("4", pr + Vector3(0, 2.25, -CELL * 0.5 + THICK * 0.5 + 0.01), 0.0, Color(0.85, 0.75, 0.45))
	block("wood_light", pr + Vector3(1.2, 0.4, 1.2), Vector3(0.5, 0.4, 0.3))          # a luggage stand
	box("leather", pr + Vector3(1.2, 0.92, 1.2), Vector3(0.36, 0.12, 0.22))           # her case on it
	var strip_at := pr + Vector3(-CELL * 0.5 + THICK * 0.5 + 0.02, 1.6, 0.3)
	box("paper", strip_at, Vector3(0.01, 0.14, 0.05))
	_examine(strip_at + Vector3(0.05, 0, 0), Vector3(0.06, 0.16, 0.08), "Photo strip",
		"Four frames from a booth, the kind they had at railway stations in the sixties. A man in a black domino mask and a woman with dark hair, laughing. In the third frame she's kissing his cheek. In the last one neither of them is laughing, and she's looking straight into the lens.",
		"On the back, in her hand: «T. and me. The last good night.» The T is the way she always made it, with the little hook. You'd forgotten you knew that.")
	# the poster, on the wall of a room near the door
	var po := center(POSTER_CELL.x, POSTER_CELL.y)
	var wall := po + Vector3(CELL * 0.5 - THICK * 0.5 - 0.01, 1.5, 0)
	if _v[POSTER_CELL.y][POSTER_CELL.x + 1] != SOLID:
		wall = po + Vector3(0, 1.5, -CELL * 0.5 + THICK * 0.5 + 0.01)
	box("paper", wall, Vector3(0.012, 0.42, 0.3) if wall.x != po.x else Vector3(0.3, 0.42, 0.012))
	_label("TRICKSHOT", wall + (Vector3(-0.02, 0.25, 0) if wall.x != po.x else Vector3(0, 0.25, 0.02)), -PI * 0.5 if wall.x != po.x else 0.0, Color(0.7, 0.12, 0.08))
	_examine(wall, Vector3(0.1, 0.45, 0.35) if wall.x != po.x else Vector3(0.35, 0.45, 0.1), "Poster",
		"Printed, in colour, on paper that wasn't made in this century. THE CHAMPION'S LEAGUE. TRICKSHOT. NEVER MISSES. The man on it is drawing a bow. You know how his shoulders feel.", "")
	# a few of the flat's papers, lying about
	for spot in [[Vector2i(4, 3), "Note", "A shopping list in Marta's hand: bread, salt, matches, the medicine. The medicine is underlined twice."],
			[Vector2i(8, 9), "Newspaper", "Pravda, folded to the weather. The date is torn off. The weather is the same every day."],
			[Vector2i(1, 5), "Drawing", "A child's crayon drawing of a house with too many rooms. Every window has a face in it."]]:
		var at := center(spot[0].x, spot[0].y) + Vector3(0.7, 0.01, 0.6)
		box("paper", at, Vector3(0.12, 0.004, 0.16))
		_examine(at + Vector3(0, 0.05, 0), Vector3(0.2, 0.08, 0.22), spot[1], spot[2], "")
	# Sonya's door, low in the corner room's west wall: СОНЯ, scratched at a child's height
	var nc := center(NURSERY_CELL.x, NURSERY_CELL.y)
	var dx := nc.x - CELL * 0.5 + THICK * 0.5 + 0.03
	box("wood", Vector3(dx, 0.75, nc.z), Vector3(0.03, 0.75, 0.42))
	box("iron", Vector3(dx + 0.04, 0.75, nc.z + 0.3), Vector3(0.02, 0.03, 0.03))
	_label("СОНЯ", Vector3(dx + 0.04, 0.95, nc.z), PI * 0.5, Color(0.25, 0.2, 0.18))
	var sd := StaticBody3D.new(); sd.set_script(load("res://scripts/labyrinth/sonya_door.gd"))
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(0.12, 1.5, 0.9); cs.shape = b; sd.add_child(cs)
	add_child(sd); sd.position = Vector3(dx + 0.05, 0.75, nc.z)

func _label(text: String, at: Vector3, yaw: float, color: Color, parent: Node3D = null) -> void:
	var l := Label3D.new(); l.text = text
	l.font_size = 48; l.pixel_size = 0.004; l.modulate = color; l.outline_size = 0
	l.shaded = false; l.double_sided = false; l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	(parent if parent else self).add_child(l)
	l.position = at
	l.rotation.y = yaw

func _examine(at: Vector3, half: Vector3, title: String, desc: String, more: String) -> void:
	var sb := StaticBody3D.new(); sb.set_script(load("res://scripts/labyrinth/examine.gd"))
	sb.set("title", title); sb.set("desc", desc); sb.set("more", more)
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = half * 2.0; cs.shape = b; sb.add_child(cs)
	add_child(sb); sb.position = at

# --- the revolver, on a table in a room deep in the east ----------------------------------------------------

func _revolver() -> void:
	var rc := center(REVOLVER_CELL.x, REVOLVER_CELL.y)
	block("wood", rc + Vector3(0, 0.38, 0), Vector3(0.45, 0.38, 0.3))
	revolver_at = rc + Vector3(0.05, 0.78, 0.02)
	revolver_mesh = Weapon.make_gun_model()
	add_child(revolver_mesh)
	revolver_mesh.transform = Transform3D(Basis(Vector3.UP, 0.7) * Basis(Vector3(0, 0, 1), PI * 0.5), revolver_at + Vector3(0, 0.018, 0))
	revolver_spot = Hotspot.make(self, global_transform * Transform3D(Basis(), revolver_at + Vector3(0, 0.12, 0)), Vector3(0.5, 0.35, 0.5), "Take")

# --- the way out: the flat's front door, bolted ----------------------------------------------------------

func _gate() -> void:
	gate = Node3D.new(); gate.name = "FrontDoor"; add_child(gate)
	gate.position = Vector3(GATE_X0, 0, GATE_Z)
	var leaf := Node3D.new(); leaf.name = "Leaf0"; gate.add_child(leaf)
	var door := MeshInstance3D.new(); var dm := BoxMesh.new(); dm.size = Vector3(GATE_X1 - GATE_X0, DOOR_H, 0.06)
	door.mesh = dm; door.material_override = _mats["wood"]; door.position = Vector3((GATE_X1 - GATE_X0) * 0.5, DOOR_H * 0.5, 0)
	leaf.add_child(door)
	_label("47", Vector3(EXIT_X - GATE_X0, 1.6, -0.035), PI, Color(0.82, 0.7, 0.4), leaf)
	var dummy := Node3D.new(); dummy.name = "Leaf1"; gate.add_child(dummy)      # (one leaf; the chapter tweens both)
	gate_body = StaticBody3D.new(); gate.add_child(gate_body)
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(GATE_X1 - GATE_X0, DOOR_H, 0.3)
	cs.shape = bs; cs.position = Vector3((GATE_X1 - GATE_X0) * 0.5, DOOR_H * 0.5, 0)
	gate_body.add_child(cs)
	# the bolt: a heavy one, on the wall beside the door, inside
	lever = Node3D.new(); lever.name = "Lever"; add_child(lever)
	lever.position = Vector3(GATE_X1 + 0.5, 1.25, GATE_Z - THICK * 0.5 - 0.03)
	var plate := MeshInstance3D.new(); var pb := BoxMesh.new(); pb.size = Vector3(0.22, 0.34, 0.03)
	plate.mesh = pb; plate.material_override = _mats["iron"]
	lever.add_child(plate)
	var arm := MeshInstance3D.new(); var ab := BoxMesh.new(); ab.size = Vector3(0.04, 0.42, 0.04)
	arm.mesh = ab; arm.material_override = _mats["iron"]; arm.position = Vector3(0, 0.16, -0.06); arm.rotation.z = -0.5; arm.name = "Arm"
	lever.add_child(arm)
	lever_spot = Hotspot.make(self, global_transform * Transform3D(Basis(), lever.position + Vector3(0, 0.1, -0.25)), Vector3(0.6, 0.8, 0.5), "Pull")

func open_gate() -> void:
	if gate_open:
		return
	gate_open = true
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(gate.get_node("Leaf0"), "rotation:y", deg_to_rad(-100), 2.4)
	tw.tween_property(lever.get_node("Arm"), "rotation:z", 0.5, 0.4)
	gate_body.collision_layer = 0
	gate_body.process_mode = Node.PROCESS_MODE_DISABLED
	Sfx.play_at("creak", to_global(Vector3(EXIT_X, 1.5, GATE_Z)), 4.0, 0.7)

# --- These Streets: chalk where the corridor comes round -------------------------------------------------

func _chalk() -> void:
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.92, 0.92, 0.88)
	m.emission_enabled = true; m.emission = Color(0.25, 0.25, 0.25)
	var dash := BoxMesh.new(); dash.size = Vector3(0.24, 0.004, 0.05)
	var cross := BoxMesh.new(); cross.size = Vector3(1.7, 0.004, 0.05)
	for x in [CELL * 0.6, LOOP - CELL * 0.6]:
		var ring := Node3D.new(); add_child(ring)
		ring.position = Vector3(x, 0.006, CELL * 0.5)
		for i in 16:
			var a := TAU * i / 16.0
			var mi := MeshInstance3D.new()
			mi.mesh = dash; mi.material_override = m
			mi.position = Vector3(cos(a), 0, sin(a)) * 0.75
			mi.rotation.y = -a + PI * 0.5
			ring.add_child(mi)
		for s in [-1.0, 1.0]:
			var mi := MeshInstance3D.new()
			mi.mesh = cross; mi.material_override = m; mi.rotation.y = PI * 0.25 * s
			ring.add_child(mi)
		ring.visible = false
		chalk.append(ring)

func show_chalk(on: bool) -> void:
	for c in chalk:
		if c.visible != on:
			c.visible = on

# --- things to take ---------------------------------------------------------------------------------

## Where the rounds, the loose bricks and the nuggets are (rooms; each sits off to one side).
const AMMO_CELLS := [Vector2i(12, 3), Vector2i(10, 6), Vector2i(3, 11)]
const ROCK_CELLS := [Vector2i(5, 2), Vector2i(8, 4), Vector2i(3, 10), Vector2i(11, 9), Vector2i(7, 12), Vector2i(1, 7)]
const NUGGET_CELLS := [Vector2i(6, 1), Vector2i(1, 0), Vector2i(11, 0), Vector2i(3, 3), Vector2i(9, 2), Vector2i(5, 5),
	Vector2i(12, 7), Vector2i(0, 9), Vector2i(7, 9), Vector2i(4, 12), Vector2i(10, 13), Vector2i(12, 11)]

func _pickups() -> void:
	var ammo := BoxMesh.new(); ammo.size = Vector3(0.14, 0.07, 0.09)
	var rock := BoxMesh.new(); rock.size = Vector3(0.1, 0.07, 0.2)
	for c in AMMO_CELLS:
		_pickup(center(c.x, c.y) + Vector3(-0.9, 0.0, 0.8), "ammo", ammo)
	for c in ROCK_CELLS:
		_pickup(center(c.x, c.y) + Vector3(0.8, 0.0, -0.7), "rock", rock)
	for i in NUGGET_CELLS.size():
		var c: Vector2i = NUGGET_CELLS[i]
		var n := Nugget.new()
		n.name = "Nugget%d" % i
		add_child(n)
		n.position = center(c.x, c.y) + Vector3(0.4, 0.6, 0.3)
		nuggets.append(n)

func _pickup(p: Vector3, kind: String, mesh: BoxMesh) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mats["brick"] if kind == "rock" else _mats["leather"]
	add_child(mi)
	mi.position = p + Vector3(0, mesh.size.y * 0.5, 0)
	mi.rotation.y = _rng.randf() * TAU
	var h := Hotspot.make(self, global_transform * Transform3D(Basis(), p + Vector3(0, 0.15, 0)), Vector3(0.5, 0.4, 0.5), "Take")
	h.set_meta("mesh", mi)
	pickups.append([h, kind])

## The nugget he's walking into this frame, if any (a world position: his middle).
func nugget_at(p: Vector3) -> Nugget:
	for n in nuggets:
		if (n as Nugget).within(p):
			return n
	return null

# --- the air ---------------------------------------------------------------------------------------------

func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.045, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.88, 0.62); env.ambient_light_energy = 0.42
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.fog_enabled = true; env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.16, 0.14, 0.09); env.fog_density = 0.06; env.fog_sky_affect = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC; env.tonemap_exposure = 1.1

# --- while he's here --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not built or not visible:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_t += delta
	_light_t -= delta
	if _light_t <= 0.0:
		_light_t = LIGHT_EVERY
		update_lights(cam.global_position)

## Light the nearest few panels to `eye` (world space) and no others. A light only changes when
## it joins or leaves the nearest few. The light is steady: no flicker.
func update_lights(eye: Vector3) -> void:
	var budget := LAMPS_PHONE if Game.is_phone() else LAMPS_DESKTOP
	var near: Array = []
	for l in lamps:
		var d := l.global_position.distance_squared_to(eye)
		if d < LAMP_RANGE * LAMP_RANGE:
			near.append([d, l])
	near.sort_custom(func(a, b): return a[0] < b[0])
	var want: Array[OmniLight3D] = []
	for i in mini(budget, near.size()):
		want.append(near[i][1])
	for l in _lit:
		if not want.has(l):
			l.visible = false
	for l in want:
		if not l.visible:
			l.visible = true
	_lit = want
	if gate_glow:
		var g := gate_glow.global_position.distance_to(eye) < 12.0
		if gate_glow.visible != g:
			gate_glow.visible = g

## The views TownChapter draws once, behind the black, before he arrives (local eye points; each
## is looked at four ways round).
func prewarm_views() -> Array[Vector3]:
	var v: Array[Vector3] = []
	for c in [ARRIVE_CELL, Vector2i(1, 0), Vector2i(11, 0), Vector2i(3, 3), Vector2i(6, 5), Vector2i(10, 4),
			REVOLVER_CELL, PORTER_CELL, Vector2i(9, 9), POSTER_CELL, NURSERY_CELL, Vector2i(EXIT_COL, H - 1)]:
		v.append(center(c.x, c.y) + Vector3(0, 1.6, 0))
	return v

## The corridor goes on for ever: walk off either end and you are at the other.
func wrap(local: Vector3) -> Vector3:
	if local.z < 0.0 or local.z >= CELL:
		return local
	if local.x < 0.0:
		return local + Vector3(LOOP, 0, 0)
	if local.x >= LOOP:
		return local - Vector3(LOOP, 0, 0)
	return local

# --- finding the way -------------------------------------------------------------------------------

## Once, at build: for every pair of rooms, the first room on the shortest way from one to the
## other (a breadth-first search back from each destination, through doorways and gaps).
func _route_table() -> void:
	var n := W * H
	_hop.resize(n * n)
	_hop.fill(-1)
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for ty in H:
		for tx in W:
			var t := Vector2i(tx, ty)
			var ti := ty * W + tx
			var seen := {t: true}
			var q: Array[Vector2i] = [t]
			var head := 0
			while head < q.size():
				var c: Vector2i = q[head]
				head += 1
				for d in dirs:
					var nb: Vector2i = c + d
					if seen.has(nb) or not passable(c, nb):
						continue
					seen[nb] = true
					_hop[(nb.y * W + nb.x) * n + ti] = c.y * W + c.x
					q.append(nb)

## The next room on the shortest way from room a to room b (a itself if they're the same, or
## (-1, -1) if there's no way).
func next_cell(a: Vector2i, b: Vector2i) -> Vector2i:
	if a == b:
		return a
	if not in_maze(a) or not in_maze(b) or _hop.is_empty():
		return Vector2i(-1, -1)
	var hop := _hop[(a.y * W + a.x) * W * H + b.y * W + b.x]
	return Vector2i(hop % W, hop / W) if hop >= 0 else Vector2i(-1, -1)

## The next point to head for, from `from` toward `to` (local space): the middle of the doorway
## into the next room on the way, or straight there in the same room.
func next_step(from: Vector3, to: Vector3) -> Vector3:
	var a := cell_of(from)
	var b := cell_of(to)
	if a == b or not in_maze(a) or not in_maze(b) or _hop.is_empty():
		return to
	var n := W * H
	var hop := _hop[(a.y * W + a.x) * n + b.y * W + b.x]
	if hop < 0:
		return to
	var step := Vector2i(hop % W, hop / W)
	# make for the gap between this room and the next (its middle), then on
	var gap := (center(a.x, a.y) + center(step.x, step.y)) * 0.5
	var lf := Vector3(from.x, 0, from.z)
	if lf.distance_to(gap) > 0.6:
		return gap
	if step == b:
		return to
	return center(step.x, step.y)
