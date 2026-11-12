class_name MartaHunter
extends CharacterBody3D
## Marta in the flesh flat, hunting. A small state machine over a grid path-finder:
##   patrol       walk a loop of points, stopping to stand still and click
##   investigate  a noise: go to where it was, look round, give up after a while
##   chase        she can see him: straight at him, fast
##   search       lost him: go to where he was last seen, then cast about nearby
##   stunned      shot: she reels back and away, then comes on harder (more suspicious)
##   encounter    the first time they see each other: she stops and clicks at him (scripted)
##   caught       she has him
## She sees in a cone, worse in the dark of a crouch; she hears every noise Game.noise reports,
## less through walls. She can't be killed: bullets hurt her and buy time, not safety.

signal caught_player
signal spotted_player
signal state_changed(s: String)

const SPEED := {"patrol": 1.0, "investigate": 1.7, "chase": 3.0, "search": 1.3, "stunned": 1.6}
const SIGHT := 13.0
const FOV_COS := 0.45

var grid: AStarGrid2D
var cell := 1.4
var origin := Vector3.ZERO      # world position of cell (0,0)'s corner
var patrol: Array = []          # world points
var player: Player
var body: MartaBody
var state := "patrol"
var awareness := 0.0            # 0..1: how sure she is she's seen him
var suspicion := 0.0            # rises each time she loses him: she searches longer, hears further
var active := true

var _path: PackedVector3Array = []
var _pi := 0
var _patrol_i := 0
var _wait := 0.0
var _goal := Vector3.ZERO
var _last_seen := Vector3.ZERO
var _state_t := 0.0
var _click_t := 1.0
var _walk := 0.0
var _twitch_t := 0.0

func _ready() -> void:
	collision_layer = 8; collision_mask = 1
	var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.3; cap.height = 1.8
	cs.shape = cap; cs.position.y = 0.9; add_child(cs)
	body = MartaBody.new("hunter"); add_child(body)
	body.snap = 18.0
	# the coral on her gives off a little sick light: you can see her coming, just
	var glow := OmniLight3D.new(); glow.light_color = Color("9adfb0"); glow.light_energy = 0.55; glow.omni_range = 2.6
	glow.shadow_enabled = false; glow.position = Vector3(0, 1.5, 0.25); add_child(glow)
	Game.noise.connect(_on_noise)

func _exit_tree() -> void:
	if Game.noise.is_connected(_on_noise): Game.noise.disconnect(_on_noise)

# ------------------------------------------------------------------ grid
func to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / cell), floori((p.z - origin.z) / cell))

func cell_center(c: Vector2i) -> Vector3:
	return origin + Vector3((c.x + 0.5) * cell, 0, (c.y + 0.5) * cell)

func go_to(p: Vector3) -> void:
	_goal = p
	var a := to_cell(global_position); var b := to_cell(p)
	if not grid.is_in_boundsv(b) or grid.is_point_solid(b):
		b = _nearest_free(b)
	var ids := grid.get_id_path(a, b, true)
	_path = PackedVector3Array()
	for c in ids: _path.append(cell_center(c))
	if _path.size() > 0: _path[_path.size() - 1] = Vector3(p.x, 0, p.z) if not grid.is_point_solid(to_cell(p)) else _path[_path.size() - 1]
	# the first point is the middle of the cell she's already in: don't walk back to it
	_pi = 1 if _path.size() > 1 else 0

func _nearest_free(c: Vector2i) -> Vector2i:
	for r in range(1, 4):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if grid.is_in_boundsv(n) and not grid.is_point_solid(n): return n
	return to_cell(global_position)

func set_state(s: String) -> void:
	if s == state: return
	state = s; _state_t = 0.0
	state_changed.emit(s)

# ------------------------------------------------------------------ senses
func head() -> Vector3:
	return global_position + Vector3(0, 1.7, 0)

func can_see_player() -> bool:
	if not player: return false
	var eye := head()
	var target := player.cam.global_position
	var d := target - eye
	var dist := d.length()
	var reach := SIGHT * (0.55 if player.crouching else 1.0)
	if dist > reach: return false
	var fwd := -global_transform.basis.z
	if dist > 1.6 and fwd.dot(Vector3(d.x, 0, d.z).normalized()) < FOV_COS: return false
	var q := PhysicsRayQueryParameters3D.create(eye, target, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _on_noise(pos: Vector3, loud: float) -> void:
	if not active or state in ["chase", "encounter", "caught", "stunned"]: return
	var dist := pos.distance_to(global_position)
	var q := PhysicsRayQueryParameters3D.create(head(), pos + Vector3(0, 0.5, 0), 1, [get_rid()])
	var through_walls := not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	var reach := loud * (16.0 + suspicion * 6.0) * (0.6 if through_walls else 1.0)
	if dist <= reach:
		set_state("investigate")
		go_to(pos)
		_click(true)

## The pistol: she reels, and backs away from him for a few seconds.
func shot(point: Vector3, dir: Vector3) -> void:
	Sfx.play_at("bullet_flesh", point, 2.0)
	Sfx.play_at("click", head(), 4.0, 0.5)
	if state == "caught": return
	set_state("stunned")
	body.pose.chest = Vector3(-0.5, 0, randf_range(-0.4, 0.4)); body.pose.head = Vector3(-0.8, 0, 0.4)
	var away := global_position + Vector3(dir.x, 0, dir.z).normalized() * 3.5
	go_to(away)
	suspicion = minf(2.0, suspicion + 0.4)

# ------------------------------------------------------------------ think and move
func _physics_process(delta: float) -> void:
	if not active or not player or not grid: return
	_state_t += delta
	var sees := can_see_player()
	match state:
		"patrol", "investigate", "search":
			if sees:
				awareness += delta * (3.0 if global_position.distance_to(player.global_position) < 4.0 else 1.3) * (0.5 if player.crouching else 1.0)
				_face(player.global_position, delta * 4.0)
				if awareness >= 1.0:
					spotted_player.emit()
					if state != "encounter": set_state("chase")
			else:
				awareness = maxf(0.0, awareness - delta * 0.3)
	match state:
		"patrol":
			if _wait > 0.0:
				_wait -= delta; _stand(delta)
			elif _follow(delta, SPEED.patrol):
				_wait = randf_range(1.5, 4.0)
				_patrol_i = (_patrol_i + 1) % patrol.size()
				go_to(patrol[_patrol_i])
		"investigate":
			if _follow(delta, SPEED.investigate):
				_stand(delta); _look_round(delta)
				if _state_t > 6.0 + suspicion * 2.0: _resume_patrol()
		"chase":
			if sees:
				_last_seen = player.global_position
				if _state_t > 0.2 or _path.is_empty():
					go_to(_last_seen); _state_t = 0.0
			elif _state_t > 0.6:
				set_state("search"); go_to(_last_seen); suspicion = minf(2.0, suspicion + 0.25)
			_follow(delta, SPEED.chase)
			if global_position.distance_to(player.global_position) < 1.15:
				_catch()
		"search":
			if _follow(delta, SPEED.search):
				_look_round(delta)
				if _state_t > 3.0:
					_state_t = 0.0
					var c := to_cell(_last_seen) + Vector2i(randi_range(-3, 3), randi_range(-3, 3))
					if grid.is_in_boundsv(c) and not grid.is_point_solid(c): go_to(cell_center(c))
			if _state_t > 0.0 and get_meta("search_total", 0.0) > 14.0 + suspicion * 5.0:
				set_meta("search_total", 0.0); _resume_patrol()
			set_meta("search_total", get_meta("search_total", 0.0) + delta)
		"stunned":
			_follow(delta, SPEED.stunned)
			if _state_t > 3.2:
				body.pose.chest = Vector3.ZERO; body.pose.head = Vector3.ZERO
				set_state("chase" if sees else "search"); _last_seen = player.global_position; go_to(_last_seen)
		"encounter":
			_stand(delta)
			_face(player.global_position, delta * 3.0)
		"caught":
			pass
	_animate(delta)
	_click_t -= delta
	if _click_t <= 0.0: _click(false)

func _resume_patrol() -> void:
	set_state("patrol"); awareness = 0.0
	var best := 0; var bd := INF
	for i in patrol.size():
		var d: float = (patrol[i] as Vector3).distance_to(global_position)
		if d < bd: bd = d; best = i
	_patrol_i = best; go_to(patrol[best])

## Walk the path; true once she's at the end of it.
func _follow(delta: float, speed: float) -> bool:
	if _pi >= _path.size():
		velocity = Vector3.ZERO
		return true
	var p := _path[_pi]
	var d := Vector3(p.x - global_position.x, 0, p.z - global_position.z)
	if d.length() < 0.25:
		_pi += 1
		return _pi >= _path.size()
	# she lurches: speed comes in surges
	var surge := 0.75 + 0.5 * absf(sin(_walk * 0.5))
	velocity = d.normalized() * speed * surge
	velocity.y = -2.0
	move_and_slide()
	_face(global_position + d, delta * 6.0)
	_walk += delta * speed * 4.0
	return false

func _stand(_delta: float) -> void:
	velocity = Vector3.ZERO

func _face(p: Vector3, k: float) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() < 0.01: return
	var want := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, want, clampf(k, 0.0, 1.0))

func _look_round(delta: float) -> void:
	rotation.y += sin(_state_t * 1.3) * delta * 1.2

func _catch() -> void:
	set_state("caught")
	velocity = Vector3.ZERO
	body.snap = 40.0
	body.pose.sh_r = Vector3(PI * 0.5 + 0.4, 0, -0.1); body.pose.sh_l = Vector3(PI * 0.5 + 0.3, 0, 0.1)
	body.pose.el_r = Vector3.ZERO; body.pose.el_l = Vector3.ZERO; body.pose.jaw = Vector3(0.7, 0, 0)
	caught_player.emit()

func _click(loud: bool) -> void:
	_click_t = randf_range(1.5, 4.0) if state == "patrol" else randf_range(0.5, 1.4)
	for i in (3 if loud else randi_range(1, 3)):
		Sfx.play_at("click", head(), (2.0 if loud else -4.0), randf_range(0.6, 0.9))
		await get_tree().create_timer(randf_range(0.06, 0.14)).timeout

## The body: a broken, hurrying walk, the head lolling and snapping, arms hanging.
func _animate(delta: float) -> void:
	var moving := velocity.length() > 0.1
	var w := _walk
	var stride := 0.55 if state == "chase" else 0.35
	if moving:
		body.pose.hip_l = Vector3(sin(w) * stride, 0, 0.05); body.pose.hip_r = Vector3(-sin(w) * stride, 0, -0.05)
		body.pose.kn_l = Vector3(-maxf(0.0, -cos(w)) * 0.8, 0, 0); body.pose.kn_r = Vector3(-maxf(0.0, cos(w)) * 0.8, 0, 0)
		body.pose.sh_l = Vector3(-sin(w) * 0.3 + (0.9 if state == "chase" else 0.1), 0, 0.15); body.pose.sh_r = Vector3(sin(w) * 0.3 + (0.9 if state == "chase" else 0.1), 0, -0.1)
	else:
		for k in ["hip_l", "hip_r", "kn_l", "kn_r"]: body.pose[k] = Vector3.ZERO
		body.pose.sh_l = Vector3(0.05, 0, 0.12); body.pose.sh_r = Vector3(0.0, 0, -0.08)
	if state != "stunned" and state != "caught":
		body.pose.spine = Vector3(0.35 if state == "chase" else 0.2, 0, 0)
		_twitch_t -= delta
		if _twitch_t <= 0.0:
			# the head: still, still, then a snap to a new angle
			_twitch_t = randf_range(0.3, 2.2) if state != "chase" else randf_range(0.15, 0.6)
			body.pose.head = Vector3(randf_range(-0.3, 0.4), randf_range(-0.5, 0.5), randf_range(-0.6, 0.6))
			body.pose.neck = Vector3(randf_range(-0.2, 0.3), 0, randf_range(-0.3, 0.3))
			body.pose.jaw = Vector3(randf_range(0.0, 0.5), 0, 0)
