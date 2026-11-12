class_name ExportDoor
extends Node3D
## A door from the exported flat. The node is the hinge (as exported) and the leaf meshes are its
## children; its yaw is psi0 + sign * angle. An AnimatableBody on the leaf blocks and pushes.
## Same interface as Door: locked (rattles), blocked (gives a little and stops), set_open, slam.

signal tried(door)
signal opened(door)

var psi0 := 0.0
var sign_ := 1.0
var angle := 0.0
var target := 0.0
var max_angle := 1.5
var leaf_w := 0.8
var locked := false
var blocked := false
var name_text := "door"
var is_open := false
var _busy := false

func setup(ex: Dictionary) -> void:
	psi0 = ex.get("psi0", 0.0); sign_ = ex.get("sign", 1.0); max_angle = maxf(1.2, ex.get("max", 1.5))
	angle = ex.get("open", 0.0); target = angle; leaf_w = ex.get("w", 0.8)
	is_open = angle > 0.15
	var body := AnimatableBody3D.new(); body.sync_to_physics = false
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new()
	b.size = Vector3(leaf_w, ex.get("h", 2.0), 0.06); cs.shape = b
	cs.position = Vector3(leaf_w * 0.5, ex.get("h", 2.0) * 0.5, 0)
	body.add_child(cs); add_child(body)
	body.set_meta("surface", "wood")
	_apply()

func _apply() -> void:
	rotation.y = psi0 + sign_ * angle

func _physics_process(delta: float) -> void:
	if absf(target - angle) > 0.001:
		angle = move_toward(angle, target, delta * maxf(0.8, absf(target - angle) * 3.0))
		_apply()

func get_prompt() -> String:
	if _busy: return ""
	return ("Close " if is_open else "Open ") + name_text

func interact(_p = null) -> void:
	if _busy: return
	if locked or blocked:
		_busy = true
		var at := global_position + global_basis * Vector3(leaf_w * 0.5, 1.0, 0)
		Sfx.play_at("door_rattle", at, -2.0)
		var give := 0.05 if blocked else 0.015
		for i in 2:
			target = give; await get_tree().create_timer(0.09).timeout
			target = 0.0; await get_tree().create_timer(0.12).timeout
		_busy = false
		tried.emit(self)
		return
	set_open(not is_open)

func set_open(o: bool, _secs := 0.7) -> void:
	is_open = o
	target = max_angle if o else 0.0
	var at := global_position + global_basis * Vector3(leaf_w * 0.5, 1.0, 0)
	Sfx.play_at("door_creak" if o else "door_shut", at, -6.0, randf_range(0.9, 1.1))
	Game.make_noise(at, 0.15)
	if o: opened.emit(self)

func slam() -> void:
	is_open = false; target = 0.0; angle = 0.0; _apply()
	Sfx.play_at("door_slam", global_position + Vector3(0, 1, 0), 4.0)
