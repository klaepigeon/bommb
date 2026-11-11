class_name Tex
extends RefCounted
## Small procedural textures, PS1-sized (64 px, unfiltered), made once.
static var _c := {}

static func get_tex(name: String) -> Texture2D:
	if _c.has(name): return _c[name]
	var img := _make(name)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_c[name] = t
	return t

static func _noise(seed: int, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new(); n.seed = seed; n.frequency = freq
	n.fractal_octaves = 3
	return n

static func _make(name: String) -> Image:
	const S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new(); rng.seed = name.hash()
	var n := _noise(name.hash(), 0.08)
	var n2 := _noise(name.hash() + 7, 0.25)
	for y in S:
		for x in S:
			var v := n.get_noise_2d(x, y) * 0.5 + 0.5
			var f := n2.get_noise_2d(x, y) * 0.5 + 0.5
			var c := Color.GRAY
			match name:
				"plaster": c = Color("8d8775").lerp(Color("6c665a"), v * 0.8) * (0.92 + f * 0.12)
				"plaster_dark": c = Color("5a5548").lerp(Color("3a3830"), v) * (0.9 + f * 0.15)
				"paint_green": c = Color("3f5a48").lerp(Color("2f4638"), v * 0.6) * (0.95 + f * 0.1)
				"draft": c = Color("d8d6cf").lerp(Color("c4c1b8"), v * 0.7)
				"brick":
					var row := y / 8
					var off := (row % 2) * 8
					var mortar := (y % 8 == 0) or ((x + off) % 16 == 0)
					c = Color("6e3b2a").lerp(Color("8a4c34"), f) * (0.85 + v * 0.3)
					if mortar: c = Color("5d574b") * (0.8 + v * 0.3)
				"lath":
					var plank := (y % 6) < 4
					c = Color("6b5236").lerp(Color("4a3826"), f) if plank else Color("1a1612")
				"concrete": c = Color("5e5d58").lerp(Color("47463f"), v) * (0.9 + f * 0.15)
				"floorboards":
					var board := x / 10
					c = Color("5a3f28").lerp(Color("3f2c1c"), _noise(board, 0.3).get_noise_1d(y) * 0.5 + 0.5) * (0.85 + f * 0.2)
					if x % 10 == 0: c *= 0.5
				"coral":
					c = Color("b0453c").lerp(Color("e8c8b0"), smoothstep(0.35, 0.8, v)) * (0.8 + f * 0.3)
				"flesh": c = Color("8e6a5c").lerp(Color("5a4038"), v) * (0.85 + f * 0.25)
				"wallpaper_green":
					var stripe := 0.85 if (x / 4) % 2 == 0 else 1.0
					c = Color("4f5e48").lerp(Color("3a4636"), v) * stripe
					if (x % 16 == 8 and y % 16 < 6) or (y % 16 == 3 and x % 16 > 5 and x % 16 < 11): c = Color("776f50")
				"wallpaper_rose":
					c = Color("7a5d58").lerp(Color("5c4440"), v)
					var d := Vector2(x % 16 - 8, y % 16 - 8).length()
					if d < 3.0: c = Color("8c4e4c")
				"damp": c = Color("4c4a3e").lerp(Color("2e2d24"), v) * (0.85 + f * 0.25)
				"tile":
					c = Color("a7aca4") * (0.92 + f * 0.1)
					if x % 16 == 0 or y % 16 == 0: c = Color("5a5c55")
				"rust": c = Color("6b3a22").lerp(Color("3c2418"), v) * (0.8 + f * 0.3)
				"paper": c = Color("e9e3cf").lerp(Color("cfc6ad"), v * 0.5)
				"sticky": c = Color("f2df67") * (0.95 + f * 0.05)
				"cloth": c = Color("5b5f6e").lerp(Color("3f4250"), v) * (0.85 + f * 0.25)
				"skin_pale": c = Color("c9b8a6").lerp(Color("9e8a7c"), v) * (0.9 + f * 0.15)
				"skin_grey": c = Color("8f8f86").lerp(Color("6a6a62"), v) * (0.9 + f * 0.15)
				"metal": c = Color("6c6f70").lerp(Color("44484a"), v) * (0.85 + f * 0.3)
				_: c = Color(0.5, 0.5, 0.5) * (0.8 + v * 0.4)
			img.set_pixel(x, y, c.clamp())
	return img
