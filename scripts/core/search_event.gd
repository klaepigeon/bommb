class_name SearchEvent
extends RefCounted
## THE SEARCH (a board space): everyone at the table gets up and searches the showroom at
## once, in first person, for scraps of paper. It's sold as a race: "whoever finds the most
## wins 10 Teeth". It isn't one. The scraps are one torn note; at the end each finder chooses,
## in secret, to KEEP their scraps (2 Teeth each) or LAY THEM ON THE TABLE. If every scrap was
## found AND everyone holding one laid it down, the note is whole and EVERYONE gets a Dead
## Rat: far more than the race was ever worth. One keeper and it stays torn. The words on the
## scraps say as much, for whoever reads them.
##
## Stages: search (walk, scraps picked up by walking over them) -> choice -> reveal -> back to
## the turn that landed on it.

const SEARCH_TIME := 40.0
const CHOICE_TIME := 20.0
const REVEAL_TIME := 7.0
const WORDS := ["NOBODY", "WINS", "ALONE.", "PUT US", "BACK", "TOGETHER."]
const PICK_R := 1.1
const RACE_PRIZE := 10
const KEEP_EACH := 2

var core: MatchCore
var active := false
var stage := ""
var t := 0.0
var by := -1
var who: Array = []
var scraps: Array = []          # [{pos: Vector2, word, by}]
var choice: Dictionary = {}     # seat -> "keep" / "lay"
var result: Dictionary = {}
var times_whole := 0            # how often a table has made it whole (the AI learns)
var _paths: Dictionary = {}     # AI seat -> path
var _pause: Dictionary = {}     # AI seat -> seconds before it moves again (looking round)


func _init(c: MatchCore) -> void:
	core = c


func start(seat: int) -> void:
	active = true
	stage = "search"
	t = 0.0
	by = seat
	choice = {}
	result = {}
	_paths = {}
	_pause = {}
	who = []
	for p in core.players:
		if p.alive and not p.away() and p.location != "escaped":
			who.append(p.seat)
	_place()
	var fac := core.facility
	for s in who:
		var p := core.p(s)
		p.location = "away"
		p.pos = fac.building.nearest_walkable(fac.seat_pos(s) * 1.25, 1.5)
		p.away_t = 0.0
		p.away_late = false
		p.away_limit = SEARCH_TIME + CHOICE_TIME + 60.0   # the Caller doesn't mind: he sent you
		core.emit({"e": "leave", "seat": s, "pos": [p.pos.x, p.pos.y]})
		_pause[s] = core.rng.randf_range(2.5, 5.0)
	core._set_phase("search")
	core.emit({"e": "search", "stage": "search", "by": seat})
	core.toast("SEARCH THE ROOM! Whoever finds the most scraps wins %d Teeth." % RACE_PRIZE)


## Six scraps on open showroom floor: clear all round (not behind a curtain or in a prop),
## off the table, spread out. Falls back to the things in the room if the floor won't do.
func _place() -> void:
	var fac := core.facility
	var b := fac.building
	var picked: Array = []
	var tries := 0
	while picked.size() < WORDS.size() and tries < 4000:
		tries += 1
		var q := Vector2(core.rng.randf_range(-6.0, 6.0), core.rng.randf_range(-8.0, 5.5))
		if q.length() < 3.6 or b.area_at(q) != "hall":
			continue
		var clear := b.walkable(q)
		for o in [Vector2(0.7, 0), Vector2(-0.7, 0), Vector2(0, 0.7), Vector2(0, -0.7), Vector2(0.5, 0.5), Vector2(-0.5, -0.5)]:
			clear = clear and b.walkable(q + o)
		if not clear:
			continue
		var far := true
		for p in picked:
			if (p as Vector2).distance_to(q) < 2.6 - minf(1.4, tries / 1500.0):
				far = false
		if far:
			picked.append(q)
	if picked.size() < WORDS.size():
		var spots: Array = []
		for id in fac.things.keys():
			if str(fac.things[id].get("area", "hall")) == "hall":
				spots.append(b.nearest_walkable(fac.stand_at(id), 2.0))
		while picked.size() < WORDS.size() and not spots.is_empty():
			picked.append(spots.pop_back())
	scraps = []
	for i in WORDS.size():
		scraps.append({"pos": picked[i % picked.size()], "word": WORDS[i], "by": -1})


func tick(dt: float) -> void:
	if not active:
		return
	t += dt
	match stage:
		"search":
			for s in who:
				var p := core.p(s)
				if not p.away():
					continue
				if core.is_ai(s):
					_ai_walk(s, dt)
				for sc in scraps:
					if int(sc.by) < 0 and p.pos.distance_to(sc.pos) <= PICK_R:
						sc.by = s
						_pause[s] = core.rng.randf_range(1.5, 3.0)
						p.stat("scraps_found")
						core.emit({"e": "scrap", "seat": s, "word": sc.word, "left": _left()})
						core.toast("A scrap of paper. It says: \"%s\"" % sc.word, s)
			if _left() == 0 or t >= core._wait(SEARCH_TIME):
				_to_choice()
		"choice":
			var waiting := false
			for s in _holders():
				if not choice.has(s):
					waiting = true
			if not waiting or t >= core._wait(CHOICE_TIME):
				for s in _holders():
					if not choice.has(s):
						choice[s] = "keep"   # say nothing, keep what you've got
				_resolve()
		"reveal":
			if t >= core._wait(REVEAL_TIME):
				_finish()


func _left() -> int:
	return scraps.filter(func(sc): return int(sc.by) < 0).size()


func count(s: int) -> int:
	return scraps.filter(func(sc): return int(sc.by) == s).size()


func _holders() -> Array:
	return who.filter(func(s): return count(s) > 0 and core.p(s).alive)


func _to_choice() -> void:
	stage = "choice"
	t = 0.0
	for s in who:
		if core.p(s).away():
			core.facility.sit(s, false, "")
	for s in _holders():
		if core.is_ai(s):
			# a table that has seen the note made whole trusts it more
			var lay := 0.45 + 0.35 * minf(1.0, float(times_whole))
			choice[s] = "lay" if core.rng.randf() < lay else "keep"
	core.emit({"e": "search", "stage": "choice", "found": _left() == 0})


## The player's choice (secret until the reveal).
func choose(seat: int, keep: bool) -> void:
	if stage != "choice" or not _holders().has(seat) or choice.has(seat):
		return
	choice[seat] = "keep" if keep else "lay"
	core.emit({"e": "search_chosen", "seat": seat})


func _resolve() -> void:
	stage = "reveal"
	t = 0.0
	# the race (what everyone was told)
	var best := 0
	for s in who:
		best = maxi(best, count(s))
	var winners: Array = []
	if best > 0:
		for s in who:
			if count(s) == best:
				winners.append(s)
				core.economy.award(s, RACE_PRIZE, "most scraps", false)
	# the truth
	var all_found := _left() == 0
	var holders := _holders()
	var laid := 0
	var keepers: Array = []
	for s in holders:
		if choice.get(s, "keep") == "lay":
			laid += count(s)
		else:
			keepers.append(s)
	var whole := all_found and keepers.is_empty() and not holders.is_empty()
	if whole:
		times_whole += 1
		for s in who:
			if core.p(s).alive:
				core.change_rats(s, 1, "the note, whole")
	else:
		for s in keepers:
			core.economy.award(s, KEEP_EACH * count(s), "kept the scraps", false)
	result = {"winners": winners, "best": best, "whole": whole, "all_found": all_found, "laid": laid, "total": scraps.size(),
		"keepers": keepers if not whole else [], "choices": choice.duplicate(), "counts": _counts()}
	core.emit({"e": "search", "stage": "reveal", "result": result.duplicate(true)})
	if whole:
		core.toast("THE NOTE, WHOLE: \"NOBODY WINS ALONE. PUT US BACK TOGETHER.\" Everyone gets a DEAD RAT.")
	elif not all_found:
		core.toast("The note stays torn: %d of %d scraps were never found." % [_left(), scraps.size()])
	else:
		core.toast("The note stays torn: %d of %d pieces on the table. Somebody kept theirs." % [laid, scraps.size()])


func _counts() -> Dictionary:
	var d := {}
	for s in who:
		d[s] = count(s)
	return d


func _finish() -> void:
	active = false
	stage = ""
	for s in who:
		if core.p(s).away():
			core.facility.sit(s, false, "")
	core._set_phase("turn")
	core.rules._after()


## The AI heads for the nearest scrap nobody has, round the walls.
func _ai_walk(s: int, dt: float) -> void:
	var p := core.p(s)
	var fac := core.facility
	if float(_pause.get(s, 0.0)) > 0.0:
		_pause[s] = float(_pause[s]) - dt * (1.0 if not core.fast else 4.0)
		return
	var path: Array = _paths.get(s, [])
	if path.is_empty():
		var best = null
		var bd := INF
		for sc in scraps:
			if int(sc.by) < 0:
				var d := p.pos.distance_to(sc.pos)
				if d < bd:
					bd = d
					best = sc
		if best == null:
			return
		path = fac.building.find_path(p.pos, best.pos)
		if path.is_empty():
			path = [best.pos]
		_paths[s] = path
	var to: Vector2 = path[0]
	var step := fac.walk_speed * 0.5 * dt * (1.0 if not core.fast else 4.0)
	var d2 := to - p.pos
	if d2.length() <= step:
		p.pos = to
		path.pop_front()
	else:
		p.pos += d2.normalized() * step
		p.yaw = atan2(-d2.x, -d2.y)
	_paths[s] = path
	# someone else got there first: pick again
	for sc in scraps:
		if int(sc.by) >= 0 and not path.is_empty() and (path.back() as Vector2).distance_to(sc.pos) < 0.2:
			_paths.erase(s)


func view_for(me: int) -> Dictionary:
	var sc := []
	for x in scraps:
		sc.append({"pos": [x.pos.x, x.pos.y], "taken": int(x.by) >= 0, "mine": int(x.by) == me and me >= 0, "word": x.word if int(x.by) == me and me >= 0 else ""})
	var mine: Array = scraps.filter(func(x): return int(x.by) == me and me >= 0).map(func(x): return x.word)
	return {"active": active, "stage": stage, "t": t, "limit": SEARCH_TIME if stage == "search" else (CHOICE_TIME if stage == "choice" else REVEAL_TIME),
		"scraps": sc, "mine": mine, "left": _left(), "total": scraps.size(), "chose": choice.has(me), "holder": _holders().has(me),
		"chosen": choice.keys(), "result": result.duplicate(true) if stage == "reveal" else {}, "who": who.duplicate()}
