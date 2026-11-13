extends CanvasLayer
## The screen effects (autoload "Fx"): one full-screen pass over the 3D picture (shaders/post.gdshader).
## Levels and cutscenes push the effects about with set_k()/kick(); `base` holds what a level
## wants all the time (the flesh flat is always a little wrong), `kick` is short-lived (a grab,
## a gunshot), and they're summed each frame. Turned off entirely by the quality setting.

var rect: ColorRect
var mat: ShaderMaterial
var base := {"grain": 0.05, "vignette": 0.45, "fringe": 0.0, "drain": 0.0, "tear": 0.0, "double_k": 0.0, "pulse": 0.0, "fear": 0.0, "hurt": 0.0}
var _kick := {}
var _tint := Color(0, 0, 0, 0)
var _t := 0.0

func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new(); mat.shader = preload("res://shaders/post.gdshader")
	rect.material = mat
	add_child(rect)

## Reset to a level's resting look.
func reset(b := {}) -> void:
	base = {"grain": 0.05, "vignette": 0.45, "fringe": 0.0, "drain": 0.0, "tear": 0.0, "double_k": 0.0, "pulse": 0.0, "fear": 0.0, "hurt": 0.0}
	for k in b: base[k] = b[k]
	_kick.clear(); _tint = Color(0, 0, 0, 0)

func set_k(k: String, v: float) -> void:
	base[k] = v

## A burst of an effect that fades back over `secs`.
func kick(k: String, amount: float, secs: float) -> void:
	_kick[k] = {"v": amount, "rate": amount / maxf(0.01, secs)}

func tint(c: Color, secs := 1.0) -> void:
	var tw := create_tween(); tw.tween_property(self, "_tint", c, secs)

func _process(delta: float) -> void:
	rect.visible = bool(Game.settings.get("post_fx", true))
	if not rect.visible: return
	_t += delta
	mat.set_shader_parameter("time_k", _t)
	var vp := get_viewport().get_visible_rect().size
	var s: float = ProjectSettings.get_setting("rendering/scaling_3d/scale", 1.0)
	mat.set_shader_parameter("res", vp * s)
	for k in base:
		var v: float = base[k]
		if _kick.has(k):
			v += _kick[k].v
			_kick[k].v = maxf(0.0, _kick[k].v - _kick[k].rate * delta)
		mat.set_shader_parameter(k, v)
	mat.set_shader_parameter("tint", _tint)
	mat.set_shader_parameter("safe", bool(Game.settings.get("reduce_flashing", true)))

# ------------------------------------------------------------------ feel
var _stop_until := 0
var _stopped := false

## Hit-stop: the world holds for a few hundredths of a second as a blow lands, so it lands.
## (Never stacked, never longer than 0.12 s; Engine.time_scale is put back exactly as it was.)
func hitstop(secs: float, scale := 0.05) -> void:
	if not Game.settings.get("hitstop", true): return
	var until := Time.get_ticks_msec() + int(minf(secs, 0.12) * 1000.0)
	_stop_until = maxi(_stop_until, until)
	if _stopped: return
	_stopped = true
	var was := Engine.time_scale
	Engine.time_scale = scale
	while Time.get_ticks_msec() < _stop_until: await get_tree().process_frame
	if is_equal_approx(Engine.time_scale, scale): Engine.time_scale = was
	_stopped = false

## A burst of bits where something was hit: plaster dust, splinters, glass, flesh. One-shot,
## frees itself. `n` the normal the bits fly off along.
const BURSTS := {
	"dust":   {"col": Color(0.62, 0.6, 0.55), "n": 18, "size": 0.025, "speed": 1.6, "grav": 2.0, "life": 0.9, "cubes": false},
	"wood":   {"col": Color(0.42, 0.28, 0.16), "n": 12, "size": 0.03, "speed": 2.6, "grav": 9.0, "life": 0.8, "cubes": true},
	"glass":  {"col": Color(0.75, 0.85, 0.85), "n": 16, "size": 0.018, "speed": 3.0, "grav": 9.0, "life": 0.7, "cubes": true},
	"flesh":  {"col": Color(0.32, 0.03, 0.04), "n": 16, "size": 0.03, "speed": 2.2, "grav": 9.0, "life": 0.7, "cubes": false},
	"spark":  {"col": Color(1.0, 0.8, 0.45), "n": 8, "size": 0.012, "speed": 3.5, "grav": 6.0, "life": 0.25, "cubes": false},
}
func burst(kind: String, pos: Vector3, n: Vector3 = Vector3.UP) -> void:
	var g = get_node_or_null("/root/Game")
	var host: Node = g.level if g and g.level and is_instance_valid(g.level) else get_tree().current_scene
	if not host or not BURSTS.has(kind): return
	var b: Dictionary = BURSTS[kind]
	var p := CPUParticles3D.new()
	p.one_shot = true; p.explosiveness = 0.95; p.amount = b.n; p.lifetime = b.life
	p.direction = n; p.spread = 55.0; p.initial_velocity_min = b.speed * 0.4; p.initial_velocity_max = b.speed
	p.gravity = Vector3(0, -b.grav, 0); p.damping_min = 1.0; p.damping_max = 3.0
	p.angular_velocity_min = -400.0; p.angular_velocity_max = 400.0
	p.scale_amount_min = 0.5; p.scale_amount_max = 1.2
	var c := Curve.new(); c.add_point(Vector2(0, 1)); c.add_point(Vector2(0.7, 0.8)); c.add_point(Vector2(1, 0))
	p.scale_amount_curve = c
	var m := StandardMaterial3D.new()
	m.albedo_color = b.col; m.roughness = 1.0
	if kind == "dust": m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.albedo_color.a = 0.5; m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if kind == "spark": m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.emission_enabled = true; m.emission = b.col
	var mesh: Mesh
	if b.cubes:
		var bx := BoxMesh.new(); bx.size = Vector3.ONE * b.size; mesh = bx
	elif kind == "dust":
		var qd := QuadMesh.new(); qd.size = Vector2.ONE * b.size * 3.0; mesh = qd
	else:
		var sp := SphereMesh.new(); sp.radius = b.size * 0.5; sp.height = b.size; sp.radial_segments = 4; sp.rings = 2; mesh = sp
	p.mesh = mesh; p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(p); p.global_position = pos + n * 0.02
	p.emitting = true
	p.finished.connect(p.queue_free)
