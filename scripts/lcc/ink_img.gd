class_name InkImg
extends RefCounted
## The Caller's pen on an Image (for things drawn into textures at runtime, like the map):
## soft-edged, wobbling, slightly uneven lines, dashes, crosses, rings, and his drawings
## pasted in.

static func _n(seed: int, t: float) -> float:
	return sin(t * 1.7 + seed * 0.37) * 0.6 + sin(t * 4.1 + seed * 1.13) * 0.3 + sin(t * 9.3 + seed * 2.9) * 0.1

## Stamp a soft round nib.
static func dot(img: Image, p: Vector2, r: float, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var x0 := maxi(0, int(floor(p.x - r - 1)))
	var x1 := mini(w - 1, int(ceil(p.x + r + 1)))
	var y0 := maxi(0, int(floor(p.y - r - 1)))
	var y1 := mini(h - 1, int(ceil(p.y + r + 1)))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(p)
			var a := clampf(r - d + 0.5, 0.0, 1.0) * col.a
			if a <= 0.0:
				continue
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(lerpf(c.r, col.r, a), lerpf(c.g, col.g, a), lerpf(c.b, col.b, a), maxf(c.a, a)))

## A freehand line from a to b. dash > 0 makes it a dashed route (dash length in pixels).
static func line(img: Image, a: Vector2, b: Vector2, r: float, col: Color, seed := 0, amp := 1.5, dash := 0.0) -> void:
	var d := b - a
	var L := d.length()
	if L < 0.5:
		return
	var u := d / L
	var nrm := Vector2(-u.y, u.x)
	var step := maxf(0.6, r * 0.6)
	var n := int(L / step)
	for i in range(n + 1):
		var s := i * step
		if dash > 0.0 and int(s / dash) % 2 == 1:
			continue
		var t := s / L
		var press := 0.75 + 0.25 * sin(PI * t)
		var p := a + u * s + nrm * _n(seed, s * 0.05) * amp * sin(PI * clampf(t, 0.0, 1.0))
		dot(img, p, r * press, col)

static func cross(img: Image, c: Vector2, r: float, w: float, col: Color, seed := 0) -> void:
	line(img, c + Vector2(-r, -r), c + Vector2(r, r), w, col, seed)
	line(img, c + Vector2(r, -r), c + Vector2(-r, r), w, col, seed + 3)

static func ring(img: Image, c: Vector2, radius: float, w: float, col: Color, seed := 0) -> void:
	var n := maxi(24, int(radius * 1.5))
	var start := float(seed % 7)
	var prev := c + Vector2(cos(start), sin(start)) * radius
	for i in range(1, n + 5):
		var t := start + TAU * i / n
		var p := c + Vector2(cos(t), sin(t)) * radius * (1.0 + 0.05 * _n(seed, t * 3.0))
		line(img, prev, p, w, col, seed + i, 0.0)
		prev = p

## Paste one of his drawings, centred.
static func stamp(img: Image, icon: Image, c: Vector2, alpha := 1.0) -> void:
	var src := icon
	if alpha < 0.99:
		src = icon.duplicate()
		for y in range(src.get_height()):
			for x in range(src.get_width()):
				var p := src.get_pixel(x, y)
				p.a *= alpha
				src.set_pixel(x, y, p)
	img.blend_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(int(c.x) - src.get_width() / 2, int(c.y) - src.get_height() / 2))
