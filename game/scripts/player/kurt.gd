class_name Kurt
extends CharacterBody3D
## Kurt Federov. Older, and it shows (he doesn't sprint for long), but he moves like someone who
## was trained to: he gets up onto things in one movement, he lands quietly, he weighs a thing
## before he throws it. Everything he does goes through here: moving, looking, what he's pointing
## at and what he can do to it, what's in his hand and in his pockets, his body, the revolver.

signal caught(by)
signal hurt_changed(hp: float)
signal reached(at: Vector3, verb: String)   ## his free hand goes out to something (the arm shows it)

const EYE := 1.62
const EYE_CROUCH := 1.0
const WALK := 1.75
const RUN := 3.7
const CROUCH := 0.95
const REACH := 1.9

var head: Node3D
var cam: Camera3D
var hand_anchor: Node3D            ## where carried things are held
var hp := 100.0
var stamina := 1.0
var crouching := false
var running := false
var frozen := false                ## the story has him (cutscene beats): no walking
var look_locked := false
var yaw := 0.0
var pitch := 0.0
var zone := -1
var level: Node                    ## the level: zone_of(), surface_of()
var target: Object = null          ## what he's looking at (has get_verbs)
var target_verbs: Array = []
var aim_point := Vector3.ZERO      ## where the look ray hit
var look_sway := Vector2.ZERO      ## how fast he's turning (the gun and the hand lag behind it)
var arm: FPArm
var held: Prop = null
var pockets: Array = []            ## [{id, title, desc, key}]
var gun_out := false
var rounds := 0                    ## in the cylinder
var weapon := "revolver"           ## or "shotgun" (Flat 48's safe)
var barrels := 0                   ## shells in the shotgun
var shells := 0
var spare := 0                     ## loose rounds
var aiming := false
var hiding_in: Node = null
var rail_axis := Vector3.ZERO     ## on a ledge: he can only shuffle along this (and slowly)
var climbing := false             ## a scripted climb (over a rail, through a window) has him
var _bob := 0.0
var _step_d := 0.0
var _eye := EYE
var _kick_cam := 0.0
var _mantle_t := -1.0
var _mantle_from := Vector3.ZERO
var _mantle_to := Vector3.ZERO
var _land_v := 0.0
var _regen_t := 0.0
var _shock_t := 0.0
var _fire_cd := 0.0
var _reload_t := 0.0

func _init() -> void:
	collision_layer = 16
	collision_mask = 1 | 2
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(48)
	add_to_group("kurt")
	add_to_group("shockable")

func build() -> void:
	var cs := CollisionShape3D.new(); cs.name = "Shape"
	var cap := CapsuleShape3D.new(); cap.radius = 0.28; cap.height = 1.75
	cs.shape = cap; cs.position.y = 0.875
	add_child(cs)
	head = Node3D.new(); head.name = "Head"; head.position.y = EYE
	add_child(head)
	cam = Camera3D.new(); cam.name = "Camera"; cam.fov = 72.0; cam.near = 0.03; cam.far = 90.0
	head.add_child(cam)
	cam.current = true
	Lights.camera = cam
	hand_anchor = Node3D.new(); hand_anchor.position = Vector3(0.12, -0.18, -0.62)
	cam.add_child(hand_anchor)
	Controls.pressed.connect(_on_pressed)
	World.register("kurt", _save, _load)
	_revolver()
	arm = FPArm.new(); arm.name = "Arm"
	cam.add_child(arm)
	arm.setup(self)

var gun_model: Node3D
var _recoil := 0.0

## The Nagant, low-poly, in his right hand: frame, cylinder, long barrel, a hand round the grip.
func _revolver() -> void:
	gun_model = Node3D.new(); gun_model.name = "Revolver"
	cam.add_child(gun_model)
	var k := Kit.new()
	var steel := Mats.tex(Tex.get_tex("metal"), -1, Color(0.55, 0.55, 0.6))
	var wood := Mats.tex(Tex.get_tex("floorboards"), -1, Color(0.9, 0.6, 0.45))
	var skin := Mats.tex(Tex.get_tex("skin_pale"), -1, Color(0.95, 0.8, 0.72))
	k.box(steel, Vector3(0, 0.02, -0.12), Vector3(0.022, 0.022, 0.2))        # barrel
	k.box(steel, Vector3(0, 0.0, -0.01), Vector3(0.042, 0.042, 0.045))      # cylinder
	k.box(steel, Vector3(0, 0.005, 0.025), Vector3(0.026, 0.05, 0.05))      # frame
	k.box(wood, Vector3(0, -0.05, 0.05), Vector3(0.028, 0.08, 0.035), Basis(Vector3.RIGHT, 0.35))
	k.box(skin, Vector3(0.006, -0.055, 0.06), Vector3(0.05, 0.075, 0.06), Basis(Vector3.RIGHT, 0.35))   # the hand
	k.box(Mats.tex(Tex.get_tex("cloth"), -1, Color(0.35, 0.33, 0.3)), Vector3(0.02, -0.1, 0.2), Vector3(0.08, 0.08, 0.25), Basis(Vector3.RIGHT, 0.5))  # the sleeve
	for mi in k.commit(gun_model, "Gun"):
		var m := (mi.material_override as ShaderMaterial).duplicate() as ShaderMaterial
		m.set_shader_parameter("snap", 0.0); m.set_shader_parameter("ambient", Vector3(0.28, 0.26, 0.25))
		mi.material_override = m
	gun_model.visible = false

# ------------------------------------------------------------------------------------- moving
func _physics_process(delta: float) -> void:
	delta = minf(delta, 0.05)
	if _mantle_t >= 0.0:
		_mantle(delta); return
	if climbing: return
	# look
	var lk := Controls.take_look()
	look_sway = look_sway.lerp(Vector2(clampf(lk.x / maxf(delta, 0.001) * 0.004, -0.06, 0.06), clampf(lk.y / maxf(delta, 0.001) * 0.004, -0.05, 0.05)), minf(delta * 10.0, 1.0))
	if not look_locked:
		yaw -= lk.x
		pitch = clampf(pitch - lk.y, -1.45, 1.4)
	rotation.y = yaw
	var fo: Array = Feel.offset()
	head.rotation.x = pitch + _kick_cam + fo[0].x
	cam.rotation = Vector3(0, fo[0].y, fo[0].z)
	cam.position = fo[1]
	_kick_cam = move_toward(_kick_cam, 0.0, delta * 1.6)
	# the body
	var g := GravityZone.gravity_at(global_position + Vector3(0, 0.9, 0))
	if g.length() < 1.4: g = Vector3.DOWN * 1.4         # where nothing weighs anything, he still does, a little
	up_direction = -g.normalized()
	var wish := Vector3.ZERO
	if not frozen and hiding_in == null:
		var m := Controls.move
		wish = (global_transform.basis * Vector3(m.x, 0, -m.y))
		wish.y = 0
	var water := WaterBody.depth_anywhere(global_position + Vector3(0, 0.02, 0))
	_auto_duck(wish)
	var want_crouch := crouching
	_eye = move_toward(_eye, EYE_CROUCH if want_crouch else EYE, delta * 3.2)
	head.position.y = _eye
	(get_node("Shape") as CollisionShape3D).shape.height = lerpf(1.1, 1.75, (_eye - EYE_CROUCH) / (EYE - EYE_CROUCH))
	(get_node("Shape") as CollisionShape3D).position.y = (get_node("Shape") as CollisionShape3D).shape.height * 0.5
	running = Controls.is_down("run") and wish.length() > 0.6 and not crouching and stamina > 0.05
	var lungs := 1.6 if Progress.has("deep_lungs") else 1.0
	if running:
		stamina = maxf(stamina - delta / (7.0 * lungs), 0.0)
	else:
		stamina = minf(stamina + delta / (5.0 / lungs), 1.0)
	var speed := RUN if running else (CROUCH if crouching else WALK)
	speed *= lerpf(1.0, 0.45, clampf(water / 0.6, 0.0, 1.0))
	if held and held.mass > 15.0: speed *= 0.6
	if hiding_in: speed = 0.0
	if rail_axis != Vector3.ZERO:
		# back to the wall, shuffling: only along it, and not fast
		wish = rail_axis * wish.dot(rail_axis)
		speed = minf(speed, 0.7)
	var hv := velocity - up_direction * velocity.dot(up_direction)
	var target_v := wish.limit_length(1.0) * speed
	var accel := 10.0 if is_on_floor() else 2.5
	hv = hv.move_toward(target_v, accel * delta * maxf(speed, 1.0))
	var vv := up_direction * velocity.dot(up_direction)
	if not is_on_floor():
		vv += g * delta
	velocity = hv + vv
	var was_air := not is_on_floor()
	var fall_v := velocity.dot(up_direction)
	move_and_slide()
	if was_air and is_on_floor() and fall_v < -4.0:
		_land(fall_v)
	_push_things()
	# footsteps
	var moved := hv.length() * delta
	if is_on_floor() and moved > 0.0:
		_step_d += moved
		_bob += moved * 5.2
		var stride := 0.75 if not running else 1.05
		if _step_d > stride:
			_step_d = 0.0
			_footstep(water)
	head.position.x = sin(_bob * 0.5) * 0.012 * (1.0 if running else 0.5)
	head.position.y = _eye + absf(cos(_bob * 0.5)) * 0.018 * (1.6 if running else 0.8)
	# where he is
	if level and level.has_method("zone_of"):
		var z: int = level.zone_of(global_position + Vector3(0, 0.5, 0))
		if z != zone:
			zone = z
			Lights.cam_zone = z
	_aim()
	_carry(delta)
	_body(delta)

## He ducks into a low opening without being told (and stands again once there's room).
var _ducked := false
func _auto_duck(wish: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	if wish.length() > 0.2:
		var fwd := wish.normalized()
		var hi := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.5, 0), global_position + Vector3(0, 1.5, 0) + fwd * 0.55, 1)
		var lo := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.8, 0), global_position + Vector3(0, 0.8, 0) + fwd * 0.75, 1)
		hi.exclude = [get_rid()]; lo.exclude = [get_rid()]
		if not crouching and not space.intersect_ray(hi).is_empty() and space.intersect_ray(lo).is_empty():
			crouching = true; _ducked = true
			return
	if _ducked and crouching:
		var up := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.0, 0), global_position + Vector3(0, 1.9, 0), 1)
		up.exclude = [get_rid()]
		if space.intersect_ray(up).is_empty():
			crouching = false; _ducked = false

func _footstep(water: float) -> void:
	var loud := 7.0 if running else (1.2 if crouching else 3.2)
	if Progress.has("quiet_feet"): loud *= 0.5
	var snd := "step_wood"
	if water > 0.03:
		snd = "step_water"; loud += 4.0
		var w := WaterBody.at(global_position)
		if w: w.splash(global_position, 0.5 if not running else 1.0)
	elif level and level.has_method("surface_of"):
		snd = level.surface_of(global_position)
	Audio.play(snd, global_position, -14.0 + loud * 1.2, randf_range(0.9, 1.1))
	Noises.make(global_position, loud, "step", self)

func _land(v: float) -> void:
	var hard := clampf((-v - 4.0) / 6.0, 0.0, 1.0)
	Audio.play("thud", global_position, -8.0 + hard * 8.0)
	Noises.make(global_position, 4.0 + hard * 10.0, "land", self)
	_kick_cam = -0.05 - hard * 0.08
	Feel.shake(0.1 + hard * 0.45)
	if hard > 0.6: hurt(hard * 25.0, null)

## Kurt doesn't stop for clutter: light things he walks into are kicked clear (a noise); heavier
## ones are nudged; the wake-up is what gets the whole pile moving.
func _push_things() -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var o := c.get_collider()
		if o is Prop and o != held:
			var p := o as Prop
			p.wake()
			var dir := -c.get_normal(); dir.y = 0.15
			var k := 1.6 if p.mass < 3.0 else 0.5
			if p.mass < 45.0:
				p.apply_central_impulse(dir.normalized() * minf(p.mass, 12.0) * k * velocity.length() * 0.25)

func jump() -> void:
	if frozen or hiding_in: return
	if _try_mantle(): return
	if is_on_floor():
		velocity += up_direction * (4.1 if not crouching else 3.0)
		crouching = false
		Audio.play("step_soft", global_position, -10.0)

## Up onto anything between knee and chest height in front of him, in one movement.
func _try_mantle() -> bool:
	var space := get_world_3d().direct_space_state
	var fwd := -global_transform.basis.z; fwd.y = 0; fwd = fwd.normalized()
	for h in [1.45, 1.2, 0.95, 0.7]:
		var top := global_position + Vector3(0, h + 0.4, 0) + fwd * 0.55
		var q := PhysicsRayQueryParameters3D.create(top, top - Vector3(0, 0.75, 0), 1 | 2)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty(): continue
		var land: Vector3 = hit.position
		var rise := land.y - global_position.y
		if rise < 0.45 or rise > 1.5: continue
		# room to stand (or crouch) up there?
		var sq := PhysicsShapeQueryParameters3D.new()
		var cap := CapsuleShape3D.new(); cap.radius = 0.25; cap.height = 1.05
		sq.shape = cap; sq.transform = Transform3D(Basis(), land + Vector3(0, 0.6, 0)); sq.collision_mask = 1 | 2
		sq.exclude = [get_rid()]
		if not space.intersect_shape(sq, 1).is_empty(): continue
		var tall := PhysicsShapeQueryParameters3D.new(); var c2 := CapsuleShape3D.new(); c2.radius = 0.25; c2.height = 1.7
		tall.shape = c2; tall.transform = Transform3D(Basis(), land + Vector3(0, 0.9, 0)); tall.collision_mask = 1 | 2; tall.exclude = [get_rid()]
		crouching = not space.intersect_shape(tall, 1).is_empty()
		_mantle_from = global_position
		_mantle_to = land + Vector3(0, 0.02, 0)
		_mantle_t = 0.0
		velocity = Vector3.ZERO
		Audio.play("step_soft", land, -8.0)
		Noises.make(land, 2.5, "mantle", self)
		World.emit_event("mantled", {"h": rise})
		return true
	return false

## Over a rail, through a window: along `points` (world positions of his feet) in `dur` seconds,
## crouched if `low`. Returns when he's there.
func climb(points: Array, dur := 1.2, low := false) -> void:
	if climbing: return
	climbing = true
	velocity = Vector3.ZERO
	if held: drop(false)
	if gun_out: holster()
	var was := crouching
	crouching = low
	if low: _eye = EYE_CROUCH; head.position.y = _eye
	var path: Array = [global_position] + points
	var seg := dur / float(path.size() - 1)
	for i in range(1, path.size()):
		var t := create_tween()
		t.tween_property(self, "global_position", path[i], seg).set_trans(Tween.TRANS_SINE)
		Audio.play("step_soft", path[i], -10.0, randf_range(0.8, 1.1))
		await t.finished
	Noises.make(global_position, 2.0, "climb", self)
	crouching = was and low
	climbing = false
	World.emit_event("climbed", {"to": global_position})

func _mantle(delta: float) -> void:
	_mantle_t += delta / 0.42
	var t := clampf(_mantle_t, 0.0, 1.0)
	var up := smoothstep(0.0, 0.6, t)
	var fw := smoothstep(0.35, 1.0, t)
	global_position = Vector3(lerpf(_mantle_from.x, _mantle_to.x, fw), lerpf(_mantle_from.y, _mantle_to.y, up), lerpf(_mantle_from.z, _mantle_to.z, fw))
	head.rotation.x = pitch - sin(t * PI) * 0.12
	if t >= 1.0: _mantle_t = -1.0

# ------------------------------------------------------------------------------- interacting
func _aim() -> void:
	target = null
	target_verbs = []
	if frozen and not get_meta("allow_use", false):
		_labels(); return
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 8)
	q.exclude = [get_rid()] + ([held.get_rid()] if held else [])
	q.collide_with_areas = true
	var hit := space.intersect_ray(q)
	if hit:
		aim_point = hit.position
		var o = hit.collider
		var actor = o.get_meta("actor") if o.has_meta("actor") else o
		if actor and actor.has_method("get_verbs"):
			target = actor
			target_verbs = actor.get_verbs(self)
			if held and actor.has_method("hold_verbs"):
				target_verbs = actor.hold_verbs(self, held) + target_verbs
	elif Progress.has("the_pull") and not held:
		# want a thing hard enough and it comes: six metres
		var q2 := PhysicsRayQueryParameters3D.create(from, from - cam.global_transform.basis.z * 6.0, 2)
		q2.exclude = [get_rid()]
		var h2 := space.intersect_ray(q2)
		if h2 and h2.collider is Prop and can_lift(h2.collider):
			target = h2.collider
			target_verbs = [{"id": "_pull", "label": "Pull"}]
	if held:
		# with something in his hand: what it's for here first; else whatever he's looking at (one
		# hand's enough for a door or a switch); else put it down / throw it
		var hv: Array = [{"id": "_drop", "label": "Put down"}, {"id": "_throw", "label": "Throw"}]
		if target_verbs.size() > 0 and target_verbs[0].get("held", false):
			hv = [target_verbs[0], {"id": "_drop", "label": "Put down"}]
		elif target_verbs.size() > 0 and not (target is Prop):
			hv = [target_verbs[0], {"id": "_drop", "label": "Put down"}]
		target_verbs = hv
	_labels()

func _labels() -> void:
	Controls.labels.use = String(target_verbs[0].label) if target_verbs.size() > 0 else ""
	Controls.labels.alt = String(target_verbs[1].label) if target_verbs.size() > 1 else ""
	Controls.show.use = target_verbs.size() > 0
	Controls.show.alt = target_verbs.size() > 1
	Controls.show.fire = gun_out
	Controls.show.aim = gun_out
	Controls.show.reload = gun_out and ((weapon == "revolver" and rounds < 7 and spare > 0) or (weapon == "shotgun" and barrels < 2 and shells > 0))
	Controls.show.bag = pockets.size() > 0 or gun_out
	Controls.show.socko = World.flag("socko_on")
	Controls.show.skills = World.flag("socko_on")
	Controls.show.torch = World.flag("socko_on")

func use_verb(i: int) -> void:
	if i >= target_verbs.size(): return
	var v: Dictionary = target_verbs[i]
	var id := String(v.id)
	Log.mark("verb %s %s" % [id, str(target.get("key") if target and "key" in target else (target.get("id") if target and "id" in target else ""))])
	match id:
		"_drop": drop(false)
		"_throw": drop(true)
		"_pull":
			var p := target as Prop
			p.wake()
			p.linear_velocity = (cam.global_position - p.global_position).normalized() * 7.0 + Vector3.UP * 1.5
			Audio.play("pressure", p.global_position, -6.0, 2.0)
			hurt(3.0, "pull")
			World.emit_event("pulled", {"prop": p})
		_:
			if target:
				reached.emit(aim_point, id)
				World.emit_event("used", {"verb": id})
				target.act(id, self)

func _on_pressed(a: String) -> void:
	if get_tree().paused: return
	match a:
		"use": use_verb(0)
		"alt": use_verb(1)
		"jump": jump()
		"crouch": crouching = not crouching
		"fire":
			if gun_out: fire()
			elif held: drop(true)
		"aim": aiming = not aiming if gun_out else false
		"reload": reload()

# --------------------------------------------------------------------------------- the hand
func can_lift(p: Prop) -> bool:
	return p.mass <= (60.0 if Progress.has("coral_grip") else 25.0)

func lift(p: Prop) -> void:
	if held: drop(false)
	if gun_out: holster()
	p.wake()
	held = p; p.held = true
	p.collision_layer = 0
	p.gravity_scale = 0.0
	p.linear_damp = 6.0; p.angular_damp = 6.0
	Audio.play("pickup", p.global_position, -8.0)
	World.emit_event("lifted", {"prop": p, "key": p.key})

func drop(throw: bool) -> void:
	if not held: return
	var p := held
	held = null; p.held = false
	p.collision_layer = 2
	p.gravity_scale = 1.0
	p.linear_damp = 0.05; p.angular_damp = 0.4
	if throw:
		var bow := 1.45 if Progress.has("the_bow") else 1.0
		var dir := -cam.global_transform.basis.z
		if Progress.has("the_bow"): dir = (dir + Vector3(0, 0.05, 0)).normalized()
		var spd := clampf(11.0 / sqrt(maxf(p.mass, 0.3)), 2.0, 13.0) * bow
		p.linear_velocity = dir * spd + velocity * 0.5
		p.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
		Audio.play("step_soft", global_position, -10.0, 1.4)
		World.emit_event("thrown", {"prop": p, "key": p.key})
	else:
		p.linear_velocity = velocity * 0.5
	if p.has_meta("pocket_id"):
		pass

func _carry(_delta: float) -> void:
	if not held: return
	if not is_instance_valid(held):
		held = null; return
	var want := hand_anchor.global_transform.origin
	if held.mass > 8.0: want = cam.global_position - cam.global_transform.basis.z * 0.9 + Vector3(0, -0.55, 0)
	var err := want - held.global_position
	if err.length() > 1.6:
		drop(false); return
	held.linear_velocity = err * 14.0
	var basis_want := Basis(Vector3.UP, yaw)
	var q := (basis_want * held.global_transform.basis.inverse()).get_rotation_quaternion()
	held.angular_velocity = q.get_axis() * q.get_angle() * 6.0 if q.get_angle() > 0.001 else Vector3.ZERO

# ------------------------------------------------------------------------------------ pockets
func has_item(id: String) -> bool:
	if id == "": return false
	for p in pockets:
		if p.id == id: return true
	if held and held.item == id: return true
	return false

func pocket(p: Prop) -> void:
	pockets.append({"id": p.item, "title": p.title, "desc": p.desc, "key": p.key, "mass": p.mass})
	Audio.play("pickup", p.global_position, -6.0)
	World.set_flag("took_" + p.item)
	World.emit_event("pocketed", {"item": p.item, "key": p.key})
	if p == held: held = null
	p.queue_free()

func give_item(id: String, title: String, desc := "") -> void:
	pockets.append({"id": id, "title": title, "desc": desc, "key": id, "mass": 0.1})
	World.set_flag("took_" + id)
	World.emit_event("pocketed", {"item": id, "key": id})

func take_item(id: String) -> Dictionary:
	for i in pockets.size():
		if pockets[i].id == id:
			var d: Dictionary = pockets[i]
			pockets.remove_at(i)
			return d
	return {}

## Takes something out of a pocket and into his hand (to hold it out, place it, throw it).
func hold_from_pocket(id: String) -> void:
	var d := take_item(id)
	if d.is_empty(): return
	if held: drop(false)
	var p := Prop.make(get_parent(), hand_anchor.global_transform, Vector3(0.12, 0.08, 0.2), float(d.get("mass", 0.3)))
	p.key = String(d.key); p.item = String(d.id); p.title = String(d.title); p.desc = String(d.get("desc", ""))
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.12, 0.08, 0.2); mi.mesh = bm
	mi.material_override = Mats.flat(Items.colour(p.item), -1)
	p.add_child(mi)
	lift(p)

# ------------------------------------------------------------------------------- reading etc
func read_doc(doc: String, title: String) -> void:
	World.emit_event("read", {"doc": doc, "title": title})

func look_at_thing(title: String, desc: String, key: String) -> void:
	World.emit_event("looked", {"title": title, "desc": desc, "key": key})

# -------------------------------------------------------------------------------- the body
func hurt(amount: float, by) -> void:
	hp = maxf(hp - amount, 0.0)
	_regen_t = 6.0
	_kick_cam = 0.06
	Feel.shake(clampf(amount / 30.0, 0.15, 0.8))
	Feel.fov_punch(-4.0)
	Audio.play("hit", global_position, -4.0)
	hurt_changed.emit(hp)
	World.emit_event("hurt", {"amount": amount, "by": by, "hp": hp})

func shock(delta: float, _w) -> void:
	_shock_t += delta
	if _shock_t > 0.25:
		_shock_t = 0.0
		hurt(9.0, "current")
		_kick_cam = randf_range(-0.04, 0.04)

func _body(delta: float) -> void:
	if _regen_t > 0.0: _regen_t -= delta
	elif hp < 100.0:
		hp = minf(hp + delta * 4.0, 100.0)
		hurt_changed.emit(hp)
	_fire_cd = maxf(_fire_cd - delta, 0.0)
	if _reload_t > 0.0:
		_reload_t -= delta
		if _reload_t <= 0.0 and spare > 0 and rounds < 7:
			rounds += 1; spare -= 1
			Audio.play("reload", global_position, -8.0)
			if rounds < 7 and spare > 0: _reload_t = 0.55 if not Progress.has("quick_reload") else 0.28
	var base_fov := 50.0 if aiming else (77.0 if running and velocity.length() > 2.5 else 72.0)
	cam.fov = lerpf(cam.fov, base_fov, minf(delta * 6.0, 1.0)) + Feel.fov_kick * minf(delta * 30.0, 1.0)
	gun_model.visible = gun_out
	_recoil = move_toward(_recoil, 0.0, delta * 4.0)
	var bob := sin(_bob * 0.5) * 0.006
	var rest := Vector3(0.02, -0.11, -0.3) if aiming else Vector3(0.16, -0.17 + bob, -0.36)
	if _reload_t > 0.0: rest += Vector3(-0.06, -0.04, 0.05)
	var sway := Vector3(-look_sway.x, look_sway.y, 0.0) * (0.35 if aiming else 1.0)
	var move_bob := Vector3(sin(_bob * 0.5) * 0.008, -absf(cos(_bob * 0.5)) * 0.006, 0.0) * (0.3 if aiming else 1.0)
	gun_model.position = gun_model.position.lerp(rest + sway + move_bob + Vector3(0, _recoil * 0.03, _recoil * 0.06), minf(delta * 14.0, 1.0))
	gun_model.rotation = Vector3(_recoil * 0.4 + (0.5 if _reload_t > 0.0 else 0.0) + look_sway.y * 1.5, (0.05 if not aiming else 0.0) + look_sway.x * 2.0, (0.6 if _reload_t > 0.0 else 0.0) + look_sway.x * 1.2)

# -------------------------------------------------------------------------------- the revolver
func draw_gun(which := "") -> void:
	if which == "": which = "revolver" if has_item("revolver") else "shotgun"
	if not has_item(which): return
	weapon = which
	if held: drop(false)
	gun_out = true
	World.emit_event("gun_out", {})

func holster() -> void:
	gun_out = false; aiming = false

func reload() -> void:
	if gun_out and weapon == "shotgun":
		if barrels < 2 and shells > 0 and _reload_t <= 0.0:
			_reload_t = 0.9; Audio.play("reload", global_position, -6.0, 0.8)
			await get_tree().create_timer(0.9, false).timeout
			var n := mini(2 - barrels, shells); barrels += n; shells -= n
		return
	if gun_out and spare > 0 and rounds < 7 and _reload_t <= 0.0:
		_reload_t = 0.5

func fire() -> void:
	if not gun_out or _fire_cd > 0.0 or _reload_t > 0.0: return
	if weapon == "shotgun":
		_fire_shotgun(); return
	if rounds <= 0:
		Audio.play("dryfire", global_position, -4.0); _fire_cd = 0.3; return
	rounds -= 1
	_fire_cd = 0.45
	_kick_cam = 0.09
	_recoil = 1.0
	Feel.shake(0.3); Feel.fov_punch(3.0)
	Audio.play("gunshot", global_position, 2.0, randf_range(0.95, 1.05))
	Noises.make(global_position, 45.0, "gunshot", self)
	var from := cam.global_position
	var spread := 0.0 if aiming else 0.02
	var dir := (-cam.global_transform.basis.z + Vector3(randf_range(-spread, spread), randf_range(-spread, spread), 0)).normalized()
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 40.0, 1 | 2 | 4)
	q.collide_with_areas = true
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	World.emit_event("shot", {"hit": hit})
	if hit.is_empty(): return
	var o = hit.collider
	if o.has_meta("monster"):
		o.get_meta("monster").shot(String(o.get_meta("part")), self, hit.position)
		Feel.hitstop(0.06 if String(o.get_meta("part")) == "head" else 0.035)
		World.emit_event("hit_marker", {"head": String(o.get_meta("part")) == "head"})
	elif o is Prop:
		(o as Prop).wake()
		(o as Prop).apply_impulse(dir * 4.0, hit.position - (o as Prop).global_position)
		if (o as Prop).breakable: (o as Prop).shatter()
	elif o.has_meta("actor") and o.get_meta("actor").has_method("shot"):
		o.get_meta("actor").shot(hit.position, self)
	else:
		Audio.play("clink", hit.position, -4.0, 0.7)

## Two barrels, nine pellets each: up close it's the end of most things; across a room, a spray.
func _fire_shotgun() -> void:
	if barrels <= 0:
		Audio.play("dryfire", global_position, -4.0); _fire_cd = 0.3; return
	barrels -= 1
	_fire_cd = 0.35; _kick_cam = 0.16; _recoil = 1.4
	Feel.shake(0.5); Feel.fov_punch(5.0)
	Audio.play("gunshot", global_position, 5.0, 0.75)
	Noises.make(global_position, 55.0, "gunshot", self)
	var space := get_world_3d().direct_space_state
	var hit_m := {}
	for i in 9:
		var dir := (-cam.global_transform.basis.z + Vector3(randf_range(-0.07, 0.07), randf_range(-0.05, 0.05), randf_range(-0.07, 0.07))).normalized()
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + dir * 25.0, 1 | 2 | 4)
		q.collide_with_areas = true; q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty(): continue
		var o = hit.collider
		if o.has_meta("monster"):
			var m = o.get_meta("monster")
			var key := str(m.get_instance_id())
			if not hit_m.has(key):
				hit_m[key] = true
				m.shot(String(o.get_meta("part")), self, hit.position)
				if cam.global_position.distance_to(hit.position) < 3.0 and m.state != Monster.S.DEAD: m.shot("body", self, hit.position)
				Feel.hitstop(0.07)
				World.emit_event("hit_marker", {"head": String(o.get_meta("part")) == "head"})
		elif o is Prop:
			(o as Prop).wake(); (o as Prop).apply_impulse(dir * 2.0, hit.position - (o as Prop).global_position)
			if (o as Prop).breakable: (o as Prop).shatter()
		elif o.has_meta("actor") and o.get_meta("actor").has_method("shot"):
			o.get_meta("actor").shot(hit.position, self)
	World.emit_event("shot", {"shotgun": true})

# ---------------------------------------------------------------------------------- saving
func _save() -> Dictionary:
	return {"xf": global_transform, "yaw": yaw, "pitch": pitch, "hp": hp, "pockets": pockets, "rounds": rounds, "spare": spare, "gun": gun_out, "weapon": weapon, "barrels": barrels, "shells": shells}

func _load(d: Dictionary) -> void:
	global_transform = d.xf; yaw = float(d.yaw); pitch = float(d.pitch); hp = float(d.hp)
	pockets = d.get("pockets", []); rounds = int(d.get("rounds", 0)); spare = int(d.get("spare", 0)); gun_out = bool(d.get("gun", false)); weapon = String(d.get("weapon", "revolver")); barrels = int(d.get("barrels", 0)); shells = int(d.get("shells", 0))
