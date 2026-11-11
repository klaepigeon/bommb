extends Node
## Kurt's two progressions. Memory (bought with memories: understanding) and Gameplay (bought
## with shards: the infection's gifts, from the Gutterspace and from killing). They aren't a
## morality meter: each has its own skills that change what Kurt can do, and they pull the
## world in opposite directions. aggression() is what the hunters read.

signal changed

var trees := {}
var owned := {}                 ## id -> true
var memories := 0               ## unspent
var shards := 0                 ## unspent
var memory_spent := 0
var gameplay_spent := 0
var found := {}                 ## what's given a memory or a shard already (one each)
var kills := 0

func _ready() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/skills.json"))
	trees = {"memory": d.memory, "gameplay": d.gameplay}
	World.register("progress", _save, _load)

func has(id: String) -> bool:
	return owned.has(id)

func skill(id: String) -> Dictionary:
	for t in trees:
		for s in trees[t]:
			if s.id == id: return s
	return {}

func tree_of(id: String) -> String:
	for t in trees:
		for s in trees[t]:
			if s.id == id: return t
	return ""

func can_buy(id: String) -> bool:
	var s := skill(id)
	if s.is_empty() or has(id): return false
	return (memories if tree_of(id) == "memory" else shards) >= int(s.cost)

func buy(id: String) -> bool:
	if not can_buy(id): return false
	var s := skill(id)
	if tree_of(id) == "memory":
		memories -= int(s.cost); memory_spent += int(s.cost)
	else:
		shards -= int(s.cost); gameplay_spent += int(s.cost)
	owned[id] = true
	Log.mark("skill " + id)
	World.emit_event("skill", {"id": id, "tree": tree_of(id)})
	changed.emit()
	return true

## A memory recovered by understanding something (once per key).
func remember(key: String, n := 1) -> bool:
	if found.has(key): return false
	found[key] = true
	memories += n
	World.emit_event("memory", {"key": key})
	changed.emit()
	return true

func gain_shards(key: String, n := 1) -> bool:
	if key != "" and found.has(key): return false
	if key != "": found[key] = true
	shards += n
	World.emit_event("shard", {"key": key, "n": n})
	changed.emit()
	return true

func killed(who: String) -> void:
	kills += 1
	gain_shards("kill_" + who, 3)

## How hard the building hunts: 1 at the start; the infection's skills and every kill sharpen
## it, what Kurt remembers softens it. 0.5 .. 2.0.
func aggression() -> float:
	return clampf(1.0 + gameplay_spent * 0.12 + kills * 0.15 - memory_spent * 0.1, 0.5, 2.0)

## How far the infection has got into Kurt (0..1): his eyes, the god's voice, Socko's patience.
func infection() -> float:
	return clampf((gameplay_spent + kills * 2) / 14.0, 0.0, 1.0)

func _save() -> Dictionary:
	return {"owned": owned, "memories": memories, "shards": shards, "ms": memory_spent, "gs": gameplay_spent, "found": found, "kills": kills}

func _load(d: Dictionary) -> void:
	owned = d.get("owned", {}); memories = int(d.get("memories", 0)); shards = int(d.get("shards", 0))
	memory_spent = int(d.get("ms", 0)); gameplay_spent = int(d.get("gs", 0)); found = d.get("found", {}); kills = int(d.get("kills", 0))
	changed.emit()
