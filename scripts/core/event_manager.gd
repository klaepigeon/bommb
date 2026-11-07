class_name EventManager
extends RefCounted
## Random events on an outcome spectrum, miracle to catastrophe (assets/data/events.json).
## The tier is rolled for the player it happens to, and who they are moves the odds: the
## Cage and suspicion drag it down, being last in Dead Rats lifts it (a way back), leading
## drags it down a little, late in the match it swings harder, a ghost's phantom coin tips
## it. It's never decided: a caged player can still get a miracle. A Lucky Tooth turns a
## bad result neutral. Everything that happened is in `history` (and the save).

var core: MatchCore
var tiers: Array = []
var weights: Array = []
var events: Dictionary = {}
var history: Array = []        # [{round, seat, tier, id}]


func _init(c: MatchCore) -> void:
	core = c
	var d := Assets.load_json("res://assets/data/events.json")
	tiers = d.get("tiers", [])
	weights = d.get("weights", [])
	events = d.get("events", {})


## The tier index (0 miracle .. 6 catastrophe) for this player now.
func roll_tier(seat: int) -> int:
	var p := core.p(seat)
	var w: Array = []
	for x in weights:
		w.append(float(x))
	var shift := 0.0     # + toward the good end
	shift -= p.cage * 0.35
	shift -= p.suspicion / 60.0
	var rank := core.rank_of(seat)
	var n := core.players.size()
	if rank == n - 1 and n > 1:
		shift += 1.0
	elif rank == 0 and p.rats > 0:
		shift -= 0.5
	# repeated bad luck earns a little sympathy
	var recent_bad := 0
	for h in history.slice(maxi(0, history.size() - 6)):
		if int(h.seat) == seat and int(h.tier) >= 4:
			recent_bad += 1
	shift += recent_bad * 0.3
	shift += p.event_shift
	p.event_shift = 0
	var progress := float(core.round_n) / float(maxi(1, core.max_rounds))
	for i in w.size():
		var good := 3.0 - i          # +3 miracle .. -3 catastrophe
		w[i] = maxf(0.2, w[i] * exp(good * shift * 0.35))
		if i == 0 or i == w.size() - 1:
			w[i] *= 1.0 + progress
	if core.cage.tip(seat, "board_event"):
		for i in range(4, w.size()):
			w[i] *= 1.6
	var total := 0.0
	for x in w:
		total += x
	var r := core.rng.randf() * total
	for i in w.size():
		r -= w[i]
		if r <= 0.0:
			return i
	return 3


## Something happens to `seat`. Returns the event (with its tier).
func trigger(seat: int, forced_tier := -1) -> Dictionary:
	var p := core.p(seat)
	var ti := forced_tier if forced_tier >= 0 else roll_tier(seat)
	if ti >= 4 and core.items.consume_passive(seat, "lucky_tooth", "the event"):
		ti = 3
	var lst: Array = events.get(tiers[ti], [])
	var ev: Dictionary = lst[core.rng.randi_range(0, lst.size() - 1)].duplicate()
	ev.tier = tiers[ti]
	history.append({"round": core.round_n, "seat": seat, "tier": ti, "id": ev.id})
	p.stat("events_good" if ti <= 2 else ("events_bad" if ti >= 4 else "events_neutral"))
	core.emit({"e": "event", "seat": seat, "id": ev.id, "name": ev.name, "tier": ev.tier})
	core.say("event_" + str(ev.tier), {"name": p.name, "event": str(ev.name)})
	core.toast("%s — %s" % [ev.name, str(ev.get("text", "%s")).replace("%s", p.name)])
	_apply(seat, ev)
	return ev


func _apply(seat: int, ev: Dictionary) -> void:
	var p := core.p(seat)
	var n := int(ev.get("n", 0))
	match str(ev.do):
		"teeth":
			if n > 0:
				core.economy.award(seat, n, "event", false)
			else:
				core.economy.take(seat, -n, "event")
		"teeth_all":
			for s in core.living():
				core.economy.award(s, n, "event", false)
		"teeth_half":
			core.economy.take(seat, p.teeth / 2, "event")
		"rats":
			core.change_rats(seat, n, "event")
		"heal_all":
			for part in Body.PARTS:
				if p.body[part].s in ["bruised", "burned", "broken"]:
					p.body[part].s = "ok"
			core.status.cure_all(seat)
			core.emit({"e": "heal", "seat": seat})
		"resurrect":
			var gs := core.ghosts()
			if gs.is_empty():
				core.economy.award(seat, 5, "event")
			else:
				core.resurrection.revive(gs[core.rng.randi_range(0, gs.size() - 1)], "event")
		"rat_near":
			core.move_rat(core.graph.ahead(p.space, 1))
		"rat_move":
			core.move_rat(-1)
		"item":
			var pool := str(ev.get("pool", "any"))
			core.give_item(seat, Items.roll(core.rng, pool), "event")
		"protect":
			p.armour = maxi(p.armour, 1)
			core.emit({"e": "protect", "seat": seat})
		"move":
			core.rules.slide(seat, n)
		"swap":
			var others := core.living().filter(func(o): return o != seat)
			if not others.is_empty():
				core.rules.swap_places(seat, others[core.rng.randi_range(0, others.size() - 1)])
		"trade":
			var others := core.living().filter(func(o): return o != seat and not core.p(o).items.is_empty())
			if not others.is_empty() and not p.items.is_empty():
				var o: int = others[core.rng.randi_range(0, others.size() - 1)]
				var a: String = p.items.pop_at(core.rng.randi_range(0, p.items.size() - 1))
				var b: String = core.p(o).items.pop_at(core.rng.randi_range(0, core.p(o).items.size() - 1))
				p.items.append(b)
				core.p(o).items.append(a)
				core.emit({"e": "trade", "a": seat, "b": o})
				core.toast("%s gets %s; %s gets %s." % [p.name, Items.name_of(b), core.p(o).name, Items.name_of(a)])
			else:
				core.economy.award(seat, 3, "event")
		"lose_item":
			if not p.items.is_empty():
				var it: String = p.items.pop_at(core.rng.randi_range(0, p.items.size() - 1))
				core.emit({"e": "item_lost", "seat": seat, "item": it})
				core.items.claim_insurance(seat, "lost an item")
			else:
				core.economy.take(seat, 3, "event")
		"gamble":
			core.rules.offer_gamble(seat)
		"caller":
			core.rules.caller_choice(seat)
		"bonus_game":
			core.queue_minigame("bonus", core.living())
		"surgery":
			core.call_special("organ_trail", -1)
		"alter":
			core.alter_space(seat)
		"injury":
			var part := Body.random_severable(p.body, core.rng)
			if part != "":
				core.hurt(seat, part, str(ev.get("status", "bruised")), "event")
		"poison":
			core.status.apply(seat, core.status.random_poison(seat), "event")
		"punish":
			core.rules.punish(seat)
		"lose_part":
			var part := Body.random_severable(p.body, core.rng)
			if part != "":
				core.hurt(seat, part, "lost", "the butcher")


func to_save() -> Array:
	return history.duplicate(true)


func load_save(d: Array) -> void:
	history = d.duplicate(true)
