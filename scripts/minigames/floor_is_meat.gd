extends ArenaGame
## FLOOR IS MEAT (FFA). A floor of steel plates over a pit of meat. One by one the plates
## go: each one flashes red, shakes, then drops (readable telegraphs; later, whole rows).
## You don't walk, you HOP from plate to plate (swipe the way you want to go; your legs
## decide how fast you can hop again). Pick up a PLANK and LAY it over a hole to make a
## bridge. SHOVE whoever's next to you off their plate. Fall in and you're out (and worse,
## later in the match). Last on their feet, or everyone still up when the time's out.

const COLS := 7
const ROWS := 5
const TILE := 1.25
const DURATION := 40.0
const WARN := 1.6

var tiles: Array = []          # [row][col] -> {s: "ok"|"warn"|"gone"|"bridge", t}
var cell: Dictionary = {}      # seat -> Vector2i
var hop_cd: Dictionary = {}
var planks: Array = []         # [Vector2i] planks lying on plates
var holding: Dictionary = {}   # seat -> true (carrying a plank)
var out_at: Dictionary = {}    # seat -> time they fell
var _drop_t := 2.0
var _wave := 0


func id() -> String:
	return "floor_is_meat"


func title() -> String:
	return "FLOOR IS MEAT"


func instructions() -> Array:
	return ["SWIPE to hop to the next plate.", "Red plates are about to drop into the meat. Get off them.",
		"Pick up a PLANK (hop onto it) and LAY it across a hole.", "SHOVE whoever's next to you.", "Last on their feet wins."]


func controls(_seat: int) -> Array:
	return [{"kind": "swipe", "do": "hop", "label": "SWIPE TO HOP"}, {"kind": "tap", "do": "lay", "label": "LAY PLANK"}, {"kind": "tap", "do": "shove", "label": "SHOVE"}]


func setup() -> void:
	for r in ROWS:
		var row := []
		for c in COLS:
			row.append({"s": "ok", "t": 0.0})
		tiles.append(row)
	var starts := [Vector2i(1, 1), Vector2i(5, 3), Vector2i(5, 1), Vector2i(1, 3)]
	for k in seats.size():
		cell[seats[k]] = starts[k % starts.size()]
		hop_cd[seats[k]] = 0.0
	bounds = Rect2(-COLS * TILE / 2.0, -ROWS * TILE / 2.0, COLS * TILE, ROWS * TILE)
	for s in seats:
		pos[s] = centre(cell[s])
		move[s] = Vector2.ZERO
		facing[s] = Vector2.RIGHT
		carry[s] = ""
	for i in 3:
		planks.append(Vector2i(rng.randi_range(0, COLS - 1), rng.randi_range(0, ROWS - 1)))


func centre(c: Vector2i) -> Vector2:
	return Vector2((c.x - (COLS - 1) / 2.0) * TILE, (c.y - (ROWS - 1) / 2.0) * TILE)


func tile(c: Vector2i) -> Dictionary:
	if c.x < 0 or c.y < 0 or c.x >= COLS or c.y >= ROWS:
		return {}
	return tiles[c.y][c.x]


func standable(c: Vector2i) -> bool:
	var t := tile(c)
	return not t.is_empty() and t.s != "gone"


func in_game(s: int) -> bool:
	return alive(s) and not out_at.has(s)


func tick(dt: float) -> void:
	t += dt
	tick_chill(dt)
	for s in seats:
		hop_cd[s] = maxf(0.0, float(hop_cd.get(s, 0.0)) - dt)
		stun[s] = maxf(0.0, float(stun.get(s, 0.0)) - dt)
	# the plates
	_drop_t -= dt
	if _drop_t <= 0.0:
		_wave += 1
		_drop_t = maxf(0.9, 2.4 - level * 0.3 - t * 0.03)
		var n := 1 + int(t / 12.0) + level / 2
		if _wave % 5 == 0:
			# a whole row (or column) at once, with a longer warning
			var r := rng.randi_range(0, ROWS - 1)
			for c in COLS:
				_warn(Vector2i(c, r), WARN + 0.6)
		else:
			for i in n:
				_warn(_pick_tile(), WARN)
	for r in ROWS:
		for c in COLS:
			var tl: Dictionary = tiles[r][c]
			if tl.s == "warn":
				tl.t -= dt
				if tl.t <= 0.0:
					tl.s = "gone"
					core.emit({"e": "mg", "k": "drop", "c": c, "r": r})
					planks = planks.filter(func(p): return p != Vector2i(c, r))
	for s in seats:
		if in_game(s) and not standable(cell[s]):
			_fall(s)
	if t >= DURATION or _standing().size() <= 1:
		_end()


func _pick_tile() -> Vector2i:
	# mostly where people are
	var cands := []
	for s in _standing():
		cands.append(cell[s])
	for i in 3:
		cands.append(Vector2i(rng.randi_range(0, COLS - 1), rng.randi_range(0, ROWS - 1)))
	return cands[rng.randi_range(0, cands.size() - 1)]


func _warn(c: Vector2i, w: float) -> void:
	var tl := tile(c)
	if tl.is_empty() or tl.s != "ok":
		return
	tl.s = "warn"
	tl.t = w


func _standing() -> Array:
	return seats.filter(func(s): return in_game(s))


func _fall(s: int) -> void:
	out_at[s] = t
	holding.erase(s)
	core.emit({"e": "mg", "k": "fall", "seat": s})
	notes.append("%s went into the meat." % core.p(s).name)
	if (level >= 2 or tip(s)) and core.kill(s, "drown", [["leg_l", "broken"], ["leg_r", "broken"]]):
		return
	core.injure(s, ["leg_l", "leg_r"][rng.randi_range(0, 1)], "broken" if level >= 1 else "bruised", "the meat")


func arena_action(seat: int, a: Dictionary) -> void:
	if not in_game(seat) or stun.get(seat, 0.0) > 0.0:
		return
	match str(a.get("do", "")):
		"hop":
			var d = a.get("dir", [0, 0])
			var v := Vector2(float(d[0]), float(d[1])) if d is Array else (d as Vector2)
			hop(seat, v)
		"lay":
			lay(seat)
		"shove":
			shove(seat)


func _dir(v: Vector2) -> Vector2i:
	if v.length() < 0.2:
		return Vector2i.ZERO
	return Vector2i(signi(roundi(v.x)), 0) if absf(v.x) >= absf(v.y) else Vector2i(0, signi(roundi(v.y)))


func hop(seat: int, v: Vector2) -> void:
	if hop_cd[seat] > 0.0:
		return
	var d := _dir(v)
	if d == Vector2i.ZERO:
		return
	var to: Vector2i = cell[seat] + d
	if tile(to).is_empty():
		return
	for o in _standing():
		if o != seat and cell[o] == to:
			return
	facing[seat] = Vector2(d)
	cell[seat] = to
	pos[seat] = centre(to)
	var legs := Body.speed(body(seat), core.p(seat).pk())
	hop_cd[seat] = 0.32 / maxf(0.3, legs) * (1.4 if handicapped.has(seat) else 1.0) * (1.6 if is_chilled(seat) else 1.0)
	core.emit({"e": "mg", "k": "hop", "seat": seat})
	if planks.has(to) and not holding.has(seat):
		planks.erase(to)
		holding[seat] = true
		core.emit({"e": "mg", "k": "plank", "seat": seat})
	if not standable(to):
		_fall(seat)


func lay(seat: int) -> void:
	if not holding.has(seat):
		return
	var to: Vector2i = cell[seat] + Vector2i(roundi(facing[seat].x), roundi(facing[seat].y))
	var tl := tile(to)
	if tl.is_empty() or tl.s != "gone":
		# no hole that way: try any neighbouring hole
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if tile(cell[seat] + d).get("s", "") == "gone":
				to = cell[seat] + d
				tl = tile(to)
				break
	if tl.is_empty() or tl.s != "gone":
		return
	tl.s = "bridge"
	holding.erase(seat)
	core.emit({"e": "mg", "k": "bridge", "seat": seat})


func shove(seat: int) -> void:
	if push_cd.get(seat, 0.0) > 0.0:
		return
	push_cd[seat] = 1.5
	for o in _standing():
		if o == seat:
			continue
		var d: Vector2i = cell[o] - cell[seat]
		if absi(d.x) + absi(d.y) == 1:
			var to: Vector2i = cell[o] + d
			if not tile(to).is_empty():
				cell[o] = to
				pos[o] = centre(to)
				stun[o] = 0.5
				core.emit({"e": "mg", "k": "push", "seat": seat, "target": o})
				core.brains[o].wronged_by(seat, 0.05)
				if not standable(to):
					_fall(o)
			return


func _end() -> void:
	var score := {}
	for s in seats:
		score[s] = DURATION + 1.0 if in_game(s) else float(out_at.get(s, 0.0))
	rank_by(score)
	var up := _standing()
	for s in up:
		teeth[s] += 3
	if up.is_empty() or (up.size() == seats.size() and seats.size() > 1):
		finish([], true)
	else:
		finish(up, false)


func cheat_options(seat: int) -> Array:
	if not in_game(seat):
		return []
	return [{"id": "weld", "name": "weld your plate in place"}]


func apply_cheat(seat: int, _cid: String) -> void:
	var tl := tile(cell[seat])
	if not tl.is_empty():
		tl.s = "bridge"


func actions_for(seat: int) -> Array:
	var out := [{"do": "shove", "name": "SHOVE"}]
	if holding.has(seat):
		out.append({"do": "lay", "name": "LAY PLANK"})
	return out


func view_for(viewers: Array) -> Dictionary:
	var v := base_view()
	objects.clear()
	for r in ROWS:
		for c in COLS:
			var tl: Dictionary = tiles[r][c]
			objects.append({"kind": "floortile", "pos": centre(Vector2i(c, r)), "size": [TILE * 0.94, TILE * 0.94], "state": tl.s, "t": tl.t})
	for pk in planks:
		objects.append({"kind": "plank", "pos": centre(pk)})
	v.merge(arena_view())
	v.merge({"holding": holding.keys(), "out": out_at.keys(), "time_left": maxf(0.0, DURATION - t), "floor": "meat"})
	return view_with_actions(v, viewers)


func ai(seat: int, brain: AiBrain, _view: Dictionary, dt: float) -> void:
	brain.wait += dt
	if not in_game(seat) or brain.wait < 0.25 + (1.0 - brain.nerve) * 0.2:
		return
	brain.wait = 0.0
	var here: Vector2i = cell[seat]
	var danger: bool = tile(here).get("s", "") == "warn"
	if holding.has(seat):
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if tile(here + d).get("s", "") == "gone":
				facing[seat] = Vector2(d)
				lay(seat)
				return
	# shove someone standing next to me, if I'm the type
	if brain.coop < 0.35 and brain.rng.randf() < 0.3:
		shove(seat)
	var best := here
	var best_score := _safety(here) - (5.0 if danger else 0.0)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = here + d
		if not standable(c):
			continue
		var sc := _safety(c) + (0.8 if planks.has(c) and not holding.has(seat) else 0.0) + brain.rng.randf() * 0.3
		if sc > best_score:
			best_score = sc
			best = c
	if best != here:
		hop(seat, Vector2(best - here))


func _safety(c: Vector2i) -> float:
	var tl := tile(c)
	if tl.is_empty() or tl.s == "gone":
		return -10.0
	var sc := 2.0 if tl.s == "ok" else (3.0 if tl.s == "bridge" else -3.0)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if standable(c + d) and tile(c + d).s != "warn":
			sc += 0.5
	# the middle lasts longer than the edges
	sc -= absf(c.x - (COLS - 1) / 2.0) * 0.1 + absf(c.y - (ROWS - 1) / 2.0) * 0.1
	return sc
