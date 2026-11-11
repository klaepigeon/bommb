class_name MartaHunter
extends CharacterBody3D
## Marta, hunting. Not scripted appearances: a creature with senses, a route and a temper, inside
## the real level. She doesn't know where Kurt is unless she sees him, hears him or finds him.
##
## Senses (10 Hz, 3 Hz when far and calm):
##   sight    range from how lit he is (dark 3.5 m .. lit 12 m; the torch makes him a beacon),
##            shorter crouched, ~115° cone (wider when she's chasing), line of sight through
##            architecture and closed doors
##   hearing  every Events.noise, measured along the actual route (not through walls), quieter
##            for every closed door on the way
## Moods: dormant → patrol → suspicious → investigate → chase → search (last known position,
## then the hiding places near it, by chance, never certainly) → patrol. Also: pound (a door
## secured against her), stunned → retreat (shot, struck, shocked), pacified (the lullaby), dead.
##
## Counterplay that works: break line of sight, keep to the dark, crouch, close and lock doors,
## barricade, make noise elsewhere, hide (not guaranteed), lure her into live water, the music
## box, the gun (not guaranteed either: she comes back angrier).

signal caught(by: MartaHunter)
signal state_changed(s: String)

## the brain is shared; a subclass changes the body and the temperament (see super_hunter.gd)
var SPD := {"patrol": 0.85, "investigate": 1.35, "chase": 2.5, "search": 1.2, "retreat": 2.8, "pound": 0.0}
var who := "marta"                ## the story ledger's name for her (violence.shot_<who> ...)
var eye_height := 1.35
var sight_dark := 3.5             ## how far she sees him in the dark .. in the light
var sight_lit := 12.0
var hearing := 1.0                ## multiplies every noise's reach
var pacifiable := true            ## the lullaby works on her
var hit_points := 100.0

var level: Level
var player: Player
var nav: NavGrid
var model: Node3D
var state := "dormant"
var hp := 100.0
var aggression := 0
var suspicion := 0.0
var last_known := Vector3.INF
var patrol: Array = []
var hit_count := 0
var finish_offered := false

var _ids := PackedInt64Array()
var _i := 0
var _goal := Vector3.INF
var _repath := 0.0
var _sense := 0.0
var _st := 0.0                    # time in state
var _lost := 0.0
var _patrol_i := 0
var _noise_pos := Vector3.INF
var _distraction: Node = null
var _door_wait: Door = null
var _pound_door: Door = null
var _pound_t := 0.0
var _search_spots: Array = []
var _search_left := 0.0
var _hide_target: Node = null
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _t := 0.0
var _click_t := 4.0
var _threatened := 0.0
var _threat_resist := 0.0
var _seen_hide: Node = null       # she saw him go in
var _rng := RandomNumberGenerator.new()
var _presence: AudioStreamPlayer3D
var _yaw := 0.0
var _hook: Hook
var _pacify_src: Node = null
var _stun_left := 0.0
var _retreat_left := 0.0
var _sees := 0.0
var _grace := 0.0                 # after a catch: she can't see or catch him for a while

func setup(p_level: Level, p_player: Player, at: Vector3, route: Array) -> void:
	level = p_level
	player = p_player
	nav = level.nav
	patrol = route
	_rng.seed = 1947
	add_to_group("hunter")
	add_to_group("shockable")
	collision_layer = 16
	collision_mask = 1 | 2
	var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.3; cap.height = 1.6
	cs.shape = cap; cs.position = Vector3(0, 0.9, 0); add_child(cs)
	hp = hit_points
	_build_body()
	Player.set_layer(model, Level.CHAR_LAYER)
	global_position = at
	_last_pos = at
	_presence = Sfx.loop_at("hum", self, -12.0, 1.5)
	if _presence:
		_presence.pitch_scale = 0.45
	Events.noise.connect(_on_noise)
	# her own collider carries the "finish it" verb when that's possible
	var hb := StaticBody3D.new(); hb.collision_layer = 32
	var hs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(0.7, 1.4, 0.7); hs.shape = bs
	hb.add_child(hs); add_child(hb); hb.position = Vector3(0, 0.9, 0)
	_hook = Hook.attach(hb, self, "Marta")

## her body: Marta, seated in a chair that isn't there (the chair, the puddle, the roots stay behind)
func _build_body() -> void:
	var m := MartaModel.new()
	model = m
	add_child(m)
	for c in m.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false

func set_state(s: String) -> void:
	if state == s:
		return
	state = s
	_st = 0.0
	state_changed.emit(s)

func wake() -> void:
	if state == "dormant":
		set_state("patrol")
		_next_patrol()

# ---------------------------------------------------------------------------------- senses

func eye() -> Vector3:
	return global_position + Vector3(0, eye_height, 0)

func _visibility() -> float:
	if not player or player.is_hidden() or _grace > 0.0:
		return 0.0
	var target := player.global_position + Vector3(0, 1.0 if player.crouching else 1.45, 0)
	var to := target - eye()
	var d := to.length()
	var bright := level.brightness_at(player.global_position)
	var rng := lerpf(sight_dark, sight_lit, bright)
	if player.torch_on:
		rng = maxf(rng, 13.0)
	if player.crouching:
		rng *= 0.7
	rng *= 1.0 + 0.08 * aggression
	if d > rng:
		return 0.0
	var fwd := -global_transform.basis.z
	var fov := 165.0 if state == "chase" else 115.0
	if d > 1.8 and rad_to_deg(fwd.angle_to(Vector3(to.x, 0, to.z))) > fov * 0.5:
		return 0.0
	var q := PhysicsRayQueryParameters3D.create(eye(), target, 1)
	q.exclude = [get_rid(), player.get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return 0.0
	return clampf(1.0 - d / rng, 0.2, 1.0)

func _sense_tick(dt: float) -> void:
	_sees = _visibility()
	if _sees > 0.0:
		var d := global_position.distance_to(player.global_position)
		suspicion = minf(1.0, suspicion + _sees * 2.6 * dt)
		if state == "chase":
			last_known = player.global_position
			_lost = 0.0
		elif state != "pacified" and (suspicion >= 1.0 or d < 2.5):
			_start_chase()
		elif state in ["patrol", "search", "investigate"] and suspicion > 0.3:
			set_state("suspicious")
			_noise_pos = player.global_position
	else:
		suspicion = maxf(0.0, suspicion - 0.12 * dt)
	# a door he's just gone through, a hiding place she saw him get into
	if _sees > 0.3 and player.is_hidden() == false:
		_seen_hide = null
	elif state == "chase" and player.is_hidden() and _lost < 1.5:
		_seen_hide = player.hidden_in

func _start_chase() -> void:
	if state != "chase":
		Sfx.stinger()
		Story.record(who + ".spotted")
	set_state("chase")
	suspicion = 1.0
	last_known = player.global_position
	_lost = 0.0

## path distance a sound travels to her, and how muffled
func _heard(pos: Vector3, radius: float) -> float:
	var ids := nav.id_path(pos, global_position)
	var dist := 0.0
	var doors := 0
	if ids.size() < 2:
		dist = pos.distance_to(global_position) * 2.0
	else:
		for i in range(1, ids.size()):
			dist += nav.astar.get_point_position(ids[i - 1]).distance_to(nav.astar.get_point_position(ids[i]))
			if nav.door_of.has(ids[i]) and (nav.door_of[ids[i]] as Door).is_closed():
				doors += 1
		# a sound that has to go round is quieter than its straight line says
		dist = maxf(dist, pos.distance_to(global_position))
	# a closed door swallows a footstep; a gunshot goes through it
	var eff := radius * pow(0.8 if radius >= 20.0 else 0.55, doors)
	return clampf(1.0 - dist / maxf(eff, 0.01), 0.0, 1.0)

func _on_noise(pos: Vector3, radius: float, kind: String, src: Node) -> void:
	if state in ["dormant", "dead", "stunned"] or src == self:
		return
	radius *= hearing
	if pos.distance_to(global_position) > radius * 1.2:
		return
	var s := _heard(pos, radius)
	if s <= 0.0:
		return
	if state == "pacified":
		if kind == "gunshot":
			_start_chase()
		return
	match kind:
		"lullaby":
			if pacifiable and (state != "chase" or s > 0.5):
				_pacify(src, pos)
			return
		"gunshot":
			suspicion = 1.0
			if state == "chase":
				last_known = pos
			else:
				_investigate(pos, null, true)
			return
		"radio", "alarm":
			if state != "chase":
				_investigate(pos, src)
			return
		"giggle":
			if state != "chase":
				_investigate(pos, null)
				_seen_hide = player.hidden_in
			return
	# footsteps, work, impacts, doors: they add up
	if state == "chase":
		if s > 0.25 and src == player:
			last_known = pos
			_lost = maxf(0.0, _lost - 0.8)
		return
	suspicion = minf(1.0, suspicion + s * (0.9 if kind in ["impact", "break", "smash", "forced", "pounding", "shock"] else 0.45))
	if suspicion >= 0.45 or s > 0.6:
		_investigate(pos, null)

func _investigate(pos: Vector3, distraction: Node, urgent := false) -> void:
	_noise_pos = pos
	_distraction = distraction
	set_state("investigate")
	_go(pos)
	if urgent:
		_threat_resist += 0.0

func _pacify(src: Node, pos: Vector3) -> void:
	_pacify_src = src
	_noise_pos = pos
	set_state("pacified")
	_go(pos)
	Story.record("stealth.pacified")

# ---------------------------------------------------------------------------------- moving

func _go(target: Vector3, ignore_locks := false) -> bool:
	_goal = target
	if state != "pound":
		_pound_door = null
	_ids = nav.id_path(global_position, target) if not ignore_locks else PackedInt64Array()
	if ignore_locks or _ids.size() < 2:
		# the route's shut: where would she go if the doors gave?
		var p := nav.path(global_position, target, true)
		if p.size() >= 2:
			var all_ids := _ids_ignoring_locks(target)
			for d in nav.doors_on(all_ids):
				if level.ai_secured(d):
					_pound_door = d
					_ids = nav.id_path(global_position, (d as Door).global_position - (d as Door).global_transform.basis.z * float((d as Door).side_of(global_position)) * -0.6)
					break
	_i = 1 if _ids.size() > 1 else 0
	_repath = 0.35
	return _ids.size() > 0

func _ids_ignoring_locks(target: Vector3) -> PackedInt64Array:
	var disabled := []
	for id in nav.door_of:
		if nav.astar.is_point_disabled(id):
			disabled.append(id)
			nav.astar.set_point_disabled(id, false)
	var ids := nav.id_path(global_position, target)
	for id in disabled:
		nav.astar.set_point_disabled(id, true)
	return ids

func _speed() -> float:
	var s: float = SPD.get(state, 1.0)
	if state == "suspicious":
		s = 0.5
	if state == "chase":
		s += 0.18 * aggression
		if _threatened > 0.0:
			s *= 0.3
	return s

func _follow(delta: float) -> bool:
	if _ids.is_empty() or _i >= _ids.size():
		velocity = Vector3.ZERO
		return true
	var id := _ids[_i]
	var p := nav.astar.get_point_position(id)
	# a door on the way: open it, or deal with it
	if nav.door_of.has(id):
		var d: Door = nav.door_of[id]
		var near := global_position.distance_to(Vector3(p.x, global_position.y, p.z)) < 1.3
		if near and not d.broken and (d.is_closed() or d.blocked):
			if level.ai_secured(d):
				_pound_door = d
				set_state("pound")
				return false
			if d.blocked:
				d.shove(55.0 + 15.0 * aggression, d.side_of(global_position))
				d.try_open(d.side_of(global_position), self)
				velocity = Vector3.ZERO
				return false
			if _door_wait != d:
				_door_wait = d
				d.try_open(d.side_of(global_position), self)
			if d.open_k < 0.55:
				velocity = Vector3.ZERO
				return false
	var to := p - global_position
	to.y = 0.0
	if to.length() < 0.35:
		# seams: she uses the loops too
		if nav.seams.has(id) and _i + 1 < _ids.size() and _ids[_i + 1] == nav.seams[id]:
			global_position = nav.astar.get_point_position(nav.seams[id])
			_i += 1
		_i += 1
		_door_wait = null
		return _i >= _ids.size()
	var v := to.normalized() * _speed()
	velocity = Vector3(v.x, 0, v.z)
	return false

func _process_motion(delta: float) -> void:
	move_and_slide()
	# float at the floor of wherever she is
	var room := level.room_at(global_position + Vector3(0, 1.0, 0))
	if room != "":
		global_position.y = move_toward(global_position.y, level.room_floor(room), delta)
	# push light things out of her way; if she's stuck, shove harder
	for i in get_slide_collision_count():
		var rb := get_slide_collision(i).get_collider() as RigidBody3D
		if rb:
			rb.apply_central_impulse(-get_slide_collision(i).get_normal() * (2.0 + rb.mass * 0.4))
	if velocity.length() > 0.1:
		_stuck_t += delta
		if _stuck_t > 1.2:
			if global_position.distance_to(_last_pos) < 0.25:
				_repath = 0.0
				velocity = Vector3.ZERO
				global_position += Vector3(_rng.randf_range(-0.2, 0.2), 0, _rng.randf_range(-0.2, 0.2))
			_stuck_t = 0.0
			_last_pos = global_position
	# face where she's going (or him, if she's after him)
	var look := velocity
	if state == "chase" and _sees > 0.0:
		look = player.global_position - global_position
	if look.length() > 0.05:
		var want := atan2(-look.x, -look.z)
		_yaw = lerp_angle(_yaw, want, minf(1.0, delta * 5.0))
		rotation.y = _yaw

# ---------------------------------------------------------------------------------- the brain

func _physics_process(delta: float) -> void:
	if state == "dead" or not player or not level:
		return
	_t += delta
	_st += delta
	_threatened = maxf(0.0, _threatened - delta)
	_grace = maxf(0.0, _grace - delta)
	var far := global_position.distance_to(player.global_position) > 22.0 and state in ["patrol", "dormant"]
	_sense -= delta
	if _sense <= 0.0 and state not in ["dormant", "stunned"]:
		var dt := 0.33 if far else 0.1
		_sense = dt
		_sense_tick(dt)
		_threat_check()
	# the way to him is a door she can't open: she goes at the door
	if state in ["chase", "search"] and _pound_door and is_instance_valid(_pound_door) and level.ai_secured(_pound_door) \
			and global_position.distance_to(_pound_door.global_position) < 1.6:
		set_state("pound")
	match state:
		"dormant":
			velocity = Vector3.ZERO
		"patrol":
			if _follow(delta):
				_next_patrol()
		"suspicious":
			velocity = Vector3.ZERO
			_face_toward(_noise_pos, delta)
			if _st > 1.6:
				if suspicion > 0.3:
					_investigate(_noise_pos, null)
				else:
					set_state("patrol")
					_next_patrol()
		"investigate":
			_repath -= delta
			if _follow(delta):
				velocity = Vector3.ZERO
				if _distraction and is_instance_valid(_distraction):
					_silence(_distraction)
					_distraction = null
				if _st > 3.5 + _rng.randf() * 2.0:
					_begin_search(_noise_pos, 0.2 + 0.15 * aggression)
		"chase":
			_lost += delta if _sees <= 0.0 else 0.0
			_repath -= delta
			if _repath <= 0.0:
				_go(last_known if _sees <= 0.0 else player.global_position)
			_follow(delta)
			var d := global_position.distance_to(player.global_position)
			if d < 1.0 and not player.is_hidden() and player.mode != "downed" and _grace <= 0.0:
				_catch()
			elif _lost > 2.5 and global_position.distance_to(last_known) < 1.2 or _lost > 7.0:
				var p_check := 0.55 + (0.35 if _seen_hide else 0.0) + 0.05 * aggression
				_begin_search(last_known, p_check)
		"search":
			_repath -= delta
			if _hide_target:
				if _follow(delta):
					velocity = Vector3.ZERO
					var found: Node = _hide_target.search()
					Story.record(who + ".checked_hide")
					if found == player:
						player.unhide()
						_catch()
						return
					_hide_target = null
					_st = 0.0
			elif _follow(delta) or _st > 6.0:
				_search_left -= _st
				_st = 0.0
				_search_step()
		"pound":
			velocity = Vector3.ZERO
			if not _pound_door or not is_instance_valid(_pound_door) or not level.ai_secured(_pound_door):
				_pound_door = null
				set_state("chase" if suspicion > 0.8 else "patrol")
				_repath = 0.0
				if state == "patrol": _next_patrol()
			else:
				_pound_t -= delta
				_face_toward(_pound_door.global_position, delta)
				if _pound_t <= 0.0:
					_pound_t = 1.15 - 0.1 * aggression
					if _pound_door.pound(13.0 + 3.0 * aggression):
						Story.record(who + ".broke_door")
				# she gives up on doors she's not sure about
				if suspicion < 0.6 and _st > 6.0:
					_pound_door = null
					set_state("patrol")
					_next_patrol()
		"stunned":
			velocity = Vector3.ZERO
			_stun_left -= delta
			model.rotation.z = sin(_t * 23.0) * 0.12 * clampf(_stun_left, 0.0, 1.0)
			if _stun_left <= 0.0:
				model.rotation.z = 0.0
				if finish_offered:
					Story.record("stealth.spared")
					finish_offered = false
					if SockoDirector.inst: SockoDirector.inst._on_record("stealth.spared", {})
				_retreat()
		"retreat":
			_retreat_left -= delta
			if _follow(delta) or _retreat_left <= 0.0:
				suspicion = 0.5
				set_state("patrol")
				_next_patrol()
		"pacified":
			if _follow(delta):
				velocity = Vector3.ZERO
			var playing: bool = _pacify_src != null and is_instance_valid(_pacify_src) and (_pacify_src as Prop).behaviour != null and bool((_pacify_src as Prop).behaviour.get("playing"))
			if not playing:
				if _st > 8.0:
					suspicion = 0.0
					set_state("patrol")
					_next_patrol()
			else:
				_st = 0.0
	_process_motion(delta)
	_animate(delta)
	_audio(delta)

func _face_toward(p: Vector3, delta: float) -> void:
	var to := p - global_position
	if to.length() > 0.1:
		_yaw = lerp_angle(_yaw, atan2(-to.x, -to.z), minf(1.0, delta * 4.0))
		rotation.y = _yaw

func _next_patrol() -> void:
	if patrol.is_empty():
		return
	_patrol_i = (_patrol_i + 1) % patrol.size()
	var a: Array = patrol[_patrol_i]
	_go(Vector3(a[0], a[1], a[2]))

func _begin_search(at: Vector3, p_check: float) -> void:
	set_state("search")
	_search_left = 16.0 + 4.0 * aggression
	_search_spots.clear()
	for h in level.hides:
		var hd := (h as Node3D).global_position.distance_to(at)
		if hd < 5.5 or h == _seen_hide:
			if h == _seen_hide or _rng.randf() < p_check:
				_search_spots.append(h)
	_search_spots.sort_custom(func(a, b): return (a as Node3D).global_position.distance_to(at) < (b as Node3D).global_position.distance_to(at))
	_seen_hide = null
	_go(at)

func _search_step() -> void:
	if not _search_spots.is_empty():
		_hide_target = _search_spots.pop_front()
		_go((_hide_target as Node3D).global_transform * (_hide_target.get("exit_pos") as Vector3))
		return
	if _search_left <= 0.0:
		suspicion = 0.25
		set_state("patrol")
		_next_patrol()
		return
	# wander the room he was last in, and the next one over
	var room := nav.room_at(last_known if last_known != Vector3.INF else global_position)
	_go(nav.random_point(room, _rng) if room != "" else global_position)

func _silence(n: Node) -> void:
	var p := n as Prop
	if p and p.behaviour and p.behaviour.has_method("silence"):
		if aggression >= 2 or suspicion > 0.8:
			p.break_apart()                      # she's past switching things off
		else:
			p.behaviour.silence()
			Sfx.play_at("switch", p.global_position, -2.0, 0.7, 2.0)
		Story.record(who + ".silenced", {"what": p.display_name})

func _retreat() -> void:
	set_state("retreat")
	_retreat_left = 16.0
	# the patrol point furthest from him
	var best: Array = []
	var bd := -1.0
	for a in patrol:
		var v := Vector3(a[0], a[1], a[2])
		var d := v.distance_to(player.global_position)
		if d > bd:
			bd = d; best = a
	if not best.is_empty():
		_go(Vector3(best[0], best[1], best[2]))

func _threat_check() -> void:
	# the revolver pointed at her: she hangs back, for a while
	if state != "chase" or not player.gun or not player.gun.aiming or _sees <= 0.0:
		_threat_resist = maxf(0.0, _threat_resist - 0.05)
		return
	var to := global_position + Vector3(0, 1.0, 0) - player.camera.global_position
	var aim := -player.camera.global_transform.basis.z
	if rad_to_deg(aim.angle_to(to)) < 12.0 and to.length() < 10.0:
		_threat_resist += 0.1
		if _threat_resist < 3.0:
			_threatened = 0.4
			if _threat_resist < 0.15:
				Story.record("violence.threatened")

func _catch() -> void:
	velocity = Vector3.ZERO
	_grace = 8.0
	Story.record("caught")
	caught.emit(self)
	Events.player_caught.emit(self)
	set_state("patrol")
	suspicion = 0.0

## the director moves her away after a catch
func reset_to(pos: Vector3) -> void:
	global_position = pos
	_ids = PackedInt64Array()
	set_state("patrol")
	_next_patrol()

# ---------------------------------------------------------------------------------- harm

func shot(pos: Vector3, _dir := Vector3.ZERO) -> void:
	if state == "dead":
		return
	var head := pos.y > global_position.y + 1.2
	var dmg := 45.0 if head else 25.0
	hp -= dmg
	hit_count += 1
	Story.record("violence.shot_" + who, {"head": head, "hp": hp})
	_hurt_sound()
	if hp <= 0.0:
		_die("violence.killed_" + who)
		return
	aggression += 1
	_stun(2.2 if not head else 3.2)

func hit_by_object(prop: Node, speed: float) -> void:
	var force := float(prop.mass) * speed
	if force < 10.0 or state == "dead":
		return
	Story.record("violence.struck_" + who)
	_stun(minf(force / 20.0, 1.6))
	suspicion = 1.0
	last_known = player.global_position

func shock(_hz: Dictionary) -> void:
	if state in ["stunned", "dead"]:
		return
	Sfx.play_at("buzz", eye(), 4.0, 0.8, 8.0, "shock", self)
	Story.record("stealth.trapped_" + who)
	_stun(5.0)

func _stun(sec: float) -> void:
	_stun_left = sec
	set_state("stunned")
	velocity = Vector3.ZERO
	if who == "marta" and hp < 40.0 and Infection.stage >= 1:
		finish_offered = true
		if SockoDirector.inst:
			SockoDirector.inst.suggest("finish")

func _die(key: String) -> void:
	set_state("dead")
	Story.record(key)
	Story.set_flag(who + "_dead", true)
	velocity = Vector3.ZERO
	if _presence:
		_presence.queue_free()
	Sfx.set_tension(0.0)
	var t := create_tween().set_parallel()
	t.tween_property(model, "rotation:x", -1.3, 1.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.tween_property(model, "position:y", -0.2, 1.4)
	collision_layer = 0

func iverbs(_p: Node) -> Array:
	if state == "stunned" and finish_offered and global_position.distance_to(player.global_position) < 2.2:
		return [Interactable.v("finish", "Finish it")]
	return []

func iverb(id: String, _p: Node) -> void:
	if id == "finish":
		finish_offered = false
		Sfx.play_at("impact_flesh", eye(), 4.0, 0.7)
		player.shake(0.6)
		_die("violence.finished_" + who)

func ifocus() -> Vector3:
	return eye()

# ---------------------------------------------------------------------------------- body & voice

func _animate(delta: float) -> void:
	var mm := model as MartaModel
	if state == "dead" or not mm:
		return
	var hover := 0.14 + sin(_t * 1.3) * 0.04
	if state == "pacified" and velocity.length() < 0.05:
		hover = 0.0
	model.position.y = lerpf(model.position.y, hover, delta * 3.0)
	var reach := 1.0 if state == "chase" else 0.0
	for j in ["shR", "shL"]:
		var n: Node3D = mm.joints.get(j)
		if n:
			n.rotation.x = lerp_angle(n.rotation.x, -1.3 * reach, delta * 3.0)
	var head: Node3D = mm.joints.get("head")
	if not head:
		return
	if state in ["chase", "stunned"] and player:
		mm.face(player.camera.global_position, MartaModel.JAW_OPEN * (1.0 if state == "chase" else 0.4))
	elif state == "pacified":
		head.rotation = head.rotation.lerp(Vector3(0.6, 0, 0.2), delta * 2.0)
	else:
		# the head hangs, then snaps to a new angle (she's listening)
		if fmod(_t, 2.3) < delta:
			head.rotation = MartaModel.HEAD_REST + Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.8, 0.8), _rng.randf_range(-0.4, 0.4))
		head.rotation = head.rotation.lerp(MartaModel.HEAD_REST, delta * 0.3)

func _hurt_sound() -> void:
	Sfx.play_at("marta_clicks", eye(), 6.0, 1.6)

func _audio(delta: float) -> void:
	var d := global_position.distance_to(player.global_position)
	_voice(delta, d)
	_tension_and_threat(delta, d)

## her clicking: her audio signature, and (as the infection grows) almost words
func _voice(delta: float, d: float) -> void:
	_click_t -= delta
	if _click_t <= 0.0 and state not in ["dormant", "pacified", "stunned"]:
		_click_t = _rng.randf_range(2.5, 5.0) if state == "chase" else _rng.randf_range(6.0, 11.0)
		Sfx.play_at("marta_clicks", eye(), -2.0 if state != "chase" else 2.0, _rng.randf_range(0.9, 1.1))
		if d < 9.0:
			var line := "marta_clicks"
			if Infection.stage >= 3: line = "marta_clicks_3"
			elif Infection.stage >= 2: line = "marta_clicks_2"
			Speech.bark(line)
	if _rng.randf() < delta * 0.15 and velocity.length() > 0.2:
		Sfx.play_at("creak", global_position, -10.0, _rng.randf_range(0.8, 1.2))

func _tension_and_threat(delta: float, d: float) -> void:
	var tension := 0.0
	match state:
		"chase": tension = 1.0
		"search", "pound": tension = 0.55
		"investigate", "suspicious": tension = 0.3 if d < 12.0 else 0.0
	Sfx.set_tension(tension)
	if SockoDirector.inst:
		SockoDirector.inst.threat_near = d < 11.0 and state not in ["patrol", "dormant", "pacified", "dead"]
	if d < 6.0:
		Infection.expose(0.004, delta)

func get_state() -> Dictionary:
	return {"pos": var_to_str(global_position), "state": state if state in ["dead", "dormant"] else "patrol", "hp": hp, "aggression": aggression, "hits": hit_count}

func set_state_dict(d: Dictionary) -> void:
	global_position = str_to_var(String(d.get("pos", var_to_str(global_position))))
	hp = float(d.get("hp", hp))
	aggression = int(d.get("aggression", 0))
	hit_count = int(d.get("hits", 0))
	var s := String(d.get("state", "patrol"))
	if s == "dead":
		_die("restored")
	elif s == "dormant":
		state = "dormant"
	else:
		set_state("patrol")
		_next_patrol()
