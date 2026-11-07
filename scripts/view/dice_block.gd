class_name DiceBlock
extends Node3D
## The roll: a grubby ink-drawn block over the roller's head, flicking through 1..max_n
## while it tumbles, then it lands on the number. Same call as the old die: roll_to().

var max_n := 9
var _labels: Array[Label3D] = []
var _cycling := false
var _t := 0.0
var _body: MeshInstance3D


func setup(n: int, body: Color, ink: Color, size: float) -> void:
	max_n = n
	_body = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * size
	_body.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = body
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_body.material_override = mat
	add_child(_body)
	# a fat ink edge: a slightly bigger box drawn inside-out
	var edge := MeshInstance3D.new()
	var em := BoxMesh.new()
	em.size = Vector3.ONE * size * 1.08
	edge.mesh = em
	var emat := StandardMaterial3D.new()
	emat.albedo_color = Color("1e120e")
	emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	emat.cull_mode = BaseMaterial3D.CULL_FRONT
	edge.material_override = emat
	add_child(edge)
	var font: Font = load("res://assets/fonts/fell_sc.ttf")
	var h := size * 0.51
	var faces := [[Vector3(0, 0, h), Vector3.ZERO], [Vector3(0, 0, -h), Vector3(0, PI, 0)], [Vector3(h, 0, 0), Vector3(0, PI / 2, 0)],
		[Vector3(-h, 0, 0), Vector3(0, -PI / 2, 0)], [Vector3(0, h, 0), Vector3(-PI / 2, 0, 0)], [Vector3(0, -h, 0), Vector3(PI / 2, 0, 0)]]
	for f in faces:
		var l := Label3D.new()
		l.font = font
		l.font_size = 160
		l.pixel_size = size / 220.0
		l.modulate = ink
		l.outline_size = 0
		l.position = f[0]
		l.rotation = f[1]
		l.text = "?"
		l.shaded = false
		add_child(l)
		_labels.append(l)


func _show(n: int) -> void:
	for l in _labels:
		l.text = str(n)


func _process(dt: float) -> void:
	if _cycling:
		_t += dt
		position.y = _hover_at.y + sin(Time.get_ticks_msec() * 0.004) * 0.06
		rotation.y += dt * 0.8
		if _t > 0.07:
			_t = 0.0
			_show(randi_range(1, max_n))


## Hang over someone's head, flicking through the numbers, waiting to be hit.
func hover(at: Vector3) -> void:
	if not visible or not _cycling or _hit:
		position = at
		scale = Vector3.ONE
		rotation = Vector3.ZERO
	visible = true
	_cycling = true
	_hit = false
	_hover_at = at


## Hit from below: it jolts up, stops on the number, and hangs there a moment.
func hit(value: int) -> void:
	_cycling = false
	_hit = true
	_show(value)
	var tw := create_tween()
	tw.tween_property(self, "position", _hover_at + Vector3(0, 0.25, 0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", _hover_at, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.0)
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.25)
	tw.tween_callback(func(): visible = false; _hit = false)


var _hit := false
var _hover_at := Vector3.ZERO


func roll_to(value: int, from: Vector3, to: Vector3, duration: float = 0.9) -> Tween:
	position = from
	rotation = Vector3.ZERO
	scale = Vector3.ONE * 0.3
	_cycling = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", to, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "rotation", Vector3(TAU * 2.0, TAU * 1.5, 0), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func():
		_cycling = false
		rotation = Vector3(0, 0, 0)
		_show(value))
	tw.chain().tween_property(self, "scale", Vector3.ONE * 1.25, 0.08)
	tw.chain().tween_property(self, "scale", Vector3.ONE, 0.12)
	return tw
