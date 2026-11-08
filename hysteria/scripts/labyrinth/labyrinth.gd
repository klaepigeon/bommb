class_name Labyrinth
extends Node3D
## Behind the bedroom wardrobe: Kerzhansk as it was under the Romanovs, about 1910, and not a
## place that can exist. A night town of render and cobbles under no sky at all, lit by gas.
##
## Laid out on a 4 m grid (MAP). You come out of a hole at the dead end of a lane (E) onto
## Дворянская улица, the main street, which goes on for ever: walk off either end and you are
## at the other, with nothing to show for it (PERIOD). South of it, a square where a fight has
## been stopped in mid-air; then a chapel plaza; then a lane of wooden houses. A cathedral dome
## hangs over everything and is always the same distance away.

const CELL := 4.0
## # block, . street, E the lane's dead end (the hole you came through)
const MAP := [
	"################",  # 0
	"######E#########",  # 1
	"######.#########",  # 2
	"######.#########",  # 3
	"#..............#",  # 4   Дворянская улица
	"#..............#",  # 5
	"##########.#####",  # 6
	"##########.#####",  # 7
	"########.....###",  # 8   the square
	"########.....###",  # 9
	"########.....###",  # 10
	"########.....###",  # 11
	"##########.#####",  # 12
	"##########.#####",  # 13
	"#######.......##",  # 14  the chapel plaza
	"###...........##",  # 15  and the lane of izbas going west
	"#######.......##",  # 16
	"################",  # 17
]
const PERIOD := 13       # the main street repeats every 13 cells (columns 1..13)
const BAND := 8          # rows 0..7 wrap with it

## what's on particular frontages: "col,row,side" (side: which way from the street cell the
## building is: n s e w) -> bay style overrides
const FRONTS := {
	"6,1,n": {"kind": "hole"},
	"2,4,n": {"kind": "shop", "sign": "АПТЕКА"},
	"8,4,n": {"kind": "shop", "sign": "БУЛОЧНАЯ", "goods": "shop_bakery"},
	"11,4,n": {"kind": "shop", "sign": "ТРАКТИРЪ", "goods": "shop_tavern"},
	"4,4,n": {"kind": "door"},
	"13,4,n": {"kind": "door"},
	"3,5,s": {"kind": "shop", "sign": "ФОТОГРАФІЯ", "goods": "shop_photo"},
	"4,5,s": {"kind": "door", "door_open": true, "lit_down": true},   # the photographer's: the salon
	"7,5,s": {"kind": "shop", "sign": "ЧАСОВЩИКЪ", "goods": "shop_clock"},
	"12,5,s": {"kind": "door"},
	"12,9,e": {"kind": "door", "door_open": true, "lit_down": true},  # ГОСТИНИЦА: the hotel room
	"12,8,e": {"kind": "shop", "sign": "ГОСТИНИЦА", "goods": "shop_hotel"},
	"8,9,w": {"kind": "door"},
	"3,15,w": {"kind": "door", "door_open": true},                     # the nursery izba
}
const SIGN_FONT_COLOR := Color(0.86, 0.7, 0.34)

var kit: TownKit
var lamps: Array[OmniLight3D] = []
var env: Environment
var dome: Node3D
var arrive := Transform3D.IDENTITY          # where you stand coming out of the hole
var hole_at := Vector3.ZERO                 # the hole, to go back through
var _colliders: StaticBody3D
var fight: FrozenFight
var revolver: Revolver

func _ready() -> void:
	build()

# ---------------------------------------------------------------- the map
func cell(c: int, r: int) -> String:
	if r < BAND and (c < 1 or c > PERIOD):
		c = 1 + posmod(c - 1, PERIOD)
	if r < 0 or r >= MAP.size() or c < 0 or c >= String(MAP[r]).length():
		return "#"
	return String(MAP[r])[c]

func is_street(c: int, r: int) -> bool:
	return cell(c, r) != "#"

func _key_col(c: int, r: int) -> int:
	return 1 + posmod(c - 1, PERIOD) if r < BAND and (c < 1 or c > PERIOD) else c

func center(c: int, r: int) -> Vector3:
	return Vector3((c + 0.5) * CELL, 0, (r + 0.5) * CELL)

## columns to build for a row: the main band runs on past both ends (the repeat), the rest is
## just the map
func _cols(r: int) -> Array:
	if r < BAND: return range(-4, PERIOD + 5)
	return range(0, String(MAP[r]).length())

# ---------------------------------------------------------------- build
func build() -> void:
	kit = TownKit.new(self)
	_colliders = StaticBody3D.new(); _colliders.name = "Collision"; add_child(_colliders)
	var floor_cs := CollisionShape3D.new(); var fb := BoxShape3D.new(); fb.size = Vector3(200, 1, 200)
	floor_cs.shape = fb; floor_cs.position = Vector3(32, -0.5, 36); _colliders.add_child(floor_cs)
	for r in MAP.size():
		for c in _cols(r):
			if is_street(c, r):
				_street_cell(c, r)
	_lamps()
	_dress()
	# the square: the fight, stopped; and the revolver in it
	fight = FrozenFight.new(); fight.name = "FrozenFight"; add_child(fight)
	fight.build(kit, self)
	revolver = Revolver.new(); revolver.name = "Revolver"; add_child(revolver)
	revolver.transform = fight.gun_at
	var pick := StaticBody3D.new(); pick.name = "RevolverPickup"; pick.set_script(load("res://scripts/weapons/revolver_pickup.gd"))
	pick.set("gun", revolver)
	var pcs := CollisionShape3D.new(); var pb := BoxShape3D.new(); pb.size = Vector3(0.3, 0.12, 0.3); pcs.shape = pb; pick.add_child(pcs)
	add_child(pick); pick.position = fight.gun_at.origin + Vector3(0, 0.04, 0)
	var n := kit.finish()
	_environment()
	_dome()
	var e := center(6, 1)
	arrive = Transform3D(Basis(Vector3.UP, PI), e + Vector3(0, 0, -0.6))
	hole_at = e + Vector3(0, 0.9, -CELL * 0.5)
	if OS.is_debug_build(): print("labyrinth: ", n, " meshes, ", lamps.size(), " lamps")

const DIRS := {"n": Vector2i(0, -1), "s": Vector2i(0, 1), "e": Vector2i(1, 0), "w": Vector2i(-1, 0)}

func _street_cell(c: int, r: int) -> void:
	var ctr := center(c, r)
	var h := CELL * 0.5
	# cobbles, the whole cell
	kit.quad("cobbles", ctr + Vector3(-h, 0, -h), ctr + Vector3(h, 0, -h), ctr + Vector3(h, 0, h), ctr + Vector3(-h, 0, h), Vector3.UP, Vector3.ZERO)
	var narrow := 0
	for d in DIRS:
		if not is_street(c + DIRS[d].x, r + DIRS[d].y): narrow += 1
	var walk := 0.75 if narrow >= 2 else 1.0
	for d in DIRS:
		var dv: Vector2i = DIRS[d]
		if is_street(c + dv.x, r + dv.y):
			continue
		var o := -Vector3(dv.x, 0, dv.y)                       # out of the building, into the street
		var a := Vector3.UP.cross(o)
		var line := ctr - o * h                                # the building line
		var f := Facades.Frame.new(line - a * h, a, o)
		# the pavement: granite slabs along the building, a kerb stone. Where the next side is a
		# building too (a corner, a dead end), this side's pavement stops where that one starts,
		# and the kerb turns the corner instead of running through it.
		var left_wall := not is_street(c + int(-a.x), r + int(-a.z))
		var right_wall := not is_street(c + int(a.x), r + int(a.z))
		var x0 := walk if left_wall else -0.02
		var x1 := CELL - walk if right_wall else CELL + 0.02
		Facades.bx(kit, f, "stone", x0 - (walk if left_wall else 0.0), x1 + (walk if right_wall else 0.0), 0.0, 0.12, 0.0, walk, 4 | 16 | 1 | 2)
		Facades.bx(kit, f, "trim", x0 - (0.0 if left_wall else 0.0), x1, 0.0, 0.14, walk - 0.14, walk, 4 | 16 | (2 if left_wall else 0) | (1 if right_wall else 0))
		_bay(c, r, d, f)
		# leaves drifted against the kerb, and a few on the pavement
		var lrng := RandomNumberGenerator.new(); lrng.seed = hash("leaf%d,%d,%s" % [_key_col(c, r), r, d])
		TownProps.leaves(kit, line + o * (walk + 0.3) + Vector3(0, 0.006, 0), a, CELL, 0.7, 10, lrng)
		TownProps.leaves(kit, line + o * (walk * 0.6) + Vector3(0, 0.126, 0), a, CELL, walk * 0.6, 3, lrng)
		# the wall, for walking into
		var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(CELL + 0.6, 12, 0.6)
		cs.shape = b; cs.position = line - o * 0.3 + Vector3(0, 6, 0)
		cs.basis = Basis(a, Vector3.UP, o)
		var front := FRONTS.get("%d,%d,%s" % [_key_col(c, r), r, d], {}) as Dictionary
		if front.get("door_open", false) or front.get("kind", "") == "hole":
			cs.set_meta("opening", true)
		_colliders.add_child(cs)

## style a bay from where it is: the main street is merchants' render in ochre and cream, the
## square grander and three storeys, the plaza mixed, the western lane log izbas
func _bay(c: int, r: int, d: String, f: Facades.Frame) -> void:
	var kc := _key_col(c, r)
	var rng := RandomNumberGenerator.new(); rng.seed = hash("%d,%d,%s" % [kc, r, d])
	var house := RandomNumberGenerator.new(); house.seed = hash("%d,%d" % [kc / 2, r])   # houses two bays wide
	var front: Dictionary = FRONTS.get("%d,%d,%s" % [kc, r, d], {})
	var res := {}
	if r == 15 and c <= 6:
		var s := {"rng": rng, "carve": ["carved_white", "carved_blue"][rng.randi() % 2], "lit": rng.randf() < 0.3, "corner_left": c == 3}
		s.merge(front, true)
		res = Facades.izba(kit, f, s)
	else:
		var palette := [["stucco_ochre", "rustic_ochre"], ["stucco_cream", "rustic_cream"], ["stucco_rose", "rustic_cream"], ["stucco_green", "rustic_cream"]]
		var p: Array = palette[house.randi() % palette.size()]
		var floors := 3 if (r >= 8 and r <= 11) else (3 if house.randf() < 0.3 else 2)
		var s := {"rng": rng, "wall": p[0], "ground": p[1] if house.randf() < 0.7 else p[0],
			"hood": ["flat", "pediment", "arch"][house.randi() % 3], "floors": floors,
			"lit_up": 0.18, "drainpipe": rng.randf() < 0.25, "kind": "window" if rng.randf() < 0.75 else "blank"}
		s.merge(front, true)
		if s.kind == "hole":
			_hole_bay(f)
			return
		res = Facades.house(kit, f, s)
	if res.has("sign") and String(res.sign[1]) != "":
		var l := Label3D.new(); l.text = res.sign[1]
		l.font_size = 64; l.pixel_size = 0.0058; l.modulate = SIGN_FONT_COLOR; l.outline_size = 0
		l.shaded = false; l.double_sided = true; l.no_depth_test = false
		l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		add_child(l)
		l.transform = Transform3D(f.basis(), res.sign[0] + f.z * 0.01)     # local: the labyrinth isn't at the origin

## the dead end of the lane: a blind wall with a ragged hole knocked through it at the bottom,
## and through the hole, dark (the way back)
func _hole_bay(f: Facades.Frame) -> void:
	Facades.bx(kit, f, "stone", 0, CELL, 0, 0.45, 0, 0.07, 4 | 16 | 1 | 2)
	Facades.wall_hole(kit, f, "stucco_cream", 0, CELL, 0.45, 7.2, 1.45, 2.55, 0.45, 2.1, 0.5, "", "brick")
	Facades.wall(kit, f, "stucco_cream", 1.45, 2.55, 0.0, 0.45)
	# the edge of the hole: brick and render broken out of it at every angle
	var rng := RandomNumberGenerator.new(); rng.seed = 47
	Facades.ragged_rim(kit, f, 1.45, 2.55, 0.45, 2.1, "stucco_cream", rng)
	# what fell out, on the pavement
	for i in 10:
		var s := rng.randf_range(0.03, 0.08)
		kit.box("brick" if rng.randf() < 0.6 else "stucco_cream", f.p(rng.randf_range(1.2, 2.8), 0.12 + s * 0.5, rng.randf_range(0.1, 0.8)), Vector3(s, s * 0.5, s * 0.7), Basis(Vector3.UP, rng.randf() * TAU))
	# and through it, nothing: a black that the torch doesn't reach the end of
	var black := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(1.1, 1.7); black.mesh = qm
	var bm := StandardMaterial3D.new(); bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; bm.albedo_color = Color.BLACK
	black.material_override = bm; add_child(black)
	black.transform = Transform3D(f.basis(), f.p(2.0, 1.27, -0.48))
	Facades.bx(kit, f, "stucco_cream", 0, CELL, 7.2, 7.4, 0, 0.2)

# ---------------------------------------------------------------- street furniture
func _solid(at: Vector3, half: Vector3, yaw := 0.0) -> void:
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = half * 2.0
	cs.shape = b; cs.position = at + Vector3(0, half.y, 0); cs.rotation.y = yaw
	_colliders.add_child(cs)

func _dress() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 1910
	# the main street's things repeat with it
	for off in [-PERIOD * CELL, 0.0, PERIOD * CELL]:
		var o := Vector3(off, 0, 0)
		TownProps.advert_column(kit, self, o + Vector3(5.5 * CELL, 0, 17.95), rng)
		_solid(o + Vector3(5.5 * CELL, 0, 17.95), Vector3(0.62, 1.6, 0.62))
		TownProps.bench(kit, o + Vector3(9.4 * CELL, 0.12, 23.25), PI)
		_solid(o + Vector3(9.4 * CELL, 0.12, 23.25), Vector3(0.85, 0.4, 0.25))
		TownProps.cart(kit, o + Vector3(12.4 * CELL, 0, 18.4), PI * 0.5 + 0.12)
		_solid(o + Vector3(12.4 * CELL, 0, 18.4), Vector3(1.3, 0.6, 0.75), 0.12)
		for bp in [Vector3(44.4, 0.12, 16.45), Vector3(45.05, 0.12, 16.42), Vector3(44.75, 0.12, 16.95)]:
			TownProps.barrel(kit, o + bp)
		_solid(o + Vector3(44.75, 0.12, 16.7), Vector3(0.7, 0.4, 0.5))
		TownProps.crate(kit, o + Vector3(33.2, 0.12, 16.4), 0.2)
		TownProps.crate(kit, o + Vector3(33.75, 0.12, 16.4), -0.1)
		TownProps.crate(kit, o + Vector3(33.5, 0.62, 16.42), 0.4, 0.22)
		_solid(o + Vector3(33.5, 0.12, 16.4), Vector3(0.6, 0.5, 0.3))
		for wx in [3.5 * CELL, 9.5 * CELL]:
			TownProps.wire(kit, o + Vector3(wx, 6.9, 16.2), o + Vector3(wx + 1.5, 6.6, 23.8), 0.55)
			TownProps.wire(kit, o + Vector3(wx + 0.3, 7.1, 16.2), o + Vector3(wx + 1.8, 6.8, 23.8), 0.6)

# ---------------------------------------------------------------- light
## gas lamps: along the main street every few cells on alternate sides, one in the lane, the
## square's corners, the plaza; and one in the square bent over by whatever happened there
const LAMP_CELLS := [[6, 2, "e"], [2, 4, "n"], [5, 5, "s"], [8, 4, "n"], [11, 5, "s"], [14, 4, "n"],
	[10, 7, "w"], [8, 8, "nw"], [12, 8, "ne"], [8, 11, "sw"], [12, 11, "se"], [10, 13, "e"],
	[7, 14, "nw"], [13, 14, "ne"], [10, 16, "s"], [4, 15, "n"]]

func _lamps() -> void:
	for spec in LAMP_CELLS:
		var cols := [spec[0]]
		if spec[1] < BAND:
			cols = [spec[0] - PERIOD, spec[0], spec[0] + PERIOD]
		for c in cols:
			var ctr := center(c, spec[1])
			var off := Vector3.ZERO
			var side: String = spec[2]
			if side.contains("n"): off.z -= CELL * 0.5 - 0.75
			if side.contains("s"): off.z += CELL * 0.5 - 0.75
			if side.contains("e"): off.x += CELL * 0.5 - 0.75
			if side.contains("w"): off.x -= CELL * 0.5 - 0.75
			if spec[1] == 4 or spec[1] == 5:
				off.x += CELL * 0.5            # between shops, not in front of their signs
			var at := Facades.gas_lamp(kit, ctr + off + Vector3(0, 0.12 if side.length() == 1 else 0.0, 0))
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.7, 0.4); l.light_energy = 2.4; l.light_specular = 0.6
			l.omni_range = 10.0; l.omni_attenuation = 1.3; l.shadow_enabled = false
			l.distance_fade_enabled = true; l.distance_fade_begin = 22.0; l.distance_fade_length = 6.0
			add_child(l); l.position = at
			l.set_meta("seed", randf() * 100.0)
			lamps.append(l)

func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.018, 0.026)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# night: cool blue in the shadows, so the gas light reads warm against it
	env.ambient_light_color = Color(0.3, 0.37, 0.52); env.ambient_light_energy = 0.48
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.fog_enabled = true; env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.05, 0.058, 0.075); env.fog_density = 0.075; env.fog_sky_affect = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES; env.tonemap_exposure = 1.25

## The cathedral: an onion dome on a drum, gilded, with a cross; always 70 m off to the south
## and 30 up, wherever you go. Unfogged, so it hangs in the black like a thing you could reach.
func _dome() -> void:
	dome = Node3D.new(); dome.name = "Cathedral"; add_child(dome)
	dome.scale = Vector3.ONE * 0.62       # within the camera's 60 m, at the same apparent size
	var gold := StandardMaterial3D.new()
	gold.albedo_texture = RomanovTextures.get_set("gold").albedo; gold.albedo_color = Color(0.9, 0.85, 0.75)
	gold.metallic = 0.6; gold.roughness = 0.4; gold.disable_fog = true
	gold.emission_enabled = true; gold.emission = Color(0.35, 0.25, 0.1); gold.emission_energy_multiplier = 0.6
	gold.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	var drum := StandardMaterial3D.new(); drum.albedo_color = Color(0.25, 0.27, 0.3); drum.disable_fog = true
	drum.emission_enabled = true; drum.emission = Color(0.05, 0.06, 0.08)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# the onion: a lathe of a bulb that swells past the drum and draws up to a point
	var prof := [[0.0, 7.0], [5.2, 7.0], [7.4, 9.5], [8.0, 12.5], [7.0, 15.5], [4.6, 18.5], [2.2, 21.0], [0.9, 23.0], [0.35, 25.0], [0.0, 26.0]]
	const SEG := 16
	for i in prof.size() - 1:
		for j in SEG:
			var a0 := TAU * j / SEG; var a1 := TAU * (j + 1) / SEG
			var p := []
			for q in [[i, a0], [i, a1], [i + 1, a1], [i + 1, a0]]:
				var rr: float = prof[q[0]][0]; var yy: float = prof[q[0]][1]
				p.append(Vector3(cos(q[1]) * rr, yy, sin(q[1]) * rr))
			for v in [p[0], p[2], p[1], p[0], p[3], p[2]]:
				st.set_uv(Vector2(float(j) / SEG * 4.0, (v as Vector3).y / 6.0)); st.add_vertex(v)
	st.generate_normals()
	var onion := MeshInstance3D.new(); onion.mesh = st.commit(); onion.material_override = gold
	dome.add_child(onion)
	var drm := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 5.4; cm.bottom_radius = 5.8; cm.height = 9.0; cm.radial_segments = 16
	drm.mesh = cm; drm.material_override = drum; drm.position.y = 2.5; dome.add_child(drm)
	for arm in [[Vector3(0, 30, 0), Vector3(0.25, 4.0, 0.25)], [Vector3(0, 30.8, 0), Vector3(1.4, 0.22, 0.22)], [Vector3(0, 29.4, 0), Vector3(0.9, 0.18, 0.18)]]:
		var m := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = arm[1] * 2.0; m.mesh = b; m.material_override = gold
		m.position = arm[0] + Vector3(0, -3.0, 0); dome.add_child(m)
	for mi in dome.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# ---------------------------------------------------------------- per frame
var _t := 0.0
func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	if not cam or not visible:
		return
	var eye := cam.global_position
	# the dome keeps its distance
	if dome:
		dome.global_position = Vector3(eye.x, global_position.y + 4.0, eye.z + 46.0)
	# gas: a slow, soft breathing, never a flicker; lamps beyond the fog are off
	for l in lamps:
		var d := l.global_position.distance_to(eye)
		l.visible = d < 30.0
		if l.visible:
			var sd: float = l.get_meta("seed")
			l.light_energy = 2.4 * (0.93 + 0.05 * sin(_t * 1.3 + sd) + 0.02 * sin(_t * 3.1 + sd * 2.0))

## The main street goes on for ever: walk off either end and you are at the other. Call with a
## body's position (local space); returns where it really is.
func wrap(local: Vector3) -> Vector3:
	var r := floori(local.z / CELL)
	if r < 3 or r > 6:
		return local
	if local.x < 1.0 * CELL:
		return local + Vector3(PERIOD * CELL, 0, 0)
	if local.x >= (PERIOD + 1) * CELL:
		return local - Vector3(PERIOD * CELL, 0, 0)
	return local
