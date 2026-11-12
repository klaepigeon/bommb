class_name Skills
## The two trees (docs/SKILLS.md). Memory: Kurt getting himself back, bought with memory points
## (found in the things people left behind). Infection: what the thing in him can do, bought with
## skill points (it grows when he's in it, when it's used, when it's fed).
##
## State lives on Game (Game.skills: unlocked ids; Game.memory_points, Game.skill_points;
## Game.memories counts the Memory nodes unlocked, which the dialogue's memory branches test).
## Effects are applied by apply(): into Game.stats (numbers the rest of the game reads) and
## flags the systems check with Skills.has().
##
## All of the writing for the Memory nodes (what he remembers) is the authors' to write: those
## texts are placeholders.

const PLACEHOLDER := "neenor neenor neenor neenor ki or Jules have to write this later neenor neenor neenor placeholder"

## id: {tree, name, cost, req (all of), tier (row in the UI), col, effect (mechanics, for the UI),
##      memory (Memory nodes: what he remembers: the authors' writing)}
const NODES := {
	# ---------------------------------------------------------------- Memory
	"m_1":        {"tree": "memory", "name": "Memory I", "cost": 1, "req": [], "tier": 0, "col": 1,
		"effect": "Kurt remembers something. His memory comes into what he says.", "memory": PLACEHOLDER},
	"m_talk":     {"tree": "memory", "name": "Talkative", "cost": 1, "req": ["m_1"], "tier": 1, "col": 0,
		"effect": "He and Socko talk twice as often."},
	"m_resource": {"tree": "memory", "name": "Resourceful", "cost": 1, "req": ["m_1"], "tier": 1, "col": 1,
		"effect": "Things he hits with wear out a third slower. Searching turns up extra rounds."},
	"m_observe":  {"tree": "memory", "name": "Observant", "cost": 1, "req": ["m_1"], "tier": 1, "col": 2,
		"effect": "When she makes a sound nearby he knows where it came from. He can tell how good a weapon something would make."},
	"m_2":        {"tree": "memory", "name": "Memory II", "cost": 1, "req": ["m_1"], "tier": 2, "col": 1,
		"effect": "Kurt remembers more. Unlocks [Memory] choices that need two memories.", "memory": PLACEHOLDER},
	"m_training": {"tree": "memory", "name": "Old Training", "cost": 2, "req": ["m_2"], "tier": 3, "col": 0,
		"effect": "Heavy blows wind up in half the time. Crouched, he moves a third faster."},
	"m_3":        {"tree": "memory", "name": "Memory III", "cost": 2, "req": ["m_2"], "tier": 3, "col": 2,
		"effect": "Kurt remembers more. Unlocks [Memory] choices that need three memories.", "memory": PLACEHOLDER},
	# ---------------------------------------------------------------- Infection
	"s_sinew":    {"tree": "infection", "name": "Sinew", "cost": 1, "req": [], "tier": 0, "col": 0,
		"effect": "Strength x1.25: every blow hits harder."},
	"s_lungs":    {"tree": "infection", "name": "Lungs", "cost": 1, "req": [], "tier": 0, "col": 1,
		"effect": "Half as much stamina again, for running and for blows."},
	"s_tk":       {"tree": "infection", "name": "Telekinesis", "cost": 1, "req": [], "tier": 0, "col": 2,
		"effect": "POWER at a loose thing within 8 m (up to 6 kg) pulls it into his hand. Costs strain."},
	"s_sinew2":   {"tree": "infection", "name": "Sinew II", "cost": 2, "req": ["s_sinew"], "tier": 1, "col": 0,
		"effect": "Strength x1.5, and blows cost a quarter less stamina."},
	"s_quiet":    {"tree": "infection", "name": "Soft Tread", "cost": 1, "req": ["s_lungs"], "tier": 1, "col": 1,
		"effect": "His footsteps make 40% less noise."},
	"s_shove":    {"tree": "infection", "name": "Telekinetic Shove", "cost": 2, "req": ["s_tk"], "tier": 1, "col": 2,
		"effect": "POWER at her: a shove from up to 8 m that takes half her poise and throws her back. Costs more strain."},
	"s_breach":   {"tree": "infection", "name": "Breach", "cost": 2, "req": ["s_sinew"], "tier": 2, "col": 0,
		"effect": "A heavy blow (fist or blunt) goes through cracked walls."},
	"s_telepathy":{"tree": "infection", "name": "Telepathy", "cost": 2, "req": ["s_tk"], "tier": 2, "col": 2,
		"effect": "[Telepathy] choices in conversation. POWER with nothing in reach: for three seconds he sees her through walls."},
	"s_reaper":   {"tree": "infection", "name": "Coup de Grace", "cost": 3, "req": ["s_sinew2", "s_shove"], "tier": 3, "col": 1,
		"effect": "A heavy blow with a blade or an axe kills her outright if she's stunned, or if he's behind her and she hasn't seen him."},
}

const STRAIN_COST := {"pull": 0.25, "shove": 0.5, "listen": 0.5}

static func has(id: String) -> bool:
	return Game.skills.has(id)

static func can_unlock(id: String) -> bool:
	if has(id) or not NODES.has(id): return false
	var n: Dictionary = NODES[id]
	for r in n.req:
		if not has(r): return false
	return points(n.tree) >= int(n.cost)

static func points(tree: String) -> int:
	return Game.memory_points if tree == "memory" else Game.skill_points

static func unlock(id: String) -> bool:
	if not can_unlock(id): return false
	var n: Dictionary = NODES[id]
	if n.tree == "memory":
		Game.memory_points -= int(n.cost)
		if String(id).begins_with("m_") and n.has("memory"): Game.memories += 1
	else:
		Game.skill_points -= int(n.cost)
	Game.skills[id] = true
	apply()
	return true

## Earn points (the levels call this when he finds something of theirs, when the infection
## grows). `why` is for the HUD's note.
static func award(tree: String, n := 1, why := "") -> void:
	if tree == "memory": Game.memory_points += n
	else: Game.skill_points += n
	var lv = Game.level
	if lv and lv.get("hud"): lv.hud.hint(("+%d memory" if tree == "memory" else "+%d infection") % n + ("  ·  " + why if why != "" else "") + "  ·  SKILLS: Tab", 4.0)

## The numbers everything else reads (Game.stat).
static func apply() -> void:
	var s := {}
	s["strength"] = 1.5 if has("s_sinew2") else (1.25 if has("s_sinew") else 1.0)
	s["stamina_max"] = 1.5 if has("s_lungs") else 1.0
	s["blow_stamina"] = 0.75 if has("s_sinew2") else 1.0
	s["noise"] = 0.6 if has("s_quiet") else 1.0
	s["wear_chance"] = 0.67 if has("m_resource") else 1.0
	s["heavy_charge"] = 0.5 if has("m_training") else 1.0
	s["crouch_speed"] = 1.33 if has("m_training") else 1.0
	s["talk_rate"] = 2.0 if has("m_talk") else 1.0
	Game.stats = s
