class_name InfectedTextures
## Textures for the infected, painted in code at PS1 resolution (sampled unfiltered), stable from
## run to run. The skins and growths share Marta's palette (RotTextures) so it reads as one
## infection taking people differently:
##   skins    rot (Marta's own flesh), pallid (waxy, mould-white, blue-veined), char (dark, dry,
##            cracked to red), bloat (swollen yellow-purple, stretched shiny, split)
##   growths  coral (Marta's), fungus (pale shelves, gills), bone (spurs, yellowed), tumour
##            (glossy clustered lumps, red-black)
##   clothes  coat, nightclothes, overalls, dress: three cuts of each (palette 0..2), worn,
##            stained, the same grime as the flat
##   raw      a wound's cut face (stumps, severed limbs)

static var _cache := {}

static func get_tex(name: String) -> ImageTexture:
	if not _cache.has(name):
		var img: Image
		match name:
			"rot": img = RotTextures.flesh()
			"coral": img = RotTextures.coral()
			"pallid": img = pallid()
			"char": img = charred()
			"bloat": img = bloat()
			"fungus": img = fungus()
			"bone": img = bone()
			"tumour": img = tumour()
			"raw": img = raw()
			"eye": img = RotTextures.eye()
			"teeth": img = RotTextures.teeth()
			_:
				if name.begins_with("cloth_"):
					var p := name.split("_")
					img = cloth(p[1], int(p[2]))
				else:
					img = RotTextures.black()
		_cache[name] = ImageTexture.create_from_image(img)
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

## Waxy, mould-white, blue veins under it, grey where it's gone, a pale fur in the creases.
static func pallid() -> Image:
	var base := _n(21, 0.04); var vein := _n(22, 0.06, 2); var mould := _n(23, 0.05); var speck := _n(24, 0.7, 1)
	return _img(128, 128, func(x, y):
		var b := base.get_noise_2d(x, y) * 0.5 + 0.5
		var c := Color("b9b6a4").lerp(Color("d8d4c2"), smoothstep(0.3, 0.8, b))
		c = c.lerp(Color("8e938c"), smoothstep(0.55, 0.9, 1.0 - b) * 0.5)
		var v := absf(vein.get_noise_2d(x * 1.4, y))
		if v < 0.045: c = c.lerp(Color("4a5a78"), 0.7 * (1.0 - v / 0.045))
		var m := mould.get_noise_2d(x, y)
		if m > 0.25: c = c.lerp(Color("e8e6dc"), smoothstep(0.25, 0.5, m) * 0.7)
		if speck.get_noise_2d(x, y) > 0.55: c = c.darkened(0.25)
		return c)

## Burnt-looking: near-black, dry, cracked through to raw red, ash-grey flakes.
static func charred() -> Image:
	var base := _n(31, 0.05); var crack := _n(32, 0.08, 2); var ash := _n(33, 0.09)
	return _img(128, 128, func(x, y):
		var c := Color("2a2420").lerp(Color("443a32"), base.get_noise_2d(x, y) * 0.5 + 0.5)
		var k := absf(crack.get_noise_2d(x, y))
		if k < 0.04: c = Color("6e1a10").lerp(Color("b0381c"), 1.0 - k / 0.04)
		var a := ash.get_noise_2d(x, y)
		if a > 0.3: c = c.lerp(Color("7c7670"), smoothstep(0.3, 0.6, a) * 0.6)
		return c)

## Swollen: yellow-green stretched shiny, purple-black pooling, stretch marks, splits.
static func bloat() -> Image:
	var base := _n(41, 0.03); var pool := _n(42, 0.025); var mark := _n(43, 0.12, 1); var split := _n(44, 0.05)
	return _img(128, 128, func(x, y):
		var c := Color("8a8a52").lerp(Color("a8a066"), base.get_noise_2d(x, y) * 0.5 + 0.5)
		c = c.lerp(Color("4a2c48"), smoothstep(0.05, 0.5, pool.get_noise_2d(x, y)) * 0.85)
		if absf(mark.get_noise_2d(x * 0.3, y)) < 0.03: c = c.lightened(0.18)
		var s := split.get_noise_2d(x, y)
		if s > 0.4: c = Color("5a1612").lerp(Color("1c0604"), smoothstep(0.4, 0.55, s))
		return c)

## Bracket fungus: pale cream to tan in growth rings, gills underneath (dark lines).
static func fungus() -> Image:
	var ring := _n(51, 0.03); var gill := _n(52, 0.4, 1)
	return _img(64, 64, func(x, y):
		var r := sin((y + ring.get_noise_2d(x, y) * 14.0) * 0.6) * 0.5 + 0.5
		var c := Color("d6c9a2").lerp(Color("8c6e44"), r * 0.55)
		if x % 4 == 0 and gill.get_noise_2d(x, y) > -0.2: c = c.darkened(0.3)
		return c)

## Bone spurs: yellowed, porous, brown at the root.
static func bone() -> Image:
	var base := _n(61, 0.08); var pore := _n(62, 0.6, 1)
	return _img(64, 64, func(x, y):
		var c := Color("d8cfae").lerp(Color("a89a70"), base.get_noise_2d(x, y) * 0.5 + 0.5)
		c = c.lerp(Color("5e4430"), smoothstep(0.75, 1.0, float(y) / 63.0) * 0.7)
		if pore.get_noise_2d(x, y) > 0.5: c = c.darkened(0.35)
		return c)

## Tumour clusters: glossy dark red to purple-black, veined, a wet sheen (spec does the rest).
static func tumour() -> Image:
	var base := _n(71, 0.06); var vein := _n(72, 0.09, 2)
	return _img(64, 64, func(x, y):
		var c := Color("5a1822").lerp(Color("2a0c1c"), base.get_noise_2d(x, y) * 0.5 + 0.5)
		if absf(vein.get_noise_2d(x, y)) < 0.05: c = c.lerp(Color("9a3a3a"), 0.6)
		return c)

## A cut: red meat, a ring of fat, a pale centre (bone) and dark clot.
static func raw() -> Image:
	var n := _n(81, 0.15)
	return _img(32, 32, func(x, y):
		var d := Vector2(x - 15.5, y - 15.5).length() / 16.0 + n.get_noise_2d(x, y) * 0.15
		var c := Color("6a1410")
		if d < 0.22: c = Color("d8cfae")
		elif d < 0.3: c = Color("2a0604")
		elif d > 0.82: c = Color("c8b070")
		return c)

## Clothes: what they wore when it took them. Worn through at the edges, grime and stains.
const CLOTH_PALETTES := {
	"coat": [Color("2f2b26"), Color("3c4033"), Color("4a3428")],
	"nightclothes": [Color("8a8f9a"), Color("9a8a78"), Color("7a8c84")],
	"overalls": [Color("2c3a52"), Color("4a4a3a"), Color("5a3a2a")],
	"dress": [Color("5a2a34"), Color("3a4a5a"), Color("6a6040")],
}

static func cloth(kind: String, palette: int) -> Image:
	var cols: Array = CLOTH_PALETTES.get(kind, CLOTH_PALETTES.coat)
	var base: Color = cols[palette % cols.size()]
	var weave := _n(91 + palette, 0.9, 1); var grime := _n(95 + palette, 0.04); var stain := _n(99 + palette, 0.03)
	return _img(64, 64, func(x, y):
		var c := base
		if (x + y) % 2 == 0: c = c.darkened(0.06)
		if kind == "nightclothes" and (x / 6) % 2 == 0: c = c.lightened(0.1)           # a stripe
		if kind == "dress" and (x % 8 == 0 or y % 8 == 0): c = c.lightened(0.08)       # a check
		if kind == "overalls" and x % 16 == 15: c = c.lightened(0.2)                    # a seam
		c = c.darkened(weave.get_noise_2d(x, y) * 0.08)
		c = c.lerp(Color("2a2418"), smoothstep(0.2, 0.7, grime.get_noise_2d(x, y)) * 0.5)
		var s := stain.get_noise_2d(x, y)
		if s > 0.35: c = c.lerp(Color("3a1810"), smoothstep(0.35, 0.6, s) * 0.6)
		return c)
