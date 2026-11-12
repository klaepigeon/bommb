class_name CrackedWall
extends StaticBody3D
## A panel of wall that's given up: cracked plaster over rotten lath, filling a doorway or a gap.
## With Breach (the Infection tree), a heavy blow (fist or anything blunt) goes through it: it
## bursts into pieces and the way's open. Without it, a blow just thuds and cracks it a bit more.

signal breached

var size := Vector3(0.8, 2.05, 0.1)
var _mesh: MeshInstance3D
var _cracks := 0

static func make(parent: Node3D, centre: Vector3, sz: Vector3, yaw := 0.0) -> CrackedWall:
	var w := CrackedWall.new(); w.size = sz
	parent.add_child(w)
	w.position = centre; w.rotation.y = yaw
	return w

func _ready() -> void:
	collision_layer = 1; collision_mask = 0
	set_meta("surface", "concrete")
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = size; cs.shape = b
	add_child(cs)
	_mesh = MeshInstance3D.new(); _mesh.mesh = Build.box_mesh(size, position.y)
	_mesh.material_override = Tex.mat("plaster", 1.0, {"tint": Color(0.82, 0.78, 0.7)})
	add_child(_mesh)
	# the cracks: dark lines across both faces
	for s in [-1.0, 1.0]:
		for i in 7:
			var ln := MeshInstance3D.new(); ln.mesh = Build.box_mesh(Vector3(randf_range(0.15, 0.5), 0.012, 0.004))
			ln.material_override = Tex.mat("black")
			add_child(ln)
			ln.position = Vector3(randf_range(-size.x * 0.35, size.x * 0.35), randf_range(-size.y * 0.4, size.y * 0.4), s * (size.z * 0.5 + 0.002))
			ln.rotation.z = randf_range(-1.2, 1.2)

## The hands call this when a blow lands on it.
func punched(_dmg: float, from: Vector3, by = null) -> void:
	var heavy: bool = by != null and by.get("heavy") == true
	var kind := "blunt"
	if by != null and by.get("_prof") is Dictionary: kind = String(by._prof.get("kind", "blunt"))
	if Skills.has("s_breach") and heavy and kind == "blunt":
		_burst(from)
	else:
		_cracks += 1
		Sfx.play_at("thud", global_position, -4.0, 0.7)

func _burst(from: Vector3) -> void:
	Sfx.play_at("door_slam", global_position, 4.0, 0.6); Sfx.play_at("glass", global_position, -8.0, 0.5)
	Game.make_noise(global_position, 1.0)
	var away := (global_position - from) * Vector3(1, 0, 1)
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	for i in 10:
		var s := Vector3(randf_range(0.08, 0.25), randf_range(0.06, 0.2), 0.04)
		var bit := Prop.make(get_parent(), global_position + Vector3(randf_range(-size.x * 0.4, size.x * 0.4), randf_range(-0.8, 0.8), 0), s, Tex.mat("plaster", 1.0), "Plaster", 0.3, 0.3)
		bit.collision_layer = 16; bit.liftable = false
		bit.linear_velocity = away * randf_range(2.0, 5.0) + Vector3(0, randf_range(0.5, 2.5), 0)
		get_tree().create_timer(30.0).timeout.connect(func(): if is_instance_valid(bit): bit.queue_free())
	breached.emit()
	queue_free()
