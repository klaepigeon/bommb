class_name TouchStick
extends Control
## A thumbstick for touch (and the mouse). Gives a vector of length <= 1.

var value := Vector2.ZERO
var _touch := -2
var _origin := Vector2.ZERO
const RADIUS := 44.0


func _init() -> void:
	custom_minimum_size = Vector2(120, 120)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		if e.pressed and _touch == -2:
			_touch = e.index
			_origin = size / 2
			_move(e.position)
		elif not e.pressed and e.index == _touch:
			_release()
	elif e is InputEventScreenDrag and e.index == _touch:
		_move(e.position)
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_touch = -1
			_origin = size / 2
			_move(e.position)
		else:
			_release()
	elif e is InputEventMouseMotion and _touch == -1:
		_move(e.position)


func _move(p: Vector2) -> void:
	value = ((p - size / 2) / RADIUS).limit_length(1.0)
	queue_redraw()


func _release() -> void:
	_touch = -2
	value = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var c := size / 2
	draw_circle(c, RADIUS + 6, Color(0, 0, 0, 0.35))
	draw_arc(c, RADIUS + 6, 0, TAU, 24, UiKit.GOLD, 2.0)
	draw_circle(c + value * RADIUS, 20, Color(UiKit.HOT, 0.9))
