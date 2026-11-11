class_name Nav
extends RefCounted
## Where things that walk can go: a graph of points (every open cell of the maze, and a handful of
## places in each room of the flat), joined where you can get from one to the other. Some joins go
## through a door (a monster has to open it, or break it). A* over it. Deterministic and cheap,
## and nothing to bake on the phone.

var pts: PackedVector3Array = PackedVector3Array()
var links: Array = []            ## per point: [[other, door or null], ...]
var tags := {}                   ## name -> point index

func add(p: Vector3, tag := "") -> int:
	pts.append(p); links.append([])
	if tag != "": tags[tag] = pts.size() - 1
	return pts.size() - 1

func join(a: int, b: int, door: Object = null) -> void:
	links[a].append([b, door]); links[b].append([a, door])

func nearest(p: Vector3, max_d := 3.0) -> int:
	var best := -1; var bd := max_d * max_d
	for i in pts.size():
		var d := Vector2(pts[i].x - p.x, pts[i].z - p.z).length_squared() + absf(pts[i].y - p.y) * 4.0
		if d < bd: bd = d; best = i
	return best

## A path of point indices from a to b (empty if there isn't one). `can_pass(door)` decides doors.
func path(a: int, b: int, can_pass: Callable = Callable()) -> PackedInt32Array:
	if a < 0 or b < 0: return PackedInt32Array()
	if a == b: return PackedInt32Array([a])
	var open := {a: true}
	var came := {}
	var g := {a: 0.0}
	var f := {a: pts[a].distance_to(pts[b])}
	var guard := 0
	while open.size() > 0 and guard < 4000:
		guard += 1
		var cur := -1; var cf := INF
		for k in open:
			if f[k] < cf: cf = f[k]; cur = k
		if cur == b:
			var out := PackedInt32Array([cur])
			while came.has(cur):
				cur = came[cur]; out.insert(0, cur)
			return out
		open.erase(cur)
		for l in links[cur]:
			var n: int = l[0]
			var door = l[1]
			var cost := pts[cur].distance_to(pts[n])
			if door != null and can_pass.is_valid():
				var c: float = can_pass.call(door)
				if c < 0.0: continue
				cost += c
			var ng: float = g[cur] + cost
			if not g.has(n) or ng < g[n]:
				came[n] = cur; g[n] = ng; f[n] = ng + pts[n].distance_to(pts[b]); open[n] = true
	return PackedInt32Array()

## The door (if any) on the link between two points.
func door_between(a: int, b: int):
	for l in links[a]:
		if l[0] == b: return l[1]
	return null
