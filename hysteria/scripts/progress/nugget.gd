class_name Nugget
extends Node3D
## A gutterspace nugget: a piece of the world that didn't load. A chunk of geometry in the
## magenta-and-black checker of a missing texture, hanging in the air, turning, now and then
## jumping a few centimetres as if it had dropped a frame. Walk into it to take it.

signal taken(n: Nugget)

static var _mat: StandardMaterial3D
var _t := randf() * 10.0
var _shape: MeshInstance3D
var _glitch := 0.0
var _home := Vector3.ZERO

static func material() -> StandardMaterial3D:
	if _mat: return _mat
	const S := 8
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	for y in S:
		for x in S:
			img.set_pixel(x, y, Color(1.0, 0.0, 1.0) if (x / 2 + y / 2) % 2 == 0 else Color(0.02, 0.0, 0.02))
	_mat = StandardMaterial3D.new()
	_mat.albedo_texture = ImageTexture.create_from_image(img)
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED     # missing textures don't take light
	_mat.disable_fog = true
	return _mat

func _ready() -> void:
	_home = position
	_shape = MeshInstance3D.new()
	var kind := randi() % 3
	match kind:
		0:
			var b := BoxMesh.new(); b.size = Vector3(0.16, 0.16, 0.16); _shape.mesh = b
		1:
			var p := PrismMesh.new(); p.size = Vector3(0.2, 0.18, 0.12); _shape.mesh = p
		_:
			var c := CylinderMesh.new(); c.top_radius = 0.0; c.bottom_radius = 0.1; c.height = 0.2; c.radial_segments = 4; c.rings = 1; _shape.mesh = c
	_shape.material_override = material()
	_shape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shape)
	_shape.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)

func _process(delta: float) -> void:
	_t += delta
	_shape.rotate_y(delta * 0.9); _shape.rotate_x(delta * 0.4)
	_glitch -= delta
	if _glitch <= 0.0 and randf() < delta * 0.6:
		_glitch = 0.08
		_shape.position = Vector3(randf_range(-0.04, 0.04), randf_range(-0.04, 0.04), randf_range(-0.04, 0.04))
	elif _glitch <= 0.0:
		_shape.position = Vector3.ZERO
	position = _home + Vector3(0, sin(_t * 1.6) * 0.04, 0)
	var cam := get_viewport().get_camera_3d()
	if cam and visible and is_visible_in_tree():
		var feet := cam.global_position - Vector3(0, 1.0, 0)
		if global_position.distance_to(feet) < 1.0 or global_position.distance_to(cam.global_position) < 0.9:
			take()

func take() -> void:
	Skills.add_nuggets(1)
	# remembered by name, so a loaded game doesn't put it back
	var gone: Dictionary = Game.flags.get("nuggets_taken", {}); gone[String(name)] = true; Game.flags["nuggets_taken"] = gone
	_blip()
	taken.emit(self)
	queue_free()

func _blip() -> void:
	const RATE := 22050
	var n := int(RATE * 0.14)
	var bytes := PackedByteArray(); bytes.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var f := 880.0 if t < 0.05 else 1320.0       # a little two-note chirp, square-ish, like a menu
		var s := (1.0 if sin(TAU * f * t) > 0.0 else -1.0) * exp(-t * 18.0) * 0.25
		bytes.encode_s16(i * 2, int(s * 30000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.data = bytes
	var ap := AudioStreamPlayer.new(); ap.stream = w; ap.volume_db = -6.0
	get_tree().root.add_child(ap); ap.play(); ap.finished.connect(ap.queue_free)
