class_name CheatingManager
extends RefCounted
## Cheating, anywhere: at the table, in the room, in Russian Roulette, in the games. A
## cheat isn't a bonus button: it works only if he doesn't see it (SuspicionManager.sees:
## watching = caught, looking away = fine, the shudder as he turns = a coin toss), it
## always adds a little to your file even when it works, and getting caught adds a lot,
## loses you what you were after and draws his attention. Catalogue: assets/data/cheats.json.

var core: MatchCore
var catalogue: Dictionary = {}
var used_once: Dictionary = {}     # "seat:id" -> true


func _init(c: MatchCore) -> void:
	core = c
	catalogue = Assets.load_json("res://assets/data/cheats.json").get("cheats", {})


func available(seat: int, context: String) -> Array:
	var out := []
	for id in catalogue.keys():
		var d: Dictionary = catalogue[id]
		if d.context == context and not used_once.has("%d:%s" % [seat, id]):
			out.append(id)
	return out


## Try it. Returns true if it worked (and he didn't see).
func attempt(seat: int, id: String, label := "") -> bool:
	var d: Dictionary = catalogue.get(id, {"ok": 6, "caught": 18, "name": id.to_upper()})
	if d.get("once", false):
		var k := "%d:%s" % [seat, id]
		if used_once.has(k):
			return false
		used_once[k] = true
	var nm := core.p(seat).name
	var what := label if label != "" else str(d.get("name", id))
	if core.suspicion.sees(seat):
		core.emit({"e": "caught", "seat": seat, "cheat": id, "what": what})
		core.say("caught", {"name": nm, "what": what.to_lower()})
		core.toast("CAUGHT: %s tried to %s." % [nm, what.to_lower()])
		core.suspicion.add(seat, int(d.get("caught", 18)), "caught: " + id)
		if core.p(seat).suspicion >= 50 and core.p(seat).alive:
			core.cage.tighten(seat, "caught")
		for o in core.living():
			core.brains[o].saw_cheat(seat, true)
		core.p(seat).stat("cheats_caught")
		return false
	core.suspicion.add(seat, int(d.get("ok", 6)), id)
	core.emit({"e": "cheat", "seat": seat, "cheat": id})
	core.p(seat).stat("cheats_ok")
	core.toast("You %s. He didn't see." % what.to_lower(), seat)
	return true
