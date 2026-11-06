class_name LampField
extends Node
## Feeds the ink shader's global lamp table: every frame, the 16 lamps nearest the
## active camera go into a 16x2 float texture (row 0: position + range, row 1: colour *
## energy + fade). Lamps fade out with distance from the camera before they drop off the
## table, so swapping which 16 are used is invisible. Also sets the moon and the ink.
## Lives on the scene that owns the world (WorldGame, the menu) so it runs in tests too.

const MAX := 16
const FADE_BEGIN := 70.0
const FADE_END := 95.0
const MOON_DIR := Vector3(0.45, -0.75, 0.5)
const MOON := Color(0.4, 0.4, 0.56)
const AMBIENT := Color(0.5, 0.43, 0.56)
const INK := Color(0.09, 0.06, 0.15)

static var lamps: Array[Lamp] = []
var _img: Image
var _tex: ImageTexture
## Distance multiplier (graphics LOW: lamps fade sooner).
var reach_scale: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_img = Image.create(MAX, 2, false, Image.FORMAT_RGBAF)
	_tex = ImageTexture.create_from_image(_img)
	RenderingServer.global_shader_parameter_set("lamp_data", _tex)
	RenderingServer.global_shader_parameter_set("moon_dir", MOON_DIR.normalized())
	RenderingServer.global_shader_parameter_set("moon_color", MOON)
	RenderingServer.global_shader_parameter_set("ambient_color", AMBIENT)
	RenderingServer.global_shader_parameter_set("ink_color", INK)
	update()


func _process(_delta: float) -> void:
	update()


func update() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye := cam.global_position if cam else Vector3.ZERO
	var pick: Array = []
	for l in lamps:
		if is_instance_valid(l) and l.is_inside_tree() and l.is_visible_in_tree():
			pick.append([l.global_position.distance_squared_to(eye), l])
	pick.sort_custom(func(a, b): return a[0] < b[0])
	var n := mini(pick.size(), MAX)
	for i in MAX:
		if i < n:
			var l: Lamp = pick[i][1]
			var p := l.global_position
			var d := sqrt(float(pick[i][0]))
			var fade := 1.0 - clampf((d - FADE_BEGIN * reach_scale) / ((FADE_END - FADE_BEGIN) * reach_scale), 0.0, 1.0)
			_img.set_pixel(i, 0, Color(p.x, p.y, p.z, l.reach))
			_img.set_pixel(i, 1, Color(l.color.r * l.energy, l.color.g * l.energy, l.color.b * l.energy, fade))
		else:
			_img.set_pixel(i, 0, Color(0, -9999, 0, 0.001))
			_img.set_pixel(i, 1, Color(0, 0, 0, 0))
	_tex.update(_img)
	RenderingServer.global_shader_parameter_set("lamp_count", n)
