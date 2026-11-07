extends Minigame
## TUG OF WAR (2v2). A rope over a pit of hooks. Tap PULL on the beat (the ring closing
## on the rope): on the beat it's a real heave, off it you just waste breath. Pulling
## costs STAMINA; let it recover. Both of a team on the same beat: a heave and a half.
## HOLD DIG IN to brace against their pull (it drains you). Drag the other pair into the
## pit; or have the rope on your side when the whistle goes. Grease their end if he
## isn't looking.

const DURATION := 30.0
const BEAT := 0.8
const WINDOW := 0.16
const LIMIT := 3.0

var rope := 0.0             # + toward team 1
var stamina: Dictionary = {}
var dig: Dictionary = {}
var last_pull: Dictionary = {}   # seat -> beat index they pulled on
var greased := [0.0, 0.0]        # seconds each team's grip is greased
var hits: Dictionary = {}        # seat -> good pulls
var ended := false


func id() -> String:
	return "tug_of_war"


func title() -> String:
	return "TUG OF WAR"


func instructions() -> Array:
	return ["Tap PULL when the ring meets the rope: on the beat.", "Off the beat you waste stamina. Let it come back.",
		"Pull on the same beat as your partner: a bigger heave.", "HOLD DIG IN to brace.", "Drag them into the pit."]


func controls(_seat: int) -> Array:
	return [{"kind": "timing", "do": "pull", "label": "PULL", "period": BEAT, "window": WINDOW}, {"kind": "hold", "do": "dig", "label": "DIG IN"}]


func setup() -> void:
	make_teams([2, 2])
	for s in seats:
		stamina[s] = 100.0
		dig[s] = false
		last_pull[s] = -1
		hits[s] = 0


func beat_phase() -> float:
	return fmod(t, BEAT) / BEAT


func on_beat() -> bool:
	var ph := fmod(t, BEAT)
	return ph < WINDOW or ph > BEAT - WINDOW


func beat_index() -> int:
	return int(round(t / BEAT))


func strength(s: int) -> float:
	var st := clampf(Body.hands(body(s)) / 2.0, 0.3, 1.0) * (0.6 + 0.4 * Body.balance(body(s)))
	if handicapped.has(s):
		st *= 0.7
	if is_chilled(s):
		st *= 0.6
	if tampered(s):
		st *= 1.15
	return st


func action(seat: int, a: Dictionary) -> void:
	if not seats.has(seat) or not alive(seat) or ended:
		return
	match str(a.get("do", "")):
		"pull":
			if float(stamina[seat]) < 8.0:
				return
			stamina[seat] = float(stamina[seat]) - 9.0
			if not on_beat():
				core.emit({"e": "mg", "k": "slip", "seat": seat})
				return
			var bi := beat_index()
			if int(last_pull[seat]) == bi:
				return
			last_pull[seat] = bi
			hits[seat] += 1
			var team := team_of(seat)
			var mate: int = -1
			for o in teams[team]:
				if o != seat:
					mate = o
			var power := 0.32 * strength(seat)
			if mate >= 0 and int(last_pull.get(mate, -2)) == bi:
				power *= 1.5
			if greased[team] > 0.0:
				power *= 0.55
			# the other side bracing
			var bracing := 0
			for o in teams[1 - team]:
				if dig.get(o, false) and alive(o):
					bracing += 1
			power *= 1.0 - 0.25 * bracing
			rope += power * (1.0 if team == 1 else -1.0)
			core.emit({"e": "mg", "k": "heave", "seat": seat, "team": team})
		"dig":
			dig[seat] = bool(a.get("on", true))


func tick(dt: float) -> void:
	t += dt
	tick_chill(dt)
	if ended:
		return
	for i in 2:
		greased[i] = maxf(0.0, greased[i] - dt)
	for s in seats:
		if dig[s] and float(stamina[s]) > 0.0:
			stamina[s] = maxf(0.0, float(stamina[s]) - 14.0 * dt)
			if float(stamina[s]) <= 0.0:
				dig[s] = false
		else:
			stamina[s] = minf(100.0, float(stamina[s]) + 13.0 * dt * (0.6 if body(s).torso.s != "ok" else 1.0))
	if absf(rope) >= LIMIT or t >= DURATION:
		_end()


func _end() -> void:
	ended = true
	var winner := -1
	if rope >= LIMIT * 0.05:
		winner = 1
	elif rope <= -LIMIT * 0.05:
		winner = 0
	if winner < 0:
		finish([], true)
		return
	var losers: Array = teams[1 - winner]
	if absf(rope) >= LIMIT:
		notes.append("The losing pair went into the hooks.")
		for s in losers:
			if (level >= 2 or tip(s)) and core.kill(s, "hooks", [["arm_l", "lost"]]):
				continue
			core.injure(s, ["hand_l", "hand_r", "arm_l", "arm_r"][rng.randi_range(0, 3)], "broken" if level >= 1 else "burned", "the hooks")
	else:
		for s in losers:
			core.injure(s, ["hand_l", "hand_r"][rng.randi_range(0, 1)], "burned", "rope burn")
	finish(teams[winner].filter(func(s): return alive(s)))


func cheat_options(seat: int) -> Array:
	return [{"id": "grease", "name": "grease their end of the rope"}] if alive(seat) else []


func apply_cheat(seat: int, _cid: String) -> void:
	greased[1 - team_of(seat)] = 6.0


func view_for(viewers: Array) -> Dictionary:
	var v := base_view()
	v.merge({"rope": rope, "limit": LIMIT, "stamina": stamina.duplicate(), "dig": dig.duplicate(), "beat": beat_phase(), "period": BEAT,
		"on_beat": on_beat(), "greased": greased.duplicate(), "hits": hits.duplicate(), "time_left": maxf(0.0, DURATION - t)})
	return view_with_actions(v, viewers)


func ai(seat: int, brain: AiBrain, _view: Dictionary, _dt: float) -> void:
	if ended:
		return
	var team := team_of(seat)
	var losing := (rope < 0.0) if team == 1 else (rope > 0.0)
	dig[seat] = losing and absf(rope) > 1.8 and float(stamina[seat]) > 40.0
	# timing: good AIs hit the beat; the clumsy ones flail
	var accuracy := 0.45 + brain.perception * 0.5
	if on_beat() and int(last_pull[seat]) != beat_index() and float(stamina[seat]) > 20.0:
		if brain.rng.randf() < accuracy:
			action(seat, {"do": "pull"})
		else:
			last_pull[seat] = beat_index()   # missed it
	elif not on_beat() and brain.rng.randf() < (1.0 - accuracy) * 0.04:
		action(seat, {"do": "pull"})
