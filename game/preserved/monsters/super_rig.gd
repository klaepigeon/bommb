class_name SuperRig
extends Node3D
## The Super's own body: his own skeleton, his own skin, his own way of moving. Nothing shared
## with the townspeople's rig.
##
## A very big frame with almost nothing left on it: shoulders like a yoke, ribs, hips, knees and
## elbows like knots in rope, and the skin of a much heavier man hanging off all of it in flaps
## (under the arms, off the chest, the belly, the flanks, the thighs, the neck). Naked. The top
## of the skull is gone: a rim of bone, and what's in it. A few white hairs.
##
## Rig space: +Y up, -Z forward, +X his left. Metres. He stands about 2.3 m to the rim.
##
## Bones: root > hips > spine > chest > neck > head > jaw
##        chest > clav.L/R > uarm > farm > hand > fingers
##        hips > thigh.L/R > shin > foot > toe
##        hips > penis0 > penis1            (hangs; swings with his step)
##        loose skin, each a sprung bone: flap_arm.L/R (under the upper arms), flap_chest.L/R,
##        flap_belly, flap_flank.L/R, flap_thigh.L/R, flap_neck
##
## animate(delta, ctx): ctx.speed (m/s), ctx.mode "idle" | "walk" | "hunt" | "stagger" | "grab",
## ctx.look (a point in rig space, or null), ctx.head_hit (bool, with stagger).

const PS1 := preload("res://preserved/shaders/ps1_lit.gdshader")
const HEAD_SCALE := 1.25

var skel: Skeleton3D
var mesh_inst: MeshInstance3D
var bones := {}
var _skins := {}
var _skin_mat := {}
var _rest := {}                 # bone -> rest global origin
var _phase := 0.0
var _t := 0.0
var _hunt := 0.0
var _grab := 0.0
var _stag := 0.0
var _head_hit := 0.0
var _flinch := Vector3.ZERO
var _flinch_v := Vector3.ZERO
var _springs := {}              # bone -> {a: Vector2 (x, z swing), v: Vector2, k, damp, gain}
var _last_hip := Vector3.ZERO
var _hip_v := Vector3.ZERO

func build() -> void:
	_skeleton()
	_mesh()

# ================================================================ skeleton

func _bone(n: String, parent: String, at: Vector3) -> int:
	var i := skel.get_bone_count()
	skel.add_bone(n)
	var pa := Vector3.ZERO
	if parent != "":
		skel.set_bone_parent(i, bones[parent])
		pa = _rest[bones[parent]]
	skel.set_bone_rest(i, Transform3D(Basis(), at - pa))
	skel.set_bone_pose(i, Transform3D(Basis(), at - pa))
	bones[n] = i
	_rest[i] = at
	return i

func _skeleton() -> void:
	skel = Skeleton3D.new(); skel.name = "Skeleton"
	add_child(skel)
	_bone("root", "", Vector3.ZERO)
	_bone("hips", "root", Vector3(0, 1.26, 0))
	_bone("spine", "hips", Vector3(0, 1.46, 0.01))
	_bone("chest", "spine", Vector3(0, 1.72, 0.02))
	_bone("neck", "chest", Vector3(0, 2.02, 0.0))
	_bone("head", "neck", Vector3(0, 2.13, -0.02))
	_bone("jaw", "head", Vector3(0, 2.19, -0.03))
	for sd in [["L", 1.0], ["R", -1.0]]:
		var n: String = sd[0]; var x: float = sd[1]
		_bone("clav." + n, "chest", Vector3(x * 0.1, 1.97, 0.0))
		_bone("uarm." + n, "clav." + n, Vector3(x * 0.4, 1.955, 0.0))
		_bone("farm." + n, "uarm." + n, Vector3(x * 0.43, 1.45, 0.0))
		_bone("hand." + n, "farm." + n, Vector3(x * 0.45, 0.96, -0.02))
		_bone("fingers." + n, "hand." + n, Vector3(x * 0.45, 0.76, -0.03))
		_bone("thigh." + n, "hips", Vector3(x * 0.15, 1.2, 0.0))
		_bone("shin." + n, "thigh." + n, Vector3(x * 0.16, 0.64, -0.01))
		_bone("foot." + n, "shin." + n, Vector3(x * 0.16, 0.09, 0.02))
		_bone("toe." + n, "foot." + n, Vector3(x * 0.16, 0.03, -0.2))
		_spring(_bone("flap_arm." + n, "uarm." + n, Vector3(x * 0.41, 1.86, 0.04)), 26.0, 3.2, 1.0)
		_spring(_bone("flap_chest." + n, "chest", Vector3(x * 0.13, 1.8, -0.14)), 34.0, 3.6, 0.8)
		_spring(_bone("flap_flank." + n, "spine", Vector3(x * 0.16, 1.5, 0.0)), 30.0, 3.4, 0.7)
		_spring(_bone("flap_thigh." + n, "thigh." + n, Vector3(x * 0.1, 1.12, 0.0)), 30.0, 3.4, 0.8)
	_spring(_bone("flap_belly", "spine", Vector3(0, 1.5, -0.1)), 24.0, 3.0, 1.0)
	_spring(_bone("flap_neck", "jaw", Vector3(0, 2.14, -0.09)), 40.0, 4.0, 0.6)
	_bone("penis0", "hips", Vector3(0, 1.115, -0.1))
	_spring(bones["penis0"], 22.0, 2.4, 1.2)
	_bone("penis1", "penis0", Vector3(0, 1.0, -0.115))
	_spring(bones["penis1"], 18.0, 2.2, 0.8)

func _spring(b: int, k: float, damp: float, gain: float) -> void:
	_springs[b] = {"a": Vector2.ZERO, "v": Vector2.ZERO, "k": k, "damp": damp, "gain": gain}

func bone_global(n: String) -> Transform3D:
	return skel.global_transform * skel.get_bone_global_pose(bones[n])

# ================================================================ skin

func _sk(tex: String, rough := 0.85, spec := 0.35, tint := Color.WHITE) -> InfectedBody.SkinB:
	var key := "%s/%s/%s/%s" % [tex, rough, spec, tint]
	if not _skins.has(key):
		_skins[key] = InfectedBody.SkinB.new()
		var m := ShaderMaterial.new(); m.shader = PS1
		m.set_shader_parameter("albedo_tex", texture(tex))
		m.set_shader_parameter("roughness", rough)
		m.set_shader_parameter("specular", spec)
		m.set_shader_parameter("albedo_color", tint)
		_skin_mat[key] = m
	return _skins[key]

static func _frame(d: Vector3) -> Array:
	var up := Vector3.FORWARD if absf(d.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := up.cross(d).normalized()
	return [x, d.cross(x).normalized()]

## A tube through p[], radius r[i] (x) and flat[i] (z squash) at each; segment i belongs to b[i],
## blending into its neighbours at the joints.
func _tube(sk: InfectedBody.SkinB, p: Array, r: Array, b: Array, before: int, sides := 8, rings := 3, lump := 0.12, cap_end := true) -> void:
	var grid := []
	var n := p.size() - 1
	var noise := MeshKit.noise()
	for i in n:
		var a: Vector3 = p[i]; var c: Vector3 = p[i + 1]
		var d := (c - a).normalized()
		var fr := _frame(d)
		for k in rings + (1 if i == n - 1 else 0):
			var t := float(k) / rings
			var c0 := a.lerp(c, t)
			var rad := lerpf(float(r[i]), float(r[i + 1]), t)
			var mine: int = b[i]
			var bf: int = b[i - 1] if i > 0 else before
			var af: int = b[i + 1] if i + 1 < b.size() else mine
			var wb := 0.5 * (1.0 - smoothstep(0.0, 0.3, t)) if bf >= 0 else 0.0
			var wa := 0.5 * smoothstep(0.7, 1.0, t) if af != mine else 0.0
			var w := {mine: 1.0 - wb - wa}
			if bf >= 0: w[bf] = w.get(bf, 0.0) + wb
			if wa > 0.0: w[af] = w.get(af, 0.0) + wa
			var ring := []
			for j in sides + 1:
				var th := TAU * float(j) / sides
				var o: Vector3 = fr[0] * cos(th) + fr[1] * sin(th)
				var q := c0 + o * rad * (1.0 + lump * noise.get_noise_3d(c0.x * 30.0 + th, c0.y * 30.0, c0.z * 30.0))
				ring.append(sk.add(q, Vector2(float(j) / sides, (i + t) * 0.5), w, o))
			grid.append(ring)
	for i in grid.size() - 1:
		for j in sides:
			sk.quad(grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j])
	if cap_end:
		var d := ((p[n] as Vector3) - (p[n - 1] as Vector3)).normalized()
		var w := {b[b.size() - 1]: 1.0}
		var mid := sk.add((p[n] as Vector3) + d * float(r[n]) * 0.6, Vector2(0.5, 0.5), w, d)
		var last: Array = grid.back()
		for j in sides: sk.tri(mid, last[j], last[j + 1])

## A lump: ellipsoid at c, radii r, weighted by wf(p).
func _blob(sk: InfectedBody.SkinB, c: Vector3, r: Vector3, wf: Callable, rows := 4, cols := 8, lump := 0.1, basis := Basis()) -> void:
	var noise := MeshKit.noise()
	var g := []
	for i in rows + 1:
		var ph := PI * float(i) / rows
		var row := []
		for j in cols + 1:
			var th := TAU * float(j) / cols
			var dir := Vector3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th))
			var p := c + basis * (dir * r * (1.0 + lump * noise.get_noise_3d(dir.x * 5.0 + c.x * 30.0, dir.y * 5.0 + c.y * 9.0, dir.z * 5.0)))
			row.append(sk.add(p, Vector2(float(j) / cols, float(i) / rows), wf.call(p), basis * dir))
		g.append(row)
	for i in rows:
		for j in cols:
			sk.quad(g[i][j], g[i][j + 1], g[i + 1][j + 1], g[i + 1][j])

## Loose skin: a pouch hung from `top` (a line of points fixed to `fixed`), falling `drop` to a
## rounded lower edge that belongs to the sprung bone `loose`. Empty at the top where it leaves
## the body, heaviest two thirds of the way down, and creased along its fall.
func _flap(sk: InfectedBody.SkinB, top: Array, drop: Vector3, fixed: int, loose: int, thick := 0.03, sag := 0.25, creases := 4.0) -> void:
	var noise := MeshKit.noise()
	var rows := 6
	var cols := maxi((top.size() - 1) * 3, 6)
	var out := drop.cross((top.back() as Vector3) - (top[0] as Vector3)).normalized()
	for face: float in [1.0, -1.0]:
		var g := []
		for i in rows + 1:
			var t := float(i) / rows
			var row := []
			for j in cols + 1:
				var u := float(j) / cols
				var fi := u * (top.size() - 1)
				var i0 := mini(int(fi), top.size() - 2)
				var a: Vector3 = (top[i0] as Vector3).lerp(top[i0 + 1], fi - i0)
				var len := (0.5 + 0.5 * pow(sin(u * PI), 0.6)) * (1.0 + sag * noise.get_noise_2d(a.x * 40.0 + a.y * 17.0, u * 9.0))
				var th := thick * sin(PI * pow(t, 1.5)) * pow(sin(u * PI), 0.5) * (1.0 + 0.4 * sin(u * PI * creases * 2.0 + a.y * 30.0))
				th = maxf(th, 0.0015) + 0.004 * (1.0 - t)
				var p := a + drop * t * len + out * face * th + out * 0.012 * sin(t * PI)      # it bellies out from the body
				var w := {fixed: 1.0 - t * t}
				w[loose] = float(w.get(loose, 0.0)) + t * t
				row.append(sk.add(p, Vector2(u * 0.5, 0.3 + t * 0.6), w, out * face))
			g.append(row)
		for i in rows:
			for j in cols:
				sk.quad(g[i][j], g[i][j + 1], g[i + 1][j + 1], g[i + 1][j])

func _w(names: Dictionary) -> Callable:
	var w := {}
	for k in names: w[bones[k]] = names[k]
	return func(_p): return w

## Linear keys [[s, a, b, ...], ...] read at s.
static func _key(keys: Array, s: float) -> Array:
	if s <= float(keys[0][0]): return keys[0]
	for i in keys.size() - 1:
		var a: Array = keys[i]; var b: Array = keys[i + 1]
		if s <= float(b[0]):
			var k := (s - float(a[0])) / (float(b[0]) - float(a[0]))
			k = k * k * (3.0 - 2.0 * k)
			var o := [s]
			for j in range(1, a.size()): o.append(lerpf(a[j], b[j], k))
			return o
	return keys.back()

static func _gauss(d2: float, sigma: float) -> float:
	return exp(-d2 / (2.0 * sigma * sigma))

## A limb as one skin from root to end: pts are its joints, bns the bone of each segment, prof
## the radii along it ([s, side-to-side, front-to-back], s counted in segments).
func _limb(sk: InfectedBody.SkinB, pts: Array, bns: Array, before: int, prof: Array, sides := 10, per_seg := 6) -> void:
	var noise := MeshKit.noise()
	var n := pts.size() - 1
	var grid := []
	var axis := ((pts[n] as Vector3) - (pts[0] as Vector3)).normalized()
	var ax := Vector3.RIGHT - axis * axis.dot(Vector3.RIGHT)
	ax = ax.normalized()
	var az := axis.cross(ax).normalized()            # front-to-back
	for i in n:
		for k in per_seg + (1 if i == n - 1 else 0):
			var t := float(k) / per_seg
			var c := (pts[i] as Vector3).lerp(pts[i + 1], t)
			var pr := _key(prof, i + t)
			var mine: int = bns[i]
			var bf: int = bns[i - 1] if i > 0 else before
			var af: int = bns[i + 1] if i + 1 < bns.size() else mine
			var wb := 0.5 * (1.0 - smoothstep(0.0, 0.28, t)) if bf >= 0 else 0.0
			var wa := 0.5 * smoothstep(0.72, 1.0, t) if af != mine else 0.0
			var w := {mine: 1.0 - wb - wa}
			if bf >= 0: w[bf] = float(w.get(bf, 0.0)) + wb
			if wa > 0.0: w[af] = float(w.get(af, 0.0)) + wa
			var ring := []
			for j in sides + 1:
				var th := TAU * float(j) / sides
				var o := ax * cos(th) + az * sin(th)
				var q := c + ax * cos(th) * float(pr[1]) + az * sin(th) * float(pr[2])
				q += o * 0.004 * noise.get_noise_3d(c.x * 25.0 + th * 2.0, c.y * 25.0, c.z * 25.0)
				ring.append(sk.add(q, Vector2(float(j) / sides, (i + t) * 0.5), w, o))
			grid.append(ring)
	for i in grid.size() - 1:
		for j in sides:
			sk.quad(grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j])

func _mesh() -> void:
	var skin := _sk("super_skin", 0.72, 0.4)
	var slack := _sk("super_slack", 0.85, 0.25)
	var raw := _sk("raw", 0.3, 0.7, Color(0.5, 0.4, 0.4))
	var bone := _sk("bone", 0.6, 0.4)
	var hair := _sk("super_hair", 1.0, 0.05)
	var dark := _sk("super_dark", 0.8, 0.35)
	var noise := MeshKit.noise()
	# ---- the trunk, one skin: a cage of ribs on a pelvis, and not much between them.
	# y, half-width, depth to the front, depth to the back
	var lv := [[1.04, 0.09, 0.08, 0.08], [1.12, 0.175, 0.1, 0.115], [1.22, 0.225, 0.105, 0.125], [1.3, 0.2, 0.09, 0.11],
		[1.38, 0.15, 0.062, 0.095], [1.48, 0.15, 0.058, 0.1], [1.56, 0.21, 0.125, 0.12], [1.66, 0.255, 0.165, 0.14],
		[1.78, 0.285, 0.175, 0.165], [1.88, 0.315, 0.155, 0.18], [1.93, 0.33, 0.13, 0.165], [1.97, 0.3, 0.1, 0.14], [2.0, 0.2, 0.082, 0.11],
		[2.03, 0.1, 0.074, 0.085], [2.06, 0.078, 0.07, 0.078], [2.13, 0.072, 0.066, 0.07]]
	var chain := [bones.hips, bones.spine, bones.chest, bones.neck, bones.head]
	var ys := [1.26, 1.46, 1.72, 2.02, 2.13]
	var tw := func(y: float) -> Dictionary:
		for i in ys.size() - 1:
			if y <= float(ys[i]): return {chain[i]: 1.0}
			if y < float(ys[i + 1]):
				var k := (y - float(ys[i])) / (float(ys[i + 1]) - float(ys[i]))
				return {chain[i]: 1.0 - k, chain[i + 1]: k}
		return {chain.back(): 1.0}
	var levels := []
	var y := 1.04
	while y < 2.131:
		levels.append(y)
		y += 0.016 if (y > 1.52 and y < 1.9) else 0.034        # closer rings where the ribs are
	var sides := 18
	var trunk := []
	const RIB := 0.064
	for ly: float in levels:
		var kf := _key(lv, ly)
		var ring := []
		for j in sides + 1:
			var th := TAU * float(j) / sides
			var cx := cos(th); var sz := sin(th)              # sz < 0: his front
			var px := float(kf[1]) * signf(cx) * pow(absf(cx), 0.8)
			var pz := (float(kf[2]) if sz < 0.0 else float(kf[3])) * signf(sz) * pow(absf(sz), 0.8)
			var o := Vector3(cx, 0, sz)
			var d := 0.0
			# the ribs: down and round from the spine, standing out of him; a groove up the breastbone
			if ly > 1.53 and ly < 1.9:
				var edge := smoothstep(1.53, 1.58, ly) * smoothstep(1.9, 1.84, ly)
				var off_spine := 1.0 - smoothstep(0.8, 0.98, sz)
				d += 0.011 * sin(TAU * (ly + 0.22 * absf(px) + 0.1 * maxf(0.0, -sz)) / RIB) * edge * off_spine
				if sz < -0.9: d -= 0.01 * edge
			# the knuckles of the spine, all the way up
			if sz > 0.96: d += 0.013 * maxf(0.0, sin(TAU * ly / 0.068)) + 0.006
			# shoulder blades like plates under the skin
			d += 0.03 * _gauss(pow(absf(px) - 0.17, 2.0) * 8.0 + pow(ly - 1.8, 2.0), 0.075) * maxf(0.0, sz)
			# the points of the hips; the hollow between them and the ribs
			d += 0.03 * _gauss(pow(absf(cx) - 0.8, 2.0) * 0.02 + pow(ly - 1.25, 2.0), 0.035) * maxf(0.0, -sz + 0.2)
			# collarbones: a shelf across the top of the chest, a pit above each
			if sz < -0.2: d += 0.008 * _gauss(pow(ly - 1.972 + 0.03 * absf(cx), 2.0), 0.012) - 0.012 * _gauss(pow(ly - 2.0, 2.0) + pow(absf(cx) - 0.5, 2.0) * 0.01, 0.014)
			d += 0.004 * noise.get_noise_3d(cx * 3.0, ly * 14.0, sz * 3.0)
			ring.append(skin.add(Vector3(px, ly, pz + 0.01) + o * d, Vector2(float(j) / sides, ly * 0.9), tw.call(ly), o))
		trunk.append(ring)
	for i in trunk.size() - 1:
		for j in sides: skin.quad(trunk[i][j], trunk[i][j + 1], trunk[i + 1][j + 1], trunk[i + 1][j])
	var under := skin.add(Vector3(0, 1.0, 0), Vector2(0.5, 0.5), {bones.hips: 1.0}, Vector3.DOWN)
	for j in sides: skin.tri(under, trunk[0][j], trunk[0][j + 1])
	# ---- arms and legs
	for sd in [["L", 1.0], ["R", -1.0]]:
		var n: String = sd[0]; var x: float = sd[1]
		var ua: int = bones["uarm." + n]; var fa: int = bones["farm." + n]; var ha: int = bones["hand." + n]; var fi: int = bones["fingers." + n]
		# the arm: a cap of shoulder, a wasted upper arm, the elbow, cords down the forearm, a flat wrist
		_limb(skin, [_rest[ua] + Vector3(-x * 0.07, 0.01, 0), _rest[fa], _rest[ha]], [ua, fa], bones.chest,
			[[0.0, 0.06, 0.07], [0.06, 0.085, 0.09], [0.13, 0.088, 0.092], [0.25, 0.07, 0.078], [0.45, 0.05, 0.056], [0.75, 0.044, 0.05], [0.93, 0.058, 0.066],
			[1.02, 0.06, 0.07], [1.12, 0.055, 0.058], [1.35, 0.052, 0.046], [1.7, 0.04, 0.034], [1.92, 0.046, 0.03], [2.0, 0.05, 0.03]])
		_blob(skin, _rest[ua] + Vector3(-x * 0.045, 0.0, 0.0), Vector3(0.07, 0.055, 0.07), _w({"chest": 0.55, "uarm." + n: 0.45}), 5, 8, 0.05)      # the knob of the shoulder, under the skin
		# a hand like a spade: long bones under the skin, knuckles, nails gone yellow
		var hp: Vector3 = _rest[ha]
		_limb(skin, [hp + Vector3(0, 0.01, 0), hp + Vector3(0, -0.14, -0.01)], [ha], fa, [[0.0, 0.03, 0.05], [0.4, 0.026, 0.07], [0.85, 0.024, 0.074], [1.0, 0.018, 0.066]], 8, 4)
		for f in 4:
			var fz := -0.058 + f * 0.036
			var fl := 0.15 - absf(f - 1.4) * 0.018
			var a := hp + Vector3(0, -0.14, fz)
			_blob(skin, a, Vector3(0.019, 0.02, 0.02), _w({"hand." + n: 1.0}), 2, 5, 0.0)                       # knuckle
			_tube(skin, [a, a + Vector3(0, -fl * 0.45, 0.0), a + Vector3(-x * 0.01, -fl * 0.78, 0.004), a + Vector3(-x * 0.022, -fl, 0.008)], [0.016, 0.013, 0.012, 0.008], [ha, fi, fi], -1, 6, 1, 0.0)
			_blob(skin, a + Vector3(0, -fl * 0.45, 0), Vector3(0.0165, 0.016, 0.017), _w({"hand." + n: 0.4, "fingers." + n: 0.6}), 2, 5, 0.0)
			_blob(bone, a + Vector3(-x * 0.026, -fl + 0.012, 0.008), Vector3(0.004, 0.014, 0.008), _w({"fingers." + n: 1.0}), 2, 4, 0.0)   # nail
		var t0 := hp + Vector3(0, -0.035, -0.06)
		_tube(skin, [t0, t0 + Vector3(0, -0.055, -0.04), t0 + Vector3(0, -0.11, -0.055), t0 + Vector3(-x * 0.01, -0.145, -0.055)], [0.022, 0.018, 0.014, 0.009], [ha, ha, ha], -1, 6, 1, 0.0)
		# the leg: all knee
		var th: int = bones["thigh." + n]; var sh: int = bones["shin." + n]; var fo: int = bones["foot." + n]; var to: int = bones["toe." + n]
		_limb(skin, [_rest[th] + Vector3(0, 0.06, 0), _rest[sh], _rest[fo]], [th, sh], bones.hips,
			[[0.0, 0.09, 0.1], [0.15, 0.088, 0.096], [0.5, 0.066, 0.076], [0.82, 0.058, 0.066], [0.95, 0.074, 0.086], [1.03, 0.072, 0.082],
			[1.15, 0.056, 0.064], [1.4, 0.052, 0.072], [1.75, 0.04, 0.046], [1.93, 0.046, 0.052], [2.0, 0.05, 0.06]])
		_blob(skin, _rest[sh] + Vector3(0, 0.005, -0.06), Vector3(0.042, 0.05, 0.03), _w({"thigh." + n: 0.5, "shin." + n: 0.5}), 3, 6, 0.05)   # kneecap
		# a long flat foot, the tendons and the big toe
		var fp: Vector3 = _rest[fo]
		_limb(skin, [fp + Vector3(0, -0.035, 0.09), fp + Vector3(0, -0.045, -0.1), _rest[to] + Vector3(0, 0.0, -0.09)], [fo, to], sh,
			[[0.0, 0.04, 0.036], [0.25, 0.056, 0.05], [0.8, 0.066, 0.04], [1.0, 0.07, 0.03], [1.6, 0.068, 0.022], [2.0, 0.05, 0.014]], 8, 4)
		for tz in 4:
			_blob(skin, _rest[to] + Vector3(x * (0.045 - tz * 0.03), 0.0, -0.1 - (0.012 if tz == 0 else 0.0)), Vector3(0.016 if tz > 0 else 0.022, 0.014, 0.024), _w({"toe." + n: 1.0}), 2, 5, 0.0)
		# ---- the skin of a much bigger man, hanging
		var fl_a: int = bones["flap_arm." + n]
		var ue: Vector3 = _rest[ua]; var el: Vector3 = _rest[fa]
		_flap(slack, [ue + Vector3(-x * 0.04, -0.07, 0.045), ue.lerp(el, 0.3) + Vector3(0, 0, 0.055), ue.lerp(el, 0.65) + Vector3(0, 0, 0.05), el + Vector3(0, 0.02, 0.05)],
			Vector3(-x * 0.03, -0.3, 0.08), ua, fl_a, 0.034, 0.25, 3.0)
		var fl_c: int = bones["flap_chest." + n]
		_flap(slack, [Vector3(x * 0.02, 1.8, -0.165), Vector3(x * 0.1, 1.79, -0.175), Vector3(x * 0.19, 1.8, -0.16), Vector3(x * 0.27, 1.84, -0.1)],
			Vector3(x * 0.02, -0.31, -0.02), bones.chest, fl_c, 0.05, 0.15, 2.0)
		_blob(dark, Vector3(x * 0.135, 1.535, -0.215), Vector3(0.02, 0.026, 0.014), func(_p): return {fl_c: 1.0}, 3, 6, 0.0)      # nipple, at the bottom of it
		var fl_f: int = bones["flap_flank." + n]
		_flap(slack, [Vector3(x * 0.2, 1.57, -0.1), Vector3(x * 0.235, 1.55, -0.02), Vector3(x * 0.22, 1.55, 0.07), Vector3(x * 0.14, 1.56, 0.125)],
			Vector3(x * 0.04, -0.3, 0.0), bones.spine, fl_f, 0.045, 0.2, 3.0)
		_flap(slack, [Vector3(x * 0.03, 1.5, 0.125), Vector3(x * 0.1, 1.5, 0.13), Vector3(x * 0.18, 1.5, 0.11)],
			Vector3(0, -0.2, 0.04), bones.spine, fl_f, 0.04, 0.2, 2.0)                                                            # a roll across the small of the back
		var fl_t: int = bones["flap_thigh." + n]
		_flap(slack, [Vector3(x * 0.06, 1.12, -0.07), Vector3(x * 0.07, 1.1, -0.01), Vector3(x * 0.08, 1.1, 0.05), Vector3(x * 0.12, 1.11, 0.1)],
			Vector3(-x * 0.012, -0.32, 0.0), th, fl_t, 0.036, 0.2, 3.0)
		_flap(slack, [Vector3(x * 0.03, 1.15, 0.13), Vector3(x * 0.1, 1.17, 0.145), Vector3(x * 0.17, 1.17, 0.135), Vector3(x * 0.22, 1.18, 0.09)],
			Vector3(0, -0.25, 0.03), bones.hips, fl_t, 0.05, 0.2, 2.0)                                                           # the backside, emptied
	# the belly: an apron with nothing in it, hung from under the ribs. It stops above the hips.
	var fb: int = bones.flap_belly
	_flap(slack, [Vector3(-0.19, 1.54, -0.1), Vector3(-0.1, 1.52, -0.125), Vector3(0, 1.515, -0.13), Vector3(0.1, 1.52, -0.125), Vector3(0.19, 1.54, -0.1)],
		Vector3(0, -0.27, -0.03), bones.spine, fb, 0.055, 0.15, 3.0)
	_blob(dark, Vector3(0, 1.36, -0.175), Vector3(0.014, 0.026, 0.01), func(_p): return {fb: 0.7, bones.spine: 0.3}, 2, 5, 0.0)       # navel, pulled long
	# ---- between his legs, in plain sight: nothing hangs over it
	var p0: int = bones.penis0; var p1: int = bones.penis1
	var pa: Vector3 = _rest[p0]; var pb: Vector3 = _rest[p1]
	_blob(hair, pa + Vector3(0, 0.05, 0.012), Vector3(0.07, 0.04, 0.016), _w({"hips": 1.0}), 3, 6, 0.5)
	_blob(dark, pa + Vector3(-0.03, -0.115, 0.04), Vector3(0.042, 0.085, 0.045), _w({"penis0": 0.8, "hips": 0.2}), 4, 7, 0.1)
	_blob(dark, pa + Vector3(0.032, -0.09, 0.04), Vector3(0.04, 0.068, 0.043), _w({"penis0": 0.8, "hips": 0.2}), 4, 7, 0.1)
	var pe := pb + Vector3(0, -0.1, -0.008)
	_limb(skin, [pa + Vector3(0, 0.02, 0.005), pb, pe], [p0, p1], bones.hips, [[0.0, 0.032, 0.03], [1.0, 0.03, 0.029], [1.7, 0.029, 0.029], [2.0, 0.026, 0.026]], 8, 3)
	_blob(dark, pe + Vector3(0, -0.012, 0), Vector3(0.031, 0.036, 0.031), _w({"penis1": 1.0}), 4, 7, 0.03)
	var before := {}
	for key in _skins: before[key] = (_skins[key] as InfectedBody.SkinB).v.size()
	_head(skin, slack, raw, bone, hair, dark)
	# a head too big for the neck it's on
	const PIVOT := Vector3(0, 2.12, -0.02)
	for key in _skins:
		var sb: InfectedBody.SkinB = _skins[key]
		for i in range(int(before.get(key, 0)), sb.v.size()):
			sb.v[i] = PIVOT + (sb.v[i] - PIVOT) * HEAD_SCALE
	var m := ArrayMesh.new()
	for key in _skins: (_skins[key] as InfectedBody.SkinB).commit(m, _skin_mat[key])
	mesh_inst = MeshInstance3D.new(); mesh_inst.name = "Body"; mesh_inst.mesh = m
	skel.add_child(mesh_inst)
	mesh_inst.skeleton = NodePath("..")
	mesh_inst.extra_cull_margin = 1.0

## The head, one skin, shaped: brow, sockets, cheekbones over hollows, a long nose, a long jaw.
## The top of the skull is gone from his left temple across (the hole's lower on that side).
func _head(skin: InfectedBody.SkinB, slack: InfectedBody.SkinB, raw: InfectedBody.SkinB, bone: InfectedBody.SkinB, hair: InfectedBody.SkinB, dark: InfectedBody.SkinB) -> void:
	var hb: int = bones.head; var jb: int = bones.jaw
	var c := Vector3(0, 2.235, -0.035)
	var r := Vector3(0.124, 0.158, 0.148)
	var jaw_line := 2.165
	var wf := func(p: Vector3) -> Dictionary:
		var k := smoothstep(jaw_line + 0.012, jaw_line - 0.03, p.y) * smoothstep(c.z + 0.05, c.z - 0.04, p.z)
		return {hb: 1.0 - k, jb: k}
	var noise := MeshKit.noise()
	var face := _sk("super_face", 0.72, 0.4)
	# what's been done to the ball it starts as: [direction, spread, how far out (+) or in (-)]
	var marks := [
		[Vector3(0.36, 0.1, -0.93), 0.15, -0.036], [Vector3(-0.36, 0.1, -0.93), 0.15, -0.036],          # eye sockets
		[Vector3(0.3, 0.3, -0.9), 0.16, 0.014], [Vector3(-0.3, 0.3, -0.9), 0.16, 0.014], [Vector3(0, 0.27, -0.96), 0.14, 0.008],   # brow
		[Vector3(0, -0.0, -1.0), 0.09, 0.012], [Vector3(0, -0.2, -0.98), 0.075, 0.026],                 # the nose: bridge, end
		[Vector3(0.62, -0.1, -0.78), 0.15, 0.016], [Vector3(-0.62, -0.1, -0.78), 0.15, 0.016],          # cheekbones
		[Vector3(0.6, -0.48, -0.64), 0.2, -0.02], [Vector3(-0.6, -0.48, -0.64), 0.2, -0.02],            # the hollows under them
		[Vector3(0.93, 0.18, -0.3), 0.2, -0.014], [Vector3(-0.93, 0.18, -0.3), 0.2, -0.014],            # temples
		[Vector3(0, -0.47, -0.88), 0.11, 0.012],                                                        # the mouth's muzzle
		[Vector3(0, -0.8, -0.6), 0.3, 0.022], [Vector3(0.62, -0.62, -0.3), 0.28, 0.026], [Vector3(-0.62, -0.62, -0.3), 0.28, 0.026],   # a square jaw, still                                                          # chin
		[Vector3(0, -0.2, 0.98), 0.3, 0.012],                                                           # the back of the skull
	]
	var rows := 12; var cols := 16
	var g := []
	for i in rows + 1:
		var ph := PI * float(i) / rows
		var row := []
		for j in cols + 1:
			var th := TAU * float(j) / cols
			var dir := Vector3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th))
			var d := 0.0
			for mk in marks:
				d += float(mk[2]) * _gauss((dir - (mk[0] as Vector3).normalized()).length_squared(), float(mk[1]))
			var p := c + dir * r + dir * d + dir * 0.003 * noise.get_noise_3d(dir.x * 5.0, dir.y * 5.0 + 7.0, dir.z * 5.0)
			# narrower below the cheekbones: a long horse's jaw
			if dir.y < -0.15: p.x *= lerpf(1.0, 0.96, smoothstep(-0.15, -0.8, dir.y))
			var cut := 0.56 - 0.24 * dir.x + 0.06 * dir.z           # where the skull stops: he keeps his forehead
			if dir.y > cut:
				var k := (dir.y - cut) / (1.0 - cut)
				var rim := 0.02 * noise.get_noise_3d(dir.x * 9.0, 3.0, dir.z * 9.0)
				p = Vector3(c.x + dir.x * r.x * (1.0 - k * 0.62), c.y + r.y * (cut + 0.02 - k * 0.42) + rim * (1.0 - k), c.z + dir.z * r.z * (1.0 - k * 0.62))
			row.append(face.add(p, Vector2(float(j) / cols, float(i) / rows), wf.call(p), dir))
		g.append(row)
	for i in rows:
		for j in cols: face.quad(g[i][j], g[i][j + 1], g[i + 1][j + 1], g[i + 1][j])
	var hw := func(_p): return {hb: 1.0}
	var jw := func(_p): return {jb: 1.0}
	# in the hole
	_blob(raw, c + Vector3(0.012, r.y * 0.36, 0.0), Vector3(r.x * 0.6, r.y * 0.13, r.z * 0.6), hw, 4, 10, 0.35, Basis(Vector3.BACK, -0.22))
	for i: int in [0, 1, 3, 4, 6, 8, 9, 11, 13]:
		var a := TAU * i / 15.0 + 0.3
		var cutr := 0.56 - 0.24 * cos(a) + 0.06 * sin(a)
		_blob(bone, c + Vector3(cos(a) * r.x * 0.88, r.y * (cutr - 0.02), sin(a) * r.z * 0.88), Vector3(0.014, 0.005 + 0.011 * absf(sin(a * 2.3)), 0.007), hw, 2, 5, 0.0, Basis(Vector3.UP, -a))
	var black := _sk("black", 1.0, 0.0)
	var eye := _sk("eye", 0.25, 0.9)
	for sx: float in [-1.0, 1.0]:
		_blob(_sk("super_eye", 0.2, 0.9), c + Vector3(sx * 0.043, 0.016, -r.z * 0.775), Vector3(0.011, 0.008, 0.008), hw, 4, 7, 0.0)     # a small wet eye a long way in
		# ears, grown long
		_blob(skin, c + Vector3(sx * r.x * 0.97, -0.012, 0.012), Vector3(0.012, 0.056, 0.032), hw, 4, 6, 0.0, Basis(Vector3.UP, sx * 0.3))
		_flap(slack, [Vector3(sx * 0.035, jaw_line - 0.01, c.z - 0.11), Vector3(sx * 0.065, jaw_line - 0.005, c.z - 0.085), Vector3(sx * 0.085, jaw_line + 0.005, c.z - 0.04)],
			Vector3(0, -0.085, 0.01), jb, bones.flap_neck, 0.026, 0.2, 1.0)                                       # jowls
		# what hair he has: a thin white fringe lying on the skull, round the sides and the back
		for hz: float in [0.2, 0.5, 0.8, 1.0]:
			var ha := hz * PI * 0.5
			_blob(hair, c + Vector3(sx * r.x * cos(ha) * 0.97, 0.0 - 0.02 * hz, r.z * sin(ha) * 0.97), Vector3(0.012, 0.06 + 0.02 * hz, 0.045), hw, 3, 6, 0.4, Basis(Vector3.UP, -sx * ha))
	# the mouth: hanging open, dark, not many teeth
	_blob(black, Vector3(0, jaw_line - 0.002, c.z - r.z * 0.74), Vector3(0.026, 0.01, 0.03), func(_p): return {hb: 0.5, jb: 0.5}, 3, 8, 0.0)
	var teeth := _sk("teeth", 0.5, 0.6)
	for i: int in [0, 1, 3, 4, 6]:
		var x := (float(i) / 6.0 - 0.5) * 0.06
		var z := c.z - r.z * 0.94 + absf(x) * 0.6
		_blob(teeth, Vector3(x, jaw_line - 0.014, z), Vector3(0.007, 0.012, 0.006), jw, 2, 5, 0.0)
		if i % 3 != 1:
			_blob(teeth, Vector3(x + 0.005, jaw_line + 0.012, z + 0.002), Vector3(0.007, 0.01, 0.006), hw, 2, 5, 0.0)
	# the neck: two cords and a windpipe, and the wattle under the jaw
	for sx: float in [-1.0, 1.0]:
		_tube(skin, [Vector3(sx * 0.07, 2.16, 0.02), Vector3(sx * 0.045, 2.06, -0.04), Vector3(sx * 0.02, 1.985, -0.085)], [0.016, 0.014, 0.012], [bones.neck, bones.neck], -1, 5, 2, 0.0, false)
	_blob(skin, Vector3(0, 2.075, -0.068), Vector3(0.02, 0.03, 0.022), _w({"neck": 1.0}), 3, 5, 0.0)
	var fn: int = bones.flap_neck
	_flap(slack, [Vector3(-0.05, 2.135, -0.115), Vector3(0, 2.125, -0.14), Vector3(0.05, 2.135, -0.115)], Vector3(0, -0.2, 0.05), jb, fn, 0.03, 0.2, 2.0)

# ---- his skin: not the townspeople's. Old, thin, blotched, veined; the hanging skin creased.
static var _tex := {}
static func texture(name: String) -> Texture2D:
	if _tex.has(name): return _tex[name]
	if not name.begins_with("super_"):
		return InfectedTextures.get_tex(name)
	var mott := FastNoiseLite.new(); mott.seed = 51; mott.frequency = 0.035; mott.fractal_octaves = 3
	var vein := FastNoiseLite.new(); vein.seed = 52; vein.frequency = 0.03; vein.fractal_octaves = 2
	var spot := FastNoiseLite.new(); spot.seed = 53; spot.noise_type = FastNoiseLite.TYPE_CELLULAR; spot.frequency = 0.11
	var fine := FastNoiseLite.new(); fine.seed = 54; fine.frequency = 0.22; fine.fractal_octaves = 1
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var col: Color
			match name:
				"super_face":
					# u: round the head (0.75 is the middle of his face), v: crown to chin
					col = (texture("super_skin") as ImageTexture).get_image().get_pixel(x, y)
					var u := (x / 128.0 - 0.75) * 4.0            # -1 .. 1 across the face
					var v := y / 128.0
					if absf(u) < 1.2:
						var au := absf(u)
						# the sockets: bruise-dark, deepest at the inner corners
						col = col.lerp(Color(0.2, 0.12, 0.16), 0.85 * _gauss(pow(au - 0.42, 2.0) + pow((v - 0.46) * 3.2, 2.0), 0.16))
						# the lines of his forehead, and between the brows
						if v > 0.3 and v < 0.41 and au < 0.85 and int(y) % 3 == 0: col = col.darkened(0.3)
						if au < 0.07 and v > 0.4 and v < 0.47: col = col.darkened(0.3)
						# under the cheekbones; from the nose to the corners of the mouth
						col = col.lerp(Color(0.34, 0.24, 0.26), 0.55 * _gauss(pow(au - 0.62, 2.0) + pow((v - 0.6) * 2.4, 2.0), 0.14))
						if absf(au - (0.16 + (v - 0.54) * 1.5)) < 0.03 and v > 0.54 and v < 0.69: col = col.darkened(0.4)
						# the nose's shadow and nostrils; the mouth, lipless, and the cracks round it
						if absf(au - 0.1) < 0.025 and v > 0.47 and v < 0.585: col = col.darkened(0.3)                # the sides of the nose
						if au > 0.03 and au < 0.1 and v > 0.575 and v < 0.592: col = Color(0.1, 0.05, 0.06)           # nostrils
						if au < 0.3 and absf(v - 0.648 - au * au * 0.12) < 0.007: col = Color(0.14, 0.07, 0.08)      # turned down at the corners
						if au < 0.4 and v > 0.62 and v < 0.7 and int(x) % 3 == 0: col = col.darkened(0.22)
						# liver spots across the temples
						if au > 0.75 and au < 1.15 and spot.get_noise_2d(x * 2.0, y * 2.0) < -0.7: col = col.lerp(Color(0.4, 0.26, 0.2), 0.7)
				"super_eye":
					var e := Vector2(x - 64, y - 64).length()
					col = Color(0.62, 0.6, 0.5).lerp(Color(0.72, 0.76, 0.8), smoothstep(34.0, 10.0, e))       # filmed over: no pupil to speak of
				"super_hair":
					col = Color(0.62, 0.62, 0.6).lerp(Color(0.4, 0.4, 0.39), absf(sin(x * 1.9 + fine.get_noise_2d(x, y * 0.2) * 3.0)) * 0.7)
				_:
					var b := mott.get_noise_2d(x, y) * 0.5 + 0.5
					col = Color(0.74, 0.63, 0.57).lerp(Color(0.86, 0.79, 0.72), smoothstep(0.25, 0.8, b))
					# where the blood's pooled and where it's gone: violet low down in the blotches, grey-yellow elsewhere
					col = col.lerp(Color(0.52, 0.4, 0.5), smoothstep(0.62, 0.95, 1.0 - b) * 0.55)
					col = col.lerp(Color(0.78, 0.74, 0.55), smoothstep(0.7, 1.0, b) * 0.3)
					var v := absf(vein.get_noise_2d(x * 1.3, y * 0.8))
					if v < 0.035: col = col.lerp(Color(0.36, 0.42, 0.56), 0.55 * (1.0 - v / 0.035))
					var s := spot.get_noise_2d(x, y)
					if s < -0.82: col = col.lerp(Color(0.42, 0.28, 0.2), 0.75)          # liver spots
					col = col.darkened(0.06 * (fine.get_noise_2d(x, y) * 0.5 + 0.5))
					if name == "super_slack":
						# creases down the fall of it, thin skin with the light half through it
						var cr := absf(sin(x * 0.55 + mott.get_noise_2d(x * 2.0, y * 0.3) * 4.0))
						col = col.lerp(Color(0.5, 0.36, 0.38), smoothstep(0.75, 1.0, cr) * 0.6)
						col = col.lerp(Color(0.8, 0.62, 0.6), 0.15)
					elif name == "super_dark":
						col = col.lerp(Color(0.45, 0.3, 0.33), 0.65)
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	_tex[name] = ImageTexture.create_from_image(img)
	return _tex[name]

# ================================================================ moving

func _q(e: Vector3) -> Quaternion:
	return Quaternion.from_euler(e)

func _pose(n: String, e: Vector3) -> void:
	skel.set_bone_pose_rotation(bones[n], _q(e))

func flinch(from_dir: Vector3, k := 1.0, head := false) -> void:
	var local := global_transform.basis.inverse() * from_dir
	_flinch_v += Vector3(local.z * 5.0, 0.0, -local.x * 5.0) * k
	_head_hit = 1.0 if head else 0.0

func animate(delta: float, ctx: Dictionary) -> void:
	_t += delta
	var speed: float = ctx.get("speed", 0.0)
	var mode: String = ctx.get("mode", "idle")
	var moving := clampf(speed / 0.6, 0.0, 1.0)
	_hunt = move_toward(_hunt, 1.0 if mode in ["hunt", "grab"] else 0.0, delta * 1.6)
	_grab = move_toward(_grab, 1.0 if mode == "grab" else 0.0, delta * 3.0)
	_stag = move_toward(_stag, 1.0 if mode == "stagger" else 0.0, delta * (6.0 if mode == "stagger" else 1.4))
	if mode != "stagger":
		_head_hit = move_toward(_head_hit, 0.0, delta * 1.2)
	# a long slow stride: each foot down is one of the thuds you hear
	_phase += speed * delta * PI / 0.95
	var ph := _phase
	var breath := sin(_t * 1.5)
	# flinch: a sprung lean away from what hit him
	_flinch_v += (-_flinch * 30.0 - _flinch_v * 5.0) * delta
	_flinch += _flinch_v * delta
	# ---- hips: the drop onto each foot, the roll over it
	var hip_p := Vector3(sin(ph) * 0.035 * moving, -absf(cos(ph)) * 0.05 * moving - 0.02 - _stag * 0.16 - _hunt * 0.05, 0.0)
	var hip_r := Vector3(-0.06 - _hunt * 0.12, sin(ph) * 0.12 * moving, sin(ph) * 0.05 * moving) + _flinch * 0.5
	skel.set_bone_pose_position(bones.hips, skel.get_bone_rest(bones.hips).origin + hip_p)
	_pose("hips", hip_r)
	# ---- the back: bent like a hook, his head carried out in front of him
	var sway := sin(_t * 0.6) * 0.02 * (1.0 - moving)
	_pose("spine", Vector3(-0.2 - _hunt * 0.12 + breath * 0.012 + _stag * 0.28 * (1.0 - _head_hit), -sin(ph) * 0.1 * moving, sway - sin(ph) * 0.04 * moving) + _flinch * 0.8)
	_pose("chest", Vector3(-0.3 - _hunt * 0.1 + breath * 0.02 - _stag * 0.2 * _head_hit, -sin(ph) * 0.08 * moving, sway) + _flinch * 0.6)
	var neck := Vector3(0.1 + _hunt * 0.16, 0, 0)
	var head := Vector3(0.06 + _hunt * 0.22, 0, 0.1 + sin(_t * 0.37) * 0.04)
	var look = ctx.get("look")
	if look != null and _stag < 0.5:
		var hp: Vector3 = skel.get_bone_global_pose(bones.head).origin
		var d: Vector3 = (look as Vector3) - hp
		var yaw := clampf(atan2(-d.x, -d.z), -1.1, 1.1)
		var pitch := clampf(atan2(d.y, Vector2(d.x, d.z).length()), -0.8, 0.5)
		neck.y += yaw * 0.4; head.y += yaw * 0.6
		head.x += pitch * 0.7
	# shot in what's left of his head: it goes back and round, and comes back slowly
	head += Vector3(0.7, 0.5 * sin(_t * 9.0) * 0.3, 0.35) * _stag * _head_hit
	neck += Vector3(0.3, 0, 0.15) * _stag * _head_hit
	_pose("neck", neck + _flinch * 0.5)
	_pose("head", head + _flinch)
	_pose("jaw", Vector3(-(0.22 + 0.05 * breath + 0.3 * _grab + 0.35 * _stag), 0, 0.04))
	# ---- legs
	for sd in [["L", 0.0, 1.0], ["R", PI, -1.0]]:
		var n: String = sd[0]; var p: float = ph + float(sd[1]); var x: float = sd[2]
		var swing := sin(p) * 0.46 * moving
		var lift := maxf(0.0, cos(p)) * moving          # the knee comes up as the leg comes through
		var buckle := _stag * 0.35 + _hunt * 0.12
		_pose("thigh." + n, Vector3(swing + lift * 0.3 + 0.07 + buckle, 0, x * 0.03))
		_pose("shin." + n, Vector3(-(0.1 + lift * 0.75 + maxf(0.0, -sin(p)) * 0.12 * moving) - buckle * 1.6, 0, 0))
		_pose("foot." + n, Vector3(-swing * 0.35 + lift * 0.25 + buckle * 0.7, 0, 0))
		_pose("toe." + n, Vector3(maxf(0.0, -sin(p)) * 0.35 * moving, 0, 0))
	# ---- arms: hanging nearly to his knees; out in front when he's after someone
	for sd in [["L", PI, 1.0], ["R", 0.0, -1.0]]:
		var n: String = sd[0]; var p: float = ph + float(sd[1]); var x: float = sd[2]
		var swing := sin(p) * 0.22 * moving
		var reach := _hunt * (1.15 + 0.1 * sin(_t * 1.3 + x)) + _grab * 0.4
		var guard := _stag * _head_hit                 # his hands come up to his head
		_pose("clav." + n, Vector3(0, 0, x * (0.05 * breath + 0.12 * reach + 0.2 * guard)))
		_pose("uarm." + n, Vector3(0.22 + swing + reach + guard * 1.9 - _stag * (1.0 - _head_hit) * 0.3, 0, x * (0.1 - _grab * 0.22 + _stag * 0.25 - guard * 0.3)))
		_pose("farm." + n, Vector3(0.28 + maxf(0.0, swing) * 0.5 + reach * 0.35 + _grab * 0.5 + guard * 1.3, 0, 0))
		_pose("hand." + n, Vector3(0.1 - reach * 0.35, x * -0.3, 0))
		_pose("fingers." + n, Vector3(0.45 - _hunt * 0.35 + _grab * 0.9 + sin(_t * 2.1 + x) * 0.06, 0, 0))
	# ---- what hangs: loose skin and the rest, swung by how the hips move
	var hip_now: Vector3 = skel.get_bone_global_pose(bones.hips).origin
	var hv := (hip_now - _last_hip) / maxf(delta, 0.001)
	var acc := (hv - _hip_v) / maxf(delta, 0.001)
	_hip_v = hv; _last_hip = hip_now
	acc = acc.limit_length(14.0)
	var gait := Vector2(cos(ph * 2.0) * 0.5, cos(ph) * 0.9) * moving * (1.0 + speed)
	for b in _springs:
		var sp: Dictionary = _springs[b]
		var a: Vector2 = sp.a; var v: Vector2 = sp.v
		var push := Vector2(-acc.z, acc.x) * 0.06 * float(sp.gain) + gait * 2.2 * float(sp.gain) + Vector2(_flinch_v.x, _flinch_v.z) * 0.6
		v += (push - a * float(sp.k) - v * float(sp.damp)) * delta
		a = (a + v * delta).limit_length(0.9)
		sp.a = a; sp.v = v
		skel.set_bone_pose_rotation(b, _q(Vector3(a.x, 0, a.y)))
