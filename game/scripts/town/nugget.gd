class_name Nugget
extends Node3D
## A gutterspace nugget: a floating shard that looks like a missing texture, pink and black.
## Walk into it and it's yours.
##
## Deliberately inert. Every nugget shares one mesh and one material (made once), and taking one
## only hides it: nothing is tweened, created or freed at the moment it's taken, so a pickup is
## the same tiny amount of work every time, wherever it happens. Whoever owns the nugget does the
## counting and decides what's said about it, later, not in the same frame.

static var _shared_mesh: Mesh
static var _shared_mat: Material

var taken := false
var _mesh: MeshInstance3D
var _t := 0.0

func _ready() -> void:
	if _shared_mesh == null:
		var pm := PrismMesh.new(); pm.size = Vector3(0.14, 0.22, 0.05)
		_shared_mesh = pm
		_shared_mat = Look.mat(Look.get_tex("nugget"), Color.WHITE, 0.0, true, Color(0.9, 0.9, 0.9))
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _shared_mesh
	_mesh.material_override = _shared_mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	_t = float(hash(name) % 1000) * 0.01

func _process(delta: float) -> void:
	if taken or not visible:
		return
	_t += delta
	_mesh.rotation.y += delta * 1.6
	_mesh.position.y = sin(_t * 2.0) * 0.05

## True if he's close enough to take it (and it's there to take).
func within(p: Vector3, reach := 0.9) -> bool:
	return not taken and visible and global_position.distance_to(p) < reach

func take() -> void:
	if taken:
		return
	taken = true
	visible = false
	set_process(false)
	Trail.mark("nugget taken")
	Sfx.play("pop", -4.0, 1.6)
