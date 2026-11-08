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
var ambient := 0.05

var level: Dictionary
var relief := 0.1     # see tools/export/entry.js: the normal maps are exported at full strength
var spawn := Transform3D.IDENTITY

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("relief="): relief = float(a.get_slice("=", 1))
		if a.begins_with("ambient="): ambient = float(a.get_slice("=", 1))
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
		var see_through := true
		for i in m.mesh.get_surface_count():
			var sm0 := m.get_active_material(i)
			if not (sm0 is BaseMaterial3D) or (sm0 as BaseMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
				see_through = false
		if see_through:
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
				if std.roughness_texture:
					sm.set_shader_parameter("roughness_tex", std.roughness_texture); sm.set_shader_parameter("use_roughness_tex", true)
				if std.normal_enabled and std.normal_texture:
					sm.set_shader_parameter("normal_tex", std.normal_texture); sm.set_shader_parameter("use_normal_tex", true)
					sm.set_shader_parameter("normal_depth", std.normal_scale * relief)
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
## The JS build's lights, converted, not re-tuned. three.js point lights are physical: candela with
## an inverse-square falloff (decay 2) and a Lambert BRDF of albedo/pi. Godot multiplies light
## energy by pi and its omni falloff is the same windowed inverse power, so energy = candela / pi
## and attenuation = decay gives the same light on the same surface at the same distance.
const CD := 1.0 / PI
func _lights() -> void:
	for L in level.lights:
		if L.get("broken", false):
			continue
		var l: Light3D
		var pos := Vector3(L.pos[0], L.pos[1], L.pos[2])
		match String(L.type):
			"PointLight":
				var o := OmniLight3D.new()
				o.omni_range = float(L.range) if float(L.range) > 0.0 else 30.0
				o.omni_attenuation = float(L.get("decay", 2.0))
				o.position = pos
				l = o
			"SpotLight":
				var sp := SpotLight3D.new()
				sp.spot_range = float(L.range) if float(L.range) > 0.0 else 30.0
				sp.spot_attenuation = float(L.get("decay", 2.0))
				sp.spot_angle = rad_to_deg(float(L.angle))
				sp.light_projector = Penumbra.make(float(L.get("penumbra", 0.0)))
				l = sp
			"RectAreaLight":
				# three: luminance x area, one-sided, never shadowed, no range. Godot's Compatibility
				# renderer has no area lights: a broad soft spot just inside the glass, facing in.
				var sp := SpotLight3D.new()
				sp.spot_range = 30.0; sp.spot_attenuation = 2.0
				sp.spot_angle = 85.0; sp.spot_angle_attenuation = 1.6
				sp.light_specular = 0.2
				l = sp
				L.intensity = float(L.intensity) * float(L.w) * float(L.h)
				pos += Vector3(L.dir[0], 0, L.dir[2]) * 0.15
			_:
				continue
		l.name = "Light_" + str(L.name)
		l.light_color = Color(L.color)
		l.light_energy = float(L.intensity) * CD
		l.shadow_enabled = bool(L.get("shadow", false))
		l.shadow_bias = 0.05; l.shadow_normal_bias = 1.0
		l.visible = bool(L.on) and powered(L.get("circuit"))
		l.set_meta("circuit", L.get("circuit")); l.set_meta("switched", bool(L.on))
		add_child(l)
		if l is SpotLight3D:
			l.position = pos
			if L.has("target"):
				l.look_at(Vector3(L.target[0], L.target[1], L.target[2]))
			elif L.has("dir"):
				l.look_at(pos + Vector3(L.dir[0], L.dir[1] - 0.15, L.dir[2]))
		var fl = L.get("flicker")
		l.set_meta("flicker", fl if fl is String else "")
		l.set_meta("base", l.light_energy)
		flickers.append(l)

var flickers: Array[Light3D] = []

## Power circuits from the fuse box (A, B, C). C starts off: it's the one that keeps tripping.
func powered(c) -> bool:
	return not (c is String) or bool(level.get("circuits", {}).get(c, true))

func set_circuit(c: String, on: bool) -> void:
	level.circuits[c] = on
	for l in flickers:
		if l.get_meta("circuit") == c:
			l.visible = on and l.get_meta("switched")
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
	env.background_color = Color("262a31")
	# three: HemisphereLight(0x6a7890, 0x1a140e, 0.06) and nothing else. The dark is the point.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6a7890").lerp(Color("1a140e"), 0.4)
	env.ambient_light_energy = ambient
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# three: FogExp2(0x262a31, 0.0062)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color("262a31")
	env.fog_density = 0.0062
	env.fog_sky_affect = 0.0
	# three: ACESFilmic, exposure 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	# three: the overcast dusk, DirectionalLight(0x9fb0c8, 1.25) from (-3, 13, -14) toward (4, 0, 3),
	# shadowed: it only gets in through the windows.
	var sun := DirectionalLight3D.new(); sun.name = "Sky"
	sun.light_color = Color("9fb0c8")
	sun.light_energy = 1.25 * CD
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 20.0
	sun.shadow_bias = 0.03; sun.shadow_normal_bias = 1.2
	add_child(sun)
	sun.look_at_from_position(Vector3(-3, 13, -14), Vector3(4, 0, 3))
