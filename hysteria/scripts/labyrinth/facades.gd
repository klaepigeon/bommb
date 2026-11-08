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

# ---------------------------------------------------------------- modelled parts
## The render's colour without the painted rustication: the blocks are real geometry now.
static func _plain(mat: String) -> String:
	return mat.replace("rustic_", "stucco_")

## Rusticated render: horizontal courses of block, each proud of the wall, with a real groove
## between them (the light catches the top edge of every course and the groove under it goes
## dark). `holes` are openings [x0, x1, y0, y1] the courses stop at.
static func rusticate(k: TownKit, f: Frame, mat: String, x0: float, x1: float, y0: float, y1: float, holes: Array, course := 0.42, proud := 0.045, groove := 0.035) -> void:
	var y := y0
	while y < y1 - 0.06:
		var ya := y + groove * 0.5; var yb := minf(y + course - groove * 0.5, y1)
		var segs := [[x0, x1]]
		for h in holes:
			if yb <= h[2] or ya >= h[3]: continue
			var next := []
			for sg in segs:
				if sg[1] <= h[0] or sg[0] >= h[1]: next.append(sg); continue
				if sg[0] < h[0]: next.append([sg[0], h[0]])
				if sg[1] > h[1]: next.append([h[1], sg[1]])
			segs = next
		for sg in segs:
			if sg[1] - sg[0] > 0.04:
				bx(k, f, mat, sg[0], sg[1], ya, yb, 0, proud, 31)
		y += course

## A moulding running along x: a stack of steps [y0, y1, projection], bottom to top.
static func moulding(k: TownKit, f: Frame, mat: String, x0: float, x1: float, steps: Array) -> void:
	for st in steps:
		bx(k, f, mat, x0, x1, st[0], st[1], 0, st[2], 4 | 8 | 16 | 1 | 2)

## A console bracket under a sill or a balcony: three stacked blocks, deepest at the top.
static func console(k: TownKit, f: Frame, mat: String, x: float, w: float, y_top: float, depth: float) -> void:
	bx(k, f, mat, x, x + w, y_top - 0.08, y_top, 0, depth, 31)
	bx(k, f, mat, x, x + w, y_top - 0.17, y_top - 0.08, 0, depth * 0.7, 31)
	bx(k, f, mat, x + w * 0.15, x + w * 0.85, y_top - 0.27, y_top - 0.17, 0, depth * 0.4, 31)

## Quoins: dressed corner stones, long and short in turn, up an edge (side -1: at x, going in +x;
## +1: at x, going in -x).
static func quoins(k: TownKit, f: Frame, mat: String, x: float, side: float, y0: float, y1: float) -> void:
	var y := y0; var i := 0
	while y < y1 - 0.2:
		var w := 0.58 if i % 2 == 0 else 0.34
		var xa := x if side < 0.0 else x - w
		bx(k, f, mat, xa, xa + w, y + 0.02, minf(y + 0.32, y1) - 0.02, 0, 0.05, 31)
		y += 0.34; i += 1

## A pilaster: base, plain shaft, a capital of two steps.
static func pilaster(k: TownKit, f: Frame, mat: String, x: float, y0: float, y1: float) -> void:
	bx(k, f, mat, x - 0.21, x + 0.21, y0, y0 + 0.3, 0, 0.1, 31)
	bx(k, f, mat, x - 0.18, x + 0.18, y0 + 0.3, y0 + 0.36, 0, 0.085, 31)
	bx(k, f, mat, x - 0.16, x + 0.16, y0 + 0.36, y1 - 0.22, 0, 0.07, 31)
	bx(k, f, mat, x - 0.19, x + 0.19, y1 - 0.22, y1 - 0.12, 0, 0.09, 31)
	bx(k, f, mat, x - 0.23, x + 0.23, y1 - 0.12, y1, 0, 0.12, 31)

## A cast-iron balcony on two consoles: the slab, the railing with its balusters and a top rail.
static func balcony(k: TownKit, f: Frame, x0: float, x1: float, y: float, depth := 0.55) -> void:
	bx(k, f, "stone", x0, x1, y - 0.07, y, 0, depth, 31)
	k.fine = true
	console(k, f, "stone", x0 + 0.12, 0.12, y - 0.07, depth * 0.85)
	console(k, f, "stone", x1 - 0.24, 0.12, y - 0.07, depth * 0.85)
	var h := 0.92
	bx(k, f, "iron", x0 + 0.02, x1 - 0.02, y + h - 0.035, y + h, depth - 0.06, depth - 0.02)
	bx(k, f, "iron", x0 + 0.02, x1 - 0.02, y + 0.06, y + 0.09, depth - 0.06, depth - 0.02)
	for side in [x0 + 0.02, x1 - 0.06]:
		bx(k, f, "iron", side, side + 0.04, y + h - 0.035, y + h, 0.02, depth - 0.02)
		bx(k, f, "iron", side, side + 0.04, y + 0.06, y + 0.09, 0.02, depth - 0.02)
	var x := x0 + 0.08
	while x < x1 - 0.06:
		bx(k, f, "iron", x, x + 0.018, y, y + h, depth - 0.05, depth - 0.032, 63 & ~32)
		x += 0.11
	for side in [x0 + 0.03, x1 - 0.048]:
		var z := 0.08
		while z < depth - 0.06:
			bx(k, f, "iron", side, side + 0.018, y, y + h, z, z + 0.018)
			z += 0.11
	# a scroll in the middle of the front, the maker's flourish
	for i in 6:
		var a := TAU * i / 6.0
		var c := Vector2((x0 + x1) * 0.5 + cos(a) * 0.12, y + 0.5 + sin(a) * 0.12)
		bx(k, f, "iron", c.x - 0.02, c.x + 0.02, c.y - 0.02, c.y + 0.02, depth - 0.05, depth - 0.03)
	k.fine = false

## A drainpipe from the gutter to the pavement: the hopper head, brackets, a shoe at the foot.
static func drainpipe(k: TownKit, f: Frame, x: float, top: float) -> void:
	k.cyl("iron", f.p(x, 0.18, 0.13), 0.05, top + 0.25, 8)
	bx(k, f, "iron", x - 0.13, x + 0.13, top + 0.42, top + 0.62, 0.02, 0.3)
	bx(k, f, "iron", x - 0.09, x + 0.09, top + 0.3, top + 0.42, 0.04, 0.24)
	k.cyl_axis("iron", f.p(x, 0.22, 0.13), f.p(x, 0.04, 0.32), 0.055, 8)
	k.fine = true
	var y := 1.0
	while y < top:
		bx(k, f, "iron", x - 0.07, x + 0.07, y, y + 0.05, 0, 0.19)
		y += 1.4
	k.fine = false

# ---------------------------------------------------------------- a merchant house bay
## style: {wall, ground, lit_up, lit_down, kind: "window"|"door"|"shop"|"blank", sign, hood,
## house_left, house_right (this bay ends its house), floors, balcony, chimney, canopy,
## drainpipe, rng}
static func house(k: TownKit, f: Frame, s: Dictionary) -> Dictionary:
	var out := {}
	var wall_mat: String = s.get("wall", "stucco_ochre")
	var ground_src: String = s.get("ground", "rustic_ochre")
	var rusticated := ground_src.begins_with("rustic_")
	var ground_mat := _plain(ground_src)
	var floors: int = s.get("floors", 2)
	var rng: RandomNumberGenerator = s.rng
	var top := G0 + F1 * (floors - 1)
	var hl: bool = s.get("house_left", false); var hr: bool = s.get("house_right", false)
	# plinth: granite, a little proud, with a chamfered top
	bx(k, f, "stone", 0, BAY, 0, 0.4, 0, 0.09, 4 | 16 | 1 | 2)
	bx(k, f, "stone", 0, BAY, 0.4, 0.47, 0, 0.05, 4 | 16 | 1 | 2)
	# ---- ground floor
	var holes := []
	match String(s.get("kind", "window")):
		"window":
			wall_hole(k, f, ground_mat, 0, BAY, 0.47, G0, 1.42, 2.58, 1.05, 2.95, 0.3, "glass", "stucco_cream")
			casement(k, f, 1.42, 2.58, 1.05, 2.95, 0.3, s.get("lit_down", false))
			holes = [[1.3, 2.7, 0.9, 3.25]]
			# a stone sill with a drip, and the voussoirs of a flat arch with a keystone
			bx(k, f, "stone", 1.3, 2.7, 0.97, 1.05, -0.02, 0.12)
			bx(k, f, "stone", 1.36, 2.64, 0.92, 0.97, 0.0, 0.08)
			for i in 5:
				var vx := 1.32 + i * 0.27
				bx(k, f, "trim", vx, vx + 0.25, 2.95, 3.2 + (0.06 if i == 2 else 0.0), 0, 0.06 if i != 2 else 0.1, 31)
		"door":
			wall_hole(k, f, ground_mat, 0, BAY, 0.47, G0, 1.35, 2.65, 0.47, 3.35, 0.36, "", "stucco_cream")
			wall(k, f, ground_mat, 1.35, 2.65, 0.0, 0.47)
			holes = [[1.1, 2.9, 0.0, 3.62]]
			# a stone doorcase: jambs and a lintel with a cornice
			bx(k, f, "stone", 1.12, 1.35, 0.47, 3.35, 0, 0.08, 31)
			bx(k, f, "stone", 2.65, 2.88, 0.47, 3.35, 0, 0.08, 31)
			bx(k, f, "stone", 1.05, 2.95, 3.35, 3.55, 0, 0.1, 31)
			bx(k, f, "stone", 0.98, 3.02, 3.55, 3.62, 0, 0.15, 31)
			var open: bool = s.get("door_open", false)
			if not open:
				bx(k, f, "paint_door", 1.37, 2.63, 0.47, 2.75, -0.36, -0.3)
				for dx in [1.5, 2.08]:
					for dy in [0.72, 1.72]:
						bx(k, f, "paint_door", dx, dx + 0.42, dy, dy + 0.75, -0.31, -0.275, 16 | 1 | 2 | 4 | 8)
						bx(k, f, "paint_door", dx + 0.06, dx + 0.36, dy + 0.06, dy + 0.69, -0.275, -0.26, 16 | 1 | 2 | 4 | 8)
				bx(k, f, "paint_door", 1.99, 2.01, 0.47, 2.75, -0.3, -0.27)            # where the leaves meet
				bx(k, f, "iron", 1.93, 1.97, 1.5, 1.66, -0.3, -0.24)
				bx(k, f, "iron", 2.03, 2.07, 1.5, 1.66, -0.3, -0.24)
			out["door"] = f.p(2.0, 0.0, -0.36)
			bx(k, f, "trim", 1.37, 2.63, 2.75, 2.82, -0.36, -0.3)
			k.quad("window_glow" if s.get("lit_down", false) else "glass", f.p(1.37, 2.82, -0.34), f.p(2.63, 2.82, -0.34), f.p(2.63, 3.33, -0.34), f.p(1.37, 3.33, -0.34), f.z, f.o)
			for i in 5:
				var a := PI * (0.15 + 0.7 * i / 4.0)
				bx(k, f, "trim", 2.0 + cos(a) * 0.35 - 0.015, 2.0 + cos(a) * 0.35 + 0.015, 2.85, 2.85 + sin(a) * 0.42, -0.35, -0.32, 16)
			# two worn steps out onto the pavement, the top one dished in the middle
			bx(k, f, "stone", 1.15, 2.85, 0.0, 0.16, 0, 0.6)
			bx(k, f, "stone", 1.25, 2.75, 0.16, 0.3, -0.1, 0.28)
			bx(k, f, "stone", 1.3, 2.7, 0.3, 0.47, -0.36, 0.0)
			# an iron canopy over the door on two scrolled brackets
			if s.get("canopy", false):
				var cy := 3.9
				k.quad("tin", f.p(1.0, cy + 0.06, 0.0), f.p(3.0, cy + 0.06, 0.0), f.p(3.0, cy - 0.12, 0.85), f.p(1.0, cy - 0.12, 0.85), (f.y * 0.85 + f.z * 0.18).normalized(), f.o)
				bx(k, f, "iron", 1.0, 3.0, cy - 0.16, cy - 0.1, 0.8, 0.88)
				k.fine = true
				for bxp in [1.05, 2.91]:
					k.cyl_axis("iron", f.p(bxp, cy - 0.7, 0.0), f.p(bxp, cy - 0.1, 0.84), 0.018, 4)
					bx(k, f, "iron", bxp - 0.01, bxp + 0.03, cy - 0.12, cy - 0.06, 0.0, 0.84)
					for i in 5:
						var a := TAU * i / 5.0
						bx(k, f, "iron", bxp, bxp + 0.02, cy - 0.38 + sin(a) * 0.1, cy - 0.34 + sin(a) * 0.1, 0.28 + cos(a) * 0.1, 0.32 + cos(a) * 0.1)
				k.fine = false
		"shop":
			wall_hole(k, f, ground_mat, 0, BAY, 0.47, G0, 0.35, 3.65, 0.6, 3.15, 0.16, String(s.get("goods", "shop")), "paint_green")
			holes = [[0.0, BAY, 0.0, G0]]        # the shopfront fills the bay: no rustication
			# the shopfront joinery: a stall riser in panels, mullions, a transom
			bx(k, f, "paint_green", 0.3, 3.7, 0.47, 0.62, -0.02, 0.07)
			for px in [0.45, 1.5, 2.6]:
				bx(k, f, "paint_green", px, px + 0.9, 0.5, 0.6, 0.07, 0.09, 16)
			bx(k, f, "paint_green", 0.3, 3.7, 3.13, 3.27, -0.02, 0.08)
			for mx in [0.3, 1.38, 2.52, 3.62]:
				bx(k, f, "paint_green", mx, mx + 0.08, 0.6, 3.15, -0.14, 0.04)
			# pilasters either side, and the signboard under a moulded fascia cornice
			for px in [0.12, 3.88]:
				bx(k, f, "paint_green", px - 0.13, px + 0.13, 0.47, 3.3, 0, 0.1, 31)
				bx(k, f, "paint_green", px - 0.16, px + 0.16, 3.2, 3.32, 0, 0.13, 31)
			bx(k, f, "paint_green", 0.15, 3.85, 3.33, 3.85, 0.0, 0.08)
			moulding(k, f, "trim", 0.05, 3.95, [[3.85, 3.9, 0.11], [3.9, 3.96, 0.15], [3.96, 4.0, 0.18]])
			bx(k, f, "trim", 0.15, 3.85, 3.28, 3.33, 0.0, 0.1)
			out["sign"] = [f.p(2.0, 3.59, 0.085), String(s.get("sign", ""))]
		"blank":
			wall(k, f, ground_mat, 0, BAY, 0.47, G0)
	if rusticated and holes.size() < 2:
		rusticate(k, f, ground_mat, 0, BAY, 0.47, G0, holes)
	# the band course between the floors: a moulded string course with a drip
	moulding(k, f, "trim", 0, BAY, [[G0 - 0.04, G0, 0.05], [G0, G0 + 0.1, 0.13], [G0 + 0.1, G0 + 0.16, 0.09], [G0 + 0.16, G0 + 0.24, 0.05]])
	# ---- upper floors
	for fl in floors - 1:
		var y0 := G0 + 0.24 + fl * F1
		var y1 := G0 + (fl + 1) * F1
		var wy0 := y0 + 0.6; var wy1 := wy0 + 1.85
		var balc: bool = fl == 0 and s.get("balcony", false) and String(s.get("kind", "")) != "shop"
		if balc: wy0 = y0 + 0.12               # a French window onto the balcony
		var lit: bool = rng.randf() < float(s.get("lit_up", 0.15))
		wall_hole(k, f, wall_mat, 0, BAY, y0, y1 if fl < floors - 2 else top, 1.48, 2.52, wy0, wy1, 0.24, "glass", "trim")
		casement(k, f, 1.48, 2.52, wy0, wy1, 0.24, lit)
		if lit: out["lit"] = out.get("lit", []) + [f.p(2.0, (wy0 + wy1) * 0.5, -0.4)]
		# the architrave, in two steps round the opening
		bx(k, f, "trim", 1.3, 1.48, wy0 - 0.08, wy1 + 0.08, 0, 0.045, 31)
		bx(k, f, "trim", 2.52, 2.7, wy0 - 0.08, wy1 + 0.08, 0, 0.045, 31)
		bx(k, f, "trim", 1.3, 2.7, wy1, wy1 + 0.14, 0, 0.045, 31)
		bx(k, f, "trim", 1.42, 1.48, wy0, wy1, 0, 0.075, 31)
		bx(k, f, "trim", 2.52, 2.58, wy0, wy1, 0, 0.075, 31)
		bx(k, f, "trim", 1.42, 2.58, wy1, wy1 + 0.06, 0, 0.075, 31)
		if balc:
			balcony(k, f, 1.1, 2.9, y0 + 0.12)
		else:
			# a sill on two consoles, with a drip under its front edge
			bx(k, f, "trim", 1.24, 2.76, wy0 - 0.1, wy0, -0.02, 0.15)
			bx(k, f, "trim", 1.28, 2.72, wy0 - 0.13, wy0 - 0.1, 0.0, 0.12)
			k.fine = true
			console(k, f, "trim", 1.36, 0.1, wy0 - 0.13, 0.11)
			console(k, f, "trim", 2.54, 0.1, wy0 - 0.13, 0.11)
			k.fine = false
			# under the window, a sunk panel
			bx(k, f, "trim", 1.5, 2.5, wy0 - 0.62, wy0 - 0.6, 0, 0.03, 31)
			bx(k, f, "trim", 1.5, 2.5, wy0 - 0.33, wy0 - 0.31, 0, 0.03, 31)
			bx(k, f, "trim", 1.5, 1.52, wy0 - 0.6, wy0 - 0.33, 0, 0.03, 31)
			bx(k, f, "trim", 2.48, 2.5, wy0 - 0.6, wy0 - 0.33, 0, 0.03, 31)
		match String(s.get("hood", "flat")):
			"flat":
				# a cornice over the window on a frieze
				bx(k, f, wall_mat, 1.3, 2.7, wy1 + 0.14, wy1 + 0.3, 0, 0.03, 31)
				moulding(k, f, "trim", 1.18, 2.82, [[wy1 + 0.3, wy1 + 0.36, 0.1], [wy1 + 0.36, wy1 + 0.44, 0.16], [wy1 + 0.44, wy1 + 0.48, 0.12]])
			"pediment":
				moulding(k, f, "trim", 1.18, 2.82, [[wy1 + 0.14, wy1 + 0.2, 0.1], [wy1 + 0.2, wy1 + 0.26, 0.15]])
				var a := f.p(1.18, wy1 + 0.26, 0.04); var b := f.p(2.82, wy1 + 0.26, 0.04); var c := f.p(2.0, wy1 + 0.68, 0.04)
				k.tri(wall_mat, a, b, c, f.z)
				# the raking cornices, proud of the tympanum
				for side: float in [-1.0, 1.0]:
					var e0 := f.p(2.0 + side * 0.86, wy1 + 0.24, 0.0); var e1 := f.p(2.0, wy1 + 0.72, 0.0)
					var dir := (e1 - e0).normalized()
					var perp := f.z.cross(dir).normalized()
					if perp.dot(f.y) < 0.0: perp = -perp
					k.box("trim", (e0 + e1) * 0.5 + perp * 0.045 + f.z * 0.08, Vector3((e1 - e0).length() * 0.5 + 0.05, 0.045, 0.08), Basis(dir, perp, f.z), 63 & ~32)
			"arch":
				# a segmental hood in voussoirs, with a keystone
				for i in 9:
					var a0 := PI * (0.08 + 0.84 * i / 9.0); var a1 := PI * (0.08 + 0.84 * (i + 1) / 9.0)
					var am := (a0 + a1) * 0.5
					var r := 0.72
					var c := f.p(2.0 - cos(am) * r, wy1 - 0.06 + sin(am) * 0.38, 0.05)
					var t := (f.x * sin(am) * r + f.y * cos(am) * 0.38).normalized()
					var n := t.cross(f.z).normalized()
					var kk := 1.35 if i == 4 else 1.0
					k.box("trim", c + f.z * 0.02 * kk, Vector3(0.075, 0.1 * kk, 0.05 * kk), Basis(t, -n, f.z).orthonormalized())
		if fl < floors - 2:
			moulding(k, f, "trim", 0, BAY, [[y1 - 0.1, y1 - 0.04, 0.06], [y1 - 0.04, y1, 0.1]])
	# ---- the edges of the bay: quoins where the house ends, a pilaster between its two bays
	if hl: quoins(k, f, "trim", 0.0, -1.0, G0 + 0.24, top)
	else: pilaster(k, f, "trim", 0.0, G0 + 0.24, top)
	if hr: quoins(k, f, "trim", BAY, 1.0, G0 + 0.24, top)
	# ---- the main cornice: architrave, frieze, bed moulding, modillions, corona, cymatium
	var ct := top
	moulding(k, f, "trim", 0, BAY, [[ct - 0.14, ct - 0.08, 0.04], [ct - 0.08, ct, 0.065]])
	bx(k, f, wall_mat, 0, BAY, ct, ct + 0.3, 0, 0.02, 4 | 8 | 16 | 1 | 2)
	moulding(k, f, "trim", 0, BAY, [[ct + 0.3, ct + 0.35, 0.08], [ct + 0.35, ct + 0.4, 0.12]])
	k.fine = true
	var mx := 0.14
	while mx < BAY:
		bx(k, f, "trim", mx, mx + 0.1, ct + 0.4, ct + 0.52, 0.0, 0.36, 31)
		bx(k, f, "trim", mx + 0.01, mx + 0.09, ct + 0.33, ct + 0.4, 0.26, 0.36, 31)
		mx += 0.4
	k.fine = false
	moulding(k, f, "trim", 0, BAY, [[ct + 0.52, ct + 0.66, 0.46], [ct + 0.66, ct + 0.72, 0.5], [ct + 0.72, ct + 0.76, 0.47]])
	# the gutter along the eave
	k.cyl_axis("iron", f.p(0, ct + 0.82, 0.55), f.p(BAY, ct + 0.82, 0.55), 0.07, 6)
	# ---- the roof: tin, with standing seams, falling back from the eave
	var r0 := f.p(0, ct + 0.76, 0.47); var r1 := f.p(BAY, ct + 0.76, 0.47)
	var r2 := f.p(BAY, ct + 2.6, -2.6); var r3 := f.p(0, ct + 2.6, -2.6)
	var roof_n := (f.y * 3.07 + f.z * 1.84).normalized()
	k.quad("tin", r0, r1, r2, r3, roof_n, f.o)
	k.fine = true
	var sx := 0.25
	while sx < BAY:
		var a := f.p(sx, ct + 0.76, 0.47) + roof_n * 0.025; var b := f.p(sx, ct + 2.6, -2.6) + roof_n * 0.025
		k.box("tin", (a + b) * 0.5, Vector3(0.012, 0.025, (a - b).length() * 0.5), Basis(f.x, roof_n, (a - b).normalized()).orthonormalized())
		sx += 0.5
	k.fine = false
	# a party wall where the house ends, so a taller house shows its brick flank above a lower one
	for edge in ([0.0] if hl else []) + ([BAY] if hr else []):
		var xs: float = edge
		k.quad("brick", f.p(xs, top - F1, 0.0), f.p(xs, top - F1, -4.0), f.p(xs, ct + 2.9, -4.0), f.p(xs, ct + 0.9, 0.0), -f.x if edge == 0.0 else f.x, f.o)
		k.quad("brick", f.p(xs, top - F1, -4.0), f.p(xs, top - F1, 0.0), f.p(xs, ct + 0.9, 0.0), f.p(xs, ct + 2.9, -4.0), f.x if edge == 0.0 else -f.x, f.o)
		bx(k, f, "stone", xs - 0.12, xs + 0.12, ct + 0.86, ct + 0.96, -0.05, 0.5)
	if s.get("chimney", false):
		var cx := rng.randf_range(0.7, 2.8)
		bx(k, f, "brick", cx, cx + 0.62, ct + 1.2, ct + 3.5, -1.95, -1.35)
		bx(k, f, "stone", cx - 0.06, cx + 0.68, ct + 3.5, ct + 3.62, -2.01, -1.29)
		bx(k, f, "brick", cx - 0.02, cx + 0.64, ct + 3.62, ct + 3.7, -1.97, -1.33)
		for px in [cx + 0.17, cx + 0.45]:
			k.cyl("brick", f.p(px, ct + 3.7, -1.65), 0.08, 0.32, 6, 0.065)
	if s.get("drainpipe", false):
		drainpipe(k, f, BAY - 0.3 if hr else BAY - 0.35, ct + 0.3)
	out["top"] = top
	return out

# ---------------------------------------------------------------- a log izba bay
## Logs, actually: round logs stacked course on course with the chinking dark between them,
## stopped at the window and door openings; saddle-notched log ends at the corner.
static func logs(k: TownKit, f: Frame, x0: float, x1: float, y0: float, y1: float, holes: Array, r := 0.135) -> void:
	# the dark chinking behind
	var back := Frame.new(f.o - f.z * (r * 0.4), f.x, f.z)
	wall(k, back, "wood", x0, x1, y0, y1)
	var y := y0 + r
	while y < y1:
		var segs := [[x0, x1]]
		for h in holes:
			if y + r <= h[2] or y - r >= h[3]: continue
			var next := []
			for sg in segs:
				if sg[1] <= h[0] or sg[0] >= h[1]: next.append(sg); continue
				if sg[0] < h[0]: next.append([sg[0], h[0]])
				if sg[1] > h[1]: next.append([h[1], sg[1]])
			segs = next
		for sg in segs:
			if sg[1] - sg[0] > 0.05:
				k.cyl_axis("wood", f.p(sg[0], y, 0.0), f.p(sg[1], y, 0.0), r * (0.92 + 0.08 * sin(y * 13.0)), 6)
		y += r * 1.9

static func izba(k: TownKit, f: Frame, s: Dictionary) -> Dictionary:
	var out := {}
	var carve: String = s.get("carve", "carved_white")
	const H := 3.2
	bx(k, f, "stone", 0, BAY, 0, 0.35, 0, 0.16, 4 | 16 | 1 | 2)          # a stone footing
	if String(s.get("kind", "window")) == "door":
		var back := Frame.new(f.o - f.z * 0.05, f.x, f.z)
		wall_hole(k, back, "wood", 0, BAY, 0.35, H, 1.45, 2.55, 0.35, 2.5, 0.2, "", "wood")
		logs(k, f, 0, BAY, 0.35, H, [[1.4, 2.6, 0.0, 2.55]])
		wall(k, f, "wood", 1.45, 2.55, 0.0, 0.35)
		if not s.get("door_open", false):
			bx(k, f, "wood", 1.47, 2.53, 0.35, 2.48, -0.25, -0.2)
			for i in 5:                                                   # a plank door, battened
				bx(k, f, "wood", 1.49 + i * 0.21, 1.5 + i * 0.21 + 0.19, 0.37, 2.46, -0.2, -0.18, 16)
			bx(k, f, "wood", 1.5, 2.5, 0.75, 0.86, -0.18, -0.15)
			bx(k, f, "wood", 1.5, 2.5, 1.95, 2.06, -0.18, -0.15)
		out["door"] = f.p(2.0, 0.0, -0.25)
		# door posts and a lintel, carved
		bx(k, f, carve, 1.3, 1.45, 0.35, 2.6, 0.0, 0.18, 31)
		bx(k, f, carve, 2.55, 2.7, 0.35, 2.6, 0.0, 0.18, 31)
		bx(k, f, carve, 1.25, 2.75, 2.5, 2.7, 0.0, 0.2, 31)
		bx(k, f, "wood", 1.3, 2.7, 0.0, 0.3, 0, 0.6)                    # a plank step
		# a little porch roof on carved posts
		k.quad("tin", f.p(1.1, 3.0, 0.0), f.p(2.9, 3.0, 0.0), f.p(2.9, 2.78, 0.85), f.p(1.1, 2.78, 0.85), (f.y * 0.85 + f.z * 0.22).normalized(), f.o)
		for px in [1.18, 2.72]:
			k.cyl("wood", f.p(px, 0.3, 0.72), 0.05, 2.5, 6)
			bx(k, f, carve, px - 0.08, px + 0.08, 2.55, 2.8, 0.0, 0.78, 3)
	else:
		# two small windows, each with a carved, painted surround and open shutters
		var back := Frame.new(f.o - f.z * 0.05, f.x, f.z)
		wall_hole(k, back, "wood", 0, BAY, 0.35, H, 1.5, 2.5, 1.15, 2.25, 0.16, "glass", "wood")
		logs(k, f, 0, BAY, 0.35, H, [[1.45, 2.55, 1.1, 2.3]])
		casement(k, back, 1.5, 2.5, 1.15, 2.25, 0.16, s.get("lit", false), "carved_white")
		bx(k, f, carve, 1.3, 2.7, 2.25, 2.75, 0.06, 0.16, 31)            # the carved top board (kokoshnik)
		k.tri(carve, f.p(1.3, 2.75, 0.16), f.p(2.7, 2.75, 0.16), f.p(2.0, 3.0, 0.16), f.z)
		bx(k, f, carve, 1.3, 2.7, 0.85, 1.15, 0.06, 0.16, 31)            # and the apron below
		bx(k, f, carve, 1.32, 1.5, 1.15, 2.25, 0.06, 0.16, 31)
		bx(k, f, carve, 2.5, 2.68, 1.15, 2.25, 0.06, 0.16, 31)
		bx(k, f, "wood", 1.25, 2.75, 1.08, 1.15, 0.06, 0.24)             # the sill
		# shutters, folded back, with their ledges
		for sx in [0.92, 2.72]:
			bx(k, f, "carved_blue", sx, sx + 0.36, 1.12, 2.28, 0.15, 0.19)
			k.fine = true
			bx(k, f, "wood", sx + 0.02, sx + 0.34, 1.3, 1.36, 0.19, 0.21)
			bx(k, f, "wood", sx + 0.02, sx + 0.34, 2.02, 2.08, 0.19, 0.21)
			k.fine = false
	# corner log ends, saddle-notched, where this bay ends a house
	if s.get("corner_left", false):
		var y := 0.35 + 0.135
		while y < H:
			k.cyl_axis("wood", f.p(0.05, y, -0.45), f.p(0.05, y, 0.25), 0.13, 6)
			k.tri("wood", f.p(0.05 - 0.13, y, 0.25), f.p(0.05 + 0.13, y, 0.25), f.p(0.05, y + 0.13, 0.25), f.z)
			y += 0.135 * 1.9
	# the gable to the street: boards, a carved bargeboard, a little attic window
	var g0 := f.p(0, H, 0.05); var g1 := f.p(BAY, H, 0.05); var gt := f.p(2.0, H + 2.1, 0.05)
	k.tri("wood", g0, g1, gt, f.z)
	k.fine = true
	var bxp := 0.2
	while bxp < BAY - 0.1:                                   # vertical boards on the gable
		var hgt := 2.1 * (1.0 - absf(bxp - 2.0) / 2.0)
		if hgt > 0.1: bx(k, f, "wood", bxp, bxp + 0.03, H, H + hgt - 0.05, 0.05, 0.08, 16 | 1 | 2)
		bxp += 0.18
	k.fine = false
	k.quad(carve, f.p(-0.2, H - 0.15, 0.14), f.p(2.0, H + 2.05, 0.14), f.p(2.0, H + 2.35, 0.14), f.p(-0.2, H + 0.15, 0.14), f.z, f.o)
	k.quad(carve, f.p(2.0, H + 2.05, 0.14), f.p(BAY + 0.2, H - 0.15, 0.14), f.p(BAY + 0.2, H + 0.15, 0.14), f.p(2.0, H + 2.35, 0.14), f.z, f.o)
	k.cyl("wood", f.p(2.0, H + 2.0, 0.15), 0.06, 0.55, 6, 0.0)          # the finial at the peak
	wall_hole(k, Frame.new(f.o + f.z * 0.05, f.x, f.z), "wood", 1.7, 2.3, H + 0.6, H + 1.2, 1.75, 2.25, H + 0.65, H + 1.15, 0.12, "glass", "wood")
	bx(k, f, carve, 1.65, 2.35, H + 1.15, H + 1.35, 0.05, 0.12)
	# roof slopes back from the gable, with a ridge board
	k.quad("tin", f.p(-0.25, H - 0.1, 0.3), f.p(2.0, H + 2.4, 0.3), f.p(2.0, H + 2.4, -6.0), f.p(-0.25, H - 0.1, -6.0), (-f.x + f.y).normalized(), f.o)
	k.quad("tin", f.p(2.0, H + 2.4, 0.3), f.p(BAY + 0.25, H - 0.1, 0.3), f.p(BAY + 0.25, H - 0.1, -6.0), f.p(2.0, H + 2.4, -6.0), (f.x + f.y).normalized(), f.o)
	bx(k, f, "wood", 1.92, 2.08, H + 2.38, H + 2.5, -6.0, 0.32)
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
