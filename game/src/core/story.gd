extends Node
## The record of what the player has done. Not a morality meter: a ledger of meaningful actions
## (who Kurt hurt, what he took, which routes he used, which clues he found, when he obeyed or
## ignored Socko) plus world flags. Systems query it to decide what happens next: Socko's mood,
## the infection, Marta's behaviour, the state Kurt arrives at Flat 48 in.
##
## Keys are plain strings, namespaced by convention:
##   violence.*   shot_marta, killed_marta, shot_at_nothing, struck
##   stealth.*    hid, broke_los, distracted, evaded
##   route.*      flat48_key, flat48_shot_lock, flat48_pried, flat48_balcony, flat48_vent ...
##   clue.*       read:<doc>, examined:<thing>
##   socko.*      obeyed, ignored
##   resource.*   fired, used:<item>
##   caught       times Marta caught Kurt

signal recorded(key: String, data: Dictionary)
signal flag_changed(key: String, value: Variant)

var flags := {}
var counters := {}
var ledger: Array = []        # [{t: seconds of play, key, data}]
var play_time := 0.0
var memory_points := 0        # memories Kurt has recovered (dialogue checks these)
var chapter := "flat47"       # flat47 | backrooms | flat48

func _process(delta: float) -> void:
	if not get_tree().paused:
		play_time += delta

func record(key: String, data := {}) -> void:
	ledger.append({"t": snappedf(play_time, 0.1), "key": key, "data": data})
	counters[key] = int(counters.get(key, 0)) + 1
	recorded.emit(key, data)

func count(key: String) -> int:
	return int(counters.get(key, 0))

## counts every key that starts with prefix ("violence." -> all violence)
func count_prefix(prefix: String) -> int:
	var n := 0
	for k in counters:
		if String(k).begins_with(prefix):
			n += int(counters[k])
	return n

func has(key: String) -> bool:
	return counters.has(key)

func flag(key: String, default: Variant = null) -> Variant:
	return flags.get(key, default)

func set_flag(key: String, value: Variant = true) -> void:
	if flags.get(key) == value:
		return
	flags[key] = value
	flag_changed.emit(key, value)

func add_memory(id: String) -> void:
	if has("memory:" + id):
		return
	record("memory:" + id)
	memory_points += 1

func reset() -> void:
	flags = {}
	counters = {}
	ledger = []
	play_time = 0.0
	memory_points = 0
	chapter = "flat47"

func to_dict() -> Dictionary:
	return {"flags": flags, "counters": counters, "ledger": ledger, "play_time": play_time,
		"memory_points": memory_points, "chapter": chapter}

func from_dict(d: Dictionary) -> void:
	flags = d.get("flags", {})
	counters = d.get("counters", {})
	ledger = d.get("ledger", [])
	play_time = float(d.get("play_time", 0.0))
	memory_points = int(d.get("memory_points", 0))
	chapter = String(d.get("chapter", "flat47"))

## How Kurt has been dealing with things, summarised for dialogue and the Flat 48 arrival.
## Each axis is a count of evidence, not a score to win.
func profile() -> Dictionary:
	return {
		"violence": count_prefix("violence."),
		"stealth": count_prefix("stealth."),
		"curiosity": count_prefix("clue."),
		"obeyed": count("socko.obeyed"),
		"ignored": count("socko.ignored"),
		"caught": count("caught"),
		"shots": count("resource.fired"),
	}
