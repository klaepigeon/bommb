class_name Player
extends CharacterBody3D
## Kurt: first-person body, movement, look, the crosshair, and what scenes do to his head.
## Tree: Player (yaw) → Head (pitch, eye height) → Shake (offset, roll) → Camera3D → hands.

signal focus_changed(prompt: String)

const EYE := 1.66
const WALK := 1.5

var controls: Controls
var can_move := false
var can_look := false
var head: Node3D
var shake_node: Node3D
var camera: Camera3D
var arm: KurtArm
var socko: Socko
var body_mesh: Node3D
var focus: Hotspot

var _pitch := 0.0
var _step_dist := 0.0
var _bob := 0.0
var _shake := 0.0
var _shake_t := 0.0
var _legs: Array[Node3D] = []

func build() -> void:
	collision_layer = 1
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.26
	cap.height = 1.78
	cs.shape = cap
	cs.position.y = 0.89
	add_child(cs)
	floor_snap_length = 0.3
	head = Node3D.new(); head.name = "Head"; head.position.y = EYE; add_child(head)
	shake_node = Node3D.new(); head.add_child(shake_node)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.03
	camera.far = 60.0
	shake_node.add_child(camera)
	camera.make_current()
	arm = KurtArm.new(); camera.add_child(arm); arm.build()
	socko = Socko.new(); camera.add_child(socko); socko.build()
	_build_body()

func _build_body() -> void:
	# What he sees looking down: coat, trousers, shoes. Rigid, cheap, and it walks.
	body_mesh = Node3D.new(); add_child(body_mesh)
	var coat := Look.mat(Look.get_tex("cloth"), Color("3b3128"), 0.0)
	var trousers := Look.mat(Look.get_tex("cloth"), Color("2a2a2e"), 0.0)
	var shoes := Look.mat(Look.get_tex("white"), Color("120d0a"), 0.0)
	var torso := MeshInstance3D.new()
	var tm := BoxMesh.new(); tm.size = Vector3(0.38, 0.5, 0.2)
	torso.mesh = tm; torso.material_override = coat
	torso.position = Vector3(0, 1.08, 0.17)
	body_mesh.add_child(torso)
	for s in [-1.0, 1.0]:
		var hip := Node3D.new(); hip.position = Vector3(0.1 * s, 0.9, 0.06); body_mesh.add_child(hip)
		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new(); lm.size = Vector3(0.14, 0.86, 0.15)
		leg.mesh = lm; leg.material_override = trousers; leg.position.y = -0.45
		hip.add_child(leg)
		var shoe := MeshInstance3D.new()
		var sm := BoxMesh.new(); sm.size = Vector3(0.11, 0.08, 0.27)
		shoe.mesh = sm; shoe.material_override = shoes; shoe.position = Vector3(0, -0.86, -0.06)
		hip.add_child(shoe)
		_legs.append(hip)
	for mi in body_mesh.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func yaw() -> float:
	return rotation.y

## Point the view at a world position (instantly).
func face(point: Vector3) -> void:
	var d := point - camera.global_position
	rotation.y = atan2(-d.x, -d.z)
	_pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.4, 1.4)
	head.rotation.x = _pitch

## Turn the view toward a world position over time (shortest way round).
func look_toward(point: Vector3, seconds: float) -> Tween:
	var d := point - head.global_position
	var target_yaw := atan2(-d.x, -d.z)
	var cur := rotation.y
	target_yaw = cur + wrapf(target_yaw - cur, -PI, PI)
	var target_pitch := clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.4, 1.4)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "rotation:y", target_yaw, seconds)
	tw.tween_method(_set_pitch, _pitch, target_pitch, seconds)
	return tw

func _set_pitch(p: float) -> void:
	_pitch = p
	head.rotation.x = p

## The muzzle climbs; the view goes with it and settles back a little.
func add_recoil(amount: float) -> void:
	_set_pitch(clampf(_pitch + amount, -1.35, 1.35))
	rotation.y += randf_range(-amount, amount) * 0.3

func shake(amount: float, seconds: float) -> void:
	_shake = amount
	_shake_t = seconds

func _physics_process(delta: float) -> void:
	if controls == null:
		return
	# look
	var look := controls.consume_look()
	if can_look:
		rotation.y -= look.x * Settings.look_sensitivity
		_pitch = clampf(_pitch - look.y * Settings.look_sensitivity, -1.35, 1.35)
		head.rotation.x = _pitch
	# move
	var input := controls.move if can_move else Vector2.ZERO
	var dir := (transform.basis * Vector3(input.x, 0, input.y))
	dir.y = 0
	var target := dir * WALK
	velocity.x = move_toward(velocity.x, target.x, delta * 6.0)
	velocity.z = move_toward(velocity.z, target.z, delta * 6.0)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = -0.1
	move_and_slide()
	var speed := Vector2(velocity.x, velocity.z).length()
	# footsteps, bob, legs
	if is_on_floor() and speed > 0.2:
		_step_dist += speed * delta
		_bob += speed * delta * 4.2
		if _step_dist > 0.72:
			_step_dist = 0.0
			Sfx.play("step", -16.0, randf_range(0.85, 1.1))
			Noises.make(global_position, 2.5 if Game.owned("quiet_feet") else 5.0, "step")
	else:
		_bob = lerpf(_bob, round(_bob / PI) * PI, delta * 4.0)
	var swing := sin(_bob) * clampf(speed / WALK, 0.0, 1.0)
	if _legs.size() == 2:
		_legs[0].rotation.x = swing * 0.45
		_legs[1].rotation.x = -swing * 0.45
	# camera: bob, shake
	var off := Vector3(0, absf(sin(_bob)) * 0.025 * clampf(speed / WALK, 0.0, 1.0), 0)
	if _shake_t > 0.0:
		_shake_t -= delta
		off += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * clampf(_shake_t * 3.0, 0.0, 1.0)
	shake_node.position = off
	_update_focus()

func _update_focus() -> void:
	var found: Hotspot = null
	if can_move:
		var from := camera.global_position
		var to := from + -camera.global_transform.basis.z * 2.0
		var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2, [get_rid()])
		q.collide_with_areas = true
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit and hit.collider is Hotspot and (hit.collider as Hotspot).enabled:
			found = hit.collider
	if found != focus:
		focus = found
		focus_changed.emit(focus.prompt if focus else "")

func try_interact() -> void:
	if focus and focus.enabled and can_move:
		focus.used.emit()
