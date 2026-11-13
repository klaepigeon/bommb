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
var _roll_feel := 0.0
# feel (docs/FEEL.md)
const FOV := 72.0
var lean := 0.0               # -1 left .. 1 right: round a corner without stepping out
var _lean_off := 0.0
var _air_t := 0.0
var _fall_v := 0.0
var _land := 0.0              # the knees taking a landing: the head dips, springs back
var _land_v := 0.0
var _step_phase := 0
var _strafe := 0.0
var _sway := Vector3.ZERO     # the hands and what's in them lag the look, and the walk
var _breath := 0.0
var _torch_near := 1.0
var tremor := 0.0
## Health (0..1). No meter: it shows in Socko (blood through the knit, a sag) and the picture's
## edges. Back slowly after nine seconds unhurt. At nothing, the level decides (on_player_down).
var health := 1.0
var _hurt_t := 99.0
signal hurt_by(amount: float, from: Vector3)

func hurt(amount: float, from: Vector3) -> void:
	if health <= 0.0: return
	health = maxf(0.0, health - amount)
	_hurt_t = 0.0
	shake(0.03 + amount * 0.05, 0.35)
	fov_kick = 4.0
	Sfx.play("gasp", -4.0, randf_range(0.9, 1.05))
	Sfx.play("thud", -6.0, 1.2)
	Fx.kick("fringe", 1.2, 0.8)
	var away := (global_position - from) * Vector3(1, 0, 1)
	if away.length() > 0.01: velocity += away.normalized() * 3.0 * amount
	var s = get_parent().get("socko")
	if s: s.gesture("recoil")
	hurt_by.emit(amount, from)
	if health <= 0.0:
		var lv = get_parent()
		if lv and lv.has_method("on_player_down"): lv.on_player_down()
		else: Game.restart_level()             # his nerve (Nerve): the hands and the aim shake
var hidden_in: Node = null
var breath_held := false      # (Nerve sets it; she listens for it)    # a HideSpot he's inside
var _hide_from := Transform3D()
var _hide_eye := Transform3D()
const TORCH_DRAIN := 1.0 / 300.0     # five minutes of light in a battery
var fov_kick := 0.0           # a blow, a scare: the view punches in for a moment

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2; collision_mask = 1 | 32
	var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new()
	cap.radius = 0.28; cap.height = 1.75
	cs.shape = cap; cs.position.y = 0.875; cs.name = "Body"
	add_child(cs)
	head = Node3D.new(); head.name = "Head"; head.position.y = HEAD_STAND
	add_child(head)
	cam = Camera3D.new(); cam.name = "Camera"; cam.fov = 72.0; cam.near = 0.05; cam.far = 80.0      # (near at 5 cm: 2.5x the depth precision; phones z-fought at 2)
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
	torch.shadow_enabled = bool(Game.settings.get("shadows", true)); torch.shadow_bias = 0.12; torch.shadow_normal_bias = 2.0
	cam.add_child(torch)
	torch_beam = Air.beam(torch, 7.0, 2.8, Color("ffe2b8"), 0.03)
	torch_beam.visible = false
	ray = RayCast3D.new(); ray.target_position = Vector3(0, 0, -REACH); ray.collision_mask = 1 | 4 | 16 | 32
	ray.add_exception(self)
	cam.add_child(ray)
	_yaw = rotation.y; rotation.y = 0.0
	Sfx.loop("pant", "pant", -80.0)

## (the Infection tree's Lungs raise it)
func stamina_max() -> float:
	return STAMINA_MAX * Game.stat("stamina_max")

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
	if hidden_in:
		# inside: the doors, and the torch (which shows through the gap)
		if e.is_action_pressed("interact"): hidden_in.interact(self)
		if e.is_action_pressed("torch") and has_torch: toggle_torch()
		return
	if not controls: return
	if e.is_action_pressed("interact"): _interact()
	if e.is_action_pressed("crouch"): crouching = not crouching
	if e.is_action_pressed("torch") and has_torch: toggle_torch()
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
		if hidden_in:
			# only as far as the gap lets him see
			var f: Vector3 = -_hide_eye.basis.z
			var base := atan2(-f.x, -f.z)
			_yaw = base + clampf(wrapf(_yaw - base, -PI, PI), -0.45, 0.45); _pitch = clampf(_pitch, -0.35, 0.3)
	_apply_view()
	if hidden_in:
		# inside: no body to move, just eyes at the gap in the doors
		velocity = Vector3.ZERO
		head.position = Vector3(0, _head_h, 0) + Vector3(0, sin(_breath) * 0.004 if Game.settings.get("sway", true) else 0.0, 0)
		_breath += delta * lerpf(1.4, 3.4, _pant)
		_torch_update(delta)
		_update_target()
		_viewmodel(delta, 0.0)
		return
	# move
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if controls else Vector2.ZERO
	var want_run := controls and Input.is_action_pressed("sprint") and input.y < -0.3 and not crouching
	if want_run and stamina > 0.0:
		running = true; stamina -= delta
	else:
		running = false; stamina = minf(stamina_max(), stamina + delta * (0.6 if want_run else 1.0))
	var speed := CROUCH * Game.stat("crouch_speed") if crouching else (RUN if running else WALK)
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
			if rb and rb != held and absf(col.get_normal().y) < 0.5 and rb.mass >= 2.0:
				if rb.has_method("wake"): rb.wake()      # (furniture he walks into; not the little things on shelves)
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
		# a step lands at the bottom of each bob, so the sound and the camera agree
		var ph := int(floor(_bob * 0.5 / PI))
		if ph != _step_phase:
			_step_phase = ph
			_footstep(0.0)
	else:
		_bob = lerpf(_bob, round(_bob * 0.5 / PI) * PI * 2.0, 1.0 - exp(-6.0 * delta))   # settle to standing
	# airborne and landing: the knees take it, harder the further he fell
	if not is_on_floor():
		_air_t += delta; _fall_v = minf(_fall_v, velocity.y)
	else:
		if _air_t > 0.12:
			var hard := clampf(-_fall_v / 5.0, 0.15, 1.0)
			_land_v -= 2.4 * hard
			_footstep(hard)
			if hard > 0.5: shake(0.012 * hard, 0.2)
		_air_t = 0.0; _fall_v = 0.0
	# (a spring: dip, overshoot a little, settle)
	_land_v += (-_land * 140.0 - _land_v * 16.0) * delta
	_land += _land_v * delta
	var bob_amt := 0.0 if crouching else (0.035 if running else 0.018)
	var bob := Vector3(cos(_bob * 0.5) * bob_amt * 0.6, absf(sin(_bob * 0.5)) * bob_amt, 0) * clampf(sp / 2.0, 0.0, 1.0)
	var sh := Vector3.ZERO
	if _shake_t > 0.0:
		_shake_t -= delta
		sh = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * clampf(_shake_t * 2.0, 0.0, 1.0)
	# lean: the head goes out to the side and tips, as far as the wall lets it
	var want_lean := 0.0
	if controls: want_lean = Input.get_axis("lean_left", "lean_right") if InputMap.has_action("lean_left") else 0.0
	want_lean = clampf(want_lean + lean, -1.0, 1.0)
	var reach_l := 0.34 * want_lean
	if absf(reach_l) > 0.01:
		var side := global_transform.basis.x * signf(reach_l)
		var eye := global_position + Vector3(0, _head_h, 0)
		var q := PhysicsRayQueryParameters3D.create(eye, eye + side * (absf(reach_l) + 0.15), 1 | 32, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty(): reach_l = signf(reach_l) * maxf(0.0, eye.distance_to(hit.position) - 0.15)
	_lean_off = lerpf(_lean_off, reach_l, 1.0 - exp(-9.0 * delta))
	# strafing tips the head a touch, into the turn
	var local_v := global_transform.basis.inverse() * hv
	_strafe = lerpf(_strafe, clampf(-local_v.x / RUN, -1.0, 1.0), 1.0 - exp(-6.0 * delta))
	_roll_feel = -_lean_off * 0.33 + _strafe * 0.018
	# breathing, standing still: the view rises and falls, faster when he's winded
	_breath += delta * lerpf(1.4, 3.4, _pant)
	var sway_on: bool = Game.settings.get("sway", true)
	var br := Vector3(0, sin(_breath) * lerpf(0.003, 0.009, _pant), 0) if sway_on else Vector3.ZERO
	head.position = Vector3(_lean_off, _head_h + _land * (0.5 if sway_on else 0.15), 0) + bob + sh + br
	# field of view: wider at a run, punched in by a blow or a fright
	fov_kick = move_toward(fov_kick, 0.0, delta * 20.0)
	cam.fov = lerpf(cam.fov, FOV + (5.0 if running and sp > 2.5 else 0.0) - fov_kick, 1.0 - exp(-6.0 * delta))
	_viewmodel(delta, sp)
	# an old man who's been running: you hear it
	_pant = clampf(_pant + (delta * 0.5 if running else -delta * 0.15), 0.0, 1.0)
	if stamina < stamina_max() * 0.4 and running: _pant = maxf(_pant, 0.6)
	Sfx.set_loop_volume("pant", linear_to_db(maxf(0.0001, _pant * 0.5)))
	_torch_update(delta)
	# health: back slowly when he's been left alone a while
	_hurt_t += delta
	if _hurt_t > 9.0 and health > 0.0: health = minf(1.0, health + delta * 0.04)
	var sk = get_parent().get("socko")
	if sk: sk.vitals = health
	Fx.set_k("hurt", 1.0 - health)
	# what's in reach
	_update_target()
	if held: _carry(delta)

## A footstep (and a landing, `hard` > 0): the sound for what he's on, and the noise she hears.
func _footstep(hard: float) -> void:
	var loud := 0.06 if crouching else (0.55 if running else 0.18)
	loud = maxf(loud, hard * 0.7)
	var surf := _surface()
	var db := -20.0 if crouching else (-8.0 if running else -14.0)
	if hard > 0.0: db = lerpf(-12.0, -3.0, hard)
	Sfx.play("step_" + surf, db, randf_range(0.9, 1.1) * (0.85 if hard > 0.4 else 1.0))
	if hard > 0.4: Sfx.play("thud", lerpf(-18.0, -8.0, hard), 1.2)
	if surf == "wood" and randf() < 0.12: Sfx.play("board_creak", -16.0, randf_range(0.8, 1.2))
	Game.make_noise(global_position, loud * noise_mult * Game.stat("noise"))

## The things in his hands lag the look and ride the walk, so they have weight.
func _viewmodel(delta: float, sp: float) -> void:
	var walk := clampf(sp / 2.0, 0.0, 1.0)
	var want := Vector3(-_look_lag.x * 0.5, _look_lag.y * 0.5, 0.0) * 0.06
	want += Vector3(cos(_bob * 0.5) * 0.008, -absf(sin(_bob * 0.5)) * 0.01, 0) * walk * (1.8 if running else 1.0)
	want.y += _land * 0.05 + (sin(_breath) * 0.002 if Game.settings.get("sway", true) else 0.0)
	want.z += 0.03 if running and sp > 2.5 else 0.0
	if tremor > 0.3:
		var tt := Time.get_ticks_msec() * 0.001
		want += Vector3(sin(tt * 23.0) + sin(tt * 37.0) * 0.5, cos(tt * 29.0) + sin(tt * 17.0) * 0.5, 0) * (tremor - 0.3) * 0.006
	_sway = _sway.lerp(want, 1.0 - exp(-14.0 * delta))
	var rot := Vector3(_sway.y * 1.6, -_sway.x * 1.6, _sway.x * 1.2 - _strafe * 0.04)
	for n in [arm_mount, hand_mount, cam.get_node_or_null("Hands")]:
		if n:
			(n as Node3D).position = _sway
			(n as Node3D).rotation = rot

func _surface() -> String:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.3, 0), global_position + Vector3(0, -0.4, 0), 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty(): return footstep.trim_prefix("step_")
	return hit.collider.get_meta("surface", footstep.trim_prefix("step_"))

## (Nerve) any time his breath is his own: moving, or hidden.
func controls_or_hidden() -> bool:
	return controls or hidden_in != null

## Into a hiding place: the body goes away, the eyes go to `eye` (a Transform3D, world), looking
## out through the gap.
func hide_in(spot: Node, eye: Transform3D) -> void:
	if held: _drop()
	hidden_in = spot
	_hide_from = global_transform
	_hide_eye = eye
	var fill := cam.get_node_or_null("Fill") as OmniLight3D
	if fill: fill.light_energy = 0.03          # (dark in a wardrobe: the gap is the only light)
	controls = false
	collision_layer = 0; collision_mask = 0
	global_position = eye.origin - Vector3(0, _head_h, 0)
	var f := -eye.basis.z
	set_view(atan2(-f.x, -f.z), 0.0)
	crouching = false

func leave_hiding(to: Vector3, facing: Vector3) -> void:
	if not hidden_in: return
	hidden_in = null
	var fill := cam.get_node_or_null("Fill") as OmniLight3D
	if fill: fill.light_energy = 0.35
	global_position = to
	collision_layer = 2; collision_mask = 1 | 32
	set_view(atan2(-facing.x, -facing.z), 0.0)
	controls = true

## The torch: a hand torch, warm, a little weak. Its beam shows in the dust.
func toggle_torch(v = null) -> void:
	if not torch: return
	torch_on = (not torch_on) if v == null else bool(v)
	Sfx.play("switch", -8.0)

func _torch_update(delta: float) -> void:
	if not torch: return
	var k := 1.0
	if torch_flicker > 0.0:
		# near her the torch sags and comes back, slowly (never strobes)
		k = 1.0 - torch_flicker * (0.45 + 0.25 * sin(Time.get_ticks_msec() * 0.0021))
	if torch_on: Game.torch_charge = maxf(0.0, Game.torch_charge - TORCH_DRAIN * delta)
	# a flat battery doesn't die, it browns down: full till a quarter, then a long slow sag
	var batt := smoothstep(0.0, 0.25, Game.torch_charge) * 0.85 + 0.15 * float(Game.torch_charge > 0.0)
	# close to a wall the beam would burn to a flat white disc: the eye stops down, so the light
	# comes down with the distance to what it's on (and the spot widens a touch, as a near beam does)
	var reach := 15.0
	if torch_on:
		var f := torch.global_position; var to := f - torch.global_transform.basis.z * 15.0
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(f, to, 1 | 8 | 32, [get_rid()]))
		if not hit.is_empty(): reach = f.distance_to(hit.position)
		if hidden_in: reach = 0.15          # (inside a wardrobe: the doors are right there)
	_torch_near = lerpf(_torch_near, clampf(reach / 2.2, 0.0, 1.0), 1.0 - exp(-6.0 * delta))
	var near_k := lerpf(0.22, 1.0, smoothstep(0.0, 1.0, _torch_near))
	torch.spot_angle = lerpf(34.0, 26.0, _torch_near)
	var want := (4.5 if torch_on else 0.0) * k * batt * near_k
	torch.light_energy = lerpf(torch.light_energy, want, 1.0 - exp(-8.0 * delta))
	torch.visible = torch.light_energy > 0.02
	torch_beam.visible = torch.visible
	(torch_beam.material_override as ShaderMaterial).set_shader_parameter("flicker", torch.light_energy / 4.5)
	# the beam swings a little behind where he looks
	torch.rotation = torch.rotation.lerp(Vector3(-_look_lag.y * 0.6, -_look_lag.x * 0.6, 0), 1.0 - exp(-12.0 * delta))

func _apply_view() -> void:
	rotation = Vector3(0, _yaw, 0)
	head.rotation = Vector3(_pitch, 0, _roll + _roll_feel)

func _blocked_above() -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.0, 0), global_position + Vector3(0, 1.85, 0), 1 | 32, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()

# ------------------------------------------------------------------ interaction
func _update_target() -> void:
	var t: Node = null
	# (holding a sticky note (Flat 48) he can still aim it at things: the note is what "use" puts there)
	if controls and (not held or held.has_meta("word")):
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
	if hidden_in: return hidden_in.get_prompt()
	if held and held.has_meta("word") and target: return target.get_prompt()
	if held:
		if inspecting: return "Turn it over"
		if Skills.has("m_observe"):
			var pr := Weapons.profile(held)
			var lbl: String = String(held.get("label")) if held.get("label") != null else "it"
			return "%s (%s · %d dmg · %d%%) · Hit · Throw · Drop" % [lbl, pr["class"], int(pr.dmg * Game.stat("strength")), int(Weapons.durability_frac(held) * 100.0)]
		var d := Weapons.durability_frac(held)
		return "%s · Hit · Throw · Drop" % [String(held.get("label")) if held.get("label") != null else "it"] if d >= 0.999 else "%s (%d%%) · Hit · Throw · Drop" % [String(held.get("label")), int(d * 100.0)]
	return target.get_prompt() if target else ""

func _interact() -> void:
	if held:
		if held.has_meta("word") and target and target.has_method("interact"):
			target.interact(self); interacted.emit(target); return
		_drop(); return
	if target:
		if target is RigidBody3D and target.get_prompt().begins_with("Pick up"):
			_pick(target)
		elif target.has_method("interact"):
			target.interact(self)
		interacted.emit(target)

func _pick(b: RigidBody3D) -> void:
	if b.has_method("wake"): b.wake()
	held = b
	ray.add_exception(b)
	b.gravity_scale = 0.0; b.linear_damp = 8.0; b.angular_damp = 8.0
	b.add_collision_exception_with(self)
	Sfx.play("pickup", -10.0)
	if b.has_method("on_picked"): b.on_picked(self)

func _carry(delta: float) -> void:
	if not is_instance_valid(held): held = null; return
	if held.freeze: return          # mid-swing: the hands have it
	var want := cam.global_position + (-cam.global_transform.basis.z) * (0.75 if not inspecting else 0.5) + Vector3(0, -0.1, 0)
	var d := want - held.global_position
	if d.length() > 1.6: _drop(); return
	held.linear_velocity = d * 14.0
	if not inspecting: held.angular_velocity *= 0.8

func _drop() -> void:
	if not held: return
	var b := held; held = null; inspecting = false
	ray.remove_exception(b)
	b.gravity_scale = 1.0; b.linear_damp = 0.1; b.angular_damp = 0.3
	b.remove_collision_exception_with(self)

## (for the hands: melee picks up what's left of a broken thing, throws, drops)
func pick_up(b: RigidBody3D) -> void: _pick(b)
func drop_held() -> void: _drop()
func throw_held() -> void: if held: _throw()

func _throw() -> void:
	var b := held
	_drop()
	b.linear_velocity = -cam.global_transform.basis.z * clampf(7.5 / maxf(0.3, b.mass), 3.0, 11.0) + velocity
	b.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
