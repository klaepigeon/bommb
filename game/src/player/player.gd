class_name Player
extends CharacterBody3D
## Kurt. First person. Input arrives as intents (move_input, look_input, actions) from the touch
## layer, the keyboard/mouse or a gamepad, so every control scheme drives the same code.
##
## What he does makes noise, and noise is what Marta hunts by:
##   crouched steps ~1.2 m   walking ~4.5 m   running ~10 m   (radius at which she can hear)

signal verbs_changed(focus: Object, verbs: Array)
signal hold_progress(k: float, label: String)
signal mode_changed(mode: String)
signal hurt(amount: int)

const WALK := 1.7
const RUN := 3.3
const CROUCH := 0.85
const EYE := 1.62
const EYE_CROUCH := 0.98
const REACH := 2.2
const GRAVITY := 9.8

var inv := Inventory.new()
var level: Level
var head: Node3D
var camera: Camera3D
var arm: KurtArm
var socko: Socko
var kbody: KurtBody
var torch: SpotLight3D
var gun: Node = null              ## Revolver, once he has it

var move_input := Vector2.ZERO    ## x right, y forward (-1..1)
var look_input := Vector2.ZERO    ## radians this frame (yaw, pitch); consumed each frame
var running := false
var crouching := false
var locked := false               ## cutscenes: no walking
var look_locked := false
var mode := "normal"              ## normal | hidden | inspect | downed
var injury := 0
var focus: Object = null          ## the Interactable in reach and in view
var verbs: Array = []
var held: Prop = null
var hidden_in: Node = null
var teleport_lock := false
var torch_on := false
var noise_now := 0.0              ## radius of the last footstep (for the AI and the HUD meter)

var _pitch := 0.0
var _step_acc := 0.0
var _eye := EYE
var _hold_verb := {}
var _hold_t := 0.0
var _hold_focus: Object = null
var _inspect: Prop = null
var _inspect_from := Transform3D.IDENTITY
var _inspect_rot := Basis.IDENTITY
var _shock_t := 0.0
var _bob := 0.0
var _shake := 0.0
var _last_focus: Object = null
var _cap: CapsuleShape3D

func _ready() -> void:
	add_to_group("player")
	add_to_group("shockable")
	collision_layer = 4
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(50)
	var cs := CollisionShape3D.new(); _cap = CapsuleShape3D.new(); _cap.radius = 0.28; _cap.height = 1.75
	cs.shape = _cap; cs.position = Vector3(0, 0.875, 0); add_child(cs)
	head = Node3D.new(); head.name = "Head"; head.position = Vector3(0, EYE, 0); add_child(head)
	camera = Camera3D.new(); camera.name = "Camera"; camera.fov = 72.0; camera.near = 0.03; camera.far = 40.0
	head.add_child(camera)
	camera.make_current()
	# Kurt (preserved rigs): his right arm, the rest of him, and Socko on the left hand
	arm = KurtArm.new(); camera.add_child(arm); arm.build(); arm.body = self
	socko = Socko.new(); camera.add_child(socko); socko.build(); socko.body = self
	socko.visible = false
	socko.set_pose("hidden", 0.0)
	kbody = KurtBody.new(); kbody.name = "KurtBody"; add_child(kbody); kbody.setup(self)
	torch = SpotLight3D.new(); torch.name = "Torch"; torch.spot_range = 9.0; torch.spot_angle = 26.0
	torch.light_color = Color(1.0, 0.86, 0.62); torch.light_energy = 2.2; torch.spot_attenuation = 1.2
	torch.position = Vector3(0.12, -0.1, 0.0); torch.visible = false
	camera.add_child(torch)
	Perf.quality_changed.connect(_apply_quality)
	_apply_quality(Perf.current)

func _apply_quality(q: Dictionary) -> void:
	camera.far = float(q.get("far", 32.0))
	torch.shadow_enabled = bool(q.get("torch_shadow", false))

# ---------------------------------------------------------------------------------- movement

func _physics_process(delta: float) -> void:
	_look(delta)
	if mode == "hidden" or mode == "downed":
		velocity = Vector3.ZERO
		_update_focus()
		return
	var want := Vector3.ZERO
	if not locked and mode == "normal":
		var mi := move_input.limit_length(1.0)
		want = (global_transform.basis * Vector3(mi.x, 0, -mi.y))
	var spd := WALK
	if crouching:
		spd = CROUCH
	elif running and move_input.length() > 0.5:
		spd = RUN
	if held and held.mass > 4.0:
		spd *= 0.75
	spd *= pow(0.85, injury)
	var target := want * spd
	var accel := 10.0 if target.length() > velocity.length() else 12.0
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	# nudge light props he walks into
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var rb := c.get_collider() as RigidBody3D
		if rb and rb.mass < 8.0 and rb != held:
			rb.apply_central_impulse(-c.get_normal() * velocity.length() * 0.3 * rb.mass)
	# crouch: height, eye
	var want_eye := EYE_CROUCH if crouching else EYE
	if not crouching and _eye < EYE - 0.05 and _ceiling_blocked():
		want_eye = _eye
	_eye = move_toward(_eye, want_eye, delta * 2.8)
	_cap.height = clampf(_eye + 0.13, 1.1, 1.75)
	(get_child(0) as CollisionShape3D).position.y = _cap.height * 0.5
	# footsteps
	var hspeed := Vector2(velocity.x, velocity.z).length()
	_step_acc += hspeed * delta
	var stride := 0.6 if crouching else (0.95 if hspeed > WALK + 0.3 else 0.75)
	if _step_acc > stride and is_on_floor():
		_step_acc = 0.0
		_footstep(hspeed)
	_bob += hspeed * delta * 6.0
	var bob_y := sin(_bob) * 0.025 * clampf(hspeed / RUN, 0.0, 1.0)
	head.position = Vector3(sin(_bob * 0.5) * 0.012 * clampf(hspeed / RUN, 0, 1), _eye + bob_y, 0)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.0)
		head.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.04
	_update_focus()
	_update_hold(delta)
	_update_held(delta)
	_update_torch(delta)
	_shock_t = maxf(0.0, _shock_t - delta)

func _ceiling_blocked() -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.9, 0), global_position + Vector3(0, 1.8, 0), 1 | 2)
	q.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _look(_delta: float) -> void:
	if look_locked:
		look_input = Vector2.ZERO
		return
	if mode == "inspect" and _inspect:
		_inspect_rot = Basis(Vector3.UP, look_input.x * 2.0) * Basis(Vector3.RIGHT, look_input.y * 2.0) * _inspect_rot
		look_input = Vector2.ZERO
		return
	rotate_y(-look_input.x)
	_pitch = clampf(_pitch - look_input.y, deg_to_rad(-80), deg_to_rad(80))
	if mode == "hidden" and hidden_in:
		_pitch = clampf(_pitch, deg_to_rad(-30), deg_to_rad(25))
	head.rotation.x = _pitch
	look_input = Vector2.ZERO

func _footstep(hspeed: float) -> void:
	var surf := "wood"
	if level and level.current_room != "" and level.rooms.has(level.current_room):
		surf = String(level.rooms[level.current_room].surface)
	var radius := 1.2 if crouching else (10.0 if hspeed > WALK + 0.3 else 4.5)
	if injury > 0:
		radius *= 1.0 + 0.15 * injury           # a limp drags
	noise_now = radius
	var db := -16.0 if crouching else (-6.0 if radius > 8.0 else -11.0)
	Sfx.play_at("step_" + surf, global_position + Vector3(0, 0.05, 0), db, randf_range(0.92, 1.08), radius, "footstep", self)

# ---------------------------------------------------------------------------------- focus & verbs

func _update_focus() -> void:
	var f: Object = null
	if mode == "normal" and not held:
		var from := camera.global_position
		var to := from - camera.global_transform.basis.z * REACH
		var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 8 | 32)
		q.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			f = Interactable.find(hit.collider)
			if f and not (f as Interactable).enabled:
				f = null
	elif mode == "hidden":
		f = null
	var new_verbs: Array = []
	if held:
		new_verbs = _held_verbs()
	elif mode == "hidden":
		new_verbs = [Interactable.v("unhide", "Come out")]
	elif mode == "inspect":
		new_verbs = [Interactable.v("end_inspect", "Put it back")]
		if _inspect and _inspect.doc_id != "":
			new_verbs.append(Interactable.v("read_inspected", "Read"))
		if _inspect and _inspect.item_id != "":
			new_verbs.push_front(Interactable.v("take_inspected", "Take"))
	elif f:
		new_verbs = (f as Interactable).get_verbs(self)
	if f != _last_focus or JSON.stringify(_strip(new_verbs)) != JSON.stringify(_strip(verbs)):
		focus = f
		verbs = new_verbs
		_last_focus = f
		verbs_changed.emit(focus, verbs)

static func _strip(a: Array) -> Array:
	return a.map(func(x): return [x.id, x.label])

func _held_verbs() -> Array:
	var out := [Interactable.v("drop", "Put down"), Interactable.v("throw", "Throw", {"noise": 2.0}), Interactable.v("inspect_held", "Turn over")]
	if held and held.doc_id != "":
		out.append(Interactable.v("read_held", "Read"))
	return out

## the main action button: the first verb
func use_primary() -> void:
	if verbs.is_empty():
		return
	begin_verb(0)

## start a verb (index into verbs). Timed verbs run while held; end_verb() cancels.
func begin_verb(i: int) -> void:
	if i < 0 or i >= verbs.size():
		return
	var v: Dictionary = verbs[i]
	if float(v.get("time", 0.0)) > 0.0:
		_hold_verb = v
		_hold_t = 0.0
		_hold_focus = focus
		return
	_do(v)

func end_verb() -> void:
	if not _hold_verb.is_empty():
		_hold_verb = {}
		hold_progress.emit(-1.0, "")

func _update_hold(delta: float) -> void:
	if _hold_verb.is_empty():
		return
	if focus != _hold_focus or not is_instance_valid(_hold_focus):
		end_verb()
		return
	_hold_t += delta
	var dur := float(_hold_verb.time)
	var k := clampf(_hold_t / dur, 0.0, 1.0)
	(_hold_focus as Interactable).verb_progress(_hold_verb.id, k, self)
	if float(_hold_verb.get("noise", 0.0)) > 0.0 and fmod(_hold_t, 0.8) < delta:
		Events.noise.emit((_hold_focus as Interactable).focus_point(), float(_hold_verb.noise), "work", self)
	hold_progress.emit(k, String(_hold_verb.label))
	arm.rattle = 0.6
	if k >= 1.0:
		var v := _hold_verb
		_hold_verb = {}
		arm.rattle = 0.0
		hold_progress.emit(-1.0, "")
		_do(v)

func _do(v: Dictionary) -> void:
	var id := String(v.id)
	match id:
		"drop": drop()
		"throw": throw()
		"inspect_held": inspect(held)
		"read_held": Events.show_document.emit(held.doc_id)
		"unhide": unhide()
		"end_inspect": end_inspect()
		"read_inspected": Events.show_document.emit(_inspect.doc_id)
		"take_inspected":
			var p := _inspect
			end_inspect(false)
			p.iverb("take", self)
		_:
			if focus:
				var ff := focus as Interactable
				if float(v.get("noise", 0.0)) > 0.0 and float(v.get("time", 0.0)) <= 0.0:
					Events.noise.emit(ff.focus_point(), float(v.noise), "work", self)
				arm.set_pose("reach", 0.15)
				get_tree().create_timer(0.35).timeout.connect(func(): if arm.pose == "reach": arm.set_pose(_idle_pose(), 0.3))
				ff.do_verb(id, self)
	_last_focus = null      # verbs may have changed

func _idle_pose() -> String:
	if gun and gun.equipped:
		return "gun"
	if held:
		return "hold"
	return "down"

# ---------------------------------------------------------------------------------- holding

func hold(p: Prop) -> void:
	if held or p.is_heavy():
		return
	held = p
	p.held = true
	p.freeze = false
	p.reparent(level.dynamic_root() if level else get_parent())
	p.gravity_scale = 0.0
	p.add_collision_exception_with(self)
	p.sleeping = false
	arm.set_pose("hold", 0.25)
	Sfx.play("pickup", -8.0)
	Story.record("handled:" + p.display_name)

func _hold_point() -> Vector3:
	return camera.global_transform * Vector3(0.1, -0.18, -0.75)

func _update_held(_delta: float) -> void:
	if mode == "inspect" and _inspect:
		_inspect.global_transform = Transform3D(camera.global_transform.basis * _inspect_rot, camera.global_transform * Vector3(0, -0.02, -0.45))
		return
	if not held:
		return
	if not is_instance_valid(held):
		held = null
		return
	var d := _hold_point() - held.global_position
	if d.length() > 1.4:
		drop()
		return
	held.linear_velocity = (d * 14.0).limit_length(7.0)
	held.angular_velocity *= 0.6

func drop(gentle := true) -> Prop:
	if not held:
		return null
	var p := held
	held = null
	p.held = false
	p.gravity_scale = 1.0
	p.remove_collision_exception_with(self)
	if gentle:
		p.linear_velocity = velocity * 0.5
	arm.set_pose(_idle_pose(), 0.3)
	return p

func throw() -> void:
	var p := drop(false)
	if not p:
		return
	var dir := -camera.global_transform.basis.z + Vector3(0, 0.12, 0)
	var spd := clampf(10.0 / sqrt(maxf(p.mass, 0.2)), 3.0, 11.0)
	p.linear_velocity = dir.normalized() * spd + velocity
	p.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
	arm.set_pose("throw", 0.1)
	get_tree().create_timer(0.3).timeout.connect(func(): arm.set_pose(_idle_pose(), 0.3))
	Sfx.play("crawl", -14.0, 1.6)
	Story.record("threw:" + p.display_name)

func inspect(p: Prop) -> void:
	if not p or mode == "inspect":
		return
	if held == p:
		drop()
	_inspect = p
	_inspect_from = p.global_transform
	_inspect_rot = Basis.IDENTITY
	p.freeze = true
	p.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	set_mode("inspect")
	Story.record("clue.examined:" + p.display_name.to_lower())
	if p.inspect_text != "":
		Events.toast.emit(p.inspect_text)

func end_inspect(put_back := true) -> void:
	if not _inspect:
		set_mode("normal")
		return
	var p := _inspect
	_inspect = null
	if put_back and is_instance_valid(p):
		p.global_transform = _inspect_from
		p.freeze = false
	set_mode("normal")

func set_mode(m: String) -> void:
	mode = m
	_last_focus = null
	mode_changed.emit(m)

# ---------------------------------------------------------------------------------- hiding

func hide_in(spot: Node) -> void:
	if held:
		drop()
	hidden_in = spot
	spot.enter(self)
	collision_layer = 0
	set_mode("hidden")
	var t := create_tween()
	t.tween_property(head, "global_transform", spot.global_transform, 0.5).set_trans(Tween.TRANS_SINE)
	_pitch = 0.0
	crouching = spot.crouched

func unhide() -> void:
	if not hidden_in:
		return
	var spot := hidden_in
	hidden_in = null
	spot.leave()
	var out: Vector3 = spot.global_transform * spot.exit_pos
	out.y = level.room_floor(level.room_at(out + Vector3(0, 1, 0))) if level else out.y
	global_position = out
	head.transform = Transform3D(Basis.IDENTITY, Vector3(0, _eye, 0))
	collision_layer = 4
	crouching = false
	set_mode("normal")

func is_hidden() -> bool:
	return mode == "hidden"

# ---------------------------------------------------------------------------------- misc

func kick() -> void:
	if kbody:
		kbody.kick()

func teleport_by(off: Vector3, yaw := 0.0) -> void:
	teleport_lock = true
	global_position += off
	if held:
		held.global_position += off
	rotate_y(yaw)
	await get_tree().create_timer(0.6).timeout
	teleport_lock = false

func set_socko(on: bool) -> void:
	socko.visible = on
	if on:
		socko.enter()
	else:
		socko.set_pose("hidden", 0.3)

func toggle_torch() -> void:
	if not inv.has("torch"):
		if inv.has("lighter"):
			torch_on = not torch_on
			torch.spot_range = 3.5
			torch.light_energy = 1.2
			torch.visible = torch_on
		return
	var charge := float(inv.state.get("torch", {}).get("charge", 1.0))
	if charge <= 0.0:
		Sfx.play("switch", -10.0)
		Events.toast.emit("The torch is dead.")
		return
	torch_on = not torch_on
	torch.spot_range = 9.0
	torch.visible = torch_on
	Sfx.play("switch", -10.0)
	if torch_on:
		Story.record("used:torch")

func _update_torch(delta: float) -> void:
	if not torch_on or not inv.has("torch"):
		return
	var st: Dictionary = inv.state.get("torch", {"charge": 1.0})
	var c := maxf(0.0, float(st.get("charge", 1.0)) - delta / 420.0)
	st["charge"] = c
	inv.state["torch"] = st
	torch.light_energy = 2.2 * (1.0 if c > 0.15 else randf_range(0.2, 1.0))
	if c <= 0.0:
		torch_on = false
		torch.visible = false
		Events.toast.emit("The torch dies.")

func torch_charge() -> float:
	return float(inv.state.get("torch", {}).get("charge", 1.0))

## use an inventory item (from the inventory UI)
func use_item(id: String) -> void:
	match id:
		"battery":
			inv.remove("battery")
			inv.state["torch"] = {"charge": 1.0}
			Sfx.play("reload", -8.0, 0.8)
			Events.toast.emit("Fresh batteries in the torch.")
		"bandage":
			if injury > 0:
				inv.remove("bandage")
				injury -= 1
				hurt.emit(-1)
				Sfx.play("crawl", -8.0, 1.3)
				Story.record("resource.used:bandage")
		"pills":
			inv.remove("pills")
			Infection.suppressed = 120.0
			if injury > 0:
				injury -= 1
				hurt.emit(-1)
			Sfx.play("swallow", -6.0)
			Story.record("resource.used:pills")
		"torch", "lighter":
			toggle_torch()
		"revolver":
			if gun:
				gun.toggle_equip()
		"alarm_clock", "music_box":
			# set it down in front of him and start it
			if inv.remove(id):
				var p := PropKit.item(id, level.light_at if level else Callable())
				level.dynamic_root().add_child(p)
				p.global_position = global_position + (-global_transform.basis.z * 0.6) + Vector3(0, 0.3, 0)
				p.relight()
				if p.behaviour:
					if id == "alarm_clock": p.behaviour.arm()
					else: p.behaviour.play()
		_:
			var doc := String(ItemDB.get_item(id).get("doc", ""))
			if doc != "":
				Events.show_document.emit(doc)

func injure(n := 1) -> void:
	injury = mini(injury + n, 3)
	_shake = 1.0
	hurt.emit(n)
	Speech.bark("k_hurt")

func shock(_hz: Dictionary) -> void:
	if _shock_t > 0.0 or mode == "hidden":
		return
	_shock_t = 2.0
	Sfx.play_at("buzz", global_position, 4.0, 1.0, 8.0, "shock", self)
	injure(1)
	velocity = global_transform.basis.z * 3.0
	Story.record("hurt.shock")

func shake(k: float) -> void:
	_shake = maxf(_shake, k)

## make the camera face a world point (cutscenes)
func face_point(p: Vector3, sec := 0.8) -> void:
	var d := p - camera.global_position
	var yaw := atan2(-d.x, -d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	var t := create_tween().set_parallel()
	t.tween_property(self, "rotation:y", rotation.y + wrapf(yaw - rotation.y, -PI, PI), sec).set_trans(Tween.TRANS_SINE)
	t.tween_method(func(v): _pitch = v; head.rotation.x = v, _pitch, pitch, sec).set_trans(Tween.TRANS_SINE)

func get_state() -> Dictionary:
	return {"pos": var_to_str(global_position), "yaw": rotation.y, "injury": injury, "inv": inv.to_dict(), "torch_on": torch_on}

func set_state(d: Dictionary) -> void:
	global_position = str_to_var(d.pos)
	rotation.y = float(d.get("yaw", 0.0))
	injury = int(d.get("injury", 0))
	inv.from_dict(d.get("inv", {}))
