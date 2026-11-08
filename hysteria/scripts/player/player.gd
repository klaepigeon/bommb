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
var right_hand: RightHand           # the one that does things
var torch_holder: Node = null       # once Socko has it, the light's his (toggle_torch goes to him)

func _ready() -> void:
	torch.light_projector = Penumbra.make(0.65)   # three: the torch's penumbra
	right_hand = RightHand.new(); right_hand.name = "RightHand"
	right_hand.setup(cam, self)
	add_child(right_hand)
	# feet: kick the debris you walk through (it doesn't block you; see prop.gd)
	feet = Area3D.new(); feet.collision_layer = 0; feet.collision_mask = 2; feet.monitorable = false
	var fs := CollisionShape3D.new(); var sp := SphereShape3D.new(); sp.radius = 0.3; fs.shape = sp
	fs.position = Vector3(0, 0.15, 0); feet.add_child(fs); add_child(feet)

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
	pitch = clampf(pitch - rel.y * look_sens, -1.45, 1.45)

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
func _shove(pre: Vector3) -> void:
	var speed := Vector2(pre.x, pre.z).length()
	if speed < 0.1:
		return
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var b := c.get_collider() as RigidBody3D
		if b and b != held:
			var push := -c.get_normal(); push.y = 0.0
			if push.length() < 0.1:
				continue
			b.sleeping = false
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

func _aim() -> void:
	target = null
	var txt := ""
	if locked:
		Game.prompt.emit(""); return
	if held:
		txt = "Throw  ·  Drop  ·  Turn over" if touch_ui else "[LMB/RT] throw   [E/A] drop   [RMB/LT] turn over"
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
	if held:
		drop()
	elif target:
		if ray.is_colliding():
			right_hand.reach(ray.get_collision_point())   # always the right hand
		target.call("interact", self)

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
	right_hand.throw_flick()
	drop()
	b.linear_velocity = -cam.global_transform.basis.z * clampf(9.0 / sqrt(b.mass), 2.0, 9.0)
