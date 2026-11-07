extends ArenaGame
## THE LAST SEAT (FFA). Four of you, three seats that are safe (one fewer than there are
## of you, always). Walk while the music plays; when the ALARM goes, sit. Take a seat off
## someone (STEAL: knock them out of it), push people away from them, and if you can get
## away with it, rig one (it gives way), lock one (nobody sits in it for a moment), or
## find out when the alarm's coming. Whoever's left standing doesn't leave.

const SCRAMBLE := 3.5

var chairs: Array = []        # [{pos, taken, rigged, locked}]
var sub := "music"
var sub_t := 0.0
var alarm_at := 8.0
var warned: Dictionary = {}
var seated: Dictionary = {}   # seat -> chair


func id() -> String:
	return "last_seat"


func title() -> String:
	return "THE LAST SEAT"


func instructions() -> Array:
	return ["Walk while the music plays.", "When the ALARM sounds: SIT.", "There's one seat fewer than there are of you.",
		"STEAL a seat by knocking someone out of it.", "Whoever's left standing... stays standing."]


func setup() -> void:
	var n := maxi(1, seats.size() - 1)
	for i in n:
		var a := TAU * i / n
		chairs.append({"pos": Vector2(sin(a), cos(a)) * 1.5, "taken": -1, "rigged": false, "locked": 0.0})
	var pts := []
	for k in seats.size():
		var a := TAU * (k + 0.5) / seats.size()
		pts.append(Vector2(sin(a), cos(a)) * 3.4)
	place_start(pts)
	bounds = Rect2(-4.5, -4.5, 9, 9)
	alarm_at = rng.randf_range(5.0, 11.0)


func start() -> void:
	core.say("mc_music")
	core.emit({"e": "mg", "k": "music"})


func can_move(s: int) -> bool:
	return not seated.has(s)


func tick(dt: float) -> void:
	t += dt
	sub_t += dt
	for c in chairs:
		c.locked = maxf(0.0, c.locked - dt)
	match sub:
		"music":
			walk_all(dt)
			for s in warned.keys():
				if not warned[s] and sub_t > alarm_at - 1.5:
					warned[s] = true
					core.toast("Any second now...", s)
			if sub_t >= alarm_at:
				sub = "scramble"
				sub_t = 0.0
				for c in chairs:
					if c.get("lock_on_alarm", false):
						c.locked = 1.6
						c.erase("lock_on_alarm")
				core.say("mc_stop")
				core.emit({"e": "mg", "k": "alarm"})
		"scramble":
			walk_all(dt)
			_claim()
			if sub_t >= SCRAMBLE:
				_result()
		"result":
			if sub_t > 3.0:
				done = true


func _claim() -> void:
	for s in living():
		if seated.has(s) or stun.get(s, 0.0) > 0.0:
			continue
		for i in chairs.size():
			var c: Dictionary = chairs[i]
			if c.taken == -1 and c.locked <= 0.0 and (pos[s] as Vector2).distance_to(c.pos) < 0.6:
				if c.rigged or tip(s):
					# it gives way
					c.rigged = false
					injure_legs(s)
					core.emit({"e": "mg", "k": "collapse", "seat": s, "chair": i})
					stun[s] = 1.0
					break
				c.taken = s
				seated[s] = i
				pos[s] = c.pos
				core.emit({"e": "mg", "k": "sit", "seat": s, "chair": i})
				break


func injure_legs(s: int) -> void:
	core.injure(s, ["leg_l", "leg_r"][rng.randi_range(0, 1)], "bruised" if level == 0 else "broken", "the chair")


func arena_action(seat: int, a: Dictionary) -> void:
	if str(a.get("do", "")) == "steal" and sub == "scramble" and not seated.has(seat):
		for o in seated.keys():
			if (pos[o] as Vector2).distance_to(pos[seat]) < 0.95:
				var ci: int = seated[o]
				seated.erase(o)
				chairs[ci].taken = seat
				seated[seat] = ci
				pos[o] = clamp_in(pos[o] + (pos[o] - pos[seat]).normalized() * 1.2)
				pos[seat] = chairs[ci].pos
				stun[o] = 0.8
				core.emit({"e": "mg", "k": "steal", "seat": seat, "target": o, "chair": ci})
				core.brains[o].wronged_by(seat, 0.15)
				return


func _result() -> void:
	sub = "result"
	sub_t = 0.0
	var standing := living().filter(func(s): return not seated.has(s))
	var sitting := living().filter(func(s): return seated.has(s))
	for s in standing:
		core.say("mc_standing", {"name": core.p(s).name})
		core.kill(s, "trapdoor", [["leg_l", "lost"]])
		notes.append("%s was left standing." % core.p(s).name)
	for s in sitting:
		teeth[s] += 2
	winners.clear()
	for s in sitting:
		winners.append(s)
	draw = standing.is_empty() or sitting.is_empty()
	if draw:
		notes.append("A DRAW.")


func actions_for(seat: int) -> Array:
	var out := [{"do": "push", "name": "PUSH"}]
	if sub == "scramble" and not seated.has(seat):
		for o in seated.keys():
			if (pos[o] as Vector2).distance_to(pos[seat]) < 0.95:
				out.append({"do": "steal", "name": "STEAL %s'S SEAT" % core.p(o).name})
				break
	return out


func cheat_options(seat: int) -> Array:
	if sub != "music":
		return []
	var out := []
	for i in chairs.size():
		if (pos[seat] as Vector2).distance_to(chairs[i].pos) < 1.0:
			out.append({"id": "rig:%d" % i, "name": "rig this seat to give way"})
			out.append({"id": "lock:%d" % i, "name": "jam this seat for a moment"})
	if not warned.has(seat):
		out.append({"id": "alarm", "name": "find out when the alarm goes"})
	return out


func apply_cheat(seat: int, cid: String) -> void:
	if cid == "alarm":
		warned[seat] = false
	elif cid.begins_with("rig:"):
		chairs[int(cid.substr(4))].rigged = true
	elif cid.begins_with("lock:"):
		chairs[int(cid.substr(5))]["lock_on_alarm"] = true


func view_for(viewers: Array) -> Dictionary:
	var v := base_view()
	objects.clear()
	for i in chairs.size():
		var c: Dictionary = chairs[i]
		objects.append({"kind": "chair", "pos": c.pos, "taken": c.taken, "locked": c.locked > 0.0})
	v.merge(arena_view())
	v.merge({"sub": sub, "sub_t": sub_t, "seated": seated.duplicate()})
	return view_with_actions(v, viewers)


func ai(seat: int, brain: AiBrain, view: Dictionary, dt: float) -> void:
	if seated.has(seat):
		move[seat] = Vector2.ZERO
		return
	if sub == "music":
		var a := atan2(pos[seat].x, pos[seat].y) + 0.7 * dt * 4.0
		steer(seat, Vector2(sin(a), cos(a)) * 2.6)
		if brain.coop < 0.3 and brain.rng.randf() < dt * 0.05:
			var opts := cheat_options(seat)
			if not opts.is_empty():
				core.action(seat, {"t": "mg_cheat", "id": opts[0].id})
		return
	if sub == "scramble":
		var best := -1
		var bd := INF
		for i in chairs.size():
			if chairs[i].taken == -1 and (pos[seat] as Vector2).distance_to(chairs[i].pos) < bd:
				bd = (pos[seat] as Vector2).distance_to(chairs[i].pos)
				best = i
		if best >= 0:
			steer(seat, chairs[best].pos)
		else:
			var o := -1
			for x in seated.keys():
				o = x
			if o >= 0:
				steer(seat, pos[o])
				if (pos[o] as Vector2).distance_to(pos[seat]) < 0.95:
					arena_action(seat, {"do": "steal"})
