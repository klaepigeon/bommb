class_name Weapon
extends Node
## What Kurt has in his right hand and what it does: the Nagant M1895 revolver (seven rounds,
## loaded one at a time through the gate) or a cobble to throw. Aiming brings the gun to his eye
## and steadies it; a shot is a ray from the sights into the world and anything's hit boxes; every
## shot is a noise the whole town hears.

signal fired(hit: Dictionary)
signal reloaded_first
signal emptied

const MAX_LOADED := 7

var player: Player
var held := ""              ## "", "gun", "rock"
var gun_mesh: Node3D
var rock_mesh: MeshInstance3D
var busy := false
var _flash: OmniLight3D
var _flash_mesh: MeshInstance3D
var _kick := 0.0
var _reload_count := 0
var _aiming := false

func setup(p: Player) -> void:
	player = p
	gun_mesh = _build_gun()
	player.arm.wrist.add_child(gun_mesh)
	gun_mesh.position = Vector3(0.0, 0.035, -0.05)
	gun_mesh.visible = false
	rock_mesh = MeshInstance3D.new()
	var rm := BoxMesh.new(); rm.size = Vector3(0.07, 0.05, 0.08)
	rock_mesh.mesh = rm
	rock_mesh.material_override = Look.mat(Look.get_tex("rubble"), Color.WHITE, 0.0, false, Color(0.2, 0.2, 0.2))
	rock_mesh.position = Vector3(0, 0.04, -0.07)
	rock_mesh.visible = false
	player.arm.wrist.add_child(rock_mesh)
	_flash = OmniLight3D.new()
	_flash.light_color = Color("ffcf8a"); _flash.omni_range = 7.0; _flash.light_energy = 0.0
	_flash.shadow_enabled = false
	player.camera.add_child(_flash)
	_flash.position = Vector3(0, 0, -0.6)

func _build_gun() -> Node3D:
	var n := Node3D.new()
	var steel := Look.mat(Look.get_tex("white"), Color("2a2a2e"), 0.0, false, Color(0.15, 0.15, 0.17))
	var wood := Look.mat(Look.get_tex("wood"), Color.WHITE, 0.0, false, Color(0.2, 0.2, 0.2))
	var parts := [
		[Vector3(0.022, 0.024, 0.12), Vector3(0, 0.02, -0.115), steel],    # barrel
		[Vector3(0.03, 0.036, 0.06), Vector3(0, 0.012, -0.03), steel],     # frame
		[Vector3(0.026, 0.07, 0.03), Vector3(0, -0.035, 0.01), wood],      # grip
		[Vector3(0.008, 0.012, 0.01), Vector3(0, 0.038, -0.17), steel],    # front sight
		[Vector3(0.006, 0.02, 0.02), Vector3(0, -0.012, -0.03), steel],    # trigger
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = p[0]
		mi.mesh = bm; mi.position = p[1]; mi.material_override = p[2]
		n.add_child(mi)
	var drum := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.022; cm.bottom_radius = 0.022; cm.height = 0.04; cm.radial_segments = 7
	drum.mesh = cm; drum.material_override = steel
	drum.rotation.x = PI * 0.5; drum.position = Vector3(0, 0.012, -0.03)
	n.add_child(drum)
	_flash_mesh = MeshInstance3D.new()
	var fm := SphereMesh.new(); fm.radius = 0.035; fm.height = 0.07
	_flash_mesh.mesh = fm
	_flash_mesh.material_override = Look.mat(Look.get_tex("white"), Color("ffd28a"), 0.0, false, Color(4, 3, 1.5))
	_flash_mesh.position = Vector3(0, 0.02, -0.2)
	_flash_mesh.visible = false
	n.add_child(_flash_mesh)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

func give_gun() -> void:
	Game.has_gun = true
	equip("gun")

func equip(what: String) -> void:
	held = what
	gun_mesh.visible = what == "gun"
	rock_mesh.visible = what == "rock"
	if _aiming:
		player.camera.fov = 70.0
	_aiming = false
	match what:
		"gun": player.arm.set_pose("gun", 0.4)
		"rock": player.arm.set_pose("hold", 0.4)
		_: player.arm.set_pose("down", 0.4)

func set_aim(on: bool) -> void:
	if held != "gun" or busy or on == _aiming:
		return
	_aiming = on
	player.arm.set_pose("aim" if on else "gun", 0.18)
	create_tween().tween_property(player.camera, "fov", 52.0 if on else 70.0, 0.18)

func is_aiming() -> bool:
	return _aiming

func _process(delta: float) -> void:
	if player == null:
		return
	_kick = move_toward(_kick, 0.0, delta * (9.0 if Game.owned("steady") else 5.5))
	gun_mesh.rotation.x = _kick * 0.5
	if _flash.light_energy > 0.0:
		_flash.light_energy = maxf(_flash.light_energy - delta * 60.0, 0.0)
		if _flash.light_energy <= 0.0:
			_flash_mesh.visible = false

func fire() -> void:
	if busy:
		return
	if held == "rock":
		_throw()
		return
	if held != "gun":
		return
	if Game.ammo_loaded <= 0:
		Sfx.play("click", -2.0)
		emptied.emit()
		return
	Game.ammo_loaded -= 1
	Sfx.play("shot", 0.0, randf_range(0.95, 1.05))
	Noises.make(player.global_position, 45.0, "gunshot")
	_flash.light_energy = 3.0
	_flash_mesh.visible = true
	var spread := 0.004 if _aiming else 0.03
	if Game.owned("steady"):
		spread *= 0.6
	spread += _kick * 0.02
	_kick = 1.0
	player.shake(0.012, 0.15)
	player.add_recoil(0.05 if Game.owned("steady") else 0.09)
	var cam := player.camera
	var b := cam.global_transform.basis
	var dir := (-b.z + b.x * randf_range(-spread, spread) + b.y * randf_range(-spread, spread)).normalized()
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 60.0, 1 | 4, [player.get_rid()])
	q.collide_with_areas = true
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		_puff(hit.position, hit.normal)
		var c: Object = hit.collider
		if c and c.has_meta("monster"):
			var m = c.get_meta("monster")
			if is_instance_valid(m):
				m.shot(String(c.get_meta("part")))
		Noises.make(hit.position, 10.0, "impact")
	fired.emit(hit)

func _puff(pos: Vector3, normal: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.06, 0.06, 0.06)
	mi.mesh = bm
	mi.material_override = Look.mat(Look.get_tex("rubble"), Color("c8c0b0"), 160.0, false, Color(0.4, 0.4, 0.4))
	player.get_parent().add_child(mi)
	mi.global_position = pos + normal * 0.03
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 3.0, 0.35)
	tw.tween_property(mi, "position", mi.position + normal * 0.2 + Vector3.UP * 0.1, 0.35)
	tw.chain().tween_callback(mi.queue_free)

## One round at a time through the loading gate, while there are rounds and room.
func reload() -> void:
	if held != "gun" or busy or Game.ammo_loaded >= MAX_LOADED or Game.ammo_spare <= 0:
		return
	busy = true
	set_aim(false)
	player.arm.set_pose("loading", 0.3)
	await get_tree().create_timer(0.35, false).timeout
	var per := 0.22 if Game.owned("quick_reload") else 0.45
	while Game.ammo_loaded < MAX_LOADED and Game.ammo_spare > 0 and held == "gun":
		await get_tree().create_timer(per, false).timeout
		Game.ammo_loaded += 1
		Game.ammo_spare -= 1
		Sfx.play("load", -6.0, randf_range(0.95, 1.1))
	Sfx.play("click", -8.0, 0.8)
	player.arm.set_pose("gun", 0.3)
	await get_tree().create_timer(0.3, false).timeout
	busy = false
	_reload_count += 1
	if _reload_count == 1:
		reloaded_first.emit()

func _throw() -> void:
	busy = true
	player.arm.set_pose("throw", 0.18)
	await get_tree().create_timer(0.2, false).timeout
	var r := Rock.new()
	player.get_parent().add_child(r)
	var cam := player.camera
	var b := cam.global_transform.basis
	r.global_position = cam.global_position - b.z * 0.5 + b.x * 0.15
	var speed := 16.0 if Game.owned("the_bow") else 10.0
	r.linear_velocity = (-b.z + Vector3.UP * 0.18).normalized() * speed
	r.angular_velocity = Vector3(randf(), randf(), randf()) * 8.0
	Sfx.play("whoosh", -8.0)
	busy = false
	equip("gun" if Game.has_gun else "")
