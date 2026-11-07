extends ArenaGame
## THE CONTROLLER (1v3). One of you is up in the booth with the panel; the rest are on the
## killing floor. The runners have to turn three valves (stand at one to turn it) to open
## the exit, then get out. The controller has a power budget that refills slowly and four
## machines, each with a cost and a tell: the SAW (cheap, fast, a line across one zone),
## the PRESS (dear, slow to come down, kills), the FLOOD (slows a zone to a wade) and the
## LOCK (winds a valve back and holds it). Choose what, and choose where (zones A-D).
## Runners win if anyone gets out; the controller wins if nobody does.

const DURATION := 42.0
const ZONES := ["A", "B", "C", "D"]
const COST := {"SAW": 3, "PRESS": 5, "FLOOD": 2, "LOCK": 4}
const TELL := {"SAW": 1.0, "PRESS": 1.6, "FLOOD": 0.0, "LOCK": 0.0}
const TURN_TIME := 1.6

var controller := -1
var runners: Array = []
var power := 4.0
var device := "SAW"
var pending: Array = []        # [{dev, zone, t, z}]
var floods: Dictionary = {}    # zone -> seconds
var zone_cd: Dictionary = {}
var valves: Array = []         # [{pos, prog, lock}]
var escaped: Dictionary = {}
var exit_open := false


func id() -> String:
	return "the_controller"


func title() -> String:
	return "THE CONTROLLER"


func instructions() -> Array:
	return ["ONE player runs the machines. The others run.", "RUNNERS: stand at a valve to turn it. Three valves open the exit. Get out.",
		"CONTROLLER: pick a machine, then a zone (A-D). Each costs power and gives a tell.", "SAW: fast, cheap. PRESS: slow, deadly. FLOOD: slows. LOCK: winds a valve back.",
		"Anyone out: the runners win. Nobody: the controller does."]


func controls(seat: int) -> Array:
	if seat == controller:
		return [{"kind": "pick", "do": "device", "label": "MACHINE", "options": ["SAW", "PRESS", "FLOOD", "LOCK"], "selected": device},
			{"kind": "pick", "do": "zone", "label": "WHERE", "options": ZONES}]
	return [{"kind": "stick"}, {"kind": "tap", "do": "push", "label": "SHOVE"}]


func setup() -> void:
	make_teams([1, seats.size() - 1])
	controller = teams[0][0]
	runners = teams[1].duplicate()
	bounds = Rect2(-6, -3.4, 12, 6.8)
	var pts := []
	for k in seats.size():
		pts.append(Vector2(-5.4, -2.0 + k * 1.2))
	place_start(pts)
	pos[controller] = Vector2(0, -4.3)
	valves = [{"pos": Vector2(-2.6, -2.2), "prog": 0.0, "lock": 0.0}, {"pos": Vector2(0.6, 2.3), "prog": 0.0, "lock": 0.0},
		{"pos": Vector2(3.4, -1.4), "prog": 0.0, "lock": 0.0}]
	for z in ZONES:
		zone_cd[z] = 0.0
		floods[z] = 0.0


func zone_of(p: Vector2) -> String:
	return ZONES[clampi(int(floor((p.x + 6.0) / 3.0)), 0, 3)]


func zone_x(z: String) -> float:
	return -4.5 + ZONES.find(z) * 3.0


func can_move(s: int) -> bool:
	return s != controller and not escaped.has(s)


func speed_of(s: int) -> float:
	var sp := super.speed_of(s)
	if float(floods.get(zone_of(pos[s]), 0.0)) > 0.0:
		sp *= 0.4
	return sp


func arena_action(seat: int, a: Dictionary) -> void:
	if seat != controller:
		return
	match str(a.get("do", "")):
		"device":
			if COST.has(str(a.get("pick", ""))):
				device = str(a.pick)
		"zone":
			fire(device, str(a.get("pick", "")))


func fire(dev: String, z: String) -> bool:
	if not ZONES.has(z) or not COST.has(dev) or float(zone_cd[z]) > 0.0:
		return false
	var cost := float(COST[dev])
	if power < cost:
		return false
	power -= cost
	zone_cd[z] = 2.0
	match dev:
		"FLOOD":
			floods[z] = 5.0
			core.emit({"e": "mg", "k": "flood", "zone": z})
		"LOCK":
			for v in valves:
				if zone_of(v.pos) == z:
					v.prog = maxf(0.0, float(v.prog) - TURN_TIME * 0.6)
					v.lock = 6.0
			core.emit({"e": "mg", "k": "lock", "zone": z})
		_:
			pending.append({"dev": dev, "zone": z, "t": float(TELL[dev]), "z": rng.randf_range(-2.8, 2.8)})
			core.emit({"e": "mg", "k": "tell", "dev": dev, "zone": z})
	return true


func tick(dt: float) -> void:
	t += dt
	walk_all(dt)
	power = minf(10.0, power + dt * (1.0 + level * 0.15) * (0.7 if handicapped.has(controller) else 1.0))
	for z in ZONES:
		zone_cd[z] = maxf(0.0, float(zone_cd[z]) - dt)
		floods[z] = maxf(0.0, float(floods[z]) - dt)
	for i in range(pending.size() - 1, -1, -1):
		var pd: Dictionary = pending[i]
		pd.t = float(pd.t) - dt
		if float(pd.t) <= 0.0:
			_strike(pd)
			pending.remove_at(i)
	# valves
	for v in valves:
		v.lock = maxf(0.0, float(v.lock) - dt)
		if float(v.prog) >= TURN_TIME or float(v.lock) > 0.0:
			continue
		for s in runners:
			if alive(s) and not escaped.has(s) and (pos[s] as Vector2).distance_to(v.pos) < 0.65:
				v.prog = minf(TURN_TIME, float(v.prog) + dt * (1.2 if tampered(s) else 1.0))
				if float(v.prog) >= TURN_TIME:
					core.emit({"e": "mg", "k": "valve", "seat": s})
				break
	if not exit_open and valves.all(func(v): return float(v.prog) >= TURN_TIME):
		exit_open = true
		core.emit({"e": "mg", "k": "exit_open"})
		core.say("controller_exit")
	if exit_open:
		for s in runners:
			if alive(s) and not escaped.has(s) and (pos[s] as Vector2).x > 5.6:
				escaped[s] = t
				pos[s] = Vector2(6.4, (pos[s] as Vector2).y)
				core.emit({"e": "mg", "k": "escaped", "seat": s})
	var left := runners.filter(func(s): return alive(s) and not escaped.has(s))
	if t >= DURATION or left.is_empty():
		_end()


func _strike(pd: Dictionary) -> void:
	var x := zone_x(pd.zone)
	core.emit({"e": "mg", "k": str(pd.dev).to_lower(), "zone": pd.zone})
	for s in runners:
		if not alive(s) or escaped.has(s):
			continue
		var p: Vector2 = pos[s]
		if absf(p.x - x) > 1.5:
			continue
		if pd.dev == "SAW" and absf(p.y - float(pd.z)) < 0.7:
			stun[s] = 0.8
			core.injure(s, ["arm_l", "arm_r", "leg_l", "leg_r", "tail"][rng.randi_range(0, 4)], "lost" if (level >= 2 or tip(s)) else "broken", "machinery")
		elif pd.dev == "PRESS" and absf(p.y) < 1.2 and absf(p.x - x) < 1.1:
			if (level >= 1 or tip(s)) and core.kill(s, "crushed", [["leg_l", "broken"], ["leg_r", "broken"]]):
				notes.append("%s was under the press." % core.p(s).name)
			else:
				stun[s] = 1.5
				core.injure(s, ["leg_l", "leg_r"][rng.randi_range(0, 1)], "broken", "machinery")


func _end() -> void:
	if done:
		return
	var out := escaped.keys()
	if not out.is_empty():
		var order := runners.duplicate()
		order.sort_custom(func(a, b): return float(escaped.get(a, 999.0)) < float(escaped.get(b, 999.0)))
		ranking = [out.duplicate()]
		var rest := runners.filter(func(s): return not escaped.has(s))
		if not rest.is_empty():
			ranking.append(rest)
		ranking.append([controller])
		notes.append("%d got out." % out.size())
		finish(runners.filter(func(s): return alive(s)))
	else:
		ranking = [[controller], runners.duplicate()]
		notes.append("Nobody got out.")
		finish([controller])


func cheat_options(seat: int) -> Array:
	if seat == controller:
		return [{"id": "overclock", "name": "short the fuse for more power"}]
	return [{"id": "jam_valve", "name": "jam a valve open"}]


func apply_cheat(seat: int, cid: String) -> void:
	if cid == "overclock":
		power = 10.0
	elif cid == "jam_valve":
		var best := 0
		var bd := INF
		for i in valves.size():
			var d := (pos[seat] as Vector2).distance_to(valves[i].pos)
			if d < bd and float(valves[i].prog) < TURN_TIME:
				bd = d
				best = i
		valves[best].prog = TURN_TIME


func actions_for(seat: int) -> Array:
	return [] if seat == controller else [{"do": "push", "name": "SHOVE"}]


func view_for(viewers: Array) -> Dictionary:
	var v := base_view()
	objects.clear()
	for z in ZONES:
		objects.append({"kind": "zone", "pos": Vector2(zone_x(z), 0), "size": [2.9, 6.6], "label": z, "flood": float(floods[z]) > 0.0})
	for vl in valves:
		objects.append({"kind": "valve", "pos": vl.pos, "prog": float(vl.prog) / TURN_TIME, "locked": float(vl.lock) > 0.0})
	for pd in pending:
		if pd.dev == "SAW":
			objects.append({"kind": "saw_tell", "pos": Vector2(zone_x(pd.zone), float(pd.z)), "size": [2.9, 0.3], "t": pd.t})
		else:
			objects.append({"kind": "press_tell", "pos": Vector2(zone_x(pd.zone), 0), "size": [2.2, 2.4], "t": pd.t})
	objects.append({"kind": "exit", "pos": Vector2(5.9, 0), "size": [0.3, 2.0], "open": exit_open})
	objects.append({"kind": "booth", "pos": Vector2(0, -4.3), "size": [2.0, 0.8]})
	v.merge(arena_view())
	v.merge({"controller": controller, "power": power, "device": device, "costs": COST, "exit_open": exit_open, "escaped": escaped.keys(),
		"zone_cd": zone_cd.duplicate(), "time_left": maxf(0.0, DURATION - t)})
	return view_with_actions(v, viewers)


func ai(seat: int, brain: AiBrain, _view: Dictionary, dt: float) -> void:
	if seat == controller:
		brain.wait += dt
		if brain.wait < 0.7:
			return
		brain.wait = 0.0
		var counts := {}
		var turning := {}
		for s in runners:
			if alive(s) and not escaped.has(s):
				var z := zone_of(pos[s])
				counts[z] = int(counts.get(z, 0)) + 1
		for vl in valves:
			if float(vl.prog) > TURN_TIME * 0.4 and float(vl.prog) < TURN_TIME:
				turning[zone_of(vl.pos)] = true
		var best := ""
		var bc := 0
		for z in counts.keys():
			if int(counts[z]) > bc and float(zone_cd[z]) <= 0.0:
				bc = int(counts[z])
				best = z
		if best == "":
			return
		if turning.has(best) and power >= 4.0:
			fire("LOCK", best)
		elif bc >= 2 and power >= 5.0:
			fire("PRESS", best)
		elif power >= 3.0:
			fire("SAW", best)
		elif power >= 2.0 and brain.rng.randf() < 0.3:
			fire("FLOOD", best)
		return
	if escaped.has(seat):
		move[seat] = Vector2.ZERO
		return
	var p: Vector2 = pos[seat]
	var target := Vector2(5.9, 0)
	if not exit_open:
		var bd := INF
		for vl in valves:
			if float(vl.prog) < TURN_TIME and p.distance_to(vl.pos) < bd:
				bd = p.distance_to(vl.pos)
				target = vl.pos
	# the tells: get out of the zone (or off the saw line)
	for pd in pending:
		var x := zone_x(pd.zone)
		if absf(p.x - x) < 1.6 and brain.rng.randf() < 0.6 + brain.perception * 0.4:
			if pd.dev == "SAW":
				target = Vector2(p.x, float(pd.z) + (1.5 if p.y > float(pd.z) else -1.5))
			else:
				target = Vector2(p.x + (1.8 if p.x < x else -1.8), p.y)
	steer(seat, target)
