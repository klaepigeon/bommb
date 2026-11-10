class_name GooglyEye
extends Node3D
## A craft-store googly eye: a white dome and a loose black pupil that slides inside it. The pupil
## has its own spring toward where the eye "wants" to look, plus gravity and the jolts of the head.

var radius := 0.02
var pupil: MeshInstance3D
var _p := Vector2.ZERO        ## pupil offset on the eye face, -1..1
var _v := Vector2.ZERO
var _want := Vector2.ZERO
var _last := Vector3.ZERO
var _last_v := Vector3.ZERO

func build(r: float) -> void:
	radius = r
	var white := Look.mat(Look.get_tex("white"), Color("f4f1e8"), 0.0)
	var black := Look.mat(Look.get_tex("white"), Color("060606"), 0.0)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0; sm.radial_segments = 12; sm.rings = 6
	ball.mesh = sm; ball.material_override = white
	ball.scale = Vector3(1, 1, 0.75)
	add_child(ball)
	pupil = MeshInstance3D.new()
	var pm := SphereMesh.new(); pm.radius = r * 0.45; pm.height = r * 0.9; pm.radial_segments = 10; pm.rings = 4
	pupil.mesh = pm; pupil.material_override = black
	pupil.scale = Vector3(1, 1, 0.35)
	add_child(pupil)
	for mi in [ball, pupil]:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func look(world_point: Vector3) -> void:
	var local := global_transform.affine_inverse() * world_point
	if local.z < 0.0:
		_want = Vector2(local.x, local.y) / maxf(-local.z, 0.05)
	else:
		_want = Vector2(signf(local.x), signf(local.y)) * 0.9
	_want = _want.limit_length(0.62)

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	# head acceleration in eye space: the pupil lags it
	var pos := global_position
	var v := (pos - _last) / delta
	var a := (v - _last_v) / delta
	_last = pos
	_last_v = v
	var inv := global_transform.basis.inverse()
	var a_local := inv * a
	var g_local := inv * Vector3(0, -9.8, 0)
	var acc := (_want - _p) * 160.0 - _v * 9.0 - Vector2(a_local.x, a_local.y) * 0.012 + Vector2(g_local.x, g_local.y) * 0.06
	_v += acc.limit_length(400.0) * delta
	_p += _v * delta
	if _p.length() > 0.62:
		_p = _p.normalized() * 0.62
		_v *= -0.3     # it knocks against the rim
	var z := -sqrt(maxf(1.0 - _p.length_squared(), 0.0)) * radius * 0.75
	pupil.position = Vector3(_p.x * radius, _p.y * radius, z - radius * 0.02)
