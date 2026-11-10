extends RigidBody3D
## A physics prop: knocked over, kicked, carried, thrown, turned over in the hand.

var title := "thing"
var desc := ""
var liftable := true

static func make(n: Node3D, ex: Dictionary) -> RigidBody3D:
	var parent := n.get_parent()
	var body := RigidBody3D.new()
	body.set_script(load("res://scripts/world/prop.gd"))
	body.name = n.name + "_body"
	parent.add_child(body)
	body.global_transform = n.global_transform
	n.reparent(body, true)
	var size: Array = ex.get("size", [0.2, 0.2, 0.2])
	var centre: Array = ex.get("centre", [0, 0, 0])
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new()
	b.size = Vector3(maxf(size[0], 0.02), maxf(size[1], 0.02), maxf(size[2], 0.02)); cs.shape = b
	cs.position = Vector3(centre[0], centre[1], centre[2])
	body.add_child(cs)
	body.mass = maxf(0.05, float(ex.get("mass", 1.0)))
	var pm := PhysicsMaterial.new(); pm.friction = 0.35; pm.bounce = 0.05     # slides when shoved (the JS build's slide material)
	body.physics_material_override = pm
	# debris (under 4 kg) is on layer 2: it collides with the world and other props but never
	# stops the player, whose feet kick it instead (player.gd). Furniture is on layer 1.
	const DEBRIS := 4.0
	body.collision_layer = 2 if body.mass < DEBRIS else 1
	body.collision_mask = 1 | 2
	body.title = ex.get("name", "thing"); body.desc = ex.get("desc", "")
	body.liftable = body.mass <= 12.0
	body.can_sleep = true; body.sleeping = true
	body.continuous_cd = body.mass < 1.0
	if body.liftable:
		# things you can throw make a noise when they land (and things hear it: Noise)
		body.contact_monitor = true; body.max_contacts_reported = 2
		body.body_entered.connect(body._on_hit)
	return body

var _hit_cd := 0
var thrown_by: Node = null      # the player, after a throw or drop, until it settles

var _speed := 0.0               # last frame's speed: by the contact signal the bounce has eaten it

func _physics_process(_d: float) -> void:
	if contact_monitor and not sleeping:
		_speed = linear_velocity.length()

func _on_hit(_other: Node) -> void:
	var v := maxf(linear_velocity.length(), _speed)
	var now := Time.get_ticks_msec()
	if v < 1.1 or now < _hit_cd or gravity_scale < 0.5:      # gravity off: it's in someone's hand
		return
	_hit_cd = now + 250
	var loud := clampf(v * pow(mass, 0.35) / 7.0, 0.1, 1.0)
	Sfx.play(get_parent(), "thud", global_position, linear_to_db(loud) + 2.0)
	Noises.make(get_tree(), global_position, loud, "impact", thrown_by if thrown_by else self)
	# a hard enough hit does damage to what can take it (a padlock): momentum, roughly
	var n: Node = _other
	while n and not n.has_method("struck"): n = n.get_parent()
	if n: n.call("struck", v * mass, self)

func prompt() -> String:
	return ("Pick up " + title.to_lower()) if liftable else ""

func interact(player: Node) -> void:
	if liftable:
		player.call("grab", self)
	else:
		Game.say("Too heavy to lift. You could push it.")
