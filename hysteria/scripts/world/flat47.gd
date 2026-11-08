extends Node3D
## Flat 47: loads the exported apartment (assets/flat47/flat47.glb + level.json) and makes it
## a level: PS1 materials, collision, floors and ceilings, lights, and behaviour on the nodes the
## exporter labelled (door_*, drawer_*, prop_*, pick_*).

const PS1 := preload("res://shaders/ps1.gdshader")
const DoorScript := preload("res://scripts/world/door.gd")
const DrawerScript := preload("res://scripts/world/drawer.gd")
const PropScript := preload("res://scripts/world/prop.gd")
const PickScript := preload("res://scripts/world/pickable.gd")

const H := 2.75

var level: Dictionary
var spawn := Transform3D.IDENTITY

func _ready() -> void:
	level = JSON.parse_string(FileAccess.get_file_as_string("res://assets/flat47/level.json"))
	var flat: Node3D = (load("res://assets/flat47/flat47.glb") as PackedScene).instantiate()
	flat.name = "Apartment"
	add_child(flat)
	_materials(flat)
	_behaviours(flat)
	_collision()
	_lights()
	_environment()
	var s: Dictionary = level.spawn
	spawn = Transform3D(Basis(Vector3.UP, s.yaw), Vector3(s.x, s.y, s.z))

# ---------------------------------------------------------------- materials
## Every opaque surface goes through the PS1 shader; glass and other transparent surfaces keep
## a standard material, unfiltered.
func _materials(root: Node) -> void:
	var cache := {}
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for i in m.mesh.get_surface_count():
			var src := m.get_active_material(i)
			if not (src is StandardMaterial3D):
				continue
			if cache.has(src):
				m.set_surface_override_material(i, cache[src]); continue
			var std: StandardMaterial3D = src
			var out: Material
			if std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				var t := std.duplicate() as StandardMaterial3D
				t.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
				out = t
			else:
				var sm := ShaderMaterial.new()
				sm.shader = PS1
				sm.set_shader_parameter("albedo_color", std.albedo_color)
				if std.albedo_texture:
					sm.set_shader_parameter("albedo_tex", std.albedo_texture)
				else:
					sm.set_shader_parameter("albedo_tex", _white())
				sm.set_shader_parameter("roughness", std.roughness)
				if std.emission_enabled:
					sm.set_shader_parameter("emission", Vector3(std.emission.r, std.emission.g, std.emission.b) * std.emission_energy_multiplier)
					if std.emission_texture:
						sm.set_shader_parameter("emission_tex", std.emission_texture); sm.set_shader_parameter("use_emission_tex", true)
				out = sm
			cache[src] = out
			m.set_surface_override_material(i, out)

var _white_tex: Texture2D
func _white() -> Texture2D:
	if not _white_tex:
		var img := Image.create(2, 2, false, Image.FORMAT_RGB8); img.fill(Color.WHITE)
		_white_tex = ImageTexture.create_from_image(img)
	return _white_tex

# ---------------------------------------------------------------- behaviours from the exporter's labels
func _extras(n: Node) -> Dictionary:
	if n.has_meta("extras"):
		return n.get_meta("extras")
	return {}

func _behaviours(root: Node) -> void:
	# collect first: attaching behaviours can reparent nodes
	var nodes := root.find_children("*", "Node3D", true, false)
	for n in nodes:
		var ex := _extras(n)
		match ex.get("kind", ""):
			"door": _attach(n, DoorScript, ex)
			"drawer": _attach(n, DrawerScript, ex)
	for n in nodes:
		var ex := _extras(n)
		match ex.get("kind", ""):
			"prop": PropScript.make(n, ex)
			"pick": PickScript.make(n, ex)

func _attach(n: Node, script: Script, ex: Dictionary) -> void:
	n.set_script(script)
	n.call("setup", ex)

# ---------------------------------------------------------------- collision
func _collision() -> void:
	var walls := StaticBody3D.new(); walls.name = "Collision"; add_child(walls)
	for c in level.colliders:
		var sh := CollisionShape3D.new()
		var b := BoxShape3D.new()
		var h: float = c.y1 - c.y0
		b.size = Vector3(c.hx * 2.0, h, c.hz * 2.0)
		sh.shape = b
		sh.transform = Transform3D(Basis(Vector3.UP, c.rot), Vector3(c.x, c.y0 + h * 0.5, c.z))
		walls.add_child(sh)
	# floors (and a ceiling over the flat, so nothing thrown leaves it upward)
	for f in level.floors:
		var sh := CollisionShape3D.new(); var b := BoxShape3D.new()
		b.size = Vector3(f.x1 - f.x0, 0.4, f.z1 - f.z0); sh.shape = b
		sh.position = Vector3((f.x0 + f.x1) * 0.5, f.y - 0.2, (f.z0 + f.z1) * 0.5)
		walls.add_child(sh)
	var ceil := CollisionShape3D.new(); var cb := BoxShape3D.new(); cb.size = Vector3(11, 0.4, 9); ceil.shape = cb
	ceil.position = Vector3(5, H + 0.2, 4); walls.add_child(ceil)

# ---------------------------------------------------------------- lights
## Exported lights become OmniLights. three.js point lights are in candela with physical falloff;
## Godot's energy is relative, so the conversion is tuned by eye.
func _lights() -> void:
	for L in level.lights:
		if L.type != "PointLight" or L.get("broken", false):
			continue
		var o := OmniLight3D.new()
		o.name = "Light_" + str(L.name)
		o.position = Vector3(L.pos[0], L.pos[1], L.pos[2])
		o.light_color = Color(L.color)
		o.light_energy = clampf(float(L.intensity) * 0.15, 0.08, 3.0)
		o.omni_range = float(L.range) if float(L.range) > 0.0 else 6.0
		o.omni_attenuation = 1.6
		o.shadow_enabled = L.name == "hall"
		o.visible = bool(L.on)
		o.set_meta("flicker", L.get("flicker", "") if L.get("flicker") is String else "")
		o.set_meta("base", o.light_energy)
		add_child(o)
		flickers.append(o)
	# the street lamp outside the living-room window
	for L in level.lights:
		if L.type == "SpotLight":
			var sp := SpotLight3D.new(); sp.light_color = Color(L.color); sp.light_energy = 2.0
			sp.spot_range = 22.0; sp.spot_angle = 40.0
			sp.position = Vector3(L.pos[0], L.pos[1], L.pos[2])
			add_child(sp); sp.look_at(Vector3(2.5, 0.0, 2.5))

var flickers: Array[OmniLight3D] = []
var t := 0.0

## The same flicker models as the JS build: a dying hall bulb, a fluorescent tube, the TV, a candle.
func _process(delta: float) -> void:
	t += delta
	for o in flickers:
		var b: float = o.get_meta("base")
		var k := 1.0
		match String(o.get_meta("flicker")):
			"dying": k = 0.05 if fmod(t * 1.7, 7.3) < 0.18 or (fmod(t, 2.9) < 0.06) else 0.85 + 0.15 * sin(t * 31.0)
			"fluoro": k = 0.0 if fmod(t * 0.9, 5.1) < 0.12 and sin(t * 90.0) > 0.0 else 1.0
			"tv": k = 0.6 + 0.4 * absf(sin(t * 7.0) * sin(t * 2.3 + 1.0))
			"candle": k = 0.8 + 0.12 * sin(t * 13.0) + 0.08 * sin(t * 29.0)
			"emergency": k = 0.7 + 0.3 * sin(t * 2.0)
			"bulb": k = 0.97 + 0.03 * sin(t * 50.0)
		o.light_energy = b * k

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.07, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.34, 0.4)
	env.ambient_light_energy = 0.38
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.13, 0.15)
	env.fog_density = 0.04
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	# the grey evening coming in from the courtyard side
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.62, 0.69, 0.78)
	sun.light_energy = 0.35
	sun.rotation_degrees = Vector3(-38, 160, 0)
	sun.shadow_enabled = true
	add_child(sun)
