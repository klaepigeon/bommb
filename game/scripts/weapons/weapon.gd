class_name Weapon
extends Node
## What Kurt has in his right hand and what it does: the Nagant M1895 revolver (seven rounds,
## loaded one at a time through the gate), the sawn-off IZh-43 from Flat 48's safe (two barrels,
## nine pellets each, breaks open to reload), a cobble to throw, or a sticky note. Aiming brings a
## gun to his eye and steadies it; a shot is a ray (or nine) from the sights into the world and
## anything's hit boxes; every shot is a noise everything hears.

signal fired(hit: Dictionary)
signal reloaded_first
signal emptied

const MAX_LOADED := 7

var player: Player
var held := ""              ## "", "gun", "shotgun", "rock", "note"
var note_word := ""         ## the word on the note in his hand
var note_id := -1           ## which note (its place on the wall), or -1
var gun_mesh: Node3D
var shotgun_mesh: Node3D
var note_mesh: Node3D
var _barrels: Node3D
var _break := 0.0           ## the shotgun: 0 shut .. 1 broken open
var _last_gun := ""         ## what goes back in his hand when a note or a cobble leaves it
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
	var gx := Vector3(0, 1, 0)
	var gz := Vector3(0.343, 0, 0.939)
	var gy := Vector3(-0.939, 0, 0.343)
	gun_mesh.transform = Transform3D(Basis(gx, gy, gz), Vector3(-0.005, -0.028, 0.0))
	gun_mesh.visible = false
	rock_mesh = MeshInstance3D.new()
	var rm := BoxMesh.new(); rm.size = Vector3(0.07, 0.05, 0.08)
	rock_mesh.mesh = rm
	rock_mesh.material_override = Look.mat(Look.get_tex("rubble"), Color.WHITE, 0.0, false, Color(0.2, 0.2, 0.2))
	rock_mesh.position = Vector3(0, -0.045, 0.0)
	rock_mesh.visible = false
	player.arm.wrist.add_child(rock_mesh)
	shotgun_mesh = make_shotgun_model()
	_barrels = shotgun_mesh.get_node("Barrels")
	player.arm.wrist.add_child(shotgun_mesh)
	shotgun_mesh.transform = Transform3D(Basis(gx, gy, gz), Vector3(-0.005, -0.02, 0.0))
	shotgun_mesh.visible = false
	# a note held up between finger and thumb, facing him, so he can read it
	note_mesh = Node3D.new()
	player.camera.add_child(note_mesh)
	note_mesh.position = Vector3(0.1, -0.075, -0.3)
	note_mesh.rotation = Vector3(-0.1, -0.2, 0.06)
	note_mesh.visible = false
	_flash = OmniLight3D.new()
	_flash.light_color = Color("ffcf8a"); _flash.omni_range = 7.0; _flash.light_energy = 0.0
	_flash.shadow_enabled = false
	player.camera.add_child(_flash)
	_flash.position = Vector3(0, 0, -0.6)

func _build_gun() -> Node3D:
	var n := make_gun_model()
	_flash_mesh = MeshInstance3D.new()
	var fm := SphereMesh.new(); fm.radius = 0.035; fm.height = 0.07
	_flash_mesh.mesh = fm
	_flash_mesh.material_override = Look.mat(Look.get_tex("white"), Color("ffd28a"), 0.0, false, Color(4, 3, 1.5))
	_flash_mesh.position = Vector3(0, 0.048, -0.2)
	_flash_mesh.visible = false
	n.add_child(_flash_mesh)
	return n

## The Nagant M1895, from the first build: modelled to its real proportions (0.235 m), walnut
## grip, blued steel, a fluted seven-chamber cylinder. Origin: the middle of the grip. -Z: the muzzle.
static func make_gun_model() -> Node3D:
	var n := Node3D.new()
	n.name = "Nagant"
	var k := TownKit.new(n)
	var gb := Basis(Vector3.RIGHT, 0.32)
	k.box("walnut", Vector3(0, -0.012, 0.012), Vector3(0.0145, 0.052, 0.0165), gb)
	k.box("blued", Vector3(0, -0.012, 0.012), Vector3(0.0105, 0.054, 0.0175), gb, 4 | 8 | 16 | 32)
	k.cyl_axis("blued", Vector3(-0.002, -0.064, 0.03), Vector3(0.002, -0.064, 0.03), 0.006, 8)
	k.box("blued", Vector3(0, 0.038, -0.008), Vector3(0.0125, 0.018, 0.03))
	k.box("blued", Vector3(0, 0.066, -0.05), Vector3(0.007, 0.004, 0.032))
	var cy0 := Vector3(0, 0.045, -0.026); var cy1 := Vector3(0, 0.045, -0.066)
	k.cyl_axis("blued", cy0, cy1, 0.0195, 14)
	for i in 7:
		var a := TAU * i / 7.0
		var o := Vector3(cos(a), sin(a), 0) * 0.0195
		k.box("iron", (cy0 + cy1) * 0.5 + o * 1.01, Vector3(0.0025, 0.0025, 0.014), Basis(Vector3.BACK, a))
	k.cyl_axis("blued", Vector3(0, 0.048, -0.066), Vector3(0, 0.048, -0.18), 0.0078, 10)
	k.cyl_axis("iron", Vector3(0, 0.048, -0.179), Vector3(0, 0.048, -0.181), 0.0035, 8)
	k.box("blued", Vector3(0, 0.0585, -0.174), Vector3(0.0012, 0.003, 0.004))
	k.cyl_axis("blued", Vector3(0, 0.035, -0.07), Vector3(0, 0.035, -0.165), 0.0028, 6)
	k.box("blued", Vector3(0.012, 0.042, -0.022), Vector3(0.002, 0.012, 0.007))
	k.box("blued", Vector3(0, 0.062, 0.012), Vector3(0.004, 0.012, 0.004), Basis(Vector3.RIGHT, -0.5))
	k.box("blued", Vector3(0, 0.016, -0.006), Vector3(0.0025, 0.01, 0.0025), Basis(Vector3.RIGHT, 0.3))
	for i in 7:
		var a := PI * (0.05 + 0.9 * i / 6.0)
		k.box("blued", Vector3(0, 0.022 - sin(a) * 0.017, -0.006 - cos(a) * 0.018), Vector3(0.003, 0.0025, 0.004), Basis(Vector3.RIGHT, a))
	k.finish()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

## The IZh-43 from the first build: a twelve-bore side-by-side, the barrels sawn off a hand's
## width past the fore-end, the stock sawn back to a pistol grip. The barrels hinge (node "Barrels").
static func make_shotgun_model() -> Node3D:
	var n := Node3D.new()
	n.name = "IZh43"
	var k := TownKit.new(n)
	var gb := Basis(Vector3.RIGHT, 0.42)
	k.box("walnut", Vector3(0, -0.02, 0.03), Vector3(0.016, 0.06, 0.022), gb)
	k.box("walnut", Vector3(0, -0.075, 0.058), Vector3(0.017, 0.012, 0.026), gb)
	k.box("blued", Vector3(0, 0.022, -0.02), Vector3(0.021, 0.022, 0.04))
	k.box("blued", Vector3(0.006, 0.047, -0.002), Vector3(0.012, 0.004, 0.006), Basis(Vector3.UP, 0.35))
	for i in 7:
		var a := PI * (0.05 + 0.9 * i / 6.0)
		k.box("blued", Vector3(0, 0.004 - sin(a) * 0.02, -0.012 - cos(a) * 0.022), Vector3(0.003, 0.0025, 0.004), Basis(Vector3.RIGHT, a))
	k.box("blued", Vector3(-0.004, -0.006, -0.018), Vector3(0.0025, 0.009, 0.0025), Basis(Vector3.RIGHT, 0.25))
	k.box("blued", Vector3(0.004, -0.006, -0.006), Vector3(0.0025, 0.009, 0.0025), Basis(Vector3.RIGHT, 0.25))
	k.finish()
	var barrels := Node3D.new(); barrels.name = "Barrels"; n.add_child(barrels)
	barrels.position = Vector3(0, 0.008, -0.058)
	var kb := TownKit.new(barrels)
	for side: float in [-1.0, 1.0]:
		var x := side * 0.0112
		kb.cyl_axis("blued", Vector3(x, 0.02, 0.0), Vector3(x, 0.02, -0.31), 0.0112, 10)
		kb.cyl_axis("iron", Vector3(x, 0.02, -0.3095), Vector3(x, 0.02, -0.3105), 0.0092, 10)
		kb.cyl_axis("gold", Vector3(x, 0.02, -0.309), Vector3(x, 0.02, -0.3112), 0.0113, 10)
	kb.box("blued", Vector3(0, 0.033, -0.155), Vector3(0.006, 0.0025, 0.155))
	kb.box("blued", Vector3(0, 0.0, -0.155), Vector3(0.009, 0.004, 0.155))
	kb.box("walnut", Vector3(0, 0.002, -0.07), Vector3(0.019, 0.011, 0.06))
	kb.box("blued", Vector3(0, -0.009, -0.11), Vector3(0.004, 0.002, 0.008))
	kb.box("blued", Vector3(0, 0.038, -0.302), Vector3(0.0015, 0.002, 0.003))
	kb.finish()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

## A yellow sticky note with a word on it (red for the other kind).
static func make_note(word: String, parent: Node3D, color := Color(0.98, 0.9, 0.36)) -> void:
	var q := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(0.09, 0.09); q.mesh = qm
	var m := StandardMaterial3D.new(); m.albedo_color = color; m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.emission_enabled = true; m.emission = color * 0.25      # paper catches what light there is
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(q)
	var l := Label3D.new(); l.text = word; l.font_size = 30 if word.length() < 9 else 22; l.pixel_size = 0.001
	l.modulate = Color(0.12, 0.12, 0.16); l.outline_size = 0; l.position = Vector3(0, 0, 0.0015)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD; l.width = 82.0; l.double_sided = false
	parent.add_child(l)

func give_gun() -> void:
	Game.has_gun = true
	equip("gun")

func give_shotgun() -> void:
	Game.has_shotgun = true
	Game.shells_loaded = 2
	equip("shotgun")

## A note off a wall (or off a thing) into his hand.
func take_note(word: String, id: int, color := Color(0.98, 0.9, 0.36)) -> void:
	for c in note_mesh.get_children():
		c.queue_free()
	make_note(word, note_mesh, color)
	note_word = word
	note_id = id
	equip("note")

## The note's gone from his hand (stuck on something, put back); the gun comes back if he has one.
func clear_note() -> void:
	note_word = ""
	note_id = -1
	equip(_last_gun)

## The revolver and the shotgun, turn about.
func swap() -> void:
	if busy or not (Game.has_gun and Game.has_shotgun) or held not in ["gun", "shotgun"]:
		return
	equip("shotgun" if held == "gun" else "gun")
	Sfx.play("click", -8.0, 0.6)

func equip(what: String) -> void:
	held = what
	if what in ["gun", "shotgun", ""]:
		_last_gun = what
	gun_mesh.visible = what == "gun"
	shotgun_mesh.visible = what == "shotgun"
	rock_mesh.visible = what == "rock"
	note_mesh.visible = what == "note"
	if _aiming:
		player.camera.fov = 70.0
	_aiming = false
	player.arm.reach_extra = {"gun": 0.1, "shotgun": 0.26}.get(what, 0.0)
	match what:
		"gun", "shotgun": player.arm.set_pose("gun", 0.4)
		"rock": player.arm.set_pose("hold", 0.4)
		"note": player.arm.set_pose("note", 0.3)
		_: player.arm.set_pose("down", 0.4)

func set_aim(on: bool) -> void:
	if held not in ["gun", "shotgun"] or busy or on == _aiming:
		return
	_aiming = on
	player.arm.set_pose("aim" if on else "gun", 0.18)
	create_tween().tween_property(player.camera, "fov", (52.0 if held == "gun" else 60.0) if on else 70.0, 0.18)

func is_aiming() -> bool:
	return _aiming

func _process(delta: float) -> void:
	if player == null:
		return
	_kick = move_toward(_kick, 0.0, delta * (9.0 if Game.owned("steady") else 5.5))
	gun_mesh.position.z = _kick * 0.02
	shotgun_mesh.position.z = _kick * 0.035
	note_mesh.position = Vector3(0.1, -0.075 - player.arm.pull * 0.35, -0.3 + player.arm.pull)
	_barrels.rotation.x = -_break * 0.62
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
	if held == "shotgun":
		_fire_shotgun()
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

## One barrel: nine pellets in a cone round the crosshair. Devastating close, useless far, and
## louder than anything in the building. A body takes a blast as up to four hits.
func _fire_shotgun() -> void:
	if Game.shells_loaded <= 0:
		Sfx.play("click", -2.0, 0.8)
		emptied.emit()
		return
	Game.shells_loaded -= 1
	Sfx.play("boom", 2.0, randf_range(0.95, 1.03))
	Noises.make(player.global_position, 70.0, "gunshot")
	_flash.light_energy = 4.5
	_kick = 1.6
	player.shake(0.03, 0.25)
	player.add_recoil(0.12 if Game.owned("steady") else 0.2)
	var cam := player.camera
	var b := cam.global_transform.basis
	var from := cam.global_position
	var space := player.get_world_3d().direct_space_state
	var struck := {}
	var puffs := 0
	var last := {}
	for i in 9:
		var a := randf() * TAU
		var r := tan(sqrt(randf()) * deg_to_rad(4.5 if _aiming else 6.0))
		var dir := (-b.z + b.x * cos(a) * r + b.y * sin(a) * r).normalized()
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 26.0, 1 | 4, [player.get_rid()])
		q.collide_with_areas = true
		var hit := space.intersect_ray(q)
		if not hit:
			continue
		last = hit
		var c: Object = hit.collider
		if c and c.has_meta("monster") and is_instance_valid(c.get_meta("monster")):
			var m: Object = c.get_meta("monster")
			var part := String(c.get_meta("part"))
			if not struck.has(m):
				struck[m] = {"n": 0, "head": false}
			struck[m]["n"] += 1
			if part == "head":
				struck[m]["head"] = true
		elif puffs < 4:
			puffs += 1
			_puff(hit.position, hit.normal)
	for m in struck:
		for k in clampi(int(ceil(struck[m]["n"] / 2.0)), 1, 4):
			if is_instance_valid(m):
				m.shot("head" if struck[m]["head"] else "body")
	fired.emit(last)

## Break it open, a shell into each empty barrel, snap it shut.
func _reload_shotgun() -> void:
	if busy or Game.shells_loaded >= 2 or Game.shells_spare <= 0:
		return
	busy = true
	set_aim(false)
	player.arm.set_pose("loading", 0.3)
	Sfx.play("click", -4.0, 0.5)
	create_tween().tween_property(self, "_break", 1.0, 0.25)
	await get_tree().create_timer(0.4, false).timeout
	var per := 0.25 if Game.owned("quick_reload") else 0.45
	while Game.shells_loaded < 2 and Game.shells_spare > 0 and held == "shotgun":
		await get_tree().create_timer(per, false).timeout
		Game.shells_loaded += 1
		Game.shells_spare -= 1
		Sfx.play("load", -4.0, 0.7)
	create_tween().tween_property(self, "_break", 0.0, 0.15)
	Sfx.play("click", -2.0, 0.6)
	if held == "shotgun":
		player.arm.set_pose("gun", 0.3)
	await get_tree().create_timer(0.3, false).timeout
	busy = false

## One round at a time through the loading gate, while there are rounds and room.
func reload() -> void:
	if held == "shotgun":
		_reload_shotgun()
		return
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
	equip(_last_gun)
