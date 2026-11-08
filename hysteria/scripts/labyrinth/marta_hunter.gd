class_name MartaHunter
extends Node3D
## Marta in the labyrinth. Still seated, in a chair that isn't there, a little off the ground:
## the woman from the table upstairs, coral and all, drifting through the streets of a town that
## was hers a long time ago. She hunts by sound.
##
##   DRIFT   wandering the streets cell to cell, slowly
##   LISTEN  she heard something: she goes to where it was
##   SEARCH  there, turning, for a while; then back to drifting
##   CHASE   she can see him: she comes, straight, faster than he walks
##   HOLD    within reach: she takes hold of him, close to her face ("Have you seen them?"), and
##           it goes black; he comes to by the hole in the lane, and she's gone off somewhere
##   DEAD    shot down: she falls out of the air and stays down (for good)
##
## Hearing and sight scale with Skills.aggression(): Survival makes her keener, Memory softer.
## Footsteps carry by how he moves (running far, crouching hardly at all; Quiet Feet less);
## a gunshot carries across the whole town; his torch lets her see him from further.

signal seen_kurt
signal held_kurt
signal died
signal hurt(head: bool)

enum S { DRIFT, LISTEN, SEARCH, CHASE, HOLD, DEAD }

const HOVER := 0.42                 # her seat's this far above where a chair's would be
const DRIFT_SPEED := 0.85
const LISTEN_SPEED := 1.35
const CHASE_SPEED := 1.95
const REACH := 1.25
const MAX_HP := 8

var lab: Labyrinth
var player: Node
var marta: Marta
var state := S.DRIFT
var hp := MAX_HP
var awake := false                  # she isn't in the labyrinth until he has the revolver
var _path: Array = []               # cells to go through
var _goal := Vector3.ZERO
var _t := 0.0
var _state_t := 0.0
var _heard_at := Vector3.ZERO
var _yaw := 0.0
var _body: StaticBody3D
var _head_shape: CollisionShape3D
var _stagger := 0.0
var _fall := 0.0
var _whisper_t := 6.0

func setup(p_lab: Labyrinth, p_player: Node) -> void:
	lab = p_lab; player = p_player
	add_to_group("listener")

func _ready() -> void:
	marta = Marta.new(); marta.name = "Marta"; add_child(marta)
	# the chair, the puddle, the roots stay at the table upstairs: here she's only herself
	for c in marta.get_children():
		if c is MeshInstance3D: (c as MeshInstance3D).visible = false
	marta.position = Vector3(0, HOVER, 0)
	visible = false
	# a cold, sickly light that goes with her: it shows the coral and what's left of her face, and
	# you see it coming round a corner before you see her
	var aura := OmniLight3D.new(); aura.name = "Aura"
	aura.light_color = Color(0.62, 0.85, 0.75); aura.light_energy = 1.1; aura.omni_range = 3.2; aura.omni_attenuation = 1.6
	aura.shadow_enabled = false; aura.position = Vector3(0, HOVER + 1.0, -0.6)
	add_child(aura)
	# something to shoot: her body, and her head (which moves with her head)
	_body = StaticBody3D.new(); _body.name = "Hit"
	add_child(_body)
	var bs := CollisionShape3D.new(); var bb := BoxShape3D.new(); bb.size = Vector3(0.5, 0.75, 0.45)
	bs.shape = bb; bs.position = Vector3(0, HOVER + 0.75, -0.02); _body.add_child(bs)
	_head_shape = CollisionShape3D.new(); var hs := SphereShape3D.new(); hs.radius = 0.15
	_head_shape.shape = hs; _body.add_child(_head_shape)
	_body.process_mode = Node.PROCESS_MODE_DISABLED

## She comes into the town: at the far side of the square, coming up the lane from the plaza.
func wake(at_cell := Vector2i(10, 12)) -> void:
	awake = true; visible = true
	_body.process_mode = Node.PROCESS_MODE_INHERIT
	position = lab.center(at_cell.x, at_cell.y)
	_enter(S.LISTEN)
	_heard_at = lab.to_local(player.global_position)
	_route_to(_heard_at)

func _enter(s: S) -> void:
	state = s; _state_t = 0.0

# ---------------------------------------------------------------- senses
## Noises.make: everything heard in the town
func hear(pos: Vector3, loud: float, what: String, source: Node) -> void:
	if not awake or state in [S.DEAD, S.HOLD, S.CHASE]: return
	var here := lab.to_local(pos)
	var radius := loud * 40.0 * Skills.aggression()
	if what == "gunshot": radius = 60.0
	if here.distance_to(position) < radius:
		_heard_at = here
		_enter(S.LISTEN)
		_route_to(here)

func _sees_kurt() -> bool:
	var eye := lab.to_global(position + Vector3(0, HOVER + 1.2, 0))
	var him: Vector3 = player.cam.global_position
	var d := eye.distance_to(him)
	var torch_on := false
	var th = player.get("torch_holder")
	if th: torch_on = bool(th.get("torch_on"))
	else: torch_on = bool(player.torch.visible)
	var range_m := (17.0 if torch_on else 9.0) * Skills.aggression()
	if player.get("crouched"): range_m *= 0.6
	if d > range_m: return false
	# she looks where her head is turned, broadly; she doesn't need eyes to see you close up
	var fwd := lab.global_transform.basis * Basis(Vector3.UP, _yaw) * Vector3(0, 0, -1)
	if d > 3.0 and fwd.dot((him - eye).normalized()) < 0.15: return false
	var q := PhysicsRayQueryParameters3D.create(eye, him)
	q.exclude = [_body.get_rid(), player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## his footsteps, every frame he makes them
func _footsteps() -> void:
	var n: float = player.get("noise")
	if n <= 0.0: return
	if Skills.owned("quiet_feet"): n *= 0.6
	var d := lab.to_local(player.global_position).distance_to(position)
	if d < n * 16.0 * Skills.aggression() and state in [S.DRIFT, S.SEARCH]:
		_heard_at = lab.to_local(player.global_position)
		_enter(S.LISTEN); _route_to(_heard_at)

# ---------------------------------------------------------------- moving through the town
func _cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / Labyrinth.CELL), floori(p.z / Labyrinth.CELL))

## breadth-first over street cells; the route is the centres of the cells in between
func _route_to(target: Vector3) -> void:
	var from := _cell_of(position); var to := _cell_of(target)
	var prev := {from: from}
	var q := [from]
	while q.size() > 0:
		var c: Vector2i = q.pop_front()
		if c == to: break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nc: Vector2i = c + d
			if prev.has(nc) or nc.x < 0 or nc.x > 15 or not lab.is_street(nc.x, nc.y): continue
			prev[nc] = c; q.append(nc)
	_path.clear()
	if not prev.has(to): return
	var c2 := to
	while c2 != from:
		_path.push_front(lab.center(c2.x, c2.y)); c2 = prev[c2]
	_path.append(Vector3(target.x, 0, target.z))

func _wander() -> void:
	for i in 20:
		var c := Vector2i(randi_range(1, 14), randi_range(2, 16))
		if lab.is_street(c.x, c.y):
			_route_to(lab.center(c.x, c.y)); return

func _move(speed: float, delta: float) -> bool:
	if _path.is_empty(): return true
	var tgt: Vector3 = _path[0]
	var to := tgt - position; to.y = 0.0
	if to.length() < 0.25:
		_path.pop_front(); return _path.is_empty()
	var step := to.normalized() * minf(speed * delta, to.length())
	position += step
	_yaw = lerp_angle(_yaw, atan2(-step.x, -step.z), 1.0 - exp(-delta * 4.0))
	return false

# ---------------------------------------------------------------- the frame
func _process(delta: float) -> void:
	if not awake or not lab.visible: return
	_t += delta; _state_t += delta
	var agg := Skills.aggression()
	var kurt_local := lab.to_local(player.global_position)
	var near := kurt_local.distance_to(position)
	match state:
		S.DRIFT:
			if _move(DRIFT_SPEED, delta) or _path.is_empty(): _wander()
			_footsteps()
			if _sees_kurt(): _enter(S.CHASE); seen_kurt.emit()
		S.LISTEN:
			if _move(LISTEN_SPEED * agg, delta): _enter(S.SEARCH)
			_footsteps()
			if _sees_kurt(): _enter(S.CHASE); seen_kurt.emit()
		S.SEARCH:
			_yaw += delta * 1.2 * sin(_state_t * 0.8)
			_footsteps()
			if _sees_kurt(): _enter(S.CHASE); seen_kurt.emit()
			elif _state_t > 6.0 / agg: _enter(S.DRIFT); _wander()
		S.CHASE:
			if _stagger > 0.0:
				_stagger -= delta
			elif _sees_kurt():
				_path = [Vector3(kurt_local.x, 0, kurt_local.z)]
				_move(CHASE_SPEED * agg, delta)
				_heard_at = kurt_local
			else:
				# lost sight: go to where he was last
				if _path.is_empty() or _state_t > 1.0: _route_to(_heard_at); _state_t = 0.0
				if _move(CHASE_SPEED * agg * 0.9, delta): _enter(S.SEARCH)
			if near < REACH and not player.get("locked"): _hold()
		S.HOLD:
			pass
		S.DEAD:
			_fall = minf(1.0, _fall + delta * 1.4)
			marta.position.y = lerpf(HOVER, -0.05, _fall * _fall)
			marta.rotation.z = _fall * 1.2; marta.rotation.x = -_fall * 0.4
			return
	# the main street wraps for her too
	position = lab.wrap(position)
	# floating: a slow bob; leaning a little into her movement; her head on him once she knows
	marta.position.y = HOVER + sin(_t * 1.1) * 0.05
	rotation.y = _yaw
	if state in [S.CHASE, S.HOLD] or (state == S.LISTEN and near < 10.0):
		marta.face(player.cam.global_position, Marta.JAW_OPEN if state == S.CHASE else 0.2)
	else:
		marta.joints.head.rotation = marta.joints.head.rotation.lerp(Vector3(-0.35, sin(_t * 0.3) * 0.6, 0.1), 1.0 - exp(-delta * 2.0))
	_head_shape.global_position = (marta.joints.head as Node3D).global_position + Vector3(0, 0.06, 0)
	# close by, sometimes, she asks
	_whisper_t -= delta
	if _whisper_t <= 0.0 and near < 9.0 and state != S.DEAD:
		_whisper_t = randf_range(9.0, 16.0)
		Game.say(["“…the boxes…”", "“Have you seen…”", "“Sonya, shoes.”"][randi() % 3], 2.5)

func _hold() -> void:
	_enter(S.HOLD)
	held_kurt.emit()
	player.set("locked", true)
	player.set("look_target", lab.to_global(position + Vector3(0, HOVER + 1.15, 0)))
	player.set("shake", 1.0)
	Game.speak("Have you seen them?", 3.0, 0.75, 0.7)
	await get_tree().create_timer(1.2).timeout
	Game.fade.emit(1.0, 0.6)
	await get_tree().create_timer(1.6).timeout
	# he comes to by the hole, and she's somewhere else
	player.global_transform = lab.global_transform * lab.arrive
	player.set("yaw", player.global_transform.basis.get_euler().y)
	player.set("look_target", null)
	position = lab.center(12, 15)
	_path.clear(); _enter(S.DRIFT)
	await get_tree().create_timer(0.6).timeout
	player.set("locked", false)
	Game.fade.emit(0.0, 1.4)

## a shot from the revolver: true if it hit her
func shot(point: Vector3, _normal: Vector3, headshot_kills: bool, shape: int) -> bool:
	if state == S.DEAD: return false
	var head := shape == 1 or point.distance_to(_head_shape.global_position) < 0.2
	hp -= 3 if head else 1
	hurt.emit(head)
	_stagger = 0.5 if not head else 0.9
	marta.position.y += 0.06
	if head and headshot_kills: hp = 0
	if state != S.CHASE: _enter(S.CHASE); _heard_at = lab.to_local(player.global_position)
	if hp <= 0: _die()
	return true

func _die() -> void:
	_enter(S.DEAD)
	Game.flags["marta_dead"] = true
	_body.process_mode = Node.PROCESS_MODE_DISABLED
	died.emit()
