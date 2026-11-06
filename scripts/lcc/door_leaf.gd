class_name DoorLeaf
extends Node3D
## A door on hinges in a doorway. It swings away from you, into the room you're going into
## (fire doors swing out, the way fire doors do). Its open angle is animated.

var portal: Dictionary
var leaf: Node3D
var is_open := false
var _swing := 1.0     # which way it opens

func setup(b: Building, p: Dictionary, floor_y: float) -> void:
	portal = p
	var at: Vector2 = p["at"]
	var w: float = p["width"]
	var h: float = p["height"]
	var d := b.portal_dir(p)
	# the hinge is at one edge of the doorway; the leaf runs along the wall from it
	var along := Vector2(0, 1) if p["axis"] == "x" else Vector2(1, 0)
	var hinge := at - along * (w / 2.0)
	position = Vector3(hinge.x, floor_y, hinge.y)
	rotation.y = atan2(-along.y, along.x)   # local +x runs along the doorway
	# open toward d: rotating about the hinge so the free edge moves along d
	var local_d := Vector3(d.x, 0, d.y).rotated(Vector3.UP, -rotation.y)
	_swing = -1.0 if local_d.z < 0.0 else 1.0
	leaf = Node3D.new()
	add_child(leaf)
	var mb := MB.new()
	var fire: bool = p.get("kind", "door") == "fire_door"
	var face := MB.mat(Tex.grime(Color("5a5e58"), Color("7a7e76"), 32, 88, 0.2)) if fire else MB.mat(Tex.wood(Color("3a2214"), 61, 32, 2))
	var brass := MB.mat(Tex.brass())
	mb.box("d", face, Vector3(w - 0.02, h - 0.01, 0.05), MB.T(Vector3(w / 2.0, h / 2.0, 0)), Color(1, 1, 1))
	if fire:
		# a push bar across both faces and a scuffed kick plate
		var bar := MB.mat(Tex.grime(Color("8a8a84"), Color("b8b8b0"), 16, 89, 0.3))
		mb.box("b", bar, Vector3(w * 0.8, 0.05, 0.05), MB.T(Vector3(w / 2.0, 1.0, 0.06)), Color(1, 1, 1))
		mb.box("b", bar, Vector3(w * 0.8, 0.05, 0.05), MB.T(Vector3(w / 2.0, 1.0, -0.06)), Color(1, 1, 1))
		mb.box("k", MB.mat(Tex.grime(Color("4a4a46"), Color("6a6a64"), 16, 90, 0.4)), Vector3(w - 0.06, 0.25, 0.06), MB.T(Vector3(w / 2.0, 0.14, 0)), Color(1, 1, 1))
	else:
		# two sunk panels a shade darker, and a brass knob both sides
		var panel := MB.mat(Tex.wood(Color("2e1a10"), 63, 32, 2))
		for side in [-1.0, 1.0]:
			mb.box("p", panel, Vector3(w * 0.6, h * 0.32, 0.01), MB.T(Vector3(w / 2.0, h * 0.72, 0.026 * side)), Color(1, 1, 1))
			mb.box("p", panel, Vector3(w * 0.6, h * 0.32, 0.01), MB.T(Vector3(w / 2.0, h * 0.3, 0.026 * side)), Color(1, 1, 1))
			mb.sphere("k", brass, 0.03, 3, 6, MB.T(Vector3(w - 0.12, 1.0, 0.05 * side)), Color(1, 1, 1))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	leaf.add_child(mi)

## Swing open or shut. Awaitable.
func set_open(open: bool, dur := 0.7) -> void:
	is_open = open
	var target := Vector3(0, -_swing * deg_to_rad(100.0) if open else 0.0, 0)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(leaf, "rotation", target, dur)
	await tw.finished

## A little push that doesn't give: it's locked.
func rattle() -> void:
	var tw := create_tween()
	for i in range(3):
		tw.tween_property(leaf, "rotation:y", -_swing * 0.03, 0.05)
		tw.tween_property(leaf, "rotation:y", 0.0, 0.05)
