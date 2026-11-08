class_name Socko
extends Node3D
## Socko's performance: the controller that moves the protagonist's left arm and hand, and so the
## sock on it. Built in the four layers of the Socko animation bible (§3):
##
##   A  The hand. Where the arm is held (low and out of the way, up for show, turned back to
##      face Kurt), the wrist following the camera with a little lag, the walk in it, pulling in
##      against walls. Always attached: the forearm starts below the camera, never floats.
##   B  The puppet. Emotional posture, the head aimed at what he's looking at (within what a wrist
##      can do), the mouth for speech, and gestures (nod, shake, point, recoil, wave, cover his
##      face, lean in, beckon, wince).
##   C  Secondary motion. The head on a spring behind the wrist: overshoot when the hand stops,
##      lag when it turns, sag when it drops; the cloth squashing with vertical jolts; the loose
##      googly pupils.
##   D  Intention. Moments that aren't the hand's: holding a gaze on a point while the arm swings
##      away, noticing something first, turning slightly further than a wrist turns, going dead
##      still, resisting the arm. Separate from B so it can be authored and tuned on its own, and
##      strength-limited so it never makes him leave the hand.
##
## Everything blends; nothing snaps. Emotional states are parameter sets lerped over ~0.4 s.

signal line_finished(text: String)

const FOREARM := SockRig.FOREARM_LEN
const SUBSTEP := 1.0 / 240.0

var cam: Camera3D
var player: Node                       # Player, if there is one (walk bob, crouch, what he's aiming at)
var rig: SockRig

# ---------------------------------------------------------------- state
var emotion := "neutral"
var intensity := 1.0
var _p := {}                            # the current blended posture
var talking := false
var loud := 1.0                         # speech volume: 0.4 whisper .. 1.5 shout
var pose_face := 0.0                    # 0 held out ahead, 1 turned back to look at Kurt
var pose_low := 0.0                     # 1 lowered out of the way (hands busy, running)
var shown := 1.0                        # 0 below the frame, 1 in view (the intro raises him)
var beyond := 0.0                       # D: how far past a wrist's range he's allowed (0..1)
var stillness := 0.0                    # D: 1 is no cloth wobble, no idle, no breath: wrong
var resist := 0.0                       # D: the hand drags behind the arm, against Kurt
var ghost_mouth := 0.0                  # D: the mouth keeps moving after the line has ended

# gaze, by priority (bible §7.2)
var _event_gaze = null; var _event_t := 0.0
var _intent_gaze = null; var _intent_t := 0.0
var _kurt_t := 0.0
var _wander := Vector3.ZERO; var _wander_t := 0.0
var _eyes_on := Vector3.ZERO           # where the pupils are pulled (they lead the head)
var gaze_point := Vector3.ZERO         # where the head is actually aimed this frame (for tests)

# gesture
var _gesture := ""; var _g_t := 0.0; var _g_len := 1.0; var _g_target = null; var _g_amp := 1.0

# speech
var _segs: Array = []                   # [{t, d, open, round, word}]
var _speech_t := 0.0
var _speech_len := 0.0
var _line := ""
var _utt_id := -1
var _word_starts: Array = []            # char offset -> segment index, for TTS boundary resync

# springs
var _rig_xf := Transform3D.IDENTITY
var _rig_vel := Vector3.ZERO
var _ang_prev := Basis()
var _ang_vel := Vector3.ZERO
var _head := Vector3.ZERO; var _head_v := Vector3.ZERO
var _jaw := 0.0; var _jaw_v := 0.0
var _sq := 0.0; var _sq_v := 0.0
var _wrist_prev := Vector3.ZERO; var _wrist_vel := Vector3.ZERO
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _snap_t := 0.0; var _snap := Vector3.ZERO
var _spill: OmniLight3D

# ---------------------------------------------------------------- emotions (bible §4–5)
# lift/lean move the hand (m); pitch/roll tilt the head (rad); jaw at rest; bounce: speech
# emphasis and liveliness; jitter: twitches; still: damping; curl: fist; squash: slump (+) / tense (-)
const EMOTIONS := {
	"neutral":      {"lift": 0.0,   "lean": 0.0,   "pitch": 0.0,   "roll": 0.0,   "jaw": 0.02, "bounce": 0.35, "jitter": 0.0, "still": 0.0, "curl": 0.0,  "squash": 0.0,  "wander": 1.0},
	"happy":        {"lift": 0.025, "lean": 0.015, "pitch": 0.2,   "roll": 0.05,  "jaw": 0.14, "bounce": 1.0,  "jitter": 0.0, "still": 0.0, "curl": -0.25,"squash": -0.15,"wander": 0.8},
	"curious":      {"lift": 0.012, "lean": 0.03,  "pitch": 0.06,  "roll": 0.38,  "jaw": 0.1,  "bounce": 0.3,  "jitter": 0.0, "still": 0.15,"curl": -0.1, "squash": -0.2, "wander": 0.3},
	"nervous":      {"lift": -0.03, "lean": -0.035,"pitch": -0.35, "roll": 0.1,   "jaw": 0.03, "bounce": 0.25, "jitter": 1.0, "still": 0.0, "curl": 0.45, "squash": 0.55, "wander": 1.6},
	"impatient":    {"lift": 0.0,   "lean": 0.01,  "pitch": 0.05,  "roll": -0.12, "jaw": 0.05, "bounce": 0.6,  "jitter": 0.35,"still": 0.0, "curl": 0.1,  "squash": -0.1, "wander": 0.6},
	"distracted":   {"lift": -0.01, "lean": 0.0,   "pitch": 0.0,   "roll": 0.1,   "jaw": 0.04, "bounce": 0.2,  "jitter": 0.0, "still": 0.0, "curl": 0.0,  "squash": 0.1,  "wander": 2.5},
	"disappointed": {"lift": -0.035,"lean": -0.01, "pitch": -0.45, "roll": -0.1,  "jaw": 0.0,  "bounce": 0.1,  "jitter": 0.0, "still": 0.35,"curl": 0.2,  "squash": 0.45, "wander": 0.4},
	"angry":        {"lift": 0.01,  "lean": 0.045, "pitch": -0.12, "roll": 0.22,  "jaw": 0.2,  "bounce": 0.55, "jitter": 0.0, "still": 0.2, "curl": 0.15, "squash": -0.4, "wander": 0.2},
	"furious":      {"lift": 0.03,  "lean": 0.06,  "pitch": -0.16, "roll": 0.32,  "jaw": 0.42, "bounce": 0.0,  "jitter": 0.0, "still": 0.7, "curl": 0.3,  "squash": -0.7, "wander": 0.0},
	"lying":        {"lift": 0.015, "lean": 0.0,   "pitch": 0.1,   "roll": 0.0,   "jaw": 0.07, "bounce": 0.05, "jitter": 0.0, "still": 0.8, "curl": -0.05,"squash": -0.1, "wander": 0.0},
	"uncanny":      {"lift": 0.0,   "lean": 0.01,  "pitch": 0.0,   "roll": 0.0,   "jaw": 0.0,  "bounce": 0.0,  "jitter": 0.0, "still": 1.0, "curl": 0.0,  "squash": -0.1, "wander": 0.0},
	"sleeping":     {"lift": -0.05, "lean": -0.02, "pitch": -0.6,  "roll": 0.25,  "jaw": 0.05, "bounce": 0.0,  "jitter": 0.0, "still": 0.3, "curl": 0.3,  "squash": 0.7,  "wander": 0.0},
}
const GESTURES := ["nod", "shake", "point", "recoil", "wave", "cover", "lean_in", "beckon", "wince", "bounce", "look_round"]

func setup(p_cam: Camera3D, p_player: Node = null) -> void:
	cam = p_cam; player = p_player

func _ready() -> void:
	top_level = true
	_rng.seed = 47
	rig = SockRig.new(); rig.name = "Rig"
	add_child(rig)
	_p = EMOTIONS.neutral.duplicate()
	# a little of the room's light kept on him, as the JS build's hand pass did, so he reads in
	# the dark (layer 2: it lights nothing else)
	_spill = OmniLight3D.new(); _spill.name = "Spill"
	_spill.light_color = Color(1.0, 0.93, 0.82); _spill.light_energy = 0.16
	_spill.omni_range = 0.9; _spill.omni_attenuation = 1.5
	_spill.light_cull_mask = 2; _spill.shadow_enabled = false
	add_child(_spill)
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).layers = 1 | 2
	if cam:
		_rig_xf = _target_xf()
		global_transform = _rig_xf
	_ang_prev = global_transform.basis
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_BOUNDARY, _on_boundary)
		DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED, _on_ended)

# ---------------------------------------------------------------- public: performance
func set_emotion(e: String, k := 1.0) -> void:
	if EMOTIONS.has(e):
		emotion = e; intensity = k

func gesture(g: String, target = null, amp := 1.0) -> void:
	_gesture = g; _g_t = 0.0; _g_target = target; _g_amp = amp
	_g_len = {"nod": 0.9, "shake": 1.0, "point": 2.2, "recoil": 0.9, "wave": 1.4, "cover": 2.4,
		"lean_in": 1.8, "beckon": 1.6, "wince": 0.8, "bounce": 0.6, "look_round": 2.6}.get(g, 1.0)

## Look at a point because something happened there (a noise, a door): top priority, brief.
func notice(p: Vector3, seconds := 1.5) -> void:
	_event_gaze = p; _event_t = seconds

## Layer D: keep watching a point on his own, even when the arm turns away. Strength 0..1.
func attend(p: Vector3, seconds := 4.0) -> void:
	_intent_gaze = p; _intent_t = seconds

func look_at_kurt(seconds := 3.0) -> void:
	_kurt_t = seconds

func busy() -> bool:
	return talking or _gesture != ""

# ---------------------------------------------------------------- speech (bible §7.5, §12)
## Say a line: subtitled, voiced by the system's TTS in Socko's register where there is one, and
## performed. The mouth follows a syllable schedule made from the text (vowel shape → opening,
## m/b/p shut it, punctuation pauses); when the TTS reports word boundaries, the schedule is pulled
## onto the voice so the mouth stays with it. Without TTS the schedule alone times the line.
func say(text: String, e := "", volume := 1.0) -> void:
	if e != "":
		set_emotion(e)
	loud = volume
	_line = text
	_build_schedule(text)
	_speech_t = -0.12            # the mouth opens just before the sound
	talking = true
	Game.toast.emit(text, maxf(2.5, _speech_len + 1.2))
	var v: String = Game._voice()
	_utt_id = -1
	if v != "":
		DisplayServer.tts_stop()
		var pitch := 1.55 if volume > 0.6 else 1.35
		var rate := clampf(1.05 * (1.15 if e in ["nervous", "impatient", "angry"] else 1.0) * (0.85 if e in ["lying", "uncanny", "sleeping"] else 1.0), 0.6, 1.6)
		_utt_id = 4700 + randi() % 100000
		DisplayServer.tts_speak(text.replace("…", "...").replace("“", "").replace("”", ""), v, int(clampf(70.0 * volume, 30.0, 100.0)), pitch, rate, _utt_id)

const VOWELS := "aeiouy"
func _build_schedule(text: String) -> void:
	_segs.clear(); _word_starts.clear()
	var t := 0.0
	var i := 0
	var s := text.to_lower()
	while i < s.length():
		var ch := s[i]
		if ch == "." and s.substr(i, 3) == "...": t += 0.6; i += 3; continue
		if ch == "…": t += 0.6; i += 1; continue
		if ch in ".!?": t += 0.42; i += 1; continue
		if ch in ",;:—–-": t += 0.22; i += 1; continue
		if not (ch.unicode_at(0) >= 97 and ch.unicode_at(0) <= 122) and ch != "'":
			i += 1; continue
		# a word
		var j := i
		while j < s.length() and ((s.unicode_at(j) >= 97 and s.unicode_at(j) <= 122) or s[j] == "'"):
			j += 1
		var word := s.substr(i, j - i)
		_word_starts.append([i, _segs.size()])
		# syllables: runs of vowels; each opens the mouth by its vowel, shut by lip consonants
		var k := 0
		var any := false
		while k < word.length():
			if VOWELS.contains(word[k]):
				var v0 := word[k]
				var m := k
				while m < word.length() and VOWELS.contains(word[m]): m += 1
				var open: float = {"a": 0.95, "o": 0.75, "e": 0.55, "i": 0.4, "u": 0.45, "y": 0.4}.get(v0, 0.6)
				var rnd := v0 in ["o", "u"]
				var shut := k > 0 and word[k - 1] in ["m", "b", "p"]
				var d := 0.13 + 0.025 * (m - k)
				_segs.append({"t": t, "d": d, "open": open, "round": rnd, "shut": shut})
				t += d; k = m; any = true
			else:
				k += 1
		if not any:
			_segs.append({"t": t, "d": 0.1, "open": 0.3, "round": false, "shut": false}); t += 0.1
		t += 0.05
		i = j
	_speech_len = t

func _on_boundary(pos: int, id: int) -> void:
	if id != _utt_id:
		return
	for ws in _word_starts:
		if ws[0] >= pos and ws[1] < _segs.size():
			_speech_t = _segs[ws[1]].t
			return

func _on_ended(id: int) -> void:
	if id == _utt_id and talking and _speech_t < _speech_len - 0.3:
		_speech_t = _speech_len - 0.05

func _speech_jaw(delta: float) -> float:
	if not talking:
		return 0.0
	_speech_t += delta
	if _speech_t >= _speech_len:
		talking = false
		line_finished.emit(_line)
		return 0.0
	for s in _segs:
		if _speech_t >= s.t and _speech_t < s.t + s.d:
			var u: float = (_speech_t - s.t) / s.d
			# fast open, slower close, the lips meeting first on m/b/p
			var env := sin(PI * pow(u, 0.7))
			if s.shut and u < 0.25: env *= u / 0.25
			return s.open * env
	return 0.0

# ---------------------------------------------------------------- the frame
func _process(delta: float) -> void:
	if not cam or delta <= 0.0:
		return
	delta = minf(delta, 0.1)     # a hitch shouldn't fling him
	_t += delta
	# blend posture toward the emotional state (no snapping between states)
	var target: Dictionary = EMOTIONS.get(emotion, EMOTIONS.neutral)
	var kb := 1.0 - pow(0.004, delta)
	for key in target:
		var want: float = target[key] * (intensity if key not in ["still", "wander", "bounce"] else 1.0)
		_p[key] = lerpf(_p.get(key, 0.0), want, kb)
	for tk in ["_event_t", "_intent_t", "_kurt_t"]:
		set(tk, maxf(0.0, get(tk) - delta))
	var g := _gesture_offsets(delta)

	# ---------------- A: where the hand is
	var busy_hand: bool = player != null and player.get("held") != null and player.get("inspecting")
	var running: bool = player != null and Vector2(player.velocity.x, player.velocity.z).length() > 2.0
	pose_low = move_toward(pose_low, 1.0 if (busy_hand or running) else 0.0, delta * 2.5)
	var face_w := clampf(pose_face + (1.0 if _kurt_t > 0.0 else 0.0) * 0.85 + g.face, 0.0, 1.0)
	_face_s = lerpf(_face_s, face_w, 1.0 - pow(0.02, delta))
	# the elbow is part of the body: it goes where the body goes. Only the swing of the forearm from
	# it lags behind a turn (more when he's resisting Kurt).
	var tx := _target_xf(g)
	var kr := 1.0 - pow(0.0001 if resist < 0.5 else 0.05, delta * (1.0 - resist * 0.8))
	_rig_xf = Transform3D(Basis(_rig_xf.basis.get_rotation_quaternion().slerp(tx.basis.get_rotation_quaternion(), kr)), tx.origin)
	global_transform = _rig_xf

	# rig angular velocity (for the head's lag) and the wrist's vertical acceleration (squash)
	var dq := (global_transform.basis * _ang_prev.inverse()).get_rotation_quaternion()
	_ang_vel = dq.get_axis() * dq.get_angle() / delta if dq.get_angle() > 0.0001 else Vector3.ZERO
	_ang_prev = global_transform.basis
	var wpos := rig.bone_global(SockRig.B.HAND).origin
	var wv := (wpos - _wrist_prev) / delta
	var wacc := (wv - _wrist_vel) / delta
	_wrist_prev = wpos; _wrist_vel = wv

	# ---------------- B + D: where he looks
	var still := clampf(_p.still + stillness, 0.0, 1.0)
	var aim := _gaze(delta, still)
	gaze_point = aim
	var local := global_transform.affine_inverse() * aim - Vector3(0, 0, -FOREARM)
	# turn the face there and keep the top of his head up as Kurt sees it (yaw-then-pitch from a
	# direction alone rolls the head over when he's turned back to face Kurt)
	var up_l := (global_transform.basis.inverse() * cam.global_transform.basis.y).normalized()
	var dl := local.normalized()
	var arc: Vector3
	if absf(dl.dot(up_l)) < 0.97:
		arc = Basis.looking_at(dl, up_l).get_euler(EULER_ORDER_YXZ)
	else:
		arc = Basis(Quaternion(Vector3.FORWARD, dl)).get_euler(EULER_ORDER_YXZ)
	var yaw := arc.y
	var pitch := arc.x
	var roll := clampf(arc.z, -0.6, 0.6)
	var lim := 1.0 + beyond * 0.7
	yaw = clampf(yaw, -0.85 * lim, 0.85 * lim)
	pitch = clampf(pitch, -1.05 * lim, 1.15 * lim)
	var idle := Vector3(sin(_t * 0.7) * 0.05 + sin(_t * 1.9) * 0.02, sin(_t * 0.53 + 1.0) * 0.06, sin(_t * 0.31) * 0.04) * (1.0 - still)
	var breath := sin(_t * 1.6) * 0.015 * (1.0 - still)
	var jitter := Vector3.ZERO
	if _p.jitter > 0.01 and _rng.randf() < delta * 3.0 * _p.jitter:
		_head_v += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-0.5, 0.5)) * 4.0 * _p.jitter
	# furious: a few sharp snaps, dead still between them (bible §5.6)
	if emotion == "furious":
		_snap_t -= delta
		if _snap_t <= 0.0:
			_snap_t = _rng.randf_range(0.5, 1.6)
			_snap = Vector3(_rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.3, 0.3))
			_head_v += _snap * 30.0
	var bounce := 0.0
	if talking:
		bounce = _jaw * 0.12 * _p.bounce * loud
	var want: Vector3 = Vector3(pitch + _p.pitch + breath + bounce, yaw, roll + _p.roll) + idle + g.head + jitter
	# C: the head on a spring behind the wrist; the arm's turn drags it, still damps it
	var freq := lerpf(8.5, 14.0, still)
	var zeta := lerpf(0.42, 1.0, still)
	var lag := global_transform.basis.inverse() * _ang_vel
	_head_v += (Vector3(-lag.x, -lag.y, -lag.z) * 0.9 * (1.0 - still)) * delta * 10.0
	var n := int(ceil(delta / SUBSTEP)); var h := delta / n
	for i in n:   # semi-implicit, in small steps: stable at any frame rate
		_head_v += ((want - _head) * freq * freq - _head_v * 2.0 * zeta * freq) * h
		_head += _head_v * h

	# ---------------- the mouth
	var spoken := _speech_jaw(delta)
	if not talking and ghost_mouth > 0.0:
		ghost_mouth = maxf(0.0, ghost_mouth - delta)
		spoken = (0.35 + 0.25 * sin(_t * 23.0)) * clampf(ghost_mouth, 0.0, 1.0) * absf(sin(_t * 9.0))
	var jaw_want := maxf(_p.jaw + g.jaw, spoken * 0.62 * clampf(loud, 0.3, 1.6))
	if emotion in ["angry", "furious"] and talking: jaw_want *= 1.25
	for i in n:
		_jaw_v += ((jaw_want - _jaw) * 380.0 - _jaw_v * 2.0 * 0.6 * 19.5) * h
		_jaw += _jaw_v * h
	# squash: jolts compress the cloth; the posture slumps or tenses it
	var sq_want: float = _p.squash + g.squash + clampf(-wacc.y * 0.012, -0.4, 0.4) * (1.0 - still)
	for i in n:
		_sq_v += ((sq_want - _sq) * 120.0 - _sq_v * 8.0) * h
		_sq += _sq_v * h
	if not (is_finite(_head.x + _head.y + _head.z + _jaw + _sq)):   # never let a bad frame stick
		_head = Vector3.ZERO; _head_v = Vector3.ZERO; _jaw = 0.0; _jaw_v = 0.0; _sq = 0.0; _sq_v = 0.0

	rig.wrist = _head
	rig.jaw = maxf(_jaw, -0.05)
	rig.skew = (0.35 if emotion in ["angry", "furious", "lying"] else 0.08) * sin(_t * 0.4 + 1.0)
	rig.curl = _p.curl + g.curl
	rig.squash = _sq
	rig.apply_pose()
	rig.gaze_world = _eyes_on
	rig.gaze_pull = lerpf(1.0, 3.0, still)
	rig.update_eyes(delta)
	_spill.global_position = rig.head_global().origin + cam.global_transform.basis.z * 0.25 + Vector3(0, 0.1, 0)

var _face_s := 0.0
var _pull := 0.0

## Where the elbow-forearm goes, in the camera's frame: blended between held ahead (show), low
## (busy, running) and turned back to face Kurt; then the walk, the emotion and the gesture, and
## pulled in if the hand would go into a wall.
func _target_xf(g := {}) -> Transform3D:
	var show_w := Vector3(-0.11, -0.15, -0.34);  var show_e := Vector3(-0.35, -0.35, 0.0)
	var low_w := Vector3(-0.2, -0.34, -0.3);      var low_e := Vector3(-0.36, -0.52, 0.04)
	var face_wp := Vector3(-0.04, -0.03, -0.36);  var face_e := Vector3(-0.07, -0.36, -0.6)
	var W := show_w.lerp(low_w, pose_low).lerp(face_wp, _face_s)
	var E := show_e.lerp(low_e, pose_low).lerp(face_e, _face_s)
	W.y += _p.get("lift", 0.0); W.z -= _p.get("lean", 0.0)
	W.y -= (1.0 - shown) * 0.42; E.y -= (1.0 - shown) * 0.42
	if player:
		var hs := Vector2(player.velocity.x, player.velocity.z).length()
		var bob: float = player.get("bob")
		W += Vector3(sin(bob) * 0.006, absf(sin(bob)) * -0.01, 0) * minf(hs, 2.5)
	if g.has("arm"):
		W += g.arm
	# don't put the hand through the wall: pull it back along the forearm
	var cxf := cam.global_transform
	var tip_cam := W + (W - E).normalized() * 0.14
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space:
		var from := cxf.origin
		var to := cxf * tip_cam
		var q := PhysicsRayQueryParameters3D.create(from, to + (to - from).normalized() * 0.04)
		if player: q.exclude = [player.get_rid()]
		var hit := space.intersect_ray(q)
		var over := 0.0
		if hit:
			over = clampf((to - from).length() + 0.04 - from.distance_to(hit.position), 0.0, 0.14)
		# eased, so brushing past a door frame is a movement of the arm, not a jump
		_pull = lerpf(_pull, over, 0.25 if over > _pull else 0.08)
		W -= (W - E).normalized() * _pull
		W.x -= _pull * 0.3
	var dir := (W - E).normalized()
	var up := Vector3.UP.lerp(Vector3.FORWARD, _face_s * 0.9).normalized()   # back of the hand away from him: the wrist bends forward and the face comes round to him, top up
	var basis := Basis.looking_at(dir, up)
	var origin := W - dir * FOREARM
	return cxf * Transform3D(basis, origin)

## Gaze priority (bible §7.2): an event, then Kurt (when he's turned to face him), then his own
## intention (D), then what the player is aiming at, then idle wandering (eyes first, head after).
func _gaze(delta: float, still: float) -> Vector3:
	var camp := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var p: Vector3
	if _event_t > 0.0 and _event_gaze != null:
		p = _event_gaze
	elif _kurt_t > 0.0 or _face_s > 0.6:
		p = camp + cam.global_transform.basis.y * -0.12   # your mouth, not your eyes: his face tips down to you and his eyes come round
	elif _intent_t > 0.0 and _intent_gaze != null:
		p = _intent_gaze
	elif _g_target != null and _gesture in ["point", "lean_in"]:
		p = _g_target
	elif player and player.get("target") is Node3D:
		p = (player.target as Node3D).global_position
	else:
		_wander_t -= delta * (_p.wander if _p.wander > 0.01 else 0.0)
		if _wander_t <= 0.0 or _wander == Vector3.ZERO:
			_wander_t = _rng.randf_range(2.0, 5.0)
			var b := cam.global_transform.basis
			_wander = b * Vector3(_rng.randf_range(-1.2, 0.8), _rng.randf_range(-0.6, 0.3), -2.5)
		p = camp + _wander if _p.wander > 0.01 else camp + fwd * 2.5 + Vector3(0, -0.4, 0)
	# the eyes lead; the head follows a beat behind (slower when he's calm, instant when still)
	_eyes_on = _eyes_on.lerp(p, 1.0 - pow(0.0005, delta)) if _eyes_on != Vector3.ZERO else p
	_head_on = _head_on.lerp(_eyes_on, 1.0 - pow(lerpf(0.05, 0.0005, still), delta)) if _head_on != Vector3.ZERO else p
	return _head_on

var _head_on := Vector3.ZERO

# ---------------------------------------------------------------- gestures (bible §6)
## Offsets for the current gesture at its normalised time, with anticipation and settle.
func _gesture_offsets(delta: float) -> Dictionary:
	var o := {"head": Vector3.ZERO, "arm": Vector3.ZERO, "jaw": 0.0, "curl": 0.0, "squash": 0.0, "face": 0.0}
	if _gesture == "":
		return o
	_g_t += delta
	var u := _g_t / _g_len
	if u >= 1.0:
		_gesture = ""; _g_target = null
		return o
	var env := smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.75, 1.0, u))
	var a := _g_amp
	match _gesture:
		"nod":
			o.head.x = (0.06 * (1.0 - smoothstep(0.0, 0.12, u)) - 0.32 * absf(sin(u * TAU))) * env * a
			o.jaw = 0.05 * env
		"shake":
			o.head.y = 0.35 * sin(u * TAU * 2.0) * env * a; o.head.x = -0.08 * env
		"point":
			# index extends, the others curl; the wrist turns to it, the body leans in; aggressive
			# points arrive head first
			o.curl = -0.6 * env; o.jaw = -0.04 * env
			if _g_target != null:
				var to: Vector3 = cam.global_transform.affine_inverse() * (_g_target as Vector3)
				o.arm = to.normalized() * 0.07 * env * a + Vector3(0.02, 0.03, 0) * env
			o.head.x += 0.05 * sin(u * PI * 6.0) * env * (1.0 - u)
		"recoil":
			var k := (1.0 - smoothstep(0.0, 0.08, u)) * 0.2 + smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.4, 1.0, u))
			o.arm = Vector3(-0.015, -0.03, 0.06) * k * a; o.head.x = -0.35 * k * a; o.curl = 0.5 * k; o.squash = 0.5 * k
		"wince":
			var k2 := sin(PI * minf(u * 1.6, 1.0))
			o.head.x = -0.25 * k2; o.head.z = 0.25 * k2; o.jaw = 0.18 * k2; o.squash = 0.4 * k2; o.curl = 0.25 * k2
		"wave":
			o.head.z = 0.35 * sin(u * TAU * 2.5) * env * a; o.arm.y = 0.04 * env; o.jaw = 0.25 * env
		"cover":
			# he turns his face into the crook of the arm and folds up
			var k3 := smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.8, 1.0, u))
			o.head = Vector3(-0.85, 0.6, 0.3) * k3; o.curl = 0.8 * k3; o.squash = 0.6 * k3; o.arm = Vector3(0.02, -0.02, 0.04) * k3
		"lean_in":
			o.arm = Vector3(0.01, 0.015, -0.07) * env * a; o.head.x = 0.12 * env; o.jaw = 0.06 * env
		"beckon":
			o.head.x = (0.25 * absf(sin(u * TAU * 2.0)) - 0.05) * env; o.arm.z = 0.03 * absf(sin(u * TAU * 2.0)) * env; o.jaw = 0.1 * env
		"bounce":
			o.arm.y = 0.025 * sin(u * PI) * a; o.squash = -0.3 * sin(u * PI * 2.0)
		"look_round":
			o.head.y = 0.75 * sin(u * TAU) * env * a; o.head.x = 0.1 * env
	return o
