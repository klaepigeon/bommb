class_name Monster
extends CharacterBody3D
## One of the people the town took. It keeps its habit and its one phrase. It hears (Noise) and
## sees; it goes to what it heard, comes for Kurt when it sees him, and takes hold of him when it
## reaches him. Shot, it flinches; enough and it dies (a headshot with Headshot kills outright).
## Talked to by someone who knows who it was, it stops, says one last thing, and sits down.

signal caught(m: Monster)
signal died(m: Monster)
signal calmed(m: Monster)

enum S { IDLE, LISTEN, CHASE, GRAB, HURT, CALM, DEAD, AWAY }

var id := ""
var data := {}               ## from content/town.json monsters
var player: Player
var state := S.IDLE
var home := Vector3.ZERO
var bounds := Rect2()        ## where it may go (x, z), in the town's space
var town: Town               ## its streets: it walks them cell to cell
var speed := 1.3
var chase_speed := 2.3
var hearing := 1.0
var sight := 13.0
var head_hp := 2
var body_hp := 4
var wanders: Array[Vector3] = []   ## patrol points, if any
var listen_time := 14.0
var listen_speed := 0.0            ## how fast it goes to a noise (0: its walking pace)            ## how long it keeps after a noise before going back
var body_radius := 0.3           ## its collision capsule
var body_height := 1.7
var talks := true                ## it has a phrase, and can be spoken to
var _shot_heard_t := -10.0
var body: Node3D
var head: Node3D
var arms: Array[Node3D] = []
var spot: Hotspot
var hit_head: Area3D
var _target := Vector3.ZERO
var _t := 0.0
var _state_t := 0.0
var _say_t := 4.0
var _wander_i := 0
var _rng := RandomNumberGenerator.new()
var _hits := 0

func setup(p_id: String, p_data: Dictionary, p_player: Player, at: Vector3, seed: int) -> void:
	id = p_id
	data = p_data
	player = p_player
	home = at
	_rng.seed = seed
	collision_layer = 0
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = body_radius; cap.height = body_height
	cs.shape = cap; cs.position.y = body_height * 0.5
	add_child(cs)
	body = Node3D.new(); add_child(body)
	build_body()
	var k := body_height / 1.7
	hit_head = _hitbox("head", head if head_follows_bone() else body, Vector3(0.28, 0.3, 0.28) * k, Vector3(0, 0.1, 0))
	_hitbox("body", body, Vector3(0.5, 1.3, 0.4) * k, Vector3(0, 0.75 * k, 0))
	spot = Hotspot.make(self, global_transform * Transform3D(Basis(), Vector3(0, 1.0, 0)), Vector3(0.9, 1.8, 0.9), "Talk")
	spot.used.connect(_talk_pressed)
	spot.enabled = talks
	Noises.heard.connect(_on_noise)
	global_position = at

## False when the head sits under a non-uniformly scaled bone (physics shapes can't take that):
## the head box then lives on the body and follows the head each frame.

func _hitbox(part: String, parent: Node3D, size: Vector3, at: Vector3) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = 4
	a.collision_mask = 0
	a.monitoring = false
	a.set_meta("monster", self)
	a.set_meta("part", part)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new(); bs.size = size
	cs.shape = bs
	a.add_child(cs)
	parent.add_child(a)
	a.position = at
	return a

# --- the body: one of the infected, from the generator (a different person for every seed) -----

var flesh: InfectedBody
var genome := {}

func build_body() -> void:
	genome = InfectedGenome.generate(_rng.seed)
	flesh = InfectedBody.new()
	flesh.name = "Flesh"
	body.add_child(flesh)
	flesh.build(genome)
	for mi in flesh.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head = Node3D.new()
	head.name = "Head"
	body.add_child(head)
	_follow_head()

## The head node rides the head bone (scenes look at it; the head's hit box goes with it).
func _follow_head() -> void:
	if flesh == null or flesh.skel == null:
		return
	var hb: Transform3D = flesh.skel.global_transform * flesh.skel.get_bone_global_pose(flesh.bones.head)
	head.global_position = hb.origin + Vector3(0, 0.08 * flesh.s, 0)

func head_follows_bone() -> bool:
	return false

func _part(parent: Node3D, m: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m; mi.material_override = mat; mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
func _box(s: Vector3) -> BoxMesh:
	var m := BoxMesh.new(); m.size = s; return m
func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new(); m.radius = r; m.height = r * 2.0; m.radial_segments = 8; m.rings = 5; return m

# --- knowing who they were --------------------------------------------------------------------

## Kurt knows who this was: the skill, and what he's read or noticed.
func known() -> bool:
	var needs: Dictionary = data.get("needs", {})
	if needs.has("skill") and not Game.owned(needs["skill"]):
		return false
	if needs.has("read") and not Game.flag("read_" + String(needs["read"])):
		return false
	if needs.has("flag") and not Game.flag(needs["flag"]):
		return false
	return true

func _talk_pressed() -> void:
	if state in [S.DEAD, S.CALM, S.AWAY]:
		return
	get_tree().call_group("director", "talk_to", self)

func calm() -> void:
	state = S.CALM
	spot.enabled = false
	velocity = Vector3.ZERO
	# down onto its knees, quiet: it keeps its habit, nothing else
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(body, "position:y", -0.35, 1.6)
	calmed.emit(self)

# --- senses and behaviour ---------------------------------------------------------------------

## Something it can hear: go and see.
func listen_to(pos: Vector3) -> void:
	state = S.LISTEN
	_target = _clamp(pos)
	_state_t = 0.0

func _on_noise(pos: Vector3, radius: float, _source: String) -> void:
	if state in [S.DEAD, S.CALM, S.GRAB, S.CHASE, S.AWAY] or not is_inside_tree():
		return
	if global_position.distance_to(pos) <= radius * hearing:
		# a shot, then where the bullet hit: it goes to the shot, not the wall beside it
		var now := Time.get_ticks_msec() / 1000.0
		if _source == "gunshot":
			_shot_heard_t = now
		elif now - _shot_heard_t < 0.5:
			return
		state = S.LISTEN
		_target = _clamp(pos)
		_state_t = 0.0

func can_see_player() -> bool:
	if player == null or not player.can_move:
		return false
	var eye := global_position + Vector3(0, 1.55, 0)
	var to := player.camera.global_position - eye
	var d := to.length()
	if d > maxf(sight, 2.5):
		return false
	var fwd := -global_transform.basis.z
	if d > 2.2 and fwd.dot(to.normalized()) < 0.2:
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, player.camera.global_position, 1, [player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _clamp(p: Vector3) -> Vector3:
	if bounds.size == Vector2.ZERO or town == null:
		return p
	var l := town.to_local(p)
	l = Vector3(clampf(l.x, bounds.position.x, bounds.end.x), l.y, clampf(l.z, bounds.position.y, bounds.end.y))
	return town.to_global(l)

func _physics_process(delta: float) -> void:
	_t += delta
	_state_t += delta
	if state in [S.DEAD, S.CALM]:
		_animate(delta, 0.0)
		return
	var move_to := Vector3.INF
	var spd := speed
	match state:
		S.IDLE:
			if wanders.size() > 0:
				move_to = wanders[_wander_i]
				if _flat(global_position).distance_to(_flat(move_to)) < 0.5:
					_wander_i = (_wander_i + 1) % wanders.size()
			elif _flat(global_position).distance_to(_flat(home)) > 0.6:
				move_to = home
			if can_see_player():
				_start_chase()
		S.LISTEN:
			move_to = _target
			spd = listen_speed if listen_speed > 0.0 else speed
			if _flat(global_position).distance_to(_flat(_target)) < 0.8 and _state_t > 2.0 or _state_t > listen_time:
				state = S.IDLE
			if can_see_player():
				_start_chase()
		S.CHASE:
			move_to = _clamp(player.global_position)
			spd = chase_speed
			if can_see_player():
				_state_t = 0.0
			elif _state_t > 6.0:
				state = S.IDLE
			if _flat(global_position).distance_to(_flat(player.global_position)) < 1.05 and player.can_move:
				state = S.GRAB
				caught.emit(self)
		S.HURT:
			if _state_t > 0.6:
				_start_chase()
		S.AWAY:
			if _state_t > 25.0:
				state = S.IDLE
			move_to = home
			spd = speed * 0.6
	_move(move_to, spd, delta)
	# the phrase, now and then, when he's near enough to hear it
	_say_t -= delta
	if _say_t <= 0.0 and player and global_position.distance_to(player.global_position) < 8.0 and Speech.speaking == "":
		_say_t = _rng.randf_range(7.0, 12.0)
		Speech.say(id, String(data.get("says", "...")), "quiet")
	spot.enabled = state in [S.IDLE, S.LISTEN, S.CHASE]
	spot.prompt = "Talk" if known() else "Talk (?)"

func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)

func _start_chase() -> void:
	state = S.CHASE
	_state_t = 0.0

func _move(to: Vector3, spd: float, delta: float) -> void:
	var v := Vector3.ZERO
	if to != Vector3.INF and town:
		to = town.to_global(town.next_step(town.to_local(global_position), town.to_local(to)))
	if to != Vector3.INF:
		var d := _flat(to) - _flat(global_position)
		if d.length() > 0.3:
			v = d.normalized() * spd
			var want := atan2(-d.x, -d.z)
			rotation.y = lerp_angle(rotation.y, want, minf(delta * 5.0, 1.0))
	velocity.x = v.x
	velocity.z = v.z
	velocity.y = -1.0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	_animate(delta, Vector2(velocity.x, velocity.z).length())

func _animate(delta: float, spd: float) -> void:
	if flesh == null:
		return
	var mode := "idle"
	if spd > 0.05:
		mode = "move"
	if state == S.GRAB:
		mode = "attack"
	elif state == S.DEAD:
		mode = "dead"
	var look = null
	if player and state in [S.CHASE, S.GRAB, S.LISTEN, S.CALM]:
		look = flesh.skel.global_transform.affine_inverse() * (player.camera.global_position if state != S.LISTEN else _target + Vector3(0, 1.5, 0))
	flesh.animate(delta, {"speed": spd, "mode": mode, "attack": 1.0 if state == S.GRAB else 0.0, "look": look})
	_follow_head()
	if hit_head:
		hit_head.global_position = head.global_position + Vector3(0, 0.02, 0)

# --- shot ---------------------------------------------------------------------------------------

func shot(part: String) -> void:
	if state in [S.DEAD]:
		return
	_hits += 1
	if part == "head":
		head_hp -= 1
		if Game.owned("headshot"):
			head_hp = 0
	else:
		body_hp -= 1
	if head_hp <= 0 or body_hp <= 0:
		die()
		return
	var was_calm := state == S.CALM
	state = S.HURT
	_state_t = 0.0
	if was_calm:
		spot.enabled = false
	if flesh:
		flesh.flinch((global_position - player.global_position).normalized(), 1.0)

func die() -> void:
	state = S.DEAD
	spot.enabled = false
	collision_mask = 0
	for a in find_children("*", "Area3D", true, false):
		(a as Area3D).collision_layer = 0
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(body, "rotation:x", PI * 0.5, 0.6)
	tw.parallel().tween_property(body, "position:y", 0.15, 0.6)
	Sfx.play_at("thud", global_position, -2.0)
	died.emit(self)

## Back where it started, as if nothing happened (after it's had hold of him).
func reset_to_home() -> void:
	if state in [S.DEAD, S.CALM]:
		return
	state = S.IDLE
	global_position = home
	_wander_i = 0
