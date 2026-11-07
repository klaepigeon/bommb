class_name ChoiceGame
extends Minigame
## The shared table for games of secret choices (PICK YOUR POISON, WRONG ANSWERS ONLY,
## CONFESSION, THE CONSENSUS): a round is CHOOSE (everyone picks, privately, against a
## clock), then REVEAL, then RESOLVE (the subclass decides what it costs). While choosing
## you can CLAIM something out loud (what you picked, what you'll pick, a lie); a cheat can
## PEEK at someone's pick; a ghost can whisper one to someone.

const CHOOSE_TIME := 14.0
const REVEAL_TIME := 3.5

var sub := "choose"           # choose | reveal | over
var sub_t := 0.0
var round_i := 0
var rounds := 3
var choices: Dictionary = {}  # seat -> choice (private until reveal)
var claims: Dictionary = {}   # seat -> what they said they'd do (public; may be a lie)
var peeked: Dictionary = {}   # seat -> {other: choice} (private)
var last_reveal: Dictionary = {}
var prompt := ""              # what this round asks
var options: Array = []       # what can be chosen (strings, or seat numbers)


func start() -> void:
	_begin()


func _begin() -> void:
	sub = "choose"
	sub_t = 0.0
	choices.clear()
	claims.clear()
	begin_round()
	core.emit({"e": "mg", "k": "choose", "round": round_i})


## Subclasses: set prompt and options for this round.
func begin_round() -> void:
	pass


## Subclasses: what the revealed choices do. Return true to end the game now.
func resolve(_revealed: Dictionary) -> bool:
	return false


func choosers() -> Array[int]:
	return living()


func tick(dt: float) -> void:
	t += dt
	sub_t += dt
	match sub:
		"choose":
			var all := true
			for s in choosers():
				if not choices.has(s):
					all = false
			if all or sub_t >= CHOOSE_TIME:
				for s in choosers():
					if not choices.has(s):
						choices[s] = options[rng.randi_range(0, options.size() - 1)] if not options.is_empty() else 0
				_reveal()
		"reveal":
			if sub_t >= REVEAL_TIME:
				round_i += 1
				if done:
					return
				if round_i >= rounds or living().size() < 2:
					conclude()
				else:
					_begin()


func _reveal() -> void:
	sub = "reveal"
	sub_t = 0.0
	last_reveal = choices.duplicate()
	core.emit({"e": "mg", "k": "reveal", "choices": last_reveal.duplicate()})
	if resolve(last_reveal):
		conclude()


## Subclasses: set winners/draw and finish().
func conclude() -> void:
	finish([], true)


func action(seat: int, a: Dictionary) -> void:
	if not seats.has(seat) or not alive(seat) or sub != "choose":
		return
	match str(a.get("do", "")):
		"choose":
			var c = a.get("choice")
			if options.has(c) and can_choose(seat, c):
				choices[seat] = c
				core.emit({"e": "mg", "k": "chosen", "seat": seat})
		"claim":
			claims[seat] = a.get("choice")
			core.emit({"e": "mg", "k": "claim", "seat": seat, "choice": a.get("choice")})
			core.toast("%s says: \"%s\"" % [core.p(seat).name, describe(a.get("choice"))])


func can_choose(_seat: int, _c) -> bool:
	return true


func describe(c) -> String:
	if c is int and c >= 0 and c < core.players.size():
		return core.p(c).name
	return str(c)


func actions_for(seat: int) -> Array:
	if sub != "choose" or not choosers().has(seat):
		return []
	var out := []
	for o in options:
		if can_choose(seat, o):
			out.append({"do": "choose", "choice": o, "name": describe(o), "picked": choices.get(seat) == o})
	for o in options:
		out.append({"do": "claim", "choice": o, "name": "SAY: " + describe(o), "small": true})
	return out


func cheat_options(seat: int) -> Array:
	if sub != "choose":
		return []
	var out := []
	for o in choosers():
		if o != seat and choices.has(o):
			out.append({"id": "peek:%d" % o, "name": "peek at %s's pick" % core.p(o).name})
	return out


func apply_cheat(seat: int, id: String) -> void:
	if id.begins_with("peek:"):
		var o := int(id.substr(5))
		if choices.has(o):
			if not peeked.has(seat):
				peeked[seat] = {}
			peeked[seat][o] = choices[o]
			core.toast("%s picked %s." % [core.p(o).name, describe(choices[o])], seat)


func ghost_secret(to: int) -> String:
	var others := choices.keys().filter(func(o): return o != to)
	if others.is_empty():
		return ""
	var o: int = others[rng.randi_range(0, others.size() - 1)]
	return "%s picked %s." % [core.p(o).name, describe(choices[o])]


func view_for(viewers: Array) -> Dictionary:
	var v := base_view()
	var mine := {}
	var my_peeks := {}
	for s in viewers:
		if choices.has(s):
			mine[s] = choices[s]
		my_peeks.merge(peeked.get(s, {}))
	var opts := []
	for o in options:
		opts.append({"value": o, "name": describe(o)})
	v.merge({"sub": sub, "sub_t": sub_t, "round": round_i, "rounds": rounds, "prompt": prompt, "options": opts,
		"mine": mine, "chosen": choices.keys(), "claims": claims.duplicate(), "peeks": my_peeks,
		"revealed": last_reveal.duplicate() if sub == "reveal" else {}, "limit": CHOOSE_TIME, "choice": true})
	return view_with_actions(v, viewers)


## AI: pick something it believes is good; a social one says what it picked (an honest
## one tells the truth).
func ai(seat: int, brain: AiBrain, view: Dictionary, dt: float) -> void:
	if view.sub != "choose" or choices.has(seat):
		return
	brain.wait += dt
	if brain.wait < brain.think_time * 1.5:
		return
	brain.wait = 0.0
	var c = ai_choice(seat, brain)
	action(seat, {"t": "mg", "do": "choose", "choice": c})
	if brain.rng.randf() < 0.4:
		var said = c if brain.coop >= 0.35 else options[brain.rng.randi_range(0, options.size() - 1)]
		if sub == "choose":
			action(seat, {"t": "mg", "do": "claim", "choice": said})


func ai_choice(seat: int, brain: AiBrain):
	var ok := options.filter(func(o): return can_choose(seat, o))
	return ok[brain.rng.randi_range(0, ok.size() - 1)] if not ok.is_empty() else options[0]


func buttons_only() -> bool:
	return true
