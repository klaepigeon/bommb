class_name Monster
extends CharacterBody3D
## Something that lives in the walls. It hears (every noise the world makes, muffled by walls,
## sharper the more the infection has its way with Kurt), it sees (Kurt, if he's lit, in front of
## it, with nothing between), it walks the Nav graph (opening doors, breaking locked ones if it
## wants in badly enough), and it has a mind (think(), per creature). Shot, it says what that
## does to it (shot()). Spoken to, it may answer (get_verbs()).

signal caught_kurt(m: Monster)

enum S { IDLE, PATROL, INVESTIGATE, HUNT, SEARCH, GRAB, STAGGER, STUNNED, CALM, DEAD, AWAY, TALK, SIT }
const S_NAMES := ["idle", "patrol", "investigate", "hunt", "search", "grab", "stagger", "stunned", "calm", "dead", "away", "talk", "sit"]

var id := ""
var level: Level
var kurt: Kurt
var body: Body
var state := S.IDLE
var state_t := 0.0
var walk_speed := 1.0
var hunt_speed := 2.0
var hearing := 1.0
var sight := 8.0
var fov := 0.55                    ## cos of half the field of view
var reach := 1.1
var can_break_doors := true
var head_hp := 2.0
var body_hp := 5.0
var killable := true
var radius := 0.3
var height := 1.7
var path := PackedInt32Array()
var path_i := 0
var goal := Vector3.ZERO
var last_known := Vector3.ZERO
var heard_at := Vector3.ZERO
var heard_loud := 0.0
var sees := false
var seen_t := 0.0                  ## how long it's had Kurt in sight
var home := Vector3.ZERO
var zone := -1
var final_sit := true               ## SIT is 'calmed for good' (the porter just sits at his desk)
var allowed := Callable()          ## func(point_index) -> bool: where it may go
var _repath_t := 0.0
var _anim_phase := 0.0
var _hit_head: Area3D
var _hit_body: Area3D
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _bash_t := 0.0

func setup(p_id: String, p_level: Level, p_kurt: Kurt, at: Vector3) -> void:
	id = p_id; level = p_level; kurt = p_kurt; home = at
	collision_layer = 32
	collision_mask = 1
	add_to_group("monsters")
	add_to_group("shockable")
	var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new()
	cap.radius = radius; cap.height = maxf(height, radius * 2.0 + 0.1)
	cs.shape = cap; cs.position.y = cap.height * 0.5
	add_child(cs)
	body = Body.new(); body.name = "Body"
	add_child(body)
	body.build(design())
	_hit_head = _hitbox("head", Vector3(0.3, 0.32, 0.3))
	_hit_body = _hitbox("body", Vector3(0.5, height * 0.6, 0.4))
	body.set_meta("actor", self)
	_hit_body.set_meta("actor", self)
	Noises.made.connect(_on_noise)
	global_position = at
	World.register("monster_" + id, _save, _load)
	after_setup()

func design() -> Dictionary:
	return {}

func after_setup() -> void:
	pass

func _hitbox(part: String, size: Vector3) -> Area3D:
	var a := Area3D.new(); a.collision_layer = 4 | 8; a.collision_mask = 0; a.monitoring = false
	a.set_meta("monster", self); a.set_meta("part", part)
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = size; cs.shape = b
	a.add_child(cs)
	add_child(a)
	return a

func set_state(s: int) -> void:
	if s == state: return
	if state == S.DEAD or (state == S.SIT and final_sit and s in [S.HUNT, S.INVESTIGATE, S.SEARCH, S.PATROL]): return   # for good means for good
	Log.mark("%s %s -> %s" % [id, S_NAMES[state], S_NAMES[s]])
	state = s; state_t = 0.0
	World.emit_event("monster_state", {"id": id, "state": S_NAMES[s], "m": self})

func dist_to_kurt() -> float:
	return global_position.distance_to(kurt.global_position)

# ------------------------------------------------------------------------------- perception
func _on_noise(n: Dictionary) -> void:
	if state in [S.DEAD, S.CALM, S.AWAY, S.STUNNED] or (state == S.SIT and final_sit) or not is_inside_tree(): return
	if n.src == self: return
	var k := Noises.heard_at(n, global_position + Vector3(0, 1, 0), get_world_3d().direct_space_state, hearing * Progress.aggression())
	if k <= 0.0: return
	if k > heard_loud or Noises.now() - float(n.t) < 0.1:
		heard_at = n.pos; heard_loud = k
		heard(n, k)

## What it does with a sound (override). Default: go and see.
func heard(_n: Dictionary, k: float) -> void:
	if state in [S.IDLE, S.PATROL, S.SEARCH, S.INVESTIGATE] and k > 0.15:
		go_to(heard_at); set_state(S.INVESTIGATE)

func can_see_kurt() -> bool:
	if kurt.hiding_in != null: return false
	var eye := body.head_pos if body.head_pos != Vector3.ZERO else global_position + Vector3(0, height * 0.9, 0)
	var to := kurt.cam.global_position - eye
	var d := to.length()
	var agg := Progress.aggression()
	var lit := Lights.light_at(kurt.global_position + Vector3(0, 1, 0), kurt.zone)
	if Lights.torch.on and (-kurt.cam.global_transform.basis.z).dot(-to.normalized()) > 0.5: lit += 0.8      # his torch, pointed this way
	var reach_d := sight * agg * clampf(0.35 + lit * 1.6, 0.35, 1.0) * (0.6 if kurt.crouching else 1.0)
	if d > reach_d and d > 1.6: return false
	var fwd := -global_transform.basis.z
	if d > 1.6 and fwd.dot(to.normalized()) < fov: return false
	var q := PhysicsRayQueryParameters3D.create(eye, kurt.cam.global_position, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

# ------------------------------------------------------------------------------- moving
func go_to(p: Vector3) -> void:
	goal = p
	var a := level.nav.nearest(global_position, 3.0)
	var b := level.nav.nearest(p, 4.0)
	path = level.nav.path(a, b, _door_cost)
	path_i = 0
	_repath_t = 0.0

func _door_cost(door) -> float:
	if door is Flat47:
		return 0.0 if World.flag("wardrobe_moved") else -1.0
	if door is Door:
		var d := door as Door
		if d.broken or d.is_open(): return 0.0
		if not d.locked(): return 0.5
		return 6.0 if can_break_doors and state == S.HUNT else -1.0
	return 0.0

## Walks the path at `speed`; true when there.
func follow(speed: float, delta: float) -> bool:
	var target := goal
	if path.size() > 0 and path_i < path.size():
		target = level.nav.pts[path[path_i]]
		if path_i > 0:
			var door = level.nav.door_between(path[path_i - 1], path[path_i])
			if door is Door and not (door as Door).is_open() and not (door as Door).broken:
				var dd := door as Door
				if global_position.distance_to(dd.global_position + Vector3(0.4, 0, 0)) < 1.8:
					velocity = Vector3.ZERO
					if dd.locked():
						_bash_t -= delta
						if _bash_t <= 0.0 and can_break_doors:
							_bash_t = 1.4
							dd.damage(22.0, self, "bash")
					else:
						dd.try_open(self)
					return false
		var flat := Vector2(target.x - global_position.x, target.z - global_position.z)
		# reached it (well inside the distance it would stop at), or it's behind on the way to the next
		var behind := path_i == 0 and path.size() > 1 and level.nav.pts[path[1]].distance_to(global_position) < level.nav.pts[path[1]].distance_to(target)
		if flat.length() < 0.5 or behind:
			path_i += 1
			return false
	var to := target - global_position
	to.y = 0
	var last := path.is_empty() or path_i >= path.size()
	if to.length() < (0.4 if last else 0.05):
		velocity = Vector3.ZERO
		return true
	var dir := to.normalized()
	velocity.x = dir.x * speed; velocity.z = dir.z * speed
	if not float_above_floor(): velocity.y -= 9.8 * delta
	else: velocity.y = 0.0
	move_and_slide()
	_face(global_position + dir, delta * 6.0)
	_anim_phase += speed * delta * 3.2
	# stuck: try again from wherever it's got to
	_stuck_t = _stuck_t + delta if global_position.distance_to(_last_pos) < speed * delta * 0.2 else 0.0
	_last_pos = global_position
	if _stuck_t > 0.8:
		_stuck_t = 0.0
		# a door left half open in the way: shove it (doors are only furniture to something like this)
		for d in level.flat.doors.values() + level.maze.doors.values():
			var dd := d as Door
			if not dd.locked() and dd.global_position.distance_to(global_position) < 1.6 and dd.angle > 0.05:
				dd.swing(dd.max_angle if dd.angle < dd.max_angle * 0.5 else 0.0, 0.3)
				Audio.play("thud", dd.handle_pos(), -2.0)
				Noises.make(dd.handle_pos(), 8.0, "door", self)
		go_to(goal)
	return false

func float_above_floor() -> bool:
	return false

func _face(p: Vector3, k: float) -> void:
	var d := p - global_position; d.y = 0
	if d.length() < 0.01: return
	var want := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, want, clampf(k, 0.0, 1.0))

func face_kurt(delta: float) -> void:
	_face(kurt.global_position, delta * 5.0)

# ------------------------------------------------------------------------------- each frame
func _physics_process(delta: float) -> void:
	if not is_inside_tree() or kurt == null: return
	delta = minf(delta, 0.05)
	state_t += delta
	heard_loud = maxf(heard_loud - delta * 0.3, 0.0)
	sees = state != S.DEAD and can_see_kurt()
	seen_t = seen_t + delta if sees else maxf(seen_t - delta * 2.0, 0.0)
	if sees: last_known = kurt.global_position
	think(delta)
	var z := level.zone_of(global_position + Vector3(0, 0.5, 0))
	if z != zone:
		zone = z; body.set_zone(z)
	_hit_head.global_position = body.head_pos if body.head_pos != Vector3.ZERO else global_position + Vector3(0, height, 0)
	_hit_body.global_position = global_position + Vector3(0, height * 0.5, 0)
	animate(delta)

func think(_delta: float) -> void:
	pass

func animate(_delta: float) -> void:
	var spd := Vector2(velocity.x, velocity.z).length()
	body.pose({"phase": _anim_phase, "stride": clampf(spd / 1.5, 0.0, 1.0), "reach": 1.0 if state == S.HUNT and dist_to_kurt() < 2.5 else 0.0})

## Has hold of him.
func grab() -> void:
	set_state(S.GRAB)
	velocity = Vector3.ZERO
	caught_kurt.emit(self)
	World.emit_event("caught", {"by": id, "m": self})

# ------------------------------------------------------------------------------- damage
func shot(part: String, by, at: Vector3) -> void:
	Audio.play("hit", at, 0.0)
	World.emit_event("monster_shot", {"id": id, "part": part, "m": self})
	if not killable:
		stagger(2.5 if part == "head" else 1.0)
		return
	if part == "head" and Progress.has("headshot"):
		die(by); return
	if part == "head": head_hp -= 1.0
	else: body_hp -= 1.0
	if head_hp <= 0.0 or body_hp <= 0.0: die(by)
	else: stagger(0.8)

func stagger(secs: float) -> void:
	if state == S.DEAD: return
	set_state(S.STAGGER)
	set_meta("stagger_for", secs)
	if state != S.HUNT: last_known = kurt.global_position

func die(by) -> void:
	set_state(S.DEAD)
	velocity = Vector3.ZERO
	collision_layer = 0
	_hit_head.collision_layer = 0; _hit_body.collision_layer = 0
	var t := create_tween()
	t.tween_property(body, "rotation:x", -PI * 0.5, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(body, "position:y", 0.15, 0.6)
	Audio.play("thud", global_position, 2.0)
	Noises.make(global_position, 10.0, "body", self)
	if by is Kurt: Progress.killed(id)
	World.set_flag("killed_" + id)
	World.emit_event("killed", {"id": id, "m": self})

func shock(delta: float, _w) -> void:
	if state in [S.DEAD]: return
	set_meta("shock_t", float(get_meta("shock_t", 0.0)) + delta)
	if float(get_meta("shock_t")) > 0.3:
		set_meta("shock_t", 0.0)
		shocked()

func shocked() -> void:
	stagger(3.0)

## Something thrown hit it.
func struck_by(p: Prop, speed: float) -> void:
	if speed > 4.0 and p.mass > 0.8:
		World.emit_event("monster_struck", {"id": id, "m": self})
		stagger(0.6)

func get_verbs(_k) -> Array:
	return []

func act(_v: String, _k) -> void:
	pass

func _save() -> Dictionary:
	return {"xf": global_transform, "state": state, "hh": head_hp, "bh": body_hp}

func _load(d: Dictionary) -> void:
	global_transform = d.xf; head_hp = float(d.hh); body_hp = float(d.bh)
	var s := int(d.state)
	if s == S.DEAD:
		state = S.STAGGER; die(null)
	elif s in [S.CALM, S.SIT, S.AWAY, S.DEAD]:
		state = s
	else:
		state = S.IDLE
