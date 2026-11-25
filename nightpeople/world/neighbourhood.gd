class_name Neighbourhood
extends NavigationRegion3D
## Builds the playable block from data/neighbourhood.json: street, sidewalks, back yard,
## buildings with enterable ground floors (rooms, walls with real door and window openings,
## floors, ceilings, lights), facades, signs, props, doors, owned items, readables, and every
## place NPCs can use (registered in World). Then bakes the navigation mesh from the result.
## Buildings are authored in local coordinates (x along the facade, z from the street inward)
## and placed with pos + rot, so one description works on either side of the street.

const DATA := "res://data/neighbourhood.json"
const FLOOR_Y := 0.15          ## sidewalk and ground-floor level
const STOREY := 3.2
const WALL_T := 0.3
const DOOR_W := 1.3
const DOOR_H := 2.1
const WALL_H := FLOOR_Y + STOREY + 0.15

const DoorScript := preload("res://world/door.gd")
const ItemScript := preload("res://world/item.gd")
const ReadableScript := preload("res://world/readable.gd")

var data: Dictionary
var street: Dictionary
var lamps: Array[OmniLight3D] = []
var room_lights: Dictionary = {}      ## room id → OmniLight3D

func build() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	street = data.street
	World.clear()
	_street()
	for b in data.buildings:
		_building(b)
	_bake()

# ------------------------------------------------------------------ street

func _street() -> void:
	var x0: float = street.x[0]
	var x1: float = street.x[1]
	var road := Assets.surface("asphalt", 3.0, Color(0.75, 0.75, 0.78))
	var walk := Assets.surface("sidewalk", 1.6)
	var curb := Assets.surface("concrete_dirty", 1.0)
	var line := Assets.surface("", 1.0, Color(0.85, 0.65, 0.1))
	var yard_floor := Assets.surface("concrete_stain", 2.5, Color(0.7, 0.7, 0.7))
	var brick := Assets.surface("brick_dirty", 2.0)
	# Chunked along x so no mesh is lit by more lights than a phone allows per object.
	var chunk := 16.0
	var x := x0
	while x < x1 - 0.01:
		var w := minf(chunk, x1 - x)
		var cx := x + w * 0.5
		var kit := MeshKit.new()
		kit.box(Vector3(cx, -0.1, 0), Vector3(w, 0.2, 10), [null, null, road, null, null, null])
		for side in [-1.0, 1.0]:
			kit.box(Vector3(cx, FLOOR_Y * 0.5, side * 7.0), Vector3(w, FLOOR_Y, 4.0), [null, null, walk, null, curb if side < 0 else null, curb if side > 0 else null])
		kit.box(Vector3(cx, 0.003, -0.12), Vector3(w, 0.006, 0.1), [null, null, line, null, null, null], false)
		kit.box(Vector3(cx, 0.003, 0.12), Vector3(w, 0.006, 0.1), [null, null, line, null, null, null], false)
		_add_kit(kit, self, "Street%d" % int(x))
		x += w
	# alley and back yard
	var yard: Dictionary = street.yard
	var kit := MeshKit.new()
	var ax: Array = yard.alley_x
	kit.box(Vector3((ax[0] + ax[1]) * 0.5, FLOOR_Y * 0.5, -16), Vector3(ax[1] - ax[0], FLOOR_Y, 14), [null, null, yard_floor, null, null, null])
	World.yard_rects = [[ax[0], -23.0, ax[1], -9.0], [yard.x[0], yard.z[0], yard.x[1], yard.z[1]]]
	var yx: Array = yard.x
	var yz: Array = yard.z
	var ycx: float = (yx[0] + yx[1]) * 0.5
	var ycz: float = (yz[0] + yz[1]) * 0.5
	kit.box(Vector3(ycx, FLOOR_Y * 0.5, ycz), Vector3(yx[1] - yx[0], FLOOR_Y, yz[1] - yz[0]), [null, null, yard_floor, null, null, null])
	kit.box(Vector3(ycx, 2.5, yz[0] - WALL_T * 0.5), Vector3(yx[1] - yx[0] + WALL_T * 2, 5.0, WALL_T), brick)
	kit.box(Vector3(yx[0] - WALL_T * 0.5, 2.5, ycz), Vector3(WALL_T, 5.0, yz[1] - yz[0]), brick)
	kit.box(Vector3(yx[1] + WALL_T * 0.5, 2.5, ycz), Vector3(WALL_T, 5.0, yz[1] - yz[0]), brick)
	_add_kit(kit, self, "Yard")
	var yard_light := _light(Vector3(-12, 4.2, -25), Color(1.0, 0.75, 0.45), 9.0, 1.0)
	add_child(yard_light)
	# street lamps: a tall Retro Urban Kit lamp, its arm over the road, a sodium-orange light
	for l in street.lamps:
		var side: float = l[1]
		var lamp := Assets.prop("detail-light-single")
		lamp.scale = Vector3.ONE * (6.0 / 3.2)
		lamp.position = Vector3(l[0], FLOOR_Y, side * 5.5)
		lamp.rotation_degrees.y = 180.0 if side < 0 else 0.0
		add_child(lamp)
		var light := _light(Vector3(l[0], 5.2, side * 4.4), Color(1.0, 0.55, 0.18), 12.0, 2.2)
		add_child(light)
		lamps.append(light)
	for p in street.props:
		_prop(p, self, Vector3.ZERO)
	for tx in [-36.0, 0.0, 36.0]:
		Sfx.loop_at("street_traffic", Vector3(tx, 1.5, 0), "", {"size": 14.0})
	for p in street.places:
		_place(p, Transform3D.IDENTITY, Vector3.ZERO)
	for pt in street.patrol:
		World.patrol.append(Vector3(pt[0], FLOOR_Y, pt[1]))
	for e in ["edge.west", "edge.east"]:
		World.edges.append(World.places[e].pos)

# ------------------------------------------------------------------ buildings

func _building(b: Dictionary) -> void:
	var node := Node3D.new()
	node.name = b.id
	node.position = Vector3(b.pos[0], 0, b.pos[1])
	node.rotation_degrees.y = b.rot
	add_child(node)
	var xf := node.transform
	var W: float = b.size[0]
	var D: float = b.size[1]
	var H: float = FLOOR_Y + b.floors * STOREY
	var facade := Assets.surface(b.facade, 2.4)
	var trim := Assets.surface("concrete_dirty", 1.5, Color(0.8, 0.78, 0.72))
	var kit := MeshKit.new()
	if b.get("solid", false):
		kit.box(Vector3(W * 0.5, H * 0.5, D * 0.5), Vector3(W, H, D), facade)
		if b.get("shuttered", false):
			kit.box(Vector3(W * 0.5, 1.6, -0.03), Vector3(W - 2.0, 2.9, 0.06), Assets.surface("shutter", 1.5, Color(0.75, 0.75, 0.7)), false)
	else:
		for r in b.rooms:
			_room(r, b, xf, kit)
		var openings := _openings(b)
		# The shell stands just inside the footprint so neighbours never share a wall plane.
		var h := WALL_T * 0.5
		var shell := [[Vector2(0, h), Vector2(W, h)], [Vector2(W - h, 0), Vector2(W - h, D)], [Vector2(W, D - h), Vector2(0, D - h)], [Vector2(h, D), Vector2(h, 0)]]
		for s in shell:
			_wall(kit, b, s[0], s[1], openings, facade, 0.0)
		for p in b.get("partitions", []):
			_wall(kit, b, Vector2(p[0][0], p[0][1]), Vector2(p[1][0], p[1][1]), openings, facade, 0.0)
		if b.floors > 1:
			var up := H - WALL_H
			kit.box(Vector3(W * 0.5, WALL_H + up * 0.5, D * 0.5), Vector3(W, up, D), facade)
		for o in openings:
			if o.has("door"):
				_door(o.door, node, o)
			else:
				_glass(o, node, kit)
	# cornice and roof
	kit.box(Vector3(W * 0.5, H + 0.2, -0.3), Vector3(W + 0.4, 0.4, 0.6), trim, false)
	kit.box(Vector3(W * 0.5, H + 0.02, D * 0.5), Vector3(W, 0.04, D), [null, null, Assets.surface("tar_roof", 3.0), null, null, null], false)
	_add_kit(kit, node, "Geometry")
	_facade_dressing(b, node, W, H)
	for p in b.get("props", []):
		_prop(p, node, Vector3(0, FLOOR_Y, 0))
	for p in b.get("places", []):
		_place(p, xf, Vector3(0, FLOOR_Y, 0), float(b.rot))
	for it in b.get("items", []):
		var item: Item = ItemScript.new()
		item.setup(it)
		item.position = Vector3(it.at[0], FLOOR_Y + it.get("y", 0.0), it.at[1])
		var vis := Assets.prop(it.get("prop", "books"))
		vis.scale = Vector3.ONE * 0.6
		item.add_child(vis)
		node.add_child(item)
	for rd in b.get("readables", []):
		var r: Readable = ReadableScript.new()
		r.title = rd.title
		r.text = rd.text
		r.label = rd.title
		r.position = Vector3(rd.at[0], FLOOR_Y + rd.get("y", 0.8), rd.at[1])
		var paper := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.3, 0.01, 0.22)
		pm.material = Assets.surface("", 1.0, Color(0.9, 0.88, 0.75), Color(0.12, 0.12, 0.1))
		paper.mesh = pm
		r.add_child(paper)
		node.add_child(r)

func _room(r: Dictionary, b: Dictionary, xf: Transform3D, kit: MeshKit) -> void:
	var x0: float = r.rect[0]
	var z0: float = r.rect[1]
	var x1: float = r.rect[2]
	var z1: float = r.rect[3]
	var c := Vector3((x0 + x1) * 0.5, 0, (z0 + z1) * 0.5)
	var size := Vector3(x1 - x0, 0, z1 - z0)
	kit.box(c + Vector3(0, FLOOR_Y * 0.5, 0), size + Vector3(0, FLOOR_Y, 0), [null, null, Assets.surface(r.floor, 2.0), null, null, null])
	kit.box(c + Vector3(0, FLOOR_Y + STOREY + 0.075, 0), size + Vector3(0, 0.15, 0), [null, null, null, Assets.surface(r.ceiling, 2.5, Color(0.8, 0.78, 0.7)), null, null], false)
	# world-space bounds for World.room_at()
	var a := xf * Vector3(x0, 0, z0)
	var bb := xf * Vector3(x1, WALL_H, z1)
	var aabb := AABB(a.min(bb), (bb - a).abs())
	var open: Array = []
	if r.has("open"):
		open = [Clock.parse(r.open[0]), Clock.parse(r.open[1])]
	World.add_room({"id": r.id, "building": b.id, "name": r.name, "aabb": aabb, "owners": r.owners, "public": r.public, "open": open, "floor": r.floor})
	for snd in r.get("sounds", []):
		var at: Vector3 = xf * (c + Vector3(0, 2.0, 0))
		if snd.has("at"):
			at = xf * Vector3(snd.at[0], FLOOR_Y + 1.2, snd.at[1])
		Sfx.loop_at(snd.id, at, r.id, {"when_open": snd.get("when_open", false), "crowd": snd.get("crowd", false), "size": maxf(size.x, size.z) * 0.5})
	var light := _light(xf * (c + Vector3(0, FLOOR_Y + 2.4, 0)), Color(r.light[0], r.light[1], r.light[2]), maxf(size.x, size.z) * 0.75 + 1.5, r.energy)
	add_child(light)
	room_lights[r.id] = light

## Door and window openings of a building, in its local plan coordinates.
func _openings(b: Dictionary) -> Array:
	var out := []
	for d in b.get("doors", []):
		out.append({"at": Vector2(d.at[0], d.at[1]), "w": DOOR_W, "y0": 0.0, "y1": FLOOR_Y + DOOR_H, "door": d})
	for w in b.get("windows", []):
		out.append({"at": Vector2(w.at[0], w.at[1]), "w": float(w.width), "y0": FLOOR_Y + float(w.sill), "y1": FLOOR_Y + float(w.top), "window": w})
	return out

## One straight, axis-aligned wall from a to c, with holes where openings sit on it. Each side
## takes the wall covering of the room it faces (facade outside).
func _wall(kit: MeshKit, b: Dictionary, a: Vector2, c: Vector2, openings: Array, facade: Material, extend: float) -> void:
	var dir := (c - a).normalized()
	var length := a.distance_to(c)
	var normal := Vector2(-dir.y, dir.x)
	var holes := []
	for o in openings:
		var rel: Vector2 = o.at - a
		if absf(rel.dot(normal)) < 0.2 and rel.dot(dir) > 0.0 and rel.dot(dir) < length:
			var t := rel.dot(dir)
			holes.append([t - o.w * 0.5, t + o.w * 0.5, o.y0, o.y1])
			o["axis_dir"] = dir
			o["wall_at"] = a + dir * t
	holes.sort_custom(func(p, q): return p[0] < q[0])
	var cursor := -extend
	for h in holes:
		if h[0] > cursor:
			_wall_piece(kit, b, a, dir, normal, cursor, h[0], 0.0, WALL_H, facade)
		if h[2] > 0.0:
			_wall_piece(kit, b, a, dir, normal, h[0], h[1], 0.0, h[2], facade)
		_wall_piece(kit, b, a, dir, normal, h[0], h[1], h[3], WALL_H, facade)
		cursor = h[1]
	if cursor < length + extend:
		_wall_piece(kit, b, a, dir, normal, cursor, length + extend, 0.0, WALL_H, facade)

func _wall_piece(kit: MeshKit, b: Dictionary, a: Vector2, dir: Vector2, normal: Vector2, t0: float, t1: float, y0: float, y1: float, facade: Material) -> void:
	if t1 - t0 < 0.01 or y1 - y0 < 0.01:
		return
	var mid := a + dir * ((t0 + t1) * 0.5)
	var center := Vector3(mid.x, (y0 + y1) * 0.5, mid.y)
	var side_l := _covering(b, mid + normal * 0.5, facade)
	var side_r := _covering(b, mid - normal * 0.5, facade)
	var size: Vector3
	var mats := []
	if absf(dir.x) > 0.5:    # runs along x: faces are ±z
		size = Vector3(t1 - t0, y1 - y0, WALL_T)
		var pz := side_l if normal.y > 0 else side_r
		var nz := side_r if normal.y > 0 else side_l
		mats = [pz, pz, pz, pz, pz, nz]
	else:                    # runs along z: faces are ±x
		size = Vector3(WALL_T, y1 - y0, t1 - t0)
		var px := side_l if normal.x > 0 else side_r
		var nx := side_r if normal.x > 0 else side_l
		mats = [px, nx, px, px, px, px]
	kit.box(center, size, mats)

func _covering(b: Dictionary, p: Vector2, facade: Material) -> Material:
	for r in b.get("rooms", []):
		if p.x > r.rect[0] and p.x < r.rect[2] and p.y > r.rect[1] and p.y < r.rect[3]:
			return Assets.surface(r.wall, 2.0)
	return facade

func _door(d: Dictionary, parent: Node3D, o: Dictionary) -> void:
	var door: Door = DoorScript.new()
	door.name = "Door_" + d.id
	door.width = DOOR_W
	var dir: Vector2 = o.get("axis_dir", Vector2.RIGHT)
	var at: Vector2 = o.get("wall_at", o.at)
	door.position = Vector3(at.x, FLOOR_Y, at.y)
	door.rotation.y = -atan2(dir.y, dir.x)
	parent.add_child(door)
	door.setup(d, d.get("leaf", "door-type-a"))

func _glass(o: Dictionary, parent: Node3D, kit: MeshKit) -> void:
	var w: Dictionary = o.window
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.35, 0.45, 0.5, 0.22)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(float(w.width), o.y1 - o.y0)
	mi.mesh = q
	mi.material_override = m
	var at: Vector2 = o.get("wall_at", o.at)
	mi.position = Vector3(at.x, (o.y0 + o.y1) * 0.5, at.y)
	parent.add_child(mi)
	var mi2 := mi.duplicate() as MeshInstance3D
	mi2.rotation_degrees.y = 180
	parent.add_child(mi2)
	kit.boxes.append([Vector3(at.x, (o.y0 + o.y1) * 0.5, at.y), Vector3(float(w.width), o.y1 - o.y0, 0.06)])

## Upper-floor windows (some lit), fire escapes, awnings and the sign: all on the street face
## (local -z), so props there turn 180° to face out.
func _facade_dressing(b: Dictionary, node: Node3D, W: float, H: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(b.id)
	var boarded: bool = b.get("boarded", false)
	var lit_colors := [Color(1.0, 0.8, 0.45), Color(0.9, 0.95, 1.0), Color(1.0, 0.6, 0.35), Color(0.6, 0.7, 1.0)]
	for f in range(1, int(b.floors)):
		var y := FLOOR_Y + f * STOREY + 0.7
		var n := int(W / 3.2)
		for i in n:
			var x := (i + 0.5) * W / n
			if b.get("fire_escape", false) and absf(x - W * 0.5) < 1.7:
				continue
			var kinds := ["window-wide-type-a", "window-wide-type-b", "window-small-type-a", "window-small-type-b"]
			var win := Assets.prop(kinds[(hash(b.id) + f * 7 + i * 3) % kinds.size()] if (i + f) % 3 else kinds[2 + (f % 2)])
			win.position = Vector3(x, y, -0.02)
			win.rotation_degrees.y = 0
			node.add_child(win)
			if not boarded and rng.randf() < 0.45:
				var glow := MeshInstance3D.new()
				var q := QuadMesh.new()
				var sz: Vector3 = win.get_meta("size")
				q.size = Vector2(sz.x * 0.78, sz.y * 0.75)
				glow.mesh = q
				var c: Color = lit_colors[rng.randi() % lit_colors.size()]
				glow.material_override = Assets.surface("", 1.0, Color.BLACK, c * rng.randf_range(0.5, 0.9))
				glow.position = Vector3(x, y + sz.y * 0.5, -0.09)
				glow.rotation_degrees.y = 180
				node.add_child(glow)
			elif boarded:
				var pl := Assets.prop("planks")
				pl.position = Vector3(x, y + 0.3, -0.12)
				pl.rotation_degrees = Vector3(90, 0, 15)
				node.add_child(pl)
	if b.get("fire_escape", false):
		for f in range(1, int(b.floors)):
			var bal := Assets.prop("balcony-type-a")
			bal.position = Vector3(W * 0.5, FLOOR_Y + f * STOREY, -0.45)
			bal.rotation_degrees.y = 0
			node.add_child(bal)
			var lad := Assets.prop("balcony-ladder-bottom")
			lad.position = Vector3(W * 0.5 + 0.8, FLOOR_Y + (f - 1) * STOREY + (0.0 if f > 1 else 0.9), -0.45)
			lad.rotation_degrees.y = 0
			if f > 1:
				node.add_child(lad)
	if not b.get("solid", false):
		for d in b.get("doors", []):
			if absf(float(d.at[1])) < 0.01 and b.id in ["diner", "bar", "pawn", "bodega", "club"]:
				var aw := Assets.prop("detail-awning-wide")
				aw.position = Vector3(d.at[0], FLOOR_Y + 2.35, -0.5)
				aw.rotation_degrees.y = 0
				node.add_child(aw)
	if b.has("sign"):
		var s: Dictionary = b.sign
		var label := Label3D.new()
		label.text = s.text
		label.font_size = 64
		label.outline_size = 0
		label.pixel_size = 0.012 * float(s.get("size", 1.0))
		label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		label.shaded = false
		label.double_sided = false
		var col := Color(s.color[0], s.color[1], s.color[2])
		label.modulate = col * (0.45 if s.get("dead", false) else 1.0)
		label.position = Vector3(s.at[0], FLOOR_Y + s.at[1], -0.06)
		label.rotation_degrees.y = 180
		node.add_child(label)
		if not s.get("dead", false):
			var glow := _light(node.transform * label.position + node.transform.basis * Vector3(0, 0, -1.0), col, 5.0, 0.8)
			add_child(glow)

# ------------------------------------------------------------------ helpers

## A prop from the registry; "repeat": n and "step": [dx, dz] lay out a run of them (counters).
func _prop(p: Dictionary, parent: Node3D, base: Vector3) -> void:
	if p.has("repeat"):
		var one := p.duplicate()
		one.erase("repeat")
		for i in int(p.repeat):
			one.at = [float(p.at[0]) + float(p.step[0]) * i, float(p.at[1]) + float(p.step[1]) * i]
			_prop(one, parent, base)
		return
	if not Assets.has_prop(p.id):
		push_warning("prop not in registry: " + p.id)
		return
	var n := Assets.prop(p.id)
	var ground := FLOOR_Y if parent == self and absf(float(p.at[1])) > 5.0 else 0.0
	n.position = base + Vector3(p.at[0], p.get("y", 0.0) + ground, p.at[1])
	n.rotation_degrees.y = p.get("yaw", 0.0)
	if p.has("scale"):
		n.scale = Vector3.ONE * (float(p.scale) / 3.2)
	parent.add_child(n)

func _place(p: Dictionary, xf: Transform3D, base: Vector3, rot := 0.0) -> void:
	var local := base + Vector3(p.at[0], 0, p.at[1])
	if xf == Transform3D.IDENTITY and absf(float(p.at[1])) > 5.0:
		local.y = FLOOR_Y
	var pos := xf * local
	World.add_place({"id": p.id, "pos": pos, "yaw": fposmod(float(p.yaw) + rot, 360.0), "room": World.room_at(pos + Vector3.UP * 0.5),
		"pose": p.pose, "tags": p.tags})

func _light(pos: Vector3, color: Color, range_m: float, energy: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.omni_range = range_m
	l.light_energy = energy
	l.omni_attenuation = 1.2
	l.shadow_enabled = false
	l.light_specular = 0.0
	return l

func _add_kit(kit: MeshKit, parent: Node3D, name: String) -> void:
	var mi := kit.build(name)
	if mi:
		parent.add_child(mi)
	if not kit.boxes.is_empty():
		var body := kit.build_body()
		body.name = name + "Body"
		parent.add_child(body)

func _bake() -> void:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.agent_radius = 0.25
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.filter_baking_aabb = AABB(Vector3(-50, -1, -32), Vector3(100, 6, 64))
	navigation_mesh = nm
	bake_navigation_mesh(false)
