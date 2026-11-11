class_name InfectedGenome
## Who an infected person was, and what the infection made of them. Everyone takes it
## differently: the same thing that grew coral through Marta grows shelves of fungus out of one,
## bone out of another, swells a third; it takes limbs, or it adds them. One seed, one person,
## always the same person for the same seed.
##
## generate(seed) -> Dictionary:
##   seed, height (m), build (0 thin .. 1 swollen), hunch (0 .. 1), lean (-1..1 to a side)
##   skin       "rot" | "pallid" | "char" | "bloat"       (the four skins, InfectedTextures)
##   growth     "coral" | "fungus" | "bone" | "tumour"   and growth_amount 0.2 .. 1
##   clothes    "coat" | "nightclothes" | "overalls" | "dress" | "none"   (who they were)
##   head       {state: "whole" | "split" (cheeks torn back, Marta's grin) | "sunk" (one side
##              caved) | "overgrown" (the growth has the face), jaw: how far it hangs, eyes: 0..2}
##   limbs      [{id, kind: "arm" | "leg", anchor: "shoulder" | "back" | "ribs" | "hip" | "belly",
##              side: -1 his right .. 1 his left, extra: bool, state, length, thick, joints,
##              out: Vector3 (which way it leaves the body)}]
##              state: "whole" | "missing" | "stump" | "short" | "long" | "fused" (grown stiff,
##              the growth through the joint) ; joints: 2 (upper, lower) or 3 (an extra joint)
##   locomotion "walk" | "limp" | "skitter" | "hop" | "lurch" | "crawl" | "drag"   (from what's left)
##   quirk      what they keep doing from before: "rocking" | "knocking" | "counting" |
##              "searching" | "folding" | "still"
##   fragment   the one thing they still say (mundane; never the boxes, never an explanation)
##   speed, hearing, sight, persistence: per person (multipliers)
##
## Chances are in CHANCE (tuned so most people are still roughly people: about half have an
## extra limb or a missing one, about one in eight is something else entirely).

const SKINS := ["rot", "pallid", "char", "bloat"]
const GROWTHS := ["coral", "fungus", "bone", "tumour"]
const CLOTHES := ["coat", "nightclothes", "overalls", "dress", "none"]
const QUIRKS := ["rocking", "knocking", "counting", "searching", "folding", "still"]
const FRAGMENTS := ["Is it Tuesday?", "Mind the step.", "I've put the kettle on.", "Who's at the door?",
	"Not the good plates.", "Wipe your feet.", "Is that you?", "The bus is late again.", "Three, four… three, four…",
	"I'll be down in a minute.", "Don't let the cat out.", "Have you eaten?", "It's cold in here.", "Shh. They're sleeping."]
# a base limb's fate, cumulative: the rest stay whole
const CHANCE := {
	"missing": 0.10, "stump": 0.08, "short": 0.08, "long": 0.10, "fused": 0.07,
	"extra_joint": 0.07,
	"extra_count": [0.52, 0.31, 0.13, 0.04],      # 0, 1, 2, 3 extra limbs
	"extra_arm": 0.72,                            # an extra limb is an arm (else a leg)
	"leg_loss": 0.45,                             # legs are lost this much less often than arms (a body that lost them didn't get far)
	"head": {"whole": 0.55, "split": 0.2, "sunk": 0.13, "overgrown": 0.12},
}

static func generate(seed: int) -> Dictionary:
	var r := RandomNumberGenerator.new(); r.seed = seed
	var g := {"seed": seed}
	g.height = r.randf_range(1.52, 1.94)
	g.build = clampf(r.randfn(0.45, 0.22), 0.0, 1.0)
	g.hunch = clampf(r.randfn(0.35, 0.25), 0.0, 1.0)
	g.lean = clampf(r.randfn(0.0, 0.35), -1.0, 1.0)
	g.skin = SKINS[r.randi() % SKINS.size()]
	if g.build > 0.8 and r.randf() < 0.6: g.skin = "bloat"
	g.growth = GROWTHS[r.randi() % GROWTHS.size()]
	g.growth_amount = r.randf_range(0.2, 1.0)
	g.clothes = CLOTHES[r.randi() % CLOTHES.size()]
	g.quirk = QUIRKS[r.randi() % QUIRKS.size()]
	g.fragment = FRAGMENTS[r.randi() % FRAGMENTS.size()]
	g.speed = r.randf_range(0.8, 1.25)
	g.hearing = r.randf_range(0.7, 1.4)
	g.sight = r.randf_range(0.6, 1.3)
	g.persistence = r.randf_range(0.6, 1.5)
	g.twitch = r.randf_range(0.1, 1.0)
	g.palette = r.randi() % 3                     # which cut of their clothes' cloth
	# the head
	var hp: Dictionary = CHANCE.head
	var hk := _pick(r, hp)
	g.head = {"state": hk, "jaw": r.randf_range(0.05, 0.5) if hk != "overgrown" else 0.1,
		"eyes": 0 if hk == "overgrown" else (2 if r.randf() < 0.75 else 1), "tilt": r.randfn(0.0, 0.25)}
	# the four limbs everyone started with
	var limbs := []
	for spec in [["arm", "shoulder", -1], ["arm", "shoulder", 1], ["leg", "hip", -1], ["leg", "hip", 1]]:
		limbs.append(_limb(r, spec[0], spec[1], spec[2], false))
	# what grew
	var n := _pick_index(r, CHANCE.extra_count)
	for i in n:
		var arm := r.randf() < CHANCE.extra_arm
		var anchor: String = (["back", "ribs", "shoulder"] if arm else ["hip", "belly"])[r.randi() % (3 if arm else 2)]
		limbs.append(_limb(r, "arm" if arm else "leg", anchor, -1 if r.randf() < 0.5 else 1, true))
	for i in limbs.size(): limbs[i].id = "%s%d" % [limbs[i].kind, i]
	g.limbs = limbs
	g.locomotion = locomotion_of(limbs)
	return g

static func _limb(r: RandomNumberGenerator, kind: String, anchor: String, side: int, extra: bool) -> Dictionary:
	var l := {"kind": kind, "anchor": anchor, "side": side, "extra": extra, "state": "whole",
		"length": 1.0, "thick": r.randf_range(0.85, 1.15), "joints": 2}
	var x := r.randf()
	var acc := 0.0
	for st in ["missing", "stump", "short", "long", "fused"]:
		acc += float(CHANCE[st]) * (float(CHANCE.leg_loss) if kind == "leg" and st in ["missing", "stump"] else 1.0)
		if x < acc and not (extra and st in ["missing", "stump"]):    # an extra limb is there: it grew
			l.state = st; break
	match l.state:
		"short": l.length = r.randf_range(0.55, 0.75)
		"long": l.length = r.randf_range(1.25, 1.5)
		"stump": l.length = r.randf_range(0.2, 0.35)
	if extra:
		l.length *= r.randf_range(0.7, 1.15)
		l.thick *= r.randf_range(0.6, 0.95)
	if l.state in ["whole", "long"] and r.randf() < CHANCE.extra_joint: l.joints = 3
	# which way it leaves the body (rig space: +Y up, -Z forward, +X his left)
	var s := float(side)
	match anchor:
		"shoulder": l.out = Vector3(s * 0.25, -1.0, 0.0)
		"back": l.out = Vector3(s * 0.6, 0.3, 0.75)
		"ribs": l.out = Vector3(s * 1.0, -0.4, -0.2)
		"hip": l.out = Vector3(s * 0.12, -1.0, 0.0)
		"belly": l.out = Vector3(s * 0.3, -0.8, -0.5)
	l.out = (l.out as Vector3).normalized()
	l.pos = r.randf()          # where along its anchor region it comes out (extras)
	return l

## Usable legs and arms: a missing or stump limb carries nothing; a fused one is a stiff prop.
static func working(limbs: Array, kind: String) -> int:
	var n := 0
	for l in limbs:
		if l.kind == kind and l.state in ["whole", "short", "long", "fused"]: n += 1
	return n

static func locomotion_of(limbs: Array) -> String:
	var legs := working(limbs, "leg")
	var arms := working(limbs, "arm")
	if legs >= 3: return "skitter"
	if legs == 2:
		for l in limbs:
			if l.kind == "leg" and l.state in ["short", "fused", "long"] and not l.extra: return "limp"
		return "walk"
	if legs == 1: return "lurch" if arms >= 1 else "hop"
	if arms >= 2: return "crawl"
	return "drag"

static func _pick(r: RandomNumberGenerator, weights: Dictionary) -> String:
	var x := r.randf(); var acc := 0.0
	for k in weights:
		acc += float(weights[k])
		if x < acc: return k
	return weights.keys().back()

static func _pick_index(r: RandomNumberGenerator, weights: Array) -> int:
	var x := r.randf(); var acc := 0.0
	for i in weights.size():
		acc += float(weights[i])
		if x < acc: return i
	return weights.size() - 1

## One line describing a person (the bench and the tests print it).
static func describe(g: Dictionary) -> String:
	var parts := []
	for l in g.limbs:
		if l.state != "whole" or l.extra or l.joints == 3:
			parts.append("%s%s %s%s%s" % ["extra " if l.extra else "", l.kind, l.state, " (" + l.anchor + ")" if l.extra else (" R" if l.side < 0 else " L"), ", 3 joints" if l.joints == 3 else ""])
	return "#%d  %.2f m %s skin, %s, %s · head %s · %s · %s · \"%s\"%s" % [g.seed, g.height, g.skin, g.growth, g.clothes, g.head.state,
		g.locomotion, g.quirk, g.fragment, ("  [" + "; ".join(parts) + "]") if parts.size() > 0 else ""]
