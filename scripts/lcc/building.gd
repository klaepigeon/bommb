class_name Building
extends RefCounted
## The bingo hall as one building you can walk through: the hall itself, the rooms off it
## (data/hall/rooms.json, each placed against the hall wall with its door in the shared wall),
## the cellar stair, the back corridor. Pure data and geometry, no nodes: what is where, which
## areas join through which doors, how high the floor is at any point, and a walk grid that
## the walker moves and paths on. Everything you can stand in front of and touch, every door,
## every trigger zone comes from data, so new rooms, locks, puzzles and scares are data too.
##
## Coordinates: metres, +y up. The game table is at the origin; the stage is toward -z.
## Every area is an axis-aligned box (rooms may be turned in quarter turns only).

const CELL := 0.15          # walk grid resolution
const RADIUS := 0.24        # how wide a person is (half)
const EYE := 1.6

var db: ContentDB
var areas: Dictionary = {}      # id -> {id, rect (Rect2 xz), floor, height, slope?, room?, xf (Transform3D), platforms}
var area_order: Array = []
var portals: Dictionary = {}    # id -> {id, a, b, at (Vector2), axis ("x"|"z"), width, height, kind, lock, ...}
var windows: Array = []         # {area, at, axis, width, sill, head}
var obstacles: Array = []       # {rect (Rect2), area, name}
var things: Dictionary = {}     # interactable id -> def (with world pos)
var triggers: Array = []
# the grid
var origin := Vector2.ZERO
var gw := 0
var gh := 0
var cells := PackedByteArray()   # 0 blocked, 1 walkable, 2+ portal index + 2 (walkable only when that portal is open)
var portal_ids: Array = []
var open_portals: Dictionary = {}  # id -> true

func _init(content: ContentDB) -> void:
	db = content
	_load()
	_build_grid()
	reset_doors()

## Every door shut; archways (no leaf to shut) stay open.
func reset_doors() -> void:
	open_portals.clear()
	for id in portals.keys():
		if portals[id].get("kind", "door") == "arch":
			open_portals[id] = true

# ------------------------------------------------------------------ loading

static func room_xf(room: Dictionary) -> Transform3D:
	var pl: Dictionary = room.get("place", {})
	var c: Array = pl.get("centre", [0, 0])
	return Transform3D(Basis(Vector3.UP, float(pl.get("rot", 0.0))), Vector3(float(c[0]), float(pl.get("floor", 0.0)), float(c[1])))

## The world-space footprint of a box of size (w along local x, d along local z) under xf.
static func footprint(xf: Transform3D, w: float, d: float) -> Rect2:
	var pts: Array = []
	for p in [Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, 0, -d / 2), Vector3(w / 2, 0, d / 2), Vector3(-w / 2, 0, d / 2)]:
		var q: Vector3 = xf * p
		pts.append(Vector2(q.x, q.z))
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r

static func _r(a: Array) -> Rect2:
	return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))

func _load() -> void:
	for a in db.all("areas"):
		var ar := {"id": a["id"], "name": a.get("name", a["id"]), "rect": _r(a["rect"]), "floor": float(a.get("floor", 0.0)),
			"height": float(a.get("height", 2.9)), "platforms": [], "def": a, "persona": a.get("persona", "")}
		if a.has("slope"):
			ar["slope"] = a["slope"]
		for p in a.get("platforms", []):
			ar["platforms"].append({"rect": _r(p["rect"]), "y": float(p["y"])})
		var c: Vector2 = ar["rect"].get_center()
		ar["xf"] = Transform3D(Basis(), Vector3(c.x, ar["floor"], c.y))
		areas[a["id"]] = ar
		area_order.append(a["id"])
		for o in a.get("obstacles", []):
			obstacles.append({"rect": _r(o["rect"]), "area": a["id"], "name": o.get("name", "")})
	for room in db.all("rooms"):
		var xf := room_xf(room)
		var size: Array = room.get("size", [6.0, 5.0])
		var w := float(size[0])
		var d := float(size[1])
		areas[room["id"]] = {"id": room["id"], "name": room.get("name", room["id"]), "rect": footprint(xf, w, d), "floor": xf.origin.y,
			"height": float(room.get("height", 2.9)), "platforms": [], "room": room, "xf": xf, "def": room, "persona": room.get("persona", "caller")}
		area_order.append(room["id"])
		for p in room.get("props", []):
			if p.get("walk_over", false) or p.get("kind", "box") == "chain":
				continue
			var at: Array = p.get("at", [0, 0])
			var sz: Array = p.get("size", [0.6, 0.6, 0.6])
			var pw := float(sz[0])
			var pd = float(sz[2]) if sz.size() > 2 else 0.6
			if p.get("kind", "") in ["cyl", "barrel", "cage"]:
				pw = float(p.get("r", 0.4)) * 2.0
				pd = pw
			if p.get("kind", "") == "box" and sz.size() > 1 and float(sz[1]) < 0.15:
				continue
			var pxf := xf * Transform3D(Basis(), Vector3(float(at[0]), 0, float(at[1])))
			obstacles.append({"rect": footprint(pxf, pw, pd), "area": room["id"], "name": p.get("name", "")})
		# the room's door into the hall is a portal
		var dd: Dictionary = room.get("door", {})
		var dat: Array = dd.get("at", [0, 0])
		portals["door:" + room["id"]] = {"id": "door:" + room["id"], "a": dd.get("from", "hall"), "b": room["id"],
			"at": Vector2(float(dat[0]), float(dat[1])), "width": float(dd.get("width", 1.0)), "height": float(dd.get("height", 2.1)),
			"kind": dd.get("kind", "door"), "lock": dd.get("lock", {}), "label": room.get("label", room["name"]), "name": room["name"]}
	for p in db.all("portals"):
		var at: Array = p["at"]
		var pd = p.duplicate(true)
		pd["at"] = Vector2(float(at[0]), float(at[1]))
		pd["width"] = float(p.get("width", 1.0))
		pd["height"] = float(p.get("height", 2.1))
		pd["kind"] = p.get("kind", "door")
		pd["lock"] = p.get("lock", {})
		portals[p["id"]] = pd
	for id in portals.keys():
		var p: Dictionary = portals[id]
		p["axis"] = _wall_axis(p)
	for w in db.all("windows"):
		var at2: Array = w["at"]
		var wd = w.duplicate(true)
		wd["at"] = Vector2(float(at2[0]), float(at2[1]))
		windows.append(wd)
	for t in db.all("things"):
		things[t["id"]] = t
	for t in db.all("triggers"):
		triggers.append(t)

## Which way the wall a portal sits in runs: "x" means the wall is a line of constant x.
func _wall_axis(p: Dictionary) -> String:
	var at: Vector2 = p["at"]
	for aid in [p.get("a", ""), p.get("b", "")]:
		if not areas.has(aid):
			continue
		var r: Rect2 = areas[aid]["rect"]
		if absf(at.x - r.position.x) < 0.05 or absf(at.x - r.end.x) < 0.05:
			return "x"
		if absf(at.y - r.position.y) < 0.05 or absf(at.y - r.end.y) < 0.05:
			return "z"
	return "z"

## The doorway as a small rectangle straddling the wall (for the walk grid).
func portal_rect(p: Dictionary, inset := 0.0) -> Rect2:
	var at: Vector2 = p["at"]
	var hw: float = p["width"] / 2.0 - inset
	var depth := RADIUS + 0.2
	if p["axis"] == "x":
		return Rect2(at.x - depth, at.y - hw, depth * 2, hw * 2)
	return Rect2(at.x - hw, at.y - depth, hw * 2, depth * 2)

## Unit vector pointing from area a into area b through the portal.
func portal_dir(p: Dictionary) -> Vector2:
	var at: Vector2 = p["at"]
	if areas.has(p.get("b", "")):
		var c: Vector2 = areas[p["b"]]["rect"].get_center()
		return Vector2(signf(c.x - at.x), 0) if p["axis"] == "x" else Vector2(0, signf(c.y - at.y))
	if areas.has(p.get("a", "")):
		var c2: Vector2 = areas[p["a"]]["rect"].get_center()
		return -(Vector2(signf(c2.x - at.x), 0) if p["axis"] == "x" else Vector2(0, signf(c2.y - at.y)))
	return Vector2(0, 1)

# ------------------------------------------------------------------ queries

func area_at(p: Vector2) -> String:
	# inner rects first; a point on a shared wall belongs to whichever is listed first
	for id in area_order:
		var r: Rect2 = areas[id]["rect"]
		if r.has_point(p):
			return id
	return ""

func floor_at(p: Vector2, hint: String = "") -> float:
	var id := hint if hint != "" and areas.has(hint) and areas[hint]["rect"].grow(0.3).has_point(p) else area_at(p)
	if id == "":
		return 0.0
	var a: Dictionary = areas[id]
	if a.has("slope"):
		var s: Dictionary = a["slope"]
		var axis_v := p.y if s.get("axis", "z") == "z" else p.x
		var k := clampf(inverse_lerp(float(s["from"]), float(s["to"]), axis_v), 0.0, 1.0)
		return lerpf(float(s["y0"]), float(s["y1"]), k)
	var y: float = a["floor"]
	for pl in a["platforms"]:
		var r: Rect2 = pl["rect"]
		# a short ramp at the edge so the step up is smooth underfoot
		var d := _rect_dist(r, p)
		if d <= 0.0:
			y = maxf(y, pl["y"])
		elif d < 0.3:
			y = maxf(y, lerpf(pl["y"], a["floor"], d / 0.3))
	return y

static func _rect_dist(r: Rect2, p: Vector2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dz := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dz).length()

func neighbours(area_id: String) -> Array:
	var out: Array = []
	for p in portals.values():
		if p["a"] == area_id and areas.has(p["b"]):
			out.append(p["b"])
		elif p["b"] == area_id and areas.has(p["a"]):
			out.append(p["a"])
	return out

func portals_of(area_id: String) -> Array:
	return portals.values().filter(func(p): return p["a"] == area_id or p["b"] == area_id)

## Openings in one edge of an area: [{t (distance along the edge from its start), width, bottom, top, portal?}]
func openings(area_id: String, edge: int) -> Array:
	var r: Rect2 = areas[area_id]["rect"]
	var out: Array = []
	var seg := edge_segment(r, edge)
	var a: Vector2 = seg[0]
	var b: Vector2 = seg[1]
	var dir := (b - a).normalized()
	var fl: float = areas[area_id]["floor"]
	for p in portals.values():
		if p["a"] != area_id and p["b"] != area_id:
			continue
		var at: Vector2 = p["at"]
		if _on_segment(at, a, b):
			# a doorway starts at the floor where it is (the stair's bottom door is far below its top)
			var inward: Vector2 = (r.get_center() - at).normalized() * 0.3
			var bottom := floor_at(at + inward, area_id) - fl
			if p.has("sill"):
				bottom += float(p["sill"])
			out.append({"t": (at - a).dot(dir), "width": p["width"], "bottom": bottom, "top": p["height"] + bottom, "portal": p["id"]})
	for w in windows:
		if w.get("area", "") != area_id and w.get("other", "") != area_id:
			continue
		var at2: Vector2 = w["at"]
		if _on_segment(at2, a, b):
			# a window's sill and head are given as heights above the floor of its own area
			var base_y: float = areas[w["area"]]["floor"] - fl
			out.append({"t": (at2 - a).dot(dir), "width": float(w["width"]), "bottom": base_y + float(w["sill"]), "top": base_y + float(w["head"]), "window": true})
	out.sort_custom(func(x, y): return x["t"] < y["t"])
	return out

static func edge_segment(r: Rect2, edge: int) -> Array:
	# 0: -z edge (west to east), 1: +x edge (north to south), 2: +z edge (east to west), 3: -x edge (south to north)
	match edge:
		0: return [Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y)]
		1: return [Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y)]
		2: return [Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)]
		_: return [Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.position.y)]

static func _on_segment(p: Vector2, a: Vector2, b: Vector2) -> bool:
	var ab := b - a
	var t := (p - a).dot(ab) / ab.length_squared()
	if t < 0.0 or t > 1.0:
		return false
	return (a + ab * t).distance_to(p) < 0.06

# ------------------------------------------------------------------ the walk grid

func _build_grid() -> void:
	var bb := Rect2()
	var first := true
	for id in area_order:
		var r: Rect2 = areas[id]["rect"]
		bb = r if first else bb.merge(r)
		first = false
	bb = bb.grow(0.5)
	origin = bb.position
	gw = int(ceil(bb.size.x / CELL))
	gh = int(ceil(bb.size.y / CELL))
	cells = PackedByteArray()
	cells.resize(gw * gh)
	cells.fill(0)
	for id in area_order:
		_fill(areas[id]["rect"].grow(-RADIUS), 1)
	for o in obstacles:
		_fill(o["rect"].grow(RADIUS), 0)
	portal_ids = portals.keys()
	for i in range(portal_ids.size()):
		var p: Dictionary = portals[portal_ids[i]]
		if p.get("kind", "door") == "window":
			continue
		_fill(portal_rect(p, RADIUS - 0.04), i + 2, true)

func _fill(r: Rect2, v: int, only_blocked := false) -> void:
	var x0 := clampi(int(ceil((r.position.x - origin.x) / CELL - 0.5)), 0, gw)
	var x1 := clampi(int(floor((r.end.x - origin.x) / CELL - 0.5)), -1, gw - 1)
	var z0 := clampi(int(ceil((r.position.y - origin.y) / CELL - 0.5)), 0, gh)
	var z1 := clampi(int(floor((r.end.y - origin.y) / CELL - 0.5)), -1, gh - 1)
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			if only_blocked and cells[z * gw + x] == 1:
				continue
			cells[z * gw + x] = v

func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor((p.x - origin.x) / CELL)), int(floor((p.y - origin.y) / CELL)))

func cell_centre(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * CELL

func _cell_ok(x: int, z: int) -> bool:
	if x < 0 or z < 0 or x >= gw or z >= gh:
		return false
	var v := cells[z * gw + x]
	if v == 0:
		return false
	if v == 1:
		return true
	return open_portals.has(portal_ids[v - 2])

func walkable(p: Vector2) -> bool:
	var c := cell_of(p)
	return _cell_ok(c.x, c.y)

## The portal whose doorway this point stands in ("" if none).
func portal_at(p: Vector2) -> String:
	var c := cell_of(p)
	if c.x < 0 or c.y < 0 or c.x >= gw or c.y >= gh:
		return ""
	var v := cells[c.y * gw + c.x]
	return portal_ids[v - 2] if v >= 2 else ""

## Move from p by step, sliding along anything in the way.
func slide(p: Vector2, step: Vector2) -> Vector2:
	var n := maxi(1, int(ceil(step.length() / (CELL * 0.5))))
	var q := p
	var s := step / n
	for i in range(n):
		if walkable(q + s):
			q += s
		elif walkable(q + Vector2(s.x, 0)):
			q += Vector2(s.x, 0)
		elif walkable(q + Vector2(0, s.y)):
			q += Vector2(0, s.y)
		else:
			break
	return q

## Nearest walkable point to p (searching outward), or p if it already is.
func nearest_walkable(p: Vector2, max_r := 3.0) -> Vector2:
	if walkable(p):
		return p
	var c := cell_of(p)
	var best := p
	var bd := INF
	var rr := int(max_r / CELL)
	for dz in range(-rr, rr + 1):
		for dx in range(-rr, rr + 1):
			if _cell_ok(c.x + dx, c.y + dz):
				var q := cell_centre(Vector2i(c.x + dx, c.y + dz))
				var d := q.distance_squared_to(p)
				if d < bd:
					bd = d
					best = q
	return best

## A* over the grid. Returns a list of Vector2 waypoints (smoothed), empty if unreachable.
func find_path(from: Vector2, to: Vector2) -> Array:
	var a := cell_of(nearest_walkable(from, 1.0))
	var b := cell_of(nearest_walkable(to, 2.0))
	if not _cell_ok(a.x, a.y) or not _cell_ok(b.x, b.y):
		return []
	var start := a.y * gw + a.x
	var goal := b.y * gw + b.x
	var came := {}
	var g := {start: 0.0}
	var open := [[_h(a, b), start]]
	var closed := {}
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var found := false
	var guard := 0
	while not open.is_empty() and guard < 60000:
		guard += 1
		# pop the lowest f (a small binary heap would be faster; the grid is small)
		var bi := 0
		for i in range(1, open.size()):
			if open[i][0] < open[bi][0]:
				bi = i
		var cur: int = open[bi][1]
		open.remove_at(bi)
		if cur == goal:
			found = true
			break
		if closed.has(cur):
			continue
		closed[cur] = true
		var cx := cur % gw
		var cz := cur / gw
		for d in dirs:
			var nx: int = cx + d.x
			var nz: int = cz + d.y
			if not _cell_ok(nx, nz):
				continue
			if d.x != 0 and d.y != 0 and (not _cell_ok(cx + d.x, cz) or not _cell_ok(cx, cz + d.y)):
				continue
			var ni := nz * gw + nx
			if closed.has(ni):
				continue
			var ng: float = g[cur] + (1.4142 if d.x != 0 and d.y != 0 else 1.0)
			if ng < g.get(ni, INF):
				g[ni] = ng
				came[ni] = cur
				open.append([ng + _h(Vector2i(nx, nz), b), ni])
	if not found:
		return []
	var cells_path: Array = []
	var k := goal
	while k != start:
		cells_path.append(Vector2i(k % gw, k / gw))
		k = came[k]
	cells_path.reverse()
	var pts: Array = [from]
	for c in cells_path:
		pts.append(cell_centre(c))
	pts[pts.size() - 1] = to if walkable(to) else pts[pts.size() - 1]
	return _smooth(pts)

static func _h(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a - b).length()

func _clear_line(a: Vector2, b: Vector2) -> bool:
	var n := int(ceil(a.distance_to(b) / (CELL * 0.5)))
	for i in range(n + 1):
		if not walkable(a.lerp(b, float(i) / maxf(1, n))):
			return false
	return true

func _smooth(pts: Array) -> Array:
	if pts.size() <= 2:
		return pts
	var out: Array = [pts[0]]
	var i := 0
	while i < pts.size() - 1:
		var j := pts.size() - 1
		while j > i + 1 and not _clear_line(pts[i], pts[j]):
			j -= 1
		out.append(pts[j])
		i = j
	return out

## Can you walk from a to b with these portals open?
func reachable(from: Vector2, to: Vector2) -> bool:
	return not find_path(from, to).is_empty()

# ------------------------------------------------------------------ things

## A thing's position in the world (things inside rooms are given in the room's own frame).
func thing_pos(t: Dictionary) -> Vector3:
	var at: Array = t.get("at", [0, 1, 0])
	var p := Vector3(float(at[0]), float(at[1]), float(at[2]))
	var aid: String = t.get("area", "hall")
	if t.get("local", false) and areas.has(aid):
		return areas[aid]["xf"] * p
	return p

## Where to stand to use something at pos: in front of it, on the walk grid.
func stand_point(pos: Vector3, area_id: String, facing := Vector2.ZERO) -> Vector2:
	var p2 := Vector2(pos.x, pos.z)
	if facing == Vector2.ZERO and areas.has(area_id):
		facing = (areas[area_id]["rect"].get_center() - p2).normalized()
		if facing == Vector2.ZERO:
			facing = Vector2(0, 1)
	for dist in [1.1, 0.8, 1.4, 0.6, 1.8]:
		var q: Vector2 = p2 + facing * dist
		if walkable(q):
			return q
	return nearest_walkable(p2 + facing * 0.9, 2.5)
