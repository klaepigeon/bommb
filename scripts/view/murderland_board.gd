class_name MurderlandBoard
extends Node3D
## MURDERLAND: the robot's theme park, as a proper party-game board (its own world, not a
## model on the table). Laid out to read like a Mario Party board from any distance: big
## bright squares with thick black outlines on dark ground, steel walkways between them
## with hazard-striped rails, generous spacing (a puppet's height between squares), one
## district per sector of the loop, and the THE MURDERLAND CONTROL SYSTEM in the middle.
##
## Colour: everything that isn't for reading is dark and dirty (steel, concrete, rust,
## grime; each district's ground a deep shade of its own hue); everything you need to read
## is bright and outlined (squares, the Dead Rat's beam, the parade, the machines' lights).
## Each district has ONE neon accent (welcome pink, woods acid green, funhouse violet,
## sunken cyan, giggleworks safety orange, carnival red, royal gold) used on its landmark,
## its sign and its lights, so you always know where you are.
##
## The machines move when the gates change (signposts, the rotating platform, the water,
## the Big Top's flaps, the palace gates, the conveyors); a closed road goes dark and
## dashed. In puppet units; GameView puts it in its own place in the world.

const SIZE := Vector2(96.0, 72.0)
const SPACE_R := 1.15
const LK := 2.3                     # landmark scale
const ACCENT := {"welcome": Color("ff4f9a"), "woods": Color("7dff5a"), "funhouse": Color("b06aff"), "sunken": Color("2ee6e6"),
	"giggleworks": Color("ff8a1c"), "carnival": Color("ff3b3b"), "royal": Color("ffc93a")}
const GROUND := {"welcome": Color("3a2530"), "woods": Color("1f3326"), "funhouse": Color("2b2340"), "sunken": Color("14303a"),
	"giggleworks": Color("3a2a1c"), "carnival": Color("3a1a1c"), "royal": Color("332c18")}
const NAMES := {"welcome": "THE WELCOME DISTRICT", "woods": "THE WISHING WOODS", "funhouse": "THE FUNHOUSE", "sunken": "THE SUNKEN KINGDOM",
	"giggleworks": "THE GIGGLEWORKS", "carnival": "THE CARNIVAL OF LAST CHANCES", "royal": "THE ROYAL DISTRICT"}
const STEEL := Color("4a5058")
const STEEL_D := Color("2b2f36")
const CONCRETE := Color("4a4c4f")
const RUST := Color("7a3b1f")
const HAZARD := Color("f2c230")
const INKC := Color("101012")
const BONE := Color("e8e0cc")

var graph: BoardGraph
var white: Material
var glow: Material
var water_mat: ShaderMaterial
var road_dim: Material
var _font: Font
var gate_meshes: Dictionary = {}
var spin: Array = []
var landmarks: Dictionary = {}
var water: MeshInstance3D
var _water_y := 0.0
var _water_want := 0.0
var rat_node: Node3D
var rat_beam: MeshInstance3D
var parade_node: Node3D
var _parade_to := Vector3.ZERO
var trap_nodes: Dictionary = {}
var choice_marks: Array = []
var console_lights: Array = []
var _console_flash := 0.0
var signpost: Node3D
var rotator: Node3D
var tent_flaps: Array = []
var palace_gates: Array = []
var conveyor_arrows: Array = []
var space_nodes: Array = []
var gates_now: Dictionary = {}
var neon: Array = []
var _t := 0.0


func build(g: BoardGraph) -> void:
	graph = g
	_font = PartyUi.title_font()
	white = MB.mat(Tex.solid(Color.WHITE))
	glow = MB.mat(Tex.solid(Color.WHITE), Color.WHITE, Vector2.ONE, true)
	road_dim = MB.mat(Tex.solid(Color("1a1b1e")))
	_water_material()
	_floor()
	_ground()
	_roads()
	_spaces()
	_control_system()
	for d in graph.districts:
		_district(str(d.id))
	_rat_and_parade()
	_lights()
	set_gates(graph.gates)


# --- helpers ----------------------------------------------------------------------------

func p2w(p: Vector2) -> Vector3:
	return Vector3((p.x - 0.5) * SIZE.x, 0.0, (p.y - 0.5) * SIZE.y)


func space_pos(i: int) -> Vector3:
	var w := p2w(graph.pos_of(i))
	w.y = 0.6
	return w


func stand_pos(i: int, s: int) -> Vector3:
	var o: Vector2 = [Vector2(-0.5, -0.42), Vector2(0.5, -0.42), Vector2(-0.5, 0.46), Vector2(0.5, 0.46)][s % 4]
	return space_pos(i) + Vector3(o.x, 0.02, o.y)


func _mi(mb: MB, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	parent.add_child(mi)
	return mi


func _n(at: Vector3, parent: Node3D = self) -> Node3D:
	var n := Node3D.new()
	n.position = at
	parent.add_child(n)
	return n


func _sign(text: String, at: Vector3, size: int, col: Color, parent: Node3D = self, billboard := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = _font
	l.font_size = size
	l.pixel_size = 0.02
	l.modulate = col
	l.outline_modulate = INKC
	l.outline_size = 18
	l.position = at
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(l)
	return l


func _light(at: Vector3, col: Color, energy: float, rng: float, parent: Node3D = self) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.position = at
	parent.add_child(l)
	return l


## Grime: a colour, a little darker and dirtier at random.
static func grime(c: Color, k: float) -> Color:
	return c.darkened(0.12 * k).lerp(Color("2a2420"), 0.08 * k)


func _water_material() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, cull_disabled;
uniform vec4 deep : source_color = vec4(0.03, 0.16, 0.2, 0.86);
uniform vec4 lit : source_color = vec4(0.18, 0.9, 0.9, 0.6);
void fragment() {
	vec2 uv = UV * 14.0;
	float t = TIME * 0.5;
	float w = sin(uv.x * 1.7 + t) * sin(uv.y * 1.3 - t * 1.2) * 0.5 + 0.5;
	float r = sin((uv.x + uv.y) * 2.9 + t * 1.8) * 0.5 + 0.5;
	vec4 c = mix(deep, lit, pow(w * r, 3.0) * 0.8);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ROUGHNESS = 0.1;
	SPECULAR = 0.8;
}
"""
	water_mat = ShaderMaterial.new()
	water_mat.shader = sh


## Free ground in a district, away from every square and walkway: for landmarks.
func free_spots(district: String, n: int, clearance: float) -> Array:
	var ids := graph.nodes.filter(func(x): return x.district == district).map(func(x): return int(x.id))
	if ids.is_empty():
		return []
	var c := Vector2.ZERO
	for i in ids:
		c += graph.pos_of(i)
	c /= ids.size()
	var segs := []
	for nd in graph.nodes:
		var a := p2w(graph.pos_of(int(nd.id)))
		for e in nd.edges:
			var b := p2w(graph.pos_of(int(e.to)))
			segs.append([Vector2(a.x, a.z), Vector2(b.x, b.z)])
	var cands := []
	for gx in 40:
		for gy in 30:
			var p := Vector2((gx + 0.5) / 40.0, (gy + 0.5) / 30.0)
			if p.distance_to(c) > 0.26 or p.distance_to(Vector2(0.5, 0.5)) < 0.15:
				continue
			var w := p2w(p)
			var q := Vector2(w.x, w.z)
			var best := INF
			for sg in segs:
				best = minf(best, Geometry2D.get_closest_point_to_segment(q, sg[0], sg[1]).distance_to(q))
			if best >= clearance and absf(w.x) < SIZE.x * 0.5 - clearance * 0.6 and absf(w.z) < SIZE.y * 0.5 - clearance * 0.6:
				cands.append([best - p.distance_to(c) * 30.0, w])
	cands.sort_custom(func(a, b): return a[0] > b[0])
	var out := []
	for cnd in cands:
		var w: Vector3 = cnd[1]
		var ok := true
		for o in out:
			if (o as Vector3).distance_to(w) < clearance * 1.5:
				ok = false
		if ok:
			out.append(w)
		if out.size() >= n:
			break
	return out


# --- the ground ---------------------------------------------------------------------------

## The factory floor round the park: dark concrete slabs, a hazard-striped kerb at the edge.
func _floor() -> void:
	var mb := MB.new()
	var big := Vector2(SIZE.x + 60, SIZE.y + 50)
	for i in 12:
		for j in 10:
			var x := -big.x / 2 + (i + 0.5) * big.x / 12
			var z := -big.y / 2 + (j + 0.5) * big.y / 10
			mb.box("w", white, Vector3(big.x / 12 - 0.15, 0.3, big.y / 10 - 0.15), MB.T(Vector3(x, -0.55, z)), grime(Color("26272a"), float((i * 7 + j * 3) % 5) / 4.0))
	var hx := SIZE.x * 0.5 + 1.2
	var hz := SIZE.y * 0.5 + 1.2
	var k := 0
	var x0 := -hx
	while x0 < hx:
		for s in [-1.0, 1.0]:
			mb.box("w", white, Vector3(2.0, 0.6, 0.8), MB.T(Vector3(x0 + 1.0, -0.1, s * hz)), HAZARD if k % 2 == 0 else INKC)
		x0 += 2.0
		k += 1
	k = 0
	var z0 := -hz
	while z0 < hz:
		for s in [-1.0, 1.0]:
			mb.box("w", white, Vector3(0.8, 0.6, 2.0), MB.T(Vector3(s * hx, -0.1, z0 + 1.0)), HAZARD if k % 2 == 0 else INKC)
		z0 += 2.0
		k += 1
	_mi(mb)


## Each district's ground, a deep shade of its hue with grime; darker seams where districts
## meet; a concrete plaza with a hazard ring round the Control System.
func _ground() -> void:
	var gw := 96
	var gh := 72
	var owner := []
	for gy in gh:
		var row := []
		for gx in gw:
			var p := Vector2((gx + 0.5) / gw, (gy + 0.5) / gh)
			var best := INF
			var dist := ""
			for nd in graph.nodes:
				var d := p.distance_squared_to(graph.pos_of(int(nd.id)))
				if d < best:
					best = d
					dist = str(nd.district)
			if p.distance_to(Vector2(0.5, 0.5)) < 0.1:
				dist = "_plaza"
			row.append(dist)
		owner.append(row)
	var mb := MB.new()
	var cw := SIZE.x / gw
	var ch := SIZE.y / gh
	for gy in gh:
		for gx in gw:
			var dist: String = owner[gy][gx]
			var w := p2w(Vector2((gx + 0.5) / gw, (gy + 0.5) / gh))
			var col: Color = CONCRETE if dist == "_plaza" else GROUND.get(dist, CONCRETE)
			# flat paint over concrete, a floor-plate grid scored into it
			if gx % 4 == 0 or gy % 4 == 0:
				col = col.darkened(0.18)
			var seam := false
			for d in [[1, 0], [0, 1], [-1, 0], [0, -1]]:
				var x2: int = gx + d[0]
				var y2: int = gy + d[1]
				if x2 >= 0 and y2 >= 0 and x2 < gw and y2 < gh and owner[y2][x2] != dist:
					seam = true
			if seam:
				col = INKC.lerp(col, 0.35)
			var y := -0.1 if dist == "sunken" else 0.0
			mb.quad("w", white, Vector3(w.x - cw / 2, y, w.z + ch / 2), Vector3(w.x + cw / 2, y, w.z + ch / 2), Vector3(w.x + cw / 2, y, w.z - ch / 2), Vector3(w.x - cw / 2, y, w.z - ch / 2), col)
	_mi(mb)
	# the plaza's hazard ring
	var ring := MB.new()
	for k in 48:
		var a := TAU * k / 48.0
		ring.box("w", white, Vector3(1.0, 0.12, 0.5), MB.T(Vector3(cos(a) * 9.2, 0.05, sin(a) * 9.2), Vector3(0, -a, 0)), HAZARD if k % 2 == 0 else INKC)
	_mi(ring)
	# the water over the Sunken Kingdom
	var cells := []
	for gy in gh:
		for gx in gw:
			if owner[gy][gx] == "sunken":
				cells.append(p2w(Vector2((gx + 0.5) / gw, (gy + 0.5) / gh)))
	if not cells.is_empty():
		var mn := Vector3(INF, 0, INF)
		var mx := Vector3(-INF, 0, -INF)
		for w in cells:
			mn = Vector3(minf(mn.x, w.x), 0, minf(mn.z, w.z))
			mx = Vector3(maxf(mx.x, w.x), 0, maxf(mx.z, w.z))
		var pm := PlaneMesh.new()
		pm.size = Vector2(mx.x - mn.x + 1.0, mx.z - mn.z + 1.0)
		water = MeshInstance3D.new()
		water.mesh = pm
		water.material_override = water_mat
		water.position = (mn + mx) * 0.5 + Vector3(0, 0.02, 0)
		add_child(water)


## Steel walkways between squares: dark grating, hazard-striped rails, only between the
## squares' edges (so every square stands clear).
func _roads() -> void:
	var by_gate := {}
	var mb := MB.new()
	for nd in graph.nodes:
		var a := space_pos(int(nd.id))
		for e in nd.edges:
			var b := space_pos(int(e.to))
			var target: MB = mb
			if e.has("gate"):
				var key := "%s:%s" % [e.gate, e.when]
				if not by_gate.has(key):
					by_gate[key] = MB.new()
				target = by_gate[key]
			_walkway(target, a, b)
	_mi(mb)
	for key in by_gate.keys():
		gate_meshes[key] = [_mi(by_gate[key])]


func _walkway(mb: MB, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var full := Vector2(d.x, d.z).length()
	if full < SPACE_R * 2.2:
		return
	var dir := d / full
	var p0 := a + dir * (SPACE_R + 0.15)
	var p1 := b - dir * (SPACE_R + 0.15)
	var l := Vector2((p1 - p0).x, (p1 - p0).z).length()
	var mid := (p0 + p1) * 0.5
	var yaw := atan2(d.x, d.z)
	mb.box("w", white, Vector3(1.15, 0.2, l), MB.T(mid - Vector3(0, 0.38, 0), Vector3(0, yaw, 0)), STEEL_D)
	# grating slats
	var n := int(l / 0.45)
	for k in n:
		var at := p0.lerp(p1, (k + 0.5) / maxf(1.0, n)) - Vector3(0, 0.27, 0)
		mb.box("w", white, Vector3(1.0, 0.04, 0.12), MB.T(at, Vector3(0, yaw, 0)), STEEL)
	# rails, striped
	var side := Vector3(cos(yaw), 0, -sin(yaw)) * 0.62
	var m := int(l / 0.5)
	for k in m:
		var at2 := p0.lerp(p1, (k + 0.5) / maxf(1.0, m)) - Vector3(0, 0.26, 0)
		var c := HAZARD if k % 2 == 0 else INKC
		mb.box("w", white, Vector3(0.16, 0.18, 0.5), MB.T(at2 + side, Vector3(0, yaw, 0)), c)
		mb.box("w", white, Vector3(0.16, 0.18, 0.5), MB.T(at2 - side, Vector3(0, yaw, 0)), c)


# --- the squares ---------------------------------------------------------------------------

func _spaces() -> void:
	var mb := MB.new()
	for nd in graph.nodes:
		var i := int(nd.id)
		var at := space_pos(i)
		var t := str(nd.type)
		var col := PartyUi.space_colour(t)
		space_nodes.append(_n(at))
		_space_shape(mb, at, t, col)
		var gl := str(PartyUi.GLYPH.get(t, ""))
		if gl != "":
			var l := _sign(gl, at + Vector3(0, 0.16, 0), 64, Color.WHITE if col.get_luminance() < 0.55 else INKC, self, false)
			l.rotation.x = -PI / 2
			l.outline_size = 14
			l.outline_modulate = INKC if col.get_luminance() < 0.55 else Color(1, 1, 1, 0.85)
	_mi(mb)


## Every square: a dark steel plinth, a thick black outline, a bright face whose SHAPE says
## what it is (a star for bonus, spikes for bad, a stall for shops, a cross for medical...).
func _space_shape(mb: MB, at: Vector3, t: String, col: Color) -> void:
	var base := at - Vector3(0, 0.6, 0)
	var r := SPACE_R
	mb.cyl("w", white, r + 0.34, r + 0.28, 0.42, 14, MB.T(base), STEEL_D)
	mb.cyl("w", white, r + 0.16, r + 0.16, 0.56, 14, MB.T(base), INKC)
	var top := base + Vector3(0, 0.58, 0)
	match t:
		"bonus":
			mb.cyl("w", white, r, r, 0.12, 14, MB.T(top), col)
			for k in 5:
				var a := TAU * k / 5.0
				mb.box("w", white, Vector3(0.36, 0.14, 0.9), MB.T(top + Vector3(sin(a), 0.06, cos(a)) * 0.55, Vector3(0, a, 0)), col.lightened(0.2))
		"bad", "trap":
			mb.cyl("w", white, r, r, 0.12, 8, MB.T(top), col)
			for k in 8:
				var a := TAU * k / 8.0
				mb.cyl("w", white, 0.11, 0.0, 0.45, 4, MB.T(top + Vector3(sin(a) * (r + 0.05), 0.2, cos(a) * (r + 0.05))), INKC)
		"event":
			mb.cyl("w", white, r, r, 0.12, 6, MB.T(top), col)
		"item":
			mb.box("w", white, Vector3(r * 1.5, 0.12, r * 1.5), MB.T(top, Vector3(0, PI / 4, 0)), col)
		"shop", "black_market", "medical":
			mb.box("w", white, Vector3(r * 1.7, 0.12, r * 1.7), MB.T(top), col)
			for sx in [-0.7, 0.7]:
				mb.box("w", white, Vector3(0.1, 1.5, 0.1), MB.T(top + Vector3(sx, 0.75, -0.8)), STEEL)
			for k in 6:
				mb.box("w", white, Vector3(0.26, 0.06, 0.6), MB.T(top + Vector3(-0.65 + k * 0.26, 1.45, -0.62), Vector3(0.45, 0, 0)), col if k % 2 == 0 else BONE)
		"roulette":
			mb.cyl("w", white, r, r, 0.12, 14, MB.T(top), col)
			for k in 6:
				var a := TAU * k / 6.0
				mb.cyl("w", white, 0.15, 0.15, 0.14, 8, MB.T(top + Vector3(sin(a) * 0.55, 0.02, cos(a) * 0.55)), Color("ff2a2a") if k == 0 else Color("3a3a3a"))
		"death":
			mb.box("w", white, Vector3(r * 1.6, 0.12, r * 1.6), MB.T(top), col)
			mb.box("w", white, Vector3(r * 1.1, 0.14, r * 1.1), MB.T(top), Color("000000"))
		"resurrect", "surgery", "medical_x":
			mb.cyl("w", white, r, r, 0.12, 14, MB.T(top), col)
			mb.box("w", white, Vector3(0.3, 0.16, 1.2), MB.T(top), Color("ff3b3b") if t == "surgery" else Color("6ab0ff"))
			mb.box("w", white, Vector3(1.2, 0.16, 0.3), MB.T(top), Color("ff3b3b") if t == "surgery" else Color("6ab0ff"))
		"start":
			mb.box("w", white, Vector3(r * 2.0, 0.12, r * 2.0), MB.T(top), BONE)
			for k in 4:
				for j in 4:
					if (k + j) % 2 == 0:
						mb.box("w", white, Vector3(r * 0.5, 0.14, r * 0.5), MB.T(top + Vector3(-r * 0.75 + k * r * 0.5, 0.01, -r * 0.75 + j * r * 0.5)), INKC)
		_:
			mb.cyl("w", white, r, r, 0.12, 14, MB.T(top), col)
			if t in ["control", "wheel", "signpost", "rotator", "floodgate", "switch", "conveyor"]:
				for k in 8:
					var a := TAU * k / 8.0
					mb.box("w", white, Vector3(0.3, 0.14, 0.12), MB.T(top + Vector3(sin(a), 0.01, cos(a)) * (r - 0.12), Vector3(0, a, 0)), HAZARD if k % 2 == 0 else INKC)


# --- the middle: THE MURDERLAND CONTROL SYSTEM ---------------------------------------------

func _control_system() -> void:
	var root := _n(Vector3.ZERO)
	root.scale = Vector3.ONE * 1.6
	landmarks.control = root
	var mb := MB.new()
	mb.cyl("w", white, 4.2, 4.5, 0.5, 16, MB.T(Vector3(0, 0.25, 0)), STEEL_D)
	mb.cyl("w", white, 3.8, 3.8, 0.12, 16, MB.T(Vector3(0, 0.56, 0)), STEEL)
	for k in 8:
		var a := -PI * 0.6 + k * PI * 1.2 / 7.0
		var at := Vector3(sin(a) * 2.5, 1.0, cos(a) * 2.5)
		mb.box("w", white, Vector3(1.0, 1.0, 0.7), MB.T(at, Vector3(0, a, 0)), STEEL)
		mb.box("w", white, Vector3(0.82, 0.55, 0.06), MB.T(at + Vector3(0, 0.8, 0) - Vector3(sin(a), 0, cos(a)) * 0.3, Vector3(-0.3, a, 0)), Color("0a1210"))
		mb.cyl("w", white, 0.05, 0.05, 0.6, 4, MB.T(at + Vector3(0.3 * cos(a), 0.7, -0.3 * sin(a)), Vector3(0.4, a, 0)), RUST)
	mb.cyl("w", white, 1.2, 1.5, 2.0, 10, MB.T(Vector3(0, 1.5, 0)), RUST.darkened(0.2))
	mb.cyl("w", white, 0.08, 0.08, 3.4, 4, MB.T(Vector3(0, 4.0, 0)), STEEL)
	# pipes out to the seven districts
	for d in graph.districts:
		var ids := graph.nodes.filter(func(x): return x.district == d.id)
		if ids.is_empty():
			continue
		var c := Vector3.ZERO
		for x in ids:
			c += space_pos(int(x.id))
		c /= ids.size()
		var dir := Vector3(c.x, 0, c.z).normalized()
		mb.box("w", white, Vector3(0.35, 0.35, 3.0), MB.T(dir * 5.6 + Vector3(0, 0.3, 0), Vector3(0, atan2(dir.x, dir.z), 0)), ACCENT.get(str(d.id), STEEL).darkened(0.35))
	_mi(mb, root)
	for k in 12:
		var a := TAU * k / 12.0
		var bulb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.2
		sm.height = 0.4
		bulb.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = HAZARD if k % 2 == 0 else Color("ff4f9a")
		bulb.material_override = m
		bulb.position = Vector3(sin(a) * 3.9, 0.75, cos(a) * 3.9)
		root.add_child(bulb)
		console_lights.append(bulb)
	_sign("THE MURDERLAND\nCONTROL SYSTEM", Vector3(0, 7.4, 0), 52, HAZARD, root)
	_light(Vector3(0, 6.0, 0), Color("ffd0a0"), 2.0, 22.0, root)


# --- the districts --------------------------------------------------------------------------

func _district(id: String) -> void:
	var acc: Color = ACCENT.get(id, HAZARD)
	var spots := free_spots(id, 8, 3.4)
	if spots.is_empty():
		return
	var main := _n(spots[0])
	main.scale = Vector3.ONE * LK
	main.rotation.y = atan2(-spots[0].x, -spots[0].z)
	call("_lm_" + id, main, acc)
	# the district's neon sign on a steel gantry beside its landmark
	var g := _n(spots[0] + Vector3(0, 0, 0))
	_sign(NAMES.get(id, id.to_upper()), Vector3(0, 9.5, 0), 44, acc, g)
	_light(spots[0] + Vector3(0, 7.0, 0), acc, 1.6, 18.0)
	for k in range(1, spots.size()):
		var p := _n(spots[k])
		p.scale = Vector3.ONE * (LK * 0.7)
		p.rotation.y = randf() * TAU
		_prop(id, p, acc, k)
	_gimmicks(id)


## Small props: the industrial bones of the place, in the district's accent.
func _prop(id: String, p: Node3D, acc: Color, k: int) -> void:
	var mb := MB.new()
	match k % 3:
		0:
			# a stack of barrels
			for j in 3:
				mb.cyl("w", white, 0.35, 0.35, 0.9, 8, MB.T(Vector3(-0.4 + j * 0.4, 0.45, (j % 2) * 0.35)), RUST if j != 1 else acc.darkened(0.3))
		1:
			# a lamp post with the accent neon
			mb.cyl("w", white, 0.08, 0.1, 3.2, 6, MB.T(Vector3(0, 1.6, 0)), STEEL_D)
			mb.box("w", glow, Vector3(0.5, 0.25, 0.25), MB.T(Vector3(0, 3.2, 0)), acc)
		2:
			# a girder frame
			for s in [-0.6, 0.6]:
				mb.box("w", white, Vector3(0.2, 2.4, 0.2), MB.T(Vector3(s, 1.2, 0)), STEEL)
			mb.box("w", white, Vector3(1.6, 0.25, 0.25), MB.T(Vector3(0, 2.4, 0)), HAZARD)
			mb.box("w", white, Vector3(1.2, 0.6, 0.06), MB.T(Vector3(0, 1.6, 0.12)), acc)
	_mi(mb, p)


func _lm_welcome(n: Node3D, acc: Color) -> void:
	var mb := MB.new()
	# a theme-park gate made of scaffolding, the WELCOME sign hung off it, the mascot on top
	for s in [-1.0, 1.0]:
		mb.box("w", white, Vector3(0.5, 3.4, 0.5), MB.T(Vector3(s * 1.6, 1.7, 0)), STEEL)
		mb.box("w", white, Vector3(0.6, 0.15, 0.6), MB.T(Vector3(s * 1.6, 0.075, 0)), HAZARD)
	mb.box("w", white, Vector3(3.8, 0.7, 0.4), MB.T(Vector3(0, 3.3, 0)), acc)
	mb.sphere("w", white, 0.6, 5, 10, MB.T(Vector3(0, 4.3, 0)), BONE)
	mb.cyl("w", white, 0.0, 0.4, 0.8, 8, MB.T(Vector3(0, 5.2, 0)), HAZARD)
	for s in [-1.0, 1.0]:
		mb.sphere("w", white, 0.14, 3, 6, MB.T(Vector3(s * 0.22, 4.4, 0.52)), Color.WHITE)
		mb.sphere("w", white, 0.07, 3, 6, MB.T(Vector3(s * 0.22, 4.4, 0.62)), INKC)
	mb.box("w", white, Vector3(0.5, 0.08, 0.06), MB.T(Vector3(0, 4.1, 0.58)), Color("5a0a12"))
	_mi(mb, n)
	_sign("WELCOME!", Vector3(0, 3.3, 0.25), 40, Color.WHITE, n, false)


func _lm_woods(n: Node3D, acc: Color) -> void:
	var mb := MB.new()
	# a dead industrial forest: lamp-post trees with acid-green canopies, a giant toadstool
	for k in 4:
		var a := TAU * k / 4.0
		var p := Vector3(sin(a) * 1.4, 0, cos(a) * 1.4)
		mb.cyl("w", white, 0.15, 0.22, 2.4, 6, MB.T(p + Vector3(0, 1.2, 0)), RUST.darkened(0.3))
		mb.sphere("w", white, 0.75, 4, 8, MB.T(p + Vector3(0, 2.7, 0)), acc.darkened(0.25 + k * 0.08))
	mb.cyl("w", white, 0.35, 0.45, 2.0, 8, MB.T(Vector3(0, 1.0, 0)), BONE.darkened(0.2))
	mb.sphere("w", white, 1.3, 4, 12, MB.T(Vector3(0, 2.2, 0)), Color("b02020"), Vector3(1, 0.45, 1))
	for j in 6:
		var a := TAU * j / 6.0
		mb.sphere("w", white, 0.16, 2, 5, MB.T(Vector3(sin(a) * 0.8, 2.6, cos(a) * 0.8)), BONE)
	_mi(mb, n)


func _lm_funhouse(n: Node3D, acc: Color) -> void:
	# the crooked carousel (it turns)
	var c := _n(Vector3.ZERO, n)
	c.rotation.z = 0.08
	var mb := MB.new()
	mb.cyl("w", white, 1.9, 1.9, 0.3, 14, MB.T(Vector3(0, 0.15, 0)), STEEL_D)
	mb.cyl("w", white, 0.0, 2.2, 1.1, 14, MB.T(Vector3(0, 2.9, 0)), acc.darkened(0.2))
	mb.cyl("w", white, 0.2, 0.2, 2.4, 6, MB.T(Vector3(0, 1.3, 0)), STEEL)
	for k in 6:
		var a := TAU * k / 6.0
		mb.cyl("w", white, 0.05, 0.05, 2.2, 4, MB.T(Vector3(sin(a) * 1.5, 1.3, cos(a) * 1.5)), BONE)
		mb.sphere("w", white, 0.32, 3, 6, MB.T(Vector3(sin(a) * 1.5, 1.0, cos(a) * 1.5)), [acc, BONE, HAZARD][k % 3], Vector3(1.4, 0.8, 0.7))
	_mi(mb, c)
	spin.append([c, Vector3.UP, 0.5])


func _lm_sunken(n: Node3D, acc: Color) -> void:
	var mb := MB.new()
	# a rusted lighthouse with a cyan lamp
	for k in 5:
		mb.cyl("w", white, 0.55 - k * 0.05, 0.6 - k * 0.05, 0.6, 8, MB.T(Vector3(0, 0.3 + k * 0.6, 0)), BONE.darkened(0.25) if k % 2 == 0 else RUST)
	mb.cyl("w", white, 0.0, 0.5, 0.6, 8, MB.T(Vector3(0, 3.9, 0)), STEEL_D)
	mb.cyl("w", glow, 0.35, 0.35, 0.5, 8, MB.T(Vector3(0, 3.35, 0)), acc)
	_mi(mb, n)
	var wheel := _n(Vector3(1.6, 1.2, 0), n)
	var wm := MB.new()
	wm.ring("w", white, 1.0, 0.12, 12, MB.T(), RUST)
	for k in 8:
		var a := TAU * k / 8.0
		wm.box("w", white, Vector3(0.1, 0.5, 0.6), MB.T(Vector3(cos(a), sin(a), 0) * 0.95, Vector3(0, 0, a)), STEEL)
	_mi(wm, wheel)
	spin.append([wheel, Vector3.BACK, 0.8])


func _lm_giggleworks(n: Node3D, acc: Color) -> void:
	var mb := MB.new()
	# a sawtooth-roofed factory, chimneys, the safety-orange gear on its wall
	mb.box("w", white, Vector3(3.2, 1.8, 2.2), MB.T(Vector3(0, 0.9, 0)), CONCRETE)
	for k in 3:
		mb.box("w", white, Vector3(1.05, 0.7, 2.2), MB.T(Vector3(-1.05 + k * 1.05, 2.1, 0), Vector3(0, 0, 0.6)), STEEL)
	for k in 2:
		mb.cyl("w", white, 0.24, 0.3, 2.4, 6, MB.T(Vector3(1.0 - k * 2.0, 3.0, -0.7)), RUST.darkened(0.2))
	_mi(mb, n)
	var gear := _n(Vector3(0, 1.0, 1.15), n)
	var gm := MB.new()
	gm.cyl("w", white, 0.75, 0.75, 0.2, 12, MB.T(Vector3.ZERO, Vector3(PI / 2, 0, 0)), acc)
	for j in 10:
		var a := TAU * j / 10.0
		gm.box("w", white, Vector3(0.25, 0.25, 0.2), MB.T(Vector3(cos(a), sin(a), 0) * 0.85, Vector3(0, 0, a)), acc)
	_mi(gm, gear)
	spin.append([gear, Vector3.BACK, 0.8])


func _lm_carnival(n: Node3D, acc: Color) -> void:
	var mb := MB.new()
	# the big top: red and dirty white stripes
	for k in 12:
		var a := TAU * k / 12.0
		mb.box("w", white, Vector3(0.95, 1.6, 0.1), MB.T(Vector3(sin(a) * 1.6, 0.8, cos(a) * 1.6), Vector3(0, a, 0)), acc.darkened(0.15) if k % 2 == 0 else BONE.darkened(0.2))
	mb.cyl("w", white, 0.0, 1.9, 1.8, 12, MB.T(Vector3(0, 2.5, 0)), acc.darkened(0.2))
	mb.cyl("w", white, 0.05, 0.05, 1.0, 4, MB.T(Vector3(0, 3.8, 0)), HAZARD)
	_mi(mb, n)
	for s in [-1.0, 1.0]:
		var flap := _n(Vector3(s * 0.35, 0, 1.62), n)
		var fm := MB.new()
		fm.box("w", white, Vector3(0.7, 1.5, 0.06), MB.T(Vector3(-s * 0.35, 0.75, 0)), HAZARD.darkened(0.2))
		_mi(fm, flap)
		tent_flaps.append([flap, s])


func _lm_royal(n: Node3D, acc: Color) -> void:
	var mb := MB.new()
	# the palace, built out of a grain silo and gold paint
	mb.box("w", white, Vector3(3.2, 2.4, 2.2), MB.T(Vector3(0, 1.2, 0)), CONCRETE.lightened(0.1))
	for k in 4:
		var o := Vector3([-1.6, 1.6, -1.6, 1.6][k], 0, [-1.1, -1.1, 1.1, 1.1][k])
		mb.cyl("w", white, 0.45, 0.5, 3.6, 8, MB.T(o + Vector3(0, 1.8, 0)), STEEL)
		mb.cyl("w", white, 0.0, 0.6, 1.0, 8, MB.T(o + Vector3(0, 4.1, 0)), acc)
	mb.cyl("w", white, 0.85, 0.95, 1.6, 10, MB.T(Vector3(0, 3.2, 0)), acc.darkened(0.3))
	mb.sphere("w", white, 0.9, 5, 10, MB.T(Vector3(0, 4.2, 0)), acc)
	_mi(mb, n)


## The machines on the squares themselves (signposts, the rotating platform, conveyors) and
## on the routes (the palace gates).
func _gimmicks(id: String) -> void:
	for nd in graph.nodes:
		if nd.district != id:
			continue
		var at := space_pos(int(nd.id))
		match str(nd.type):
			"signpost":
				signpost = _n(at + Vector3(1.4, 0, -1.4))
				var smb := MB.new()
				smb.box("w", white, Vector3(0.2, 3.2, 0.2), MB.T(Vector3(0, 1.6, 0)), STEEL)
				smb.box("w", white, Vector3(2.2, 0.55, 0.1), MB.T(Vector3(0.9, 2.7, 0)), ACCENT.woods)
				smb.cyl("w", white, 0.0, 0.42, 0.4, 3, MB.T(Vector3(2.1, 2.7, 0), Vector3(0, 0, -PI / 2)), ACCENT.woods)
				_mi(smb, signpost)
			"rotator":
				rotator = _n(at + Vector3(0, 0.02, 0))
				var rmb := MB.new()
				rmb.box("w", glow, Vector3(0.3, 0.1, 1.6), MB.T(Vector3(0, 0.02, 0.9)), HAZARD)
				rmb.cyl("w", glow, 0.0, 0.35, 0.5, 3, MB.T(Vector3(0, 0.02, 1.8), Vector3(PI / 2, 0, 0)), HAZARD)
				_mi(rmb, rotator)
			"conveyor":
				var nx := space_pos(int(graph.next_of(int(nd.id))[0]))
				var arrow := _n(at + Vector3(0, 0.12, 0))
				arrow.rotation.y = atan2(nx.x - at.x, nx.z - at.z)
				var amb := MB.new()
				amb.cyl("w", glow, 0.0, 0.45, 0.7, 3, MB.T(Vector3(0, 0, 0.15), Vector3(PI / 2, 0, 0)), HAZARD)
				_mi(amb, arrow)
				conveyor_arrows.append(arrow)
	for b in graph.branches:
		if str(b.gate) == "royal" and str(b.district) == id:
			var a := space_pos(int(b.from))
			var nx := space_pos(int(b.ids[0]))
			var mid := a.lerp(nx, 0.5)
			var yaw := atan2(nx.x - a.x, nx.z - a.z)
			for s in [-1.0, 1.0]:
				var hinge := _n(mid + Vector3(cos(yaw), 0, -sin(yaw)) * 0.75 * s)
				hinge.rotation.y = yaw
				var gm := MB.new()
				gm.box("w", white, Vector3(0.72, 1.6, 0.08), MB.T(Vector3(-0.36 * s, 0.8, 0)), ACCENT.royal)
				_mi(gm, hinge)
				palace_gates.append([hinge, s, yaw])


func _rat_and_parade() -> void:
	rat_node = Node3D.new()
	add_child(rat_node)
	var mi := MeshInstance3D.new()
	mi.mesh = DeadRat.mesh()
	mi.scale = Vector3.ONE * 2.6
	mi.position = Vector3(0, 0.3, 0)
	rat_node.add_child(mi)
	rat_beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 1.2
	cm.height = 12.0
	rat_beam.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.9, 0.4, 0.22)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	rat_beam.material_override = m
	rat_beam.position = Vector3(0, 6.0, 0)
	rat_node.add_child(rat_beam)
	_sign("DEAD RAT", Vector3(0, 2.6, 0), 40, HAZARD, rat_node)
	_light(Vector3(0, 3.0, 0), Color("ffe080"), 2.0, 6.0, rat_node)
	rat_node.visible = false
	parade_node = Node3D.new()
	add_child(parade_node)
	var mb := MB.new()
	mb.box("w", white, Vector3(1.8, 0.6, 1.1), MB.T(Vector3(0, 0.55, 0)), ACCENT.welcome)
	mb.sphere("w", white, 0.55, 4, 8, MB.T(Vector3(0, 1.4, 0)), BONE)
	mb.cyl("w", white, 0.0, 0.35, 0.7, 6, MB.T(Vector3(0, 2.1, 0)), HAZARD)
	for s in [-1.0, 1.0]:
		for z in [-0.42, 0.42]:
			mb.cyl("w", white, 0.22, 0.22, 0.14, 8, MB.T(Vector3(s * 0.8, 0.22, z), Vector3(0, 0, PI / 2)), INKC)
	_mi(mb, parade_node)
	parade_node.visible = not graph.parade.is_empty()
	if not graph.parade.is_empty():
		parade_node.position = space_pos(int(graph.parade[0])) + Vector3(0, -0.55, 0)
		_parade_to = parade_node.position


func _lights() -> void:
	# a hard work-light from above, cold fill from the sides: the factory at night
	for p in [Vector3(-SIZE.x * 0.25, 18, -SIZE.y * 0.2), Vector3(SIZE.x * 0.25, 18, -SIZE.y * 0.2), Vector3(-SIZE.x * 0.25, 18, SIZE.y * 0.25), Vector3(SIZE.x * 0.25, 18, SIZE.y * 0.25)]:
		_light(p, Color("fff0dc"), 1.6, 45.0)


# --- live state -------------------------------------------------------------------------------

func set_gates(g: Dictionary) -> void:
	gates_now = g.duplicate()
	for key in gate_meshes.keys():
		var parts := str(key).split(":")
		var open := str(g.get(parts[0], "")) == parts[1]
		for mi in gate_meshes[key]:
			(mi as MeshInstance3D).material_override = null if open else road_dim
	_water_want = 0.35 if str(g.get("flood", "low")) == "high" else -0.05


func set_rat(space: int) -> void:
	rat_node.visible = space >= 0
	if space >= 0:
		rat_node.position = space_pos(space) + Vector3(0, 0.05, 0)


func set_parade(space: int) -> void:
	if space >= 0:
		_parade_to = space_pos(space) + Vector3(0, -0.55, 0)


func set_traps(spaces: Array) -> void:
	for k in trap_nodes.keys():
		if not spaces.has(k):
			trap_nodes[k].queue_free()
			trap_nodes.erase(k)
	for s in spaces:
		var i := int(s)
		if trap_nodes.has(i):
			continue
		var n := _n(space_pos(i) + Vector3(0.45, 0.08, 0.45))
		var mb := MB.new()
		mb.box("w", white, Vector3(0.9, 0.08, 0.5), MB.T(), RUST)
		mb.box("w", white, Vector3(0.9, 0.06, 0.06), MB.T(Vector3(0, 0.14, 0.18), Vector3(0.9, 0, 0)), STEEL)
		_mi(mb, n)
		trap_nodes[i] = n


func set_types(_altered: Dictionary) -> void:
	pass


func show_choices(from_space: int, options: Array) -> void:
	for c in choice_marks:
		c.queue_free()
	choice_marks.clear()
	if from_space < 0:
		return
	var a := space_pos(from_space)
	for o in options:
		var b := space_pos(int(o.to))
		var dir := (b - a).normalized()
		var n := _n(a + dir * 2.2 + Vector3(0, 1.2, 0))
		n.rotation.y = atan2(b.x - a.x, b.z - a.z)
		var mb := MB.new()
		var col := HAZARD if o.can else Color("666666")
		mb.cyl("w", glow, 0.0, 0.55, 0.9, 3, MB.T(Vector3(0, 0, 0.3), Vector3(PI / 2, 0, 0)), col)
		mb.box("w", glow, Vector3(0.3, 0.16, 0.8), MB.T(Vector3(0, 0, -0.45)), col)
		_mi(mb, n)
		var l := _sign(str(o.name), Vector3(0, 1.1, 0), 36, BONE, n)
		l.no_depth_test = true
		choice_marks.append(n)


func flash_console() -> void:
	_console_flash = 2.5


func _process(delta: float) -> void:
	_t += delta
	for sp in spin:
		(sp[0] as Node3D).rotate_object_local(sp[1], float(sp[2]) * delta)
	if water:
		_water_y = lerpf(_water_y, _water_want, minf(1.0, delta * 0.8))
		water.position.y = _water_y
	if rat_node and rat_node.visible:
		rat_node.rotation.y += delta * 0.8
		rat_beam.scale = Vector3.ONE * (1.0 + sin(_t * 3.0) * 0.06)
	if parade_node:
		parade_node.position = parade_node.position.lerp(_parade_to, minf(1.0, delta * 1.2))
		parade_node.rotation.y = sin(_t * 2.0) * 0.15
	_console_flash = maxf(0.0, _console_flash - delta)
	for k in console_lights.size():
		var on: bool = (int(_t * (8.0 if _console_flash > 0.0 else 1.5)) + k) % 3 == 0
		(console_lights[k] as MeshInstance3D).visible = on or (_console_flash <= 0.0 and k % 2 == 0)
	if signpost:
		var want := 0.6 if str(gates_now.get("woods_sign", "left")) == "left" else -0.6
		signpost.rotation.y = lerp_angle(signpost.rotation.y, want, minf(1.0, delta * 2.0))
	if rotator:
		var want_r := 0.0 if str(gates_now.get("rotator", "maze")) == "maze" else PI * 0.7
		rotator.rotation.y = lerp_angle(rotator.rotation.y, want_r, minf(1.0, delta * 1.5))
	for f in tent_flaps:
		var open := str(gates_now.get("big_top", "shut")) == "open"
		(f[0] as Node3D).rotation.y = lerpf((f[0] as Node3D).rotation.y, (1.2 * float(f[1])) if open else 0.0, minf(1.0, delta * 2.0))
	for pg in palace_gates:
		var open2 := str(gates_now.get("royal", "shut")) == "open"
		(pg[0] as Node3D).rotation.y = lerp_angle((pg[0] as Node3D).rotation.y, float(pg[2]) + (1.4 * float(pg[1]) if open2 else 0.0), minf(1.0, delta * 1.5))
	var back := str(gates_now.get("conveyor", "forward")) == "back"
	for ar in conveyor_arrows:
		(ar as Node3D).scale = Vector3(1, 1, -1 if back else 1)
