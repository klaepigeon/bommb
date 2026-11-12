class_name Hands
extends Node3D
## Kurt's right hand in first person (his left is Socko's): the rigged KurtArm, seen when he
## punches, holds something or swings it. Melee lives here (docs/MELEE.md).
##
## Attack ("fire"): holding something, he swings it; empty-handed (or with the pistol put away,
## "holster"), he punches. Tap for a quick blow; hold, then let go, for a heavy one (slower, harder,
## dearer). Every blow costs stamina (the same stamina running uses); tired, he hits weakly.
## Swung things wear out (Weapons.durability) and break: glass into a shard he keeps hold of, a
## chair into a leg, a lamp into its pole. "throw" throws what he's holding.
##
## The timeline of a blow: windup (draw back; held there while the button is), strike (fast,
## the hit is resolved at its end), recover (back to guard). Poses are wrist transforms in camera
## space; the arm hangs back from the wrist toward the shoulder. A held thing rides in the hand
## through the swing (frozen kinematic, at the offset it had when the swing began).

signal struck(target: Node, dmg: float)
signal broke(what: String)

const GUARD := Vector3(0.17, -0.2, -0.38)       # fist up, low right (in view)
const SHOULDER := Vector3(0.2, -0.25, 0.08)      # his right shoulder, from the eye
const POLE := Vector3(0.7, -1.0, 0.25)           # the elbow bends out and down
const HIDDEN := Vector3(0.24, -0.62, -0.12)
const HEAVY_HOLD := 0.35                        # seconds held before a blow becomes a heavy one
const STRIKE_T := 0.08

var player: Player
var arm: KurtArm
var state := "idle"            # idle, windup, strike, recover
var heavy := false
var _t := 0.0
var _pressed := false
var _hold := 0.0
var _prof := {}
var _from := Transform3D()      # wrist pose at the start of the current phase (camera space)
var _wrist := Transform3D()     # where the wrist is now (camera space)
var _shown := 0.0               # 0 out of sight .. 1 in view
var _idle_t := 0.0
var _swinging: RigidBody3D = null
var _grip := Transform3D()      # the held thing relative to the hand, for the swing
var _weak := false
var _hand := Transform3D()      # the hand as shown this frame (camera space; fingers -Z, back +Y)

func attach(p: Player) -> void:
	player = p
	name = "Hands"
	p.cam.add_child(self)
	arm = KurtArm.new(); arm.name = "RightArm"
	add_child(arm)
	arm.pose_name = "fist"; arm.blend_speed = 18.0
	_wrist = _pose(HIDDEN, Vector3(-0.1, 0.2, -1.0))
	_hand = _wrist
	for mi in arm.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## A wrist transform: at `at`, fingers along `dir`, the back of the hand roughly up.
func _pose(at: Vector3, dir: Vector3, roll := 0.0) -> Transform3D:
	var b := Basis.looking_at(dir.normalized(), Vector3(0.15, 1.0, 0.1))
	if roll != 0.0: b = b.rotated(dir.normalized(), roll)
	return Transform3D(b, at)

func melee_mode() -> bool:
	return player.held != null or Game.gun_out() == ""

func _unhandled_input(e: InputEvent) -> void:
	if not player or not player.controls: return
	if e.is_action_pressed("holster") and (Game.pistol.have or Game.shotgun.have):
		Game.cycle_gun()
		Sfx.play("pickup", -14.0, 0.7)
	if e.is_action_pressed("throw") and player.held and state == "idle":
		player.throw_held()
	if e.is_action_pressed("fire") and melee_mode() and state == "idle" and not player.inspecting:
		_begin()
	if e.is_action_released("fire"):
		_pressed = false

# ------------------------------------------------------------------ the blow
func _begin() -> void:
	_prof = Weapons.profile(player.held)
	state = "windup"; _t = 0.0; _pressed = true; _hold = 0.0; heavy = false
	_from = _wrist
	if player.held: _start_swing()
	arm.pose_name = "grip" if player.held else "fist"

func _windup_pose() -> Transform3D:
	if player.held:
		if heavy: return _pose(Vector3(0.1, 0.32, -0.28), Vector3(0.0, 0.9, -0.4), 0.3)       # overhead
		return _pose(Vector3(0.34, 0.08, -0.3), Vector3(0.6, 0.5, -0.6), 0.6)                # back over the right shoulder
	if heavy: return _pose(Vector3(0.3, -0.22, -0.1), Vector3(0.4, 0.15, -1.0), -0.6)        # drawn right back
	return _pose(Vector3(0.2, -0.26, -0.22), Vector3(-0.05, 0.1, -1.0), -0.2)

func _strike_pose() -> Transform3D:
	var reach: float = _prof.get("reach", 1.0)
	var z := -clampf(reach * 0.62, 0.55, 0.85)
	if player.held:
		if heavy: return _pose(Vector3(0.0, -0.32, z), Vector3(0.0, -0.8, -0.6), 0.3)          # down through it
		return _pose(Vector3(-0.2, -0.16, z), Vector3(-0.7, -0.2, -0.7), -0.4)                 # across, right to left
	if heavy: return _pose(Vector3(-0.02, -0.1, z), Vector3(-0.35, 0.05, -1.0), -1.3)         # a hook
	return _pose(Vector3(0.04, -0.12, z), Vector3(-0.05, 0.05, -1.0), -0.25)                 # straight out

const HOLD_AT := Vector3(0.06, -0.22, -0.5)     # where a swung thing comes back to before it's let go

func _rest_pose() -> Transform3D:
	if _swinging:
		# back from the swing to the carry, clear of whatever it hit, before it's handed back to physics
		return _pose(HOLD_AT, Vector3(-0.15, 0.35, -1.0))
	if player.held:
		# holding it: the hand under the thing, where the carry has it
		var p: Vector3 = player.cam.global_transform.affine_inverse() * player.held.global_position
		return _pose(p + Vector3(0.05, -0.07, 0.07), (p - Vector3(0.25, -0.35, 0.2)).normalized() + Vector3(0, 0.3, 0))
	return _pose(GUARD, Vector3(-0.08, 0.15, -1.0), -0.2)

func _process(delta: float) -> void:
	if not player: return
	var dt := delta
	match state:
		"windup":
			_t += dt
			_pressed = _pressed and Input.is_action_pressed("fire")     # (polled: any device's release counts)
			if _pressed: _hold += dt
			if _hold >= HEAVY_HOLD * Game.stat("heavy_charge") and not heavy:
				heavy = true; _from = _wrist; _t = 0.0
			var w: float = _prof.windup * (Weapons.HEAVY.windup if heavy else 1.0)
			var k := clampf(_t / maxf(0.01, w), 0.0, 1.0)
			_wrist = _from.interpolate_with(_windup_pose(), _ease(k))
			if k >= 1.0 and not _pressed: _strike()
		"strike":
			_t += dt
			var k := clampf(_t / (STRIKE_T * (1.5 if heavy else 1.0)), 0.0, 1.0)
			_wrist = _from.interpolate_with(_strike_pose(), k * k)
			if k >= 1.0:
				_resolve()
				state = "recover"; _t = 0.0; _from = _wrist
		"recover":
			_t += dt
			var r: float = _prof.recover * (Weapons.HEAVY.recover if heavy else 1.0) * (1.4 if _weak else 1.0)
			var k := clampf(_t / r, 0.0, 1.0)
			_wrist = _from.interpolate_with(_rest_pose(), _ease(k))
			if k >= 1.0:
				state = "idle"; _idle_t = 0.0
				_end_swing()
		_:
			_idle_t += dt
			var want := _rest_pose()
			_wrist = _wrist.interpolate_with(want, 1.0 - exp(-12.0 * dt))
			arm.pose_name = "hold" if player.held else ("fist" if _idle_t < 1.2 else "relaxed")
	# seen when it's doing something, or holding something; otherwise it drops out of view
	var want_shown := 1.0 if (state != "idle" or player.held or _idle_t < 1.2) and player.controls else 0.0
	if Game.gun_out() != "" and not player.held and state == "idle": want_shown = 0.0
	_shown = move_toward(_shown, want_shown, dt * 4.0)
	arm.visible = _shown > 0.01
	var hidden := _pose(HIDDEN, Vector3(-0.1, 0.2, -1.0))
	_hand = hidden.interpolate_with(_wrist, _ease(_shown))
	# the arm, by IK, from his shoulder to the hand (the solver wants Y along the fingers, Z out of
	# the back of the hand)
	arm.transform = Transform3D.IDENTITY
	if arm.skeleton:
		arm.solve_arm(SHOULDER, Transform3D(KurtArm.frame(-_hand.basis.z, _hand.basis.y), _hand.origin), POLE)
	if _swinging and is_instance_valid(_swinging):
		_swinging.global_transform = global_transform * _hand * _grip

func _ease(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)

func _strike() -> void:
	state = "strike"; _t = 0.0; _from = _wrist
	var cost: float = _prof.stamina * (Weapons.HEAVY.stamina if heavy else 1.0) * Game.stat("blow_stamina")
	_weak = player.stamina < cost
	player.stamina = maxf(0.0, player.stamina - cost)
	Sfx.play("whoosh", -8.0 if heavy else -12.0, randf_range(0.8, 0.95) if heavy else randf_range(1.0, 1.2))
	if heavy: Sfx.play("breath", -14.0, 1.2)

## Where the blow lands: rays out from the eye along the look, the nearest thing they meet.
func _resolve() -> void:
	var cam := player.cam
	var from := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var right := cam.global_transform.basis.x
	var reach: float = _prof.reach
	var ex := [player.get_rid()]
	if _swinging: ex.append(_swinging.get_rid())
	var best := {}; var bd := INF
	for off in [0.0, -0.14, 0.14]:
		var to: Vector3 = from + fwd * reach + right * off + Vector3(0, -0.05, 0)
		var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 8 | 16 | 32, ex)
		var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty(): continue
		var d := from.distance_to(hit.position)
		if d < bd: bd = d; best = hit
	var dmg: float = _prof.dmg * (Weapons.HEAVY.dmg if heavy else 1.0) * (0.5 if _weak else 1.0) * Game.stat("strength")
	var knock: float = _prof.knock * (Weapons.HEAVY.knock if heavy else 1.0) * (0.6 if _weak else 1.0)
	if best.is_empty():
		return
	var c: Node = best.collider
	var p: Vector3 = best.position
	var target := c
	for i in 4:
		if target == null or target.has_method("melee_hit"): break
		target = target.get_parent()
	var wear := 0
	var kind: String = _prof.kind
	if target and target.has_method("melee_hit"):
		target.melee_hit(dmg, from, knock, self)
		Sfx.play_at("bullet_flesh" if kind != "sharp" else "squelch", p, -2.0 if heavy else -5.0, randf_range(0.8, 1.0))
		player.shake(0.02 if heavy else 0.012, 0.15)
		Fx.kick("fringe", 0.6, 0.3)
		Fx.burst("flesh", p, (best.get("normal", -fwd) as Vector3))
		Fx.hitstop(0.09 if heavy else 0.05)
		player.fov_kick = 3.0 if heavy else 1.5
		wear = 1
		struck.emit(target, dmg)
	elif c is RigidBody3D:
		var rb := c as RigidBody3D
		if rb.has_method("wake"): rb.wake()
		# what it's knocked to: a light thing flies, a heavy one shifts
		# (a blow from above would only press it into the table it's on: send it along and a little up)
		var dir := Vector3(fwd.x, maxf(fwd.y, 0.2), fwd.z).normalized()
		rb.apply_impulse(dir * knock * 3.0 * clampf(rb.mass, 0.2, 4.0) + Vector3(0, knock * 0.6 * minf(rb.mass, 2.0), 0), (p - rb.global_position) * 0.5)
		Sfx.play_at(_hit_sound(kind), p, -6.0, randf_range(0.9, 1.1))
		Fx.burst("glass" if kind == "glass" else "wood", p, (best.get("normal", -fwd) as Vector3))
		Fx.hitstop(0.03)
		wear = 1 if rb.mass > 2.0 else 0
		struck.emit(rb, dmg)
	else:
		# a wall, a door: it jars up his arm
		Sfx.play_at(_hit_sound(kind), p, -4.0, randf_range(0.75, 0.9))
		player.shake(0.015, 0.12)
		Fx.burst("dust", p, (best.get("normal", -fwd) as Vector3))
		Fx.hitstop(0.06 if heavy else 0.035)
		wear = 1
		if c and c.has_method("punched"): c.punched(dmg, from, self)
		struck.emit(c, dmg)
	Game.make_noise(p, clampf(_prof.noise * (1.3 if heavy else 1.0), 0.05, 1.0))
	if _swinging and wear > 0 and randf() < Game.stat("wear_chance"):
		if Weapons.wear(_swinging, wear * (Weapons.HEAVY.wear if heavy else 1)): _break(p)

func _hit_sound(kind: String) -> String:
	match kind:
		"glass": return "glass"
		"sharp": return "metal"
		"soft": return "thud"
	return "thud"

# ------------------------------------------------------------------ swinging a held thing
func _start_swing() -> void:
	var b := player.held
	_swinging = b
	b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC; b.freeze = true
	var hand_g := player.cam.global_transform * _hand
	_grip = hand_g.affine_inverse() * b.global_transform
	# a long thing is held at its end, not its middle: push it out along the fingers
	var aabb := _size_of(b)
	var long := maxf(aabb.x, maxf(aabb.y, aabb.z))
	if long > 0.3: _grip.origin = Vector3(0, 0, -long * 0.4)
	else: _grip.origin = Vector3(0, 0.0, -0.06)

func _end_swing() -> void:
	if _swinging and is_instance_valid(_swinging):
		_swinging.freeze = false
	_swinging = null

static func _size_of(b: Node) -> Vector3:
	for c in b.get_children():
		if c is CollisionShape3D and c.shape is BoxShape3D: return (c.shape as BoxShape3D).size
	return Vector3(0.2, 0.2, 0.2)

## It's had it. Glass goes to pieces and leaves a shard in his hand; a chair comes apart and he's
## left holding a leg; anything else just falls apart.
func _break(at: Vector3) -> void:
	var old := _swinging
	var cls: String = _prof["class"]
	var into: String = _prof.breaks
	var kind: String = _prof.kind
	_end_swing()
	player.drop_held()
	var pos := old.global_position
	Sfx.play_at("glass" if kind == "glass" else "door_slam", at, 0.0, randf_range(1.2, 1.5) if kind == "glass" else 1.6)
	Game.make_noise(at, 0.8)
	# pieces
	var mat: Material = Tex.mat("glass", 4.0) if kind == "glass" else Tex.mat("wood", 4.0)
	for i in (6 if kind == "glass" else 4):
		var s := Vector3(randf_range(0.02, 0.06), randf_range(0.01, 0.03), randf_range(0.02, 0.07)) * (1.0 if kind == "glass" else 2.5)
		var bit := Prop.make(player.get_parent(), pos + Vector3(randf_range(-0.1, 0.1), randf_range(0.0, 0.1), randf_range(-0.1, 0.1)), s, mat, "Piece", 0.05, 0.2)
		bit.set_meta("debris", true); bit.liftable = false
		bit.linear_velocity = Vector3(randf_range(-2, 2), randf_range(0.5, 2.5), randf_range(-2, 2))
		get_tree().create_timer(20.0).timeout.connect(func(): if is_instance_valid(bit): bit.queue_free())
	old.queue_free()
	broke.emit(cls)
	if into != "":
		var size: Vector3 = {"shard": Vector3(0.03, 0.012, 0.16), "pole": Vector3(0.035, 1.2, 0.035), "leg": Vector3(0.04, 0.45, 0.04)}[into]
		var m2: Material = Tex.mat("glass", 4.0) if into == "shard" else (Tex.mat("metal", 4.0) if into == "pole" else Tex.mat("wood", 4.0))
		var piece := Prop.make(player.get_parent(), pos, size, m2, Weapons.BROKEN_LABEL[into], 0.15 if into == "shard" else 0.8, 0.3)
		piece.set_meta("weapon_class", into)
		player.pick_up(piece)
