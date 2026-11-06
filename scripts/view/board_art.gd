class_name BoardArt
extends RefCounted
## The board, drawn. LAST CALL 3's board is a picture of a place, the way a children's
## board game is (a winding path of coloured squares through a sweet little land), except
## the land is made of meat: hills of ham, a river of gravy, sausage trees, bone fences.
## Beside the path, numbered in order, eight little drawings tell a story, and the story is
## always a bad one (assets/data/board_stories.json, one per match).
##
## Everything is drawn into one Image in crayon and ink (no imported art). Coordinates in
## and out are board units, (x, z) on the sheet; the image maps the sheet's top face.

const W := 1024
const H := 704

var size := Vector2(21.0, 14.4)
var img: Image
var rng := RandomNumberGenerator.new()
var path: Array[Vector2] = []

const INK := Color("2a0e0a")
const PAPER := Color("d8c8a0")


func _init(sheet_size: Vector2, seed_v: int) -> void:
	size = sheet_size
	rng.seed = seed_v
	img = Image.create(W, H, false, Image.FORMAT_RGBA8)


func px(p: Vector2) -> Vector2:
	return Vector2((p.x + size.x / 2) / size.x * W, (p.y + size.y / 2) / size.y * H)


func unit() -> float:
	return W / size.x


# --- primitives --------------------------------------------------------------------

func rect(x: float, y: float, w: float, h: float, c: Color) -> void:
	var r := Rect2i(int(x), int(y), maxi(1, int(w)), maxi(1, int(h))).intersection(Rect2i(0, 0, W, H))
	if r.size.x > 0 and r.size.y > 0:
		img.fill_rect(r, c)


func ellipse(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for yy in range(int(-ry), int(ry) + 1):
		var k := 1.0 - float(yy * yy) / maxf(ry * ry, 1.0)
		if k < 0.0:
			continue
		var hw := rx * sqrt(k)
		rect(cx - hw, cy + yy, hw * 2.0 + 1.0, 1, c)


func disc(cx: float, cy: float, r: float, c: Color) -> void:
	ellipse(cx, cy, r, r, c)


func line(a: Vector2, b: Vector2, thick: float, c: Color) -> void:
	var n := maxi(1, int(a.distance_to(b) / maxf(thick * 0.5, 0.5)))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		disc(p.x, p.y, thick * 0.5, c)


func poly(pts: Array, c: Color) -> void:
	var y0 := INF
	var y1 := -INF
	for p in pts:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	for y in range(int(y0), int(y1) + 1):
		var xs := []
		for i in pts.size():
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % pts.size()]
			if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
				xs.append(a.x + (y - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		for i in range(0, xs.size() - 1, 2):
			rect(xs[i], y, xs[i + 1] - xs[i] + 1, 1, c)


func outline(pts: Array, thick: float, c: Color) -> void:
	for i in pts.size():
		line(pts[i], pts[(i + 1) % pts.size()], thick, c)


## Crayon: lots of short strokes, roughly one colour, over an area.
func crayon(cx: float, cy: float, rx: float, ry: float, c: Color, n: int = 60) -> void:
	for i in n:
		var a := Vector2(cx + rng.randf_range(-rx, rx), cy + rng.randf_range(-ry, ry))
		if pow((a.x - cx) / rx, 2) + pow((a.y - cy) / ry, 2) > 1.0:
			continue
		var b := a + Vector2(rng.randf_range(4, 12), rng.randf_range(-3, 3))
		line(a, b, 2.0, c.lerp(c.darkened(0.3), rng.randf()))


# --- the land -------------------------------------------------------------------------

var _keep_clear: Array[Vector2] = []


func paint(story: Dictionary, path_pts: Array[Vector2], beat_spaces: Array) -> Array:
	path = path_pts
	var beats: Array = story.get("beats", [])
	var spots: Array[Vector2] = []
	for k in mini(beats.size(), beat_spaces.size()):
		spots.append(_beside(int(beat_spaces[k]), 2.4))
	_keep_clear = spots
	# paper, gone yellow; then the land in big soft crayon areas
	img.fill(PAPER)
	for i in 900:
		var p := Vector2(rng.randf() * W, rng.randf() * H)
		line(p, p + Vector2(rng.randf_range(8, 30), rng.randf_range(-4, 4)), 1.0, PAPER.darkened(rng.randf_range(0.02, 0.08)))
	_meadow()
	_river()
	for i in 9:
		_ham_hill(_free_spot(2.2))
	for i in 10:
		_sausage_tree(_free_spot(1.2))
	for i in 6:
		_bone_fence(_free_spot(1.4))
	for i in 8:
		_gumdrop(_free_spot(0.9))
	_path_band()
	# the story, drawn beside the path in order; returns where each caption goes
	var captions := []
	for k in spots.size():
		var at := spots[k]
		# a pale vignette behind each picture so it reads as one
		ellipse(px(at).x, px(at).y + unit() * 0.1, unit() * 1.7, unit() * 1.35, Color("efe2c0"))
		_drawing(str(beats[k][0]), px(at) + Vector2(0, -unit() * 0.15), unit() * 1.45)
		_number(px(at) + Vector2(-unit() * 1.5, -unit() * 1.0), k + 1)
		# the caption under the picture, or over it if the road's in the way
		var cap := at + Vector2(0, 1.3)
		for q in path:
			if cap.distance_to(q) < 1.1:
				cap = at + Vector2(0, -1.75)
				break
		captions.append({"at": cap, "text": "%d. %s" % [k + 1, str(beats[k][1])]})
	_frame()
	return captions


func texture() -> ImageTexture:
	return ImageTexture.create_from_image(img)


func _meadow() -> void:
	# patches of sickly sweet colour: pink, mint, lemon
	var cols := [Color("e8b0b8"), Color("b8d8b0"), Color("e8dca0"), Color("d8b8e0")]
	for i in 22:
		var c: Color = cols[i % cols.size()]
		var p := Vector2(rng.randf() * W, rng.randf() * H)
		crayon(p.x, p.y, rng.randf_range(60, 160), rng.randf_range(40, 110), c, 220)


func _river() -> void:
	# a river of gravy, from the top edge to the bottom, wandering
	var pts := []
	var x := W * rng.randf_range(0.25, 0.75)
	for i in 12:
		x += rng.randf_range(-70, 70)
		x = clampf(x, W * 0.1, W * 0.9)
		pts.append(Vector2(x, i * H / 11.0))
	for i in pts.size() - 1:
		line(pts[i], pts[i + 1], 34, Color("6a2a18"))
	for i in pts.size() - 1:
		line(pts[i], pts[i + 1], 22, Color("8a3a20"))
		line(pts[i] + Vector2(4, 0), pts[i + 1] + Vector2(4, 0), 3, Color("a85a38"))
	for i in pts.size() - 1:
		line(pts[i] + Vector2(-17, 0), pts[i + 1] + Vector2(-17, 0), 2, INK)
		line(pts[i] + Vector2(17, 0), pts[i + 1] + Vector2(17, 0), 2, INK)


func _ham_hill(p: Vector2) -> void:
	var r := unit() * rng.randf_range(0.9, 1.5)
	ellipse(p.x, p.y, r, r * 0.6, Color("d8707a"))
	ellipse(p.x, p.y - r * 0.15, r * 0.82, r * 0.42, Color("e88a90"))
	# the fat cap and the bone through it
	ellipse(p.x, p.y - r * 0.4, r * 0.5, r * 0.15, Color("f0e0c8"))
	line(Vector2(p.x - r * 0.1, p.y - r * 0.4), Vector2(p.x + r * 0.1, p.y - r * 1.0), 7, Color("f0ead8"))
	disc(p.x + r * 0.1, p.y - r * 1.0, 6, Color("f0ead8"))
	line(Vector2(p.x - r, p.y), Vector2(p.x + r, p.y), 2, INK)


func _sausage_tree(p: Vector2) -> void:
	line(p, p + Vector2(0, -unit() * 0.8), 5, Color("5a3a20"))
	# a lollipop of sausage links, coiled
	var c := p + Vector2(0, -unit() * 1.05)
	for k in 14:
		var a := k * 0.9
		var r := 3.0 + k * 1.8
		disc(c.x + cos(a) * r, c.y + sin(a) * r, 6, Color("b04a3a") if k % 2 == 0 else Color("c86050"))
	disc(c.x, c.y, 4, Color("e0c8a0"))


func _bone_fence(p: Vector2) -> void:
	for k in 5:
		var x := p.x - 30 + k * 15
		line(Vector2(x, p.y), Vector2(x, p.y - 26), 4, Color("f0e8d4"))
		disc(x - 2, p.y - 27, 3, Color("f0e8d4"))
		disc(x + 2, p.y - 27, 3, Color("f0e8d4"))
	line(Vector2(p.x - 32, p.y - 12), Vector2(p.x + 32, p.y - 12), 3, Color("e0d8c0"))


func _gumdrop(p: Vector2) -> void:
	# a gumdrop. With an eye in it.
	var c: Color = [Color("e84a6a"), Color("4ab0e0"), Color("f0c030"), Color("60c060")][rng.randi_range(0, 3)]
	poly([p + Vector2(-14, 0), p + Vector2(-9, -16), p + Vector2(0, -20), p + Vector2(9, -16), p + Vector2(14, 0)], c)
	disc(p.x, p.y - 9, 5, Color("f8f4ec"))
	disc(p.x + 1, p.y - 9, 2, INK)


func _path_band() -> void:
	# the road under the squares: a wobbly cream ribbon, inked both sides
	for i in path.size():
		var a := px(path[i])
		var b := px(path[(i + 1) % path.size()])
		line(a, b, unit() * 1.35, INK)
	for i in path.size():
		var a := px(path[i])
		var b := px(path[(i + 1) % path.size()])
		line(a, b, unit() * 1.15, Color("f0e4c4"))


func _frame() -> void:
	for k in 3:
		var m := 6 + k * 5
		outline([Vector2(m, m), Vector2(W - m, m), Vector2(W - m, H - m), Vector2(m, H - m)], 2 if k else 4, INK if k != 1 else Color("8a1a12"))


func _number(p: Vector2, n: int) -> void:
	disc(p.x, p.y, 15, Color("8a1a12"))
	disc(p.x, p.y, 12, Color("f0e4c4"))
	LcTex.draw_digits(img, str(n), int(p.x - 5), int(p.y - 7), 3, Color("8a1a12"))


## A point beside space i, off the road, toward the middle of the board.
func _beside(i: int, dist: float) -> Vector2:
	var a := path[(i - 1 + path.size()) % path.size()]
	var b := path[(i + 1) % path.size()]
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	var p := path[i]
	if (p + n).length() > (p - n).length():
		n = -n
	var at := p + n * dist
	at.x = clampf(at.x, -size.x / 2 + 1.4, size.x / 2 - 1.4)
	at.y = clampf(at.y, -size.y / 2 + 1.3, size.y / 2 - 1.6)
	return at


func _free_spot(clear: float) -> Vector2:
	for tries in 40:
		var p := Vector2(rng.randf_range(-size.x / 2 + 1, size.x / 2 - 1), rng.randf_range(-size.y / 2 + 1, size.y / 2 - 1))
		var ok := true
		for q in path:
			if p.distance_to(q) < clear + 0.6:
				ok = false
				break
		for q in _keep_clear:
			if p.distance_to(q) < clear + 1.9:
				ok = false
				break
		if ok:
			return px(p)
	return Vector2(-100, -100)


# --- the story's drawings ---------------------------------------------------------------

func _drawing(kind: String, c: Vector2, s: float) -> void:
	var k := s / 50.0   # drawn as if 100 px across, then scaled
	var red := Color("8a1a12")
	var P := func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * k
	# a scribbled patch of shadow under every drawing
	ellipse(c.x, c.y + 40 * k, 46 * k, 9 * k, Color("b8a880"))
	match kind:
		"house":
			poly([P.call(-36, 40), P.call(-36, -6), P.call(36, -6), P.call(36, 40)], Color("e8d8b0"))
			poly([P.call(-44, -4), P.call(0, -40), P.call(44, -4)], Color("a83a2a"))
			rect(P.call(-8, 14).x, P.call(-8, 14).y, 16 * k, 26 * k, Color("5a3020"))
			rect(P.call(-28, 4).x, P.call(-28, 4).y, 14 * k, 12 * k, Color("f0d870"))
			rect(P.call(14, 4).x, P.call(14, 4).y, 14 * k, 12 * k, Color("20140c"))
			outline([P.call(-36, 40), P.call(-36, -6), P.call(36, -6), P.call(36, 40)], 2, INK)
			outline([P.call(-44, -4), P.call(0, -40), P.call(44, -4)], 2, INK)
			# something at the upstairs window
			disc(P.call(21, 9).x, P.call(21, 9).y, 2 * k, Color("f0f0f0"))
		"cake":
			poly([P.call(-34, 38), P.call(-34, 4), P.call(34, 4), P.call(34, 38)], Color("f0c8d0"))
			poly([P.call(-26, 4), P.call(-26, -18), P.call(26, -18), P.call(26, 4)], Color("f8e0e8"))
			for i in 7:
				line(P.call(-30 + i * 10, 4), P.call(-30 + i * 10, 14 + (i % 2) * 6), 3 * k, red)
			for i in 5:
				var x := -20 + i * 10
				line(P.call(x, -18), P.call(x, -30), 3 * k, Color("e0e0f0"))
				disc(P.call(x, -33).x, P.call(x, -33).y, 2.5 * k, Color("f0b030"))
			# a hand, coming out of the side of it
			line(P.call(34, 26), P.call(46, 22), 5 * k, Color("e0b0a0"))
			for f in 3:
				line(P.call(46, 22), P.call(52, 17 + f * 4), 2 * k, Color("e0b0a0"))
			outline([P.call(-34, 38), P.call(-34, 4), P.call(34, 4), P.call(34, 38)], 2, INK)
		"woods":
			for t in 5:
				var x := -38 + t * 19
				line(P.call(x, 40), P.call(x, 10), 4 * k, Color("4a2a18"))
				poly([P.call(x - 13, 16), P.call(x, -34 + (t % 2) * 10), P.call(x + 13, 16)], Color("2a4a2a").lerp(Color("3a5a30"), t * 0.2))
			# eyes between the trees
			for e in 3:
				var q: Vector2 = P.call(-28 + e * 22, 26)
				disc(q.x - 3, q.y, 1.6 * k, Color("f8f0a0"))
				disc(q.x + 3, q.y, 1.6 * k, Color("f8f0a0"))
		"lake":
			ellipse(c.x, c.y + 14 * k, 44 * k, 20 * k, Color("4a6a7a"))
			ellipse(c.x, c.y + 12 * k, 36 * k, 14 * k, Color("6a8a98"))
			# a hand above the water. Not waving.
			line(P.call(6, 12), P.call(6, -14), 5 * k, Color("d8b0a0"))
			for f in 4:
				line(P.call(6, -14), P.call(1 + f * 3, -24), 2 * k, Color("d8b0a0"))
			for r in 3:
				ellipse(P.call(6, 12).x, P.call(6, 12).y, (8 + r * 7) * k, (3 + r * 2) * k, Color("8aa8b8"))
				ellipse(P.call(6, 12).x, P.call(6, 12).y, (7 + r * 7) * k, (2 + r * 2) * k, Color("6a8a98"))
		"table":
			rect(P.call(-40, 6).x, P.call(-40, 6).y, 80 * k, 8 * k, Color("6a3a20"))
			line(P.call(-34, 14), P.call(-34, 38), 4 * k, Color("4a2a18"))
			line(P.call(34, 14), P.call(34, 38), 4 * k, Color("4a2a18"))
			for i in 4:
				var x := -27 + i * 18
				ellipse(P.call(x, 4).x, P.call(x, 4).y, 7 * k, 2.5 * k, Color("f0f0f0"))
				# chairs; one empty, the rest with little round heads looking at it
				if i != 2:
					disc(P.call(x, -14).x, P.call(x, -14).y, 6 * k, Color("e0b8a0"))
					disc(P.call(x - 2, -15).x, P.call(x - 2, -15).y, 1.2 * k, INK)
					disc(P.call(x + 2, -15).x, P.call(x + 2, -15).y, 1.2 * k, INK)
					line(P.call(x, -8), P.call(x, 2), 6 * k, Color("8a3a3a"))
			ellipse(P.call(-9, 2).x, P.call(-9, 2).y, 9 * k, 5 * k, Color("a8402a"))
		"grave":
			poly([P.call(-18, 40), P.call(-18, -18), P.call(-10, -28), P.call(10, -28), P.call(18, -18), P.call(18, 40)], Color("a8a8a0"))
			outline([P.call(-18, 40), P.call(-18, -18), P.call(-10, -28), P.call(10, -28), P.call(18, -18), P.call(18, 40)], 2, INK)
			line(P.call(-8, -6), P.call(8, -6), 2 * k, INK)
			line(P.call(-8, 2), P.call(6, 2), 2 * k, INK)
			# a party hat on it, and a balloon tied to it
			poly([P.call(-6, -28), P.call(0, -44), P.call(6, -28)], Color("e84a6a"))
			line(P.call(14, -10), P.call(28, -40), 1.5 * k, INK)
			disc(P.call(29, -46).x, P.call(29, -46).y, 8 * k, Color("4ab0e0"))
		"door":
			rect(P.call(-22, -36).x, P.call(-22, -36).y, 44 * k, 76 * k, Color("2a1a10"))
			rect(P.call(-18, -32).x, P.call(-18, -32).y, 36 * k, 72 * k, Color("6a3a20"))
			disc(P.call(10, 6).x, P.call(10, 6).y, 3 * k, Color("e0c050"))
			for d in 3:
				disc(P.call(-8 + d * 8, -12).x, P.call(-8 + d * 8, -12).y, 3 * k, Color("c8a040"))
			# light under it
			rect(P.call(-18, 38).x, P.call(-18, 38).y, 36 * k, 3 * k, Color("fff4c0"))
		"car":
			poly([P.call(-40, 26), P.call(-40, 8), P.call(-22, 8), P.call(-12, -8), P.call(20, -8), P.call(30, 8), P.call(40, 8), P.call(40, 26)], Color("3a6aa8"))
			outline([P.call(-40, 26), P.call(-40, 8), P.call(-22, 8), P.call(-12, -8), P.call(20, -8), P.call(30, 8), P.call(40, 8), P.call(40, 26)], 2, INK)
			disc(P.call(-24, 28).x, P.call(-24, 28).y, 9 * k, INK)
			disc(P.call(24, 28).x, P.call(24, 28).y, 9 * k, INK)
			# faces at the windows; the back one is a different colour
			for w in 2:
				var q: Vector2 = P.call(-6 + w * 16, 2)
				disc(q.x, q.y, 5 * k, Color("e0b8a0") if w == 0 else Color("a8b8a0"))
			# something dragging behind on a rope
			line(P.call(40, 18), P.call(56, 30), 1.5 * k, INK)
			ellipse(P.call(58, 32).x, P.call(58, 32).y, 6 * k, 3 * k, Color("8a2a2a"))
		"tent":
			poly([P.call(-42, 40), P.call(0, -36), P.call(42, 40)], Color("e84a4a"))
			for st in 4:
				poly([P.call(-42 + st * 21, 40), P.call(-1 + st * 0.5, -36), P.call(-32 + st * 21, 40)], Color("f0e8d8"))
			poly([P.call(-8, 40), P.call(0, 18), P.call(8, 40)], Color("140a08"))
			line(P.call(0, -36), P.call(0, -46), 2 * k, INK)
			poly([P.call(0, -46), P.call(12, -42), P.call(0, -38)], Color("f0c030"))
		"well":
			ellipse(c.x, c.y + 20 * k, 26 * k, 8 * k, Color("8a8a80"))
			rect(P.call(-26, 4).x, P.call(-26, 4).y, 52 * k, 16 * k, Color("9a9a90"))
			ellipse(c.x, c.y + 4 * k, 26 * k, 8 * k, Color("101010"))
			line(P.call(-24, 4), P.call(-24, -30), 3 * k, Color("5a3a20"))
			line(P.call(24, 4), P.call(24, -30), 3 * k, Color("5a3a20"))
			poly([P.call(-32, -28), P.call(0, -44), P.call(32, -28)], Color("7a3a24"))
			# two hands on the rim, from inside
			for h in 2:
				var q: Vector2 = P.call(-12 + h * 20, -1)
				for f in 4:
					line(q + Vector2(f * 2.5 * k, 0), q + Vector2(f * 2.5 * k, 5 * k), 1.6 * k, Color("d8b8a8"))
		"church":
			poly([P.call(-30, 40), P.call(-30, 0), P.call(30, 0), P.call(30, 40)], Color("c8c0b0"))
			poly([P.call(-36, 2), P.call(0, -16), P.call(36, 2)], Color("5a5a60"))
			rect(P.call(-8, -46).x, P.call(-8, -46).y, 16 * k, 30 * k, Color("c8c0b0"))
			poly([P.call(-10, -44), P.call(0, -60), P.call(10, -44)], Color("5a5a60"))
			line(P.call(0, -60), P.call(0, -70), 2 * k, INK)
			line(P.call(-4, -66), P.call(4, -66), 2 * k, INK)
			rect(P.call(-6, 22).x, P.call(-6, 22).y, 12 * k, 18 * k, Color("2a1a10"))
			# the windows are boarded
			for x in [-20, 14]:
				rect(P.call(x, 10).x, P.call(x, 10).y, 8 * k, 12 * k, Color("2a1a10"))
				line(P.call(x - 1, 12), P.call(x + 9, 20), 2 * k, Color("8a6a40"))
		"factory":
			poly([P.call(-40, 40), P.call(-40, 0), P.call(-20, -12), P.call(-20, 0), P.call(0, -12), P.call(0, 0), P.call(20, -12), P.call(20, 0), P.call(40, 0), P.call(40, 40)], Color("8a5a4a"))
			rect(P.call(26, -40).x, P.call(26, -40).y, 9 * k, 40 * k, Color("6a4a3a"))
			for sm in 4:
				disc(P.call(32 + sm * 5, -46 - sm * 8).x, P.call(32 + sm * 5, -46 - sm * 8).y, (5 + sm * 2) * k, Color("c89090"))
			# the sign
			rect(P.call(-30, 12).x, P.call(-30, 12).y, 42 * k, 10 * k, Color("f0e0c0"))
			for i in 5:
				line(P.call(-27 + i * 8, 15), P.call(-23 + i * 8, 19), 2 * k, red)
		"clown":
			disc(c.x, c.y, 30 * k, Color("f0ece0"))
			disc(P.call(0, 4).x, P.call(0, 4).y, 7 * k, Color("e02a2a"))
			for sx in [-1, 1]:
				disc(P.call(sx * 12, -8).x, P.call(sx * 12, -8).y, 6 * k, Color("2a6ae0"))
				disc(P.call(sx * 12, -8).x, P.call(sx * 12, -8).y, 2.5 * k, INK)
				disc(P.call(sx * 30, -8).x, P.call(sx * 30, -8).y, 12 * k, Color("e86a2a"))
			# the smile goes all the way round
			for i in 16:
				var a := PI * 0.1 + PI * 0.8 * i / 15.0
				disc(c.x + cos(a) * 20 * k, c.y + 4 * k + sin(a) * 16 * k, 3 * k, Color("c01818"))
			poly([P.call(-16, -26), P.call(0, -52), P.call(16, -26)], Color("6a2ae0"))
		"bed":
			rect(P.call(-40, 10).x, P.call(-40, 10).y, 80 * k, 14 * k, Color("f0e8e8"))
			rect(P.call(-40, 0).x, P.call(-40, 0).y, 80 * k, 12 * k, Color("e86a8a"))
			rect(P.call(-44, -14).x, P.call(-44, -14).y, 6 * k, 52 * k, Color("6a3a20"))
			rect(P.call(38, 0).x, P.call(38, 0).y, 6 * k, 38 * k, Color("6a3a20"))
			ellipse(P.call(-28, -2).x, P.call(-28, -2).y, 9 * k, 5 * k, Color("ffffff"))
			# the shape under the covers is the wrong shape
			ellipse(P.call(4, -2).x, P.call(4, -2).y, 26 * k, 8 * k, Color("d85a7a"))
			ellipse(P.call(18, -6).x, P.call(18, -6).y, 8 * k, 9 * k, Color("d85a7a"))
