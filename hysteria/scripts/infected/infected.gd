class_name Infected
extends CharacterBody3D
## One infected person, loose: their body (InfectedBody, built from their genome) and what they do.
## They hunt like Marta, by sound first, but each in their own way: how well they hear and see,
## how fast they can go on what they've got left, how long they keep looking, what they still do
## out of habit, the one thing they still say.
##
##   IDLE     standing (or lying) where they are, doing what they kept doing
##   WANDER   drifting somewhere near, slowly
##   LISTEN   heard something: going to where it was
##   SEARCH   there, looking round, for a while
##   CHASE    can see him: coming, as fast as their body lets them
##   GRAB     within reach: they take hold of him (as Marta does: it goes black, he comes to
##            somewhere else; `on_caught` decides where), then they lose interest for a while
##   DEAD     shot down, collapsed, for good
##
## Shots (revolver, shotgun: anything that calls shot()) hit a part: the head (worst), the trunk,
## or a limb. Enough damage to a limb takes it off: it falls, and they go on with what's left
## (no legs: they crawl; nothing: they drag). How dangerous they are reads the threat manager's
## levers (hearing, sight, pace, persistence) as Marta does, times their own.

signal died
signal caught_kurt
signal lost_limb(id: String)

enum S { IDLE, WANDER, LISTEN, SEARCH, CHASE, GRAB, DEAD }

const SPEED := {"walk": 1.25, "limp": 0.85, "skitter": 1.9, "hop": 0.9, "lurch": 0.7, "crawl": 0.6, "drag": 0.3}
const REACH := 1.0
const HP := {"head": 4, "torso": 9, "limb": 3}

var genome: Dictionary
var body: InfectedBody
var player: Node                     # Kurt (or anything with global_position and a camera "cam")
var state := S.IDLE
var on_caught: Callable              # what happens when they take hold of him (default: Marta's)
var home := Vector3.ZERO
var wander_radius := 5.0
var _hp := {}
var _t := 0.0; var _state_t := 0.0
var _goal := Vector3.ZERO
var _yaw := 0.0
var _attack := 0.0
var _hits: StaticBody3D
var _shape_part: Array = []          # shape index -> hit part index
var _said := 0.0
var _rng := RandomNumberGenerator.new()
var _gravity := 9.8
var _calm_until := 0.0               # after taking hold of him they lose interest a while

func setup(g: Dictionary, p_player: Node = null) -> void:
	genome = g
	player = p_player

func _ready() -> void:
	if genome.is_empty(): genome = InfectedGenome.generate(randi())
	_rng.seed = int(genome.seed) + 101
	add_to_group("listener"); add_to_group("infected")
	collision_layer = 1 | 4; collision_mask = 1     # solid to Kurt and to each other; layer 4 marks them
	var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new()
	cap.radius = 0.28; cap.height = 1.0 if genome.locomotion in ["crawl", "drag"] else 1.6
	cs.shape = cap; cs.position.y = cap.height * 0.5; add_child(cs)
	body = InfectedBody.new(); body.name = "Body"; add_child(body)
	body.build(genome)
	home = global_position if is_inside_tree() else position
	_yaw = rotation.y
	_hit_shapes()
	_hp = {"head": HP.head, "torso": HP.torso}
	for l in genome.limbs: _hp[l.id] = HP.limb + (1 if String(l.state) == "fused" else 0)
	_state_t = _rng.randf_range(0.0, 4.0)

# ---------------------------------------------------------------- hit shapes, on the bones
func _hit_shapes() -> void:
	_hits = StaticBody3D.new(); _hits.name = "Hits"
	_hits.collision_layer = 8; _hits.collision_mask = 0      # shots look for it; nothing walks into it
	add_child(_hits)
	for i in body.hit_parts.size():
		var hp: Dictionary = body.hit_parts[i]
		var cs := CollisionShape3D.new(); var sh := CapsuleShape3D.new()
		sh.radius = float(hp.r); sh.height = maxf((hp.a as Vector3).distance_to(hp.b) + sh.radius * 2.0, sh.radius * 2.01)
		cs.shape = sh; _hits.add_child(cs)
		_shape_part.append(i)
	_update_hits()

func _update_hits() -> void:
	var sk := body.skel
	for i in _shape_part.size():
		var hp: Dictionary = body.hit_parts[_shape_part[i]]
		var cs: CollisionShape3D = _hits.get_child(i)
		var part := String(hp.part)
		if body.severed.has(part):
			cs.disabled = true; continue
		var b: int = hp.bone
		var bx := sk.global_transform * sk.get_bone_global_pose(b) * sk.get_bone_global_rest(b).affine_inverse()
		var a := bx * (hp.a as Vector3); var c := bx * (hp.b as Vector3)
		var d := c - a
		var basis := Basis(Quaternion(Vector3.UP, d.normalized())) if d.length() > 1e-4 else Basis()
		cs.global_transform = Transform3D(basis, a.lerp(c, 0.5))

## The part a shot landed on: whichever part's bone segment the hit point is closest to the skin
## of (the shape index a ray reports can belong to the body capsule, so it isn't trusted).
func part_at(point: Vector3, _shape := -1) -> String:
	var best := "torso"; var bd := INF
	for i in _shape_part.size():
		var cs: CollisionShape3D = _hits.get_child(i)
		if cs.disabled: continue
		var sh: CapsuleShape3D = cs.shape
		var half := cs.global_transform.basis.y.normalized() * maxf(0.0, sh.height * 0.5 - sh.radius)
		var a := cs.global_position - half; var b := cs.global_position + half
		var d := Geometry3D.get_closest_point_to_segment(point, a, b).distance_to(point) - sh.radius
		if d < bd: bd = d; best = String(body.hit_parts[_shape_part[i]].part)
	return best

# ---------------------------------------------------------------- senses
func _lever(n: String) -> float:
	return ThreatManager.lever(n)

func _eye() -> Vector3:
	return body.skel.global_transform * body.skel.get_bone_global_pose(body.bones.head).origin

func _kurt() -> Vector3:
	if player == null: return Vector3.INF
	var c = player.get("cam")
	return (c as Node3D).global_position if c is Node3D else (player as Node3D).global_position + Vector3(0, 1.6, 0)

func sees_kurt() -> bool:
	if player == null or state == S.DEAD or _t < _calm_until: return false
	if int(genome.head.eyes) == 0 and genome.head.state != "overgrown": return false
	var k := _kurt()
	var e := _eye()
	var d := e.distance_to(k)
	var range := 9.0 * float(genome.sight) * _lever("sight")
	if player.get("torch_holder") != null or player.get("torch_on"): range *= 1.4
	if d > range: return false
	var fwd := -global_transform.basis.z
	var to := (k - e).normalized()
	if fwd.dot(to) < (-0.1 if d < 2.0 else 0.35): return false
	var q := PhysicsRayQueryParameters3D.create(e, k)
	q.collision_mask = 1
	q.exclude = [get_rid(), (player as CollisionObject3D).get_rid()] if player is CollisionObject3D else [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## A noise (Noises.make): heard if it carries to them.
func hear(pos: Vector3, loud: float, what: String, _source: Node) -> void:
	if state in [S.DEAD, S.GRAB, S.CHASE] or _t < _calm_until: return
	var d := global_position.distance_to(pos)
	if d > 12.0 * loud * float(genome.hearing) * _lever("hearing"): return
	_goal = pos; _enter(S.LISTEN)

# ---------------------------------------------------------------- state
func _enter(s: S) -> void:
	state = s; _state_t = 0.0

func _physics_process(delta: float) -> void:
	_t += delta; _state_t += delta
	var speed := 0.0
	var mode := "move"
	var look = null
	var base_speed: float = float(SPEED.get(body.locomotion, 0.6)) * float(genome.speed) * _lever("pace")
	if state != S.DEAD and state != S.GRAB and sees_kurt():
		if state != S.CHASE: _say_fragment()
		_enter(S.CHASE)
	match state:
		S.IDLE:
			mode = "idle"
			if _state_t > _rng.randf_range(5.0, 12.0):
				_goal = home + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)) * wander_radius
				_enter(S.WANDER)
		S.WANDER:
			speed = _steer(_goal, base_speed * 0.5, delta)
			if speed < 0.0 or _state_t > 14.0: speed = 0.0; _enter(S.IDLE)
		S.LISTEN:
			speed = _steer(_goal, base_speed * 0.8, delta)
			look = _goal
			if speed < 0.0 or _state_t > 20.0: speed = 0.0; _enter(S.SEARCH)
		S.SEARCH:
			mode = "idle"
			_yaw += sin(_state_t * 1.3) * delta * 1.2
			if _state_t > 6.0 * float(genome.persistence): home = global_position; _enter(S.IDLE)
		S.CHASE:
			var k := _kurt()
			look = k
			var flat := Vector3(k.x, global_position.y, k.z)
			var reach := REACH * (1.2 if body.locomotion in ["crawl", "drag"] else 1.0)
			# up to arm's length, not into him (pushing into a body, they'd climb it)
			speed = _steer(flat, base_speed * 1.25, delta, reach * 0.85)
			if global_position.distance_to(flat) < reach:
				_grab()
			elif not sees_kurt() and _state_t > 2.0 * float(genome.persistence) * _lever("persistence") / 6.0 + 1.5:
				_goal = flat; _enter(S.SEARCH)
			if speed < 0.0: speed = 0.0
		S.GRAB:
			mode = "attack"
			_attack = minf(1.0, _attack + delta * 2.5)
		S.DEAD:
			mode = "dead"
	if state != S.GRAB: _attack = maxf(0.0, _attack - delta * 2.0)
	# gravity and the move
	if not is_on_floor(): velocity.y -= _gravity * delta
	else: velocity.y = minf(velocity.y, 0.0)
	if state == S.DEAD or state == S.GRAB or state in [S.IDLE, S.SEARCH]:
		velocity.x = move_toward(velocity.x, 0.0, delta * 6.0); velocity.z = move_toward(velocity.z, 0.0, delta * 6.0)
	move_and_slide()
	rotation.y = lerp_angle(rotation.y, _yaw, 1.0 - exp(-delta * (6.0 if state == S.CHASE else 3.0)))
	var ctx := {"speed": Vector2(velocity.x, velocity.z).length(), "mode": mode, "attack": _attack,
		"look": (body.skel.global_transform.affine_inverse() * (look as Vector3)) if look != null else null}
	body.animate(delta, ctx)
	_update_hits()

## Head for a point: returns the speed they're going at, or -1 when they're there.
func _steer(to: Vector3, speed: float, delta: float, arrive := 0.5) -> float:
	var d := to - global_position; d.y = 0.0
	if d.length() < arrive:
		velocity.x = 0.0; velocity.z = 0.0
		return -1.0
	var dir := d.normalized()
	# feel ahead: turn off a wall rather than walk into it
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 0.5, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 0.9); q.collision_mask = 1; q.exclude = [get_rid()]
	if not space.intersect_ray(q).is_empty():
		for a in [0.7, -0.7, 1.4, -1.4]:
			var alt := dir.rotated(Vector3.UP, a)
			var q2 := PhysicsRayQueryParameters3D.create(from, from + alt * 0.9); q2.collision_mask = 1; q2.exclude = [get_rid()]
			if space.intersect_ray(q2).is_empty(): dir = alt; break
	_yaw = atan2(-dir.x, -dir.z)
	# the gait has a rhythm: crawling and dragging come in pulls, hopping in hops
	var pulse := 1.0
	match body.locomotion:
		"crawl", "drag", "lurch": pulse = 0.55 + 0.45 * absf(sin(body._phase * 0.5 + 0.8))
		"hop": pulse = 0.4 + 0.6 * absf(sin(body._phase * 0.8))
	var v := dir * speed * pulse
	velocity.x = move_toward(velocity.x, v.x, delta * 8.0); velocity.z = move_toward(velocity.z, v.z, delta * 8.0)
	return speed * pulse

func _say_fragment() -> void:
	if _t - _said < 20.0 or player == null: return
	if global_position.distance_to((player as Node3D).global_position) > 8.0: return
	_said = _t
	var game := get_node_or_null("/root/Game")
	if game: game.call("speak", "“%s”" % genome.fragment, 3.0, _rng.randf_range(0.6, 0.95), 0.75)

func _grab() -> void:
	_enter(S.GRAB)
	caught_kurt.emit()
	if on_caught.is_valid():
		await on_caught.call(self)
	else:
		await _default_caught()
	if state == S.DEAD: return
	# he's gone; they lose interest a while, and drift off
	_attack = 0.0
	_calm_until = _t + 8.0
	home = global_position
	_goal = global_position + global_transform.basis.z * 3.0
	_enter(S.WANDER)

## As Marta does: held to their face, the fragment, black; he comes to a few metres back.
func _default_caught() -> void:
	var game := get_node_or_null("/root/Game")
	if player == null: return
	player.set("locked", true)
	player.set("look_target", _eye())
	player.set("shake", 1.0)
	if game: game.call("speak", "“%s”" % genome.fragment, 3.0, 0.75, 0.7)
	await get_tree().create_timer(1.2).timeout
	if game: game.fade.emit(1.0, 0.6)
	await get_tree().create_timer(1.6).timeout
	var back := (player as Node3D).global_position - (-global_transform.basis.z) * 4.0
	(player as Node3D).global_position = Vector3(back.x, (player as Node3D).global_position.y, back.z)
	player.set("look_target", null)
	await get_tree().create_timer(0.6).timeout
	player.set("locked", false)
	if game: game.fade.emit(0.0, 1.4)

# ---------------------------------------------------------------- shot
## Anything that shoots calls this. Head: worst. Trunk: slow. A limb: enough and it comes off.
func shot(point: Vector3, _normal: Vector3, headshot_kills: bool, shape: int) -> bool:
	if state == S.DEAD: return false
	var part := part_at(point, shape)
	var dmg := 1
	_hp[part] = int(_hp.get(part, 1)) - dmg
	body.flinch(global_transform.basis.inverse() * (point - global_position).normalized(), 1.5 if part == "head" else 1.0)
	if part == "head":
		if headshot_kills or int(_hp.head) <= 0: _die(); return true
	elif part == "torso":
		if int(_hp.torso) <= 0: _die(); return true
	else:
		if int(_hp[part]) <= 0:
			if body.sever(part) != null: lost_limb.emit(part)
	if state != S.CHASE and player != null:
		_goal = (player as Node3D).global_position; _enter(S.CHASE)
	return true

func _die() -> void:
	_enter(S.DEAD)
	_hits.collision_layer = 0
	collision_layer = 0
	died.emit()
