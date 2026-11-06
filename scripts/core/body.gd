class_name Body
extends RefCounted
## The persistent injury model. A contestant's body is nine parts, each with a status;
## injuries stay between minigames, and every system asks the questions below (how good
## are your hands? your legs? can you see? hear?) instead of reading parts directly, so a
## minigame can respond to injuries its own way.
##
##   temporary  bruised, burned (wear off after a few board rounds)
##   persistent broken (until treated)
##   permanent  lost (a prosthetic brings back some use)

const PARTS := ["hand_l", "hand_r", "arm_l", "arm_r", "leg_l", "leg_r", "eye_l", "eye_r", "ears"]
const RANK := {"ok": 0, "bruised": 1, "burned": 2, "broken": 3, "prosthetic": 4, "lost": 5}
const FACTOR := {"ok": 1.0, "bruised": 0.8, "burned": 0.6, "broken": 0.35, "prosthetic": 0.7, "lost": 0.0}
const TEMP_ROUNDS := 2
const LABEL := {"hand_l": "LEFT HAND", "hand_r": "RIGHT HAND", "arm_l": "LEFT ARM", "arm_r": "RIGHT ARM",
	"leg_l": "LEFT LEG", "leg_r": "RIGHT LEG", "eye_l": "LEFT EYE", "eye_r": "RIGHT EYE", "ears": "EARS"}


static func fresh() -> Dictionary:
	var b := {}
	for p in PARTS:
		b[p] = {"s": "ok", "t": 0}
	return b


## Apply an injury. Returns the status the part ends up with. A worse injury replaces a
## lesser one; a temporary injury on a part that is already worse does nothing; anything
## broken or lost on a prosthetic wrecks it (lost again).
static func injure(body: Dictionary, part: String, status: String) -> String:
	if not body.has(part):
		return ""
	var cur: Dictionary = body[part]
	var s: String = cur.s
	if s == "lost":
		return s
	if s == "prosthetic":
		if status in ["broken", "lost"]:
			cur.s = "lost"
		return cur.s
	if RANK[status] > RANK[s]:
		cur.s = status
		cur.t = TEMP_ROUNDS if status in ["bruised", "burned"] else 0
	# Losing an arm takes the hand with it.
	if status == "lost" and part.begins_with("arm"):
		body["hand_" + part.right(1)].s = "lost"
	return cur.s


static func heal_temporary(body: Dictionary) -> int:
	var n := 0
	for p in PARTS:
		if body[p].s in ["bruised", "burned"]:
			body[p].s = "ok"
			body[p].t = 0
			n += 1
	return n


## Set one broken part back to bruised. Returns the part, or "".
static func set_bone(body: Dictionary) -> String:
	for p in PARTS:
		if body[p].s == "broken":
			body[p].s = "bruised"
			body[p].t = TEMP_ROUNDS
			return p
	return ""


## Fit a prosthetic to the most useful lost part (legs first). Returns the part, or "".
static func fit_prosthetic(body: Dictionary) -> String:
	for p in ["leg_l", "leg_r", "arm_r", "arm_l", "hand_r", "hand_l"]:
		if body[p].s == "lost":
			if p.begins_with("arm"):
				body[p].s = "prosthetic"
				body["hand_" + p.right(1)].s = "prosthetic"
			else:
				body[p].s = "prosthetic"
			return p
	return ""


## Temporary injuries count down once per board round.
static func tick_round(body: Dictionary) -> void:
	for p in PARTS:
		var c: Dictionary = body[p]
		if c.s in ["bruised", "burned"]:
			c.t -= 1
			if c.t <= 0:
				c.s = "ok"
				c.t = 0


static func f(body: Dictionary, part: String, painkillers := false) -> float:
	var s: String = body[part].s
	var v: float = FACTOR[s]
	if painkillers and s in ["bruised", "burned", "broken"]:
		v = maxf(v, 0.85)
	return v


## How good one hand is: no better than the arm it's on.
static func hand(body: Dictionary, side: String, pk := false) -> float:
	return minf(f(body, "hand_" + side, pk), f(body, "arm_" + side, pk) if body["arm_" + side].s != "ok" else 1.0)


static func hands(body: Dictionary, pk := false) -> float:
	return hand(body, "l", pk) + hand(body, "r", pk)


static func two_handed(body: Dictionary) -> bool:
	return hand(body, "l") > 0.0 and hand(body, "r") > 0.0


static func legs(body: Dictionary, pk := false) -> float:
	return (f(body, "leg_l", pk) + f(body, "leg_r", pk)) * 0.5


## Movement speed multiplier. Never zero: with no legs you drag yourself.
static func speed(body: Dictionary, pk := false) -> float:
	return 0.3 + 0.7 * legs(body, pk)


static func sight(body: Dictionary) -> float:
	var a := f(body, "eye_l")
	var b := f(body, "eye_r")
	return maxf(a, b) * 0.75 + minf(a, b) * 0.25


static func hearing(body: Dictionary) -> float:
	return f(body, "ears")


## The highest the board die can roll for you.
static func dice_max(body: Dictionary, pk := false) -> int:
	var m := 6
	for p in ["leg_l", "leg_r"]:
		match body[p].s:
			"broken":
				m -= 0 if pk else 1
			"prosthetic":
				m -= 1
			"lost":
				m -= 2
	return maxi(m, 2)


## Something a first aid tin can do something about.
static func treatable(body: Dictionary) -> bool:
	for p in PARTS:
		if body[p].s in ["bruised", "burned", "broken"]:
			return true
	return false


static func any_lost(body: Dictionary) -> bool:
	for p in PARTS:
		if body[p].s == "lost":
			return true
	return false


static func worst(body: Dictionary) -> int:
	var w := 0
	for p in PARTS:
		w = maxi(w, RANK[body[p].s] if body[p].s != "prosthetic" else 2)
	return w


static func summary(body: Dictionary) -> Array:
	var out := []
	for p in PARTS:
		if body[p].s != "ok":
			out.append("%s %s" % [LABEL[p], str(body[p].s).to_upper()])
	return out
