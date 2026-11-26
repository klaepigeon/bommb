class_name Feeder
extends CharacterBody3D
## The Court's thralls under the street. Not people (no schedule, no memory of who you are):
## patrol, sleep, go to noises, hunt what they see, grab. They see far in the light and barely in
## the dark, so the station's power cuts both ways. They can be hurt, staggered, killed, and they
## burn on the live rail like anything else.

enum State { PATROL, SLEEP, INVESTIGATE, HUNT, ATTACK, STAGGER, DEAD }

const WALK := 1.1
const RUN := 3.0
const REACH := 1.4
const DAMAGE := 18.0

var id := ""
var def: Dictionary
var state := State.PATROL
var health := 60.0
var puppet: Puppet
var agent: NavigationAgent3D
var patrol: Array[Vector3] = []
var talk_label := ""

var _patrol_i := 0
var _t := 0.0                 ## time left in the current state (investigate, stagger, attack wind-up)
var _target := Vector3.ZERO
var _see_t := 0.0
var _lost_t := 0.0
var _swing := 0.0
var _replan := 0.0

func setup(d: Dictionary, floor_y: float) -> void:
	def = d
	id = d.id
	health = float(d.get("health", health))
	name = "Feeder_" + id
	add_to_group("hostile")
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	puppet = Puppet.new()
	add_child(puppet)
	puppet.setup({"model": d.get("model", "Zombie_Male"), "height": float(d.get("height", 1.85)), "colors": d.get("colors", {})})
	agent = NavigationAgent3D.new()
	agent.navigation_layers = 1
	agent.path_desired_distance = 0.5
	agent.target_desired_distance = 0.4
	add_child(agent)
	for p in d.get("patrol", []):
		patrol.append(Vector3(p[0], floor_y, p[1]))
	global_position = Vector3(d.at[0], floor_y + 0.05, d.at[1])
	if d.get("sleeping", false):
		state = State.SLEEP
		puppet.hold("sleep")
	Events.world_event.connect(_on_event)

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	var player: Player = World.players[0] if not World.players.is_empty() else null
	if player == null or player.global_position.distance_to(global_position) > 45.0:
		return                      # nobody near: they keep still (the cheapest tier)
	_see_t -= delta
	if _see_t <= 0.0:
		_see_t = 0.25
		if state != State.STAGGER and state != State.SLEEP and _sees(player):
			if state != State.HUNT and state != State.ATTACK:
				Sfx.play_at("knock", global_position + Vector3.UP, -8.0, 0.3)
			state = State.HUNT if state != State.ATTACK else state
			_target = player.global_position
			_lost_t = 5.0
		elif state == State.SLEEP and player.global_position.distance_to(global_position) < 2.2:
			_wake(player.global_position)
	match state:
		State.SLEEP:
			return
		State.PATROL:
			if patrol.is_empty():
				puppet.locomote(0.0)
				return
			if _go(patrol[_patrol_i], WALK, delta):
				_patrol_i = (_patrol_i + 1) % patrol.size()
		State.INVESTIGATE:
			if _go(_target, WALK * 1.6, delta):
				puppet.locomote(0.0)
				_t -= delta
				if _t <= 0.0:
					state = State.PATROL
		State.HUNT:
			_lost_t -= delta
			if _sees_cheap(player):
				_target = player.global_position
			if global_position.distance_to(player.global_position) < REACH:
				state = State.ATTACK
				_swing = 0.0
			elif _lost_t <= 0.0:
				state = State.INVESTIGATE
				_t = 4.0
			else:
				_go(_target, RUN, delta)
		State.ATTACK:
			_face(player.global_position, delta)
			puppet.locomote(0.0)
			_swing -= delta
			if _swing <= 0.0:
				_swing = 1.3
				puppet.gesture("Punch")
				get_tree().create_timer(0.35).timeout.connect(func():
					if state == State.ATTACK and global_position.distance_to(player.global_position) < REACH + 0.3:
						player.hurt(DAMAGE, def.get("name", "something pale"), global_position))
			if global_position.distance_to(player.global_position) > REACH + 0.6:
				state = State.HUNT
		State.STAGGER:
			_t -= delta
			if _t <= 0.0:
				state = State.HUNT
				_lost_t = 5.0

## Walk/run toward p; true when there.
func _go(p: Vector3, speed: float, delta: float) -> bool:
	_replan -= delta
	if _replan <= 0.0 or agent.target_position.distance_to(p) > 1.0:
		agent.target_position = p
		_replan = 0.5
	if global_position.distance_to(p) < 0.5 or agent.is_navigation_finished():
		return true
	var next := agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0
	if dir.length() < 0.01:
		return true
	dir = dir.normalized()
	velocity = dir * speed + Vector3(0, -4.0 if not is_on_floor() else 0.0, 0)
	move_and_slide()
	_face(global_position + dir, delta)
	puppet.locomote(speed)
	return false

func _face(at: Vector3, delta: float) -> void:
	var d := at - global_position
	if Vector2(d.x, d.z).length() > 0.05:
		puppet.rotation.y = lerp_angle(puppet.rotation.y, atan2(d.x, d.z), 10.0 * delta)

## Sight: far in the light, close in the dark; a cone in front; nothing through walls.
func _sees(p: Node3D) -> bool:
	var eye := global_position + Vector3.UP * 1.6
	var to := p.global_position + Vector3.UP * 1.1 - eye
	var lit := World.light_at(p.global_position) > 0.3
	var range_m := 13.0 if lit else 4.0
	if to.length() > range_m:
		return false
	var fwd := Vector3(sin(puppet.rotation.y), 0, cos(puppet.rotation.y))
	if to.length() > 1.8 and fwd.dot(Vector3(to.x, 0, to.z).normalized()) < 0.3:
		return false
	return _clear(eye, eye + to)

func _sees_cheap(p: Node3D) -> bool:
	var eye := global_position + Vector3.UP * 1.6
	return _clear(eye, p.global_position + Vector3.UP * 1.1)

func _clear(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1 | 8)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _on_event(e: Dictionary) -> void:
	if state in [State.DEAD, State.HUNT, State.ATTACK]:
		return
	var pos: Vector3 = e.position
	var loud: float = e.get("loudness", 0.0)
	if state == State.SLEEP:
		loud *= 0.5
	if absf(pos.y - global_position.y) < 4.0 and pos.distance_to(global_position) < loud:
		_wake(pos)

func _wake(at: Vector3) -> void:
	if state == State.SLEEP:
		puppet.locomote(0.0)
	state = State.INVESTIGATE
	_target = at
	_t = 5.0

func hurt(amount: float, source: String, from: Vector3) -> void:
	if state == State.DEAD:
		return
	health -= amount
	if health <= 0.0:
		state = State.DEAD
		remove_from_group("hostile")
		collision_layer = 0
		puppet.hold("sleep")
		Events.notice.emit("It goes down and stays down.")
		return
	puppet.gesture("RecieveHit")
	state = State.STAGGER
	_t = 0.8 if source == "player" else 1.5
	_target = from
