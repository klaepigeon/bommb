class_name MgView
extends Node3D
## Base for a minigame's look (the rules are in scripts/minigames/). GameView makes one
## when a minigame starts, feeds it every view and event, and frees it after.

var gv: GameView
var center := Vector3(0, 0, 0.6)


func setup(g: GameView, _view: Dictionary) -> void:
	gv = g


func update_view(_view: Dictionary, _dt: float) -> void:
	pass


func on_event(_e: Dictionary) -> void:
	pass


## [camera position, look-at point]
func camera() -> Array:
	return [Vector3(0, 10, 10.5), center]


## Something every view needs: a contestant's figure.
func fig(seat: int) -> Contestant:
	return gv.contestants[seat]
