class_name RomanovPortraits
## The pictures in the labyrinth, painted in code: they're how the place tells you things.
##
##   rasputin    a sepia studio cabinet card: the big bearded man in a peasant shirt and black
##               coat, his hand on the head of a seated young woman who looks away (Marta)
##   photobooth  four frames from a 1960s booth: a masked man and the same woman
##   icon        a small Mother of God on gold, for the icon corner
##   drawing     a child's crayon drawing: MAMA, the girl, and a small man with a bow walking off
##               the edge of the paper
##   drawing2    another: a house with smoke, two figures in the doorway
##   lullaby     the music box's tune, a little out of true, winding down and starting again

static var _cache := {}

static func _cached(key: String, f: Callable) -> Variant:
	if not _cache.has(key): _cache[key] = f.call()
	return _cache[key]

# ---------------------------------------------------------------- drawing helpers
static func _ellipse(img: Image, c: Vector2, r: Vector2, col: Color, soft := 0.0) -> void:
	for y in range(int(c.y - r.y - 2), int(c.y + r.y + 3)):
		for x in range(int(c.x - r.x - 2), int(c.x + r.x + 3)):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height(): continue
			var d := Vector2((x - c.x) / r.x, (y - c.y) / r.y).length()
			if d <= 1.0:
				var a := 1.0 if soft <= 0.0 else clampf((1.0 - d) / soft, 0.0, 1.0)
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(col, a * col.a))

static func _poly(img: Image, pts: PackedVector2Array, col: Color) -> void:
	var minp := pts[0]; var maxp := pts[0]
	for p in pts: minp = minp.min(p); maxp = maxp.max(p)
	for y in range(int(minp.y), int(maxp.y) + 1):
		for x in range(int(minp.x), int(maxp.x) + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height(): continue
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(col, col.a))

static func _line(img: Image, a: Vector2, b: Vector2, col: Color, w := 1.0, jitter := 0.0, rng: RandomNumberGenerator = null) -> void:
	var n := int(a.distance_to(b) * 2.0) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		if rng and jitter > 0.0: p += Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
		_ellipse(img, p, Vector2(w, w), col)

static func _finish(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# ---------------------------------------------------------------- the cabinet card
static func rasputin() -> ImageTexture:
	return _cached("rasputin", func() -> ImageTexture:
		const W := 96; const H := 124
		var img := Image.create(W, H, false, Image.FORMAT_RGB8)
		var rng := RandomNumberGenerator.new(); rng.seed = 1916
		var n := FastNoiseLite.new(); n.seed = 3; n.frequency = 0.08
		var sep := func(v: float) -> Color: return Color(0.18, 0.12, 0.07).lerp(Color(0.86, 0.76, 0.58), clampf(v, 0.0, 1.0))
		# the card mount, then the print: the studio's painted garden behind them, darker below
		img.fill(Color(0.8, 0.74, 0.6))
		for y in range(6, H - 14):
			for x in range(6, W - 6):
				var v := 0.62 - float(y - 6) / (H - 20) * 0.25 + n.get_noise_2d(x, y) * 0.08
				img.set_pixel(x, y, sep.call(v))
		# the balustrade of the backdrop, faint
		for x in range(6, W - 6, 6):
			_line(img, Vector2(x, 70), Vector2(x, 84), sep.call(0.55), 1.0)
		_line(img, Vector2(6, 69), Vector2(W - 6, 69), sep.call(0.58), 1.0)
		# HIM: standing, left of centre. Long black coat, flaring to the knee; a pale belted
		# peasant shirt at the chest; long hair parted in the middle; a beard to the chest
		var cx := 36.0
		_poly(img, PackedVector2Array([Vector2(cx - 13, 44), Vector2(cx + 13, 44), Vector2(cx + 20, 108), Vector2(cx - 19, 108)]), sep.call(0.1))     # coat
		_poly(img, PackedVector2Array([Vector2(cx - 5, 45), Vector2(cx + 6, 45), Vector2(cx + 7, 70), Vector2(cx - 6, 70)]), sep.call(0.72))          # shirt
		_line(img, Vector2(cx - 6, 64), Vector2(cx + 7, 64), sep.call(0.25), 1.0)                                                                     # belt
		_ellipse(img, Vector2(cx, 31), Vector2(7.5, 9.5), sep.call(0.66))                                                                           # face
		_poly(img, PackedVector2Array([Vector2(cx - 8, 26), Vector2(cx - 12, 46), Vector2(cx - 6, 40)]), sep.call(0.12))                             # hair, left
		_poly(img, PackedVector2Array([Vector2(cx + 8, 26), Vector2(cx + 12, 46), Vector2(cx + 6, 40)]), sep.call(0.12))                             # hair, right
		_ellipse(img, Vector2(cx, 23), Vector2(8.5, 5.0), sep.call(0.12))                                                                           # crown, parted
		_line(img, Vector2(cx, 18), Vector2(cx, 24), sep.call(0.5), 0.5)
		_poly(img, PackedVector2Array([Vector2(cx - 7, 33), Vector2(cx + 7, 33), Vector2(cx + 5, 56), Vector2(cx, 60), Vector2(cx - 5, 56)]), sep.call(0.14))   # beard
		_ellipse(img, Vector2(cx - 3, 29), Vector2(1.4, 1.0), sep.call(0.04))                                                                      # the eyes, deep-set
		_ellipse(img, Vector2(cx + 3, 29), Vector2(1.4, 1.0), sep.call(0.04))
		_line(img, Vector2(cx - 5, 27), Vector2(cx - 1.5, 27.5), sep.call(0.2), 0.6)
		_line(img, Vector2(cx + 1.5, 27.5), Vector2(cx + 5, 27), sep.call(0.2), 0.6)
		# his right arm out to her: the sleeve, the big hand on her hair
		_poly(img, PackedVector2Array([Vector2(cx + 10, 48), Vector2(cx + 15, 47), Vector2(cx + 27, 60), Vector2(cx + 24, 64)]), sep.call(0.1))
		# HER: seated, right, lower; dark hair up; a pale high-necked dress; her face turned
		# from the camera
		var hx := 64.0
		_poly(img, PackedVector2Array([Vector2(hx - 15, 106), Vector2(hx + 15, 106), Vector2(hx + 11, 76), Vector2(hx - 9, 76)]), sep.call(0.7))     # skirt
		_poly(img, PackedVector2Array([Vector2(hx - 8, 76), Vector2(hx + 9, 76), Vector2(hx + 7, 60), Vector2(hx - 6, 60)]), sep.call(0.76))           # bodice
		_ellipse(img, Vector2(hx + 1.5, 52), Vector2(5.0, 6.5), sep.call(0.7))                                                                      # face, turned
		_ellipse(img, Vector2(hx - 1, 46.5), Vector2(6.5, 4.5), sep.call(0.1))                                                                      # hair
		_ellipse(img, Vector2(hx - 3, 42), Vector2(3.5, 2.8), sep.call(0.1))                                                                        # the knot
		_ellipse(img, Vector2(hx + 4.0, 51.5), Vector2(0.9, 0.7), sep.call(0.1))                                                                   # one eye, looking off
		_ellipse(img, Vector2(cx + 26, 61), Vector2(3.0, 2.5), sep.call(0.62))                                                                     # his hand, on her head
		# the chair's back beside her
		_line(img, Vector2(hx + 13, 60), Vector2(hx + 13, 100), sep.call(0.15), 1.0)
		# the oval vignette, foxing, a studio's name blind-stamped below
		for y in range(6, H - 14):
			for x in range(6, W - 6):
				var d := Vector2((x - W * 0.5) / (W * 0.44), (y - (H - 8) * 0.5) / (H * 0.46)).length()
				var c := img.get_pixel(x, y).lerp(Color(0.84, 0.78, 0.64), smoothstep(0.82, 1.02, d))
				if rng.randf() < 0.012: c = c.lerp(Color(0.55, 0.4, 0.22), 0.5)
				img.set_pixel(x, y, c)
		for x in range(30, 66):
			if x % 3 != 0: img.set_pixel(x, H - 8, Color(0.7, 0.62, 0.48))
		return _finish(img))

# ---------------------------------------------------------------- the photo strip
static func photobooth() -> ImageTexture:
	return _cached("booth", func() -> ImageTexture:
		const W := 22; const H := 80
		var img := Image.create(W, H, false, Image.FORMAT_RGB8)
		img.fill(Color(0.95, 0.94, 0.9))
		for f in 4:
			var y0 := 2 + f * 19
			for y in range(y0, y0 + 17):
				for x in range(2, W - 2):
					img.set_pixel(x, y, Color(0.55, 0.55, 0.55).lerp(Color(0.75, 0.75, 0.74), float(y - y0) / 17.0))
			var m := Vector2(8, y0 + 8); var w := Vector2(15, y0 + 9)
			if f == 2: m.x += 2; w.x -= 2                  # she kisses his cheek
			_ellipse(img, m + Vector2(0, 7), Vector2(4.5, 3.5), Color(0.15, 0.15, 0.15))   # his shoulders
			_ellipse(img, m, Vector2(3.2, 4.0), Color(0.72, 0.72, 0.7))
			_line(img, m + Vector2(-3, -0.5), m + Vector2(3, -0.5), Color(0.05, 0.05, 0.05), 0.9)   # the mask
			_ellipse(img, w + Vector2(0, 7), Vector2(4.0, 3.0), Color(0.4, 0.4, 0.4))
			_ellipse(img, w, Vector2(3.0, 3.8), Color(0.8, 0.8, 0.78))
			_ellipse(img, w + Vector2(0, -2.5), Vector2(3.6, 2.4), Color(0.1, 0.1, 0.1))   # her hair
			if f == 3:
				img.set_pixel(int(w.x) - 1, int(w.y), Color.BLACK); img.set_pixel(int(w.x) + 1, int(w.y), Color.BLACK)   # her eyes, on you
			elif f < 2:
				_line(img, w + Vector2(-1.5, 1.5), w + Vector2(1.5, 1.5), Color(0.2, 0.2, 0.2), 0.4)   # laughing
		return _finish(img))

# ---------------------------------------------------------------- the icon
static func icon() -> ImageTexture:
	return _cached("icon", func() -> ImageTexture:
		const W := 32; const H := 40
		var img := Image.create(W, H, false, Image.FORMAT_RGB8)
		img.fill(Color(0.72, 0.55, 0.22))
		for y in H:
			for x in W:
				if x < 2 or y < 2 or x >= W - 2 or y >= H - 2: img.set_pixel(x, y, Color(0.35, 0.18, 0.1))
		_ellipse(img, Vector2(16, 12), Vector2(7, 7), Color(0.9, 0.75, 0.35))               # halo
		_poly(img, PackedVector2Array([Vector2(16, 8), Vector2(27, 20), Vector2(26, 38), Vector2(6, 38), Vector2(5, 20)]), Color(0.42, 0.12, 0.1))   # maphorion
		_ellipse(img, Vector2(16, 13), Vector2(3.4, 4.2), Color(0.55, 0.38, 0.25))          # her face
		_ellipse(img, Vector2(20, 26), Vector2(4, 4), Color(0.88, 0.72, 0.35))              # the child's halo
		_ellipse(img, Vector2(20, 26), Vector2(2.2, 2.6), Color(0.55, 0.38, 0.25))
		_poly(img, PackedVector2Array([Vector2(17, 28), Vector2(23, 28), Vector2(24, 36), Vector2(16, 36)]), Color(0.75, 0.6, 0.35))
		return _finish(img))

# ---------------------------------------------------------------- her drawings
static func drawing() -> ImageTexture:
	return _cached("drawing", func() -> ImageTexture:
		const W := 96; const H := 68
		var img := Image.create(W, H, false, Image.FORMAT_RGB8)
		img.fill(Color(0.93, 0.9, 0.82))
		var rng := RandomNumberGenerator.new(); rng.seed = 22
		var red := Color(0.78, 0.12, 0.1); var black := Color(0.08, 0.08, 0.1); var yellow := Color(0.9, 0.72, 0.1)
		# the sun in the corner
		_ellipse(img, Vector2(10, 9), Vector2(5, 5), yellow)
		for i in 8:
			var a := TAU * i / 8.0
			_line(img, Vector2(10, 9) + Vector2(cos(a), sin(a)) * 7, Vector2(10, 9) + Vector2(cos(a), sin(a)) * 10, yellow, 0.6, 0.3, rng)
		# MAMA, big: a red triangle dress, a black crown of hair, stick arms
		_poly(img, PackedVector2Array([Vector2(34, 26), Vector2(48, 60), Vector2(20, 60)]), red)
		_ellipse(img, Vector2(34, 20), Vector2(6, 6), Color(0.95, 0.8, 0.65))
		for i in 7:
			var a := PI + PI * i / 6.0
			_line(img, Vector2(34, 18) + Vector2(cos(a), sin(a)) * 6, Vector2(34, 18) + Vector2(cos(a), sin(a)) * 10, black, 0.9, 0.3, rng)
		_line(img, Vector2(31, 19), Vector2(31, 19), black, 0.6); _line(img, Vector2(37, 19), Vector2(37, 19), black, 0.6)
		_line(img, Vector2(31, 23), Vector2(37, 23), red, 0.5)
		_line(img, Vector2(27, 32), Vector2(18, 40), red, 0.8, 0.3, rng)
		_line(img, Vector2(41, 32), Vector2(52, 40), red, 0.8, 0.3, rng)
		# the girl holding her hand: small, yellow
		_poly(img, PackedVector2Array([Vector2(56, 40), Vector2(62, 58), Vector2(50, 58)]), yellow)
		_ellipse(img, Vector2(56, 36), Vector2(3.5, 3.5), Color(0.95, 0.8, 0.65))
		_line(img, Vector2(53, 33), Vector2(51, 36), black, 0.6); _line(img, Vector2(59, 33), Vector2(61, 36), black, 0.6)
		# and him: right at the edge, small, black, a bow on his back, walking off the paper
		_line(img, Vector2(90, 42), Vector2(90, 52), black, 0.6, 0.2, rng)
		_ellipse(img, Vector2(90, 39), Vector2(2, 2), black)
		_line(img, Vector2(90, 52), Vector2(87, 59), black, 0.5, 0.2, rng); _line(img, Vector2(90, 52), Vector2(94, 58), black, 0.5, 0.2, rng)
		_line(img, Vector2(90, 45), Vector2(95, 48), black, 0.5)
		for i in 6:
			var a0 := -0.9 + i * 0.3; var a1 := a0 + 0.3
			_line(img, Vector2(87, 46) + Vector2(sin(a0) * 2, -cos(a0) * 7), Vector2(87, 46) + Vector2(sin(a1) * 2, -cos(a1) * 7), black, 0.4)
		# МАМА across the top in red crayon, the letters wobbly and too big
		var x := 24.0
		for ch in "МАМА":
			if ch == "М":
				_line(img, Vector2(x, 12), Vector2(x, 4), red, 0.8, 0.3, rng); _line(img, Vector2(x, 4), Vector2(x + 3, 9), red, 0.8, 0.3, rng)
				_line(img, Vector2(x + 3, 9), Vector2(x + 6, 4), red, 0.8, 0.3, rng); _line(img, Vector2(x + 6, 4), Vector2(x + 6, 12), red, 0.8, 0.3, rng)
				x += 9.0
			else:
				_line(img, Vector2(x, 12), Vector2(x + 3, 4), red, 0.8, 0.3, rng); _line(img, Vector2(x + 3, 4), Vector2(x + 6, 12), red, 0.8, 0.3, rng)
				_line(img, Vector2(x + 1.3, 9), Vector2(x + 4.7, 9), red, 0.7, 0.2, rng)
				x += 9.0
		return _finish(img))

static func drawing2() -> ImageTexture:
	return _cached("drawing2", func() -> ImageTexture:
		const S := 64
		var img := Image.create(S, S, false, Image.FORMAT_RGB8)
		img.fill(Color(0.92, 0.9, 0.84))
		var rng := RandomNumberGenerator.new(); rng.seed = 23
		var brown := Color(0.45, 0.28, 0.12); var blue := Color(0.2, 0.3, 0.7)
		_poly(img, PackedVector2Array([Vector2(16, 30), Vector2(48, 30), Vector2(48, 56), Vector2(16, 56)]), brown)
		_poly(img, PackedVector2Array([Vector2(12, 31), Vector2(32, 12), Vector2(52, 31)]), Color(0.7, 0.15, 0.1))
		_poly(img, PackedVector2Array([Vector2(28, 42), Vector2(36, 42), Vector2(36, 56), Vector2(28, 56)]), Color(0.95, 0.85, 0.4))
		_ellipse(img, Vector2(30, 47), Vector2(1.6, 1.6), Color(0.7, 0.1, 0.1)); _ellipse(img, Vector2(34, 47), Vector2(1.3, 1.3), Color(0.9, 0.75, 0.2))
		for i in 5:
			_ellipse(img, Vector2(42 + i * 2 + rng.randf(), 12 - i * 2.5), Vector2(2.5 + i * 0.4, 2), Color(0.55, 0.55, 0.6))
		_line(img, Vector2(4, 58), Vector2(60, 58), Color(0.2, 0.55, 0.2), 1.0, 0.4, rng)
		_line(img, Vector2(6, 6), Vector2(14, 8), blue, 0.6)
		return _finish(img))

# ---------------------------------------------------------------- the music box
static func lullaby() -> AudioStreamWAV:
	return _cached("lullaby", func() -> AudioStreamWAV:
		const RATE := 22050
		# a slow lullaby in a minor key, music-box comb tines: a bright attack, a long bell decay;
		# the mechanism a hair out of tune, slowing at the end of the phrase as it runs down
		var melody := [[76, 1], [76, 1], [74, 1], [76, 1], [72, 2], [71, 2], [69, 1], [72, 1], [71, 1], [69, 1], [68, 2], [69, 2],
			[76, 1], [77, 1], [76, 1], [74, 1], [72, 2], [74, 1], [72, 1], [71, 1], [69, 1], [71, 1], [68, 1], [69, 4]]
		var beat := 0.42
		var total := 0.0
		for nt in melody: total += float(nt[1]) * beat
		total += 3.0
		var n := int(total * RATE)
		var buf := PackedFloat32Array(); buf.resize(n)
		var t0 := 0.0
		for i in melody.size():
			var nt: Array = melody[i]
			var slow := 1.0 + smoothstep(0.7, 1.0, float(i) / melody.size()) * 0.6
			var f := 440.0 * pow(2.0, (float(nt[0]) - 69.0) / 12.0) * (1.0 + (randf() - 0.5) * 0.004)
			var start := int(t0 * RATE)
			for k in int(RATE * 2.2):
				var idx := start + k
				if idx >= n: break
				var t := float(k) / RATE
				var env := exp(-t * 2.6)
				buf[idx] += (sin(TAU * f * t) + 0.35 * sin(TAU * f * 2.0 * t) * exp(-t * 6.0) + 0.15 * sin(TAU * f * 5.4 * t) * exp(-t * 14.0)) * env * 0.22
			t0 += float(nt[1]) * beat * slow
		var bytes := PackedByteArray(); bytes.resize(n * 2)
		for i in n: bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
		var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.data = bytes
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_end = n
		return w)
