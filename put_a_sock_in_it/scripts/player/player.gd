class_name Player
extends CharacterBody3D
## Kurt. An old man who used to be very good at this and doesn't remember it: walks deliberately,
## runs hard but not for long, crouches like he's been trained to, and his hands are steady.
##
## One controller for every platform: keyboard and mouse, gamepad and the touch overlay all drive
## the same input actions (see Game._setup_input); touch-look and mouse-look both arrive through
## add_look(). Cutscenes switch `controls` off and move the body and head themselves.

signal interacted(target: Node)

const WALK := 2.0
const RUN := 3.5
const CROUCH := 1.0
const HEAD_STAND := 1.62
const HEAD_CROUCH := 1.0
const REACH := 2.1
const STAMINA_MAX := 4.5      # seconds of running before his lungs say no

var controls := true          # player input moves him
var look_enabled := true      # (cutscenes can leave look on while movement is off)
var crouching := false
var running := false
var stamina := STAMINA_MAX
var footstep := "step_wood"
var target: Node = null       # what the interaction ray is on (has get_prompt / interact)
var held: RigidBody3D = null
var inspecting := false
var noise_mult := 1.0
var torch: SpotLight3D
var torch_beam: MeshInstance3D
var torch_on := false
var has_torch := true
var torch_flicker := 0.0     # 0 steady .. 1 failing (Marta near)
var _look_lag := Vector2.ZERO
var _pant := 0.0
var head_override := -1.0     # cutscenes: hold the eyes at this height (lying on the floor, crawling)

var head: Node3D
var cam: Camera3D
var arm_mount: Node3D         # Socko's arm hangs here (left side, under the camera)
var hand_mount: Node3D        # the pistol (right hand)
var ray: RayCast3D
var _yaw := 0.0
var _pitch := 0.0
var _look := Vector2.ZERO
var _bob := 0.0
var _step_d := 0.0
var _shake := 0.0
var _shake_t := 0.0
var _head_h := HEAD_STAND
var _roll := 0.0

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2; collision_mask = 1 | 32
	var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new()
	cap.radius = 0.28; cap.height = 1.75
	cs.shape = cap; cs.position.y = 0.875; cs.name = "Body"
	add_child(cs)
	head = Node3D.new(); head.name = "Head"; head.position.y = HEAD_STAND
	add_child(head)
	cam = Camera3D.new(); cam.name = "Camera"; cam.fov = 72.0; cam.near = 0.02; cam.far = 80.0
	cam.current = true
	head.add_child(cam)
	arm_mount = Node3D.new(); arm_mount.name = "ArmMount"; cam.add_child(arm_mount)
	hand_mount = Node3D.new(); hand_mount.name = "HandMount"; cam.add_child(hand_mount)
	# a faint light at the eye, a metre's reach: Socko and the hands always read, even in the dark
	var fill := OmniLight3D.new(); fill.name = "Fill"; fill.light_color = Color("ffe6c8"); fill.light_energy = 0.35
	fill.omni_range = 0.9; fill.omni_attenuation = 1.5; fill.shadow_enabled = false; fill.light_specular = 0.1
	cam.add_child(fill); fill.position = Vector3(0, 0.05, 0.05)
	torch = SpotLight3D.new(); torch.name = "Torch"
	torch.position = Vector3(0.18, -0.12, -0.05)
	torch.light_color = Color("ffe2b8"); torch.spot_range = 15.0; torch.spot_angle = 26.0; torch.spot_angle_attenuation = 0.7
	torch.spot_attenuation = 1.2; torch.light_energy = 0.0
	torch.shadow_enabled = bool(Game.settings.get("shadows", true)); torch.shadow_bias = 0.05
	cam.add_child(torch)
	torch_beam = Air.beam(torch, 7.0, 2.8, Color("ffe2b8"), 0.03)
	torch_beam.visible = false
	ray = RayCast3D.new(); ray.target_position = Vector3(0, 0, -REACH); ray.collision_mask = 1 | 4 | 16 | 32
	ray.add_exception(self)
	cam.add_child(ray)
	_yaw = rotation.y; rotation.y = 0.0
	Sfx.loop("pant", "pant", -80.0)

## Point him somewhere: body yaw and head pitch (radians).
func set_view(yaw: float, pitch: float) -> void:
	_yaw = yaw; _pitch = pitch
	_apply_view()

func get_yaw() -> float: return _yaw
func get_pitch() -> float: return _pitch

## Turn to face a world point over `secs` (cutscenes).
func look_toward(p: Vector3, secs := 0.8) -> void:
	var from := cam.global_position
	var d := p - from
	var yaw := atan2(-d.x, -d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	yaw = _yaw + wrapf(yaw - _yaw, -PI, PI)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(k): set_view(lerpf(_yaw, yaw, k), lerpf(_pitch, pitch, k)), 0.0, 1.0, secs)
	await tw.finished

func shake(amount: float, secs: float) -> void:
	_shake = maxf(_shake, amount); _shake_t = maxf(_shake_t, secs)

func set_roll(r: float) -> void:
	_roll = r

## Mouse, touch-drag and stick look all end up here (radians).
func add_look(v: Vector2) -> void:
	if look_enabled and not inspecting:
		_look += v
	elif inspecting and held:
		held.angular_velocity = Vector3.ZERO
		var b := cam.global_transform.basis
		held.global_rotate(b.y, v.x * 2.0); held.global_rotate(b.x, v.y * 2.0)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s: float = 0.0022 * float(Game.settings.sensitivity)
		add_look(Vector2(-e.relative.x * s, -e.relative.y * s * (-1.0 if Game.settings.invert_y else 1.0)))
	if not controls: return
	if e.is_action_pressed("interact"): _interact()
	if e.is_action_pressed("crouch"): crouching = not crouching
	if e.is_action_pressed("torch") and has_torch: toggle_torch()
	if e.is_action_pressed("fire") and held: _throw()
	if e.is_action_pressed("inspect") and held: inspecting = true
	if e.is_action_released("inspect"): inspecting = false

func _physics_process(delta: float) -> void:
	# look: stick, then whatever mouse/touch accumulated
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick.length() > 0.0:
		add_look(Vector2(-stick.x, -stick.y * (-1.0 if Game.settings.invert_y else 1.0)) * 2.6 * delta * float(Game.settings.sensitivity))
	_look_lag = _look_lag.lerp(_look * 6.0, 1.0 - exp(-10.0 * delta))
	if _look != Vector2.ZERO:
		_yaw += _look.x; _pitch = clampf(_pitch + _look.y, -1.45, 1.45); _look = Vector2.ZERO
	_apply_view()
	# move
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if controls else Vector2.ZERO
	var want_run := controls and Input.is_action_pressed("sprint") and input.y < -0.3 and not crouching
	if want_run and stamina > 0.0:
		running = true; stamina -= delta
	else:
		running = false; stamina = minf(STAMINA_MAX, stamina + delta * (0.6 if want_run else 1.0))
	var speed := CROUCH if crouching else (RUN if running else WALK)
	var dir := (Basis(Vector3.UP, _yaw) * Vector3(input.x, 0, input.y))
	var hv := Vector3(velocity.x, 0, velocity.z)
	hv = hv.lerp(dir * speed, 1.0 - exp(-(10.0 if dir.length() > 0.1 else 14.0) * delta))
	velocity.x = hv.x; velocity.z = hv.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	if controls or velocity.length() > 0.01:
		move_and_slide()
		# a step up (a sill, the balcony's drop, a bit of rubble): up to 30 cm, he steps up onto it
		if is_on_floor() and is_on_wall() and Vector2(hv.x, hv.z).length() > 0.2:
			var fwd := Vector3(hv.x, 0, hv.z).normalized() * 0.15
			for step in [0.14, 0.3]:
				var raised := global_transform.translated(Vector3(0, step, 0))
				if not test_move(global_transform, Vector3(0, step, 0)) and not test_move(raised, fwd):
					global_position += Vector3(0, step, 0) + fwd
					move_and_collide(Vector3(0, -step - 0.05, 0))
					break
		# walking into a loose chair or a box shoves it; the heavy furniture barely moves
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			var rb := col.get_collider() as RigidBody3D
			if rb and rb != held and absf(col.get_normal().y) < 0.5:
				var push := -col.get_normal() * Vector3(1, 0, 1)
				rb.apply_central_impulse(push * clampf(8.0 / rb.mass, 0.1, 1.0) * 0.35)
	# crouch: a trained, controlled drop, not a pop
	var want_h := HEAD_CROUCH if crouching else HEAD_STAND
	if not crouching and _blocked_above(): want_h = HEAD_CROUCH; crouching = true
	if head_override >= 0.0: want_h = head_override
	_head_h = lerpf(_head_h, want_h, 1.0 - exp(-7.0 * delta))
	(get_node("Body").shape as CapsuleShape3D).height = maxf(1.1, _head_h + 0.13)
	get_node("Body").position.y = (get_node("Body").shape as CapsuleShape3D).height * 0.5
	# steps, bob and noise
	var sp := hv.length()
	if is_on_floor() and sp > 0.3:
		_bob += delta * sp * (5.2 if not running else 4.4)
		_step_d += sp * delta
		var stride := 0.75 if not running else 1.0
		if _step_d > stride:
			_step_d = 0.0
			var loud := 0.06 if crouching else (0.55 if running else 0.18)
			Sfx.play("step_" + _surface(), -20.0 if crouching else (-8.0 if running else -14.0), randf_range(0.9, 1.1))
			if _surface() == "wood" and randf() < 0.12: Sfx.play("board_creak", -16.0, randf_range(0.8, 1.2))
			Game.make_noise(global_position, loud * noise_mult)
	var bob_amt := 0.0 if crouching else (0.035 if running else 0.018)
	var bob := Vector3(cos(_bob * 0.5) * bob_amt * 0.6, absf(sin(_bob * 0.5)) * bob_amt, 0) * clampf(sp / 2.0, 0.0, 1.0)
	var sh := Vector3.ZERO
	if _shake_t > 0.0:
		_shake_t -= delta
		sh = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * clampf(_shake_t * 2.0, 0.0, 1.0)
	head.position = Vector3(0, _head_h, 0) + bob + sh
	# an old man who's been running: you hear it
	_pant = clampf(_pant + (delta * 0.5 if running else -delta * 0.15), 0.0, 1.0)
	if stamina < STAMINA_MAX * 0.4 and running: _pant = maxf(_pant, 0.6)
	Sfx.set_loop_volume("pant", linear_to_db(maxf(0.0001, _pant * 0.5)))
	_torch_update(delta)
	# what's in reach
	_update_target()
	if held: _carry(delta)

func _surface() -> String:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.3, 0), global_position + Vector3(0, -0.4, 0), 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty(): return footstep.trim_prefix("step_")
	return hit.collider.get_meta("surface", footstep.trim_prefix("step_"))

## The torch: a hand torch, warm, a little weak. Its beam shows in the dust.
func toggle_torch(v = null) -> void:
	if not torch: return
	torch_on = (not torch_on) if v == null else bool(v)
	Sfx.play("switch", -8.0)

func _torch_update(delta: float) -> void:
	if not torch: return
	var k := 1.0
	if torch_flicker > 0.0 and randf() < torch_flicker * delta * 8.0: k = randf_range(0.0, 0.5)
	var want := (4.5 if torch_on else 0.0) * k
	torch.light_energy = lerpf(torch.light_energy, want, 1.0 - exp(-30.0 * delta))
	torch.visible = torch.light_energy > 0.02
	torch_beam.visible = torch.visible
	(torch_beam.material_override as ShaderMaterial).set_shader_parameter("flicker", torch.light_energy / 4.5)
	# the beam swings a little behind where he looks
	torch.rotation = torch.rotation.lerp(Vector3(-_look_lag.y * 0.6, -_look_lag.x * 0.6, 0), 1.0 - exp(-12.0 * delta))

func _apply_view() -> void:
	rotation = Vector3(0, _yaw, 0)
	head.rotation = Vector3(_pitch, 0, _roll)

func _blocked_above() -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.0, 0), global_position + Vector3(0, 1.85, 0), 1 | 32, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()

# ------------------------------------------------------------------ interaction
func _update_target() -> void:
	var t: Node = null
	if controls and not held:
		ray.force_raycast_update()
		if ray.is_colliding():
			t = find_interactable(ray.get_collider())
	target = t

## Walk up from a collider to the node that handles interaction (has get_prompt()).
static func find_interactable(n: Node) -> Node:
	for i in 4:
		if n == null: return null
		if n.has_method("get_prompt") and n.get_prompt() != "": return n
		n = n.get_parent()
	return null

func prompt() -> String:
	if held: return "Throw · Drop" if not inspecting else "Turn it over"
	return target.get_prompt() if target else ""

func _interact() -> void:
	if held:
		_drop(); return
	if target:
		if target is RigidBody3D and target.get_prompt().begins_with("Pick up"):
			_pick(target)
		elif target.has_method("interact"):
			target.interact(self)
		interacted.emit(target)

func _pick(b: RigidBody3D) -> void:
	held = b
	b.gravity_scale = 0.0; b.linear_damp = 8.0; b.angular_damp = 8.0
	b.add_collision_exception_with(self)
	Sfx.play("pickup", -10.0)
	if b.has_method("on_picked"): b.on_picked(self)

func _carry(delta: float) -> void:
	if not is_instance_valid(held): held = null; return
	var want := cam.global_position + (-cam.global_transform.basis.z) * (0.75 if not inspecting else 0.5) + Vector3(0, -0.1, 0)
	var d := want - held.global_position
	if d.length() > 1.6: _drop(); return
	held.linear_velocity = d * 14.0
	if not inspecting: held.angular_velocity *= 0.8

func _drop() -> void:
	if not held: return
	var b := held; held = null; inspecting = false
	b.gravity_scale = 1.0; b.linear_damp = 0.1; b.angular_damp = 0.3
	b.remove_collision_exception_with(self)

func _throw() -> void:
	var b := held
	_drop()
	b.linear_velocity = -cam.global_transform.basis.z * clampf(7.5 / maxf(0.3, b.mass), 3.0, 11.0) + velocity
	b.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
