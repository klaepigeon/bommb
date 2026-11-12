class_name Shotgun
extends Node3D
## Papa's sawn-off (Flat 48): an IZh-43 side-by-side, the barrels cut a hand's width past the
## fore-end and the stock cut to a pistol grip, so one hand holds it (the other is Socko).
## Two barrels, one per pull; nine pellets of buckshot each, in a cone about 5 degrees wide.
## Break-open reload: both barrels at once, from loose shells ("shells" in his pocket).
## Very loud, and it kicks: the view jumps and he has to bring it down again.
## Pellets call shot(point, dir) once per thing they hit (more pellets, more knock on loose things).

const BARRELS := 2
const PELLETS := 9
const SPREAD := 0.045         # radians, the cone's half-width
const RANGE := 25.0

var player: Player
var gun: Node3D
var _kick := 0.0
var _reload_t := 0.0
var _cool := 0.0
var _raise := 0.0
var _open := 0.0              # 0 shut .. 1 broken open (reloading)
var _barrels: Node3D
var _flash: OmniLight3D

func _ready() -> void:
	name = "Shotgun"
	gun = Node3D.new(); add_child(gun)
	var steel := Tex.mat("gunmetal", 8.0, {"rough": 0.35})
	var wood := Tex.mat("wood", 10.0, {"tint": Color(0.55, 0.32, 0.2)})
	var skin := Tex.mat("skin", 4.0, {"tint": Color(1.3, 1.15, 1.05)})
	# the grip and the receiver stay; the barrels hinge down from the front of the receiver
	_part(gun, Vector3(0, -0.055, 0.03), Vector3(0.034, 0.1, 0.05), wood, Vector3(-0.35, 0, 0))      # pistol grip
	_part(gun, Vector3(0, 0.0, -0.03), Vector3(0.05, 0.045, 0.1), steel)                             # receiver
	_part(gun, Vector3(0, -0.03, -0.02), Vector3(0.008, 0.03, 0.05), steel)                          # trigger guard
	_part(gun, Vector3(0.0, -0.05, 0.035), Vector3(0.055, 0.08, 0.075), skin, Vector3(-0.3, 0, 0))   # his hand
	_part(gun, Vector3(0.0, -0.085, 0.11), Vector3(0.075, 0.085, 0.14), Tex.mat("cloth_red", 6.0, {"tint": Color(0.35, 0.3, 0.28)}), Vector3(-0.4, 0, 0))
	_barrels = Node3D.new(); _barrels.position = Vector3(0, -0.012, -0.08); gun.add_child(_barrels)
	for sx in [-0.012, 0.012]:
		var b := MeshInstance3D.new(); var cy := CylinderMesh.new()
		cy.top_radius = 0.0115; cy.bottom_radius = 0.0115; cy.height = 0.26; cy.radial_segments = 8
		b.mesh = cy; b.material_override = steel; b.rotation.x = PI * 0.5
		b.position = Vector3(sx, 0.012, -0.13); _barrels.add_child(b)
		var bore := MeshInstance3D.new(); var bc := CylinderMesh.new()
		bc.top_radius = 0.008; bc.bottom_radius = 0.008; bc.height = 0.002; bc.radial_segments = 8
		bore.mesh = bc; bore.material_override = Tex.mat("black"); bore.rotation.x = PI * 0.5
		bore.position = Vector3(sx, 0.012, -0.261); _barrels.add_child(bore)
	_part(_barrels, Vector3(0, -0.008, -0.07), Vector3(0.042, 0.02, 0.12), wood)                     # fore-end
	_flash = OmniLight3D.new(); _flash.light_color = Color("ffcf80"); _flash.omni_range = 7.0; _flash.light_energy = 0.0
	_flash.position = Vector3(0, 0.0, -0.36); gun.add_child(_flash)
	for c in gun.find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _part(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new(); mi.mesh = Build.box_mesh(size); mi.material_override = mat
	mi.position = pos; mi.rotation = rot; parent.add_child(mi)

func attach(p: Player) -> void:
	player = p
	p.hand_mount.add_child(self)

func ready_to_fire() -> bool:
	return Game.gun_out() == "shotgun" and player and player.controls and not player.held and _reload_t <= 0.0

func _unhandled_input(e: InputEvent) -> void:
	if not player or not player.controls or Game.gun_out() != "shotgun": return
	if e.is_action_pressed("fire") and not player.held: fire()
	if e.is_action_pressed("reload"): reload()

func fire() -> void:
	if not ready_to_fire() or _cool > 0.0: return
	if int(Game.shotgun.loaded) <= 0:
		Sfx.play("dry_fire", -4.0, 0.8); _cool = 0.3; return
	Game.shotgun.loaded = int(Game.shotgun.loaded) - 1
	_cool = 0.35; _kick = 1.0
	Sfx.play("gunshot", 3.0, randf_range(0.62, 0.7))
	Sfx.play("thud", -2.0, 0.6)
	Game.make_noise(player.global_position, 1.0)
	player.shake(0.02, 0.3)
	player.fov_kick = 5.0
	Fx.kick("fringe", 1.2, 0.5)
	player.add_look(Vector2(randf_range(-0.01, 0.01), 0.06))
	_flash.light_energy = 5.0
	get_tree().create_timer(0.06).timeout.connect(func(): _flash.light_energy = 0.0)
	var cam := player.cam
	var from := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var right := cam.global_transform.basis.x; var up := cam.global_transform.basis.y
	var shake := maxf(0.0, player.tremor - 0.4) * 0.06
	fwd = (fwd + right * randf_range(-shake, shake) + up * randf_range(-shake, shake)).normalized()
	var space := player.get_world_3d().direct_space_state
	var hits := {}          # target -> [count, point]
	var landed := false
	for i in PELLETS:
		var a := randf() * TAU; var r := sqrt(randf()) * SPREAD
		var dir := (fwd + right * cos(a) * r + up * sin(a) * r).normalized()
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * RANGE, 1 | 8 | 16 | 32, [player.get_rid()])
		var hit := space.intersect_ray(q)
		if hit.is_empty(): continue
		var c: Node = hit.collider
		var target := c
		for k in 4:
			if target == null or target.has_method("shot"): break
			target = target.get_parent()
		var n: Vector3 = hit.get("normal", -dir)
		if target and target.has_method("shot"):
			if not hits.has(target): hits[target] = [0, hit.position, dir]
			hits[target][0] += 1
			Fx.burst("flesh", hit.position, n)
		elif c is RigidBody3D:
			if c.has_method("wake"): c.wake()
			(c as RigidBody3D).apply_impulse(dir * 2.2, hit.position - c.global_position)
			if i % 3 == 0: Fx.burst("wood", hit.position, n)
		else:
			if i % 2 == 0: Fx.burst("dust", hit.position, n)
			if i % 4 == 0: Sfx.play_at("bullet_hit", hit.position, -6.0, randf_range(0.9, 1.2))
		landed = true
	for t in hits:
		t.shot(hits[t][1], hits[t][2])
	if not hits.is_empty(): Fx.hitstop(0.07)

func reload() -> void:
	if _reload_t > 0.0 or int(Game.shotgun.loaded) >= BARRELS or Game.count("shells") <= 0: return
	_reload_t = 1.6
	Sfx.play("door_shut", -12.0, 2.2)                 # broken open: the lever and the hinge
	await get_tree().create_timer(0.55).timeout
	Sfx.play("pickup", -8.0, 1.4)                     # the empties out
	await get_tree().create_timer(0.4).timeout
	var need: int = BARRELS - int(Game.shotgun.loaded)
	var got: int = mini(need, Game.count("shells"))
	Game.take_item("shells", got)
	Game.shotgun.loaded = int(Game.shotgun.loaded) + got
	Sfx.play("reload", -6.0, 0.75)                    # in, and snapped shut

func _process(delta: float) -> void:
	visible = Game.shotgun.get("have", false) and player != null
	if not visible: return
	_cool = maxf(0.0, _cool - delta)
	_kick = maxf(0.0, _kick - delta * 5.0)
	_reload_t = maxf(0.0, _reload_t - delta)
	var lowered: bool = (not player.controls) or player.held != null or player.running or Game.gun_out() != "shotgun"
	_raise = move_toward(_raise, 0.0 if lowered else 1.0, delta * 3.5)
	# broken open for the middle of the reload
	var want_open := 1.0 if _reload_t > 0.25 and _reload_t < 1.35 else 0.0
	_open = move_toward(_open, want_open, delta * 6.0)
	_barrels.rotation.x = -_open * 0.55
	var rest := Vector3(0.15, -0.19, -0.3).lerp(Vector3(0.22, -0.5, -0.22), 1.0 - _raise)
	gun.position = rest + Vector3(0, _open * 0.04, _kick * 0.07)
	gun.rotation = Vector3(_kick * 0.35 + _open * 0.5, 0, 0)
