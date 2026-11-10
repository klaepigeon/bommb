class_name Flat47
extends Node3D
## Flat 47: the exported apartment from the first build (assets/flat47/flat47.glb + level.json),
## textured and dressed, made a level: PS1 materials, collision, steady lights, doors and drawers
## that work, the notes and papers you can read, and the landing outside the front door.
## Metres; floor at y=0. The flat runs x 0..10, z 0..8; the landing is east of the front door.
##
##   living (x0-4.4, z0-5.2)   bedroom (4.4-7.6, 0-3.8)   kitchen (7.6-10, 0-3.8)
##   hall (4.4-10, 3.8-5.2) ── front door at x=10.06 ── landing (x 10.4-14)
##   box room (0-2.8, 5.2-8)   Sonya's room (2.8-6.4)    bathroom (6.4-10)

const PS1 := preload("res://shaders/ps1_lit.gdshader")
const H := 2.75
const KEEP := AABB(Vector3(-0.6, -0.8, -1.95), Vector3(14.6, 4.3, 10.4))     # the flat, its balcony, the landing
const LIGHT_AREA := AABB(Vector3(-0.3, -0.5, -0.3), Vector3(14.2, H + 3.5, 8.6))
const ROOM_NEAR := 3.0

var level: Dictionary
var doors := {}                 ## id -> HingeDoor
var front_door: HingeDoor
var room_door: HingeDoor        ## the living room's: open when he goes in, shut while he's out
var room_door_spot: Hotspot     ## (kept for the scene's API: the door's own leaf is what you use)
var marta_seat := Vector3(3.0, 0, 1.42)
var marta_yaw := PI * 0.5
var wardrobe: Node3D
var wardrobe_spot: Hotspot
var hole_spot: Hotspot
var hole_center := Vector3(3.55, 0.55, 5.13)
var flat_nuggets: Array[Node3D] = []
var lights: Array[Light3D] = []
var readables: Array = []       ## usable bodies carrying "title"/"desc" metas
var env_settings := {}

## Where things are, for the scene and the tests.
const POINTS := {
	"landing": Vector3(11.3, 0, 4.55),
	"door_out": Vector3(10.06, 1.35, 4.55),
	"hall": Vector3(8.6, 0, 4.5),
	"hall_west": Vector3(5.1, 0, 4.55),
	"living_in": Vector3(3.9, 0, 4.55),
	"approach": Vector3(3.4, 0, 3.6),
	"near_marta": Vector3(3.4, 0, 2.5),
	"wake": Vector3(3.55, 0, 1.0),
	"by_door": Vector3(3.98, 0, 3.95),
	"by_wardrobe": Vector3(3.9, 0, 4.25),
}

const WARDROBE_AT := Vector3(3.35, 0.0, 4.84)
const WALL_Z := 5.13
const SLIDE := -0.62
const HOLE_MIN := Vector3(3.27, 0.04, 5.04)
const HOLE_MAX := Vector3(3.83, 1.8, 5.36)

func build() -> void:
	level = JSON.parse_string(FileAccess.get_file_as_string("res://assets/flat47/level.json"))
	var flat: Node3D = (load("res://assets/flat47/flat47.glb") as PackedScene).instantiate()
	flat.name = "Apartment"
	add_child(flat)
	_strip_outside(flat)
	_materials(flat)
	_behaviours(flat)
	_collision()
	_lights()
	_outside()
	_wardrobe()
	# a lamp on the dinner table, still on (the first build had Kurt's torch to see her by)
	add_lamp(Vector3(2.6, 1.0, 2.05), Color("ffb070"), 1.1, 2.8)
	RenderingServer.global_shader_parameter_set("hole_min", Vector4(HOLE_MIN.x, HOLE_MIN.y, HOLE_MIN.z, 0.0))
	RenderingServer.global_shader_parameter_set("hole_max", Vector4(HOLE_MAX.x, HOLE_MAX.y, HOLE_MAX.z, 0.0))
	front_door = doors.get("dEntry")
	room_door = doors.get("dLiving")
	front_door.max_angle = 85.0
	front_door.set_angle(0.0)
	front_door.set_usable(false)     # the scene opens it
	doors["dStore"].locked = true    # bolted from the outside
	room_door_spot = Hotspot.make(self, Transform3D(Basis(), Vector3(-50, -50, -50)), Vector3(0.1, 0.1, 0.1), "")
	room_door_spot.enabled = false
	for p in [Vector3(0.6, 0.45, 3.4), Vector3(1.2, 0.5, 0.6)]:
		var n := Nugget.new()
		add_child(n)
		n.position = p
		n.visible = false          # they're only there after he wakes
		flat_nuggets.append(n)

## The environment the flat wants (Main applies it while you're here).
func apply_environment(env: Environment) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(1, 1, 1)
	env.background_energy_multiplier = 1.6        # outside is a flat, even white
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6a7890").lerp(Color("1a140e"), 0.4)
	env.ambient_light_energy = 0.12
	env.fog_enabled = true
	env.fog_light_color = Color("262a31")
	env.fog_density = 0.0062
	env.fog_sky_affect = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15

# --- the model --------------------------------------------------------------------------------

func _strip_outside(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		var a: AABB = m.global_transform * m.get_aabb()
		if not KEEP.has_point(a.get_center()) or a.size.length() > 40.0:
			m.queue_free()

func _materials(root: Node) -> void:
	var cache := {}
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in m.mesh.get_surface_count():
			var src := m.get_active_material(i)
			if not (src is StandardMaterial3D):
				continue
			if cache.has(src):
				m.set_surface_override_material(i, cache[src])
				continue
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
				sm.set_shader_parameter("albedo_tex", std.albedo_texture if std.albedo_texture else _white())
				sm.set_shader_parameter("roughness", std.roughness)
				if std.roughness_texture:
					sm.set_shader_parameter("roughness_tex", std.roughness_texture)
					sm.set_shader_parameter("use_roughness_tex", true)
				if std.normal_enabled and std.normal_texture:
					sm.set_shader_parameter("normal_tex", std.normal_texture)
					sm.set_shader_parameter("use_normal_tex", true)
					sm.set_shader_parameter("normal_depth", std.normal_scale * 0.1)
				if std.emission_enabled:
					sm.set_shader_parameter("emission", Vector3(std.emission.r, std.emission.g, std.emission.b) * std.emission_energy_multiplier)
					if std.emission_texture:
						sm.set_shader_parameter("emission_tex", std.emission_texture)
						sm.set_shader_parameter("use_emission_tex", true)
				out = sm
			cache[src] = out
			m.set_surface_override_material(i, out)

static var _white_tex: Texture2D
static func _white() -> Texture2D:
	if not _white_tex:
		var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
		img.fill(Color.WHITE)
		_white_tex = ImageTexture.create_from_image(img)
	return _white_tex

## Some of the first build's text named a husband; there's none in canon (story bible).
const TEXT_PATCH := {
	"prop_0_Wedding_photograph": "Face down, the glass starred. The photograph itself has been cut out of the frame, carefully, with nail scissors. Someone pulled it off the wall afterwards; the nail came with it.",
	"pick_129_Bundle_of_letters": "Tied with darning wool. Her handwriting, every one, to a post-office box in Moscow with no name on it. Every one stamped RETURN TO SENDER.",
}

func _behaviours(root: Node) -> void:
	var nodes := root.find_children("*", "Node3D", true, false)
	for n in nodes:
		if not n.has_meta("extras"):
			continue
		var ex: Dictionary = n.get_meta("extras")
		if TEXT_PATCH.has(String(n.name)):
			ex["desc"] = TEXT_PATCH[String(n.name)]
		match String(ex.get("kind", "")):
			"door":
				n.set_script(load("res://scripts/world/hinge_door.gd"))
				n.call("setup", ex)
				doors[String(ex.get("id", n.name))] = n
			"drawer":
				n.set_script(load("res://scripts/world/slide_drawer.gd"))
				n.call("setup", ex)
	for n in nodes:
		if not is_instance_valid(n) or not n.has_meta("extras"):
			continue
		var ex: Dictionary = n.get_meta("extras")
		match String(ex.get("kind", "")):
			"prop": _prop(n, ex)
			"pick": _readable(n, ex)

## Furniture is solid; small things are just there (nothing here is physics: steadier on a phone).
## Anything with a description can be looked at.
func _prop(n: Node3D, ex: Dictionary) -> void:
	var mass := float(ex.get("mass", 1.0))
	var size: Array = ex.get("size", [0.2, 0.2, 0.2])
	var centre: Array = ex.get("centre", [0, 0, 0])
	var desc := String(ex.get("desc", ""))
	if mass < 4.0 and desc == "":
		return
	var sb := StaticBody3D.new()
	sb.set_script(load("res://scripts/world/usable.gd"))
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new()
	b.size = Vector3(maxf(size[0], 0.04), maxf(size[1], 0.04), maxf(size[2], 0.04)); cs.shape = b
	cs.position = Vector3(centre[0], centre[1], centre[2])
	sb.add_child(cs)
	n.add_child(sb)
	sb.collision_layer = 1 if mass >= 4.0 else 8
	sb.set("enabled", desc != "")
	sb.set("prompt", "Look")
	sb.set_meta("title", String(ex.get("name", "")))
	sb.set_meta("desc", desc)
	readables.append(sb)

func _readable(n: Node3D, ex: Dictionary) -> void:
	var aabb := AABB()
	var first := true
	var meshes: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		meshes.append(n)
	for m in meshes:
		var a: AABB = (m as MeshInstance3D).get_aabb()
		a = (n.global_transform.affine_inverse() * (m as Node3D).global_transform) * a
		aabb = a if first else aabb.merge(a)
		first = false
	var sb := StaticBody3D.new()
	sb.set_script(load("res://scripts/world/usable.gd"))
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new()
	b.size = aabb.size.max(Vector3(0.06, 0.06, 0.06)); cs.shape = b
	cs.position = aabb.get_center()
	sb.add_child(cs)
	n.add_child(sb)
	sb.collision_layer = 8
	sb.set("prompt", "Read" if ex.get("read", false) else "Look")
	sb.set_meta("title", String(ex.get("name", "")))
	sb.set_meta("desc", String(ex.get("desc", "")))
	readables.append(sb)

## Hides the exported meshes around a point (where something built here takes their place).
func hide_near(p: Vector3, radius: float, max_size: float) -> void:
	for mi in find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if not m.is_inside_tree() or m.get_parent() is MartaModel:
			continue
		var a: AABB = m.global_transform * m.get_aabb()
		if a.size.length() > max_size:
			continue
		var c := a.get_center()
		if Vector2(c.x - p.x, c.z - p.z).length() < radius and c.y < p.y + 0.6:
			m.visible = false

func _collision() -> void:
	var walls := StaticBody3D.new(); walls.name = "Collision"; add_child(walls)
	for c in level.colliders:
		var sh := CollisionShape3D.new(); var b := BoxShape3D.new()
		var h: float = c.y1 - c.y0
		b.size = Vector3(c.hx * 2.0, h, c.hz * 2.0)
		sh.shape = b
		sh.transform = Transform3D(Basis(Vector3.UP, c.rot), Vector3(c.x, c.y0 + h * 0.5, c.z))
		walls.add_child(sh)
	for f in level.floors:
		var sh := CollisionShape3D.new(); var b := BoxShape3D.new()
		b.size = Vector3(f.x1 - f.x0, 0.4, f.z1 - f.z0); sh.shape = b
		sh.position = Vector3((f.x0 + f.x1) * 0.5, f.y - 0.2, (f.z0 + f.z1) * 0.5)
		walls.add_child(sh)
	var ceil := CollisionShape3D.new(); var cb := BoxShape3D.new(); cb.size = Vector3(15, 0.4, 9)
	ceil.shape = cb; ceil.position = Vector3(7, H + 0.2, 4)
	walls.add_child(ceil)
	# the landing: you don't go down the stairs (not yet)
	for z in [[3.4, 8.5]]:
		var sh := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(0.3, 3.0, z[1] - z[0])
		sh.shape = b; sh.position = Vector3(13.4, 1.5, (z[0] + z[1]) * 0.5)
		walls.add_child(sh)

# --- light: steady, few, by room --------------------------------------------------------------

const CD := 1.0 / PI

func _lights() -> void:
	for L in level.lights:
		if L.get("broken", false) or not bool(L.on):
			continue
		var pos := Vector3(L.pos[0], L.pos[1], L.pos[2])
		if String(L.type) == "PointLight" and not LIGHT_AREA.has_point(pos):
			continue
		if not powered(L.get("circuit")):
			continue
		var l: Light3D
		match String(L.type):
			"PointLight":
				var o := OmniLight3D.new()
				o.omni_range = float(L.range) if float(L.range) > 0.0 else 30.0
				o.omni_attenuation = float(L.get("decay", 2.0))
				l = o
			"SpotLight":
				var sp := SpotLight3D.new()
				sp.spot_range = float(L.range) if float(L.range) > 0.0 else 30.0
				sp.spot_attenuation = float(L.get("decay", 2.0))
				sp.spot_angle = rad_to_deg(float(L.angle))
				sp.light_projector = Penumbra.make(float(L.get("penumbra", 0.0)))
				l = sp
			"RectAreaLight":
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
		var k := 1.0
		var fl = L.get("flicker")
		match (fl if fl is String else ""):        # every light steady; the failing ones just dimmer
			"dying": k = 0.8
			"fluoro": k = 0.95
			"emergency": k = 0.8
		l.light_energy = float(L.intensity) * CD * k
		l.shadow_enabled = false
		add_child(l)
		l.position = pos
		if l is SpotLight3D:
			if L.has("target"):
				l.look_at(Vector3(L.target[0], L.target[1], L.target[2]))
			elif L.has("dir"):
				l.look_at(pos + Vector3(L.dir[0], L.dir[1] - 0.15, L.dir[2]))
		l.set_meta("base", l.light_energy)
		lights.append(l)

func powered(c) -> bool:
	return not (c is String) or bool(level.get("circuits", {}).get(c, true))

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

## A room's lights are on while you're in it or near it, and fade (slowly: no popping) when you're
## further. Off lights cost nothing and keep every mesh under the phone renderer's light limit.
func _process(delta: float) -> void:
	if not visible:
		return
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else Vector3(5, 1.6, 4)
	for o in lights:
		if not o.has_meta("room"):
			var probe := o.global_position
			if o is SpotLight3D:
				probe += -o.global_transform.basis.z * 1.2
			var k := room_of(probe)
			if k == "" and o is SpotLight3D:
				k = room_of(o.global_position - o.global_transform.basis.z * 6.0)
			o.set_meta("room", k)
			o.set_meta("near", 1.0)
		var near: float = o.get_meta("near")
		var want := 1.0 if _room_dist(o.get_meta("room"), eye) < ROOM_NEAR else 0.0
		near = move_toward(near, want, delta / 1.2)
		o.set_meta("near", near)
		o.visible = near > 0.001
		o.light_energy = float(o.get_meta("base")) * smoothstep(0.0, 1.0, near)

## A light by the table, low and warm, so she can be seen (the first build had Kurt's torch).
func add_lamp(at: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color; l.light_energy = energy; l.omni_range = reach; l.omni_attenuation = 1.4
	l.shadow_enabled = false
	add_child(l)
	l.position = at
	l.set_meta("base", energy)
	lights.append(l)
	return l

# --- outside: there isn't one --------------------------------------------------------------------

func _outside() -> void:
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
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const N := 12
	var pts := []
	for j in N + 1:
		var row := []
		for i in N + 1:
			var u := float(i) / N; var v := float(j) / N
			var curl := pow(maxf(0.0, v - 0.55) / 0.45, 2.2) * size * 0.07
			curl += pow(maxf(0.0, u - 0.7) / 0.3, 2.0) * pow(maxf(0.0, v - 0.6) / 0.4, 1.5) * size * 0.05
			row.append(Vector3((u - 0.5) * size, (0.5 - v) * size, curl))
		pts.append(row)
	for j in N:
		for i in N:
			var a0: Vector3 = pts[j][i]; var a1: Vector3 = pts[j][i + 1]; var b1: Vector3 = pts[j + 1][i + 1]; var b0: Vector3 = pts[j + 1][i]
			var vt := (float(j) + 0.5) / N
			var c := Color("f4e06a") if vt > 0.14 else Color("e9d35a")
			c = c.darkened(0.06 * smoothstep(0.55, 1.0, vt))
			for p in [a0, a1, b1, a0, b1, b0]:
				st.set_color(c); st.add_vertex(p)
	var paper := MeshInstance3D.new(); paper.mesh = st.commit()
	var pm := StandardMaterial3D.new(); pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.vertex_color_use_as_albedo = true; pm.cull_mode = BaseMaterial3D.CULL_DISABLED; pm.disable_fog = true
	paper.material_override = pm
	note.add_child(paper)
	var word := Label3D.new(); word.text = "“outside”"
	word.font_size = 160; word.pixel_size = size / 900.0; word.outline_size = 0
	word.modulate = Color("1d2333"); word.shaded = false; word.double_sided = true
	word.position = Vector3(0, -size * 0.03, size * 0.004)
	note.add_child(word)

# --- the wardrobe, and what's behind it ---------------------------------------------------------

func _wardrobe() -> void:
	wardrobe = Node3D.new(); wardrobe.name = "Wardrobe"
	add_child(wardrobe)
	wardrobe.position = WARDROBE_AT
	var model: Node3D = find_child("prop_34_Wardrobe", true, false)
	if model:
		var rot := model.global_basis
		model.reparent(wardrobe, false)
		model.transform = Transform3D(rot, Vector3.ZERO)
		for c in model.find_children("*", "StaticBody3D", true, false):
			c.queue_free()
	var body := AnimatableBody3D.new(); body.sync_to_physics = false
	var shape := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(1.0, 1.9, 0.59)
	shape.shape = b; shape.position = Vector3(0, 0.95, -0.025)
	body.add_child(shape)
	wardrobe.add_child(body)
	wardrobe_spot = Hotspot.make(wardrobe, wardrobe.global_transform * Transform3D(Basis(), Vector3(0, 1.0, -0.3)), Vector3(1.1, 1.9, 0.2), "Push")
	wardrobe_spot.enabled = false
	hole_spot = Hotspot.make(self, Transform3D(Basis(), hole_center + Vector3(0, 0, -0.12)), Vector3(0.6, 1.1, 0.3), "Crawl through")
	hole_spot.enabled = false

var _shoves := 0

## One shove: it grinds a third of the way along the wall. True when the hole's clear.
func shove_wardrobe() -> bool:
	_shoves += 1
	var to := WARDROBE_AT + Vector3(SLIDE * _shoves / 3.0, 0, 0)
	create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(wardrobe, "position", to, 0.6)
	Sfx.play_at("scrape", wardrobe.global_position + Vector3(0, 0.5, 0), 2.0, randf_range(0.9, 1.05))
	Noises.make(wardrobe.global_position, 10.0, "scrape")
	if _shoves >= 3:
		_open_hole()
		return true
	return false

## The plaster cut away (the shader's wall-hole box), broken brick at its edge, rubble on the floor,
## and through it: gaslight and cobbles, a long way off.
func _open_hole() -> void:
	RenderingServer.global_shader_parameter_set("hole_min", Vector4(HOLE_MIN.x, HOLE_MIN.y, HOLE_MIN.z, 1.0))
	RenderingServer.global_shader_parameter_set("hole_max", Vector4(HOLE_MAX.x, HOLE_MAX.y, HOLE_MAX.z, 1.0))
	var kit := TownKit.new(self)
	var rng := RandomNumberGenerator.new(); rng.seed = 47
	var f := Facades.Frame.new(Vector3(HOLE_MIN.x, 0, WALL_Z - 0.01), Vector3(1, 0, 0), Vector3(0, 0, -1))
	Facades.ragged_rim(kit, f, 0.0, HOLE_MAX.x - HOLE_MIN.x, 0.04, 1.76, "stucco_cream", rng, 38)
	for i in 14:
		var p := Vector3(HOLE_MIN.x + rng.randf() * 0.6, 0.0, WALL_Z - 0.08 - rng.randf() * 0.45)
		var s := rng.randf_range(0.02, 0.07)
		kit.box("brick" if rng.randf() < 0.5 else "stucco_cream", p + Vector3(0, s * 0.5, 0), Vector3(s, s * 0.5, s * 0.8), Basis(Vector3.UP, rng.randf() * TAU))
	kit.finish()
	# the far side: dark, and at the end of it a street under gas
	var back := MeshInstance3D.new(); var bx := BoxMesh.new(); bx.size = Vector3(0.75, 2.1, 0.06); back.mesh = bx
	var bm := StandardMaterial3D.new(); bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(0.0, 0.0, 0.0)
	back.material_override = bm; add_child(back)
	back.position = Vector3((HOLE_MIN.x + HOLE_MAX.x) * 0.5, 0.95, WALL_Z + 0.24)
	bm.disable_fog = true
	var far := MeshInstance3D.new(); var fm := QuadMesh.new(); fm.size = Vector2(0.08, 0.12); far.mesh = fm
	var fmat := StandardMaterial3D.new(); fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color(0.75, 0.5, 0.25); fmat.disable_fog = true
	far.material_override = fmat; add_child(far)
	far.position = Vector3((HOLE_MIN.x + HOLE_MAX.x) * 0.5 + 0.05, 0.45, WALL_Z + 0.215)
	far.rotation.y = PI
	var tunnel := StaticBody3D.new(); add_child(tunnel)
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(0.7, 2.0, 0.2); cs.shape = b
	tunnel.add_child(cs); tunnel.position = Vector3((HOLE_MIN.x + HOLE_MAX.x) * 0.5, 1.0, WALL_Z + 0.25)
