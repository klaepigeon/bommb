class_name Rock
extends RigidBody3D
## A thrown cobble: it lands, it clatters, and everything near enough hears where.

var _landed := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	mass = 0.8
	continuous_cd = true     # small and fast: without this it goes straight through a floor
	contact_monitor = true
	max_contacts_reported = 2
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new(); bs.size = Vector3(0.08, 0.06, 0.09)
	cs.shape = bs
	add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = bs.size
	mi.mesh = bm
	mi.material_override = Look.mat(Look.get_tex("rubble"))
	add_child(mi)
	body_entered.connect(_hit)
	get_tree().create_timer(12.0).timeout.connect(queue_free)

func _hit(_b: Node) -> void:
	if _landed:
		return
	_landed = true
	Sfx.play_at("clatter", global_position, 0.0, randf_range(0.9, 1.1))
	Noises.make(global_position, 16.0, "thrown")
