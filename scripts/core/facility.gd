class_name FacilityManager
extends RefCounted
## THE FACILITY: getting up from the table and walking the place in real time while the
## board carries on without you (assets/data/facility.json; the building itself is the LCC
## one, data/hall/*.json, so where you can walk is the same walk grid the view uses).
##
## Three parts, as the spec asks: the OFF-TABLE CONTROLLER (leave, walk, interact, sit:
## action()), the RETURN TIMER (tick(): every away player's clock, and the moment it runs
## out) and the CALLER RESPONSE MANAGER (CallerResponseManager: what he does about it).
## The room remembers: counters, flags, what's been taken, what's broken (state; saved).
## Positions are host-checked (no teleporting); the walls are the client's business.

var core: MatchCore
var data: Dictionary = {}
var things: Dictionary = {}
var pools: Dictionary = {}
var building: Building
var responses: CallerResponseManager
var state: Dictionary = {}          # flags and counters: "panel_found", "shoes", "vending_uses"...
var used_once: Dictionary = {}      # action id -> true
var used_round: Dictionary = {}     # "seat:action" -> round
var spiked := false
var spiker := -1
var ring_t := 0.0                   # the phone: >0 while it's ringing
var _next_ring := 30.0
var drain_teeth := 0
var _drain_t := 0.0
var locker_name := -1               # whose name is on the locker this round
var arcade: Dictionary = {}         # seat -> {lit_at, t}
var walk_speed := 3.2
var escape: EscapeRoom


func _init(c: MatchCore) -> void:
	core = c
	data = Assets.load_json("res://assets/data/facility.json")
	things = data.get("things", {})
	pools = data.get("pools", {})
	walk_speed = float(data.get("walk_speed", 3.2))
	building = Building.new(Content.db)
	_open_doors()
	responses = CallerResponseManager.new(c)
	escape = EscapeRoom.new(c, self)
	_next_ring = core.rng.randf_range(20.0, 45.0)


## Doors that open: everything without a lock, and locked ones once their flag is set.
func _open_doors() -> void:
	for id in building.portals.keys():
		var need := str(data.get("locks", {}).get(id, ""))
		if need == "" or state.has(need):
			building.open_portals[id] = true
		elif building.open_portals.has(id) and building.portals[id].get("kind", "door") != "arch":
			building.open_portals.erase(id)


func open_portals() -> Array:
	return building.open_portals.keys()


func area_of(p: Vector2) -> String:
	return building.area_at(p)


func thing_pos(id: String) -> Vector2:
	var a: Array = things[id].pos
	return Vector2(float(a[0]), float(a[1]))


## Where to stand to use it (the nearest walkable point).
func stand_at(id: String) -> Vector2:
	return building.nearest_walkable(thing_pos(id), 2.5)


func seat_pos(seat: int) -> Vector2:
	var a := TAU * seat / maxf(1.0, core.players.size()) + PI / 2
	return Vector2(cos(a), sin(a)) * 1.9


func at_table(p: Vector2) -> bool:
	return p.length() <= float(data.get("table_radius", 2.7))


# --- the off-table controller -------------------------------------------------------------

## Nobody gets up whenever they like any more: the room is searched together, from a SEARCH
## square (SearchEvent puts everyone out there itself).
func can_leave(seat: int) -> bool:
	if not data.get("free_leave", false):
		return false
	var p := core.p(seat)
	if not p.alive or p.away():
		return false
	if core.phase in ["ending", "finale", "door", "intro"]:
		return false
	if core.phase == "turn" and core.rules.current() == seat and core.rules.sub in ["moving", "prompt"]:
		return false
	if core.phase == "mg_play" and core.mg and core.mg.seats.has(seat):
		return false
	return true


func action(seat: int, a: Dictionary) -> void:
	match str(a.get("t", "")):
		"leave":
			leave(seat, a.get("pos", null))
		"walk":
			walk(seat, a)
		"interact":
			interact(seat, str(a.get("id", "")), str(a.get("do", "")), int(a.get("target", -1)))
		"sit":
			var p := core.p(seat)
			if p.away() and (at_table(p.pos) or a.get("force", false) and core.is_ai(seat)):
				sit(seat, false, "")


func leave(seat: int, at = null) -> void:
	if not can_leave(seat):
		return
	var p := core.p(seat)
	p.location = "away"
	p.pos = seat_pos(seat)
	if at is Array and at.size() == 2:
		var q := Vector2(float(at[0]), float(at[1]))
		if q.length() < 3.0:
			p.pos = q
	p.pos = building.nearest_walkable(p.pos * 1.25, 1.5)
	p.away_t = 0.0
	p.away_late = false
	p.away_limit = float(data.get("return_time", 45)) * float(core.rulebook.value("return_mult", 1.0, seat))
	p.stat("room_trips")
	var amount := int(core.rulebook.value("leave_suspicion", int(data.get("leave_suspicion", 4)), seat))
	amount *= 2 if core.suspicion.watching else 1
	core.suspicion.add(seat, amount, "left the table")
	core.emit({"e": "leave", "seat": seat, "pos": [p.pos.x, p.pos.y]})
	core.say("leave_table", {"name": p.name})


## A position update. The host takes it if it's possible at walking pace.
func walk(seat: int, a: Dictionary) -> void:
	var p := core.p(seat)
	if not p.away():
		return
	var at = a.get("pos", null)
	if not (at is Array and at.size() == 2):
		return
	var q := Vector2(float(at[0]), float(at[1]))
	var d := q - p.pos
	var lim := walk_speed * 1.6 * maxf(0.25, float(a.get("dt", 0.25)))
	if d.length() > lim:
		q = p.pos + d.normalized() * lim
	p.pos = q
	p.yaw = float(a.get("yaw", p.yaw))


func sit(seat: int, forced: bool, why: String) -> void:
	var p := core.p(seat)
	if not p.away() or p.location == "escaped":
		return
	p.location = "table"
	p.away_t = 0.0
	p.away_late = false
	arcade.erase(seat)
	core.emit({"e": "sit", "seat": seat, "forced": forced, "why": why})
	if forced:
		core.say("forced_sit", {"name": p.name})


# --- the return timer ---------------------------------------------------------------------

func tick(dt: float) -> void:
	for p in core.players:
		if not p.away() or p.location == "escaped":
			continue
		p.away_t += dt
		if p.away_t >= p.away_limit and not p.away_late:
			p.away_late = true
			p.stat("times_late")
			responses.respond(p.seat)
	# the phone rings when nobody's near it
	if ring_t > 0.0:
		ring_t -= dt
		if _anyone_near("phone", 4.5):
			ring_t = 0.0
			core.emit({"e": "phone", "ringing": false})
	else:
		_next_ring -= dt
		if _next_ring <= 0.0:
			_next_ring = core.rng.randf_range(25.0, 60.0)
			if not _anyone_near("phone", 5.0):
				ring_t = 9.0
				core.emit({"e": "phone", "ringing": true})
	# the drain fills up
	_drain_t += dt
	if _drain_t >= 15.0:
		_drain_t = 0.0
		drain_teeth = mini(8, drain_teeth + 1)
	escape.tick(dt)
	for s in arcade.keys():
		arcade[s].t += dt
		if arcade[s].t > float(arcade[s].lit_at) + 1.2:
			core.toast("Too slow. GAME OVER.", s)
			arcade.erase(s)


func _anyone_near(id: String, r: float) -> bool:
	for p in core.players:
		if p.away() and p.pos.distance_to(thing_pos(id)) < r:
			return true
	return false


func new_round() -> void:
	var cand := core.players.map(func(x): return x.seat)
	locker_name = cand[core.rng.randi_range(0, cand.size() - 1)] if not cand.is_empty() else -1


# --- interactions -------------------------------------------------------------------------

func near(seat: int, id: String) -> bool:
	var p := core.p(seat)
	return p.away() and things.has(id) and p.pos.distance_to(thing_pos(id)) <= float(things[id].get("r", 1.5)) + 0.6


## What `seat` can do at thing `id` right now.
func actions_at(seat: int, id: String) -> Array:
	var out := []
	if not things.has(id):
		return out
	for a in things[id].actions:
		if a.get("once", false) and used_once.has(a.id):
			continue
		if a.has("needs_flag") and not _flag(seat, str(a.needs_flag)):
			continue
		if a.has("hidden_if") and state.has(str(a.hidden_if)):
			continue
		if a.has("hidden_until_not") and state.has(str(a.hidden_until_not)):
			continue
		if a.get("per_round", false) and int(used_round.get("%d:%s" % [seat, a.id], -1)) == core.round_n:
			continue
		out.append(a)
	return out


func _flag(seat: int, f: String) -> bool:
	match f:
		"arcade_lit":
			return arcade.has(seat) and float(arcade[seat].t) >= float(arcade[seat].lit_at)
	return state.has(f)


func interact(seat: int, id: String, action_id: String, target := -1) -> void:
	var p := core.p(seat)
	if not near(seat, id):
		return
	var a: Dictionary = {}
	for x in actions_at(seat, id):
		if x.id == action_id:
			a = x
	if a.is_empty():
		return
	if a.has("needs") and not p.items.has(str(a.needs)):
		core.toast("You need a %s for that." % Items.name_of(str(a.needs)).to_lower(), seat)
		return
	if int(a.get("cost", 0)) > 0 and not core.economy.charge(seat, int(a.cost), str(a.id)):
		core.toast("That costs %d Teeth." % int(a.cost), seat)
		return
	if a.get("once", false):
		used_once[a.id] = true
	if a.get("per_round", false):
		used_round["%d:%s" % [seat, a.id]] = core.round_n
	if int(a.get("caught", 0)) > 0 and _seen(seat, id):
		core.emit({"e": "caught", "seat": seat, "cheat": a.id, "what": a.name})
		core.say("caught_room", {"name": p.name})
		core.toast("CAUGHT: %s, at %s." % [p.name, str(things[id].name).to_lower()])
		core.suspicion.add(seat, int(a.get("caught", 15)), "caught: " + a.id)
		core.economy.take(seat, 2, "fined")
		p.stat("cheats_caught")
		sit(seat, true, "caught")
		return
	core.suspicion.add(seat, int(a.get("ok", 4)), a.id)
	core.emit({"e": "interact", "seat": seat, "id": id, "action": a.id})
	_effect(seat, id, a, target)


## Does he see this? In the showroom it's his attention; anywhere else, only a camera.
func _seen(seat: int, id: String) -> bool:
	var area := str(things[id].get("area", "hall"))
	if area == "hall":
		return core.suspicion.sees(seat)
	return core.suspicion.watching and core.rng.randf() < float(data.get("camera_chance", 0.25))


func _found(seat: int) -> void:
	core.p(seat).stat("room_found")


func _effect(seat: int, id: String, a: Dictionary, target: int) -> void:
	var p := core.p(seat)
	if str(a.effect).begins_with("esc_"):
		escape.effect(seat, a)
		return
	match str(a.effect):
		"find":
			_find(seat, str(a.pool))
		"give":
			if core.give_item(seat, str(a.item), "facility"):
				_found(seat)
				core.toast("You take the %s." % Items.name_of(str(a.item)).to_lower(), seat)
		"rob":
			var opts := core.living().filter(func(o): return o != seat)
			if target < 0 or not opts.has(target):
				target = opts[core.rng.randi_range(0, opts.size() - 1)] if not opts.is_empty() else -1
			if target < 0:
				return
			var t := core.p(target)
			if not t.items.is_empty() and p.items.size() < Items.MAX_HELD:
				var it: String = t.items.pop_at(core.rng.randi_range(0, t.items.size() - 1))
				p.items.append(it)
				core.toast("In %s's coat: a %s. It's yours now." % [t.name, Items.name_of(it)], seat)
			else:
				var n := core.economy.transfer(target, seat, 3, "robbed")
				core.toast("%d Teeth out of %s's coat." % [n, t.name], seat)
			p.stat("steals")
			t.stat("victimised")
			core.brains[target].wronged_by(seat, 0.1)
		"spike":
			spiked = true
			spiker = seat
			core.toast("You tip a little bottle into the punch.", seat)
		"unlock":
			state[str(a.flag)] = true
			p.items.erase("hairpin")
			_open_doors()
			core.emit({"e": "unlock", "flag": a.flag})
			core.toast("The lock gives.", seat)
			_found(seat)
		"nest":
			if core.cage.tip(seat, "environment"):
				core.injure(seat, "hand_r", "broken", "rat bite")
				core.status.apply(seat, "rat_fever", "rat bite")
				core.toast("Something in the nest is still alive.", seat)
			else:
				var n := core.economy.award(seat, 5, "the nest")
				core.toast("You pull %d Teeth out of the nest." % n, seat)
				_found(seat)
		"read_file":
			var file := {}
			for o in core.players:
				file[o.seat] = {"suspicion": o.suspicion, "cage": o.cage}
			p.known["file"] = file
			core.toast("His files. Everyone's in here. He's very thorough.", seat)
		"doctor_file":
			core.suspicion.add(seat, -18, "doctored the file")
			core.toast("You rub out a page of yourself.", seat)
		"loosen_cage":
			core.cage.loosen(seat, "tampered")
			core.toast("A notch on your Cage, eased. He'll notice. Eventually.", seat)
		"pinata":
			if core.cage.tip(seat, "environment"):
				core.injure(seat, "hand_l", "burned", "pinata")
				core.status.apply(seat, "rat_fever", "pinata")
				core.toast("It splits. What comes out isn't sweets.", seat)
			else:
				match core.rng.randi_range(0, 2):
					0:
						core.economy.award(seat, 3, "pinata")
						core.toast("Teeth rain out of it.", seat)
					1:
						core.give_item(seat, Items.roll(core.rng), "pinata")
					2:
						core.give_item(seat, "painkillers", "pinata")
				_found(seat)
		"tamper":
			var nxt := core.next_minigame()
			p.tamper[nxt] = true
			core.toast("You fix something in the box for %s. It'll go your way." % MinigameRegistry.title_of(nxt), seat)
		"look_ahead":
			var nxt := core.next_minigame()
			p.known["next_game"] = nxt
			core.toast("Set out for later: %s." % MinigameRegistry.title_of(nxt), seat)
		"distract":
			core.suspicion.distract(8.0)
			core.toast("The lights go. He looks up at them.", seat)
		"vend":
			state.vending_uses = int(state.get("vending_uses", 0)) + 1
			if int(state.vending_uses) % 6 == 0:
				state.vending_jammed = true
				core.toast("It takes your Teeth and makes a noise like a throat. Jammed.", seat)
				return
			match core.rng.randi_range(0, 5):
				0:
					core.toast("A can drops out: MEAT. Just MEAT. It's warm. You feel better.", seat)
					Body.heal_temporary(p.body)
				1:
					core.economy.award(seat, 1, "vending", false)
					core.toast("One Tooth comes out. Somebody's. Change.", seat)
				2:
					core.injure(seat, "hand_r", "bruised", "the vending machine")
					core.toast("Something alive comes out of the flap and bites.", seat)
				3:
					core.give_item(seat, Items.roll(core.rng, "common"), "vending")
					_found(seat)
				4:
					core.toast("A photograph drops out. It's you, asleep, from above. Tonight.", seat)
					core.suspicion.add(seat, -3, "it's only a photo")
				5:
					core.give_item(seat, ["counterfeit_teeth", "loaded_wallet", "lucky_tooth"][core.rng.randi_range(0, 2)], "vending")
					_found(seat)
		"kick_vending":
			state.erase("vending_jammed")
			core.economy.award(seat, 3, "vending", false)
			core.suspicion.add(seat, 4, "noise")
			core.toast("You kick it. It coughs up three Teeth and starts working again.", seat)
		"phone":
			if ring_t <= 0.0:
				core.toast("A dial tone. Then breathing. Then the dial tone again.", seat)
				return
			ring_t = 0.0
			core.emit({"e": "phone", "ringing": false})
			_found(seat)
			match core.rng.randi_range(0, 2):
				0:
					var nxt := core.next_minigame()
					p.known["next_game"] = nxt
					core.toast("A child's voice: \"Next is %s. Practise.\"" % MinigameRegistry.title_of(nxt), seat)
				1:
					var ci := core.rng.randi_range(0, 2)
					p.clues[ci] = core.code[ci]
					core.toast("An old woman reads you a number, very slowly: %d. Then she hangs up." % core.code[ci], seat)
				2:
					var objs := core.victory.hidden.map(func(o): return core.victory.data.objectives[o].name)
					if objs.is_empty():
						core.toast("A man's voice: \"The rat will move. It always moves.\"", seat)
					else:
						p.known["objectives"] = objs
						core.toast("A man's voice, reading: \"%s.\"" % ", ".join(objs), seat)
		"arcade_play":
			arcade[seat] = {"t": 0.0, "lit_at": core.rng.randf_range(1.0, 3.0)}
			core.toast("The screen comes on: WAIT FOR RED.", seat)
		"arcade_hit":
			var st: Dictionary = arcade.get(seat, {})
			arcade.erase(seat)
			if st.is_empty():
				return
			state.arcade_wins = int(state.get("arcade_wins", 0)) + 1
			core.economy.award(seat, 6, "arcade", false)
			core.toast("HIGH SCORE. It spits out 6 Teeth and asks for your initials.", seat)
			state.high_score = p.name
			if int(state.arcade_wins) == 3:
				core.toast("The cabinet shudders. There's another game inside it. It's coming out after the turns.")
				core.queue_minigame("bonus", core.living(), "", 0, seat)
				_found(seat)
		"knock":
			state.knocks = int(state.get("knocks", 0)) + 1
			if int(state.knocks) >= 2:
				state.panel_found = true
				core.toast("Hollow. A panel, painted to look like the wall.", seat)
				_found(seat)
			else:
				core.toast("Solid. Probably.", seat)
		"open_panel":
			core.give_item(seat, "shortcut_key", "the panel")
			core.economy.award(seat, 5, "the panel", false)
			core.toast("Behind the panel: a crawlspace, a key on a nail, a little pile of Teeth, and a child's drawing of you.", seat)
			_found(seat)
		"drain":
			if core.cage.tip(seat, "environment") or core.rng.randf() < 0.15:
				core.injure(seat, "hand_l", "bruised", "the drain")
				core.toast("Something in the drain closes on your fingers.", seat)
			if drain_teeth > 0:
				var n := drain_teeth
				drain_teeth = 0
				core.economy.award(seat, n, "the drain", false)
				core.toast("You fish %d Teeth out of the drain. More are coming up from somewhere." % n, seat)
				_found(seat)
			else:
				core.toast("Just hair. Lots of hair.", seat)
		"shoes":
			state.shoes = int(state.get("shoes", 0)) + 1
			var n := int(state.shoes)
			if n % 3 == 0 and core.rng.randf() < 0.3:
				core.injure(seat, ["hand_l", "hand_r"][core.rng.randi_range(0, 1)], "bruised", "frostbite")
			if n == 5:
				core.give_item(seat, "greased_shoes", "the freezer")
				core.toast("Shoe number %d isn't the same. It's been greased." % n, seat)
				_found(seat)
			elif n == 9:
				core.change_rats(seat, 1, "the freezer")
				core.toast("Shoe number nine has a Dead Rat in it. Frozen solid. It counts.", seat)
				_found(seat)
			else:
				core.toast("Another left shoe. Size nine. Brown. Identical to all the others. (That's %d.)" % n, seat)
		"minutes":
			p.known["rules_next"] = true
			var objs := core.victory.hidden.map(func(o): return core.victory.data.objectives[o].name)
			if not objs.is_empty():
				p.known["objectives"] = objs
				core.toast("The minutes of the last meeting. Item 4: '%s'." % ", ".join(objs), seat)
			else:
				core.toast("The minutes: 'Item 1: the rat. Item 2: the rat. Item 3: more chairs.'", seat)
			_found(seat)
		"amendment":
			core.rulebook.add_random(seat)
		"locker":
			if locker_name < 0:
				new_round()
			if locker_name == seat:
				core.give_item(seat, Items.roll(core.rng, "rare"), "your locker")
				core.toast("Your name on the locker. Inside, something left for you.", seat)
			else:
				var owner := core.p(locker_name)
				core.economy.award(seat, 4, "a locker", false)
				owner.stat("victimised")
				core.suspicion.add(seat, 4, "someone else's locker")
				core.toast("%s's name is on it. Inside: 4 Teeth and a photo of %s's family. You take the Teeth." % [owner.name, owner.name], seat)
			_found(seat)
			# and the name changes as you look
			var others := core.players.filter(func(x): return x.seat != locker_name).map(func(x): return x.seat)
			if not others.is_empty():
				locker_name = others[core.rng.randi_range(0, others.size() - 1)]
		"sabotage":
			var opts := core.living().filter(func(o): return o != seat)
			if target < 0 or not opts.has(target):
				target = opts[core.rng.randi_range(0, opts.size() - 1)] if not opts.is_empty() else -1
			if target < 0:
				return
			core.p(target).handicap = true
			core.p(target).stat("victimised")
			core.toast("You loosen something that %s's next game depends on." % core.p(target).name, seat)
		"till":
			if not state.has("yard"):
				state.yard = true
				_open_doors()
				core.emit({"e": "unlock", "flag": "yard"})
				core.toast("Under the coins: a key on a tag that says YARD.", seat)
				_found(seat)
			core.economy.award(seat, 3, "the till")
		"drink":
			if core.rng.randf() < 0.5:
				core.status.apply(seat, core.status.random_poison(seat), "a drink at the bar")
			else:
				core.status.apply(seat, "cure", "a drink at the bar")


func _find(seat: int, pool: String) -> void:
	var entries: Array = pools.get(pool, [])
	if entries.is_empty():
		return
	var pick: String = ""
	if core.cage.tip(seat, "environment"):
		pick = "nothing" if core.rng.randf() < 0.6 else "bite"
	else:
		var total := 0
		for e in entries:
			total += int(e[1])
		var r := core.rng.randi_range(0, total - 1)
		for e in entries:
			r -= int(e[1])
			if r < 0:
				pick = str(e[0])
				break
	match pick:
		"nothing":
			core.toast("Nothing. Lint. A ticket stub from last year.", seat)
		"teeth":
			core.economy.award(seat, 3, "found")
			core.toast("Three Teeth, stiff, in a pocket.", seat)
			_found(seat)
		"teeth_big":
			core.economy.award(seat, 7, "found")
			core.toast("A jar of Teeth.", seat)
			_found(seat)
		"bite":
			core.injure(seat, "hand_l", "bruised", "something bit")
			core.toast("Something in there bites.", seat)
		"poison":
			core.status.apply(seat, core.status.random_poison(seat), "tasted something")
		_:
			if Items.has(pick) and core.give_item(seat, pick, "found"):
				core.toast("You find a %s." % Items.name_of(pick), seat)
				_found(seat)


func view_for(seat: int) -> Dictionary:
	var th := {}
	for id in things.keys():
		var acts := []
		if seat >= 0:
			for a in actions_at(seat, id):
				acts.append({"id": a.id, "name": a.name, "target": a.get("target", false), "needs": a.get("needs", ""), "cost": int(a.get("cost", 0))})
		th[id] = {"name": things[id].name, "pos": things[id].pos, "r": float(things[id].get("r", 1.5)), "area": str(things[id].get("area", "hall")), "actions": acts}
	var away := {}
	for p in core.players:
		if p.away():
			away[p.seat] = {"pos": [p.pos.x, p.pos.y], "yaw": p.yaw, "t": p.away_t, "limit": p.away_limit}
	return {"things": th, "away": away, "open": open_portals(), "ringing": ring_t > 0.0, "drain": drain_teeth,
		"locker": core.p(locker_name).name if locker_name >= 0 else "", "state": state.duplicate(),
		"arcade_lit": seat >= 0 and _flag(seat, "arcade_lit"), "arcade_on": seat >= 0 and arcade.has(seat),
		"areas": data.get("areas", {}), "high_score": str(state.get("high_score", ""))}


func to_save() -> Dictionary:
	return {"state": state.duplicate(true), "once": used_once.duplicate(), "drain": drain_teeth, "locker": locker_name,
		"spiked": spiked, "spiker": spiker, "late": responses.late_count, "escape": escape.to_save()}


func load_save(d: Dictionary) -> void:
	state = d.get("state", {}).duplicate(true)
	for k in state.keys():
		if typeof(state[k]) == TYPE_FLOAT:
			state[k] = int(state[k])
	used_once = d.get("once", {}).duplicate()
	drain_teeth = int(d.get("drain", 0))
	locker_name = int(d.get("locker", -1))
	spiked = bool(d.get("spiked", false))
	spiker = int(d.get("spiker", -1))
	responses.late_count = int(d.get("late", 0))
	escape.load_save(d.get("escape", {}))
	_open_doors()
