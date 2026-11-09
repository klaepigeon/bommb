class_name Player
extends CharacterBody3D
## The protagonist: an old man who used to be very good at this. Deliberate walking pace, a
## short burst of running that costs him, a crouch his knee complains about. Looks at things,
## takes them, turns them over, throws them.

const WALK := 1.45
const RUN := 2.7
const CROUCH := 0.8
const EYE := 1.62
const EYE_CROUCH := 1.05
const REACH := 1.7

var yaw := 0.0
var pitch := 0.0
var look_sens := 0.0022
var invert_y := false               # pause menu setting
var pad_sens := 2.6
var stamina := 1.0
var crouched := false
var bob := 0.0
var held: RigidBody3D
var inspecting := false
var target: Node
var touch_ui := false   # prompts without key names when playing by touch
var noise := 0.0    # how loud he is this frame, 0..1 (footsteps, impacts); for the AI later
# scripted moments take the body away from the player
var locked := false                 # no walking or looking
var look_target = null              # Vector3 to turn the head toward (while locked), or null
var look_speed := 6.0
var eye_override := -1.0            # forced eye height (lying on the floor, being pulled down)
var shake := 0.0                    # camera shake, decays
var _shake_t := 0.0

@onready var head: Node3D = $Head
@onready var cam: Camera3D = $Head/Camera
@onready var ray: RayCast3D = $Head/Camera/Ray
@onready var hold: Node3D = $Head/Camera/Hold
@onready var torch: SpotLight3D = $Head/Camera/Torch

var feet: Area3D
var arm: KurtArm
var body: KurtBody
var _hand_world := Transform3D.IDENTITY
var _reach_t := -1.0                      # time into a reach for the thing being used, or -1
var _reach_at := Vector3.ZERO             # world point being reached for
var _reach_pose := "grip"
var torch_holder: Node = null        # once Socko has it, the light's his (toggle_torch goes to him)
var gun: Node3D = null               # the revolver, once he has it (Revolver)
var armory: Node = null              # what he carries (Armory): the guns, cycled with [Q]
var throw_power := 1.0               # The Bow (memory) makes throws flatter and harder

func _ready() -> void:
	torch.light_projector = Penumbra.make(0.65)   # three: the torch's penumbra
	# feet: kick the debris you walk through (it doesn't block you; see prop.gd)
	feet = Area3D.new(); feet.collision_layer = 0; feet.collision_mask = 2; feet.monitorable = false
	var fs := CollisionShape3D.new(); var sp := SphereShape3D.new(); sp.radius = 0.3; fs.shape = sp
	fs.position = Vector3(0, 0.15, 0); feet.add_child(fs); add_child(feet)
	# Kurt's right arm, shoulder to fingertips (docs/KURT.md §3.5). It hangs from the body, not the
	# camera: the shoulder turns with him but doesn't tip when he looks down.
	arm = KurtArm.new(); arm.name = "RightArm"
	add_child(arm)
	# and the rest of him, for when he looks down (KurtBody: trunk, coat, legs, shoes)
	body = KurtBody.new(); body.name = "Body"; body.setup(self)
	add_child(body)
	_hand_world = cam.global_transform * _arm_rest()

func place(t: Transform3D) -> void:
	global_position = t.origin
	yaw = t.basis.get_euler().y
	pitch = 0.0

func look(rel: Vector2) -> void:
	if locked:
		return
	if inspecting and held:
		held.angular_velocity = Vector3.ZERO
		held.rotate(cam.global_transform.basis.y, rel.x * 0.01)
		held.rotate(cam.global_transform.basis.x, rel.y * 0.01)
		return
	yaw -= rel.x * look_sens
	pitch = clampf(pitch - rel.y * look_sens * (-1.0 if invert_y else 1.0), -1.45, 1.45)

func _physics_process(delta: float) -> void:
	# look (pad)
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.15:
		look(stick * pad_sens * delta / look_sens * 0.5)
	if look_target != null:
		var d: Vector3 = (look_target as Vector3) - cam.global_position
		var want_yaw := atan2(-d.x, -d.z); var want_pitch := atan2(d.y, Vector2(d.x, d.z).length())
		var k := minf(1.0, delta * look_speed)
		yaw += wrapf(want_yaw - yaw, -PI, PI) * k
		pitch += (want_pitch - pitch) * k
	rotation.y = yaw
	head.rotation.x = pitch
	# shake: a jolt that dies away
	_shake_t += delta
	shake = maxf(0.0, shake - delta * 1.6)
	cam.position = Vector3(sin(_shake_t * 61.0), cos(_shake_t * 53.0), 0) * 0.02 * shake * shake
	cam.rotation.x = sin(_shake_t * 47.0) * 0.03 * shake * shake

	# move
	var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var pad := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if pad.length() > 0.2:
		inp = pad.limit_length(1.0)
	if locked:
		inp = Vector2.ZERO
	elif Input.is_action_just_pressed("crouch"):
		toggle_crouch()
	var running := Input.is_action_pressed("sprint") and not crouched and inp.y < -0.3 and stamina > 0.05
	var speed := CROUCH if crouched else (RUN if running else WALK)
	stamina = clampf(stamina + (-0.22 if running else 0.12) * delta, 0.0, 1.0)
	if stamina < 0.25:
		speed = minf(speed, WALK * 0.85)     # winded
	var dir := (transform.basis * Vector3(inp.x, 0, inp.y))
	var want := dir * speed
	var accel := 9.0 if not locked else 4.0      # a shove (recoil, being pulled) carries a moment
	velocity.x = move_toward(velocity.x, want.x, delta * accel)
	velocity.z = move_toward(velocity.z, want.z, delta * accel)
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	var pre := velocity
	move_and_slide()
	_step_up(pre, delta)
	_shove(pre)
	_kick(pre)

	# eye height, bob with a limp on the right leg
	var hs := Vector2(velocity.x, velocity.z).length()
	bob += hs * delta * 5.2
	var limp := 0.012 if sin(bob) > 0.0 else 0.022
	var eye := EYE_CROUCH if crouched else EYE
	if eye_override >= 0.0:
		eye = eye_override
	head.position.y = lerpf(head.position.y, eye + sin(bob * 2.0) * limp * minf(hs, 1.0), delta * (8.0 if eye_override < 0.0 else 2.2))
	cam.rotation.z = sin(bob) * 0.006 * minf(hs, 1.5)
	noise = 0.0 if hs < 0.2 else (0.15 if crouched else (0.7 if running else 0.35))

	_carry(delta)
	_aim()

## Thresholds and the balcony sill are low steps (up to 20 cm). If walking into something that
## low, and there's room above it, step up onto it.
const STEP := 0.2
func _step_up(pre: Vector3, delta: float) -> void:
	if not is_on_wall() or not is_on_floor():
		return
	for i in get_slide_collision_count():          # only onto the building, never onto loose things
		if get_slide_collision(i).get_collider() is RigidBody3D:
			return
	var h := Vector3(pre.x, 0, pre.z) * delta
	if h.length() < 0.0005:
		return
	var up := Vector3(0, STEP, 0)
	if test_move(global_transform, up):
		return
	var raised := global_transform.translated(up)
	if test_move(raised, h * 3.0):
		return
	global_position += up + h
	apply_floor_snap()

## Loose things in the way get shoved (chairs, bottles, the bucket). Props slide on a low-friction
## material (prop.gd); the shove beats that friction for anything, and heavy furniture moves
## slower than light things.
## Walking into things: he doesn't stop for them. Anything loose up to about a chair's-and-a-half
## weight he kicks out of his way (a real kick: the right foot, a thud, a noise anyone listening
## hears); heavier furniture he leans into and shoves; an unlocked door he walks into, he pushes
## open with his hand. The doorway and the room stay clear without fiddling.
const KICK_MAX_KG := 45.0
var _kicked := {}                   # body id -> time it was last kicked (so it's one kick, not a stream)
func _shove(pre: Vector3) -> void:
	var speed := Vector2(pre.x, pre.z).length()
	if speed < 0.1:
		return
	var now := Time.get_ticks_msec()
	var move := Vector3(pre.x, 0, pre.z).normalized()
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col := c.get_collider()
		# a door: open it
		var dn: Node = (col as Node).get_parent() if col is AnimatableBody3D else null
		if dn and dn.get_script() and String(dn.get_script().resource_path).ends_with("door.gd"):
			if String(dn.get("locked")) == "" and float(dn.get("target")) < 0.15 and move.dot(-c.get_normal()) > 0.5:
				dn.set("target", float(dn.get("max_angle")))
				_reach_t = 0.0; _reach_at = c.get_position(); _reach_pose = "flat"
			continue
		var b := col as RigidBody3D
		if not b or b == held:
			continue
		var push := -c.get_normal(); push.y = 0.0
		if push.length() < 0.1 or move.dot(push.normalized()) < 0.3:
			continue
		b.sleeping = false
		if b.mass <= KICK_MAX_KG:
			if now - int(_kicked.get(b.get_instance_id(), 0)) < 450: continue
			_kicked[b.get_instance_id()] = now
			# the kick: hard enough to clear his way, by weight (a chair skids off, a box shoves aside)
			var dir := (move * 0.75 + push.normalized() * 0.25).normalized()
			var dv := clampf(4.2 / sqrt(maxf(b.mass, 0.5)), 0.6, 3.2)
			var lift := 0.9 if b.mass < 8.0 else 0.25
			b.apply_central_impulse((dir * dv + Vector3.UP * lift) * b.mass)
			b.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * b.mass * 0.15)
			if body: body.call("kick")
			shake = maxf(shake, 0.18)
			noise = maxf(noise, 0.6)
			Sfx.play(get_parent(), "thud", c.get_position(), -2.0)
			Noises.make(get_tree(), c.get_position(), 0.55, "kick", self)
			if "thrown_by" in b: b.set("thrown_by", self)
		else:
			var dv := 0.14 * clampf(20.0 / b.mass, 0.35, 1.0) * minf(speed / WALK, 1.0)
			b.apply_central_impulse(push.normalized() * dv * b.mass)

func _kick(pre: Vector3) -> void:
	var v := Vector3(pre.x, 0, pre.z)
	if v.length() < 0.3:
		return
	for b in feet.get_overlapping_bodies():
		var rb := b as RigidBody3D
		if rb and rb != held:
			var away := rb.global_position - global_position; away.y = 0.0
			var dir := (v.normalized() * 0.7 + away.normalized() * 0.3).normalized()
			rb.sleeping = false
			rb.apply_central_impulse((dir * v.length() * 0.45 + Vector3.UP * 0.25) * minf(rb.mass, 2.0) * 0.5)
			noise = maxf(noise, 0.5)

# ---------------------------------------------------------------- the right arm in first person
const SHOULDER := Vector3(0.19, -0.26, 0.10)      # from the eye (unpitched): right, below, slightly behind
const ELBOW_POLE := Vector3(0.7, -1.0, 0.25)

## Where the hand rests: low in the bottom right of view, palm turned in, fingers relaxed.
func _arm_rest() -> Transform3D:
	return Transform3D(KurtArm.frame(Vector3(-0.22, -0.32, -1.0), Vector3(0.88, 0.3, 0.12)), Vector3(0.15, -0.235, -0.3))

func _process(delta: float) -> void:
	if not arm:
		return
	arm.visible = eye_override < 0.0 or eye_override > 0.6           # not while lying on the floor
	var want := _arm_rest()
	var pose := "relaxed"
	var hs := Vector2(velocity.x, velocity.z).length()
	want.origin += Vector3(sin(bob) * 0.006, absf(cos(bob)) * 0.007, 0) * minf(hs, 1.5)   # it swings a little with the walk
	var on_gun := gun != null and bool(gun.get("drawn")) and not held
	if on_gun:
		# the revolver in the right hand: back of the hand out to the right, the fingers wrapped
		# forward and down round the grip (its rake), the palm on the right-hand panel
		var g: Transform3D = cam.global_transform.affine_inverse() * gun.call("grip_global")
		var gx := g.basis.x.normalized(); var gy := g.basis.y.normalized(); var gz := g.basis.z.normalized()
		var fingers := (-gz * cos(0.35) - gy * sin(0.35) - gx * 0.25).normalized()
		var hb := KurtArm.frame(fingers, gx)
		var palm := g.origin + gx * 0.012 - gy * 0.004
		want = Transform3D(hb, palm - hb.y * 0.058 + hb.z * 0.03)
		pose = "grip"
	elif held:
		# carrying: palm up under it, fingers curled round
		want = Transform3D(KurtArm.frame(Vector3(-0.35, 0.05, -1.0), Vector3(0.3, -0.92, 0.25)), Vector3(0.09, -0.2, -0.36))
		pose = "hold"
	elif _reach_t >= 0.0:
		_reach_t += delta
		var k := sin(clampf(_reach_t / 0.6, 0.0, 1.0) * PI)
		var at := cam.global_transform.affine_inverse() * _reach_at
		var sh_cam := cam.global_transform.affine_inverse() * (global_transform * _shoulder())
		var to := at - sh_cam
		at = sh_cam + to.limit_length(KurtArm.UPPER + KurtArm.FOREARM - 0.08) - to.normalized() * 0.07
		want.origin = want.origin.lerp(at, k)
		want.basis = want.basis.slerp(KurtArm.frame((at - sh_cam).normalized(), Vector3(0.5, 0.8, 0.2)), k)
		pose = "reach" if _reach_t < 0.22 else _reach_pose
		if _reach_t > 0.6:
			_reach_t = -1.0
	elif locked and look_target != null:
		# being pulled: the arm goes out toward what has hold of it
		var at := cam.global_transform.affine_inverse() * (look_target as Vector3) + Vector3(0.05, -0.2, 0.15)
		var sh_cam := cam.global_transform.affine_inverse() * (global_transform * _shoulder())
		want.origin = sh_cam + (at - sh_cam).limit_length(0.55)
		want.basis = KurtArm.frame((at - sh_cam).normalized(), Vector3(0.2, 1.0, 0.0))
		pose = "open"
	# keep the hand out of walls: if something is closer than the hand would reach, draw it back
	if ray.is_colliding() and not held:
		var d := cam.global_position.distance_to(ray.get_collision_point())
		if d < 0.5:
			want.origin.z = maxf(want.origin.z, -maxf(0.16, d - 0.14))
			want.origin.y -= (0.5 - d) * 0.25
	# the hand has weight: it follows the head a beat behind
	var target_world := cam.global_transform * want
	var k := 1.0 - exp(-delta * 16.0)
	_hand_world = Transform3D(_hand_world.basis.slerp(target_world.basis, k).orthonormalized(), _hand_world.origin.lerp(target_world.origin, k))
	if on_gun:
		_hand_world = target_world          # the gun carries its own lag; the hand stays on it
	var local := global_transform.affine_inverse() * _hand_world        # body space (the arm's space)
	arm.pose_name = pose
	arm.idle = pose == "relaxed"
	arm.solve_arm(_shoulder(), local, ELBOW_POLE)
	if held:
		hold.global_position = global_transform * arm.palm_point() + cam.global_basis.y * 0.035

## The shoulder, in body space: under the eye, following crouch and the head's height, not its pitch.
func _shoulder() -> Vector3:
	return head.position + SHOULDER

func _aim() -> void:
	target = null
	var txt := ""
	if locked:
		Game.prompt.emit(""); return
	if held:
		txt = "Throw  ·  Drop  ·  Turn over" if touch_ui else "[LMB/RT] throw   [E/A] drop   [RMB/LT] turn over"
		# something that takes what's in the hand (the axe on the chain): use offers that instead
		var w := _use_with_target()
		if w:
			target = w
			var p2: String = w.call("use_with_prompt", held)
			txt = p2 if touch_ui else "[E/A] " + p2
	elif ray.is_colliding():
		var n: Node = ray.get_collider()
		while n and not n.has_method("interact"):
			n = n.get_parent()
		if n:
			var p: String = n.call("prompt")
			if p != "":
				target = n; txt = p if touch_ui else "[E] " + p
	Game.prompt.emit(txt)

func _unhandled_input(e: InputEvent) -> void:
	if locked:
		return
	if e.is_action_pressed("interact"):
		use()
	elif e.is_action_pressed("torch"):
		toggle_torch()
	elif e.is_action_pressed("throw"):
		throw()
	elif e.is_action_pressed("inspect"):
		inspecting = held != null
	elif e.is_action_released("inspect"):
		inspecting = false

# ---------------------------------------------------------------- actions (keys, pad and touch)
func use() -> void:
	if locked:
		return
	if held and target and target.has_method("use_with") and target.call("use_with", self, held):
		_reach_t = 0.0
		_reach_at = ray.get_collision_point() if ray.is_colliding() else cam.global_position - cam.global_basis.z * 0.5
		_reach_pose = "grip"
	elif held:
		drop()
	elif target:
		# the hand goes to it: flat to push a door, a grip for most things
		_reach_t = 0.0
		_reach_at = ray.get_collision_point() if ray.is_colliding() else cam.global_position - cam.global_basis.z * 0.5
		_reach_pose = "flat" if target.get_script() and String(target.get_script().resource_path).ends_with("door.gd") else "grip"
		target.call("interact", self)

## While holding something: the thing under the crosshair (past the held prop) that would take it.
func _use_with_target() -> Node:
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_basis.z * 1.6)
	q.exclude = [get_rid(), held.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit: return null
	var n: Node = hit.collider
	while n and not n.has_method("use_with_prompt"):
		n = n.get_parent()
	if n and String(n.call("use_with_prompt", held)) != "": return n
	return null

func toggle_torch() -> void:
	if torch_holder:
		torch_holder.call("toggle_torch")
	else:
		torch.visible = not torch.visible

func toggle_crouch() -> void:
	crouched = not crouched

# ---------------------------------------------------------------- carrying
func grab(b: RigidBody3D) -> void:
	held = b
	b.sleeping = false
	b.gravity_scale = 0.0
	b.add_collision_exception_with(self)

func _carry(delta: float) -> void:
	if not held:
		return
	if not is_instance_valid(held):
		held = null; return
	var to := (hold.global_position - held.global_position)
	if to.length() > 1.2:
		drop(); return
	held.linear_velocity = to / maxf(delta, 0.001) * 0.35
	if not inspecting:
		held.angular_velocity *= 0.8

func drop() -> void:
	if not held:
		return
	held.gravity_scale = 1.0
	var b := held
	if "thrown_by" in b: b.set("thrown_by", self)
	held = null; inspecting = false
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(b):
		b.remove_collision_exception_with(self)

func throw() -> void:
	if not held:
		return
	var b := held
	drop()
	b.linear_velocity = -cam.global_transform.basis.z * clampf(9.0 / sqrt(b.mass), 2.0, 9.0) * throw_power
