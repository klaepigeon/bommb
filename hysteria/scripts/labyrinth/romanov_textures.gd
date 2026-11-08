class_name RomanovTextures
## Textures for the town under the Romanovs, painted in code like everything else in HYSTERIA,
## at the flat's texel density (about 128 px a metre on walls), unfiltered. Each surface gets a
## height field too, turned into a normal map, so gas light rakes across the cobbles and the
## rustication instead of lying flat. Cached: built once per run.
##
##   cobbles    granite setts in sand, worn round, wet in the low places (roughness map)
##   stucco     lime render over brick, in the town's ochres and creams: mottled, rain-streaked
##              from the cornices down, cracked, and in places fallen away to the brick
##   rustic     the same render, scored into the ground-floor blocks of a merchant house
##   trim       the white of window surrounds and cornices, gone grey and chalky
##   wood       weathered grey planks, for the izbas; carved and painted trim (white, faded blue)
##   tin        the roofs: green-grey sheet with seams and rust run-off
##   glass      dark old glass, a little warped, with a sheen
##   shop       a lit shop window: shelves, jars, loaves, behind dirty glass
##   gold       the dome's gilding, tarnished
##   plaster_in interior walls: distempered plaster with a stencilled frieze

static var _cache := {}

static func get_set(name: String) -> Dictionary:
	if _cache.has(name):
		return _cache[name]
	var d: Dictionary
	match name:
		"cobbles": d = _cobbles()
		"stucco_ochre": d = _stucco(Color("c9a35e"), 11)
		"stucco_cream": d = _stucco(Color("d8ccae"), 12)
		"stucco_rose": d = _stucco(Color("c08a78"), 13)
		"stucco_green": d = _stucco(Color("8fa38a"), 14)
		"rustic_ochre": d = _rustic(Color("bf9655"), 21)
		"rustic_cream": d = _rustic(Color("cfc3a4"), 22)
		"trim": d = _trim()
		"wood": d = _wood(31)
		"carved_white": d = _carved(Color("e6e2d6"), 41)
		"carved_blue": d = _carved(Color("7d97b4"), 42)
		"tin": d = _tin()
		"glass": d = _glass()
		"shop": d = _shop()
		"shop_bakery", "shop_photo", "shop_clock", "shop_tavern", "shop_hotel": d = _shop_kind(name.trim_prefix("shop_"))
		"gold": d = _gold()
		"plaster_in": d = _plaster_in()
		"parquet": d = _parquet()
		"brick": d = _brick()
		"paper": d = _paper(false)
		"paper_old": d = _paper(true)
		"leaves": d = _leaves()
		"wallpaper_red": d = _wallpaper(Color(0.42, 0.08, 0.07), Color(0.62, 0.45, 0.2), 171)
		"wallpaper_damask": d = _wallpaper(Color(0.52, 0.58, 0.48), Color(0.78, 0.76, 0.62), 172)
		"rug": d = _rug()
		"backdrop": d = _backdrop()
		"lace": d = _lace()
		"planks": d = _planks()
		"wicker": d = _wicker()
		_: d = _stucco(Color("aaaaaa"), 1)
	_cache[name] = d
	return d

# ---------------------------------------------------------------- helpers
static func _noise(seed: int, freq: float, octaves := 4, kind := FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed; n.frequency = freq; n.noise_type = kind
	n.fractal_type = FastNoiseLite.FRACTAL_FBM; n.fractal_octaves = octaves
	return n

static func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = seed
	return r

## albedo + height (+ roughness) images to textures; the height becomes a normal map
static func _pack(albedo: Image, height: Image, rough: Image = null, strength := 6.0) -> Dictionary:
	albedo.generate_mipmaps()
	var d := {"albedo": ImageTexture.create_from_image(albedo)}
	if height:
		var nm := height.duplicate() as Image
		nm.convert(Image.FORMAT_RGBA8)
		nm.bump_map_to_normal_map(strength)
		nm.generate_mipmaps()
		d["normal"] = ImageTexture.create_from_image(nm)
	if rough:
		rough.generate_mipmaps()
		d["rough"] = ImageTexture.create_from_image(rough)
	return d

static func _img(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGB8)

# ---------------------------------------------------------------- cobbles
static func _cobbles() -> Dictionary:
	const S := 256
	var cell := FastNoiseLite.new(); cell.seed = 7; cell.noise_type = FastNoiseLite.TYPE_CELLULAR
	cell.frequency = 0.034; cell.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	cell.cellular_jitter = 0.75; cell.fractal_type = FastNoiseLite.FRACTAL_NONE
	cell.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var edge := cell.get_seamless_image(S, S, false, false, 0.1)
	cell.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	var val := cell.get_seamless_image(S, S, false, false, 0.1)
	var grain := _noise(8, 0.08, 3).get_seamless_image(S, S)
	var wet := _noise(9, 0.012, 3).get_seamless_image(S, S)
	var a := _img(S, S); var h := Image.create(S, S, false, Image.FORMAT_L8); var r := Image.create(S, S, false, Image.FORMAT_L8)
	for y in S:
		for x in S:
			var e := edge.get_pixel(x, y).r           # 0 at the joints
			var v := val.get_pixel(x, y).r
			var g := grain.get_pixel(x, y).r
			var w := smoothstep(0.58, 0.72, wet.get_pixel(x, y).r)   # puddled in the low places
			var stone := smoothstep(0.05, 0.22, e)
			var dome := sqrt(clampf(e * 3.2, 0.0, 1.0))               # setts are worn round on top
			var base := Color(0.33, 0.32, 0.31).lerp(Color(0.5, 0.47, 0.43), v)
			base = base.lerp(Color(0.42, 0.36, 0.3), absf(v - 0.5) * 0.6)   # some warmer granite
			base = base * (0.82 + g * 0.35)
			var sand := Color(0.2, 0.18, 0.15) * (0.8 + g * 0.4)
			var c := sand.lerp(base, stone)
			c = c.darkened(w * 0.35)                                  # wet stone is darker
			a.set_pixel(x, y, c)
			h.set_pixel(x, y, Color(stone * (0.55 + dome * 0.45), 0, 0))
			r.set_pixel(x, y, Color(lerpf(0.92, 0.25, w * stone), 0, 0))   # and shiny
	return _pack(a, h, r, 9.0)

# ---------------------------------------------------------------- stucco
static func _stucco(col: Color, seed: int, rust_rows := false) -> Dictionary:
	const S := 256
	var mott := _noise(seed, 0.02, 5).get_seamless_image(S, S)
	var fine := _noise(seed + 100, 0.2, 2).get_seamless_image(S, S)
	var fall := _noise(seed + 200, 0.008, 3).get_seamless_image(S, S)
	var rng := _rng(seed)
	var streak := PackedFloat32Array(); streak.resize(S)     # rain run-off from above, per column
	var acc := 0.0
	for x in S:
		acc = clampf(acc + rng.randf_range(-0.08, 0.08), 0.0, 1.0)
		streak[x] = acc * acc
	var a := _img(S, S); var h := Image.create(S, S, false, Image.FORMAT_L8)
	for y in S:
		for x in S:
			var m := mott.get_pixel(x, y).r; var f := fine.get_pixel(x, y).r
			var c := col * (0.86 + m * 0.24) * (0.95 + f * 0.1)
			c = c.darkened(smoothstep(0.75, 1.0, float(y) / S) * 0.18 * (0.5 + m))      # splash-back at the foot
			# rain streaks: darker and greyer, strongest under the top edge
			var s := streak[x] * (1.0 - float(y) / S) * 0.5
			c = c.lerp(Color(0.33, 0.33, 0.32), s * 0.7)
			# where the render has fallen away: the brick underneath
			var hole := smoothstep(0.765, 0.775, fall.get_pixel(x, y).r)
			var height := 0.6 + f * 0.08
			if hole > 0.0:
				var bx := (x + (8 if (y / 8) % 2 == 0 else 0)) % 16
				var mortar := (y % 8 == 0) or bx == 0
				var brick := Color(0.4, 0.24, 0.19) * (0.75 + f * 0.35)
				c = c.lerp(Color(0.6, 0.57, 0.5) if mortar else brick, hole)
				height = lerpf(height, 0.25 if mortar else 0.35, hole)
			# the broken edge of the render, a lighter lip
			var lip := smoothstep(0.745, 0.765, fall.get_pixel(x, y).r) * (1.0 - hole)
			c = c.lightened(lip * 0.12)
			a.set_pixel(x, y, c); h.set_pixel(x, y, Color(height + lip * 0.15, 0, 0))
	# cracks: a few random walks, thin and dark
	for k in 5:
		var p := Vector2(rng.randf() * S, rng.randf() * S); var d := Vector2.from_angle(rng.randf() * TAU)
		for i in 90:
			d = d.rotated(rng.randf_range(-0.5, 0.5)); p += d * 1.5
			var ix := int(p.x) % S; var iy := int(p.y) % S
			if ix < 0: ix += S
			if iy < 0: iy += S
			a.set_pixel(ix, iy, a.get_pixel(ix, iy).darkened(0.45)); h.set_pixel(ix, iy, Color(0.3, 0, 0))
	return _pack(a, h, null, 4.0)

static func _rustic(col: Color, seed: int) -> Dictionary:
	var d := _stucco(col, seed)
	# score the blocks into the albedo/height: rows of 32 px (0.25 m), joints staggered every 96
	var a: Image = (d.albedo as ImageTexture).get_image(); a.clear_mipmaps()
	var h := Image.create(256, 256, false, Image.FORMAT_L8)
	for y in 256:
		for x in 256:
			var row := y / 32
			var jx := (x + (48 if row % 2 == 1 else 0)) % 96
			var gy := y % 32
			var groove := gy < 3 or jx < 3
			var bevel := 1.0 - smoothstep(3.0, 7.0, float(mini(gy, jx)))
			var c := a.get_pixel(x, y)
			if groove: c = c.darkened(0.22)
			else: c = c.lightened(bevel * 0.06)
			a.set_pixel(x, y, c)
			h.set_pixel(x, y, Color(0.15 if groove else 0.6 + (1.0 - bevel) * 0.15, 0, 0))
	return _pack(a, h, null, 7.0)

static func _trim() -> Dictionary:
	const S := 128
	var n := _noise(51, 0.05, 4).get_seamless_image(S, S)
	var a := _img(S, S); var h := Image.create(S, S, false, Image.FORMAT_L8)
	for y in S:
		for x in S:
			var v := n.get_pixel(x, y).r
			var c := Color(0.86, 0.84, 0.78) * (0.85 + v * 0.2)
			c = c.lerp(Color(0.45, 0.45, 0.43), smoothstep(0.62, 0.8, v) * 0.5)   # soot in the hollows
			a.set_pixel(x, y, c); h.set_pixel(x, y, Color(0.5 + v * 0.2, 0, 0))
	return _pack(a, h, null, 2.0)

# ---------------------------------------------------------------- wood
static func _wood(seed: int) -> Dictionary:
	const S := 256
	var grain := _noise(seed, 0.01, 3)
	var fine := _noise(seed + 1, 0.15, 2).get_seamless_image(S, S)
	var rng := _rng(seed)
	var a := _img(S, S); var h := Image.create(S, S, false, Image.FORMAT_L8)
	var plank := 40     # px per plank (~0.3 m), horizontal logs
	var shade := []
	for i in S / plank + 2: shade.append(rng.randf_range(0.8, 1.1))
	for y in S:
		for x in S:
			var row := y / plank; var py := y % plank
			var g := grain.get_noise_2d(x * 0.6 + row * 37.0, y * 6.0) * 0.5 + 0.5
			var f := fine.get_pixel(x, y).r
			var c: Color = Color(0.4, 0.37, 0.33).lerp(Color(0.56, 0.52, 0.46), g) * float(shade[row]) * (0.9 + f * 0.2)
			var round := sin(PI * float(py) / plank)            # logs are round in section
			c = c.darkened((1.0 - round) * 0.35)
			if py < 2: c = Color(0.12, 0.11, 0.1)               # the gap between logs
			a.set_pixel(x, y, c); h.set_pixel(x, y, Color(round * 0.8 + g * 0.1, 0, 0))
	return _pack(a, h, null, 6.0)

## carved, painted window surrounds (nalichniki): a band of pierced scrollwork over chipped paint
static func _carved(paint: Color, seed: int) -> Dictionary:
	const S := 128
	var chips := _noise(seed, 0.09, 3).get_seamless_image(S, S)
	var a := Image.create(S, S, false, Image.FORMAT_RGBA8); var h := Image.create(S, S, false, Image.FORMAT_L8)
	for y in S:
		for x in S:
			var u := float(x) / S; var v := float(y) / S
			# scrolls: a repeating pattern of circles and teardrops cut through the board
			var cu := fmod(u * 4.0, 1.0) - 0.5; var cv := fmod(v * 4.0, 1.0) - 0.5
			var cut := Vector2(cu, cv * 1.3).length() < 0.2 or (absf(cu) < 0.06 and cv > 0.15)
			var ch := chips.get_pixel(x, y).r
			var c := paint * (0.88 + ch * 0.18)
			if ch > 0.66: c = Color(0.42, 0.38, 0.33)            # paint gone, grey wood
			var alpha := 0.0 if cut else 1.0
			a.set_pixel(x, y, Color(c.r, c.g, c.b, alpha)); h.set_pixel(x, y, Color(0.0 if cut else 0.7, 0, 0))
	return _pack(a, h, null, 5.0)

# ---------------------------------------------------------------- roofs, glass, gold
static func _tin() -> Dictionary:
	const S := 128
	var n := _noise(61, 0.04, 4).get_seamless_image(S, S)
	var rng := _rng(61)
	var rust := PackedFloat32Array(); rust.resize(S)
	for x in S: rust[x] = rng.randf() ** 3
	var a := _img(S, S); var h := Image.create(S, S, false, Image.FORMAT_L8)
	for y in S:
		for x in S:
			var seam := x % 32 < 3
			var v := n.get_pixel(x, y).r
			var c := Color(0.3, 0.36, 0.33) * (0.8 + v * 0.35)
			c = c.lerp(Color(0.42, 0.24, 0.13), rust[x] * (float(y) / S) * 0.8)
			if seam: c = c.lightened(0.15)
			a.set_pixel(x, y, c); h.set_pixel(x, y, Color(0.8 if seam else 0.4, 0, 0))
	return _pack(a, h, null, 4.0)

static func _glass() -> Dictionary:
	const S := 64
	var n := _noise(71, 0.06, 2).get_seamless_image(S, S)
	var a := _img(S, S)
	for y in S:
		for x in S:
			var v := n.get_pixel(x, y).r
			var sheen := smoothstep(0.35, 0.0, absf(float(x - y) / S - 0.2)) * 0.18
			a.set_pixel(x, y, Color(0.07, 0.08, 0.09) * (0.8 + v * 0.4) + Color(sheen, sheen, sheen * 1.1))
	return _pack(a, null)

static func _shop() -> Dictionary:
	# a lit shop window: warm back wall, three shelves of jars and loaves, a counter; behind the
	# grime of the glass. 128 x 128, used with emission.
	const S := 128
	var rng := _rng(81)
	var a := _img(S, S)
	a.fill(Color(0.62, 0.42, 0.2))
	for y in S:
		for x in S:
			var vg := 1.0 - Vector2(float(x) / S - 0.5, float(y) / S - 0.45).length() * 1.1
			a.set_pixel(x, y, Color(0.55, 0.36, 0.16) * clampf(vg, 0.25, 1.0))
	for shelf in [30, 62, 94]:
		a.fill_rect(Rect2i(6, shelf, S - 12, 3), Color(0.22, 0.13, 0.07))
		var x := 10
		while x < S - 16:
			var w := rng.randi_range(6, 12); var hgt := rng.randi_range(8, 20)
			var col: Color = [Color(0.5, 0.3, 0.12), Color(0.75, 0.6, 0.35), Color(0.35, 0.4, 0.3), Color(0.6, 0.2, 0.12)][rng.randi() % 4]
			a.fill_rect(Rect2i(x, shelf - hgt, w, hgt), col * rng.randf_range(0.7, 1.1))
			a.fill_rect(Rect2i(x + 1, shelf - hgt, 2, hgt), col.lightened(0.3))    # a highlight down one side
			x += w + rng.randi_range(2, 5)
	a.fill_rect(Rect2i(0, 108, S, 20), Color(0.25, 0.15, 0.08))     # the counter
	var grime := _noise(82, 0.05, 3).get_seamless_image(S, S)
	for y in S:
		for x in S:
			a.set_pixel(x, y, a.get_pixel(x, y).lerp(Color(0.25, 0.22, 0.18), grime.get_pixel(x, y).r * 0.45))
	return _pack(a, null)

static func _gold() -> Dictionary:
	const S := 64
	var n := _noise(91, 0.08, 3).get_seamless_image(S, S)
	var a := _img(S, S); var r := Image.create(S, S, false, Image.FORMAT_L8)
	for y in S:
		for x in S:
			var v := n.get_pixel(x, y).r
			var rib := x % 16 < 2
			var c := Color(0.78, 0.6, 0.25).lerp(Color(0.35, 0.3, 0.2), smoothstep(0.55, 0.8, v))
			if rib: c = c.lightened(0.2)
			a.set_pixel(x, y, c); r.set_pixel(x, y, Color(0.35 + v * 0.4, 0, 0))
	return _pack(a, null, r)

# ---------------------------------------------------------------- interiors
static func _plaster_in() -> Dictionary:
	const S := 256
	var n := _noise(101, 0.03, 4).get_seamless_image(S, S)
	var a := _img(S, S); var h := Image.create(S, S, false, Image.FORMAT_L8)
	for y in S:
		for x in S:
			var v := n.get_pixel(x, y).r
			var c := Color(0.55, 0.5, 0.42) * (0.85 + v * 0.25)
			# a stencilled frieze band near the top: little repeating lozenges in faded red
			if y > 20 and y < 40:
				var u := fmod(float(x), 24.0) - 12.0; var w := float(y) - 30.0
				if absf(u) + absf(w) * 1.2 < 8.0: c = c.lerp(Color(0.5, 0.18, 0.14), 0.65)
			if y == 18 or y == 42: c = c.darkened(0.3)
			a.set_pixel(x, y, c); h.set_pixel(x, y, Color(0.5 + v * 0.15, 0, 0))
	return _pack(a, h, null, 2.0)

static func _parquet() -> Dictionary:
	const S := 256
	var n := _noise(111, 0.05, 3).get_seamless_image(S, S)
	var a := _img(S, S); var h := Image.create(S, S, false, Image.FORMAT_L8)
	for y in S:
		for x in S:
			# herringbone: 64 x 16 px blocks at right angles
			var bx := x / 16; var by := y / 16
			var horiz := (bx + by) % 2 == 0
			var along := (x if horiz else y) % 64
			var across := (y if horiz else x) % 16
			var seam := along < 1 or across < 1
			var v := n.get_pixel(x, y).r
			var c := Color(0.36, 0.22, 0.12).lerp(Color(0.5, 0.33, 0.18), v) * (0.92 if horiz else 1.05)
			if seam: c = c.darkened(0.45)
			a.set_pixel(x, y, c); h.set_pixel(x, y, Color(0.3 if seam else 0.6, 0, 0))
	return _pack(a, h, null, 3.0)

static func _brick() -> Dictionary:
	const S := 256
	var n := _noise(121, 0.1, 3).get_seamless_image(S, S)
	var rng := _rng(121)
	var a := _img(S, S); var h := Image.create(S, S, false, Image.FORMAT_L8)
	var tones := []
	for i in 64: tones.append(rng.randf_range(0.75, 1.1))
	for y in S:
		for x in S:
			var row := y / 16; var bx := (x + (16 if row % 2 else 0)) % 32
			var mortar := y % 16 < 2 or bx < 2
			var v := n.get_pixel(x, y).r
			var c: Color = Color(0.36, 0.33, 0.29) if mortar else Color(0.47, 0.22, 0.15) * float(tones[(row * 9 + (x + (16 if row % 2 else 0)) / 32) % 64]) * (0.85 + v * 0.3)
			a.set_pixel(x, y, c); h.set_pixel(x, y, Color(0.2 if mortar else 0.6 + v * 0.1, 0, 0))
	return _pack(a, h, null, 5.0)

# ---------------------------------------------------------------- paper, leaves
static func _paper(old: bool) -> Dictionary:
	const S := 64
	var n := _noise(131 + int(old), 0.08, 3).get_seamless_image(S, S)
	var edge := _noise(141, 0.2, 2).get_seamless_image(S, S)
	var a := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var v := n.get_pixel(x, y).r
			var c := Color(0.86, 0.82, 0.7) * (0.9 + v * 0.15)
			if old: c = c.lerp(Color(0.6, 0.55, 0.45), 0.5)
			c = c.lerp(Color(0.55, 0.4, 0.25), smoothstep(0.7, 0.9, v) * 0.4)       # foxing
			var alpha := 1.0
			if old:
				# torn away from one corner diagonally: ragged
				var t := float(x) / S + float(y) / S
				if t > 1.15 + (edge.get_pixel(x, y).r - 0.5) * 0.3: alpha = 0.0
			a.set_pixel(x, y, Color(c.r, c.g, c.b, alpha))
	return _pack(a, null)

static func _leaves() -> Dictionary:
	const S := 64
	var rng := _rng(151)
	var a := Image.create(S, S, false, Image.FORMAT_RGBA8)
	a.fill(Color(0, 0, 0, 0))
	for i in 9:
		var c := Vector2(rng.randf_range(8, 56), rng.randf_range(8, 56))
		var ang := rng.randf() * TAU; var L := rng.randf_range(6, 11)
		var col: Color = [Color(0.55, 0.3, 0.1), Color(0.42, 0.22, 0.08), Color(0.6, 0.45, 0.15), Color(0.3, 0.17, 0.08)][rng.randi() % 4]
		for y in S:
			for x in S:
				var q := (Vector2(x, y) - c).rotated(-ang)
				var w := L * 0.45 * sin(PI * clampf((q.x + L) / (2.0 * L), 0.0, 1.0))
				if absf(q.x) < L and absf(q.y) < w:
					var vein := absf(q.y) < 0.6
					a.set_pixel(x, y, Color(col.r, col.g, col.b, 1.0).darkened(0.3 if vein else 0.0))
	return _pack(a, null)

## the other shop windows: the same warm back room and grimy glass, different goods
static func _shop_kind(kind: String) -> Dictionary:
	const S := 128
	var rng := _rng(hash(kind))
	var a := _img(S, S)
	for y in S:
		for x in S:
			var vg := 1.0 - Vector2(float(x) / S - 0.5, float(y) / S - 0.45).length() * 1.1
			var back := Color(0.55, 0.36, 0.16)
			if kind == "tavern": back = Color(0.45, 0.24, 0.1)
			if kind == "photo": back = Color(0.5, 0.42, 0.3)
			a.set_pixel(x, y, back * clampf(vg, 0.25, 1.0))
	match kind:
		"bakery":
			for shelf in [40, 78]:
				a.fill_rect(Rect2i(6, shelf, S - 12, 3), Color(0.25, 0.15, 0.08))
				var x := 10
				while x < S - 18:
					var w := rng.randi_range(12, 18); var h := rng.randi_range(7, 10)
					var cx: int = x + w / 2; var cy: int = shelf - h / 2 - 1
					for yy in range(cy - h / 2, cy + h / 2 + 1):
						for xx in range(x, x + w):
							var q := Vector2(float(xx - cx) / (w * 0.5), float(yy - cy) / (h * 0.5))
							if q.length() <= 1.0:
								var crust := Color(0.62, 0.38, 0.14).lerp(Color(0.85, 0.62, 0.3), clampf(-q.y, 0.0, 1.0))
								a.set_pixel(xx, yy, crust)
					x += w + rng.randi_range(2, 4)
			# kalachi hanging on strings across the top
			for i in 6:
				var cx := 14 + i * 19; var cy := 16
				for yy in range(cy - 6, cy + 7):
					for xx in range(cx - 7, cx + 8):
						var d := Vector2(xx - cx, yy - cy).length()
						if d < 6.5 and d > 2.8: a.set_pixel(xx, yy, Color(0.8, 0.55, 0.25))
		"photo":
			# portraits in oval mounts, sepia; one large one in the middle
			for i in 7:
				var big := i == 3
				var w: int = 30 if big else 18; var h: int = 40 if big else 24
				var x: int = [8, 30, 52, 47, 96, 74, 100][i]; var y: int = [10, 14, 8, 50, 12, 58, 52][i]
				if big: x = 49; y = 46
				a.fill_rect(Rect2i(x - 2, y - 2, w + 4, h + 4), Color(0.2, 0.14, 0.08))
				a.fill_rect(Rect2i(x, y, w, h), Color(0.78, 0.7, 0.55))
				var cx: int = x + w / 2; var cy: int = y + h / 2
				for yy in range(y, y + h):
					for xx in range(x, x + w):
						var q := Vector2(float(xx - cx) / (w * 0.42), float(yy - cy) / (h * 0.44))
						if q.length() < 1.0:
							var sep := Color(0.45, 0.33, 0.2).lerp(Color(0.72, 0.6, 0.42), 1.0 - q.length())
							# a sitter: head and shoulders, darker
							var head := Vector2(float(xx - cx) / (w * 0.14), float(yy - (cy - h * 0.12)) / (h * 0.14)).length() < 1.0
							var body := yy > cy + h * 0.05 and absf(xx - cx) < w * 0.3 * (1.0 + float(yy - cy) / h)
							if head or body: sep = sep.darkened(0.55)
							a.set_pixel(xx, yy, sep)
		"clock":
			for i in 8:
				var cx: int = 16 + (i % 4) * 32; var cy: int = 26 + (i / 4) * 46; var r := rng.randi_range(9, 13)
				for yy in range(cy - r - 2, cy + r + 3):
					for xx in range(cx - r - 2, cx + r + 3):
						var d := Vector2(xx - cx, yy - cy).length()
						if d < r: a.set_pixel(xx, yy, Color(0.9, 0.86, 0.74))
						elif d < r + 2: a.set_pixel(xx, yy, Color(0.55, 0.4, 0.15))
				var t := rng.randf() * TAU
				for k in r - 2:
					a.set_pixel(cx + int(cos(t) * k), cy + int(sin(t) * k), Color(0.1, 0.08, 0.06))
					if k < r - 5: a.set_pixel(cx + int(cos(t * 3.0) * k), cy + int(sin(t * 3.0) * k), Color(0.1, 0.08, 0.06))
		"tavern":
			a.fill_rect(Rect2i(0, 96, S, 32), Color(0.22, 0.12, 0.06))
			for shelf in [30, 60]:
				a.fill_rect(Rect2i(6, shelf, S - 12, 3), Color(0.2, 0.11, 0.05))
				var x := 9
				while x < S - 10:
					var hgt := rng.randi_range(14, 22)
					var col: Color = [Color(0.15, 0.3, 0.12), Color(0.35, 0.15, 0.08), Color(0.6, 0.5, 0.2)][rng.randi() % 3]
					a.fill_rect(Rect2i(x, shelf - hgt + 6, 6, hgt - 6), col)
					a.fill_rect(Rect2i(x + 2, shelf - hgt, 2, 6), col)
					a.fill_rect(Rect2i(x + 1, shelf - hgt + 7, 1, hgt - 9), col.lightened(0.4))
					x += 9
			# the samovar on the counter
			for yy in range(70, 97):
				var w := 10 if yy > 78 else 6
				a.fill_rect(Rect2i(64 - w, yy, w * 2, 1), Color(0.7, 0.5, 0.25).lightened(0.1 if yy % 5 == 0 else 0.0))
		"hotel":
			a.fill_rect(Rect2i(0, 100, S, 28), Color(0.3, 0.15, 0.08))
			a.fill_rect(Rect2i(30, 20, 68, 50), Color(0.3, 0.18, 0.08))
			for i in 24:
				var x := 34 + (i % 8) * 8; var y := 24 + (i / 8) * 15
				a.fill_rect(Rect2i(x, y, 1, 6), Color(0.75, 0.6, 0.3))
				a.fill_rect(Rect2i(x - 1, y + 6, 3, 3), Color(0.8, 0.65, 0.3))
	var grime := _noise(83, 0.05, 3).get_seamless_image(S, S)
	for y in S:
		for x in S:
			a.set_pixel(x, y, a.get_pixel(x, y).lerp(Color(0.25, 0.22, 0.18), grime.get_pixel(x, y).r * 0.45))
	return _pack(a, null)

# ---------------------------------------------------------------- interiors
## flock wallpaper: a damask figure (a lily in a lozenge) repeating in a half-drop, the ground
## faded unevenly, darker under where pictures hung
static func _wallpaper(ground: Color, figure: Color, seed: int) -> Dictionary:
	const S := 128
	var n := _noise(seed, 0.03, 3).get_seamless_image(S, S)
	var a := _img(S, S); var h := Image.create(S, S, false, Image.FORMAT_L8)
	for y in S:
		for x in S:
			var col := x / 32; var row := y / 48
			var lx := fmod(float(x), 32.0) - 16.0; var ly := fmod(float(y + (24 if col % 2 == 1 else 0)), 48.0) - 24.0
			var lily := (absf(lx) * 1.6 + absf(ly)) < 16.0 and (absf(lx) * 1.6 + absf(ly)) > 12.0
			lily = lily or (Vector2(lx, ly + 6).length() < 4.0) or (absf(lx) < 1.2 and ly > -6 and ly < 10) or (Vector2(absf(lx) - 4.0, ly - 2).length() < 2.5)
			var v := n.get_pixel(x, y).r
			var c := ground * (0.82 + v * 0.3)
			if lily: c = c.lerp(figure, 0.55)
			a.set_pixel(x, y, c); h.set_pixel(x, y, Color(0.62 if lily else 0.5, 0, 0))
	return _pack(a, h, null, 2.0)

static func _rug() -> Dictionary:
	const S := 128
	var a := _img(S, S)
	var n := _noise(181, 0.1, 2).get_seamless_image(S, S)
	for y in S:
		for x in S:
			var u := float(x) / S; var v := float(y) / S
			var e := minf(minf(u, 1.0 - u), minf(v, 1.0 - v))
			var c := Color(0.5, 0.1, 0.08)
			if e < 0.12: c = Color(0.12, 0.15, 0.32)
			if e < 0.1 and e > 0.08: c = Color(0.82, 0.72, 0.5)
			if e < 0.03: c = Color(0.82, 0.72, 0.5)
			var m := absf(u - 0.5) * 1.3 + absf(v - 0.5)
			if m < 0.25 and m > 0.2: c = Color(0.85, 0.7, 0.4)
			if m < 0.14: c = Color(0.12, 0.15, 0.32)
			if m < 0.06: c = Color(0.85, 0.7, 0.4)
			c = c * (0.85 + n.get_pixel(x, y).r * 0.25)
			a.set_pixel(x, y, c)
	return _pack(a, null)

## the photographer's painted backdrop: a garden in soft distemper, a balustrade, an urn
static func _backdrop() -> Dictionary:
	const W := 256; const H := 160
	var a := _img(W, H)
	var n := _noise(191, 0.025, 4).get_seamless_image(W, H)
	for y in H:
		for x in W:
			var v := n.get_pixel(x, y).r
			var sky := Color(0.62, 0.62, 0.55).lerp(Color(0.5, 0.56, 0.48), float(y) / H)
			var edge := 0.28 + 0.1 * sin(float(x) * 0.06) * v + 0.05 * sin(float(x) * 0.17)
			var c := sky.lerp(Color(0.36, 0.4, 0.3) * (0.8 + v * 0.35), smoothstep(edge - 0.04, edge + 0.04, float(y) / H))
			if y > H * 0.62:
				c = Color(0.68, 0.64, 0.54) * (0.85 + v * 0.2)           # the balustrade's stone
				if y < H * 0.68 or (x % 10 < 5 and y < H * 0.92): c = c.darkened(0.12)
			a.set_pixel(x, y, c)
	return _pack(a, null)

static func _lace() -> Dictionary:
	const S := 64
	var a := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var u := fmod(float(x), 16.0) - 8.0; var v := fmod(float(y), 16.0) - 8.0
			var ring := absf(Vector2(u, v).length() - 5.0) < 1.0
			var grid := x % 4 == 0 or y % 4 == 0
			var alpha := 0.85 if ring else (0.45 if grid else 0.0)
			a.set_pixel(x, y, Color(0.92, 0.9, 0.85, alpha))
	return _pack(a, null)

static func _planks() -> Dictionary:
	const S := 256
	var grain := _noise(201, 0.012, 3)
	var a := _img(S, S); var h := Image.create(S, S, false, Image.FORMAT_L8)
	var rng := _rng(201)
	var tone := []
	for i in 8: tone.append(rng.randf_range(0.8, 1.1))
	for y in S:
		for x in S:
			var row := x / 48; var px := x % 48
			var g := grain.get_noise_2d(x * 5.0, y * 0.5 + row * 50.0) * 0.5 + 0.5
			var c := Color(0.36, 0.26, 0.17).lerp(Color(0.5, 0.38, 0.26), g) * float(tone[row % 8])
			if px < 2: c = Color(0.1, 0.07, 0.05)
			a.set_pixel(x, y, c); h.set_pixel(x, y, Color(0.2 if px < 2 else 0.55 + g * 0.1, 0, 0))
	return _pack(a, h, null, 4.0)

static func _wicker() -> Dictionary:
	const S := 64
	var a := _img(S, S); var h := Image.create(S, S, false, Image.FORMAT_L8)
	for y in S:
		for x in S:
			var over := ((x / 4) + (y / 4)) % 2 == 0
			var t := sin(PI * fmod(float(x if over else y), 4.0) / 4.0)
			var c := Color(0.62, 0.48, 0.28) * (0.65 + t * 0.45)
			a.set_pixel(x, y, c); h.set_pixel(x, y, Color(t * (0.8 if over else 0.6), 0, 0))
	return _pack(a, h, null, 4.0)
