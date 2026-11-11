class_name Revolver
extends Node3D
## The Nagant. Seven chambers, loaded one round at a time through the gate; double action, slow.
## Not a damage button: every shot is a loud event (heard ~30 m away, through walls), it costs one
## of very few rounds, and what it hits decides what it does:
##   Marta        hurt (staggered, then she pulls back, then she comes back angrier); headshots more
##   a padlock    gone (one round)
##   a door lock  shot out (one round, the door won't lock again)
##   breakables   damaged; props pushed, fragile ones broken
## Aiming at her while she can see it makes her hesitate: the threat controls space without firing.

const CAPACITY := 7
const RANGE := 30.0
const NOISE := 30.0

var player: Player
var equipped := false
var aiming := false
var loaded := 2
var _cool := 0.0
var _reloading := false
var _mesh: MeshInstance3D
var _flash: OmniLight3D
var _base_fov := 72.0

func setup(p: Player) -> void:
	player = p
	_mesh = MeshInstance3D.new()
	var mb := MB.new()
	mb.box("metal", Vector3(0, 0.0, -0.1), Vector3(0.011, 0.012, 0.09))                  # barrel
	mb.box("metal", Vector3(0, 0.0, -0.005), Vector3(0.018, 0.02, 0.026))                # cylinder
	mb.box("metal", Vector3(0, -0.012, 0.035), Vector3(0.014, 0.012, 0.02))              # frame
	mb.box("wood_dark", Vector3(0, -0.06, 0.06), Vector3(0.013, 0.05, 0.02), Basis(Vector3.RIGHT, -0.35))
	mb.box("metal", Vector3(0, 0.017, -0.18), Vector3(0.002, 0.004, 0.003))              # front sight
	var c := Color(0.35, 0.33, 0.3)
	_mesh.mesh = mb.commit({"metal": Mats.flat("metal", c), "wood_dark": Mats.flat("wood_dark", c)})
	_mesh.visible = false
	_mesh.layers = Level.CHAR_LAYER | 1
	player.arm.wrist.add_child(_mesh)
	_mesh.position = Vector3(0, 0.02, -0.02)
	_flash = OmniLight3D.new(); _flash.light_color = Color(1.0, 0.8, 0.5); _flash.omni_range = 7.0
	_flash.light_energy = 0.0; _flash.shadow_enabled = false
	player.camera.add_child(_flash)
	_flash.position = Vector3(0.1, -0.1, -0.5)
	_base_fov = player.camera.fov

func toggle_equip() -> void:
	equipped = not equipped
	if player.held and equipped:
		player.drop()
	_mesh.visible = equipped
	if not equipped:
		set_aim(false)
	player.arm.set_pose("gun" if equipped else "down", 0.35)
	Sfx.play("cylinder", -10.0, 0.8)

func set_aim(on: bool) -> void:
	if on and not equipped:
		return
	aiming = on
	player.arm.set_pose("aim" if on else ("gun" if equipped else "down"), 0.2)
	var t := create_tween()
	t.tween_property(player.camera, "fov", _base_fov * (0.72 if on else 1.0), 0.2)

func fire() -> void:
	if not equipped or _cool > 0.0:
		return
	if _reloading:
		_reloading = false
		return
	_cool = 0.75
	if loaded <= 0:
		Sfx.play_at("dry_fire", player.global_position + Vector3(0, 1.4, 0), -4.0, 1.0, 2.5, "dry_fire", player)
		Speech.bark("k_empty")
		return
	loaded -= 1
	Story.record("resource.fired", {"left": loaded})
	var origin := player.camera.global_position
	Sfx.play_at("gunshot", origin, 4.0, randf_range(0.95, 1.05), NOISE, "gunshot", player)
	_flash.light_energy = 6.0
	var ft := create_tween(); ft.tween_property(_flash, "light_energy", 0.0, 0.09)
	player.shake(0.35)
	player.arm.set_pose("throw" if not aiming else "aim", 0.05)
	get_tree().create_timer(0.15).timeout.connect(func(): player.arm.set_pose("aim" if aiming else "gun", 0.25))
	# where it goes: tight when aimed, loose from the hip
	var spread := deg_to_rad(0.6 if aiming else 4.0)
	var dir := -player.camera.global_transform.basis.z
	dir = dir.rotated(player.camera.global_transform.basis.x, randf_range(-spread, spread))
	dir = dir.rotated(Vector3.UP, randf_range(-spread, spread))
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * RANGE, 1 | 2 | 16 | 32)
	q.exclude = [player.get_rid()]
	q.collide_with_areas = false
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	# recoil
	player._pitch = clampf(player._pitch + deg_to_rad(3.5), deg_to_rad(-80), deg_to_rad(80))
	if hit.is_empty():
		Story.record("violence.shot_at_nothing")
		return
	_hit(hit.collider, hit.position, dir)
	if loaded == 1:
		Speech.bark("k_ammo_low")

func _hit(col: Object, pos: Vector3, dir: Vector3) -> void:
	Sfx.play_at("impact_flesh" if col and col.is_in_group("hunter") else "thud_light", pos, 0.0, 1.3)
	var n: Node = col as Node
	# walk up to whoever owns this collider
	while n and not n.has_method("shot") and not (n is Prop) and n.get_parent():
		if n.has_meta("interactable"):
			var it = n.get_meta("interactable")
			if it is Hook and it.target and it.target.has_method("shot"):
				it.target.shot(pos)
				return
			if it is Hook and it.target is Door:
				(it.target as Door).shot(pos)
				return
			if it is Hook and it.target is Fixtures.Breakable:
				(it.target as Fixtures.Breakable).damage(80.0)
				Story.record("route.shot_breakable")
				return
		n = n.get_parent()
	if n and n.has_method("shot"):
		n.shot(pos, dir)
	elif n is Prop:
		var p := n as Prop
		p.sleeping = false
		p.apply_impulse(dir * 6.0, pos - p.global_position)
		p.damage(40.0, player)

func reload() -> void:
	if not equipped or _reloading or loaded >= CAPACITY:
		return
	if not player.inv.has("ammo"):
		Speech.bark("k_no_ammo")
		return
	_reloading = true
	set_aim(false)
	player.arm.set_pose("loading", 0.3)
	Sfx.play("cylinder", -6.0)
	await get_tree().create_timer(0.4).timeout
	while _reloading and loaded < CAPACITY and player.inv.has("ammo"):
		await get_tree().create_timer(0.55).timeout
		if not _reloading:
			break
		player.inv.remove("ammo")
		loaded += 1
		Sfx.play("reload", -6.0, randf_range(0.95, 1.1))
		Events.noise.emit(player.global_position, 1.5, "reload", player)
	_reloading = false
	if equipped:
		player.arm.set_pose("gun", 0.3)

## weapon inspection: count what's in the cylinder by touch
func check_cylinder() -> void:
	Sfx.play("cylinder", -8.0)
	Events.toast.emit("%d in the cylinder. %d loose." % [loaded, player.inv.count("ammo")])

func _process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)

func get_state() -> Dictionary:
	return {"loaded": loaded, "equipped": equipped}

func set_state(d: Dictionary) -> void:
	loaded = int(d.get("loaded", loaded))
	if bool(d.get("equipped", false)) != equipped:
		toggle_equip()
