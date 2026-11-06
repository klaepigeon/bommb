class_name MatchCore
extends RefCounted
## The whole match, as the host runs it: phases, contestants, deaths, endings. No nodes,
## no drawing, no networking: tick() it and feed it actions; read events and views out.
## Everything that decides anything happens here (host-authoritative), with one seeded
## RNG, so a match can be replayed and tested headless.
##
## Phases: intro -> turn (board, BoardRules) -> mg_intro -> mg_play -> mg_results ->
## (next round) turn ... -> door (the collective push) / ceremony -> ending.

const MAX_ROUNDS := 10
const INTRO_TIME := 9.0
const MG_INTRO_TIME := 8.0
const MG_RESULTS_TIME := 5.0
const CEREMONY_TIME := 6.0
const HUMAN_TURN_LIMIT := 30.0
const DOOR_PUSH_TIME := 12.0

var rng := RandomNumberGenerator.new()
var seed_value := 0
var players: Array[PlayerState] = []
var board: Array = []
var board_name := ""
var code: Array[int] = []
var shared_code: Dictionary = {}     # clue index -> digit, told to everyone
var key_space := -1                  # a dropped key lies here
var key_exists := false              # the key has been made (the bomb gave it up)
var round_n := 1
var max_rounds := MAX_ROUNDS
var phase := "intro"
var phase_t := 0.0
var unrest := 0.0                    # 0..3: how far the contestants have got under his skin
var subversions: Array[String] = []
var ending := ""                     # "" | "dead" | "escape"
var ending_info := {}
var mg: Minigame
var mg_id := ""
var mg_count := 0
var schedule: Array = []
var events: Array = []
var ready_seats: Dictionary = {}
var door_push: Dictionary = {}
var ceremony := ""
var brains: Dictionary = {}          # seat -> AiBrain (for AI seats and timed-out humans)
var rules: BoardRules
var log_lines: Array[String] = []
var fast := false                    # tests: shorten the waits


func setup(seat_list: Array, match_seed: int = 0, board_path := "res://assets/data/board.json") -> void:
	seed_value = match_seed if match_seed != 0 else int(Time.get_ticks_usec() % 2147483647)
	rng.seed = seed_value
	var bd := Assets.load_json(board_path)
	board = bd.get("spaces", [])
	board_name = str(bd.get("name", "THE BOARD"))
	for s in seat_list:
		var p := PlayerState.from_seat(s)
		players.append(p)
		var b := AiBrain.new()
		b.setup(p.seat, rng.randi(), s.get("ai", {}))
		brains[p.seat] = b
	for i in 3:
		code.append(rng.randi_range(1, 9))
	schedule = MinigameRegistry.schedule()
	rules = BoardRules.new(self)
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


func is_ai(seat: int) -> bool:
	return players[seat].kind == "ai"


func injure(seat: int, part: String, status: String, cause := "") -> void:
	var pl := players[seat]
	if not pl.alive:
		return
	var before: String = pl.body[part].s
	var now := Body.injure(pl.body, part, status)
	if now != before:
		emit({"e": "injure", "seat": seat, "part": part, "status": now, "cause": cause})
		log_lines.append("%s: %s %s (%s)" % [pl.name, part, now, cause])


## Kill a contestant (anim names a death animation). A worn helmet takes it instead and
## the `fallback` injuries ([part, status] pairs) happen. Returns true if they died.
func kill(seat: int, anim: String, fallback := [], forced := false) -> bool:
	var pl := players[seat]
	if not pl.alive:
		return false
	if pl.helmet and not forced:
		pl.helmet = false
		emit({"e": "helmet", "seat": seat})
		for f in fallback:
			injure(seat, f[0], f[1], "helmet")
		return false
	pl.alive = false
	pl.death = anim
	pl.died_round = round_n
	pl.at_door = false
	if pl.has_key:
		pl.has_key = false
		key_space = pl.space
		emit({"e": "key_drop", "space": key_space})
	emit({"e": "death", "seat": seat, "anim": anim})
	log_lines.append("DEATH: %s (%s)" % [pl.name, anim])
	say("death", {"name": pl.name})
	return true


func give_item(seat: int, id: String, how := "found") -> bool:
	var pl := players[seat]
	if pl.items.size() >= Items.MAX_HELD:
		toast("%s's pockets are full." % pl.name)
		return false
	pl.items.append(id)
	emit({"e": "item", "seat": seat, "item": id, "how": how})
	return true


## A human seat's peer left: the Caller plays for them (an AI takes the seat).
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


# --- the clock ------------------------------------------------------------------------

func tick(dt: float) -> void:
	if ending != "":
		return
	phase_t += dt
	match phase:
		"intro":
			if phase_t > _wait(INTRO_TIME) or _all_ready():
				_start_round()
		"turn":
			rules.tick(dt)
		"mg_intro":
			if phase_t > _wait(MG_INTRO_TIME) or _all_ready():
				_set_phase("mg_play")
				mg.start()
		"mg_play":
			mg.tick(dt)
			for s in mg.seats:
				if players[s].alive and is_ai(s):
					brains[s].minigame(self, mg, dt)
			if mg.done:
				_finish_minigame()
		"mg_results":
			if phase_t > _wait(MG_RESULTS_TIME) or _all_ready():
				_after_minigame()
		"door":
			_tick_door()
		"ceremony":
			if phase_t > _wait(CEREMONY_TIME):
				for s in living():
					kill(s, "prize", [], true)
				_end("dead")
	if phase == "turn":
		var cur := rules.current()
		if cur >= 0 and players[cur].alive and is_ai(cur):
			brains[cur].board(self, dt)


func _wait(t: float) -> float:
	return t * (0.05 if fast else 1.0)


func _all_ready() -> bool:
	var need := 0
	for pl in players:
		if pl.kind != "ai" and pl.alive:
			need += 1
			if not ready_seats.has(pl.seat):
				return false
	return need > 0


# --- actions --------------------------------------------------------------------------

## Every input from every contestant (human, remote, AI) comes through here.
func action(seat: int, a: Dictionary) -> void:
	if ending != "" or seat < 0 or seat >= players.size():
		return
	var t := str(a.get("t", ""))
	if t == "ready":
		ready_seats[seat] = true
		return
	if not players[seat].alive:
		return
	match phase:
		"turn":
			rules.action(seat, a)
		"mg_play":
			if t == "mg" and mg:
				mg.action(seat, a)
		"door":
			if t == "push":
				door_push[seat] = true
				emit({"e": "push", "seat": seat})


# --- rounds and minigames ---------------------------------------------------------------

func _start_round() -> void:
	_set_phase("turn")
	say("round", {"n": round_n})
	rules.begin_round()


## Called by BoardRules when everyone has had a turn.
func board_round_done() -> void:
	mg_id = str(schedule[mg_count % schedule.size()])
	var level := mg_count / schedule.size()
	mg_count += 1
	mg = MinigameRegistry.create(mg_id, self, living(), level)
	_set_phase("mg_intro")
	emit({"e": "minigame", "id": mg_id, "title": mg.title(), "level": level})
	say("minigame", {"game": mg.title()})


func _finish_minigame() -> void:
	for s in mg.tickets.keys():
		players[s].tickets = maxi(0, players[s].tickets + int(mg.tickets[s]))
	_set_phase("mg_results")
	say("results")
	emit({"e": "results", "id": mg_id, "tickets": mg.tickets.duplicate(), "summary": mg.summary()})


func _after_minigame() -> void:
	var alive := living()
	if alive.is_empty():
		_end("dead")
		return
	if alive.size() == 1:
		ceremony = "winner"
		say("winner", {"name": players[alive[0]].name})
		_set_phase("ceremony")
		emit({"e": "ceremony", "kind": "winner", "seat": alive[0]})
		return
	round_n += 1
	for pl in players:
		if pl.alive:
			Body.tick_round(pl.body)
			pl.painkillers = maxi(0, pl.painkillers - 1)
	if round_n > max_rounds:
		ceremony = "last_call"
		say("last_call")
		_set_phase("ceremony")
		emit({"e": "ceremony", "kind": "last_call"})
		return
	mg = null
	_start_round()


# --- the door ---------------------------------------------------------------------------

## Someone at the door tries it. It tells them what's missing, without saying how.
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
	var standings := []
	for pl in players:
		standings.append({"seat": pl.seat, "name": pl.name, "tickets": pl.tickets, "alive": pl.alive, "death": pl.death})
	ending_info = {"kind": kind, "round": round_n, "standings": standings, "subversions": subversions.duplicate()}
	say("ending_escape" if kind == "escape" else "ending_dead")
	_set_phase("ending")
	emit({"e": "ending", "kind": kind})
	log_lines.append("ENDING: " + kind)


# --- what each screen (and each AI) is allowed to see -----------------------------------

func view_for(seats: Array) -> Dictionary:
	var pv := []
	for pl in players:
		pv.append(pl.to_view(seats.has(pl.seat)))
	var known := shared_code.duplicate()
	return {
		"phase": phase, "phase_t": phase_t, "round": round_n, "max_rounds": max_rounds,
		"players": pv, "board_name": board_name, "shared_code": known, "key_space": key_space,
		"unrest": unrest, "ending": ending, "ending_info": ending_info, "ceremony": ceremony,
		"turn": rules.view() if rules else {}, "mg_id": mg_id,
		"mg": mg.view_for(seats) if mg else {}, "door_push": door_push.keys(),
		"ready": ready_seats.keys(), "you": seats,
	}
