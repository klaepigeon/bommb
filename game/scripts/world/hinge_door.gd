class_name HingeDoor
extends Node3D
## A door from the exported flat. The node is the hinge (as exported); its yaw is
## psi0 + sign * angle. A moving body on the leaf is what you aim at and what stops you.
## Angles here are in degrees (0 = shut).

signal tried(door: HingeDoor)        ## used while locked

var id := ""
var psi0 := 0.0
var sign_ := 1.0
var angle := 0.0                     ## degrees, now
var max_angle := 85.0
var locked := false
var custom := false                  ## used does nothing here but say so (`tried`): the scene decides
var leaf_w := 0.8
var leaf_h := 2.0
var body: StaticBody3D
var _tween: Tween

func setup(ex: Dictionary) -> void:
	id = String(ex.get("id", ""))
	psi0 = float(ex.get("psi0", 0.0))
	sign_ = float(ex.get("sign", 1.0))
	max_angle = minf(rad_to_deg(float(ex.get("max", 1.5))), 95.0)
	angle = rad_to_deg(float(ex.get("open", 0.0)))
	leaf_w = float(ex.get("w", 0.8))
	leaf_h = float(ex.get("h", 2.0))
	body = AnimatableBody3D.new()
	(body as AnimatableBody3D).sync_to_physics = false
	body.set_script(load("res://scripts/world/usable.gd"))
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new()
	b.size = Vector3(leaf_w, leaf_h, 0.06); cs.shape = b
	cs.position = Vector3(leaf_w * 0.5, leaf_h * 0.5, 0)
	body.add_child(cs)
	add_child(body)
	body.connect("used", _use)
	_apply()
	_refresh()

func _apply() -> void:
	rotation.y = psi0 + sign_ * deg_to_rad(angle)

func _refresh() -> void:
	if not custom:
		body.set("prompt", "Close" if angle > 10.0 else "Open")

func _use() -> void:
	if custom:
		tried.emit(self)
		return
	if locked:
		Sfx.play_at("rattle", handle_position(), -2.0)
		tried.emit(self)
		return
	swing(0.0 if angle > 10.0 else max_angle, 0.9)
	Sfx.play_at("creak", handle_position(), -10.0, 1.3)

func handle_position() -> Vector3:
	return global_transform * Vector3(leaf_w - 0.08, 1.0, 0)

func swing(to_degrees: float, seconds: float) -> Tween:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(a: float):
		angle = a
		_apply(), angle, to_degrees, seconds)
	_tween.tween_callback(_refresh)
	return _tween

func set_angle(deg: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	angle = deg
	_apply()
	_refresh()

## Shown to the crosshair or not (a door Kurt shouldn't be offered).
func set_usable(on: bool) -> void:
	body.set("enabled", on)
