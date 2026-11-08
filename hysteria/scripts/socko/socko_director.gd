class_name SockoDirector
extends RefCounted
## Socko's animation director: one place that decides what the puppet is doing, on top of the
## puppet's own physics (Socko: springs, gaze, speech) and below the story (intro, tutorial,
## labyrinth, the way out, cutscenes). It owns:
##
##   layers       five clip layers, by priority:  0 CUTSCENE  1 REACTION  2 DIALOGUE  3 IDLE
##                4 BACKGROUND. Each plays SockoClips with crossfades. A clip that masks a group
##                ("body", "face") fades out the layers below it on that group as it fades in, so a
##                cutscene never fights an idle for the head, and a sneeze isn't added to a nod.
##                Clips without masks are additive (a nod on top of talking on top of an idle).
##   expression   a held face (SockoClips.EXPRESSIONS), between the idle and dialogue layers.
##   state        the emotional performance: presenter, companion, manipulator, frustrated, angry.
##                Driven by the story stage and by what the player does (obeyed / defied).
##   eyes         each googly eye's target, rate and hold: together by default, a beat apart,
##                and now and then on their own (divided attention and its variations).
##   cues         dialogue cues (inline {tags} in a line, or cue arrays) fired on the words they're
##                attached to; perform() timelines for cutscenes; named transition sequences.
##
## Everything the director outputs is an offset that returns to zero, so no clip, cue or state can
## leave him permanently bent out of shape.

const L := SockoClips.L
const FACE_CH := ["smile_l", "smile_r", "wide", "pucker", "skew", "jaw", "jaw_mul"]
const BODY_CH := ["head", "arm", "curl", "squash", "stretch", "twist", "tremble", "face"]

const STATES := {
	"presenter":   {"emotion": "happy",     "idles": ["Idle_Excited", "Idle_Default"],         "expr": "smile",            "k": 0.8, "amp": 1.2,  "independence": 0.0,  "talk": "Talking_Excited"},
	"companion":   {"emotion": "neutral",   "idles": ["Idle_Default", "Idle_Observing"],       "expr": "smile",            "k": 0.55,"amp": 1.0,  "independence": 0.12, "talk": "Talking_Default"},
	"manipulator": {"emotion": "lying",     "idles": ["Idle_Observing"],                       "expr": "smile",            "k": 0.5, "amp": 0.75, "independence": 0.55, "talk": "Talking_Sympathetic"},
	"frustrated":  {"emotion": "impatient", "idles": ["Idle_Impatient", "Idle_Disappointed"],  "expr": "forced_happiness", "k": 0.6, "amp": 1.1,  "independence": 0.2,  "talk": "Talking_Annoyed"},
	"angry":       {"emotion": "angry",     "idles": ["Idle_Threatening", "Idle_Angry"],       "expr": "forced_happiness", "k": 0.8, "amp": 1.2,  "independence": 0.35, "talk": "Talking_Threatening"},
}
const STATE_ORDER := ["presenter", "companion", "manipulator", "frustrated", "angry"]

var socko                       # Socko (untyped: no cyclic class reference)
var intensity := 1.0            # performance intensity: scales every clip
var layers: Array = [[], [], [], [], []]   # per layer: tracks {clip, t, w, to, fade, amp, speed, hold}
var channels := {}              # the last evaluated output (for the test bench)

# expression
var expr := "neutral"; var expr_k := 0.0; var _expr_w := 0.0; var _expr_until := -1.0
var _face_now := {}             # the expression channels as blended this frame

# state
var state := "presenter"
var stage := "presenter"        # where the story has him (his "base" persona)
var defiance := 0.0             # what the player's done lately against him (decays)
var obedience := 0.0
var locked_state := ""          # a scripted state (cutscenes): overrides the player-driven one
var _idle_t := 0.0; var _idle := ""; var idle_lock := ""
var _leak_t := 6.0
var _since_line := 99.0

# eyes
var targets := {}               # named attention targets: name -> Vector3 or Node3D
var agenda = null               # what he wants Kurt to notice next (spec): divided attention looks here
var eye_points: Array = [Vector3.ZERO, Vector3.ZERO]
var eye_rates: Array = [14.0, 11.0]
var eye_holds: Array = [0.0, 0.0]
var _eye_over: Array = [null, null]       # {look, rate, until}
var _eye_keys: Array = []                 # {at, eye, look, rate, hold}
var _wander_pt := [Vector3.ZERO, Vector3.ZERO]
var _glance_t := 9.0
var behaviour := ""; var _behaviour_until := 0.0

# dialogue cues and timelines
var _line_cues: Array = []      # {word, time, cue}
var _timeline: Array = []; var _tl_t := 0.0
var _cut_exit := false; var _cut_exit_t := 0.0
var _await_turn := false; var _turn_from := Vector3.ZERO; var _await_t := 0.0
var _cam_prev := Basis(); var cam_turn := 0.0  # camera angular speed (rad/s)
var _peak := 0.0; var _last_speech := 0.0
var _rng := RandomNumberGenerator.new()
var _now := 0.0

func _init(p_socko) -> void:
	socko = p_socko
	_rng.seed = 4747

# ================================================================ clips
## Play a clip from the library. opts: layer, fade (s), amp, speed, hold (stay on the last frame:
## default for exits), restart (default true).
func play(clip: String, opts := {}) -> bool:
	if not SockoClips.has(clip):
		push_warning("SockoDirector: no clip %s" % clip)
		return false
	var li: int = opts.get("layer", SockoClips.layer_of(clip))
	var fade: float = opts.get("fade", 0.06 if li == L.CUTSCENE else (0.12 if li == L.REACTION else 0.3))
	var track := {"clip": clip, "t": 0.0, "w": 0.0 if fade > 0.0 else 1.0, "to": 1.0, "fade": fade,
		"amp": float(opts.get("amp", 1.0)), "speed": float(opts.get("speed", 1.0)),
		"hold": bool(opts.get("hold", SockoClips.INFO[clip][4] == "exit"))}
	if not opts.get("restart", true):
		for tr in layers[li]:
			if tr.clip == clip and tr.to > 0.0: return true
	for tr in layers[li]:
		tr.to = 0.0; tr.fade = fade      # crossfade out what was on this layer
	layers[li].append(track)
	return true

func stop_layer(li: int, fade := 0.3) -> void:
	for tr in layers[li]:
		tr.to = 0.0; tr.fade = fade

func stop(clip: String, fade := 0.3) -> void:
	for li in layers.size():
		for tr in layers[li]:
			if tr.clip == clip: tr.to = 0.0; tr.fade = fade

func playing(clip: String) -> bool:
	for li in layers.size():
		for tr in layers[li]:
			if tr.clip == clip and tr.to > 0.0: return true
	return false

## Is anything holding him out of view (an exit) right now?
func hidden() -> bool:
	for tr in layers[L.CUTSCENE]:
		if tr.to > 0.0 and SockoClips.INFO[tr.clip][4] == "exit": return true
	return false

## Leave the view between camera movements: the next time the camera whips round (or after a few
## seconds anyway) he's gone. Real movement, not a pop: the exit happens while you're not looking.
func exit_between_cuts(timeout := 3.0) -> void:
	_cut_exit = true; _cut_exit_t = timeout

## Already there when you turn round: waits until the camera has turned well away and back
## round, then he's simply there, facing you.
func appear_when_turned(timeout := 8.0) -> void:
	_await_turn = true; _await_t = timeout
	_turn_from = -socko.cam.global_transform.basis.z if socko.cam else Vector3.FORWARD
	if not hidden(): play("Exit_Between_Cuts")

# ================================================================ expression
## Hold a face (SockoClips.EXPRESSIONS) at strength k for `hold` seconds (<0: until changed).
func set_expression(name: String, k := 1.0, hold := -1.0) -> void:
	if not SockoClips.EXPRESSIONS.has(name):
		push_warning("SockoDirector: no expression %s" % name); return
	expr = name; expr_k = k
	_expr_until = _now + hold if hold > 0.0 else -1.0

func clear_expression() -> void:
	expr = ""; _expr_until = -1.0

# ================================================================ state
## The story's stage for him: presenter (just met), companion (the flat), manipulator (the
## labyrinth). The player's defiance pushes him from there to frustrated and angry.
func set_stage(s: String) -> void:
	if STATES.has(s): stage = s

## Force a state (scripted scenes). "" hands it back to the player-driven state.
func set_state(s: String) -> void:
	locked_state = s if STATES.has(s) else ""

## The player did what he wanted (w ~ how much he cares). He warms back up.
func obeyed(w := 1.0) -> void:
	obedience += w
	defiance = maxf(0.0, defiance - w * 0.8)

## The player ignored or crossed him. Enough of it and the friendliness wears through.
func defied(w := 1.0) -> void:
	defiance += w

func _want_state() -> String:
	if locked_state != "": return locked_state
	if defiance >= 4.5: return "angry"
	if defiance >= 2.0: return "frustrated"
	return stage

func _enter_state(s: String) -> void:
	var was := state
	state = s
	var st: Dictionary = STATES[s]
	_idle = ""; _idle_t = 0.0
	if socko.auto_perform and not socko.talking:
		socko.set_emotion(st.emotion, 1.0)
	# transitions (bible §7): never a hard cut; scripted beats where it matters
	if s == "frustrated" and STATE_ORDER.find(was) < 3:
		sequence("friendly_frustrated")
	elif s == "angry":
		play("Face_Unnatural_Stillness", {"amp": 1.0}); play("Head_Snap", {"amp": 0.7})
	elif was == "angry":
		sequence("angry_realize")
	elif s == "manipulator":
		sequence("presenter_manipulative")
	elif s == "presenter":
		play("Head_Bob")

# ================================================================ eyes
func register_target(name: String, where) -> void:
	targets[name] = where

func set_agenda(where) -> void:
	agenda = where

## Resolve a look spec to a world point (or null: straight ahead).
func resolve(spec):
	if spec == null: return null
	if spec is Vector3: return spec
	if spec is Node3D: return (spec as Node3D).global_position if is_instance_valid(spec) else null
	var s := String(spec)
	var cam: Camera3D = socko.cam
	match s:
		"kurt", "player", "you": return cam.global_position
		"gaze", "with_head": return socko._eyes_on if socko._eyes_on != Vector3.ZERO else null
		"ahead": return null
		"up": return socko.rig.head_global().origin + cam.global_transform.basis.y * 2.0 - cam.global_transform.basis.z * 0.6
		"down": return socko.rig.head_global().origin - cam.global_transform.basis.y * 2.0 - cam.global_transform.basis.z * 0.8
		"agenda": return resolve(agenda) if agenda != null else null
	if targets.has(s): return resolve(targets[s])
	return null

## Script one or more eyes: each key {at: s from now, eye: 0 left / 1 right / 2 both, look: spec,
## rate: 1/s, hold: s (then back to ordinary behaviour; < 0 until changed)}.
func eye_track(keys: Array) -> void:
	for k in keys:
		var kk: Dictionary = (k as Dictionary).duplicate()
		kk.at = _now + float(kk.get("at", 0.0))
		_eye_keys.append(kk)
	_eye_keys.sort_custom(func(a, b): return a.at < b.at)

func eyes_reset() -> void:
	_eye_keys.clear(); _eye_over = [null, null]; behaviour = ""

func _eye_side(p) -> int:
	# the eye on the side of the point (his left = eye 0), so the glance reads as a glance
	if p == null: return 1
	var hl: Transform3D = socko.rig.head_global()
	return 0 if (hl.affine_inverse() * (p as Vector3)).x < 0.0 else 1

func _begin(b: String, secs: float) -> void:
	behaviour = b; _behaviour_until = _now + secs

## THE signature behaviour. He's listening to you, warmly, eyes on you; one eye slides off to
## what he wants you to notice, holds there a moment, comes back, and both carry on as if nothing
## happened. The head doesn't move. Small and quick enough to miss.
func divided_attention(target = null, hold := 0.75, eye := -1) -> void:
	var t = resolve(target if target != null else "agenda")
	if t == null: return
	var e := eye if eye >= 0 else _eye_side(t)
	var o := 1 - e
	var lead := 0.35
	eye_track([
		{"at": 0.0, "eye": 2, "look": "kurt", "rate": 16.0, "hold": lead + hold + 1.4},
		{"at": lead, "eye": e, "look": t, "rate": 26.0, "hold": hold},                    # the glance
		{"at": lead + hold, "eye": e, "look": "kurt", "rate": 13.0, "hold": 1.2},          # back, unhurried
		{"at": lead, "eye": o, "look": "kurt", "rate": 18.0, "hold": hold + 1.4}])         # the other never leaves you
	_begin("divided_attention", lead + hold + 1.4)

## One eye on Kurt, the other examining a thing, for a while.
func examine(target, secs := 2.5, eye := -1) -> void:
	var t = resolve(target)
	if t == null: return
	var e := eye if eye >= 0 else _eye_side(t)
	eye_track([{"at": 0.0, "eye": 1 - e, "look": "kurt", "rate": 14.0, "hold": secs},
		{"at": 0.1, "eye": e, "look": t, "rate": 8.0, "hold": secs - 0.1}])
	_begin("examine", secs)

## A sound: both eyes go to it, a hair apart, and come back.
func sound_glance(pos: Vector3, hold := 0.6) -> void:
	eye_track([{"at": 0.0, "eye": 0, "look": pos, "rate": 32.0, "hold": hold},
		{"at": 0.06, "eye": 1, "look": pos, "rate": 26.0, "hold": hold - 0.02}])
	_begin("sound_glance", hold + 0.1)

## Both look at something; one comes back to Kurt before the other does.
func staggered_return(target, look := 1.0, lag := 0.45) -> void:
	var t = resolve(target)
	if t == null: return
	var first := _rng.randi() % 2
	eye_track([{"at": 0.0, "eye": 2, "look": t, "rate": 18.0, "hold": look + lag},
		{"at": look, "eye": first, "look": "kurt", "rate": 14.0, "hold": lag + 0.8},
		{"at": look + lag, "eye": 1 - first, "look": "kurt", "rate": 12.0, "hold": 0.8}])
	_begin("staggered_return", look + lag + 0.8)

## One eye flicks up (at nothing), alone.
func upward_glance(eye := -1, hold := 0.45) -> void:
	var e := eye if eye >= 0 else _rng.randi() % 2
	eye_track([{"at": 0.0, "eye": e, "look": "up", "rate": 24.0, "hold": hold}])
	_begin("upward_glance", hold)

## Eyes locked on where they're looking now while the head turns away under them.
func fixed_while_turning(secs := 1.5) -> void:
	for i in 2:
		var p = eye_points[i] if eye_points[i] != Vector3.ZERO else resolve("kurt")
		eye_track([{"at": 0.0, "eye": i, "look": p, "rate": 60.0, "hold": secs}])
	_begin("fixed_while_turning", secs)

## Both eyes drift slowly in on something interesting.
func converge(target, secs := 2.5) -> void:
	var t = resolve(target)
	if t == null: return
	eye_track([{"at": 0.0, "eye": 0, "look": t, "rate": 2.2, "hold": secs}, {"at": 0.25, "eye": 1, "look": t, "rate": 1.8, "hold": secs - 0.25}])
	_begin("converge", secs)

## One eye stays on Kurt; the other wanders, distracted.
func track_and_distracted(secs := 4.0, eye := -1) -> void:
	var e := eye if eye >= 0 else _rng.randi() % 2
	var keys := [{"at": 0.0, "eye": 1 - e, "look": "kurt", "rate": 16.0, "hold": secs}]
	var t := 0.2
	while t < secs - 0.3:
		keys.append({"at": t, "eye": e, "look": _random_point(), "rate": 5.0, "hold": minf(1.3, secs - t)})
		t += _rng.randf_range(0.8, 1.3)
	eye_track(keys)
	_begin("track_and_distracted", secs)

## Sudden interest: both eyes snap to it at once, together.
func sync_snap(target, secs := 1.5) -> void:
	var t = resolve(target)
	if t == null: return
	eye_track([{"at": 0.0, "eye": 2, "look": t, "rate": 45.0, "hold": secs}])
	_begin("sync_snap", secs)

func cam_eyes() -> Vector3:
	return socko.cam.global_position

func _random_point() -> Vector3:
	var cam: Camera3D = socko.cam
	var b := cam.global_transform.basis
	return cam.global_position + b * Vector3(_rng.randf_range(-1.6, 1.0), _rng.randf_range(-0.6, 0.7), -2.5)

func _update_eyes(delta: float) -> void:
	# fire due keys
	while _eye_keys.size() > 0 and float(_eye_keys[0].at) <= _now:
		var k: Dictionary = _eye_keys.pop_front()
		var hold: float = k.get("hold", 1.0)
		var o := {"look": k.get("look"), "rate": float(k.get("rate", 14.0)), "until": _now + hold if hold >= 0.0 else INF}
		var which: int = k.get("eye", 2)
		for i in 2:
			if which == 2 or which == i: _eye_over[i] = o.duplicate()
	if behaviour != "" and _now > _behaviour_until: behaviour = ""
	# ordinary gaze: where the head's attention is, the left eye a touch quicker than the right
	var lead = socko._eyes_on if socko._eyes_on != Vector3.ZERO else null
	if socko._kurt_t > 0.0 or socko._face_s > 0.6:
		lead = cam_eyes()                  # turned to face him: eye contact, his eyes, not his mouth
	var still: float = clampf(socko.stillness + channels.get("still", 0.0), 0.0, 1.0)
	for i in 2:
		var ov = _eye_over[i]
		if ov != null and _now > float(ov.until): _eye_over[i] = null; ov = null
		var p = resolve(ov.look) if ov != null else lead
		eye_points[i] = p if p != null else Vector3.ZERO
		eye_rates[i] = float(ov.rate) if ov != null else lerpf([14.0, 11.0][i], 30.0, still)
		eye_holds[i] = 0.0
	# spontaneous: now and then (by state), one eye goes its own way. Never during a line's
	# important cues, never while something scripted has the eyes, never in stillness.
	var ind: float = STATES[state].independence
	if ind > 0.0 and _eye_keys.is_empty() and behaviour == "" and still < 0.5 and socko.auto_perform:
		_glance_t -= delta * ind
		if _glance_t <= 0.0:
			_glance_t = _rng.randf_range(6.0, 11.0)
			var r := _rng.randf()
			if agenda != null and r < 0.55 and (state == "manipulator" or socko.talking):
				divided_attention()
			elif r < 0.75: upward_glance()
			elif agenda != null: examine("agenda", 1.6)
			else: track_and_distracted(2.5)

# ================================================================ dialogue
const TALK_FOR := {"happy": "Talking_Excited", "nervous": "Talking_Desperate", "impatient": "Talking_Annoyed",
	"angry": "Talking_Annoyed", "furious": "Talking_Threatening", "disappointed": "Talking_Sarcastic",
	"curious": "Talking_Explaining", "uncanny": "Talking_Threatening", "distracted": "Talking_Confused",
	"sleeping": "Talking_Whispering"}

## Pull the {tags} out of a line: returns [clean text, cues]. Tags (case as written):
##   {expr:NAME[:hold]}  {eye:L|R|B:SPEC[:hold]}  {eyes:SPEC[:hold]}  {clip:NAME}  {g:GESTURE}
##   {state:NAME}  {pause:secs}  {divided[:SPEC]}  {interrupt}  {notice:SPEC}
## SPEC: kurt, up, down, agenda, ahead, or a registered target's name.
static func parse_line(text: String) -> Array:
	var clean := ""
	var cues := []
	var i := 0
	while i < text.length():
		var ch := text[i]
		if ch == "{":
			var j := text.find("}", i)
			if j < 0: clean += text.substr(i); break
			var parts := text.substr(i + 1, j - i - 1).split(":")
			var words := clean.strip_edges().split(" ", false).size() if clean.strip_edges() != "" else 0
			# a tag between words belongs to the next word
			var cue := {"word": words}
			match parts[0]:
				"expr": cue.do = "expr"; cue.name = parts[1]; cue.hold = float(parts[2]) if parts.size() > 2 else 2.5
				"eye": cue.do = "eye"; cue.eye = {"L": 0, "R": 1}.get(parts[1], 2); cue.look = parts[2]; cue.hold = float(parts[3]) if parts.size() > 3 else 1.0
				"eyes": cue.do = "eye"; cue.eye = 2; cue.look = parts[1]; cue.hold = float(parts[2]) if parts.size() > 2 else 1.0
				"clip": cue.do = "clip"; cue.name = parts[1]
				"g": cue.do = "gesture"; cue.name = parts[1]
				"state": cue.do = "state"; cue.name = parts[1]
				"pause": cue.do = "pause"; cue.secs = float(parts[1]) if parts.size() > 1 else 0.6
				"divided": cue.do = "divided"; cue.look = parts[1] if parts.size() > 1 else "agenda"
				"interrupt": cue.do = "interrupt"
				"notice": cue.do = "notice"; cue.look = parts[1]
				_: cue.do = ""
			if cue.do != "": cues.append(cue)
			i = j + 1
			continue
		clean += ch
		i += 1
	# tidy the spaces a tag leaves behind
	while clean.contains("  "): clean = clean.replace("  ", " ")
	return [clean.strip_edges(), cues]

## A line is starting (Socko.say): pick its talking clip and schedule its cues on its words.
func on_line(emotion: String, volume: float, style: String, cues: Array, word_times: Array) -> void:
	_since_line = 0.0
	var clip := style
	if clip == "" or not SockoClips.has(clip):
		if volume < 0.6: clip = "Talking_Whispering"
		elif emotion == "lying": clip = "Talking_Sympathetic" if state == "manipulator" else "Talking_Sarcastic"
		elif emotion in ["", "neutral"] or (emotion == "happy" and state in ["presenter", "companion"]): clip = STATES[state].talk
		else: clip = TALK_FOR.get(emotion, STATES[state].talk)
	play(clip, {"layer": L.DIALOGUE, "fade": 0.25, "amp": STATES[state].amp})
	_line_cues.clear()
	for c in cues:
		var w: int = c.get("word", 0)
		var at: float = c.get("at", word_times[w] if w < word_times.size() else (word_times.back() if word_times.size() > 0 else 0.0))
		_line_cues.append({"at": at, "cue": c})
	_line_cues.sort_custom(func(a, b): return a.at < b.at)
	# sympathetic lines with something to steer toward: the glance comes with them, sometimes
	if clip == "Talking_Sympathetic" and agenda != null and cues.is_empty() and _rng.randf() < 0.5:
		_line_cues.append({"at": 0.9, "cue": {"do": "divided", "look": "agenda"}})

func on_line_end() -> void:
	_since_line = 0.0
	stop_layer(L.DIALOGUE, 0.45)
	_line_cues.clear()

## Do a cue now (from a line, a timeline, or the test bench).
func cue(c: Dictionary) -> void:
	match String(c.get("do", "")):
		"expr": set_expression(c.name, float(c.get("k", 1.0)), float(c.get("hold", 2.5)))
		"eye": eye_track([{"at": 0.0, "eye": int(c.get("eye", 2)), "look": c.get("look"), "rate": float(c.get("rate", 22.0)), "hold": float(c.get("hold", 1.0))}])
		"clip": play(c.name, c.get("opts", {}))
		"gesture":
			if SockoClips.has(String(c.name)): play(c.name)
			else: socko.gesture(c.name, resolve(c.get("look")))
		"state": set_state(c.name)
		"stage": set_stage(c.name)
		"pause": socko.pause_speech(float(c.get("secs", 0.6)))
		"divided": divided_attention(c.get("look", "agenda"), float(c.get("hold", 0.75)))
		"interrupt": socko.interrupt()
		"notice":
			var p = resolve(c.get("look"))
			if p != null: socko.notice(p, float(c.get("secs", 1.2)))
		"say": socko.say(c.text, c.get("emotion", ""), float(c.get("volume", 1.0)), c.get("style", ""))
		"behaviour": call(String(c.name))
		"obeyed": obeyed(float(c.get("w", 1.0)))
		"defied": defied(float(c.get("w", 1.0)))

## A cutscene timeline: [{t: seconds from now, do: ..., ...}], any cue (including "say").
## Replaces any timeline already running.
func perform(timeline: Array) -> void:
	_timeline = timeline.duplicate(true)
	_timeline.sort_custom(func(a, b): return float(a.get("t", 0.0)) < float(b.get("t", 0.0)))
	_tl_t = 0.0

func performing() -> bool:
	return not _timeline.is_empty()

## The transitions (bible §7), as short authored timelines.
const SEQUENCES := {
	"presenter_laugh": [{"t": 0.0, "do": "clip", "name": "Idle_Excited"}, {"t": 0.0, "do": "expr", "name": "excitement", "hold": 1.6},
		{"t": 0.2, "do": "clip", "name": "Head_Tilt_Backward"}, {"t": 1.4, "do": "clip", "name": "Laughing"},
		{"t": 3.6, "do": "expr", "name": "smile", "hold": 2.0}],
	"presenter_manipulative": [{"t": 0.0, "do": "expr", "name": "smile", "k": 0.6, "hold": 4.0},
		{"t": 0.6, "do": "eye", "eye": 2, "look": "kurt", "rate": 40.0, "hold": 3.0}, {"t": 0.6, "do": "clip", "name": "Face_Unnatural_Stillness"},
		{"t": 2.4, "do": "expr", "name": "uncomfortable_smile", "k": 0.7, "hold": 2.0}],
	"sympathetic_divided": [{"t": 0.0, "do": "clip", "name": "Talking_Sympathetic", "opts": {"layer": 2}},
		{"t": 0.0, "do": "expr", "name": "smile", "k": 0.5, "hold": 5.5}, {"t": 1.2, "do": "divided", "look": "agenda", "hold": 0.8},
		{"t": 3.4, "do": "eye", "eye": 2, "look": "kurt", "rate": 20.0, "hold": 1.5}, {"t": 3.6, "do": "clip", "name": "Head_Nod", "opts": {"amp": 0.6}}],
	"friendly_frustrated": [{"t": 0.0, "do": "clip", "name": "Head_Snap", "opts": {"amp": 0.5}}, {"t": 0.0, "do": "expr", "name": "irritation", "hold": 0.8},
		{"t": 0.85, "do": "expr", "name": "forced_happiness", "hold": 2.4}, {"t": 0.9, "do": "clip", "name": "Head_Tilt_Left", "opts": {"amp": 0.6}}],
	"observe_snap": [{"t": 0.0, "do": "clip", "name": "Idle_Observing"}, {"t": 1.8, "do": "clip", "name": "Head_Snap"},
		{"t": 1.8, "do": "eye", "eye": 2, "look": "kurt", "rate": 45.0, "hold": 3.0}, {"t": 1.9, "do": "clip", "name": "Face_Unnatural_Stillness"},
		{"t": 1.9, "do": "expr", "name": "unnatural_stillness", "hold": 3.0}],
	"angry_realize": [{"t": 0.0, "do": "expr", "name": "anger", "hold": 0.7}, {"t": 0.7, "do": "clip", "name": "Face_Unnatural_Stillness", "opts": {"layer": 1, "speed": 2.5}},
		{"t": 1.5, "do": "clip", "name": "Turn_To_Player"}, {"t": 1.6, "do": "expr", "name": "forced_happiness", "hold": 2.5},
		{"t": 1.7, "do": "clip", "name": "Head_Bob"}],
}

func sequence(name: String) -> void:
	if SEQUENCES.has(name): perform(SEQUENCES[name])

# ================================================================ the frame
## Evaluate everything for this frame. ctx: {speech: current spoken opening}. Returns the merged
## channels (see SockoClips): offsets for Socko to add to his posture.
func update(delta: float) -> Dictionary:
	_now += delta
	_since_line += delta
	var cam: Camera3D = socko.cam
	if cam:
		var dq := (cam.global_transform.basis.orthonormalized() * _cam_prev.inverse()).get_rotation_quaternion()
		cam_turn = dq.get_angle() / maxf(delta, 1e-4)
		_cam_prev = cam.global_transform.basis.orthonormalized()
	# the state, from the story and the player
	defiance = maxf(0.0, defiance - delta / 75.0)
	var want := _want_state()
	if want != state: _enter_state(want)
	# idles: chosen by state, varied every so often
	_idle_t -= delta
	var idles: Array = STATES[state].idles
	if socko.emotion == "uncanny" or socko.stillness > 0.5: idles = ["Idle_Observing"]
	if idle_lock != "": idles = [idle_lock]
	if _idle == "" or _idle_t <= 0.0 or not (_idle in idles):
		_idle = idles[_rng.randi() % idles.size()]
		_idle_t = _rng.randf_range(8.0, 15.0)
		play(_idle, {"layer": L.IDLE, "fade": 1.0, "restart": false, "amp": STATES[state].amp})
	# the line's emotion fades back into the state's after he stops talking
	if socko.auto_perform and not socko.talking and _since_line > 2.5 and _since_line - delta <= 2.5 and socko.stillness < 0.5:
		socko.set_emotion(STATES[state].emotion, 1.0)
	# the angry and frustrated leaks: dead still, then cheerful again at once
	if socko.auto_perform and state in ["angry", "frustrated"] and not performing():
		_leak_t -= delta
		if _leak_t <= 0.0:
			_leak_t = _rng.randf_range(9.0, 16.0)
			if state == "angry":
				perform([{"t": 0.0, "do": "clip", "name": "Face_Unnatural_Stillness", "opts": {"layer": 1}}, {"t": 0.0, "do": "expr", "name": "anger", "k": 0.6, "hold": 1.6},
					{"t": 1.7, "do": "expr", "name": "forced_happiness", "hold": 2.0}, {"t": 1.7, "do": "clip", "name": "Idle_Excited", "opts": {"layer": 1}}])
			else:
				perform([{"t": 0.0, "do": "expr", "name": "irritation", "hold": 0.5}, {"t": 0.5, "do": "expr", "name": "forced_happiness", "hold": 1.8}])
	# timeline
	if not _timeline.is_empty():
		_tl_t += delta
		while not _timeline.is_empty() and float(_timeline[0].get("t", 0.0)) <= _tl_t:
			cue(_timeline.pop_front())
	# this line's cues, on its words
	if socko.talking:
		while not _line_cues.is_empty() and float(_line_cues[0].at) <= socko._speech_t:
			cue(_line_cues.pop_front().cue)
	# exits between cuts / appearing when turned
	if _cut_exit:
		_cut_exit_t -= delta
		if cam_turn > 2.2 or _cut_exit_t <= 0.0:
			_cut_exit = false; play("Exit_Between_Cuts")
	if _await_turn and cam:
		_await_t -= delta
		var f := -cam.global_transform.basis.z
		if f.angle_to(_turn_from) > 1.9 or _await_t <= 0.0:
			_await_turn = false
			stop_layer(L.CUTSCENE, 0.0)
			play("Enter_Already_There", {"fade": 0.0})
			eye_track([{"at": 0.0, "eye": 2, "look": "kurt", "rate": 80.0, "hold": 1.6}])
	# syllable onsets (for clips that ride the speech)
	var sp: float = socko.spoken
	if sp - _last_speech > 0.05: _peak = 1.0
	_peak = maxf(0.0, _peak - delta * 6.0)
	_last_speech = sp
	channels = _evaluate(delta, {"speech": sp, "peak": _peak})
	_update_eyes(delta)
	return channels

func _evaluate(delta: float, ctx: Dictionary) -> Dictionary:
	var acc := {}
	# expression: the held face (scripted) over the state's face
	if _expr_until > 0.0 and _now > _expr_until: expr = ""; _expr_until = -1.0
	var face_name: String = expr if expr != "" else STATES[state].expr
	var face_k: float = expr_k if expr != "" else float(STATES[state].k)
	if socko.emotion == "uncanny" or (socko.stillness > 0.5 and expr == ""): face_name = "unnatural_stillness"; face_k = 0.6
	var target_face := SockoClips._face(face_name, face_k)
	var kf := 1.0 - pow(0.0005, delta)       # ~0.25 s to change face
	var keys := {}
	for k in _face_now: keys[k] = true
	for k in target_face: keys[k] = true
	for k in keys:
		var cur = _face_now.get(k, Vector3.ZERO if k == "head" else 0.0)
		var tgt = target_face.get(k, Vector3.ZERO if k == "head" else 0.0)
		_face_now[k] = cur.lerp(tgt, kf) if cur is Vector3 else lerpf(cur, tgt, kf)
	for li in range(layers.size() - 1, -1, -1):
		var lvals := {}
		var mask := {"body": 0.0, "face": 0.0}
		var keep := []
		for tr in layers[li]:
			var len := SockoClips.length(tr.clip)
			tr.t += delta * float(tr.speed)
			if not SockoClips.loops(tr.clip) and tr.t >= len:
				if tr.hold: tr.t = len
				else: tr.to = 0.0; tr.fade = maxf(tr.fade, 0.05)
			if tr.fade <= 0.0: tr.w = tr.to
			else: tr.w = move_toward(tr.w, tr.to, delta / tr.fade)
			if tr.w <= 0.0 and tr.to <= 0.0: continue
			keep.append(tr)
			var c := ctx.duplicate(); c.amp = float(tr.amp) * intensity
			var s := _norm(SockoClips.sample(tr.clip, tr.t, c))
			for k in s:
				lvals[k] = lvals.get(k, Vector3.ZERO if s[k] is Vector3 else 0.0) + s[k] * tr.w
			# a cutscene owns the puppet: whatever it plays takes body and face from the layers below
			for g in (["body", "face"] if li == L.CUTSCENE else SockoClips.masks(tr.clip)):
				mask[g] = maxf(mask[g], tr.w)
		layers[li] = keep
		for k in acc:
			var g := "face" if k in FACE_CH else ("body" if k in BODY_CH else "")
			if g != "" and mask[g] > 0.0: acc[k] = acc[k] * (1.0 - mask[g])
		for k in lvals:
			acc[k] = acc.get(k, Vector3.ZERO if lvals[k] is Vector3 else 0.0) + lvals[k]
		if li == L.IDLE:
			# the expression sits above the idles: its face replaces theirs, its body adds
			var fn := _norm(_face_now)
			for k in fn:
				if k in FACE_CH: acc[k] = fn[k] + acc.get(k, 0.0) * 0.25
				else: acc[k] = acc.get(k, Vector3.ZERO if fn[k] is Vector3 else 0.0) + fn[k]
	return acc

## smile -> both corners; jaw_mul stored as an offset from 1.
static func _norm(d: Dictionary) -> Dictionary:
	var o := {}
	for k in d:
		if k == "smile":
			o.smile_l = o.get("smile_l", 0.0) + d[k]; o.smile_r = o.get("smile_r", 0.0) + d[k]
		elif k == "jaw_mul":
			o.jaw_mul = o.get("jaw_mul", 0.0) + d[k] - 1.0
		elif k in ["smile_l", "smile_r"]:
			o[k] = o.get(k, 0.0) + d[k]
		else:
			o[k] = d[k]
	return o

## How the test bench and the QA see what's going on.
func describe() -> String:
	var parts := []
	for li in layers.size():
		for tr in layers[li]:
			if tr.to > 0.0: parts.append("%s:%s" % [["CUT", "REACT", "DLG", "IDLE", "BG"][li], tr.clip])
	return "state %s (stage %s, defiance %.1f)  face %s  eyes %s  %s" % [state, stage, defiance, expr if expr != "" else STATES[state].expr, behaviour if behaviour != "" else "together", "  ".join(parts)]
