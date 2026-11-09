class_name GunFeel
extends Node
## What makes a shot feel like something (owner: "immensely satisfying, real weight"; the story
## wants it to feel good, because Socko wants him to like it). Shared by every gun:
##
##   the shot     the view kicks up on a spring and comes most of the way back (a little drift
##                stays), a roll, a field-of-view punch, a weighted shake, a long muzzle smoke,
##                the phone and the pad buzz
##   the aim      generous: a round goes to a target near the crosshair (bullet magnetism, head
##                first, wider up close); on touch and pad the view eases onto a target as it
##                crosses the crosshair. Never on a mouse: a mouse hand wants its own aim.
##   the hit      dust and chips from what was hit (plaster, wood, stone, sparks off metal, coral
##                off her, plaster off the figures), a deep thunk and a tick on the crosshair,
##                and the moment held: a hit-stop, a few hundredths of a second
##   the kill     slow motion for a breath (longer for a head), the world's sound slowed with it
##   Socko        loves it, and says so (not every time)

var main: Node
var player: Node
var _recoil := Vector2.ZERO          # pitch, yaw (radians), the spring's position
var _recoil_v := Vector2.ZERO
var _roll := 0.0; var _roll_v := 0.0
var _fov_punch := 0.0
var _base_fov := 0.0
var _applied := Vector2.ZERO
var _acc := 0.0
var _slow_until := 0
var _socko_t := 0.0
var _rng := RandomNumberGenerator.new()
var _pad_active := false

func setup(p_main: Node) -> void:
	main = p_main; player = main.player
	add_to_group("gun_feel")
	_base_fov = (player.get("cam") as Camera3D).fov

static func get_in(tree: SceneTree) -> GunFeel:
	return tree.get_first_node_in_group("gun_feel") as GunFeel

func _input(e: InputEvent) -> void:
	if e is InputEventJoypadMotion or e is InputEventJoypadButton: _pad_active = true
	elif e is InputEventMouseMotion: _pad_active = false

# ---------------------------------------------------------------- the shot
## strength: 1 the revolver, ~1.9 the shotgun (times the gun's own kick scale)
func kick(gun: Node3D, strength: float) -> void:
	# velocities in rad/s: the spring turns them into a kick that peaks ~0.045 rad (revolver)
	_recoil_v += Vector2(1.05 * strength, _rng.randf_range(-0.4, 0.4) * strength)
	_roll_v += _rng.randf_range(-0.7, 0.7) * strength
	_fov_punch += 3.5 * strength
	player.set("shake", maxf(float(player.get("shake")), 0.55 + 0.3 * strength))
	# a little of every kick stays: he has to bring it back down himself, like a real one
	player.set("pitch", float(player.get("pitch")) + 0.012 * strength)
	_haptic(strength)
	if gun.has_method("muzzle_global"): _smoke(gun.call("muzzle_global"), strength)

func _haptic(strength: float) -> void:
	if Game.is_phone(): Input.vibrate_handheld(int(45 + 35 * strength), clampf(0.5 + 0.25 * strength, 0.0, 1.0))
	for j in Input.get_connected_joypads():
		Input.start_joy_vibration(j, clampf(0.35 * strength, 0.0, 1.0), clampf(0.6 * strength, 0.0, 1.0), 0.12 + 0.05 * strength)

func _process(delta: float) -> void:
	if not player: return
	var real := delta / maxf(Engine.time_scale, 0.01)       # the spring runs on real time
	# a stiff, slightly underdamped spring: a sharp kick, a quick fall, the smallest overshoot
	# stepped at a fixed 1/240 s whatever the frame rate: a stiff spring stepped with a long frame
	# (a slow phone, a hitch) would blow up
	var k := 220.0; var c := 22.0
	_acc += minf(real, 0.25)
	while _acc >= 1.0 / 240.0:
		var h := 1.0 / 240.0
		_acc -= h
		_recoil_v += (-k * _recoil - c * _recoil_v) * h
		_recoil += _recoil_v * h
		_roll_v += (-k * _roll - c * _roll_v) * h
		_roll += _roll_v * h
	var cam: Camera3D = player.get("cam")
	_fov_punch = move_toward(_fov_punch, 0.0, real * 40.0)
	cam.fov = _base_fov - _fov_punch
	# apply only what's changed since last frame, so the player's own look isn't fought
	var d := _recoil - _applied
	player.set("pitch", clampf(float(player.get("pitch")) + d.x, -1.45, 1.45))
	player.set("yaw", float(player.get("yaw")) + d.y)
	_applied = _recoil
	cam.rotation.z = _roll
	_aim_assist(real)
	if _slow_until > 0 and Time.get_ticks_msec() >= _slow_until:
		_slow_until = 0
		Engine.time_scale = 1.0; AudioServer.playback_speed_scale = 1.0
	_socko_t -= real

# ---------------------------------------------------------------- the aim
## every target's points, head first: [{pos, head, target}]
func _points() -> Array:
	var out := []
	for t in get_tree().get_nodes_in_group("shootable_target"):
		if t.has_method("aim_points") and t.is_visible_in_tree():
			for p in t.call("aim_points"): out.append(p)
	return out

## The way a round should go: straight down the crosshair, unless a target's head or body is close
## to it, then at that (head first). Returns {dir, target, head}.
func resolve_aim(from: Vector3, dir: Vector3, range_m: float) -> Dictionary:
	var best := {}; var best_score := 1e9
	for p in _points():
		var to: Vector3 = p.pos - from
		var dist := to.length()
		if dist > range_m or dist < 0.2: continue
		var ang := dir.angle_to(to / dist)
		# wider up close (a body fills more of the view), head cone a bit tighter but preferred
		var cone := deg_to_rad((4.0 if p.head else 6.5) + 6.0 / maxf(dist, 1.0))
		if ang > cone: continue
		var score := ang / cone - (0.35 if p.head else 0.0)
		if score < best_score and _clear(from, p.pos, p.target):
			best_score = score; best = {"dir": to / dist, "target": p.target, "head": p.head}
	if best.is_empty(): return {"dir": dir, "target": null, "head": false}
	return best

func _clear(a: Vector3, b: Vector3, target: Node) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b); q.exclude = [player.get_rid()]
	var hit: Dictionary = (player as Node3D).get_world_3d().direct_space_state.intersect_ray(q)
	if not hit: return true
	var n: Node = hit.collider
	while n:
		if n == target: return true
		n = n.get_parent()
	return false

## On touch and a pad: as a target crosses the crosshair, the view eases onto it.
func _aim_assist(real: float) -> void:
	var g = player.get("gun")
	if not g or not g.get("drawn") or player.get("locked"): return
	if not (bool(player.get("touch_ui")) or _pad_active or Game.has_touch()): return
	var cam: Camera3D = player.get("cam")
	var fwd := -cam.global_basis.z
	var best: Vector3 = Vector3.ZERO; var best_ang := deg_to_rad(7.0)
	for p in _points():
		var to: Vector3 = p.pos - cam.global_position
		if to.length() > 25.0: continue
		var a := fwd.angle_to(to.normalized())
		if a < best_ang: best_ang = a; best = to.normalized()
	if best == Vector3.ZERO: return
	var want_yaw := atan2(-best.x, -best.z); var want_pitch := asin(clampf(best.y, -1.0, 1.0))
	var k := minf(1.0, real * 3.0)
	player.set("yaw", float(player.get("yaw")) + wrapf(want_yaw - float(player.get("yaw")), -PI, PI) * k * 0.35)
	player.set("pitch", float(player.get("pitch")) + (want_pitch - float(player.get("pitch"))) * k * 0.35)

# ---------------------------------------------------------------- the hit
## What a round did where it struck: dust, chips, sparks, by what it hit.
func impact(hit: Dictionary, dir: Vector3, power := 1.0) -> void:
	if hit.is_empty(): return
	var c: Node = hit.collider
	var kind := "plaster"
	var n := c
	while n:
		if n.has_method("impact_kind"): kind = String(n.call("impact_kind")); break
		n = n.get_parent()
	if kind == "plaster":
		if c is RigidBody3D: kind = "wood"
		elif c is StaticBody3D and (c as Node).has_method("prompt") and String((c as Node).call("prompt")) == "": kind = "metal"
	var col: Color = {"plaster": Color(0.82, 0.78, 0.7), "wood": Color(0.45, 0.3, 0.18), "metal": Color(1.0, 0.8, 0.4),
		"coral": Color(0.85, 0.42, 0.38), "figure": Color(0.95, 0.94, 0.9), "stone": Color(0.6, 0.58, 0.55)}.get(kind, Color(0.8, 0.8, 0.8))
	_burst(hit.position, hit.normal, dir, col, kind, power)

func _burst(at: Vector3, normal: Vector3, dir: Vector3, col: Color, kind: String, power: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true; p.explosiveness = 1.0; p.emitting = false
	p.amount = int((10 if kind != "metal" else 14) * clampf(power, 0.6, 2.0))
	p.lifetime = 0.5 if kind != "metal" else 0.25
	var m := BoxMesh.new(); m.size = Vector3.ONE * (0.012 if kind != "figure" else 0.025)
	var mat := StandardMaterial3D.new(); mat.albedo_color = col; mat.roughness = 1.0
	if kind == "metal": mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat; p.mesh = m
	var out := (normal * 0.8 - dir * 0.4).normalized()
	p.direction = out; p.spread = 35.0; p.local_coords = false
	p.initial_velocity_min = 1.5 * power; p.initial_velocity_max = (4.5 if kind != "metal" else 6.0) * power
	p.gravity = Vector3(0, -9.8, 0); p.scale_amount_min = 0.5; p.scale_amount_max = 1.4
	p.angular_velocity_min = -400; p.angular_velocity_max = 400
	main.player.get_parent().add_child(p)
	p.global_position = at + normal * 0.01
	p.emitting = true
	# and a puff of dust that hangs a moment (not off metal)
	if kind != "metal": _smoke(Transform3D(Basis(), at + normal * 0.03), 0.6 * power, col.lerp(Color(0.6, 0.6, 0.6), 0.4))
	get_tree().create_timer(2.0, true, false, true).timeout.connect(p.queue_free)

## smoke: soft grey puffs that rise and spread and thin (at the muzzle, or where a round struck)
func _smoke(at: Transform3D, strength: float, col := Color(0.75, 0.74, 0.72)) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true; p.explosiveness = 0.85; p.emitting = false
	p.amount = int(10 + 6 * strength); p.lifetime = 2.0
	p.local_coords = false
	var q := QuadMesh.new(); q.size = Vector2(0.16, 0.16)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(minf(col.r * 1.25, 1.0), minf(col.g * 1.25, 1.0), minf(col.b * 1.25, 1.0), 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.albedo_texture = _puff()
	mat.vertex_color_use_as_albedo = true
	q.material = mat; p.mesh = q
	p.direction = -at.basis.z if at.basis != Basis() else Vector3.UP
	p.spread = 30.0; p.initial_velocity_min = 0.3; p.initial_velocity_max = 1.1 * strength
	p.gravity = Vector3(0, 0.35, 0); p.damping_min = 1.0; p.damping_max = 2.0
	p.scale_amount_min = 0.6; p.scale_amount_max = 1.6 * strength
	var ramp := Gradient.new(); ramp.set_color(0, Color(1, 1, 1, 0.9)); ramp.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = ramp
	var sc := Curve.new(); sc.add_point(Vector2(0, 0.5)); sc.add_point(Vector2(1, 3.2)); p.scale_amount_curve = sc
	main.player.get_parent().add_child(p)
	p.global_transform = at
	p.emitting = true
	get_tree().create_timer(2.5, true, false, true).timeout.connect(p.queue_free)

static var _puff_tex: Texture2D
static func _puff() -> Texture2D:
	if _puff_tex: return _puff_tex
	const S := 32
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var d := Vector2(x - S * 0.5 + 0.5, y - S * 0.5 + 0.5).length() / (S * 0.5)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 1.6))
	_puff_tex = ImageTexture.create_from_image(img)
	return _puff_tex

## A target took it: the thunk, the tick, the moment held; a kill, slowed for a breath.
func confirm(head: bool, kill: bool) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("hit_tick"): hud.call("hit_tick", head, kill)
	var ap := AudioStreamPlayer.new(); ap.stream = _thunk(head); ap.volume_db = -3.0 if head else -6.0
	ap.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ap); ap.play(); ap.finished.connect(ap.queue_free)
	if kill:
		_slow(0.22 if head else 0.3, 650 if head else 420)
	else:
		_slow(0.05, 55 if head else 35)          # the hit-stop
	if Game.is_phone(): Input.vibrate_handheld(90 if kill else 30, 1.0 if kill else 0.6)
	_socko_line(head, kill)

func _slow(scale: float, ms: int) -> void:
	Engine.time_scale = scale
	AudioServer.playback_speed_scale = lerpf(0.55, 1.0, scale)
	_slow_until = maxi(_slow_until, Time.get_ticks_msec() + ms)

## the thunk: low and round, with a crack on top for a head
static func _thunk(head: bool) -> AudioStreamWAV:
	const R := 22050
	var n := int(R * 0.35); var s := PackedFloat32Array(); s.resize(n)
	var rng := RandomNumberGenerator.new(); rng.seed = 7 if head else 3
	for i in n:
		var t := float(i) / R
		s[i] = sin(TAU * (95.0 - 40.0 * t) * t) * exp(-t * 14.0) * 0.9 + rng.randf_range(-1, 1) * exp(-t * 90.0) * (0.7 if head else 0.3)
		if head: s[i] += sin(TAU * 1250.0 * t) * exp(-t * 30.0) * 0.18
	return FlatEscape._wav(s, R)

func _socko_line(head: bool, kill: bool) -> void:
	var s = main.get("socko")
	if not s or not s.visible or s.get("talking") or _socko_t > 0.0: return
	if main.get("speech") and main.speech.in_conversation(): return
	if not kill and not head and _rng.randf() > 0.25: return
	_socko_t = 7.0
	var pool: Array
	if kill and head: pool = ["Oh, that's lovely. Do it again.", "Did you feel that? I felt that.", "Right through the— oh, yes."]
	elif kill: pool = ["Look at that. Look at what you can do.", "See? Doesn't that feel better?", "That's my boy."]
	elif head: pool = ["Ooh. Right in the thinking.", "There it is. There's the old you."]
	else: pool = ["Again.", "Keep going.", "That's it. That's it."]
	s.call("say", pool[_rng.randi() % pool.size()], "happy", 1.0)
