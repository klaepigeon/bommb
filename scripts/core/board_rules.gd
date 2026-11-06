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
var sub := "idle"      # pre | moving | prompt | after | idle
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
	idx = 0
	_start_turn()


func current() -> int:
	return order[idx] if sub != "idle" and idx < order.size() else -1


func _start_turn() -> void:
	while idx < order.size() and not core.p(order[idx]).alive:
		idx += 1
	if idx >= order.size():
		sub = "idle"
		core.board_round_done()
		return
	sub = "pre"
	sub_t = 0.0
	roll = 0
	steps = 0
	prompt = {}
	var s := order[idx]
	core.emit({"e": "turn", "seat": s})
	core.say("turn", {"name": core.p(s).name})


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
		"moving":
			if sub_t >= core._wait(STEP_TIME):
				sub_t = 0.0
				_step()
		"prompt":
			if not core.is_ai(s) and sub_t > core._wait(PROMPT_LIMIT):
				if prompt.kind == "door_stop":
					action(s, {"t": "answer", "yes": false})
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
		"pre":
			match t:
				"roll":
					roll = core.rng.randi_range(1, Body.dice_max(pl.body, pl.pk()))
					steps = roll
					pl.at_door = false
					core.emit({"e": "roll", "seat": seat, "n": roll, "max": Body.dice_max(pl.body, pl.pk())})
					core.say("roll", {"n": roll})
					sub = "moving"
					sub_t = -0.8   # let the dice land
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
		pl.tickets += 2
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
	match str(sp.type):
		"start":
			pl.tickets += 2
			core.say("pass_start", {"name": name})
		"tickets":
			var n := 3 + core.round_n / 3
			pl.tickets += n
			core.say("space_tickets", {"name": name, "n": n})
		"item":
			var id := Items.roll(core.rng)
			if core.give_item(s, id):
				core.say("space_item", {"name": name, "item": Items.name_of(id)})
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
				if o != s and (not core.p(o).items.is_empty() or core.p(o).tickets > 0):
					opts.append(o)
			if not opts.is_empty():
				core.say("space_steal", {"name": name})
				sub = "prompt"
				sub_t = 0.0
				prompt = {"kind": "steal", "seat": s, "options": opts}
				core.emit({"e": "prompt", "seat": s, "kind": "steal"})
				return
		"medic":
			var n := Body.heal_temporary(pl.body)
			core.emit({"e": "heal", "seat": s})
			core.say("space_medic", {"name": name})
			if n == 0:
				pl.tickets += 1
		"door":
			pl.at_door = true
			core.emit({"e": "door_stop", "seat": s})
			core.say("door_stop", {"name": name})
			_check_gather()
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
			var n := mini(3, pl.tickets)
			pl.tickets -= n
			core.say("caller_tax", {"name": pl.name, "n": n})
		3:
			pl.tickets += 4
			core.say("caller_bonus", {"name": pl.name, "n": 4})


func _steal(s: int, o: int) -> void:
	var a := core.p(s)
	var b := core.p(o)
	if not b.items.is_empty() and a.items.size() < Items.MAX_HELD:
		var id: String = b.items.pop_at(core.rng.randi_range(0, b.items.size() - 1))
		a.items.append(id)
		core.emit({"e": "steal", "seat": s, "from": o, "item": id})
		core.say("steal", {"name": a.name, "target": b.name})
	else:
		var n := mini(3, b.tickets)
		b.tickets -= n
		a.tickets += n
		core.emit({"e": "steal", "seat": s, "from": o, "tickets": n})
		core.say("steal", {"name": a.name, "target": b.name})
	core.brains[o].wronged_by(s, 0.15)


func use_item(seat: int, id: String) -> void:
	var pl := core.p(seat)
	if not pl.items.has(id) or not Items.usable_on_board(id):
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
	if used:
		pl.items.erase(id)
		core.emit({"e": "use", "seat": seat, "item": id})
		core.say("use_item", {"name": pl.name, "item": Items.name_of(id)})


func _give(seat: int, id: String, target: int) -> void:
	var pl := core.p(seat)
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
	return {"seat": current(), "sub": sub, "sub_t": sub_t, "roll": roll, "steps": steps, "prompt": prompt, "order": order}
