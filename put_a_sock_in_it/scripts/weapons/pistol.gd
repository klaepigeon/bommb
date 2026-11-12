class_name Pistol
extends Node3D
## A Makarov PM in Kurt's right hand. Eight in the magazine, loose rounds in his pocket. He
## handles it like a man who did this for a living: the reload is quick and clean, the recoil is
## taken and gone. It's loud: every shot is a noise everything nearby hears, so it's a tool, not
## the answer. Hits call `shot(point, dir)` on whatever was hit (Marta flinches and backs off,
## props get knocked about), and leave a mark otherwise.

const MAG_SIZE := 8
const RANGE := 40.0

var player: Player
var gun: Node3D
var _kick := 0.0
var _reload_t := 0.0
var _inspect := 0.0
var _flash: OmniLight3D
var _flash_mesh: MeshInstance3D
var _cool := 0.0
var _raise := 0.0           # 0 lowered (out of view) .. 1 ready

func _ready() -> void:
	gun = Node3D.new(); add_child(gun)
	var dark := Tex.mat("gunmetal", 8.0, {"rough": 0.4})
	var grip := Tex.mat("wood", 12.0, {"tint": Color(0.5, 0.35, 0.3)})
	_part(gun, Vector3(0, 0.02, -0.07), Vector3(0.028, 0.03, 0.16), dark)        # slide
	_part(gun, Vector3(0, 0.0, -0.06), Vector3(0.026, 0.018, 0.13), dark)        # frame
	_part(gun, Vector3(0, -0.05, 0.0), Vector3(0.026, 0.09, 0.04), grip, Vector3(-0.25, 0, 0))   # grip
	_part(gun, Vector3(0, -0.025, -0.04), Vector3(0.006, 0.025, 0.04), dark)     # trigger guard
	# the hand round it: an old man's hand, knuckles and a cuff
	var skin := Tex.mat("skin", 4.0, {"tint": Color(1.3, 1.15, 1.05)})
	_part(gun, Vector3(0.0, -0.045, 0.012), Vector3(0.05, 0.075, 0.07), skin, Vector3(-0.25, 0, 0))
	_part(gun, Vector3(-0.004, -0.03, -0.03), Vector3(0.048, 0.05, 0.03), skin)
	_part(gun, Vector3(0.0, -0.075, 0.09), Vector3(0.07, 0.08, 0.14), Tex.mat("cloth_red", 6.0, {"tint": Color(0.35, 0.3, 0.28)}), Vector3(-0.35, 0, 0))
	_flash = OmniLight3D.new(); _flash.light_color = Color("ffcf80"); _flash.omni_range = 5.0; _flash.light_energy = 0.0
	_flash.position = Vector3(0, 0.02, -0.2); gun.add_child(_flash)
	_flash_mesh = MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(0.09, 0.09); _flash_mesh.mesh = q
	var fm := StandardMaterial3D.new(); fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; fm.albedo_color = Color("ffd890")
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mesh.material_override = fm; _flash_mesh.position = Vector3(0, 0.02, -0.19); _flash_mesh.visible = false
	gun.add_child(_flash_mesh)
	for c in gun.get_children():
		if c is MeshInstance3D: c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _part(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new(); mi.mesh = Build.box_mesh(size); mi.material_override = mat
	mi.position = pos; mi.rotation = rot; parent.add_child(mi)

func attach(p: Player) -> void:
	player = p
	p.hand_mount.add_child(self)

func ready_to_fire() -> bool:
	return Game.pistol.have and player and player.controls and not player.held and _reload_t <= 0.0 and _inspect < 0.5

func _unhandled_input(e: InputEvent) -> void:
	if not player or not player.controls or not Game.pistol.have: return
	if e.is_action_pressed("fire") and not player.held: fire()
	if e.is_action_pressed("reload"): reload()

func fire() -> void:
	if not ready_to_fire() or _cool > 0.0: return
	if Game.pistol.mag <= 0:
		Sfx.play("dry_fire", -6.0); _cool = 0.25; return
	Game.pistol.mag -= 1
	_cool = 0.22; _kick = 1.0
	Sfx.play("gunshot", 0.0, randf_range(0.95, 1.05))
	Game.make_noise(player.global_position, 1.0)
	player.shake(0.006, 0.12)
	Fx.kick("fringe", 0.8, 0.35)
	player.add_look(Vector2(randf_range(-0.004, 0.004), 0.018))   # muzzle climb he puts back himself
	_flash.light_energy = 3.0; _flash_mesh.visible = true; _flash_mesh.rotation.z = randf() * TAU
	get_tree().create_timer(0.05).timeout.connect(func(): _flash.light_energy = 0.0; _flash_mesh.visible = false)
	var cam := player.cam
	var from := cam.global_position; var dir := -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * RANGE, 1 | 8, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty(): return
	var c: Node = hit.collider
	var target := c
	for i in 4:
		if target == null or target.has_method("shot"): break
		target = target.get_parent()
	if target and target.has_method("shot"):
		target.shot(hit.position, dir)
	elif c is RigidBody3D:
		(c as RigidBody3D).apply_impulse(dir * 4.0, hit.position - c.global_position)
		Sfx.play_at("bullet_hit", hit.position, -2.0)
	else:
		Sfx.play_at("bullet_hit", hit.position, -2.0)
		_mark(hit.position, hit.normal)

func _mark(p: Vector3, n: Vector3) -> void:
	var d := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(0.05, 0.05); d.mesh = q
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.05, 0.04, 0.03); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	d.material_override = m
	get_tree().current_scene.add_child(d)
	d.global_position = p + n * 0.005
	if absf(n.dot(Vector3.UP)) < 0.99: d.look_at(p + n, Vector3.UP)
	else: d.look_at(p + n, Vector3.FORWARD)
	d.rotate_object_local(Vector3.UP, PI)

func reload() -> void:
	if _reload_t > 0.0 or Game.pistol.mag >= MAG_SIZE or Game.count("ammo") <= 0: return
	_reload_t = 1.0
	Sfx.play("reload", -6.0)
	await get_tree().create_timer(0.6).timeout
	var need: int = MAG_SIZE - int(Game.pistol.mag)
	var got: int = mini(need, Game.count("ammo"))
	Game.take_item("ammo", got)
	Game.pistol.mag += got

func _process(delta: float) -> void:
	visible = Game.pistol.have and player != null
	if not visible: return
	_cool = maxf(0.0, _cool - delta)
	_kick = maxf(0.0, _kick - delta * 7.0)
	_reload_t = maxf(0.0, _reload_t - delta)
	var want_inspect := player.controls and Input.is_action_pressed("inspect") and not player.held
	_inspect = move_toward(_inspect, 1.0 if want_inspect else 0.0, delta * 3.0)
	var lowered := (not player.controls) or player.held != null or player.running
	_raise = move_toward(_raise, 0.0 if lowered else 1.0, delta * 4.0)
	# ready: low right, pointing where Kurt looks; the kick snaps it up and back
	var rest := Vector3(0.17, -0.17, -0.34).lerp(Vector3(0.22, -0.45, -0.25), 1.0 - _raise)
	var dip := sin(clampf(_reload_t, 0.0, 1.0) * PI) * 0.12
	var sway := Vector3(sin(Time.get_ticks_msec() * 0.0011) * 0.003, sin(Time.get_ticks_msec() * 0.0017) * 0.002, 0)
	gun.position = rest + Vector3(0, -dip, _kick * 0.04) + sway + Vector3(-0.08, 0.05, 0.06) * _inspect
	gun.rotation = Vector3(_kick * 0.25 - dip * 2.0, _inspect * 1.3, _inspect * 0.5 + dip * 1.5)
