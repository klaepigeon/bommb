class_name Interiors
## The three rooms in the labyrinth, behind open doors. Each tells part of who Marta was without
## a word said: you look at things, and some of them have a line of description when you do.
##
##   the séance salon (behind the photographer's): she was a psychic, and Rasputin's lover
##   the hotel room (ГОСТИНИЦА, off the square): she was Trickshot's lover
##   the nursery (the last izba): there was a child, Sonya, and her father walked away
##
## Rooms are built with the town's kit; their walls are solid and the door is the way in.

const SALON := {"x0": 14.0, "x1": 22.0, "z0": 24.32, "z1": 30.4, "y": 0.45, "h": 3.9, "door": ["n", 18.0, 1.3, 2.9]}
const HOTEL := {"x0": 52.32, "x1": 58.4, "z0": 34.6, "z1": 41.4, "y": 0.45, "h": 3.7, "door": ["w", 38.0, 1.3, 2.9]}
const NURSERY := {"x0": 6.2, "x1": 11.78, "z0": 59.6, "z1": 64.4, "y": 0.35, "h": 2.45, "door": ["e", 62.0, 1.1, 2.15]}

static func build(k: TownKit, owner: Node3D, colliders: StaticBody3D) -> Dictionary:
	var out := {}
	out["salon"] = _salon(k, owner, colliders)
	out["hotel"] = _hotel(k, owner, colliders)
	out["nursery"] = _nursery(k, owner, colliders)
	return out

# ---------------------------------------------------------------- a room
## floor, ceiling, four walls (one with the door), skirting, picture rail, cornice; solid walls
static func room(k: TownKit, colliders: StaticBody3D, r: Dictionary, wall: String, floor_mat: String, ceil_mat: String, trim := "trim") -> void:
	var x0: float = r.x0; var x1: float = r.x1; var z0: float = r.z0; var z1: float = r.z1
	var y: float = r.y; var h: float = r.h
	var d: Array = r.door
	k.quad(floor_mat, Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), Vector3.UP, Vector3(x0, y, z0))
	k.quad(ceil_mat, Vector3(x0, y + h, z1), Vector3(x1, y + h, z1), Vector3(x1, y + h, z0), Vector3(x0, y + h, z0), Vector3.DOWN, Vector3(x0, y + h, z0))
	# floor collision (the room is raised above the street)
	_solid(colliders, Vector3((x0 + x1) * 0.5, y - 0.25, (z0 + z1) * 0.5), Vector3((x1 - x0) * 0.5 + 0.3, 0.25, (z1 - z0) * 0.5 + 0.3))
	for side in ["n", "s", "e", "w"]:
		# each wall as a frame facing into the room
		var f: Facades.Frame
		var length: float
		match side:
			"n": f = Facades.Frame.new(Vector3(x1, y, z0), Vector3(-1, 0, 0), Vector3(0, 0, 1)); length = x1 - x0
			"s": f = Facades.Frame.new(Vector3(x0, y, z1), Vector3(1, 0, 0), Vector3(0, 0, -1)); length = x1 - x0
			"e": f = Facades.Frame.new(Vector3(x1, y, z1), Vector3(0, 0, -1), Vector3(-1, 0, 0)); length = z1 - z0
			"w": f = Facades.Frame.new(Vector3(x0, y, z0), Vector3(0, 0, 1), Vector3(1, 0, 0)); length = z1 - z0
		var has_door: bool = d[0] == side
		var dc := 0.0
		if has_door:
			# door centre along this wall, in the frame's x
			match side:
				"n": dc = x1 - float(d[1])
				"s": dc = float(d[1]) - x0
				"e": dc = z1 - float(d[1])
				"w": dc = float(d[1]) - z0
			var dw: float = d[2]; var dh: float = d[3]
			Facades.wall_hole(k, f, wall, 0, length, 0, h, dc - dw * 0.5, dc + dw * 0.5, 0.0, dh, 0.0, "", wall)
			Facades.bx(k, f, trim, dc - dw * 0.5 - 0.1, dc - dw * 0.5, 0, dh + 0.1, 0, 0.03)
			Facades.bx(k, f, trim, dc + dw * 0.5, dc + dw * 0.5 + 0.1, 0, dh + 0.1, 0, 0.03)
			Facades.bx(k, f, trim, dc - dw * 0.5 - 0.1, dc + dw * 0.5 + 0.1, dh, dh + 0.1, 0, 0.03)
		else:
			Facades.wall(k, f, wall, 0, length, 0, h)
		# skirting, a dado rail, a picture rail, a cornice; broken at the door
		for seg in ([[0.0, dc - d[2] * 0.5 - 0.1], [dc + d[2] * 0.5 + 0.1, length]] if has_door else [[0.0, length]]):
			if seg[1] - seg[0] < 0.01: continue
			Facades.bx(k, f, "paint_door", seg[0], seg[1], 0, 0.16, 0, 0.025, 16 | 4)
			Facades.bx(k, f, trim, seg[0], seg[1], 0.9, 0.94, 0, 0.02, 16 | 4 | 8)
		Facades.bx(k, f, trim, 0, length, h - 0.5, h - 0.47, 0, 0.015, 16 | 8)
		Facades.bx(k, f, trim, 0, length, h - 0.14, h, 0, 0.12, 16 | 8)
		# the wall, solid (a gap at the door)
		if has_door:
			var dw2: float = d[2]
			var left := dc - dw2 * 0.5; var right := length - (dc + dw2 * 0.5)
			_solid_f(colliders, f, left * 0.5, left * 0.5, h)
			_solid_f(colliders, f, dc + dw2 * 0.5 + right * 0.5, right * 0.5, h)
		else:
			_solid_f(colliders, f, length * 0.5, length * 0.5, h)

static func _solid_f(colliders: StaticBody3D, f: Facades.Frame, cx: float, half: float, h: float) -> void:
	if half < 0.02: return
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(half * 2.0, h + 1.0, 0.3)
	cs.shape = b; cs.position = f.p(cx, h * 0.5, -0.15); cs.basis = f.basis()
	colliders.add_child(cs)

static func _solid(colliders: StaticBody3D, at: Vector3, half: Vector3, yaw := 0.0) -> void:
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = half * 2.0
	cs.shape = b; cs.position = at; cs.rotation.y = yaw
	colliders.add_child(cs)

static func examine(owner: Node3D, at: Vector3, half: Vector3, title: String, desc: String) -> StaticBody3D:
	var sb := StaticBody3D.new(); sb.set_script(load("res://scripts/labyrinth/examine.gd"))
	sb.set("title", title); sb.set("desc", desc)
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = half * 2.0; cs.shape = b; sb.add_child(cs)
	owner.add_child(sb); sb.position = at
	return sb

static func picture(owner: Node3D, tex: Texture2D, at: Vector3, normal: Vector3, size: Vector2, frame_mat: Material) -> void:
	var q := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = size; q.mesh = qm
	var m := StandardMaterial3D.new(); m.albedo_texture = tex; m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness = 0.6
	q.material_override = m
	owner.add_child(q)
	var up := Vector3.UP if absf(normal.y) < 0.9 else Vector3.FORWARD
	q.transform = Transform3D(Basis.looking_at(-normal, up), at + normal * 0.012)
	# the frame: four mouldings
	var fr := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(size.x + 0.1, size.y + 0.1, 0.02); fr.mesh = bm
	fr.material_override = frame_mat; owner.add_child(fr)
	fr.transform = Transform3D(Basis.looking_at(-normal, up), at + normal * 0.002)

# ---------------------------------------------------------------- the salon
static func _salon(k: TownKit, owner: Node3D, colliders: StaticBody3D) -> Dictionary:
	var r := SALON
	room(k, colliders, r, "wallpaper_red", "parquet", "plaster_in")
	var y: float = r.y
	var c := Vector3(18.0, y, 27.6)
	# a Turkey rug under a round table with a fringed cloth; six chairs, two of them in the air
	k.quad("rug", c + Vector3(-1.7, 0.006, -1.3), c + Vector3(1.7, 0.006, -1.3), c + Vector3(1.7, 0.006, 1.3), c + Vector3(-1.7, 0.006, 1.3), Vector3.UP, c + Vector3(-1.7, 0, -1.3))
	k.cyl("cloth_dark", c, 0.7, 0.74, 16, 0.62)            # the cloth falls to the floor
	k.cyl("cloth_dark", c + Vector3(0, 0.74, 0), 0.62, 0.02, 16, 0.62)
	_solid(colliders, c + Vector3(0, 0.37, 0), Vector3(0.62, 0.37, 0.62))
	var orbit := Node3D.new(); orbit.name = "Orbit"; owner.add_child(orbit); orbit.position = c + Vector3(0, 1.9, 0)
	orbit.set_script(load("res://scripts/labyrinth/slow_spin.gd"))
	var floating := TownKit.new(orbit)
	for i in 6:
		var a := TAU * i / 6.0
		var p := c + Vector3(cos(a), 0, sin(a)) * 1.05
		if i == 1 or i == 4:
			# these two have lifted: up off the floor and turning slowly round the table
			var lp := Vector3(cos(a), 0, sin(a)) * 1.25 + Vector3(0, -0.4 + i * 0.1, 0)
			_chair_simple(floating, lp, Basis(Vector3.UP, -a + PI * 0.5) * Basis(Vector3(1, 0, 0), 0.3 * (i - 2)))
		else:
			_chair_simple(k, p, Basis(Vector3.UP, -a + PI * 0.5))
	# tea things on the table; two cups and a saucer up in the air with the chairs
	for i in 3:
		var a := TAU * i / 3.0 + 0.4
		k.cyl("china", c + Vector3(cos(a) * 0.32, 0.76, sin(a) * 0.32), 0.07, 0.008, 10, 0.07)
		k.cyl("china", c + Vector3(cos(a) * 0.32, 0.768, sin(a) * 0.32), 0.035, 0.06, 8, 0.042)
	for i in 3:
		var a := TAU * i / 3.0 + 1.2
		floating.cyl("china", Vector3(cos(a) * 0.7, 0.2 + i * 0.15, sin(a) * 0.7), 0.035, 0.06, 8, 0.042)
	floating.finish()
	# candles on the table, the crystal ball between them, faintly lit from inside
	for i in 3:
		var a := TAU * i / 3.0 + 1.0
		var cp := c + Vector3(cos(a) * 0.4, 0.76, sin(a) * 0.4)
		k.cyl("trim", cp, 0.035, 0.03, 8, 0.03)
		k.cyl("wax", cp + Vector3(0, 0.03, 0), 0.016, 0.16 - i * 0.03, 6, 0.016)
		k.box("flame", cp + Vector3(0, 0.21 - i * 0.03, 0), Vector3(0.008, 0.018, 0.008))
	k.cyl("iron", c + Vector3(0, 0.76, 0), 0.06, 0.04, 8, 0.05)
	var ball := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.11; sm.height = 0.22; sm.radial_segments = 12; sm.rings = 6
	ball.mesh = sm
	var bm := StandardMaterial3D.new(); bm.albedo_color = Color(0.55, 0.6, 0.8, 0.55); bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.roughness = 0.05; bm.metallic = 0.2; bm.emission_enabled = true; bm.emission = Color(0.35, 0.3, 0.6); bm.emission_energy_multiplier = 0.8
	ball.material_override = bm; owner.add_child(ball); ball.position = c + Vector3(0, 0.91, 0)
	var candle := OmniLight3D.new(); candle.name = "Candles"; candle.light_color = Color(1.0, 0.72, 0.42); candle.light_energy = 1.6
	candle.omni_range = 5.5; candle.omni_attenuation = 1.3; candle.shadow_enabled = false
	candle.set_script(load("res://scripts/labyrinth/candle_light.gd"))
	owner.add_child(candle); candle.position = c + Vector3(0, 1.05, 0)
	# two oil sconces either side of the portrait, turned low
	for sx in [16.4, 19.6]:
		var sc := Vector3(sx, y + 2.0, 30.3)
		k.box("gold", sc + Vector3(0, -0.1, -0.03), Vector3(0.05, 0.08, 0.04))
		k.cyl("lamp_glass", sc + Vector3(0, -0.02, -0.08), 0.045, 0.16, 8, 0.03)
		var sl := OmniLight3D.new(); sl.light_color = Color(1.0, 0.7, 0.4); sl.light_energy = 1.1; sl.omni_range = 4.0
		sl.omni_attenuation = 1.3; sl.set_script(load("res://scripts/labyrinth/candle_light.gd"))
		owner.add_child(sl); sl.position = sc + Vector3(0, 0.1, -0.15)
	var glow := OmniLight3D.new(); glow.light_color = Color(0.55, 0.5, 1.0); glow.light_energy = 0.5; glow.omni_range = 1.4
	owner.add_child(glow); glow.position = c + Vector3(0, 0.95, 0)
	# heavy curtains on the side walls, a painted studio backdrop on the back wall (a garden, a
	# balustrade: this was the photographer's), his camera on its tripod under a black cloth
	for z in [25.2, 29.4]:
		for side in [14.03, 21.97]:
			_curtain(k, Vector3(side, y, z), Vector3(1 if side < 18 else -1, 0, 0), 0.9, r.h - 0.2)
	k.quad("backdrop", Vector3(15.0, y + 0.05, 30.38), Vector3(21.0, y + 0.05, 30.38), Vector3(21.0, y + 3.1, 30.38), Vector3(15.0, y + 3.1, 30.38), Vector3(0, 0, -1))
	k.cyl_axis("wood", Vector3(14.95, y + 3.15, 30.33), Vector3(21.05, y + 3.15, 30.33), 0.025, 6)
	var cam_at := Vector3(15.3, y, 25.4)
	for i in 3:
		var a := TAU * i / 3.0
		k.cyl_axis("wood", cam_at + Vector3(cos(a) * 0.32, 0, sin(a) * 0.32), cam_at + Vector3(0, 1.25, 0), 0.015, 5)
	k.box("wood", cam_at + Vector3(0, 1.38, 0), Vector3(0.16, 0.14, 0.2), Basis(Vector3.UP, 0.6))
	k.cyl_axis("gold", cam_at + Vector3(0.12, 1.38, 0.13), cam_at + Vector3(0.2, 1.38, 0.22), 0.05, 10)
	k.box("cloth_dark", cam_at + Vector3(-0.08, 1.4, -0.1), Vector3(0.22, 0.2, 0.18), Basis(Vector3.UP, 0.6))
	_solid(colliders, cam_at + Vector3(0, 0.7, 0), Vector3(0.3, 0.7, 0.3))
	# a chaise longue by the wall, a potted palm, a little table with the paper on it
	_chaise(k, Vector3(20.6, y, 26.0))
	_solid(colliders, Vector3(20.6, y + 0.3, 26.0), Vector3(0.35, 0.3, 0.9))
	k.cyl("brick", Vector3(21.3, y, 29.6), 0.18, 0.4, 8, 0.22)
	for i in 7:
		var a := TAU * i / 7.0
		k.quad("leaf_green", Vector3(21.3, y + 0.4, 29.6), Vector3(21.3, y + 0.4, 29.6) + Vector3(cos(a) * 0.1, 0.3, sin(a) * 0.1), Vector3(21.3, y + 0.4, 29.6) + Vector3(cos(a) * 0.55, 0.9, sin(a) * 0.55), Vector3(21.3, y + 0.4, 29.6) + Vector3(cos(a + 0.3) * 0.5, 0.6, sin(a + 0.3) * 0.5), Vector3.UP)
	# the photograph: a studio portrait over the table, in a gilt frame
	var gilt := k.material("gold")
	picture(owner, RomanovPortraits.rasputin(), Vector3(18.0, y + 1.85, 30.2), Vector3(0, 0, -1), Vector2(0.62, 0.8), gilt)
	examine(owner, Vector3(18.0, y + 1.85, 30.15), Vector3(0.36, 0.45, 0.06), "Photograph", "A studio portrait, taken in this room against that garden. A big man in a peasant's shirt and a long black coat, beard to his chest, his hand resting on the head of a young woman who isn't looking at the camera. You know her face. You've seen it at a table upstairs. Not this young.")
	# his note, on the table, under a candlestick
	k.box("paper", c + Vector3(0.12, 0.762, -0.18), Vector3(0.1, 0.002, 0.07), Basis(Vector3.UP, 0.3))
	examine(owner, c + Vector3(0.12, 0.8, -0.18), Vector3(0.12, 0.05, 0.1), "Note", "In a big, uneven hand, in pencil, the spelling bad: \"My swallow. They say I am not to come to you any more, that you see too much. Let them talk. You saw the river before I did. You told me first. — G.\"").set("more", "The folds are hers: small enough to carry in a glove. She carried it for years. She had it on her the night you met her; you remember the glove.")
	# and the newspaper on the floor, by the chaise
	k.box("paper", Vector3(19.9, y + 0.006, 26.9), Vector3(0.26, 0.003, 0.19), Basis(Vector3.UP, -0.4))
	examine(owner, Vector3(19.9, y + 0.05, 26.9), Vector3(0.3, 0.05, 0.24), "Newspaper", "Petrograd, the nineteenth of December, 1916. A body recovered from the ice of the Malaya Nevka has been identified as that of Grigori Efimovich Rasputin. Someone has folded it so that's the only thing showing.").set("more", "In the margin, in pencil, in a woman's hand you know: two words. «Told him.»")
	return {"centre": c}

# ---------------------------------------------------------------- the hotel room
static func _hotel(k: TownKit, owner: Node3D, colliders: StaticBody3D) -> Dictionary:
	var r := HOTEL
	room(k, colliders, r, "wallpaper_damask", "parquet", "plaster_in")
	var y: float = r.y
	# a brass bed, slept in, the sheets thrown back
	var bed := Vector3(56.6, y, 36.4)
	k.box("cloth_white", bed + Vector3(0, 0.45, 0), Vector3(0.75, 0.1, 1.0))
	k.box("cloth_white", bed + Vector3(0.0, 0.58, 0.55), Vector3(0.72, 0.05, 0.42), Basis(Vector3.RIGHT, 0.08))
	k.box("cloth_dark", bed + Vector3(-0.15, 0.6, -0.15), Vector3(0.62, 0.06, 0.55), Basis.from_euler(Vector3(0.05, 0.3, 0.06)))
	for px in [-0.32, 0.32]:
		k.box("cloth_white", bed + Vector3(px, 0.62, -0.82), Vector3(0.28, 0.07, 0.16))
	for corner in [[-0.78, -1.02], [0.78, -1.02], [-0.78, 1.02], [0.78, 1.02]]:
		k.cyl("gold", bed + Vector3(corner[0], 0, corner[1]), 0.025, 1.25 if corner[1] < 0 else 0.85, 6, 0.025)
	for i in 6:
		k.cyl_axis("gold", bed + Vector3(-0.78 + i * 0.31, 0.4, -1.02), bed + Vector3(-0.78 + i * 0.31, 1.2, -1.02), 0.01, 5)
	k.cyl_axis("gold", bed + Vector3(-0.78, 1.22, -1.02), bed + Vector3(0.78, 1.22, -1.02), 0.02, 6)
	_solid(colliders, bed + Vector3(0, 0.35, 0), Vector3(0.8, 0.35, 1.05))
	# the nightstand: a lamp, two glasses, one with lipstick on it, an ashtray
	var ns := Vector3(55.55, y, 35.2)
	k.box("wood", ns + Vector3(0, 0.32, 0), Vector3(0.22, 0.32, 0.22))
	k.cyl("china", ns + Vector3(0.08, 0.64, 0.06), 0.06, 0.03, 8, 0.03)
	k.cyl_axis("iron", ns + Vector3(0.08, 0.67, 0.06), ns + Vector3(0.08, 0.95, 0.06), 0.008, 5)
	k.cyl("lampshade", ns + Vector3(0.08, 0.92, 0.06), 0.13, 0.16, 10, 0.07)
	for gi in 2:
		var gp := ns + Vector3(-0.08 + gi * 0.1, 0.64, -0.08)
		k.cyl("glass", gp, 0.03, 0.09, 8, 0.035)
		if gi == 1: k.cyl("lipstick", gp + Vector3(0, 0.085, 0), 0.036, 0.008, 8, 0.036)
	k.cyl("glass", ns + Vector3(0.1, 0.64, -0.12), 0.05, 0.015, 8, 0.05)
	var lamp := OmniLight3D.new(); lamp.light_color = Color(1.0, 0.78, 0.5); lamp.light_energy = 2.0; lamp.omni_range = 6.0
	lamp.omni_attenuation = 1.2; owner.add_child(lamp); lamp.position = ns + Vector3(0.08, 0.95, 0.06)
	# a glass ceiling bowl, on, dim
	var cb := Vector3(55.4, y + r.h - 0.35, 38.0)
	k.cyl_axis("iron", cb + Vector3(0, 0.12, 0), cb + Vector3(0, 0.35, 0), 0.01, 4)
	k.cyl("lampshade", cb, 0.22, 0.12, 12, 0.12)
	var cl := OmniLight3D.new(); cl.light_color = Color(1.0, 0.85, 0.65); cl.light_energy = 1.0; cl.omni_range = 6.5
	owner.add_child(cl); cl.position = cb + Vector3(0, -0.1, 0)
	examine(owner, ns + Vector3(0, 0.72, -0.08), Vector3(0.14, 0.08, 0.1), "Glasses", "Two glasses. One has a half-moon of lipstick on the rim, the dark red of a woman going out in the evening. The other has been drunk from by a man who held it by the bowl, not the stem.")
	# a chair by the window with a quiver hung over its back: leather, worn smooth, arrows in it
	var ch := Vector3(53.6, y, 40.2)
	_chair_simple(k, ch, Basis(Vector3.UP, 2.4))
	_solid(colliders, ch + Vector3(0, 0.45, 0), Vector3(0.25, 0.45, 0.25))
	var qb := Basis(Vector3.UP, 2.4) * Basis(Vector3.RIGHT, -0.25)
	var qp := ch + Vector3(0, 0.85, 0) + Basis(Vector3.UP, 2.4) * Vector3(0, 0, -0.22)
	k.cyl_axis("leather", qp - qb.y * 0.32, qp + qb.y * 0.28, 0.06, 8, 0.07)
	for i in 5:
		var off := qb.x * (i - 2) * 0.022 + qb.z * ((i % 2) * 0.02 - 0.01)
		k.cyl_axis("trim", qp + qb.y * 0.2 + off, qp + qb.y * 0.48 + off, 0.004, 4)
		k.box("awning_red" if i % 2 == 0 else "awning_white", qp + qb.y * 0.45 + off, Vector3(0.002, 0.05, 0.015), qb)
	examine(owner, qp, Vector3(0.12, 0.3, 0.12), "Quiver", "A leather quiver, worn smooth where a shoulder carried it. The arrows in it have heads no shop ever sold. Your right hand goes to them before you've decided to touch them.")
	# the mirror over the washstand, a strip of photo-booth pictures tucked in its frame
	var ws := Vector3(52.55, y, 37.0)
	k.box("wood", ws + Vector3(0.22, 0.4, 0), Vector3(0.22, 0.4, 0.4))
	k.cyl("china", ws + Vector3(0.24, 0.8, 0), 0.18, 0.06, 12, 0.12)
	_solid(colliders, ws + Vector3(0.22, 0.4, 0), Vector3(0.24, 0.4, 0.42))
	var mir := MeshInstance3D.new(); var mq := QuadMesh.new(); mq.size = Vector2(0.55, 0.75); mir.mesh = mq
	var mm := StandardMaterial3D.new(); mm.albedo_color = Color(0.15, 0.17, 0.2); mm.metallic = 0.9; mm.roughness = 0.12
	mir.material_override = mm; owner.add_child(mir)
	mir.transform = Transform3D(Basis.looking_at(Vector3(-1, 0, 0), Vector3.UP).rotated(Vector3.UP, PI), ws + Vector3(0.015, 1.55, 0))
	picture(owner, RomanovPortraits.photobooth(), ws + Vector3(0.02, 1.62, 0.33), Vector3(1, 0, 0), Vector2(0.06, 0.22), k.material("paper"))
	examine(owner, ws + Vector3(0.05, 1.6, 0.3), Vector3(0.05, 0.14, 0.06), "Photo strip", "Four frames from a booth, the kind they had at railway stations in the sixties. A man in a black domino mask and a woman with dark hair, laughing. In the third frame she's kissing his cheek. In the last one neither of them is laughing, and she's looking straight into the lens.").set("more", "On the back, in her hand: «T. and me. The last good night.» The T is the way she always made it, with the little hook. You'd forgotten you knew that.")
	# a suitcase on the stand, open, a man's things and a woman's mixed in it
	var sc := Vector3(57.6, y, 40.5)
	k.box("leather", sc + Vector3(0, 0.25, 0), Vector3(0.36, 0.1, 0.24))
	k.box("leather", sc + Vector3(0, 0.45, -0.24), Vector3(0.36, 0.22, 0.02), Basis(Vector3.RIGHT, -0.25))
	k.box("cloth_white", sc + Vector3(-0.1, 0.36, 0.02), Vector3(0.14, 0.02, 0.18))
	k.box("awning_red", sc + Vector3(0.12, 0.37, 0.0), Vector3(0.16, 0.025, 0.16))
	_solid(colliders, sc + Vector3(0, 0.25, 0), Vector3(0.38, 0.25, 0.28))
	# lace at the window (the window looks out on nothing: black)
	k.quad("glass", Vector3(58.38, y + 1.0, 36.0), Vector3(58.38, y + 1.0, 37.4), Vector3(58.38, y + 2.9, 37.4), Vector3(58.38, y + 2.9, 36.0), Vector3(-1, 0, 0))
	k.quad("lace", Vector3(58.33, y + 0.9, 35.9), Vector3(58.33, y + 0.9, 37.5), Vector3(58.33, y + 3.0, 37.5), Vector3(58.33, y + 3.0, 35.9), Vector3(-1, 0, 0))
	return {}

# ---------------------------------------------------------------- the nursery
static func _nursery(k: TownKit, owner: Node3D, colliders: StaticBody3D) -> Dictionary:
	var r := NURSERY
	room(k, colliders, r, "wood", "planks", "wood", "wood")
	var y: float = r.y; var h: float = r.h
	# ceiling beams
	for i in 4:
		var x := 7.0 + i * 1.4
		k.box("wood", Vector3(x, y + h - 0.1, 62.0), Vector3(0.09, 0.1, 2.4))
	# the stove: whitewashed brick, a ledge to sleep on, a dark mouth
	var st := Vector3(7.0, y, 60.5)
	k.box("whitewash", st + Vector3(0, 0.9, 0), Vector3(0.75, 0.9, 0.85))
	k.box("whitewash", st + Vector3(0, 1.9, -0.1), Vector3(0.6, 0.12, 0.7))
	k.box("iron", st + Vector3(0.76, 0.55, 0.1), Vector3(0.01, 0.2, 0.25))
	_solid(colliders, st + Vector3(0, 0.9, 0), Vector3(0.78, 0.9, 0.88))
	# the icon corner: a small icon on a shelf, a red lamp burning under it
	var ic := Vector3(11.7, y + 1.85, 59.75)
	k.box("wood", ic + Vector3(-0.15, -0.25, 0.15), Vector3(0.2, 0.02, 0.2))
	picture(owner, RomanovPortraits.icon(), ic + Vector3(-0.05, 0.0, 0.05), Vector3(-0.7, 0, 0.7).normalized(), Vector2(0.22, 0.28), k.material("gold"))
	k.cyl("lampada", ic + Vector3(-0.15, -0.23, 0.15), 0.03, 0.06, 8, 0.04)
	var lamp := OmniLight3D.new(); lamp.name = "Lampada"; lamp.light_color = Color(1.0, 0.35, 0.25); lamp.light_energy = 0.9
	lamp.omni_range = 4.0; lamp.omni_attenuation = 1.2; lamp.set_script(load("res://scripts/labyrinth/candle_light.gd"))
	owner.add_child(lamp); lamp.position = ic + Vector3(-0.15, -0.12, 0.15)
	# the cradle: a basket hung from the beam on a springy pole, rocking by itself, slowly
	var cradle := Node3D.new(); cradle.name = "Cradle"; owner.add_child(cradle)
	cradle.position = Vector3(9.4, y + h - 0.2, 62.0)
	cradle.set_script(load("res://scripts/labyrinth/rock.gd"))
	var ck := TownKit.new(cradle)
	for cx in [-0.32, 0.32]:
		for cz in [-0.2, 0.2]:
			ck.cyl_axis("rope", Vector3(0, 0, 0), Vector3(cx, -1.05, cz), 0.006, 4)
	ck.box("wicker", Vector3(0, -1.2, 0), Vector3(0.35, 0.14, 0.22))
	ck.box("cloth_white", Vector3(0, -1.08, 0.03), Vector3(0.3, 0.03, 0.18))
	ck.box("cloth_white", Vector3(0.0, -1.06, -0.12), Vector3(0.13, 0.04, 0.06))
	ck.finish()
	# her drawings, pinned to the logs; the one of MAMA and a man with a bow walking off the paper
	var draw_at := Vector3(10.4, y + 1.35, 64.38)
	picture(owner, RomanovPortraits.drawing(), draw_at, Vector3(0, 0, -1), Vector2(0.42, 0.3), k.material("paper"))
	examine(owner, draw_at + Vector3(0, 0, -0.04), Vector3(0.24, 0.17, 0.05), "Drawing", "Wax crayon. MAMA, big, in a red dress, a crown of black hair. A girl holding her hand. And right at the edge of the paper, small, a man with a bow on his back, walking off it. He has no face. She drew him the size you draw things that are far away.").set("more", "On the back, in Marta's hand, small, along the bottom edge: «She asked me where he went. I said far.»")
	picture(owner, RomanovPortraits.drawing2(), draw_at + Vector3(-1.1, 0.15, 0), Vector3(0, 0, -1), Vector2(0.3, 0.3), k.material("paper"))
	# the letters to Papa on the sill, never posted; the register on the table
	var sill := Vector3(8.0, y + 0.9, 64.3)
	k.box("wood", sill, Vector3(0.5, 0.03, 0.08))
	for i in 6:
		k.box("paper", sill + Vector3(-0.3 + i * 0.02, 0.04 + i * 0.012, 0.0), Vector3(0.1, 0.006, 0.065), Basis(Vector3.UP, 0.1 * (i - 3)))
	examine(owner, sill + Vector3(-0.22, 0.08, 0), Vector3(0.16, 0.08, 0.1), "Letters", "Envelopes in a child's printing, a stamp on every one. All of them to PAPA. No street, no city. None of them were ever posted, and none of them are open.").set("more", "The P of PAPA is made the way you make yours: a loop at the top, and a tail. Somebody showed her how. You showed her how.")
	var tb := Vector3(10.6, y, 60.6)
	k.box("wood", tb + Vector3(0, 0.38, 0), Vector3(0.5, 0.025, 0.35))
	for lx in [-0.44, 0.44]:
		for lz in [-0.3, 0.3]:
			k.box("wood", tb + Vector3(lx, 0.18, lz), Vector3(0.03, 0.18, 0.03))
	k.box("paper", tb + Vector3(0.05, 0.415, 0), Vector3(0.18, 0.012, 0.13), Basis(Vector3.UP, -0.2))
	k.box("leather", tb + Vector3(0.05, 0.405, 0), Vector3(0.19, 0.008, 0.14), Basis(Vector3.UP, -0.2))
	_solid(colliders, tb + Vector3(0, 0.2, 0), Vector3(0.52, 0.2, 0.37))
	# a kerosene lamp on the table, turned down
	var kl := tb + Vector3(-0.3, 0.4, 0.15)
	k.cyl("gold", kl, 0.06, 0.05, 8, 0.04)
	k.cyl("lamp_glass", kl + Vector3(0, 0.05, 0), 0.035, 0.14, 8, 0.025)
	var klight := OmniLight3D.new(); klight.light_color = Color(1.0, 0.72, 0.42); klight.light_energy = 1.7; klight.omni_range = 5.0
	klight.omni_attenuation = 1.2; klight.set_script(load("res://scripts/labyrinth/candle_light.gd"))
	owner.add_child(klight); klight.position = kl + Vector3(0, 0.2, 0)
	examine(owner, tb + Vector3(0.05, 0.45, 0), Vector3(0.2, 0.06, 0.15), "Register", "A parish birth register, open. SOPHIA — SONYA, in brackets, in another hand. Mother: Marta Sokolova. Father: written in, crossed out, written again and crossed out again, until the pen went through the page.").set("more", "Under the crossings-out you can still make out the first two letters of the first try. A K, and an F. Her hand. She wrote you in, and then she couldn't leave you there.")
	# a rag doll on the floor by the stove
	k.box("cloth_white", Vector3(7.9, y + 0.05, 61.6), Vector3(0.08, 0.05, 0.12), Basis(Vector3.UP, 0.8))
	k.box("awning_red", Vector3(7.9, y + 0.06, 61.72), Vector3(0.05, 0.05, 0.05), Basis(Vector3.UP, 0.8))
	# and the inner door, low down on it, scratched into the paint at a child's height: СОНЯ
	var dr := Vector3(6.21, y, 63.2)
	var df := Facades.Frame.new(dr + Vector3(0, 0, 0.5), Vector3(0, 0, -1), Vector3(1, 0, 0))
	Facades.bx(k, df, "paint_door", 0.05, 0.95, 0.0, 2.0, 0.0, 0.05)
	Facades.bx(k, df, "wood", -0.05, 0.05, 0.0, 2.1, 0.0, 0.07)
	Facades.bx(k, df, "wood", 0.95, 1.05, 0.0, 2.1, 0.0, 0.07)
	Facades.bx(k, df, "wood", -0.05, 1.05, 2.0, 2.1, 0.0, 0.07)
	k.box("iron", dr + Vector3(0.07, 1.0, 0.0), Vector3(0.02, 0.02, 0.06))
	var scratch := Label3D.new(); scratch.text = "СОНЯ"; scratch.font_size = 40; scratch.pixel_size = 0.0035
	scratch.modulate = Color(0.75, 0.72, 0.65); scratch.shaded = true; scratch.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	owner.add_child(scratch)
	scratch.transform = Transform3D(Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0)).rotated(Vector3(1, 0, 0), 0.08), dr + Vector3(0.06, 0.62, 0.0))
	var door := StaticBody3D.new(); door.set_script(load("res://scripts/labyrinth/sonya_door.gd"))
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(0.12, 2.0, 0.9); cs.shape = b; door.add_child(cs)
	owner.add_child(door); door.position = dr + Vector3(0.06, 1.0, 0.0)
	# the music box on the shelf by the door: it plays when you come in
	var mb := Vector3(6.5, y + 1.25, 60.2)
	k.box("wood", mb + Vector3(0, -0.06, 0), Vector3(0.25, 0.02, 0.14))
	k.box("paint_door", mb + Vector3(0, 0.0, 0), Vector3(0.07, 0.04, 0.05))
	var music := AudioStreamPlayer3D.new(); music.name = "MusicBox"; music.stream = RomanovPortraits.lullaby()
	music.unit_size = 2.0; music.max_distance = 9.0; music.volume_db = -8.0; music.autoplay = true
	owner.add_child(music); music.position = mb
	return {"door": dr}

# ---------------------------------------------------------------- furniture
static func _chair_simple(k: TownKit, at: Vector3, b: Basis) -> void:
	k.box("wood", at + b * Vector3(0, 0.45, 0), Vector3(0.21, 0.025, 0.2), b)
	for lx in [-0.17, 0.17]:
		for lz in [-0.16, 0.16]:
			k.box("wood", at + b * Vector3(lx, 0.22, lz), Vector3(0.018, 0.22, 0.018), b)
	for lx in [-0.17, 0.17]:
		k.box("wood", at + b * Vector3(lx, 0.72, -0.17), Vector3(0.018, 0.27, 0.018), b)
	k.box("wood", at + b * Vector3(0, 0.9, -0.17), Vector3(0.19, 0.06, 0.015), b)
	k.box("wood", at + b * Vector3(0, 0.66, -0.17), Vector3(0.17, 0.02, 0.012), b)

static func _chaise(k: TownKit, at: Vector3) -> void:
	k.box("velvet", at + Vector3(0, 0.32, 0), Vector3(0.32, 0.1, 0.85))
	k.box("velvet", at + Vector3(0.22, 0.62, -0.5), Vector3(0.1, 0.3, 0.35), Basis(Vector3(0, 0, 1), 0.25))
	for lz in [-0.75, 0.75]:
		for lx in [-0.26, 0.26]:
			k.cyl("wood", at + Vector3(lx, 0, lz), 0.025, 0.22, 6, 0.02)

static func _curtain(k: TownKit, at: Vector3, into: Vector3, width: float, h: float) -> void:
	# folds: a row of tall panels at alternating depths
	var along := into.cross(Vector3.UP).normalized()
	const N := 8
	for i in N:
		var x0 := (float(i) / N - 0.5) * width; var x1 := (float(i + 1) / N - 0.5) * width
		var d0 := 0.04 + 0.05 * (i % 2); var d1 := 0.04 + 0.05 * ((i + 1) % 2)
		k.quad("velvet", at + along * x0 + into * d0, at + along * x1 + into * d1, at + along * x1 + into * d1 + Vector3(0, h, 0), at + along * x0 + into * d0 + Vector3(0, h, 0), into)
	k.cyl_axis("gold", at + along * (-width * 0.6) + into * 0.1 + Vector3(0, h + 0.02, 0), at + along * (width * 0.6) + into * 0.1 + Vector3(0, h + 0.02, 0), 0.015, 6)
