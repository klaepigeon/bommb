extends ArenaGame
## DEAD WEIGHT (FFA). Everyone has a pressure plate with a number on it. Crates (one each)
## lie about. When the clock runs out, each plate has to hold exactly its number, or it
## springs. GRAB a crate (one at a time), DROP it. Take crates off other people's plates;
## push people off course. There are exactly enough crates for everyone: if you all get it
## right, it's a draw (and you know what a draw does).

const DURATION := 34.0
var plates: Dictionary = {}    # seat -> {pos, target}
var crates: Array = []         # [{pos, on: seat|-1, held: seat|-1}]
var shimmed: Dictionary = {}


func id() -> String:
	return "dead_weight"


func title() -> String:
	return "DEAD WEIGHT"


func instructions() -> Array:
	return ["Your plate needs EXACTLY its number of crates.", "GRAB a crate, carry it, DROP it on a plate.",
		"Steal from other plates. Push.", "Wrong when the time's up: it springs."]


func setup() -> void:
	bounds = Rect2(-5, -3.8, 10, 7.6)
	var corners := [Vector2(-3.8, -2.7), Vector2(3.8, -2.7), Vector2(-3.8, 2.7), Vector2(3.8, 2.7)]
	var pts := []
	var total := 0
	for k in seats.size():
		var s: int = seats[k]
		var tgt := rng.randi_range(2, 4)
		plates[s] = {"pos": corners[k % 4], "target": tgt}
		total += tgt
		pts.append(corners[k % 4] * 0.6)
	place_start(pts)
	for i in total:
		crates.append({"pos": Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-1.8, 1.8)), "on": -1, "held": -1})


func on_plate(s: int) -> int:
	var n := 0
	for c in crates:
		if c.on == s:
			n += 1
	return n


func carry_drop(s: int) -> void:
	for c in crates:
		if c.held == s:
			c.held = -1
			c.pos = pos[s]
			_settle(c)
	carry[s] = ""


func _settle(c: Dictionary) -> void:
	c.on = -1
	for s in plates.keys():
		if (c.pos as Vector2).distance_to(plates[s].pos) < 0.8:
			c.on = s


func arena_action(seat: int, a: Dictionary) -> void:
	match str(a.get("do", "")):
		"grab":
			if carry.get(seat, "") != "":
				return
			var best: Dictionary = {}
			var bd := 0.9
			for c in crates:
				if c.held == -1 and (c.pos as Vector2).distance_to(pos[seat]) < bd:
					bd = (c.pos as Vector2).distance_to(pos[seat])
					best = c
			if not best.is_empty():
				if best.on >= 0 and best.on != seat:
					core.brains[best.on].wronged_by(seat, 0.05)
				best.held = seat
				best.on = -1
				carry[seat] = "crate"
		"drop":
			carry_drop(seat)


func tick(dt: float) -> void:
	t += dt
	walk_all(dt)
	for c in crates:
		if c.held >= 0:
			c.pos = pos[c.held]
	if t >= DURATION:
		_end()


func _end() -> void:
	var right: Array = []
	var wrong: Array = []
	for s in living():
		carry_drop(s)
	for s in living():
		var diff: int = absi(on_plate(s) - int(plates[s].target))
		if shimmed.has(s) and not tip(s):
			diff = 0
		if diff == 0:
			right.append(s)
		else:
			wrong.append(s)
			core.emit({"e": "mg", "k": "spring", "seat": s})
			if diff >= 3 and core.kill(s, "launch", [["leg_l", "lost"]]):
				notes.append("%s's plate was very wrong." % core.p(s).name)
			elif core.p(s).alive:
				core.injure(s, ["leg_l", "leg_r"][rng.randi_range(0, 1)], "broken" if diff == 1 else "lost", "the plate")
	for s in right:
		rats[s] += 3
	finish(right, right.is_empty() or wrong.is_empty())


func actions_for(seat: int) -> Array:
	var out := [{"do": "push", "name": "PUSH"}]
	if carry.get(seat, "") != "":
		out.append({"do": "drop", "name": "DROP THE CRATE"})
	else:
		out.append({"do": "grab", "name": "GRAB A CRATE"})
	return out


func cheat_options(seat: int) -> Array:
	if shimmed.has(seat):
		return []
	if (pos[seat] as Vector2).distance_to(plates[seat].pos) < 1.0:
		return [{"id": "shim", "name": "shim your plate so it reads right"}]
	return []


func apply_cheat(seat: int, cid: String) -> void:
	if cid == "shim":
		shimmed[seat] = true


func ghost_secret(to: int) -> String:
	return "your plate has %d. It wants %d." % [on_plate(to), plates[to].target]


func view_for(viewers: Array) -> Dictionary:
	var v := base_view()
	objects.clear()
	for s in plates.keys():
		objects.append({"kind": "plate", "pos": plates[s].pos, "target": plates[s].target, "count": on_plate(s), "owner": s})
	for c in crates:
		objects.append({"kind": "crate", "pos": c.pos, "held": c.held})
	v.merge(arena_view())
	v.merge({"time_left": maxf(0.0, DURATION - t)})
	return view_with_actions(v, viewers)


func ai(seat: int, brain: AiBrain, _view: Dictionary, _dt: float) -> void:
	var need: int = int(plates[seat].target) - on_plate(seat)
	if carry.get(seat, "") != "":
		# carrying: to my plate if I need it; a kind one takes a spare to someone short
		var dest: Vector2 = plates[seat].pos
		if need <= 0 and brain.coop >= 0.5:
			for o in plates.keys():
				if o != seat and on_plate(o) < int(plates[o].target):
					dest = plates[o].pos
					break
		elif need <= 0:
			dest = Vector2.ZERO
		steer(seat, dest)
		if (pos[seat] as Vector2).distance_to(dest) < 0.5:
			arena_action(seat, {"do": "drop"})
		return
	if need < 0:
		steer(seat, plates[seat].pos)
		if (pos[seat] as Vector2).distance_to(plates[seat].pos) < 0.6:
			arena_action(seat, {"do": "grab"})
		return
	if need == 0:
		move[seat] = Vector2.ZERO
		return
	# find a loose crate (or, if selfish, one off someone else's plate)
	var best := Vector2.INF
	for c in crates:
		if c.held != -1 or c.on == seat:
			continue
		if c.on >= 0 and brain.coop >= 0.5 and on_plate(c.on) <= int(plates[c.on].target):
			continue
		if (c.pos as Vector2).distance_to(pos[seat]) < (best - pos[seat]).length():
			best = c.pos
	if best != Vector2.INF:
		steer(seat, best)
		if best.distance_to(pos[seat]) < 0.7:
			arena_action(seat, {"do": "grab"})
