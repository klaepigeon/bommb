class_name Socko
extends Node3D
## Socko in play: Kurt's left forearm and hand in the sock (SockRig), held in the first-person
## view, performing. The rig is the puppet (one skinned mesh over the hand's bones); this decides
## what the hand does with it, frame by frame, in layers that add rather than fight:
##   1. the hold: where the arm is (held out ahead, turned back to talk to Kurt, raised to his
##      forehead, pointing), blended smoothly between holds
##   2. the arm's lag: when Kurt turns his head the arm swings behind and catches up
##   3. emotion: how he carries himself (bounce, slump, the mouth's corners, how open he idles)
##   4. gestures: one-shot moves (recoil, tilt, nod, bounce, point) on top
##   5. speech: the jaw opens on each syllable Dialogue types for him, never the same twice
##   6. the eyes: on a look target, wandering when idle, sometimes one eye on what he wants you
##      to notice while the other stays on you, and cross-eyed on request
## Dialogue steps carry {"socko": {"emotion", "gesture", "look"}} cues; levels call cue() too.

const EMOTIONS := {
	# bounce: idle bob; jaw: resting mouth; smile; squash (+ slumped / - perky); curl; tilt (roll)
	"neutral":      {"bounce": 0.4, "jaw": 0.03, "smile": 0.15, "squash": 0.0,  "curl": 0.0,  "tilt": 0.0},
	"happy":        {"bounce": 1.0, "jaw": 0.1,  "smile": 0.8,  "squash": -0.2, "curl": -0.2, "tilt": 0.08},
	"excited":      {"bounce": 1.6, "jaw": 0.2,  "smile": 1.0,  "squash": -0.4, "curl": -0.4, "tilt": 0.0},
	"curious":      {"bounce": 0.3, "jaw": 0.06, "smile": 0.3,  "squash": -0.15,"curl": -0.1, "tilt": 0.35},
	"nervous":      {"bounce": 0.2, "jaw": 0.02, "smile": -0.3, "squash": 0.5,  "curl": 0.4,  "tilt": -0.1},
	"disappointed": {"bounce": 0.1, "jaw": 0.0,  "smile": -0.6, "squash": 0.5,  "curl": 0.2,  "tilt": -0.15},
	"uncanny":      {"bounce": 0.0, "jaw": 0.0,  "smile": 0.6,  "squash": -0.1, "curl": 0.0,  "tilt": 0.0},
}

# Holds, in the camera's frame: elbow position, forearm direction, the back of the hand's
# direction, and the wrist (pitch, yaw, roll).
const HOLDS := {
	"hidden": [Vector3(-0.25, -0.9, 0.1), Vector3(0.1, 0.3, -1.0), Vector3(0, 1, 0.3), Vector3(0.1, 0, 0)],
	"out":    [Vector3(-0.2, -0.27, 0.02), Vector3(0.24, 0.5, -1.0), Vector3(0.0, 1.0, 0.45), Vector3(-0.4, 0.1, 0.0)],
	"face":   [Vector3(-0.1, -0.36, -0.2), Vector3(0.14, 1.0, -0.22), Vector3(0.0, 0.25, -1.0), Vector3(-1.45, 0.0, 0.0)],
	"rub":    [Vector3(-0.26, -0.22, -0.02), Vector3(0.45, 1.0, -0.3), Vector3(0.3, 0.2, -1.0), Vector3(-0.6, 0.0, 0.4)],
	"low":    [Vector3(-0.22, -0.42, 0.0), Vector3(0.18, 0.32, -1.0), Vector3(0.0, 1.0, 0.25), Vector3(-0.3, 0.0, 0.0)],
}

var rig: SockRig
var player: Player
var points := {}              # look targets the level names: "door", "hole", "gun", "marta"...
var interest = null           # a point he keeps half an eye on (divided attention), or null
var hold := "hidden"
var emotion := "neutral"
var look := "ahead"           # "kurt", "ahead", "away", or a key in points
var cross_eyed := false

var _elbow := Vector3.ZERO; var _fdir := Vector3.FORWARD; var _up := Vector3.UP; var _wrist := Vector3.ZERO
var _e := EMOTIONS.neutral.duplicate()
var _jaw := 0.0; var _jaw_v := 0.0; var _jaw_kick := 0.0
var _g := {"pitch": 0.0, "yaw": 0.0, "roll": 0.0, "lift": 0.0, "push": 0.0, "squash": 0.0, "stretch": 0.0, "jaw": 0.0}
var _t := 0.0
var _sway := Vector2.ZERO; var _sway_v := Vector2.ZERO
var _last_yaw := 0.0; var _last_pitch := 0.0
var _wander_t := 2.0; var _wander_at := Vector3.ZERO
var _glance_t := 6.0; var _glance := 0.0
var _point_at = null

func _ready() -> void:
	rig = SockRig.new(); rig.name = "Rig"
	add_child(rig)
	Dialogue.syllable.connect(_on_syllable)
	Dialogue.line_started.connect(_on_line)
	var h: Array = HOLDS[hold]
	_elbow = h[0]; _fdir = h[1].normalized(); _up = h[2].normalized(); _wrist = h[3]
	visible = false

## Put him on a player's arm.
func attach(p: Player) -> void:
	player = p
	if get_parent(): get_parent().remove_child(self)
	p.arm_mount.add_child(self)
	transform = Transform3D.IDENTITY
	_last_yaw = p.get_yaw(); _last_pitch = p.get_pitch()

## A performance cue: {"emotion", "gesture", "look", "hold"}.
func cue(c: Dictionary) -> void:
	if c.has("emotion"): emotion = c.emotion
	if c.has("look"): look = c.look
	if c.has("hold"): hold = c.hold
	if c.has("gesture"): gesture(c.gesture)

func gesture(g: String) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	match g:
		"recoil":   # yanked back, squashed, then a wobbling recovery
			tw.tween_method(func(k): _g.push = -0.07 * k; _g.squash = 0.8 * k; _g.pitch = 0.3 * k, 0.0, 1.0, 0.12)
			tw.tween_method(func(k): _g.push = -0.07 * k; _g.squash = 0.8 * k * cos(k * 12.0); _g.pitch = 0.3 * k, 1.0, 0.0, 0.9)
		"tilt":
			var s := 1.0 if randf() < 0.5 else -1.0
			tw.tween_method(func(k): _g.roll = 0.45 * s * k, 0.0, 1.0, 0.25).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.9)
			tw.tween_method(func(k): _g.roll = 0.45 * s * k, 1.0, 0.0, 0.5)
		"nod":
			tw.tween_method(func(k): _g.pitch = -0.25 * sin(k * TAU * 2.0) * (1.0 - k), 0.0, 1.0, 0.8)
		"bounce":
			tw.tween_method(func(k): _g.lift = 0.025 * absf(sin(k * PI * 3.0)) * (1.0 - k * 0.5); _g.stretch = 0.5 * sin(k * PI * 3.0) * (1.0 - k), 0.0, 1.0, 0.75)
		"point":
			_point_at = look
			tw.tween_method(func(k): _g.push = 0.08 * k; _g.stretch = 0.7 * k, 0.0, 1.0, 0.3).set_ease(Tween.EASE_OUT)
			tw.tween_interval(1.8)
			tw.tween_method(func(k): _g.push = 0.08 * k; _g.stretch = 0.7 * k, 1.0, 0.0, 0.5)
			tw.tween_callback(func(): _point_at = null)
		"shake":
			tw.tween_method(func(k): _g.yaw = 0.3 * sin(k * TAU * 2.5) * (1.0 - k), 0.0, 1.0, 0.8)

func set_cross_eyed(on: bool) -> void:
	cross_eyed = on

func _on_line(step: Dictionary) -> void:
	if step.has("socko"): cue(step.socko)

func _on_syllable(who: String) -> void:
	if who == "socko" and visible:
		_jaw_kick = randf_range(0.35, 0.85) * (1.25 if emotion == "excited" else 1.0)

func _process(delta: float) -> void:
	if not rig or not visible: return
	_t += delta
	var target_e: Dictionary = EMOTIONS.get(emotion, EMOTIONS.neutral)
	for k in _e: _e[k] = lerpf(_e[k], target_e[k], 1.0 - exp(-4.0 * delta))
	# 1. the hold
	# talking to Kurt means turning round to him: an outstretched hand can't look back at its owner
	var hk := "face" if (look == "kurt" and hold == "out") else hold
	var h: Array = HOLDS.get(hk, HOLDS.out)
	var k := 1.0 - exp(-5.0 * delta)
	_elbow = _elbow.lerp(h[0], k); _fdir = _fdir.slerp(h[1].normalized(), k).normalized()
	_up = _up.slerp(h[2].normalized(), k).normalized(); _wrist = _wrist.lerp(h[3], k)
	# 2. the arm lags behind the head (a spring on how fast Kurt turns)
	if player:
		var dyaw := wrapf(player.get_yaw() - _last_yaw, -PI, PI); var dpitch := player.get_pitch() - _last_pitch
		_last_yaw = player.get_yaw(); _last_pitch = player.get_pitch()
		_sway_v += Vector2(dyaw, dpitch) * 9.0
	_sway_v += (-_sway * 70.0 - _sway_v * 11.0) * delta
	_sway += _sway_v * delta
	_sway = _sway.limit_length(0.35)
	# 3. emotion: idle bob and breathing
	var bob: float = sin(_t * 2.2) * 0.006 * _e.bounce + sin(_t * 0.9) * 0.002
	var walk := 0.0
	if player and player.velocity.length() > 0.3: walk = sin(_t * 9.0) * 0.008
	var elbow: Vector3 = _elbow + Vector3(_sway.x * 0.12, -_sway.y * 0.1 + bob + walk + _g.lift, 0)
	var basis := _basis(_fdir, _up)
	elbow += basis * Vector3(0, 0, -_g.push)
	transform = Transform3D(basis, elbow)
	# where the head should face (look target) as an extra wrist turn, limited to what a wrist does
	var wrist: Vector3 = _wrist + Vector3(_g.pitch, _g.yaw - _sway.x * 0.8, _g.roll + _e.tilt + _sway.x * 0.3)
	var aim = _look_point(_point_at if _point_at != null else look)
	if aim != null and hk == "out" or (aim != null and hk == "low"):
		var local: Vector3 = (rig.global_transform.affine_inverse() * (aim as Vector3))
		var from: Vector3 = rig.skel.get_bone_global_pose(SockRig.B.HAND).origin
		var d := (local - from).normalized()
		wrist.y += clampf(atan2(-d.x, -d.z), -0.8, 0.8) * 0.8
		wrist.x += clampf(atan2(d.y, Vector2(d.x, d.z).length()), -0.6, 0.6) * 0.8
	rig.wrist = wrist
	# 5. the jaw: a spring kicked by syllables, settling to the emotion's resting mouth
	_jaw_kick = maxf(0.0, _jaw_kick - delta * 5.0)
	var want: float = maxf(_e.jaw, _jaw_kick) + _g.jaw
	_jaw_v += ((want - _jaw) * 260.0 - _jaw_v * 18.0) * delta
	_jaw += _jaw_v * delta
	rig.jaw = maxf(_jaw, -0.03)
	rig.smile_l = _e.smile; rig.smile_r = _e.smile * (0.85 if emotion == "uncanny" else 1.0)
	rig.squash = _e.squash + _g.squash
	rig.stretch = _g.stretch
	rig.curl = _e.curl
	rig.apply_pose()
	# 6. the eyes
	_eyes(delta)
	rig.update_eyes(delta)

func _basis(fdir: Vector3, up: Vector3) -> Basis:
	var z := -fdir.normalized()
	var x := up.cross(z).normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z)

func _look_point(key) -> Variant:
	if key == null: return null
	var cam := get_viewport().get_camera_3d()
	match key:
		"kurt": return cam.global_position if cam else null
		"ahead": return null
		"away":
			return rig.head_global().origin + (cam.global_transform.basis * Vector3(-1.0, 0.3, -0.4)) if cam else null
	if points.has(key):
		var p = points[key]
		return p.global_position if p is Node3D else p
	return null

func _eyes(delta: float) -> void:
	var head := rig.head_global()
	if cross_eyed:
		var c := head.origin + head.basis * Vector3(0, 0.03, -0.035)
		rig.eye_targets = [c + head.basis.x * 0.02, c - head.basis.x * 0.02]
		rig.eye_rates = [18.0, 15.0]
		return
	var cam := get_viewport().get_camera_3d()
	var main = _look_point(look)
	if main == null:
		# idle: wander between the room ahead and Kurt
		_wander_t -= delta
		if _wander_t <= 0.0 or _wander_at == Vector3.ZERO:
			_wander_t = randf_range(1.2, 3.5)
			var ahead := head.origin + (-head.basis.z) * 2.0
			_wander_at = cam.global_position if (cam and randf() < 0.35) else ahead + Vector3(randf_range(-1, 1), randf_range(-0.4, 0.5), randf_range(-1, 1))
		main = _wander_at
	var t0 = main; var t1 = main
	# divided attention: one eye stays put, the other goes to what he wants noticed, then back
	_glance_t -= delta
	if interest != null and _glance_t <= 0.0 and _glance <= 0.0 and not Dialogue.speaking == "socko":
		_glance = randf_range(0.7, 1.1); _glance_t = randf_range(7.0, 12.0)
	if _glance > 0.0:
		_glance -= delta
		t1 = interest
	rig.eye_targets = [t0, t1]
	rig.eye_rates = [12.0, 9.0 if _glance > 0.0 else 11.0]
