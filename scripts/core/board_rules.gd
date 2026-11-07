class_name BoardRules
extends RefCounted
## The board half of a round: everyone alive takes a turn (use or give items, share what
## you know, roll, walk, land), then MatchCore runs a minigame. Spaces are data
## (assets/data/board.json); what each type does is _land() below.

const STEP_TIME := 0.32
const AFTER_TIME := 1.8
const PROMPT_LIMIT := 20.0
const LIMBS := ["hand_l", "hand_r", "arm_l", "arm_r", "leg_l", "leg_r"]

var core: MatchCore
var order: Array[int] = []
var idx := 0
var sub := "idle"      # pre | moving | prompt | after | room | ghost | idle
var sub_t := 0.0
var roll := 0
var steps := 0
var prompt := {}


func _init(c: MatchCore) -> void:
	core = c


func begin_round() -> void:
	order = core.living()
	if order.is_empty():
		return
	var shift := (core.round_n - 1) % order.size()
	order = order.slice(shift) + order.slice(0, shift)
	# the dead take their turns after the living
	order.append_array(core.ghosts())
	idx = 0
	_start_turn()


func current() -> int:
	return order[idx] if sub != "idle" and idx < order.size() else -1


func _start_turn() -> void:
	while idx < order.size() and not (core.p(order[idx]).alive or core.p(order[idx]).ghost):
		idx += 1
	if idx >= order.size():
		sub = "idle"
		core.board_round_done()
		return
	sub_t = 0.0
	roll = 0
	steps = 0
	prompt = {}
	var s := order[idx]
	var pl := core.p(s)
	if pl.ghost:
		sub = "ghost"
		core.emit({"e": "turn", "seat": s, "ghost": true})
		core.say("ghost_turn", {"name": pl.name})
		return
	sub = "pre"
	core.emit({"e": "turn", "seat": s})
	core.say("turn", {"name": pl.name})
	core.status.tick_turn(s)


func next_turn() -> void:
	idx += 1
	_start_turn()


func tick(dt: float) -> void:
	sub_t += dt
	var s := current()
	match sub:
		"pre":
			if not core.is_ai(s) and sub_t > core._wait(MatchCore.HUMAN_TURN_LIMIT):
				core.toast("%s took too long. The Caller rolls for them." % core.p(s).name)
				action(s, {"t": "roll"})
		"room":
			if not core.is_ai(s) and sub_t > core._wait(MatchCore.HUMAN_TURN_LIMIT):
				core.room.sit(s, true)
		"ghost":
			if not core.is_ai(s) and sub_t > core._wait(MatchCore.HUMAN_TURN_LIMIT):
				action(s, {"t": "ghost", "do": "scavenge"})
		"moving":
			if sub_t >= core._wait(STEP_TIME):
				sub_t = 0.0
				_step()
		"prompt":
			if not core.is_ai(s) and sub_t > core._wait(PROMPT_LIMIT):
				if prompt.kind == "door_stop":
					action(s, {"t": "answer", "yes": false})
				elif prompt.kind in ["shop", "gamble", "hidden"]:
					action(s, {"t": "answer", "done": true})
				else:
					action(s, {"t": "answer", "target": prompt.options[0]})
		"after":
			if sub_t >= core._wait(AFTER_TIME):
				next_turn()


func action(seat: int, a: Dictionary) -> void:
	if seat != current():
		return
	var pl := core.p(seat)
	var t := str(a.get("t", ""))
	match sub:
		"ghost":
			_ghost_action(seat, a)
		"room":
			match t:
				"go":
					core.room.go(seat, str(a.get("where", "")))
				"room_act":
					core.room.act(seat, str(a.get("id", "")), int(a.get("target", -1)))
				"sit":
					core.room.sit(seat, false)
		"pre":
			match t:
				"roll":
					var dmax := Body.dice_max(pl.body, pl.pk())
					var mod := core.status.dice_mod(seat)
					dmax = clampi(dmax + int(mod[0]), 1, 9)
					roll = core.cage.roll(seat, dmax)
					if pl.roll_bonus >= 100:
						roll = dmax                      # a loaded die
					elif pl.roll_bonus != 0:
						roll = maxi(0, roll + pl.roll_bonus)
					pl.roll_bonus = 0
					if mod[1]:
						roll = 0
						core.toast("%s can't make their legs move (paralytic)." % pl.name)
					steps = roll
					pl.at_door = false
					core.emit({"e": "roll", "seat": seat, "n": roll, "max": dmax})
					core.say("roll", {"n": roll})
					if roll <= 0:
						_after()
						return
					sub = "moving"
					sub_t = -0.8   # let the dice land
				"leave":
					core.room.leave(seat)
					sub = "room"
					sub_t = 0.0
				"cheat":
					_board_cheat(seat, str(a.get("id", "")), int(a.get("target", -1)))
				"item":
					use_item(seat, str(a.get("id", "")))
				"give":
					_give(seat, str(a.get("id", "")), int(a.get("target", -1)))
				"share":
					_share(seat)
				"stay":
					if pl.at_door:
						core.toast("%s waits by the door." % pl.name)
						core.emit({"e": "stay", "seat": seat})
						_after()
				"try_door":
					if pl.at_door:
						core.try_door(seat)
						if core.phase == "door":
							sub = "idle"
		"prompt":
			if t != "answer":
				return
			if prompt.kind == "door_stop":
				if a.get("yes", false):
					steps = 0
					pl.at_door = true
					core.emit({"e": "door_stop", "seat": seat})
					core.say("door_stop", {"name": pl.name})
					_check_gather()
					_after()
				else:
					core.say("door_pass", {"name": pl.name})
					sub = "moving"
					sub_t = 0.0
			elif prompt.kind == "steal":
				var target := int(a.get("target", -1))
				if not prompt.options.has(target):
					target = prompt.options[0]
				_steal(seat, target)
				_after()
			elif prompt.kind == "shop":
				if a.has("buy"):
					core.economy.buy(seat, str(a.buy), str(prompt.shop))
				if a.get("done", false):
					_after()
			elif prompt.kind == "gamble":
				var w := int(a.get("wager", 0))
				if w > 0 and pl.rats > 0:
					core.economy.gamble(seat, w)
				_after()
			elif prompt.kind == "hidden":
				if a.get("yes", false):
					_hidden(seat)
				_after()


func _after() -> void:
	sub = "after"
	sub_t = 0.0
	prompt = {}


func _step() -> void:
	var s := current()
	var pl := core.p(s)
	pl.space = (pl.space + 1) % core.board.size()
	steps -= 1
	core.emit({"e": "move", "seat": s, "space": pl.space})
	var sp: Dictionary = core.board[pl.space]
	if core.key_space == pl.space:
		core.key_space = -1
		pl.has_key = true
		core.emit({"e": "key", "seat": s})
		core.toast("%s picks up a small brass winding key." % pl.name)
	# Walking past the wallpaper, a sharp eye catches what's under it.
	if sp.type == "clue" and steps > 0 and not pl.clues.has(int(sp.get("clue", 0))):
		if core.rng.randf() < 0.5 * Body.sight(pl.body):
			var ci := int(sp.get("clue", 0))
			pl.clues[ci] = core.code[ci]
			core.toast("Walking past, you notice: %s The number is %d." % [str(sp.get("text", "")), core.code[ci]], s)
			core.emit({"e": "clue", "seat": s, "index": ci})
	if sp.type == "start" and steps > 0:
		core.economy.award(s, 2, "payday")
		core.say("pass_start", {"name": pl.name})
	if steps <= 0:
		_land()
	elif sp.type == "door":
		sub = "prompt"
		sub_t = 0.0
		prompt = {"kind": "door_stop", "seat": s, "options": [true, false]}
		core.emit({"e": "prompt", "seat": s, "kind": "door_stop"})


func _land() -> void:
	var s := current()
	var pl := core.p(s)
	var sp: Dictionary = core.board[pl.space]
	var name := pl.name
	core.emit({"e": "land", "seat": s, "space": pl.space, "type": sp.type})
	var kind := str(sp.type)
	# his thumb on the board: a good square goes bad
	if kind in ["rats", "item", "medic", "gamble", "hidden"] and core.cage.tip(s, "board_event"):
		core.say("cage_board", {"name": name})
		kind = "punish"
	match kind:
		"start":
			core.economy.award(s, 2, "start")
			core.say("pass_start", {"name": name})
		"rats":
			var n := core.economy.award(s, 3 + core.round_n / 3, "square")
			core.say("space_rats", {"name": name, "n": n})
		"item":
			var id := Items.roll(core.rng, "any", core.cage.tip(s, "items"))
			if core.give_item(s, id):
				core.say("space_item", {"name": name, "item": Items.name_of(id)})
		"roulette":
			core.pending_encounter = "roulette"
			core.say("space_roulette", {"name": name})
			core.emit({"e": "encounter", "id": "roulette"})
		"resurrect":
			core.say("space_resurrect", {"name": name})
			core.resurrection.square(s)
		"black_market":
			core.say("space_black_market", {"name": name})
			_shop_prompt(s, "black_market")
			return
		"poison":
			core.say("space_poison", {"name": name})
			core.status.apply(s, core.status.random_poison(s), "the poison square")
		"gamble":
			if pl.rats > 0:
				core.say("space_gamble", {"name": name})
				sub = "prompt"
				sub_t = 0.0
				prompt = {"kind": "gamble", "seat": s, "options": [1, 3, 5]}
				core.emit({"e": "prompt", "seat": s, "kind": "gamble"})
				return
		"punish":
			_punish(s)
		"hidden":
			sub = "prompt"
			sub_t = 0.0
			prompt = {"kind": "hidden", "seat": s, "options": [true, false]}
			core.emit({"e": "prompt", "seat": s, "kind": "hidden"})
			return
		"hazard":
			var part: String = LIMBS[core.rng.randi_range(0, LIMBS.size() - 1)]
			var status := "bruised" if core.round_n < 4 else ("burned" if core.round_n < 7 else "broken")
			core.say("space_hazard", {"name": name, "target": Body.LABEL[part].to_lower() + " " + status})
			core.injure(s, part, status, "party favour")
		"note":
			core.toast(str(sp.get("text", "")))
			core.say("space_note", {"name": name})
		"clue":
			var i := int(sp.get("clue", 0))
			pl.clues[i] = core.code[i]
			core.toast("%s The number is %d." % [str(sp.get("text", "")), core.code[i]], s)
			core.toast("%s is picking at the wallpaper." % name)
			core.emit({"e": "clue", "seat": s, "index": i})
			core.say("space_clue", {"name": name})
		"caller":
			_caller_choice(s)
		"steal":
			var opts := []
			for o in core.living():
				if o != s and (not core.p(o).items.is_empty() or core.p(o).rats > 0):
					opts.append(o)
			if not opts.is_empty():
				core.say("space_steal", {"name": name})
				sub = "prompt"
				sub_t = 0.0
				prompt = {"kind": "steal", "seat": s, "options": opts}
				core.emit({"e": "prompt", "seat": s, "kind": "steal"})
				return
		"medic":
			Body.heal_temporary(pl.body)
			core.status.cure_all(s)
			core.emit({"e": "heal", "seat": s})
			core.say("space_medic", {"name": name})
			_shop_prompt(s, "medical")
			return
		"door":
			pl.at_door = true
			core.emit({"e": "door_stop", "seat": s})
			core.say("door_stop", {"name": name})
			_check_gather()
	_after()


func _shop_prompt(s: int, which: String) -> void:
	sub = "prompt"
	sub_t = 0.0
	prompt = {"kind": "shop", "seat": s, "shop": which, "options": core.economy.prices(which).keys()}
	core.emit({"e": "prompt", "seat": s, "kind": "shop", "shop": which})


## A punishment square: the Caller chooses, and the Cage chooses for him.
func _punish(s: int) -> void:
	var pl := core.p(s)
	core.say("space_punish", {"name": pl.name})
	var roll_p := core.rng.randi_range(0, 3)
	if core.cage.tip(s, "encounter"):
		roll_p = 0
	match roll_p:
		0:
			var part := Body.random_severable(pl.body, core.rng)
			if part != "":
				core.injure(s, part, "broken", "punishment")
		1:
			var n := core.economy.take(s, 3 + core.round_n / 3, "punishment")
			core.toast("He takes %d Dead Rats off %s." % [n, pl.name])
		2:
			core.suspicion.add(s, 8, "punishment")
		3:
			core.status.apply(s, core.status.random_poison(s), "punishment")


## A hidden square: there's something under it, if you look.
func _hidden(s: int) -> void:
	var pl := core.p(s)
	if core.cage.tip(s, "environment"):
		core.injure(s, "hand_r", "bruised", "trap")
		core.toast("A mousetrap under the square. A big one.", s)
		return
	match core.rng.randi_range(0, 2):
		0:
			core.economy.award(s, 4, "hidden")
			core.toast("Under the square: a nest of Dead Rats.", s)
		1:
			core.give_item(s, ["loaded_die", "alibi", "lucky_foot", "lazarus_rat"][core.rng.randi_range(0, 3)], "hidden")
		2:
			core.suspicion.add(s, -10, "hidden")
			core.toast("Under the square: a page from his file. Yours. You eat it.", s)


## Cheats at the table (assets/data/cheats.json, context "board").
func _board_cheat(seat: int, id: String, target: int) -> void:
	var pl := core.p(seat)
	if not core.cheats.available(seat, "board").has(id):
		return
	var others := core.living().filter(func(o): return o != seat)
	if core.cheats.catalogue[id].get("target", false) and not others.has(target):
		target = others[core.rng.randi_range(0, others.size() - 1)] if not others.is_empty() else -1
		if target < 0:
			return
	if not core.cheats.attempt(seat, id):
		if id == "palm_rats":
			core.economy.take(seat, 3, "caught palming")
		_after()   # caught: that's your turn
		return
	match id:
		"load_dice":
			pl.roll_bonus = 100
		"palm_rats":
			var n := mini(2, core.economy.house_pile)
			core.economy.house_pile -= n
			pl.rats += n
		"pick_pocket":
			var t := core.p(target)
			if not t.items.is_empty() and pl.items.size() < Items.MAX_HELD:
				var it: String = t.items.pop_at(core.rng.randi_range(0, t.items.size() - 1))
				pl.items.append(it)
			else:
				pl.rats += core.economy.take(target, 3, "pickpocketed")
			core.brains[target].wronged_by(seat, 0.05)
		"nudge":
			pl.space = (pl.space + 1) % core.board.size()
			core.emit({"e": "move", "seat": seat, "space": pl.space})
		"shove":
			var t := core.p(target)
			t.space = posmod(t.space - 2, core.board.size())
			t.at_door = false
			core.emit({"e": "move", "seat": target, "space": t.space})
			core.brains[target].wronged_by(seat, 0.05)


## A ghost's turn: one thing, then it's over. Ghosts can't be caged; they're not his any more.
func _ghost_action(seat: int, a: Dictionary) -> void:
	if str(a.get("t", "")) != "ghost":
		return
	var pl := core.p(seat)
	var target := int(a.get("target", -1))
	var living := core.living()
	match str(a.get("do", "")):
		"scavenge":
			var n := core.rng.randi_range(1, 3)
			pl.rats += n
			core.emit({"e": "rats", "seat": seat, "delta": n, "why": "scavenged"})
			core.toast("%s's ghost finds %d Dead Rat%s in the walls." % [pl.name, n, "" if n == 1 else "s"])
		"haunt":
			if not living.has(target):
				return
			core.p(target).roll_bonus -= 2
			core.toast("Something cold sits on %s's shoulder." % core.p(target).name)
		"bless":
			if not living.has(target):
				return
			core.p(target).roll_bonus += 2
			core.toast("%s feels a hand on their back, pushing." % core.p(target).name)
		"distract":
			core.suspicion.distract(8.0)
			core.toast("The neon fizzes and dies for a moment. He turns to look.")
		"rise":
			if not core.resurrection.buy(seat):
				return
		"whisper":
			core.emit({"e": "ghost_chat", "seat": seat, "text": str(a.get("text", "..."))})
			return   # talking isn't your turn
		_:
			return
	_after()


func room_done(seat: int) -> void:
	if seat == current() and sub == "room":
		_after()


func _check_gather() -> void:
	var n := 0
	for o in core.living():
		if core.p(o).at_door:
			n += 1
	if n >= 2:
		core.say("door_gather")


func _caller_choice(s: int) -> void:
	var pl := core.p(s)
	core.say("space_caller", {"name": pl.name})
	match core.rng.randi_range(0, 3):
		0:
			var id := Items.roll(core.rng)
			if core.give_item(s, id, "caller"):
				core.say("caller_gift", {"name": pl.name, "item": Items.name_of(id)})
		1:
			var others := core.living().filter(func(o): return o != s)
			if others.is_empty():
				return
			var o: int = others[core.rng.randi_range(0, others.size() - 1)]
			var a := pl.space
			pl.space = core.p(o).space
			core.p(o).space = a
			var door_a := pl.at_door
			pl.at_door = core.p(o).at_door
			core.p(o).at_door = door_a
			core.emit({"e": "swap", "a": s, "b": o})
			core.say("caller_swap", {"name": pl.name, "target": core.p(o).name})
		2:
			var n := mini(3, pl.rats)
			pl.rats -= n
			core.say("caller_tax", {"name": pl.name, "n": n})
		3:
			pl.rats += 4
			core.say("caller_bonus", {"name": pl.name, "n": 4})


func _steal(s: int, o: int) -> void:  # the item exchange square
	var a := core.p(s)
	var b := core.p(o)
	if not b.items.is_empty() and a.items.size() < Items.MAX_HELD:
		var id: String = b.items.pop_at(core.rng.randi_range(0, b.items.size() - 1))
		a.items.append(id)
		core.emit({"e": "steal", "seat": s, "from": o, "item": id})
		core.say("steal", {"name": a.name, "target": b.name})
	else:
		var n := mini(3, b.rats)
		b.rats -= n
		a.rats += n
		core.emit({"e": "steal", "seat": s, "from": o, "rats": n})
		core.say("steal", {"name": a.name, "target": b.name})
	core.brains[o].wronged_by(s, 0.15)


func use_item(seat: int, id: String) -> void:
	var pl := core.p(seat)
	if not pl.items.has(id) or not Items.usable_on_board(id):
		return
	if not pl.alive:
		return
	var used := true
	match id:
		"first_aid":
			var n := Body.heal_temporary(pl.body)
			var bone := Body.set_bone(pl.body)
			if n == 0 and bone == "":
				core.toast("Nothing for the first aid tin to fix.", seat)
				used = false
		"painkillers":
			pl.painkillers = 3
		"prosthetic":
			var part := Body.fit_prosthetic(pl.body)
			if part == "":
				core.toast("You haven't lost anything to replace. Yet.", seat)
				used = false
		"helmet":
			if pl.helmet:
				core.toast("You're already wearing one.", seat)
				used = false
			else:
				pl.helmet = true
		"surgery":
			var n := 0
			for part in Body.PARTS:
				if pl.body[part].s == "broken":
					pl.body[part].s = "ok"
					n += 1
			if core.status.has(seat, "necrosis"):
				core.status.cure(seat, "necrosis")
				n += 1
			if n == 0:
				core.toast("Nothing to operate on.", seat)
				used = false
		"antidote":
			if core.status.cure_all(seat) == 0:
				core.toast("You're not poisoned. (That you know of.)", seat)
				used = false
		"alibi":
			core.suspicion.add(seat, -20, "alibi")
		"lucky_foot":
			if pl.cage <= 0:
				core.toast("Your Cage is as open as it gets.", seat)
				used = false
			else:
				core.cage.loosen(seat, "rabbit's foot")
		"loaded_die":
			# contraband: swapping it in is a cheat
			pl.items.erase(id)
			if core.cheats.attempt(seat, "load_dice", "swap in a loaded die"):
				pl.roll_bonus = 100
			return
	if used:
		pl.items.erase(id)
		core.emit({"e": "use", "seat": seat, "item": id})
		core.say("use_item", {"name": pl.name, "item": Items.name_of(id)})


func _give(seat: int, id: String, target: int) -> void:
	var pl := core.p(seat)
	if id == "lazarus_rat" and pl.items.has(id) and target >= 0 and target < core.players.size() and core.p(target).ghost:
		pl.items.erase(id)
		core.say("lazarus", {"name": pl.name, "target": core.p(target).name})
		core.resurrection.revive(target, "lazarus")
		for o in core.living():
			core.brains[o].saw_kindness(seat, 0.3)
		return
	if not pl.items.has(id) or target == seat or target < 0 or target >= core.players.size() or not core.p(target).alive:
		return
	if core.p(target).items.size() >= Items.MAX_HELD:
		core.toast("%s can't carry any more." % core.p(target).name, seat)
		return
	pl.items.erase(id)
	core.p(target).items.append(id)
	core.emit({"e": "give", "seat": seat, "to": target, "item": id})
	core.say("give", {"name": pl.name, "item": Items.name_of(id), "target": core.p(target).name})
	for o in core.living():
		core.brains[o].saw_kindness(seat, 0.1 if o != target else 0.25)


func _share(seat: int) -> void:
	var pl := core.p(seat)
	if pl.clues.is_empty():
		core.toast("You don't know anything worth telling.", seat)
		return
	var new := false
	for i in pl.clues.keys():
		if not core.shared_code.has(i):
			core.shared_code[i] = pl.clues[i]
			new = true
	if not new:
		core.toast("They already know.", seat)
		return
	var parts := []
	for i in 3:
		parts.append(str(core.shared_code[i]) if core.shared_code.has(i) else "_")
	core.toast("%s tells everyone what they found: %s" % [pl.name, " ".join(parts)])
	core.emit({"e": "share", "seat": seat, "code": core.shared_code.duplicate()})
	core.say("share", {"name": pl.name})
	core.add_unrest("share", 0.34)
	for o in core.living():
		core.brains[o].saw_kindness(seat, 0.2)


func view() -> Dictionary:
	return {"seat": current(), "sub": sub, "sub_t": sub_t, "roll": roll, "steps": steps, "prompt": prompt, "order": order,
		"limit": MatchCore.HUMAN_TURN_LIMIT}
