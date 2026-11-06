class_name Lamp
extends Node3D
## A light in the house. Not a real Godot light: the ink shader draws its warm pool
## (see LampField). Register by being in the tree.

@export var color := Color(1.0, 0.78, 0.5)
@export var energy: float = 1.0
@export var reach: float = 24.0


static func create(parent: Node, pos: Vector3, light_color: Color, light_energy: float, light_range: float) -> Lamp:
	var l := Lamp.new()
	l.position = pos
	l.color = light_color
	l.energy = light_energy
	l.reach = light_range
	parent.add_child(l)
	return l


func _enter_tree() -> void:
	LampField.lamps.append(self)


func _exit_tree() -> void:
	LampField.lamps.erase(self)
