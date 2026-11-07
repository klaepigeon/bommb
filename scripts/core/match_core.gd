class_name MatchCore
extends RefCounted
## The whole match, as the host runs it: phases, contestants, deaths, the finale. No nodes,
## no drawing, no networking: tick() it and feed it actions; read events and views out.
## Everything that decides anything happens here (host-authoritative), with one seeded RNG
## whose state is saved, so a match replays exactly and a reload can't reroll anything.
##
## LAST CALL 3 v0.2.5, the party-game loop: a match is 10/15/20/30 rounds. A round: every
## contestant takes a board turn (BoardRules: items, roll, walk the board graph, land),
## then the minigames queued this round (duels, bonus games), then the round's minigame
## (a battle if someone hit a battle square, Russian Roulette if someone hit that). The
## last round is FINAL ROUND. Then the finale: the Caller's Awards, the Caller's Game,
## final standings by DEAD RATS, a winner.
##
## Phases: intro -> turn -> mg_intro -> mg_play -> mg_results -> (more queued | next round)
## ... -> finale -> ending. And the door (the old way out, still there for those who find it).
##
## The systems hang off this as managers, one file each, talking to each other only
## through MatchCore: suspicion, cage, cheats, facility (leaving the table, in real time),
## resurrection, status (poisons), economy (Teeth), items, shops, rulebook (amendments),
## fate (random events), awards, victory (standings, the Caller's Game).

const DEFAULT_ROUNDS := 15
const LENGTHS := {"quick": 10, "standard": 15, "extended": 20, "marathon": 30}
const INTRO_TIME := 6.0
const MG_INTRO_TIME := 6.0
const MG_RESULTS_TIME := 4.0
const FINALE_TIME := 14.0
const HUMAN_TURN_LIMIT := 30.0
const DOOR_PUSH_TIME := 12.0
## minigame payouts by format (placings: best first; ties share the better place)
const PAYOUT := {
	"ffa": [10, 6, 3, 0], "bonus": [16, 9, 4, 1], "2v2": [8, 0], "1v3_solo": 14, "1v3_team": 6,
	"coop": 8, "duel": 6, "draw": 3, "special": [8, 4, 2, 0],
}

var rng := RandomNumberGenerator.new()
var seed_value := 0
var players: Array[PlayerState] = []
var graph: BoardGraph
var board: Array = []                # graph.nodes (kept for old callers)
var board_name := ""
var rat_space := -1                  # where the Dead Rat sits
var traps: Dictionary = {}           # space -> who set the rat trap
var code: Array[int] = []
var shared_code: Dictionary = {}
var key_space := -1
var key_exists := false
var round_n := 1
var max_rounds := DEFAULT_ROUNDS
var mode := "classic"                # classic | callers_game
var phase := "intro"
var phase_t := 0.0
var unrest := 0.0
var subversions: Array[String] = []
var ending := ""                     # "" | "winner" | "dead" | "escape"
var ending_info := {}
var mg: Minigame
var mg_id := ""
var mg_entry := {}                   # {id, kind, seats, pool, wager, by}
var mg_queue: Array = []
var mg_count := 0
var mg_history: Array = []
var schedule: Array = []
var events: Array = []
var ready_seats: Dictionary = {}
var door_push: Dictionary = {}
var ceremony := ""
var brains: Dictionary = {}
var rules: BoardRules
var log_lines: Array[String] = []
var fast := false
var suspicion: SuspicionManager
var cage: CageManager
var cheats: CheatingManager
var facility: FacilityManager
var resurrection: ResurrectionManager
var status: StatusEffectManager
var economy: EconomyManager
var items: ItemManager
var shops: ShopManager
var rulebook: RuleManager
var fate: EventManager
var awards: AwardManager
var victory: VictoryManager
var cutscenes: CutsceneManager
var machines: BoardMachines
var pending_encounter := ""          # "roulette" | "battle": a square has called it for this round
var _next_mg := ""
var _last_mg := ""
var draws := 0
var last_results := {}
var leader_seat := -1


func setup(seat_list: Array, match_seed: int = 0, opts := {}) -> void:
	seed_value = match_seed if match_seed != 0 else int(Time.get_ticks_usec() % 2147483647)
	rng.seed = seed_value
	var turns = opts.get("turns", DEFAULT_ROUNDS)
	max_rounds = int(LENGTHS.get(turns, turns)) if turns is String else int(turns)
	max_rounds = clampi(max_rounds, 1, 60)
	mode = str(opts.get("mode", "classic"))
	graph = BoardGraph.load_board(str(opts.get("board", "res://assets/data/murderland.json")))
	board = graph.nodes
	board_name = graph.name
	for s in seat_list:
		var p := PlayerState.from_seat(s)
		players.append(p)
		var b := AiBrain.new()
		b.setup(p.seat, rng.randi(), s.get("ai", {}))
		brains[p.seat] = b
	for i in 3:
		code.append(rng.randi_range(1, 9))
	schedule = MinigameRegistry.schedule()
	suspicion = SuspicionManager.new(self)
	cage = CageManager.new(self)
	cheats = CheatingManager.new(self)
	facility = FacilityManager.new(self)
	resurrection = ResurrectionManager.new(self)
	status = StatusEffectManager.new(self)
	economy = EconomyManager.new(self)
	items = ItemManager.new(self)
	shops = ShopManager.new(self)
	rulebook = RuleManager.new(self)
	fate = EventManager.new(self)
	awards = AwardManager.new(self)
	victory = VictoryManager.new(self)
	cutscenes = CutsceneManager.new(self)
	machines = BoardMachines.new(self)
	rules = BoardRules.new(self)
	victory.setup(mode)
	rat_space = graph.rat_spots[rng.randi_range(0, graph.rat_spots.size() - 1)] if not graph.rat_spots.is_empty() else -1
	for p in players:
		p.teeth = int(opts.get("start_teeth", 10))
	say("intro")
	_set_phase("intro")


# --- events -------------------------------------------------------------------------

func emit(e: Dictionary) -> void:
	events.append(e)


func take_events() -> Array:
	var e := events
	events = []
	return e


func say(key: String, params := {}) -> void:
	var l := CallerLines.pick(key, unrest, rng, params)
	if l.is_empty():
		return
	l.e = "say"
	l.key = key
	emit(l)
	log_lines.append("CALLER: " + str(l.text))


func toast(text: String, to := -1) -> void:
	emit({"e": "toast", "text": text, "to": to})
	log_lines.append(("[to %d] " % to if to >= 0 else "") + text)


func add_unrest(why: String, amount := 1.0) -> void:
	unrest = minf(3.0, unrest + amount)
	subversions.append(why)
	emit({"e": "unrest", "level": unrest, "why": why})
	if amount >= 1.0:
		say("unrest")


func _set_phase(p: String) -> void:
	phase = p
	phase_t = 0.0
	ready_seats.clear()
	emit({"e": "phase", "phase": p})


# --- contestants ----------------------------------------------------------------------

func p(seat: int) -> PlayerState:
	return players[seat]


func living() -> Array[int]:
	var out: Array[int] = []
	for pl in players:
		if pl.alive:
			out.append(pl.seat)
	return out


## Living and sitting at the table.
func seated() -> Array[int]:
	var out: Array[int] = []
	for pl in players:
		if pl.alive and not pl.away():
			out.append(pl.seat)
	return out


func is_ai(seat: int) -> bool:
	return players[seat].kind == "ai"


func ghosts() -> Array[int]:
	return resurrection.ghosts()


## Standings order now (0 = leading): Dead Rats, then Teeth.
func rank_of(seat: int) -> int:
	var st := victory.standings()
	for i in st.size():
		if int(st[i].seat) == seat:
			return i
	return 0


func leader() -> int:
	var st := victory.standings()
	return int(st[0].seat) if not st.is_empty() else -1


## The one at the bottom (living only, if asked).
func trailer(living_only := false) -> int:
	var st := victory.standings()
	for i in range(st.size() - 1, -1, -1):
		if not living_only or players[int(st[i].seat)].alive:
			return int(st[i].seat)
	return -1


## Dead Rats in or out (the score).
func change_rats(seat: int, n: int, why: String) -> void:
	var pl := players[seat]
	if n < 0:
		n = -mini(-n, pl.rats)
	if n == 0:
		return
	pl.rats += n
	pl.stat("rats_got" if n > 0 else "rats_lost", absi(n))
	emit({"e": "rats", "seat": seat, "delta": n, "why": why})
	log_lines.append("%s: %+d Dead Rat (%s)" % [pl.name, n, why])


## Hurt someone. Their safety pin stops it, body armour takes the edge off (unless
## `protect` is false: the sacrifice takes what it takes).
func injure(seat: int, part: String, st: String, cause := "", protect := true) -> void:
	var pl := players[seat]
	if not pl.alive or not pl.body.has(part):
		return
	if protect:
		if items and items.consume_passive(seat, "safety_pin", "the " + cause if cause != "" else "an injury"):
			return
		if pl.armour > 0:
			pl.armour -= 1
			var milder := {"lost": "broken", "broken": "burned", "burned": "bruised", "bruised": ""}.get(st, st)
			emit({"e": "armour", "seat": seat})
			if milder == "":
				return
			st = milder
	var before: String = pl.body[part].s
	var now := Body.injure(pl.body, part, status.worsen(seat, st) if status else st)
	if now != before:
		pl.stat("injuries")
		if now == "lost":
			pl.stat("parts_lost")
			if items:
				items.claim_insurance(seat, "lost a " + Body.LABEL.get(part, part).to_lower())
		if cause in ["trap", "machinery", "the belt", "the grinder", "the press", "the drum", "hazard", "party favour"]:
			pl.stat("traps_hit")
		emit({"e": "injure", "seat": seat, "part": part, "status": now, "cause": cause})
		log_lines.append("%s: %s %s (%s)" % [pl.name, part, now, cause])


func hurt(seat: int, part: String, st: String, cause := "") -> void:
	injure(seat, part, st, cause)


## Kill a contestant. A worn helmet takes it instead and the `fallback` injuries happen.
func kill(seat: int, anim: String, fallback := [], forced := false) -> bool:
	var pl := players[seat]
	if not pl.alive:
		return false
	if pl.helmet and not forced:
		pl.helmet = false
		pl.stat("near_deaths")
		emit({"e": "helmet", "seat": seat})
		for f in fallback:
			injure(seat, f[0], f[1], "helmet")
		return false
	if items:
		items.on_death(seat)
	pl.alive = false
	pl.ghost = true
	pl.death = anim
	pl.died_round = round_n
	pl.deaths += 1
	pl.at_door = false
	if pl.away():
		facility.sit(seat, true, "")
	pl.location = "table"
	pl.statuses.clear()
	if pl.has_key:
		pl.has_key = false
		key_space = pl.space
		emit({"e": "key_drop", "space": key_space})
	emit({"e": "death", "seat": seat, "anim": anim})
	log_lines.append("DEATH: %s (%s)" % [pl.name, anim])
	say("death", {"name": pl.name})
	if living().is_empty() and phase != "ending":
		_end("dead")
	return true


func give_item(seat: int, id: String, how := "found") -> bool:
	var pl := players[seat]
	if pl.items.size() >= Items.MAX_HELD:
		toast("%s's pockets are full (three things)." % pl.name)
		return false
	pl.items.append(id)
	pl.stat("items_got")
	emit({"e": "item", "seat": seat, "item": id, "how": how})
	return true


func seat_disconnected(seat: int) -> void:
	var pl := players[seat]
	if pl.kind == "remote":
		pl.kind = "ai"
		say("disconnect", {"name": pl.name})


func knows_code(seat: int) -> bool:
	for i in 3:
		if not shared_code.has(i) and not players[seat].clues.has(i):
			return false
	return true


# --- the board's furniture ----------------------------------------------------------

## The Dead Rat moves to another spot (`to` = -1: a random one it isn't on).
func move_rat(to := -1) -> void:
	if to < 0:
		var spots := graph.rat_spots.filter(func(x): return int(x) != rat_space)
		if spots.is_empty():
			return
		to = int(spots[rng.randi_range(0, spots.size() - 1)])
	rat_space = to
	emit({"e": "rat_moved", "space": rat_space})


## Renovations: a square near someone changes type for the rest of the match.
func alter_space(seat: int) -> void:
	var at := graph.ahead(players[seat].space, rng.randi_range(1, 4))
	var t := graph.type_of(at)
	if not t in ["normal", "bad"]:
		return
	var to := "bad" if t == "normal" else "normal"
	if rng.randf() < 0.3:
		to = ["event", "item", "trap", "gamble"][rng.randi_range(0, 3)]
	graph.nodes[at].type = to
	graph.altered[at] = to
	emit({"e": "alter", "space": at, "type": to})


# --- the clock ------------------------------------------------------------------------

func tick(dt: float) -> void:
	if ending != "":
		return
	phase_t += dt
	suspicion.tick(dt)
	facility.tick(dt)
	cutscenes.tick(dt)
	# a blocking cutscene: everybody watches; the board (and the clock) waits
	if cutscenes.blocking():
		phase_t -= dt
		return
	match phase:
		"intro":
			if phase_t > _wait(INTRO_TIME) or _all_ready():
				_start_round()
		"turn":
			rules.tick(dt)
		"mg_intro":
			if phase_t > _wait(MG_INTRO_TIME) or _all_ready():
				_register_and_play()
		"mg_play":
			mg.tick(dt)
			for s in mg.seats:
				if players[s].alive and is_ai(s):
					brains[s].minigame(self, mg, dt)
			for s in ghosts():
				if is_ai(s):
					brains[s].ghost_minigame(self, mg, dt)
			if mg.done:
				_finish_minigame()
		"mg_results":
			if phase_t > _wait(MG_RESULTS_TIME) or _all_ready():
				_after_minigame()
		"door":
			_tick_door()
		"finale":
			if phase_t > _wait(FINALE_TIME) or (_all_ready() and phase_t > _wait(4.0)):
				_end("winner")
	if phase == "turn":
		var cur := rules.current()
		if cur >= 0 and is_ai(cur):
			if players[cur].alive:
				brains[cur].board(self, dt)
			elif players[cur].ghost:
				brains[cur].ghost_turn(self, dt)
	# the AI wanders off (or comes back) on its own clock, whoever's turn it is
	for pl in players:
		if pl.alive and is_ai(pl.seat):
			brains[pl.seat].facility(self, dt)


func _wait(t: float) -> float:
	return t * (0.05 if fast else 1.0)


func _all_ready() -> bool:
	var need := 0
	for pl in players:
		if pl.kind != "ai" and (pl.alive or pl.ghost):
			need += 1
			if not ready_seats.has(pl.seat):
				return false
	return need > 0


# --- actions --------------------------------------------------------------------------

func action(seat: int, a: Dictionary) -> void:
	if ending != "" or seat < 0 or seat >= players.size():
		return
	var t := str(a.get("t", ""))
	if t == "ready":
		ready_seats[seat] = true
		return
	if not players[seat].alive and not players[seat].ghost:
		return
	# the facility is real time: these work whatever's happening at the table
	if t in ["leave", "walk", "interact", "sit"] and players[seat].alive:
		if t == "leave" and phase == "mg_play" and mg and mg.seats.has(seat):
			return
		facility.action(seat, a)
		return
	match phase:
		"turn":
			rules.action(seat, a)
		"mg_play":
			if mg == null:
				return
			if players[seat].ghost:
				if t == "ghost":
					mg.ghost_action(seat, a)
				return
			if t == "mg":
				mg.action(seat, a)
			elif t == "mg_cheat":
				var id := str(a.get("id", ""))
				var label := ""
				for o in mg.cheat_options(seat):
					if o.id == id:
						label = str(o.name)
				if label != "" and cheats.attempt(seat, "game_cheat", label):
					mg.apply_cheat(seat, id)
		"mg_intro":
			if t == "wager" and mg_entry.get("kind", "") == "battle":
				pass
		"door":
			if t == "push" and players[seat].alive:
				door_push[seat] = true
				emit({"e": "push", "seat": seat})


# --- rounds and minigames ---------------------------------------------------------------

func final_round() -> bool:
	return round_n >= max_rounds


func _start_round() -> void:
	_set_phase("turn")
	if final_round():
		say("final_round")
		emit({"e": "final_round"})
		toast("FINAL ROUND. Everything on the board pays triple. The Caller's Awards are next.")
	else:
		say("round", {"n": round_n})
	victory.on_round(round_n)
	if mode == "callers_game" and victory.revealed and round_n % 3 == 0:
		rulebook.add_random(-1)
	shops.restock()
	items.round_tick()
	facility.new_round()
	machines.round_start()
	if facility.spiked:
		facility.spiked = false
		say("punch")
		for s in living():
			if s != facility.spiker:
				status.apply(s, status.random_poison(s), "the punch")
	# the leader this round (for MAIN CHARACTER)
	var lead := leader()
	if lead >= 0 and players[lead].rats > 0:
		players[lead].stat("lead_rounds")
		if lead != leader_seat and leader_seat >= 0:
			emit({"e": "lead_change", "seat": lead})
		leader_seat = lead
	for pl in players:
		pl.stat_max("suspicion_max", pl.suspicion)
		if pl.ghost:
			pl.stat("ghost_turns")
	_next_mg = _pick_minigame(living().size())
	emit({"e": "round", "n": round_n, "final": final_round()})
	if _saves_ok():
		Engine.get_main_loop().root.get_node("/root/Saves").checkpoint(self)
	rules.begin_round()


func _saves_ok() -> bool:
	var ml := Engine.get_main_loop()
	return ml is SceneTree and (ml as SceneTree).root.has_node("Saves") and not fast


## What's next (decided at the start of the round, so the props cupboard can show it).
func next_minigame() -> String:
	if pending_encounter == "roulette":
		return "roulette"
	if _next_mg == "":
		_next_mg = _pick_minigame(living().size())
	return _next_mg


func _pick_minigame(n: int, fmt := "") -> String:
	var recent := mg_history.slice(maxi(0, mg_history.size() - 3))
	var pool := MinigameRegistry.eligible(n, fmt).filter(func(k): return not recent.has(k))
	if pool.is_empty():
		pool = MinigameRegistry.eligible(n, fmt).filter(func(k): return k != _last_mg)
	if pool.is_empty():
		pool = MinigameRegistry.eligible(n, fmt)
	if pool.is_empty():
		return ""
	# the ten 0.2.5 games come up more than the extra catalogue
	var w := []
	var total := 0
	for k in pool:
		var x := 3 if MinigameRegistry.GAMES[k].get("core", false) else 1
		w.append(x)
		total += x
	var r := rng.randi_range(0, total - 1)
	for i in pool.size():
		r -= w[i]
		if r < 0:
			return pool[i]
	return pool[0]


## Something on the board has asked for a game after the turns: a duel, a bonus game.
func queue_minigame(kind: String, seats: Array, id := "", wager := 0, by := -1) -> void:
	mg_queue.append({"kind": kind, "seats": seats.duplicate(), "id": id, "wager": wager, "by": by})
	emit({"e": "queued", "kind": kind, "seats": seats})


## A special event (ORGAN TRAIL) is called for, after this round's turns.
func call_special(id: String, by := -1) -> void:
	for e in mg_queue:
		if str(e.id) == id:
			return
	queue_minigame("special", [], id, 0, by)
	emit({"e": "special", "id": id, "by": by})
	say("special_" + id)
	toast("THE CALLER: \"A SPECIAL EVENT! After the turns: %s.\"" % MinigameRegistry.title_of(id))


func board_round_done() -> void:
	if living().is_empty():
		_end("dead")
		return
	# the round's own game goes last
	var main_kind := "main"
	if pending_encounter == "roulette":
		main_kind = "roulette"
	elif pending_encounter == "battle":
		main_kind = "battle"
	mg_queue.append({"kind": main_kind, "seats": [], "id": "", "wager": 0, "by": -1})
	pending_encounter = ""
	_next_queued()


func _next_queued() -> void:
	while not mg_queue.is_empty():
		var e: Dictionary = mg_queue.pop_front()
		if _start_entry(e):
			return
	_round_over()


## Set up one game from the queue. False if it can't be played (not enough people).
func _start_entry(e: Dictionary) -> bool:
	var seats: Array[int] = []
	var want: Array = e.seats if not (e.seats as Array).is_empty() else living()
	for s in want:
		if players[int(s)].alive:
			seats.append(int(s))
	var kind := str(e.kind)
	var id := str(e.id)
	match kind:
		"main":
			id = _next_mg if _next_mg != "" and MinigameRegistry.fits(_next_mg, seats.size()) else _pick_minigame(seats.size())
		"roulette":
			id = "roulette"
		"battle", "bonus":
			if id == "":
				id = _pick_minigame(seats.size(), "ffa")
		"duel":
			if seats.size() != 2:
				return false
			if id == "":
				id = _pick_minigame(2, "duel")
		"special":
			if not MinigameRegistry.fits(id, seats.size()):
				toast("%s needs %d of you at the table. Not tonight." % [MinigameRegistry.title_of(id), int(MinigameRegistry.GAMES.get(id, {}).get("min", 4))])
				return false
	if id == "" or seats.size() < int(MinigameRegistry.GAMES.get(id, {}).get("min", 2)):
		return false
	mg_entry = e.duplicate(true)
	mg_entry.id = id
	mg_entry.seats = seats
	mg_entry.pool = 0
	mg_entry.rat_prize = kind == "battle" and rng.randf() < 0.15
	if kind == "battle":
		var how: String = ["fixed", "percent", "double"][rng.randi_range(0, 2)]
		mg_entry.wager_rule = how
		for s in seats:
			var w := 5 if how == "fixed" else (players[s].teeth / 5 if how == "percent" else players[s].teeth / 2)
			mg_entry.pool += economy.take(s, w, "battle wager")
	elif kind == "duel":
		for s in seats:
			mg_entry.pool += economy.take(s, int(e.wager), "duel wager")
	mg_id = id
	_last_mg = id
	mg_history.append(id)
	var level := mini(mg_count / 4, 3)
	mg_count += 1
	mg = MinigameRegistry.create(id, self, seats, level)
	_set_phase("mg_intro")
	emit({"e": "minigame", "id": mg_id, "title": mg.title(), "level": level, "kind": kind, "pool": mg_entry.pool, "presentation": MinigameRegistry.presentation(id),
		"wager_rule": mg_entry.get("wager_rule", ""), "seats": seats})
	say("minigame_" + kind if kind != "main" else "minigame", {"game": mg.title(), "n": mg_entry.pool})
	return true


## The countdown's over: whoever's at the table plays. Anyone still out in the facility
## misses it (a forfeit). If that leaves too few, the game doesn't happen.
func _register_and_play() -> void:
	var present: Array[int] = []
	for s in mg.seats:
		if players[s].alive and not players[s].away():
			present.append(s)
		elif players[s].alive:
			players[s].stat("forfeits")
			toast("%s isn't at the table. They miss %s." % [players[s].name, mg.title()])
			emit({"e": "forfeit", "seat": s, "id": mg_id})
	if present.size() != mg.seats.size():
		var fits := MinigameRegistry.fits(mg_id, present.size())
		if not fits:
			toast("Not enough of you at the table. %s is cancelled." % mg.title())
			# a wager goes back
			_refund_pool(mg.seats)
			mg = null
			_next_queued()
			return
		mg = MinigameRegistry.create(mg_id, self, present, mini((mg_count - 1) / 4, 3))
		mg_entry.seats = present
	for s in mg.seats:
		if players[s].handicap:
			players[s].handicap = false
			mg.handicap(s)
	_set_phase("mg_play")
	mg.start()


func _refund_pool(seats: Array) -> void:
	var pool := int(mg_entry.get("pool", 0))
	if pool <= 0 or seats.is_empty():
		return
	for s in seats:
		players[int(s)].teeth += pool / seats.size()
	mg_entry.pool = 0


## Results: placings, payouts, the pool, stats, and the one rule every free-for-all shares:
## a draw brings the dead back, and every living player pays for it with a part of themselves.
func _finish_minigame() -> void:
	var kind := str(mg_entry.get("kind", "main"))
	var fmt := mg.format
	var groups := mg.placings()
	var pay := {}
	for s in mg.seats:
		pay[s] = 0
	var drew: bool = mg.draw
	if drew:
		for s in mg.seats:
			pay[s] = PAYOUT.draw
	elif kind == "duel" or fmt == "duel":
		for s in mg.winners:
			pay[s] = PAYOUT.duel
	elif fmt == "2v2":
		for s in mg.winners:
			pay[s] = PAYOUT["2v2"][0]
	elif fmt == "1v3":
		for s in mg.winners:
			pay[s] = PAYOUT["1v3_solo"] if mg.winners.size() == 1 else PAYOUT["1v3_team"]
	elif fmt == "coop":
		for s in mg.winners:
			pay[s] = PAYOUT.coop
	else:
		var table: Array = PAYOUT.bonus if kind == "bonus" else (PAYOUT.special if fmt == "special" else PAYOUT.ffa)
		var place := 0
		for g in groups:
			for s in g:
				pay[s] = int(table[mini(place, table.size() - 1)])
			place += (g as Array).size()
	if kind == "bonus":
		for s in pay.keys():
			pay[s] = int(pay[s])
	# what they picked up in the game itself
	for s in mg.teeth.keys():
		pay[s] = int(pay.get(s, 0)) + int(mg.teeth[s])
	for s in pay.keys():
		var n := int(pay[s])
		if n > 0 and players[s].alive:
			economy.award(s, n, mg_id)
		elif n < 0:
			economy.take(s, -n, mg_id)
	# the pot
	var pool := int(mg_entry.get("pool", 0))
	var pool_to: Array = []
	if pool > 0:
		if drew or mg.winners.is_empty():
			_refund_pool(mg.seats)
		else:
			pool_to = mg.winners.duplicate()
			for s in pool_to:
				players[s].teeth += pool / pool_to.size()
				emit({"e": "teeth", "seat": s, "delta": pool / pool_to.size(), "why": "the pot"})
			economy.house_pile += pool % pool_to.size()
	if mg_entry.get("rat_prize", false) and not drew:
		for s in mg.winners:
			change_rats(s, 1, "battle prize")
	# stats
	for s in mg.winners:
		players[s].stat("minigame_wins")
	if not drew and groups.size() > 1:
		var last: Array = groups[groups.size() - 1]
		if last.size() < mg.seats.size():
			for s in last:
				players[s].stat("last_places")
	if mg_id == "last_seat":
		for s in mg.winners:
			players[s].stat("chairs")
	var draw_resurrects := drew and mg.format == "ffa"
	if drew:
		var dt := int(rulebook.value("draw_teeth", 0))
		for s in mg.seats:
			if dt > 0 and players[s].alive:
				economy.award(s, dt, "participation")
	_set_phase("mg_results")
	say("results_draw" if draw_resurrects else "results")
	last_results = {"id": mg_id, "kind": kind, "pay": pay.duplicate(), "summary": mg.summary(), "winners": mg.winners.duplicate(),
		"draw": drew, "placings": groups.duplicate(true), "pool": pool, "pool_to": pool_to}
	emit({"e": "results", "id": mg_id, "kind": kind, "teeth": pay.duplicate(), "summary": mg.summary(), "winners": mg.winners.duplicate(),
		"draw": drew, "placings": groups.duplicate(true), "pool": pool})
	if draw_resurrects and not living().is_empty():
		draws += 1
		resurrection.collective()


func _after_minigame() -> void:
	if living().is_empty():
		_end("dead")
		return
	mg = null
	_next_queued()


func _round_over() -> void:
	mg = null
	if living().is_empty():
		_end("dead")
		return
	cage.review()
	rulebook.end_round()
	for pl in players:
		if pl.alive:
			Body.tick_round(pl.body)
			pl.painkillers = maxi(0, pl.painkillers - 1)
	if round_n >= max_rounds:
		_finale()
		return
	round_n += 1
	_start_round()


## The end of the match: the Caller's Awards, the Caller's Game, standings, a winner.
func _finale() -> void:
	ceremony = "awards"
	_set_phase("finale")
	say("finale")
	var given := awards.present(3)
	for g in given:
		var names := []
		for s in g.seats:
			names.append(players[int(s)].name)
		say("award", {"award": str(g.name), "name": ", ".join(names)})
	victory.settle()
	emit({"e": "finale", "awards": given, "objectives": victory.results.duplicate(true), "standings": victory.standings()})


# --- the door ---------------------------------------------------------------------------

func try_door(seat: int) -> void:
	var alive := living()
	var all_there := true
	for s in alive:
		if not players[s].at_door:
			all_there = false
	var key_here := false
	for s in alive:
		if players[s].has_key:
			key_here = true
	if not key_here:
		toast("The door is real. It's locked. There's a keyhole shaped like a winding key.", seat)
		say("door_stop", {"name": players[seat].name})
		return
	if not knows_code(seat):
		toast("The key turns. Above the handle, three brass dials: _ _ _. You don't know the numbers.", seat)
		return
	if alive.size() < 2 or not all_there:
		toast("Key in, dials set. It's heavy. It will not move for one person. Not for %d." % _count_at_door(), seat)
		say("door_gather")
		return
	add_unrest("door", 1.0)
	door_push.clear()
	door_push[seat] = true
	_set_phase("door")
	say("door_open")
	emit({"e": "door", "opener": seat})


func _count_at_door() -> int:
	var n := 0
	for s in living():
		if players[s].at_door:
			n += 1
	return n


func _tick_door() -> void:
	var alive := living()
	var all := true
	for s in alive:
		if not door_push.has(s):
			all = false
			if is_ai(s):
				brains[s].door(self)
	if all:
		emit({"e": "door_open"})
		_end("escape")
		return
	if phase_t > 4.0 and int(phase_t * 10) % 40 == 0:
		say("door_push")
	if phase_t > _wait(DOOR_PUSH_TIME):
		var holdouts := []
		for s in alive:
			if not door_push.has(s):
				holdouts.append(players[s].name)
		say("door_fail")
		toast("The door settles shut. Not everyone pushed: %s." % ", ".join(holdouts))
		_set_phase("turn")
		rules.next_turn()


# --- endings ----------------------------------------------------------------------------

func _end(kind: String) -> void:
	ending = kind
	var st := victory.standings()
	var winner := -1
	var winners: Array = st.filter(func(x): return int(x.place) == 1).map(func(x): return int(x.seat))
	if kind == "escape":
		winners = facility.escape.escaped.keys() if not facility.escape.escaped.is_empty() else living()
		winner = int(winners[0]) if not winners.is_empty() else -1
	elif not st.is_empty():
		winner = int(st[0].seat)
	ending_info = {"kind": kind, "round": round_n, "max_rounds": max_rounds, "standings": st, "winner": winner,
		"winners": winners, "escaped": facility.escape.escaped.keys(),
		"awards": awards.given.duplicate(true), "objectives": victory.results.duplicate(true),
		"subversions": subversions.duplicate(), "economy": economy.flow.duplicate(), "draws": draws}
	match kind:
		"escape":
			say("ending_escape")
		"dead":
			say("ending_dead")
		_:
			say("ending_winner", {"name": players[winner].name if winner >= 0 else "nobody"})
	_set_phase("ending")
	emit({"e": "ending", "kind": kind, "winner": winner})
	log_lines.append("ENDING: " + kind)
	if _saves_ok():
		Engine.get_main_loop().root.get_node("/root/Saves").clear()


# --- what each screen (and each AI) is allowed to see -----------------------------------

func view_for(seats: Array) -> Dictionary:
	var pv := []
	for pl in players:
		pv.append(pl.to_view(seats.has(pl.seat)))
	var me := int(seats[0]) if not seats.is_empty() else -1
	var shelves := {}
	if me >= 0:
		for sid in shops.shops().keys():
			shelves[sid] = shops.shelf(me, sid)
	return {
		"phase": phase, "phase_t": phase_t, "round": round_n, "max_rounds": max_rounds, "final": final_round(), "mode": mode,
		"players": pv, "board_name": board_name, "shared_code": shared_code.duplicate(), "key_space": key_space,
		"unrest": unrest, "ending": ending, "ending_info": ending_info, "ceremony": ceremony,
		"turn": rules.view() if rules else {}, "mg_id": mg_id, "mg_entry": mg_entry.duplicate(true), "presentation": MinigameRegistry.presentation(mg_id) if mg_id != "" else "MEAT_PUPPET",
		"mg": mg.view_for(seats) if mg else {}, "door_push": door_push.keys(),
		"ready": ready_seats.keys(), "you": seats,
		"attention": suspicion.view(), "ghosts": ghosts(), "resurrect_cost": economy.resurrect_cost(),
		"cage_levels": cage.levels, "shelves": shelves, "draws": draws, "encounter": pending_encounter,
		"rat_space": rat_space, "rat_price": economy.rat_price(), "traps": traps.keys(), "altered": graph.altered.duplicate(),
		"rules": rulebook.view(), "objectives": victory.view(), "last_results": last_results,
		"queue": mg_queue.map(func(e): return str(e.kind)),
		"facility": facility.view_for(me),
		"cheats": cheats.available(me, "board") if me >= 0 else [],
		"flags": status.view_flags(me) if me >= 0 else {},
		"next_game": next_minigame() if me >= 0 and str(players[me].known.get("next_game", "")) != "" and not status.has(me, "memory") else "",
		"cutscene": cutscenes.view(), "machines": machines.view(),
		"finale": {"awards": awards.given.duplicate(true), "objectives": victory.results.duplicate(true), "standings": victory.standings()} if phase in ["finale", "ending"] else {},
	}


# --- saving (SaveManager writes this at the start of every round) ------------------------

func snapshot() -> Dictionary:
	var pl := []
	for x in players:
		pl.append(x.to_save())
	var br := {}
	for s in brains.keys():
		br[str(s)] = brains[s].to_save()
	var tr := {}
	for k in traps.keys():
		tr[str(k)] = traps[k]
	var sc := {}
	for k in shared_code.keys():
		sc[str(k)] = shared_code[k]
	var alt := {}
	for k in graph.altered.keys():
		alt[str(k)] = graph.altered[k]
	return {
		"version": 3, "seed": seed_value, "rng_state": str(rng.state), "round": round_n, "max_rounds": max_rounds, "mode": mode,
		"players": pl, "brains": br, "rat_space": rat_space, "traps": tr, "altered": alt, "code": Array(code), "shared_code": sc,
		"key_space": key_space, "key_exists": key_exists, "unrest": unrest, "subversions": Array(subversions), "mg_count": mg_count,
		"mg_history": mg_history.duplicate(), "last_mg": _last_mg, "next_mg": _next_mg, "draws": draws, "leader": leader_seat,
		"rulebook": rulebook.to_save(), "shops": shops.to_save(), "victory": victory.to_save(), "fate": fate.to_save(),
		"facility": facility.to_save(), "machines": machines.to_save(), "cage": cage.to_save(), "cheats_once": cheats.used_once.duplicate(),
		"economy": {"house": economy.house_pile, "flow": economy.flow.duplicate()}, "log": log_lines.slice(maxi(0, log_lines.size() - 60)),
	}


## Rebuild a match from a snapshot (made at the start of a round): the board turns of that
## round replay from the same RNG state, so nothing comes out differently.
static func from_snapshot(seat_list: Array, d: Dictionary) -> MatchCore:
	var c := MatchCore.new()
	c.fast = false
	c.setup(seat_list, int(d.seed), {"turns": int(d.max_rounds), "mode": str(d.mode)})
	c.take_events()
	c.round_n = int(d.round)
	for i in mini(c.players.size(), (d.players as Array).size()):
		var kind := c.players[i].kind
		var peer := c.players[i].peer
		c.players[i].load_save(d.players[i])
		c.players[i].kind = kind
		c.players[i].peer = peer
	for s in (d.get("brains", {}) as Dictionary).keys():
		if c.brains.has(int(s)):
			c.brains[int(s)].load_save(d.brains[s])
	c.rat_space = int(d.rat_space)
	c.traps.clear()
	for k in d.get("traps", {}).keys():
		c.traps[int(k)] = int(d.traps[k])
	for k in d.get("altered", {}).keys():
		c.graph.nodes[int(k)].type = str(d.altered[k])
		c.graph.altered[int(k)] = str(d.altered[k])
	c.code.clear()
	for x in d.code:
		c.code.append(int(x))
	c.shared_code.clear()
	for k in d.get("shared_code", {}).keys():
		c.shared_code[int(k)] = int(d.shared_code[k])
	c.key_space = int(d.key_space)
	c.key_exists = bool(d.key_exists)
	c.unrest = float(d.unrest)
	c.mg_count = int(d.mg_count)
	c.mg_history = d.get("mg_history", []).duplicate()
	c._last_mg = str(d.get("last_mg", ""))
	c.draws = int(d.get("draws", 0))
	c.leader_seat = int(d.get("leader", -1))
	c.rulebook.load_save(d.get("rulebook", {}))
	c.shops.load_save(d.get("shops", {}))
	c.victory.load_save(d.get("victory", {}))
	c.fate.load_save(d.get("fate", []))
	c.facility.load_save(d.get("facility", {}))
	c.machines.load_save(d.get("machines", {}))
	c.cage.load_save(d.get("cage", {}))
	c.cheats.used_once = d.get("cheats_once", {}).duplicate()
	c.economy.house_pile = int(d.get("economy", {}).get("house", 30))
	c.rng.state = int(str(d.rng_state))
	# the round restarts exactly where the save was made: everyone back at the table
	for x in c.players:
		x.location = "table"
	c.say("resume", {"n": c.round_n})
	c._resume_round()
	return c


func _resume_round() -> void:
	_set_phase("turn")
	_next_mg = _pick_minigame(living().size())
	emit({"e": "round", "n": round_n, "final": final_round(), "resumed": true})
	rules.begin_round()
