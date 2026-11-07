extends ArenaGame
## RUN FOR YOUR LIFE (FFA). A corridor. Something comes down it behind you (the hooks),
## faster all the time. Blades sweep across it; a door can be slammed in the face of
## whoever's behind you; a vent is a shortcut if you'll crawl; a lever at the start sends
## the blades mad for everyone ahead of you. Teeth on the floor. First to the end
## wins. Finishing isn't guaranteed.

const DURATION := 40.0
var blades: Array = []      # [{x, speed, phase, mad}]
var doors: Array = []       # [{x, shut, by}]
var pickups: Array = []
var hooks_x := -7.8
var finished: Array[int] = []
var crawling: Dictionary = {}   # seat -> seconds left in the vent
var lever_used := false


func id() -> String:
	return "run_for_your_life"


func title() -> String:
	return "RUN FOR YOUR LIFE"


func instructions() -> Array:
	return ["Run to the far end. Something is coming down the corridor behind you.", "Blades sweep across. Time them.",
		"SLAM a door on whoever's behind you. CRAWL the vent if you dare.", "First to the end wins."]


func setup() -> void:
	bounds = Rect2(-7.5, -1.6, 15, 3.2)
	var pts := []
	for k in seats.size():
		pts.append(Vector2(-6.6, -1.2 + k * 0.8))
	place_start(pts)
	for x in [-3.0, 1.0, 4.6]:
		blades.append({"x": x, "speed": rng.randf_range(1.6, 2.4) + level * 0.3, "phase": rng.randf() * TAU, "mad": 0.0})
	for x in [-1.2, 3.0]:
		doors.append({"x": x, "shut": 0.0, "by": -1})
	for i in 8:
		pickups.append(Vector2(rng.randf_range(-5.5, 6.0), rng.randf_range(-1.3, 1.3)))


func blade_z(b: Dictionary) -> float:
	return sin(t * b.speed * (2.2 if b.mad > 0.0 else 1.0) + b.phase) * 1.5


func can_move(s: int) -> bool:
	return not finished.has(s) and not crawling.has(s)


func tick(dt: float) -> void:
	t += dt
	hooks_x += (0.45 + t * 0.012 + level * 0.1) * dt
	var before := {}
	for s in living():
		before[s] = pos[s]
	walk_all(dt)
	for b in blades:
		b.mad = maxf(0.0, b.mad - dt)
	for d in doors:
		d.shut = maxf(0.0, d.shut - dt)
	for s in living():
		if finished.has(s):
			continue
		if crawling.has(s):
			crawling[s] -= dt
			if crawling[s] <= 0.0:
				crawling.erase(s)
				pos[s] = Vector2(2.2, -1.2)
			continue
		var p: Vector2 = pos[s]
		# shut doors are walls (except to whoever shut them, who's already through)
		for d in doors:
			if d.shut > 0.0 and d.by != s and (before[s] as Vector2).x < d.x and p.x >= d.x - 0.1:
				p.x = d.x - 0.15
		pos[s] = p
		for b in blades:
			if absf(p.x - b.x) < 0.35 and absf(p.y - blade_z(b)) < 0.45 and stun.get(s, 0.0) <= 0.0:
				stun[s] = 0.9
				pos[s] = clamp_in(p + Vector2(-0.9, 0))
				var part: String = ["arm_l", "arm_r", "leg_l", "leg_r", "tail", "ears"][rng.randi_range(0, 5)]
				core.injure(s, part, "lost" if (level >= 2 or tip(s)) else "broken", "the blade")
				core.emit({"e": "mg", "k": "blade", "seat": s})
		for i in range(pickups.size() - 1, -1, -1):
			if p.distance_to(pickups[i]) < 0.5:
				pickups.remove_at(i)
				teeth[s] += 1
		if p.x >= bounds.end.x - 0.3:
			finished.append(s)
			core.emit({"e": "mg", "k": "finish", "seat": s, "place": finished.size()})
			if finished.size() == 1:
				core.say("run_first", {"name": core.p(s).name})
		elif p.x <= hooks_x:
			core.say("run_caught", {"name": core.p(s).name})
			core.kill(s, "jaws", [["leg_r", "lost"]])
			if core.p(s).alive:
				pos[s] = Vector2(hooks_x + 1.5, 0)
	var running := living().filter(func(s): return not finished.has(s))
	if running.is_empty() or t >= DURATION:
		for s in running:
			core.kill(s, "jaws", [["leg_l", "lost"]])
		if finished.is_empty():
			finish([], true)
		else:
			teeth[finished[0]] += 3
			finish([finished[0]], false)


func arena_action(seat: int, a: Dictionary) -> void:
	var p: Vector2 = pos[seat]
	match str(a.get("do", "")):
		"slam":
			for d in doors:
				if p.x > d.x and p.x - d.x < 1.0 and d.shut <= 0.0:
					d.shut = 2.5
					d.by = seat
					core.emit({"e": "mg", "k": "slam", "seat": seat})
		"crawl":
			if absf(p.x - (-1.8)) < 0.8 and p.y < -0.8 and not crawling.has(seat):
				crawling[seat] = 2.5 if Body.legs(body(seat)) > 0.0 else 3.5


func actions_for(seat: int) -> Array:
	var out := [{"do": "push", "name": "PUSH"}]
	var p: Vector2 = pos[seat]
	for d in doors:
		if p.x > d.x and p.x - d.x < 1.0 and d.shut <= 0.0:
			out.append({"do": "slam", "name": "SLAM THE DOOR"})
	if absf(p.x - (-1.8)) < 0.8 and p.y < -0.8:
		out.append({"do": "crawl", "name": "CRAWL INTO THE VENT"})
	return out


func cheat_options(seat: int) -> Array:
	if not lever_used and (pos[seat] as Vector2).x < -5.0:
		return [{"id": "lever", "name": "pull the lever (blades go mad)"}]
	return []


func apply_cheat(_seat: int, cid: String) -> void:
	if cid == "lever":
		lever_used = true
		for b in blades:
			b.mad = 6.0


func view_for(viewers: Array) -> Dictionary:
	var v := base_view()
	objects.clear()
	objects.append({"kind": "corridor", "pos": Vector2(0, 0), "size": [15, 3.2]})
	objects.append({"kind": "hooks", "pos": Vector2(hooks_x, 0), "size": [0.4, 3.2]})
	objects.append({"kind": "finish", "pos": Vector2(bounds.end.x - 0.15, 0), "size": [0.3, 3.2]})
	objects.append({"kind": "vent", "pos": Vector2(-1.8, -1.4)})
	for b in blades:
		objects.append({"kind": "blade", "pos": Vector2(b.x, blade_z(b)), "mad": b.mad > 0.0})
	for d in doors:
		objects.append({"kind": "door", "pos": Vector2(d.x, 0), "shut": d.shut > 0.0})
	for p in pickups:
		objects.append({"kind": "rat", "pos": p})
	v.merge(arena_view())
	v.merge({"finished": finished.duplicate(), "time_left": maxf(0.0, DURATION - t)})
	return view_with_actions(v, viewers)


func ai(seat: int, brain: AiBrain, _view: Dictionary, _dt: float) -> void:
	var p: Vector2 = pos[seat]
	var target := Vector2(bounds.end.x, p.y)
	# wait for a blade that's about to cross
	for b in blades:
		if b.x - p.x > 0.0 and b.x - p.x < 0.9 and absf(p.y - blade_z(b)) < 0.9:
			target = Vector2(p.x, p.y)
	steer(seat, target)
	# slam a door in someone's face
	if brain.coop < 0.45:
		for d in doors:
			if p.x > d.x and p.x - d.x < 0.8:
				for o in living():
					if o != seat and (pos[o] as Vector2).x < d.x and d.x - (pos[o] as Vector2).x < 2.0:
						arena_action(seat, {"do": "slam"})
