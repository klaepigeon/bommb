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
signal died

const SPEED := {"patrol": 1.0, "investigate": 1.7, "chase": 3.0, "search": 1.3, "stunned": 1.6}
const SIGHT := 13.0
const FOV_COS := 0.45

var grid: AStarGrid2D
var cell := 1.4
var origin := Vector3.ZERO      # world position of cell (0,0)'s corner
var patrol: Array = []          # world points
var player: Player
var body: MartaSeated
var state := "patrol"
var awareness := 0.0            # 0..1: how sure she is she's seen him
var suspicion := 0.0            # rises each time she loses him: she searches longer, hears further
var active := true
## Places she won't go and can't see into (the maze's safe rooms): a Callable(point) -> bool.
var refuge: Callable

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
var _stuck := 0.0
## Melee doesn't hurt her the way it would hurt a person: it knocks her about. Each blow takes
## poise; small blows make her flinch, and when her poise is gone she reels (the same stun a
## bullet gives). It comes back quickly.
const POISE_MAX := 40.0
var poise := POISE_MAX
var _shove := Vector3.ZERO

func _ready() -> void:
	collision_layer = 8; collision_mask = 1
	var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.3; cap.height = 1.8
	cs.shape = cap; cs.position.y = 0.9; add_child(cs)
	body = MartaSeated.new(true, evolution); add_child(body)
	var breath := AudioStreamPlayer3D.new(); breath.stream = Sfx.streams.get("marta_rattle"); breath.volume_db = -6.0
	breath.unit_size = 2.0; breath.max_distance = 14.0; breath.bus = "World"; breath.autoplay = true; add_child(breath); breath.position.y = 1.6   # the same woman as at the table, on her feet
	body.snap = 18.0
	# the coral on her gives off a little sick light: you can see her coming, just
	var glow := OmniLight3D.new(); glow.light_color = Color("9adfb0"); glow.light_energy = 0.55; glow.omni_range = 2.6
	glow.shadow_enabled = false; glow.position = Vector3(0, 1.5, 0.25); add_child(glow)

## How far along she is (MartaSeated.stage); set before she's added, or use evolve().
var evolution := 1

## She's changed since he last saw her: a new body at the next stage, posed as the old one was.
func evolve(to: int) -> void:
	if to == evolution or not body: return
	evolution = to
	var old := body
	body = MartaSeated.new(true, to); body.snap = old.snap
	add_child(body)
	for k in old.pose: body.pose[k] = old.pose[k]
	old.queue_free()

func _enter_tree() -> void:
	# (she's moved between copies of the flat: reconnect each time she's put somewhere)
	if not Game.noise.is_connected(_on_noise): Game.noise.connect(_on_noise)

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
	if not grid.is_in_boundsv(a) or grid.is_point_solid(a): a = _nearest_free(a)     # she's up against furniture
	if not grid.is_in_boundsv(b) or grid.is_point_solid(b):
		b = _nearest_free(b)
	if not grid.is_in_boundsv(a) or not grid.is_in_boundsv(b):
		_path = PackedVector3Array(); _pi = 0; return     # somewhere not in her flat
	var ids := grid.get_id_path(a, b, true)
	_path = PackedVector3Array()
	for c in ids: _path.append(cell_center(c))
	if _path.size() > 0: _path[_path.size() - 1] = Vector3(p.x, 0, p.z) if grid.is_in_boundsv(to_cell(p)) and not grid.is_point_solid(to_cell(p)) else _path[_path.size() - 1]
	# the first point is the middle of the cell she's already in: don't walk back to it
	_pi = 1 if _path.size() > 1 else 0

func _nearest_free(c: Vector2i) -> Vector2i:
	var r0 := grid.region
	c = Vector2i(clampi(c.x, r0.position.x, r0.end.x - 1), clampi(c.y, r0.position.y, r0.end.y - 1))
	if not grid.is_point_solid(c): return c
	for r in range(1, 4):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if grid.is_in_boundsv(n) and not grid.is_point_solid(n): return n
	return c

func set_state(s: String) -> void:
	if s == state: return
	state = s; _state_t = 0.0
	state_changed.emit(s)

# ------------------------------------------------------------------ senses
func head() -> Vector3:
	return global_position + Vector3(0, 1.7, 0)

func in_refuge(p: Vector3) -> bool:
	return refuge.is_valid() and bool(refuge.call(p))

func can_see_player() -> bool:
	if not player: return false
	if in_refuge(player.global_position): return false
	var eye := head()
	var target := player.cam.global_position
	var d := target - eye
	var dist := d.length()
	var reach := SIGHT * (0.55 if player.crouching else 1.0)
	if player.torch_on: reach *= 1.6     # a torch in the dark is a lighthouse
	if dist > reach: return false
	var fwd := -global_transform.basis.z
	if dist > 1.6 and fwd.dot(Vector3(d.x, 0, d.z).normalized()) < FOV_COS: return false
	var q := PhysicsRayQueryParameters3D.create(eye, target, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _on_noise(pos: Vector3, loud: float) -> void:
	if not active or state in ["chase", "encounter", "caught", "stunned"]: return
	if in_refuge(pos): return
	var dist := pos.distance_to(global_position)
	var q := PhysicsRayQueryParameters3D.create(head(), pos + Vector3(0, 0.5, 0), 1, [get_rid()])
	var through_walls := not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	var reach := loud * (16.0 + suspicion * 6.0) * (0.6 if through_walls else 1.0)
	if dist <= reach:
		set_state("investigate")
		go_to(pos)
		_click(true)

## The pistol: she reels, and backs away from him for a few seconds.
func melee_hit(dmg: float, from: Vector3, knock: float, _by = null) -> void:
	if state == "caught" or state == "dead": return
	# Coup de Grace (the Infection tree): a heavy blow with an edge, while she's reeling, or from
	# behind while she hasn't seen him
	if _by is Hands and _by.heavy and Skills.has("s_reaper") and String(_by._prof.get("kind", "")) == "sharp":
		var to_him: Vector3 = (from - global_position) * Vector3(1, 0, 1)
		var behind: bool = to_him.normalized().dot(-global_basis.z) < -0.2
		if state == "stunned" or (behind and state in ["patrol", "investigate", "search"]):
			die(); return
	var away := (global_position - from) * Vector3(1, 0, 1)
	away = away.normalized() if away.length() > 0.01 else -global_basis.z
	_shove += away * knock
	Sfx.play_at("bone_crack", head(), -2.0, randf_range(0.8, 1.2))
	poise -= dmg
	suspicion = minf(2.0, suspicion + 0.1)
	if poise <= 0.0:
		poise = POISE_MAX
		set_state("stunned")
		Sfx.play_at("marta_scream", head(), 0.0, 1.2)
		body.pose.chest = Vector3(0.4, 0, randf_range(-0.4, 0.4)); body.pose.head = Vector3(-0.8, 0, 0.4)
		go_to(global_position + away * 3.0)
	else:
		# a flinch: the head snapped round, the chest knocked back
		body.pose.head = Vector3(randf_range(-0.6, -0.2), randf_range(-0.8, 0.8), randf_range(-0.6, 0.6))
		body.pose.chest = Vector3(0.25, 0, randf_range(-0.3, 0.3))
		if state in ["patrol", "investigate", "search", "encounter"]:
			_last_seen = player.global_position if player else from
			set_state("chase"); go_to(_last_seen)

## Down, for good (in this copy of the flat: what she is reforms ahead of him).
func die() -> void:
	set_state("dead")
	active = false
	collision_layer = 0
	velocity = Vector3.ZERO
	Sfx.play_at("marta_scream", head(), 2.0, 0.6)
	for i in 4: get_tree().create_timer(0.15 * i).timeout.connect(func(): Sfx.play_at("bone_crack", head(), 0.0, randf_range(0.6, 0.9)))
	body.snap = 6.0
	body.pose.spine = Vector3(-0.9, 0, 0.3); body.pose.neck = Vector3(-0.6, 0, 0.4); body.pose.head = Vector3(-0.5, 0.4, 0.9)
	body.pose.kn_l = Vector3(-1.6, 0, 0); body.pose.kn_r = Vector3(-1.4, 0, 0); body.pose.hip_l = Vector3(1.2, 0, 0.2); body.pose.hip_r = Vector3(1.0, 0, -0.2)
	body.pose.sh_l = Vector3(-0.6, 0, 0.9); body.pose.sh_r = Vector3(-0.5, 0, -0.9); body.pose.jaw = Vector3(1.4, 0, 0)
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(body, "position:y", -0.55, 1.1).set_delay(0.4)
	tw.parallel().tween_property(body, "rotation:x", -0.5, 1.1).set_delay(0.4)
	died.emit()

## Back (she's re-formed ahead of him, in the next copy).
func revive() -> void:
	if state != "dead": return
	collision_layer = 8
	body.position = Vector3.ZERO; body.rotation = Vector3.ZERO
	for k in body.pose: body.pose[k] = Vector3.ZERO
	poise = POISE_MAX
	active = true
	set_state("patrol")

func shot(point: Vector3, dir: Vector3) -> void:
	if state == "dead": return
	Sfx.play_at("bullet_flesh", point, 2.0)
	Sfx.play_at("click", head(), 4.0, 0.5)
	if state == "caught": return
	set_state("stunned")
	Sfx.play_at("marta_scream", head(), 0.0, 1.15)
	body.pose.chest = Vector3(0.4, 0, randf_range(-0.4, 0.4)); body.pose.head = Vector3(-0.8, 0, 0.4)
	var away := global_position + Vector3(dir.x, 0, dir.z).normalized() * 3.5
	go_to(away)
	suspicion = minf(2.0, suspicion + 0.4)

# ------------------------------------------------------------------ think and move
func _physics_process(delta: float) -> void:
	if not active or not player or not grid: return
	poise = minf(POISE_MAX, poise + 6.0 * delta)
	if _shove.length() > 0.05:
		move_and_collide(_shove * delta)
		_shove = _shove.lerp(Vector3.ZERO, 1.0 - exp(-7.0 * delta))
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
			if in_refuge(player.global_position):
				# he's got into somewhere she won't go: she stands off, then goes looking elsewhere
				set_state("search"); _last_seen = global_position; go_to(global_position)
			elif global_position.distance_to(player.global_position) < 1.15:
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
	var before := global_position
	move_and_slide()
	# caught on something the grid doesn't know (a chair someone moved): after a moment, give up
	# on this point and make for the next one
	if global_position.distance_to(before) < speed * delta * 0.2:
		_stuck += delta
		if _stuck > 0.5: _stuck = 0.0; _pi += 1
	else:
		_stuck = 0.0
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
	body.pose.sh_r = Vector3(0.7, 0, -0.1); body.pose.sh_l = Vector3(0.6, 0, 0.1)
	body.pose.el_r = Vector3.ZERO; body.pose.el_l = Vector3.ZERO; body.pose.jaw = Vector3(0.8, 0, 0)
	body.pose.spine = Vector3(-0.3, 0, 0); body.pose.head = Vector3(0.2, 0, 0)
	Sfx.play_at("marta_scream", head(), 6.0, 0.9)
	caught_player.emit()

func _click(loud: bool) -> void:
	_click_t = randf_range(1.5, 4.0) if state == "patrol" else randf_range(0.5, 1.4)
	for i in (3 if loud else randi_range(1, 3)):
		Sfx.play_at("click", head(), (2.0 if loud else -4.0), randf_range(0.6, 0.9))
		await get_tree().create_timer(randf_range(0.06, 0.14)).timeout

## The body: a broken, hurrying walk, the head lolling and snapping, arms hanging.
## Her body, by what she's doing. All procedural, on the chair model's joints (MartaSeated
## standing): a dragging, broken walk with the right leg stiff; a scuttle when she chases, bent
## double, arms clawing ahead; when she stops, a sniff and the head going round further than a
## neck goes; a cocked, listening crouch; the long slow tilt when she first sees him; the reel when
## she's shot; and through all of it the tics: stillness, then a snap, and the crack of it.
var _anim_t := 0.0
var _sniff_t := 2.0
var _swivel := 0.0
func _animate(delta: float) -> void:
	_anim_t += delta
	var t := _anim_t
	var moving := velocity.length() > 0.1
	var w := _walk
	var P: Dictionary = body.pose
	match state:
		"chase":
			body.snap = 22.0
			# a scuttle: short fast steps, body pitched forward, arms reaching and clawing in turn
			P.hip_l = Vector3(sin(w) * 0.7, 0, 0.12); P.hip_r = Vector3(-sin(w) * 0.55, 0, -0.1)
			P.kn_l = Vector3(-0.35 - maxf(0.0, -cos(w)) * 0.9, 0, 0); P.kn_r = Vector3(-0.35 - maxf(0.0, cos(w)) * 0.6, 0, 0)
			P.spine = Vector3(-0.45 - sin(w * 2.0) * 0.05, sin(w) * 0.12, sin(w) * 0.1)
			P.sh_l = Vector3(0.1 + maxf(0.0, sin(w * 1.3)) * 0.35, 0.2, 0.2); P.sh_r = Vector3(0.1 + maxf(0.0, -sin(w * 1.3)) * 0.35, -0.2, -0.2)
			P.el_l = Vector3(-0.2 - maxf(0.0, -sin(w * 1.3)) * 0.6, 0, 0); P.el_r = Vector3(-0.2 - maxf(0.0, sin(w * 1.3)) * 0.6, 0, 0)
			P.jaw = Vector3(0.55 + sin(t * 9.0) * 0.1, 0, 0)
			P.neck = Vector3(0.45, 0, sin(t * 3.0) * 0.15)      # the head held up, looking at him, as the body goes down
		"stunned":
			body.snap = 16.0
			P.spine = Vector3(0.3, sin(t * 7.0) * 0.3, sin(t * 5.0) * 0.35)
			P.sh_l = Vector3(-0.4 + sin(t * 11.0) * 0.6, 0, 0.8); P.sh_r = Vector3(-0.4 + cos(t * 9.0) * 0.6, 0, -0.8)
			P.el_l = Vector3(-0.8, 0, 0); P.el_r = Vector3(-0.9, 0, 0)
			P.head = Vector3(-0.7, sin(t * 6.0) * 0.4, 0.5); P.jaw = Vector3(0.8, 0, 0)
			P.hip_l = Vector3(sin(w) * 0.4, 0, 0.1); P.hip_r = Vector3(-sin(w) * 0.4, 0, -0.1)
			P.kn_l = Vector3(-maxf(0.0, -cos(w)) * 0.8, 0, 0); P.kn_r = Vector3(-maxf(0.0, cos(w)) * 0.8, 0, 0)
		"encounter":
			body.snap = 3.0
			# she stops dead; the head tilts over, slowly, too far; the teeth chatter
			P.hip_l = Vector3.ZERO; P.hip_r = Vector3.ZERO; P.kn_l = Vector3.ZERO; P.kn_r = Vector3.ZERO
			P.spine = Vector3(-0.1, 0, 0)
			P.head = Vector3(0.1, 0, clampf(_state_t * 0.5, 0.0, 1.35))
			P.neck = Vector3(0, 0, clampf(_state_t * 0.2, 0.0, 0.4))
			P.jaw = Vector3(0.25 + sin(t * 60.0) * 0.06, 0, 0)
			P.sh_l = Vector3(0.1, 0, 0.1); P.sh_r = Vector3(0.1, 0, -0.1)
		"caught":
			pass
		_:
			body.snap = 12.0
			if moving:
				# the walk: the left leg swings, the right drags stiff, the body rolls over it
				P.hip_l = Vector3(sin(w) * 0.45, 0, 0.06); P.hip_r = Vector3(-sin(w) * 0.2, 0, -0.04)
				P.kn_l = Vector3(-maxf(0.0, -cos(w)) * 0.9, 0, 0); P.kn_r = Vector3(-0.08, 0, 0)
				P.spine = Vector3(-0.2, sin(w) * 0.08, sin(w) * 0.16)
				P.sh_l = Vector3(0.35 - sin(w) * 0.15, 0, 0.12); P.sh_r = Vector3(0.25 + sin(w) * 0.1, 0, -0.08)
				P.el_l = Vector3(-0.2, 0, 0); P.el_r = Vector3(-0.35, 0, 0)
				if state == "investigate":
					P.spine = Vector3(-0.32, 0, 0.1)        # bent, listening
					P.head = Vector3(0.0, 0.0, 0.6)
			else:
				for k in ["hip_l", "hip_r", "kn_l", "kn_r"]: P[k] = Vector3.ZERO
				P.spine = Vector3(-0.15 - sin(t * TAU / 3.2) * 0.03, 0, 0)
				P.sh_l = Vector3(0.3, 0, 0.12); P.sh_r = Vector3(0.2, 0, -0.08)
				# standing: sniffing the air, then the head goes round, too far
				_sniff_t -= delta
				if _sniff_t <= 0.0:
					_sniff_t = randf_range(3.0, 6.0)
					Sfx.play_at("sniff", head(), -6.0, randf_range(0.8, 1.0))
					_swivel = randf_range(-1.6, 1.6)
				P.neck = Vector3(0.2 + sin(t * 9.0) * 0.04 * float(_sniff_t > 2.5), _swivel * 0.45, 0)
				P.head = Vector3(-0.15, _swivel * 0.6, _swivel * 0.15)
				_swivel = lerpf(_swivel, 0.0, 1.0 - exp(-0.25 * delta))
	# tics, any time she isn't reeling or holding still for him: still, then a snap, and a crack
	if state in ["patrol", "investigate", "search", "chase"]:
		_twitch_t -= delta
		if _twitch_t <= 0.0:
			_twitch_t = randf_range(0.8, 2.6) if state != "chase" else randf_range(0.3, 0.9)
			P.head = Vector3(randf_range(-0.3, 0.4), randf_range(-0.6, 0.6), randf_range(-0.8, 0.8))
			if state != "chase": P.jaw = Vector3(randf_range(0.0, 0.45), 0, 0)
			if randf() < 0.5: Sfx.play_at("bone_crack", head(), -10.0, randf_range(0.8, 1.3))
