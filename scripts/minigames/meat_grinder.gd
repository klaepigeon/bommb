extends ArenaGame
## MEAT GRINDER (FFA). A conveyor belt runs toward the grinder; walk against it. Dead Rats
## ride the belt: grab them. Presses come down across parts of the belt: be somewhere else.
## PUSH people back toward the end. Jam a press if he isn't looking. Most rats when the
## belt stops wins; the grinder takes whatever reaches it.

const BELT := 1.25
const DURATION := 32.0
var presses: Array = []       # [{x, z0, z1, period, phase, jam}]
var pickups: Array = []       # [Vector2]
var score: Dictionary = {}
var _spawn := 0.0


func id() -> String:
	return "meat_grinder"


func title() -> String:
	return "MEAT GRINDER"


func instructions() -> Array:
	return ["The belt carries you to the grinder. Walk against it.", "Grab the Dead Rats riding the belt.",
		"Don't be under a press when it comes down.", "PUSH people. Most rats when it stops wins."]


func setup() -> void:
	bounds = Rect2(-6, -2.4, 12, 4.8)
	var pts := []
	for k in seats.size():
		pts.append(Vector2(1.5 + k * 0.6, -1.6 + k * 1.1))
	place_start(pts)
	for k in [-2.2, 0.8, 3.4]:
		var lane := rng.randi_range(0, 1)
		presses.append({"x": k, "z0": -2.4 if lane == 0 else 0.0, "z1": 0.0 if lane == 0 else 2.4,
			"period": rng.randf_range(2.4, 3.6) - level * 0.3, "phase": rng.randf() * 3.0, "jam": 0.0})
	for s in seats:
		score[s] = 0


func drift(_s: int) -> Vector2:
	return Vector2(-BELT - level * 0.12, 0)


func closed(pr: Dictionary) -> bool:
	if pr.jam > 0.0:
		return false
	return fmod(t + pr.phase, pr.period) > pr.period - 0.7


func tick(dt: float) -> void:
	t += dt
	walk_all(dt)
	_spawn -= dt
	if _spawn <= 0.0:
		_spawn = 0.9
		pickups.append(Vector2(6.0, rng.randf_range(-2.0, 2.0)))
	for i in pickups.size():
		pickups[i] += Vector2(-BELT, 0) * dt
	pickups = pickups.filter(func(p): return p.x > -6.0)
	for pr in presses:
		pr.jam = maxf(0.0, pr.jam - dt)
	for s in living():
		var p: Vector2 = pos[s]
		for i in range(pickups.size() - 1, -1, -1):
			if p.distance_to(pickups[i]) < 0.55:
				pickups.remove_at(i)
				score[s] += 1
		for pr in presses:
			if closed(pr) and absf(p.x - pr.x) < 0.45 and p.y > pr.z0 and p.y < pr.z1 and stun.get(s, 0.0) <= 0.0:
				stun[s] = 1.2
				var part: String = ["arm_l", "arm_r", "leg_l", "leg_r", "hand_l", "hand_r", "tail"][rng.randi_range(0, 6)]
				var sev := "lost" if (level >= 2 or tip(s)) else "broken"
				core.injure(s, part, sev, "the press")
				core.emit({"e": "mg", "k": "press", "seat": s})
		if p.x <= bounds.position.x + 0.2:
			core.say("grinder", {"name": core.p(s).name})
			# the first time it takes your feet; after that (or if he's leaning on you) all of you
			if (level >= 1 or tip(s)) and core.kill(s, "boom", [["leg_l", "lost"], ["leg_r", "lost"]]):
				notes.append("%s went in the grinder." % core.p(s).name)
			elif core.p(s).alive:
				core.injure(s, ["leg_l", "leg_r"][rng.randi_range(0, 1)], "lost", "the grinder")
				pos[s] = Vector2(2.5, p.y)
				stun[s] = 1.0
	if t >= DURATION or living().size() <= 0:
		_end()


func _end() -> void:
	var best := -1
	var top: Array = []
	for s in living():
		if score[s] > best:
			best = score[s]
			top = [s]
		elif score[s] == best:
			top.append(s)
	for s in living():
		rats[s] += score[s]
	finish(top if top.size() == 1 else [], top.size() != 1)


func cheat_options(seat: int) -> Array:
	var out := []
	for i in presses.size():
		if absf((pos[seat] as Vector2).x - presses[i].x) < 1.5:
			out.append({"id": "jam:%d" % i, "name": "jam this press"})
	return out


func apply_cheat(_seat: int, cid: String) -> void:
	if cid.begins_with("jam:"):
		presses[int(cid.substr(4))].jam = 6.0


func actions_for(_seat: int) -> Array:
	return [{"do": "push", "name": "PUSH"}]


func view_for(viewers: Array) -> Dictionary:
	var v := base_view()
	objects.clear()
	objects.append({"kind": "belt", "pos": Vector2(0, 0), "size": [12, 4.8]})
	objects.append({"kind": "grinder", "pos": Vector2(-6.2, 0), "size": [0.6, 4.8]})
	for pr in presses:
		objects.append({"kind": "press", "pos": Vector2(pr.x, (pr.z0 + pr.z1) / 2.0), "size": [0.8, pr.z1 - pr.z0], "closed": closed(pr), "jam": pr.jam > 0.0})
	for p in pickups:
		objects.append({"kind": "rat", "pos": p})
	v.merge(arena_view())
	v.merge({"score": score.duplicate(), "time_left": maxf(0.0, DURATION - t)})
	return view_with_actions(v, viewers)


func ai(seat: int, brain: AiBrain, _view: Dictionary, _dt: float) -> void:
	var p: Vector2 = pos[seat]
	var target := Vector2(2.5, p.y)
	var best := INF
	for q in pickups:
		if q.x > -1.0 and p.distance_to(q) < best:
			best = p.distance_to(q)
			target = q
	# keep out from under a press that's about to come down
	for pr in presses:
		if absf(p.x - pr.x) < 0.9 and fmod(t + pr.phase, pr.period) > pr.period - 1.4:
			if p.y > pr.z0 and p.y < pr.z1:
				target = Vector2(p.x + 0.5, pr.z1 + 0.6 if pr.z0 < -1.0 else pr.z0 - 0.6)
	if p.x < -1.5:
		target = Vector2(4.0, p.y)
	steer(seat, target)
	var o := nearest_other(seat)
	if o >= 0 and brain.coop < 0.4 and (pos[o] as Vector2).distance_to(p) < 0.9 and (pos[o] as Vector2).x < p.x:
		facing[seat] = Vector2.LEFT
		push(seat)
