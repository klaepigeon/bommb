class_name Door
extends Node3D
## A hinged door. The node sits on the hinge; the panel swings round Y. States: closed, open,
## locked (it rattles and says so), blocked (it gives a little and stops: something outside).
## Built in code: `width`, `height`, `material`. Emits `tried` when someone tries it shut.

signal tried(door: Door)
signal opened(door: Door)

@export var width := 0.9
@export var height := 2.05
@export var open_angle := -1.6    # radians; sign picks the swing direction
var material: Material
var locked := false
var blocked := false
var is_open := false
var name_text := "door"
var panel: AnimatableBody3D
var _busy := false

func _ready() -> void:
	panel = AnimatableBody3D.new(); panel.sync_to_physics = false
	add_child(panel)
	var mi := MeshInstance3D.new(); mi.mesh = Build.box_mesh(Vector3(width, height, 0.05))
	mi.material_override = material if material else Tex.mat("wood")
	mi.position = Vector3(width * 0.5, height * 0.5, 0)
	panel.add_child(mi)
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(width, height, 0.05)
	cs.shape = sh; cs.position = mi.position; panel.add_child(cs)
	var knob := MeshInstance3D.new(); knob.mesh = Build.box_mesh(Vector3(0.05, 0.05, 0.14))
	knob.material_override = Tex.mat("metal"); knob.position = Vector3(width - 0.09, 1.0, 0)
	panel.add_child(knob)
	if is_open: panel.rotation.y = open_angle

func get_prompt() -> String:
	if _busy: return ""
	if is_open: return "Close " + name_text
	return "Open " + name_text

func interact(_p = null) -> void:
	if _busy: return
	if locked or blocked:
		_busy = true
		Sfx.play_at("door_rattle", global_position + Vector3(0, 1, 0), -4.0)
		var tw := create_tween()
		var give := 0.04 if blocked else 0.012
		tw.tween_property(panel, "rotation:y", open_angle * give, 0.08)
		tw.tween_property(panel, "rotation:y", 0.0, 0.1)
		tw.tween_property(panel, "rotation:y", open_angle * give * 0.6, 0.08)
		tw.tween_property(panel, "rotation:y", 0.0, 0.12)
		await tw.finished
		_busy = false
		tried.emit(self)
		return
	set_open(not is_open)

func set_open(o: bool, secs := 0.7) -> void:
	is_open = o; _busy = true
	Sfx.play_at("drawer", global_position + Vector3(0, 1, 0), -8.0, 0.7)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "rotation:y", open_angle if o else 0.0, secs)
	await tw.finished
	_busy = false
	if o: opened.emit(self)
	Game.make_noise(global_position, 0.15)

## Shut it hard (the wind, someone outside).
func slam() -> void:
	is_open = false
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(panel, "rotation:y", 0.0, 0.18)
	await tw.finished
	Sfx.play_at("door_slam", global_position + Vector3(0, 1, 0), 2.0)
