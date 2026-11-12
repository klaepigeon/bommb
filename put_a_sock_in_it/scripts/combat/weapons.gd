class_name Weapons
## Melee: what anything Kurt can pick up does when he hits something with it (docs/MELEE.md).
##
## A held prop is classified once, by what it's called and how heavy it is, into a class; the
## class gives its numbers. Its durability lives on the prop (meta "durability"), so a hammer
## that's been used stays used if he drops it and picks it up again.
##
## Numbers per class:
##   dmg        damage to her poise (light attack)          windup    seconds before the hit lands
##   reach      metres from the eye                          recover   seconds after, before another
##   knock      shove (m/s) on what's hit                    stamina   seconds of Kurt's stamina it costs
##   dur        hits before it breaks (-1: never)            noise     how loud a hit is (0..1)
##   breaks     what it breaks into ("" : nothing)           kind      "blunt", "sharp", "glass", "soft"
## A heavy attack (hold, then release) does HEAVY times as much, slower and dearer.

const HEAVY := {"dmg": 1.8, "knock": 1.6, "windup": 2.2, "recover": 1.4, "stamina": 1.6, "wear": 2}

const CLASSES := {
	"fist":    {"dmg": 6.0,  "windup": 0.07, "recover": 0.28, "reach": 0.95, "knock": 0.6, "stamina": 0.25, "dur": -1, "noise": 0.25, "breaks": "", "kind": "blunt"},
	"flimsy":  {"dmg": 3.0,  "windup": 0.10, "recover": 0.30, "reach": 1.05, "knock": 0.3, "stamina": 0.20, "dur": 12, "noise": 0.15, "breaks": "", "kind": "soft"},
	"brittle": {"dmg": 9.0,  "windup": 0.12, "recover": 0.32, "reach": 1.05, "knock": 0.8, "stamina": 0.30, "dur": 1,  "noise": 0.75, "breaks": "shard", "kind": "glass"},
	"blunt":   {"dmg": 11.0, "windup": 0.16, "recover": 0.38, "reach": 1.15, "knock": 1.2, "stamina": 0.35, "dur": 10, "noise": 0.5, "breaks": "", "kind": "blunt"},
	"tool":    {"dmg": 18.0, "windup": 0.18, "recover": 0.42, "reach": 1.15, "knock": 1.4, "stamina": 0.40, "dur": 30, "noise": 0.45, "breaks": "", "kind": "blunt"},
	"blade":   {"dmg": 15.0, "windup": 0.10, "recover": 0.28, "reach": 1.05, "knock": 0.4, "stamina": 0.25, "dur": 14, "noise": 0.2, "breaks": "", "kind": "sharp"},
	"shard":   {"dmg": 12.0, "windup": 0.09, "recover": 0.26, "reach": 0.95, "knock": 0.3, "stamina": 0.22, "dur": 4,  "noise": 0.2, "breaks": "", "kind": "sharp"},
	"chop":    {"dmg": 30.0, "windup": 0.38, "recover": 0.70, "reach": 1.35, "knock": 2.2, "stamina": 0.80, "dur": 25, "noise": 0.6, "breaks": "", "kind": "sharp"},
	"long":    {"dmg": 14.0, "windup": 0.30, "recover": 0.60, "reach": 1.80, "knock": 2.6, "stamina": 0.70, "dur": 6,  "noise": 0.8, "breaks": "pole", "kind": "blunt"},
	"pole":    {"dmg": 12.0, "windup": 0.26, "recover": 0.55, "reach": 1.70, "knock": 2.2, "stamina": 0.60, "dur": 6,  "noise": 0.6, "breaks": "", "kind": "blunt"},
	"heavy":   {"dmg": 24.0, "windup": 0.50, "recover": 0.85, "reach": 1.30, "knock": 3.5, "stamina": 1.00, "dur": 3,  "noise": 1.0, "breaks": "leg", "kind": "blunt"},
	"leg":     {"dmg": 13.0, "windup": 0.18, "recover": 0.40, "reach": 1.25, "knock": 1.3, "stamina": 0.35, "dur": 8,  "noise": 0.5, "breaks": "", "kind": "blunt"},
}

## By name first (the exported flat names its things), then by weight.
const NAMED := [
	["knife", "blade"], ["razor", "blade"], ["scissor", "blade"], ["shard", "shard"],
	["axe", "chop"], ["hammer", "tool"], ["wrench", "tool"], ["spanner", "tool"], ["iron", "tool"],
	["bottle", "brittle"], ["jar", "brittle"], ["glass", "brittle"], ["cup", "brittle"], ["mug", "brittle"],
	["tureen", "brittle"], ["vase", "brittle"], ["plate", "brittle"], ["ashtray", "brittle"], ["shade", "brittle"],
	["lamp", "long"], ["pole", "pole"], ["broom", "long"], ["mop", "long"],
	["chair", "heavy"], ["stool", "heavy"], ["leg", "leg"],
	["book", "flimsy"], ["magazine", "flimsy"], ["newspaper", "flimsy"], ["paper", "flimsy"], ["note", "flimsy"],
	["letter", "flimsy"], ["drawing", "flimsy"], ["calendar", "flimsy"], ["sock", "flimsy"], ["doll", "flimsy"],
	["shoe", "flimsy"], ["boot", "blunt"], ["block", "flimsy"], ["candle", "flimsy"], ["match", "flimsy"],
	["photo", "flimsy"], ["blister", "flimsy"], ["inhaler", "flimsy"], ["battery", "flimsy"],
	["tin", "blunt"], ["stove", "blunt"],
]

static func class_of(label: String, mass: float) -> String:
	var l := label.to_lower()
	for pair in NAMED:
		if l.contains(pair[0]): return pair[1]
	if mass < 0.3: return "flimsy"
	if mass < 2.0: return "blunt"
	if mass < 6.0: return "heavy"
	return "heavy"

## The numbers for a held thing (null: the fists), with its class name in "class".
static func profile(prop: Node) -> Dictionary:
	var c := "fist"
	if prop:
		if prop.has_meta("weapon_class"): c = prop.get_meta("weapon_class")
		else:
			c = class_of(String(prop.get("label")) if prop.get("label") != null else String(prop.name), float(prop.get("mass")) if prop.get("mass") != null else 1.0)
			prop.set_meta("weapon_class", c)
	var p: Dictionary = (CLASSES[c] as Dictionary).duplicate()
	p["class"] = c
	return p

## How much use is left in it (1.0 new .. 0.0 about to go); fists: 1.
static func durability(prop: Node) -> int:
	if not prop: return -1
	var p := profile(prop)
	if int(p.dur) < 0: return -1
	if not prop.has_meta("durability"): prop.set_meta("durability", int(p.dur))
	return int(prop.get_meta("durability"))

static func durability_frac(prop: Node) -> float:
	var d := durability(prop)
	if d < 0: return 1.0
	return float(d) / float(maxi(1, int(profile(prop).dur)))

## Use it up by `n` hits. Returns true if that broke it.
static func wear(prop: Node, n: int) -> bool:
	var d := durability(prop)
	if d < 0: return false
	d -= n
	prop.set_meta("durability", maxi(0, d))
	return d <= 0

## Names for the things a broken thing leaves in his hand (what he's holding now).
const BROKEN_LABEL := {"shard": "Broken glass", "pole": "Lamp pole", "leg": "Chair leg"}
