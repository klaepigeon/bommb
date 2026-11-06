class_name WorldView
extends Node3D
## Everything off the hall, built from the Building: the rooms (shell + furniture + lamp), the
## stair down to the cellar, the back corridor, the doors (real leaves on hinges), and the
## things you can pick up or use. Each area renders on its own layer and its lamp lights only
## that layer, so a lamp in the kitchen doesn't glow through the hall wall. Areas you can't
## see into are hidden.

var b: Building
var hall: Hall
var area_nodes: Dictionary = {}   # area id -> Node3D
var sconces: Array = []           # [node, area a, area b]: lit only while either side is in view
var area_lights: Dictionary = {}  # area id -> Array of Light3D
var doors: Dictionary = {}        # portal id -> DoorLeaf
var thing_nodes: Dictionary = {}  # thing id -> Node3D
var layer_of: Dictionary = {}     # area id -> layer bit
var padlocks: Dictionary = {}     # portal id -> Padlock
var _flicker: Dictionary = {}     # area id -> seconds left
var _t := 0.0

func setup(h: Hall, building: Building) -> void:
	hall = h
	b = building
	var bit := 1
	for id in b.area_order:
		if id == "hall":
			layer_of[id] = 1
		else:
			layer_of[id] = 1 << bit
			bit = mini(bit + 1, 18)
			# bit 17 is the sharp overlay (Stage.SHARP_LAYER): an area on it would draw over everything
			if (1 << bit) == Stage.SHARP_LAYER:
				bit += 1
	for id in b.area_order:
		if id != "hall":
			_build_area(id)
	for pid in b.portals.keys():
		_build_door(b.portals[pid])
	for t in b.things.values():
		_build_thing(t)
	for w in b.windows:
		_build_window(w)
	# the hall's own lights stay in the hall
	for l in _lights_under(hall):
		if not _is_ours(l):
			l.light_cull_mask = 1 | (1 << 19) | Stage.SHARP_LAYER
	show_from("hall")

func _is_ours(n: Node) -> bool:
	var p := n.get_parent()
	while p != null:
		if p == self:
			return true
		if p is CallerFigure:
			return true
		p = p.get_parent()
	return false

static func _lights_under(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is Light3D:
			out.append(c)
		out.append_array(_lights_under(c))
	return out

static func set_layers(n: Node, mask: int) -> void:
	if n is VisualInstance3D:
		n.layers = mask
	for c in n.get_children():
		set_layers(c, mask)

# ------------------------------------------------------------------ areas

func _style(a: Dictionary) -> Dictionary:
	var d: Dictionary = a["def"]
	return d.get("style", {})

func _build_area(id: String) -> void:
	var a: Dictionary = b.areas[id]
	var root := Node3D.new()
	root.name = "Area_" + id
	add_child(root)
	area_nodes[id] = root
	var st := _style(a)
	var seed := b.area_order.find(id) + 3
	var wall_c := Color(st.get("wall", "#5a5a50"))
	var floor_c := Color(st.get("floor", "#2a2420"))
	var wall_m := MB.mat(Tex.grime(wall_c.darkened(0.2), wall_c, 64, seed + 60, 0.06, 0.2), Color.WHITE)
	var floor_m := MB.mat(Tex.checker(floor_c, floor_c.lightened(0.15), 64, 8, seed + 3, 0.3) if st.get("tiles", false) else Tex.wood(floor_c, seed + 40, 64, 6), Color.WHITE)
	var ceil_m := MB.mat(Tex.ceiling(seed + 7))
	var mb := MB.new()
	var r: Rect2 = a["rect"]
	var height: float = a["height"]
	if a.has("slope"):
		_build_stairs(mb, a, wall_m, floor_m, ceil_m)
	else:
		# an outdoor area ("sky": true in its style) has walls round it but no ceiling
		ShellBuilder.floor_and_ceiling(mb, r, a["floor"], height, floor_m, null if st.get("sky", false) else ceil_m)
		ShellBuilder.walls(mb, b, id, wall_m, height)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	root.add_child(mi)
	if a.has("room"):
		var contents := RoomBuilder.build_contents(a["room"], b.area_order.find(id), a["xf"])
		root.add_child(contents)
	# a bare bulb on a flex in the middle of the ceiling
	var centre := Vector3(r.get_center().x, a["floor"] + height - 0.5, r.get_center().y)
	if a.has("slope"):
		centre.y = float(a["slope"]["y0"]) + 2.1
		centre.z = r.get_center().y + 0.4
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(st.get("light", a["def"].get("style", {}).get("light", "#e8d8b0")))
	lamp.light_energy = float(st.get("energy", 2.4))
	lamp.omni_range = maxf(r.size.x, r.size.y) * 1.3
	lamp.omni_attenuation = 0.8
	lamp.shadow_enabled = false
	lamp.position = centre
	root.add_child(lamp)
	var bulb := MB.new()
	bulb.sphere("b", MB.mat(Tex.solid(Color("fff2c8")), Color.WHITE, Vector2.ONE, true), 0.07, 3, 6, MB.T(centre + Vector3(0, 0.05, 0)), Color(1, 1, 1))
	bulb.box("c", MB.mat(Tex.solid(Color("1a1a1a"))), Vector3(0.01, 0.4, 0.01), MB.T(centre + Vector3(0, 0.3, 0)), Color(1, 1, 1))
	var bmi := MeshInstance3D.new()
	bmi.mesh = bulb.build()
	bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bmi.set_meta("bulb", true)
	root.add_child(bmi)
	area_lights[id] = [lamp]
	lamp.set_meta("energy", lamp.light_energy)
	if a.has("slope"):
		# a second bulb down at the bottom, where the switch is
		var low := OmniLight3D.new()
		low.light_color = lamp.light_color
		low.light_energy = 1.6
		low.omni_range = 4.0
		low.position = Vector3(r.get_center().x, float(a["slope"]["y1"]) + 2.0, r.position.y + 0.6)
		low.light_cull_mask = layer_of[id] | (1 << 19)
		low.set_meta("energy", 1.6)
		root.add_child(low)
		area_lights[id].append(low)
	set_layers(root, layer_of[id])
	lamp.light_cull_mask = layer_of[id] | (1 << 19)

## The cellar stair: a sloping shaft with treads, walls tall enough for the drop.
func _build_stairs(mb: MB, a: Dictionary, wall_m: Material, floor_m: Material, ceil_m: Material) -> void:
	var r: Rect2 = a["rect"]
	var s: Dictionary = a["slope"]
	var y0 := float(s["y0"])
	var y1 := float(s["y1"])
	var z_from := float(s["from"])
	var z_to := float(s["to"])
	var height: float = a["height"]
	# landing at the top and at the bottom
	ShellBuilder.floor_and_ceiling(mb, Rect2(r.position.x, z_from, r.size.x, r.end.y - z_from), y0, height, floor_m, null)
	ShellBuilder.floor_and_ceiling(mb, Rect2(r.position.x, r.position.y, r.size.x, z_to - r.position.y), y1, height, floor_m, null)
	# treads
	var steps := 14
	var tread_m := MB.mat(Tex.wood(Color("7a5a3a"), 81, 32, 2))
	for i in range(steps):
		var k0 := float(i) / steps
		var za := lerpf(z_from, z_to, k0)
		var zb := lerpf(z_from, z_to, float(i + 1) / steps)
		var y := lerpf(y0, y1, (k0 + 0.5 / steps))
		mb.box("t", tread_m, Vector3(r.size.x, 0.06, absf(zb - za) + 0.02), MB.T(Vector3(r.get_center().x, y, (za + zb) / 2)), Color(1, 1, 1))
		mb.box("t", tread_m, Vector3(r.size.x, absf(y1 - y0) / steps, 0.03), MB.T(Vector3(r.get_center().x, y - absf(y1 - y0) / steps / 2, zb)), Color(0.7, 0.7, 0.7))
	# a sloping ceiling, and the walls from the bottom landing to above the top
	var top := y0 + height
	mb.quad_uv("c", ceil_m, Vector3(r.position.x, top, r.position.y), Vector3(r.end.x, top, r.position.y), Vector3(r.end.x, top, r.end.y), Vector3(r.position.x, top, r.end.y), Color(0.6, 0.6, 0.6),
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 2), Vector2(0, 2))
	ShellBuilder.walls(mb, b, a["id"], wall_m, top - a["floor"], [0.8, 0.7, 0.65, 0.7], y1 - a["floor"])
	# a handrail down the left
	var rail := MB.mat(Tex.grime(Color("3a3a36"), Color("5a5a54"), 16, 82, 0.3))
	var p0 := Vector3(r.position.x + 0.08, y0 + 0.9, z_from)
	var p1 := Vector3(r.position.x + 0.08, y1 + 0.9, z_to)
	mb.box("r", rail, Vector3(0.04, 0.04, p0.distance_to(p1)), Transform3D(Basis.looking_at((p1 - p0).normalized(), Vector3.UP), (p0 + p1) / 2), Color(1, 1, 1))

# ------------------------------------------------------------------ doors and things

func _build_door(p: Dictionary) -> void:
	var la: int = layer_of.get(p["a"], 1)
	var lb: int = layer_of.get(p["b"], 0)
	var fy: float = b.floor_at(p["at"] - b.portal_dir(p) * 0.3, p["a"])
	var fm := MB.new()
	var frame_m := MB.mat(Tex.wood(Color("6a4a2e"), 62, 32, 2))
	ShellBuilder.frame(fm, p, frame_m, fy)
	var fmi := MeshInstance3D.new()
	fmi.mesh = fm.build()
	add_child(fmi)
	set_layers(fmi, la | lb)
	if p.get("kind", "door") == "arch":
		return
	var leaf := DoorLeaf.new()
	leaf.name = "Door_" + p["id"].replace(":", "_")
	add_child(leaf)
	leaf.setup(b, p, fy)
	set_layers(leaf, la | lb)
	doors[p["id"]] = leaf
	if p.get("beyond", "") == "bricks":
		_bricks(p, fy, la)
	if p.get("lock", {}).has("code"):
		var pl := Padlock.new()
		add_child(pl)
		var thing: Dictionary = b.things.get(p["lock"].get("thing", ""), {})
		var pos := b.thing_pos(thing) if not thing.is_empty() else Vector3(p["at"].x, fy + 1.1, p["at"].y)
		pl.setup(str(p["lock"]["code"]).length(), pos, -b.portal_dir(p))
		set_layers(pl, la)
		padlocks[p["id"]] = pl
	if p["a"] == "hall":
		_sconce(p, fy)
	# the sign over it
	var font: Font = load("res://assets/fonts/fell_sc.ttf")
	if p.get("label", "") != "" and p["a"] == "hall" and p.get("sign", "") != "exit":
		var l := Label3D.new()
		l.text = p["label"].to_upper()
		l.font = font
		l.font_size = 30
		l.pixel_size = 0.006
		l.modulate = Color("c8a888") if p.get("sign", "") != "exit" else Color("6ae08a")
		var d := -b.portal_dir(p)
		l.position = Vector3(p["at"].x, fy + 2.4, p["at"].y) + Vector3(d.x, 0, d.y) * 0.04
		l.rotation.y = atan2(d.x, d.y)
		l.double_sided = false
		l.shaded = false
		add_child(l)

## A small window between two areas: a dirty pane in a frame.
func _build_window(w: Dictionary) -> void:
	var at: Vector2 = w["at"]
	var fy: float = b.areas[w["area"]]["floor"]
	var sill := float(w["sill"])
	var head := float(w["head"])
	var width := float(w["width"])
	var axis_x: bool = false
	var r: Rect2 = b.areas[w["area"]]["rect"]
	if absf(at.x - r.position.x) < 0.05 or absf(at.x - r.end.x) < 0.05:
		axis_x = true
	var along := Vector3(0, 0, 1) if axis_x else Vector3(1, 0, 0)
	var across := Vector3(1, 0, 0) if axis_x else Vector3(0, 0, 1)
	var basis := Basis(along, Vector3.UP, across)
	var mb := MB.new()
	var frame_m := MB.mat(Tex.wood(Color("4a2e1c"), 87, 32, 2))
	var mid := Vector3(at.x, fy + (sill + head) / 2.0, at.y)
	var hh := (head - sill) / 2.0
	mb.box("f", frame_m, Vector3(width + 0.12, 0.06, 0.2), Transform3D(basis, mid + Vector3(0, hh + 0.03, 0)), Color(1, 1, 1))
	mb.box("f", frame_m, Vector3(width + 0.12, 0.06, 0.24), Transform3D(basis, mid - Vector3(0, hh + 0.03, 0)), Color(1, 1, 1))
	mb.box("f", frame_m, Vector3(0.06, head - sill, 0.2), Transform3D(basis, mid + along * (width / 2 + 0.03)), Color(1, 1, 1))
	mb.box("f", frame_m, Vector3(0.06, head - sill, 0.2), Transform3D(basis, mid - along * (width / 2 + 0.03)), Color(1, 1, 1))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	add_child(mi)
	var glass := StandardMaterial3D.new()
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.25, 0.28, 0.22, 0.45)
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gm := MB.new()
	gm.box("g", glass, Vector3(width, head - sill, 0.01), Transform3D(basis, mid), Color(1, 1, 1))
	var gmi := MeshInstance3D.new()
	gmi.mesh = gm.build()
	gmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gmi)
	var mask: int = layer_of.get(w["area"], 1) | layer_of.get(w.get("other", ""), 0)
	set_layers(mi, mask)
	set_layers(gmi, mask)

## A little wall lamp beside a door on the hall side, so you can find the doors in the dark.
func _sconce(p: Dictionary, fy: float) -> void:
	var d := -b.portal_dir(p)
	var along := Vector2(0, 1) if p["axis"] == "x" else Vector2(1, 0)
	var at: Vector2 = p["at"] + along * (p["width"] / 2.0 + 0.35) + d * 0.08
	var root := Node3D.new()
	root.position = Vector3(at.x, fy + 2.05, at.y)
	add_child(root)
	sconces.append([root, p["a"], p["b"]])
	var mb := MB.new()
	mb.box("b", MB.mat(Tex.brass()), Vector3(0.08, 0.12, 0.08), MB.T(), Color(1, 1, 1))
	mb.cyl("s", MB.mat(Tex.solid(Color("f0d8a0")), Color.WHITE, Vector2.ONE, true), 0.07, 0.04, 0.12, 6, MB.T(Vector3(0, 0.06, 0)), Color(1, 1, 1))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = Color("e8c890")
	l.light_energy = 0.9
	l.omni_range = 2.8
	l.omni_attenuation = 1.2
	l.position = Vector3(d.x * 0.2, 0.1, d.y * 0.2)
	l.light_cull_mask = 1 | (1 << 19)
	root.add_child(l)

func _bricks(p: Dictionary, fy: float, layer: int) -> void:
	var d := b.portal_dir(p)
	var at: Vector2 = p["at"] + d * 0.3
	var mb := MB.new()
	var brick := MB.mat(Tex.cached("bricks", func():
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in range(64):
			for x in range(64):
				var row := y / 8
				var off := 8 if row % 2 == 0 else 0
				var mortar := y % 8 == 0 or (x + off) % 16 == 0
				var c := Color("6a2a1e") if not mortar else Color("9a9488")
				c = c.lerp(Color("3a1a12"), Tex.fbm(x * 0.2, y * 0.2, 5) * 0.5)
				if mortar and Tex._h(x, y, 9) > 0.6:
					c = Color("b8b0a0")
				img.set_pixel(x, y, c)
		return img))
	var along := Vector3(0, 0, 1) if p["axis"] == "x" else Vector3(1, 0, 0)
	var across := Vector3(d.x, 0, d.y)
	mb.box("b", brick, Vector3(p["width"] + 0.4, p["height"] + 0.2, 0.25), Transform3D(Basis(along, Vector3.UP, across), Vector3(at.x, fy + p["height"] / 2, at.y)), Color(1, 1, 1), 1.6)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	add_child(mi)
	set_layers(mi, layer)

func _build_thing(t: Dictionary) -> void:
	var model: String = t.get("model", "")
	if model == "":
		return
	var pos := b.thing_pos(t)
	var aid: String = t.get("area", "hall")
	var root := Node3D.new()
	root.position = pos
	# face away from the nearest wall, into the room
	var r: Rect2 = b.areas[aid]["rect"]
	var p2 := Vector2(pos.x, pos.z)
	var dists := [p2.y - r.position.y, r.end.x - p2.x, r.end.y - p2.y, p2.x - r.position.x]
	var nearest := 0
	for i in range(4):
		if dists[i] < dists[nearest]:
			nearest = i
	root.rotation.y = [0.0, -PI / 2, PI, PI / 2][nearest]
	var mb := MB.new()
	var brass := MB.mat(Tex.brass())
	var iron := MB.mat(Tex.grime(Color("2a2a28"), Color("4a4a46"), 16, 84, 0.3))
	var paper := MB.mat(Tex.paper(Color("e0d4b0"), 85))
	match model:
		"keys":
			mb.box("h", iron, Vector3(0.03, 0.03, 0.06), MB.T(Vector3(0, 0.05, 0.03)), Color(1, 1, 1))
			mb.ring("k", iron, 0.05, 0.008, 10, MB.T(Vector3(0, 0.0, 0.05)), Color(1, 1, 1))
			mb.box("k", iron, Vector3(0.012, 0.16, 0.008), MB.T(Vector3(0.02, -0.11, 0.05), Vector3(0, 0, 0.15)), Color(1, 1, 1))
			mb.box("k", brass, Vector3(0.01, 0.08, 0.008), MB.T(Vector3(-0.03, -0.08, 0.055), Vector3(0, 0, -0.3)), Color(1, 1, 1))
			mb.box("k", brass, Vector3(0.01, 0.07, 0.008), MB.T(Vector3(0.0, -0.08, 0.06), Vector3(0, 0, 0.05)), Color(1, 1, 1))
		"note":
			mb.box("p", paper, Vector3(0.22, 0.16, 0.004), MB.T(Vector3(0, 0, 0.005), Vector3(0, 0, 0.06)), Color(1, 1, 1))
			var l := Label3D.new()
			l.text = "WE CLOSE AT"
			l.font = load("res://assets/fonts/special_elite.ttf")
			l.font_size = 22
			l.pixel_size = 0.0012
			l.modulate = Color("8a0e0a")
			l.position = Vector3(0, 0.01, 0.009)
			l.rotation.z = 0.06
			l.shaded = true
			l.double_sided = false
			root.add_child(l)
		"hooks":
			for i in range(7):
				mb.box("h", brass, Vector3(0.02, 0.06, 0.06), MB.T(Vector3(-0.9 + i * 0.3, 0, 0.03)), Color(1, 1, 1))
			mb.box("w", MB.mat(Tex.wood(Color("4a2e1c"), 86, 32, 2)), Vector3(2.2, 0.1, 0.02), MB.T(Vector3(0, 0.02, 0.01)), Color(1, 1, 1))
			mb.box("plaid", MB.mat(Tex.plaid()), Vector3(0.05, 0.08, 0.01), MB.T(Vector3(-0.9 + 6 * 0.3, -0.06, 0.06), Vector3(0, 0, 0.4)), Color(1, 1, 1))
		"padlock":
			pass   # the Padlock node draws itself
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	root.add_child(mi)
	add_child(root)
	set_layers(root, layer_of.get(aid, 1))
	thing_nodes[t["id"]] = root

## Show or hide things whose hide_if/when conditions have changed.
func refresh_things(host) -> void:
	for id in thing_nodes.keys():
		var t: Dictionary = b.things[id]
		var vis := WorldScript.test(t.get("when", {}), host)
		if t.has("hide_if") and WorldScript.test(t["hide_if"], host):
			vis = false
		thing_nodes[id].visible = vis
	for pid in padlocks.keys():
		padlocks[pid].visible = WorldScript.locked(b.portals[pid])

# ------------------------------------------------------------------ what can be seen

## Show the area you're in and those next to it; hide the rest.
func show_from(area_id: String) -> void:
	var vis := {area_id: true}
	for n in b.neighbours(area_id):
		vis[n] = true
		# and one further, through open doors (the stair shows the cellar)
		for n2 in b.neighbours(n):
			vis[n2] = true
	for id in area_nodes.keys():
		area_nodes[id].visible = vis.has(id)
	for s in sconces:
		s[0].visible = (area_id == s[1] or area_id == s[2]) or (vis.has(s[1]) and vis.has(s[2]) and (s[1] == "hall" or s[2] == "hall"))

## Hide everything off the hall (sitting at the table).
func hide_all() -> void:
	for id in area_nodes.keys():
		area_nodes[id].visible = false
	for s in sconces:
		s[0].visible = true

func flicker(area_id: String, seconds: float) -> void:
	_flicker[area_id] = seconds

func set_lights(area_id: String, on: bool) -> void:
	for l in area_lights.get(area_id, []):
		l.light_energy = l.get_meta("energy", 2.0) if on else 0.0

func _process(delta: float) -> void:
	_t += delta
	for id in _flicker.keys():
		_flicker[id] -= delta
		var on: bool = _flicker[id] <= 0.0 or (sin(_t * 37.0) * sin(_t * 11.0 + 2.0)) > 0.1
		for l in area_lights.get(id, []):
			l.light_energy = l.get_meta("energy", 2.0) * (1.0 if on else 0.05)
		if _flicker[id] <= 0.0:
			_flicker.erase(id)
