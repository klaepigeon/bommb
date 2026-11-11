class_name Prop
extends RigidBody3D
## A loose thing. It sleeps frozen where it was put (so a cluttered shelf doesn't jitter on a phone)
## until something disturbs it: a hand, a foot, a door, another thing landing on it, gravity
## changing. Then it's physical: it can be carried, thrown, stacked, piled against a door. It
## makes a noise when it lands (as loud as it's heavy and fast), and what breaks, breaks: glass
## and china shatter, a jar of water spills. In water, the light ones float.

var key := ""                    ## its stable id (the model's node name, or one made here)
var title := ""
var desc := ""
var stuff := "wood"              ## wood, glass, china, metal, cloth, paper, plastic, flesh
var item := ""                   ## if set, it goes in a pocket (Inventory id) instead of the hand
var contents := ""               ## "water"
var floats := false
var breakable := false
var doc := ""                    ## docs.json key, if it's something to read
var awake := false
var held := false
var _last_hit := 0.0
var _rng := RandomNumberGenerator.new()

static func make(parent: Node, xf: Transform3D, size: Vector3, p_mass: float, centre := Vector3.ZERO) -> Prop:
	var p := Prop.new()
	p.mass = maxf(p_mass, 0.05)
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new()
	b.size = size.max(Vector3(0.04, 0.04, 0.04)); cs.shape = b; cs.position = centre
	p.add_child(cs)
	parent.add_child(p)
	p.global_transform = xf
	return p

func _init() -> void:
	collision_layer = 2
	collision_mask = 1 | 2
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	contact_monitor = true
	max_contacts_reported = 2
	continuous_cd = false
	can_sleep = true
	linear_damp = 0.05
	angular_damp = 0.4
	body_entered.connect(_hit)

func _ready() -> void:
	_rng.randomize()
	if stuff in ["glass", "china"]:
		breakable = true
	var pm := PhysicsMaterial.new()
	pm.friction = 0.8 if stuff in ["cloth", "paper", "flesh"] else 0.55
	pm.bounce = 0.0 if stuff in ["cloth", "paper", "flesh"] else 0.15
	physics_material_override = pm

func wake() -> void:
	if not awake:
		awake = true
		freeze = false
		sleeping = false

func _hit(other: Node) -> void:
	if other is Prop and not (other as Prop).awake:
		(other as Prop).wake()
	var sp := linear_velocity.length()
	var now := Time.get_ticks_msec() / 1000.0
	if sp < 1.2 or now - _last_hit < 0.15 or held:
		return
	_last_hit = now
	var loud := clampf(sp * sqrt(mass) * 2.2, 2.0, 20.0)
	var snd := "thud"
	match stuff:
		"glass", "china", "metal": snd = "clink"
		"cloth", "paper", "flesh": snd = "step_soft"
	Audio.play(snd, global_position, clampf(-14.0 + loud, -14.0, 4.0), _rng.randf_range(0.85, 1.2) * (1.4 if mass < 0.5 else 1.0))
	Noises.make(global_position, loud, "impact", self)
	World.emit_event("impact", {"prop": self, "speed": sp, "other": other})
	if other is Node and other.has_method("struck_by"):
		other.struck_by(self, sp)
	if breakable and sp > 3.2:
		shatter()

func shatter() -> void:
	Audio.play("glass", global_position, 2.0, _rng.randf_range(0.9, 1.1))
	Noises.make(global_position, 14.0, "glass", self)
	World.emit_event("shattered", {"prop": self, "key": key, "contents": contents, "at": global_position})
	for i in 6:
		var s := MeshInstance3D.new(); var bm := BoxMesh.new()
		bm.size = Vector3(0.03, 0.005, 0.02) * _rng.randf_range(0.6, 1.6); s.mesh = bm
		s.material_override = Mats.flat(Color(0.7, 0.75, 0.72) if stuff == "glass" else Color(0.85, 0.85, 0.8), -1)
		get_parent().add_child(s)
		s.global_position = global_position
		var to := global_position + Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4))
		to.y = maxf(to.y - 2.0, _floor_y(to))
		s.rotation = Vector3(0, _rng.randf() * TAU, 0)
		s.create_tween().tween_property(s, "global_position", to, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if contents == "water":
		Puddle.spill(get_parent(), global_position, 0.5)
	World.set_flag("broken_" + key)
	queue_free()

func _floor_y(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.5, 0), p + Vector3(0, -4, 0), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return (hit.position as Vector3).y + 0.003 if hit else p.y - 2.0

# --------------------------------------------------------------------------------------- verbs
func get_verbs(k) -> Array:
	var v: Array = []
	if held:
		return v
	if item != "":
		v.append({"id": "pocket", "label": "Take"})
	elif k.can_lift(self):
		v.append({"id": "lift", "label": "Pick up"})
	else:
		v.append({"id": "shove", "label": "Push"})
	if doc != "":
		v.append({"id": "read", "label": "Read"})
	elif desc != "":
		v.append({"id": "look", "label": "Look"})
	return v

func act(verb: String, k) -> void:
	match verb:
		"pocket": k.pocket(self)
		"lift": k.lift(self)
		"shove":
			wake()
			apply_central_impulse((global_position - k.global_position).normalized() * Vector3(1, 0, 1) * mass * 0.9)
			Audio.play("scrape", global_position, -6.0)
			Noises.make(global_position, 6.0, "scrape", k)
		"read": k.read_doc(doc, title)
		"look": k.look_at_thing(title, desc, key)

func save() -> Dictionary:
	return {"xf": global_transform, "awake": awake}

func load_state(d: Dictionary) -> void:
	if d.has("xf"):
		global_transform = d.xf
	if bool(d.get("awake", false)):
		wake()
