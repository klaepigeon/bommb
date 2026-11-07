extends Minigame
## LAST MAN BREATHING (duel). Two of you, two glass tanks, one pipe feeding both. The pipe
## breathes clean air and then FOUL gas, in turns, and it isn't the same for both tanks.
## HOLD to hold your breath (your air runs down: faster if your chest's hurt). LET GO to
## breathe: clean air fills you up; foul gas poisons you. Read the tells: the pipe KNOCKS
## just before it turns foul (you'll hear it, if you've still got ears; the gauge
## twitches if you watch). Run out of air and you breathe whatever's there. Too much gas
## and you go under. The one still breathing wins.

const DURATION := 60.0
const KNOCK := 0.9

var air: Dictionary = {}
var tox: Dictionary = {}
var holding: Dictionary = {}
var foul: Dictionary = {}       # seat -> is the gas foul now
var gas_t: Dictionary = {}      # seat -> seconds until it changes
var under: Dictionary = {}      # seat -> time they went under
var _ended := false


func id() -> String:
	return "last_man_breathing"


func title() -> String:
	return "LAST MAN BREATHING"


func instructions() -> Array:
	return ["HOLD to hold your breath. LET GO to breathe.", "Clean air fills you up. FOUL gas poisons you.",
		"The pipe KNOCKS (and the gauge twitches) just before it turns foul.", "Out of air, you breathe whatever's there.", "Last one breathing wins."]


func controls(_seat: int) -> Array:
	return [{"kind": "hold", "do": "hold", "label": "HOLD YOUR BREATH"}]


func setup() -> void:
	for s in seats:
		air[s] = 100.0
		tox[s] = 0.0
		holding[s] = false
		foul[s] = false
		gas_t[s] = rng.randf_range(2.5, 4.5)


func knocking(s: int) -> bool:
	return not foul[s] and float(gas_t[s]) < KNOCK


func action(seat: int, a: Dictionary) -> void:
	if not seats.has(seat) or not alive(seat) or under.has(seat):
		return
	if str(a.get("do", "")) == "hold":
		holding[seat] = bool(a.get("on", true)) and float(air[seat]) > 0.0


func tick(dt: float) -> void:
	t += dt
	tick_chill(dt)
	if _ended:
		return
	var pace := 1.0 + t / 30.0
	for s in seats:
		if not alive(s) or under.has(s):
			continue
		gas_t[s] = float(gas_t[s]) - dt
		if float(gas_t[s]) <= 0.0:
			foul[s] = not foul[s]
			gas_t[s] = rng.randf_range(1.6, 3.2) * (pace if foul[s] else 1.0 / pace) + (0.6 if foul[s] and level > 0 else 0.0)
			if foul[s]:
				core.emit({"e": "mg", "k": "foul", "seat": s})
		var chest := 1.0 if body(s).torso.s == "ok" else (1.5 if body(s).torso.s in ["bruised", "burned"] else 2.2)
		if handicapped.has(s) or is_chilled(s):
			chest *= 1.3
		if holding[s]:
			air[s] = maxf(0.0, float(air[s]) - 11.0 * chest * dt)
			if float(air[s]) <= 0.0:
				holding[s] = false
				core.emit({"e": "mg", "k": "gasp", "seat": s})
		else:
			if foul[s]:
				tox[s] = float(tox[s]) + (24.0 + level * 4.0) * dt
				air[s] = minf(100.0, float(air[s]) + 10.0 * dt)
			else:
				air[s] = minf(100.0, float(air[s]) + 38.0 * dt)
				tox[s] = maxf(0.0, float(tox[s]) - 3.0 * dt)
		if float(tox[s]) >= 100.0:
			under[s] = t
			core.emit({"e": "mg", "k": "under", "seat": s})
			notes.append("%s went under." % core.p(s).name)
	var breathing := seats.filter(func(s): return alive(s) and not under.has(s))
	if breathing.size() <= 1 or t >= DURATION:
		_end(breathing)


func _end(breathing: Array) -> void:
	_ended = true
	for s in under.keys():
		if (level >= 2 or tip(s)) and core.kill(s, "gassed", [["torso", "burned"]]):
			continue
		core.injure(s, "torso", "burned" if level == 0 else "broken", "the gas")
		if rng.randf() < 0.3:
			core.injure(s, ["eye_l", "eye_r"][rng.randi_range(0, 1)] if body(s).has("eye_l") else "head", "burned", "the gas")
	var score := {}
	for s in seats:
		score[s] = 1000.0 - float(tox[s]) if not under.has(s) else float(under[s])
	rank_by(score)
	if breathing.size() == 1:
		finish(breathing)
	else:
		finish([], true)


func cheat_options(seat: int) -> Array:
	return [{"id": "kink", "name": "kink their air pipe"}] if alive(seat) and not under.has(seat) else []


func apply_cheat(seat: int, _cid: String) -> void:
	for o in seats:
		if o != seat:
			foul[o] = true
			gas_t[o] = 3.0


func view_for(viewers: Array) -> Dictionary:
	var v := base_view()
	var me := int(viewers[0]) if not viewers.is_empty() else -1
	var knock := {}
	for s in seats:
		# your own tank's tell: louder for you; you can only half see theirs
		knock[s] = knocking(s)
	v.merge({"air": air.duplicate(), "tox": tox.duplicate(), "holding": holding.duplicate(), "foul": foul.duplicate(), "knock": knock,
		"under": under.keys(), "time_left": maxf(0.0, DURATION - t), "me": me})
	return view_with_actions(v, viewers)


func ai(seat: int, brain: AiBrain, _view: Dictionary, _dt: float) -> void:
	if under.has(seat) or not alive(seat):
		return
	var read := brain.rng.randf() < 0.55 + brain.perception * 0.4
	var hold: bool = holding[seat]
	if foul[seat] or (knocking(seat) and read):
		hold = float(air[seat]) > 6.0
	else:
		hold = false
	if hold != holding[seat]:
		action(seat, {"do": "hold", "on": hold})
