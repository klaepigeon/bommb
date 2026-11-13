class_name Inhabitant
extends CharacterBody3D
## Someone who lives in the building (docs/CHAPTER2.md). Not a zombie and not a person: an
## individual whose idea of ordinary life has gone wrong, getting on with it whether Kurt is there
## or not. Built from a profile (a Dictionary, the level's data):
##
##   id, body (FleshBody params), speed 1.1, run 2.6, hp 60, poise 30, faction "residents"
##   hostile_to ["kurt", factions...]   who it attacks on sight
##   sight {range 10, cos 0.5, needs_light false}   hearing 1.0 (0 = deaf)   blind (no sight)
##   attack {dmg 0.25, reach 1.3, windup 0.45, cool 1.4}   voice (Sfx name for its noises)
##   territory [Vector3 min, Vector3 max]   (defend: trespassers inside are attacked)
##   fear_light false (it won't stay in light; it flees the torch)   steals_into_dark
##   objectives: [{type, weight, ...}] (see _score / _do):
##     work      {stations: [kind...], order: "loop"|"random"}     do things at stations
##     patrol    {points: [Vector3...], wait 2}
##     hunt      {targets: [faction or id...]}                       go for other inhabitants
##     carry     {from: kind, to: kind}                              fetch from one, use at the other
##     push      {things: "furniture", to: [Vector3...]}             shove furniture about
##     follow    {who: "kurt", dist 6}                               keep him in sight, at a distance
##     sabotage  {}                                                  the super: power back off
##     relock    {doors: [...]}                                      the super: doors he wants shut
## Every second or so it scores its objectives (plus the reactive ones: attack what it hates
## that it can see, look into a noise, defend its territory, get out of the light) and does the
## highest. No text ever says what it's doing: you see it, and hear it.

signal died(who: Inhabitant)
signal attacked(who: Inhabitant, target: Node)

var prof := {}
var id := ""
var faction := "residents"
var body: FleshBody
var agent: NavigationAgent3D
var level: Node
var player: Player

var hp := 60.0
var poise := 30.0
var dead := false
var state := "idle"             # what it's doing (developer overlay only): idle, work, patrol, hunt, attack, investigate, defend, flee, carry, push, follow, sabotage, relock, stagger, dead
var objective := ""             # the objective it's on
var target: Node = null         # who it's after
var awareness := 0.0            # of Kurt: 0..1 (seen / heard)
var _think := 0.0
var _goal := Vector3.INF
var _station: Station = null
var _station_t := 0.0
var _noise_at := Vector3.INF
var _noise_t := 0.0
var _attack_t := 0.0
var _windup := 0.0
var _stagger := 0.0
var _walk := 0.0
var _stuck := 0.0
var _unstick := 0.0
var _unstick_dir := Vector3.ZERO
var _stuck_count := 0
var _last_pos := Vector3.ZERO
var _work_i := 0
var _carrying := ""
var _push_body: RigidBody3D = null
var _anim_t := 0.0
var _sound_t := 0.0
var memory := {}                # whatever the level wants to keep about it (grudges, etc.)

func _init(profile := {}) -> void:
	prof = profile
	id = String(profile.get("id", "someone"))
	faction = String(profile.get("faction", "residents"))
	hp = float(profile.get("hp", 60.0)); poise = float(profile.get("poise", 30.0))

func _ready() -> void:
	add_to_group("inhabitant")
	collision_layer = 8 | 32; collision_mask = 1 | 32
	var h: float = float(prof.get("body", {}).get("height", 1.75))
	var cs := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.18; cap.height = maxf(0.6, h)
	cs.shape = cap; cs.position.y = cap.height * 0.5; add_child(cs)
	body = FleshBody.new(prof.get("body", {})); add_child(body)
	agent = NavigationAgent3D.new(); agent.path_desired_distance = 0.4; agent.target_desired_distance = 0.5
	agent.avoidance_enabled = false; agent.max_speed = float(prof.get("run", 2.6))
	add_child(agent)
	_last_pos = global_position
	if not Game.noise.is_connected(_on_noise): Game.noise.connect(_on_noise)

func _exit_tree() -> void:
	if Game.noise.is_connected(_on_noise): Game.noise.disconnect(_on_noise)

func eye() -> Vector3:
	return body.at("head") + Vector3(0, 0.08, 0)

# ------------------------------------------------------------------ senses
## Can it see `n` (Kurt or another inhabitant)? Distance, cone, a clear line, and for some, light.
func sees(n: Node3D) -> bool:
	if prof.get("blind", false) or not is_instance_valid(n): return false
	var s: Dictionary = prof.get("sight", {})
	var to: Vector3 = (n.global_position + Vector3(0, 1.2, 0)) - eye()
	var reach: float = float(s.get("range", 10.0))
	if n == player:
		if player.hidden_in: return false
		if player.crouching: reach *= 0.6
		if player.torch_on: reach *= 1.5
		elif s.get("needs_light", false) and level and level.has_method("lit") and not level.lit(player.global_position): reach *= 0.3
	if to.length() > reach: return false
	var fwd := -global_basis.z
	if to.length() > 1.4 and fwd.dot(Vector3(to.x, 0, to.z).normalized()) < float(s.get("cos", 0.5)): return false
	var q := PhysicsRayQueryParameters3D.create(eye(), eye() + to, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func hates(n: Node) -> bool:
	var h: Array = prof.get("hostile_to", [])
	if n == player: return h.has("kurt")
	if n is Inhabitant: return h.has(n.faction) or h.has(n.id)
	return false

func _on_noise(pos: Vector3, loud: float) -> void:
	if dead: return
	var hear: float = float(prof.get("hearing", 1.0))
	if hear <= 0.0: return
	var d := pos.distance_to(global_position)
	if pos.distance_to(global_position) < 0.8: return            # (its own)
	var through := not get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye(), pos + Vector3(0, 0.4, 0), 1, [get_rid()])).is_empty()
	var reach := loud * 14.0 * hear * (0.55 if through else 1.0)
	if d <= reach:
		_noise_at = pos; _noise_t = 6.0 + loud * 6.0
		if player and pos.distance_to(player.global_position) < 1.5: awareness = maxf(awareness, 0.5 * hear)
		_think = 0.0

# ------------------------------------------------------------------ deciding
func _physics_process(delta: float) -> void:
	if dead or not player: return
	_anim_t += delta
	_attack_t = maxf(0.0, _attack_t - delta)
	_noise_t = maxf(0.0, _noise_t - delta)
	if _stagger > 0.0:
		_stagger -= delta; velocity = velocity.lerp(Vector3.ZERO, 1.0 - exp(-6.0 * delta)); move_and_slide()
		_animate(delta); return
	# Kurt: seen raises it, unseen lets it fall
	if sees(player): awareness = minf(1.0, awareness + delta * (2.0 if global_position.distance_to(player.global_position) < 4.0 else 0.8))
	else: awareness = maxf(0.0, awareness - delta * 0.15)
	_think -= delta
	if _think <= 0.0:
		_think = randf_range(0.35, 0.6)
		_decide()
	_act(delta)
	_hazards(delta)
	_animate(delta)
	_sounds(delta)

func _decide() -> void:
	var best := ""; var best_s := 0.0; var best_o := {}
	# reactive first: something it hates, in front of it
	var foe := _visible_foe()
	if foe:
		target = foe
		best = "attack"; best_s = 10.0
	if best == "" and prof.get("fear_light", false) and _in_light():
		best = "flee"; best_s = 9.0
	if best == "" and prof.has("territory") and _trespasser():
		best = "defend"; best_s = 8.0
	if best == "" and _noise_t > 0.0 and _noise_at != Vector3.INF and float(prof.get("hearing", 1.0)) > 0.0:
		best = "investigate"; best_s = 5.0 + float(prof.get("hearing", 1.0))
	if best == "" or best_s < 5.0:
		for o in prof.get("objectives", []):
			var s := _score(o)
			if s > best_s: best_s = s; best = String(o.type); best_o = o
	if best != objective:
		_leave()
		objective = best
		if best_o: memory["obj"] = best_o
	state = objective if objective != "" else "idle"

func _score(o: Dictionary) -> float:
	var w: float = float(o.get("weight", 1.0))
	match String(o.type):
		"work", "patrol": return w
		"hunt":
			var t = _nearest_target(o.get("targets", []), 30.0)
			if t: target = t; return 6.0 * w
			return 0.0
		"carry": return w
		"push": return w * (1.0 if randf() < 0.6 else 0.3)
		"follow": return 4.0 * w if Game.disposition(String(o.get("who_rel", "super"))) == "suspicious" else 0.0
		"sabotage": return 7.0 * w if level and level.get("power_on") and Game.disposition("super") == "hostile" else 0.0
		"relock":
			for d in o.get("doors", []): if is_instance_valid(d) and not d.locked and not d.is_open: return 3.0 * w
			return 0.0
		"hunt_kurt": return 6.5 * w if Game.disposition("super") == "hostile" else 0.0
	return 0.0

func _leave() -> void:
	if _station and _station.busy_by == self: _station.busy_by = null
	_station = null; _push_body = null

func _nearest_target(list: Array, within: float) -> Node3D:
	var best: Node3D = null; var bd := within
	for n in get_tree().get_nodes_in_group("inhabitant"):
		if n == self or n.dead: continue
		if list.has(n.faction) or list.has(n.id):
			var d: float = n.global_position.distance_to(global_position)
			if d < bd: bd = d; best = n
	return best

func _visible_foe() -> Node3D:
	if hates(player) and awareness >= 1.0: return player
	if hates(player) and sees(player) and global_position.distance_to(player.global_position) < 2.2: return player
	for n in get_tree().get_nodes_in_group("inhabitant"):
		if n != self and not n.dead and hates(n) and n.global_position.distance_to(global_position) < 9.0 and sees(n): return n
	return null

func _trespasser() -> bool:
	var a: Vector3 = prof.territory[0]; var b: Vector3 = prof.territory[1]
	var inside := func(v: Vector3) -> bool: return v.x > a.x and v.x < b.x and v.z > a.z and v.z < b.z and v.y > a.y - 0.5 and v.y < b.y
	if inside.call(player.global_position) and not player.hidden_in: target = player; return true
	for n in get_tree().get_nodes_in_group("inhabitant"):
		if n != self and not n.dead and n.faction != faction and inside.call(n.global_position): target = n; return true
	return false

func _in_light() -> bool:
	if not level or not level.has_method("lit"): return false
	if level.lit(global_position + Vector3(0, 0.6, 0)): return true
	if player.torch_on:
		var to := global_position + Vector3(0, 0.6, 0) - player.cam.global_position
		if to.length() < 9.0 and (-player.cam.global_transform.basis.z).dot(to.normalized()) > 0.9: return true
	return false

# ------------------------------------------------------------------ doing
func _act(delta: float) -> void:
	var speed: float = float(prof.get("speed", 1.1))
	match objective:
		"attack", "defend", "hunt", "hunt_kurt":
			if objective == "hunt_kurt": target = player
			if not is_instance_valid(target) or (target is Inhabitant and target.dead):
				target = null; objective = ""; return
			var tp: Vector3 = target.global_position
			var d := global_position.distance_to(tp)
			var reach: float = float(prof.get("attack", {}).get("reach", 1.3))
			if d > reach * 0.9:
				_go(tp, float(prof.get("run", 2.6)), delta)
			else:
				_stop(); _face(tp, delta * 8.0); _strike(delta)
			if target == player and not sees(player) and d > 3.0 and objective == "attack":
				awareness = maxf(0.0, awareness - delta * 0.4)
				_noise_at = tp; _noise_t = 5.0
		"investigate":
			if _noise_at == Vector3.INF or _noise_t <= 0.0: objective = ""; return
			if global_position.distance_to(_noise_at) > 1.0: _go(_noise_at, speed * 1.4, delta)
			else:
				_stop(); rotation.y += sin(_anim_t * 1.3) * delta
				# whoever's standing where the noise was, if it hates them, it goes for them
				for n in get_tree().get_nodes_in_group("inhabitant"):
					if n != self and not n.dead and hates(n) and n.global_position.distance_to(global_position) < 2.0: target = n; objective = "attack"
				if hates(player) and player.global_position.distance_to(global_position) < 2.2 and not player.hidden_in: target = player; objective = "attack"; awareness = 1.0
		"flee":
			var away := _darkest_near()
			_go(away, float(prof.get("run", 2.6)), delta)
		"work": _work(delta)
		"patrol": _patrol(delta)
		"carry": _carry(delta)
		"push": _push(delta)
		"follow":
			var d2 := global_position.distance_to(player.global_position)
			if d2 > 7.0 or not sees(player): _go(player.global_position, speed, delta)
			else: _stop(); _face(player.global_position, delta * 3.0)
		"sabotage":
			if level and level.has_method("sabotage_point"):
				var sp: Vector3 = level.sabotage_point()
				if global_position.distance_to(sp) > 0.9: _go(sp, float(prof.get("run", 2.6)), delta)
				else: _stop(); level.sabotage(self)
		"relock":
			for dr in memory.get("obj", {}).get("doors", []):
				if is_instance_valid(dr) and not dr.locked and not dr.is_open:
					if global_position.distance_to(dr.global_position) > 1.2: _go(dr.global_position, speed, delta)
					else: _stop(); dr.locked = true; Sfx.play_at("door_rattle", dr.global_position + Vector3(0, 1, 0), -6.0, 0.8)
					break
		_:
			_stop()

## A blow: wind up (seen and heard: the telegraph), then if the target's still in front and in
## reach, it lands. Staggered out of a windup by a hard enough hit.
func _strike(delta: float) -> void:
	var a: Dictionary = prof.get("attack", {})
	if _windup > 0.0:
		_windup -= delta
		if _windup <= 0.0:
			_attack_t = float(a.get("cool", 1.4))
			if is_instance_valid(target) and target.global_position.distance_to(global_position) < float(a.get("reach", 1.3)) + 0.3:
				var to: Vector3 = (target.global_position - global_position) * Vector3(1, 0, 1)
				if (-global_basis.z).dot(to.normalized()) > 0.4:
					attacked.emit(self, target)
					Sfx.play_at("thud", target.global_position + Vector3(0, 1.2, 0), -2.0, 0.8)
					if target == player: player.hurt(float(a.get("dmg", 0.25)), global_position)
					elif target is Inhabitant: target.take_hit(float(a.get("dmg", 0.25)) * 80.0, global_position, self)
		return
	if _attack_t <= 0.0:
		_windup = float(a.get("windup", 0.45))
		_say("attack")

func take_hit(dmg: float, from: Vector3, by: Node = null) -> void:
	if dead: return
	hp -= dmg; poise -= dmg
	Sfx.play_at("bone_crack", eye(), -4.0, randf_range(0.7, 1.0))
	if poise <= 0.0:
		poise = float(prof.get("poise", 30.0)); _stagger = 1.2; _windup = 0.0
		var away := (global_position - from) * Vector3(1, 0, 1)
		if away.length() > 0.01: velocity = away.normalized() * 2.5
	if by and by != self:
		if by == player: awareness = 1.0
		if (by == player and not hates(player)) or by is Inhabitant:
			# it remembers who hurt it
			var h: Array = prof.get("hostile_to", []).duplicate()
			var key: String = "kurt" if by == player else String(by.id)
			if not h.has(key): h.append(key); prof["hostile_to"] = h
			target = by; objective = "attack"
	if hp <= 0.0: die()

## (the player's weapons and Fx call these, the same names Marta answers to)
func melee_hit(dmg: float, from: Vector3, knock: float, by = null) -> void:
	take_hit(dmg, from, player if by != null else null)
	velocity += ((global_position - from) * Vector3(1, 0, 1)).normalized() * knock

func shot(point: Vector3, dir: Vector3) -> void:
	take_hit(22.0, point - dir, player)

func die() -> void:
	if dead: return
	dead = true; state = "dead"; objective = ""
	_leave()
	collision_layer = 0
	_say("die")
	body.snap = 5.0
	body.pose = {"spine": Vector3(-1.2, 0, 0.3), "neck": Vector3(-0.4, 0, 0.3), "kn_l": Vector3(-1.6, 0, 0), "kn_r": Vector3(-1.4, 0, 0),
		"hip_l": Vector3(1.3, 0, 0.2), "hip_r": Vector3(1.1, 0, -0.2), "sh_l": Vector3(-0.4, 0, 0.8), "sh_r": Vector3(-0.3, 0, -0.9), "jaw": Vector3(0.6, 0, 0)}
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(body, "position:y", -0.5, 0.9).set_delay(0.3)
	died.emit(self)

# ------------------------------------------------------------------ objectives
func _work(delta: float) -> void:
	var o: Dictionary = memory.get("obj", {})
	if not _station or not is_instance_valid(_station):
		var kinds: Array = o.get("stations", [])
		if kinds.is_empty(): _stop(); return
		var kind: String = kinds[_work_i % kinds.size()] if o.get("order", "loop") == "loop" else kinds[randi() % kinds.size()]
		var opts: Array = Station.find(get_tree(), kind)
		opts = opts.filter(func(s): return s.busy_by == null or s.busy_by == self)
		if opts.is_empty(): _work_i += 1; _stop(); return
		opts.sort_custom(func(a2, b2): return a2.global_position.distance_to(global_position) < b2.global_position.distance_to(global_position))
		_station = opts[0]; _station.busy_by = self; _station_t = 0.0
	if global_position.distance_to(_station.global_position) > 0.45:
		_go(_station.global_position, float(prof.get("speed", 1.1)), delta)
	else:
		_stop(); _face(_station.global_position - _station.global_basis.z, delta * 5.0)
		_station_t += delta
		if _station.noise_every > 0.0 and fmod(_station_t, _station.noise_every) < delta: Game.make_noise(_station.global_position, _station.noise)
		if _station.sound != "" and fmod(_station_t, 2.5) < delta: Sfx.play_at(_station.sound, _station.global_position + Vector3(0, 0.9, 0), _station.sound_db, randf_range(0.85, 1.1))
		if _station_t >= _station.secs:
			if level and level.has_method("station_done"): level.station_done(self, _station)
			_station.busy_by = null; _station = null; _work_i += 1

func _patrol(delta: float) -> void:
	var pts: Array = memory.get("obj", {}).get("points", [])
	if pts.is_empty(): _stop(); return
	var p: Vector3 = pts[_work_i % pts.size()]
	if global_position.distance_to(p) > 0.6: _go(p, float(prof.get("speed", 1.1)), delta)
	else:
		_stop(); _station_t += delta
		if _station_t > float(memory.get("obj", {}).get("wait", 2.0)): _station_t = 0.0; _work_i += 1

func _carry(delta: float) -> void:
	var o: Dictionary = memory.get("obj", {})
	var want: String = String(o.get("to")) if _carrying != "" else String(o.get("from"))
	var opts: Array = Station.find(get_tree(), want)
	if opts.is_empty(): _stop(); return
	var s: Station = opts[0]
	if global_position.distance_to(s.global_position) > 0.5: _go(s.global_position, float(prof.get("speed", 1.1)), delta)
	else:
		_stop(); _face(s.global_position - s.global_basis.z, delta * 5.0)
		_station_t += delta
		if s.sound != "" and fmod(_station_t, 2.0) < delta: Sfx.play_at(s.sound, s.global_position + Vector3(0, 0.8, 0), s.sound_db, randf_range(0.8, 1.0))
		if _station_t > s.secs:
			_station_t = 0.0
			if _carrying == "": _carrying = s.item if s.item != "" else "it"
			else:
				if level and level.has_method("delivered"): level.delivered(self, s, _carrying)
				_carrying = ""

func _push(delta: float) -> void:
	var o: Dictionary = memory.get("obj", {})
	if not is_instance_valid(_push_body):
		_push_body = null
		var best: RigidBody3D = null; var bd := 8.0
		for b in get_tree().get_nodes_in_group("pushable"):
			var d: float = b.global_position.distance_to(global_position)
			if d < bd and absf(b.global_position.y - global_position.y) < 1.0: bd = d; best = b
		if not best: _stop(); return
		_push_body = best; memory["push_to"] = (o.get("to", [global_position]) as Array).pick_random()
	var to: Vector3 = memory.get("push_to", global_position)
	var b2 := _push_body
	if b2.global_position.distance_to(to) < 0.6: _push_body = null; _stop(); return
	# get behind it, then lean into it
	var dir := (to - b2.global_position) * Vector3(1, 0, 1)
	var behind: Vector3 = b2.global_position - dir.normalized() * 0.75
	if global_position.distance_to(behind) > 0.5: _go(behind, float(prof.get("speed", 1.1)), delta)
	else:
		_face(b2.global_position, delta * 6.0)
		if b2.has_method("wake"): b2.wake()
		b2.apply_central_force(dir.normalized() * 60.0 * b2.mass)
		velocity = dir.normalized() * 0.5; move_and_slide()
		if fmod(_anim_t, 1.4) < delta:
			Sfx.play_at("scrape", b2.global_position + Vector3(0, 0.3, 0), -2.0, randf_range(0.7, 0.9))
			Game.make_noise(b2.global_position, 0.45)

## The darkest walkable spot it knows of nearby (fleeing the light).
func _darkest_near() -> Vector3:
	if level and level.has_method("dark_spot_near"): return level.dark_spot_near(global_position)
	return global_position - (player.global_position - global_position).normalized() * 4.0

# ------------------------------------------------------------------ moving
func _go(p: Vector3, speed: float, delta: float) -> void:
	_goal = p
	if agent.target_position.distance_to(p) > 0.3: agent.target_position = p
	var next := agent.get_next_path_position()
	var d := next - global_position; d.y = 0.0
	if d.length() < 0.05:
		d = (p - global_position) * Vector3(1, 0, 1)
	velocity.x = d.normalized().x * speed; velocity.z = d.normalized().z * speed
	velocity.y = -3.0 if not is_on_floor() else -0.5
	_open_doors()
	move_and_slide()
	_face(global_position + d, delta * 7.0)
	_walk += delta * speed * 4.0
	if _unstick > 0.0:
		# caught on a door frame or a corner: a step to the side, then find the way again
		_unstick -= delta
		velocity = _unstick_dir * speed * 0.8; velocity.y = -0.5; move_and_slide()
		if _unstick <= 0.0: agent.target_position = p + Vector3(0.01, 0, 0)
	elif global_position.distance_to(_last_pos) < speed * delta * 0.15:
		_stuck += delta
		if _stuck > 0.8:
			_stuck = 0.0; _unstick = 0.45
			var side := Vector3(-d.z, 0, d.x).normalized() * (1.0 if randf() < 0.5 else -1.0)
			_unstick_dir = (side - d.normalized() * 0.5).normalized()
			_stuck_count += 1
			if _stuck_count > 6: _stuck_count = 0; _think = 0.0; objective = ""; _leave()
	else: _stuck = 0.0; _stuck_count = maxi(0, _stuck_count - 1) if randf() < 0.01 else _stuck_count
	_last_pos = global_position

func _stop() -> void:
	velocity.x = 0.0; velocity.z = 0.0
	velocity.y = -3.0 if not is_on_floor() else -0.5
	move_and_slide()

func _face(p: Vector3, k: float) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() < 0.01: return
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), clampf(k, 0.0, 1.0))

## Doors in the way open (the super's keys open locked ones).
func _open_doors() -> void:
	for d in get_tree().get_nodes_in_group("door"):
		if d.is_open or d.global_position.distance_to(global_position) > 1.3: continue
		if d.locked and not prof.get("keys", false): continue
		if d.get("blocked"): continue
		d.set_open(true)
		Sfx.play_at("door_creak", d.global_position + Vector3(0, 1, 0), -10.0, randf_range(0.8, 1.0))

func _hazards(delta: float) -> void:
	for hz in get_tree().get_nodes_in_group("hazard"):
		if hz.has_method("hurts") and hz.hurts(global_position):
			take_hit(float(hz.get("dps")) * delta, hz.global_position, null)

# ------------------------------------------------------------------ the body
func _say(what: String) -> void:
	var v: String = String(prof.get("voice", "marta_breath"))
	match what:
		"attack": Sfx.play_at(String(prof.get("voice_attack", "marta_rattle")), eye(), -2.0, randf_range(0.7, 0.9))
		"die": Sfx.play_at(String(prof.get("voice_die", "groan")), eye(), 0.0, randf_range(0.8, 1.0))
		_: Sfx.play_at(v, eye(), -8.0, randf_range(0.8, 1.0))

func _sounds(delta: float) -> void:
	_sound_t -= delta
	if _sound_t <= 0.0:
		_sound_t = randf_range(4.0, 9.0) * float(prof.get("voice_every", 1.0))
		if objective in ["attack", "hunt", "defend", "hunt_kurt"]: _sound_t *= 0.4
		_say("idle")
	# footsteps: bare, wet, heavy, or the scrabble of the ones in the walls
	if velocity.length() > 0.3 and fmod(_walk, PI) < 0.08:
		Sfx.play_at(String(prof.get("step", "step_flesh")), global_position, -12.0 + velocity.length() * 2.0, randf_range(0.7, 0.9))

func _animate(_delta: float) -> void:
	var P := body.pose
	var w := _walk
	var moving := Vector2(velocity.x, velocity.z).length() > 0.2
	var hunch: float = float(prof.get("body", {}).get("hunch", 0.0))
	for k in P: P[k] = Vector3.ZERO
	P.spine = Vector3(-hunch, 0, 0)
	if _stagger > 0.0:
		body.snap = 14.0
		P.spine = Vector3(0.35, sin(_anim_t * 13.0) * 0.3, sin(_anim_t * 9.0) * 0.3); P.head = Vector3(-0.6, 0, 0.4)
		P.sh_l = Vector3(-0.6, 0, 0.9); P.sh_r = Vector3(-0.6, 0, -0.9); P.jaw = Vector3(0.7, 0, 0)
		return
	body.snap = 12.0
	if moving:
		var a := 0.6 if velocity.length() > 2.0 else 0.4
		P.hip_l = Vector3(sin(w) * a, 0, 0); P.hip_r = Vector3(-sin(w) * a, 0, 0)
		P.kn_l = Vector3(-maxf(0.0, -cos(w)) * a * 1.6, 0, 0); P.kn_r = Vector3(-maxf(0.0, cos(w)) * a * 1.6, 0, 0)
		P.sh_l = Vector3(-sin(w) * a * 0.6, 0, 0.08); P.sh_r = Vector3(sin(w) * a * 0.6, 0, -0.08)
		P.spine += Vector3(-0.1 * velocity.length() / 2.5, sin(w) * 0.06, 0)
	if _windup > 0.0:
		# the telegraph: arms back, head down, the mouth opening
		P.sh_l = Vector3(-1.4, 0, 0.5); P.sh_r = Vector3(-1.4, 0, -0.5); P.el_l = Vector3(-0.9, 0, 0); P.el_r = Vector3(-0.9, 0, 0)
		P.spine += Vector3(0.3, 0, 0); P.jaw = Vector3(0.9, 0, 0)
	elif _attack_t > float(prof.get("attack", {}).get("cool", 1.4)) - 0.25:
		# the blow
		P.sh_l = Vector3(1.6, 0, 0.1); P.sh_r = Vector3(1.6, 0, -0.1); P.spine += Vector3(-0.5, 0, 0); P.jaw = Vector3(1.1, 0, 0)
	elif _station and not moving:
		var act := _station.activity
		var t := _anim_t
		match act:
			"stir", "work":
				P.sh_r = Vector3(0.9 + sin(t * 5.0) * 0.25, 0, -0.1); P.el_r = Vector3(-0.6, 0, 0)
				P.sh_l = Vector3(0.7 + cos(t * 4.0) * 0.15, 0, 0.1); P.el_l = Vector3(-0.8, 0, 0); P.spine += Vector3(-0.25, 0, 0); P.head = Vector3(-0.3, 0, 0)
			"scrub":
				P.sh_l = Vector3(1.3, sin(t * 7.0) * 0.4, 0); P.sh_r = Vector3(1.3, -sin(t * 7.0) * 0.4, 0); P.spine += Vector3(-0.7, 0, 0)
			"feed":
				P.sh_l = Vector3(1.0 + sin(t * 1.5) * 0.3, 0, 0.2); P.sh_r = Vector3(1.0 + sin(t * 1.5 + 0.5) * 0.3, 0, -0.2); P.spine += Vector3(-0.8, 0, 0); P.head = Vector3(-0.4, 0, sin(t * 0.7) * 0.4)
			"bang":
				var hit := absf(sin(t * 3.0))
				P.sh_r = Vector3(1.6 * hit, 0, 0); P.el_r = Vector3(-0.3, 0, 0); P.head = Vector3(-0.2, 0, 0)
			"sit":
				P.hip_l = Vector3(1.4, 0, 0); P.hip_r = Vector3(1.4, 0, 0); P.kn_l = Vector3(-1.5, 0, 0); P.kn_r = Vector3(-1.5, 0, 0)
				P.sh_r = Vector3(0.6, 0, 0); P.el_r = Vector3(-1.0, 0, 0); P.head = Vector3(-0.2, sin(t * 0.3) * 0.3, 0)
			_:
				P.head = Vector3(0.0, sin(t * 0.4) * 0.6, 0)
	else:
		# standing: breathing, and the head going round slower than it should
		P.spine += Vector3(sin(_anim_t * 1.7) * 0.03, 0, 0)
		P.head = Vector3(-0.1, sin(_anim_t * 0.31) * 0.5, sin(_anim_t * 0.23) * 0.2)
		if objective == "investigate": P.head = Vector3(0.0, sin(_anim_t * 2.0) * 0.8, 0.6)    # listening
	if _carrying != "":
		P.sh_l = Vector3(0.8, 0, 0.3); P.sh_r = Vector3(0.8, 0, -0.3); P.el_l = Vector3(-1.2, 0, 0); P.el_r = Vector3(-1.2, 0, 0)
	if prof.get("twitch", true) and fmod(_anim_t, 3.7) < 0.12:
		P.head += Vector3(randf_range(-0.3, 0.3), randf_range(-0.6, 0.6), randf_range(-0.5, 0.5))
