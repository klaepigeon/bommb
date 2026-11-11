class_name MeshKit
## Procedural geometry for things nobody would model by hand in this project: lumpy, sagging
## flesh (blob), limbs and strands (tube), branching coral (coral), teeth (box). Everything is
## written into a SurfaceTool as plain triangles, in whatever space the caller passes via `xf`.

static var _noise: FastNoiseLite

static func noise() -> FastNoiseLite:
	if not _noise:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 1.0
		_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		_noise.fractal_octaves = 3
	return _noise

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_uv(ua); st.add_vertex(a)
	st.set_uv(ub); st.add_vertex(b)
	st.set_uv(uc); st.add_vertex(c)

static func _grid(st: SurfaceTool, g: Array, uv: Array) -> void:
	for i in g.size() - 1:
		for j in g[i].size() - 1:
			var a: Vector3 = g[i][j]; var b: Vector3 = g[i][j + 1]; var c: Vector3 = g[i + 1][j + 1]; var d: Vector3 = g[i + 1][j]
			_tri(st, a, c, b, uv[i][j], uv[i + 1][j + 1], uv[i][j + 1])
			_tri(st, a, d, c, uv[i][j], uv[i + 1][j], uv[i + 1][j + 1])

## A lumpy ellipsoid. `sag` melts it: the lower half slumps down and spreads, as flesh does when
## it stops holding itself up. `slide` drags the front of it down (a face sliding off a skull).
static func blob(st: SurfaceTool, c: Vector3, r: Vector3, opts := {}) -> void:
	var rings: int = opts.get("rings", 10); var segs: int = opts.get("segs", 14)
	var bumps: float = opts.get("bumps", 0.12); var freq: float = opts.get("freq", 6.0)
	var sag: float = opts.get("sag", 0.0); var slide: float = opts.get("slide", 0.0)
	var seed: float = opts.get("seed", 0.0); var xf: Transform3D = opts.get("xf", Transform3D.IDENTITY)
	var uvs: float = opts.get("uv", 1.0)
	var g := []; var uv := []
	var n := noise()
	for i in rings + 1:
		var row := []; var urow := []
		var phi := PI * float(i) / rings
		for j in segs + 1:
			var th := TAU * float(j) / segs
			var dir := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			var p := dir * r
			var k := n.get_noise_3d(dir.x * freq + seed * 13.1, dir.y * freq + seed * 3.7, dir.z * freq)
			p += dir * (r.x + r.y + r.z) / 3.0 * bumps * k
			if sag > 0.0 and dir.y < 0.35:
				var s := (0.35 - dir.y) / 1.35
				p.y -= sag * s * s * r.y
				p.x *= 1.0 + sag * s * 0.45; p.z *= 1.0 + sag * s * 0.45
			if slide > 0.0 and dir.z < 0.0:
				var f := -dir.z
				p.y -= slide * f * f * r.y * (0.6 + 0.4 * (1.0 - dir.y))
				p.z -= slide * f * 0.12 * r.z
			row.append(xf * (c + p)); urow.append(Vector2(float(j) / segs, float(i) / rings) * uvs)
		g.append(row); uv.append(urow)
	_grid(st, g, uv)

## A tube along `pts` with radius per point (tapers, bulges, strands of goo that thin in the
## middle). Parallel-transported frames, so it doesn't twist. Ends are closed to a point.
static func tube(st: SurfaceTool, pts: Array, radii: Array, opts := {}) -> void:
	var sides: int = opts.get("sides", 6); var bumps: float = opts.get("bumps", 0.0)
	var seed: float = opts.get("seed", 0.0); var xf: Transform3D = opts.get("xf", Transform3D.IDENTITY)
	var cap: bool = opts.get("cap", true)
	var n := noise()
	var t0: Vector3 = (pts[1] - pts[0]).normalized()
	var nrm := t0.cross(Vector3.UP if absf(t0.y) < 0.9 else Vector3.RIGHT).normalized()
	var g := []; var uv := []; var along := 0.0
	for i in pts.size():
		var t: Vector3
		if i == 0: t = (pts[1] - pts[0]).normalized()
		elif i == pts.size() - 1: t = (pts[i] - pts[i - 1]).normalized()
		else: t = (pts[i + 1] - pts[i - 1]).normalized()
		nrm = (nrm - t * nrm.dot(t)).normalized()
		var bin := t.cross(nrm)
		if i > 0: along += (pts[i] - pts[i - 1]).length()
		var row := []; var urow := []
		for j in sides + 1:
			var a := TAU * float(j) / sides
			var d := nrm * cos(a) + bin * sin(a)
			var rr: float = radii[i] * (1.0 + bumps * n.get_noise_3d(pts[i].x * 40.0 + seed, pts[i].y * 40.0 + a, pts[i].z * 40.0))
			row.append(xf * (pts[i] + d * rr)); urow.append(Vector2(float(j) / sides, along * 4.0))
		g.append(row); uv.append(urow)
	_grid(st, g, uv)
	if cap:
		for end in [0, pts.size() - 1]:
			var tip: Vector3 = xf * pts[end]
			var row: Array = g[end]
			for j in sides:
				if end == 0: _tri(st, tip, row[j], row[j + 1], Vector2(0.5, 0), Vector2(0, 0), Vector2(1, 0))
				else: _tri(st, tip, row[j + 1], row[j], Vector2(0.5, 1), Vector2(1, 1), Vector2(0, 1))

## A box (teeth, chair parts) with its own basis.
static func box(st: SurfaceTool, c: Vector3, size: Vector3, basis := Basis.IDENTITY, xf := Transform3D.IDENTITY) -> void:
	var h := size * 0.5
	var corners := []
	for k in 8:
		corners.append(xf * (c + basis * Vector3(h.x * (1 if k & 1 else -1), h.y * (1 if k & 2 else -1), h.z * (1 if k & 4 else -1))))
	var faces := [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
	for f in faces:
		var a: Vector3 = corners[f[0]]; var b: Vector3 = corners[f[1]]; var cc: Vector3 = corners[f[2]]; var d: Vector3 = corners[f[3]]
		_tri(st, a, b, cc, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1))
		_tri(st, a, cc, d, Vector2(0, 0), Vector2(1, 1), Vector2(0, 1))

## Branching coral grown from `start` along `dir`: short, thick, blunt arms that fork and end
## in knobbed polyp heads (staghorn more than twig). Deterministic for a given rng.
static func coral(st: SurfaceTool, start: Vector3, dir: Vector3, length: float, radius: float, rng: RandomNumberGenerator, depth := 2, xf := Transform3D.IDENTITY) -> void:
	var pts := [start]; var radii := [radius * 1.25]
	var p := start; var d := dir.normalized()
	var segs := 3
	for i in segs:
		d = (d + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.1, 0.3), rng.randf_range(-0.3, 0.3))).normalized()
		p += d * length / segs
		pts.append(p); radii.append(radius * (1.0 - 0.3 * float(i + 1) / segs))
	tube(st, pts, radii, {"sides": 6, "bumps": 0.45, "seed": rng.randf() * 100.0, "xf": xf, "cap": false})
	blob(st, p, Vector3.ONE * radii[-1] * 1.25, {"rings": 5, "segs": 7, "bumps": 0.45, "freq": 11.0, "seed": rng.randf() * 50.0, "xf": xf})
	# polyps: little knobs all along it
	for k in rng.randi_range(2, 4):
		var at: int = rng.randi_range(1, segs)
		var off: Vector3 = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * float(radii[at])
		blob(st, pts[at] + off, Vector3.ONE * radii[at] * 0.45, {"rings": 3, "segs": 5, "bumps": 0.2, "xf": xf})
	if depth > 0:
		for k in rng.randi_range(1, 2):
			var at: int = rng.randi_range(1, segs - 1)
			var nd := (d + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.1, 0.7), rng.randf_range(-1, 1)) * 0.8).normalized()
			coral(st, pts[at], nd, length * rng.randf_range(0.55, 0.8), radii[at] * 0.75, rng, depth - 1, xf)

## Knobbly lump of brain-coral-like growth sitting on a surface.
static func lump(st: SurfaceTool, c: Vector3, r: float, rng: RandomNumberGenerator, xf := Transform3D.IDENTITY) -> void:
	blob(st, c, Vector3(r, r * 0.65, r), {"rings": 7, "segs": 10, "bumps": 0.6, "freq": 16.0, "seed": rng.randf() * 80.0, "xf": xf})
