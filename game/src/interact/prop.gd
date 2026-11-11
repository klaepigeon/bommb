class_name Prop
extends RigidBody3D
## A physical object. Its properties decide what can be done with it, and they matter:
##   mass         light things are held and thrown; heavy things (> CARRY_MAX) are pushed / pulled
##   noise_k      how loud it is when it lands (a pot vs a cushion)
##   sound        impact sound family: thud | glass | metal | wood | soft
##   hp           durability; fragile things also break on hard impacts (break_speed)
##   contents     item ids that fall out when it breaks (the key in the jar)
##   item_id      Take puts it in the inventory (the object is gone)
##   doc_id       Read shows the document (taken documents stay readable in the inventory)
##   tags         what it is good for: "throwable", "barricade", "insulator", "climb", "plank"...
##   inspect_text a line shown when turned over in the hands
## Collision layer 2 (props); it collides with architecture (1), props (2), the player (4) and
## the AI (16).

const CARRY_MAX := 14.0
const LAYER := 2

@export var display_name := "Object"
@export var item_id := ""
@export var doc_id := ""
@export var noise_k := 1.0
@export var sound := "thud"
@export var hp := 999.0
@export var fragile := false
@export var break_speed := 4.0
@export var inspect_text := ""
@export var persist_id := ""
var contents: Array = []
var tags: Array = []
var held := false
var light_fn: Callable            ## the level's light sampler, to relight after moving
var _mats: Array = []
var _prev_v := Vector3.ZERO
var _last_noise := 0.0
var _relit := true
var hook: Hook
var behaviour: Node = null        ## optional: radio, alarm clock... (has iverbs_extra / iverb_extra)
var _born := 0.0                  ## props settle when a level loads: no breaking, no noise, for a moment

func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 1 | 2 | 4 | 16
	contact_monitor = true
	max_contacts_reported = 3
	continuous_cd = mass < 3.0
	can_sleep = true
	linear_damp = 0.1
	angular_damp = 0.4
	body_entered.connect(_on_body_entered)
	hook = Hook.attach(self, self, display_name, persist_id)
	if persist_id != "":
		add_to_group("persist_props")
	add_to_group("props")
	var pm := PhysicsMaterial.new()
	pm.friction = 0.8 if mass > CARRY_MAX else 0.6
	pm.bounce = 0.05
	physics_material_override = pm

## register the materials that should be relit when it moves
func set_materials(mats: Array) -> void:
	_mats = mats

func is_heavy() -> bool:
	return mass > CARRY_MAX

func iverbs(p: Node) -> Array:
	var out := []
	if item_id != "":
		out.append(Interactable.v("take", "Take " + display_name.to_lower() if display_name != "" else "Take"))
	if doc_id != "" and item_id == "":
		out.append(Interactable.v("read", "Read"))
	if behaviour and behaviour.has_method("iverbs_extra"):
		out.append_array(behaviour.iverbs_extra(p))
	if is_heavy():
		out.append(Interactable.v("push", "Push", {"noise": 5.0, "time": 1.0}))
		out.append(Interactable.v("pull", "Pull", {"noise": 5.0, "time": 1.0}))
	elif not freeze or freeze_mode == RigidBody3D.FREEZE_MODE_KINEMATIC:
		if item_id == "":
			out.append(Interactable.v("hold", "Pick up"))
		out.append(Interactable.v("inspect", "Turn over"))
	if p and p.inv and p.inv.with_tag("strike") != "" and hp < 900.0 and (fragile or tags.has("breakable")):
		out.append(Interactable.v("strike", "Smash it (%s)" % ItemDB.item_name(p.inv.with_tag("strike")), {"noise": 10.0}))
	return out

func iverb(id: String, p: Node) -> void:
	match id:
		"take":
			p.inv.add(item_id)
			Sfx.play("pickup", -4.0)
			Events.toast.emit(ItemDB.item_name(item_id))
			Story.record("took:" + item_id)
			if doc_id != "":
				Events.show_document.emit(doc_id)
			_gone()
		"read":
			Events.show_document.emit(doc_id)
		"hold":
			p.hold(self)
		"inspect":
			p.inspect(self)
		"push", "pull":
			Story.record("moved:" + (persist_id if persist_id != "" else display_name))
		"strike":
			damage(25.0, p)
			Sfx.play_at("thud_light" if sound != "glass" else "glass", global_position, 0.0, 1.0, 10.0, "smash", p)
		_:
			if behaviour and behaviour.has_method("iverb_extra"):
				behaviour.iverb_extra(id, p)

## pushing and pulling are held: he keeps shoving while the button's down
func iprogress(id: String, k: float, p: Node) -> void:
	if id != "push" and id != "pull":
		return
	var dir: Vector3 = -p.camera.global_transform.basis.z
	dir.y = 0.0
	dir = dir.normalized() * (1.0 if id == "push" else -1.0)
	sleeping = false
	freeze = false
	apply_central_force(dir * mass * 13.0)
	if fmod(k * 4.0, 1.0) < 0.05:
		Sfx.play_at("scrape", global_position, -4.0, randf_range(0.8, 1.0), 6.0, "scrape", self)
		if id == "push" and p.has_method("kick"):
			p.kick()

func ifocus() -> Vector3:
	return global_position + Vector3(0, 0.4 if is_heavy() else 0.0, 0)

func _physics_process(delta: float) -> void:
	_born += delta
	# a physics spike (two things spawned overlapping, a squeeze) must never fling anything
	if linear_velocity.length() > 14.0:
		linear_velocity = linear_velocity.normalized() * 14.0
	if angular_velocity.length() > 25.0:
		angular_velocity = angular_velocity.normalized() * 25.0
	if not sleeping:
		_prev_v = linear_velocity
		_relit = false
	elif not _relit:
		_relit = true
		relight()

func relight() -> void:
	if light_fn.is_valid() and not _mats.is_empty():
		var c: Color = light_fn.call(global_position + Vector3(0, 0.2, 0), Vector3.UP)
		for m in _mats:
			(m as ShaderMaterial).set_shader_parameter("flat_light", Vector3(c.r, c.g, c.b))

func _on_body_entered(other: Node) -> void:
	var speed := _prev_v.length()
	if held or speed < 1.2 or _born < 1.5:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_noise < 0.15:
		return
	_last_noise = now
	var radius := clampf(speed * sqrt(mass) * noise_k * 0.9, 1.0, 18.0)
	var snd: String = {"glass": "thud_light", "metal": "metal", "soft": "thud_light", "wood": "thud_light"}.get(sound, "thud_heavy" if mass > 5.0 else "thud_light")
	Sfx.play_at(snd, global_position, linear_to_db(clampf(radius / 10.0, 0.1, 1.5)), randf_range(0.9, 1.1) * (1.2 if mass < 1.0 else 1.0), radius, "impact", self)
	if other and other.has_method("hit_by_object"):
		other.hit_by_object(self, speed)
	if fragile and speed > break_speed:
		break_apart()
	elif speed > 6.0 and tags.has("breakable"):
		damage(speed * mass * 0.5, null)

func damage(amount: float, _by: Node) -> void:
	hp -= amount
	if hp <= 0.0:
		break_apart()

func break_apart() -> void:
	if not is_inside_tree():
		return
	var pos := global_position
	Sfx.play_at("glass" if sound == "glass" else "thud_heavy", pos, 0.0, randf_range(0.9, 1.2), 12.0, "break", self)
	Story.record("broke:" + (persist_id if persist_id != "" else display_name))
	var parent := get_parent()
	for id in contents:
		var p := PropKit.item(String(id), light_fn)
		parent.add_child(p)
		p.global_position = pos + Vector3(randf_range(-0.1, 0.1), 0.15, randf_range(-0.1, 0.1))
	_debris(pos)
	_gone()

func _debris(pos: Vector3) -> void:
	var parent := get_parent()
	var mat: Material = _mats[0] if not _mats.is_empty() else null
	for i in 3:
		var d := RigidBody3D.new()
		d.collision_layer = 0
		d.collision_mask = 1
		d.mass = 0.1
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3.ONE * randf_range(0.03, 0.07)
		mi.mesh = bm; mi.material_override = mat; d.add_child(mi)
		var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = bm.size; cs.shape = sh; d.add_child(cs)
		parent.add_child(d)
		d.global_position = pos + Vector3(randf_range(-0.1, 0.1), 0.1, randf_range(-0.1, 0.1))
		d.linear_velocity = Vector3(randf_range(-1.5, 1.5), randf_range(1, 2.5), randf_range(-1.5, 1.5))
		get_tree().create_timer(6.0).timeout.connect(d.queue_free)

func _gone() -> void:
	if persist_id != "":
		Story.set_flag("gone:" + persist_id, true)
	Events.world_changed.emit(self, "gone")
	queue_free()

func get_state() -> Dictionary:
	return {"xf": var_to_str(global_transform)}

func set_state(d: Dictionary) -> void:
	if d.has("xf"):
		global_transform = str_to_var(d.xf)
