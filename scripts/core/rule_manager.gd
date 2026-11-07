class_name RuleManager
extends RefCounted
## The rulebook (assets/data/rules.json): amendments that change the match while it's on.
## Squares (RULEBOOK adds one, VETO strikes one), items (gavel, loophole, rubber stamp,
## emergency legislation, executive privilege) and, in THE CALLER'S GAME, the Caller
## himself every few rounds. Each rule sets effect keys; everything that a rule can change
## asks value(key, default, seat). Contradictions: the higher priority wins, then the newer
## rule. At most `limit` at once. Nothing here can touch the win condition (most Dead Rats).

var core: MatchCore
var catalogue: Dictionary = {}
var limit := 5
var active: Array = []      # [{id, left (rounds, 0 = permanent), n (order added), by}]
var _n := 0


func _init(c: MatchCore) -> void:
	core = c
	var d := Assets.load_json("res://assets/data/rules.json")
	catalogue = d.get("rules", {})
	limit = int(d.get("limit", 5))


func is_active(id: String) -> bool:
	for r in active:
		if r.id == id:
			return true
	return false


## What the rules say about `key` (for `seat`: a loophole means they don't apply to you).
func value(key: String, default = null, seat := -1):
	if seat >= 0 and seat < core.players.size() and core.p(seat).loophole > 0:
		return default
	var best = null
	var best_pri := -999
	var best_n := -1
	for r in active:
		var d: Dictionary = catalogue.get(r.id, {})
		var fx: Dictionary = d.get("effects", {})
		if not fx.has(key):
			continue
		var pri := int(d.get("priority", 1))
		if pri > best_pri or (pri == best_pri and int(r.n) > best_n):
			best = fx[key]
			best_pri = pri
			best_n = int(r.n)
	return default if best == null else best


func add(id: String, by := -1) -> bool:
	if not catalogue.has(id) or is_active(id):
		return false
	if active.size() >= limit:
		var victim := -1
		for i in active.size():
			if int(active[i].left) > 0:
				victim = i
				break
		repeal_at(victim if victim >= 0 else 0, "make room")
	_n += 1
	active.append({"id": id, "left": int(catalogue[id].get("turns", 0)), "n": _n, "by": by})
	var d: Dictionary = catalogue[id]
	core.emit({"e": "rule", "id": id, "name": d.name, "desc": d.desc, "by": by})
	core.say("rule_add", {"rule": str(d.name)})
	core.toast("NEW AMENDMENT: %s. %s%s" % [d.name, d.desc, "" if int(d.get("turns", 0)) == 0 else " (%d rounds)" % int(d.turns)])
	return true


## A random amendment that isn't in force.
func add_random(by := -1) -> String:
	var pool := catalogue.keys().filter(func(k): return not is_active(k))
	if pool.is_empty():
		return ""
	pool.sort()
	var id: String = pool[core.rng.randi_range(0, pool.size() - 1)]
	add(id, by)
	return id


## Three to choose from (the gavel).
func offer(n := 3) -> Array:
	var pool := catalogue.keys().filter(func(k): return not is_active(k))
	pool.sort()
	var out := []
	while out.size() < n and not pool.is_empty():
		out.append(pool.pop_at(core.rng.randi_range(0, pool.size() - 1)))
	return out


func repeal(id: String, why := "") -> bool:
	for i in active.size():
		if active[i].id == id:
			repeal_at(i, why)
			return true
	return false


func repeal_at(i: int, why := "") -> void:
	if i < 0 or i >= active.size():
		return
	var r: Dictionary = active.pop_at(i)
	core.emit({"e": "rule_repeal", "id": r.id, "why": why})
	core.toast("REPEALED: %s%s." % [catalogue[r.id].name, "" if why == "" else " (%s)" % why])


func repeal_temporary() -> int:
	var n := 0
	for i in range(active.size() - 1, -1, -1):
		if int(active[i].left) > 0:
			repeal_at(i, "emergency legislation")
			n += 1
	return n


func extend(n: int) -> void:
	for r in active:
		if int(r.left) > 0:
			r.left = int(r.left) + n


## End of a round: temporary amendments run down.
func end_round() -> void:
	for i in range(active.size() - 1, -1, -1):
		if int(active[i].left) > 0:
			active[i].left = int(active[i].left) - 1
			if int(active[i].left) <= 0:
				repeal_at(i, "expired")


func view() -> Array:
	var out := []
	for r in active:
		var d: Dictionary = catalogue[r.id]
		out.append({"id": r.id, "name": d.name, "desc": d.desc, "left": r.left})
	return out


func to_save() -> Dictionary:
	return {"active": active.duplicate(true), "n": _n}


func load_save(d: Dictionary) -> void:
	active = d.get("active", []).duplicate(true)
	for r in active:
		r.left = int(r.left)
		r.n = int(r.n)
		r.by = int(r.by)
	_n = int(d.get("n", 0))
