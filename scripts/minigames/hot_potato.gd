extends Minigame
## MINIGAME 03: HOT POTATO. "It's not a potato." A ticking clockwork toy with a face is
## passed round; whoever holds it when it goes off is out. That's the game on the card.
##
## The game under the game: the toy can be stopped. Whoever holds it can FIDDLE with it
## (twist its nose). Nothing announces anything, but its face lights the next thing it
## wants done, and the one who did the last thing can't do the next: it has to be passed
## to somebody else. Done in order, by different hands, before it runs out, it stops,
## and gives up its winding key. The order never changes, so it can be learnt.

const STEPS := [
	{"id": "nose", "name": "TWIST ITS NOSE", "hands": 1},
	{"id": "ribbon", "name": "PULL THE RIBBON", "hands": 2},
	{"id": "key", "name": "WIND THE KEY BACKWARDS", "hands": 1},
	{"id": "eyes", "name": "PRESS BOTH EYES", "hands": 2},
	{"id": "hush", "name": "SAY 'HUSH'", "hands": 0},
]
const STEP_TIME := 0.5        # doing a step
const AWKWARD_TIME := 2.2     # a two-handed step with one hand (or none: teeth, elbows)

var holder := -1
var flight := {}              # {from, to, t, dur}
var fuse := 30.0
var elapsed := 0.0
var step_i := -1              # -1: nobody has fiddled; else the next step to do
var n_steps := 4
var last_doer := -1
var busy := {}                # {seat, t, dur, step} a step in progress (can't pass)
var sub := "play"             # play | boom | defused | over
var sub_t := 0.0
var defused_by: Array[int] = []


func id() -> String:
	return "hot_potato"


func title() -> String:
	return "HOT POTATO"


func instructions() -> Array:
	return ["It's not a potato.", "PASS it to someone. Don't hold it.",
		"Whoever has it when it goes off is out.", "Don't fiddle with it."]


func setup() -> void:
	n_steps = 4 + mini(level, 1)
	fuse = rng.randf_range(30.0, 42.0) - 3.0 * mini(level, 2)
	holder = seats[rng.randi_range(0, seats.size() - 1)]


func start() -> void:
	sub = "play"
	core.say("hp_start")
	core.emit({"e": "mg", "k": "start", "holder": holder})


func tick(dt: float) -> void:
	t += dt
	sub_t += dt
	match sub:
		"play":
			elapsed += dt
			if not flight.is_empty():
				flight.t += dt
				if flight.t >= flight.dur:
					holder = flight.to
					flight = {}
					core.emit({"e": "mg", "k": "catch", "seat": holder})
			if not busy.is_empty():
				busy.t += dt
				if busy.t >= busy.dur:
					_complete_step(busy.seat)
			if holder >= 0 and not alive(holder):
				_pass_to(holder, _random_other(holder))
			if elapsed >= fuse:
				_boom()
		"boom", "defused":
			if sub_t > 3.0:
				sub = "over"
				finish(living(), false)


func _random_other(s: int) -> int:
	var o := living().filter(func(x): return x != s)
	return o[rng.randi_range(0, o.size() - 1)] if not o.is_empty() else s


func can_step(seat: int) -> bool:
	return sub == "play" and holder == seat and flight.is_empty() and busy.is_empty() and step_i >= 1 and step_i < n_steps and seat != last_doer


func action(seat: int, a: Dictionary) -> void:
	if sub != "play" or seat != holder or not flight.is_empty() or not busy.is_empty():
		return
	match str(a.get("do", "")):
		"pass":
			var to := int(a.get("target", -1))
			if to == seat or not seats.has(to) or not alive(to):
				to = _random_other(seat)
			_pass_to(seat, to)
		"fiddle":
			if step_i == -1:
				step_i = 0
				_begin_step(seat)
		"step":
			if can_step(seat):
				_begin_step(seat)


func _pass_to(from: int, to: int) -> void:
	if to == from:
		return
	var hands := Body.hands(body(from), core.p(from).pk()) if alive(from) else 2.0
	flight = {"from": from, "to": to, "t": 0.0, "dur": 0.55 / clampf(hands / 2.0, 0.35, 1.0)}
	holder = -1
	core.emit({"e": "mg", "k": "pass", "from": from, "to": to})


func _begin_step(seat: int) -> void:
	var st: Dictionary = STEPS[step_i]
	var dur := STEP_TIME
	var hands := Body.hands(body(seat))
	if int(st.hands) == 2 and not Body.two_handed(body(seat)):
		dur = AWKWARD_TIME
	elif int(st.hands) == 1 and hands <= 0.0:
		dur = AWKWARD_TIME
	busy = {"seat": seat, "t": 0.0, "dur": dur, "step": step_i}
	core.emit({"e": "mg", "k": "doing", "seat": seat, "step": step_i, "dur": dur})


func _complete_step(seat: int) -> void:
	busy = {}
	last_doer = seat
	if not defused_by.has(seat):
		defused_by.append(seat)
	core.emit({"e": "mg", "k": "step_done", "seat": seat, "step": step_i})
	step_i += 1
	if step_i >= 2 and step_i <= 4:
		core.say("hp_step%d" % mini(step_i - 1, 3))
	for o in living():
		core.brains[o].saw_kindness(seat, 0.15)
	if step_i >= n_steps:
		_defused(seat)


func _defused(seat: int) -> void:
	sub = "defused"
	sub_t = 0.0
	core.emit({"e": "mg", "k": "defused", "seat": seat})
	core.say("hp_defused")
	notes.append("It stopped. %d pairs of hands." % defused_by.size())
	if not core.key_exists:
		core.key_exists = true
		core.p(seat).has_key = true
		core.emit({"e": "key", "seat": seat})
		core.toast("%s is left holding a little brass winding key." % core.p(seat).name)
		notes.append("%s kept the key." % core.p(seat).name)
	else:
		for s in defused_by:
			teeth[s] += 3
	core.add_unrest("defused", 1.0)


func _boom() -> void:
	sub = "boom"
	sub_t = 0.0
	var victim := holder if holder >= 0 else int(flight.get("to", -1))
	flight = {}
	busy = {}
	core.emit({"e": "mg", "k": "boom", "seat": victim})
	if victim >= 0 and alive(victim):
		var nm := core.p(victim).name
		core.say("hp_boom", {"name": nm})
		if core.kill(victim, "boom", [["hand_l", "lost"], ["hand_r", "lost"], ["eye_r", "broken"]]):
			notes.append("%s was holding it." % nm)
		else:
			notes.append("%s's helmet saved most of them." % nm)
	for s in living():
		if s != victim:
			teeth[s] += 2


func view_for(_viewers: Array) -> Dictionary:
	var v := base_view()
	# The fuse length is hidden. The ticking (in the view: `urgency`) is not.
	var urgency := clampf(elapsed / fuse, 0.0, 1.0)
	var next_name := ""
	if step_i >= 1 and step_i < n_steps:
		next_name = STEPS[step_i].name
	v.merge({"sub": sub, "sub_t": sub_t, "holder": holder, "flight": flight.duplicate(), "urgency": urgency,
		"step": step_i, "n_steps": n_steps, "next": next_name, "next_hands": STEPS[step_i].hands if step_i >= 0 and step_i < n_steps else 0,
		"last_doer": last_doer, "busy": busy.duplicate()})
	return v


# --- AI ------------------------------------------------------------------------------

func ai(seat: int, brain: AiBrain, view: Dictionary, dt: float) -> void:
	if view.sub != "play" or view.holder != seat or not view.busy.is_empty():
		brain.wait = 0.0
		return
	brain.wait += dt
	var started := int(view.step) >= 1
	if started:
		# Its face is lit and asking for something. Cooperative ones answer.
		if brain.wait < 0.6:
			return
		if view.last_doer != seat and brain.coop >= 0.2 and brain.rng.randf() < 0.9:
			action(seat, {"t": "mg", "do": "step"})
		else:
			var others := living().filter(func(o): return o != seat and o != view.last_doer)
			if others.is_empty():
				others = living().filter(func(o): return o != seat)
			action(seat, {"t": "mg", "do": "pass", "target": others[brain.rng.randi_range(0, others.size() - 1)] if not others.is_empty() else -1})
		brain.wait = 0.0
		return
	if brain.wait < brain.hold_time:
		# the curious ones fiddle
		if brain.rng.randf() < dt * 0.25 * brain.coop * brain.coop:
			action(seat, {"t": "mg", "do": "fiddle"})
			brain.wait = 0.0
		return
	brain.wait = 0.0
	brain.hold_time = brain.rng.randf_range(0.7, 2.6) * (1.3 - brain.nerve * 0.6)
	action(seat, {"t": "mg", "do": "pass", "target": brain.rival(core, seat) if brain.coop < 0.5 else _random_other(seat)})


func buttons_only() -> bool:
	return true
