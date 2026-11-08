class_name Facades
## The fronts of the old town's buildings, one 4 m bay at a time. A bay is built in its own frame:
## X along the street, Y up, Z out toward the street; the wall face is at Z = 0. Merchant houses
## in render over brick (a rusticated ground floor, a band course, framed and hooded windows on
## the floor above, pilasters, a deep cornice with dentils, a tin roof), shopfronts with painted
## signboards in the old orthography, doors with steps and fanlights, and log izbas with carved,
## painted window surrounds. Every window is a real recess with reveals, a sill and glass.

const BAY := 4.0
const G0 := 3.9          # ground floor height
const F1 := 3.3          # upper floor height

class Frame:
	var o: Vector3; var x: Vector3; var z: Vector3
	var y := Vector3.UP
	func _init(p_o: Vector3, p_x: Vector3, p_z: Vector3) -> void:
		o = p_o; x = p_x; z = p_z
	func p(a: float, b: float, c: float) -> Vector3:
		return o + x * a + y * b + z * c
	func basis() -> Basis:
		return Basis(x, y, z)

## box in bay coordinates: [x0, x1] [y0, y1] [z0, z1]
static func bx(k: TownKit, f: Frame, mat: String, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, faces := 63) -> void:
	k.box(mat, f.p((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5), Vector3(absf(x1 - x0), absf(y1 - y0), absf(z1 - z0)) * 0.5, f.basis(), faces)

## a flat wall panel facing out (Z = z)
static func wall(k: TownKit, f: Frame, mat: String, x0: float, x1: float, y0: float, y1: float, z := 0.0) -> void:
	if x1 - x0 < 0.001 or y1 - y0 < 0.001: return
	k.quad(mat, f.p(x0, y0, z), f.p(x1, y0, z), f.p(x1, y1, z), f.p(x0, y1, z), f.z, f.o)

## a wall panel with a recessed opening: four wall pieces, four reveals, and a back (glass etc.)
static func wall_hole(k: TownKit, f: Frame, mat: String, x0: float, x1: float, y0: float, y1: float, hx0: float, hx1: float, hy0: float, hy1: float, depth: float, back := "glass", reveal := "") -> void:
	var rv := mat if reveal == "" else reveal
	wall(k, f, mat, x0, hx0, y0, y1)
	wall(k, f, mat, hx1, x1, y0, y1)
	wall(k, f, mat, hx0, hx1, y0, hy0)
	wall(k, f, mat, hx0, hx1, hy1, y1)
	# reveals
	k.quad(rv, f.p(hx0, hy0, 0), f.p(hx0, hy0, -depth), f.p(hx0, hy1, -depth), f.p(hx0, hy1, 0), f.x, f.o)
	k.quad(rv, f.p(hx1, hy0, -depth), f.p(hx1, hy0, 0), f.p(hx1, hy1, 0), f.p(hx1, hy1, -depth), -f.x, f.o)
	k.quad(rv, f.p(hx0, hy0, -depth), f.p(hx1, hy0, -depth), f.p(hx1, hy0, 0), f.p(hx0, hy0, 0), f.y, f.o)
	k.quad(rv, f.p(hx0, hy1, 0), f.p(hx1, hy1, 0), f.p(hx1, hy1, -depth), f.p(hx0, hy1, -depth), -f.y, f.o)
	if back != "":
		k.quad(back, f.p(hx0, hy0, -depth), f.p(hx1, hy0, -depth), f.p(hx1, hy1, -depth), f.p(hx0, hy1, -depth), f.z, f.p(hx0, hy0, -depth))

## a sash window in an opening: glass, a frame, glazing bars (the old 2-over-2 / T-shaped casement)
static func casement(k: TownKit, f: Frame, x0: float, x1: float, y0: float, y1: float, depth: float, lit: bool, frame_mat := "trim") -> void:
	var z := -depth + 0.02
	var t := 0.045
	bx(k, f, frame_mat, x0, x1, y0, y0 + t, z - 0.02, z + 0.03, 20)
	bx(k, f, frame_mat, x0, x1, y1 - t, y1, z - 0.02, z + 0.03, 24)
	bx(k, f, frame_mat, x0, x0 + t, y0, y1, z - 0.02, z + 0.03, 17)
	bx(k, f, frame_mat, x1 - t, x1, y0, y1, z - 0.02, z + 0.03, 18)
	var xm := (x0 + x1) * 0.5; var ym := y1 - (y1 - y0) * 0.3
	bx(k, f, frame_mat, xm - 0.02, xm + 0.02, y0, ym, z - 0.01, z + 0.025, 19)
	bx(k, f, frame_mat, x0, x1, ym - 0.02, ym + 0.02, z - 0.01, z + 0.025, 28)
	if lit:
		k.quad("window_glow", f.p(x0, y0, -depth + 0.005), f.p(x1, y0, -depth + 0.005), f.p(x1, y1, -depth + 0.005), f.p(x0, y1, -depth + 0.005), f.z, f.p(x0, y0, 0))

# ---------------------------------------------------------------- a merchant house bay
## style: {wall, ground, lit_up, lit_down, kind: "window"|"door"|"shop"|"blank", sign, hood,
## pilaster_left, pilaster_right, floors, rng}
static func house(k: TownKit, f: Frame, s: Dictionary) -> Dictionary:
	var out := {}
	var wall_mat: String = s.get("wall", "stucco_ochre")
	var ground_mat: String = s.get("ground", "rustic_ochre")
	var floors: int = s.get("floors", 2)
	var rng: RandomNumberGenerator = s.rng
	var top := G0 + F1 * (floors - 1)
	# plinth: granite, a little proud
	bx(k, f, "stone", 0, BAY, 0, 0.45, 0, 0.07, 4 | 16 | 1 | 2)
	# ---- ground floor
	match String(s.get("kind", "window")):
		"window":
			wall_hole(k, f, ground_mat, 0, BAY, 0.45, G0, 1.42, 2.58, 1.05, 2.95, 0.26, "glass", "stucco_cream")
			casement(k, f, 1.42, 2.58, 1.05, 2.95, 0.26, s.get("lit_down", false))
			bx(k, f, "stone", 1.3, 2.7, 0.97, 1.05, -0.02, 0.1)              # sill
			bx(k, f, "trim", 1.85, 2.15, 2.95, 3.22, -0.02, 0.06)            # keystone
		"door":
			wall_hole(k, f, ground_mat, 0, BAY, 0.45, G0, 1.35, 2.65, 0.45, 3.35, 0.32, "", "stucco_cream")
			wall(k, f, ground_mat, 1.35, 2.65, 0.0, 0.45, 0.0)
			# double door with raised panels; a fanlight above
			var open: bool = s.get("door_open", false)
			if not open:
				bx(k, f, "paint_door", 1.37, 2.63, 0.45, 2.75, -0.32, -0.26)
				for dx in [1.5, 2.08]:
					for dy in [0.7, 1.7]:
						bx(k, f, "paint_door", dx, dx + 0.42, dy, dy + 0.75, -0.27, -0.235, 16)
				bx(k, f, "iron", 1.96, 2.04, 1.5, 1.62, -0.26, -0.2)          # the handle
			out["door"] = f.p(2.0, 0.0, -0.32)
			bx(k, f, "trim", 1.37, 2.63, 2.75, 2.82, -0.32, -0.26)
			k.quad("window_glow" if s.get("lit_down", false) else "glass", f.p(1.37, 2.82, -0.3), f.p(2.63, 2.82, -0.3), f.p(2.63, 3.33, -0.3), f.p(1.37, 3.33, -0.3), f.z, f.o)
			for i in 5:
				var a := PI * (0.15 + 0.7 * i / 4.0)
				bx(k, f, "trim", 2.0 + cos(a) * 0.35 - 0.015, 2.0 + cos(a) * 0.35 + 0.015, 2.85, 2.85 + sin(a) * 0.42, -0.31, -0.28, 16)
			# two worn steps out onto the pavement
			bx(k, f, "stone", 1.2, 2.8, 0.0, 0.17, 0, 0.55)
			bx(k, f, "stone", 1.3, 2.7, 0.17, 0.34, -0.1, 0.25)
		"shop":
			wall_hole(k, f, ground_mat, 0, BAY, 0.45, G0, 0.35, 3.65, 0.6, 3.15, 0.14, String(s.get("goods", "shop")), "paint_green")
			# the shopfront joinery: a painted frame, mullions, a stall riser
			bx(k, f, "paint_green", 0.3, 3.7, 0.45, 0.62, -0.02, 0.06)
			bx(k, f, "paint_green", 0.3, 3.7, 3.13, 3.27, -0.02, 0.08)
			for mx in [0.3, 1.38, 2.52, 3.62]:
				bx(k, f, "paint_green", mx, mx + 0.08, 0.6, 3.15, -0.12, 0.04)
			# the signboard, in gold on green, the old spelling
			bx(k, f, "paint_green", 0.15, 3.85, 3.33, 3.85, 0.0, 0.07)
			bx(k, f, "trim", 0.15, 3.85, 3.85, 3.9, 0.0, 0.09)
			bx(k, f, "trim", 0.15, 3.85, 3.28, 3.33, 0.0, 0.09)
			out["sign"] = [f.p(2.0, 3.59, 0.075), String(s.get("sign", ""))]
		"blank":
			wall(k, f, ground_mat, 0, BAY, 0.45, G0)
	# band course between the floors
	bx(k, f, "trim", 0, BAY, G0, G0 + 0.12, 0, 0.12, 4 | 8 | 16 | 1 | 2)
	bx(k, f, "trim", 0, BAY, G0 + 0.12, G0 + 0.24, 0, 0.06, 4 | 16 | 1 | 2)
	# ---- upper floors
	for fl in floors - 1:
		var y0 := G0 + 0.24 + fl * F1
		var y1 := G0 + (fl + 1) * F1
		var wy0 := y0 + 0.6; var wy1 := wy0 + 1.85
		var lit: bool = rng.randf() < float(s.get("lit_up", 0.15))
		wall_hole(k, f, wall_mat, 0, BAY, y0, y1 if fl < floors - 2 else top, 1.48, 2.52, wy0, wy1, 0.2, "glass", "trim")
		casement(k, f, 1.48, 2.52, wy0, wy1, 0.2, lit)
		if lit: out["lit"] = out.get("lit", []) + [f.p(2.0, (wy0 + wy1) * 0.5, -0.4)]
		# architrave round the window, a sill on two brackets, a hood or a pediment
		bx(k, f, "trim", 1.34, 1.48, wy0 - 0.06, wy1 + 0.06, 0, 0.05, 61)
		bx(k, f, "trim", 2.52, 2.66, wy0 - 0.06, wy1 + 0.06, 0, 0.05, 62)
		bx(k, f, "trim", 1.34, 2.66, wy1, wy1 + 0.12, 0, 0.05, 20)
		bx(k, f, "trim", 1.28, 2.72, wy0 - 0.1, wy0, -0.02, 0.13)
		for bxp in [1.4, 2.5]:
			bx(k, f, "trim", bxp, bxp + 0.1, wy0 - 0.3, wy0 - 0.1, 0, 0.09, 63 & ~32)
		match String(s.get("hood", "flat")):
			"flat":
				bx(k, f, "trim", 1.22, 2.78, wy1 + 0.14, wy1 + 0.3, 0, 0.14)
			"pediment":
				bx(k, f, "trim", 1.22, 2.78, wy1 + 0.14, wy1 + 0.22, 0, 0.14)
				var a := f.p(1.22, wy1 + 0.22, 0.13); var b := f.p(2.78, wy1 + 0.22, 0.13); var c := f.p(2.0, wy1 + 0.6, 0.13)
				k.tri("trim", a, b, c, f.z)
				k.quad("trim", f.p(1.22, wy1 + 0.22, 0.13), f.p(1.22, wy1 + 0.22, 0.0), f.p(2.0, wy1 + 0.6, 0.0), f.p(2.0, wy1 + 0.6, 0.13), (f.y - f.x).normalized(), f.o)
				k.quad("trim", f.p(2.0, wy1 + 0.6, 0.13), f.p(2.0, wy1 + 0.6, 0.0), f.p(2.78, wy1 + 0.22, 0.0), f.p(2.78, wy1 + 0.22, 0.13), (f.y + f.x).normalized(), f.o)
			"arch":
				for i in 7:
					var a0 := PI * i / 7.0; var a1 := PI * (i + 1) / 7.0
					var r := 0.66
					bx(k, f, "trim", 2.0 - cos(a0) * r - 0.06, 2.0 - cos(a0) * r + 0.06, wy1 + 0.12 + sin(a0) * 0.32, wy1 + 0.12 + sin(a1) * 0.32 + 0.08, 0, 0.09)
		if fl < floors - 2:
			bx(k, f, "trim", 0, BAY, y1 - 0.08, y1, 0, 0.08, 4 | 8 | 16 | 1 | 2)
	# pilasters on the bay's edges, upper floors
	if s.get("pilaster_left", true):
		bx(k, f, "trim", -0.16, 0.16, G0 + 0.24, top, 0, 0.07, 63 & ~32)
	if s.get("pilaster_right", false):
		bx(k, f, "trim", BAY - 0.16, BAY + 0.16, G0 + 0.24, top, 0, 0.07, 63 & ~32)
	# the cornice: a frieze, dentils, and a deep overhang, then the roof
	bx(k, f, "trim", 0, BAY, top, top + 0.16, 0, 0.1, 4 | 8 | 16 | 1 | 2)
	var dx := 0.06
	while dx < BAY:
		bx(k, f, "trim", dx, dx + 0.09, top + 0.16, top + 0.3, 0.02, 0.18, 63 & ~32 & ~4)
		dx += 0.22
	bx(k, f, "trim", 0, BAY, top + 0.3, top + 0.42, 0, 0.26, 63 & ~32)
	bx(k, f, "trim", 0, BAY, top + 0.42, top + 0.52, 0, 0.36, 63 & ~32)
	var r0 := f.p(0, top + 0.52, 0.36); var r1 := f.p(BAY, top + 0.52, 0.36)
	var r2 := f.p(BAY, top + 2.3, -2.4); var r3 := f.p(0, top + 2.3, -2.4)
	k.quad("tin", r0, r1, r2, r3, (f.y * 2.8 + f.z * 1.78).normalized(), f.o)
	if rng.randf() < 0.25:
		var cx := rng.randf_range(0.6, 3.0)
		bx(k, f, "brick", cx, cx + 0.55, top + 0.9, top + 3.3, -1.6, -1.1)
		bx(k, f, "stone", cx - 0.05, cx + 0.6, top + 3.3, top + 3.42, -1.65, -1.05)
	if s.get("drainpipe", false):
		k.cyl("iron", f.p(BAY - 0.25, 0.1, 0.12), 0.05, top + 0.3, 6)
		bx(k, f, "iron", BAY - 0.37, BAY - 0.13, top + 0.25, top + 0.45, 0.02, 0.26)
	out["top"] = top
	return out

# ---------------------------------------------------------------- a log izba bay
static func izba(k: TownKit, f: Frame, s: Dictionary) -> Dictionary:
	var out := {}
	var carve: String = s.get("carve", "carved_white")
	const H := 3.2
	bx(k, f, "stone", 0, BAY, 0, 0.35, 0, 0.12, 4 | 16 | 1 | 2)          # a stone footing
	if String(s.get("kind", "window")) == "door":
		wall_hole(k, f, "wood", 0, BAY, 0.35, H, 1.45, 2.55, 0.35, 2.5, 0.22, "", "wood")
		wall(k, f, "wood", 1.45, 2.55, 0.0, 0.35)
		if not s.get("door_open", false):
			bx(k, f, "wood", 1.47, 2.53, 0.35, 2.48, -0.22, -0.17)
		out["door"] = f.p(2.0, 0.0, -0.22)
		bx(k, f, "wood", 1.3, 2.7, 0.0, 0.3, 0, 0.6)                    # a plank step
		# a little porch roof on carved brackets
		bx(k, f, "tin", 1.15, 2.85, 2.75, 2.8, -0.05, 0.75)
		bx(k, f, carve, 1.2, 1.35, 2.3, 2.75, 0.0, 0.7, 3)
		bx(k, f, carve, 2.65, 2.8, 2.3, 2.75, 0.0, 0.7, 3)
	else:
		# two small windows, each with a carved, painted surround and open shutters
		wall_hole(k, f, "wood", 0, BAY, 0.35, H, 1.5, 2.5, 1.15, 2.25, 0.18, "glass", "wood")
		casement(k, f, 1.5, 2.5, 1.15, 2.25, 0.18, s.get("lit", false), "carved_white")
		bx(k, f, carve, 1.3, 2.7, 2.25, 2.75, 0.0, 0.05)               # the carved top board (kokoshnik)
		bx(k, f, carve, 1.3, 2.7, 0.85, 1.15, 0.0, 0.05)               # and the apron below
		bx(k, f, carve, 1.32, 1.5, 1.15, 2.25, 0.0, 0.05)
		bx(k, f, carve, 2.5, 2.68, 1.15, 2.25, 0.0, 0.05)
		# shutters, folded back
		bx(k, f, "carved_blue", 0.95, 1.3, 1.12, 2.28, 0.0, 0.04)
		bx(k, f, "carved_blue", 2.7, 3.05, 1.12, 2.28, 0.0, 0.04)
	# corner log ends (the saddle-notched crossings), if this bay ends a house
	if s.get("corner_left", false):
		var y := 0.4
		while y < H:
			bx(k, f, "wood", -0.18, 0.12, y, y + 0.28, -0.15, 0.18)
			y += 0.32
	# the gable to the street: boards, a carved bargeboard, a little attic window
	var g0 := f.p(0, H, 0.05); var g1 := f.p(BAY, H, 0.05); var gt := f.p(2.0, H + 2.1, 0.05)
	k.tri("wood", g0, g1, gt, f.z)
	k.quad(carve, f.p(-0.2, H - 0.15, 0.12), f.p(2.0, H + 2.05, 0.12), f.p(2.0, H + 2.35, 0.12), f.p(-0.2, H + 0.15, 0.12), f.z, f.o)
	k.quad(carve, f.p(2.0, H + 2.05, 0.12), f.p(BAY + 0.2, H - 0.15, 0.12), f.p(BAY + 0.2, H + 0.15, 0.12), f.p(2.0, H + 2.35, 0.12), f.z, f.o)
	bx(k, f, "glass", 1.75, 2.25, H + 0.6, H + 1.15, -0.02, 0.0, 16)
	bx(k, f, carve, 1.65, 2.35, H + 1.15, H + 1.35, 0.0, 0.06)
	# roof slopes back from the gable
	k.quad("tin", f.p(-0.25, H - 0.1, 0.3), f.p(2.0, H + 2.4, 0.3), f.p(2.0, H + 2.4, -6.0), f.p(-0.25, H - 0.1, -6.0), (-f.x + f.y).normalized(), f.o)
	k.quad("tin", f.p(2.0, H + 2.4, 0.3), f.p(BAY + 0.25, H - 0.1, 0.3), f.p(BAY + 0.25, H - 0.1, -6.0), f.p(2.0, H + 2.4, -6.0), (f.x + f.y).normalized(), f.o)
	out["top"] = H + 2.4
	return out

# ---------------------------------------------------------------- street furniture
## A gas lamp: a fluted cast-iron post, a lantern of four glass panes under a little roof.
## Returns the light position.
static func gas_lamp(k: TownKit, at: Vector3, bent := 0.0) -> Vector3:
	k.cyl("iron", at, 0.13, 0.35, 8, 0.1)
	k.cyl("iron", at + Vector3(0, 0.35, 0), 0.07, 2.4, 8, 0.05)
	var top := at + Vector3(0, 2.75, 0)
	if bent != 0.0:
		top = at + Vector3(sin(bent) * 1.6, 0.35 + cos(bent) * 2.4, 0)
		k.box("iron", at + Vector3(sin(bent) * 0.8, 0.35 + cos(bent) * 1.2, 0), Vector3(0.06, 1.25, 0.06), Basis(Vector3(0, 0, 1), -bent))
	# the ladder bar the lamplighter rested his ladder on
	k.box("iron", top + Vector3(0, -0.28, 0), Vector3(0.32, 0.02, 0.02))
	# the lantern: four panes of glass, wider at the top, in an iron cage, under a pyramid cap
	k.box("iron", top + Vector3(0, 0.03, 0), Vector3(0.1, 0.03, 0.1))
	const B := 0.1; const T := 0.17; const HG := 0.46
	var c0 := top + Vector3(0, 0.06, 0)
	for i in 4:
		var a0 := PI * 0.5 * i + PI * 0.25; var a1 := a0 + PI * 0.5
		var d0 := Vector3(cos(a0), 0, sin(a0)) * 1.4142; var d1 := Vector3(cos(a1), 0, sin(a1)) * 1.4142
		var n := ((d0 + d1) * 0.5).normalized()
		k.quad("lamp_glass" if bent == 0.0 else "glass", c0 + d0 * B, c0 + d1 * B, c0 + d1 * T + Vector3(0, HG, 0), c0 + d0 * T + Vector3(0, HG, 0), n)
		# the cage's corner bars
		var mid := c0 + d0 * (B + T) * 0.5 + Vector3(0, HG * 0.5, 0)
		k.box("iron", mid, Vector3(0.012, HG * 0.52, 0.012), Basis(d0.cross(Vector3.UP).normalized(), -atan2(T - B, HG)))
	k.box("iron", c0 + Vector3(0, HG + 0.015, 0), Vector3(T + 0.03, 0.02, T + 0.03))
	k.cyl("iron", c0 + Vector3(0, HG + 0.03, 0), (T + 0.05) * 1.3, 0.2, 4, 0.03)
	k.cyl("iron", c0 + Vector3(0, HG + 0.23, 0), 0.025, 0.12, 6, 0.0)
	return top + Vector3(0, 0.3, 0)

## The broken edge of a hole knocked through a wall: shards of brick and lumps of render, of
## different sizes, at different depths and angles, round an opening x0..x1, y0..y1 (in the
## frame), denser at the top where the lintel gave way. `wall_mat` is the render they came from.
static func ragged_rim(k: TownKit, f: Frame, x0: float, x1: float, y0: float, y1: float, wall_mat: String, rng: RandomNumberGenerator, n := 46) -> void:
	var per := 2.0 * (y1 - y0) + (x1 - x0)
	for i in n:
		var t := rng.randf() * per
		var p: Vector2; var inward: Vector2
		if t < y1 - y0:
			p = Vector2(x0, y0 + t); inward = Vector2(1, 0)
		elif t < (y1 - y0) + (x1 - x0):
			p = Vector2(x0 + t - (y1 - y0), y1); inward = Vector2(0, -1)
		else:
			p = Vector2(x1, y1 - (t - (y1 - y0) - (x1 - x0))); inward = Vector2(-1, 0)
		p += inward * rng.randf_range(-0.07, 0.05) + inward.orthogonal() * rng.randf_range(-0.03, 0.03)
		var brick := rng.randf() < 0.6
		var sx := rng.randf_range(0.04, 0.12) if brick else rng.randf_range(0.03, 0.09)
		var sy := sx * rng.randf_range(0.35, 0.6) if brick else sx * rng.randf_range(0.5, 1.0)
		var depth := rng.randf_range(-0.22, 0.03)
		var b := f.basis() * Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.4, 0.4), rng.randf_range(-0.5, 0.5)))
		k.box("brick" if brick else wall_mat, f.p(p.x, p.y, depth), Vector3(sx, sy, rng.randf_range(0.03, 0.08)), b)
