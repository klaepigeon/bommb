class_name Town
extends Node3D
## The town behind the wardrobe: Kerzhansk under the Romanovs, at night, built in code. Local
## coordinates; the node sits far from the flat.
##
##            z=-40  white ─ the way out
##            z=-24  ══ GATE ══ (lever on the right post); Marta keeps to it
##                   │ THE SQUARE: the frozen fight, the revolver, TRICKSHOT on the west wall
##            z=-4   ┴─────┬─ nursery (x4-8) ──────────────────────────────── north houses
##  x=0 seam   MAIN STREET (13 houses, 52 m, and it comes round: x wraps 0 ↔ 52)
##            z=4    ┬ arrival arch (x0-4) ─ HOTEL (x8-16) ─────── SALON (x36-44) ─ south houses
##
## Main street wraps: past either end Kurt is moved 52 m back, among identical houses, so it
## never ends. Monsters keep to their own parts of town.

const LOOP := 52.0
const STREET_W := 4.0
const PALETTE := ["d8b878", "c9a06a", "d9c39a", "b98a6a", "c8b0a0", "a8b090", "d0a888", "c0a070", "d8c8a0", "b09878", "c8a888", "d0b890", "b8a07a"]
const HEIGHTS := [7.5, 8.5, 6.5, 9.0, 7.0, 8.0, 6.5, 9.5, 7.5, 6.0, 8.5, 7.0, 8.0]

var arrival := Vector3(2.0, 0, 2.6)           ## local: where Kurt comes out of the hole
var revolver_at := Vector3(26.0, 0.02, -13.0)
var marta_post := Vector3(26.0, 0, -21.0)
var marta_away := Vector3(17.5, 0, -7.0)
var gate: Node3D
var gate_body: StaticBody3D
var gate_open := false
var lever_spot: Hotspot
var revolver_spot: Hotspot
var revolver_mesh: Node3D
var chalk: Array[Node3D] = []
var docs := {}            ## doc id → Hotspot
var pickups: Array = []   ## [Hotspot, kind]
var nuggets: Array[Node3D] = []
var sonya_spot: Hotspot
var nursery_center := Vector3(6, 1.2, -7)
var porter_home := Vector3(12, 0, 5.2)
var lamplighter_path: Array[Vector3] = []
var spin_root: Node3D
var cradle: Node3D

var _rng := RandomNumberGenerator.new()
var _b: Dictionary = {}

func _mats(b: Build) -> void:
	b.material("cobbles", Look.mat(Look.get_tex("cobbles")))
	b.material("stone", Look.mat(Look.get_tex("concrete"), Color("a8a49c")))
	b.material("roof", Look.mat(Look.get_tex("roof")))
	b.material("white", Look.mat(Look.get_tex("stucco"), Color("f0ece0")))
	b.material("dark", Look.mat(Look.get_tex("concrete"), Color("141414")))
	b.material("window_lit", Look.mat(Look.get_tex("plaster"), Color("ffcf80"), 160.0, false, Color(1.6, 1.1, 0.5)))
	b.material("window_dark", Look.mat(Look.get_tex("plaster"), Color("1a2028")))
	b.material("door", Look.mat(Look.get_tex("wood")))
	b.material("iron", Look.mat(Look.get_tex("iron")))
	b.material("wallpaper", Look.mat(Look.get_tex("wallpaper"), Color("c8a0a0")))
	b.material("parquet", Look.mat(Look.get_tex("parquet")))
	b.material("plaster", Look.mat(Look.get_tex("plaster")))
	b.material("wood", Look.mat(Look.get_tex("wood")))
	b.material("cloth_red", Look.mat(Look.get_tex("cloth"), Color("6a2a28")))
	b.material("cloth_white", Look.mat(Look.get_tex("cloth"), Color("d8d0c0")))
	b.material("paper", Look.mat(Look.get_tex("paper")))
	b.material("glow_white", Look.mat(Look.get_tex("white"), Color.WHITE, 160.0, false, Color(2.2, 2.2, 2.2)))
	b.material("lamp", Look.mat(Look.get_tex("white"), Color("ffe0a0"), 160.0, false, Color(2.5, 1.8, 0.9)))
	for i in PALETTE.size():
		b.material("house%d" % i, Look.mat(Look.get_tex("stucco"), Color(PALETTE[i])))

func _builder(name: String) -> Build:
	if not _b.has(name):
		var b := Build.new(self, name)
		_mats(b)
		_b[name] = b
	return _b[name]

func build() -> void:
	_rng.seed = 1910
	_street()
	_square()
	_hotel()
	_salon()
	_nursery()
	_arrival_arch()
	for b in _b.values():
		b.finish()
	_lights()
	_pickups()
	_dome()

# --- main street ------------------------------------------------------------------------------

func _street() -> void:
	for part in [["street_w", -28.0, 26.0], ["street_e", 26.0, 80.0]]:
		var b := _builder(part[0])
		b.box("cobbles", Vector3(part[1], -0.5, -STREET_W), Vector3(part[2], 0.0, STREET_W))
		b.box("stone", Vector3(part[1], 0.0, -STREET_W), Vector3(part[2], 0.12, -STREET_W + 1.0), Transform3D.IDENTITY, false)
		b.box("stone", Vector3(part[1], 0.0, STREET_W - 1.0), Vector3(part[2], 0.12, STREET_W), Transform3D.IDENTITY, false)
	for n in range(-7, 20):
		var x0 := n * 4.0
		var k := posmod(n, 13)
		var b := _builder("street_w" if x0 < 26.0 else "street_e")
		# north row (fronts face +z, the street)
		var in_square := x0 >= 16.0 and x0 < 32.0
		var in_square_dup := (x0 >= 68.0 and x0 < 84.0) or (x0 >= -36.0 and x0 < -20.0)
		if not in_square and not in_square_dup:
			if n == 1:
				_house_front(b, x0, k, true, true)        # the nursery's house: a real door
			else:
				_house_front(b, x0, k, true, false)
		# south row (fronts face -z)
		var real_door := n in [0, 2, 3, 9, 10]
		_house_front(b, x0, posmod(k + 5, 13), false, real_door)
		# a gas lamp per house on the south kerb: thirteen of them
		var lx := x0 + 2.0
		b.box("iron", Vector3(lx - 0.05, 0.1, 3.05), Vector3(lx + 0.05, 3.2, 3.15), Transform3D.IDENTITY, true)
		b.box("lamp", Vector3(lx - 0.15, 3.2, 2.95), Vector3(lx + 0.15, 3.6, 3.25), Transform3D.IDENTITY, false)
		b.box("iron", Vector3(lx - 0.2, 3.6, 2.9), Vector3(lx + 0.2, 3.66, 3.3), Transform3D.IDENTITY, false)
	# the chalk circle where the street comes round on itself (shown with These Streets)
	for x in [0.0, LOOP]:
		var ring := Node3D.new()
		add_child(ring)
		ring.position = Vector3(x, 0.005, 0)
		var m := Look.mat(Look.get_tex("white"), Color("e8e8e0"), 160.0, false, Color(0.3, 0.3, 0.3))
		for i in 16:
			var a := TAU * i / 16.0
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new(); bm.size = Vector3(0.22, 0.004, 0.05)
			mi.mesh = bm; mi.material_override = m
			mi.position = Vector3(cos(a), 0, sin(a)) * 0.7
			mi.rotation.y = -a + PI * 0.5
			ring.add_child(mi)
		for s in [-1.0, 1.0]:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new(); bm.size = Vector3(1.6, 0.004, 0.05)
			mi.mesh = bm; mi.material_override = m
			mi.rotation.y = PI * 0.25 * s
			ring.add_child(mi)
		ring.visible = false
		chalk.append(ring)
	# the lamplighter's beat: the length of the street and back
	lamplighter_path = [Vector3(6, 0, 1.8), Vector3(46, 0, 1.8)]
	# the lamplighter's tally on a post
	docs["lamps"] = Hotspot.make(self, global_transform * Transform3D(Basis(), Vector3(22.0, 1.4, 3.05)), Vector3(0.4, 0.8, 0.4), "Look")
	_builder("street_w").box("white", Vector3(21.94, 1.2, 2.98), Vector3(21.96, 1.6, 3.12), Transform3D.IDENTITY, false)
	# stop at the square's outer walls; invisible walls across the street ends (wrapped before)
	var bw := _builder("street_w")
	bw.collide(Vector3(-28.5, 0, -4), Vector3(-28, 4, 4))
	bw.collide(Vector3(80, 0, -4), Vector3(80.5, 4, 4))

func _house_front(b: Build, x0: float, k: int, north: bool, door_hole: bool) -> void:
	var h: float = HEIGHTS[k]
	var mat := "house%d" % k
	var z_front := -STREET_W if north else STREET_W
	var z_back := -12.0 if north else 12.0
	var out := 1.0 if north else -1.0          # +z is toward the street from the north row
	var d0 := 1.5; var d1 := 2.5               # door, centred
	if door_hole:
		# a front wall with a real doorway; the rest of the house is built by its interior
		b.wall_z(z_front - out * 0.15, x0, x0 + 4.0, mat, [[x0 + d0, x0 + d1, 0.0, 2.4]], 0.3, h)
	else:
		var mn := Vector3(x0, 0, minf(z_front, z_back))
		var mx := Vector3(x0 + 4.0, h, maxf(z_front, z_back))
		b.box(mat, mn, mx)
		b.box("door", Vector3(x0 + d0, 0.1, z_front + out * 0.0 - 0.03), Vector3(x0 + d1, 2.3, z_front + out * 0.04 + 0.03), Transform3D.IDENTITY, false)
	# cornice, plinth, windows with carved white frames
	var f := z_front + out * 0.05
	b.box("white", Vector3(x0, h - 0.4, f - 0.2), Vector3(x0 + 4.0, h - 0.1, f + 0.2), Transform3D.IDENTITY, false)
	b.box("roof", Vector3(x0, h - 0.1, minf(z_front, z_back)), Vector3(x0 + 4.0, h + 0.15, maxf(z_front, z_back)), Transform3D.IDENTITY, false)
	if door_hole:
		b.box("stone", Vector3(x0, 0, f - 0.12), Vector3(x0 + d0, 0.5, f + 0.12), Transform3D.IDENTITY, false)
		b.box("stone", Vector3(x0 + d1, 0, f - 0.12), Vector3(x0 + 4.0, 0.5, f + 0.12), Transform3D.IDENTITY, false)
	else:
		b.box("stone", Vector3(x0, 0, f - 0.12), Vector3(x0 + 4.0, 0.5, f + 0.12), Transform3D.IDENTITY, false)
	var floors := int((h - 1.0) / 3.0)
	for fl in floors:
		var y := 3.0 + fl * 3.0
		if y + 1.6 > h - 0.4:
			break
		for wx in [x0 + 0.6, x0 + 2.8]:
			if fl == 0 and wx > x0 + 1.0 and wx < x0 + 3.0:
				continue
			var lit := _rng.randf() < 0.22
			b.box("white", Vector3(wx - 0.12, y - 0.15, f - 0.06), Vector3(wx + 0.72, y + 1.75, f + 0.06), Transform3D.IDENTITY, false)
			b.box("window_lit" if lit else "window_dark", Vector3(wx, y, f - 0.08), Vector3(wx + 0.6, y + 1.5, f + 0.08), Transform3D.IDENTITY, false)
			b.box("white", Vector3(wx - 0.2, y + 1.6, f - 0.14), Vector3(wx + 0.8, y + 1.78, f + 0.14), Transform3D.IDENTITY, false)
	# ground-floor windows beside the door
	for wx in [x0 + 0.35, x0 + 2.95]:
		b.box("window_dark", Vector3(wx, 0.9, f - 0.08), Vector3(wx + 0.7, 2.1, f + 0.08), Transform3D.IDENTITY, false)

# --- the square: the frozen fight, the gate ---------------------------------------------------

func _square() -> void:
	var b := _builder("square")
	b.box("cobbles", Vector3(16, -0.5, -40), Vector3(36, 0.0, -4))
	# its walls: houses round three sides, the gate in the north side
	for side in [[16.0, "w"], [36.0, "e"]]:
		var x: float = side[0]
		var t := 8.0 if side[1] == "w" else -8.0
		var mn := Vector3(minf(x, x - t), 0, -24)
		var mx := Vector3(maxf(x, x - t), 8.0, -4)
		b.box("house%d" % (3 if side[1] == "w" else 7), mn, mx)
		for z in [-8.0, -13.0, -18.0]:
			var fx := x + (0.05 if side[1] == "w" else -0.05)
			b.box("window_dark", Vector3(fx - 0.08, 3.0, z), Vector3(fx + 0.08, 4.5, z + 0.7), Transform3D.IDENTITY, false)
			b.box("white", Vector3(fx - 0.1, 4.55, z - 0.1), Vector3(fx + 0.1, 4.7, z + 0.8), Transform3D.IDENTITY, false)
	b.box("house9", Vector3(16, 0, -32), Vector3(23.5, 9.0, -24))
	b.box("house11", Vector3(28.5, 0, -32), Vector3(36, 9.0, -24))
	# the gate posts and the lane beyond, going into white
	for x in [23.1, 28.9]:
		b.box("stone", Vector3(x - 0.4, 0, -24.6), Vector3(x + 0.4, 4.2, -23.4))
		b.box("white", Vector3(x - 0.5, 4.2, -24.7), Vector3(x + 0.5, 4.5, -23.3), Transform3D.IDENTITY, false)
	b.box("stone", Vector3(22.7, 3.6, -24.3), Vector3(29.3, 4.0, -23.7), Transform3D.IDENTITY, false)
	b.box("house2", Vector3(21.5, 0, -40), Vector3(23.5, 9, -24.6))
	b.box("house5", Vector3(28.5, 0, -40), Vector3(30.5, 9, -24.6))
	b.box("glow_white", Vector3(23.5, 0, -40.2), Vector3(28.5, 9, -40.0))
	b.collide(Vector3(23.5, 0, -40.6), Vector3(28.5, 4, -40.2))
	_gate()
	# the lever, on the right post
	var lever := Node3D.new(); add_child(lever); lever.position = Vector3(29.35, 1.2, -23.6)
	var lm := MeshInstance3D.new(); var lb := BoxMesh.new(); lb.size = Vector3(0.06, 0.5, 0.06)
	lm.mesh = lb; lm.material_override = Look.mat(Look.get_tex("iron")); lm.position.y = 0.2; lm.rotation.z = -0.4
	lever.add_child(lm)
	lever.name = "Lever"
	lever_spot = Hotspot.make(self, global_transform * Transform3D(Basis(), Vector3(29.4, 1.3, -23.3)), Vector3(0.6, 0.9, 0.6), "Pull")
	# TRICKSHOT on the west wall
	b.box("paper", Vector3(16.04, 1.2, -10.6), Vector3(16.08, 2.6, -9.6), Transform3D.IDENTITY, false)
	var lbl := Label3D.new()
	lbl.text = "THE CHAMPION'S\nLEAGUE\n\nTRICKSHOT"
	lbl.font_size = 22
	lbl.modulate = Color("3a1a14")
	lbl.outline_size = 0
	lbl.pixel_size = 0.004
	add_child(lbl)
	lbl.position = Vector3(16.1, 1.9, -10.1)
	lbl.rotation.y = PI * 0.5
	docs["poster"] = Hotspot.make(self, global_transform * Transform3D(Basis(), Vector3(16.3, 1.9, -10.1)), Vector3(0.5, 1.4, 1.1), "Look")
	# the frozen fight
	spin_root = Node3D.new(); spin_root.name = "FrozenFight"; add_child(spin_root)
	var c := Vector3(26, 1.3, -13.0)
	var stone := Look.mat(Look.get_tex("cobbles"))
	var wood := Look.mat(Look.get_tex("wood"))
	for i in 14:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		if i % 3 == 0:
			bm.size = Vector3(0.42, 0.06, 0.42)   # a chair seat with its legs
			mi.material_override = wood
		else:
			bm.size = Vector3(0.3, 0.15, 0.2)
			mi.material_override = stone
		mi.mesh = bm
		var a := _rng.randf() * TAU
		mi.position = c + Vector3(cos(a) * _rng.randf_range(1.2, 4.0), _rng.randf_range(-0.8, 2.2), sin(a) * _rng.randf_range(1.2, 4.0))
		mi.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, 0)
		mi.set_meta("spin", Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.2, 0.2), 0))
		spin_root.add_child(mi)
	var shaft_m := Look.mat(Look.get_tex("wood_light"))
	var fletch_m := Look.mat(Look.get_tex("cloth"), Color("a02020"))
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		var from := c + Vector3(cos(a) * 3.0, _rng.randf_range(-0.4, 0.8), sin(a) * 3.0)
		var arrow := Node3D.new()
		spin_root.add_child(arrow)
		arrow.position = from
		arrow.look_at_from_position(from, c, Vector3.UP)
		var s := MeshInstance3D.new(); var sm := BoxMesh.new(); sm.size = Vector3(0.012, 0.012, 0.7)
		s.mesh = sm; s.material_override = shaft_m; arrow.add_child(s)
		var fl := MeshInstance3D.new(); var fm := BoxMesh.new(); fm.size = Vector3(0.05, 0.05, 0.1)
		fl.mesh = fm; fl.material_override = fletch_m; fl.position.z = 0.32; arrow.add_child(fl)
	# the mask on the cobbles
	b.box("dark", Vector3(-0.09, 0, -0.035), Vector3(0.09, 0.012, 0.035), Transform3D(Basis(Vector3.UP, 0.4), Vector3(24.6, 0.0, -12.2)), false)
	docs["mask"] = Hotspot.make(self, global_transform * Transform3D(Basis(), Vector3(24.6, 0.2, -12.2)), Vector3(0.5, 0.4, 0.5), "Look")
	# the revolver, in the middle of it all
	revolver_mesh = Node3D.new(); add_child(revolver_mesh)
	revolver_mesh.position = revolver_at
	var rv := MeshInstance3D.new(); var rb := BoxMesh.new(); rb.size = Vector3(0.05, 0.035, 0.24)
	rv.mesh = rb; rv.material_override = Look.mat(Look.get_tex("white"), Color("2a2a2e"), 160.0, false, Color(0.25, 0.25, 0.3))
	rv.rotation.y = 0.7
	revolver_mesh.add_child(rv)
	var grip := MeshInstance3D.new(); var gb := BoxMesh.new(); gb.size = Vector3(0.03, 0.03, 0.08)
	grip.mesh = gb; grip.material_override = wood; grip.position = Vector3(0.05, 0, 0.08); grip.rotation.y = 0.7 + 0.5
	revolver_mesh.add_child(grip)
	revolver_spot = Hotspot.make(self, global_transform * Transform3D(Basis(), revolver_at + Vector3(0, 0.15, 0)), Vector3(0.6, 0.4, 0.6), "Take")

func _gate() -> void:
	gate = Node3D.new(); gate.name = "Gate"; add_child(gate)
	gate.position = Vector3(23.5, 0, -24.0)
	var iron := Look.mat(Look.get_tex("iron"), Color.WHITE, 160.0, true)
	for leaf_i in 2:
		var leaf := Node3D.new()
		gate.add_child(leaf)
		leaf.position = Vector3(0.0 if leaf_i == 0 else 5.0, 0, 0)
		leaf.name = "Leaf%d" % leaf_i
		var dirx := 1.0 if leaf_i == 0 else -1.0
		for i in 11:
			var bar := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.04, 3.4, 0.04)
			bar.mesh = bm; bar.material_override = iron
			bar.position = Vector3(dirx * (0.12 + i * 0.22), 1.7, 0)
			leaf.add_child(bar)
		for y in [0.3, 1.7, 3.3]:
			var rail := MeshInstance3D.new(); var rm := BoxMesh.new(); rm.size = Vector3(2.5, 0.06, 0.06)
			rail.mesh = rm; rail.material_override = iron
			rail.position = Vector3(dirx * 1.25, y, 0)
			leaf.add_child(rail)
	gate_body = StaticBody3D.new(); gate.add_child(gate_body)
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(5.0, 4.0, 0.3)
	cs.shape = bs; cs.position = Vector3(2.5, 2.0, 0)
	gate_body.add_child(cs)

func open_gate() -> void:
	gate_open = true
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(gate.get_node("Leaf0"), "rotation:y", deg_to_rad(-100), 3.0)
	tw.tween_property(gate.get_node("Leaf1"), "rotation:y", deg_to_rad(100), 3.0)
	gate_body.queue_free()
	Sfx.play_at("creak", global_transform * Vector3(26, 1.5, -24), 4.0, 0.7)

# --- interiors ---------------------------------------------------------------------------------

func _room(b: Build, x0: float, x1: float, z0: float, z1: float, h: float, door_side_z: float, wall := "wallpaper") -> void:
	b.box("parquet", Vector3(x0, -0.1, z0), Vector3(x1, 0.0, z1))
	b.box("plaster", Vector3(x0, h, z0), Vector3(x1, h + 0.1, z1), Transform3D.IDENTITY, false)
	var back_z := z1 if door_side_z == z0 else z0
	b.wall_z(back_z, x0, x1, wall, [], 0.2, h)
	b.wall_x(x0, minf(z0, z1), maxf(z0, z1), wall, [], 0.2, h)
	b.wall_x(x1, minf(z0, z1), maxf(z0, z1), wall, [], 0.2, h)
	# inside face of the front wall
	b.box(wall, Vector3(x0, 0, door_side_z - 0.02), Vector3(x1, 0.01, door_side_z + 0.02), Transform3D.IDENTITY, false)

func _hotel() -> void:
	var b := _builder("hotel")
	_room(b, 8.0, 16.0, 4.2, 10.0, 3.2, 4.2)
	b.wall_z(7.2, 8.0, 16.0, "wallpaper", [[11.0, 12.2, 0.0, 2.3]], 0.15, 3.2)   # the lobby and room four
	b.box("wood", Vector3(10.0, 0, 5.6), Vector3(14.0, 1.1, 6.1))                  # desk
	b.box("paper", Vector3(12.3, 1.1, 5.7), Vector3(12.8, 1.13, 6.0), Transform3D.IDENTITY, false)
	docs["register"] = Hotspot.make(self, global_transform * Transform3D(Basis(), Vector3(12.55, 1.2, 5.85)), Vector3(0.6, 0.4, 0.5), "Read")
	var lbl := _sign("ГОСТИНИЦА", Vector3(12.0, 3.0, 3.8), PI)
	lbl.modulate = Color("e8d0a0")
	porter_home = Vector3(14.6, 0, 8.6)
	# room four: bed, chair with the quiver, two glasses, the photo strip
	b.box("wood", Vector3(13.6, 0, 8.0), Vector3(15.8, 0.5, 9.8))
	b.box("cloth_white", Vector3(13.7, 0.5, 8.1), Vector3(15.7, 0.62, 9.7), Transform3D.IDENTITY, false)
	b.box("cloth_red", Vector3(13.7, 0.62, 8.9), Vector3(15.7, 0.66, 9.7), Transform3D.IDENTITY, false)
	b.box("wood", Vector3(9.0, 0, 8.6), Vector3(9.5, 0.46, 9.1))
	b.box("wood", Vector3(9.0, 0.46, 9.05), Vector3(9.5, 1.0, 9.1), Transform3D.IDENTITY, false)
	b.box("cloth_red", Vector3(9.1, 0.5, 8.95), Vector3(9.25, 1.1, 9.05), Transform3D.IDENTITY, false)   # quiver
	docs["quiver"] = Hotspot.make(self, global_transform * Transform3D(Basis(), Vector3(9.25, 0.8, 8.9)), Vector3(0.5, 0.8, 0.5), "Look")
	b.box("wood", Vector3(10.6, 0, 9.0), Vector3(11.6, 0.7, 9.8))
	for gx in [10.9, 11.2]:
		b.box("glow_white", Vector3(gx, 0.7, 9.3), Vector3(gx + 0.06, 0.8, 9.36), Transform3D.IDENTITY, false)
	docs["glasses"] = Hotspot.make(self, global_transform * Transform3D(Basis(), Vector3(11.05, 0.8, 9.35)), Vector3(0.5, 0.4, 0.5), "Look")
	b.box("paper", Vector3(15.0, 0.66, 8.3), Vector3(15.06, 0.67, 8.5), Transform3D.IDENTITY, false)
	docs["strip"] = Hotspot.make(self, global_transform * Transform3D(Basis(), Vector3(15.0, 0.75, 8.4)), Vector3(0.5, 0.3, 0.5), "Look")

func _salon() -> void:
	var b := _builder("salon")
	_room(b, 36.0, 44.0, 4.2, 10.0, 3.4, 4.2, "wallpaper")
	_sign("ФОТОГРАФІЯ", Vector3(40.0, 3.0, 3.8), PI).modulate = Color("e8d0a0")
	b.box("wood", Vector3(38.5, 0, 7.0), Vector3(41.5, 0.75, 8.4))      # the séance table
	b.box("cloth_red", Vector3(38.4, 0.75, 6.9), Vector3(41.6, 0.78, 8.5), Transform3D.IDENTITY, false)
	b.box("paper", Vector3(36.12, 1.3, 8.6), Vector3(36.14, 2.1, 9.2), Transform3D.IDENTITY, false)   # the portrait
	docs["photo"] = Hotspot.make(self, global_transform * Transform3D(Basis(), Vector3(36.4, 1.7, 8.9)), Vector3(0.5, 0.9, 0.8), "Look")
	b.box("paper", Vector3(39.2, 0.78, 7.5), Vector3(39.5, 0.79, 7.7), Transform3D.IDENTITY, false)
	docs["g_note"] = Hotspot.make(self, global_transform * Transform3D(Basis(), Vector3(39.35, 0.85, 7.6)), Vector3(0.4, 0.3, 0.4), "Read")
	b.box("paper", Vector3(40.6, 0.78, 7.2), Vector3(41.2, 0.79, 7.8), Transform3D.IDENTITY, false)
	docs["paper"] = Hotspot.make(self, global_transform * Transform3D(Basis(), Vector3(40.9, 0.85, 7.5)), Vector3(0.6, 0.3, 0.6), "Read")
	# chairs and teacups circling in the air
	var ring := Node3D.new(); ring.name = "SeanceRing"; add_child(ring)
	ring.position = Vector3(40, 1.9, 7.7)
	ring.set_meta("orbit", 0.25)
	var wood := Look.mat(Look.get_tex("wood"))
	var china := Look.mat(Look.get_tex("white"), Color("e8e4dc"))
	for i in 8:
		var a := TAU * i / 8.0
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.4, 0.5, 0.4) if i % 2 == 0 else Vector3(0.09, 0.07, 0.09)
		mi.mesh = bm
		mi.material_override = wood if i % 2 == 0 else china
		mi.position = Vector3(cos(a) * 1.5, sin(a * 3.0) * 0.2, sin(a) * 1.5)
		mi.rotation = Vector3(0.3, a, 0.2)
		ring.add_child(mi)
	spin_root.set_meta("ring", ring)

func _nursery() -> void:
	var b := _builder("nursery")
	_room(b, 4.0, 8.0, -10.0, -4.2, 3.0, -4.2, "wallpaper")
	nursery_center = Vector3(6.0, 1.2, -7.2)
	# the cradle, rocking by itself
	cradle = Node3D.new(); add_child(cradle); cradle.position = Vector3(5.0, 0, -8.6)
	var cm := MeshInstance3D.new(); var cb := BoxMesh.new(); cb.size = Vector3(0.9, 0.35, 0.5)
	cm.mesh = cb; cm.material_override = Look.mat(Look.get_tex("wood_light")); cm.position.y = 0.4
	cradle.add_child(cm)
	b.box("wood", Vector3(6.8, 0, -6.2), Vector3(7.8, 0.6, -5.4))           # a little table
	b.box("paper", Vector3(7.0, 0.6, -6.0), Vector3(7.4, 0.61, -5.7), Transform3D.IDENTITY, false)
	docs["drawing"] = Hotspot.make(self, global_transform * Transform3D(Basis(), Vector3(7.2, 0.7, -5.85)), Vector3(0.5, 0.3, 0.5), "Look")
	b.box("paper", Vector3(7.45, 0.6, -5.9), Vector3(7.7, 0.64, -5.6), Transform3D.IDENTITY, false)
	docs["letters"] = Hotspot.make(self, global_transform * Transform3D(Basis(), Vector3(7.55, 0.7, -5.75)), Vector3(0.4, 0.3, 0.4), "Read")
	# her door, at the back, scratched low down at a child's height: СОНЯ
	b.box("door", Vector3(5.5, 0, -9.92), Vector3(6.5, 2.0, -9.86), Transform3D.IDENTITY, false)
	var l := _sign("СОНЯ", Vector3(6.0, 0.7, -9.83), 0.0)
	l.font_size = 18
	l.modulate = Color("d8d0c0")
	sonya_spot = Hotspot.make(self, global_transform * Transform3D(Basis(), Vector3(6.0, 1.0, -9.7)), Vector3(1.0, 2.0, 0.4), "Open")

func _arrival_arch() -> void:
	# where the hole comes out: a low cellar arch in the south row, dark behind
	var b := _builder("street_w")
	b.box("dark", Vector3(0.6, 0, 4.0), Vector3(3.4, 2.0, 4.6))
	b.box("stone", Vector3(0.4, 2.0, 3.8), Vector3(3.6, 2.3, 4.2), Transform3D.IDENTITY, false)

func _sign(text: String, at: Vector3, yaw: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.006
	l.outline_size = 6
	add_child(l)
	l.position = at
	l.rotation.y = yaw
	return l

# --- light, things to take, the dome ----------------------------------------------------------

func _lights() -> void:
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("6f86a8")
	moon.light_energy = 0.75
	moon.shadow_enabled = false
	moon.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
	add_child(moon)
	for p in [Vector3(2, 3.3, 2.8), Vector3(14, 3.3, 2.8), Vector3(38, 3.3, 2.8), Vector3(26, 4.0, -12), Vector3(26, 3.8, -22.5)]:
		_omni(p, Color("ffc070"), 1.3, 9.0)
	_omni(Vector3(12, 2.6, 6.5), Color("ffb060"), 0.9, 6.0)      # hotel lamp
	_omni(Vector3(40, 2.6, 7.5), Color("d0a0ff"), 0.8, 6.0)      # séance candle-ish
	_omni(Vector3(6, 2.4, -7.5), Color("a0b8ff"), 0.6, 5.0)      # nursery night-light

func _omni(p: Vector3, c: Color, e: float, r: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = c; l.light_energy = e; l.omni_range = r; l.shadow_enabled = false
	l.omni_attenuation = 1.3
	add_child(l)
	l.position = p

func _pickups() -> void:
	# rounds for the Nagant: seven to a box
	for p in [Vector3(13.5, 1.15, 5.8), Vector3(42.5, 0.1, 9.0), Vector3(34.5, 0.1, -5.5)]:
		_pickup(p, "ammo", Color("8a6a3a"), Vector3(0.14, 0.07, 0.09))
	# loose cobbles, to throw
	for p in [Vector3(19.0, 0.05, -5.5), Vector3(30.5, 0.05, -18.0), Vector3(9.0, 0.05, -2.5), Vector3(44.0, 0.05, 2.0), Vector3(21.0, 0.05, -20.5), Vector3(3.0, 0.05, 1.5)]:
		_pickup(p, "rock", Color.WHITE, Vector3(0.09, 0.06, 0.1))
	# gutterspace nuggets
	for p in [Vector3(4.5, 0.6, 0.0), Vector3(18.0, 0.6, 2.0), Vector3(15.2, 0.9, 9.4), Vector3(9.5, 0.6, 5.0),
			Vector3(43.0, 0.6, 5.0), Vector3(37.0, 2.2, 9.2), Vector3(4.6, 0.6, -9.4), Vector3(34.0, 0.6, -22.0),
			Vector3(17.5, 0.6, -20.0), Vector3(49.0, 0.6, -2.5), Vector3(30.0, 2.6, -12.0), Vector3(7.5, 0.6, -4.8)]:
		var n := Nugget.new()
		add_child(n)
		n.position = p
		nuggets.append(n)

func _pickup(p: Vector3, kind: String, tint: Color, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm
	mi.material_override = Look.mat(Look.get_tex("rubble" if kind == "rock" else "cloth"), tint, 160.0, false, Color(0.15, 0.15, 0.15))
	add_child(mi)
	mi.position = p + Vector3(0, size.y * 0.5, 0)
	var h := Hotspot.make(self, global_transform * Transform3D(Basis(), p + Vector3(0, 0.15, 0)), Vector3(0.5, 0.4, 0.5), "Take")
	h.set_meta("mesh", mi)
	pickups.append([h, kind])

var dome: Node3D

func _dome() -> void:
	# The church that stays the same distance away however far you walk.
	dome = Node3D.new(); dome.name = "Dome"; add_child(dome)
	var m := Look.mat(Look.get_tex("roof"), Color("8a98a8"), 0.0, false, Color(0.1, 0.12, 0.16))
	var gold := Look.mat(Look.get_tex("white"), Color("c8a040"), 0.0, false, Color(0.6, 0.45, 0.15))
	var drum := MeshInstance3D.new(); var dm := CylinderMesh.new(); dm.top_radius = 4; dm.bottom_radius = 4; dm.height = 8; dm.radial_segments = 12
	drum.mesh = dm; drum.material_override = m; drum.position.y = 10
	dome.add_child(drum)
	var cap := MeshInstance3D.new(); var cp := SphereMesh.new(); cp.radius = 4.4; cp.height = 8.8; cp.is_hemisphere = true; cp.radial_segments = 12; cp.rings = 6
	cap.mesh = cp; cap.material_override = m; cap.position.y = 14
	dome.add_child(cap)
	var cross := MeshInstance3D.new(); var cb := BoxMesh.new(); cb.size = Vector3(0.3, 3, 0.3)
	cross.mesh = cb; cross.material_override = gold; cross.position.y = 19.8
	dome.add_child(cross)
	var bar := MeshInstance3D.new(); var bb := BoxMesh.new(); bb.size = Vector3(1.6, 0.3, 0.3)
	bar.mesh = bb; bar.material_override = gold; bar.position.y = 20.5
	dome.add_child(bar)

func _process(delta: float) -> void:
	if not visible:
		return
	var cam := get_viewport().get_camera_3d()
	if cam:
		var local := to_local(cam.global_position)
		dome.position = Vector3(local.x + 4.0, 0, local.z - 34.0)
	for c in spin_root.get_children():
		if c.has_meta("spin"):
			var s: Vector3 = c.get_meta("spin")
			c.rotation += s * delta
	if spin_root.has_meta("ring"):
		var r: Node3D = spin_root.get_meta("ring")
		r.rotation.y += delta * 0.25
	if cradle:
		cradle.rotation.x = sin(Time.get_ticks_msec() * 0.0015) * 0.18
