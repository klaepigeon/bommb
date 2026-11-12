class_name Prop
extends RigidBody3D
## A loose thing in the world: a bottle, a pan, a book. Kurt can pick it up, turn it over, throw
## it. When it lands hard it makes a noise the infected can hear: the distraction system is just
## this, physics and ears.

var label := "thing"
var desc := ""               # what you notice turning it over (the exported flat's writing)
var liftable := true
var loud := 0.5             # how much noise a hard landing makes
var _last_hit := 0.0

static func make(parent: Node, pos: Vector3, size: Vector3, mat: Material, label_text: String, mass_kg := 0.5, loudness := 0.5) -> Prop:
	var p := Prop.new(); p.label = label_text; p.mass = mass_kg; p.loud = loudness
	var mi := MeshInstance3D.new(); mi.mesh = Build.box_mesh(size); mi.material_override = mat
	p.add_child(mi)
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size; cs.shape = sh
	p.add_child(cs)
	parent.add_child(p); p.global_position = pos
	return p

func _ready() -> void:
	# little things (16) don't stop a man walking; furniture (32) stops him but not her: she knows
	# her own flat in the dark, and her path goes round it
	collision_layer = 16 if get_meta("debris", false) else 32
	collision_mask = 1 | 2 | 16 | 32
	contact_monitor = true; max_contacts_reported = 2
	continuous_cd = true
	body_entered.connect(_hit)

## (picked up: a thing that brings something back to him is a memory point, once)
func on_picked(_p = null) -> void:
	if has_meta("memory_item") and not Game.flag("mem_" + String(get_meta("memory_item"))):
		Game.set_flag("mem_" + String(get_meta("memory_item")))
		Skills.award("memory", 1)

func get_prompt() -> String:
	return ("Pick up " + label.to_lower()) if liftable else ""

## A prop from the exported flat: its meshes go into a rigid body sized from the export.
static func from_export(n: Node3D, ex: Dictionary) -> Prop:
	var parent := n.get_parent()
	var p := Prop.new(); p.name = String(n.name) + "_body"
	# (decide what it is before it enters the scene: _ready picks its collision layer from this)
	var mass_kg := maxf(0.05, float(ex.get("mass", 1.0)))
	p.set_meta("debris", mass_kg < 4.0)
	parent.add_child(p)
	p.global_transform = n.global_transform
	n.reparent(p, true)
	var size: Array = ex.get("size", [0.2, 0.2, 0.2]); var centre: Array = ex.get("centre", [0, 0, 0])
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new()
	b.size = Vector3(maxf(float(size[0]), 0.03), maxf(float(size[1]), 0.03), maxf(float(size[2]), 0.03)); cs.shape = b
	cs.position = Vector3(centre[0], centre[1], centre[2])
	p.add_child(cs)
	p.mass = maxf(0.05, float(ex.get("mass", 1.0)))
	p.label = ex.get("name", "thing"); p.desc = ex.get("desc", "")
	p.liftable = p.mass <= 12.0
	p.loud = clampf(0.3 + p.mass * 0.1, 0.3, 1.0) if String(ex.get("sound", "")) != "soft" else 0.15
	var pm := PhysicsMaterial.new(); pm.friction = 0.4; pm.bounce = 0.05
	p.physics_material_override = pm
	p.can_sleep = true; p.sleeping = true
	return p

func _hit(_b: Node) -> void:
	var sp := linear_velocity.length()
	var now := Time.get_ticks_msec() / 1000.0
	if sp > 2.0 and now - _last_hit > 0.25:
		_last_hit = now
		Sfx.play_at("bullet_hit" if loud > 0.6 else "thud", global_position, -10.0 + sp * 1.5, randf_range(1.2, 1.6))
		Game.make_noise(global_position, clampf(loud * sp / 6.0, 0.1, 1.0))
