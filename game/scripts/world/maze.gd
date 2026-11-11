class_name Maze
extends Node3D
## Behind the wardrobe: the walls. The box room's back wall has gone through into a maze of
## passages that has no business fitting behind a flat: papered in the building's wallpapers,
## lath and brick where it's broken, low, close, lit by bulbs on the walls' own circuits. It runs
## behind the whole flat and breaks back into it in two more places (Sonya's room, the bathroom).
## Marta lives in it now. So do others.
##
## Built from MAP: one character per 1.25 m cell. Row 0 lies against the flat's south wall.
##   #  solid       .  passage      +  a door        E/c/b  where it opens into the flat
##   N  the nursery (Sonya's door)   G  the hanging room (no weight; the revolver)
##   B  the breaker room             W  flooded       P  the porter's lodge
##   F  the white room (the figures) X  the service ring (the Super)   S  the service door out

const CELL := 1.25
const X0 := -10.05
const Z0 := 8.42
const CEIL := 2.3
const MAP := [
	"#########E##c#bb#######",
	"#.......#.#.......#.SS#",
	"#.###.#.#.#.#####.#.#.#",
	"#.#NN.#...#.#BB.#...#.#",
	"#.#NN.#####.#BB.#####.#",
	"#.#.......#...+.#XXXXX#",
	"#.#####.#.###.###X###X#",
	"#...#...#...#...#X#.+X#",
	"###.#.#####.#.#.#X#.#X#",
	"#...#.#GGG#.#.#...#.#X#",
	"#.###.#GGG..#.#####.#X#",
	"#.#...#GGG#.#.....#.#X#",
	"#.#.###.###.#####.#.#X#",
	"#.#...#.WWWWWW#...#.+X#",
	"#.###.#.#####W#.###.#X#",
	"#...+.#...PP#W#.FFF.#X#",
	"#.#####.#.PP#W#.FFF.#X#",
	"#.......#...#W..FFF.XX#",
	"#######################",
]
const ZONE := {".": 20, "E": 20, "c": 20, "b": 20, "+": 20, "N": 21, "G": 22, "B": 23, "W": 24, "P": 25, "F": 26, "X": 27, "S": 28}
const CHAMBER_LIGHT := {
	"N": [Color(1.0, 0.75, 0.55), 0.7, "", "candle"], "G": [Color(0.75, 0.82, 1.0), 0.9, "M3", ""],
	"B": [Color(1.0, 0.92, 0.7), 0.8, "", "dying"], "W": [Color(0.7, 0.85, 0.8), 0.5, "M1", ""],
	"P": [Color(1.0, 0.8, 0.5), 0.75, "", "candle"], "F": [Color(0.95, 0.96, 1.0), 1.1, "", "fluoro"],
	"X": [Color(0.9, 0.5, 0.35), 0.45, "M2", "dying"], "S": [Color(0.6, 0.9, 0.6), 0.5, "M2", ""],
}

var cells := {}                 ## Vector2i -> char
var nav: Nav
var doors := {}                 ## "r_c" -> Door
var chambers := {}              ## char -> AABB
var lamps: Array[Lamp] = []
var water: WaterBody
var water_leg: WaterBody
var gravity: GravityZone
var _rng := RandomNumberGenerator.new()

func build(p_nav: Nav) -> void:
	nav = p_nav
	_rng.seed = 1947
	for r in MAP.size():
		var row: String = MAP[r]
		for c in row.length():
			cells[Vector2i(c, r)] = row[c]
	_geometry()
	_collision()
	_doors()
	_lights()
	_nav()
	_systems()
	for z in [5, 6, 7]:
		Lights.set_link(z, 20, true)
	Log.mark("maze built: %d cells, %d lamps" % [cells.size(), lamps.size()])

func ch(c: int, r: int) -> String:
	return String(cells.get(Vector2i(c, r), "#"))

func is_open(c: int, r: int) -> bool:
	return ch(c, r) != "#"

func center(c: int, r: int) -> Vector3:
	return Vector3(X0 + (c + 0.5) * CELL, 0.0, Z0 + (r + 0.5) * CELL)

func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - X0) / CELL), floori((p.z - Z0) / CELL))

func zone_of(p: Vector3) -> int:
	if p.z < Z0: return -1
	var k := cell_of(p)
	if not cells.has(k): return -1
	return int(ZONE.get(cells[k], 20))

func surface_of(p: Vector3) -> String:
	var k := ch(cell_of(p).x, cell_of(p).y)
	match k:
		"F": return "step_tile"
		"X", "S", "B": return "step_tile"
	return "step_wood"

func chamber_center(k: String) -> Vector3:
	var a: AABB = chambers.get(k, AABB())
	return a.get_center() * Vector3(1, 0, 1)

# ------------------------------------------------------------------------------------ building
func _wall_tex(c: int, r: int, k: String) -> Material:
	var z := int(ZONE.get(k, 20))
	match k:
		"F": return Mats.tex(Tex.get_tex("draft"), z)
		"X", "S": return Mats.tex(Tex.get_tex("concrete"), z)
		"B": return Mats.tex(Tex.get_tex("plaster_dark"), z)
		"N": return Mats.tex(Tex.get_tex("wallpaper_rose"), z)
		"G": return Mats.tex(Tex.get_tex("brick"), z)
		"P": return Mats.tex(Tex.get_tex("wallpaper_green"), z)
	var opts := ["plaster", "wallpaper_green", "wallpaper_rose", "lath", "damp", "plaster", "brick"]
	var i := absi((c * 7 + r * 13 + (c / 3) * 5) % opts.size())
	return Mats.tex(Tex.get_tex(opts[i]), z)

func _geometry() -> void:
	var kit := Kit.new()
	var bounds := AABB()
	for key in cells:
		var k: String = cells[key]
		if k == "#": continue
		var c: int = key.x; var r: int = key.y
		var z := int(ZONE.get(k, 20))
		var x0 := X0 + c * CELL; var x1 := x0 + CELL
		var z0 := Z0 + r * CELL; var z1 := z0 + CELL
		var floor_m := Mats.tex(Tex.get_tex("draft" if k == "F" else ("concrete" if k in ["X", "S", "W", "B"] else "floorboards")), z)
		kit.quad(floor_m, Vector3(x0, 0, z1), Vector3(x1, 0, z1), Vector3(x1, 0, z0), Vector3(x0, 0, z0))
		var ceil_m := Mats.tex(Tex.get_tex("draft" if k == "F" else "plaster_dark"), z)
		var ch_y := CEIL + (0.9 if k in ["G", "F"] else 0.0)
		kit.quad(ceil_m, Vector3(x0, ch_y, z0), Vector3(x1, ch_y, z0), Vector3(x1, ch_y, z1), Vector3(x0, ch_y, z1))
		# walls where the neighbour is solid (row 0's north side is the flat's own wall)
		var wm := _wall_tex(c, r, k)
		if not is_open(c, r - 1) and r > 0:
			kit.quad(wm, Vector3(x1, 0, z0), Vector3(x0, 0, z0), Vector3(x0, ch_y, z0), Vector3(x1, ch_y, z0))
		elif r == 0:
			kit.quad(wm, Vector3(x1, 1.35 if k == "b" else (1.22 if k == "c" else 2.05), z0 - 0.02), Vector3(x0, 1.35 if k == "b" else (1.22 if k == "c" else 2.05), z0 - 0.02), Vector3(x0, ch_y, z0 - 0.02), Vector3(x1, ch_y, z0 - 0.02))
		if not is_open(c, r + 1):
			kit.quad(wm, Vector3(x0, 0, z1), Vector3(x1, 0, z1), Vector3(x1, ch_y, z1), Vector3(x0, ch_y, z1))
		if not is_open(c - 1, r):
			kit.quad(wm, Vector3(x0, 0, z0), Vector3(x0, 0, z1), Vector3(x0, ch_y, z1), Vector3(x0, ch_y, z0))
		if not is_open(c + 1, r):
			kit.quad(wm, Vector3(x1, 0, z1), Vector3(x1, 0, z0), Vector3(x1, ch_y, z0), Vector3(x1, ch_y, z1))
		# a taller room next to a lower passage: close the step in the ceiling
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nk := ch(c + d.x, r + d.y)
			if nk != "#" and ch_y > CEIL + 0.1 and not (nk in ["G", "F"]):
				var a := Vector3(x0 if d.x <= 0 else x1, CEIL, z0 if d.y <= 0 else z1)
				if d.x != 0:
					kit.quad(wm, Vector3(a.x, CEIL, z0), Vector3(a.x, CEIL, z1), Vector3(a.x, ch_y, z1), Vector3(a.x, ch_y, z0))
				else:
					kit.quad(wm, Vector3(x0, CEIL, a.z), Vector3(x1, CEIL, a.z), Vector3(x1, ch_y, a.z), Vector3(x0, ch_y, a.z))
		if not chambers.has(k) and k not in [".", "+", "E", "c", "b"]:
			chambers[k] = AABB(Vector3(x0, 0, z0), Vector3(CELL, ch_y, CELL))
		elif chambers.has(k):
			chambers[k] = (chambers[k] as AABB).merge(AABB(Vector3(x0, 0, z0), Vector3(CELL, ch_y, CELL)))
		# skirting, pipes, coral: what makes a passage a place
		if k == "." and _rng.randf() < 0.18:
			var y := _rng.randf_range(1.6, 2.1)
			var wall_side := -1 if not is_open(c - 1, r) else (1 if not is_open(c + 1, r) else 0)
			if wall_side != 0:
				var px := (x0 + 0.06) if wall_side < 0 else (x1 - 0.06)
				kit.box(Mats.tex(Tex.get_tex("rust"), z), Vector3(px, y, (z0 + z1) * 0.5), Vector3(0.07, 0.07, CELL))
	# the den's mouth: from the box room's broken back wall into row 0 is one long throat of lath
	for mi in kit.commit(self, "Maze"):
		(mi.material_override as ShaderMaterial).set_shader_parameter("ambient", Vector3(0.16, 0.15, 0.15))
	_coral()

## Marta's coral, growing where she's been most: thickest round the nursery and toward the flat.
func _coral() -> void:
	var kit := Kit.new()
	var mat := Mats.tex(Tex.get_tex("coral"), -1)
	for key in cells:
		var k: String = cells[key]
		if k == "#": continue
		var p := center(key.x, key.y)
		var near_n := p.distance_to(chamber_center("N")) if chambers.has("N") else 99.0
		var chance := 0.55 if near_n < 4.0 else (0.12 if k == "." else 0.05)
		if k in ["F", "S", "X"]: chance = 0.0
		if _rng.randf() > chance: continue
		for i in _rng.randi_range(2, 6):
			var side := _rng.randi_range(0, 3)
			var off := Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(0.0, 2.0), _rng.randf_range(-0.5, 0.5))
			match side:
				0: off.x = -CELL * 0.5 + 0.05
				1: off.x = CELL * 0.5 - 0.05
				2: off.z = -CELL * 0.5 + 0.05
				3: off.z = CELL * 0.5 - 0.05
			var q := p + off
			var cc := cell_of(q + (q - p).normalized() * 0.2)
			if is_open(cc.x, cc.y) and cc != key: continue
			kit.blob(mat, q, Vector3(_rng.randf_range(0.04, 0.12), _rng.randf_range(0.06, 0.2), _rng.randf_range(0.04, 0.12)), _rng, 0.35)
	kit.commit(self, "Coral")

func _collision() -> void:
	var body := StaticBody3D.new(); body.name = "MazeWalls"; add_child(body)
	var rows := MAP.size(); var cols: int = (MAP[0] as String).length()
	for r in rows:
		var c := 0
		while c < cols:
			if ch(c, r) != "#": c += 1; continue
			var start := c
			while c < cols and ch(c, r) == "#": c += 1
			var x0 := X0 + start * CELL; var x1 := X0 + c * CELL
			var sh := CollisionShape3D.new(); var b := BoxShape3D.new()
			var top := CEIL + 1.0
			b.size = Vector3(x1 - x0, top + 0.5, CELL)
			sh.shape = b; sh.position = Vector3((x0 + x1) * 0.5, top * 0.5 - 0.25, Z0 + (r + 0.5) * CELL)
			if r == 0:
				b.size.z = CELL - 0.02; sh.position.z += 0.01
			body.add_child(sh)
	var fl := CollisionShape3D.new(); var fb := BoxShape3D.new()
	fb.size = Vector3(cols * CELL, 0.4, rows * CELL); fl.shape = fb
	fl.position = Vector3(X0 + cols * CELL * 0.5, -0.2, Z0 + rows * CELL * 0.5); body.add_child(fl)
	var ce := CollisionShape3D.new(); var cb := BoxShape3D.new()
	cb.size = Vector3(cols * CELL, 0.4, rows * CELL); ce.shape = cb
	ce.position = Vector3(X0 + cols * CELL * 0.5, CEIL + 1.1, Z0 + rows * CELL * 0.5); body.add_child(ce)
	# low ceilings over the passages (the tall rooms go up to CEIL + 0.9)
	for key in cells:
		var k: String = cells[key]
		if k == "#" or k in ["G", "F"]: continue
		var lc := CollisionShape3D.new(); var lb := BoxShape3D.new(); lb.size = Vector3(CELL, 0.2, CELL); lc.shape = lb
		lc.position = center(key.x, key.y) + Vector3(0, CEIL + 0.1, 0); body.add_child(lc)
	# the box room's floor reaches through to row 0
	var bridge := CollisionShape3D.new(); var bb := BoxShape3D.new(); bb.size = Vector3(1.2, 0.4, 0.6); bridge.shape = bb
	bridge.position = Vector3(1.83, -0.2, 8.2); body.add_child(bridge)

func _doors() -> void:
	for key in cells:
		if cells[key] != "+": continue
		var c: int = key.x; var r: int = key.y
		var ew := is_open(c - 1, r) and is_open(c + 1, r)     # passage runs east-west: the leaf spans z
		var ctr := center(c, r)
		var d := Door.new(); d.name = "MazeDoor_%d_%d" % [r, c]
		add_child(d)
		var w := 0.9
		var ex := {"psi0": -PI * 0.5 if ew else 0.0, "sign": 1.0, "max": 1.5, "open": 0.0, "w": w, "h": 2.0}
		if ew: d.position = Vector3(ctr.x, 0, ctr.z - w * 0.5)
		else: d.position = Vector3(ctr.x - w * 0.5, 0, ctr.z)
		d.setup("m%d_%d" % [r, c], ex)
		d.zone_a = 20; d.zone_b = 20
		var kit := Kit.new()
		var wood := Mats.tex(Tex.get_tex("floorboards"), -1, Color(0.85, 0.75, 0.7))
		kit.box(wood, Vector3(w * 0.5, 1.0, 0), Vector3(w - 0.03, 2.0, 0.045))
		kit.box(Mats.flat(Color(0.65, 0.6, 0.45), -1), Vector3(w - 0.1, 1.0, 0.05), Vector3(0.03, 0.03, 0.05))
		kit.commit(d, "Leaf")
		# frame: fill the cell's width either side of the leaf
		var jk := Kit.new()
		var jm := _wall_tex(c, r, ".")
		var gap := (CELL - w) * 0.5
		if ew:
			jk.box(jm, ctr + Vector3(0, 1.15, -CELL * 0.5 + gap * 0.5 - 0.0), Vector3(0.18, 2.3, gap))
			jk.box(jm, ctr + Vector3(0, 1.15, CELL * 0.5 - gap * 0.5), Vector3(0.18, 2.3, gap))
			jk.box(jm, ctr + Vector3(0, 2.15, 0), Vector3(0.18, 0.3, CELL))
		else:
			jk.box(jm, ctr + Vector3(-CELL * 0.5 + gap * 0.5, 1.15, 0), Vector3(gap, 2.3, 0.18))
			jk.box(jm, ctr + Vector3(CELL * 0.5 - gap * 0.5, 1.15, 0), Vector3(gap, 2.3, 0.18))
			jk.box(jm, ctr + Vector3(0, 2.15, 0), Vector3(CELL, 0.3, 0.18))
		jk.commit(self, "Frame")
		var sb := StaticBody3D.new(); add_child(sb)
		for off in ([Vector3(0, 0, -CELL * 0.5 + gap * 0.5), Vector3(0, 0, CELL * 0.5 - gap * 0.5)] if ew else [Vector3(-CELL * 0.5 + gap * 0.5, 0, 0), Vector3(CELL * 0.5 - gap * 0.5, 0, 0)]):
			var cs := CollisionShape3D.new(); var b := BoxShape3D.new()
			b.size = Vector3(0.18, 2.3, gap) if ew else Vector3(gap, 2.3, 0.18)
			cs.shape = b; cs.position = ctr + off + Vector3(0, 1.15, 0); sb.add_child(cs)
		# bolts: each door bolts from the side away from the flat (row lower = nearer the flat)
		d.bolt = "a"
		doors["%d_%d" % [r, c]] = d

func _lights() -> void:
	Power.add("M1", "Walls: west passages", true)
	Power.add("M2", "Walls: service", true, false)       # no fuse: the service side is dead
	Power.add("M3", "Walls: the hanging room", false)
	var done := {}
	for key in cells:
		var k: String = cells[key]
		if k == "X":
			if (key.x + key.y) % 3 == 0:
				lamps.append(Lamp.make(self, center(key.x, key.y) + Vector3(0, CEIL - 0.2, 0), Color(0.9, 0.5, 0.35), 0.45, 4.0, PackedInt32Array([27, 20]), "M2", "dying"))
			continue
		if CHAMBER_LIGHT.has(k) and not done.has(k):
			done[k] = true
			var spec: Array = CHAMBER_LIGHT[k]
			var a: AABB = chambers[k]
			var p := a.get_center() + Vector3(0, a.size.y * 0.5 - 0.25, 0)
			var l := Lamp.make(self, p, spec[0], spec[1], maxf(a.size.x, a.size.z) * 0.9 + 2.5, PackedInt32Array([int(ZONE[k]), 20]), spec[2], spec[3])
			lamps.append(l)
	# the hanging room has a light of its own, cold, from nothing in particular
	var gc: AABB = chambers["G"]
	lamps.append(Lamp.make(self, gc.get_center() + Vector3(0, 0.6, 0), Color(0.55, 0.65, 0.9), 0.45, 4.5, PackedInt32Array([22, 20]), "", "glow"))
	# bulbs along the passages: the west side on M1, the east on M2 (dead), a few on nothing
	var n := 0
	for key in cells:
		var k: String = cells[key]
		if k != ".": continue
		if (key.x * 7 + key.y * 5) % 5 != 0: continue
		var circ := "M1" if key.x < 11 else "M2"
		var zs := PackedInt32Array([20])
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nk := ch(key.x + d.x, key.y + d.y)
			if ZONE.has(nk) and int(ZONE[nk]) != 20 and not zs.has(int(ZONE[nk])): zs.append(int(ZONE[nk]))
		var l := Lamp.make(self, center(key.x, key.y) + Vector3(0, CEIL - 0.2, 0), Color(1.0, 0.82, 0.6), 0.75, 4.6, zs, circ, "dying" if n % 3 == 0 else "")
		l.name = "Bulb%d" % n
		l.add_to_group("maze_bulbs")
		lamps.append(l)
		n += 1
		var kit := Kit.new()
		kit.box(Mats.flat(Color(1, 0.9, 0.7), -1, 1.0), l.global_position, Vector3(0.06, 0.08, 0.06))
		kit.commit(self, "Bulb")

func _nav() -> void:
	var idx := {}
	for key in cells:
		if cells[key] == "#": continue
		idx[key] = nav.add(center(key.x, key.y), "maze_%d_%d" % [key.x, key.y])
	for key in idx:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var o: Vector2i = key + d
			if idx.has(o):
				var door = null
				if cells[key] == "+": door = doors.get("%d_%d" % [key.y, key.x])
				elif cells[o] == "+": door = doors.get("%d_%d" % [o.y, o.x])
				nav.join(idx[key], idx[o], door)

func _systems() -> void:
	# the flooded passage
	# (an L: along row 13, then down column 13; two bodies, one level)
	water = WaterBody.new(); water.name = "Flood"; add_child(water)
	water.setup("flood", Rect2(X0 + 8 * CELL, Z0 + 13 * CELL, 6 * CELL, CELL), 0.0, 0.6, 0.42, 24)
	water.colour = Color(0.06, 0.07, 0.06, 0.82)
	water_leg = WaterBody.new(); water_leg.name = "FloodLeg"; add_child(water_leg)
	water_leg.setup("floodleg", Rect2(X0 + 13 * CELL, Z0 + 14 * CELL, CELL, 4 * CELL), 0.0, 0.6, 0.42, 24)
	water_leg.colour = water.colour
	water.level_changed.connect(func(l): water_leg.level = l; water_leg._place())
	# the hanging room: nothing weighs anything while its circuit is dead
	var ga: AABB = chambers["G"]
	gravity = GravityZone.make(self, AABB(ga.position, Vector3(ga.size.x, CEIL + 0.9, ga.size.z)), Vector3.DOWN, 0.0, "M3", false)
