class_name Look
extends RefCounted
## Procedural textures (small, nearest-filtered, mipmapped) and the materials that use them.

static var _cache := {}
static var _shader: Shader
static var _shader2: Shader

static func mat(tex: Texture2D, tint := Color.WHITE, snap := 160.0, double := false, glow := Color.BLACK) -> ShaderMaterial:
	if _shader == null:
		_shader = load("res://shaders/ps1.gdshader")
		_shader2 = load("res://shaders/ps1_double.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _shader2 if double else _shader
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("snap", snap)
	m.set_shader_parameter("glow", Vector3(glow.r, glow.g, glow.b))
	return m

static func _noise(seed: int, freq: float, octaves := 3) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = freq
	n.fractal_octaves = octaves
	return n

static func _done(key: String, img: Image) -> ImageTexture:
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t

static func get_tex(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	match key:
		"wallpaper": return _wallpaper()
		"plaster": return _plain(key, Color("b8b2a2"), Color("8d8676"), 7, 0.08)
		"paint_green": return _plain(key, Color("4b6a55"), Color("34483a"), 11, 0.06)
		"concrete": return _plain(key, Color("7d7b76"), Color("55534e"), 3, 0.12)
		"parquet": return _parquet()
		"wood": return _wood(key, Color("4a2e1d"), Color("2e1b10"))
		"wood_light": return _wood(key, Color("8a6844"), Color("5c4128"))
		"leather": return _leather()
		"cloth": return _plain(key, Color("ffffff"), Color("b0b0b0"), 21, 0.25)
		"skin": return _skin()
		"skin_kurt": return _plain(key, Color("c99a7c"), Color("9c7058"), 61, 0.3)
		"coral": return _coral()
		"mould": return _plain(key, Color("26301f"), Color("0e120b"), 31, 0.2)
		"sock": return _sock()
		"sock_head": return _sock_head()
		"felt": return _plain(key, Color("b8362a"), Color("7a1d17"), 41, 0.25)
		"paper": return _plain(key, Color("d8d0bc"), Color("a59c86"), 17, 0.2)
		"white": return _plain(key, Color.WHITE, Color.WHITE, 1, 1.0)
		"rubble": return _plain(key, Color("9a948a"), Color("5f5a52"), 51, 0.3)
	return _plain(key, Color.MAGENTA, Color.MAGENTA, 1, 1.0)

static func _plain(key: String, a: Color, b: Color, seed: int, freq: float) -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var n := _noise(seed, freq)
	for y in 64:
		for x in 64:
			var v := n.get_noise_2d(x, y) * 0.5 + 0.5
			img.set_pixel(x, y, a.lerp(b, clampf(v * 1.2 - 0.1, 0.0, 1.0)))
	return _done(key, img)

static func _wallpaper() -> ImageTexture:
	# Faded mustard damask: a stripe, a diamond motif, water stains running down from the top.
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var n := _noise(5, 0.05)
	var stain := _noise(9, 0.03, 2)
	var base := Color("a8946a")
	var ink := Color("7b6a45")
	for y in 64:
		for x in 64:
			var c := base
			var dx := absf(fposmod(x, 16.0) - 8.0)
			var dy := absf(fposmod(y, 16.0) - 8.0)
			if dx + dy < 4.5 and dx + dy > 2.5:
				c = ink
			if x % 16 == 0:
				c = c.lerp(ink, 0.6)
			var v := n.get_noise_2d(x, y) * 0.5 + 0.5
			c = c.darkened(v * 0.18)
			var s := stain.get_noise_2d(x, y * 0.4)
			if s > 0.25:
				c = c.lerp(Color("5b4a2e"), clampf((s - 0.25) * 2.5, 0.0, 0.7))
			img.set_pixel(x, y, c)
	return _done("wallpaper", img)

static func _parquet() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var n := _noise(3, 0.2)
	for y in 64:
		for x in 64:
			var block := (int(x / 16) + int(y / 16)) % 2
			var along := y if block == 0 else x
			var across := x if block == 0 else y
			var plank := int(across / 4)
			var c := Color("6b4a2c").lerp(Color("4a301b"), float((plank * 7) % 5) / 5.0)
			c = c.darkened((n.get_noise_2d(along * 0.3 + plank * 13, across) * 0.5 + 0.5) * 0.25)
			if across % 4 == 0 or (along % 16 == 0):
				c = c.darkened(0.45)
			img.set_pixel(x, y, c.lerp(Color("5d5a54"), 0.18))
	return _done("parquet", img)

static func _wood(key: String, a: Color, b: Color) -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var n := _noise(13, 0.08)
	for y in 64:
		for x in 64:
			var g := sin((x + n.get_noise_2d(x, y) * 14.0) * 0.6) * 0.5 + 0.5
			img.set_pixel(x, y, a.lerp(b, g * 0.7))
	return _done(key, img)

static func _leather() -> ImageTexture:
	# The padded front door: oxblood vinyl quilted into diamonds with brass studs.
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var n := _noise(19, 0.15)
	for y in 64:
		for x in 64:
			var dx := absf(fposmod(x + y, 32.0) - 16.0)
			var dy := absf(fposmod(x - y, 32.0) - 16.0)
			var puff := minf(dx, dy) / 16.0
			var c := Color("5a1414").lerp(Color("2c0808"), 1.0 - puff)
			c = c.darkened((n.get_noise_2d(x, y) * 0.5 + 0.5) * 0.2)
			if (x % 16 == 0 and y % 16 == 0):
				c = Color("a08a4a")
			img.set_pixel(x, y, c)
	return _done("leather", img)

static func _skin() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var n := _noise(23, 0.09)
	var m := _noise(29, 0.2)
	for y in 64:
		for x in 64:
			var c := Color("8f9282").lerp(Color("5d5f4c"), n.get_noise_2d(x, y) * 0.5 + 0.5)
			if m.get_noise_2d(x, y) > 0.35:
				c = c.lerp(Color("2b2f1f"), 0.6)    # mould under the skin
			if m.get_noise_2d(x + 40, y) > 0.5:
				c = c.lerp(Color("5e2a26"), 0.5)    # bruising
			img.set_pixel(x, y, c)
	return _done("skin", img)

static func _coral() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var n := _noise(37, 0.25)
	for y in 64:
		for x in 64:
			var v := n.get_noise_2d(x, y)
			var c := Color("e3a08c").lerp(Color("f1ddc8"), clampf(v + 0.5, 0.0, 1.0))
			if v < -0.35:
				c = Color("7a3b33")       # pores
			img.set_pixel(x, y, c)
	return _done("coral", img)

static func _stains(c: Color, x: int, y: int, n: FastNoiseLite, m: FastNoiseLite, low: float) -> Color:
	var g := n.get_noise_2d(x, y) * 0.5 + 0.5
	c = c.darkened(g * 0.22)
	if m.get_noise_2d(x, y) > 0.42:
		c = c.lerp(Color("5a3326"), 0.45)             # old blood
	if m.get_noise_2d(x + 70, y) > 0.45:
		c = c.lerp(Color("46523a"), 0.45)             # mould
	if low > 0.6 and m.get_noise_2d(x, y + 90) > 0.2:
		c = c.lerp(Color("a28f4a"), 0.35)             # the yellow you don't ask about
	return c

static func _sock() -> ImageTexture:
	# The tube (UV v runs along it, cuff at v=1): grubby off-white, red and blue cuff stripes.
	var img := Image.create(32, 64, false, Image.FORMAT_RGB8)
	var n := _noise(43, 0.2)
	var m := _noise(47, 0.12)
	for y in 64:
		for x in 32:
			var c := Color("c8bfa6")
			if y >= 46 and y < 50:
				c = Color("9a2620")
			elif y >= 53 and y < 57:
				c = Color("2a3a78")
			if x % 4 == 0:
				c = c.darkened(0.08)      # knit ribs
			img.set_pixel(x, y, _stains(c, x, y, n, m, float(x % 16) / 16.0))
	return _done("sock", img)

static func _sock_head() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	var n := _noise(53, 0.25)
	var m := _noise(59, 0.15)
	for y in 32:
		for x in 32:
			var c := Color("c8bfa6")
			if (x + y) % 3 == 0:
				c = c.darkened(0.06)
			img.set_pixel(x, y, _stains(c, x, y, n, m, float(y) / 32.0))
	return _done("sock_head", img)
