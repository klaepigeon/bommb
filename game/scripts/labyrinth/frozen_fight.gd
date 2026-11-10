class_name FrozenFight
extends Node3D
## The square: a fight, stopped. Nobody says what happened here; it's all still here.
##
## Where she stood, off the ground, the paving has been torn up in a ring and every sett of it
## hangs in the air where it was thrown, in a shell around nothing. The café's chairs and table
## are in the air, and the glass of the café window, in pieces, each catching the light. From the
## north-west corner of the square, where a man stood, arrows: steel, with heads no shop sells
## (a grapnel, a bulb, a fork), stopped in flight, all aimed at the same empty place above the
## crater. His domino mask on the cobbles where he stood. On the wall behind him, among the
## Tsar's town's bills, a printed poster from sixty years later: THE CHAMPION'S LEAGUE, TRICKSHOT.
## And at the crater's edge, the revolver. Dust hangs in the air and doesn't fall.

const CENTER := Vector3(42.0, 0.0, 40.0)          # where she was, in the labyrinth's space
const HER := Vector3(42.0, 2.3, 40.0)             # where she was, in the air
const ARCHER := Vector3(34.6, 0.0, 33.4)          # where he stood (north-west corner)

var kit: TownKit
var gun_at := Transform3D.IDENTITY
var examine_nodes: Array = []

func build(p_kit: TownKit, owner: Node3D) -> void:
	kit = p_kit
	var rng := RandomNumberGenerator.new(); rng.seed = 1964
	_crater(rng)
	_hanging_setts(rng)
	_cafe(rng)
	_arrows(rng)
	_mask(owner)
	_poster(owner)
	_dust(owner, rng)
	_stillness(owner)
	_finish_trails(owner)
	# the revolver lies at the crater's lip on the archer's side, where it was dropped
	var g := CENTER + Vector3(-1.45, 0.03, -1.1)
	gun_at = Transform3D(Basis(Vector3.UP, 0.7) * Basis(Vector3(0, 0, 1), PI * 0.5), g + Vector3(0, 0.018, 0))
	# a glint on it: the stillness's light catching blued steel, enough to find it by
	var glint := OmniLight3D.new(); glint.name = "Glint"; glint.light_color = Color(0.8, 0.88, 1.0)
	glint.light_energy = 0.9; glint.omni_range = 0.9; glint.shadow_enabled = false
	owner.add_child(glint); glint.position = g + Vector3(0.1, 0.35, 0.1)
	var sign := Label3D.new(); sign.text = "КОФЕЙНЯ"; sign.font_size = 44; sign.pixel_size = 0.005
	sign.modulate = Color(0.86, 0.7, 0.34); sign.shaded = false; sign.double_sided = true; sign.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	owner.add_child(sign); sign.transform = _cafe_sign

## the ground torn up where she was: the setts gone, the dark bedding sand showing, and the
## slabs round the edge heaved up and over
func _crater(rng: RandomNumberGenerator) -> void:
	const R := 1.7
	for i in 18:
		var a0 := TAU * i / 18.0; var a1 := TAU * (i + 1) / 18.0
		var r0 := R * (0.85 + rng.randf() * 0.25)
		kit.tri("sand", CENTER + Vector3(0, 0.008, 0), CENTER + Vector3(cos(a1), 0, sin(a1)) * r0 + Vector3(0, 0.008, 0), CENTER + Vector3(cos(a0), 0, sin(a0)) * r0 + Vector3(0, 0.008, 0), Vector3.UP)
	for i in 22:
		var a := TAU * i / 22.0 + rng.randf_range(-0.1, 0.1)
		var out := Vector3(cos(a), 0, sin(a))
		var p := CENTER + out * (R + rng.randf_range(-0.1, 0.25))
		var tilt := Basis(Vector3(-out.z, 0, out.x), rng.randf_range(0.5, 1.2)) * Basis(Vector3.UP, a)
		kit.box("stone", p + Vector3(0, 0.12, 0), Vector3(0.24, 0.05, 0.17), tilt)

## the paving from the crater, thrown outward and up and stopped: big slabs and whole sheets of
## setts still bedded in sand, each with a faint trail back toward where it came from
func _hanging_setts(rng: RandomNumberGenerator) -> void:
	for i in 46:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.15, 1.0), rng.randf_range(-1, 1)).normalized()
		var r := rng.randf_range(1.4, 5.0)
		var p := CENTER + Vector3(0, 0.3, 0) + dir * r
		var b := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		if rng.randf() < 0.5:
			kit.box("stone", p, Vector3(rng.randf_range(0.18, 0.3), 0.045, rng.randf_range(0.14, 0.22)), b)         # a slab
		else:
			var sheet := rng.randf_range(0.18, 0.32)
			kit.box("sand", p - b.y * 0.04, Vector3(sheet, 0.03, sheet * 0.8), b)                                      # a sheet of setts
			for sx in 3:
				for sz in 2:
					kit.box("stone", p + b.x * (sx - 1) * sheet * 0.62 + b.z * (sz - 0.5) * sheet * 0.75, Vector3(sheet * 0.28, 0.035, sheet * 0.34), b)
		_trail(p, CENTER + Vector3(0, 0.3, 0), r * 0.35)
	for i in 50:    # and the loose setts, smaller, in between
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.1, 1.0), rng.randf_range(-1, 1)).normalized()
		var p := CENTER + Vector3(0, 0.3, 0) + dir * rng.randf_range(1.0, 5.5)
		kit.box("stone", p, Vector3(0.08, 0.05, 0.07), Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)))

## a frozen streak: where a thing was a moment ago, faint, tapering back along its flight to
## nothing (vertex alpha), drawn crossed so it reads from any side
var _trails: SurfaceTool
func _trail(at: Vector3, from: Vector3, length: float) -> void:
	if not _trails:
		_trails = SurfaceTool.new(); _trails.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d := (at - from).normalized()
	var s1 := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var s2 := d.cross(s1).normalized()
	var b := at - d * length
	var head := Color(0.8, 0.88, 1.0, 0.22); var tail := Color(0.8, 0.88, 1.0, 0.0)
	for side in [s1 * 0.018, s2 * 0.018]:
		for v in [[at - side, head], [at + side, head], [b, tail]]:
			_trails.set_color(v[1]); _trails.add_vertex(v[0])

func _finish_trails(owner: Node3D) -> void:
	if not _trails: return
	var mi := MeshInstance3D.new(); mi.mesh = _trails.commit(); mi.name = "Trails"
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED; m.disable_fog = false
	mi.material_override = m; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	owner.add_child(mi)

## the café on this corner of the square: its tables and bentwood chairs in the air, its striped
## awning torn off and stopped mid-flap, its signboard tumbling, its window's glass a cloud
func _cafe(rng: RandomNumberGenerator) -> void:
	var chairs := [[Vector3(45.6, 2.2, 37.4), Vector3(0.6, 0.3, 1.9)], [Vector3(46.6, 1.2, 41.6), Vector3(-0.4, 2.1, 0.5)],
		[Vector3(39.2, 3.0, 43.2), Vector3(2.6, 0.9, -0.4)], [Vector3(44.2, 3.6, 42.9), Vector3(1.2, -0.6, 2.4)]]
	for spec in chairs:
		_chair(spec[0], Basis.from_euler(spec[1]))
		_trail(spec[0], CENTER + Vector3(0, 0.8, 0), 1.6)
	for spec in [[Vector3(44.6, 2.6, 43.8), Vector3(0.9, 0.4, 0.35)], [Vector3(47.2, 0.9, 38.6), Vector3(-0.5, 1.2, 1.4)]]:
		var tb := Basis.from_euler(spec[1]); var tp: Vector3 = spec[0]
		kit.cyl_axis("stone", tp + tb * Vector3(0, 0.36, 0), tp + tb * Vector3(0, 0.39, 0), 0.34, 12)
		kit.cyl_axis("iron", tp, tp + tb * Vector3(0, 0.36, 0), 0.025, 6)
		kit.box("iron", tp, Vector3(0.22, 0.02, 0.22), tb)
		_trail(tp, CENTER + Vector3(0, 0.8, 0), 1.8)
	# the awning: a sheet of striped canvas, rippled, frozen
	var aw := Vector3(48.5, 4.4, 40.0)
	const AN := 8
	for i in AN:
		for j in 4:
			var u0 := float(i) / AN; var u1 := float(i + 1) / AN; var v0 := float(j) / 4.0; var v1 := float(j + 1) / 4.0
			var P := func(u: float, v: float) -> Vector3:
				return aw + Vector3(-v * 1.6 - sin(u * 5.0) * 0.25, sin(u * 4.0 + v * 2.0) * 0.35 - v * 0.6, (u - 0.5) * 3.2)
			var m := "awning_red" if i % 2 == 0 else "awning_white"
			kit.quad(m, P.call(u0, v0), P.call(u1, v0), P.call(u1, v1), P.call(u0, v1), Vector3(0.3, 1, 0).normalized())
			kit.quad(m, P.call(u0, v0), P.call(u0, v1), P.call(u1, v1), P.call(u1, v0), -Vector3(0.3, 1, 0).normalized())
	# the signboard, tumbling
	var sb := Basis.from_euler(Vector3(0.4, -1.2, 0.7)); var sp := Vector3(46.3, 3.3, 44.6)
	kit.box("paint_green", sp, Vector3(0.9, 0.22, 0.03), sb)
	_trail(sp, Vector3(51.5, 3.6, 44.0), 1.4)
	_cafe_sign = Transform3D(sb, sp + sb.z * 0.035)
	for i in 70:
		var p := Vector3(47.6, 0.0, 39.5) + Vector3(rng.randf_range(-2.8, 0.4), rng.randf_range(0.6, 3.6), rng.randf_range(-1.8, 1.8))
		var b := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		var s := rng.randf_range(0.05, 0.16)
		kit.tri("glass", p + b.x * s, p + b.y * s * 1.3, p - b.x * s * 0.7 - b.y * s * 0.4, b.z)
		kit.tri("glass", p + b.x * s, p - b.x * s * 0.7 - b.y * s * 0.4, p + b.y * s * 1.3, -b.z)
	# the lamp post nearest her, bent over away from the crater
	Facades.gas_lamp(kit, CENTER + Vector3(2.6, 0, -2.4), 0.75)

var _cafe_sign := Transform3D.IDENTITY

func _chair(at: Vector3, b: Basis) -> void:
	var seat := at + b * Vector3(0, 0.45, 0)
	kit.cyl_axis("wood", seat - b.y * 0.02, seat + b.y * 0.02, 0.21, 10)
	for lx in [-0.16, 0.16]:
		for lz in [-0.16, 0.16]:
			kit.cyl_axis("wood", at + b * Vector3(lx * 1.15, 0.0, lz * 1.15), seat + b * Vector3(lx, -0.02, lz), 0.016, 5)
	for i in 9:
		var a0 := PI * i / 9.0; var a1 := PI * (i + 1) / 9.0
		kit.cyl_axis("wood", at + b * Vector3(cos(a0) * 0.18, 0.62 + sin(a0) * 0.32, -0.19), at + b * Vector3(cos(a1) * 0.18, 0.62 + sin(a1) * 0.32, -0.19), 0.014, 5)
	for sx in [-0.18, 0.18]:
		kit.cyl_axis("wood", seat + b * Vector3(sx, 0, -0.18), at + b * Vector3(sx, 0.62, -0.19), 0.015, 5)

## trick arrows from the archer's corner, stopped in flight, converging on where she hung
func _arrows(rng: RandomNumberGenerator) -> void:
	var from := ARCHER + Vector3(0, 1.5, 0)
	for i in 9:
		var target := HER + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.4), rng.randf_range(-0.3, 0.3))
		var t := rng.randf_range(0.35, 0.8)            # how far along its flight it was when it stopped
		var start := from + Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2))
		var p := start.lerp(target, t) + Vector3(0, sin(t * PI) * 0.35, 0)
		var d := (target - start).normalized()
		_arrow(p, d, ["grapnel", "bulb", "fork", "plain"][i % 4])
		_trail(p + d * 0.37, p - d * 2.2, 2.4)
	# two that went wide and stuck in the walls
	_arrow(Vector3(52.0, 3.1, 37.2) - Vector3(0.35, 0, 0), Vector3(1, -0.05, 0.25).normalized(), "plain")
	_arrow(Vector3(47.3, 5.0, 32.0) + Vector3(0, 0, 0.35), Vector3(0.25, 0.1, -1).normalized(), "fork")

func _arrow(at: Vector3, d: Vector3, head: String) -> void:
	var b := Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT)
	const L := 0.74
	kit.box("trim", at, Vector3(0.008, 0.008, L * 0.5), b)
	var tip := at - b.z * L * 0.5
	var tail := at + b.z * L * 0.5
	for k in 3:   # fletching: three vanes, red, white, red
		var ang := TAU * k / 3.0
		var v := (b.x * cos(ang) + b.y * sin(ang))
		var fn := v.cross(b.z).normalized()
		var fm := "awning_red" if k != 1 else "awning_white"
		kit.quad(fm, tail - b.z * 0.02, tail - b.z * 0.18, tail - b.z * 0.15 + v * 0.05, tail - b.z * 0.03 + v * 0.06, fn)
		kit.quad(fm, tail - b.z * 0.02, tail - b.z * 0.03 + v * 0.06, tail - b.z * 0.15 + v * 0.05, tail - b.z * 0.18, -fn)
	match head:
		"grapnel":
			for k in 3:
				var ang := TAU * k / 3.0
				var v := (b.x * cos(ang) + b.y * sin(ang))
				kit.box("iron", tip + v * 0.03 + b.z * 0.02, Vector3(0.006, 0.006, 0.045), Basis.looking_at((v - b.z * 0.6).normalized(), b.z))
			kit.box("iron", tip, Vector3(0.012, 0.012, 0.03), b)
		"bulb":
			kit.cyl("paint_green", tip - b.z * 0.0, 0.025, 0.06, 6, 0.0)
			kit.box("paint_door", tip, Vector3(0.022, 0.022, 0.04), b)
		"fork":
			for sx in [-1, 1]:
				kit.box("iron", tip - b.z * 0.025 + b.x * 0.012 * sx, Vector3(0.004, 0.004, 0.035), b * Basis(Vector3.UP, 0.25 * sx))
		_:
			kit.box("iron", tip - b.z * 0.02, Vector3(0.012, 0.004, 0.03), b)

## his mask, on the cobbles where he stood
func _mask(owner: Node3D) -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const N := 14
	var pts := []
	for i in N + 1:
		var u := float(i) / N - 0.5                     # across the face
		var w := 0.055 - absf(u) * 0.03                 # narrower at the sides
		var bend := -pow(u * 2.0, 2.0) * 0.03           # curved round a face
		var eye := absf(absf(u) - 0.18) < 0.07          # the eye holes
		pts.append([Vector3(u * 0.19, w * (0.3 if eye else 1.0), bend), Vector3(u * 0.19, -w * (0.3 if eye else 1.0), bend), eye])
	for i in N:
		var a: Array = pts[i]; var b: Array = pts[i + 1]
		if a[2] and b[2]:
			# around an eye hole: just the thin rims
			for row in [[0.65, 1.0], [-1.0, -0.65]]:
				var a0: Vector3 = a[0].lerp(a[1], 0.5); var b0: Vector3 = b[0].lerp(b[1], 0.5)
				var ha: float = (a[0] as Vector3).y / 0.3; var hb: float = (b[0] as Vector3).y / 0.3
				for v in [Vector3(a0.x, ha * row[0], a0.z), Vector3(b0.x, hb * row[0], b0.z), Vector3(b0.x, hb * row[1], b0.z), Vector3(a0.x, ha * row[0], a0.z), Vector3(b0.x, hb * row[1], b0.z), Vector3(a0.x, ha * row[1], a0.z)]:
					st.add_vertex(v)
			continue
		for v in [a[0], b[0], b[1], a[0], b[1], a[1]]:
			st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit()
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.04, 0.04, 0.045); m.roughness = 0.45; m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	owner.add_child(mi)
	mi.position = ARCHER + Vector3(0.6, 0.012, 0.9); mi.rotation = Vector3(-PI * 0.5, 0.4, 0)
	_examine(owner, mi.position + Vector3(0, 0.05, 0), Vector3(0.14, 0.06, 0.08), "Mask", "A black domino mask, the elastic perished. You turn it over. It fits your face.")

## the 1960s poster, among the Imperial bills on the wall behind where he stood
func _poster(owner: Node3D) -> void:
	var at := Vector3(32.08, 1.75, 35.35)          # the square's west wall, by the corner, beside a window
	var n := Vector3(1, 0, 0)
	var t := Vector3(0, 0, -1)
	var w := 0.55; var h := 0.8
	# bold flat colour: a red field, a yellow burst, a black silhouette of a man drawing a bow
	kit.quad("paint_door", at - t * w - Vector3(0, h, 0), at + t * w - Vector3(0, h, 0), at + t * w + Vector3(0, h, 0), at - t * w + Vector3(0, h, 0), n)
	var lines := [["THE CHAMPION'S LEAGUE", 26, 0.6, Color(0.95, 0.85, 0.3)], ["TRICKSHOT", 58, 0.35, Color(0.98, 0.95, 0.85)], ["NEVER MISSES", 22, -0.62, Color(0.95, 0.85, 0.3)]]
	for L in lines:
		var l := Label3D.new(); l.text = L[0]; l.font_size = L[1]; l.pixel_size = 0.0035
		l.modulate = L[3]; l.outline_size = 6; l.outline_modulate = Color(0.1, 0.05, 0.05)
		l.shaded = true; l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		owner.add_child(l)
		l.transform = Transform3D(Basis(t, Vector3.UP, n), at + n * 0.01 + Vector3(0, float(L[2]), 0))
	# the archer: drawn with boxes in black over the red, bow bent
	var c := at + n * 0.006
	kit.box("iron", c + Vector3(0, -0.05, 0), Vector3(0.002, 0.18, 0.045))                  # body
	kit.box("iron", c + Vector3(0, 0.17, 0), Vector3(0.002, 0.045, 0.04))                   # head
	kit.box("iron", c + Vector3(0, 0.08, -0.12), Vector3(0.002, 0.02, 0.12))                # arm out to the bow
	for i in 6:
		var a := -0.9 + i * 0.36
		kit.box("iron", c + Vector3(0, sin(a) * 0.22 + 0.08, -0.25 + cos(a) * 0.05), Vector3(0.002, 0.04, 0.01))
	_examine(owner, at, Vector3(0.05, h, w), "Poster", "Printed, in colour, on paper that wasn't made in this century. THE CHAMPION'S LEAGUE. TRICKSHOT. NEVER MISSES. The man on it is drawing a bow. You know how his shoulders feel.")

## dust in the air, not moving: a cloud of motes that hang
func _dust(owner: Node3D, rng: RandomNumberGenerator) -> void:
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.instance_count = 260
	var q := QuadMesh.new(); q.size = Vector2(0.018, 0.018)
	var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.85, 0.82, 0.75, 0.6); mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = mat; mm.mesh = q
	for i in mm.instance_count:
		var p := HER + Vector3(rng.randf_range(-5, 5), rng.randf_range(-2.2, 2.5), rng.randf_range(-5, 5))
		mm.set_instance_transform(i, Transform3D(Basis(), p))
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	owner.add_child(mi)

## the light at the middle of it: cold, still, where she was; and a sound like a held breath
func _stillness(owner: Node3D) -> void:
	var l := OmniLight3D.new(); l.name = "Stillness"
	l.light_color = Color(0.72, 0.82, 1.0); l.light_energy = 2.4; l.omni_range = 9.0; l.omni_attenuation = 1.4
	l.shadow_enabled = false; l.position = HER
	owner.add_child(l)
	var ap := AudioStreamPlayer3D.new(); ap.name = "Hum"; ap.stream = _hum(); ap.unit_size = 5.0; ap.max_distance = 22.0
	ap.volume_db = -6.0; ap.autoplay = true; ap.position = HER
	owner.add_child(ap)

static func _hum() -> AudioStreamWAV:
	const RATE := 22050
	var n := RATE * 4
	var bytes := PackedByteArray(); bytes.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		# two low tones a hair apart (they beat, slowly), a glassy overtone
		var s := sin(TAU * 55.0 * t) * 0.35 + sin(TAU * 55.25 * t) * 0.35 + sin(TAU * 880.0 * t) * 0.03 * (0.5 + 0.5 * sin(TAU * 0.25 * t))
		bytes.encode_s16(i * 2, int(s * 0.5 * 32000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.data = bytes
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_end = n
	return w

## something you can look at and read about (the right hand doesn't take it)
func _examine(owner: Node3D, at: Vector3, half: Vector3, title: String, desc: String) -> void:
	var sb := StaticBody3D.new(); sb.set_script(load("res://scripts/labyrinth/examine.gd"))
	sb.set("title", title); sb.set("desc", desc)
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = half * 2.0; cs.shape = b; sb.add_child(cs)
	owner.add_child(sb); sb.position = at
	examine_nodes.append(sb)
