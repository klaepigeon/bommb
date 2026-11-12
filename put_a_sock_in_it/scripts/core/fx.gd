extends CanvasLayer
## The screen effects (autoload "Fx"): one full-screen pass over the 3D picture (shaders/post.gdshader).
## Levels and cutscenes push the effects about with set_k()/kick(); `base` holds what a level
## wants all the time (the flesh flat is always a little wrong), `kick` is short-lived (a grab,
## a gunshot), and they're summed each frame. Turned off entirely by the quality setting.

var rect: ColorRect
var mat: ShaderMaterial
var base := {"grain": 0.05, "vignette": 0.45, "fringe": 0.0, "drain": 0.0, "tear": 0.0, "double_k": 0.0, "pulse": 0.0}
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
	base = {"grain": 0.05, "vignette": 0.45, "fringe": 0.0, "drain": 0.0, "tear": 0.0, "double_k": 0.0, "pulse": 0.0}
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
