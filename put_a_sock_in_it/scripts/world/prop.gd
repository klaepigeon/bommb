class_name Prop
extends RigidBody3D
## A loose thing in the world: a bottle, a pan, a book. Kurt can pick it up, turn it over, throw
## it. When it lands hard it makes a noise the infected can hear: the distraction system is just
## this, physics and ears.

var label := "thing"
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
	collision_layer = 1; collision_mask = 1 | 2
	contact_monitor = true; max_contacts_reported = 2
	continuous_cd = true
	body_entered.connect(_hit)

func get_prompt() -> String:
	return "Pick up " + label

func _hit(_b: Node) -> void:
	var sp := linear_velocity.length()
	var now := Time.get_ticks_msec() / 1000.0
	if sp > 2.0 and now - _last_hit > 0.25:
		_last_hit = now
		Sfx.play_at("bullet_hit" if loud > 0.6 else "thud", global_position, -10.0 + sp * 1.5, randf_range(1.2, 1.6))
		Game.make_noise(global_position, clampf(loud * sp / 6.0, 0.1, 1.0))
