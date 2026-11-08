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

@onready var head: Node3D = $Head
@onready var cam: Camera3D = $Head/Camera
@onready var ray: RayCast3D = $Head/Camera/Ray
@onready var hold: Node3D = $Head/Camera/Hold
@onready var torch: SpotLight3D = $Head/Camera/Torch

func _ready() -> void:
	torch.light_projector = Penumbra.make(0.65)   # three: the torch's penumbra

func place(t: Transform3D) -> void:
	global_position = t.origin
	yaw = t.basis.get_euler().y
	pitch = 0.0

func look(rel: Vector2) -> void:
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
	rotation.y = yaw
	head.rotation.x = pitch

	# move
	var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var pad := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if pad.length() > 0.2:
		inp = pad.limit_length(1.0)
	if Input.is_action_just_pressed("crouch"):
		toggle_crouch()
	var running := Input.is_action_pressed("sprint") and not crouched and inp.y < -0.3 and stamina > 0.05
	var speed := CROUCH if crouched else (RUN if running else WALK)
	stamina = clampf(stamina + (-0.22 if running else 0.12) * delta, 0.0, 1.0)
	if stamina < 0.25:
		speed = minf(speed, WALK * 0.85)     # winded
	var dir := (transform.basis * Vector3(inp.x, 0, inp.y))
	var want := dir * speed
	velocity.x = move_toward(velocity.x, want.x, delta * 9.0)
	velocity.z = move_toward(velocity.z, want.z, delta * 9.0)
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()

	# eye height, bob with a limp on the right leg
	var hs := Vector2(velocity.x, velocity.z).length()
	bob += hs * delta * 5.2
	var limp := 0.012 if sin(bob) > 0.0 else 0.022
	var eye := EYE_CROUCH if crouched else EYE
	head.position.y = lerpf(head.position.y, eye + sin(bob * 2.0) * limp * minf(hs, 1.0), delta * 8.0)
	cam.rotation.z = sin(bob) * 0.006 * minf(hs, 1.5)
	noise = 0.0 if hs < 0.2 else (0.15 if crouched else (0.7 if running else 0.35))

	_carry(delta)
	_aim()

func _aim() -> void:
	target = null
	var txt := ""
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
	if held:
		drop()
	elif target:
		target.call("interact", self)

func toggle_torch() -> void:
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
	held = null; inspecting = false
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(b):
		b.remove_collision_exception_with(self)

func throw() -> void:
	if not held:
		return
	var b := held
	drop()
	b.linear_velocity = -cam.global_transform.basis.z * clampf(9.0 / sqrt(b.mass), 2.0, 9.0)
