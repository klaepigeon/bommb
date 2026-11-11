class_name RotTextures
## Painted-in-code textures for Marta, at PS1 resolution (sampled unfiltered). Each is a function
## of a few noise fields so they're stable between runs.

static var _cache := {}

static func get_tex(name: String) -> ImageTexture:
	if not _cache.has(name):
		var makers := {"flesh": flesh, "coral": coral, "cloth": cloth, "teeth": teeth, "gums": gums, "slime": slime,
			"puddle": puddle, "eye": eye, "hair": hair, "bone": bone, "wood": wood, "black": black}
		_cache[name] = ImageTexture.create_from_image((makers[name] as Callable).call())
	return _cache[name]

static func _n(seed: int, freq: float, octaves := 3) -> FastNoiseLite:
	var n := FastNoiseLite.new(); n.seed = seed; n.frequency = freq
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH; n.fractal_octaves = octaves
	return n

static func _img(w: int, h: int, f: Callable) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			img.set_pixel(x, y, f.call(x, y))
	return img

## Skin three weeks gone: grey-green and waxy yellow, bruised purple-black where the blood
## settled, marbled with dark veins, raw red where it's split, mould blooming in pale fur.
static func flesh() -> Image:
	var base := _n(11, 0.035); var vein := _n(12, 0.05, 2); var raw := _n(13, 0.05); var mould := _n(14, 0.045); var speck := _n(15, 0.6, 1); var blot := _n(16, 0.02)
	return _img(128, 128, func(x, y):
		var b := base.get_noise_2d(x, y) * 0.5 + 0.5
		var c := Color("4f5241").lerp(Color("7c7656"), smoothstep(0.3, 0.75, b))          # grey-green to waxy
		var l := blot.get_noise_2d(x, y)
		c = c.lerp(Color("2e2230"), smoothstep(0.0, 0.45, l) * 0.9)                         # lividity, purple-black
		c = c.lerp(Color("4a3a24"), smoothstep(-0.1, -0.5, l) * 0.6)                        # brown where it's drying
		var v := absf(vein.get_noise_2d(x * 1.3, y))
		if v < 0.05: c = c.lerp(Color("1e1424"), 0.8 * (1.0 - v / 0.05))                 # marbling
		var r := raw.get_noise_2d(x, y)
		if r > 0.22: c = c.lerp(Color("5a1612"), smoothstep(0.22, 0.4, r))               # split, raw
		if r > 0.42: c = Color("1c0604")                                                  # the black under it
		var m := mould.get_noise_2d(x, y)
		if m > 0.3 and speck.get_noise_2d(x, y) > 0.0: c = c.lerp(Color("a8aa98"), 0.6 * smoothstep(0.3, 0.55, m))
		return c)

## Coral: bone-white going to a sick salmon pink at the growing tips (v is along the branch), with
## dark pores.
static func coral() -> Image:
	var pores := _n(21, 0.45, 1); var tone := _n(22, 0.07)
	return _img(64, 64, func(x, y):
		var t := clampf(1.0 - float(y) / 64.0 * 1.3 + tone.get_noise_2d(x, y) * 0.35, 0.0, 1.0)
		var c := Color("9a4a3c").lerp(Color("c88a6c"), t).lerp(Color("d8c8b0"), smoothstep(0.75, 1.0, t))   # flesh-red root, salmon, pale tip
		if pores.get_noise_2d(x, y) > 0.35: c = c.darkened(0.6)
		return c)

## Her dress: dark faded floral, rotted through and soaked with what came out of her.
static func cloth() -> Image:
	var stain := _n(31, 0.05); var weave := _n(32, 0.9, 1)
	return _img(64, 64, func(x, y):
		var c := Color("2a2634")
		if (x / 8 + y / 8) % 3 == 0 and (x % 8 > 2 and x % 8 < 6) and (y % 8 > 2 and y % 8 < 6): c = Color("4a3e44")   # little flowers
		c = c.darkened(weave.get_noise_2d(x, y) * 0.15)
		var s := stain.get_noise_2d(x, y)
		if s > 0.05: c = c.lerp(Color("3a2a12"), smoothstep(0.05, 0.4, s) * 0.9)
		return c)

## Teeth: nicotine yellow to brown at the roots, a dark line between each.
static func teeth() -> Image:
	return _img(16, 16, func(x, y):
		var c := Color("b0a070").lerp(Color("4a3420"), float(y) / 16.0 * 0.9)
		if x == 0 or x == 15: c = Color("2a1a10")
		return c)

static func gums() -> Image:
	var n := _n(41, 0.3)
	return _img(32, 32, func(x, y): return Color("4a0c10").lerp(Color("1a0204"), n.get_noise_2d(x, y) * 0.5 + 0.5))

## Wet slime and melted fat: greasy yellow-brown with darker strands.
static func slime() -> Image:
	var n := _n(51, 0.12)
	return _img(32, 32, func(x, y):
		var v := n.get_noise_2d(x * 0.4, y) * 0.5 + 0.5
		return Color("4a4020").lerp(Color("1e1608"), v))

## The puddle under the chair: black-brown, red at the edges, scummed.
static func puddle() -> Image:
	var n := _n(61, 0.06); var scum := _n(62, 0.25, 1)
	return _img(64, 64, func(x, y):
		var d := Vector2(x - 32, y - 32).length() / 32.0
		var c := Color("1a0e08").lerp(Color("4a1410"), smoothstep(0.4, 1.0, d + n.get_noise_2d(x, y) * 0.3))
		if scum.get_noise_2d(x, y) > 0.4: c = c.lerp(Color("6a6a40"), 0.5)
		return c)

## Milky, clouded eyes with a ghost of an iris.
static func eye() -> Image:
	return _img(16, 16, func(x, y):
		var d := Vector2(x - 8, y - 8).length()
		var c := Color("c9cbb8")
		if d < 3.2: c = Color("8a8c80")
		if d < 1.4: c = Color("4a4a44")
		if (x * 7 + y * 3) % 11 == 0: c = c.lerp(Color("8a2a20"), 0.6)     # burst vessels
		return c)

static func hair() -> Image:
	return _img(8, 32, func(x, y): return Color("1c1612").lerp(Color("3a3226"), float((x * 5 + y) % 4) / 6.0))

static func bone() -> Image:
	var n := _n(71, 0.2)
	return _img(32, 32, func(x, y): return Color("cfc4a8").lerp(Color("7a6a4a"), n.get_noise_2d(x, y) * 0.5 + 0.5))

static func wood() -> Image:
	var n := _n(81, 0.04)
	return _img(32, 64, func(x, y):
		var g := sin(y * 0.6 + n.get_noise_2d(x, y) * 6.0) * 0.5 + 0.5
		return Color("4a2e1c").lerp(Color("2a180e"), g * 0.6))

static func black() -> Image:
	return _img(4, 4, func(_x, _y): return Color("060303"))
