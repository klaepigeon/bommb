class_name Skills
## The two skill trees and the gutterspace nuggets that pay for them. Anything can be bought, in
## any order. Survival makes Kurt more dangerous and makes the things hunting him more dangerous
## too; Memory gives him back pieces of himself, shows him more of the story, and calms them.
## (Story bible §2c; the design doc's two-tree / pursuer relationship.)
##
## State lives in Game.flags ("nuggets", "skills": {id: true}) so it goes wherever the flags go.

const TREES := {
	"survival": [
		{"id": "headshot", "name": "Headshot", "cost": 8, "desc": "A shot to the head kills outright.", "socko": true},
		{"id": "steady", "name": "Steady Hand", "cost": 4, "desc": "The revolver kicks less and comes back on target faster."},
		{"id": "quick_reload", "name": "Quick Reload", "cost": 5, "desc": "A round into the gate in a fifth of a second."},
		{"id": "quiet_feet", "name": "Quiet Feet", "cost": 4, "desc": "You walk like a man who's been somewhere he shouldn't. Footsteps carry less."},
		{"id": "second_wind", "name": "Second Wind", "cost": 3, "desc": "Your breath comes back faster after running."},
		{"id": "deep_pockets", "name": "Deep Pockets", "cost": 3, "desc": "Seven more rounds, from a coat pocket you didn't know you had."},
	],
	"memory": [
		{"id": "handwriting", "name": "Her Handwriting", "cost": 5, "desc": "You know whose hand that is. Letters and notes tell you more."},
		{"id": "the_bow", "name": "The Bow", "cost": 4, "desc": "Your shoulders remember drawing it. Things you throw go where you mean them to."},
		{"id": "how_she_moves", "name": "How She Moves", "cost": 5, "desc": "You've fought her before. You can feel where she is when she's close."},
		{"id": "these_streets", "name": "These Streets", "cost": 3, "desc": "You know this town. You notice when a street comes round on itself."},
		{"id": "sonya", "name": "Counting", "cost": 6, "desc": "A girl's voice, counting, somewhere. You know which way it is."},
	],
}

static func _flags() -> Dictionary:
	return Engine.get_main_loop().root.get_node("Game").get("flags")

static func nuggets() -> int:
	return int(_flags().get("nuggets", 0))

static func add_nuggets(n: int) -> void:
	_flags()["nuggets"] = nuggets() + n

static func owned(id: String) -> bool:
	return bool((_flags().get("skills", {}) as Dictionary).get(id, false))

static func find(id: String) -> Dictionary:
	for tree in TREES:
		for s in TREES[tree]:
			if s.id == id: return s
	return {}

static func tree_of(id: String) -> String:
	for tree in TREES:
		for s in TREES[tree]:
			if s.id == id: return tree
	return ""

static func can_buy(id: String) -> bool:
	var s := find(id)
	return not s.is_empty() and not owned(id) and nuggets() >= int(s.cost)

static func buy(id: String) -> bool:
	if not can_buy(id): return false
	var f := _flags()
	f["nuggets"] = nuggets() - int(find(id).cost)
	var owned_d: Dictionary = f.get("skills", {})
	owned_d[id] = true
	f["skills"] = owned_d
	return true

static func count(tree: String) -> int:
	var n := 0
	for s in TREES[tree]:
		if owned(s.id): n += 1
	return n

## How hard the things hunting him come at him: more Survival, harder; more Memory, softer.
## kept for older callers: the threat manager's score (content/threat.json)
static func aggression() -> float:
	return ThreatManager.score()
