class_name Socko
extends Node3D
## Socko's body: the first build's sock (SockRig: one skinned sock over the forearm and hand; the
## fingers his upper jaw, the thumb his lower; googly eyes with loose pupils) and its clip library
## (SockoClips: ~70 clips, 16 expressions), performed. This node lives in Kurt's camera and holds
## the arm; what he wants and says is SockoMind.
##
## Layers, bottom to top: where the hand's held (pose) → where he looks (Kurt, a thing, a threat,
## somewhere he's pointing, you) with the head on a spring behind the wrist → the held expression
## and clips (idle, talking, reactions) → speech (the mouth from Speech.mouth) → the hand's own
## fear (a tremble near danger) → layer D (stillness: when he's being wrong).

const POSES := {
	"hidden": [Vector3(-0.2, -0.76, -0.3), Vector3(-0.36, -0.94, 0.04)],
	"low":    [Vector3(-0.2, -0.34, -0.3), Vector3(-0.36, -0.52, 0.04)],
	"up":     [Vector3(-0.11, -0.15, -0.34), Vector3(-0.35, -0.35, 0.0)],
	"talk":   [Vector3(-0.01, -0.1, -0.3), Vector3(-0.24, -0.16, -0.43)],
}
const FOREARM := SockRig.FOREARM_LEN
const TALK_FOR := {"smile": "Talking_Excited", "wide_smile": "Talking_Excited", "excitement": "Talking_Excited",
	"confusion": "Talking_Confused", "irritation": "Talking_Annoyed", "anger": "Talking_Threatening",
	"disappointment": "Talking_Sarcastic", "suspicion": "Talking_Sarcastic", "panic": "Talking_Desperate",
	"nervousness": "Talking_Desperate", "forced_happiness": "Talking_Excited", "uncomfortable_smile": "Talking_Sympathetic"}

var rig: SockRig
var kurt: Kurt
var expression := "neutral"
var idle_clip := "Idle_Default"
var face_kurt := 0.0               ## 0 ahead .. 1 turned to Kurt
var look_target = null             ## a point he's looking at (an interesting thing, a threat)
var fear := 0.0                    ## 0..1: trembling, eyes wide, the hand drawn in
var stillness := 0.0               ## layer D: the wrongness
var at_player := 0.0               ## looking straight out of the screen
var torch_on := false
var _w := Vector3.ZERO; var _e := Vector3.ZERO
var _w_from := Vector3.ZERO; var _e_from := Vector3.ZERO
var _w_to := Vector3.ZERO; var _e_to := Vector3.ZERO
var _k := 1.0; var _dur := 0.0; var _trans := Tween.TRANS_SINE
var _t := 0.0
var _head := Vector3.ZERO; var _head_v := Vector3.ZERO
var _jaw := 0.0; var _jaw_v := 0.0
var _cross := false
var _point := Vector3.INF
var _clips: Array = []
var _face := {}
var _idle_t := 0.0
var _talk_t := 0.0
var _talk_clip := ""
var _style := ""
var _pull := 0.0
var _cue_n := 0
var _zone := -99

func build(k: Kurt) -> void:
	kurt = k
	rig = SockRig.new(); rig.name = "SockRig"
	add_child(rig)
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in m.get_surface_override_material_count():
			_tune(m.get_surface_override_material(i))
		if m.material_override is BaseMaterial3D:
			# the googly eyes are plain materials: put them on the game's lighting, bright (they're white)
			var conv := (Mats.convert(m.material_override, -1) as ShaderMaterial).duplicate() as ShaderMaterial
			conv.set_shader_parameter("snap", 0.0)
			conv.set_shader_parameter("self_lit", 0.6)
			m.material_override = conv
		_tune(m.material_override)
		if m.mesh:
			for i in m.mesh.get_surface_count():
				_tune(m.mesh.surface_get_material(i))
	set_pose("hidden", 0.0)
	visible = false
	Speech.line_cue.connect(_on_cue)
	Speech.line_started.connect(func(sp, _t): if sp == "socko": _talk_t = 0.0)
	Speech.line_finished.connect(_relax)

func _tune(m) -> void:
	if m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter("snap", 0.0)
		(m as ShaderMaterial).set_shader_parameter("zone", -1.0)
		(m as ShaderMaterial).set_shader_parameter("ambient", Vector3(0.3, 0.27, 0.25))     # he's in the torch's spill: always readable

func play(clip: String) -> void:
	if SockoClips.has(clip): _clips.append({"name": clip, "t": 0.0})

func _relax(_speaker: String) -> void:
	var n := _cue_n
	await get_tree().create_timer(2.2, false).timeout
	if n == _cue_n and Speech.speaking == "" and expression != "unnatural_stillness":
		expression = "neutral"

func _on_cue(_id: String, l: Dictionary) -> void:
	_cue_n += 1
	if l.has("socko_face"): expression = String(l["socko_face"])
	if l.has("socko_clip"): play(String(l["socko_clip"]))
	_talk_clip = String(l.get("socko_talk", ""))
	_style = String(l.get("style", ""))
	if String(l.get("speaker", "")) == "socko" or l.has("socko_face"):
		face_kurt = maxf(face_kurt, 0.7)

func set_pose(name: String, seconds := 0.6, trans := Tween.TRANS_SINE) -> void:
	var p: Array = POSES[name]
	_w_from = _w; _e_from = _e; _w_to = p[0]; _e_to = p[1]
	_trans = trans; _dur = maxf(seconds, 0.0001); _k = 0.0 if seconds > 0.0 else 1.0
	if seconds <= 0.0: _w = _w_to; _e = _e_to

## Up into view from below: overshoots, settles; a soft wet pop.
func enter() -> void:
	visible = true
	set_pose("hidden", 0.0)
	set_pose("up", 0.9, Tween.TRANS_BACK)
	Audio.play("pop", null, -6.0)
	play("Head_Bob")

func cross_eyes(on: bool) -> void:
	_cross = on

func point_at(world: Vector3) -> void:
	_point = world
	if world != Vector3.INF: face_kurt = 0.0

func gesture(name: String) -> void:
	match name:
		"nod": play("Head_Nod")
		"shake": play("Head_Shake")
		"tilt": play("Head_Tilt_Left")
		"bounce": play("Head_Bob")
		"startle": play("Sudden_Surprise")
		"laugh": play("Giggling")
		"peek": play("Peeking")

## The torch is in his mouth: it shines where Kurt looks, as bright as his mouth is open.
func _torch() -> void:
	Lights.torch.on = torch_on and visible
	if not torch_on or not visible: return
	var m := rig.mouth_global()
	var cam := get_parent() as Node3D
	Lights.torch.pos = m.origin
	var aim := cam.global_position - cam.global_transform.basis.z * 6.0
	Lights.torch.dir = (aim - m.origin).normalized()
	Lights.torch.energy = 0.75 + clampf(_jaw, 0.0, 0.6) * 0.6
	Lights.torch.cos = 0.82
	rig.mouth_mat.set_shader_parameter("glow", Vector3(1.0, 0.75, 0.55) * 0.9)

func _process(delta: float) -> void:
	if not visible or rig == null: return
	delta = minf(delta, 0.1)
	_t += delta
	var m := Speech.mouth("socko")
	var talking := Speech.speaking == "socko"
	var ch := _channels(delta, m, talking)
	_k = minf(_k + delta / _dur, 1.0)
	var e := Tween.interpolate_value(0.0, 1.0, _k, 1.0, _trans, Tween.EASE_OUT) as float
	var W := _w_from.lerp(_w_to, e)
	var E := _e_from.lerp(_e_to, e)
	var cam := get_parent() as Node3D
	if _point != Vector3.INF:
		var tp: Vector3 = cam.to_local(_point)
		var want: Vector3 = (tp - W).normalized()
		W = W.lerp(Vector3(-0.08, -0.13, -0.36), 0.7)
		E = W - want * 0.3
	# fear draws the hand in toward the body
	W = W.lerp(Vector3(-0.16, -0.24, -0.26), fear * 0.4)
	W.y += sin(_t * 1.6) * 0.004 * (1.0 - stillness)
	W += ch.get("arm", Vector3.ZERO)
	W.y -= float(ch.get("hide", 0.0)) * 0.42
	E.y -= float(ch.get("hide", 0.0)) * 0.42
	# breathing: Kurt's stamina shows in the hand's lift
	if kurt: W.y += sin(_t * (2.0 + (1.0 - kurt.stamina) * 5.0)) * 0.01 * (1.0 - kurt.stamina)
	# not through walls
	var tip := W + (W - E).normalized() * 0.15
	var from := cam.global_position
	var to: Vector3 = cam.global_transform * tip
	var q := PhysicsRayQueryParameters3D.create(from, to + (to - from).normalized() * 0.05, 1)
	if kurt: q.exclude = [kurt.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var over := clampf(from.distance_to(to) + 0.05 - from.distance_to(hit.position), 0.0, 0.3) if hit else 0.0
	_pull = lerpf(_pull, over, 0.3 if over > _pull else 0.1)
	if _pull > 0.001:
		W -= tip.normalized() * _pull; E -= tip.normalized() * _pull * 0.5; W.y -= _pull * 0.25
	_w = W; _e = E
	var dir := (W - E).normalized()
	transform = Transform3D(Basis.looking_at(dir, Vector3.UP), W - dir * FOREARM)
	# where he looks
	var cam_pos := cam.global_position
	var cam_up := cam.global_transform.basis.y
	var aim: Vector3
	var fk := clampf(face_kurt + float(ch.get("face", 0.0)) + at_player, 0.0, 1.0)
	if _point != Vector3.INF: aim = _point
	elif look_target != null and fk < 0.5: aim = look_target
	elif fk > 0.01:
		var ahead := global_transform * Vector3(0, -0.2, -FOREARM - 2.0)
		aim = ahead.lerp(cam_pos - cam_up * (0.12 if at_player < 0.5 else -0.02), fk)
	else:
		aim = global_transform * Vector3(sin(_t * 0.4) * 0.3, -0.25, -FOREARM - 2.5)
	var local := global_transform.affine_inverse() * aim - Vector3(0, 0, -FOREARM)
	var up_l := (global_transform.basis.inverse() * cam_up).normalized()
	var dl := local.normalized()
	var arc: Vector3
	if absf(dl.dot(up_l)) < 0.97: arc = Basis.looking_at(dl, up_l).get_euler(EULER_ORDER_YXZ)
	else: arc = Basis(Quaternion(Vector3.FORWARD, dl)).get_euler(EULER_ORDER_YXZ)
	var still := clampf(float(ch.get("still", 0.0)) + stillness, 0.0, 1.0)
	var tremble := float(ch.get("tremble", 0.0)) + fear * 0.8
	var shake := Vector3(sin(_t * 37.0) + sin(_t * 53.0), sin(_t * 41.0), sin(_t * 29.0)) * 0.012 * tremble
	var bob := m * 0.1 if talking else 0.0
	var want_head := Vector3(clampf(arc.x, -1.05, 1.15) + bob, clampf(arc.y, -1.3, 1.3), clampf(arc.z, -0.6, 0.6)) + (ch.get("head", Vector3.ZERO) as Vector3) * (1.0 - still * 0.5) + shake
	var n := int(ceil(delta / 0.004)); var h := delta / n
	var damping := lerpf(10.5, 30.0, still)
	for i in n:
		_head_v += ((want_head - _head) * 110.0 - _head_v * damping) * h
		_head += _head_v * h
	var jaw_mul := 1.0 + float(ch.get("jaw_mul", 0.0))
	if _style == "quiet" and talking: jaw_mul *= 0.45
	var jaw_want := maxf(m * 0.62 * maxf(jaw_mul, 0.2) + float(ch.get("jaw", 0.0)), -0.05) + (0.35 if torch_on else 0.0)
	for i in n:
		_jaw_v += ((jaw_want - _jaw) * 380.0 - _jaw_v * 23.4) * h
		_jaw += _jaw_v * h
	if not is_finite(_head.x + _head.y + _head.z + _jaw):
		_head = Vector3.ZERO; _head_v = Vector3.ZERO; _jaw = 0.0; _jaw_v = 0.0
	var smile := float(ch.get("smile", 0.0))
	rig.wrist = _head
	rig.jaw = maxf(_jaw, -0.05)
	rig.smile_l = clampf(smile + float(ch.get("smile_l", 0.0)), -1.0, 1.0)
	rig.smile_r = clampf(smile + float(ch.get("smile_r", 0.0)), -1.0, 1.0)
	rig.wide = clampf(float(ch.get("wide", 0.0)) + fear * 0.3, -1.0, 1.0)
	rig.pucker = clampf(float(ch.get("pucker", 0.0)), -1.0, 1.0)
	rig.skew = clampf(float(ch.get("skew", 0.0)), -1.0, 1.0)
	rig.squash = clampf(float(ch.get("squash", 0.0)) + fear * 0.25, -1.0, 1.0)
	rig.stretch = clampf(float(ch.get("stretch", 0.0)) + m * 0.08, -1.0, 1.0)
	rig.twist = clampf(float(ch.get("twist", 0.0)), -1.0, 1.0)
	rig.curl = clampf(float(ch.get("curl", 0.0)), -1.0, 1.0)
	rig.apply_pose()
	for i in 2:
		var t = null
		if _cross: t = rig.head_global() * Vector3(0, 0.03, -0.075)
		elif _point != Vector3.INF: t = _point
		elif at_player > 0.5: t = cam_pos + cam.global_transform.basis.z * 0.5
		elif look_target != null and fk < 0.5: t = look_target
		elif fk > 0.5: t = cam_pos
		rig.eye_targets[i] = t
	rig.pupil_gain = 1.0 - stillness * 0.8
	rig.update_eyes(delta)
	_torch()

func _channels(delta: float, m: float, talking: bool) -> Dictionary:
	var out := {}
	_idle_t += delta
	_add(out, SockoClips.sample(idle_clip, _idle_t, {"amp": 1.0 - face_kurt * 0.4}), 1.0)
	if talking:
		_talk_t += delta
		var tc := _talk_clip
		if tc == "": tc = "Talking_Whispering" if _style == "quiet" else String(TALK_FOR.get(expression, "Talking_Default"))
		_add(out, SockoClips.sample(tc, _talk_t, {"speech": m, "amp": 1.0}), 1.0)
	var keep: Array = []
	for c in _clips:
		c.t += delta
		_add(out, SockoClips.sample(c.name, c.t, {"speech": m, "amp": 1.0}), 1.0)
		if SockoClips.loops(c.name) or c.t < SockoClips.length(c.name): keep.append(c)
	_clips = keep
	var want: Dictionary = SockoClips.EXPRESSIONS.get(expression, {})
	var k := 1.0 - exp(-delta * 6.0)
	for key in want:
		if not _face.has(key): _face[key] = Vector3.ZERO if want[key] is Vector3 else 0.0
	for key in _face.keys():
		var target = want.get(key, Vector3.ZERO if _face[key] is Vector3 else 0.0)
		_face[key] = lerp(_face[key], target, k)
	_add(out, _face, 1.0)
	return out

static func _add(into: Dictionary, ch: Dictionary, w: float) -> void:
	for key in ch:
		var v = ch[key]
		if v is Vector3: into[key] = into.get(key, Vector3.ZERO) + v * w
		elif v is float or v is int: into[key] = float(into.get(key, 0.0)) + float(v) * w
