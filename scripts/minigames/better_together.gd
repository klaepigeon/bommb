extends ArenaGame
## BETTER TOGETHER (2v2). Partners are chained at the ankle. A course of holes and saws;
## both of you have to reach the far end. Stray too far apart and the chain drags you
## together. YANK pulls your partner to you (to help them out of trouble, or into it). The
## lever stops the saws on your side for a moment. First pair across wins.

const CHAIN := 1.7
const DURATION := 45.0
var holes: Array = []      # [Rect2]
var saws: Array = []       # [{x, speed, phase, stop}]
var across: Dictionary = {}


func id() -> String:
	return "better_together"


func title() -> String:
	return "BETTER TOGETHER"


func instructions() -> Array:
	return ["You're chained to your partner.", "Both of you across the holes and the saws to the far end.",
		"YANK pulls your partner to you.", "First pair across wins."]


func setup() -> void:
	bounds = Rect2(-6.5, -3.0, 13, 6)
	make_teams([2, 2])
	var pts := []
	for k in seats.size():
		pts.append(Vector2(-6.0, -2.4 + k * 1.4))
	place_start(pts)
	# order the start points so partners stand together
	var z := -2.4
	for team in teams:
		for s in team:
			pos[s] = Vector2(-6.0, z)
			z += 0.9
		z += 0.6
	for r in [Rect2(-3.6, -3.0, 1.2, 2.6), Rect2(-3.6, 0.8, 1.2, 2.2), Rect2(0.2, -1.2, 1.4, 2.4), Rect2(3.4, -3.0, 1.0, 2.0), Rect2(3.4, 1.4, 1.0, 1.6)]:
		holes.append(r)
	for x in [-1.4, 2.4, 5.2]:
		saws.append({"x": x, "speed": rng.randf_range(1.2, 1.8), "phase": rng.randf() * TAU, "stop": 0.0})


func partner(s: int) -> int:
	var tm := team_of(s)
	if tm < 0:
		return -1
	for o in teams[tm]:
		if o != s:
			return o
	return -1


func saw_z(sw: Dictionary) -> float:
	return sin(t * sw.speed + sw.phase) * 2.6 if sw.stop <= 0.0 else sin(sw.phase) * 2.6


func tick(dt: float) -> void:
	t += dt
	walk_all(dt)
	for sw in saws:
		sw.stop = maxf(0.0, sw.stop - dt)
	# the chain
	for team in teams:
		var a: int = team[0]
		var b: int = team[1] if team.size() > 1 else team[0]
		if a == b or not alive(a) or not alive(b):
			continue
		var d: Vector2 = pos[b] - pos[a]
		if d.length() > CHAIN:
			var fix := d.normalized() * (d.length() - CHAIN) * 0.5
			pos[a] += fix
			pos[b] -= fix
	for s in living():
		var p: Vector2 = pos[s]
		for h in holes:
			if h.has_point(p) and stun.get(s, 0.0) <= 0.0:
				var o := partner(s)
				var held := o >= 0 and alive(o) and not _in_hole(pos[o])
				core.injure(s, ["leg_l", "leg_r"][rng.randi_range(0, 1)], "broken" if held else "lost", "the drop")
				stun[s] = 1.2
				core.emit({"e": "mg", "k": "fall", "seat": s})
				pos[s] = pos[o] + Vector2(-0.4, 0) if held else Vector2(h.position.x - 0.5, p.y)
		for sw in saws:
			if absf(p.x - sw.x) < 0.35 and absf(p.y - saw_z(sw)) < 0.4 and stun.get(s, 0.0) <= 0.0:
				stun[s] = 0.8
				core.injure(s, ["arm_l", "arm_r", "hand_l", "hand_r"][rng.randi_range(0, 3)], "lost" if tip(s) else "broken", "the saw")
				core.emit({"e": "mg", "k": "saw", "seat": s})
	for i in teams.size():
		var all_across := true
		var any_alive := false
		for s in teams[i]:
			if alive(s):
				any_alive = true
				if (pos[s] as Vector2).x < bounds.end.x - 0.4:
					all_across = false
		if any_alive and all_across:
			for s in teams[i]:
				teeth[s] += 3
			finish(teams[i].filter(func(s): return alive(s)), false)
			return
	if t >= DURATION or living().is_empty():
		finish([], true)


func _in_hole(p: Vector2) -> bool:
	for h in holes:
		if h.has_point(p):
			return true
	return false


func arena_action(seat: int, a: Dictionary) -> void:
	match str(a.get("do", "")):
		"yank":
			var o := partner(seat)
			if o >= 0 and alive(o):
				pos[o] = (pos[o] as Vector2).lerp(pos[seat], 0.6)
				core.emit({"e": "mg", "k": "yank", "seat": seat, "target": o})
		"lever":
			for sw in saws:
				if absf(sw.x - (pos[seat] as Vector2).x) < 2.5:
					sw.stop = 3.0


func actions_for(_seat: int) -> Array:
	return [{"do": "yank", "name": "YANK THE CHAIN"}, {"do": "lever", "name": "STOP THE NEAREST SAW"}, {"do": "push", "name": "PUSH"}]


func view_for(viewers: Array) -> Dictionary:
	var v := base_view()
	objects.clear()
	for h in holes:
		objects.append({"kind": "hole", "pos": h.get_center(), "size": [h.size.x, h.size.y]})
	for sw in saws:
		objects.append({"kind": "saw", "pos": Vector2(sw.x, saw_z(sw)), "stopped": sw.stop > 0.0})
	objects.append({"kind": "finish", "pos": Vector2(bounds.end.x - 0.2, 0), "size": [0.4, 6]})
	for team in teams:
		if team.size() > 1:
			objects.append({"kind": "chain", "a": team[0], "b": team[1]})
	v.merge(arena_view())
	v.merge({"time_left": maxf(0.0, DURATION - t)})
	return view_with_actions(v, viewers)


func ai(seat: int, brain: AiBrain, _view: Dictionary, _dt: float) -> void:
	var p: Vector2 = pos[seat]
	var o := partner(seat)
	var target := Vector2(bounds.end.x, p.y)
	# steer round holes ahead
	for h in holes:
		if h.position.x - p.x < 1.0 and h.end.x > p.x and p.y > h.position.y - 0.3 and p.y < h.end.y + 0.3:
			target = Vector2(p.x + 0.4, h.position.y - 0.6 if p.y < h.get_center().y else h.end.y + 0.6)
	for sw in saws:
		if sw.x - p.x > 0.0 and sw.x - p.x < 0.8 and absf(p.y - saw_z(sw)) < 1.0:
			target = p
	if o >= 0 and alive(o) and (pos[o] as Vector2).distance_to(p) > CHAIN * 0.85:
		target = pos[o]
	steer(seat, target)
	if o >= 0 and alive(o) and brain.coop >= 0.3 and _in_hole(pos[o]):
		arena_action(seat, {"do": "yank"})
