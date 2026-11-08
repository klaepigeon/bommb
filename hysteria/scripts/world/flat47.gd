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
	_strip_outside(flat)
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

## The owner's canon changed after the JS build: there is no husband in 47 (docs/STORY_BIBLE.md).
## The flat's two lines that named him, rewritten.
const TEXT_PATCH := {
	"prop_0_Wedding_photograph": "Face down, the glass starred. The photograph itself has been cut out of the frame, carefully, with nail scissors. Someone pulled it off the wall afterwards; the nail came with it.",
	"pick_129_Bundle_of_letters": "Tied with darning wool. Her handwriting, every one, to a post-office box in Moscow with no name on it. Every one stamped RETURN TO SENDER.",
}

func _behaviours(root: Node) -> void:
	# collect first: attaching behaviours can reparent nodes
	var nodes := root.find_children("*", "Node3D", true, false)
	for n in nodes:
		if TEXT_PATCH.has(String(n.name)) and n.has_meta("extras"):
			var ex: Dictionary = n.get_meta("extras"); ex["desc"] = TEXT_PATCH[String(n.name)]; n.set_meta("extras", ex)
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

## Hides the exported meshes around a point (smaller than `max_size`): used where a piece of
## the JS build's dressing is replaced by something built here.
func hide_near(p: Vector3, radius: float, max_size: float) -> int:
	var n := 0
	for mi in find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if not m.is_inside_tree() or m.get_parent() is Marta: continue
		var a: AABB = m.global_transform * m.get_aabb()
		if a.size.length() > max_size: continue
		var c := a.get_center()
		if Vector2(c.x - p.x, c.z - p.z).length() < radius and c.y < p.y + 0.6:
			m.visible = false; n += 1
	return n

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
## Godot's Compatibility renderer (the one Android runs) shades each mesh with at most
## MAX_PER_OBJECT omni and MAX_PER_OBJECT spot lights. Past that it drops lights per mesh in
## culling order, which changes as the camera moves: whole walls pop between lit and unlit.
## The JS build's light list includes the building around the flat (the stairwell lamps,
## the courtyard lamp) that only ever reach the flat by shining through walls; with them the
## flat's meshes see 10-14 lights. So: keep a light only if it's in the flat's footprint (or
## shadowed, so the walls really do stop it), which keeps every mesh under the limit.
const MAX_PER_OBJECT := 8
const FOOTPRINT := AABB(Vector3(-0.3, -0.5, -0.3), Vector3(10.6, H + 3.5, 8.6))
func _lights() -> void:
	for L in level.lights:
		if L.get("broken", false):
			continue
		var at := Vector3(L.pos[0], L.pos[1], L.pos[2])
		if String(L.type) == "PointLight" and not bool(L.get("shadow", false)) and not FOOTPRINT.has_point(at):
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
				sp.spot_range = 9.0; sp.spot_attenuation = 2.0
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
		# no shadowed lights in the flat: each one is another pass over every mesh it touches (and on
		# phones those passes are where shimmer creeps in). The street lamp shines in unshadowed:
		# a warm wash through the child's window. The only shadow left is Kurt's torch.
		l.shadow_enabled = false
		l.shadow_bias = 0.05; l.shadow_normal_bias = 1.0
		l.visible = bool(L.on) and powered(L.get("circuit"))
		var circ = L.get("circuit")
		l.set_meta("circuit", circ if circ is String else ""); l.set_meta("switched", bool(L.on))     # "" = not on the mains
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
			l.set_meta("powered", on and l.get_meta("switched"))
var t := 0.0

## Flicker, calmed for a screen that refreshes 30-60 times a second. The JS build's models had
## per-frame random jitter (the TV, the candle) and 50 Hz hum (sin(t * 314)) that alias into
## strobing on a phone, and random dips on every ordinary bulb. Now: ordinary bulbs are steady
## with a slow breath; the dying hall bulb and the fluorescent tube are the two that misbehave,
## in slow, deliberate holds (never fully black for the bulb); the TV and candle wander on smooth
## noise; the building's brownout fades down and back instead of stepping.
var _fl := {}            # light -> {t, timer, state, startup, seed}
var _brown := 1.0
var _brown_want := 1.0
var _brown_t := 50.0
var _brown_hold := 0.0
var _noise := FastNoiseLite.new()

func _flick(l: Light3D, kind: String, dt: float) -> float:
	var s: Dictionary = _fl.get(l, {"t": randf() * 9.0, "timer": 0.0, "state": 1.0, "startup": 0.0, "seed": randf() * 100.0})
	_fl[l] = s
	s.t += dt
	var tt: float = s.t
	var nz := func(f: float) -> float: return _noise.get_noise_2d(tt * f, s.seed)   # -1..1, smooth
	match kind:
		"fluoro":
			# a tired tube: now and then it drops out for a few frames, and rarely restarts
			if s.startup > 0.0:
				s.startup -= dt
				return 1.0 if fmod(s.startup, 0.35) < 0.12 else 0.15
			if s.timer > 0.0:
				s.timer -= dt; return s.state
			if randf() < dt * 0.06:
				s.timer = 0.08 + randf() * 0.15; s.state = 0.25
			elif randf() < dt * 0.008:
				s.startup = 1.0 + randf()
			return 0.96 + 0.03 * nz.call(0.6)
		"bulb":
			return 0.95 + 0.04 * nz.call(0.25)
		"dying":
			# the hall bulb: dims and catches, slowly; never quite out
			if s.timer > 0.0:
				s.timer -= dt; return s.state
			if randf() < dt * 0.22:
				s.timer = 0.12 + randf() * 0.35; s.state = 0.3 + randf() * 0.25; return s.state
			return 0.8 + 0.08 * nz.call(0.9)
		"candle":
			return 0.84 + 0.1 * nz.call(1.8)
		"tv":
			return 0.65 + 0.25 * nz.call(3.0)
		"emergency":
			return 0.65 + 0.35 * maxf(0.0, sin(tt * 2.1))
	return 1.0

# ---------------------------------------------------------------- which lights are on
## Fewer lights without losing any you'd notice: each light belongs to a room (by where it
## shines); a room's lights are on while you're in it or near it (within ROOM_NEAR m of its
## floor), and fade out over ~0.6 s once you're further. Off lights are hidden, so they cost
## nothing and can't push a mesh over the renderer's per-object limit. There's no sun: outside is
## a white void (see _outside); the window lights carry the daylight in.
const ROOM_NEAR := 3.0

func room_of(p: Vector3) -> String:
	for k in level.rooms:
		var r: Dictionary = level.rooms[k]
		if p.x >= r.x0 and p.x < r.x1 and p.z >= r.z0 and p.z < r.z1:
			return k
	return ""

func _room_dist(k: String, p: Vector3) -> float:
	if k == "":
		return 0.0
	var r: Dictionary = level.rooms[k]
	var dx := maxf(maxf(r.x0 - p.x, p.x - r.x1), 0.0)
	var dz := maxf(maxf(r.z0 - p.z, p.z - r.z1), 0.0)
	return Vector2(dx, dz).length()

func _assign_room(l: Light3D) -> void:
	var probe := l.global_position
	if l is SpotLight3D:
		probe += -l.global_transform.basis.z * 1.2     # where it shines (window lights, the street lamp)
	var k := room_of(probe)
	if k == "" and l is SpotLight3D:
		probe = l.global_position - l.global_transform.basis.z * 6.0
		k = room_of(probe)
	l.set_meta("room", k)
	l.set_meta("powered", l.visible)
	l.set_meta("near", 1.0)

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else Vector3(5, 1.6, 4)
	# the building's supply sags now and then (every 50-110 s): mains lights fade down together
	_brown_t -= delta
	if _brown_t <= 0.0:
		_brown_t = 50.0 + randf() * 60.0
		_brown_want = 0.35 + randf() * 0.25; _brown_hold = 1.2 + randf() * 1.5
	if _brown_hold > 0.0:
		_brown_hold -= delta
		if _brown_hold <= 0.0: _brown_want = 1.0
	_brown = move_toward(_brown, _brown_want, delta * 1.6)
	for o in flickers:
		if not o.has_meta("room"):
			_assign_room(o)
		var near: float = o.get_meta("near")
		var want := 1.0 if _room_dist(o.get_meta("room"), eye) < ROOM_NEAR else 0.0
		near = move_toward(near, want, delta / 0.6)
		o.set_meta("near", near)
		o.visible = bool(o.get_meta("powered")) and near > 0.001
		if not o.visible:
			continue
		var b: float = o.get_meta("base")
		var k := _flick(o, String(o.get_meta("flicker")), delta)
		if o.get_meta("circuit") != "":                # on the mains
			k *= _brown
		o.light_energy = b * k * smoothstep(0.0, 1.0, near)

## How many lights are on right now (for tests and the light budget).
func active_lights() -> int:
	var n := 0
	for o in flickers:
		if o.visible: n += 1
	return n

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
	# outside isn't there: the background is a flat, even white (see _outside). No sky light.
	env.background_color = Color(1, 1, 1)
	env.background_energy_multiplier = 1.6     # still white after the tonemap
	var we := WorldEnvironment.new(); we.name = "Environment"; we.environment = env; add_child(we)
	environment = env
	_outside()

var environment: Environment

# ---------------------------------------------------------------- outside
## The model came with the JS build's courtyard and city (trees, cars, lamp posts, wires, other
## blocks), and the building around the flat (the stairwell, the landing, Flat 48 next door).
## None of it exists here: anything whose middle is beyond Flat 47's own walls and balcony, or
## above or below this storey, is removed. (Less to draw, fewer surfaces for lights to reach.)
const BUILDING := AABB(Vector3(-0.6, -0.8, -1.95), Vector3(11.05, 4.3, 10.4))
func _strip_outside(root: Node) -> void:
	var gone := 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		var a: AABB = m.global_transform * m.get_aabb()
		if not BUILDING.has_point(a.get_center()) or a.size.length() > 40.0:
			m.queue_free(); gone += 1
	if OS.is_debug_build(): print("outside: removed ", gone, " meshes")

## There is no outside. Through every window and off the balcony: white, even, empty, out of
## reach (the balcony railing stops you), and hanging in it a giant sticky note that says
## “outside”, in neat lowercase print. One out the front (courtyard side: the living room,
## bedroom and kitchen windows, the balcony) and one out the back (between the boards in Sonya's
## window).
func _outside() -> void:
	# the white gives off a soft, shadowless light: enough that the balcony isn't a cut-out
	var glow := OmniLight3D.new(); glow.name = "Light_void"
	glow.light_color = Color(0.93, 0.95, 1.0); glow.light_energy = 0.9; glow.light_specular = 0.0
	glow.omni_range = 3.2; glow.omni_attenuation = 0.8; glow.shadow_enabled = false
	glow.position = Vector3(2.25, 1.6, -2.4)
	add_child(glow)
	_sticky_note(Vector3(3.6, 2.2, -15.0), 0.0, 7.0, -0.035)
	_sticky_note(Vector3(4.8, 2.0, 21.0), PI, 6.0, 0.03)

func _sticky_note(at: Vector3, yaw: float, size: float, tilt: float) -> void:
	var note := Node3D.new(); note.name = "Note_outside"
	add_child(note)
	note.position = at; note.rotation = Vector3(0, yaw, tilt)
	# the paper: a square of yellow, the adhesive strip along the top a shade darker and flat
	# against nothing, the bottom edge lifting away in a soft curl
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const N := 12
	var pts := []
	for j in N + 1:
		var row := []
		for i in N + 1:
			var u := float(i) / N; var v := float(j) / N            # v = 0 top, 1 bottom
			var curl := pow(maxf(0.0, v - 0.55) / 0.45, 2.2) * size * 0.07
			curl += pow(maxf(0.0, u - 0.7) / 0.3, 2.0) * pow(maxf(0.0, v - 0.6) / 0.4, 1.5) * size * 0.05   # the corner lifts most
			row.append(Vector3((u - 0.5) * size, (0.5 - v) * size, curl))
		pts.append(row)
	for j in N:
		for i in N:
			var a0: Vector3 = pts[j][i]; var a1: Vector3 = pts[j][i + 1]; var b1: Vector3 = pts[j + 1][i + 1]; var b0: Vector3 = pts[j + 1][i]
			var vt := (float(j) + 0.5) / N
			var c := Color("f4e06a") if vt > 0.14 else Color("e9d35a")
			c = c.darkened(0.06 * smoothstep(0.55, 1.0, vt))         # the curl turns a little from the light
			for p in [a0, a1, b1, a0, b1, b0]:
				st.set_color(c); st.add_vertex(p)
	var paper := MeshInstance3D.new(); paper.mesh = st.commit()
	var pm := StandardMaterial3D.new(); pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.vertex_color_use_as_albedo = true; pm.cull_mode = BaseMaterial3D.CULL_DISABLED; pm.disable_fog = true
	paper.material_override = pm; paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	note.add_child(paper)
	# its shadow on the white: soft, offset down and away, as if there were a wall there
	var sh := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(size * 1.02, size * 1.02); sh.mesh = qm
	var sm := StandardMaterial3D.new(); sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; sm.disable_fog = true
	sm.albedo_texture = _soft_square(); sm.albedo_color = Color(0.55, 0.55, 0.58, 0.22)
	sh.material_override = sm; sh.position = Vector3(size * 0.035, -size * 0.05, -0.25)
	note.add_child(sh)
	# the word, printed neatly in felt-tip
	var word := Label3D.new(); word.text = "\u201coutside\u201d"
	word.font_size = 160; word.pixel_size = size / 900.0; word.outline_size = 0
	word.modulate = Color("1d2333"); word.shaded = false; word.double_sided = true
	word.position = Vector3(0, -size * 0.03, size * 0.004)
	note.add_child(word)

static var _soft_tex: Texture2D
static func _soft_square() -> Texture2D:
	if _soft_tex: return _soft_tex
	const S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var e := minf(minf(x, S - 1 - x), minf(y, S - 1 - y)) / (S * 0.18)
			img.set_pixel(x, y, Color(1, 1, 1, smoothstep(0.0, 1.0, clampf(e, 0.0, 1.0))))
	_soft_tex = ImageTexture.create_from_image(img)
	return _soft_tex
