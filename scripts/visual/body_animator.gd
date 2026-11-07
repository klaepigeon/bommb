class_name BodyAnimator
extends Node
## THE ANIMATION FRAMEWORK, for both of a player's bodies: the meat puppet on the board
## and in every ordinary minigame (style "puppet": bigger, bouncier, stronger silhouettes,
## a game piece with a personality) and the full-sized person at the table and in the
## special events (style "full"). Both read the same persistent state (the PlayerState
## body and statuses, as the view sends them): a lost arm is a gameplay condition, so the
## animator never plays a clip that needs a hand that isn't there; it picks a fallback.
##
## Layers, on a Ps1Human's joints, on top of whatever the figure itself is doing (walking,
## sitting): CONDITION (continuous: trembling with poison, a broken arm held close, a blind
## head searching, a ghost's sway, a limp, the shakes), GESTURE (one-shot clips with
## anticipation, action, impact, follow-through and recovery: cheer, sulk, point, clap, cry,
## laugh, taunt, beg, flinch, stagger, collapse, cough, drink, dice throw, victory dances,
## defeat slumps...), and LOOK (head toward a point). Offsets are added after the figure
## poses itself and taken off again before it poses next frame, so nothing accumulates and
## nothing snaps. AnimationVariantSelector: play("victory") picks a variant that suits the
## body and the personality. AnimationEventManager: GameView maps game events to play().

signal clip_done(name: String)

var human: Ps1Human
var style := "puppet"          # puppet | full
var seed_v := 0
var body: Dictionary = {}
var statuses: Array = []
var ghost := false
var personality := {"nerve": 0.5, "coop": 0.5, "greed": 0.5}
var look_at := Vector3.INF
var clip := ""
var clip_t := 0.0
var clip_len := 1.0
var queue: Array = []
var _applied: Dictionary = {}  # joint -> [rot offset, pos offset]
var _restorer: Node
var _t := 0.0
var _freeze := 0.0
var played: Array = []         # the last clips (tests, debugging)


const CLIPS := {
	"cheer": {"len": 1.4, "needs": ["arm"], "fallback": "hop_happy"},
	"hop_happy": {"len": 1.0},
	"sulk": {"len": 1.8},
	"point": {"len": 1.3, "needs": ["arm"], "fallback": "nod_at"},
	"nod_at": {"len": 0.9},
	"clap": {"len": 1.6, "needs": ["two_hands"], "fallback": "cheer"},
	"cry": {"len": 2.2, "needs": ["arm"], "fallback": "sulk"},
	"laugh": {"len": 1.8},
	"taunt": {"len": 1.6, "needs": ["arm"], "fallback": "laugh"},
	"shrug": {"len": 1.2},
	"nod": {"len": 0.9},
	"shake_head": {"len": 1.0},
	"beg": {"len": 2.0, "needs": ["two_hands"], "fallback": "bow"},
	"bow": {"len": 1.4},
	"flinch": {"len": 0.7},
	"recoil": {"len": 0.9},
	"stagger": {"len": 1.4},
	"fall": {"len": 1.6},
	"collapse": {"len": 2.0},
	"recover": {"len": 1.0},
	"celebrate": {"len": 1.6},
	"dance": {"len": 2.4},
	"panic": {"len": 1.8},
	"disbelief": {"len": 1.6, "needs": ["arm"], "fallback": "shake_head"},
	"disgust": {"len": 1.2},
	"relief": {"len": 1.4},
	"exhausted": {"len": 2.0},
	"cough": {"len": 1.4},
	"vomit": {"len": 1.8},
	"twitch": {"len": 1.2},
	"scratch": {"len": 1.6, "needs": ["arm"], "fallback": "twitch"},
	"clutch_stomach": {"len": 1.6, "needs": ["arm"], "fallback": "sulk"},
	"hands_out": {"len": 1.8, "needs": ["arm"], "fallback": "look_around"},
	"ears": {"len": 1.4, "needs": ["arm"], "fallback": "shake_head"},
	"look_around": {"len": 1.8},
	"dice_throw": {"len": 0.9, "needs": ["arm"], "fallback": "dice_kick"},
	"dice_kick": {"len": 0.9, "needs": ["leg"], "fallback": "dice_headbutt"},
	"dice_headbutt": {"len": 0.9},
	"land": {"len": 0.5},
	"pickup": {"len": 1.0, "needs": ["arm"], "fallback": "bow"},
	"push": {"len": 0.8, "needs": ["arm"], "fallback": "headbutt"},
	"headbutt": {"len": 0.8},
	"drink": {"len": 1.6, "needs": ["arm"], "fallback": "bow"},
	"inject": {"len": 1.2},
	"struggle": {"len": 2.0},
	"stump": {"len": 1.8},
	"rise": {"len": 2.2},
	"ghost_spook": {"len": 1.4},
	"surgeon_cut": {"len": 1.0, "needs": ["arm"], "fallback": "headbutt"},
	"surgeon_pull": {"len": 1.2, "needs": ["arm"], "fallback": "bow"},
	"victory_arrogant": {"len": 2.0, "needs": ["arm"], "fallback": "celebrate"},
	"victory_greedy": {"len": 2.0, "needs": ["two_hands"], "fallback": "celebrate"},
	"victory_injured": {"len": 2.0},
	"defeat_angry": {"len": 1.8, "needs": ["arm"], "fallback": "stomp"},
	"stomp": {"len": 1.4, "needs": ["leg"], "fallback": "sulk"},
}
const VARIANTS := {
	"victory": ["celebrate", "dance", "cheer", "victory_arrogant", "victory_greedy", "victory_injured", "clap"],
	"defeat": ["sulk", "cry", "defeat_angry", "disbelief", "collapse", "shrug", "beg"],
	"good": ["cheer", "hop_happy", "clap", "laugh"],
	"bad": ["sulk", "shake_head", "disbelief", "stomp"],
	"hurt": ["flinch", "recoil", "stagger"],
}


func setup(h: Ps1Human, st := "puppet", s := 0) -> void:
	human = h
	style = st
	seed_v = s
	process_priority = 100
	_restorer = Node.new()
	_restorer.name = "AnimRestore"
	_restorer.process_priority = -100
	_restorer.set_script(_RESTORE)
	add_child(_restorer)
	_restorer.set("anim", self)


func set_state(b: Dictionary, st: Array, is_ghost := false) -> void:
	body = b
	statuses = st
	ghost = is_ghost


func has_part(p: String) -> bool:
	return body.is_empty() or not body.has(p) or str(body[p].s) != "lost"


func usable(p: String) -> bool:
	return body.is_empty() or not body.has(p) or not str(body[p].s) in ["lost", "broken"]


## Can this body do that clip? (the persistent condition decides)
func can(name: String) -> bool:
	var c: Dictionary = CLIPS.get(name, {})
	for need in c.get("needs", []):
		match str(need):
			"arm":
				if not (usable("arm_l") and has_part("hand_l")) and not (usable("arm_r") and has_part("hand_r")):
					return false
			"two_hands":
				if not (has_part("hand_l") and has_part("hand_r") and usable("arm_l") and usable("arm_r")):
					return false
			"leg":
				if not (has_part("leg_l") or has_part("leg_r")):
					return false
	return true


## The clip that will actually play (following fallbacks).
func resolve(name: String) -> String:
	if VARIANTS.has(name):
		name = _variant(name)
	var guard := 0
	while not can(name) and guard < 6:
		name = str(CLIPS.get(name, {}).get("fallback", "nod"))
		guard += 1
	return name if CLIPS.has(name) else "nod"


## AnimationVariantSelector: the body and the personality pick which victory, which defeat.
func _variant(kind: String) -> String:
	var opts: Array = VARIANTS[kind]
	var hurt := 0
	for p in body.keys():
		if str(body[p].s) in ["broken", "lost"]:
			hurt += 1
	if kind == "victory":
		if hurt >= 2:
			return "victory_injured"
		if float(personality.get("greed", 0.5)) > 0.7:
			return "victory_greedy"
		if float(personality.get("nerve", 0.5)) > 0.75:
			return "victory_arrogant"
	if kind == "defeat" and float(personality.get("coop", 0.5)) < 0.25:
		return "defeat_angry"
	var r := RandomNumberGenerator.new()
	r.seed = seed_v * 131 + int(_t * 10.0)
	return opts[r.randi_range(0, opts.size() - 1)]


func play(name: String, now := true) -> String:
	var n := resolve(name)
	if now or clip == "":
		clip = n
		clip_t = 0.0
		clip_len = float(CLIPS[n].len) * (0.85 if style == "puppet" else 1.0)
	else:
		queue.append(n)
	played.append(n)
	if played.size() > 20:
		played.pop_front()
	return n


func playing() -> bool:
	return clip != ""


func _process(delta: float) -> void:
	_t += delta
	if human == null or not is_instance_valid(human):
		return
	var off := {}
	_condition(off)
	if clip != "":
		clip_t += delta
		var u := clip_t / clip_len
		if u >= 1.0:
			var done := clip
			clip = ""
			clip_done.emit(done)
			if not queue.is_empty():
				play(queue.pop_front())
		else:
			_clip(clip, u, off)
	if look_at != Vector3.INF and human.head:
		var lp := human.head.global_position
		var d := look_at - lp
		var local := human.global_transform.basis.inverse() * d
		var yaw := clampf(atan2(local.x, local.z), -1.0, 1.0)
		var pitch := clampf(-atan2(local.y, Vector2(local.x, local.z).length()), -0.6, 0.6)
		_add(off, human.head, Vector3(pitch * 0.6, yaw * 0.8, 0))
	_apply(off)


func _add(off: Dictionary, j: Node3D, rot: Vector3, pos := Vector3.ZERO) -> void:
	if j == null:
		return
	if not off.has(j):
		off[j] = [Vector3.ZERO, Vector3.ZERO]
	off[j][0] += rot
	off[j][1] += pos


func _apply(off: Dictionary) -> void:
	var k := 1.5 if style == "puppet" else 1.0
	for j in off.keys():
		if not is_instance_valid(j):
			continue
		var r: Vector3 = off[j][0] * k
		var p: Vector3 = off[j][1] * k
		(j as Node3D).rotation += r
		(j as Node3D).position += p
		_applied[j] = [r, p]


## Taken off before the figure poses itself next frame (the restorer runs first).
func restore() -> void:
	for j in _applied.keys():
		if is_instance_valid(j):
			(j as Node3D).rotation -= _applied[j][0]
			(j as Node3D).position -= _applied[j][1]
	_applied.clear()


## The phases of a clip: anticipation (pulls the other way), action, impact (the peak),
## follow-through (overshoots), recovery (settles). w(u) is the main curve, a(u) the
## anticipation, f(u) the follow-through wobble.
static func w(u: float) -> float:
	if u < 0.15:
		return -0.25 * sin(u / 0.15 * PI)
	if u < 0.5:
		return smoothstep(0.15, 0.5, u)
	if u < 0.65:
		return 1.0
	if u < 0.85:
		return 1.0 + sin((u - 0.65) / 0.2 * PI) * 0.12
	return 1.0 - smoothstep(0.85, 1.0, u)


static func pulse(u: float, n: float) -> float:
	return sin(u * TAU * n) * (1.0 - smoothstep(0.85, 1.0, u))


func _clip(name: String, u: float, off: Dictionary) -> void:
	var h := human
	var e := w(u)
	# one-armed people use the arm they've got
	var ra := h.arm_r if usable("arm_r") and has_part("hand_r") else h.arm_l
	var rf := h.fore_r if ra == h.arm_r else h.fore_l
	var sgn := 1.0 if ra == h.arm_r else -1.0
	match name:
		"cheer", "celebrate":
			_add(off, h.arm_l, Vector3(-2.6 * e, 0, -0.3 * e))
			_add(off, h.arm_r, Vector3(-2.6 * e, 0, 0.3 * e))
			_add(off, h.hips, Vector3.ZERO, Vector3(0, absf(sin(u * PI * (2.0 if name == "celebrate" else 1.0))) * 0.25 * e, 0))
		"hop_happy":
			_add(off, h.hips, Vector3(0, 0, sin(u * TAU * 2.0) * 0.15), Vector3(0, absf(sin(u * TAU * 1.5)) * 0.3, 0))
		"sulk", "exhausted":
			_add(off, h.upper, Vector3(0.45 * e, 0, 0))
			_add(off, h.head, Vector3(0.5 * e, 0, 0))
			_add(off, h.arm_l, Vector3(0.1 * e, 0, 0.15 * e))
			_add(off, h.arm_r, Vector3(0.1 * e, 0, -0.15 * e))
		"point", "nod_at":
			if name == "point":
				_add(off, ra, Vector3(-1.5 * e, 0.3 * sgn * e, 0))
				_add(off, rf, Vector3(0.2 * e, 0, 0))
			_add(off, h.head, Vector3(-0.15 * e + (pulse(u, 2.0) * 0.2 if name == "nod_at" else 0.0), 0, 0))
		"clap":
			var c := absf(pulse(u, 4.0))
			_add(off, h.arm_l, Vector3(-1.2 * e, 0.6 * e * c, 0))
			_add(off, h.arm_r, Vector3(-1.2 * e, -0.6 * e * c, 0))
			_add(off, h.fore_l, Vector3(-0.6 * e, 0, 0))
			_add(off, h.fore_r, Vector3(-0.6 * e, 0, 0))
		"cry":
			_add(off, ra, Vector3(-2.0 * e, 0, 0))
			_add(off, rf, Vector3(-1.6 * e, 0, 0))
			_add(off, h.head, Vector3(0.35 * e, 0, pulse(u, 3.0) * 0.08))
			_add(off, h.upper, Vector3(0.2 * e + pulse(u, 6.0) * 0.04, 0, 0))
		"laugh":
			_add(off, h.upper, Vector3(-0.25 * e + pulse(u, 6.0) * 0.12, 0, 0))
			_add(off, h.head, Vector3(-0.4 * e, 0, 0))
		"taunt":
			_add(off, ra, Vector3(-1.6 * e, 0, 0.3 * sgn * e))
			_add(off, rf, Vector3(-0.8 * e + pulse(u, 4.0) * 0.4, 0, 0))
			_add(off, h.hips, Vector3(0, pulse(u, 2.0) * 0.3, 0))
		"shrug":
			_add(off, h.arm_l, Vector3(0, 0, 0.4 * e), Vector3(0, 0.05 * e, 0))
			_add(off, h.arm_r, Vector3(0, 0, -0.4 * e), Vector3(0, 0.05 * e, 0))
			_add(off, h.head, Vector3(0, 0, 0.2 * e))
		"nod":
			_add(off, h.head, Vector3(pulse(u, 2.0) * 0.35, 0, 0))
		"shake_head":
			_add(off, h.head, Vector3(0, pulse(u, 3.0) * 0.5, 0))
		"beg", "bow":
			_add(off, h.upper, Vector3(0.7 * e, 0, 0))
			if name == "beg":
				_add(off, h.arm_l, Vector3(-1.3 * e, 0.3 * e, 0))
				_add(off, h.arm_r, Vector3(-1.3 * e, -0.3 * e, 0))
				_add(off, h.fore_l, Vector3(-0.9 * e + pulse(u, 5.0) * 0.1, 0, 0))
				_add(off, h.fore_r, Vector3(-0.9 * e + pulse(u, 5.0) * 0.1, 0, 0))
		"flinch", "recoil":
			var k := 1.0 if name == "recoil" else 0.6
			_add(off, h.upper, Vector3(-0.5 * e * k, 0, 0.1 * e))
			_add(off, h.head, Vector3(-0.3 * e * k, 0.3 * e, 0))
			_add(off, h.arm_l, Vector3(-0.8 * e, 0, -0.3 * e))
			_add(off, h.arm_r, Vector3(-0.8 * e, 0, 0.3 * e))
			_add(off, h.hips, Vector3.ZERO, Vector3(0, 0, -0.15 * e * k))
		"stagger":
			_add(off, h.hips, Vector3(0, 0, sin(u * TAU * 1.5) * 0.35 * e), Vector3(sin(u * TAU) * 0.15, 0, -0.1 * e))
			_add(off, h.upper, Vector3(0.2 * e, 0, -sin(u * TAU * 1.5) * 0.3 * e))
		"fall", "collapse":
			var g := smoothstep(0.1, 0.6, u) * (1.0 if u < 0.9 or name == "collapse" else 1.0 - smoothstep(0.9, 1.0, u))
			_add(off, h.hips, Vector3(-1.3 * g, 0, 0.2 * g), Vector3(0, -0.6 * g, 0.2 * g))
			_add(off, h.leg_l, Vector3(1.0 * g, 0, 0))
			_add(off, h.leg_r, Vector3(0.8 * g, 0, 0))
			_add(off, h.arm_l, Vector3(-1.2 * g, 0, 0))
			_add(off, h.arm_r, Vector3(-1.0 * g, 0, 0))
		"recover":
			_add(off, h.upper, Vector3(0.6 * (1.0 - u), 0, 0))
		"dance":
			_add(off, h.hips, Vector3(0, sin(u * TAU * 2.0) * 0.6, sin(u * TAU * 4.0) * 0.2), Vector3(0, absf(sin(u * TAU * 4.0)) * 0.15, 0))
			_add(off, h.arm_l, Vector3(-1.5 + sin(u * TAU * 4.0) * 0.6, 0, -0.4))
			_add(off, h.arm_r, Vector3(-1.5 - sin(u * TAU * 4.0) * 0.6, 0, 0.4))
		"panic":
			_add(off, h.arm_l, Vector3(-2.2 + pulse(u, 6.0) * 0.6, 0, -0.5))
			_add(off, h.arm_r, Vector3(-2.2 - pulse(u, 6.0) * 0.6, 0, 0.5))
			_add(off, h.head, Vector3(0, pulse(u, 4.0) * 0.5, 0))
			_add(off, h.hips, Vector3.ZERO, Vector3(pulse(u, 3.0) * 0.15, absf(pulse(u, 6.0)) * 0.1, 0))
		"disbelief":
			_add(off, ra, Vector3(-2.2 * e, 0, 0))
			_add(off, rf, Vector3(-1.4 * e, 0, 0))
			_add(off, h.head, Vector3(0, pulse(u, 2.0) * 0.3, 0))
		"disgust":
			_add(off, h.head, Vector3(-0.2 * e, 0.6 * e, 0))
			_add(off, h.upper, Vector3(-0.2 * e, 0.3 * e, 0))
		"relief":
			_add(off, h.upper, Vector3(-0.2 * e, 0, 0))
			_add(off, h.head, Vector3(-0.35 * e, 0, 0))
			_add(off, h.arm_l, Vector3(0, 0, 0.2 * e))
			_add(off, h.arm_r, Vector3(0, 0, -0.2 * e))
		"cough", "vomit":
			var n := 5.0 if name == "cough" else 2.0
			_add(off, h.upper, Vector3(0.5 * e + absf(pulse(u, n)) * 0.3, 0, 0))
			_add(off, h.head, Vector3(0.3 * absf(pulse(u, n)), 0, 0))
			_add(off, ra, Vector3(-1.0 * e, 0, 0))
		"twitch":
			_add(off, h.head, Vector3(pulse(u, 9.0) * 0.2, pulse(u, 7.0) * 0.3, 0))
			_add(off, h.arm_l, Vector3(pulse(u, 8.0) * 0.4, 0, 0))
			_add(off, h.arm_r, Vector3(-pulse(u, 9.0) * 0.4, 0, 0))
		"scratch":
			_add(off, ra, Vector3(-1.8 * e, 0, -0.8 * sgn * e))
			_add(off, rf, Vector3(-1.2 * e + pulse(u, 8.0) * 0.3, 0, 0))
		"clutch_stomach":
			_add(off, h.upper, Vector3(0.6 * e, 0, 0))
			_add(off, h.arm_l, Vector3(-0.8 * e, 0.6 * e, 0))
			_add(off, h.arm_r, Vector3(-0.8 * e, -0.6 * e, 0))
		"hands_out":
			_add(off, h.arm_l, Vector3(-1.5 * e, 0.2, 0))
			_add(off, h.arm_r, Vector3(-1.5 * e, -0.2, 0))
			_add(off, h.head, Vector3(0, pulse(u, 2.0) * 0.6, 0))
		"ears":
			_add(off, h.arm_l, Vector3(-2.6 * e, 0, -0.9 * e))
			_add(off, h.arm_r, Vector3(-2.6 * e, 0, 0.9 * e))
			_add(off, h.fore_l, Vector3(-1.4 * e, 0, 0))
			_add(off, h.fore_r, Vector3(-1.4 * e, 0, 0))
		"look_around":
			_add(off, h.head, Vector3(0, sin(u * TAU) * 0.9, 0))
			_add(off, h.upper, Vector3(0, sin(u * TAU) * 0.3, 0))
		"dice_throw":
			# wind up (anticipation), throw (action), follow-through across the body
			var a := -0.9 if u < 0.35 else lerpf(-0.9, 1.4, smoothstep(0.35, 0.55, u)) * (1.0 - smoothstep(0.8, 1.0, u))
			_add(off, ra, Vector3(-1.8 + a, 0, 0) * (1.0 - smoothstep(0.85, 1.0, u)))
			_add(off, h.upper, Vector3(0.3 * a * 0.4, -0.3 * a * sgn, 0))
		"dice_kick":
			_add(off, h.leg_r if has_part("leg_r") else h.leg_l, Vector3(-1.4 * e, 0, 0))
		"dice_headbutt", "headbutt":
			_add(off, h.upper, Vector3(0.9 * e, 0, 0))
			_add(off, h.head, Vector3(0.4 * e, 0, 0))
		"land":
			_add(off, h.hips, Vector3.ZERO, Vector3(0, -0.18 * sin(u * PI), 0))
			_add(off, h.leg_l, Vector3(-0.4 * sin(u * PI), 0, 0))
			_add(off, h.leg_r, Vector3(-0.4 * sin(u * PI), 0, 0))
			_add(off, h.shin_l, Vector3(0.8 * sin(u * PI), 0, 0))
			_add(off, h.shin_r, Vector3(0.8 * sin(u * PI), 0, 0))
		"pickup":
			_add(off, h.upper, Vector3(0.9 * e, 0, 0))
			_add(off, ra, Vector3(-0.6 * e, 0, 0))
		"push":
			_add(off, h.arm_l, Vector3(-1.5 * e, 0, 0))
			_add(off, h.arm_r, Vector3(-1.5 * e, 0, 0))
			_add(off, h.upper, Vector3(0.3 * e, 0, 0), Vector3(0, 0, 0.1 * e))
		"drink":
			_add(off, ra, Vector3(-2.3 * e, 0, 0.3 * sgn * e))
			_add(off, rf, Vector3(-1.6 * e, 0, 0))
			_add(off, h.head, Vector3(-0.6 * e, 0, 0))
		"inject":
			_add(off, h.arm_l, Vector3(-1.0 * e, 0, -0.5 * e))
			_add(off, h.head, Vector3(0.4 * e, -0.4 * e, 0))
		"struggle":
			_add(off, h.upper, Vector3(pulse(u, 3.0) * 0.3, pulse(u, 2.0) * 0.4, 0))
			_add(off, h.arm_l, Vector3(pulse(u, 5.0) * 0.5, 0, 0))
			_add(off, h.arm_r, Vector3(-pulse(u, 5.0) * 0.5, 0, 0))
			_add(off, h.leg_l, Vector3(pulse(u, 4.0) * 0.3, 0, 0))
		"stump":
			# looking at where it was
			_add(off, h.head, Vector3(0.6 * e, 0.5 * e * (1.0 if not has_part("arm_r") else -1.0), 0))
			_add(off, h.upper, Vector3(0.3 * e + pulse(u, 6.0) * 0.05, 0, 0))
		"rise":
			var r := 1.0 - smoothstep(0.0, 0.8, u)
			_add(off, h.hips, Vector3(-1.2 * r, 0, 0), Vector3(0, -0.6 * r, 0))
			_add(off, h.arm_l, Vector3(-2.4 * smoothstep(0.5, 0.8, u) * (1.0 - smoothstep(0.85, 1.0, u)), 0, 0))
			_add(off, h.arm_r, Vector3(-2.4 * smoothstep(0.5, 0.8, u) * (1.0 - smoothstep(0.85, 1.0, u)), 0, 0))
		"ghost_spook":
			_add(off, h.arm_l, Vector3(-1.6 * e, 0, -0.6 * e))
			_add(off, h.arm_r, Vector3(-1.6 * e, 0, 0.6 * e))
			_add(off, h.hips, Vector3.ZERO, Vector3(0, 0.3 * e, 0.2 * e))
		"surgeon_cut":
			_add(off, ra, Vector3(-1.2 * e, 0, 0))
			_add(off, rf, Vector3(-0.6 * e + pulse(u, 3.0) * 0.2, 0.4 * pulse(u, 2.0), 0))
			_add(off, h.upper, Vector3(0.5 * e, 0, 0))
		"surgeon_pull":
			_add(off, h.arm_l, Vector3(-1.0 * e, 0, 0))
			_add(off, h.arm_r, Vector3(-1.0 * e, 0, 0))
			_add(off, h.upper, Vector3(0.4 * e - smoothstep(0.5, 0.8, u) * 0.6, 0, 0))
		"victory_arrogant":
			_add(off, ra, Vector3(-2.8 * e, 0, 0.2 * sgn))
			_add(off, h.head, Vector3(-0.4 * e, 0, 0))
			_add(off, h.upper, Vector3(-0.2 * e, 0, 0))
		"victory_greedy":
			_add(off, h.arm_l, Vector3(-1.1 * e, 0.8 * e, 0))
			_add(off, h.arm_r, Vector3(-1.1 * e, -0.8 * e, 0))
			_add(off, h.upper, Vector3(0.3 * e, pulse(u, 3.0) * 0.2, 0))
		"victory_injured":
			_add(off, h.hips, Vector3(0, 0, sin(u * TAU) * 0.15), Vector3(0, absf(sin(u * PI)) * 0.12, 0))
			_add(off, h.arm_l if usable("arm_l") else h.arm_r, Vector3(-2.2 * e, 0, 0))
		"defeat_angry", "stomp":
			_add(off, h.leg_r if has_part("leg_r") else h.leg_l, Vector3(-0.8 * absf(pulse(u, 3.0)), 0, 0))
			if name == "defeat_angry":
				_add(off, h.arm_l, Vector3(-0.6 * e, 0, -0.3 * e))
				_add(off, h.arm_r, Vector3(-0.6 * e, 0, 0.3 * e))
			_add(off, h.head, Vector3(0.3 * e, 0, 0))


## The CONDITION layer: what's wrong with them shows all the time.
func _condition(off: Dictionary) -> void:
	var h := human
	var ids := statuses.map(func(s): return str(s.id))
	var t := _t + seed_v
	if ghost:
		_add(off, h.hips, Vector3(sin(t * 1.3) * 0.08, 0, sin(t * 0.9) * 0.1))
		_add(off, h.arm_l, Vector3(-0.4 + sin(t * 1.1) * 0.15, 0, -0.2))
		_add(off, h.arm_r, Vector3(-0.4 + sin(t * 1.2) * 0.15, 0, 0.2))
		return
	if ids.has("paralytic"):
		_freeze = maxf(0.0, _freeze - get_process_delta_time())
		if _freeze <= 0.0 and fmod(t, 5.0) < 0.02:
			_freeze = 1.2
		_add(off, h.arm_l, Vector3(0.2, 0, 0.1))
		_add(off, h.arm_r, Vector3(0.2, 0, -0.1))
	if ids.has("stimulant") or ids.has("rat_fever") or ids.has("thinner") or ids.has("necrosis"):
		var k := 0.06 if ids.has("stimulant") else 0.035
		_add(off, h.arm_l, Vector3(sin(t * 31.0) * k, 0, 0))
		_add(off, h.arm_r, Vector3(sin(t * 29.0) * k, 0, 0))
		_add(off, h.head, Vector3(sin(t * 23.0) * k * 0.6, 0, 0))
	if ids.has("hallucinogen"):
		_add(off, h.head, Vector3(0, sin(t * 2.3) * 0.5 + sin(t * 7.1) * 0.15, 0))
	if ids.has("blindness") or (not body.is_empty() and body.has("eye_l") and str(body.eye_l.s) == "lost" and str(body.eye_r.s) == "lost"):
		_add(off, h.head, Vector3(-0.1, sin(t * 1.1) * 0.6, 0))
		_add(off, h.arm_r, Vector3(-0.5, 0, 0))
	if ids.has("hunger") or ids.has("necrosis"):
		_add(off, h.upper, Vector3(0.2, 0, 0))
	if not body.is_empty():
		# a broken arm held close; a stump; a bad leg leaned off
		for side in ["l", "r"]:
			var s := -1.0 if side == "l" else 1.0
			if body.has("arm_" + side) and str(body["arm_" + side].s) == "broken":
				_add(off, h.get("arm_" + side), Vector3(-0.5, 0, -0.25 * s))
				_add(off, h.get("fore_" + side), Vector3(-1.2, 0, 0))
			if body.has("leg_" + side) and str(body["leg_" + side].s) in ["broken", "lost"]:
				_add(off, h.hips, Vector3(0, 0, 0.08 * s))
		if body.has("head") and str(body.head.s) in ["broken", "burned"]:
			_add(off, h.head, Vector3(0, 0, sin(t * 0.7) * 0.12))


const _RESTORE := preload("res://scripts/visual/anim_restore.gd")
