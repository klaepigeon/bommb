class_name Meat
extends RefCounted
## LAST CALL 3's puppets are made of meat. Textures for it, generated once and cached:
## marbled muscle with streaks of fat and sinew, going off in patches (grey-green, bruise
## purple, black where it's clotted), stitched where pieces were joined. And eyes: the one
## thing on them that isn't crude. A real eye, wet and veined, in a PS1 body.

static var _cache: Dictionary = {}


static func _cached(key: String, fn: Callable) -> ImageTexture:
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(fn.call())
	return _cache[key]


## Rotting meat, `rot` 0 (fresh) .. 1 (well gone), `s` a seed.
static func flesh(rot := 0.4, s := 1) -> ImageTexture:
	return _cached("flesh%d_%d" % [int(rot * 10), s], func():
		var size := 32
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var muscle := Color("b02a30")
		var bright := Color("f0707a")
		var fat := Color("e8d0a8")
		var green := Color("5a6a3a")
		var purple := Color("4a1a3a")
		for y in size:
			for x in size:
				# muscle fibres run one way, with the grain wandering
				var g := LcTex.fbm(x * 0.12, y * 0.45, s, 3)
				var c := muscle.lerp(bright, clampf(g * 1.3 - 0.15, 0.0, 1.0))
				c = c.darkened(0.12 * float((x + int(g * 6.0)) % 3 == 0))
				# marbling: thin wandering streaks of fat
				var m := absf(sin((x * 0.35 + y * 0.12) + LcTex.fbm(x * 0.15, y * 0.15, s + 3) * 6.0))
				if m < 0.16:
					c = c.lerp(fat, 0.8)
				# going off
				var r := LcTex.fbm(x * 0.09 + 3.0, y * 0.09, s + 7, 3)
				if r > 1.0 - rot * 0.55:
					c = c.lerp(green, 0.6)
				if r > 1.0 - rot * 0.35:
					c = c.lerp(purple, 0.5)
				# clots
				if LcTex._h(x / 2, y / 2, s + 11) > 0.97:
					c = Color("1a0406")
				img.set_pixel(x, y, c)
		return img)


## Skin that's been sewn back on: pale, mottled, with a row of black stitches.
static func hide(s := 1) -> ImageTexture:
	return _cached("hide%d" % s, func():
		var size := 32
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in size:
			for x in size:
				var n := LcTex.fbm(x * 0.15, y * 0.15, s + 20, 3)
				var c := Color("c89a88").lerp(Color("8a5a5a"), n)
				if LcTex.fbm(x * 0.1, y * 0.1, s + 23) > 0.68:
					c = c.lerp(Color("6a7050"), 0.5)
				if (y == 15 or y == 16) and x % 4 < 2:
					c = Color("120808")
				if y == 15 and x % 4 == 1:
					c = Color("120808")
				img.set_pixel(x, y, c)
		return img)


## An eye, laid out for LcMB.sphere's UVs (u round the equator, v pole to pole): the iris
## centred where the sphere faces +Z (u 0.25, v 0.5). Veined sclera, a striated iris with a
## dark limbal ring, the pupil, a wet highlight.
static func eye(iris_col: Color, bloodshot := 0.0, s := 1) -> ImageTexture:
	return _cached("eye%s_%d_%d" % [iris_col.to_html(), int(bloodshot * 10), s], func():
		var w := 128
		var h := 64
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = s * 97 + 5
		var cu := 0.25 * w
		var cv := 0.5 * h
		for y in h:
			for x in w:
				# angular distance from the front of the eye, roughly
				var du := (x - cu) / w * TAU
				var dv := (y - cv) / h * PI
				var d := sqrt(du * du + dv * dv)
				var c := Color("f2ece0").lerp(Color("e8c8b8"), clampf((d - 0.6) * 0.5, 0.0, 1.0))
				c = c.lerp(Color("d89080"), bloodshot * 0.35)
				var ang := atan2(dv, du)
				if d < 0.42:
					# iris: fibres radiating out, darker ring at the edge
					var fib := 0.75 + 0.25 * sin(ang * 38.0 + LcTex.fbm(ang * 3.0, d * 8.0, s) * 5.0)
					c = iris_col.darkened(0.25).lerp(iris_col.lightened(0.25), fib * (0.5 + d))
					if d > 0.36:
						c = c.darkened(0.55)
					if d < 0.2:
						c = c.lerp(iris_col.lightened(0.4).lerp(Color("c8a050"), 0.3), 0.35)
				if d < 0.15:
					c = Color("060404")
				# the highlight: a window, up and to one side
				var hx := du + 0.12
				var hy := dv + 0.12
				if hx * hx + hy * hy < 0.0035:
					c = Color("ffffff")
				img.set_pixel(x, y, c)
		# veins: crooked red lines creeping in from the back of the eye
		var veins := 5 + int(bloodshot * 12)
		for k in veins:
			var a := rng.randf() * TAU
			var r := 1.5
			var px := cu + cos(a) * r / TAU * w
			var py := cv + sin(a) * r / PI * h
			for step in 40:
				r -= 0.025
				a += rng.randf_range(-0.25, 0.25)
				px = cu + cos(a) * r / TAU * w
				py = cv + sin(a) * r / PI * h
				if r < 0.5:
					break
				var ix := int(px) % w
				var iy := clampi(int(py), 0, h - 1)
				img.set_pixel(ix, iy, Color("b8302a").lerp(Color("e05a50"), rng.randf()))
		return img)


## A whole eyeball (sphere, high for a PS1 model: the eyes are the realistic part).
static func eyeball(radius: float, iris_col: Color, bloodshot := 0.0, s := 1) -> ArrayMesh:
	var mb := LcMB.new()
	var m := LcMB.mat(eye(iris_col, bloodshot, s), Color(1.25, 1.25, 1.25))
	mb.sphere("e", m, radius, 10, 16, LcMB.T(), Color(1, 1, 1))
	return mb.build()
