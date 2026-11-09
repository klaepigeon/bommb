class_name WorldState
## What dialogue conditions read and dialogue consequences write: the game's flags (Game.flags,
## saved with everything else), plus per-character knowledge and relationships, kept apart so
## that nobody knows a thing just because Kurt found it out somewhere else.
##
##   Game.flags["npc"][id] = {"knows": {fact: true}, "rel": {"trust": 0, "fear": 0, ...}}
##
## Conditions are short strings, all of which must hold:
##   "flag:marta_at_peace"         a flag is set (truthy)       "!flag:marta_dead"  it isn't
##   "skill:handwriting"           a skill is owned             "!skill:..."
##   "knows:marta:kurt_said_name"  a character knows a fact     "!knows:..."
##   "rel:marta.trust>=1"          a relationship dimension compared (>=, <=, >, <, ==)
##   "memory>=2"                   how many Memory skills are owned
##   "seen:node_id"                this conversation already passed through a node
## Actions:
##   "set:flag_name"  "set:flag_name=value"  "unset:flag_name"
##   "know:marta:fact"   "rel:marta.trust+=1"   "rel:marta.fear-=1"

static func flags() -> Dictionary:
	return Engine.get_main_loop().root.get_node("Game").get("flags")

static func npc(id: String) -> Dictionary:
	var all: Dictionary = flags().get_or_add("npc", {})
	var d: Dictionary = all.get_or_add(id, {})
	d.get_or_add("knows", {}); d.get_or_add("rel", {})
	return d

static func rel(id: String, dim: String) -> float:
	return float((npc(id).rel as Dictionary).get(dim, 0))

static func knows(id: String, fact: String) -> bool:
	return bool((npc(id).knows as Dictionary).get(fact, false))

static func check_all(conds: Array, seen := {}) -> bool:
	for c in conds:
		if not check(String(c), seen): return false
	return true

static func check(c: String, seen := {}) -> bool:
	var neg := c.begins_with("!")
	if neg: c = c.substr(1)
	var r := _check(c, seen)
	return not r if neg else r

static func _check(c: String, seen: Dictionary) -> bool:
	if c.begins_with("flag:"): return bool(flags().get(c.substr(5), false))
	if c.begins_with("skill:"): return Skills.owned(c.substr(6))
	if c.begins_with("seen:"): return seen.has(c.substr(5))
	if c.begins_with("knows:"):
		var p := c.substr(6).split(":")
		return p.size() == 2 and knows(p[0], p[1])
	if c.begins_with("rel:") or c.begins_with("memory"):
		for op in [">=", "<=", "==", ">", "<"]:
			var i := c.find(op)
			if i < 0: continue
			var lhs := c.substr(0, i); var rhs := float(c.substr(i + op.length()))
			var v := 0.0
			if lhs == "memory":
				for s in Skills.TREES.memory: if Skills.owned(s.id): v += 1.0
			else:
				var q := lhs.substr(4).split(".")
				if q.size() != 2: return false
				v = rel(q[0], q[1])
			match op:
				">=": return v >= rhs
				"<=": return v <= rhs
				"==": return is_equal_approx(v, rhs)
				">": return v > rhs
				"<": return v < rhs
	push_warning("WorldState: unknown condition '%s'" % c)
	return false

static func apply_all(actions: Array) -> void:
	for a in actions: apply(String(a))

static func apply(a: String) -> void:
	if a.begins_with("set:"):
		var kv := a.substr(4).split("=", true, 1)
		flags()[kv[0]] = (true if kv.size() == 1 else _value(kv[1]))
	elif a.begins_with("unset:"):
		flags().erase(a.substr(6))
	elif a.begins_with("know:"):
		var p := a.substr(5).split(":")
		if p.size() == 2: (npc(p[0]).knows as Dictionary)[p[1]] = true
	elif a.begins_with("rel:"):
		for op in ["+=", "-=", "="]:
			var i := a.find(op)
			if i < 0: continue
			var q := a.substr(4, i - 4).split(".")
			var v := float(a.substr(i + op.length()))
			var r: Dictionary = npc(q[0]).rel
			match op:
				"+=": r[q[1]] = float(r.get(q[1], 0)) + v
				"-=": r[q[1]] = float(r.get(q[1], 0)) - v
				"=": r[q[1]] = v
			return
	else:
		push_warning("WorldState: unknown action '%s'" % a)

static func _value(s: String) -> Variant:
	if s == "true": return true
	if s == "false": return false
	if s.is_valid_int(): return int(s)
	if s.is_valid_float(): return float(s)
	return s
