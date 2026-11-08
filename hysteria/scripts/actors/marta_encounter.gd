class_name MartaEncounter
extends Node
## Flat 47's first encounter (story bible §5, beats 4–8), with Marta as a corpse:
##
##   STILL   She's dead. Nothing moves but the flies. No timer, no sound cue.
##   SNAP    Lean in to look at her face (or touch her, or stay in the room long enough) and her
##           head whips up to you with a crack of bone and coral, the jaw dropping open on that
##           grin. You're thrown back a step. No warning, no music sting before it.
##   STARE   Her head follows you round the room. "Have you seen the boxes?"
##           Look at her and answer (use): "You haven't. No. Nobody has." Stay near: she asks again.
##   GRAB    Come within reach after that and, without warning, her arm tears up off the table,
##           out of the coral, and takes your wrist. She pulls you down to her face.
##           "Have you seen them?" Black from the edges in.
##   BLACK   Heartbeat. Five seconds.
##   AWAKE   On the floor by the table, looking at the ceiling. The chair is empty.

enum S { STILL, SNAP, STARE, GRAB, BLACK, AWAKE }

const LINGER := 45.0          # seconds in the room before she looks up at you anyway
const REACH := 1.45           # how close counts as within her reach
const SNAP_TIME := 0.09

var marta: Marta
var player: Player
var presence: Presence
var dread: Dread
var room := "living"

var state := S.STILL
var t := 0.0                  # time in the current state
var in_room := 0.0
var looking := 0.0            # how long the player has been leaning in at her face
var asked := 0
var answered := false
var grab_at := -1.0
var _head_from := Vector3.ZERO
var _strands: MeshInstance3D
var _table_pts := []          # where her right forearm was fused to the cloth
var _heart: AudioStreamPlayer
var collider: StaticBody3D
var _cleared := false
var _pull_from := Vector3.ZERO

func setup(p_marta: Marta, p_player: Player, p_presence: Presence, p_dread: Dread) -> void:
	marta = p_marta; player = p_player; presence = p_presence; dread = p_dread
	# she's solid, and she's what you're looking at when you use her
	collider = StaticBody3D.new(); collider.set_script(load("res://scripts/actors/marta_touch.gd"))
	collider.set("encounter", self)
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(0.5, 1.4, 0.55)
	cs.shape = b; cs.position = Vector3(0, 0.7, -0.08)
	collider.add_child(cs); marta.add_child(collider)
	_strands = MeshInstance3D.new(); marta.add_child(_strands)
	_strands.top_level = true
	for k in 4:
		_table_pts.append(marta.to_global(Marta.J.elR.lerp(Marta.J.wrR, 0.2 + k * 0.22) + Vector3(0, -0.035, 0)))

func state_name() -> String:
	return S.keys()[state]

func head_pos() -> Vector3:
	return marta.joints.head.global_position + marta.global_basis * Vector3(0, 0.1, -0.03)

func eye_pos() -> Vector3:
	return player.cam.global_position

func _enter(s: S) -> void:
	state = s; t = 0.0

func _physics_process(delta: float) -> void:
	t += delta
	match state:
		S.STILL: _still(delta)
		S.SNAP: _snap(delta)
		S.STARE: _stare(delta)
		S.GRAB: _grab(delta)
		S.BLACK: _black(delta)
		S.AWAKE: pass

# ---------------------------------------------------------------- still: she's a corpse
func _still(delta: float) -> void:
	if dread.room_at(player.global_position) != room:
		looking = 0.0
		return
	in_room += delta
	var to_head := head_pos() - eye_pos()
	var fwd := -player.cam.global_basis.z
	var her_front := -marta.global_basis.z
	var leaning_in := to_head.length() < 1.3 and fwd.dot(to_head.normalized()) > cos(deg_to_rad(24.0)) and her_front.dot(-to_head.normalized()) > -0.15
	looking = looking + delta if leaning_in else 0.0
	if looking > 0.5 or in_room > LINGER:
		wake()

## Touching her, looking too long, or the linger timeout: the head comes up.
func wake() -> void:
	if state != S.STILL:
		return
	_head_from = marta.joints.head.rotation
	_enter(S.SNAP)
	Sfx.play(marta, "crack", head_pos(), 6.0)
	marta.flies.initial_velocity_max = 2.5; marta.flies.radial_accel_min = 3.0; marta.flies.radial_accel_max = 6.0   # scatter
	player.shake = 1.0
	var away := (player.global_position - marta.global_position); away.y = 0.0
	player.velocity += away.normalized() * 2.2
	player.locked = true; player.look_target = head_pos(); player.look_speed = 14.0
	Game.flags["marta_woke"] = true

# ---------------------------------------------------------------- snap: the head whips round
func _snap(_delta: float) -> void:
	var k := clampf(t / SNAP_TIME, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0) + sin(k * PI) * 0.12          # fast, with an overshoot
	var target := _face_rotation(eye_pos())
	marta.joints.head.rotation = _head_from.lerp(target, e)
	marta.joints.jaw.rotation.x = -lerpf(Marta.JAW_REST, Marta.JAW_OPEN, minf(1.0, k * 1.5))
	if t > 0.65:
		player.locked = false; player.look_target = null; player.look_speed = 6.0
		_enter(S.STARE)

func _face_rotation(p: Vector3) -> Vector3:
	var saved: Vector3 = marta.joints.head.rotation; var jaw: float = marta.joints.jaw.rotation.x
	marta.face(p)
	var r: Vector3 = marta.joints.head.rotation
	marta.joints.head.rotation = saved; marta.joints.jaw.rotation.x = jaw
	return r

# ---------------------------------------------------------------- stare: she watches you, and asks
func _stare(delta: float) -> void:
	var target := _face_rotation(eye_pos())
	marta.joints.head.rotation = marta.joints.head.rotation.lerp(target, minf(1.0, delta * 2.2))   # follows you, a beat behind
	var speaking := false
	var d := player.global_position.distance_to(marta.global_position)
	if asked == 0 and t > 1.6:
		asked = 1; Game.flags["heard_boxes_question"] = true
		Game.speak("“Have you seen the boxes?”", 4.5, 0.8, 0.7)
	elif asked == 1 and t > 8.0 and d < 2.6 and not answered:
		asked = 2
		Game.speak("“The boxes. Have you seen them?”", 4.5, 0.8, 0.65)
		t = 8.0
	speaking = (asked == 1 and t < 4.5) or (asked == 2 and t > 8.0 and t < 11.5)
	marta.joints.jaw.rotation.x = -(Marta.JAW_OPEN + (sin(t * 19.0) * 0.06 if speaking else 0.0))
	# after she's asked, coming within reach is all it takes
	if asked >= 1 and t > 3.0 and d < REACH:
		if grab_at < 0.0:
			grab_at = t + randf_range(0.6, 2.4)
		elif t > grab_at:
			_start_grab()
	elif d >= REACH:
		grab_at = -1.0

## Using her while she's looking at you: you answer her by looking back.
func answer() -> void:
	if state == S.STILL:
		wake(); return
	if state == S.STARE and asked >= 1 and not answered:
		answered = true
		Game.speak("“You haven't. No. Nobody has.”", 4.0, 0.8, 0.7)
		grab_at = t + 3.0

# ---------------------------------------------------------------- grab
func _start_grab() -> void:
	_enter(S.GRAB)
	player.add_collision_exception_with(collider)        # nothing between you and her now
	_pull_from = player.global_position
	Sfx.play(marta, "tear", head_pos(), 6.0)
	player.locked = true; player.look_speed = 9.0
	player.shake = 0.8
	_burst_coral()

func _grab(delta: float) -> void:
	var eye := eye_pos()
	# the arm: straight out of the table at your wrist (about a forearm below your eye)
	var wrist := eye + Vector3(0, -0.45, 0) + (-player.cam.global_basis.z) * 0.25
	var k := clampf(t / 0.22, 0.0, 1.0)
	_reach(wrist, k)
	# you're pulled down to her: bent over the table, her face a hand's width from yours
	var face := head_pos()
	var her_front := -marta.global_basis.z; her_front.y = 0.0
	var spot := face + her_front.normalized() * 0.42; spot.y = 0.0
	var pull := clampf((t - 0.15) / 0.45, 0.0, 1.0)
	pull = pull * pull * (3.0 - 2.0 * pull)
	player.velocity = Vector3.ZERO
	player.global_position = _pull_from.lerp(spot, pull)
	player.eye_override = lerpf(1.62, face.y + 0.02, pull)
	player.look_target = face
	marta.joints.head.rotation = marta.joints.head.rotation.lerp(_face_rotation(eye), minf(1.0, delta * 8.0))
	marta.joints.jaw.rotation.x = -(Marta.JAW_OPEN + 0.08 + sin(t * 23.0) * 0.05)
	_draw_strands()
	if t > 0.9 and t - delta <= 0.9:
		Game.speak("“Have you seen them?”", 3.0, 0.9, 0.9)
	if t > 1.0:
		player.shake = maxf(player.shake, 0.35)
	if t > 2.4 and t - delta <= 2.4:
		Game.fade.emit(1.0, 1.1)
	if t > 3.6:
		_enter(S.BLACK)
		_heart = AudioStreamPlayer.new(); _heart.stream = Sfx.get_sound("heartbeat"); _heart.volume_db = -2.0
		add_child(_heart); _heart.play()

## Points her right arm at a world point: the shoulder aims the whole arm, the elbow straightens.
func _reach(world: Vector3, k: float) -> void:
	var sh: Node3D = marta.joints.shR; var el: Node3D = marta.joints.elR
	var rest_dir: Vector3 = (Marta.J.wrR - Marta.J.shR).normalized()
	var hips: Node3D = marta.joints.hips
	var want := (hips.global_transform.affine_inverse() * world - Marta.J.shR + Marta.J.hips).normalized()
	var q := Quaternion(rest_dir, want)
	sh.quaternion = Quaternion.IDENTITY.slerp(q, k)
	var upper: Vector3 = (Marta.J.elR - Marta.J.shR).normalized(); var fore: Vector3 = (Marta.J.wrR - Marta.J.elR).normalized()
	el.quaternion = Quaternion.IDENTITY.slerp(Quaternion(fore, upper), k)

## Strings of her stretched between the lifting forearm and the cloth it was fused to; they
## thin as they stretch and snap past half a metre.
func _draw_strands() -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fore_a: Vector3 = marta.joints.elR.global_position
	var fore_b: Vector3 = marta.joints.wrR.global_position
	var any := false
	for k in _table_pts.size():
		var top: Vector3 = fore_a.lerp(fore_b, 0.2 + k * 0.22)
		var bot: Vector3 = _table_pts[k]
		var ln := top.distance_to(bot)
		if ln > 0.4 + k * 0.05:
			continue
		any = true
		var pts := []; var rr := []
		for i in 7:
			var u := float(i) / 6.0
			pts.append(bot.lerp(top, u) + Vector3(0, -sin(u * PI) * ln * 0.25, 0))
			rr.append(lerpf(0.012, 0.009, u) * (1.0 - 0.85 * sin(u * PI)) * clampf(1.2 - ln * 1.6, 0.25, 1.0))
		MeshKit.tube(st, pts, rr, {"sides": 4})
	if any:
		st.generate_normals()
		var m := st.commit()
		m.surface_set_material(0, marta.mat("slime", 0.15, 0.55))
		_strands.mesh = m
	else:
		_strands.mesh = null

func _burst_coral() -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true; p.amount = 26; p.lifetime = 1.4; p.explosiveness = 0.95
	p.direction = Vector3(0, 1, 0); p.spread = 70.0
	p.initial_velocity_min = 0.8; p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, -9.8, 0)
	var bm := BoxMesh.new(); bm.size = Vector3(0.018, 0.012, 0.014); bm.material = marta.mat("coral", 0.75)
	p.mesh = bm
	marta.add_child(p); p.global_position = marta.joints.elR.global_position.lerp(marta.joints.wrR.global_position, 0.5)
	p.emitting = true

# ---------------------------------------------------------------- black, then awake
func _black(_delta: float) -> void:
	if t < 0.05:
		return
	if not _cleared:
		_cleared = true
		# she's gone: the body, the flies. The chair, the puddle and the coral stay.
		marta.joints.hips.visible = false
		marta.flies.emitting = false; marta.flies.visible = false
		_strands.mesh = null
		collider.queue_free()
		presence.active = false
		# on the floor beside the table, on his back
		player.global_position = marta.to_global(Vector3(0.55, 0, -0.1))
		player.velocity = Vector3.ZERO
		player.eye_override = 0.25
		player.head.position.y = 0.25
		player.pitch = 1.3
		player.look_target = null
	if t > 5.0:
		_heart.volume_db = lerpf(-2.0, -30.0, clampf((t - 5.0) / 3.0, 0.0, 1.0))
	if t > 5.0 and t - get_physics_process_delta_time() <= 5.0:
		Game.fade.emit(0.0, 3.5)
	if t > 9.0:
		# he sits up, badly (the shoulder), and gets to his feet
		player.eye_override = -1.0
		player.locked = false
		_heart.queue_free()
		_enter(S.AWAKE)
		Game.flags["woke_in_47"] = true
