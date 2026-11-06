class_name CallerLines
extends RefCounted
## Picks what the Caller says (assets/data/caller_lines.json). The host picks, so every
## screen shows the same line. Lines can be limited to an unrest band: as the contestants
## undermine the game he gets stranger.

static var _lines: Dictionary = {}


static func lines() -> Dictionary:
	if _lines.is_empty():
		_lines = Assets.load_json("res://assets/data/caller_lines.json") if Engine.get_main_loop() else {}
	return _lines


static func pick(key: String, unrest: float, rng: RandomNumberGenerator, params := {}) -> Dictionary:
	var pool: Array = lines().get(key, [])
	if pool.is_empty():
		return {}
	var band := int(floor(unrest))
	var any := []
	var banded := []
	for l in pool:
		var u: Array = l.get("unrest", [])
		if u.is_empty():
			any.append(l)
		elif band >= int(u[0]) and band <= int(u[1]):
			banded.append(l)
	var choose: Array = banded if (not banded.is_empty() and (any.is_empty() or rng.randf() < 0.6)) else any
	if choose.is_empty():
		choose = pool
	var i := rng.randi_range(0, choose.size() - 1)
	var l: Dictionary = choose[i]
	var text := str(l.text)
	for k in params.keys():
		text = text.replace("{" + str(k) + "}", str(params[k]))
	return {"id": "%s_%d" % [key, pool.find(l)], "text": text, "gesture": str(l.get("gesture", "talk")), "mood": str(l.get("mood", "calm"))}
