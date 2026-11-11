class_name Level
extends Node3D
## Builds a level from layout data. Flat 47, its Backrooms and Flat 48 are all layouts fed through
## this one builder and the one Kit, which is what makes the Backrooms recognisably the same flat:
## same pieces, same textures, rearranged and altered.
##
## Layout:
##  rooms:    {id: {rect: [x0, z0, x1, z1], y, h, floor, wall, ceiling, lights: [...], circuit,
##             acoustics: {size, damp, wet}, ambience, surface, alter: {wrong, mould, tint},
##             open: ["n"...] (sides with no wall: balconies), no_ceiling, ambient: [r, g, b]}}
##  openings: [{p: [x, z], axis: "x"|"z", w, h, sill, door: {...} | null, window: "night"|"void"|...}]
##            door: {id, style, swing, locked, key, bolt: side, chain: side, jammed, padlock: key tag, open}
##  furniture:[Kit defs]
##  circuits: {A: {live, fuse}}
##  spawns:   {name: [x, y, z, yaw_degrees]}
##  triggers: [{id, p: [x, y, z], size: [x, y, z], once}]
##  seams:    [{a: [x, y, z], b: [x, y, z], size: [x, y, z], yaw: deg}]   (teleport loops)
##  hazards:  [{type: "water", rect: [...], circuit}]

signal trigger_entered(id: String)
signal room_entered(room: String)

const T := 0.06               # half the thickness of an interior wall

var data := {}
var rooms := {}
var doors := {}
var power: Power
var nav := NavGrid.new()
var hides: Array = []
var breakables: Array = []
var spawns := {}
var player: Node = null
var current_room := ""
var level_name := ""
var _dyn: Node3D
var _openings: Array = []
var _flicker_t := 0.0
var _hazards: Array = []

func dynamic_root() -> Node3D:
	return _dyn

func room_mb(r: String) -> MB:
	return rooms[r].mb if rooms.has(r) else MB.new()

func room_body(r: String) -> StaticBody3D:
	return rooms[r].body

func room_floor(r: String) -> float:
	return float(rooms[r].y) if rooms.has(r) else 0.0

func room_alter(r: String) -> Dictionary:
	return rooms[r].alter if rooms.has(r) else {}

func room_center(r: String) -> Vector3:
	if not rooms.has(r):
		return Vector3.ZERO
	var rc: Rect2 = rooms[r].rect
	return Vector3(rc.get_center().x, float(rooms[r].y) + 1.2, rc.get_center().y)

func room_at(pos: Vector3) -> String:
	var best := ""
	for id in rooms:
		var r: Dictionary = rooms[id]
		if (r.rect as Rect2).grow(0.05).has_point(Vector2(pos.x, pos.z)) and pos.y > r.y - 0.5 and pos.y < r.y + r.h + 0.5:
			best = id
	return best

func register_hide(h: Node) -> void:
	hides.append(h)

func register_breakable(b: Node) -> void:
	breakables.append(b)

func block_rect(xf: Transform3D, c: Vector3, h: Vector3) -> void:
	# axis-aligned bounds of the rotated rectangle, inflated by the agent's radius
	var pts := [xf * (c + Vector3(-h.x, 0, -h.z)), xf * (c + Vector3(h.x, 0, -h.z)), xf * (c + Vector3(h.x, 0, h.z)), xf * (c + Vector3(-h.x, 0, h.z))]
	var r := Rect2(Vector2(pts[0].x, pts[0].z), Vector2.ZERO)
	for p in pts:
		r = r.expand(Vector2(p.x, p.z))
	nav.add_block(r.grow(0.22))

# ---------------------------------------------------------------------------------- light

## the baked light at a point (full power): the room's fixtures + its ambient, with corners darker
func bake(room: String, pos: Vector3, n: Vector3) -> Color:
	if not rooms.has(room):
		return Color(0.05, 0.05, 0.05)
	var r: Dictionary = rooms[room]
	var amb: Array = r.get("ambient", [0.03, 0.03, 0.035])
	var c := Color(amb[0], amb[1], amb[2])
	for l in r.lights:
		var lp := Vector3(l.p[0], l.p[1], l.p[2])
		var d := pos.distance_to(lp)
		var rng := float(l.get("r", 5.0))
		if d >= rng:
			continue
		var att := pow(1.0 - d / rng, 2.0)
		var lam := maxf(0.0, n.dot((lp - pos).normalized())) * 0.7 + 0.3
		var col := Color(String(l.get("c", "#ffd9a8")))
		var e := float(l.get("e", 1.0))
		c += col * (att * lam * e)
	# contact darkening: low and near walls
	var rc: Rect2 = r.rect
	var dx := minf(pos.x - rc.position.x, rc.end.x - pos.x)
	var dz := minf(pos.z - rc.position.y, rc.end.y - pos.z)
	var dw := minf(dx, dz)
	var yh := pos.y - float(r.y)
	var ao := clampf(minf(dw * 2.0, 1.0) * 0.4 + clampf(yh * 1.5, 0.0, 1.0) * 0.35 + 0.25, 0.25, 1.0)
	if dw < 0.12 and yh < 0.12:
		ao *= 0.6
	return Color(c.r * ao, c.g * ao, c.b * ao)

## what a prop or a dynamic thing should be lit with right now (power applied)
func light_at(pos: Vector3, n := Vector3.UP) -> Color:
	var room := room_at(pos)
	if room == "":
		return Color(0.04, 0.04, 0.045)
	var c := bake(room, pos, n)
	var k := float(rooms[room].mats.power)
	var amb: Array = rooms[room].get("ambient", [0.03, 0.03, 0.035])
	return Color(amb[0], amb[1], amb[2]).lerp(c, k)

## 0..1 how visible something standing here is (for the AI's sight): lit rooms, near fixtures
func brightness_at(pos: Vector3) -> float:
	var c := light_at(pos + Vector3(0, 1.0, 0))
	return clampf((c.r + c.g + c.b) / 1.2, 0.0, 1.0)

# ---------------------------------------------------------------------------------- build

func build(p_data: Dictionary, p_name := "") -> void:
	data = p_data
	level_name = p_name
	_dyn = Node3D.new(); _dyn.name = "Dynamic"; add_child(_dyn)
	power = Power.new(); power.name = "Power"; power.level = self; add_child(power)
	for c in data.get("circuits", {}):
		var cd: Dictionary = data.circuits[c]
		power.add_circuit(c, cd.get("live", true), cd.get("fuse", true))
	for id in data.rooms:
		_init_room(id, data.rooms[id])
	_openings = data.get("openings", [])
	for id in rooms:
		_room_shell(id)
	for o in _openings:
		_opening(o)
	for f in data.get("furniture", []):
		Kit.place(self, f)
	for id in rooms:
		_commit_room(id)
	for id in rooms:
		var r: Dictionary = rooms[id]
		nav.add_room(id, r.rect, r.y)
	for o in _openings:
		_nav_opening(o)
	for s in data.get("seams", []):
		_seam(s)
	for sp in data.get("spawns", {}):
		var a: Array = data.spawns[sp]
		spawns[sp] = Transform3D(Basis(Vector3.UP, deg_to_rad(float(a[3]) if a.size() > 3 else 0.0)), Vector3(a[0], a[1], a[2]))
	for t in data.get("triggers", []):
		var tr := Fixtures.Trigger.box(String(t.id), Vector3(t.p[0], t.p[1], t.p[2]), Vector3(t.size[0], t.size[1], t.size[2]))
		tr.once = t.get("once", false)
		add_child(tr)
		tr.entered.connect(func(x): trigger_entered.emit(x.trigger_id))
	_hazards = data.get("hazards", [])
	refresh_power()
	_environment()

func _init_room(id: String, d: Dictionary) -> void:
	var rr: Array = d.rect
	var rect := Rect2(Vector2(rr[0], rr[1]), Vector2(float(rr[2]) - float(rr[0]), float(rr[3]) - float(rr[1])))
	var alter: Dictionary = d.get("alter", {})
	var body := StaticBody3D.new(); body.name = "Room_" + id; body.collision_layer = 1; body.collision_mask = 0
	add_child(body)
	rooms[id] = {
		"rect": rect, "y": float(d.get("y", 0.0)), "h": float(d.get("h", 2.6)),
		"floor": d.get("floor", "parquet"), "wall": d.get("wall", "plaster"), "ceiling": d.get("ceiling", "ceiling"),
		"lights": d.get("lights", []), "mats": Mats.RoomMats.new(alter), "mb": MB.new(), "body": body,
		"alter": alter, "acoustics": d.get("acoustics", {"size": 0.3, "damp": 0.6, "wet": 0.15}),
		"ambience": d.get("ambience", ""), "surface": d.get("surface", "wood"), "open": d.get("open", []),
		"no_ceiling": d.get("no_ceiling", false), "ambient": d.get("ambient", [0.03, 0.03, 0.035]),
		"skirting": d.get("skirting", true),
	}
	if d.has("circuit"):
		power.room_circuit[id] = String(d.circuit)
		power.room_switch[id] = bool(d.get("switch_on", true))
	if d.has("flicker"):
		power.flicker[id] = float(d.flicker)

## walls (with their openings cut out), floor and ceiling
func _room_shell(id: String) -> void:
	var r: Dictionary = rooms[id]
	var rc: Rect2 = r.rect
	var y0: float = r.y
	var H: float = r.h
	var mb: MB = r.mb
	var x0 := rc.position.x; var z0 := rc.position.y; var x1 := rc.end.x; var z1 := rc.end.y
	var fl: String = r.floor
	# floor, ceiling
	mb.plane(fl, Vector3(x0, y0, z1), Vector3(x1 - x0, 0, 0), Vector3(0, 0, -(z1 - z0)), Vector3.UP, Mats.uvm(fl), 0.7, Vector2(x0, -z1) / Mats.uvm(fl))
	if not r.no_ceiling:
		mb.plane(r.ceiling, Vector3(x0, y0 + H, z0), Vector3(x1 - x0, 0, 0), Vector3(0, 0, z1 - z0), Vector3.DOWN, Mats.uvm(r.ceiling), 0.9)
	_col_box(r.body, Vector3((x0 + x1) * 0.5, y0 - 0.1, (z0 + z1) * 0.5), Vector3((x1 - x0) * 0.5 + 0.1, 0.1, (z1 - z0) * 0.5 + 0.1))
	# four walls: [side, line coord, run axis, run min, run max, inward normal]
	var sides := [
		["n", z0, "x", x0, x1, Vector3(0, 0, 1)],
		["s", z1, "x", x0, x1, Vector3(0, 0, -1)],
		["w", x0, "z", z0, z1, Vector3(1, 0, 0)],
		["e", x1, "z", z0, z1, Vector3(-1, 0, 0)],
	]
	for sd in sides:
		if sd[0] in r.open:
			continue
		_wall(id, sd[1], sd[2], sd[3], sd[4], sd[5])
	# fixtures (the light sources themselves)
	for l in r.lights:
		var lp := Vector3(l.p[0], l.p[1], l.p[2])
		match String(l.get("fix", "bulb")):
			"bulb":
				mb.cyl("rubber", lp + Vector3(0, 0.05, 0), 0.005, y0 + H - lp.y - 0.05, 4, -1.0, false)
				mb.cyl("bulb", lp - Vector3(0, 0.05, 0), 0.04, 0.1, 6)
			"tube":
				mb.box("bulb", lp, Vector3(0.6, 0.02, 0.03))
				mb.box("metal", lp + Vector3(0, 0.04, 0), Vector3(0.62, 0.02, 0.05))
			"shade":
				mb.cyl("rubber", lp + Vector3(0, 0.2, 0), 0.005, y0 + H - lp.y - 0.2, 4, -1.0, false)
				mb.cyl("fabric_bed", lp, 0.22, 0.2, 8, 0.1, false)
				mb.cyl("bulb", lp - Vector3(0, 0.02, 0), 0.035, 0.08, 6)

func _holes_on(axis: String, coord: float, rmin: float, rmax: float) -> Array:
	var out := []
	for o in _openings:
		if String(o.get("axis", "x")) != axis:
			continue
		var p: Array = o.p
		var line := float(p[1]) if axis == "x" else float(p[0])
		var along := float(p[0]) if axis == "x" else float(p[1])
		if absf(line - coord) > 0.2:
			continue
		var w := float(o.get("w", 0.9))
		if along + w * 0.5 < rmin or along - w * 0.5 > rmax:
			continue
		var sill := float(o.get("sill", 0.0))
		out.append({"a": along - w * 0.5, "b": along + w * 0.5, "y0": sill, "y1": sill + float(o.get("h", 2.05)), "o": o})
	out.sort_custom(func(a, b): return a.a < b.a)
	return out

## does any room lie on the other side of this wall line at `along`?
func _room_beyond(id: String, axis: String, coord: float, along: float, normal: Vector3) -> String:
	var probe := Vector3(along, 0, coord) if axis == "x" else Vector3(coord, 0, along)
	probe -= normal * 0.2
	for oid in rooms:
		if oid == id:
			continue
		if (rooms[oid].rect as Rect2).has_point(Vector2(probe.x, probe.z)):
			return oid
	return ""

func _wall(id: String, coord: float, axis: String, rmin: float, rmax: float, n: Vector3) -> void:
	var r: Dictionary = rooms[id]
	var mb: MB = r.mb
	var y0: float = r.y
	var H: float = r.h
	var style: String = r.wall
	var uvm := Mats.uvm(style)
	var face := coord + T * (n.z if axis == "x" else n.x)
	var a0 := rmin + T
	var a1 := rmax - T
	var holes := _holes_on(axis, coord, rmin, rmax)
	var run := Vector3(1, 0, 0) if axis == "x" else Vector3(0, 0, 1)
	var exterior_any := false
	var segs := []      # [a, b, ylo, yhi]
	var cur := a0
	for h in holes:
		var ha := maxf(float(h.a), a0); var hb := minf(float(h.b), a1)
		if ha > cur:
			segs.append([cur, ha, 0.0, H])
		if float(h.y0) > 0.0:
			segs.append([ha, hb, 0.0, float(h.y0)])
		if float(h.y1) < H:
			segs.append([ha, hb, float(h.y1), H])
		cur = maxf(cur, hb)
		# jambs: the wall's thickness, seen in the opening
		var beyond := _room_beyond(id, axis, coord, (ha + hb) * 0.5, n)
		var depth := T if beyond != "" else T + 0.25
		if beyond == "":
			exterior_any = true
		for side in [[ha, 1.0], [hb, -1.0]]:
			var at := float(side[0])
			var jn: Vector3 = run * float(side[1])
			var o := _pt(axis, at, face, y0 + float(h.y0))
			mb.plane(style, o, -n * depth, Vector3(0, float(h.y1) - float(h.y0), 0), jn, uvm, 2.0)
		var lo := _pt(axis, ha, face, y0 + float(h.y1))
		mb.plane(style, lo, run * (hb - ha), -n * depth, Vector3.DOWN, uvm, 2.0)
		if float(h.y0) > 0.0:
			var so := _pt(axis, ha, face, y0 + float(h.y0))
			mb.plane("wood_light", so, run * (hb - ha), -n * depth, Vector3.UP, 0.5, 2.0)
		else:
			# threshold: floor across the wall's thickness
			var to := _pt(axis, ha, face, y0 + 0.002)
			mb.plane(String(r.floor), to, run * (hb - ha), -n * depth, Vector3.UP, Mats.uvm(String(r.floor)), 2.0)
		# windows: glass (or what's beyond) at the boundary
		var win := String(h.o.get("window", ""))
		if win != "":
			var go := _pt(axis, ha, coord, y0 + float(h.y0))
			var gstyle := "glass" if win == "night" else ("void" if win == "void" else "black")
			mb.plane(gstyle, go, run * (hb - ha), Vector3(0, float(h.y1) - float(h.y0), 0), n, hb - ha, 2.0)
			_col_box(r.body, _pt(axis, (ha + hb) * 0.5, coord, y0 + (float(h.y0) + float(h.y1)) * 0.5), _half(axis, (hb - ha) * 0.5, (float(h.y1) - float(h.y0)) * 0.5, 0.05))
			# frame cross
			mb.box("wood_light", _pt(axis, (ha + hb) * 0.5, face - (n.z if axis == "x" else n.x) * 0.02, y0 + (float(h.y0) + float(h.y1)) * 0.5), _half(axis, 0.02, (float(h.y1) - float(h.y0)) * 0.5, 0.02))
	if cur < a1:
		segs.append([cur, a1, 0.0, H])
	for s in segs:
		var sa := float(s[0]); var sb := float(s[1]); var ylo := float(s[2]); var yhi := float(s[3])
		if sb - sa < 0.005 or yhi - ylo < 0.005:
			continue
		var o := _pt(axis, sa, face, y0 + ylo)
		mb.plane(style, o, run * (sb - sa), Vector3(0, yhi - ylo, 0), n, uvm, 0.65, Vector2(sa / uvm, -ylo / uvm))
		if ylo == 0.0 and r.skirting:
			var so := _pt(axis, sa, face + (n.z if axis == "x" else n.x) * 0.012, y0)
			mb.plane("wood_dark", so, run * (sb - sa), Vector3(0, 0.08, 0), n, 0.5, 2.0)
		# collision: centred on the boundary line (interior), thicker outward on exterior walls
		var mid := (sa + sb) * 0.5
		var beyond := _room_beyond(id, axis, coord, mid, n)
		var thick := T if beyond != "" else 0.3
		var cc := _pt(axis, mid, coord - (0.0 if beyond != "" else (thick - T)) * (n.z if axis == "x" else n.x), y0 + (ylo + yhi) * 0.5)
		_col_box(r.body, cc, _half(axis, (sb - sa) * 0.5, (yhi - ylo) * 0.5, thick))
		# occluder for big solid stretches
		if sb - sa > 1.2 and ylo == 0.0 and yhi >= H - 0.01:
			var oc := OccluderInstance3D.new()
			var q := QuadOccluder3D.new(); q.size = Vector2(sb - sa, H)
			oc.occluder = q
			add_child(oc)
			oc.global_position = _pt(axis, mid, coord, y0 + H * 0.5)
			oc.rotation.y = 0.0 if axis == "x" else PI * 0.5

func _pt(axis: String, along: float, across: float, y: float) -> Vector3:
	return Vector3(along, y, across) if axis == "x" else Vector3(across, y, along)

func _half(axis: String, along: float, up: float, across: float) -> Vector3:
	return Vector3(along, up, across) if axis == "x" else Vector3(across, up, along)

func _col_box(body: StaticBody3D, c: Vector3, h: Vector3) -> void:
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = h * 2.0
	cs.shape = bs; cs.position = c - body.position
	body.add_child(cs)

## doors in openings
func _opening(o: Dictionary) -> void:
	var dd = o.get("door")
	if not (dd is Dictionary):
		return
	var axis := String(o.get("axis", "x"))
	var p: Array = o.p
	var y := float(o.get("y", 0.0))
	var room := room_at(Vector3(p[0], y + 1.0, p[1]) + (Vector3(0, 0, 0.2) if axis == "x" else Vector3(0.2, 0, 0)))
	if room != "":
		y = float(rooms[room].y)
	var d := Door.new()
	d.name = "Door_" + String(dd.get("id", "door"))
	d.door_id = String(dd.get("id", ""))
	d.width = float(o.get("w", 0.9)) - 0.04
	d.height = float(o.get("h", 2.05)) - 0.02
	d.style = String(dd.get("style", "door_panel"))
	d.swing = float(dd.get("swing", 1.0))
	d.thickness = 0.05
	add_child(d)
	d.global_transform = Transform3D(Basis.IDENTITY if axis == "x" else Basis(Vector3.UP, -PI * 0.5), Vector3(p[0], y, p[1]))
	var lr := room_at(d.global_position + d.global_transform.basis.z * 0.3 + Vector3(0, 1, 0))
	d.build(light_at(d.global_position + Vector3(0, 1.2, 0)) if lr == "" else bake(lr, d.global_position + Vector3(0, 1.2, 0), Vector3.UP), room_alter(lr))
	d.locked = dd.get("locked", false)
	d.key_tag = String(dd.get("key", ""))
	d.pickable = dd.get("pickable", true)
	d.bolt_side = int(dd.get("bolt", 0)); d.bolt_on = dd.get("bolt_on", false)
	d.chain_side = int(dd.get("chain", 0)); d.chain_on = dd.get("chain_on", false)
	d.jammed = String(dd.get("jammed", ""))
	if dd.has("padlock"):
		var pl := Fixtures.Padlock.new(); pl.name = "Padlock"; pl.key_tag = String(dd.padlock); pl.door = d; pl.lock_id = d.door_id
		var side := float(dd.get("padlock_side", 1.0))
		d.add_child(pl)
		pl.position = Vector3(d.width * 0.5 - 0.05, 1.05, side * 0.07)
		var mb := MB.new()
		mb.box("chrome", Vector3(0, 0.0, 0), Vector3(0.03, 0.035, 0.012))
		mb.box("chrome", Vector3(0, 0.05, 0), Vector3(0.022, 0.018, 0.004))
		mb.box("metal", Vector3(-0.06, 0.05, -side * 0.02), Vector3(0.07, 0.015, 0.006))      # hasp
		var mi := MeshInstance3D.new(); mi.mesh = mb.commit({"chrome": Mats.flat("brass", Color(0.4, 0.4, 0.4)), "metal": Mats.flat("metal", Color(0.4, 0.4, 0.4))})
		pl.add_child(mi)
		var b := StaticBody3D.new(); b.collision_layer = 32 | 1
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(0.12, 0.14, 0.06); cs.shape = bs
		b.add_child(cs); pl.add_child(b); pl.body = b
		Hook.attach(b, pl, "Padlock", "padlock_" + d.door_id)
		d.padlock = pl
	if dd.get("open", 0.0) > 0.0:
		d.open_instant(float(dd.open))
	doors[d.door_id] = d
	o["_door"] = d
	d.state_changed.connect(_door_changed)

func _door_changed(d: Door) -> void:
	# she opens ordinary doors herself; a secured one is closed to her route (she may pound it)
	nav.set_door_passable(d, not ai_secured(d))

func ai_secured(d: Door) -> bool:
	if d.broken:
		return false
	return d.jammed != "" or d.locked or d.bolt_on or d.chain_on or (d.padlock != null and d.padlock.is_locked())

func _nav_opening(o: Dictionary) -> void:
	if o.get("window", "") != "" or float(o.get("sill", 0.0)) > 0.3:
		return
	var axis := String(o.get("axis", "x"))
	var p: Array = o.p
	var c := Vector3(p[0], 0, p[1])
	var n := Vector3(0, 0, 1) if axis == "x" else Vector3(1, 0, 0)
	var ra := room_at(c - n * 0.4 + Vector3(0, 1, 0))
	var rb := room_at(c + n * 0.4 + Vector3(0, 1, 0))
	if ra == "" or rb == "" or o.get("ai", true) == false:
		return
	c.y = float(rooms[ra].y)
	var d: Door = o.get("_door")
	nav.add_opening(c, n, ra, rb, d)
	if d:
		_door_changed(d)

func _commit_room(id: String) -> void:
	var r: Dictionary = rooms[id]
	var mb: MB = r.mb
	var mats: Mats.RoomMats = r.mats
	var mesh := mb.commit(mats.dict_for(mb), func(pos, n): return bake(id, pos, n))
	var mi := MeshInstance3D.new(); mi.name = "Mesh_" + id; mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 40.0
	add_child(mi)
	r["mi"] = mi
	# the room's own tracker: acoustics, ambience, footsteps
	var tr := Fixtures.Trigger.box("room:" + id, Vector3(r.rect.get_center().x, r.y + r.h * 0.5, r.rect.get_center().y), Vector3(r.rect.size.x - 0.05, r.h, r.rect.size.y - 0.05))
	add_child(tr)
	tr.entered.connect(func(_t): _enter_room(id))

func _enter_room(id: String) -> void:
	if current_room == id:
		return
	current_room = id
	var r: Dictionary = rooms[id]
	Sfx.set_room(r.acoustics)
	if String(r.ambience) != "":
		Sfx.set_ambience(String(r.ambience))
	room_entered.emit(id)

func _seam(s: Dictionary) -> void:
	var a := Vector3(s.a[0], s.a[1], s.a[2]); var b := Vector3(s.b[0], s.b[1], s.b[2])
	nav.seam(a, b)
	var sz: Array = s.get("size", [1.6, 2.4, 0.4])
	var tr := Fixtures.Trigger.box("seam", a + Vector3(0, 1.2, 0), Vector3(sz[0], sz[1], sz[2]))
	add_child(tr)
	var off := b - a
	tr.entered.connect(func(_t):
		if player and not player.get("teleport_lock"):
			player.teleport_by(off, deg_to_rad(float(s.get("yaw", 0.0)))))

func refresh_power() -> void:
	for id in rooms:
		var lit := power.room_lit(id)
		(rooms[id].mats as Mats.RoomMats).set_power(1.0 if lit else 0.0)
	for p in get_tree().get_nodes_in_group("props"):
		if is_ancestor_of(p):
			p.relight()

func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0, 0, 0)
	env.ambient_light_energy = 0.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.0, 0.0, 0.0)
	env.fog_depth_begin = float(data.get("fog_begin", 4.0))
	env.fog_depth_end = float(data.get("fog_end", 16.0))
	env.fog_density = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	add_child(we)

func _process(delta: float) -> void:
	_flicker_t += delta
	for id in power.flicker:
		if not power.room_lit(id):
			continue
		var k := float(power.flicker[id])
		var f := 1.0
		var n := sin(_flicker_t * 13.0 + id.hash()) * sin(_flicker_t * 7.3) + sin(_flicker_t * 31.0)
		if n > 1.2 - k:
			f = randf_range(0.1, 0.6)
		(rooms[id].mats as Mats.RoomMats).set_power(f)

func _physics_process(_delta: float) -> void:
	# live hazards: water on a live circuit
	for hz in _hazards:
		if not power.is_live(String(hz.get("circuit", ""))):
			continue
		var rr: Array = hz.rect
		var rect := Rect2(Vector2(rr[0], rr[1]), Vector2(float(rr[2]) - float(rr[0]), float(rr[3]) - float(rr[1])))
		for b in get_tree().get_nodes_in_group("shockable"):
			var pos: Vector3 = b.global_position
			if rect.has_point(Vector2(pos.x, pos.z)) and b.has_method("shock"):
				b.shock(hz)

## a prop wants a behaviour started once it's in the tree (radio on at load, etc.)
func prop_ready(p: Prop, what: String) -> void:
	if p.behaviour:
		match what:
			"radio_on": p.behaviour.set_on(true)

func persist_nodes() -> Array:
	return get_tree().get_nodes_in_group("persist")
