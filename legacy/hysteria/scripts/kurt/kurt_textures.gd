class_name KurtTextures
## Kurt's skin, nails and clothes, painted in code at PS1 resolution. Regional colour (palm vs
## back of the hand, creases, veins, spots) is in the mesh's vertex colours; these carry the
## fine texture.

static var _cache := {}

static func get_tex(name: String) -> ImageTexture:
	if not _cache.has(name):
		var makers := {"skin": skin, "nail": nail, "coat": coat, "cuff": cuff}
		_cache[name] = ImageTexture.create_from_image((makers[name] as Callable).call())
	return _cache[name]

static func _n(seed: int, freq: float, oct := 3) -> FastNoiseLite:
	var n := FastNoiseLite.new(); n.seed = seed; n.frequency = freq; n.fractal_octaves = oct
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	return n

static func _img(w: int, h: int, f: Callable) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			img.set_pixel(x, y, f.call(x, y))
	return img

## Older fair skin, weathered: mottled and a little ruddy, fine creasing, pigment spots.
static func skin() -> Image:
	var mott := _n(101, 0.06); var fine := _n(102, 0.5, 1); var blot := _n(103, 0.025); var spot := _n(104, 0.18, 1); var crease := _n(105, 0.09, 2)
	return _img(64, 64, func(x, y):
		var c := Color("c7977d").lerp(Color("a9775f"), mott.get_noise_2d(x, y) * 0.5 + 0.5)
		c = c.lerp(Color("b97a6a"), maxf(0.0, blot.get_noise_2d(x, y)) * 0.55)
		c = c.darkened(fine.get_noise_2d(x, y) * 0.07)
		if absf(crease.get_noise_2d(x * 0.6, y * 2.2)) < 0.035: c = c.darkened(0.1)     # fine creases, mostly across
		if spot.get_noise_2d(x, y) > 0.55: c = c.lerp(Color("8a5e44"), 0.45)            # pigment spots
		return c)

## Nails: ivory going yellow, with lengthwise ridges.
static func nail() -> Image:
	return _img(16, 16, func(x, y):
		var c := Color("e2d2b8").lerp(Color("c9b48e"), float(y) / 16.0 * 0.6)
		if x % 4 == 0: c = c.darkened(0.08)
		if y > 12: c = Color("efe6d4")      # the free edge
		return c)

## A dark wool overcoat: brown-grey twill, worn.
static func coat() -> Image:
	var n := _n(111, 0.2, 2); var wear := _n(112, 0.04)
	return _img(32, 32, func(x, y):
		var c := Color("3a3430").darkened(0.1 * float((x + y) % 3 == 0))
		c = c.lightened(n.get_noise_2d(x, y) * 0.08)
		c = c.lerp(Color("4c4540"), maxf(0.0, wear.get_noise_2d(x, y)) * 0.6)
		return c)

## A shirt cuff, off-white and not quite clean.
static func cuff() -> Image:
	var n := _n(121, 0.15)
	return _img(16, 16, func(x, y): return Color("d8d2c2").darkened(maxf(0.0, n.get_noise_2d(x, y)) * 0.2 + 0.04 * float(y % 4 == 0)))
