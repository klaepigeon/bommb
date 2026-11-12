class_name DoorLeaf
## Door leaves built as geometry instead of textured slabs. In the hinge's frame: the leaf runs
## x 0..w from the hinge, y 0..h, centred on z = 0.
##
## "padded": a Soviet flat's front door. Leatherette over wadding, quilted in diamonds, a brass
##   stud in every tuft, a piped border nailed down with more studs; a lever handle, two lock
##   cylinders, a peephole, and (outside) the flat's number on a brass plate.
## "panel": an interior door. Gloss paint gone yellow, stiles and rails standing proud of
##   recessed panels with a moulding round them; the top panel glazed if `glazed`; a lever on a
##   long plate, the keyhole under it, two hinges.
##
## Materials come from `conv`, a Callable taking a StandardMaterial3D (the exported flat's
## converter, so the doors flesh over with everything else in the flesh flat).

const T := 0.042        # leaf thickness

static func build(parent: Node3D, w: float, h: float, style: String, conv: Callable, opts := {}) -> Node3D:
	var root := Node3D.new(); root.name = "Leaf"; parent.add_child(root)
	opts["style"] = style
	var m := materials(conv, opts)
	var sts := {}
	for k in m: sts[k] = _st()
	if style == "padded": _padded(sts, w, h, opts)
	else: _panel(sts, w, h, opts)
	for k in sts:
		var st: SurfaceTool = sts[k]
		var mesh := st.commit()
		if mesh.get_surface_count() == 0: continue
		var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.name = k
		mi.material_override = m[k]
		if k == "glass": mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	if opts.has("number"):
		var s: float = opts.get("outside", 1.0)
		var lb := Label3D.new(); lb.text = str(opts.number); lb.font_size = 40; lb.pixel_size = 0.0016
		lb.modulate = Color("2a1e10"); lb.outline_size = 0; lb.shaded = true
		lb.position = Vector3(w * 0.5, 1.68, s * (T * 0.5 + 0.052)); lb.rotation.y = 0.0 if s > 0.0 else PI
		root.add_child(lb)
	return root

## The material set: body (vinyl or paint), trim (the leaf's edge, stiles), metal (the lever,
## hinges), brass (studs, plate), dark (keyholes, the peephole's lens), glass.
static func materials(conv: Callable, opts := {}) -> Dictionary:
	var body: StandardMaterial3D
	if opts.get("style", "") == "padded" or opts.has("vinyl"):
		body = _std(Tex.tex("vinyl"), opts.get("vinyl", Color("7a3a2c")), 0.45)
	else:
		body = _std(Tex.tex("paint_door"), opts.get("paint", Color("e8e0c8")), 0.35)
	return {
		"body": conv.call(body),
		"trim": conv.call(_std(Tex.tex("paint_door"), opts.get("trim", Color("d8cfb4")), 0.4)),
		"metal": conv.call(_std(Tex.tex("metal"), Color("b8bcc0"), 0.3)),
		"brass": conv.call(_std(Tex.tex("brass"), Color(1, 1, 1), 0.3)),
		"dark": conv.call(_std(Tex.tex("black"), Color(1, 1, 1), 0.6)),
		"glass": conv.call(_std(Tex.tex("glass_reeded"), Color(1, 1, 1), 0.15)),
	}

static func _std(t: Texture2D, c: Color, rough: float) -> StandardMaterial3D:
	var s := StandardMaterial3D.new(); s.albedo_texture = t; s.albedo_color = c; s.roughness = rough
	return s

static func _st() -> SurfaceTool:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); return st

## A quad facing +z (s = 1) or -z (s = -1): a, b, c, d go round anticlockwise seen from +z
## (bottom-left, bottom-right, top-right, top-left).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, s: float, uv := []) -> void:
	var u: Array = uv if uv.size() == 4 else [Vector2(a.x, -a.y), Vector2(b.x, -b.y), Vector2(c.x, -c.y), Vector2(d.x, -d.y)]
	var p := [a, b, c, d]
	var order := [0, 2, 1, 0, 3, 2] if s > 0.0 else [0, 1, 2, 0, 2, 3]
	var n := (b - a).cross(d - a).normalized() * s
	for i in order:
		st.set_normal(n); st.set_uv(u[i]); st.add_vertex(p[i])

## An axis-aligned box with metre UVs (good for anything painted).
static func _box(st: SurfaceTool, c: Vector3, size: Vector3) -> void:
	var h := size * 0.5
	var x0 := c.x - h.x; var x1 := c.x + h.x; var y0 := c.y - h.y; var y1 := c.y + h.y; var z0 := c.z - h.z; var z1 := c.z + h.z
	_quad(st, Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), 1.0)
	_quad(st, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x0, y1, z0), -1.0)
	# sides: x faces and y faces, wound outward
	_side(st, Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3.RIGHT)
	_side(st, Vector3(x0, y0, z1), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3.LEFT)
	_side(st, Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0), Vector3.UP)
	_side(st, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3.DOWN)

static func _side(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	var p := [a, b, c, d]
	var uvs := [Vector2(0, 0), Vector2((b - a).length(), 0), Vector2((b - a).length(), (d - a).length()), Vector2(0, (d - a).length())]
	# wind so the face looks along n (Godot: clockwise from the front)
	var order := [0, 2, 1, 0, 3, 2] if (b - a).cross(d - a).dot(n) > 0.0 else [0, 1, 2, 0, 2, 3]
	for i in order:
		st.set_normal(n); st.set_uv(uvs[i]); st.add_vertex(p[i])

## A cylinder along z (studs, the peephole, lock cylinders), its face out at z.
static func _disc(st: SurfaceTool, c: Vector3, r: float, depth: float, s: float, sides := 8, dome := 0.0) -> void:
	var back := c - Vector3(0, 0, s * depth)
	var tip := c + Vector3(0, 0, s * dome)
	for i in sides:
		var a0 := TAU * i / sides; var a1 := TAU * (i + 1) / sides
		var p0 := Vector3(cos(a0) * r, sin(a0) * r, 0); var p1 := Vector3(cos(a1) * r, sin(a1) * r, 0)
		var n0 := Vector3(cos(a0), sin(a0), 0); var n1 := Vector3(cos(a1), sin(a1), 0)
		# the rim
		var q := [back + p0, back + p1, c + p1, c + p0]
		var o := [0, 2, 1, 0, 3, 2] if s > 0.0 else [0, 1, 2, 0, 2, 3]
		var nn := [n0, n1, n1, n0]
		for k in o:
			st.set_normal(nn[k]); st.set_uv(Vector2(float(i) / sides, 0)); st.add_vertex(q[k])
		# the face (a low cone when domed)
		var f := [c + p0, c + p1, tip]
		var fn := (Vector3(0, 0, s) + (n0 + n1) * 0.5 * (0.6 if dome > 0.0 else 0.0)).normalized()
		var fo := [0, 2, 1] if s > 0.0 else [0, 1, 2]
		for k in fo:
			st.set_normal(fn); st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(f[k])

# ------------------------------------------------------------------ padded
static func _padded(sts: Dictionary, w: float, h: float, opts: Dictionary) -> void:
	var body: SurfaceTool = sts.body; var brass: SurfaceTool = sts.brass
	_box(body, Vector3(w * 0.5, h * 0.5, 0), Vector3(w, h, T))
	var mg := 0.065                    # the border outside the piping
	var iw := w - mg * 2.0; var ih := h - mg * 2.0
	var cols := 4
	var sx := iw / cols; var sy := sx * 1.4
	var rows := int(round(ih / sy)); sy = ih / rows
	var nx := 40; var ny := int(nx * ih / iw)
	for s in [1.0, -1.0]:
		var z0: float = s * T * 0.5
		# the quilt: diamonds puffed up between the tufts, pulled flat at the piping
		var g := []
		for j in ny + 1:
			var row := []
			for i in nx + 1:
				var u := iw * i / nx; var v := ih * j / ny
				var a := u / sx + v / sy; var c := u / sx - v / sy
				var puff := sqrt(absf(sin(PI * a) * sin(PI * c)))
				var edge := smoothstep(0.0, 0.05, minf(minf(u, iw - u), minf(v, ih - v)))
				row.append(Vector3(mg + u, mg + v, z0 + s * (0.006 + 0.02 * puff * edge)))
			g.append(row)
		for j in ny:
			for i in nx:
				_quad(body, g[j][i], g[j][i + 1], g[j + 1][i + 1], g[j + 1][i], s)
		# a tuft button wherever two creases cross
		for ai in range(0, cols + rows + 1):
			for cj in range(-rows, cols + 1):
				# a = ai/1 ... solve u, v at integer a, c: u = (a + c) * sx / 2, v = (a - c) * sy / 2
				var u := (ai + cj) * sx * 0.5; var v := (ai - cj) * sy * 0.5
				if u <= 0.02 or u >= iw - 0.02 or v <= 0.02 or v >= ih - 0.02: continue
				_disc(brass, Vector3(mg + u, mg + v, z0 + s * 0.007), 0.009, 0.004, s, 6, 0.004)
		# the piping, and the nails holding it, every 6 cm round the border
		var pz: float = z0 + s * 0.008
		var corners := [Vector3(mg, mg, pz), Vector3(w - mg, mg, pz), Vector3(w - mg, h - mg, pz), Vector3(mg, h - mg, pz)]
		for e in 4:
			var a3: Vector3 = corners[e]; var b3: Vector3 = corners[(e + 1) % 4]
			MeshKit.tube(body, [a3, b3], [0.011, 0.011], {"sides": 6, "cap": true})
			var n := int((b3 - a3).length() / 0.06)
			for k in n:
				var p: Vector3 = a3.lerp(b3, (k + 0.5) / n)
				var out := (Vector3(w * 0.5, h * 0.5, pz) - p); out.z = 0.0
				_disc(brass, p - out.normalized() * 0.026 + Vector3(0, 0, -s * 0.004), 0.006, 0.003, s, 6, 0.003)
		_hardware(sts, w, s, z0 + s * 0.006, true)
		if opts.has("number") and s == float(opts.get("outside", 1.0)):
			_box(brass, Vector3(w * 0.5, 1.68, z0 + s * 0.045), Vector3(0.1, 0.07, 0.006))
	# the edge: a thin wooden lip round the leaf
	var trim: SurfaceTool = sts.trim
	# (2 mm proud of the leaf all round, so the lip's faces never lie on the leaf's)
	for e in [[Vector3(0.006, h * 0.5, 0), Vector3(0.016, h + 0.004, T + 0.012)], [Vector3(w - 0.006, h * 0.5, 0), Vector3(0.016, h + 0.004, T + 0.012)],
			[Vector3(w * 0.5, h - 0.006, 0), Vector3(w + 0.004, 0.016, T + 0.012)], [Vector3(w * 0.5, 0.006, 0), Vector3(w + 0.004, 0.016, T + 0.012)]]:
		_box(trim, e[0], e[1])

## Lever, plate, lock cylinders, peephole (the padded door's sit proud of the quilt).
static func _hardware(sts: Dictionary, w: float, s: float, z: float, front: bool) -> void:
	var metal: SurfaceTool = sts.metal; var dark: SurfaceTool = sts.dark; var brass: SurfaceTool = sts.brass
	var hx := w - 0.075
	var plate_z := z + s * (0.035 if front else 0.004)
	# the long plate, the lever's boss, the lever reaching back toward the hinge
	_box(metal, Vector3(hx, 0.98, plate_z), Vector3(0.045, 0.24, 0.008))
	_disc(metal, Vector3(hx, 1.03, plate_z + s * 0.004), 0.012, 0.004, s, 8, 0.0)
	_box(metal, Vector3(hx, 1.03, plate_z + s * 0.03), Vector3(0.016, 0.016, 0.055))
	_box(metal, Vector3(hx - 0.055, 1.03, plate_z + s * 0.055), Vector3(0.12, 0.018, 0.016))
	_box(dark, Vector3(hx, 0.92, plate_z + s * 0.0045), Vector3(0.008, 0.022, 0.002))
	if front:
		# two lock cylinders above, and the peephole
		for y in [1.2, 1.38]:
			_disc(brass, Vector3(hx, y, plate_z), 0.018, 0.035, s, 8, 0.0)
			_box(dark, Vector3(hx, y, plate_z + s * 0.001), Vector3(0.003, 0.014, 0.002))
		_disc(brass, Vector3(w * 0.5, 1.5, z + s * 0.03), 0.014, 0.03, s, 8, 0.0)
		_disc(dark, Vector3(w * 0.5, 1.5, z + s * 0.031), 0.007, 0.002, s, 8, 0.0)

# ------------------------------------------------------------------ panelled
static func _panel(sts: Dictionary, w: float, h: float, opts: Dictionary) -> void:
	var body: SurfaceTool = sts.body
	var st_w := 0.11; var top := 0.12; var bot := 0.2; var mid := 1.0; var mid_h := 0.14
	# stiles and rails, the full thickness
	_box(body, Vector3(st_w * 0.5, h * 0.5, 0), Vector3(st_w, h, T))
	_box(body, Vector3(w - st_w * 0.5, h * 0.5, 0), Vector3(st_w, h, T))
	_box(body, Vector3(w * 0.5, h - top * 0.5, 0), Vector3(w - st_w * 2.0, top, T))
	_box(body, Vector3(w * 0.5, bot * 0.5, 0), Vector3(w - st_w * 2.0, bot, T))
	_box(body, Vector3(w * 0.5, mid + mid_h * 0.5, 0), Vector3(w - st_w * 2.0, mid_h, T))
	# panels: below the lock rail, and above it (glass when glazed)
	var pw := w - st_w * 2.0
	var panels := [[bot, mid], [mid + mid_h, h - top]]
	for i in panels.size():
		var y0: float = panels[i][0]; var y1: float = panels[i][1]
		var c := Vector3(w * 0.5, (y0 + y1) * 0.5, 0)
		if i == 1 and opts.get("glazed", false):
			_box(sts.glass, c, Vector3(pw, y1 - y0, 0.006))
		else:
			_box(body, c, Vector3(pw, y1 - y0, T * 0.45))
			# a raised field in the middle of the panel
			_box(body, c, Vector3(pw - 0.09, y1 - y0 - 0.09, T * 0.6))
		# the moulding round it, each side
		for s in [1.0, -1.0]:
			var z: float = s * (T * 0.5 + 0.004)
			_box(body, Vector3(w * 0.5, y0 + 0.008, z), Vector3(pw, 0.016, 0.012))
			_box(body, Vector3(w * 0.5, y1 - 0.008, z), Vector3(pw, 0.016, 0.012))
			_box(body, Vector3(st_w + 0.008, (y0 + y1) * 0.5, z), Vector3(0.016, y1 - y0, 0.012))
			_box(body, Vector3(w - st_w - 0.008, (y0 + y1) * 0.5, z), Vector3(0.016, y1 - y0, 0.012))
	for s in [1.0, -1.0]:
		_hardware(sts, w, s, s * T * 0.5, false)
	# hinges
	for y in [0.25, h - 0.25]:
		_box(sts.metal, Vector3(-0.004, y, 0), Vector3(0.018, 0.1, 0.018))
