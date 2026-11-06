class_name Padlock
extends Node3D
## A combination padlock hanging off a chain: a brass body and a row of little number wheels.
## Tap the top half of a wheel to turn it up, the bottom half to turn it down.

signal turned(code: String)

var digits: Array = []
var wheels: Array = []     # Node3D per wheel (rotates about x)
var labels: Array = []     # Label3D per wheel showing the digit at the front
const WHEEL_R := 0.022
const PITCH := 0.034

func setup(n: int, pos: Vector3, facing: Vector2) -> void:
	position = pos
	rotation.y = atan2(facing.x, facing.y)
	var brass := MB.mat(Tex.brass())
	var iron := MB.mat(Tex.grime(Color("2a2a28"), Color("4a4a46"), 16, 91, 0.3))
	var mb := MB.new()
	var width := n * PITCH + 0.03
	mb.box("b", brass, Vector3(width, 0.08, 0.035), MB.T(Vector3(0, 0, 0)), Color(1, 1, 1))
	# the shackle and two turns of chain up to the push bar
	mb.ring("s", iron, 0.03, 0.006, 10, MB.T(Vector3(0, 0.07, 0), Vector3(0, 0, 0)), Color(1, 1, 1))
	for i in range(6):
		mb.box("c", iron, Vector3(0.018, 0.04, 0.008 if i % 2 == 0 else 0.018), MB.T(Vector3(-0.02 + i * 0.012, 0.11 + i * 0.03, -0.01), Vector3(0, 0, 0.4)), Color(1, 1, 1))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	add_child(mi)
	var font: Font = load("res://assets/fonts/special_elite.ttf")
	for i in range(n):
		digits.append(0)
		var w := Node3D.new()
		w.position = Vector3(-((n - 1) * PITCH) / 2.0 + i * PITCH, -0.005, 0.03)
		add_child(w)
		var wm := MB.new()
		wm.cyl("w", MB.mat(Tex.grime(Color("c8b890"), Color("e8dcc0"), 16, 92 + i, 0.2)), WHEEL_R, WHEEL_R, PITCH * 0.8, 10, MB.T(Vector3(-PITCH * 0.4, 0, 0), Vector3(0, 0, -PI / 2)), Color(1, 1, 1))
		var wmi := MeshInstance3D.new()
		wmi.mesh = wm.build()
		w.add_child(wmi)
		var l := Label3D.new()
		l.font = font
		l.font_size = 40
		l.pixel_size = 0.0007
		l.modulate = Color("7a0a08")
		l.outline_size = 0
		l.position = Vector3(0, 0, WHEEL_R + 0.0015)
		l.shaded = false
		l.double_sided = false
		l.text = "0"
		w.add_child(l)
		wheels.append(w)
		labels.append(l)

func code() -> String:
	return "".join(digits.map(func(d): return str(d)))

## Which wheel (and which half) is under a point on the screen: [index, +1 up / -1 down] or [].
func pick(stage: Stage, screen_pos: Vector2) -> Array:
	for i in range(wheels.size()):
		var w: Node3D = wheels[i]
		var c := w.global_position + global_transform.basis.z * WHEEL_R
		var top := stage.world_to_screen(c + global_transform.basis.y * WHEEL_R * 1.2)
		var bot := stage.world_to_screen(c - global_transform.basis.y * WHEEL_R * 1.2)
		var left := stage.world_to_screen(c - global_transform.basis.x * PITCH * 0.5)
		var right := stage.world_to_screen(c + global_transform.basis.x * PITCH * 0.5)
		var r := Rect2(Vector2(minf(left.x, right.x), minf(top.y, bot.y)), Vector2.ZERO).expand(Vector2(maxf(left.x, right.x), maxf(top.y, bot.y)))
		if r.grow(4.0).has_point(screen_pos):
			return [i, 1 if screen_pos.y < (top.y + bot.y) / 2.0 else -1]
	return []

func turn(i: int, delta: int) -> void:
	digits[i] = posmod(int(digits[i]) + delta, 10)
	labels[i].text = str(digits[i])
	var w: Node3D = wheels[i]
	var tw := create_tween()
	w.rotation.x = 0.0
	tw.tween_property(w, "rotation:x", -0.6 * delta, 0.06)
	tw.tween_property(w, "rotation:x", 0.0, 0.08)
	turned.emit(code())

## The hasp springs: the lock drops open.
func spring() -> void:
	var tw := create_tween()
	tw.tween_property(self, "position", position + Vector3(0, -0.06, 0), 0.15).set_trans(Tween.TRANS_BOUNCE)
	tw.tween_property(self, "rotation:z", 0.5, 0.3)
