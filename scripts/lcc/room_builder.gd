class_name RoomBuilder
extends RefCounted
## The furniture in a room off the hall, from its data (data/hall/rooms.json).

## The furniture of a room, in the room's own frame (front wall, with the door, at +z).
## The shell (walls with the door hole, floor, ceiling) and the lamp come from WorldView.
static func build_contents(room: Dictionary, index: int, xf: Transform3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Contents_" + room["id"]
	root.transform = xf
	var mb := MB.new()
	for p in room.get("props", []):
		_prop(mb, p, index)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	root.add_child(mi)
	return root

static func _c(p: Dictionary) -> Color:
	return Color(p.get("color", "#6a6a60"))

static func _prop(mb: MB, p: Dictionary, index: int) -> void:
	var at: Array = p.get("at", [0, 0])
	var x := float(at[0])
	var z := float(at[1])
	var y := float(p.get("y", 0.0))
	var size: Array = p.get("size", [0.6, 0.6, 0.6])
	var sx := float(size[0])
	var sy := float(size[1]) if size.size() > 1 else 0.6
	var sz := float(size[2]) if size.size() > 2 else 0.6
	var col := _c(p)
	var m := MB.mat(Tex.grime(col.darkened(0.25), col, 32, index * 7 + int(x * 10) + 3, 0.12, 0.15))
	match p.get("kind", "box"):
		"box":
			mb.box(col.to_html(), m, Vector3(sx, sy, sz), MB.T(Vector3(x, y + sy / 2, z)), Color(1, 1, 1), 1.0)
		"cyl":
			mb.cyl(col.to_html(), m, float(p.get("r", 0.3)), float(p.get("r", 0.3)), float(p.get("h", 0.5)), 8, MB.T(Vector3(x, y, z)), Color(1, 1, 1))
		"barrel":
			var r := float(p.get("r", 0.4))
			var hh := float(p.get("h", 1.0))
			mb.cyl(col.to_html(), m, r * 0.85, r, hh / 2, 8, MB.T(Vector3(x, y, z)), Color(1, 1, 1), false)
			mb.cyl(col.to_html(), m, r, r * 0.85, hh / 2, 8, MB.T(Vector3(x, y + hh / 2, z)), Color(1, 1, 1))
			var hoop := MB.mat(Tex.solid(Color("3a3a36")))
			for k in [0.15, 0.5, 0.85]:
				mb.ring("h", hoop, r * (0.9 + 0.1 * (1.0 - absf(k - 0.5) * 2.0)), 0.02, 10, MB.T(Vector3(x, y + hh * k, z)), Color(1, 1, 1))
		"shelf":
			for k in range(4):
				mb.box(col.to_html(), m, Vector3(sx, 0.04, sz), MB.T(Vector3(x, y + 0.4 + k * sy / 4.0, z)), Color(1, 1, 1))
			var rr := RandomNumberGenerator.new()
			rr.seed = index * 31 + 7
			for k in range(14):
				var jar := MB.mat(Tex.solid(Color.from_hsv(rr.randf(), 0.4, 0.5)))
				mb.cyl("j%d" % (k % 4), jar, 0.05, 0.05, 0.14, 6, MB.T(Vector3(x - sx / 2 + 0.15 + (k % 7) * sx / 7.5, y + 0.42 + (k / 7) * sy / 4.0, z)), Color(1, 1, 1))
		"rail":
			mb.box(col.to_html(), m, Vector3(sx, 0.04, 0.04), MB.T(Vector3(x, y + sy, z)), Color(1, 1, 1))
			mb.box(col.to_html(), m, Vector3(0.05, sy, 0.05), MB.T(Vector3(x - sx / 2, y + sy / 2, z)), Color(1, 1, 1))
			mb.box(col.to_html(), m, Vector3(0.05, sy, 0.05), MB.T(Vector3(x + sx / 2, y + sy / 2, z)), Color(1, 1, 1))
			var rr2 := RandomNumberGenerator.new()
			rr2.seed = index * 13 + 5
			for k in range(7):
				var coat := MB.mat(Tex.grime(Color.from_hsv(rr2.randf(), 0.35, 0.25), Color.from_hsv(rr2.randf(), 0.3, 0.35), 16, k + 90, 0.2))
				mb.box("coat%d" % (k % 3), coat, Vector3(0.36, rr2.randf_range(0.8, 1.1), 0.18), MB.T(Vector3(x - sx / 2 + 0.25 + k * (sx - 0.5) / 6.0, y + sy - 0.55, z), Vector3(0, rr2.randf_range(-0.3, 0.3), 0)), Color(1, 1, 1))
		"stall":
			mb.box(col.to_html(), m, Vector3(0.04, sy, sz), MB.T(Vector3(x - sx / 2, y + sy / 2 + 0.15, z)), Color(1, 1, 1))
			mb.box(col.to_html(), m, Vector3(0.04, sy, sz), MB.T(Vector3(x + sx / 2, y + sy / 2 + 0.15, z)), Color(1, 1, 1))
			mb.box(col.to_html(), m, Vector3(sx * 0.9, sy - 0.1, 0.04), MB.T(Vector3(x, y + sy / 2 + 0.15, z + sz / 2)), Color(0.9, 0.9, 0.9))
			mb.box("porc", MB.mat(Tex.solid(Color("d8d8d0"))), Vector3(0.4, 0.45, 0.55), MB.T(Vector3(x, y + 0.22, z - sz / 2 + 0.35)), Color(1, 1, 1))
		"frame":
			mb.box(col.to_html(), m, Vector3(sx, sy, sz), MB.T(Vector3(x, y, z)), Color(1, 1, 1))
			var inner := MB.mat(Tex.grime(Color("2a2420"), Color("6a5a4a"), 16, index + 99, 0.2))
			var thin := Vector3(sx * 0.85, sy * 0.85, sz + 0.01) if sx > sz else Vector3(sx + 0.01, sy * 0.85, sz * 0.85)
			mb.box("in", inner, thin, MB.T(Vector3(x, y, z)), Color(1, 1, 1))
		"chair":
			mb.box(col.to_html(), m, Vector3(sx, 0.08, sz), MB.T(Vector3(x, y + 0.45, z)), Color(1, 1, 1))
			mb.box(col.to_html(), m, Vector3(sx, sy - 0.45, 0.08), MB.T(Vector3(x, y + 0.45 + (sy - 0.45) / 2, z - sz / 2)), Color(1, 1, 1))
			for lx in [-1, 1]:
				for lz in [-1, 1]:
					mb.box(col.to_html(), m, Vector3(0.05, 0.45, 0.05), MB.T(Vector3(x + lx * (sx / 2 - 0.04), y + 0.22, z + lz * (sz / 2 - 0.04))), Color(1, 1, 1))
		"cage":
			var r2 := float(p.get("r", 0.5))
			var brass := MB.mat(Tex.brass())
			for k in range(6):
				mb.ring("cg", brass, r2, 0.015, 14, MB.T(Vector3(x, y + r2 + 0.3, z), Vector3(PI * k / 6.0, 0, 0)), Color(1, 1, 1))
			mb.box("cg", brass, Vector3(0.06, 0.3, 0.06), MB.T(Vector3(x, y + 0.15, z)), Color(1, 1, 1))
			var tooth := MB.mat(Tex.solid(Color("e8dcc0")))
			var rr3 := RandomNumberGenerator.new()
			rr3.seed = 77
			for k in range(26):
				mb.box("t", tooth, Vector3(0.04, 0.06, 0.04), MB.T(Vector3(x + rr3.randf_range(-0.3, 0.3), y + 0.35 + rr3.randf_range(0.0, 0.25), z + rr3.randf_range(-0.3, 0.3)), Vector3(rr3.randf(), rr3.randf(), rr3.randf())), Color(1, 1, 1))
		"chain":
			var cm := MB.mat(Tex.grime(Color("3a3a36"), Color("5a5a54"), 16, 33, 0.3))
			for k in range(int(sy / 0.1)):
				mb.box("ch", cm, Vector3(0.03, 0.09, 0.012 if k % 2 == 0 else 0.03), MB.T(Vector3(x, 2.9 - 0.05 - k * 0.1, z)), Color(1, 1, 1))
			mb.ring("ch", cm, 0.08, 0.02, 8, MB.T(Vector3(x, 2.9 - sy - 0.08, z), Vector3(PI / 2, 0, 0)), Color(1, 1, 1))
