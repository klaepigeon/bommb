class_name ItemManager
extends RefCounted
## What every item does (the catalogue is Items / assets/data/items.json). Board items are
## used before you roll (BoardRules sends them here); passive ones work by themselves while
## you carry them (consume_passive, called by whatever they protect against); ghost items
## on a ghost's turn; roulette items in the roulette encounter; room items in the facility.
## Returns whether the item was used up. Every use is an event for the views and a stat.

var core: MatchCore


func _init(c: MatchCore) -> void:
	core = c


## Can `seat` use `id` on the board right now (and on whom)?
func can_use(seat: int, id: String) -> bool:
	var p := core.p(seat)
	if not p.items.has(id):
		return false
	var u := Items.use_of(id)
	if p.ghost:
		return u == "ghost"
	if u != "board":
		return false
	if core.rulebook.value("items_banned", false, seat):
		return false
	return true


func targets_for(seat: int, id: String) -> Array:
	match Items.target_of(id):
		"player":
			return core.living().filter(func(o): return o != seat)
		"ghost":
			return core.ghosts()
	return []


func use(seat: int, id: String, target := -1, choice := "") -> bool:
	if not can_use(seat, id):
		if core.p(seat).items.has(id) and core.rulebook.value("items_banned", false, seat):
			core.toast("PROHIBITION is in force: no items.", seat)
		return false
	var p := core.p(seat)
	var tgt := Items.target_of(id)
	if tgt == "player":
		var ts := targets_for(seat, id)
		if ts.is_empty():
			core.toast("There's nobody to use that on.", seat)
			return false
		if not ts.has(target):
			target = ts[0]
	var used := true
	var nm := p.name
	match id:
		"loaded_dice":
			p.next_roll = "high" if choice.to_upper() != "LOW" else "low"
		"high_roller":
			p.next_roll = "d10"
		"double_roll":
			p.next_roll = "double"
		"loaded_double":
			p.next_roll = "loaded_double"
		"greased_shoes":
			p.move_bonus += 3
		"reverse_gear":
			p.reverse = true
		"warp_tooth":
			core.rules.swap_places(seat, target)
			_hit(seat, target)
		"pickpocket":
			var k := core.economy.transfer(target, seat, 6, "pickpocket")
			p.stat("steals")
			_hit(seat, target)
			core.toast("%s lifts %d Teeth off %s." % [nm, k, core.p(target).name])
		"rat_trap":
			core.traps[p.space] = seat
			core.emit({"e": "trap_set", "seat": seat, "space": p.space})
		"poisoned_gift":
			var t := core.p(target)
			if t.items.size() >= Items.MAX_HELD:
				core.toast("%s's hands are full. Keep it for later." % t.name, seat)
				return false
			t.items.append("gift")
			t.stat("gifts_received")
			core.emit({"e": "give", "seat": seat, "to": target, "item": "gift"})
			core.toast("%s gives %s a lovely little box." % [nm, t.name])
			p.stat("items_on_others")
		"tooth_tax":
			var k := core.economy.take(target, 5, "tooth tax")
			core.economy.house_pile += k
			_hit(seat, target)
			core.toast("%s pays %d Teeth in tax. %s filed the paperwork." % [core.p(target).name, k, nm])
		"sabotage_kit":
			core.p(target).handicap = true
			_hit(seat, target)
			core.toast("Somebody has been at %s's equipment." % core.p(target).name)
		"debt_collector":
			var got := 0
			for o in core.players:
				if o.seat != seat and o.debts.has(seat):
					got += core.economy.settle(o.seat, seat, 1.5)
			if got == 0:
				core.toast("Nobody owes you anything.", seat)
				used = false
			else:
				core.toast("%s collects %d Teeth in debts." % [nm, got])
		"body_armour":
			p.armour += 3
		"antidote":
			if core.status.cure_all(seat) == 0:
				core.toast("You're not poisoned. (That you know of.)", seat)
				used = false
		"helmet":
			if p.helmet:
				core.toast("You're already wearing one.", seat)
				used = false
			else:
				p.helmet = true
		"counterfeit_teeth":
			core.economy.award(seat, 12, "counterfeit", false)
			p.counterfeit += 12
		"loaded_wallet":
			core.economy.award(seat, 8, "wallet", false)
		"gift_basket":
			var k := core.economy.transfer(seat, target, 5, "gift")
			var extra := Items.roll(core.rng, "common")
			if core.p(target).items.size() < Items.MAX_HELD:
				core.p(target).items.append(extra)
			p.stat("gifts_given")
			p.stat("teeth_given", k)
			core.p(target).stat("gifts_received")
			for o in core.living():
				core.brains[o].saw_kindness(seat, 0.2)
			core.toast("%s gives %s a gift basket: %d Teeth and a %s." % [nm, core.p(target).name, k, Items.name_of(extra).to_lower()])
		"debt_note":
			if p.teeth < 6:
				core.toast("You need 6 Teeth to lend.", seat)
				return false
			core.economy.transfer(seat, target, 6, "loan")
			core.economy.add_debt(target, seat, 10)
			core.toast("%s lends %s 6 Teeth. %s owes 10." % [nm, core.p(target).name, core.p(target).name])
		"black_market_coupon":
			p.items.erase(id)
			core.emit({"e": "use", "seat": seat, "item": id})
			core.rules.open_shop(seat, "black_market", true)
			return true
		"first_aid":
			var n := Body.heal_temporary(p.body)
			var bone := Body.set_bone(p.body)
			if n == 0 and bone == "":
				core.toast("Nothing for the first aid tin to fix.", seat)
				used = false
		"bandage":
			var n := 0
			for part in Body.PARTS:
				if p.body[part].s == "bruised":
					p.body[part].s = "ok"
					n += 1
			if n == 0:
				core.toast("No bruises to bandage.", seat)
				used = false
		"painkillers":
			p.painkillers = 3
		"prosthetic":
			if Body.fit_prosthetic(p.body) == "":
				core.toast("You haven't lost anything to replace. Yet.", seat)
				used = false
		"surgery":
			var n := 0
			for part in Body.PARTS:
				if p.body[part].s == "broken":
					p.body[part].s = "ok"
					n += 1
			if core.status.has(seat, "necrosis"):
				core.status.cure(seat, "necrosis")
				n += 1
			if n == 0:
				core.toast("Nothing to operate on.", seat)
				used = false
		"alibi":
			core.suspicion.add(seat, -20, "alibi")
		"lucky_foot":
			if p.cage <= 0:
				core.toast("Your Cage is as open as it gets.", seat)
				used = false
			else:
				core.cage.loosen(seat, "rabbit's foot")
		"loaded_die":
			p.items.erase(id)
			if core.cheats.attempt(seat, "load_dice", "swap in a loaded die"):
				p.next_roll = "six"
			return true
		"gavel":
			p.items.erase(id)
			core.emit({"e": "use", "seat": seat, "item": id})
			core.rules.open_rule_prompt(seat, "gavel")
			return true
		"executive_privilege":
			if core.rulebook.active.is_empty():
				core.toast("There's nothing in the rulebook to strike.", seat)
				return false
			p.items.erase(id)
			core.emit({"e": "use", "seat": seat, "item": id})
			core.rules.open_rule_prompt(seat, "veto")
			return true
		"loophole":
			p.loophole = 3
		"rubber_stamp":
			if core.rulebook.active.is_empty():
				used = false
			core.rulebook.extend(3)
		"emergency_legislation":
			if core.rulebook.repeal_temporary() == 0:
				core.toast("No temporary amendments to repeal.", seat)
				used = false
		"gift":
			p.items.erase(id)
			core.status.apply(seat, core.status.random_poison(seat), "a poisoned gift")
			core.toast("%s opens the gift. Something inside bites." % nm)
			core.emit({"e": "use", "seat": seat, "item": id})
			return true
		# ghosts
		"cold_hand":
			core.p(target).cold_hand = true
			core.toast("A cold hand closes on %s's wrist." % core.p(target).name)
		"phantom_coin":
			if choice.to_upper() == "CURSE":
				var lead := core.leader()
				if lead >= 0:
					core.p(lead).event_shift -= 2
			else:
				var last := core.trailer()
				if last >= 0:
					core.p(last).event_shift += 2
			core.toast("A coin spins on the table by itself.")
		"possession_ticket":
			core.move_rat(-1)
			core.toast("%s's ghost gets into the machinery. The Dead Rat moves." % nm)
		_:
			used = false
	if used:
		p.items.erase(id)
		p.stat("items_used")
		core.emit({"e": "use", "seat": seat, "item": id, "target": target})
		core.say("use_item", {"name": nm, "item": Items.name_of(id)})
	return used


func _hit(seat: int, target: int) -> void:
	core.p(seat).stat("items_on_others")
	if target >= 0:
		core.p(target).stat("victimised")
		core.brains[target].wronged_by(seat, 0.1)


## A carried item that works by itself: is it there? (Then it's used up.)
func consume_passive(seat: int, id: String, why := "") -> bool:
	var p := core.p(seat)
	if not p.items.has(id):
		return false
	p.items.erase(id)
	core.emit({"e": "passive", "seat": seat, "item": id, "why": why})
	core.toast("%s's %s saves them from %s." % [p.name, Items.name_of(id).to_lower(), why] if why != "" else "%s uses up their %s." % [p.name, Items.name_of(id).to_lower()])
	return true


func claim_insurance(seat: int, why: String) -> void:
	var p := core.p(seat)
	if p.items.has("insurance"):
		p.items.erase("insurance")
		p.teeth += 10
		core.emit({"e": "teeth", "seat": seat, "delta": 10, "why": "insurance"})
		core.toast("%s's insurance pays out 10 Teeth (%s)." % [p.name, why])


## At death: the estate.
func on_death(seat: int) -> void:
	var p := core.p(seat)
	claim_insurance(seat, "death")
	if p.items.has("last_will"):
		p.items.erase("last_will")
		var poor := core.trailer(true)
		if poor >= 0 and poor != seat:
			core.economy.award(poor, maxi(1, p.teeth / 2), "the will", false)
		core.toast("%s's will is read. Their Teeth go into the grave with them." % p.name)
	else:
		# without a will, the house takes half
		var k := p.teeth / 2
		p.teeth -= k
		core.economy.house_pile += k


## Start of each round: plaster Teeth get found out.
func round_tick() -> void:
	for p in core.players:
		if p.counterfeit > 0 and core.rng.randf() < 0.3:
			core.economy.take(p.seat, 15, "counterfeit")
			core.suspicion.add(p.seat, 10, "counterfeit teeth")
			core.toast("He bites one of %s's Teeth. It's plaster." % p.name)
			p.counterfeit = 0
		if p.loophole > 0:
			pass
