extends Minigame
## RUSSIAN ROULETTE: the board encounter (a square calls it, in place of that round's game).
## Everyone is taken to a separate table; a gun in the middle, six chambers. On your turn:
## pull the trigger (at yourself), or play something first. Every empty click pays. A
## shot is death (you'll be a ghost). It ends when someone's shot, or it's been round.
##
## It's social: SAY what you think is in the next chamber (true or not); OFFER someone Dead
## Rats to take your turn (they can say no); give a ghost's whisper something to work with.
## And it's crooked: PEEK at the cylinder, SPIN it when nobody's looking, POCKET the round,
## or load a SPARE ROUND you found. He sees what he sees (CheatingManager), and the Cage
## leans on the cylinder for the ones he doesn't like.
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
var offer := {}              # {from, to, rats}
var claims: Dictionary = {}  # seat -> "EMPTY" | "LOADED"


func id() -> String:
	return "roulette"


func title() -> String:
	return "RUSSIAN ROULETTE"


func instructions() -> Array:
	return ["A gun, six chambers, passed round the table.", "On your turn, PULL THE TRIGGER. Or pay someone to.",
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
						notes.append("It went round the table and nobody was shot.")
					sub = "over"
					for s in living():
						rats[s] += 3
					finish(living(), false)
				else:
					_next()


func action(seat: int, a: Dictionary) -> void:
	var what := str(a.get("do", ""))
	# answering an offer, and talking, happen out of turn
	if what in ["accept", "decline"] and not offer.is_empty() and offer.to == seat and sub == "turn":
		if what == "accept":
			var paid := core.economy.take(offer.from, int(offer.rats), "paid for a turn")
			core.p(seat).rats += paid
			core.toast("%s takes %s's turn, for %d Dead Rats." % [core.p(seat).name, core.p(offer.from).name, paid])
			mirror[offer.from] = -100 - seat    # marker: the trigger is pulled by `seat`, at `seat`
			offer = {}
			_pull(current())
		else:
			core.toast("%s won't take it." % core.p(seat).name)
			offer = {}
		return
	if what == "claim":
		claims[seat] = str(a.get("say", "EMPTY"))
		core.toast("%s says: \"%s.\"" % [core.p(seat).name, "It's empty" if claims[seat] == "EMPTY" else "It's loaded"])
		core.emit({"e": "mg", "k": "claim", "seat": seat, "say": claims[seat]})
		return
	if sub != "turn" or seat != current():
		return
	var pl := core.p(seat)
	match what:
		"offer":
			var to := int(a.get("target", -1))
			var n := clampi(int(a.get("rats", 3)), 1, pl.rats)
			if to != seat and living().has(to) and pl.rats > 0:
				offer = {"from": seat, "to": to, "rats": n}
				core.toast("%s offers %s %d Dead Rats to take the next pull." % [pl.name, core.p(to).name, n])
				core.emit({"e": "mg", "k": "offer", "from": seat, "to": to, "rats": n})
			return
		"cheat":
			var cid := str(a.get("id", ""))
			if not core.cheats.available(seat, "roulette").has(cid):
				return
			if core.cheats.attempt(seat, cid):
				match cid:
					"peek_gun":
						peeks[seat] = chambers[idx]
						core.toast("You tilt it to the light: %s" % ("there's a round in the next one." if chambers[idx] else "the next one's empty."), seat)
					"spin_gun":
						var n := loaded
						_spin()
						loaded = n
					"pocket_round":
						if chambers[idx]:
							chambers[idx] = false
							loaded = maxi(0, loaded - 1)
						else:
							for i in CHAMBERS:
								if chambers[i]:
									chambers[i] = false
									loaded = maxi(0, loaded - 1)
									break
						core.give_item(seat, "bullet", "pocketed")
			return
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
				"bullet":
					# load another chamber (contraband: he has to not see it)
					if core.cheats.attempt(seat, "spin_gun", "slip a spare round into the cylinder"):
						for i in CHAMBERS:
							var k := (idx + 1 + i) % CHAMBERS
							if not chambers[k]:
								chambers[k] = true
								loaded += 1
								break
				"bribe":
					var to := int(a.get("target", -1))
					var opts := living().filter(func(o): return o != seat)
					if not opts.has(to):
						to = opts[0] if not opts.is_empty() else -1
					if to >= 0:
						offer = {"from": seat, "to": to, "rats": 5}
						core.p(seat).rats += 5   # the envelope is the money
						core.toast("%s slides an envelope to %s: take my turn." % [pl.name, core.p(to).name])
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
	if target <= -100:
		target = -100 - target       # someone took the turn for money
	if not alive(target):
		target = seat
	offer = {}
	# he leans on the cylinder for the people he doesn't like
	if not chambers[idx] and loaded > 0 and core.cage.tip(target, "roulette"):
		for i in CHAMBERS:
			if chambers[i]:
				chambers[i] = false
				chambers[idx] = true
				break
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
		core.emit({"e": "mg", "k": "shot", "seat": target})
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
		rats[seat] += 1
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
		"loaded": loaded, "pulls": pulls, "laps": laps, "offer": offer.duplicate(), "claims": claims.duplicate(), "lower_streak": lower_streak, "last": last, "peeks": my_peek,
		"aims": mirror.duplicate(), "limit": TURN_LIMIT})
	return view_with_actions(v, viewers)


func actions_for(seat: int) -> Array:
	var out := []
	if not offer.is_empty() and offer.to == seat:
		out.append({"do": "accept", "name": "TAKE THE TURN FOR %d RATS" % int(offer.rats)})
		out.append({"do": "decline", "name": "SAY NO"})
	out.append({"do": "claim", "say": "EMPTY", "name": "SAY: IT'S EMPTY", "small": true})
	out.append({"do": "claim", "say": "LOADED", "name": "SAY: IT'S LOADED", "small": true})
	if sub != "turn" or seat != current():
		return out
	var pl := core.p(seat)
	for it in pl.items:
		if Items.CATALOGUE.get(it, {}).get("use", "") == "roulette":
			out.append({"do": "item", "id": it, "name": Items.name_of(it)})
	for o in living():
		if o != seat and pl.rats > 0 and offer.is_empty():
			out.append({"do": "offer", "target": o, "rats": mini(3, pl.rats), "name": "PAY %s TO PULL (%d)" % [core.p(o).name, mini(3, pl.rats)], "small": true})
	out.append({"do": "lower", "name": "put it down", "small": true})
	out.append({"do": "pull", "name": "PULL THE TRIGGER", "primary": true})
	return out


func cheat_options(seat: int) -> Array:
	if sub != "turn" or seat != current():
		return []
	var out := []
	for cid in core.cheats.available(seat, "roulette"):
		out.append({"id": cid, "name": str(core.cheats.catalogue[cid].name).to_lower(), "direct": true})
	return out


func ghost_secret(_to: int) -> String:
	return "the next chamber is %s." % ("loaded" if chambers[idx] else "empty")


# --- AI ------------------------------------------------------------------------------

func ai(seat: int, brain: AiBrain, view: Dictionary, _dt: float) -> void:
	# somebody wants to pay me to take their turn
	if not offer.is_empty() and offer.to == seat:
		brain.wait += _dt
		if brain.wait > brain.think_time:
			brain.wait = 0.0
			var left := float(CHAMBERS - clicks)
			var risk := float(loaded) / maxf(left, 1.0)
			var yes := brain.greed > 0.55 and risk < 0.3 + brain.nerve * 0.2 and int(offer.rats) >= 3
			action(seat, {"t": "mg", "do": "accept" if yes else "decline"})
		return
	if view.sub != "turn" or view.turn != seat:
		brain.wait = 0.0
		return
	brain.wait += _dt
	if brain.wait < brain.think_time:
		return
	brain.wait = 0.0
	var pl := core.p(seat)
	# cheat when he isn't looking (the bold, the desperate)
	var att: Dictionary = core.suspicion.view()
	if not att.watching and not att.turning and brain.coop < 0.5 and pl.suspicion < 60:
		if not peeks.has(seat) and core.cheats.available(seat, "roulette").has("peek_gun") and brain.rng.randf() < 0.5:
			action(seat, {"t": "mg", "do": "cheat", "id": "peek_gun"})
			return
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
		if pl.rats >= 3 and offer.is_empty() and brain.rng.randf() < 0.5:
			var others := living().filter(func(o): return o != seat)
			if not others.is_empty():
				action(seat, {"t": "mg", "do": "offer", "target": others[brain.rng.randi_range(0, others.size() - 1)], "rats": 3})
				return
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
