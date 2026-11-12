class_name Tex
## Procedural low-resolution textures and the materials made from them. Every surface in the game
## comes from here, painted pixel by pixel at PS1 sizes (32-64 px), sampled without filtering.
## Cached: asking twice for the same material returns the same one.

const PS1 := preload("res://shaders/ps1.gdshader")
const PS1_DOUBLE := preload("res://shaders/ps1_double.gdshader")
static var _tex := {}
static var _mat := {}

## A material for a named surface. `density`: texture repeats per metre.
static func mat(name: String, density := 1.0, opts := {}) -> ShaderMaterial:
	var key := "%s@%.2f@%s" % [name, density, str(opts)]
	if _mat.has(key): return _mat[key]
	var m := ShaderMaterial.new(); m.shader = PS1_DOUBLE if opts.get("double", false) else PS1
	m.set_shader_parameter("albedo_tex", tex(name))
	m.set_shader_parameter("uv_scale", Vector2(density, density))
	if opts.has("tint"): m.set_shader_parameter("albedo_color", opts.tint)
	if opts.has("pulse"): m.set_shader_parameter("pulse", opts.pulse)
	if opts.has("emission"): m.set_shader_parameter("emission", opts.emission)
	if opts.has("rough"): m.set_shader_parameter("roughness", opts.rough)
	m.set_meta("surface", surface_of(name))
	_mat[key] = m
	return m

## What a material sounds like underfoot.
static func surface_of(name: String) -> String:
	if name in ["parquet", "wood", "wood_light"]: return "wood"
	if name == "lino": return "lino"
	if name in ["tiles", "enamel"]: return "tile"
	if name in ["concrete", "stairwell", "plaster"]: return "concrete"
	if name in ["rug", "fabric", "fabric_green", "cloth_red", "cardboard"]: return "soft"
	if name.begins_with("flesh") or name == "coral": return "flesh"
	return "wood"

static func tex(name: String) -> Texture2D:
	if _tex.has(name): return _tex[name]
	var img: Image
	match name:
		"wallpaper": img = _wallpaper(Color("8f9a7a"), Color("6d7a5c"), Color("b3a77d"), 11)
		"wallpaper_bed": img = _wallpaper(Color("a08a78"), Color("7d6a5c"), Color("c4a98a"), 23)
		"wallpaper_flesh": img = _flesh_wallpaper()
		"plaster": img = _plaster(Color("c9c2b0"), 3)
		"parquet": img = _parquet()
		"lino": img = _lino()
		"tiles": img = _tiles(Color("c8cfc8"), Color("6f746c"))
		"wood": img = _wood(Color("5a3a24"), 5)
		"wood_light": img = _wood(Color("8a6440"), 9)
		"door_padded": img = _padded()
		"stairwell": img = _stairwell()
		"concrete": img = _plaster(Color("7f7d76"), 41)
		"fabric": img = _fabric(Color("6b4a3a"), Color("8c6a4a"))
		"fabric_green": img = _fabric(Color("4f5a3e"), Color("6c7552"))
		"flesh": img = _flesh(Color("8c3b3b"), Color("c4706a"), 7)
		"flesh_dark": img = _flesh(Color("6a2a2e"), Color("a04a48"), 13)
		"coral": img = _coral()
		"mould": img = _mould()
		"skin": img = _skin()
		"paper_boxes": img = _box_drawing()
		"metal": img = _plaster(Color("5c5f60"), 17)
		"gunmetal": img = _plaster(Color("2a2b2d"), 19)
		"enamel": img = _plaster(Color("d8d6cc"), 29)
		"cloth_red": img = _fabric(Color("6e2a26"), Color("8a3a32"))
		"black": img = _flat(Color("0b0908"))
		"cardboard": img = _cardboard()
		"newspaper": img = _newspaper()
		"sticky": img = _flat(Color("f2dc5a"))
		"glass": img = _flat(Color("8aa0a8"))
		"rug": img = _rug()
		_: img = _flat(Color.MAGENTA)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[name] = t
	return t

# ------------------------------------------------------------------ painters
static func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = seed; return r

static func _noise(seed: int, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new(); n.seed = seed; n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM; n.fractal_octaves = 3
	return n

static func _flat(c: Color) -> Image:
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8); img.fill(c); return img

## Soviet wallpaper: vertical bands with a small repeating diamond, faded, a tide line of damp at
## the top and grime at the bottom (the texture is one metre: bottom of the image is the floor).
static func _wallpaper(base: Color, line: Color, motif: Color, seed: int) -> Image:
	var S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var r := _rng(seed); var n := _noise(seed, 0.08)
	for y in S:
		for x in S:
			var c := base
			var bx := x % 16
			if bx == 0 or bx == 15: c = c.lerp(line, 0.6)
			var dx := absi((x % 16) - 8); var dy := absi((y % 16) - 8)
			if dx + dy == 4: c = c.lerp(motif, 0.7)
			if dx + dy <= 1: c = c.lerp(line, 0.5)
			c = c.darkened(0.08 * n.get_noise_2d(x, y) + r.randf() * 0.06)
			img.set_pixel(x, y, c)
	return img

static func _flesh_wallpaper() -> Image:
	var img := _wallpaper(Color("9a7a6a"), Color("7a4a42"), Color("c08a7a"), 11)
	var n := _noise(5, 0.09); var v := _noise(77, 0.05)
	for y in 64:
		for x in 64:
			var c := img.get_pixel(x, y)
			var k := clampf(0.5 + n.get_noise_2d(x, y) * 1.4, 0.0, 1.0)
			c = c.lerp(Color("8c3b3b"), k * 0.75)
			var vein := absf(v.get_noise_2d(x * 1.3, y))
			if vein < 0.035: c = c.lerp(Color("4a1a2a"), 0.8)
			img.set_pixel(x, y, c)
	return img

static func _plaster(base: Color, seed: int) -> Image:
	var S := 32
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var r := _rng(seed); var n := _noise(seed, 0.12)
	for y in S:
		for x in S:
			img.set_pixel(x, y, base.darkened(0.1 * n.get_noise_2d(x, y) + r.randf() * 0.07))
	return img

static func _parquet() -> Image:
	var S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var r := _rng(3)
	for y in S:
		for x in S:
			var bx := x / 8; var by := (y + (bx % 2) * 16) / 32
			var plank_seed := bx * 31 + by * 7
			var base := Color("6e4a2c").darkened(fposmod(plank_seed * 0.137, 0.25))
			var grain := sin(x * 1.7 + plank_seed) * 0.04
			var c := base.darkened(grain + r.randf() * 0.05)
			if x % 8 == 0 or (y + (bx % 2) * 16) % 32 == 0: c = c.darkened(0.35)
			img.set_pixel(x, y, c)
	return img

static func _lino() -> Image:
	var S := 32
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var r := _rng(8); var n := _noise(8, 0.1)
	for y in S:
		for x in S:
			var chk := ((x / 8) + (y / 8)) % 2 == 0
			var c := Color("9a8f6a") if chk else Color("6f6650")
			img.set_pixel(x, y, c.darkened(0.12 * n.get_noise_2d(x, y) + r.randf() * 0.05))
	return img

static func _tiles(tile: Color, grout: Color) -> Image:
	var S := 32
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var r := _rng(4)
	for y in S:
		for x in S:
			var c := tile if (x % 8 != 0 and y % 8 != 0) else grout
			img.set_pixel(x, y, c.darkened(r.randf() * 0.06))
	return img

static func _wood(base: Color, seed: int) -> Image:
	var S := 32
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var r := _rng(seed); var n := _noise(seed, 0.05)
	for y in S:
		for x in S:
			var g := sin(y * 0.9 + n.get_noise_2d(x, y) * 8.0) * 0.08
			img.set_pixel(x, y, base.darkened(g + r.randf() * 0.04))
	return img

## The front door: brown leatherette padding held by a diamond of upholstery studs.
static func _padded() -> Image:
	var S := 32
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var r := _rng(12)
	for y in S:
		for x in S:
			var dx := absi((x % 16) - 8); var dy := absi((y % 16) - 8)
			var c := Color("4a2a1c").darkened(float(dx + dy) * 0.015 + r.randf() * 0.05)
			if dx + dy == 8: c = c.darkened(0.3)
			if (x % 16 == 0 and y % 16 == 0) or (x % 16 == 8 and y % 16 == 8): c = Color("a89a6a")
			img.set_pixel(x, y, c)
	return img

## Stairwell wall: institutional green paint to 1.2 m, whitewash above (2 m texture).
static func _stairwell() -> Image:
	var S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var r := _rng(14); var n := _noise(14, 0.1)
	for y in S:
		for x in S:
			var h := 1.0 - float(y) / S  # 0 floor .. 1 at 2 m
			var c := Color("3f6a55") if h < 0.6 else Color("b9b6a8")
			if absf(h - 0.6) < 0.02: c = Color("2a3a30")
			img.set_pixel(x, y, c.darkened(0.1 * n.get_noise_2d(x, y) + r.randf() * 0.05))
	return img

static func _fabric(a: Color, b: Color) -> Image:
	var S := 32
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var r := _rng(int(a.r * 999))
	for y in S:
		for x in S:
			var weave := (x + y) % 2 == 0
			var flower := Vector2(x % 16 - 8, y % 16 - 8).length() < 3.5
			var c := (b if flower else a).darkened(0.06 if weave else 0.0)
			img.set_pixel(x, y, c.darkened(r.randf() * 0.06))
	return img

static func _flesh(base: Color, light: Color, seed: int) -> Image:
	var S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var n := _noise(seed, 0.07); var v := _noise(seed + 50, 0.04); var r := _rng(seed)
	for y in S:
		for x in S:
			var k := clampf(0.5 + n.get_noise_2d(x, y), 0.0, 1.0)
			var c := base.lerp(light, k)
			var vein := absf(v.get_noise_2d(x, y))
			if vein < 0.04: c = c.lerp(Color("3a1430"), 0.7)
			elif vein < 0.07: c = c.lerp(Color("5a2440"), 0.3)
			c = c.darkened(r.randf() * 0.06)
			img.set_pixel(x, y, c)
	return img

static func _coral() -> Image:
	var S := 32
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var n := _noise(21, 0.25); var r := _rng(21)
	for y in S:
		for x in S:
			var k := n.get_noise_2d(x, y)
			var c := Color("d8c8b0").lerp(Color("c48a80"), clampf(k + 0.3, 0.0, 1.0))
			if r.randf() < 0.12: c = c.darkened(0.45)   # pores
			img.set_pixel(x, y, c)
	return img

static func _mould() -> Image:
	var S := 32
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var n := _noise(31, 0.2); var r := _rng(31)
	for y in S:
		for x in S:
			var k := clampf(0.5 + n.get_noise_2d(x, y), 0.0, 1.0)
			var c := Color("2a3020").lerp(Color("6a7a4a"), k)
			if r.randf() < 0.1: c = Color("c8d0a0")
			img.set_pixel(x, y, c)
	return img

## Marta's skin: grey and waxy, with mould coming through in blooms.
static func _skin() -> Image:
	var S := 32
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var n := _noise(41, 0.15); var r := _rng(41)
	for y in S:
		for x in S:
			var k := clampf(0.5 + n.get_noise_2d(x, y) * 1.5, 0.0, 1.0)
			var c := Color("a69a8a").lerp(Color("4a5236"), smoothstep(0.55, 0.9, k))
			img.set_pixel(x, y, c.darkened(r.randf() * 0.08))
	return img

## A sheet of paper covered in boxes drawn inside boxes, in biro, pressed hard.
static func _box_drawing() -> Image:
	var S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	img.fill(Color("d6cfb8"))
	var r := _rng(47)
	for b in 5:
		var cx := r.randi_range(10, 54); var cy := r.randi_range(10, 54)
		var sz := r.randi_range(8, 14)
		while sz > 1:
			for i in range(-sz, sz + 1):
				for p in [Vector2i(cx + i, cy - sz), Vector2i(cx + i, cy + sz), Vector2i(cx - sz, cy + i), Vector2i(cx + sz, cy + i)]:
					if p.x >= 0 and p.y >= 0 and p.x < S and p.y < S: img.set_pixelv(p, Color("2a2a4a"))
			sz -= r.randi_range(2, 3)
			cx += r.randi_range(-1, 1); cy += r.randi_range(-1, 1)
	return img

static func _cardboard() -> Image:
	var S := 32
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var r := _rng(51); var n := _noise(51, 0.2)
	for y in S:
		for x in S:
			var c := Color("9a7a50").darkened(0.08 * n.get_noise_2d(x, y) + r.randf() * 0.05)
			if y % 4 == 0: c = c.darkened(0.05)          # the corrugation showing through
			if absi(y - 16) <= 2: c = Color("b8a888").darkened(r.randf() * 0.05)   # parcel tape
			img.set_pixel(x, y, c)
	return img

static func _newspaper() -> Image:
	var S := 32
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var r := _rng(53)
	for y in S:
		for x in S:
			var c := Color("c8c0a8")
			if y % 3 != 0 and x % 16 > 1 and r.randf() < 0.45: c = Color("6a665c")   # columns of print
			if y < 5: c = Color("3a3a3a") if (x + y) % 3 != 0 else c                 # a headline
			img.set_pixel(x, y, c.darkened(r.randf() * 0.06))
	return img

static func _rug() -> Image:
	var S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var r := _rng(57)
	for y in S:
		for x in S:
			var dx := absi(x - 32); var dy := absi(y - 32)
			var ring := maxi(dx, dy)
			var c := Color("6a1e1e")
			if ring > 28: c = Color("2a1a3a")
			elif ring % 8 < 2: c = Color("b08a4a")
			elif (dx + dy) % 12 < 3: c = Color("2a3a5a")
			img.set_pixel(x, y, c.darkened(r.randf() * 0.1))
	return img
