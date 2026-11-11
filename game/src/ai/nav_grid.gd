class_name NavGrid
extends RefCounted
## Navigation for the AI. A grid of points (CELL metres) over every room's free floor, linked
## through doorways, solved with the engine's AStar3D. Why not a navmesh: the level is built at
## runtime on a phone, and this is cheaper to build, deterministic to test, and lets doors gate
## routes directly (a door's points are disabled while it is secured against her).
##   path(a, b)               the route, honouring doors
##   path(a, b, true)         ignoring locks: where she'd go if the doors gave (she pounds them)
##   seam(a, b)               join two distant points (the Backrooms' loops and impossible doors)

const CELL := 0.5

var astar := AStar3D.new()
var _next := 0
var room_pts := {}            # room -> PackedInt64Array
var point_room := {}          # id -> room
var door_pts := {}            # Door -> Array[int]
var door_of := {}             # id -> Door
var seams := {}               # id -> id (teleport pairs)
var _blocked: Array = []      # [Rect2]

func add_block(r: Rect2) -> void:
	_blocked.append(r)

func _free(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	for r in _blocked:
		if (r as Rect2).has_point(p):
			return false
	return true

func _add(pos: Vector3, room: String) -> int:
	var id := _next
	_next += 1
	astar.add_point(id, pos)
	point_room[id] = room
	if not room_pts.has(room):
		room_pts[room] = PackedInt64Array()
	room_pts[room].append(id)
	return id

## a room's floor: rect (x0, z0, size), floor height y
func add_room(room: String, rect: Rect2, y: float) -> void:
	var inset := 0.32
	var nx := int(floor((rect.size.x - inset * 2.0) / CELL)) + 1
	var nz := int(floor((rect.size.y - inset * 2.0) / CELL)) + 1
	var ox := rect.position.x + (rect.size.x - (nx - 1) * CELL) * 0.5
	var oz := rect.position.y + (rect.size.y - (nz - 1) * CELL) * 0.5
	var grid := {}
	for i in nx:
		for j in nz:
			var x := ox + i * CELL
			var z := oz + j * CELL
			if _free(x, z):
				grid[Vector2i(i, j)] = _add(Vector3(x, y + 0.05, z), room)
	for k in grid:
		for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
			var o: Vector2i = k + d
			if grid.has(o):
				# diagonals only where both orthogonal cells are free (no corner cutting)
				if d.x != 0 and d.y != 0 and not (grid.has(k + Vector2i(d.x, 0)) and grid.has(k + Vector2i(0, d.y))):
					continue
				astar.connect_points(grid[k], grid[o])

## a doorway between two rooms: centre on the boundary, `normal` across it. Door may be null (an arch).
func add_opening(center: Vector3, normal: Vector3, room_a: String, room_b: String, door: Object) -> void:
	var mid := _add(center + Vector3(0, 0.05, 0), "door")
	var a := _add(center - normal * 0.45 + Vector3(0, 0.05, 0), room_a)
	var b := _add(center + normal * 0.45 + Vector3(0, 0.05, 0), room_b)
	astar.connect_points(a, mid)
	astar.connect_points(mid, b)
	_link_to_room(a, room_a)
	_link_to_room(b, room_b)
	if door:
		door_pts[door] = [mid]
		door_of[mid] = door

func _link_to_room(id: int, room: String) -> void:
	var p := astar.get_point_position(id)
	var pts: PackedInt64Array = room_pts.get(room, PackedInt64Array())
	var best := []
	for q in pts:
		if q == id:
			continue
		var d := astar.get_point_position(q).distance_to(p)
		if d < CELL * 1.6:
			best.append(q)
	if best.is_empty():
		# nearest at any distance
		var bd := INF; var bq := -1
		for q in pts:
			if q == id: continue
			var d := astar.get_point_position(q).distance_to(p)
			if d < bd: bd = d; bq = q
		if bq >= 0: best.append(bq)
	for q in best:
		astar.connect_points(id, q)

## two points (anywhere) that connect: walking into one comes out of the other
func seam(a: Vector3, b: Vector3) -> void:
	var ia := astar.get_closest_point(a)
	var ib := astar.get_closest_point(b)
	if ia >= 0 and ib >= 0:
		astar.connect_points(ia, ib)
		seams[ia] = ib
		seams[ib] = ia

func set_door_passable(door: Object, passable: bool) -> void:
	for id in door_pts.get(door, []):
		astar.set_point_disabled(id, not passable)

func path(from: Vector3, to: Vector3, ignore_locks := false) -> PackedVector3Array:
	var disabled := []
	if ignore_locks:
		for id in door_of:
			if astar.is_point_disabled(id):
				disabled.append(id)
				astar.set_point_disabled(id, false)
	var a := astar.get_closest_point(from)
	var b := astar.get_closest_point(to)
	var out := PackedVector3Array()
	if a >= 0 and b >= 0:
		out = astar.get_point_path(a, b)
	for id in disabled:
		astar.set_point_disabled(id, true)
	return out

func id_path(from: Vector3, to: Vector3) -> PackedInt64Array:
	var a := astar.get_closest_point(from)
	var b := astar.get_closest_point(to)
	if a < 0 or b < 0:
		return PackedInt64Array()
	return astar.get_id_path(a, b)

## doors along a path (in order), for the AI to deal with
func doors_on(path_ids: PackedInt64Array) -> Array:
	var out := []
	for id in path_ids:
		if door_of.has(id):
			out.append(door_of[id])
	return out

func random_point(room: String, rng: RandomNumberGenerator) -> Vector3:
	var pts: PackedInt64Array = room_pts.get(room, PackedInt64Array())
	if pts.is_empty():
		return Vector3.ZERO
	return astar.get_point_position(pts[rng.randi() % pts.size()])

func room_at(pos: Vector3) -> String:
	var id := astar.get_closest_point(pos, true)
	return String(point_room.get(id, ""))

func reachable(from: Vector3, to: Vector3) -> bool:
	return path(from, to).size() > 0
