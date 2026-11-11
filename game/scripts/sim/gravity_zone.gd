class_name GravityZone
extends Area3D
## Somewhere gravity is wrong. Loose things inside follow it (Godot's own area gravity) and wake
## up; Kurt reads `gravity_at` every step. Can be tied to a circuit (on while it's live, or while
## it's dead), so the building's wiring decides which way is down.

var vector := Vector3.DOWN
var strength := 9.8
var circuit := ""
var when_live := true
var box := AABB()
static var all: Array[GravityZone] = []

static func make(parent: Node, aabb: AABB, dir: Vector3, g: float, circ := "", on_live := true) -> GravityZone:
	var z := GravityZone.new()
	z.box = aabb; z.vector = dir.normalized(); z.strength = g; z.circuit = circ; z.when_live = on_live
	z.collision_layer = 0; z.collision_mask = 2
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = aabb.size; cs.shape = b
	z.add_child(cs)
	parent.add_child(z)
	z.global_position = aabb.get_center()
	return z

func _ready() -> void:
	gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	body_entered.connect(func(b): if b is Prop: (b as Prop).wake())
	all.append(self)
	Power.changed.connect(func(_c): _refresh())
	_refresh()

func _exit_tree() -> void:
	all.erase(self)

func active() -> bool:
	return circuit == "" or Power.live(circuit) == when_live

func _refresh() -> void:
	monitoring = true
	gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE if active() else Area3D.SPACE_OVERRIDE_DISABLED
	gravity_direction = vector; gravity = strength
	# whichever way it changed, everything in here has to notice
	for b in get_overlapping_bodies():
		if b is Prop: (b as Prop).wake()
		if b is RigidBody3D: (b as RigidBody3D).sleeping = false
	if not active():
		World.emit_event("gravity_back", {"zone": self})
		Noises.make(box.get_center(), 22.0, "crash", self)

static func gravity_at(p: Vector3) -> Vector3:
	for z in all:
		if z.active() and z.box.has_point(p):
			return z.vector * z.strength
	return Vector3.DOWN * 9.8
