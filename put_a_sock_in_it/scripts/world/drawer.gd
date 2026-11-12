class_name Drawer
extends AnimatableBody3D
## A drawer that slides out along its local +Z. Whatever is parented to it rides along.

signal opened(d: Drawer)
@export var size := Vector3(0.5, 0.16, 0.45)
@export var travel := 0.32
var material: Material
var is_open := false
var _busy := false
var _rest := Vector3.ZERO

func _ready() -> void:
	sync_to_physics = false
	_rest = position
	var mi := MeshInstance3D.new(); mi.mesh = Build.box_mesh(size)
	mi.material_override = material if material else Tex.mat("wood_light", 2.0)
	add_child(mi)
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size; cs.shape = sh; add_child(cs)
	var h := MeshInstance3D.new(); h.mesh = Build.box_mesh(Vector3(0.12, 0.025, 0.03))
	h.material_override = Tex.mat("metal"); h.position = Vector3(0, 0, size.z * 0.5 + 0.015); add_child(h)

func get_prompt() -> String:
	return "" if _busy else ("Close drawer" if is_open else "Open drawer")

func interact(_p = null) -> void:
	if _busy: return
	_busy = true; is_open = not is_open
	Sfx.play_at("drawer", global_position, -6.0)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", _rest + transform.basis.z * (travel if is_open else 0.0), 0.45)
	await tw.finished
	_busy = false
	if is_open: opened.emit(self)
