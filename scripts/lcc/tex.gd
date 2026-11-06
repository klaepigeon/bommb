class_name Tex
extends RefCounted
## Procedural low-resolution textures, made to look hand-painted at 32-128 px.
## Everything is generated once and cached; all sampling is nearest-neighbour.

static var _cache: Dictionary = {}
static var _kinds: Dictionary = {}     # texture instance id -> the kind of pen-work over it
static var _sheets: Dictionary = {}

## Remember what a texture is of, so the material can lay the right pen-work over it.
static func _k(t: ImageTexture, kind: String) -> ImageTexture:
	_kinds[t.get_instance_id()] = kind
	return t

static func ink_kind(t: Texture2D) -> String:
	return _kinds.get(t.get_instance_id(), "") if t != null else ""

static func ink_sheet(kind: String) -> Texture2D:
	if not _sheets.has(kind):
		var p := "res://assets/ink/tex/%s.png" % kind
		_sheets[kind] = load(p) if ResourceLoader.exists(p) else null
	return _sheets[kind]

const DIGITS_3X5 := {
	"0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
	"2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "011", "001", "111"],
	"4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
	"6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
	"8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
}

static func cached(key: String, fn: Callable) -> ImageTexture:
	if _cache.has(key):
		return _cache[key]
	var img: Image = fn.call()
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t

static func _h(x: int, y: int, s: int) -> float:
	var n := (x * 374761393 + y * 668265263 + s * 2147483647) & 0x7fffffff
	n = (n ^ (n >> 13)) * 1274126177
	n = n & 0x7fffffff
	return float(n % 10000) / 10000.0

static func _vnoise(x: float, y: float, s: int) -> float:
	var xi := int(floor(x))
	var yi := int(floor(y))
	var fx := x - xi
	var fy := y - yi
	var a := _h(xi, yi, s)
	var b := _h(xi + 1, yi, s)
	var c := _h(xi, yi + 1, s)
	var d := _h(xi + 1, yi + 1, s)
	var u := fx * fx * (3.0 - 2.0 * fx)
	var v := fy * fy * (3.0 - 2.0 * fy)
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v)

static func fbm(x: float, y: float, s: int, oct := 3) -> float:
	var t := 0.0
	var amp := 0.5
	var f := 1.0
	for i in range(oct):
		t += _vnoise(x * f, y * f, s + i * 17) * amp
		f *= 2.0
		amp *= 0.5
	return t

static func _shade(c: Color, k: float) -> Color:
	return Color(clampf(c.r * k, 0, 1), clampf(c.g * k, 0, 1), clampf(c.b * k, 0, 1), c.a)

## Wooden planks running along x. Visible seams, grain, the odd knot.
static func wood(base: Color = Color("6a4a30"), s: int = 1, size: int = 64, planks: int = 4) -> ImageTexture:
	return _k(cached("wood%s%d%d%d" % [base.to_html(), s, size, planks], func():
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var ph := size / planks
		for y in range(size):
			var plank := y / ph
			var tone := 0.85 + _h(plank, 3, s) * 0.3
			for x in range(size):
				var g := fbm(x * 0.06 + plank * 7.0, y * 0.5, s)
				var grain := 0.8 + 0.4 * g + 0.08 * sin((x + plank * 13) * 0.35 + g * 6.0)
				var c := _shade(base, tone * grain)
				if y % ph == 0:
					c = _shade(base, 0.35)
				elif y % ph == ph - 1:
					c = _shade(base, 0.6)
				var seam_x := int(_h(plank, 9, s) * size)
				if x == seam_x:
					c = _shade(base, 0.4)
				if _h(x / 3, y / 2, s + plank) > 0.985:
					c = _shade(base, 0.45)
				img.set_pixel(x, y, c)
		return img), "wood")

static func checker(a: Color, b: Color, size: int = 64, cells: int = 4, s: int = 2, grime := 0.25) -> ImageTexture:
	return _k(cached("chk%s%s%d%d%d" % [a.to_html(), b.to_html(), size, cells, s], func():
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var cs := size / cells
		for y in range(size):
			for x in range(size):
				var c := a if ((x / cs) + (y / cs)) % 2 == 0 else b
				var n := fbm(x * 0.12, y * 0.12, s)
				c = _shade(c, 1.0 - grime + n * grime * 1.6)
				if x % cs == 0 or y % cs == 0:
					c = _shade(c, 0.7)
				img.set_pixel(x, y, c)
		return img), "tiles4" if cells <= 4 else "tiles8")

## Generic grimy surface (plaster, stone, flesh) from a palette of two colours.
static func grime(a: Color, b: Color, size: int = 64, s: int = 3, scale := 0.08, blotch := 0.0) -> ImageTexture:
	return _k(cached("grm%s%s%d%d%f%f" % [a.to_html(), b.to_html(), size, s, scale, blotch], func():
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in range(size):
			for x in range(size):
				var n := fbm(x * scale, y * scale, s, 4)
				var c := a.lerp(b, clampf(n * 1.4 - 0.2, 0, 1))
				if blotch > 0.0 and fbm(x * 0.05 + 9.0, y * 0.05, s + 5) > 1.0 - blotch:
					c = _shade(c, 0.6)
				c = _shade(c, 0.92 + _h(x, y, s) * 0.16)
				img.set_pixel(x, y, c)
		return img), "hatch")

## Stone flags for tactical tiles: one tile per texture, beveled edge, cracks.
static func flagstone(base: Color, s: int = 4, size: int = 32, crack := 0.5) -> ImageTexture:
	return _k(cached("flag%s%d%d%f" % [base.to_html(), s, size, crack], func():
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in range(size):
			for x in range(size):
				var n := fbm(x * 0.15, y * 0.15, s, 3)
				var c := _shade(base, 0.8 + n * 0.45)
				if x == 0 or y == 0:
					c = _shade(base, 1.25)
				elif x == size - 1 or y == size - 1:
					c = _shade(base, 0.5)
				img.set_pixel(x, y, c)
		# a crack
		if _h(s, 1, 7) < crack:
			var cx := 4 + int(_h(s, 2, 7) * (size - 8))
			var cy := 2
			while cy < size - 2:
				img.set_pixel(cx, cy, _shade(base, 0.45))
				cx = clampi(cx + int(_h(cx, cy, s) * 3) - 1, 1, size - 2)
				cy += 1
				if _h(cx, cy, s + 3) > 0.9:
					break
		return img), "stone")

## Tartan for the Caller's jacket: dark red ground, brown and mustard stripes.
static func plaid(s: int = 5) -> ImageTexture:
	return _k(cached("plaid%d" % s, func():
		var size := 32
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var ground := Color("7a3a24")
		var dark := Color("3e1e14")
		var mustard := Color("b8862e")
		var red := Color("a83a22")
		for y in range(size):
			for x in range(size):
				var c := ground
				var mx := x % 16
				var my := y % 16
				if mx < 4 or my < 4:
					c = c.lerp(dark, 0.6)
				if mx == 8 or my == 8:
					c = c.lerp(mustard, 0.7)
				if mx == 12 or my == 12:
					c = c.lerp(red, 0.5)
				if (x + y) % 2 == 0:
					c = _shade(c, 0.9)
				img.set_pixel(x, y, c)
		return img), "fabric")

static func paper(base: Color = Color("e0d2a8"), s: int = 6, size: int = 64) -> ImageTexture:
	return _k(cached("paper%s%d%d" % [base.to_html(), s, size], func():
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		for y in range(size):
			for x in range(size):
				var n := fbm(x * 0.1, y * 0.1, s)
				var c := _shade(base, 0.88 + n * 0.2)
				if _h(x, y, s) > 0.992:
					c = _shade(base, 0.7)
				img.set_pixel(x, y, c)
		return img), "paper")

static func solid(c: Color) -> ImageTexture:
	return cached("solid" + c.to_html(), func():
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(c)
		return img)

## Wall paneling: sickly green plaster above, dark wood dado below, water stains.
static func wall_panel(s: int = 8) -> ImageTexture:
	return _k(cached("wallp%d" % s, func():
		var w := 64
		var h := 64
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var plaster := Color("4e5a46")
		var dado := Color("3a2618")
		for y in range(h):
			for x in range(w):
				var c: Color
				if y > 44:
					c = _shade(dado, 0.8 + fbm(x * 0.3, y * 0.1, s) * 0.4)
					if x % 16 == 0:
						c = _shade(dado, 0.5)
					if y == 45:
						c = _shade(dado, 1.4)
				else:
					var n := fbm(x * 0.07, y * 0.05, s, 4)
					c = _shade(plaster, 0.75 + n * 0.45)
					# drips
					if fbm(x * 0.4, 1.0, s + 2) > 0.62 and y > 6 and fbm(x * 0.4, y * 0.02, s + 3) > 0.45:
						c = _shade(c, 0.78)
				img.set_pixel(x, y, c)
		return img), "plaster")

static func ceiling(s: int = 9) -> ImageTexture:
	return _k(cached("ceil%d" % s, func():
		var size := 32
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var base := Color("6a665a")
		for y in range(size):
			for x in range(size):
				var c := _shade(base, 0.85 + _h(x, y, s) * 0.25)
				if x == 0 or y == 0:
					c = _shade(base, 0.45)
				if fbm(x * 0.15, y * 0.15, s) > 0.62:
					c = c.lerp(Color("5a4a2a"), 0.4)
				img.set_pixel(x, y, c)
		return img), "ceiling")

static func brass(s: int = 10) -> ImageTexture:
	return grime(Color("8a6a2a"), Color("c8a04a"), 16, s, 0.3)

## 3x5 digits drawn at a pixel scale into an image.
static func draw_digits(img: Image, text: String, x0: int, y0: int, scale: int, col: Color) -> void:
	var x := x0
	for ch in text:
		if DIGITS_3X5.has(ch):
			var rows: Array = DIGITS_3X5[ch]
			for ry in range(5):
				for rx in range(3):
					if rows[ry][rx] == "1":
						for sy in range(scale):
							for sx in range(scale):
								var px := x + rx * scale + sx
								var py := y0 + ry * scale + sy
								if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
									img.set_pixel(px, py, col)
		x += 4 * scale

static func digits_width(text: String, scale: int) -> int:
	return text.length() * 4 * scale - scale

## Atlas for a polyhedral die: n faces in a grid of cells, each with its number.
## A small bar under 6 and 9 tells them apart.
static func die_atlas(faces: int, body: Color, ink: Color, key: String = "") -> ImageTexture:
	return cached("die%d%s%s%s" % [faces, body.to_html(), ink.to_html(), key], func():
		var cols := 5
		var rows := int(ceil(faces / float(cols)))
		var cell := 32
		var img := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
		img.fill(body)
		for i in range(faces):
			var cx := (i % cols) * cell
			var cy := (i / cols) * cell
			for y in range(cell):
				for x in range(cell):
					var c := _shade(body, 0.92 + _h(x + cx, y + cy, 11) * 0.12)
					img.set_pixel(cx + x, cy + y, c)
			var t := str(i + 1)
			var sc := 3
			var w := digits_width(t, sc)
			var ox := cx + (cell - w) / 2
			var oy := cy + 10
			draw_digits(img, t, ox, oy, sc, ink)
			if t == "6" or t == "9":
				for x in range(w):
					img.set_pixel(ox + x, oy + 17, ink)
		return img)

## A d6 atlas with pips instead of numbers. Face 1 is one big pip, like a pupil.
static func pip_atlas(body: Color, ink: Color, eye: Color) -> ImageTexture:
	return cached("pips%s%s%s" % [body.to_html(), ink.to_html(), eye.to_html()], func():
		var cols := 5
		var cell := 32
		var img := Image.create(cols * cell, 2 * cell, false, Image.FORMAT_RGBA8)
		img.fill(body)
		var spots := {1: [[0.5, 0.5]], 2: [[0.28, 0.28], [0.72, 0.72]], 3: [[0.26, 0.26], [0.5, 0.5], [0.74, 0.74]],
			4: [[0.28, 0.28], [0.72, 0.28], [0.28, 0.72], [0.72, 0.72]],
			5: [[0.27, 0.27], [0.73, 0.27], [0.5, 0.5], [0.27, 0.73], [0.73, 0.73]],
			6: [[0.28, 0.24], [0.72, 0.24], [0.28, 0.5], [0.72, 0.5], [0.28, 0.76], [0.72, 0.76]]}
		for i in range(6):
			var cx := (i % cols) * cell
			var cy := (i / cols) * cell
			for y in range(cell):
				for x in range(cell):
					img.set_pixel(cx + x, cy + y, _shade(body, 0.9 + _h(x + cx, y + cy, 13) * 0.14))
			var r := 7.5 if i == 0 else 3.2
			for sp in spots[i + 1]:
				var px: float = cx + sp[0] * cell
				var py: float = cy + sp[1] * cell
				for y in range(int(py - r - 1), int(py + r + 2)):
					for x in range(int(px - r - 1), int(px + r + 2)):
						var d := Vector2(x + 0.5 - px, y + 0.5 - py).length()
						if d <= r:
							var c := ink
							if i == 0:
								# the pupil: an iris ring, a dark centre, one hard highlight
								c = eye if d > r * 0.45 else Color("140808")
								if Vector2(x + 0.5 - (px - 2.5), y + 0.5 - (py - 2.5)).length() < 1.3:
									c = Color("f8f0e0")
							img.set_pixel(x, y, c)
		return img)

## Board tile texture by kind, styled by the setting palette.
static func tile_tex(kind: String, pal: Dictionary, s: int) -> ImageTexture:
	var floor_c := Color(pal.get("floor", "#4a4a42"))
	var floor2 := Color(pal.get("floor2", "#3a3e38"))
	match kind:
		"water", "flood":
			return grime(Color("1a3038"), Color("2a5058") if kind == "water" else Color("1a4048"), 32, s, 0.2)
		"mud":
			return grime(Color("3a2e1e"), Color("5a4a2e"), 32, s, 0.2)
		"fire":
			return grime(Color("8a2a0a"), Color("e8a030"), 32, s, 0.25)
		"bile":
			return grime(Color("4a5a1a"), Color("8a9a2a"), 32, s, 0.25)
		"shock":
			return grime(Color("2a2a3a"), Color("6a8ab8"), 32, s, 0.4)
		"steam":
			return grime(Color("4a4440"), Color("8a8480"), 32, s, 0.3)
		"ice":
			return grime(Color("8aa8b8"), Color("c8e0e8"), 32, s, 0.2)
		"flesh":
			return grime(Color("6a2a2a"), Color("a85a50"), 32, s, 0.15, 0.3)
		"blood":
			return grime(Color("3a0a08"), Color("6a1410"), 32, s, 0.2)
		"spikes", "gears":
			return flagstone(_shade(floor_c, 0.7), s, 32, 0.0)
		"sanctum":
			return flagstone(Color("8a7a4a"), s, 32, 0.0)
		"exit":
			return flagstone(Color("3a5a3a"), s, 32, 0.0)
		"unpainted":
			return grime(Color("8a8478"), Color("a8a294"), 32, s, 0.3)
		"trap", "enemy_trap":
			return flagstone(floor_c, s, 32, 0.6)
	return flagstone(floor_c if s % 2 == 0 else floor2, s, 32, 0.6)
