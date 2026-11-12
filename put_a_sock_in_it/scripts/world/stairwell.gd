class_name Stairwell
## The landing outside 47, in the flat's frame: the stairwell of a tired block. Tiled floor worn
## through to concrete in a path; institutional green to shoulder height, whitewash above, both
## grimed and peeling; graffiti; the meter cabinet hanging open, its wires running along the
## ceiling to a bare bulb in a cage. The stair down drops past an iron rail into the dark, the
## top flight jammed with furniture somebody piled there; a window on the half-landing below lets
## in the night, blue. 48 across the landing, padded like 47.
##
## build(f, opts) adds it all under `f` (an ExportedFlat) and returns {"bulb": Fitting or null,
## "door48": Door}. opts: "tint" (Color: the flesh flat's blue), "pulse" (walls breathing),
## "bulb" (false: no bulb), "open48" (48 stands open).

const RAIL_X := 13.05       # the rail along the well
const WELL_Z0 := 4.2        # the first step down
const WELL_Z1 := 7.1        # the rail's return; the lower landing beyond
const STEPS := 10
const RISE := 0.2

static func build(f: ExportedFlat, opts := {}) -> Dictionary:
	var tint: Color = opts.get("tint", Color(1, 1, 1))
	var t := {"tint": tint}
	var wall_o := t.duplicate(); if opts.has("pulse"): wall_o["pulse"] = opts.pulse
	var sw := Tex.mat("stairwell", 0.25, wall_o)
	var plaster := Tex.mat("plaster", 0.7, t)
	var dark := Tex.mat("concrete", 1.0, {"tint": tint * Color(0.55, 0.55, 0.55)})
	var conc := Tex.mat("concrete", 1.5, t)
	var tiles := Tex.mat("metlakh", 1.0, t)
	var out := {}
	var first := f.get_child_count()
	var keep := []

	# -------------------------------------------------- floor, ceiling, walls
	Build.box(f, Vector3(11.575, -0.05, 5.7), Vector3(2.95, 0.1, 4.6), tiles)                # the landing
	Build.box(f, Vector3(13.675, -0.05, 3.8), Vector3(1.25, 0.1, 0.8), tiles)                # the top of the flight
	Build.box(f, Vector3(13.675, -0.05, 7.55), Vector3(1.25, 0.1, 0.9), tiles)               # the corner by 48
	Build.box(f, Vector3(RAIL_X - 0.01, -0.16, 5.65), Vector3(0.04, 0.3, 2.9), conc, false)  # the slab's edge over the well
	Build.box(f, Vector3(11.575, 2.87, 5.7), Vector3(2.95, 0.1, 4.6), plaster)
	Build.box(f, Vector3(13.675, 2.87, 7.55), Vector3(1.25, 0.1, 0.9), plaster)
	Build.box(f, Vector3(13.675, 2.87, 3.8), Vector3(1.25, 0.1, 0.8), plaster)
	Build.wall(f, Vector2(10.15, 3.4), Vector2(14.3, 3.4), sw, [], 2.8, 0.1)
	Build.wall(f, Vector2(14.3, 3.4), Vector2(14.3, 8.0), sw, [], 2.8, 0.1)
	Build.wall(f, Vector2(10.15, 8.0), Vector2(14.3, 8.0), sw, [{"at": 2.4, "w": 0.95, "top": 2.1}], 2.8, 0.1)
	f.landing_face(sw, Tex.mat("plaster", 1.0, t))
	# the well: down to the half-landing, and up into the dark of the next floor
	Build.wall(f, Vector2(RAIL_X, 3.4), Vector2(RAIL_X, 8.0), dark, [], 2.3, 0.08, -2.4)
	Build.wall(f, Vector2(RAIL_X, 3.4), Vector2(14.3, 3.4), dark, [], 2.3, 0.1, -2.4)
	Build.wall(f, Vector2(14.3, 3.4), Vector2(14.3, 8.0), dark, [{"at": 2.3, "w": 0.95, "bottom": 1.1, "top": 2.25}], 2.4, 0.1, -2.4)
	Build.wall(f, Vector2(RAIL_X, 8.0), Vector2(14.3, 8.0), dark, [], 2.3, 0.1, -2.4)
	Build.box(f, Vector3(13.675, -2.05, 7.55), Vector3(1.25, 0.1, 0.9), conc, false)         # the half-landing
	Build.wall(f, Vector2(RAIL_X, 3.4), Vector2(14.3, 3.4), dark, [], 2.8, 0.1, 2.8)
	Build.wall(f, Vector2(14.3, 3.4), Vector2(14.3, 7.1), dark, [], 2.8, 0.1, 2.8)
	Build.wall(f, Vector2(11.6, 3.4), Vector2(11.6, 8.0), dark, [], 2.8, 0.1, 2.92)          # the floor above, beyond its rail
	Build.box(f, Vector3(12.9, 5.65, 5.25), Vector3(2.8, 0.1, 3.8), Tex.mat("black"), false)
	# the floor above's rail, seen up the well
	_rail(f, Vector3(RAIL_X, 2.92, WELL_Z0), Vector3(RAIL_X, 2.92, WELL_Z1), tint, false)

	# -------------------------------------------------- the stair down
	for i in STEPS:
		var top := -RISE * (i + 1)
		var z := WELL_Z0 + (WELL_Z1 - WELL_Z0) * (i + 0.5) / STEPS
		var go := (WELL_Z1 - WELL_Z0) / STEPS
		Build.box(f, Vector3(13.675, top - 0.12, z), Vector3(1.2, 0.24, go), conc, false)
		Build.box(f, Vector3(13.675, top + 0.004, z - go * 0.5 + 0.03), Vector3(1.2, 0.012, 0.05), Tex.mat("concrete", 3.0, {"tint": tint * Color(0.6, 0.58, 0.55)}), false)   # the worn nosing
	_rail(f, Vector3(RAIL_X, 0.0, WELL_Z0), Vector3(RAIL_X, 0.0, WELL_Z1), tint, true)
	_rail(f, Vector3(RAIL_X, 0.0, WELL_Z1), Vector3(14.3, 0.0, WELL_Z1), tint, true)
	_barricade(f, tint)
	_window(f, tint)
	# someone's light, two floors down
	var below := OmniLight3D.new(); below.light_color = Color("ff9a5a") * tint; below.light_energy = 0.5; below.omni_range = 3.5
	f.add_child(below); below.position = Vector3(13.7, -1.5, 7.6)

	# -------------------------------------------------- 48
	var d48 := Door.new(); d48.width = 0.95; d48.height = 2.05; d48.locked = true
	d48.style = "padded"; d48.conv = f.conv
	d48.leaf_opts = {"number": 48, "outside": -1.0, "vinyl": Color("4e3a2c") * tint}
	if opts.get("open48", false): d48.open_angle = 1.2; d48.is_open = true
	f.add_child(d48); d48.position = Vector3(12.075, 0, 7.96)
	out["door48"] = d48
	var trim := Tex.mat("wood", 2.0, {"tint": tint * Color(0.75, 0.6, 0.5)})
	_architrave(f, Vector3(10.47, 0, 4.56), 0.88, 2.1, Vector3.RIGHT, trim)
	_architrave(f, Vector3(12.55, 0, 7.94), 0.95, 2.1, Vector3.BACK * -1.0, trim)
	_mat(f, Vector3(10.85, 0.006, 4.56), Vector2(0.55, 0.85), Color("3a3633") * tint)
	_mat(f, Vector3(12.55, 0.006, 7.55), Vector2(0.85, 0.5), Color("6a3028") * tint)

	# -------------------------------------------------- light
	out["bulb"] = null
	if opts.get("bulb", true):
		var at := Vector3(11.7, 2.48, 5.7)
		var b := Fitting.make(f, at, Color("ffcf8a"), 1.7, 6.5, "dying", true)
		var g := Build.box(f, at, Vector3(0.05, 0.075, 0.05), Tex.mat("enamel", 1.0, {"emission": Vector3(1.4, 1.15, 0.75)}), false)
		b.add_glow(g, Vector3(1.4, 1.15, 0.75)); keep.append(g)
		_cage(f, at, tint)
		out["bulb"] = b
	_cabinet(f, tint)
	_pipes(f, tint)
	_rubbish(f, tint)
	_graffiti(f, tint)
	_decals(f, tint)
	var mine := []
	for i in range(first, f.get_child_count()): mine.append(f.get_child(i))
	Build.merge(f, mine, keep)
	for n in mine:
		if is_instance_valid(n) and n.name == "Barricade": Build.merge(n, n.get_children())
	Air.dust(f, Vector3(12.0, 1.4, 5.7), Vector3(1.9, 1.3, 2.2), 260)
	Air.dust(f, Vector3(13.7, 0.0, 5.6), Vector3(0.6, 1.8, 1.4), 90, Color(0.75, 0.85, 1.0))
	return out

## An iron rail from a to b (on the floor at a.y): square balusters, a bottom bar, and a
## handrail capped in brown plastic. Solid if `solid`.
static func _rail(f: Node3D, a: Vector3, b: Vector3, tint: Color, solid: bool) -> void:
	var iron := Tex.mat("gunmetal", 2.0, {"tint": tint * Color(1.3, 1.3, 1.3)})
	var cap := Tex.mat("wood", 3.0, {"tint": tint * Color(0.55, 0.32, 0.22)})
	var d := b - a; var L := Vector2(d.x, d.z).length()
	var yaw := atan2(d.x, d.z)
	var mid := (a + b) * 0.5
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := int(L / 0.13)
	var bs := Basis(Vector3.UP, yaw)
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		MeshKit.box(st, p + Vector3(0, 0.47, 0), Vector3(0.016, 0.9, 0.016))
	MeshKit.box(st, mid + Vector3(0, 0.08, 0), Vector3(0.02, 0.02, L), bs)
	MeshKit.box(st, mid + Vector3(0, 0.92, 0), Vector3(0.03, 0.02, L), bs)
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = iron; f.add_child(mi)
	var h := Build.box(f, mid + Vector3(0, 0.95, 0), Vector3(0.06, 0.04, L + 0.04), cap, false, yaw)
	h.name = "Handrail"
	if solid:
		var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := BoxShape3D.new()
		sh.size = Vector3(0.08, 1.1, L); cs.shape = sh; sb.add_child(cs); f.add_child(sb)
		sb.position = mid + Vector3(0, 0.55, 0); sb.rotation.y = yaw; sb.set_meta("surface", "metal")

## The top of the flight, jammed: a wardrobe door, chairs, a mattress, boards. Nobody's going down.
static func _barricade(f: Node3D, tint: Color) -> void:
	var wood := Tex.mat("wood", 2.0, {"tint": tint})
	var paint := Tex.mat("paint_door", 1.0, {"tint": tint * Color(0.9, 0.88, 0.8)})
	var cloth := Tex.mat("fabric", 2.0, {"tint": tint * Color(0.9, 0.85, 0.8)})
	var pile := Node3D.new(); pile.name = "Barricade"; f.add_child(pile); pile.position = Vector3(13.68, 0, 4.55)
	_part(pile, Vector3(0.0, 0.55, 0.15), Vector3(1.1, 1.6, 0.08), cloth, Vector3(-0.55, 0.15, 0.1))         # the mattress, on its side
	_part(pile, Vector3(-0.2, 0.75, -0.1), Vector3(0.75, 1.9, 0.035), paint, Vector3(-0.35, -0.2, 0.25))     # a door, off its hinges
	for c in [[Vector3(0.3, 0.25, -0.15), Vector3(0.3, 1.2, 0.6)], [Vector3(-0.3, 0.55, 0.05), Vector3(2.4, 0.4, -0.3)]]:
		var ch := Node3D.new(); pile.add_child(ch); ch.position = c[0]; ch.rotation = c[1]
		_part(ch, Vector3(0, 0.0, 0), Vector3(0.42, 0.04, 0.4), wood)
		_part(ch, Vector3(0, 0.25, -0.19), Vector3(0.42, 0.5, 0.03), wood)
		for lx in [-0.18, 0.18]:
			for lz in [-0.17, 0.17]:
				_part(ch, Vector3(lx, -0.22, lz), Vector3(0.03, 0.44, 0.03), wood)
	for i in 5:
		_part(pile, Vector3(-0.5 + i * 0.25, 0.5 + (i % 2) * 0.3, -0.3 + (i % 3) * 0.15), Vector3(0.08, 1.4, 0.02), wood, Vector3(0.3 * (i % 2 * 2 - 1), 0.2 * i, 0.7 - i * 0.3))
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := BoxShape3D.new()
	sh.size = Vector3(1.25, 2.0, 1.0); cs.shape = sh; sb.add_child(cs); pile.add_child(sb); sb.position = Vector3(0, 1.0, 0.1)
	sb.set_meta("surface", "wood")

static func _part(parent: Node3D, pos: Vector3, size: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = Build.box_mesh(size); mi.material_override = m
	parent.add_child(mi); mi.position = pos; mi.rotation = rot
	return mi

## The half-landing's window, in the well's east wall below the floor: night outside, blue.
static func _window(f: Node3D, tint: Color) -> void:
	var c := Vector3(14.3, -0.75, 5.7)
	var frame := Tex.mat("paint_door", 2.0, {"tint": tint * Color(0.75, 0.75, 0.7)})
	var glass := Tex.mat("glass", 1.0, {"tint": tint * Color(0.25, 0.32, 0.5), "emission": Vector3(0.05, 0.08, 0.16) * Vector3(tint.r, tint.g, tint.b)})
	Build.box(f, c + Vector3(0.02, 0, 0), Vector3(0.02, 1.15, 0.95), glass, false)
	for d in [[Vector3(0, 0.56, 0), Vector3(0.08, 0.05, 0.97)], [Vector3(0, -0.56, 0), Vector3(0.14, 0.05, 1.05)], [Vector3(0, 0, 0.46), Vector3(0.08, 1.15, 0.05)],
			[Vector3(0, 0, -0.46), Vector3(0.08, 1.15, 0.05)], [Vector3(0, 0.1, 0), Vector3(0.06, 0.04, 0.95)], [Vector3(0, 0, 0), Vector3(0.06, 1.15, 0.04)]]:
		Build.box(f, c + d[0], d[1], frame, false)
	# a cracked pane: a dark line across
	Build.box(f, c + Vector3(-0.0, -0.25, 0.2), Vector3(0.012, 0.006, 0.4), Tex.mat("black"), false, 0.0).rotation.x = 0.5
	var moon := SpotLight3D.new(); moon.light_color = Color("7f98d8") * tint; moon.light_energy = 2.2
	moon.spot_range = 9.0; moon.spot_angle = 38.0; moon.spot_attenuation = 1.2; moon.light_specular = 0.1
	f.add_child(moon); moon.position = c + Vector3(0.6, -0.2, 0)
	moon.look_at(f.to_global(Vector3(12.6, 2.6, 5.4)))

## A cord, a socket, a wire cage round the bulb.
static func _cage(f: Node3D, at: Vector3, tint: Color) -> void:
	var k := Tex.mat("black")
	Build.box(f, at + Vector3(0, 0.19, 0), Vector3(0.012, 0.32, 0.012), k, false)
	Build.box(f, at + Vector3(0, 0.06, 0), Vector3(0.045, 0.06, 0.045), k, false)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var a := TAU * i / 6.0
		var p := at + Vector3(cos(a) * 0.065, -0.03, sin(a) * 0.065)
		MeshKit.tube(st, [at + Vector3(0, 0.04, 0), p, at + Vector3(cos(a) * 0.02, -0.11, sin(a) * 0.02)], [0.003, 0.003, 0.003], {"sides": 3, "cap": false})
	var ring := []
	for i in 13:
		var a := TAU * i / 12.0
		ring.append(at + Vector3(cos(a) * 0.066, -0.03, sin(a) * 0.066))
	MeshKit.tube(st, ring, ring.map(func(_p): return 0.003), {"sides": 3, "cap": false})
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = Tex.mat("gunmetal", 1.0, {"tint": tint * Color(1.5, 1.5, 1.5)})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.add_child(mi)

## The meter cabinet, hanging open: three meters, a knot of wires, the cable running along the
## ceiling to the bulb.
static func _cabinet(f: Node3D, tint: Color) -> void:
	var grey := Tex.mat("metal", 2.0, {"tint": tint * Color(1.5, 1.7, 1.55)})
	var k := Tex.mat("black")
	var face := Tex.mat("enamel", 4.0, {"tint": tint})
	var c := Vector3(11.4, 1.75, 3.54)
	Build.box(f, c + Vector3(0, 0, -0.06), Vector3(0.7, 0.9, 0.02), k, false)
	for d in [[Vector3(-0.34, 0, 0), Vector3(0.02, 0.9, 0.16)], [Vector3(0.34, 0, 0), Vector3(0.02, 0.9, 0.16)],
			[Vector3(0, 0.44, 0), Vector3(0.7, 0.02, 0.16)], [Vector3(0, -0.44, 0), Vector3(0.7, 0.02, 0.16)]]:
		Build.box(f, c + d[0], d[1], grey, false)
	for i in 3:
		var m := c + Vector3(-0.2 + i * 0.2, 0.12, -0.02)
		Build.box(f, m, Vector3(0.13, 0.2, 0.08), k, false)
		Build.box(f, m + Vector3(0, 0.03, 0.041), Vector3(0.09, 0.05, 0.004), face, false)
	var door := Node3D.new(); f.add_child(door); door.position = c + Vector3(-0.35, 0, 0.08); door.rotation.y = 0.45
	var dm := Build.box(door, Vector3(0.35, 0, 0), Vector3(0.7, 0.9, 0.015), grey, false)
	var lb := Label3D.new(); lb.text = "ЩИТ  47-48"; lb.font_size = 26; lb.pixel_size = 0.0018; lb.shaded = true
	lb.modulate = Color("8a2a20") * tint; dm.add_child(lb); lb.position = Vector3(0, 0.3, 0.009)
	# wires: out of the top, up to the ceiling, along it to the bulb
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshKit.tube(st, [c + Vector3(0.1, 0.45, 0), Vector3(11.5, 2.79, 3.5), Vector3(11.7, 2.79, 4.4), Vector3(11.7, 2.79, 5.7)], [0.012, 0.012, 0.012, 0.012], {"sides": 4})
	MeshKit.tube(st, [c + Vector3(-0.1, 0.45, 0), Vector3(11.3, 2.79, 3.48), Vector3(10.4, 2.79, 3.48)], [0.009, 0.009, 0.009], {"sides": 4})
	for i in 4:
		MeshKit.tube(st, [c + Vector3(-0.2 + i * 0.13, 0.4, -0.02), c + Vector3(-0.1 + i * 0.05, -0.1 - i * 0.04, 0.08), c + Vector3(-0.15 + i * 0.1, -0.38, 0.0)], [0.005, 0.005, 0.005], {"sides": 3})
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = k; f.add_child(mi)

## The risers in the corner by 47: two pipes, floor to ceiling, rusty, clamped to the wall.
static func _pipes(f: Node3D, tint: Color) -> void:
	var rust := Tex.mat("metal", 3.0, {"tint": tint * Color(0.85, 0.6, 0.45)})
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in [[Vector3(10.32, 0, 3.52), 0.034], [Vector3(10.42, 0, 3.5), 0.022]]:
		var b: Vector3 = p[0]
		MeshKit.tube(st, [b, b + Vector3(0, 2.85, 0)], [p[1], p[1]], {"sides": 7, "bumps": 0.08})
		for y in [0.6, 2.2]:
			MeshKit.box(st, b + Vector3(0, y, -0.03), Vector3(p[1] * 2.6, 0.04, 0.04))
	MeshKit.box(st, Vector3(10.32, 1.1, 3.52), Vector3(0.09, 0.07, 0.09))
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = rust; f.add_child(mi)

## Bags, a bundle of newspapers, a dead plant: the corner by 48.
static func _rubbish(f: Node3D, tint: Color) -> void:
	var bag := Tex.mat("black", 1.0, {"tint": tint})
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshKit.blob(st, Vector3(13.95, 0.22, 7.7), Vector3(0.24, 0.24, 0.22), {"sag": 0.7, "bumps": 0.35, "seed": 3})
	MeshKit.blob(st, Vector3(13.55, 0.16, 7.78), Vector3(0.2, 0.17, 0.18), {"sag": 0.8, "bumps": 0.4, "seed": 9})
	MeshKit.blob(st, Vector3(13.95, 0.5, 7.7), Vector3(0.05, 0.08, 0.05), {"bumps": 0.5, "seed": 4})   # the knot
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = bag; f.add_child(mi)
	var news := Tex.mat("newspaper", 3.0, {"tint": tint * Color(0.85, 0.8, 0.7)})
	for i in 3:
		Build.box(f, Vector3(13.35, 0.06 + i * 0.1, 7.35), Vector3(0.42, 0.1, 0.3), news, false, 0.15 * i)
	Build.box(f, Vector3(13.35, 0.16, 7.35), Vector3(0.44, 0.31, 0.01), Tex.mat("cardboard", 2.0, {"tint": tint}), false, 0.15)
	# the plant, long dead, beside 48's door
	var pot := SurfaceTool.new(); pot.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshKit.tube(pot, [Vector3(11.55, 0, 7.75), Vector3(11.55, 0.28, 7.75)], [0.1, 0.13], {"sides": 8})
	pot.generate_normals()
	var pm := MeshInstance3D.new(); pm.mesh = pot.commit(); pm.material_override = Tex.mat("brass", 2.0, {"tint": tint * Color(1.1, 0.6, 0.45)}); f.add_child(pm)
	for i in 5:
		Build.box(f, Vector3(11.55 + (i - 2) * 0.03, 0.5, 7.75), Vector3(0.008, 0.45, 0.008), Tex.mat("wood", 4.0, {"tint": tint * Color(0.7, 0.6, 0.4)}), false, i * 0.6).rotation.z = (i - 2) * 0.25
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := BoxShape3D.new()
	sh.size = Vector3(1.1, 0.6, 0.75); cs.shape = sh; sb.add_child(cs); f.add_child(sb); sb.position = Vector3(13.7, 0.3, 7.6)

## Writing on the walls.
static func _graffiti(f: Node3D, tint: Color) -> void:
	# (the words themselves are to be written: placeholders until then)
	const P := ExportedFlat.PLACEHOLDER
	for g in [
			[P, Vector3(12.4, 1.05, 3.456), 0.0, -0.06, Color("1c1a18"), 40],        # north wall, facing south
			[P, Vector3(10.95, 1.35, 7.944), PI, 0.08, Color("d8d2c0"), 30],       # by 48, scratched
			[P, Vector3(10.486, 1.55, 5.75), PI * 0.5, -0.1, Color("6a2a1e"), 36],   # by 47
			[P, Vector3(10.486, 1.0, 7.0), PI * 0.5, 0.04, Color("4a4a50"), 22]]:      # in pencil
		var lb := Label3D.new(); lb.text = g[0]; lb.font_size = g[5]; lb.pixel_size = 0.0022
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; lb.width = 380.0
		lb.modulate = (g[4] as Color) * tint; lb.modulate.a = 0.85; lb.shaded = true; lb.outline_size = 0
		lb.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		f.add_child(lb); lb.position = g[1]; lb.rotation = Vector3(0, g[2], g[3])

## Grime along the skirting and round the doors, paint peeling off the whitewash, a stain on
## the ceiling over the well.
static func _decals(f: Node3D, tint: Color) -> void:
	var grime := _decal_mat("grime", tint)
	var peel := _decal_mat("peel", tint)
	# [texture, centre, size, the way the face looks]
	var list := [
		[grime, Vector3(11.2, 0.3, 3.46), Vector2(1.6, 0.6), Vector3.BACK],
		[grime, Vector3(12.6, 0.25, 3.46), Vector2(1.2, 0.5), Vector3.BACK],
		[grime, Vector3(11.3, 0.3, 7.94), Vector2(1.4, 0.6), Vector3.FORWARD],
		[grime, Vector3(10.49, 0.35, 6.6), Vector2(1.8, 0.7), Vector3.RIGHT],
		[grime, Vector3(10.49, 0.3, 3.8), Vector2(0.6, 0.6), Vector3.RIGHT],
		[grime, Vector3(13.08, 1.0, 5.6), Vector2(2.6, 0.4), Vector3.RIGHT],
		[peel, Vector3(12.9, 2.1, 3.46), Vector2(0.6, 0.45), Vector3.BACK],
		[peel, Vector3(10.49, 2.35, 6.1), Vector2(0.8, 0.5), Vector3.RIGHT],
		[peel, Vector3(10.49, 1.9, 7.2), Vector2(0.35, 0.3), Vector3.RIGHT],
		[peel, Vector3(11.9, 2.4, 7.94), Vector2(0.7, 0.5), Vector3.FORWARD],
		[peel, Vector3(14.24, 1.8, 7.5), Vector2(0.5, 0.4), Vector3.LEFT],
		[peel, Vector3(14.24, -1.2, 4.4), Vector2(0.9, 0.7), Vector3.LEFT],
	]
	for d in list:
		var q := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = d[2]; q.mesh = qm
		q.material_override = d[0]; q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.add_child(q); q.position = d[1]
		var n: Vector3 = d[3]
		var up := Vector3.UP if absf(n.y) < 0.5 else Vector3.FORWARD
		q.basis = Basis.looking_at(-n, up)

static func _decal_mat(tex_name: String, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_texture = Tex.tex(tex_name); m.albedo_color = tint
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR; m.alpha_scissor_threshold = 0.3
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS; m.roughness = 0.9
	return m

## A door's casing on the landing side: two jambs and a head.
static func _architrave(f: Node3D, centre: Vector3, w: float, h: float, facing: Vector3, m: Material) -> void:
	var along := Vector3(-facing.z, 0, facing.x)
	var z := facing * 0.012
	for s in [-1.0, 1.0]:
		var p: Vector3 = centre + along * s * (w * 0.5 + 0.035) + Vector3(0, h * 0.5 + 0.035, 0) + z
		Build.box(f, p, (along.abs() * 0.07 + Vector3(0, h + 0.07, 0) + facing.abs() * 0.025), m, false)
	Build.box(f, centre + Vector3(0, h + 0.035, 0) + z, along.abs() * (w + 0.14) + Vector3(0, 0.07, 0) + facing.abs() * 0.025, m, false)

## A doormat.
static func _mat(f: Node3D, at: Vector3, size: Vector2, c: Color) -> void:
	Build.box(f, at, Vector3(size.x, 0.012, size.y), Tex.mat("fabric", 6.0, {"tint": c * Color(2.2, 2.2, 2.2)}), false)
