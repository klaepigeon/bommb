class_name SockoClips
extends RefCounted
## Socko's animation library: every clip is a small, authored function of time that returns
## offsets on a fixed set of channels. They are played by the SockoDirector on its layers, blended
## and masked there, and fed into the puppet (Socko) on top of his emotional posture and springs.
## Because they're offsets on shared channels and not keyframes on bones, the same clip works on
## any pose of the arm (held out, facing Kurt, lowered), they stack (a nod on top of talking on top
## of an idle), and they always end at zero: nothing a clip does is left behind.
##
## Channels (all optional; missing = 0):
##   head    Vector3 pitch (+up), yaw (+his left), roll (rad) added to where he's looking
##   arm     Vector3 the hand's offset in the camera's frame (m): x right, y up, z back toward Kurt
##   jaw     mouth opening added (0..1)        jaw_mul  speech opening multiplier (1 = as spoken)
##   curl    fist (+) / stretched fingers (-)  squash   slump (+) / tense (-)
##   stretch drawn out long (+) / short (-)    twist    wrung round the arm
##   smile_l, smile_r, wide, pucker, skew       the mouth's shape (corner bones)
##   still   stillness added (0..1: no idle, no wobble, eyes held)
##   face    turn the hand round to face Kurt (0..1)
##   hide    0..1, how far out of view the hand has gone (1 = gone, below/behind the frame)
##   tremble small fast shaking of the head (0..1)
##
## INFO: name -> [length s, loops, default layer, masks, category]. Masks name the channel groups a
## clip takes over on its layer (the layers below it are faded out there): "body", "face".

enum L { CUTSCENE, REACTION, DIALOGUE, IDLE, BACKGROUND }

const INFO := {
	# ---- idles (looping, under everything)
	"Idle_Default":      [4.0, true, L.IDLE, [], "idle"],
	"Idle_Excited":      [1.6, true, L.IDLE, [], "idle"],
	"Idle_Impatient":    [2.6, true, L.IDLE, [], "idle"],
	"Idle_Confused":     [4.2, true, L.IDLE, [], "idle"],
	"Idle_Observing":    [7.0, true, L.IDLE, [], "idle"],
	"Idle_Threatening":  [5.0, true, L.IDLE, [], "idle"],
	"Idle_Angry":        [2.2, true, L.IDLE, [], "idle"],
	"Idle_Disappointed": [5.5, true, L.IDLE, [], "idle"],
	# ---- the face (expressions held, with an attack and a release)
	"Face_Smile":               [2.2, false, L.DIALOGUE, ["face"], "face"],
	"Face_Wide_Smile":          [2.2, false, L.DIALOGUE, ["face"], "face"],
	"Face_Uncomfortable_Smile": [2.8, false, L.DIALOGUE, ["face"], "face"],
	"Face_Frown":               [2.2, false, L.DIALOGUE, ["face"], "face"],
	"Face_Confusion":           [2.4, false, L.DIALOGUE, ["face"], "face"],
	"Face_Surprise":            [1.6, false, L.DIALOGUE, ["face"], "face"],
	"Face_Excitement":          [2.0, false, L.DIALOGUE, ["face"], "face"],
	"Face_Disappointment":      [2.6, false, L.DIALOGUE, ["face"], "face"],
	"Face_Irritation":          [2.2, false, L.DIALOGUE, ["face"], "face"],
	"Face_Anger":               [2.2, false, L.DIALOGUE, ["face"], "face"],
	"Face_Forced_Happiness":    [3.0, false, L.DIALOGUE, ["face"], "face"],
	"Face_Nervousness":         [2.4, false, L.DIALOGUE, ["face"], "face"],
	"Face_Suspicion":           [2.6, false, L.DIALOGUE, ["face"], "face"],
	"Face_Panic":               [2.0, false, L.DIALOGUE, ["face"], "face"],
	"Face_Unnatural_Stillness": [3.5, false, L.DIALOGUE, ["face", "body"], "face"],
	# ---- the head (reusable, additive: they go on top of whatever he's doing)
	"Head_Tilt_Left":     [1.5, false, L.REACTION, [], "head"],
	"Head_Tilt_Right":    [1.5, false, L.REACTION, [], "head"],
	"Head_Tilt_Forward":  [1.4, false, L.REACTION, [], "head"],
	"Head_Tilt_Backward": [1.4, false, L.REACTION, [], "head"],
	"Head_Bob":           [0.9, false, L.REACTION, [], "head"],
	"Head_Shake":         [1.1, false, L.REACTION, [], "head"],
	"Head_Nod":           [0.9, false, L.REACTION, [], "head"],
	"Head_Snap":          [1.2, false, L.REACTION, [], "head"],
	"Head_Drop":          [2.2, false, L.REACTION, [], "head"],
	"Head_Raise":         [1.4, false, L.REACTION, [], "head"],
	"Head_Rotate":        [2.4, false, L.REACTION, [], "head"],
	"Head_Stretch":       [1.6, false, L.REACTION, [], "head"],
	"Head_Squash":        [1.4, false, L.REACTION, [], "head"],
	# ---- talking (looping while a line plays; they ride the syllables)
	"Talking_Default":      [3.0, true, L.DIALOGUE, [], "talk"],
	"Talking_Excited":      [2.0, true, L.DIALOGUE, [], "talk"],
	"Talking_Explaining":   [4.0, true, L.DIALOGUE, [], "talk"],
	"Talking_Interrupting": [2.0, true, L.DIALOGUE, [], "talk"],
	"Talking_Confused":     [3.2, true, L.DIALOGUE, [], "talk"],
	"Talking_Annoyed":      [2.4, true, L.DIALOGUE, [], "talk"],
	"Talking_Whispering":   [3.0, true, L.DIALOGUE, [], "talk"],
	"Talking_Laughing":     [1.2, true, L.DIALOGUE, [], "talk"],
	"Talking_Sarcastic":    [3.6, true, L.DIALOGUE, [], "talk"],
	"Talking_Threatening":  [4.0, true, L.DIALOGUE, [], "talk"],
	"Talking_Desperate":    [2.2, true, L.DIALOGUE, [], "talk"],
	"Talking_Sympathetic":  [5.0, true, L.DIALOGUE, [], "talk"],
	# ---- physical comedy (reactions: they take the body over)
	"Laughing":          [2.2, false, L.REACTION, ["body", "face"], "comedy"],
	"Giggling":          [1.5, false, L.REACTION, ["body", "face"], "comedy"],
	"Coughing":          [1.9, false, L.REACTION, ["body", "face"], "comedy"],
	"Sputtering":        [1.6, false, L.REACTION, ["body", "face"], "comedy"],
	"Sneezing":          [2.2, false, L.REACTION, ["body", "face"], "comedy"],
	"Sudden_Surprise":   [1.3, false, L.REACTION, ["body", "face"], "comedy"],
	"Squishing":         [1.7, false, L.REACTION, ["body"], "comedy"],
	"Stretching":        [2.4, false, L.REACTION, ["body", "face"], "comedy"],
	"Losing_Balance":    [2.2, false, L.REACTION, ["body"], "comedy"],
	"Recovering_Fall":   [2.4, false, L.REACTION, ["body", "face"], "comedy"],
	"Looking_Around":    [3.2, false, L.REACTION, ["body"], "comedy"],
	"Peeking":           [2.8, false, L.REACTION, ["body"], "comedy"],
	"Popping_In":        [0.9, false, L.REACTION, ["body"], "comedy"],
	"Retreating":        [1.3, false, L.REACTION, ["body"], "comedy"],
	"Turn_To_Player":    [0.9, false, L.REACTION, ["body"], "comedy"],
	"Tangled":           [3.0, false, L.REACTION, ["body", "face"], "comedy"],
	# ---- entrances and exits (the cutscene layer; the exits hold at their end, out of view)
	"Enter_From_Behind":   [2.2, false, L.CUTSCENE, ["body"], "enter"],
	"Enter_Doorway":       [2.4, false, L.CUTSCENE, ["body"], "enter"],
	"Enter_Pop":           [0.8, false, L.CUTSCENE, ["body"], "enter"],
	"Enter_Rise":          [3.0, false, L.CUTSCENE, ["body"], "enter"],
	"Enter_Lean_In":       [1.8, false, L.CUTSCENE, ["body"], "enter"],
	"Enter_Already_There": [1.6, false, L.CUTSCENE, ["body", "face"], "enter"],
	"Exit_Retreat":        [1.4, false, L.CUTSCENE, ["body"], "exit"],
	"Exit_Drop":           [0.9, false, L.CUTSCENE, ["body"], "exit"],
	"Exit_Between_Cuts":   [0.1, false, L.CUTSCENE, ["body"], "exit"],
}

## The expressions: face channels (and a little body) for each. Face_* clips and the director's
## held expression both use these.
const EXPRESSIONS := {
	"neutral":             {},
	"smile":               {"smile": 0.7, "jaw": 0.05, "wide": 0.15},
	"wide_smile":          {"smile": 1.0, "wide": 0.8, "jaw": 0.32, "stretch": 0.12, "head": Vector3(0.08, 0, 0)},
	"uncomfortable_smile": {"smile_l": 0.85, "smile_r": 0.2, "wide": 0.35, "jaw": 0.03, "skew": 0.3, "still": 0.3},
	"frown":               {"smile": -0.85, "jaw": -0.2, "squash": 0.15, "head": Vector3(-0.08, 0, 0)},
	"confusion":           {"smile_l": -0.35, "smile_r": 0.25, "skew": 0.5, "jaw": 0.08, "curl": 0.1, "head": Vector3(0, 0, 0.25)},
	"surprise":            {"jaw": 0.75, "pucker": 0.55, "stretch": 0.35, "curl": -0.3, "head": Vector3(0.15, 0, 0)},
	"excitement":          {"smile": 0.9, "wide": 0.5, "jaw": 0.45, "stretch": 0.2, "head": Vector3(0.1, 0, 0)},
	"disappointment":      {"smile": -0.55, "jaw": -0.12, "squash": 0.4, "head": Vector3(-0.3, 0, -0.08)},
	"irritation":          {"smile": -0.25, "skew": -0.4, "jaw": -0.15, "squash": -0.2, "curl": 0.2, "pucker": -0.3},
	"anger":               {"smile": -0.9, "wide": 0.45, "jaw": 0.25, "squash": -0.45, "curl": 0.35, "head": Vector3(-0.15, 0, 0)},
	"forced_happiness":    {"smile": 1.0, "wide": 0.65, "jaw": 0.12, "still": 0.5, "squash": -0.3, "skew": 0.15},
	"nervousness":         {"smile": 0.2, "pucker": 0.3, "jaw": 0.05, "squash": 0.35, "curl": 0.3, "tremble": 0.6},
	"suspicion":           {"smile_l": -0.25, "smile_r": 0.12, "jaw": -0.15, "skew": -0.35, "curl": 0.15, "head": Vector3(-0.1, 0, -0.2)},
	"panic":               {"jaw": 0.9, "wide": 0.6, "pucker": 0.2, "stretch": 0.3, "squash": -0.2, "tremble": 1.0},
	"unnatural_stillness": {"still": 1.0, "smile": 0.35},
}

const FACE_OF := {
	"Face_Smile": "smile", "Face_Wide_Smile": "wide_smile", "Face_Uncomfortable_Smile": "uncomfortable_smile",
	"Face_Frown": "frown", "Face_Confusion": "confusion", "Face_Surprise": "surprise", "Face_Excitement": "excitement",
	"Face_Disappointment": "disappointment", "Face_Irritation": "irritation", "Face_Anger": "anger",
	"Face_Forced_Happiness": "forced_happiness", "Face_Nervousness": "nervousness", "Face_Suspicion": "suspicion",
	"Face_Panic": "panic", "Face_Unnatural_Stillness": "unnatural_stillness",
}

static func has(clip: String) -> bool:
	return INFO.has(clip)

static func length(clip: String) -> float:
	return float(INFO[clip][0]) if INFO.has(clip) else 1.0

static func loops(clip: String) -> bool:
	return bool(INFO[clip][1]) if INFO.has(clip) else false

static func layer_of(clip: String) -> int:
	return int(INFO[clip][2]) if INFO.has(clip) else L.REACTION

static func masks(clip: String) -> Array:
	return INFO[clip][3] if INFO.has(clip) else []

static func names(category := "") -> Array:
	var out := []
	for k in INFO:
		if category == "" or INFO[k][4] == category: out.append(k)
	return out

# ---------------------------------------------------------------- easing helpers
## 0 -> 1 with a little anticipation dip first and an overshoot after (a puppeteer's move).
static func _move(u: float, antic := 0.08, over := 0.12) -> float:
	u = clampf(u, 0.0, 1.0)
	var a := -antic * sin(PI * clampf(u / 0.18, 0.0, 1.0)) if u < 0.18 else 0.0
	var m := smoothstep(0.12, 0.6, u)
	var o := over * sin(PI * clampf((u - 0.45) / 0.55, 0.0, 1.0)) * exp(-3.0 * maxf(u - 0.45, 0.0))
	return a + m + o

## Rise, hold, fall: in over [0, a], out over [b, 1].
static func _env(u: float, a := 0.15, b := 0.75) -> float:
	return smoothstep(0.0, a, u) * (1.0 - smoothstep(b, 1.0, u))

## A damped wobble after an impulse at u0 (follow-through), amplitude 1 at the impulse.
static func _settle(u: float, u0: float, freq := 3.0, damp := 6.0) -> float:
	if u < u0: return 0.0
	var x := u - u0
	return sin(x * TAU * freq) * exp(-x * damp)

## Pulse: 1 at the centre c, width w.
static func _bump(u: float, c: float, w: float) -> float:
	return exp(-pow((u - c) / w, 2.0))

static func _face(name: String, k: float) -> Dictionary:
	var e: Dictionary = EXPRESSIONS.get(name, {})
	var o := {}
	for key in e:
		o[key] = e[key] * k
	return o

# ---------------------------------------------------------------- sampling
## The channels of `clip` at time t (s). ctx: {speech: 0..1 current spoken opening, peak: 0..1
## syllable onset pulse, amp: performance intensity, seed: per-play variation}.
static func sample(clip: String, t: float, ctx := {}) -> Dictionary:
	var len := length(clip)
	var u := t / len
	if loops(clip): u = fposmod(u, 1.0)
	else: u = clampf(u, 0.0, 1.0)
	var a: float = ctx.get("amp", 1.0)
	var sp: float = ctx.get("speech", 0.0)
	var pk: float = ctx.get("peak", 0.0)
	var o := {}
	if FACE_OF.has(clip):
		var k := smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.82, 1.0, u))
		o = _face(FACE_OF[clip], k * a)
		if clip == "Face_Surprise":
			o["head"] = Vector3(0.18 * _move(u * 2.0, 0.15, 0.3), 0, 0) * k
		return o
	match clip:
		# ================================================================ idles
		"Idle_Default":
			var w := u * TAU
			o.head = Vector3(sin(w) * 0.03 + sin(w * 3.0) * 0.008, sin(w + 1.3) * 0.05, sin(w * 2.0 + 0.4) * 0.03) * a
			o.squash = sin(w * 2.0) * 0.05
			o.arm = Vector3(0, sin(w * 2.0) * 0.003, 0)
		"Idle_Excited":
			# bouncing on his toes: squash on the landing, stretch at the top, a sway
			var hop := absf(sin(u * PI))
			o.arm = Vector3(0, 0.011 * hop * a, 0)
			o.stretch = (0.18 * hop - 0.1) * a
			o.squash = 0.25 * pow(1.0 - hop, 4.0) * a
			o.head = Vector3(0.06 * hop, sin(u * TAU * 0.5) * 0.05, sin(u * TAU * 0.5) * 0.14) * a
			o.smile = 0.6; o.wide = 0.3; o.jaw = 0.12
		"Idle_Impatient":
			# three quick taps of the head, a pause, a glance away and back
			var taps := 0.0
			for c in [0.1, 0.2, 0.3]: taps += _bump(u, c, 0.03)
			o.head = Vector3(-0.09 * taps, 0.22 * _env((u - 0.55) / 0.35, 0.2, 0.7) if u > 0.55 and u < 0.9 else 0.0, -0.1) * a
			o.squash = -0.12 + 0.12 * taps
			o.twist = 0.1 * sin(u * TAU)
			o.smile = -0.15; o.skew = -0.2
		"Idle_Confused":
			# tilts one way, holds, the other way, holds
			var side := 1.0 if u < 0.5 else -1.0
			var k := smoothstep(0.0, 0.15, fposmod(u, 0.5) / 0.5) * (1.0 - smoothstep(0.85, 1.0, fposmod(u, 0.5) / 0.5))
			o.head = Vector3(0.04, 0.06 * side * k, 0.3 * side * k) * a
			o.jaw = 0.08; o.skew = 0.35 * side; o.curl = 0.1
			o.smile_l = -0.2 * side; o.smile_r = 0.2 * side
		"Idle_Observing":
			# almost nothing: dead still, then one tiny adjustment (a breath, a reposition)
			o.still = 0.75
			var adj := smoothstep(0.38, 0.46, u) * (1.0 - smoothstep(0.8, 0.95, u))
			o.head = Vector3(0.012 * adj, -0.018 * adj, 0.0) * a
			o.squash = 0.04 * _bump(u, 0.62, 0.04)
		"Idle_Threatening":
			# head lowered, leaning in, a slow drift as if following you
			o.still = 0.55
			o.head = Vector3(-0.16, sin(u * TAU) * 0.05, 0.03) * a
			o.arm = Vector3(0.008, 0.0, -0.022) * a
			o.squash = -0.28; o.curl = 0.15; o.smile = 0.15
		"Idle_Angry":
			# tense, trembling, now and then a sharp roll
			o.squash = -0.38; o.curl = 0.22; o.smile = -0.5; o.wide = 0.25
			o.tremble = 0.45
			o.head = Vector3(-0.08, 0, 0.18 * _bump(u, 0.6, 0.05)) * a
			o.twist = 0.12 * _bump(u, 0.6, 0.06)
		"Idle_Disappointed":
			# slumped; a long sigh (rise, then sink lower)
			var sigh := _bump(u, 0.35, 0.1)
			var sink := smoothstep(0.4, 0.6, u) * (1.0 - smoothstep(0.85, 1.0, u))
			o.squash = 0.35 + 0.25 * sink - 0.2 * sigh
			o.stretch = 0.12 * sigh
			o.head = Vector3(-0.25 + 0.1 * sigh - 0.08 * sink, 0, -0.08) * a
			o.smile = -0.45; o.jaw = 0.04 * sigh
		# ================================================================ head
		"Head_Tilt_Left", "Head_Tilt_Right":
			var s := 1.0 if clip == "Head_Tilt_Left" else -1.0
			var k := _move(u / 0.45, 0.12, 0.18) * (1.0 - smoothstep(0.7, 1.0, u))
			o.head = Vector3(0.03 * k, 0.05 * s * k, 0.42 * s * k) * a
			o.squash = 0.06 * k
		"Head_Tilt_Forward":
			var k := _move(u / 0.45, 0.1, 0.15) * (1.0 - smoothstep(0.7, 1.0, u))
			o.head = Vector3(-0.38 * k, 0, 0) * a; o.squash = 0.12 * k; o.arm = Vector3(0, 0, -0.012 * k)
		"Head_Tilt_Backward":
			var k := _move(u / 0.45, 0.1, 0.15) * (1.0 - smoothstep(0.7, 1.0, u))
			o.head = Vector3(0.38 * k, 0, 0) * a; o.stretch = 0.15 * k; o.jaw = 0.05 * k
		"Head_Bob":
			var b := absf(sin(u * TAU)) * _env(u, 0.05, 0.85)
			o.head = Vector3(-0.16 * b, 0, 0) * a; o.squash = 0.18 * b; o.arm = Vector3(0, -0.006 * b, 0)
		"Head_Shake":
			o.head = Vector3(-0.06 * _env(u), 0.34 * sin(u * TAU * 2.0) * _env(u, 0.1, 0.7) + 0.05 * _settle(u, 0.75, 2.5, 8.0), 0) * a
			o.twist = 0.15 * sin(u * TAU * 2.0) * _env(u)
		"Head_Nod":
			var antic := 0.07 * (1.0 - smoothstep(0.0, 0.12, u)) * smoothstep(0.0, 0.04, u)
			var nod := -0.3 * absf(sin(clampf((u - 0.1) / 0.6, 0.0, 1.0) * TAU))
			o.head = Vector3(antic + nod + 0.04 * _settle(u, 0.72, 2.0, 8.0), 0, 0) * a
			o.squash = 0.12 * -nod / 0.3; o.jaw = 0.04 * _env(u)
		"Head_Snap":
			# whip round in a few frames, overshoot, then dead still: the snap is the stillness after
			var k := smoothstep(0.0, 0.06, u)
			o.head = Vector3(0.06 * k, 0.48 * k + 0.12 * _settle(u, 0.06, 3.0, 9.0), 0.08 * k) * a * (1.0 - smoothstep(0.8, 1.0, u))
			o.still = 0.9 * smoothstep(0.1, 0.2, u) * (1.0 - smoothstep(0.85, 1.0, u))
			o.squash = -0.3 * _bump(u, 0.05, 0.04)
		"Head_Drop":
			# falls like it's lost the hand inside it, bounces, comes back up slowly (not quite at once)
			var fall := pow(smoothstep(0.0, 0.18, u), 2.0)
			var rec := smoothstep(0.45, 0.95, u)
			o.head = Vector3(-0.75 * fall * (1.0 - rec) + 0.12 * _settle(u, 0.18, 2.5, 7.0) * (1.0 - rec), 0, 0.15 * fall * (1.0 - rec)) * a
			o.squash = (0.6 * _bump(u, 0.19, 0.04) + 0.2 * fall) * (1.0 - rec)
			o.arm = Vector3(0, -0.03 * fall * (1.0 - rec), 0)
			o.jaw = 0.12 * fall * (1.0 - rec)
		"Head_Raise":
			var k := _move(u / 0.5, 0.1, 0.2) * (1.0 - smoothstep(0.75, 1.0, u))
			o.head = Vector3(0.32 * k, 0, 0) * a; o.stretch = 0.25 * k; o.arm = Vector3(0, 0.012 * k, 0)
		"Head_Rotate":
			var w := u * TAU
			var e := _env(u, 0.12, 0.8)
			o.head = Vector3(sin(w) * 0.18, cos(w) * 0.12, sin(w + 1.57) * 0.4) * e * a
			o.twist = sin(w) * 0.25 * e
		"Head_Stretch":
			var k := _move(u / 0.4, 0.15, 0.25) * (1.0 - smoothstep(0.65, 0.85, u))
			o.stretch = (0.7 * k + 0.2 * _settle(u, 0.85, 3.0, 9.0)) * a
			o.squash = -0.25 * k; o.head = Vector3(0.12 * k, 0, 0) * a; o.jaw = 0.06 * k
		"Head_Squash":
			var k := _move(u / 0.35, 0.12, 0.2) * (1.0 - smoothstep(0.55, 0.75, u))
			o.squash = 0.8 * k * a
			o.stretch = (-0.35 * k + 0.25 * _settle(u, 0.72, 3.0, 7.0)) * a
			o.head = Vector3(-0.1 * k, 0, 0) * a
		# ================================================================ talking
		"Talking_Default":
			o.head = Vector3(0.06 * sp + 0.05 * pk, sin(t * 1.3) * 0.04, sin(t * 0.9) * 0.04) * a
			o.squash = -0.05 * sp
		"Talking_Excited":
			o.arm = Vector3(0, 0.01 * sp + 0.006 * pk, 0) * a
			o.stretch = (0.16 * sp + 0.08 * pk) * a
			o.head = Vector3(0.1 * pk, sin(t * 2.3) * 0.06, sin(t * 2.0) * 0.12) * a
			o.smile = 0.6; o.wide = 0.35; o.jaw_mul = 1.15
		"Talking_Explaining":
			# lays out points: a tilt one way per phrase, a sweep, a little nod on each stress
			var ph := sin(t * 0.9)
			o.head = Vector3(0.08 * pk - 0.03, 0.12 * ph, 0.16 * ph) * a
			o.arm = Vector3(0.01 * ph, 0.004 * pk, 0) * a
			o.smile = 0.25
		"Talking_Interrupting":
			o.arm = Vector3(0.0, 0.004, -0.03) * a
			o.head = Vector3(-0.08 + 0.1 * pk, 0.05 * sin(t * 5.0), 0) * a
			o.still = 0.2; o.squash = -0.2; o.jaw_mul = 1.3; o.wide = 0.3
		"Talking_Confused":
			o.head = Vector3(0.03, 0.06 * sin(t * 3.0), 0.25) * a
			o.skew = 0.4; o.smile_l = -0.2; o.smile_r = 0.15; o.jaw_mul = 0.9
		"Talking_Annoyed":
			o.head = Vector3(-0.12 * pk - 0.04, 0.03 * sin(t * 1.7), -0.06) * a
			o.squash = -0.25; o.skew = -0.3; o.curl = 0.15; o.smile = -0.3; o.jaw_mul = 1.1
		"Talking_Whispering":
			# leans in close to Kurt's face, head down, mouth barely working
			o.arm = Vector3(0.02, 0.01, 0.035) * a
			o.head = Vector3(-0.12, 0.0, 0.08) * a
			o.still = 0.4; o.pucker = 0.25; o.jaw_mul = 0.5; o.face = 0.3
		"Talking_Laughing":
			var h := absf(sin(u * TAU * 3.0))
			o.arm = Vector3(0, 0.008 * h, 0) * a
			o.jaw = 0.35 * h; o.head = Vector3(0.18 + 0.06 * h, 0, 0.05 * sin(u * TAU)) * a
			o.squash = 0.2 * (1.0 - h) - 0.1; o.smile = 1.0; o.wide = 0.5
		"Talking_Sarcastic":
			# half a smile, the head turned a little away, a slow roll on the long words
			o.head = Vector3(0.05, 0.14 + 0.04 * sin(t * 0.8), 0.1 * sin(t * 0.6)) * a
			o.smile_r = 0.6; o.smile_l = -0.1; o.skew = 0.3; o.jaw_mul = 0.8
		"Talking_Threatening":
			# slow, low, leaning in; the smile stays on (wrong)
			o.still = 0.6
			o.head = Vector3(-0.15 + 0.03 * pk, 0, 0) * a
			o.arm = Vector3(0.006, 0.0, -0.04) * a
			o.squash = -0.3; o.smile = 0.3; o.jaw_mul = 0.7
		"Talking_Desperate":
			o.head = Vector3(0.15 + 0.05 * pk, 0.04 * sin(t * 4.0), 0.15 * sin(t * 3.1)) * a
			o.arm = Vector3(0, 0.006 * sp, 0.02) * a
			o.stretch = 0.15 * sp; o.pucker = 0.35; o.tremble = 0.3; o.jaw_mul = 1.1
			o.squash = 0.15 * sin(t * 5.0)
		"Talking_Sympathetic":
			# gentle tilts, small reassuring nods at phrase ends, soft body, eyes on you
			var tilt := sin(t * TAU * 0.18 + 0.6)
			var nod := _bump(fposmod(t, 2.5), 2.1, 0.12)
			o.head = Vector3(-0.07 * nod + 0.03 * pk - 0.04, 0.03 * sin(t * 0.7), 0.2 + 0.06 * tilt) * a
			o.arm = Vector3(0, 0.004 * sin(t * 1.1), 0.01) * a
			o.squash = 0.08 + 0.04 * nod; o.smile = 0.4; o.jaw_mul = 0.85
		# ================================================================ comedy
		"Laughing":
			var burst := absf(sin(u * TAU * 5.0)) * _env(u, 0.08, 0.8)
			o.head = Vector3(0.3 * _env(u, 0.1, 0.8) + 0.08 * burst, 0.05 * sin(u * TAU * 2.0), 0.1 * sin(u * TAU)) * a
			o.jaw = (0.25 + 0.45 * burst) * _env(u, 0.08, 0.85)
			o.squash = 0.3 * (1.0 - burst) * _env(u) - 0.1; o.stretch = 0.15 * burst
			o.arm = Vector3(0, 0.01 * burst, 0); o.smile = 1.0 * _env(u); o.wide = 0.6 * _env(u)
		"Giggling":
			var g := absf(sin(u * TAU * 7.0)) * _env(u, 0.1, 0.8)
			o.head = Vector3(-0.12 * _env(u) + 0.04 * g, 0, 0.08 * g) * a
			o.jaw = 0.08 * g; o.pucker = 0.3 * _env(u); o.smile = 0.7 * _env(u); o.squash = 0.15 * g + 0.1 * _env(u)
		"Coughing":
			for c in [0.22, 0.48, 0.72]:
				var pre := _bump(u, c - 0.06, 0.04)
				var hit := _bump(u, c, 0.03)
				o.stretch = o.get("stretch", 0.0) + 0.2 * pre
				o.squash = o.get("squash", 0.0) + 0.6 * hit
				o.jaw = o.get("jaw", 0.0) + 0.55 * hit
				o.head = o.get("head", Vector3.ZERO) + Vector3(0.12 * pre - 0.3 * hit, 0, 0) * a
			o.smile = -0.3 * _env(u)
		"Sputtering":
			var fl := (0.5 + 0.5 * sin(u * TAU * 18.0)) * _env(u, 0.1, 0.8)
			o.jaw = 0.08 + 0.18 * fl; o.pucker = 0.6 * _env(u)
			o.head = Vector3(0.0, 0.1 * sin(u * TAU * 6.0) * _env(u), 0.0) * a; o.tremble = 0.4 * _env(u)
		"Sneezing":
			# ah… ah… (building: stretched up, head back, mouth opening), CHOO (slammed down), dazed
			var build := smoothstep(0.0, 0.5, u) * (1.0 - smoothstep(0.5, 0.53, u))
			var choo := _bump(u, 0.56, 0.035)
			var daze := smoothstep(0.58, 0.7, u) * (1.0 - smoothstep(0.85, 1.0, u))
			o.stretch = 0.45 * build; o.jaw = 0.55 * build + 0.8 * choo
			o.head = Vector3(0.4 * build - 0.65 * choo + 0.1 * _settle(u, 0.58, 2.0, 5.0), 0.05 * daze * sin(u * 30.0), 0.12 * daze) * a
			o.squash = 0.9 * choo + 0.2 * daze; o.arm = Vector3(0, -0.02 * choo, -0.03 * choo)
			o.pucker = 0.3 * build
		"Sudden_Surprise":
			var antic := _bump(u, 0.05, 0.04)
			var pop := smoothstep(0.07, 0.15, u) * (1.0 - smoothstep(0.6, 1.0, u))
			o.squash = 0.25 * antic - 0.2 * pop; o.stretch = 0.7 * pop + 0.2 * _settle(u, 0.6, 3.0, 8.0)
			o.jaw = 0.8 * pop; o.pucker = 0.4 * pop; o.curl = -0.4 * pop
			o.head = Vector3(0.25 * pop, 0, 0) * a; o.arm = Vector3(0, 0.02 * pop, 0.025 * pop)
		"Squishing":
			var k := sin(PI * clampf(u / 0.75, 0.0, 1.0))
			o.squash = 1.0 * k; o.stretch = -0.5 * k + 0.25 * _settle(u, 0.75, 3.0, 7.0); o.twist = 0.4 * k * sin(u * 9.0)
			o.curl = 0.4 * k; o.head = Vector3(-0.15 * k, 0, 0.1 * k) * a
		"Stretching":
			var k := smoothstep(0.0, 0.45, u) * (1.0 - smoothstep(0.6, 0.8, u))
			o.stretch = 0.85 * k; o.jaw = 0.65 * _bump(u, 0.45, 0.12); o.head = Vector3(0.35 * k, 0, 0.3 * k) * a
			o.twist = 0.3 * k; o.curl = -0.5 * k
			var shake := (1.0 - smoothstep(0.8, 1.0, u)) * smoothstep(0.75, 0.8, u)
			o.head += Vector3(0, 0.12 * sin(u * 80.0) * shake, 0)
		"Losing_Balance":
			var e := _env(u, 0.1, 0.75)
			var wob := sin(u * TAU * 2.2) * (0.25 + 0.4 * u) * e
			o.head = Vector3(-0.1 * absf(wob), 0.1 * wob, 0.55 * wob) * a
			o.arm = Vector3(0.03 * wob, -0.01 * absf(wob), 0); o.squash = 0.2 * absf(wob); o.jaw = 0.3 * e * absf(wob)
			o.twist = 0.3 * wob; o.pucker = 0.4 * e
		"Recovering_Fall":
			# from in a heap: shake it off, stand up too tall, settle back (and not quite all the way at once)
			var heap := 1.0 - smoothstep(0.1, 0.45, u)
			var up := _bump(u, 0.55, 0.08)
			o.head = Vector3(-0.8 * heap + 0.2 * up, 0.25 * sin(u * 40.0) * _bump(u, 0.3, 0.06), 0.5 * heap) * a
			o.squash = 0.75 * heap - 0.2 * up; o.stretch = 0.45 * up + 0.12 * _settle(u, 0.62, 2.0, 4.0) * (1.0 - smoothstep(0.85, 1.0, u))
			o.arm = Vector3(0, -0.04 * heap, 0); o.curl = 0.4 * heap; o.jaw = 0.2 * heap
		"Looking_Around":
			var yaw := 0.0
			if u < 0.3: yaw = 0.7 * _move(u / 0.3, 0.1, 0.1)
			elif u < 0.65: yaw = lerpf(0.7, -0.7, _move((u - 0.3) / 0.35, 0.05, 0.12))
			else: yaw = -0.7 * (1.0 - smoothstep(0.65, 0.95, u))
			o.head = Vector3(0.06, yaw, 0.05 * yaw) * a
		"Peeking":
			# the hand held off to the side, out of frame; the head comes round the edge, twice
			var hold := _env(u, 0.12, 0.85)
			var peek := maxf(_bump(u, 0.35, 0.08), _bump(u, 0.68, 0.1))
			o.arm = Vector3(-0.14 * hold + 0.06 * peek, 0, 0.02 * hold)
			o.head = Vector3(0.05 * peek, -0.5 * peek, -0.5 * peek) * a
			o.hide = 0.55 * hold * (1.0 - peek)
		"Popping_In":
			var k := smoothstep(0.0, 0.3, u)
			o.hide = 1.0 - k
			o.stretch = 0.5 * _bump(u, 0.3, 0.08) + 0.2 * _settle(u, 0.4, 3.0, 7.0)
			o.squash = 0.4 * _bump(u, 0.45, 0.06)
			o.head = Vector3(0.15 * _bump(u, 0.3, 0.1), 0, 0) * a
		"Retreating":
			var antic := _bump(u, 0.12, 0.08)
			var go := smoothstep(0.2, 0.75, u)
			o.arm = Vector3(-0.04 * go, -0.02 * go, 0.04 * go - 0.02 * antic); o.head = Vector3(-0.3 * go + 0.08 * antic, 0.3 * go, 0) * a
			o.hide = go * (1.0 - smoothstep(0.85, 1.0, u)); o.squash = 0.3 * go
		"Turn_To_Player":
			var k := smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(0.75, 1.0, u))
			o.face = k
			o.head = Vector3(0.0, 0.2 * _settle(u, 0.12, 3.0, 8.0), 0.0) * a
			o.still = 0.6 * smoothstep(0.2, 0.3, u) * (1.0 - smoothstep(0.75, 1.0, u)); o.stretch = 0.2 * _bump(u, 0.1, 0.05)
		"Tangled":
			var k := smoothstep(0.0, 0.2, u) * (1.0 - smoothstep(0.75, 0.85, u))
			var st := sin(u * 30.0) * k
			o.twist = 0.9 * k + 0.2 * st; o.curl = 0.6 * k; o.squash = 0.5 * k; o.skew = 0.6 * k
			o.head = Vector3(-0.3 * k + 0.1 * st, 0.15 * st, 0.75 * k) * a
			o.stretch = 0.4 * _bump(u, 0.86, 0.04) + 0.15 * _settle(u, 0.88, 3.0, 9.0)
			o.smile_l = -0.5 * k; o.jaw = 0.25 * k
		# ================================================================ entrances / exits
		"Enter_From_Behind":
			# from behind the edge of the frame (Kurt's own shoulder): the head first, then the rest
			var head_in := smoothstep(0.1, 0.45, u); var body_in := smoothstep(0.3, 0.85, u)
			o.arm = Vector3(-0.3 * (1.0 - body_in), -0.05 * (1.0 - body_in), 0.12 * (1.0 - body_in))
			o.head = Vector3(0.0, -0.6 * head_in * (1.0 - body_in), -0.35 * head_in * (1.0 - body_in)) * a
			o.hide = 1.0 - smoothstep(0.05, 0.4, u)
			o.stretch = 0.15 * _settle(u, 0.85, 2.0, 6.0)
		"Enter_Doorway":
			# emerges forward from tight against the body, head bowed, then lifts it
			var out := smoothstep(0.0, 0.7, u)
			o.arm = Vector3(0.02 * (1.0 - out), -0.1 * (1.0 - out), 0.2 * (1.0 - out))
			o.head = Vector3(-0.6 * (1.0 - smoothstep(0.5, 0.9, u)) + 0.1 * _settle(u, 0.9, 2.0, 6.0), 0, 0) * a
			o.hide = 0.8 * (1.0 - smoothstep(0.0, 0.35, u))
		"Enter_Pop":
			var k := smoothstep(0.0, 0.25, u)
			o.hide = 1.0 - k
			o.arm = Vector3(-0.05 * (1.0 - k), 0, 0)
			o.stretch = 0.6 * _bump(u, 0.25, 0.08) + 0.25 * _settle(u, 0.35, 3.0, 8.0)
			o.squash = 0.45 * _bump(u, 0.42, 0.06); o.jaw = 0.3 * _bump(u, 0.3, 0.1)
		"Enter_Rise":
			var k := smoothstep(0.0, 0.85, u)
			o.hide = 1.0 - k
			o.head = Vector3(-0.5 * (1.0 - smoothstep(0.55, 1.0, u)), 0, 0.15 * (1.0 - k)) * a
			o.squash = 0.3 * (1.0 - k)
		"Enter_Lean_In":
			var k := _move(u / 0.75, 0.05, 0.12)
			o.arm = Vector3(-0.36 * (1.0 - k), 0.02 * (1.0 - k), 0)
			o.head = Vector3(0, -0.2 * (1.0 - k), 0.6 * (1.0 - k)) * a
			o.hide = 0.6 * (1.0 - smoothstep(0.0, 0.4, u))
		"Enter_Already_There":
			# he's just there, turned to you, dead still, already looking; then a small, friendly tilt
			var k := 1.0 - smoothstep(0.7, 1.0, u)
			o.face = k; o.still = k
			o.head = Vector3(0, 0, 0.18 * _bump(u, 0.75, 0.08)) * a
			o.smile = 0.5 * k
		"Exit_Retreat":
			var antic := _bump(u, 0.1, 0.07)
			var go := smoothstep(0.15, 0.9, u)
			o.arm = Vector3(-0.32 * go, -0.06 * go, 0.1 * go - 0.015 * antic)
			o.head = Vector3(-0.2 * go + 0.06 * antic, 0.4 * go, 0) * a
			o.hide = go
		"Exit_Drop":
			var fall := pow(smoothstep(0.1, 0.9, u), 1.7)
			o.hide = fall; o.stretch = 0.35 * fall * (1.0 - fall) * 4.0 - 0.2 * _bump(u, 0.05, 0.04)
			o.head = Vector3(0.3 * fall, 0, 0.1 * fall) * a
		"Exit_Between_Cuts":
			o.hide = 1.0
	return o
