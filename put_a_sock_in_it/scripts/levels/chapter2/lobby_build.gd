class_name LobbyBuild
## The building of Chapter 2 (docs/CHAPTER2.md), from a room table: three floors on a 24 x 14 m
## plan, a corridor down the middle of each, flats either side, the stairwell at the east end
## (a switchback: up the west side to a half-landing, back up the east side), the lift shaft by it,
## and the maintenance ladder in a closet at the west end of each corridor.
##
##   ground   the lobby and its entrance (chained), the super's office and his flat behind it,
##            maintenance (the breaker, the boiler, a chest freezer), the laundry, 2, 3
##   first    11 12 13, the fuse closet by the lift, storage, 14 15 16
##   second   21 22 23, the valve closet, 24 25 26, and 27

const FH := 3.2                 # floor to floor
const CH := 3.0                 # floor to ceiling
const T := 0.15                 # walls
const W := 24.0
const D := 14.0
const DOOR_W := 0.9
const DOOR_H := 2.05
const SHAFT := Rect2(16.3, 3.6, 2.0, 2.4)      # the lift (x, z, w, d)
const CLOSET := Rect2(0.0, 6.0, 1.5, 2.0)      # the ladder

## id, floor, side (s: z 0..6, n: z 8..14), x0, x1, door x on the corridor ("" none), lock, look
const ROOMS := [
	["flat1", 0, "s", 0.0, 5.0, "", "super", "home"],
	["office", 0, "s", 5.0, 8.0, 6.5, "", "office"],
	["lobby", 0, "s", 8.0, 16.0, "", "", "lobby"],
	["maint", 0, "s", 18.3, 20.0, 19.15, "maint", "maint"],
	["laundry", 0, "n", 1.5, 7.0, 4.2, "", "laundry"],
	["flat2", 0, "n", 7.0, 12.0, 9.5, "key2", "home"],
	["flat3", 0, "n", 12.0, 17.0, 14.5, "", "den"],
	["flat11", 1, "s", 0.0, 5.0, 3.0, "", "home"],
	["flat12", 1, "s", 5.0, 10.0, 8.5, "", "kitchen"],
	["flat13", 1, "s", 10.0, 16.0, 13.0, "", "home"],
	["fuses", 1, "s", 18.3, 20.0, 19.15, "", "closet"],
	["storage", 1, "n", 1.5, 5.0, 3.2, "", "storage"],
	["flat14", 1, "n", 5.0, 10.0, 7.5, "", "home"],
	["flat15", 1, "n", 10.0, 15.0, 12.5, "", "home"],
	["flat16", 1, "n", 15.0, 20.0, 17.5, "key16", "home"],
	["flat21", 2, "s", 0.0, 6.0, 4.0, "", "rot"],
	["flat22", 2, "s", 6.0, 12.0, 9.0, "", "rot"],
	["flat23", 2, "s", 12.0, 16.0, 14.0, "", "rot"],
	["valves", 2, "s", 18.3, 20.0, 19.15, "", "closet"],
	["flat24", 2, "n", 1.5, 6.0, 3.8, "", "rot"],
	["flat25", 2, "n", 6.0, 10.0, 8.0, "", "rot"],
	["flat26", 2, "n", 10.0, 15.0, 12.5, "", "rot"],
	["flat27", 2, "n", 15.0, 20.0, 17.5, "", "rot"],
]

static func room(id: String) -> Array:
	for r in ROOMS: if r[0] == id: return r
	return []

static func centre(id: String, y := 0.0) -> Vector3:
	var r := room(id)
	var z0 := 0.0 if r[2] == "s" else 8.0; var z1 := 6.0 if r[2] == "s" else 14.0
	if id == "maint" or id == "fuses" or id == "valves": z0 = 3.6
	return Vector3((float(r[3]) + float(r[4])) * 0.5, float(r[1]) * FH + y, (z0 + z1) * 0.5)

static func door_at(id: String) -> Vector3:
	var r := room(id)
	return Vector3(float(r[5]), float(r[1]) * FH, 6.0 if r[2] == "s" else 8.0)

## Whether a point is in a room (its floor, its walls).
static func in_room(id: String, p: Vector3) -> bool:
	var r := room(id)
	if r.is_empty(): return false
	var y0 := float(r[1]) * FH
	var z0 := 0.0 if r[2] == "s" else 8.0; var z1 := 6.0 if r[2] == "s" else 14.0
	return p.x > float(r[3]) and p.x < float(r[4]) and p.z > z0 and p.z < z1 and p.y > y0 - 0.3 and p.y < y0 + CH

static func floor_of(p: Vector3) -> int:
	return clampi(int(floor((p.y + 0.6) / FH)), 0, 2)

# ------------------------------------------------------------------ building it
## Builds everything solid into `root` and returns {"doors": {room id: Door}, "entrance": [Door,
## Door], "closet_doors": [Door x3]}.
static func build(root: Node3D) -> Dictionary:
	var out := {"doors": {}, "entrance": [], "closet_doors": []}
	var mats := _materials()
	for f in 3:
		var y0 := f * FH
		var m: Dictionary = mats[f]
		_slabs(root, f, m)
		_walls(root, f, m, out)
	_stairs(root, mats)
	# the roof
	Build.box(root, Vector3(W * 0.5, 3 * FH + 0.1, D * 0.5), Vector3(W, 0.2, D), mats[2].ceil)
	return out

static func _materials() -> Array:
	var g := {"floor": Tex.mat("metlakh", 0.8), "wall": Tex.mat("stairwell", 0.25), "flat": Tex.mat("wallpaper", 0.6),
		"ceil": Tex.mat("plaster", 0.6, {"tint": Color(0.85, 0.83, 0.78)}), "flatfloor": Tex.mat("parquet", 1.0)}
	var f1 := {"floor": Tex.mat("lino", 1.0, {"tint": Color(0.8, 0.75, 0.68)}), "wall": Tex.mat("stairwell", 0.25, {"tint": Color(0.9, 0.9, 0.85)}), "flat": Tex.mat("wallpaper_bed", 0.6),
		"ceil": Tex.mat("plaster", 0.6, {"tint": Color(0.75, 0.72, 0.68)}), "flatfloor": Tex.mat("parquet", 1.0, {"tint": Color(0.8, 0.75, 0.7)})}
	var f2 := {"floor": Tex.mat("flesh_dark", 1.0, {"pulse": 0.004}), "wall": Tex.mat("wallpaper_flesh", 0.6, {"pulse": 0.006}), "flat": Tex.mat("wallpaper_flesh", 0.6, {"pulse": 0.006}),
		"ceil": Tex.mat("flesh", 0.8, {"pulse": 0.006, "tint": Color(0.7, 0.6, 0.6)}), "flatfloor": Tex.mat("flesh_dark", 1.0, {"pulse": 0.004})}
	return [g, f1, f2]

static func _slabs(root: Node3D, f: int, m: Dictionary) -> void:
	var y0 := f * FH
	# the floor of the building part (x 0..20), less the lift shaft above the ground
	var pieces := [Rect2(0, 0, SHAFT.position.x, D), Rect2(SHAFT.end.x, 0, 20.0 - SHAFT.end.x, D),
		Rect2(SHAFT.position.x, 0, SHAFT.size.x, SHAFT.position.y), Rect2(SHAFT.position.x, SHAFT.end.y, SHAFT.size.x, D - SHAFT.end.y)]
	if f == 0: pieces = [Rect2(0, 0, 20.0, D)]
	for r in pieces:
		var c: Vector2 = r.get_center()
		Build.box(root, Vector3(c.x, y0 - 0.1, c.y), Vector3(r.size.x, 0.2, r.size.y), m.floor)
	# the stairwell: its floor (ground), its landings
	if f == 0: Build.box(root, Vector3(22.0, -0.1, D * 0.5), Vector3(4.0, 0.2, D), m.floor)
	else: Build.box(root, Vector3(22.0, y0 - 0.1, 7.0), Vector3(4.0, 0.2, 3.0), m.floor)

static func _walls(root: Node3D, f: int, m: Dictionary, out: Dictionary) -> void:
	var y0 := f * FH
	var ext: Material = Tex.mat("plaster", 0.6, {"tint": Color(0.7, 0.68, 0.62)}) if f < 2 else m.wall
	# outside walls, floor to floor
	var south_open := []
	if f == 0: south_open = [{"at": 12.0, "w": 2.0, "top": 2.3}]
	Build.wall(root, Vector2(0, 0), Vector2(W, 0), ext, south_open, FH, T, y0)
	Build.wall(root, Vector2(0, D), Vector2(W, D), ext, [], FH, T, y0)
	Build.wall(root, Vector2(0, 0), Vector2(0, D), ext, [], FH, T, y0)
	Build.wall(root, Vector2(W, 0), Vector2(W, D), ext, [], FH, T, y0)
	if f == 0:
		# the way in: two leaves, chained shut
		for s in [-1, 1]:
			var d := _door(root, Vector3(12.0 + s * 1.0, y0, 0.0), 0.0 if s < 0 else PI, 1.0, "front door", m)
			d.blocked = true; out.entrance.append(d)
	# the corridor's walls, with the flats' doors
	var south_cuts := []; var north_cuts := []
	for r in ROOMS:
		if int(r[1]) != f or typeof(r[5]) == TYPE_STRING: continue
		(south_cuts if r[2] == "s" else north_cuts).append({"at": float(r[5]), "w": DOOR_W + 0.15, "top": DOOR_H + 0.05})
	south_cuts.append({"at": SHAFT.get_center().x, "w": 1.3, "top": 2.15})       # the lift's doors
	if f == 0:
		# the lobby is open to the corridor
		Build.wall(root, Vector2(CLOSET.end.x, 6.0), Vector2(8.0, 6.0), m.wall, south_cuts.filter(func(c): return c.at < 8.0).map(func(c): c = c.duplicate(); c.at -= CLOSET.end.x; return c), CH, T, y0)
		Build.wall(root, Vector2(16.0, 6.0), Vector2(20.0, 6.0), m.wall, south_cuts.filter(func(c): return c.at > 16.0).map(func(c): c = c.duplicate(); c.at -= 16.0; return c), CH, T, y0)
	else:
		Build.wall(root, Vector2(CLOSET.end.x, 6.0), Vector2(20.0, 6.0), m.wall, south_cuts.map(func(c): c = c.duplicate(); c.at -= CLOSET.end.x; return c), CH, T, y0)
	Build.wall(root, Vector2(CLOSET.end.x, 8.0), Vector2(20.0, 8.0), m.wall, north_cuts.map(func(c): c = c.duplicate(); c.at -= CLOSET.end.x; return c), CH, T, y0)
	# the ladder closet
	Build.wall(root, Vector2(0, 6.0), Vector2(CLOSET.end.x, 6.0), m.wall, [], CH, T, y0)
	Build.wall(root, Vector2(0, 8.0), Vector2(CLOSET.end.x, 8.0), m.wall, [], CH, T, y0)
	Build.wall(root, Vector2(CLOSET.end.x, 6.0), Vector2(CLOSET.end.x, 8.0), m.wall, [{"at": 1.0, "w": DOOR_W + 0.15, "top": DOOR_H + 0.05}], CH, T, y0)
	var cd := _door(root, Vector3(CLOSET.end.x, y0, 6.55), -PI * 0.5, DOOR_W, "door", m)
	cd.locked = f == 0
	out.closet_doors.append(cd)
	# the stairwell's west wall, open to the corridor
	Build.wall(root, Vector2(20.0, 0), Vector2(20.0, D), m.wall, [{"at": 7.0, "w": 2.0, "top": 2.3}], FH, T, y0)
	# the lift shaft
	Build.wall(root, Vector2(SHAFT.position.x, SHAFT.position.y), Vector2(SHAFT.end.x, SHAFT.position.y), ext, [], FH, T, y0)
	Build.wall(root, Vector2(SHAFT.position.x, SHAFT.position.y), Vector2(SHAFT.position.x, SHAFT.end.y), ext, [], FH, T, y0)
	Build.wall(root, Vector2(SHAFT.end.x, SHAFT.position.y), Vector2(SHAFT.end.x, SHAFT.end.y), ext, [], FH, T, y0)
	# partitions between the flats (each x once per side), and the flats' doors
	var seen := {}
	for r in ROOMS:
		if int(r[1]) != f: continue
		var z0 := 0.0 if r[2] == "s" else 8.0; var z1 := 6.0 if r[2] == "s" else 14.0
		if r[0] in ["maint", "fuses", "valves"]:
			# a closet off the corridor, beside the shaft
			Build.wall(root, Vector2(SHAFT.end.x, 3.6), Vector2(20.0, 3.6), m.wall, [], CH, T, y0)
			if r[0] == "maint":
				Build.wall(root, Vector2(16.0, 3.6), Vector2(SHAFT.position.x, 3.6), m.wall, [], CH, T, y0)
		for x in [float(r[3]), float(r[4])]:
			var key := "%s%.2f" % [r[2], x]
			if seen.has(key) or x <= 0.0 or x >= 20.0: continue
			if f == 0 and r[2] == "s" and (x == 8.0 or x == 16.0) and r[0] != "office": pass
			seen[key] = true
			if r[0] in ["maint", "fuses", "valves"] and x == 18.3: continue          # (the shaft's wall)
			var zz0 := z0; var zz1 := z1
			if r[2] == "s" and x == 16.0 and f > 0: zz1 = 3.6
			if r[2] == "s" and x == 18.3: zz1 = 3.6
			var cuts := []
			if r[0] == "flat1" and x == 5.0: cuts = [{"at": 3.0, "w": DOOR_W + 0.15, "top": DOOR_H + 0.05}]      # his flat, off the office
			if r[0] == "office" and x == 8.0:
				Build.wall(root, Vector2(x, z0), Vector2(x, z1), m.wall, [{"at": 3.5, "w": 2.0, "top": 2.0, "bottom": 1.0}], CH, T, y0)   # the reception window
				continue
			Build.wall(root, Vector2(x, zz0), Vector2(x, zz1), m.flat if r[0] != "lobby" else m.wall, cuts, CH, T, y0)
		if typeof(r[5]) != TYPE_STRING:
			var dz := 6.0 if r[2] == "s" else 8.0
			var d := _door(root, Vector3(float(r[5]) - DOOR_W * 0.5, y0, dz), 0.0, DOOR_W, _door_name(r[0]), m)
			d.locked = String(r[6]) != ""
			out.doors[r[0]] = d
	# the door from the office into his flat
	if f == 0:
		var hd := _door(root, Vector3(5.0, 0.0, 3.0 - DOOR_W * 0.5), -PI * 0.5, DOOR_W, "door", m)
		hd.locked = true
		out.doors["flat1"] = hd

static func _door_name(id: String) -> String:
	if id.begins_with("flat"): return id.substr(4)
	match id:
		"maint": return "maintenance"
		"fuses", "valves": return "door"
	return id

static func _door(root: Node3D, hinge: Vector3, rot: float, w: float, nm: String, m: Dictionary) -> Door:
	var d := Door.new(); d.width = w; d.height = DOOR_H; d.panel_layer = 32
	d.material = Tex.mat("paint_door", 1.0, {"tint": Color(0.55, 0.45, 0.35)}) if m.has("wall") else null
	d.name_text = nm
	root.add_child(d); d.position = hinge; d.rotation.y = rot
	return d

## The stairs: ground to first, first to second (the second floor's are blocked half way).
static func _stairs(root: Node3D, mats: Array) -> void:
	for f in 2:
		var y0 := f * FH
		var m: Dictionary = mats[f]
		# up the west side, north, to the half-landing
		for i in 10:
			var top := y0 + 0.16 * (i + 1)
			Build.box(root, Vector3(21.07, top - 0.1, 8.5 + i * 0.49 + 0.245), Vector3(1.85, 0.2, 0.49), m.floor, false)
		_ramp(root, Vector3(21.07, y0, 8.5), Vector3(21.07, y0 + 1.6, 13.4), 1.85)
		Build.box(root, Vector3(22.0, y0 + 1.6 - 0.1, 13.7), Vector3(4.0, 0.2, 0.6), m.floor)
		# and back down the east side to the next floor's landing
		for j in 10:
			var top2 := y0 + 1.6 + 0.16 * (j + 1)
			Build.box(root, Vector3(22.95, top2 - 0.1, 13.4 - (j + 1) * 0.49 + 0.245), Vector3(1.85, 0.2, 0.49), m.floor, false)
		_ramp(root, Vector3(22.95, y0 + 1.6, 13.4), Vector3(22.95, y0 + 3.2, 8.5), 1.85)
		# (the half-landing under the meat on the first floor is solid: the stairs end there)
		# a rail between the two flights
		Build.box(root, Vector3(22.0, y0 + 1.6, 11.0), Vector3(0.06, 3.2, 4.8), Tex.mat("gunmetal"))

## What feet walk on, under the steps: a slope from a (bottom, centre of the edge) to b (top),
## `w` wide. Invisible; the steps are what you see. (Nobody but Kurt can step up a stair.)
static func _ramp(root: Node3D, a: Vector3, b: Vector3, w: float) -> void:
	var sb := StaticBody3D.new(); root.add_child(sb)
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new()
	var run := Vector2(b.z - a.z, b.y - a.y)
	sh.size = Vector3(w, 0.08, run.length() + 0.1); cs.shape = sh; sb.add_child(cs)
	sb.position = (a + b) * 0.5 + Vector3(0, -0.04, 0)
	var ang := atan2(b.y - a.y, b.z - a.z)
	sb.rotation.x = -ang
