class_name Flat47
extends Node3D
## Flat 47 and the landing outside it, built in code. Metres; floor at y=0; north is -Z.
##
##            z=-6 ┌────────────── LIVING ROOM ─────┐┌──── bedroom door (shut)
##                 │ window     Marta at the table  ││ HALLWAY
##                 │                         doorway ─  kitchen / bathroom doors (shut)
##          z=-1.2 └────────────────────────────────┘│
##                                    front door z=0 ┴── LANDING (start), stairs east

const H := 2.7            ## ceiling height
const T := 0.14           ## interior wall thickness

var front_door: Door
var front_door_spot: Hotspot
var marta_seat := Vector3(-3.75, 0.0, -3.9)
var table_top := 0.74
var stuck_doors: Array[Door] = []
var lights: Array[Light3D] = []

var _b: Build
var _rng := RandomNumberGenerator.new()

func build() -> void:
	_rng.seed = 1996
	_b = Build.new(self, "Shell")
	_b.material("wallpaper", Look.mat(Look.get_tex("wallpaper")))
	_b.material("plaster", Look.mat(Look.get_tex("plaster")))
	_b.material("green", Look.mat(Look.get_tex("paint_green")))
	_b.material("concrete", Look.mat(Look.get_tex("concrete")))
	_b.material("parquet", Look.mat(Look.get_tex("parquet")))
	_b.material("wood", Look.mat(Look.get_tex("wood")))
	_b.material("wood_light", Look.mat(Look.get_tex("wood_light")))
	_b.material("paper", Look.mat(Look.get_tex("paper")))
	_b.material("mould", Look.mat(Look.get_tex("mould")))
	_b.material("rubble", Look.mat(Look.get_tex("rubble")))
	_b.material("cloth_red", Look.mat(Look.get_tex("cloth"), Color("6a3a32")))
	_b.material("cloth_green", Look.mat(Look.get_tex("cloth"), Color("3f5a4a")))
	_b.material("cloth_coat", Look.mat(Look.get_tex("cloth"), Color("3b3128")))
	_b.material("white_cloth", Look.mat(Look.get_tex("cloth"), Color("cfcab8")))
	_b.material("coral", Look.mat(Look.get_tex("coral")))
	_b.material("window", Look.mat(Look.get_tex("plaster"), Color("9aa6b0"), 160.0, false, Color(0.9, 0.95, 1.0)))
	_b.material("dark", Look.mat(Look.get_tex("concrete"), Color("181818")))
	_shell()
	_landing()
	_hallway()
	_living_room()
	_b.finish()
	_doors()
	_lights()

# --- walls -------------------------------------------------------------------------------------

func _segments(a: float, b: float, holes: Array) -> Array:
	var out := []
	var cur := a
	var hs := holes.duplicate()
	hs.sort_custom(func(p, q): return p[0] < q[0])
	for h in hs:
		if h[0] > cur:
			out.append([cur, h[0], 0.0, H])
		if h[2] > 0.0:
			out.append([h[0], h[1], 0.0, h[2]])
		if h[3] < H:
			out.append([h[0], h[1], h[3], H])
		cur = h[1]
	if b > cur:
		out.append([cur, b, 0.0, H])
	return out

## Wall at constant z from x0 to x1. neg/pos: materials facing -z and +z. holes: [x0, x1, sill, top].
func wall_z(z: float, x0: float, x1: float, neg: String, pos: String, holes := [], t := T) -> void:
	for s in _segments(x0, x1, holes):
		_b.box(neg, Vector3(s[0], s[2], z - t * 0.5), Vector3(s[1], s[3], z), Transform3D.IDENTITY, true, 1.0, [Vector3.BACK])
		_b.box(pos, Vector3(s[0], s[2], z), Vector3(s[1], s[3], z + t * 0.5), Transform3D.IDENTITY, false, 1.0, [Vector3.FORWARD])

## Wall at constant x from z0 to z1. neg/pos: materials facing -x and +x. holes: [z0, z1, sill, top].
func wall_x(x: float, z0: float, z1: float, neg: String, pos: String, holes := [], t := T) -> void:
	for s in _segments(z0, z1, holes):
		_b.box(neg, Vector3(x - t * 0.5, s[2], s[0]), Vector3(x, s[3], s[1]), Transform3D.IDENTITY, true, 1.0, [Vector3.RIGHT])
		_b.box(pos, Vector3(x, s[2], s[0]), Vector3(x + t * 0.5, s[3], s[1]), Transform3D.IDENTITY, false, 1.0, [Vector3.LEFT])

func floor_ceiling(x0: float, z0: float, x1: float, z1: float, floor_mat: String, ceil_mat: String) -> void:
	_b.box(floor_mat, Vector3(x0, -0.1, z0), Vector3(x1, 0.0, z1), Transform3D.IDENTITY, true, 1.0)
	_b.box(ceil_mat, Vector3(x0, H, z0), Vector3(x1, H + 0.1, z1), Transform3D.IDENTITY, false, 1.0)

func _shell() -> void:
	# Front wall of the flat (landing side is green paint, hallway side wallpaper), door 0.9 wide.
	wall_z(0.0, -1.5, 1.5, "wallpaper", "green", [[-0.45, 0.45, 0.0, 2.05]], 0.24)
	# Hallway: x -1..1, z -5.2..0
	wall_x(-1.0, -1.2, 0.0, "plaster", "wallpaper")                                    # box room side
	wall_x(-1.0, -5.2, -1.2, "wallpaper", "wallpaper", [[-4.4, -3.5, 0.0, 2.05]])     # living room doorway
	wall_x(1.0, -5.2, 0.0, "wallpaper", "plaster", [[-2.8, -2.0, 0.0, 2.05], [-4.7, -4.0, 0.0, 2.05]])
	wall_z(-5.2, -1.0, 1.0, "plaster", "wallpaper", [[-0.4, 0.4, 0.0, 2.05]])
	floor_ceiling(-1.0, -5.2, 1.0, 0.0, "parquet", "plaster")
	# Living room: x -6..-1, z -6..-1.2; window in the west wall.
	wall_z(-6.0, -6.0, -1.0, "plaster", "wallpaper", [], 0.3)
	wall_z(-1.2, -6.0, -1.0, "wallpaper", "plaster")
	wall_x(-6.0, -6.0, -1.2, "plaster", "wallpaper", [[-4.6, -2.8, 0.85, 2.15]], 0.3)
	wall_x(-1.0, -6.0, -5.2, "wallpaper", "plaster")
	floor_ceiling(-6.0, -6.0, -1.0, -1.2, "parquet", "plaster")
	# the window: glass glowing grey daylight, a cross of frame
	_b.box("window", Vector3(-6.16, 0.85, -4.6), Vector3(-6.1, 2.15, -2.8), Transform3D.IDENTITY, true)
	_b.box("wood_light", Vector3(-6.12, 1.45, -4.6), Vector3(-6.04, 1.52, -2.8), Transform3D.IDENTITY, false)
	_b.box("wood_light", Vector3(-6.12, 0.85, -3.74), Vector3(-6.04, 2.15, -3.66), Transform3D.IDENTITY, false)
	_b.box("wood_light", Vector3(-6.15, 0.82, -4.7), Vector3(-5.86, 0.86, -2.7), Transform3D.IDENTITY, false)  # sill

func _landing() -> void:
	# Landing: x -1.5..1.5, z 0..2.8; the stair goes down to the east, into the dark.
	wall_x(-1.5, 0.0, 2.8, "concrete", "green", [], 0.24)
	wall_z(2.8, -1.5, 1.5, "green", "concrete", [], 0.24)
	_b.box("concrete", Vector3(-1.5, -0.1, 0.0), Vector3(1.5, 0.0, 2.8))
	_b.box("plaster", Vector3(-1.5, H, 0.0), Vector3(3.6, H + 0.1, 2.8), Transform3D.IDENTITY, false)
	wall_z(0.0, 1.5, 3.6, "concrete", "green", [], 0.24)
	wall_z(2.8, 1.5, 3.6, "green", "concrete", [], 0.24)
	wall_x(3.6, 0.0, 2.8, "green", "concrete", [], 0.24)
	# steps down, and the well going on below
	for i in 8:
		var y := -0.17 * (i + 1)
		_b.box("concrete", Vector3(1.5 + i * 0.27, y - 0.1, 0.1), Vector3(1.5 + (i + 1) * 0.27, y, 1.3), Transform3D.IDENTITY, false)
	_b.box("dark", Vector3(1.5, -3.0, 1.3), Vector3(3.6, -1.5, 2.8), Transform3D.IDENTITY, false)
	_b.box("concrete", Vector3(1.5, -0.1, 1.3), Vector3(3.6, 0.0, 2.8))       # the half landing
	_b.box("wood", Vector3(1.5, 0.0, 1.26), Vector3(3.6, 0.9, 1.32), Transform3D.IDENTITY, true)   # banister
	_b.collide(Vector3(1.5, -2.0, 0.0), Vector3(1.56, 3.0, 1.3))              # don't go down (yet)
	# the green paint stops at shoulder height; whitewash above
	_b.box("plaster", Vector3(-1.38, 1.5, 0.12), Vector3(-1.37, H, 2.68), Transform3D.IDENTITY, false)
	_b.box("plaster", Vector3(-1.38, 1.5, 2.67), Vector3(1.5, H, 2.68), Transform3D.IDENTITY, false)
	_b.box("plaster", Vector3(-1.5, 1.5, 0.121), Vector3(-0.45, H, 0.13), Transform3D.IDENTITY, false)
	_b.box("plaster", Vector3(0.45, 1.5, 0.121), Vector3(1.5, H, 0.13), Transform3D.IDENTITY, false)
	_b.box("plaster", Vector3(-0.45, 2.05, 0.121), Vector3(0.45, H, 0.13), Transform3D.IDENTITY, false)
	# a doormat; the flat number
	_b.box("cloth_red", Vector3(-0.4, 0.0, 0.15), Vector3(0.4, 0.02, 0.65), Transform3D.IDENTITY, false)
	_b.box("paper", Vector3(-0.08, 2.15, 0.12), Vector3(0.08, 2.3, 0.14), Transform3D.IDENTITY, false)

# --- what's in the rooms -----------------------------------------------------------------------

func _mould(center: Vector3, normal: Vector3, size: float) -> void:
	# A creeping patch on a wall or floor: overlapping thin plates, darker in the middle.
	var t := Basis(Quaternion(Vector3.BACK, normal.normalized()))
	for i in 12:
		var r := size * _rng.randf_range(0.12, 0.38) * (1.3 - i * 0.06)
		var off := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * size * 0.5 * (0.4 + i * 0.06)
		var spin := Basis(Vector3.BACK, _rng.randf_range(0, PI))
		var xf := Transform3D(t * spin, center + t * off + normal * (0.004 + i * 0.0012))
		_b.box("mould", Vector3(-r, -r * 0.7, 0), Vector3(r, r * 0.7, 0.002), xf, false)

func _coral(p: Vector3, dir: Vector3, length: float, r: float, depth: int) -> void:
	var cyl := _cyl()
	var d := dir.normalized()
	_b.mesh("coral", cyl, Transform3D(Build.along(d, r, length), p + d * length * 0.5))
	_b.mesh("coral", _ball(), Transform3D(Basis().scaled(Vector3.ONE * r * 1.25), p + d * length))
	if depth <= 0:
		return
	for k in _rng.randi_range(1, 3):
		var nd := (d + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.6, 0.8), _rng.randf_range(-1, 1)) * 0.9).normalized()
		_coral(p + d * length * _rng.randf_range(0.6, 1.0), nd, length * _rng.randf_range(0.55, 0.8), r * 0.7, depth - 1)

static var _cyl_m: CylinderMesh
static var _ball_m: SphereMesh
static func _cyl() -> CylinderMesh:
	if _cyl_m == null:
		_cyl_m = CylinderMesh.new()
		_cyl_m.top_radius = 0.7; _cyl_m.bottom_radius = 1.0; _cyl_m.height = 1.0
		_cyl_m.radial_segments = 6; _cyl_m.rings = 1
	return _cyl_m
static func _ball() -> SphereMesh:
	if _ball_m == null:
		_ball_m = SphereMesh.new()
		_ball_m.radius = 1.0; _ball_m.height = 2.0
		_ball_m.radial_segments = 6; _ball_m.rings = 4
	return _ball_m

func _rot(yaw_deg: float, at: Vector3, roll_deg := 0.0, pitch_deg := 0.0) -> Transform3D:
	var b := Basis.from_euler(Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), deg_to_rad(roll_deg)))
	return Transform3D(b, at)

func _papers(center: Vector3, spread: float, count: int) -> void:
	for i in count:
		var p := center + Vector3(_rng.randf_range(-spread, spread), 0.003 + i * 0.0006, _rng.randf_range(-spread, spread))
		_b.box("paper", Vector3(-0.1, 0, -0.14), Vector3(0.1, 0.002, 0.14), _rot(_rng.randf_range(0, 360), p), false)

func _rubble(center: Vector3, spread: float, count: int) -> void:
	for i in count:
		var s := _rng.randf_range(0.04, 0.16)
		var p := center + Vector3(_rng.randf_range(-spread, spread), s * 0.3, _rng.randf_range(-spread, spread))
		_b.box("rubble", Vector3(-s, -s * 0.3, -s * 0.8), Vector3(s, s * 0.3, s * 0.8), _rot(_rng.randf_range(0, 360), p, _rng.randf_range(-20, 20)), false)

func _hallway() -> void:
	# coat hooks on the west wall; one coat still up, two pulled down onto the floor
	_b.box("wood", Vector3(-0.99, 1.62, -1.1), Vector3(-0.95, 1.7, -0.3), Transform3D.IDENTITY, false)
	_b.box("cloth_coat", Vector3(-0.96, 0.85, -0.85), Vector3(-0.8, 1.66, -0.45), Transform3D.IDENTITY, false)
	_b.box("cloth_red", Vector3(-0.3, 0, -0.3), Vector3(0.3, 0.06, 0.3), _rot(35, Vector3(-0.55, 0.0, -1.5)), false)
	_b.box("cloth_coat", Vector3(-0.35, 0, -0.25), Vector3(0.35, 0.07, 0.25), _rot(-20, Vector3(-0.5, 0.06, -1.7)), false)
	# shoe rack kicked over; shoes everywhere
	_b.box("wood", Vector3(-0.4, 0, -0.15), Vector3(0.4, 0.3, 0.15), _rot(80, Vector3(0.75, 0.15, -0.8), 90), true)
	for i in 5:
		var p := Vector3(_rng.randf_range(-0.6, 0.7), 0.04, _rng.randf_range(-2.5, -0.6))
		_b.box("dark", Vector3(-0.05, -0.04, -0.13), Vector3(0.05, 0.05, 0.13), _rot(_rng.randf_range(0, 360), p), false)
	# a wardrobe come down across the hallway, wedged at an angle against the wall
	_b.box("wood", Vector3(-0.3, 0, -0.9), Vector3(0.3, 1.9, 0.0), _rot(0, Vector3(0.7, 0.0, -3.1), 0, 0) * Transform3D(Basis.from_euler(Vector3(0, 0, deg_to_rad(10))), Vector3.ZERO), true)
	# the ceiling's let go over the bedroom door
	_b.box("rubble", Vector3(-0.6, H - 0.05, -5.0), Vector3(0.3, H, -4.2), Transform3D.IDENTITY, false)
	_rubble(Vector3(0.0, 0.0, -4.6), 0.55, 14)
	_papers(Vector3(0.0, 0.0, -2.0), 0.6, 10)
	# mould climbing out of the corners; coral reaching in from the living room doorway
	_mould(Vector3(0.99 - 0.07, 0.4, -1.2), Vector3.LEFT, 0.5)
	_mould(Vector3(-0.93, 2.3, -2.5), Vector3.RIGHT, 0.7)
	_mould(Vector3(0.93, 2.4, -4.6), Vector3.LEFT, 0.6)
	_mould(Vector3(-0.3, H - 0.005, -3.3), Vector3.DOWN, 0.7)
	_mould(Vector3(-0.92, 0.3, -4.9), Vector3.RIGHT, 0.5)
	for i in 4:
		_coral(Vector3(-1.0, 0.0, -3.6 - i * 0.22), Vector3(1.0, 0.15, _rng.randf_range(-0.5, 0.5)), 0.35, 0.025, 2)
	# the bulb: a bare one on its flex
	_b.box("dark", Vector3(-0.005, 2.35, -2.505), Vector3(0.005, H, -2.495), Transform3D.IDENTITY, false)

func _living_room() -> void:
	var m := marta_seat
	# the table, set for dinner for three, a long time ago
	var t0 := Vector3(m.x + 0.45, 0, m.z - 0.65)
	var t1 := Vector3(m.x + 1.35, table_top, m.z + 0.65)
	_b.box("wood", Vector3(t0.x, table_top - 0.04, t0.z), t1, Transform3D.IDENTITY, false)
	_b.box("white_cloth", Vector3(t0.x - 0.03, table_top, t0.z - 0.03), Vector3(t1.x + 0.03, table_top + 0.006, t1.z + 0.03), Transform3D.IDENTITY, false)
	for c in [Vector3(t0.x + 0.05, 0, t0.z + 0.05), Vector3(t1.x - 0.1, 0, t0.z + 0.05), Vector3(t0.x + 0.05, 0, t1.z - 0.1), Vector3(t1.x - 0.1, 0, t1.z - 0.1)]:
		_b.box("wood", c, c + Vector3(0.05, table_top - 0.04, 0.05), Transform3D.IDENTITY, false)
	_b.collide(Vector3(t0.x, 0, t0.z), Vector3(t1.x, table_top + 0.05, t1.z))
	for p in [Vector3(m.x + 0.7, 0, m.z), Vector3(m.x + 1.0, 0, m.z - 0.42), Vector3(m.x + 1.0, 0, m.z + 0.42)]:
		_b.box("white_cloth", Vector3(-0.11, table_top + 0.006, -0.11), Vector3(0.11, table_top + 0.02, 0.11), Transform3D(Basis(), p), false)
		_b.box("mould", Vector3(-0.07, table_top + 0.02, -0.07), Vector3(0.07, table_top + 0.035, 0.07), Transform3D(Basis(), p), false)
	# the other two chairs: one pushed back, one on its side
	_chair(Vector3(m.x + 1.2, 0, m.z - 0.95), 160.0, false)
	_chair(Vector3(m.x + 1.7, 0, m.z - 1.45), -60.0, true)
	# an armchair face down; the bookcase on its face across the room; books everywhere
	_b.box("cloth_green", Vector3(-0.45, 0, -0.4), Vector3(0.45, 0.85, 0.4), _rot(20, Vector3(-2.0, 0, -1.9), 0, 95), true)
	_b.box("wood", Vector3(-0.9, 0, -0.2), Vector3(0.9, 0.35, 0.2), _rot(10, Vector3(-4.6, 0, -5.4)), true)
	for i in 16:
		var p := Vector3(_rng.randf_range(-5.5, -3.8), 0.03, _rng.randf_range(-5.6, -4.7))
		var col: String = ["cloth_red", "cloth_green", "cloth_coat", "paper"][i % 4]
		_b.box(col, Vector3(-0.08, -0.03, -0.11), Vector3(0.08, 0.03, 0.11), _rot(_rng.randf_range(0, 360), p), false)
	# the wall unit, doors hanging, the good china smashed on the floor
	_b.box("wood", Vector3(-5.8, 0, -1.6), Vector3(-3.6, 2.0, -1.2), Transform3D.IDENTITY, true)
	_b.box("dark", Vector3(-5.6, 0.9, -1.62), Vector3(-4.8, 1.5, -1.6), Transform3D.IDENTITY, false)   # the TV's dead face
	_rubble(Vector3(-4.6, 0, -1.9), 0.4, 10)
	_papers(Vector3(-2.2, 0, -4.4), 0.7, 12)
	# the plaster's down in the corner by the window
	_b.box("rubble", Vector3(-6.0, H - 0.06, -6.0), Vector3(-4.8, H, -5.0), Transform3D.IDENTITY, false)
	_rubble(Vector3(-5.4, 0, -5.4), 0.5, 12)
	# the standard lamp knocked over, still lit, lying by her chair
	_b.box("wood_light", Vector3(-0.015, 0, -0.015), Vector3(0.015, 1.4, 0.015), _rot(40, Vector3(m.x - 0.3, 0.03, m.z + 1.4), 0, 84), false)
	_b.box("paper", Vector3(-0.17, -0.12, -0.17), Vector3(0.17, 0.12, 0.17), _rot(40, Vector3(m.x - 1.1, 0.17, m.z + 0.45), 0, 75), false)
	# the coral: out of her, into her chair, the floor, the wall behind her and up onto the ceiling
	for i in 9:
		var a := TAU * i / 9.0
		_coral(Vector3(m.x, 0.0, m.z), Vector3(cos(a), 0.12, sin(a)), _rng.randf_range(0.45, 0.8), 0.04, 3)
	for i in 5:
		_coral(Vector3(m.x - 0.25, 0.9 + i * 0.12, m.z + _rng.randf_range(-0.25, 0.25)), Vector3(-1, 0.4, _rng.randf_range(-0.6, 0.6)), 0.5, 0.035, 3)
	for i in 6:
		_coral(Vector3(-6.0 + 0.16, _rng.randf_range(0.3, 2.3), m.z + _rng.randf_range(-1.2, 1.2)), Vector3(1, _rng.randf_range(-0.3, 0.5), _rng.randf_range(-0.5, 0.5)), 0.4, 0.035, 2)
	for i in 4:
		_coral(Vector3(m.x + _rng.randf_range(-1, 0.6), H, m.z + _rng.randf_range(-1, 1)), Vector3(_rng.randf_range(-0.5, 0.5), -1, _rng.randf_range(-0.5, 0.5)), 0.35, 0.03, 2)
	_b.collide(Vector3(m.x - 1.4, 0, m.z - 1.0), Vector3(m.x - 0.6, 0.5, m.z + 1.0))
	# mould: thick around her, up the wall behind her, across the ceiling
	_mould(Vector3(m.x, 0.001, m.z), Vector3.UP, 1.6)
	_mould(Vector3(m.x + 0.8, 0.001, m.z - 0.3), Vector3.UP, 1.0)
	_mould(Vector3(-5.85, 1.3, m.z), Vector3.RIGHT, 1.5)
	_mould(Vector3(-5.85, 2.2, m.z - 1.4), Vector3.RIGHT, 0.9)
	_mould(Vector3(m.x, H - 0.005, m.z), Vector3.DOWN, 1.6)
	_mould(Vector3(-1.16, 1.7, -5.0), Vector3.LEFT, 0.8)
	_mould(Vector3(-2.5, 2.4, -1.35), Vector3.FORWARD, 0.7)

func _chair(at: Vector3, yaw: float, fallen: bool) -> void:
	var base := _rot(yaw, at)
	if fallen:
		base = base * Transform3D(Basis.from_euler(Vector3(0, 0, deg_to_rad(90))), Vector3(0.22, 0.22, 0))
	_b.box("wood", Vector3(-0.21, 0.42, -0.21), Vector3(0.21, 0.46, 0.21), base, false)
	_b.box("wood", Vector3(-0.21, 0.46, 0.17), Vector3(0.21, 0.95, 0.21), base, false)
	for c in [Vector3(-0.2, 0, -0.2), Vector3(0.16, 0, -0.2), Vector3(-0.2, 0, 0.16), Vector3(0.16, 0, 0.16)]:
		_b.box("wood", c, c + Vector3(0.04, 0.42, 0.04), base, false)
	_b.collide(Vector3(-0.22, 0, -0.22), Vector3(0.22, 0.5, 0.22), base)

func _doors() -> void:
	var leather := Look.mat(Look.get_tex("leather"), Color.WHITE, 0.0)
	var paint := Look.mat(Look.get_tex("plaster"), Color("d8d2bf"), 0.0)
	# The front door: hinged at x=-0.45, opens inward (toward -z), padded.
	front_door = Door.new()
	front_door.name = "FrontDoor"
	add_child(front_door)
	front_door.position = Vector3(-0.45, 0, 0.0)
	front_door.setup(0.9, 2.05, leather, 0.08)
	front_door.set_angle(0.0)
	front_door_spot = Hotspot.make(self, Transform3D(Basis(), Vector3(0, 1.0, 0)), Vector3(0.9, 2.0, 0.4), "Open")
	front_door_spot.enabled = false
	# Doors that stay shut in this scene. Solid; trying them only rattles them.
	var specs := [
		[Vector3(1.0, 0, -2.0), 90.0],     # kitchen
		[Vector3(1.0, 0, -4.0), 90.0],     # bathroom
		[Vector3(-0.4, 0, -5.2), 0.0],     # bedroom
	]
	for s in specs:
		var d := Door.new()
		add_child(d)
		d.position = s[0]
		d.rotation.y = deg_to_rad(s[1])
		d.setup(0.8 if s[1] == 0.0 else 0.7, 2.05, paint, 0.05)
		stuck_doors.append(d)
		var spot := Hotspot.make(self, d.global_transform * Transform3D(Basis(), Vector3(d.width * 0.5, 1.0, 0)), Vector3(d.width, 2.0, 0.3), "Open")
		spot.used.connect(func():
			Sfx.play_at("rattle", d.handle_position(), -4.0, 1.05))

func _lights() -> void:
	# Steady lights only. Few of them (phones): none cast shadows.
	lights.append(_omni(Vector3(0, 2.45, 1.4), Color("ffd9a0"), 1.1, 5.0))     # landing
	lights.append(_omni(Vector3(0, 2.3, -2.5), Color("ffc87a"), 0.75, 5.5))    # hallway bulb
	lights.append(_omni(Vector3(-5.2, 1.7, -3.7), Color("aebccc"), 1.2, 6.5))  # window daylight
	lights.append(_omni(Vector3(marta_seat.x - 1.0, 0.25, marta_seat.z + 0.5), Color("ff9a55"), 0.9, 3.6))  # the fallen lamp
	# the bulbs themselves
	for p in [Vector3(0, 2.32, -2.5), Vector3(0, 2.6, 1.4)]:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.04; sm.height = 0.1
		mi.mesh = sm
		mi.material_override = Look.mat(Look.get_tex("white"), Color("ffe2b0"), 160.0, false, Color(3, 2.5, 1.6))
		add_child(mi)
		mi.position = p

func _omni(p: Vector3, c: Color, e: float, r: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = e
	l.omni_range = r
	l.omni_attenuation = 1.2
	l.shadow_enabled = false
	add_child(l)
	l.position = p
	return l
