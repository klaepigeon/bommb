extends ArenaGame
## HUMAN SHIELD (2v2). Each team: a CARRIER with the parcel, and a SHIELD. Darts come
## across the room from the walls, a lane at a time (a red line warns you a moment
## before). A dart hits the first body in its lane: stand in front of your carrier and it's
## you it hits. RAISE a barrier across a lane for a few seconds. Deliver the parcel to the
## far end. If a carrier falls, their shield can pick the parcel up.

const DURATION := 45.0
var role: Dictionary = {}     # seat -> "carrier" | "shield"
var parcel: Dictionary = {}   # team -> {pos, holder}
var lanes: Array = []         # warnings: [{x, from, t}]
var barriers: Array = []      # [{x, t}]
var barrier_cd: Dictionary = {}
var _fire := 1.5


func id() -> String:
	return "human_shield"


func title() -> String:
	return "HUMAN SHIELD"


func instructions() -> Array:
	return ["Carriers: get the parcel to the far end.", "Shields: stand between your carrier and the darts. RAISE a barrier.",
		"A dart hits the first body in its lane.", "First team to deliver wins."]


func setup() -> void:
	bounds = Rect2(-6.5, -3.2, 13, 6.4)
	make_teams([2, 2])
	var pts := []
	for k in seats.size():
		pts.append(Vector2(-6.0, -2 + k))
	place_start(pts)
	for i in teams.size():
		var tm: Array = teams[i]
		role[tm[0]] = "carrier"
		if tm.size() > 1:
			role[tm[1]] = "shield"
		pos[tm[0]] = Vector2(-6.0, -1.5 + i * 3.0)
		if tm.size() > 1:
			pos[tm[1]] = Vector2(-5.4, -1.5 + i * 3.0)
		parcel[i] = {"holder": tm[0]}
		carry[tm[0]] = "parcel"


func tick(dt: float) -> void:
	t += dt
	walk_all(dt)
	for b in barriers:
		b.t -= dt
	barriers = barriers.filter(func(b): return b.t > 0.0)
	for s in barrier_cd.keys():
		barrier_cd[s] = maxf(0.0, barrier_cd[s] - dt)
	_fire -= dt
	if _fire <= 0.0:
		_fire = maxf(0.6, 1.3 - level * 0.2)
		lanes.append({"x": rng.randf_range(-5.0, 5.5), "from": [-1, 1][rng.randi_range(0, 1)], "t": 0.8})
	for ln in lanes:
		ln.t -= dt
		if ln.t <= 0.0:
			_dart(ln)
	lanes = lanes.filter(func(ln): return ln.t > 0.0)
	for i in teams.size():
		var h: int = parcel[i].holder
		if h >= 0 and not alive(h):
			# pick it up if you're their partner
			parcel[i].holder = -1
			for o in teams[i]:
				if alive(o):
					parcel[i].holder = o
					carry[o] = "parcel"
					role[o] = "carrier"
		h = parcel[i].holder
		if h >= 0 and (pos[h] as Vector2).x >= bounds.end.x - 0.4:
			for s in teams[i]:
				rats[s] += 3
			finish(teams[i].filter(func(s): return alive(s)), false)
			return
	if t >= DURATION or living().is_empty():
		finish([], true)


func _dart(ln: Dictionary) -> void:
	for b in barriers:
		if absf(b.x - ln.x) < 0.6:
			core.emit({"e": "mg", "k": "blocked", "x": ln.x})
			return
	var hit := -1
	var best := INF
	for s in living():
		var p: Vector2 = pos[s]
		if absf(p.x - ln.x) < 0.35:
			var d := absf(p.y - (bounds.position.y if ln.from < 0 else bounds.end.y))
			if d < best:
				best = d
				hit = s
	if hit < 0:
		return
	core.emit({"e": "mg", "k": "dart", "seat": hit, "x": ln.x})
	var part := Body.random_severable(body(hit), rng)
	var lethal := level >= 2 and tip(hit)
	if lethal:
		core.kill(hit, "pop", [[part, "lost"]])
	elif part != "":
		core.injure(hit, part, "broken" if role.get(hit, "") == "carrier" or tip(hit) else "bruised", "a dart")
	stun[hit] = 0.5


func arena_action(seat: int, a: Dictionary) -> void:
	if str(a.get("do", "")) == "barrier" and barrier_cd.get(seat, 0.0) <= 0.0:
		barrier_cd[seat] = 5.0
		barriers.append({"x": (pos[seat] as Vector2).x, "t": 2.5})
		core.emit({"e": "mg", "k": "barrier", "seat": seat})


func actions_for(seat: int) -> Array:
	var out := [{"do": "push", "name": "PUSH"}]
	if role.get(seat, "") == "shield":
		out.push_front({"do": "barrier", "name": "RAISE A BARRIER" if barrier_cd.get(seat, 0.0) <= 0.0 else "(barrier recharging)"})
	return out


func view_for(viewers: Array) -> Dictionary:
	var v := base_view()
	objects.clear()
	for ln in lanes:
		objects.append({"kind": "lane", "pos": Vector2(ln.x, 0), "size": [0.3, bounds.size.y], "from": ln.from})
	for b in barriers:
		objects.append({"kind": "barrier", "pos": Vector2(b.x, 0), "size": [0.4, bounds.size.y]})
	objects.append({"kind": "finish", "pos": Vector2(bounds.end.x - 0.2, 0), "size": [0.4, bounds.size.y]})
	v.merge(arena_view())
	v.merge({"role": role.duplicate(), "time_left": maxf(0.0, DURATION - t)})
	return view_with_actions(v, viewers)


func ai(seat: int, brain: AiBrain, _view: Dictionary, _dt: float) -> void:
	var p: Vector2 = pos[seat]
	var tm := team_of(seat)
	if role.get(seat, "") == "carrier":
		var target := Vector2(bounds.end.x, p.y)
		for ln in lanes:
			if absf(ln.x - p.x) < 0.6 and ln.t < 0.6:
				target = Vector2(p.x - 0.5, p.y)
		steer(seat, target)
		return
	var c: int = parcel[tm].holder if tm >= 0 else -1
	if c < 0 or not alive(c):
		move[seat] = Vector2.ZERO
		return
	# stand beside the carrier, on the side the next dart comes from
	var side := -1.0
	for ln in lanes:
		if absf(ln.x - (pos[c] as Vector2).x) < 1.0:
			side = float(ln.from)
			if brain.coop >= 0.3 and barrier_cd.get(seat, 0.0) <= 0.0 and ln.t < 0.5:
				arena_action(seat, {"do": "barrier"})
	steer(seat, (pos[c] as Vector2) + Vector2(0.15, 0.7 * side))
