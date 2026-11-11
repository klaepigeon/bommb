class_name Door
extends Node3D
## A hinged door. The node is the hinge; its yaw is psi0 + sign * angle. The leaf is a moving
## solid body: it stops Kurt, it shoves loose things as it swings, and what's piled against it
## stops it (a barricade is just weight in the way). Locks are separate and stack: a key lock
## (with the key maybe still in it, on one side), a bolt (worked from one side only), a chain
## with a padlock, a jam. Anything can be beaten through: kicks, an axe, a bullet in the lock,
## Marta. Light and sound go through it while it's open.

signal opened(by)
signal tried(by)
signal broke(by)

var id := ""
var psi0 := 0.0
var sgn := 1.0
var angle := 0.0                 ## radians, 0 = shut
var max_angle := 1.5
var w := 0.8
var h := 2.02
var zone_a := -1                 ## the room on the leaf's +Z side
var zone_b := -1
var key_locked := false
var key_id := ""                 ## the key that works it
var key_in := ""                 ## "a"/"b": the key is sitting in the lock on that side
var bolt := ""                   ## "a"/"b": the side the bolt is on ("" = none)
var bolted := false
var chained := false             ## opens a crack, no further
var padlock := false             ## on the chain: needs padlock_key, or breaking
var jam := 0.0                   ## > 0: stuck; force takes it down
var hp := 100.0
var broken := false
var chain_gap := 0.11
var under_door := ""
var inside := "a"                ## the side the chain is worked from             ## what's been slid under it (the magazine trick)
var body: AnimatableBody3D
var _tween: Tween
var _swing_to := 0.0
var _swinging := false
var _blocked_t := 0.0

func setup(p_id: String, ex: Dictionary) -> void:
	id = p_id
	psi0 = float(ex.get("psi0", 0.0)); sgn = float(ex.get("sign", 1.0))
	max_angle = minf(float(ex.get("max", 1.5)), 1.65)
	angle = float(ex.get("open", 0.0))
	w = float(ex.get("w", 0.8)); h = float(ex.get("h", 2.02))
	body = AnimatableBody3D.new(); body.sync_to_physics = false
	body.collision_layer = 1; body.collision_mask = 0
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new()
	b.size = Vector3(w - 0.02, h, 0.05); cs.shape = b
	cs.position = Vector3(w * 0.5, h * 0.5, 0)
	body.add_child(cs)
	body.set_meta("actor", self)
	add_child(body)
	_apply()

func is_open() -> bool:
	return angle > 0.15

func locked() -> bool:
	return not broken and (key_locked or bolted or jam > 0.0 or (chained and padlock))

func side_of(p: Vector3) -> String:
	var par := get_parent() as Node3D
	var shut := Transform3D(Basis(Vector3.UP, psi0), position)
	if par: shut = par.global_transform * shut
	return "a" if (shut.affine_inverse() * p).z > 0.0 else "b"

func handle_pos() -> Vector3:
	return global_transform * Vector3(w - 0.1, 1.0, 0)

func _apply() -> void:
	rotation.y = psi0 + sgn * angle
	if zone_a >= 0 and zone_b >= 0:
		Lights.set_link(zone_a, zone_b, angle > 0.08)

# --------------------------------------------------------------------------------------- verbs
func get_verbs(k) -> Array:
	var v: Array = []
	var side := side_of(k.global_position)
	if is_open():
		v.append({"id": "close", "label": "Close"})
	else:
		v.append({"id": "open", "label": "Open"})
	if not broken and key_locked and (k.has_item(key_id) or key_in == side):
		v.push_front({"id": "unlock", "label": "Unlock"})
	elif not broken and not key_locked and key_id != "" and not is_open() and (k.has_item(key_id) or key_in == side):
		v.append({"id": "lock", "label": "Lock"})
	if bolt == side and not broken:
		v.push_front({"id": "unbolt" if bolted else "bolt", "label": "Slide the bolt back" if bolted else "Bolt it"})
	if chained and padlock and k.has_item("padlock_key"):
		v.push_front({"id": "unpadlock", "label": "Unlock the padlock"})
	elif chained and not padlock and side == inside:
		v.push_front({"id": "unchain", "label": "Take the chain off"})
	if chained and padlock and Progress.has("coral_grip"):
		v.push_front({"id": "snap", "label": "Snap the chain"})
	if not is_open() and not broken:
		v.append({"id": "kick", "label": "Kick"})
	if key_in != "" and key_in != side and not broken:
		v.append({"id": "keyhole", "label": "Look through the keyhole"})
	if under_door != "" and not broken:
		v.push_front({"id": "pull_under", "label": "Pull the %s back" % under_door})
	return v

## Holding something thin and wide (the magazine): it goes under the door.
func hold_verbs(k, held) -> Array:
	if held.item == "magazine" and not is_open() and under_door == "":
		return [{"id": "slide_under", "label": "Slide it under the door", "held": true}]
	if chained and padlock and held.mass >= 0.8:
		return [{"id": "smash", "label": "Hit the padlock with it", "held": true}]
	if not is_open() and not broken and locked() and held.mass >= 1.2:
		return [{"id": "batter", "label": "Hit the lock with it", "held": true}]
	return []

var padlock_hits := 0

## Something heavy, swung at the padlock: the axe breaks it in three, anything else takes longer.
func _smash(k) -> void:
	var h: Prop = k.held
	var axe := h != null and "Axe" in h.key
	padlock_hits += 1
	Audio.play("axe" if axe else "kick", handle_pos(), 2.0, randf_range(0.9, 1.1))
	Audio.play("chain", handle_pos(), -2.0)
	Noises.make(handle_pos(), 22.0, "bang", k)
	World.emit_event("padlock_hit", {"n": padlock_hits, "axe": axe})
	if padlock_hits >= (3 if axe else 7):
		_padlock_off("smash")

func _padlock_off(how: String) -> void:
	padlock = false; chained = false
	Audio.play("chain", handle_pos(), 2.0, 0.8)
	World.emit_event("padlock_off", {"door": id, "how": how})

## A bullet: in the padlock, it's gone in two; in a lock, it's 50 off the door.
func shot(at: Vector3, by) -> void:
	var lock_at: Vector3 = get_meta("lock_at", handle_pos())
	if chained and padlock and at.distance_to(lock_at) < 0.45:
		padlock_hits += 2
		Audio.play("clink", at, 2.0, 0.6)
		if padlock_hits >= 4: _padlock_off("shot")
		return
	if at.distance_to(handle_pos()) < 0.35:
		damage(50.0, by, "bullet")
	else:
		Audio.play("splinter", at, -6.0, 1.5)

## Socko can get his nose into a keyhole.
func socko_verbs(k) -> Array:
	if key_in != "" and key_in != side_of(k.global_position) and not broken and not is_open():
		return [{"id": "poke", "label": "Poke the key out"}]
	return []

func socko_act(id: String, k, mind) -> void:
	if id != "poke": return
	mind.socko.set_pose("talk", 0.4)
	mind.socko.point_at(handle_pos())
	await mind.bark("cmd_poke", true)
	await get_tree().create_timer(1.2, false).timeout
	mind.socko.point_at(Vector3.INF)
	mind.socko.set_pose("up", 0.5)
	var far := key_in
	key_in = ""
	Audio.play("clink", handle_pos() + Vector3(0, -0.9, 0), -6.0)
	if under_door == "magazine":
		set_meta("key_on_magazine", true)
		World.emit_event("key_poked", {"door": id, "caught": true})
	else:
		# it's on the floor on the far side now, where his hand can't get to
		var side_dir := 1.0 if far == "a" else -1.0
		var shut := Transform3D(Basis(Vector3.UP, psi0), position)
		var par := get_parent() as Node3D
		if par: shut = par.global_transform * shut
		var p := Prop.make(get_parent(), Transform3D(Basis(), shut * Vector3(w * 0.8, 0.03, 0.35 * side_dir)), Vector3(0.06, 0.01, 0.03), 0.02)
		p.key = id + "_key"; p.item = key_id; p.title = "Door key"; p.desc = "The key to the living room door."; p.stuff = "metal"
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.06, 0.01, 0.025); mi.mesh = bm
		mi.material_override = Mats.flat(Color(0.75, 0.62, 0.3), -1); p.add_child(mi)
		mind.bark("cmd_poke_fall", true)
		World.emit_event("key_poked", {"door": id, "caught": false})

func act(verb: String, k) -> void:
	match verb:
		"open": try_open(k)
		"close": swing(0.0, 0.7); Audio.play("latch", handle_pos(), -6.0)
		"unlock":
			key_locked = false; key_in = side_of(k.global_position) if key_in == "" else key_in
			Audio.play("latch", handle_pos(), -4.0); Noises.make(handle_pos(), 3.0, "latch", k)
			World.emit_event("door_unlocked", {"door": id})
		"lock": key_locked = true; Audio.play("latch", handle_pos(), -4.0)
		"bolt": bolted = true; Audio.play("latch", handle_pos(), -2.0); Noises.make(handle_pos(), 4.0, "latch", k); World.emit_event("door_bolted", {"door": id})
		"unbolt": bolted = false; Audio.play("latch", handle_pos(), -2.0); Noises.make(handle_pos(), 4.0, "latch", k)
		"unpadlock":
			padlock = false; chained = false
			Audio.play("chain", handle_pos(), -2.0); Noises.make(handle_pos(), 5.0, "chain", k)
			World.emit_event("padlock_off", {"door": id, "how": "key"})
		"unchain": chained = false; Audio.play("chain", handle_pos(), -4.0)
		"kick": kick(k)
		"smash": _smash(k)
		"batter":
			damage(30.0 if k.held and "Axe" in k.held.key else 15.0, k, "axe" if k.held and "Axe" in k.held.key else "kick")
		"snap":
			Audio.play("splinter", handle_pos(), 0.0)
			Noises.make(handle_pos(), 12.0, "bang", k)
			_padlock_off("grip")
		"keyhole": World.emit_event("keyhole", {"door": id})
		"slide_under":
			under_door = "magazine"
			var h = k.held
			k.held = null
			if h: h.queue_free()
			Audio.play("pickup", handle_pos() + Vector3(0, -0.95, 0), -10.0)
			World.emit_event("slid_under", {"door": id})
		"pull_under":
			var had_key: bool = get_meta("key_on_magazine", false)
			under_door = ""
			set_meta("key_on_magazine", false)
			k.give_item("magazine", "Magazine", "Rabotnitsa, the women's monthly. Glossy, thin, wide.")
			if had_key:
				k.give_item(key_id, "Door key", "The key to the living room door. It came under the door on the magazine.")
				World.emit_event("key_retrieved", {"door": id})

func try_open(by) -> void:
	if broken:
		swing(max_angle, 0.6); return
	if jam > 0.0 or key_locked or bolted:
		Audio.play("rattle", handle_pos(), -2.0)
		Noises.make(handle_pos(), 5.0, "rattle", by)
		tried.emit(by)
		World.emit_event("door_tried", {"door": id, "by": by})
		return
	if chained:
		swing(chain_gap, 0.25)
		Audio.play("chain", handle_pos(), -3.0)
		tried.emit(by)
		World.emit_event("door_tried", {"door": id, "by": by, "chain": true})
		return
	swing(max_angle, 0.9)
	Audio.play("creak", handle_pos(), -10.0, randf_range(1.1, 1.4))
	Noises.make(handle_pos(), 3.5, "door", by)
	opened.emit(by)

## Force against it (a kick ~25, a shoulder from a monster ~20, an axe ~35, a bullet in the lock 50).
func damage(amount: float, by, kind := "kick") -> void:
	if broken:
		return
	hp -= amount
	if jam > 0.0: jam = maxf(jam - amount, 0.0)
	Audio.play("kick" if kind != "axe" else "axe", handle_pos(), 0.0, randf_range(0.9, 1.1))
	Noises.make(handle_pos(), 18.0 if kind != "bullet" else 30.0, "bang", by)
	if hp <= 0.0 or (not locked() and kind != "axe"):
		if hp <= 0.0:
			broken = true; key_locked = false; bolted = false; chained = false; padlock = false; jam = 0.0
			Audio.play("splinter", handle_pos(), 2.0)
			broke.emit(by)
			World.emit_event("door_broken", {"door": id, "by": by, "kind": kind})
		swing(max_angle, 0.35)
		opened.emit(by)

func kick(k) -> void:
	var f := 25.0
	if Progress.has("coral_grip"): f = 45.0
	damage(f, k, "kick")
	World.emit_event("kicked", {"door": id})

func swing(to: float, seconds: float) -> void:
	_swing_to = clampf(to, 0.0, chain_gap if (chained and not broken) else max_angle)
	if _tween and _tween.is_valid(): _tween.kill()
	_swinging = true
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_angle_checked, angle, _swing_to, seconds)
	_tween.tween_callback(func(): _swinging = false)

func set_angle(a: float) -> void:
	if _tween and _tween.is_valid(): _tween.kill()
	angle = a; _apply()

## As it swings, heavy things in the way stop it (a barricade); light ones are shoved.
func _set_angle_checked(a: float) -> void:
	if a > angle and _blocked(a):
		if _tween and _tween.is_valid(): _tween.kill()
		_swinging = false
		Audio.play("thud", handle_pos(), -6.0)
		World.emit_event("door_blocked", {"door": id})
		return
	angle = a
	_apply()

func _blocked(a: float) -> bool:
	if not is_inside_tree(): return false
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var b := BoxShape3D.new(); b.size = Vector3(w * 0.9, h * 0.8, 0.08)
	q.shape = b
	var par := get_parent() as Node3D
	var xf := (par.global_transform if par else Transform3D.IDENTITY) * Transform3D(Basis(Vector3.UP, psi0 + sgn * a), position)
	q.transform = xf * Transform3D(Basis(), Vector3(w * 0.5, h * 0.5, 0))
	q.collision_mask = 2
	var mass := 0.0
	for r in space.intersect_shape(q, 16):
		var c = r.collider
		if c is RigidBody3D:
			mass += (c as RigidBody3D).mass
			if c is Prop: (c as Prop).wake()
			(c as RigidBody3D).apply_central_impulse((xf.basis.z * sgn) * 0.6)
	return mass > 30.0

func save() -> Dictionary:
	return {"a": angle, "kl": key_locked, "ki": key_in, "b": bolted, "c": chained, "p": padlock, "j": jam, "hp": hp, "br": broken, "u": under_door}

func load_state(d: Dictionary) -> void:
	angle = float(d.get("a", angle)); key_locked = bool(d.get("kl", key_locked)); key_in = String(d.get("ki", key_in))
	bolted = bool(d.get("b", bolted)); chained = bool(d.get("c", chained)); padlock = bool(d.get("p", padlock))
	jam = float(d.get("j", jam)); hp = float(d.get("hp", hp)); broken = bool(d.get("br", broken)); under_door = String(d.get("u", ""))
	_apply()
