class_name Sketch
extends RefCounted
## Freehand lines for anything drawn at runtime (card frames, rings, ticks, map routes): the
## Caller's pen, not a ruler. Deterministic per seed so a card doesn't shimmer when redrawn.

const INK := Color("6e0c08")       # blood-red ink
const INK_DRY := Color("420806")   # where it pooled and dried
const INK_WASH := Color("9a3a2a")  # watered down
const BONE := Color("e6dcc6")      # bone-white ink, for the dark cards

static func _n(seed: int, t: float) -> float:
	return sin(t * 1.7 + seed * 0.37) * 0.6 + sin(t * 4.1 + seed * 1.13) * 0.3 + sin(t * 9.3 + seed * 2.9) * 0.1

## A wobbly polyline from a to b.
static func points(a: Vector2, b: Vector2, amp: float, seed: int, overshoot := 0.0) -> PackedVector2Array:
	var d := b - a
	var L := d.length()
	if L < 0.01:
		return PackedVector2Array([a, b])
	var u := d / L
	var nrm := Vector2(-u.y, u.x)
	a -= u * overshoot
	b += u * overshoot
	var n := maxi(3, int(L / 8.0))
	var pts := PackedVector2Array()
	for i in range(n + 1):
		var t := float(i) / n
		var p := a.lerp(b, t) + nrm * _n(seed, t * L * 0.05) * amp * sin(PI * clampf(t * 1.2, 0.0, 1.0) + 0.3)
		pts.append(p)
	return pts

static func line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w := 1.5, seed := 0, amp := 1.2) -> void:
	ci.draw_polyline(points(a, b, amp, seed, w * 0.8), col, w, true)

## A rectangle drawn as four strokes that overshoot at the corners, twice over.
static func rect(ci: CanvasItem, r: Rect2, col: Color, w := 1.5, seed := 0, twice := true) -> void:
	var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for k in range(2 if twice else 1):
		var cc := col if k == 0 else Color(col, col.a * 0.55)
		for i in range(4):
			ci.draw_polyline(points(c[i], c[(i + 1) % 4], 1.2 + k, seed + i * 7 + k * 31, 2.5 + k), cc, w if k == 0 else w * 0.6, true)

## A ring gone round once and a bit, the end not quite meeting the start.
static func ring(ci: CanvasItem, centre: Vector2, radius: float, col: Color, w := 2.0, seed := 0) -> void:
	var pts := PackedVector2Array()
	var n := 40
	var start := float(seed % 7)
	for i in range(n + 6):
		var t := start + TAU * i / n
		var rr := radius * (1.0 + 0.05 * _n(seed, t * 3.0))
		pts.append(centre + Vector2(cos(t), sin(t)) * rr)
	ci.draw_polyline(pts, col, w, true)

## A cross scratched over something.
static func cross(ci: CanvasItem, centre: Vector2, r: float, col: Color, w := 2.5, seed := 0) -> void:
	line(ci, centre + Vector2(-r, -r), centre + Vector2(r, r), col, w, seed)
	line(ci, centre + Vector2(r, -r), centre + Vector2(-r, r), col, w, seed + 5)

## A few drops flicked off the nib.
static func splatter(ci: CanvasItem, centre: Vector2, radius: float, col: Color, n: int, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in range(n):
		var a := rng.randf() * TAU
		var d := radius * sqrt(rng.randf())
		ci.draw_circle(centre + Vector2(cos(a), sin(a)) * d, rng.randf_range(0.6, 2.0), col)
