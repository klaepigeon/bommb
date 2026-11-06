extends Minigame
## MINIGAME 02: POPPER ROULETTE. The Lucky Popper is a brass party cracker the size of a
## biscuit tin, with six chambers on a drum and a pull-string. Some chambers hold the Big
## Pop. Pass it round the table: on your turn pull the string (it goes off at you), or play
## an item first. Every empty click pays a ticket. It ends when it goes off.
##
## The probability state lives here, on the host, with its own seeded RNG. Everyone can
## see how many chambers have clicked since the last spin; only a Peeker shows what's next.
##
## (Not on the card: you can also put it down. If everyone at the table puts it down, one
## after another, nobody pulls, and the game doesn't know what to do with itself.)

const CHAMBERS := 6
const TURN_LIMIT := 15.0
const MAX_PULLS := 14
var laps := 1                  # it goes round the table this many times, then it's over

var order: Array[int] = []
var cur := 0
var chambers: Array[bool] = []
var idx := 0
var loaded := 1
var clicks := 0            # since the last spin (public)
var pulls := 0
var lower_streak := 0
var mirror: Dictionary = {}    # seat -> target for their next pull
var peeks: Dictionary = {}     # seat -> bool (private: is the next chamber loaded)
var sub := "turn"          # turn | resolve | over
var sub_t := 0.0
var last := {}
var voided := false


func id() -> String:
	return "roulette"


func title() -> String:
	return "POPPER ROULETTE"


func instructions() -> Array:
	return ["Pass the Lucky Popper round the table.", "On your turn, PULL the string. It goes off at you.",
		"An empty click pays a ticket. Once round the table and it's over.", "Items: SPINNER, PEEKER, SKIP CARD, HAND MIRROR."]


func setup() -> void:
	order = seats.duplicate()
	loaded = 1 + mini(level, 1)
	laps = 1 + mini(level, 1)
	_spin()
	cur = rng.randi_range(0, order.size() - 1)


func start() -> void:
	sub = "turn"
	sub_t = 0.0
	_announce()


func _spin() -> void:
	chambers.clear()
	for i in CHAMBERS:
		chambers.append(false)
	var placed := 0
	while placed < loaded:
		var i := rng.randi_range(0, CHAMBERS - 1)
		if not chambers[i]:
			chambers[i] = true
			placed += 1
	idx = rng.randi_range(0, CHAMBERS - 1)
	clicks = 0
	peeks.clear()


func current() -> int:
	return order[cur]


func _announce() -> void:
	core.emit({"e": "mg", "k": "turn", "seat": current()})
	core.say("pr_turn", {"name": core.p(current()).name})


func _next() -> void:
	for k in order.size():
		cur = (cur + 1) % order.size()
		if alive(order[cur]):
			break
	sub = "turn"
	sub_t = 0.0
	_announce()


func tick(dt: float) -> void:
	t += dt
	sub_t += dt
	match sub:
		"turn":
			if not alive(current()):
				_next()
			elif not core.is_ai(current()) and sub_t > core._wait(TURN_LIMIT):
				core.toast("The Caller helps %s pull." % core.p(current()).name)
				action(current(), {"t": "mg", "do": "pull"})
		"resolve":
			if sub_t > 2.2:
				var lap_over := pulls >= laps * living().size()
				if last.get("bang", false) and not last.get("helmet", false) or voided or lap_over or pulls >= MAX_PULLS or living().size() <= 1:
					if lap_over and not last.get("bang", false):
						notes.append("It went round the table and nobody popped.")
					sub = "over"
					done = true
				else:
					_next()


func action(seat: int, a: Dictionary) -> void:
	if sub != "turn" or seat != current():
		return
	var pl := core.p(seat)
	match str(a.get("do", "")):
		"pull":
			_pull(seat)
		"lower":
			lower_streak += 1
			core.emit({"e": "mg", "k": "lower", "seat": seat, "streak": lower_streak})
			core.say("pr_lower", {"name": pl.name})
			for o in living():
				core.brains[o].saw_kindness(seat, 0.12)
			if lower_streak >= living().size():
				_void()
			else:
				_resolve({"seat": seat, "lowered": true})
		"item":
			var item := str(a.get("id", ""))
			if not pl.items.has(item) or Items.CATALOGUE.get(item, {}).get("use", "") != "roulette":
				return
			pl.items.erase(item)
			core.emit({"e": "use", "seat": seat, "item": item})
			match item:
				"spinner":
					_spin()
					core.say("pr_spin")
					core.emit({"e": "mg", "k": "spin"})
				"peeker":
					peeks[seat] = chambers[idx]
					core.toast("You squint into the next chamber: %s" % ("THE BIG POP is in there." if chambers[idx] else "empty."), seat)
					core.say("pr_peek", {"name": pl.name})
				"skip":
					core.say("pr_skip", {"name": pl.name})
					lower_streak = 0
					_resolve({"seat": seat, "skipped": true})
				"mirror":
					var target := int(a.get("target", -1))
					var opts := living().filter(func(o): return o != seat)
					if not opts.has(target):
						target = opts[rng.randi_range(0, opts.size() - 1)] if not opts.is_empty() else seat
					mirror[seat] = target
					core.say("pr_mirror", {"name": pl.name, "target": core.p(target).name})
					core.emit({"e": "mg", "k": "aim", "seat": seat, "target": target})
					core.brains[target].wronged_by(seat, 0.3)


func _pull(seat: int) -> void:
	var target: int = mirror.get(seat, seat)
	mirror.erase(seat)
	if not alive(target):
		target = seat
	var bang := chambers[idx]
	chambers[idx] = false
	idx = (idx + 1) % CHAMBERS
	clicks += 1
	pulls += 1
	lower_streak = 0
	peeks.clear()
	var r := {"seat": seat, "target": target, "bang": bang}
	if bang:
		var helmet := core.p(target).helmet
		if core.kill(target, "pop", [["eye_l", "lost"], ["ears", "broken"]]):
			core.say("pr_bang", {"name": core.p(target).name})
			notes.append("%s popped." % core.p(target).name)
		else:
			r.helmet = helmet
			core.say("pr_helmet", {"name": core.p(target).name})
			notes.append("%s's helmet took the pop." % core.p(target).name)
			loaded = maxi(0, loaded - 1)
			if loaded == 0:
				loaded = 1
				_spin()
	else:
		tickets[seat] += 1
		core.say("pr_click")
	core.emit({"e": "mg", "k": "pull", "seat": seat, "target": target, "bang": bang})
	_resolve(r)


func _void() -> void:
	voided = true
	core.emit({"e": "mg", "k": "void"})
	core.say("pr_void")
	notes.append("Nobody picked it up.")
	for s in living():
		core.injure(s, "hand_r", "burned", "discipline")
	core.add_unrest("roulette_void", 1.0)
	_resolve({"void": true})


func _resolve(r: Dictionary) -> void:
	last = r
	sub = "resolve"
	sub_t = 0.0


func view_for(viewers: Array) -> Dictionary:
	var v := base_view()
	var my_peek := {}
	for s in viewers:
		if peeks.has(s):
			my_peek[s] = peeks[s]
	v.merge({"sub": sub, "sub_t": sub_t, "turn": current(), "order": order, "clicks": clicks, "chambers": CHAMBERS,
		"loaded": loaded, "pulls": pulls, "laps": laps, "lower_streak": lower_streak, "last": last, "peeks": my_peek,
		"aims": mirror.duplicate(), "limit": TURN_LIMIT})
	return v


# --- AI ------------------------------------------------------------------------------

func ai(seat: int, brain: AiBrain, view: Dictionary, _dt: float) -> void:
	if view.sub != "turn" or view.turn != seat:
		brain.wait = 0.0
		return
	brain.wait += _dt
	if brain.wait < brain.think_time:
		return
	brain.wait = 0.0
	var pl := core.p(seat)
	var left := float(view.chambers - view.clicks)
	var risk := clampf(float(view.loaded) / maxf(left, 1.0), 0.0, 1.0)
	var peek: Variant = view.peeks.get(seat, null)
	if peek == null and pl.items.has("peeker"):
		action(seat, {"t": "mg", "do": "item", "id": "peeker"})
		return
	if peek == true:
		risk = 1.0
	elif peek == false:
		risk = 0.0
	# put it down? if others already have, or if this one is that way inclined
	var streak := int(view.lower_streak)
	if brain.coop >= 0.75 or (streak > 0 and brain.coop >= 0.4) or (streak > 0 and streak >= living().size() - 1 and brain.coop >= 0.25):
		action(seat, {"t": "mg", "do": "lower"})
		return
	if risk >= 0.5:
		if pl.items.has("mirror") and brain.coop < 0.5:
			action(seat, {"t": "mg", "do": "item", "id": "mirror", "target": brain.rival(core, seat)})
			return
		if pl.items.has("skip"):
			action(seat, {"t": "mg", "do": "item", "id": "skip"})
			return
		if pl.items.has("spinner"):
			action(seat, {"t": "mg", "do": "item", "id": "spinner"})
			return
	elif risk >= 0.34 and pl.items.has("spinner") and brain.nerve < 0.6:
		action(seat, {"t": "mg", "do": "item", "id": "spinner"})
		return
	action(seat, {"t": "mg", "do": "pull"})
