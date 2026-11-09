class_name Shotgun
extends Node3D
## The gun in Flat 48's safe: an IZh-43, the Izhevsk side-by-side, twelve-bore, the hunting gun
## half the men in the Union kept by law in a steel cabinet. This one has been cut down: the
## barrels sawn off a hand's width past the fore-end, the stock sawn back to a pistol grip, so
## it's held in one hand (the other one being Socko). Somebody did that with a hacksaw at a
## kitchen table; the cuts are bright and not quite square.
##
## Two barrels, two shells. Each pull fires the next barrel: nine pellets of buckshot in a cone,
## devastating close, useless far, and louder than anything in the building. Reload: it breaks
## open, the spent hulls kick out over his shoulder, a shell into each barrel, snap shut.
##
## Origin: the middle of the grip, where Kurt's right hand holds it; the barrels along -Z.

signal fired(hits: Array)
signal emptied

const CAPACITY := 2
const PELLETS := 9
const SPREAD := deg_to_rad(4.5)
const RANGE := 26.0
const HIP := Vector3(0.13, -0.19, -0.36)
const LOAD_EACH := 0.45

var kind := "shotgun"
var capacity := CAPACITY
var loaded := CAPACITY
var spare := 0
var drawn := false
var player: Node
var cam: Camera3D
var reloading := false
var headshot_kills := false
var reload_each := LOAD_EACH
var kick_scale := 1.0

var _kick := 0.0
var _flash: OmniLight3D
var _flash_q: MeshInstance3D
var _flash_t := 0.0
var _break := 0.0          # 0 shut .. 1 broken open
var _barrels: Node3D
var _holes: Array = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_model()
	_flash = OmniLight3D.new(); _flash.light_color = Color(1.0, 0.72, 0.4); _flash.omni_range = 7.0; _flash.light_energy = 0.0
	_flash.position = Vector3(0, 0.03, -0.38); add_child(_flash)
	_flash_q = MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(0.16, 0.16); _flash_q.mesh = qm
	var fm := StandardMaterial3D.new(); fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; fm.albedo_color = Color(1.0, 0.8, 0.45)
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_texture = Revolver._star(); _flash_q.material_override = fm; _flash_q.visible = false
	_flash_q.position = Vector3(0, 0.03, -0.39); add_child(_flash_q)
	Revolver.ensure_inputs()

func equip(p_player: Node) -> void:
	player = p_player; cam = player.get("cam")
	if get_parent(): get_parent().remove_child(self)
	player.get_parent().add_child(self)
	top_level = true
	drawn = true
	player.set("gun", self)
	var arm = player.get("armory")
	if arm: arm.call("add", self)
	SkillEffects.apply_to_gun(self)

# ---------------------------------------------------------------- the model
## IZh-43 proportions: 12-bore tubes 22 mm across side by side, a boxlock action, a top lever;
## here the barrels cut to 31 cm and the butt sawn off behind the wrist.
func _model() -> void:
	var k := TownKit.new(self)
	# the sawn pistol grip, walnut, chequered where the hand goes, the saw cut at its end
	var gb := Basis(Vector3.RIGHT, 0.42)
	k.box("walnut", Vector3(0, -0.02, 0.03), Vector3(0.016, 0.06, 0.022), gb)
	k.box("walnut", Vector3(0, -0.075, 0.058), Vector3(0.017, 0.012, 0.026), gb)        # the raw cut, a little proud
	# the action: a boxlock frame, case-hardened grey, the top lever, the trigger guard, two triggers
	k.box("blued", Vector3(0, 0.022, -0.02), Vector3(0.021, 0.022, 0.04))
	k.box("blued", Vector3(0.006, 0.047, -0.002), Vector3(0.012, 0.004, 0.006), Basis(Vector3.UP, 0.35))
	for i in 7:
		var a := PI * (0.05 + 0.9 * i / 6.0)
		k.box("blued", Vector3(0, 0.004 - sin(a) * 0.02, -0.012 - cos(a) * 0.022), Vector3(0.003, 0.0025, 0.004), Basis(Vector3.RIGHT, a))
	k.box("blued", Vector3(-0.004, -0.006, -0.018), Vector3(0.0025, 0.009, 0.0025), Basis(Vector3.RIGHT, 0.25))
	k.box("blued", Vector3(0.004, -0.006, -0.006), Vector3(0.0025, 0.009, 0.0025), Basis(Vector3.RIGHT, 0.25))
	k.finish()
	# the barrels and fore-end hinge on the action's knuckle: their own node, to break open
	_barrels = Node3D.new(); _barrels.name = "Barrels"; add_child(_barrels)
	_barrels.position = Vector3(0, 0.008, -0.058)
	var kb := TownKit.new(_barrels)
	for side: float in [-1.0, 1.0]:
		var x := side * 0.0112
		kb.cyl_axis("blued", Vector3(x, 0.02, 0.0), Vector3(x, 0.02, -0.31), 0.0112, 10)
		kb.cyl_axis("iron", Vector3(x, 0.02, -0.3095), Vector3(x, 0.02, -0.3105), 0.0092, 10)     # the bore, black
		kb.cyl_axis("gold", Vector3(x, 0.02, -0.309), Vector3(x, 0.02, -0.3112), 0.0113, 10)      # the saw cut: bright steel
	kb.box("blued", Vector3(0, 0.033, -0.155), Vector3(0.006, 0.0025, 0.155))                     # the rib between them
	kb.box("blued", Vector3(0, 0.0, -0.155), Vector3(0.009, 0.004, 0.155))                        # and under
	kb.box("walnut", Vector3(0, 0.002, -0.07), Vector3(0.019, 0.011, 0.06))                       # the fore-end
	kb.box("blued", Vector3(0, -0.009, -0.11), Vector3(0.004, 0.002, 0.008))                      # its catch
	kb.box("blued", Vector3(0, 0.038, -0.302), Vector3(0.0015, 0.002, 0.003))                     # the bead
	kb.finish()
	for mi in find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(mi as MeshInstance3D).layers = 1 | 2

func grip_global() -> Transform3D:
	return global_transform

# ---------------------------------------------------------------- in the hand
func _process(delta: float) -> void:
	if not player or not cam:
		return
	visible = drawn
	if not drawn:
		return
	var want := cam.global_transform * Transform3D(Basis(), HIP)
	var target := want.origin
	var pos := global_position.lerp(target, 1.0 - exp(-delta * 18.0)) if global_position.distance_to(target) < 0.5 else target
	_kick = move_toward(_kick, 0.0, delta * 3.0)
	var aim_at := cam.global_position - cam.global_transform.basis.z * 7.0
	var b := Basis.looking_at((aim_at - pos).normalized(), cam.global_transform.basis.y)
	b = b * Basis(Vector3.UP, 0.12) * Basis(Vector3.BACK, -0.06)
	# broken open: the muzzles drop, the gun tips up to the breech, the hand rolls it toward him
	b = b * Basis(Vector3.RIGHT, _kick * 0.5 + _break * 0.35) * Basis(Vector3.BACK, _break * 0.5)
	global_transform = Transform3D(b, pos - b.z * (-_kick * 0.05) + b.y * _break * 0.04)
	_barrels.rotation.x = -_break * 0.62
	_flash_t -= delta
	_flash.light_energy = maxf(0.0, _flash_t) * 90.0
	_flash_q.visible = _flash_t > 0.0

func _unhandled_input(e: InputEvent) -> void:
	if not player or player.get("locked") or player.get("gun") != self: return
	if drawn and e.is_action_pressed("reload"):
		reload()
	elif drawn and e.is_action_pressed("throw") and player.get("held") == null:
		fire(); get_viewport().set_input_as_handled()

func toggle() -> void:
	if reloading: return
	drawn = not drawn
	_sfx(Revolver._click(0.5))

## One barrel: nine pellets in a cone round the crosshair. Whatever takes a shot takes it once
## per blast however many pellets hit it (a padlock, Marta, a figure), with the pellet count, so
## a full face of buckshot at arm's length is what it is.
func fire() -> void:
	if not drawn or reloading: return
	if loaded <= 0:
		_sfx(Revolver._click(0.8)); emptied.emit(); return
	loaded -= 1
	_kick = kick_scale; _flash_t = 0.07
	player.set("shake", 1.1 * kick_scale)
	player.set("pitch", float(player.get("pitch")) + 0.06 * kick_scale)
	_sfx(_boom())
	Noises.make(get_tree(), global_position, 1.0, "gunshot", player)
	var from := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var right := cam.global_transform.basis.x; var up := cam.global_transform.basis.y
	var space := get_world_3d().direct_space_state
	var struck := {}          # node -> [hit, pellets]
	var hits := []
	for i in PELLETS:
		var a := _rng.randf() * TAU; var r := sqrt(_rng.randf()) * SPREAD
		var dir := (fwd + right * cos(a) * tan(r) + up * sin(a) * tan(r)).normalized()
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * RANGE); q.exclude = [player.get_rid()]; q.collide_with_areas = true
		var hit := space.intersect_ray(q)
		if not hit: continue
		hits.append(hit)
		var n: Node = hit.collider as Node
		while n and not n.has_method("shot"): n = n.get_parent()
		if n:
			if struck.has(n): struck[n][1] += 1
			else: struck[n] = [hit, 1]
		elif hit.collider is RigidBody3D:
			var rb := hit.collider as RigidBody3D
			rb.apply_impulse(dir * 2.6, hit.position - rb.global_position)
		else:
			_hole(hit.position, hit.normal)
	for n in struck:
		var h: Dictionary = struck[n][0]
		var pellets: int = struck[n][1]
		# close enough for most of the pattern: a body takes it as several hits
		for k in clampi(int(ceil(pellets / 2.0)), 1, 4):
			if not is_instance_valid(n): break
			n.call("shot", h.position, h.normal, headshot_kills, h.get("shape", 0))
	fired.emit(hits)

## Break it open, the spent hulls out over his shoulder, a shell into each empty barrel, shut.
func reload() -> void:
	if reloading or loaded >= CAPACITY or spare <= 0: return
	reloading = true
	_sfx(Revolver._click(0.45))
	var t := 0.0
	while t < 0.22:
		await get_tree().process_frame
		t += get_process_delta_time(); _break = clampf(t / 0.22, 0.0, 1.0)
	_break = 1.0
	for i in CAPACITY - loaded:
		_eject()
	await get_tree().create_timer(0.18).timeout
	while loaded < CAPACITY and spare > 0 and reloading:
		await get_tree().create_timer(reload_each).timeout
		loaded += 1; spare -= 1
		_sfx(Revolver._click(1.1))
	await get_tree().create_timer(0.12).timeout
	t = 0.0
	while t < 0.14:
		await get_tree().process_frame
		t += get_process_delta_time(); _break = 1.0 - clampf(t / 0.14, 0.0, 1.0)
	_break = 0.0
	_sfx(_snap())
	reloading = false

## a spent hull: red paper and brass, kicked back out of the breech, left where it lands
func _eject() -> void:
	var b := RigidBody3D.new(); b.mass = 0.012; b.collision_layer = 2; b.collision_mask = 1
	var cs := CollisionShape3D.new(); var sh := CylinderShape3D.new(); sh.radius = 0.011; sh.height = 0.07; cs.shape = sh; cs.rotation.x = PI * 0.5; b.add_child(cs)
	var k := TownKit.new(b)
	k.cyl_axis("lipstick", Vector3(0, 0, -0.035), Vector3(0, 0, 0.02), 0.0105, 8)
	k.cyl_axis("gold", Vector3(0, 0, 0.02), Vector3(0, 0, 0.035), 0.011, 8)
	k.finish()
	player.get_parent().add_child(b)
	b.global_transform = global_transform * Transform3D(Basis(), Vector3(0, 0.03, -0.06))
	b.linear_velocity = global_transform.basis * Vector3(_rng.randf_range(-0.4, 0.4), 1.6, 1.8)
	b.angular_velocity = Vector3(_rng.randf_range(-12, 12), _rng.randf_range(-12, 12), 0)
	get_tree().create_timer(30.0).timeout.connect(func(): if is_instance_valid(b): b.queue_free())

func _hole(at: Vector3, n: Vector3) -> void:
	var m := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(0.02, 0.02); m.mesh = qm
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.05, 0.04, 0.04); mat.roughness = 1.0
	mat.albedo_texture = Revolver._star(); mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.material_override = mat
	player.get_parent().add_child(m)
	var up := Vector3.UP if absf(n.y) < 0.95 else Vector3.RIGHT
	m.global_transform = Transform3D(Basis.looking_at(-n, up), at + n * 0.004)
	_holes.append(m)
	if _holes.size() > 90: (_holes.pop_front() as Node).queue_free()

# ---------------------------------------------------------------- sound (synthesised)
func _sfx(w: AudioStreamWAV) -> void:
	var ap := AudioStreamPlayer.new(); ap.stream = w; ap.volume_db = -1.0
	add_child(ap); ap.play(); ap.finished.connect(ap.queue_free)

static var _boom_cache: AudioStreamWAV
## deeper and longer than the revolver: a twelve-bore in a concrete stairwell
static func _boom() -> AudioStreamWAV:
	if _boom_cache: return _boom_cache
	const RATE := 22050
	var n := int(RATE * 2.2)
	var bytes := PackedByteArray(); bytes.resize(n * 2)
	var rng := RandomNumberGenerator.new(); rng.seed = 43
	var lp := 0.0; var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var crack := rng.randf_range(-1, 1) * exp(-t * 35.0)
		lp += (rng.randf_range(-1, 1) - lp) * 0.09
		lp2 += (lp - lp2) * 0.04
		var body := sin(TAU * 48.0 * t * (1.0 - t * 0.5)) * exp(-t * 9.0)
		var tail := lp2 * 3.6 * exp(-t * 2.0)
		bytes.encode_s16(i * 2, int(clampf(crack + body + tail, -1.0, 1.0) * 31000.0))
	_boom_cache = AudioStreamWAV.new(); _boom_cache.format = AudioStreamWAV.FORMAT_16_BITS; _boom_cache.mix_rate = RATE; _boom_cache.data = bytes
	return _boom_cache

static func _snap() -> AudioStreamWAV:
	const RATE := 22050
	var n := int(RATE * 0.12)
	var bytes := PackedByteArray(); bytes.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var s := sin(TAU * 1400.0 * t) * exp(-t * 90.0) + sin(TAU * 420.0 * t) * exp(-t * 40.0) * 0.8
		bytes.encode_s16(i * 2, int(clampf(s * 0.6, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.data = bytes
	return w
