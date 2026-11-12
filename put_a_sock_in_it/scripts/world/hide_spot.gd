class_name HideSpot
extends Wardrobe
## A wardrobe he can get into (docs/SYSTEMS.md). Inside, he looks out through the gap between the
## doors; she can't see him. But:
##   if she saw him get in, she comes straight to it and has him out
##   if she's hunting nearby, she may stop at the doors and listen; then it's his nerve: hold
##   his breath and stay calm and she moves on, or she hears him
## Getting in and out makes a noise (the doors), so not with her right there.

signal entered(s: HideSpot)
signal left(s: HideSpot)

var occupant: Player = null
var _since := 0.0

func _ready() -> void:
	super._ready()
	add_to_group("hide_spot")

func get_prompt() -> String:
	return "Get out" if occupant else "Hide in the wardrobe"

func interact(p = null) -> void:
	var pl := p as Player
	if not pl: return
	if occupant:
		var out := front()
		pl.leave_hiding(out, global_basis.z)
		occupant = null
		_doors()
		left.emit(self)
	else:
		occupant = pl
		pl.hide_in(self, eye())
		_doors()
		_since = 0.0
		entered.emit(self)

## Where he stands when he gets out (in front, on the floor).
func front() -> Vector3:
	return global_position + global_basis.z * (size.z * 0.5 + 0.45)

## His eyes inside: just behind the doors, looking out through the gap.
func eye() -> Transform3D:
	var at := global_position + Vector3(0, 1.55, 0) + global_basis.z * (size.z * 0.5 - 0.16)
	return Transform3D(global_basis, at)

func _doors() -> void:
	Sfx.play_at("door_creak", global_position + Vector3(0, 1.2, 0), -10.0, 1.4)
	Sfx.play_at("door_shut", global_position + Vector3(0, 1.2, 0), -8.0, 1.2)
	Game.make_noise(global_position, 0.22)

func _process(delta: float) -> void:
	if occupant: _since += delta

## (Marta) how long he's been in.
func time_inside() -> float:
	return _since if occupant else -1.0

## She has him out.
func drag_out() -> void:
	if not occupant: return
	var p := occupant
	occupant = null
	Sfx.play_at("door_slam", global_position + Vector3(0, 1.2, 0), 0.0, 1.1)
	p.leave_hiding(front(), global_basis.z)
	left.emit(self)
