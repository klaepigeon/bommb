class_name ExportedFlat
extends Node3D
## Flat 47 as built for the JS version (assets/flat47/flat47.glb + level.json), as an art asset:
## the rooms, the furniture, everything the Sokolovs owned, with its painted relief. This makes it
## a place you can be in: every surface through shaders/world.gdshader, collision and footstep
## surfaces from the room plan, the lights given characters (Fitting), the labelled doors,
## drawers and loose things given behaviours. `flesh` (0..1) turns every surface to meat in place
## (level 2 is this flat, grown).
##
## Coordinates: x east 0..10, z south 0..8, the courtyard windows along z = 0, the balcony north
## of them, the front door in the hall's east wall at x = 10, the landing east of it.

const H := 2.75
const KEEP := AABB(Vector3(-0.6, -0.8, -1.95), Vector3(14.8, 4.3, 10.4))   # the flat, its balcony, the landing
const PLACEHOLDER := "neenor neenor neenor neenor ki or Jules have to write this later neenor neenor neenor placeholder"
const TEXT_PATCH := {
	# the JS version's text named a husband who isn't in this story: to be rewritten
	"prop_0_Wedding_photograph": PLACEHOLDER,
	"pick_129_Bundle_of_letters": PLACEHOLDER,
}
const SURFACE := {"bath": "tile", "kitchen": "lino", "hall": "wood", "living": "wood", "bedroom": "wood", "child": "wood", "storage": "wood"}

var level: Dictionary
var flesh := 0.0
var doors := {}            # id -> ExportDoor
var drawers: Array = []    # ExportDrawer
var props := {}            # node name -> Prop
var fittings: Array = []   # Fitting
var model: Node3D
var _mats := {}
var skip_props: Array = [] # node names the level handles itself (the wardrobe)
## The meat's colours (the world shader's meat_* uniforms); empty keeps the shader's red.
var meat := {}

## Kit mode (the maze): the flat isn't built; its model is loaded (hidden), its materials
## converted, and it hands out copies of its pieces (piece()) and its rooms' surfaces
## (surface_material(), surface_uv()).
var kit := false

func _init(flesh_amount := 0.0, skip: Array = [], as_kit := false) -> void:
	flesh = flesh_amount; skip_props = skip; kit = as_kit

func _ready() -> void:
	level = JSON.parse_string(FileAccess.get_file_as_string("res://assets/flat47/level.json"))
	model = (load("res://assets/flat47/flat47.glb") as PackedScene).instantiate()
	model.name = "Apartment"
	add_child(model)
	if kit:
		model.visible = false
		_lift_coplanar()
		_materials()
		return
	_strip_outside()
	_lift_coplanar()
	_materials()
	_behaviours()
	_collision()
	_lights()

func room_of(p: Vector3) -> String:
	for k in level.rooms:
		var r: Dictionary = level.rooms[k]
		if p.x >= r.x0 and p.x < r.x1 and p.z >= r.z0 and p.z < r.z1: return k
	if p.x >= 10.0 and p.z > 3.4: return "landing"
	if p.z < 0.0: return "balcony"
	return ""

## Faces the export laid exactly on other faces (skirting on walls, tiles on walls, trims and
## reveals doubled on the wall shell, rugs on floors) fight for the pixel, and flicker as the view
## moves. tools/geo_check.py finds them; zfix.json lists the smaller of each pair, and here they're
## lifted 2.5 mm a layer off what they lie on (a trim on a tile on a wall: two layers), along their
## own normals, so they always win.
const LIFT := 0.0025
func _lift_coplanar() -> void:
	if not FileAccess.file_exists("res://assets/flat47/zfix.json"): return
	var layers = JSON.parse_string(FileAccess.get_file_as_string("res://assets/flat47/zfix.json"))
	for p in layers:
		var mi := model.find_child(String(p), true, false) as MeshInstance3D
		var up: float = LIFT * float(layers[p])
		if not mi or not mi.mesh: continue
		var am := ArrayMesh.new()
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var n = arr[Mesh.ARRAY_NORMAL]
			if n == null or (n as PackedVector3Array).size() != v.size(): continue
			# each triangle along its own flat normal (stored normals are smoothed round corners,
			# so pushing along them can land a face back in the plane it was meant to leave);
			# the stored normals only say which side is the front. Unshared, so faces move apart.
			var idx = arr[Mesh.ARRAY_INDEX]
			var order: PackedInt32Array = idx if idx != null and (idx as PackedInt32Array).size() > 0 else PackedInt32Array(range(v.size()))
			var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var uv = arr[Mesh.ARRAY_TEX_UV]
			for t in range(0, order.size() - 2, 3):
				var i0 := order[t]; var i1 := order[t + 1]; var i2 := order[t + 2]
				var fn := (v[i1] - v[i0]).cross(v[i2] - v[i0]).normalized()
				var avg: Vector3 = (n as PackedVector3Array)[i0] + (n as PackedVector3Array)[i1] + (n as PackedVector3Array)[i2]
				if fn.dot(avg) < 0.0: fn = -fn
				for i in [i0, i1, i2]:
					st.set_normal((n as PackedVector3Array)[i])
					if uv != null and (uv as PackedVector2Array).size() == v.size(): st.set_uv((uv as PackedVector2Array)[i])
					st.add_vertex(v[i] + fn * up)
			st.commit(am)
			am.surface_set_material(am.get_surface_count() - 1, mi.mesh.surface_get_material(s))
		if am.get_surface_count() == mi.mesh.get_surface_count(): mi.mesh = am

func _strip_outside() -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		var a: AABB = (global_transform.affine_inverse() * m.global_transform) * m.get_aabb()
		var c := a.get_center()
		if not KEEP.has_point(c) or a.size.length() > 30.0 or (c.x > 10.4 and c.z < 3.3):
			m.queue_free()

## Every opaque surface through the world shader (painted relief, roughness, emission, flesh);
## glass keeps a standard material, sampled unfiltered.
func _materials() -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.is_queued_for_deletion(): continue
		var all_clear := true
		for i in m.mesh.get_surface_count():
			var src := m.get_active_material(i)
			var clear: bool = src is BaseMaterial3D and (src as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
			all_clear = all_clear and clear
			if not (src is StandardMaterial3D): continue
			if not _mats.has(src): _mats[src] = _convert(src)
			m.set_surface_override_material(i, _mats[src])
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if all_clear else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func _convert(std: StandardMaterial3D) -> Material:
	if std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		var t := std.duplicate() as StandardMaterial3D
		t.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		if flesh > 0.0: t.albedo_color = t.albedo_color * meat.get("glass", Color(1.0, 0.5, 0.5, 1.0))
		return t
	var sm := ShaderMaterial.new(); sm.shader = preload("res://shaders/world.gdshader")
	sm.set_shader_parameter("albedo_color", std.albedo_color)
	sm.set_shader_parameter("albedo_tex", std.albedo_texture if std.albedo_texture else _white())
	sm.set_shader_parameter("roughness", std.roughness)
	if std.roughness_texture:
		sm.set_shader_parameter("roughness_tex", std.roughness_texture); sm.set_shader_parameter("use_roughness_tex", true)
	if std.normal_enabled and std.normal_texture:
		sm.set_shader_parameter("normal_tex", std.normal_texture); sm.set_shader_parameter("use_normal_tex", true)
		sm.set_shader_parameter("normal_depth", std.normal_scale * 0.1)
	if std.emission_enabled:
		sm.set_shader_parameter("emission", Vector3(std.emission.r, std.emission.g, std.emission.b) * std.emission_energy_multiplier)
		if std.emission_texture:
			sm.set_shader_parameter("emission_tex", std.emission_texture); sm.set_shader_parameter("use_emission_tex", true)
	if std.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR: sm.set_shader_parameter("use_alpha_cut", true)
	sm.set_shader_parameter("flesh", flesh)
	sm.set_shader_parameter("flesh_seed", randf() * 10.0)
	for k in meat:
		if k != "glass": sm.set_shader_parameter(k, meat[k])
	return sm

static var _white_tex: Texture2D
static func _white() -> Texture2D:
	if not _white_tex:
		var img := Image.create(2, 2, false, Image.FORMAT_RGB8); img.fill(Color.WHITE)
		_white_tex = ImageTexture.create_from_image(img)
	return _white_tex

func _extras(n: Node) -> Dictionary:
	return n.get_meta("extras") if n.has_meta("extras") else {}

func _behaviours() -> void:
	var nodes := model.find_children("*", "Node3D", true, false)
	for n in nodes:
		if TEXT_PATCH.has(String(n.name)) and n.has_meta("extras"):
			var ex: Dictionary = n.get_meta("extras"); ex["desc"] = "" if Game.hides_placeholders() else TEXT_PATCH[String(n.name)]; n.set_meta("extras", ex)
	for n in nodes:
		if n.is_queued_for_deletion(): continue
		var ex := _extras(n)
		match ex.get("kind", ""):
			"door":
				n.set_script(ExportDoor); n.call("setup", ex)
				# a door left half open stands across the hall: open it all the way to the wall
				var dd := n as ExportDoor
				if dd.angle > 0.15: dd.angle = dd.max_angle; dd.target = dd.max_angle; dd.is_open = true; dd._apply()
				doors[ex.get("id", String(n.name))] = n
			"drawer":
				n.set_script(ExportDrawer); n.call("setup", ex)
				drawers.append(n)
	_dress_doors()
	for n in nodes:
		if n.is_queued_for_deletion() or not is_instance_valid(n): continue
		var ex := _extras(n)
		var k: String = ex.get("kind", "")
		if (k == "prop" or k == "pick") and not skip_props.has(String(n.name)):
			props[String(n.name)] = Prop.from_export(n, ex)

## The doors rebuilt as geometry (DoorLeaf): the front door padded and quilted, the rest
## panelled and painted, the living room's glazed. The balcony door keeps its exported glass.
const DOOR_STYLE := {"dEntry": ["padded", {"number": 47}], "dLiving": ["panel", {"glazed": true}], "dKitchen": ["panel", {"glazed": true}]}
func _dress_doors() -> void:
	for id in doors:
		if String(id).begins_with("bal"): continue
		var d: ExportDoor = doors[id]
		var spec: Array = DOOR_STYLE.get(id, ["panel", {}])
		for mi in d.find_children("*", "MeshInstance3D", true, false): (mi as MeshInstance3D).visible = false
		var o: Dictionary = (spec[1] as Dictionary).duplicate()
		if spec[0] == "padded":
			# the number goes on the side facing the landing (+x)
			var z_closed: Vector3 = d.get_parent().global_basis * Basis(Vector3.UP, d.psi0) * Vector3(0, 0, 1)
			o["outside"] = 1.0 if z_closed.x > 0.0 else -1.0
		DoorLeaf.build(d, d.leaf_w, float(_extras(d).get("h", 2.02)), spec[0], conv, o)

var _conv_cache := {}
## A StandardMaterial3D through the world shader (and the flesh), shared when asked twice.
func conv(std: StandardMaterial3D) -> Material:
	var key := "%d|%s|%.2f|%d" % [std.albedo_texture.get_rid().get_id() if std.albedo_texture else 0, std.albedo_color, std.roughness, std.transparency]
	if not _conv_cache.has(key): _conv_cache[key] = _convert(std)
	return _conv_cache[key]

## Collision from the room plan: wall boxes, floors (each with what it sounds like underfoot),
## a ceiling.
func _collision() -> void:
	var walls := StaticBody3D.new(); walls.name = "Walls"; add_child(walls)
	walls.set_meta("surface", "wood")
	for c in level.colliders:
		# rubble under 30 cm he steps over; things overhead (the fallen ceiling) don't stop feet
		if c.y1 <= 0.3 or c.y0 > 1.8: continue
		var sh := CollisionShape3D.new(); var b := BoxShape3D.new()
		var h: float = c.y1 - c.y0
		b.size = Vector3(c.hx * 2.0, h, c.hz * 2.0); sh.shape = b
		sh.transform = Transform3D(Basis(Vector3.UP, c.rot), Vector3(c.x, c.y0 + h * 0.5, c.z))
		walls.add_child(sh)
	# floors: one body per room so a footstep can ask what it's on
	for k in level.rooms:
		var r: Dictionary = level.rooms[k]
		_floor(r.x0, r.x1, r.z0, r.z1, 0.0, SURFACE.get(k, "wood"))
	for f in level.floors:
		if f.x0 > 13.9: continue
		_floor(f.x0, f.x1, f.z0, f.z1, f.y, "concrete" if (f.x0 > 10.0 or f.z1 < 0.1) else "wood")
	var ceil := StaticBody3D.new(); add_child(ceil)
	var cs := CollisionShape3D.new(); var cb := BoxShape3D.new(); cb.size = Vector3(15, 0.4, 9); cs.shape = cb
	cs.position = Vector3(7, H + 0.2, 4); ceil.add_child(cs)

func _floor(x0: float, x1: float, z0: float, z1: float, y: float, surface: String) -> void:
	var sb := StaticBody3D.new(); sb.set_meta("surface", surface); add_child(sb)
	var sh := CollisionShape3D.new(); var b := BoxShape3D.new()
	b.size = Vector3(x1 - x0, 0.4, z1 - z0); sh.shape = b
	sh.position = Vector3((x0 + x1) * 0.5, y - 0.2, (z0 + z1) * 0.5)
	sb.add_child(sh)

## The JS version's lights (physical units converted: energy = candela / pi), each a Fitting with
## the character the JS version gave it. Courtyard and street lights shining in from outside are
## left out: outside isn't there any more.
func _lights() -> void:
	for L in level.lights:
		if L.get("broken", false): continue
		var pos := Vector3(L.pos[0], L.pos[1], L.pos[2])
		if not KEEP.has_point(pos) or (pos.y > 3.0 and String(L.type) != "SpotLight"): continue
		if String(L.type) == "SpotLight": continue        # the street lamp: no street
		if String(L.get("name", "")).begins_with("stair"): continue    # the level lights its own stairwell
		var l: Light3D
		match String(L.type):
			"PointLight":
				var o := OmniLight3D.new()
				o.omni_range = float(L.range) if float(L.range) > 0.0 else 8.0
				o.omni_attenuation = float(L.get("decay", 2.0))
				l = o
			"RectAreaLight":
				# window light (no area lights on phones): a broad soft spot just inside the glass
				var sp := SpotLight3D.new()
				sp.spot_range = 7.0; sp.spot_attenuation = 2.0; sp.spot_angle = 80.0; sp.spot_angle_attenuation = 1.6
				sp.light_specular = 0.2
				L.intensity = float(L.intensity) * float(L.w) * float(L.h)
				pos += Vector3(L.dir[0], 0, L.dir[2]) * 0.15
				l = sp
		l.light_color = Color(L.color)
		l.light_energy = float(L.intensity) / PI
		l.shadow_enabled = false
		add_child(l); l.position = pos
		if l is SpotLight3D: l.look_at(pos + Vector3(L.dir[0], L.dir[1] - 0.15, L.dir[2]))
		var fl = L.get("flicker")
		var kind: String = fl if fl is String else "steady"
		if kind == "emergency": kind = "pulse"
		var f := Fitting.wrap(l, kind, L.get("circuit") is String)
		f.on = bool(L.on) and (not (L.get("circuit") is String) or bool(level.circuits.get(L.circuit, true)))
		f.room = room_of(pos + ((-l.global_basis.z) * 1.2 if l is SpotLight3D else Vector3.ZERO))
		f.set_meta("window", String(L.type) == "RectAreaLight")
		fittings.append(f)

## (Lights used to switch on and off with distance to stay inside the phone renderer's 8 a mesh;
## that read as flicker. They stay on: each copy of the flat is shown on its own.)

func _room_dist(k: String, p: Vector3) -> float:
	if k == "" or not level.rooms.has(k):
		return 0.0 if k == "" else (0.0 if room_of(p) == k else 2.0)
	var r: Dictionary = level.rooms[k]
	return Vector2(maxf(maxf(r.x0 - p.x, p.x - r.x1), 0.0), maxf(maxf(r.z0 - p.z, p.z - r.z1), 0.0)).length()

## The landing side of the front wall, built where the wall's collision really ends (x = 10.42:
## the export's wall is 42 cm thick but only drawn on the flat's side), with the doorway as a
## proper opening the size of the gap in the collision (z 4.12-5.0, 2.1 m high) and its depth
## lined back to the door, like a doorway in a thick Soviet wall.
func landing_face(face: Material, _reveal: Material) -> void:
	const X := 10.447; const Z0 := 4.12; const Z1 := 5.0; const TOP := 2.1; const H2 := 2.8     # (3 mm proud of the export's door surround, at 10.44)
	Build.wall(self, Vector2(X, 3.4), Vector2(X, 8.0), face, [{"at": (Z0 + Z1) * 0.5 - 3.4, "w": Z1 - Z0, "top": TOP}], H2, 0.02)
	# (the reveals through the wall are the export's own: doubling them made them flicker)

# ------------------------------------------------------------------ kit mode
## A copy of a named piece of the flat (a cupboard, the bath, a chair), its materials converted,
## placed so its floor-centre is the returned node's origin. meta "size": its bounding size.
func piece(node_name: String) -> Node3D:
	var n := model.find_child(node_name, true, false) as Node3D
	if not n: return null
	var ab := AABB(); var first := true
	var meshes: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D: meshes.append(n)
	var inv := model.global_transform.affine_inverse()
	for mi in meshes:
		var m := mi as MeshInstance3D
		if not m.mesh: continue
		var a: AABB = (inv * m.global_transform) * m.get_aabb()
		ab = a if first else ab.merge(a); first = false
	var dup := n.duplicate() as Node3D
	dup.transform = inv * n.global_transform
	dup.visible = true
	for c in dup.find_children("*", "Node3D", true, false): (c as Node3D).visible = true
	var holder := Node3D.new(); holder.name = node_name
	holder.add_child(dup)
	dup.position -= Vector3(ab.get_center().x, ab.position.y, ab.get_center().z)
	holder.set_meta("size", ab.size)
	return holder

## The converted material on one of the room surfaces ("living-n", "bath-floor", ...).
func surface_material(mesh_name: String) -> Material:
	var mi := model.find_child(mesh_name, true, false) as MeshInstance3D
	if not mi: return null
	return mi.get_surface_override_material(0) if mi.get_surface_override_material(0) else mi.get_active_material(0)

## How that surface's texture is laid on: UV per metre along it (x) and up it / across it (y),
## fitted to its vertices; walls: (along the wall, up), floors: (x, z). z, w: the UV at 0.
func surface_uv(mesh_name: String) -> Vector4:
	var mi := model.find_child(mesh_name, true, false) as MeshInstance3D
	if not mi or not mi.mesh: return Vector4(1, 1, 0, 0)
	var arr := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv = arr[Mesh.ARRAY_TEX_UV]
	if uv == null or v.size() < 3: return Vector4(1, 1, 0, 0)
	var ab := AABB(v[0], Vector3.ZERO)
	for p in v: ab = ab.expand(p)
	var floor := ab.size.y < 0.01
	var h_axis := 0 if ab.size.x >= ab.size.z else 2
	var a_axis := 2 if floor else 1
	return Vector4(_slope(v, uv, h_axis, 0), _slope(v, uv, a_axis, 1), _slope(v, uv, h_axis, 0, true), _slope(v, uv, a_axis, 1, true))

static func _slope(v: PackedVector3Array, uv: PackedVector2Array, axis: int, comp: int, intercept := false) -> float:
	# least squares: uv[comp] against position[axis]
	var n := float(v.size()); var sx := 0.0; var sy := 0.0; var sxx := 0.0; var sxy := 0.0
	for i in v.size():
		var x: float = v[i][axis]; var y: float = uv[i][comp]
		sx += x; sy += y; sxx += x * x; sxy += x * y
	var den := n * sxx - sx * sx
	var slope := 1.0 if absf(den) < 1e-9 else (n * sxy - sx * sy) / den
	return (sy - slope * sx) / n if intercept else slope

## The nearest drawer to a point (the level picks one to hide something in).
func drawer_near(p: Vector3) -> ExportDrawer:
	var best: ExportDrawer = null; var bd := INF
	for d in drawers:
		var dd: float = (d as Node3D).global_position.distance_to(p)
		if dd < bd: bd = dd; best = d
	return best

## A labelled node by name (the wardrobe, for instance), wherever it is in the model.
func node(name: String) -> Node3D:
	return model.find_child(name, true, false) as Node3D

## Hide exported meshes near a point (where something built here replaces the JS version's).
func hide_near(p: Vector3, radius: float, max_size: float) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if not m.is_inside_tree(): continue
		var a: AABB = m.global_transform * m.get_aabb()
		if a.size.length() > max_size: continue
		var c := a.get_center()
		if Vector2(c.x - p.x, c.z - p.z).length() < radius: m.visible = false

## A path-finding grid over the flat's floor (for the infected): cells `cell` metres, solid where
## a wall is (grown by `margin`). Grid cell (0,0) is at the flat's local (-0.5, -2.0).
func _prop_box(pr: Node) -> AABB:
	for c in pr.get_children():
		if c is CollisionShape3D and c.shape is BoxShape3D:
			return AABB(c.position - c.shape.size * 0.5, c.shape.size)
	return AABB()

func nav_grid(cell: float, margin := 0.18, fmargin := 0.1, loose_corners := false) -> AStarGrid2D:
	var g := AStarGrid2D.new()
	var w := int(ceil(11.0 / cell)); var h := int(ceil(10.5 / cell))
	g.region = Rect2i(0, 0, w, h); g.cell_size = Vector2(cell, cell)
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS if loose_corners else AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.update()
	for y in h:
		for x in w:
			var p := Vector2(-0.5 + (x + 0.5) * cell, -2.0 + (y + 0.5) * cell)
			var solid := true
			for f in level.floors:
				if p.x >= f.x0 and p.x <= f.x1 and p.y >= f.z0 and p.y <= f.z1 and f.x0 < 13.9: solid = false
			if not solid:
				for pr in props.values():
					if not is_instance_valid(pr) or pr.get_meta("debris", false): continue
					var ab: AABB = (global_transform.affine_inverse() * (pr as Node3D).global_transform) * _prop_box(pr)
					if p.x > ab.position.x - fmargin and p.x < ab.end.x + fmargin and p.y > ab.position.z - fmargin and p.y < ab.end.z + fmargin and ab.end.y > 0.35:
						solid = true; break
			if not solid:
				for nb in get_tree().get_nodes_in_group("nav_block"):
					var ab2: AABB = (global_transform.affine_inverse() * (nb as Node3D).global_transform) * _prop_box(nb)
					if p.x > ab2.position.x - fmargin and p.x < ab2.end.x + fmargin and p.y > ab2.position.z - fmargin and p.y < ab2.end.z + fmargin:
						solid = true; break
			if not solid:
				for c in level.colliders:
					var d := (p - Vector2(c.x, c.z)).rotated(float(c.rot))
					var m2: float = margin if c.y1 - c.y0 > 2.2 else fmargin        # walls; furniture tighter
					if c.y1 > 0.3 and c.y0 < 1.8 and absf(d.x) <= c.hx + m2 and absf(d.y) <= c.hz + m2: solid = true; break
			g.set_point_solid(Vector2i(x, y), solid)
	return g
