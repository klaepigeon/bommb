extends Minigame
## SPIN CYCLE (FFA). Inside an industrial washing drum. It turns, and carries you up the
## side with it; HOLD LEFT or RIGHT to run against it and stay near the bottom. Get carried
## too high and you lose your footing and come down hard (BALANCE goes; at nothing, you're
## out, through the door seal). The drum REVERSES (the lights stutter first) and speeds up;
## loose bricks tumble down from the top (watch for the shadow). Once a game you can pull
## the REVERSE LEVER yourself, timed to throw someone else.

const DURATION := 35.0
const FALL_AT := 1.75        # radians from the bottom
const REVERSE_WARN := 1.5

var ang: Dictionary = {}      # seat -> angle from the bottom (radians; + is the drum's way)
var run: Dictionary = {}      # seat -> -1..1
var balance: Dictionary = {}  # 0..100
var stun_t: Dictionary = {}
var lever_used: Dictionary = {}
var out_at: Dictionary = {}
var omega := 1.0
var dir := 1.0
var rev_warn := 0.0
var _next_rev := 6.0
var bricks: Array = []        # [{a, warn, fall}]
var _brick_t := 4.0


func id() -> String:
	return "spin_cycle"


func title() -> String:
	return "SPIN CYCLE"


func instructions() -> Array:
	return ["The drum carries you up the side. HOLD ◀ or ▶ to run against it.", "Too high and you fall: BALANCE drops. At zero you're out.",
		"When the lights stutter, it's about to REVERSE.", "Watch for falling bricks.", "Pull the REVERSE LEVER (once) to throw someone."]


func controls(_seat: int) -> Array:
	var out: Array = [{"kind": "hold", "do": "left", "label": "◀ RUN"}, {"kind": "hold", "do": "right", "label": "RUN ▶"}]
	if not lever_used.has(_seat):
		out.append({"kind": "tap", "do": "lever", "label": "REVERSE LEVER"})
	return out


func setup() -> void:
	for k in seats.size():
		var s: int = seats[k]
		ang[s] = (k - (seats.size() - 1) / 2.0) * 0.35
		run[s] = 0.0
		balance[s] = 100.0
		stun_t[s] = 0.0
	omega = 1.0 + level * 0.25


func in_game(s: int) -> bool:
	return alive(s) and not out_at.has(s)


func action(seat: int, a: Dictionary) -> void:
	if not seats.has(seat) or not in_game(seat):
		return
	var on := bool(a.get("on", true))
	match str(a.get("do", "")):
		"left":
			run[seat] = -1.0 if on else (0.0 if float(run[seat]) < 0.0 else float(run[seat]))
		"right":
			run[seat] = 1.0 if on else (0.0 if float(run[seat]) > 0.0 else float(run[seat]))
		"lever":
			if not lever_used.has(seat):
				lever_used[seat] = true
				_reverse()
				core.emit({"e": "mg", "k": "lever", "seat": seat})


func _reverse() -> void:
	dir = -dir
	rev_warn = 0.0
	_next_rev = rng.randf_range(5.0, 8.0)
	core.emit({"e": "mg", "k": "reverse"})


func tick(dt: float) -> void:
	t += dt
	tick_chill(dt)
	omega = 1.0 + level * 0.25 + t * 0.025
	_next_rev -= dt
	if _next_rev <= REVERSE_WARN and rev_warn <= 0.0 and _next_rev > 0.0:
		rev_warn = REVERSE_WARN
		core.emit({"e": "mg", "k": "reverse_warn"})
	if _next_rev <= 0.0:
		_reverse()
	rev_warn = maxf(0.0, rev_warn - dt)
	# bricks
	_brick_t -= dt
	if _brick_t <= 0.0:
		_brick_t = maxf(1.6, 4.0 - t * 0.06 - level * 0.4)
		var target := 0.0
		var up := seats.filter(func(s): return in_game(s))
		if not up.is_empty():
			target = float(ang[up[rng.randi_range(0, up.size() - 1)]])
		bricks.append({"a": target + rng.randf_range(-0.2, 0.2), "warn": 1.2})
	for b in bricks:
		b.warn = float(b.warn) - dt
		if float(b.warn) <= 0.0 and not b.get("hit", false):
			b.hit = true
			for s in seats:
				if in_game(s) and absf(float(ang[s]) - float(b.a)) < 0.28:
					_knock(s, 30.0, "a brick")
	bricks = bricks.filter(func(b): return float(b.warn) > -0.4)
	for s in seats:
		if not in_game(s):
			continue
		if float(stun_t[s]) > 0.0:
			stun_t[s] = float(stun_t[s]) - dt
			ang[s] = move_toward(float(ang[s]), 0.0, 2.0 * dt)
			continue
		var legs := Body.speed(body(s), core.p(s).pk()) * (0.75 if handicapped.has(s) else 1.0) * (0.5 if is_chilled(s) else 1.0)
		var carry := omega * dir * 0.85
		var slide := -sin(float(ang[s])) * 1.1
		ang[s] = float(ang[s]) + (carry + slide + float(run[s]) * 2.3 * legs) * dt
		if absf(float(ang[s])) > FALL_AT:
			_knock(s, 25.0, "the drum")
	if t >= DURATION or seats.filter(func(s): return in_game(s)).size() <= 1:
		_end()


func _knock(s: int, amount: float, why: String) -> void:
	ang[s] = 0.0
	stun_t[s] = 1.0
	balance[s] = maxf(0.0, float(balance[s]) - amount)
	core.emit({"e": "mg", "k": "fall", "seat": s, "why": why})
	core.injure(s, ["arm_l", "arm_r", "leg_l", "leg_r", "head"][rng.randi_range(0, 4)], "bruised" if level == 0 else "burned", "the drum")
	if float(balance[s]) <= 0.0:
		out_at[s] = t
		notes.append("%s went through the door seal." % core.p(s).name)
		if (level >= 2 or tip(s)) and core.kill(s, "crushed", [["torso", "broken"]]):
			return
		core.injure(s, "torso", "broken", "the drum")


func _end() -> void:
	var score := {}
	for s in seats:
		score[s] = (1000.0 + float(balance[s])) if in_game(s) else float(out_at.get(s, 0.0))
	rank_by(score)
	var up := seats.filter(func(s): return in_game(s))
	var best := -1.0
	var top := []
	for s in up:
		if float(balance[s]) > best:
			best = float(balance[s])
			top = [s]
		elif float(balance[s]) == best:
			top.append(s)
	for s in up:
		teeth[s] += 2
	if top.size() == 1:
		finish(top)
	else:
		finish([], true)


func cheat_options(seat: int) -> Array:
	return [{"id": "grip", "name": "wedge your boots in the holes"}] if in_game(seat) else []


func apply_cheat(seat: int, _cid: String) -> void:
	balance[seat] = minf(100.0, float(balance[seat]) + 30.0)


func view_for(viewers: Array) -> Dictionary:
	var v := base_view()
	var bv := []
	for b in bricks:
		bv.append({"a": b.a, "warn": b.warn})
	v.merge({"ang": ang.duplicate(), "balance": balance.duplicate(), "out": out_at.keys(), "omega": omega * dir, "rev_warn": rev_warn > 0.0,
		"bricks": bv, "stun": stun_t.duplicate(), "lever_used": lever_used.keys(), "time_left": maxf(0.0, DURATION - t), "run": run.duplicate()})
	return view_with_actions(v, viewers)


func ai(seat: int, brain: AiBrain, _view: Dictionary, _dt: float) -> void:
	if not in_game(seat):
		return
	var a := float(ang[seat])
	# anticipate the reverse if you're sharp
	var expect := dir * (-1.0 if rev_warn > 0.0 and brain.rng.randf() < brain.perception else 1.0)
	var want := -expect * 0.9 - a * 1.2
	for b in bricks:
		if float(b.warn) > 0.0 and absf(a - float(b.a)) < 0.4:
			want = signf(a - float(b.a)) * 2.0
	run[seat] = clampf(want, -1.0, 1.0)
	# the lever, when someone else is high up on the other side
	if not lever_used.has(seat) and brain.coop < 0.5:
		for o in seats:
			if o != seat and in_game(o) and absf(float(ang[o])) > 1.2 and signf(float(ang[o])) == dir and absf(a) < 0.5:
				action(seat, {"do": "lever"})
				break
