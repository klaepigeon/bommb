class_name Maze
## The maze's plan (pure data; Maze47 builds it). A grid of cells, `w` by `h`; walls between
## them. Generated from a seed so it's the same every time:
##   - a perfect maze (recursive backtracker) from `start` to `exit`;
##   - three safe rooms: dead ends just off the way through, about a quarter, a half and five
##     sixths of the way along it (one door each, kept that way);
##   - loops knocked through elsewhere, so a chase has somewhere to go (never into a safe room);
##   - zones: each cell wears one of the flat's rooms (nearest of a few seeds);
##   - two cracked walls: walls that, broken (Breach), would cut a long way off the route.
## Cells are Vector2i(x, y); y runs with world z.

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const THEMES := ["hall", "living", "kitchen", "bath", "child", "bedroom", "storage"]

var w := 8
var h := 8
var start := Vector2i(0, 0)
var exit := Vector2i(7, 7)
var open := {}              # "x,y|x,y" (sorted) -> true: no wall between the two cells
var theme := {}             # cell -> theme
var safe: Array = []        # cells
var cracked: Array = []     # [cell, cell] pairs: a cracked wall between them
var path: Array = []        # start .. exit
var rng := RandomNumberGenerator.new()

static func key(a: Vector2i, b: Vector2i) -> String:
	if a.x > b.x or (a.x == b.x and a.y > b.y): var t := a; a = b; b = t
	return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]

func is_open(a: Vector2i, b: Vector2i) -> bool:
	return open.has(key(a, b))

func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h

func neighbours(c: Vector2i) -> Array:
	var out := []
	for d in DIRS:
		if inside(c + d) and is_open(c, c + d): out.append(c + d)
	return out

func exits_of(c: Vector2i) -> int:
	return neighbours(c).size()

## Try seeds from `seed` on and keep the first good one: three safe rooms, a long enough way
## through (but not the whole maze), two cracked walls. The same seed always gives the same maze.
func generate_good(seed: int) -> int:
	for s in range(seed, seed + 200):
		generate(s)
		if safe.size() == 3 and path.size() >= 24 and path.size() <= 40 and cracked.size() == 2: return s
	generate(seed)
	return seed

func generate(seed: int) -> void:
	rng.seed = seed
	open = {}
	# the backtracker
	var seen := {start: true}
	var stack := [start]
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var nexts := []
		for d in DIRS:
			var n: Vector2i = c + d
			if inside(n) and not seen.has(n): nexts.append(n)
		if nexts.is_empty():
			stack.pop_back(); continue
		var n: Vector2i = nexts[rng.randi() % nexts.size()]
		open[key(c, n)] = true
		seen[n] = true
		stack.append(n)
	# the way out: the cell on the far (east) side that's furthest to walk to
	var far := -1
	for y in h:
		var c := Vector2i(w - 1, y)
		var r := route(start, c)
		if r.size() > far: far = r.size(); exit = c
	path = route(start, exit)
	_pick_safe()
	_loops()
	path = route(start, exit)
	_zones()
	_cracks()

## Breadth-first: the cells from a to b.
func route(a: Vector2i, b: Vector2i, blocked := {}) -> Array:
	var prev := {a: a}
	var q := [a]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == b: break
		for n in neighbours(c):
			if prev.has(n) or blocked.has(n): continue
			prev[n] = c; q.append(n)
	if not prev.has(b): return []
	var out := [b]
	while out.back() != a: out.append(prev[out.back()])
	out.reverse()
	return out

func _pick_safe() -> void:
	safe = []
	var on_path := {}
	for c in path: on_path[c] = true
	for frac in [0.25, 0.5, 0.82]:
		var anchor: Vector2i = path[int(frac * (path.size() - 1))]
		var found = null
		for limit in [3, 6, 99]:          # as close to the way through as can be found
			found = _dead_end_near(anchor, on_path, limit)
			if found != null: break
		if found != null: safe.append(found)

func _dead_end_near(anchor: Vector2i, on_path: Dictionary, limit: int):
	# the nearest dead end off the way through, from there, within `limit` steps
	var prev := {anchor: true}
	var depth := {anchor: 0}
	var q := [anchor]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if int(depth[c]) >= limit: continue
		for n in neighbours(c):
			if prev.has(n): continue
			prev[n] = true; depth[n] = int(depth[c]) + 1
			if not on_path.has(n) and exits_of(n) == 1 and not safe.has(n) and n != start and n != exit:
				return n
			q.append(n)
	return null

## Loops, so a chase has somewhere to go round, but only away from the way through (they'd cut
## it short) and never into a safe room.
func _loops() -> void:
	var on_path := {}
	for c in path: on_path[c] = true
	var tries := 0; var made := 0
	while made < int(w * h * 0.07) and tries < 600:
		tries += 1
		var c := Vector2i(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1))
		var d: Vector2i = DIRS[rng.randi() % 4]
		var n: Vector2i = c + d
		if not inside(n) or is_open(c, n) or safe.has(c) or safe.has(n): continue
		if on_path.has(c) and on_path.has(n): continue
		open[key(c, n)] = true; made += 1

func _zones() -> void:
	theme = {}
	var seeds := []
	var themes := ["living", "kitchen", "bath", "child", "bedroom", "storage"]
	for i in themes.size():
		seeds.append([Vector2i(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1)), themes[i]])
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			var best := ""; var bd := 1e9
			for s in seeds:
				var d := float((c - (s[0] as Vector2i)).length_squared())
				if d < bd: bd = d; best = s[1]
			theme[c] = best
	# the corridors of the way through mostly hall
	for i in path.size():
		if i % 3 != 0: theme[path[i]] = "hall"
	for c in safe: theme[c] = "safe"

## Walls that, opened, would save the most walking along the route.
func _cracks() -> void:
	cracked = []
	var dist := {}
	for i in path.size(): dist[path[i]] = i
	var best := []
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var n: Vector2i = c + d
				if not inside(n) or is_open(c, n) or safe.has(c) or safe.has(n): continue
				if dist.has(c) and dist.has(n):
					best.append([absi(int(dist[c]) - int(dist[n])), c, n])
	best.sort_custom(func(a, b): return a[0] > b[0])
	# a real shortcut, not the whole maze: saves between 5 and 12 cells, nowhere near the start
	best = best.filter(func(b): return b[0] >= 5 and b[0] <= 12 and b[1] != start and b[2] != start)
	for b in best.slice(0, 2): cracked.append([b[1], b[2]])
