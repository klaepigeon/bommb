class_name Socko
extends Node3D
## Socko: the first build's sock (SockRig: the left forearm and hand and the sock over them, one
## skinned mesh on one skeleton; the fingers are his upper jaw, the thumb his lower; two googly
## eyes on ping-pong balls, each with a loose pupil). This node lives in the camera's space and
## places the arm; the rig does the cloth, the mouth and the eyes.
##
## Layers: where the hand is held (pose) → where he looks (Kurt, ahead, something he's pointing at,
## per-eye overrides) with the head on a spring behind the wrist → emotion (the mouth's corners,
## posture) → gestures (nod, tilt, bounce, startle, wiggle: additive, decaying) → speech (the jaw
## from Speech.mouth).

## [wrist, elbow-direction point] in camera space (the first build's held positions)
const POSES := {
	"hidden": [Vector3(-0.2, -0.76, -0.3), Vector3(-0.36, -0.94, 0.04)],
	"low":    [Vector3(-0.2, -0.34, -0.3), Vector3(-0.36, -0.52, 0.04)],
	"up":     [Vector3(-0.11, -0.15, -0.34), Vector3(-0.35, -0.35, 0.0)],
	"talk":   [Vector3(-0.01, -0.1, -0.3), Vector3(-0.24, -0.16, -0.43)],
}
const FOREARM := SockRig.FOREARM_LEN

var face_kurt := 0.0
## The scenes' shorthand for how he's feeling; each is one of the expressions below.
var emotion := "neutral":
	set(v):
		emotion = v
		expression = EMOTION_FACE.get(v, v)
## The face he's holding (SockoClips.EXPRESSIONS: smile, wide_smile, uncomfortable_smile, frown,
## confusion, surprise, excitement, disappointment, irritation, anger, forced_happiness,
## nervousness, suspicion, panic, unnatural_stillness, neutral). Lines can set it (content: "socko_face").
var expression := "neutral"
var idle_clip := "Idle_Default"
const EMOTION_FACE := {"neutral": "neutral", "happy": "smile", "proud": "wide_smile", "curious": "confusion", "sly": "suspicion"}
const TALK_FOR := {"smile": "Talking_Excited", "wide_smile": "Talking_Excited", "excitement": "Talking_Excited",
	"confusion": "Talking_Confused", "irritation": "Talking_Annoyed", "anger": "Talking_Threatening",
	"disappointment": "Talking_Sarcastic", "suspicion": "Talking_Sarcastic", "panic": "Talking_Desperate",
	"nervousness": "Talking_Desperate", "forced_happiness": "Talking_Excited", "uncomfortable_smile": "Talking_Sympathetic"}
var gaze_override := [null, null]
var rig: SockRig
var body: CollisionObject3D      ## Kurt (rays that look for walls leave him out)
var _pull := 0.0

var _w := Vector3.ZERO
var _e := Vector3.ZERO
var _w_from := Vector3.ZERO
var _e_from := Vector3.ZERO
var _w_to := Vector3.ZERO
var _e_to := Vector3.ZERO
var _k := 1.0
var _dur := 0.0
var _trans := Tween.TRANS_SINE
var _t := 0.0
var _g := {"nod": 0.0, "tilt": 0.0, "bounce": 0.0, "startle": 0.0, "wiggle": 0.0}
var _head := Vector3.ZERO
var _head_v := Vector3.ZERO
var _jaw := 0.0
var _jaw_v := 0.0
var _smile := 0.0
var _cross := false
var _point := Vector3.INF
var _clips: Array = []        ## [{name, t}] playing on top
var _face := {}               ## the held expression's channels, eased
var _idle_t := 0.0
var _talk_t := 0.0
var _talk_clip := ""
var _style := ""

func build() -> void:
	rig = SockRig.new()
	rig.name = "SockRig"
	add_child(rig)
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_pose("hidden", 0.0)
	visible = false
	Speech.line_cue.connect(_on_cue)
	Speech.line_started.connect(_on_line_started)
	Speech.line_finished.connect(_relax)
	Speech.line_finished.connect(_lower_after)

## Out of a scene (walking the town), he's held low, out of the way. With this on, he comes up
## into view to say his lines (so you see him say them) and goes back down after.
var present_when_talking := false
var _pose := "hidden"
var _raised := false
var _raise_n := 0

func _on_line_started(sp: String, _text: String) -> void:
	if sp != "socko":
		return
	_talk_t = 0.0
	if present_when_talking and visible and (_pose == "low" or _raised):
		_raise_n += 1
		if not _raised:
			_set_pose_internal("up", 0.35, Tween.TRANS_BACK)
			_raised = true

func _lower_after(sp: String) -> void:
	if sp != "socko" or not _raised:
		return
	var n := _raise_n
	await get_tree().create_timer(0.9, false).timeout
	if n == _raise_n and _raised and Speech.speaking != "socko":
		_raised = false
		_set_pose_internal("low", 0.7)

## Plays one of SockoClips' clips on top of whatever he's doing (Head_Nod, Face_Surprise,
## Laughing, Peeking...). It ends by itself.
func play(clip: String) -> void:
	if SockoClips.has(clip):
		_clips.append({"name": clip, "t": 0.0})

## A line's cues from content: socko_face (hold an expression), socko_clip (play a clip),
## socko_talk (the talking style for this line), socko_idle (what he does when quiet).
var _cue_n := 0

## A while after a line, a face that isn't held on purpose goes back to his ordinary one.
func _relax(_speaker: String) -> void:
	var n := _cue_n
	await get_tree().create_timer(2.2, false).timeout
	if n == _cue_n and Speech.speaking == "" and expression != "unnatural_stillness":
		expression = EMOTION_FACE.get(emotion, "neutral") if emotion != "neutral" else "neutral"

func _on_cue(_id: String, l: Dictionary) -> void:
	_cue_n += 1
	if l.has("socko_face"):
		expression = String(l["socko_face"])
	if l.has("socko_clip"):
		play(String(l["socko_clip"]))
	if l.has("socko_idle"):
		idle_clip = String(l["socko_idle"])
	_talk_clip = String(l.get("socko_talk", ""))
	_style = String(l.get("style", ""))

func set_pose(name: String, seconds := 0.6, trans := Tween.TRANS_SINE) -> void:
	_raised = false          # a scene placing him outright takes over from talking-raise
	_set_pose_internal(name, seconds, trans)

func _set_pose_internal(name: String, seconds: float, trans := Tween.TRANS_SINE) -> void:
	if not POSES.has(name):
		push_error("Socko: no pose " + name)
		return
	_pose = name
	var p: Array = POSES[name]
	_w_from = _w
	_e_from = _e
	_w_to = p[0]
	_e_to = p[1]
	_trans = trans
	_dur = maxf(seconds, 0.0001)
	_k = 0.0 if seconds > 0.0 else 1.0
	if seconds <= 0.0:
		_w = _w_to
		_e = _e_to

## Up into view from below: overshoots, settles; a soft wet pop.
func enter() -> void:
	visible = true
	set_pose("hidden", 0.0)
	set_pose("up", 0.9, Tween.TRANS_BACK)
	Sfx.play("pop", -6.0)
	gesture("bounce", 1.0)

## The scenes' shorthand gestures: each is a clip from the library.
func gesture(name: String, amount := 1.0) -> void:
	match name:
		"nod": play("Head_Nod")
		"tilt": play("Head_Tilt_Left" if amount >= 0.0 else "Head_Tilt_Right")
		"bounce": play("Head_Bob")
		"startle": play("Sudden_Surprise")
		"wiggle": play("Giggling")
		_: _g[name] = amount

func cross_eyes(on: bool) -> void:
	_cross = on

func point_at(world: Vector3) -> void:
	_point = world
	if world != Vector3.INF:
		face_kurt = 0.0

func divided_glance(at: Vector3, seconds := 1.4) -> void:
	gaze_override[1] = at
	await get_tree().create_timer(seconds, false).timeout
	gaze_override[1] = null

func _process(delta: float) -> void:
	if not visible or rig == null:
		return
	delta = minf(delta, 0.1)
	_t += delta
	for k in _g:
		_g[k] = move_toward(float(_g[k]), 0.0, delta * (1.2 if k != "tilt" else 0.6))
	# ---- the clip layers: idle under everything, talking while he talks, played clips on top,
	# and the held expression (eased so faces change like a hand changing its grip)
	var m := Speech.mouth("socko")
	var talking := Speech.speaking == "socko"
	var ch := _channels(delta, m, talking)
	# ---- where the hand is (camera space: this node's parent is the camera)
	_k = minf(_k + delta / _dur, 1.0)
	var e := Tween.interpolate_value(0.0, 1.0, _k, 1.0, _trans, Tween.EASE_OUT) as float
	var W := _w_from.lerp(_w_to, e)
	var E := _e_from.lerp(_e_to, e)
	if _point != Vector3.INF:
		var par := get_parent() as Node3D
		var tp: Vector3 = par.to_local(_point) if par else _point
		var want: Vector3 = (tp - W).normalized()
		W = W.lerp(Vector3(-0.08, -0.13, -0.36), 0.7)
		E = W - want * 0.3
	W.y += sin(_t * 1.6) * 0.004
	var arm_add: Vector3 = ch.get("arm", Vector3.ZERO)
	W += arm_add
	W.y -= float(ch.get("hide", 0.0)) * 0.42
	E.y -= float(ch.get("hide", 0.0)) * 0.42
	# don't put the hand through a wall: draw it back along the forearm, and in a little
	var cam_node := get_parent() as Node3D
	if cam_node and is_inside_tree():
		var tip := W + (W - E).normalized() * 0.15
		var from := cam_node.global_position
		var to: Vector3 = cam_node.global_transform * tip
		var ray_dir := (to - from).normalized()
		var q := PhysicsRayQueryParameters3D.create(from, to + ray_dir * 0.05, 1)
		if body:
			q.exclude = [body.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		var over := 0.0
		if hit:
			over = clampf(from.distance_to(to) + 0.05 - from.distance_to(hit.position), 0.0, 0.3)
		_pull = lerpf(_pull, over, 0.3 if over > _pull else 0.1)
		if _pull > 0.001:
			W -= tip.normalized() * _pull
			E -= tip.normalized() * _pull * 0.5
			W.y -= _pull * 0.25
	_w = W
	_e = E
	var dir := (W - E).normalized()
	transform = Transform3D(Basis.looking_at(dir, Vector3.UP), W - dir * FOREARM)
	# ---- where he looks
	var aim: Vector3
	var cam := get_parent() as Node3D
	var cam_pos: Vector3 = cam.global_position if cam else global_position
	var cam_up: Vector3 = cam.global_transform.basis.y if cam else Vector3.UP
	if _point != Vector3.INF:
		aim = _point
	elif face_kurt + float(ch.get("face", 0.0)) > 0.01:
		var ahead := global_transform * Vector3(0, -0.2, -FOREARM - 2.0)
		aim = ahead.lerp(cam_pos - cam_up * 0.12, clampf(face_kurt + float(ch.get("face", 0.0)), 0.0, 1.0))
	else:
		aim = global_transform * Vector3(sin(_t * 0.4) * 0.3, -0.25, -FOREARM - 2.5)
	var local := global_transform.affine_inverse() * aim - Vector3(0, 0, -FOREARM)
	var up_l := (global_transform.basis.inverse() * cam_up).normalized()
	var dl := local.normalized()
	var arc: Vector3
	if absf(dl.dot(up_l)) < 0.97:
		arc = Basis.looking_at(dl, up_l).get_euler(EULER_ORDER_YXZ)
	else:
		arc = Basis(Quaternion(Vector3.FORWARD, dl)).get_euler(EULER_ORDER_YXZ)
	var yaw := clampf(arc.y, -1.3, 1.3)
	var pitch := clampf(arc.x, -1.05, 1.15)
	var roll := clampf(arc.z, -0.6, 0.6)
	# emotion and gestures on top
	var tilt: float = _g["tilt"] * 0.45 + (0.2 if emotion == "curious" else 0.0) + (-0.12 if emotion == "sly" else 0.0)
	var nod: float = sin(_t * 9.0) * _g["nod"] * 0.3
	var wig: float = sin(_t * 17.0) * _g["wiggle"] * 0.25
	var startle: float = _g["startle"]
	var proud := 0.12 if emotion in ["proud", "happy"] else 0.0
	var still := clampf(float(ch.get("still", 0.0)), 0.0, 1.0)
	var bob := m * 0.1 if talking else 0.0
	var tremble := float(ch.get("tremble", 0.0))
	var shake := Vector3(sin(_t * 37.0) + sin(_t * 53.0), sin(_t * 41.0), sin(_t * 29.0)) * 0.012 * tremble
	var head_add: Vector3 = ch.get("head", Vector3.ZERO)
	var want_head: Vector3 = Vector3(pitch + proud * 0.5 + bob + nod + startle * 0.35, yaw + wig, roll + tilt) + head_add * (1.0 - still * 0.5) + shake
	# the head on a spring behind the wrist (it lags, overshoots, settles)
	var n := int(ceil(delta / 0.004))
	var h := delta / n
	for i in n:
		_head_v += ((want_head - _head) * 110.0 - _head_v * 2.0 * 0.5 * 10.5) * h
		_head += _head_v * h
	# the mouth
	var jaw_mul := 1.0 + float(ch.get("jaw_mul", 0.0))
	if _style == "quiet" and talking:
		jaw_mul *= 0.45
	var jaw_want := maxf(m * 0.62 * maxf(jaw_mul, 0.2) + float(ch.get("jaw", 0.0)), -0.05) + startle * 0.7
	for i in n:
		_jaw_v += ((jaw_want - _jaw) * 380.0 - _jaw_v * 2.0 * 0.6 * 19.5) * h
		_jaw += _jaw_v * h
	if not is_finite(_head.x + _head.y + _head.z + _jaw):
		_head = Vector3.ZERO; _head_v = Vector3.ZERO; _jaw = 0.0; _jaw_v = 0.0
	var smile := float(ch.get("smile", 0.0))
	rig.wrist = _head
	rig.jaw = maxf(_jaw, -0.05)
	rig.smile_l = clampf(smile + float(ch.get("smile_l", 0.0)), -1.0, 1.0)
	rig.smile_r = clampf(smile + float(ch.get("smile_r", 0.0)), -1.0, 1.0)
	rig.wide = clampf(float(ch.get("wide", 0.0)), -1.0, 1.0)
	rig.pucker = clampf(float(ch.get("pucker", 0.0)), -1.0, 1.0)
	rig.skew = clampf(float(ch.get("skew", 0.0)), -1.0, 1.0)
	rig.squash = clampf(float(ch.get("squash", 0.0)) - startle * 0.5, -1.0, 1.0)
	rig.stretch = clampf(float(ch.get("stretch", 0.0)) + startle * 0.4 + m * 0.08, -1.0, 1.0)
	rig.twist = clampf(float(ch.get("twist", 0.0)), -1.0, 1.0)
	rig.curl = clampf(float(ch.get("curl", 0.0)), -1.0, 1.0)
	rig.apply_pose()
	# the eyes: on Kurt when he's facing him, crossed, or where they've been told
	for i in 2:
		var t = null
		if _cross:
			t = rig.head_global() * Vector3(0, 0.03, -0.075)
		elif gaze_override[i] != null:
			t = gaze_override[i]
		elif _point != Vector3.INF:
			t = _point
		elif face_kurt > 0.5:
			t = cam_pos
		rig.eye_targets[i] = t
	rig.update_eyes(delta)

## Everything the clip layers add this frame, summed by channel.
func _channels(delta: float, m: float, talking: bool) -> Dictionary:
	var out := {}
	_idle_t += delta
	var idle_k := 1.0 - face_kurt * 0.4
	_add(out, SockoClips.sample(idle_clip, _idle_t, {"amp": idle_k}), 1.0)
	if talking:
		_talk_t += delta
		var tc := _talk_clip
		if tc == "":
			tc = "Talking_Whispering" if _style == "quiet" else String(TALK_FOR.get(expression, "Talking_Default"))
		_add(out, SockoClips.sample(tc, _talk_t, {"speech": m, "amp": 1.0}), 1.0)
	var keep: Array = []
	for c in _clips:
		c.t += delta
		_add(out, SockoClips.sample(c.name, c.t, {"speech": m, "amp": 1.0}), 1.0)
		if SockoClips.loops(c.name) or c.t < SockoClips.length(c.name):
			keep.append(c)
	_clips = keep
	# the held face, eased toward its channels
	var want: Dictionary = SockoClips.EXPRESSIONS.get(expression, {})
	var k := 1.0 - exp(-delta * 6.0)
	for key in want:
		if not _face.has(key):
			_face[key] = Vector3.ZERO if want[key] is Vector3 else 0.0
	for key in _face.keys():
		var target = want.get(key, Vector3.ZERO if _face[key] is Vector3 else 0.0)
		_face[key] = lerp(_face[key], target, k)
	_add(out, _face, 1.0)
	return out

static func _add(into: Dictionary, ch: Dictionary, w: float) -> void:
	for key in ch:
		var v = ch[key]
		if v is Vector3:
			into[key] = into.get(key, Vector3.ZERO) + v * w
		elif v is float or v is int:
			into[key] = float(into.get(key, 0.0)) + float(v) * w
