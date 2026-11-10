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
var bounds := Rect2()        ## where it may go (x, z) in world space
var speed := 1.3
var chase_speed := 2.3
var hearing := 1.0
var sight := 13.0
var head_hp := 2
var body_hp := 4
var wanders: Array[Vector3] = []   ## patrol points, if any
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
	var cap := CapsuleShape3D.new(); cap.radius = 0.3; cap.height = 1.7
	cs.shape = cap; cs.position.y = 0.85
	add_child(cs)
	body = Node3D.new(); add_child(body)
	build_body()
	hit_head = _hitbox("head", head if head_follows_bone() else body, Vector3(0.28, 0.3, 0.28), Vector3(0, 0.1, 0))
	_hitbox("body", body, Vector3(0.5, 1.3, 0.4), Vector3(0, 0.75, 0))
	spot = Hotspot.make(self, global_transform * Transform3D(Basis(), Vector3(0, 1.0, 0)), Vector3(0.9, 1.8, 0.9), "Talk")
	spot.used.connect(_talk_pressed)
	Noises.heard.connect(_on_noise)
	global_position = at

## False when the head sits under a non-uniformly scaled bone (physics shapes can't take that):
## the head box then lives on the body and follows the head each frame.
func head_follows_bone() -> bool:
	return true

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

# --- the body: one of the infected, from primitives, different per seed -----------------------

func build_body() -> void:
	var skin := Look.mat(Look.get_tex("skin"), Color.WHITE.lerp(Color("c8b8a0"), _rng.randf()))
	var cloth := Look.mat(Look.get_tex("cloth"), [Color("3a3328"), Color("2c3440"), Color("4a3a30"), Color("2a2a2a")][_rng.randi() % 4])
	var growth_kind := _rng.randi() % 3
	var growth := Look.mat(Look.get_tex("coral"), [Color.WHITE, Color("9a8a60"), Color("e8e0d0")][growth_kind])
	var dark := Look.mat(Look.get_tex("white"), Color("060505"))
	var h := _rng.randf_range(0.92, 1.08)
	body.scale = Vector3(h, h, h)
	for s in [-1.0, 1.0]:
		var leg := Node3D.new(); leg.position = Vector3(0.1 * s, 0.85, 0); body.add_child(leg)
		_part(leg, _box(Vector3(0.14, 0.85, 0.15)), cloth, Vector3(0, -0.42, 0))
		_part(leg, _box(Vector3(0.11, 0.07, 0.24)), dark, Vector3(0, -0.84, -0.05))
		arms.append(leg)    # legs swing with the gait; kept with the arms for simplicity
	var torso := Node3D.new(); torso.name = "Torso"; torso.position = Vector3(0, 0.85, 0); body.add_child(torso)
	torso.rotation.x = -_rng.randf_range(0.05, 0.35)   # hunched
	_part(torso, _box(Vector3(0.42, 0.62, 0.24)), cloth, Vector3(0, 0.31, 0))
	head = Node3D.new(); head.position = Vector3(0, 0.72, -0.02); torso.add_child(head)
	_part(head, _sphere(0.12), skin, Vector3(0, 0.1, 0)).scale = Vector3(0.9, 1.1, 1)
	_part(head, _box(Vector3(0.13, 0.025, 0.02)), dark, Vector3(0, 0.05, -0.11))
	for s in [-1.0, 1.0]:
		_part(head, _sphere(0.022), dark, Vector3(0.04 * s, 0.13, -0.1))
	var missing := _rng.randi() % 4 == 0
	for s in [-1.0, 1.0]:
		if missing and s < 0:
			continue
		var arm := Node3D.new(); arm.position = Vector3(0.25 * s, 0.56, 0); torso.add_child(arm)
		_part(arm, _box(Vector3(0.1, 0.62, 0.1)), cloth, Vector3(0, -0.28, 0))
		_part(arm, _box(Vector3(0.08, 0.12, 0.05)), skin, Vector3(0, -0.64, 0))
		arms.append(arm)
	if _rng.randi() % 3 == 0:
		var extra := Node3D.new(); extra.position = Vector3(0.1, 0.45, 0.12); extra.rotation = Vector3(0.9, 0, -0.6); torso.add_child(extra)
		_part(extra, _box(Vector3(0.07, 0.5, 0.07)), skin, Vector3(0, -0.25, 0))
	# growth over the back and shoulders, where Marta's came out
	for i in 9:
		var p := Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(0.2, 0.75), _rng.randf_range(0.08, 0.18))
		var g := _part(torso, _sphere(_rng.randf_range(0.04, 0.09)), growth, p)
		g.scale = Vector3(1, [1.0, 0.35, 1.8][growth_kind], 1)

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
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(body, "position:y", -0.45, 1.6)
	tw.tween_property(head, "rotation:x", 0.7, 1.6)
	for a in arms:
		tw.tween_property(a, "rotation", Vector3(0.3, 0, 0), 1.2)
	calmed.emit(self)

# --- senses and behaviour ---------------------------------------------------------------------

func _on_noise(pos: Vector3, radius: float, _source: String) -> void:
	if state in [S.DEAD, S.CALM, S.GRAB, S.CHASE, S.AWAY] or not is_inside_tree():
		return
	if global_position.distance_to(pos) <= radius * hearing:
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
	if bounds.size == Vector2.ZERO:
		return p
	return Vector3(clampf(p.x, bounds.position.x, bounds.end.x), p.y, clampf(p.z, bounds.position.y, bounds.end.y))

func _physics_process(delta: float) -> void:
	_t += delta
	_state_t += delta
	if state in [S.DEAD, S.CALM]:
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
			if _flat(global_position).distance_to(_flat(_target)) < 0.8 and _state_t > 2.0 or _state_t > 14.0:
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
	if to != Vector3.INF:
		var d := _flat(to) - _flat(global_position)
		if d.length() > 0.3:
			v = d.normalized() * spd
			var want := atan2(-d.x, -d.z)
			rotation.y = lerp_angle(rotation.y, want, minf(delta * 5.0, 1.0))
	velocity.x = v.x
	velocity.z = v.z
	velocity.y = -1.0
	move_and_slide()
	var moving := v.length() > 0.1
	var gait := sin(_t * (9.0 if state == S.CHASE else 5.5)) * (0.5 if moving else 0.0)
	if arms.size() >= 2:
		arms[0].rotation.x = gait
		arms[1].rotation.x = -gait
	for i in range(2, arms.size()):
		arms[i].rotation.x = lerpf(arms[i].rotation.x, -1.3 if state == S.CHASE else sin(_t * 1.3 + i) * 0.1, delta * 4.0)
	body.position.y = absf(gait) * 0.04

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
	var tw := create_tween()
	tw.tween_property(body, "rotation:x", 0.35, 0.08)
	tw.tween_property(body, "rotation:x", 0.0, 0.4)

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
