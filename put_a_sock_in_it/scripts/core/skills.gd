class_name Skills
## The two trees (docs/SKILLS.md), bought from ONE pool of points (Game.points). Memory: Kurt
## getting himself back. Infection: what the thing in him can do. Every point is one or the
## other: what he remembers is what he didn't let it have, and the other way about. Points come
## from what brings something back to him, from the infection growing, and from what he kills
## (it feeds).
##
## State lives on Game (Game.skills: unlocked ids; Game.points; Game.memories counts the Memory
## nodes unlocked, which the dialogue's memory branches test). Effects are applied by apply():
## into Game.stats (numbers the rest of the game reads) and flags the systems check with has().
## How far he's gone (lean(): -1 all memory .. +1 all infection) shows on his arm, and the
## dialogue can test it (`lean > 0.5`).
##
## All of the writing for the Memory nodes (what he remembers) is the authors' to write: those
## texts are placeholders.

const PLACEHOLDER := "neenor neenor neenor neenor ki or Jules have to write this later neenor neenor neenor placeholder"
const POINT := "point"          # (what the HUD calls one)

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
	"m_people":   {"tree": "memory", "name": "Read People", "cost": 1, "req": ["m_talk"], "tier": 2, "col": 0,
		"effect": "In conversation he can tell how each thing he could say will land, and how the other one feels about him right now."},
	"m_2":        {"tree": "memory", "name": "Memory II", "cost": 1, "req": ["m_1"], "tier": 2, "col": 1,
		"effect": "Kurt remembers more. Unlocks [Memory] choices that need two memories.", "memory": PLACEHOLDER},
	"m_steady":   {"tree": "memory", "name": "Steady", "cost": 1, "req": ["m_observe"], "tier": 2, "col": 2,
		"effect": "Fear builds a third slower, so his hands shake less and his aim holds."},
	"m_training": {"tree": "memory", "name": "Old Training", "cost": 2, "req": ["m_2"], "tier": 3, "col": 0,
		"effect": "Heavy blows wind up in half the time. Crouched, he moves a third faster."},
	"m_aid":      {"tree": "memory", "name": "First Aid", "cost": 1, "req": ["m_2"], "tier": 3, "col": 1,
		"effect": "Out of danger, crouched and still, he patches himself up four times faster."},
	"m_3":        {"tree": "memory", "name": "Memory III", "cost": 2, "req": ["m_2"], "tier": 3, "col": 2,
		"effect": "Kurt remembers more. Unlocks [Memory] choices that need three memories.", "memory": PLACEHOLDER},
	"m_locks":    {"tree": "memory", "name": "Locksmith", "cost": 2, "req": ["m_training"], "tier": 4, "col": 1,
		"effect": "He can work a lock open with what's in his pockets. Slow, but quiet, where a crowbar is loud."},
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
		"effect": "POWER at something that wants him dead: a shove from up to 8 m that breaks its stance and throws it back. Costs more strain."},
	"s_breach":   {"tree": "infection", "name": "Breach", "cost": 2, "req": ["s_sinew"], "tier": 2, "col": 0,
		"effect": "A heavy blow (fist or blunt) goes through cracked walls."},
	"s_regrow":   {"tree": "infection", "name": "Regrowth", "cost": 1, "req": ["s_lungs"], "tier": 2, "col": 1,
		"effect": "What's torn knits: he heals two and a half times as fast, and starts sooner."},
	"s_telepathy":{"tree": "infection", "name": "Telepathy", "cost": 2, "req": ["s_tk"], "tier": 2, "col": 2,
		"effect": "[Telepathy] choices in conversation. POWER with nothing in reach: for three seconds he sees everything alive near him through the walls."},
	"s_feed":     {"tree": "infection", "name": "Feed", "cost": 2, "req": ["s_sinew2"], "tier": 3, "col": 0,
		"effect": "What he kills, it eats: a kill heals him and gives back his strain."},
	"s_shade":    {"tree": "infection", "name": "Shade", "cost": 1, "req": ["s_quiet"], "tier": 3, "col": 1,
		"effect": "Out of the light, eyes slide off him: they see him half as far."},
	"s_voice":    {"tree": "infection", "name": "Throw Voice", "cost": 2, "req": ["s_telepathy"], "tier": 3, "col": 2,
		"effect": "POWER while crouched: a sound where he's looking (up to 20 m). Whatever listens goes to look."},
	"s_reaper":   {"tree": "infection", "name": "Coup de Grace", "cost": 3, "req": ["s_sinew2", "s_shove"], "tier": 4, "col": 1,
		"effect": "A heavy blow with a blade or an axe kills outright anything that's reeling, or that hasn't seen him and has its back to him."},
}

const STRAIN_COST := {"pull": 0.25, "shove": 0.5, "listen": 0.5, "voice": 0.3}

static func has(id: String) -> bool:
	return Game.skills.has(id)

static func can_unlock(id: String) -> bool:
	if has(id) or not NODES.has(id): return false
	var n: Dictionary = NODES[id]
	for r in n.req:
		if not has(r): return false
	return Game.points >= int(n.cost)

static func points(_tree := "") -> int:
	return Game.points

static func unlock(id: String) -> bool:
	if not can_unlock(id): return false
	var n: Dictionary = NODES[id]
	Game.points -= int(n.cost)
	if n.tree == "memory" and n.has("memory"): Game.memories += 1
	Game.skills[id] = true
	apply()
	return true

## Points spent in a tree.
static func spent(tree: String) -> int:
	var t := 0
	for id in Game.skills:
		if NODES.has(id) and NODES[id].tree == tree: t += int(NODES[id].cost)
	return t

## How far he's gone: -1 (all memory) .. 0 (even, or nothing yet) .. +1 (all infection).
static func lean() -> float:
	var m := spent("memory"); var i := spent("infection")
	return 0.0 if m + i == 0 else float(i - m) / float(m + i)

## Earn points (the levels call this when he finds something that brings something back, when
## the infection grows, when he kills). `kind` is "memory", "infection" or "feed": only what the
## HUD says about it, they're all the same points. `why` is for the HUD's note.
static func award(kind: String, n := 1, why := "") -> void:
	Game.points += n
	var lv = Game.level
	var what: String = {"memory": "something comes back", "infection": "it grows", "feed": "it feeds"}.get(kind, "")
	if lv and lv.get("hud"): lv.hud.hint("+%d %s%s  ·  %s%s  ·  SKILLS: Tab" % [n, POINT, "" if n == 1 else "s", what, ("  ·  " + why if why != "" else "")], 4.0)

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
	s["fear_rise"] = 0.67 if has("m_steady") else 1.0
	s["regen"] = 2.5 if has("s_regrow") else 1.0
	s["regen_delay"] = 4.0 if has("s_regrow") else 9.0
	s["seen_dark"] = 0.5 if has("s_shade") else 1.0
	Game.stats = s
