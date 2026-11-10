class_name ThreatManager
## How dangerous the pursuer is right now, and in what ways (master document §29–30;
## content/threat.json holds the tuning). One score from: a base, each owned skill's contribution
## (Survival up, Memory down), story flags, what Kurt has done lately (shots fired, an axe on a
## chain), and difficulty. The pursuer never reads the score itself: it reads levers (hearing,
## sight, pace, persistence, alertness, recovery), each mapped from the score through three
## points (at the minimum, at 1, at the maximum), so "more dangerous" means she hears further,
## commits faster, searches longer and keeps tracking him after she's lost him, not more health.

const PATH := "res://content/threat.json"
static var _cfg := {}
static var _recent := {}          # what -> time (s) it last happened
static var difficulty := "normal"

static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_cfg = d if d is Dictionary else {"base": 1.0, "min": 0.5, "max": 2.2}
	return _cfg

static func now() -> float:
	return Time.get_ticks_msec() / 1000.0

## Something Kurt did that keys her up for a while (Noises calls this for every noise).
static func note(what: String) -> void:
	if (cfg().get("recent", {}) as Dictionary).has(what): _recent[what] = now()

static func forget_recent() -> void:
	_recent.clear()

## The score, and where it comes from (for the monster inspector and tests).
static func breakdown() -> Dictionary:
	var c := cfg()
	var out := {"base": float(c.get("base", 1.0))}
	var defaults: Dictionary = c.get("skill_default", {})
	var per: Dictionary = c.get("skills", {})
	for tree in Skills.TREES:
		for s in Skills.TREES[tree]:
			if Skills.owned(s.id):
				out["skill:" + s.id] = float(per.get(s.id, defaults.get(tree, 0.0)))
	var f: Dictionary = WorldState.flags()
	for k in (c.get("flags", {}) as Dictionary):
		if f.get(k, false): out["flag:" + k] = float(c.flags[k])
	for k in _recent:
		var r: Dictionary = c.recent[k]
		var age := now() - float(_recent[k])
		var fade := float(r.get("fade", 30.0))
		if age < fade: out["recent:" + k] = float(r.get("add", 0.0)) * (1.0 - age / fade)
	out["difficulty"] = float((c.get("difficulty", {}) as Dictionary).get(difficulty, 1.0))
	return out

static func score() -> float:
	var c := cfg()
	var b := breakdown()
	var s := 0.0
	for k in b:
		if k != "difficulty": s += float(b[k])
	return clampf(s * float(b.difficulty), float(c.get("min", 0.5)), float(c.get("max", 2.2)))

## A lever's value at the current score: piecewise linear through its three points.
static func lever(name: String) -> float:
	var c := cfg()
	var l: Dictionary = (c.get("levers", {}) as Dictionary).get(name, {})
	if l.is_empty(): return score()
	var s := score()
	var lo := float(c.get("min", 0.5)); var hi := float(c.get("max", 2.2))
	if s <= 1.0: return lerpf(float(l.at_min), float(l.at_1), inverse_lerp(lo, 1.0, s))
	return lerpf(float(l.at_1), float(l.at_max), inverse_lerp(1.0, hi, s))

static func levers() -> Dictionary:
	var out := {}
	for k in (cfg().get("levers", {}) as Dictionary): out[k] = lever(k)
	return out
