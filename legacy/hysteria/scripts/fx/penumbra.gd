class_name Penumbra
## three.js's spot penumbra: full strength in the inner (1 - penumbra) of the cone, then a
## smoothstep to nothing at the edge. Godot's angle attenuation can't make that curve; a light
## projector can. Projectors map the cone onto the texture square, so the circle fills it.

static var _cache := {}

static func make(penumbra: float) -> ImageTexture:
	var key := snappedf(penumbra, 0.01)
	if _cache.has(key):
		return _cache[key]
	const N := 64
	var img := Image.create(N, N, false, Image.FORMAT_L8)
	for y in N:
		for x in N:
			var r := Vector2(x + 0.5 - N * 0.5, y + 0.5 - N * 0.5).length() / (N * 0.5)
			var k := 1.0 - smoothstep(1.0 - key, 1.0, r) if key > 0.0 else (1.0 if r <= 1.0 else 0.0)
			img.set_pixel(x, y, Color(k, k, k))
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t
