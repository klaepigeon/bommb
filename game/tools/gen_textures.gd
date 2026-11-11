extends SceneTree
## Generates the environment texture library (res://textures/*.png): small, dirty, PS1-scale.
## godot --headless --path game -s tools/gen_textures.gd
## Both apartments (Flat 47 and its Backrooms) use these same textures; the Backrooms alter them
## in the material (tint, damp, mould, pattern drift), not with different art.

var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.seed = 1996
	DirAccess.make_dir_recursive_absolute("res://textures")
	var n := 0
	for m in get_method_list():
		if String(m.name).begins_with("t_"):
			var img: Image = call(m.name)
			img.save_png("res://textures/%s.png" % String(m.name).substr(2))
			n += 1
	print("gen_textures: ", n)
	quit()

func nz(seed: int, freq: float, oct := 3, type := FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> FastNoiseLite:
	var f := FastNoiseLite.new()
	f.seed = seed; f.frequency = freq; f.fractal_octaves = oct; f.noise_type = type
	return f

## tileable 2D noise: sample on a torus
func tn(f: FastNoiseLite, x: float, y: float, w: float, h: float) -> float:
	var a := x / w * TAU; var b := y / h * TAU
	var r := w / TAU
	return f.get_noise_3d(cos(a) * r, sin(a) * r + cos(b) * r * 0.7, sin(b) * r * 0.7 + 100.0) * 0.5 + 0.5

func make(w: int, h: int, fn: Callable) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			img.set_pixel(x, y, fn.call(x, y))
	return img

## grime: darker toward the bottom of a wall texture (tiles vertically once per wall height)
func grime(c: Color, k: float) -> Color:
	return c.darkened(clampf(k, 0.0, 0.8))

# ------------------------------------------------------------------ walls

func t_wallpaper_damask() -> Image:      # living room: faded olive damask, water-stained
	var n := nz(1, 0.05); var st := nz(2, 0.02, 4)
	return make(128, 128, func(x: int, y: int) -> Color:
		var u := float(x % 32) / 32.0 - 0.5; var v := float(y % 48) / 48.0 - 0.5
		var off := 0.5 if (y / 48) % 2 == 1 else 0.0
		u = fmod(u + off + 1.5, 1.0) - 0.5
		var motif := 1.0 - smoothstep(0.18, 0.24, sqrt(u * u * 1.8 + v * v) + 0.05 * sin(atan2(v, u) * 6.0))
		var c := Color(0.42, 0.40, 0.27).lerp(Color(0.52, 0.49, 0.33), motif * 0.8)
		c = c.darkened(0.15 * tn(n, x, y, 128, 128))
		var stain := tn(st, x, y, 128, 128)
		if stain > 0.62: c = c.lerp(Color(0.33, 0.28, 0.16), (stain - 0.62) * 2.5)
		return c)

func t_wallpaper_floral() -> Image:      # bedroom: dusty rose stripes with small flowers
	var n := nz(3, 0.06)
	return make(128, 128, func(x: int, y: int) -> Color:
		var stripe := 1.0 if (x % 16) < 3 else 0.0
		var fx := float((x + 8) % 16) - 8.0; var fy := float(y % 20) - 10.0
		var flower := 1.0 - smoothstep(2.0, 3.5, sqrt(fx * fx + fy * fy))
		var c := Color(0.56, 0.45, 0.43)
		c = c.lerp(Color(0.47, 0.36, 0.35), stripe * 0.7)
		c = c.lerp(Color(0.62, 0.53, 0.40), flower * 0.7)
		return c.darkened(0.2 * tn(n, x, y, 128, 128)))

func t_wallpaper_child() -> Image:       # child's room: pale blue with small boats
	var n := nz(4, 0.05)
	return make(64, 64, func(x: int, y: int) -> Color:
		var bx := x % 16; var by := y % 16
		var boat := (by >= 9 and by <= 11 and bx >= 3 and bx <= 12) or (bx == 8 and by >= 3 and by < 9) or (by >= 4 and by <= 7 and bx > 8 and bx < 8 + (8 - by))
		var c := Color(0.52, 0.60, 0.66)
		if boat: c = Color(0.62, 0.66, 0.68)
		return c.darkened(0.18 * tn(n, x, y, 64, 64)))

func t_plaster() -> Image:               # corridor / kitchen upper walls: dirty off-white, cracks
	var n := nz(5, 0.04, 4); var cr := nz(6, 0.08, 1, FastNoiseLite.TYPE_CELLULAR)
	return make(64, 64, func(x: int, y: int) -> Color:
		var c := Color(0.62, 0.60, 0.53).darkened(0.25 * tn(n, x, y, 64, 64))
		var crack := absf(tn(cr, x, y, 64, 64) - 0.5)
		if crack < 0.012: c = c.darkened(0.35)
		return c)

func t_plaster_draft() -> Image:         # Flat 48: bare grey draft plaster with pencil guide lines
	var n := nz(7, 0.06)
	return make(64, 64, func(x: int, y: int) -> Color:
		var c := Color(0.60, 0.60, 0.58).darkened(0.08 * tn(n, x, y, 64, 64))
		if x % 32 == 0 or y % 32 == 0: c = c.darkened(0.25)
		return c)

func t_tile_wall() -> Image:             # bathroom / kitchen splashback: white tile, black grout
	var n := nz(8, 0.08)
	return make(64, 64, func(x: int, y: int) -> Color:
		if x % 16 == 0 or y % 16 == 0: return Color(0.18, 0.17, 0.14)
		var c := Color(0.74, 0.74, 0.70).darkened(0.25 * tn(n, x, y, 64, 64))
		if (x % 16) < 2 or (y % 16) < 2: c = c.lightened(0.08)
		return c)

func t_tile_floor() -> Image:            # bathroom floor: small grey/white checker
	var n := nz(9, 0.1)
	return make(64, 64, func(x: int, y: int) -> Color:
		if x % 8 == 0 or y % 8 == 0: return Color(0.15, 0.14, 0.12)
		var chk := ((x / 8) + (y / 8)) % 2 == 0
		var c := Color(0.58, 0.58, 0.55) if chk else Color(0.36, 0.37, 0.36)
		return c.darkened(0.3 * tn(n, x, y, 64, 64)))

func t_parquet() -> Image:               # living / bedroom / corridor floor: herringbone, grey with wear
	var n := nz(10, 0.2); var w := nz(11, 0.03)
	return make(64, 64, func(x: int, y: int) -> Color:
		var blk := ((x / 8) + (y / 32)) % 2
		var along := y if blk == 0 else x
		var plank := ((x / 8) * 7 + (y / 32) * 3) % 5
		var c := Color(0.36, 0.27, 0.18).lightened(plank * 0.03)
		c = c.darkened(0.25 * tn(n, along * 0.3, x + y, 64, 64))
		if x % 8 == 0 or y % 32 == 0: c = c.darkened(0.45)
		return c.lerp(Color(0.38, 0.36, 0.33), 0.35 * tn(w, x, y, 64, 64)))

func t_lino() -> Image:                  # kitchen floor: patterned linoleum, worn through
	var n := nz(12, 0.05)
	return make(64, 64, func(x: int, y: int) -> Color:
		var d := (x + y) % 16 < 8
		var c := Color(0.47, 0.40, 0.30) if d else Color(0.40, 0.36, 0.30)
		if (x % 16 == 0) or (y % 16 == 0): c = Color(0.30, 0.26, 0.20)
		var wear := tn(n, x, y, 64, 64)
		if wear > 0.6: c = c.lerp(Color(0.23, 0.20, 0.17), (wear - 0.6) * 2.0)
		return c)

func t_carpet() -> Image:                # rug: red/brown oriental, filthy
	var n := nz(13, 0.25); var p := nz(14, 0.05)
	return make(64, 64, func(x: int, y: int) -> Color:
		var u := absf(float(x) - 32.0) / 32.0; var v := absf(float(y) - 32.0) / 32.0
		var border := maxf(u, v) > 0.8
		var med := 1.0 - smoothstep(0.25, 0.35, u + v)
		var c := Color(0.38, 0.12, 0.10)
		if border: c = Color(0.22, 0.13, 0.08)
		c = c.lerp(Color(0.50, 0.40, 0.22), med * 0.6)
		c = c.darkened(0.3 * tn(n, x, y, 64, 64) + 0.2 * tn(p, x, y, 64, 64))
		return c)

func t_concrete() -> Image:              # stair landing, Backrooms underlay
	var n := nz(15, 0.1, 4)
	return make(64, 64, func(x: int, y: int) -> Color:
		var k := tn(n, x, y, 64, 64)
		var c := Color(0.42, 0.42, 0.40).darkened(0.35 * k)
		if rng.randf() < 0.03: c = c.lightened(0.15)
		return c)

func t_ceiling() -> Image:               # yellowed plaster ceiling with water rings
	var n := nz(16, 0.04); var r := nz(17, 0.02, 1)
	return make(64, 64, func(x: int, y: int) -> Color:
		var c := Color(0.58, 0.56, 0.48).darkened(0.18 * tn(n, x, y, 64, 64))
		var ring := absf(fmod(tn(r, x, y, 64, 64) * 6.0, 1.0) - 0.5)
		if ring < 0.05 and tn(r, x, y, 64, 64) > 0.55: c = Color(0.45, 0.38, 0.24)
		return c)

func t_green_paint() -> Image:           # stairwell: green gloss to shoulder height
	var n := nz(18, 0.06)
	return make(64, 64, func(x: int, y: int) -> Color:
		var c := Color(0.22, 0.34, 0.27) if y > 20 else Color(0.62, 0.62, 0.55)
		if y == 20 or y == 21: c = Color(0.15, 0.2, 0.16)
		return c.darkened(0.25 * tn(n, x, y, 64, 64)))

# ------------------------------------------------------------------ furniture / props

func t_wood_dark() -> Image:             # veneer furniture
	var n := nz(19, 0.03, 2)
	return make(64, 64, func(x: int, y: int) -> Color:
		var g := sin((float(x) + tn(n, x, y, 64, 64) * 30.0) * 0.6) * 0.5 + 0.5
		return Color(0.25, 0.15, 0.09).lerp(Color(0.33, 0.21, 0.12), g).darkened(0.1 * rng.randf()))

func t_wood_light() -> Image:            # kitchen units, shelves, the child's bed
	var n := nz(20, 0.03, 2)
	return make(64, 64, func(x: int, y: int) -> Color:
		var g := sin((float(y) + tn(n, x, y, 64, 64) * 24.0) * 0.5) * 0.5 + 0.5
		return Color(0.55, 0.43, 0.29).lerp(Color(0.62, 0.50, 0.34), g).darkened(0.12 * rng.randf()))

func t_wood_raw() -> Image:              # planks, boards, crates
	var n := nz(21, 0.05, 3)
	return make(64, 64, func(x: int, y: int) -> Color:
		var c := Color(0.48, 0.38, 0.26).darkened(0.35 * tn(n, x * 3, y * 0.4, 64, 64))
		if y % 16 == 0: c = c.darkened(0.5)
		return c)

func t_fabric_green() -> Image:          # the sofa / armchair
	var n := nz(22, 0.2)
	return make(32, 32, func(x: int, y: int) -> Color:
		var c := Color(0.22, 0.30, 0.20).darkened(0.25 * tn(n, x, y, 32, 32))
		if (x + y) % 4 == 0: c = c.darkened(0.12)
		return c)

func t_fabric_bed() -> Image:            # sheets and blankets
	var n := nz(23, 0.1)
	return make(32, 32, func(x: int, y: int) -> Color:
		var c := Color(0.55, 0.53, 0.50).darkened(0.25 * tn(n, x, y, 32, 32))
		if x % 8 < 2: c = c.lerp(Color(0.45, 0.32, 0.30), 0.4)
		return c)

func t_enamel() -> Image:                # stove, fridge, bath, sink: chipped off-white
	var n := nz(24, 0.08)
	return make(32, 32, func(x: int, y: int) -> Color:
		var c := Color(0.78, 0.77, 0.72).darkened(0.2 * tn(n, x, y, 32, 32))
		if rng.randf() < 0.02: c = Color(0.15, 0.13, 0.12)
		return c)

func t_metal() -> Image:                 # painted metal: radiators, fuse box, padlock
	var n := nz(25, 0.1)
	return make(32, 32, func(x: int, y: int) -> Color:
		var c := Color(0.40, 0.42, 0.42).darkened(0.3 * tn(n, x, y, 32, 32))
		if tn(n, x * 2, y * 2, 32, 32) > 0.7: c = c.lerp(Color(0.40, 0.22, 0.10), 0.6)
		return c)

func t_door_padded() -> Image:           # the front doors: padded brown leatherette, studded
	var n := nz(26, 0.1)
	return make(32, 64, func(x: int, y: int) -> Color:
		var c := Color(0.30, 0.18, 0.12).darkened(0.25 * tn(n, x, y, 32, 64))
		if (x % 8 == 4 and y % 8 == 4): c = Color(0.65, 0.55, 0.35)
		return c)

func t_door_panel() -> Image:            # interior doors: painted panel doors, grubby
	var n := nz(27, 0.06)
	return make(32, 64, func(x: int, y: int) -> Color:
		var c := Color(0.66, 0.64, 0.56).darkened(0.2 * tn(n, x, y, 32, 64))
		var inset := (x > 4 and x < 27) and ((y > 4 and y < 28) or (y > 34 and y < 59))
		var edge := (x == 4 or x == 27) and ((y > 4 and y < 28) or (y > 34 and y < 59))
		if edge: c = c.darkened(0.4)
		elif inset: c = c.darkened(0.08)
		if y > 50 and x > 2 and x < 30: c = c.darkened(0.15 * tn(n, x * 3, y * 3, 32, 64))
		return c)

func t_glass_night() -> Image:           # windows: almost black, a faint reflection
	return make(16, 16, func(x: int, y: int) -> Color:
		return Color(0.03, 0.04, 0.05).lightened(0.04 * float(x + y) / 32.0))

func t_paper() -> Image:                 # documents, notes, the sticky note's paper
	var n := nz(28, 0.15)
	return make(32, 32, func(x: int, y: int) -> Color:
		var c := Color(0.82, 0.79, 0.68).darkened(0.12 * tn(n, x, y, 32, 32))
		if y % 4 == 0 and y > 4 and x > 3 and x < 28 and rng.randf() < 0.85: c = c.darkened(0.45)
		return c)

func t_sticky() -> Image:                # the yellow sticky notes
	var n := nz(29, 0.15)
	return make(16, 16, func(x: int, y: int) -> Color:
		return Color(0.86, 0.80, 0.30).darkened(0.1 * tn(n, x, y, 16, 16)))

func t_cardboard() -> Image:             # the boxes
	var n := nz(30, 0.1)
	return make(32, 32, func(x: int, y: int) -> Color:
		var c := Color(0.52, 0.40, 0.25).darkened(0.2 * tn(n, x, y, 32, 32))
		if y == 15 or y == 16: c = Color(0.65, 0.58, 0.42)   # tape
		return c)

func t_mould() -> Image:                 # overlay: black mould and damp (alpha in red channel)
	var n := nz(31, 0.06, 5)
	return make(64, 64, func(x: int, y: int) -> Color:
		var k := tn(n, x, y, 64, 64)
		var m := smoothstep(0.55, 0.75, k)
		return Color(m, m, m))

func t_coral() -> Image:                 # the growth, where it reaches into the rooms
	var n := nz(32, 0.12, 3, FastNoiseLite.TYPE_CELLULAR)
	return make(32, 32, func(x: int, y: int) -> Color:
		var k := tn(n, x, y, 32, 32)
		return Color(0.62, 0.22, 0.20).lerp(Color(0.86, 0.74, 0.68), k))

func t_black() -> Image:
	return make(4, 4, func(_x: int, _y: int) -> Color: return Color(0.02, 0.02, 0.02))

func t_white() -> Image:
	return make(4, 4, func(_x: int, _y: int) -> Color: return Color(1, 1, 1))
