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

const PS1 := preload("res://shaders/ps1_lit.gdshader")

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
		_bone("uarm." + n, "clav." + n, Vector3(x * 0.36, 1.96, 0.0))
		_bone("farm." + n, "uarm." + n, Vector3(x * 0.4, 1.47, 0.0))
		_bone("hand." + n, "farm." + n, Vector3(x * 0.42, 1.0, -0.02))
		_bone("fingers." + n, "hand." + n, Vector3(x * 0.425, 0.88, -0.03))
		_bone("thigh." + n, "hips", Vector3(x * 0.15, 1.2, 0.0))
		_bone("shin." + n, "thigh." + n, Vector3(x * 0.16, 0.64, -0.01))
		_bone("foot." + n, "shin." + n, Vector3(x * 0.16, 0.09, 0.02))
		_bone("toe." + n, "foot." + n, Vector3(x * 0.16, 0.03, -0.2))
		_spring(_bone("flap_arm." + n, "uarm." + n, Vector3(x * 0.38, 1.86, 0.03)), 26.0, 3.2, 1.0)
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
		m.set_shader_parameter("albedo_tex", InfectedTextures.get_tex(tex))
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

## Loose skin: a thin sheet hung from `top` (a line of points fixed to `fixed`), falling `drop`
## to a ragged lower edge that belongs to the sprung bone `loose`. Both faces.
func _flap(sk: InfectedBody.SkinB, top: Array, drop: Vector3, fixed: int, loose: int, thick := 0.012, sag := 0.25) -> void:
	var noise := MeshKit.noise()
	var rows := 3
	var out := drop.cross((top.back() as Vector3) - (top[0] as Vector3)).normalized()
	for face: float in [1.0, -1.0]:
		var g := []
		for i in rows + 1:
			var t := float(i) / rows
			var row := []
			for j in top.size():
				var u := float(j) / (top.size() - 1)
				var a: Vector3 = top[j]
				# longest in the middle, and uneven along the edge
				var len := (0.45 + 0.55 * sin(u * PI)) * (1.0 + sag * noise.get_noise_2d(a.x * 40.0 + a.y * 17.0, u * 9.0))
				var p := a + drop * t * len + out * face * thick * (0.3 + sin(t * PI) * 0.9)
				var w := {fixed: 1.0 - t * t}
				w[loose] = float(w.get(loose, 0.0)) + t * t
				row.append(sk.add(p, Vector2(u, t), w, out * face))
			g.append(row)
		for i in rows:
			for j in top.size() - 1:
				sk.quad(g[i][j], g[i][j + 1], g[i + 1][j + 1], g[i + 1][j])

func _w(names: Dictionary) -> Callable:
	var w := {}
	for k in names: w[bones[k]] = names[k]
	return func(_p): return w

func _mesh() -> void:
	var skin := _sk("pallid", 0.8, 0.35, Color(0.93, 0.88, 0.84))
	var slack := _sk("pallid", 0.9, 0.2, Color(0.82, 0.74, 0.72))        # the hanging skin: thinner, greyer
	var raw := _sk("raw", 0.3, 0.7)
	var bone := _sk("bone", 0.6, 0.4)
	var hair := _sk("bone", 1.0, 0.05, Color(1.25, 1.25, 1.3))
	var dark := _sk("pallid", 0.85, 0.3, Color(0.6, 0.47, 0.47))
	var noise := MeshKit.noise()
	# ---- the trunk: a wide frame, a hollow waist. y, half-width, half-depth, z
	var lv := [[1.07, 0.1, 0.08, 0.0], [1.15, 0.185, 0.105, 0.01], [1.25, 0.205, 0.11, 0.01], [1.34, 0.15, 0.085, 0.0],
		[1.46, 0.14, 0.085, -0.005], [1.58, 0.185, 0.125, -0.01], [1.72, 0.235, 0.15, -0.005], [1.85, 0.275, 0.14, 0.01],
		[1.95, 0.3, 0.115, 0.02], [2.03, 0.07, 0.068, 0.01], [2.13, 0.06, 0.062, -0.005]]
	var chain := [bones.hips, bones.spine, bones.chest, bones.neck, bones.head]
	var ys := [1.26, 1.46, 1.72, 2.02, 2.13]
	var tw := func(y: float) -> Dictionary:
		for i in ys.size() - 1:
			if y <= float(ys[i]): return {chain[i]: 1.0}
			if y < float(ys[i + 1]):
				var k := (y - float(ys[i])) / (float(ys[i + 1]) - float(ys[i]))
				return {chain[i]: 1.0 - k, chain[i + 1]: k}
		return {chain.back(): 1.0}
	var sides := 12
	var trunk := []
	for l in lv:
		var ring := []
		for j in sides + 1:
			var th := TAU * float(j) / sides
			var o := Vector3(cos(th), 0, sin(th))
			var bump := 1.0 + 0.06 * noise.get_noise_3d(o.x * 3.0, float(l[0]) * 14.0, o.z * 3.0)
			# the belly's a hollow under the ribs
			var hollow := 0.75 if (o.z < -0.3 and float(l[0]) > 1.3 and float(l[0]) < 1.52) else 1.0
			ring.append(skin.add(Vector3(o.x * float(l[1]) * bump, float(l[0]), float(l[3]) + o.z * float(l[2]) * bump * hollow), Vector2(float(j) / sides, float(l[0])), tw.call(float(l[0])), o))
		trunk.append(ring)
	for i in trunk.size() - 1:
		for j in sides: skin.quad(trunk[i][j], trunk[i][j + 1], trunk[i + 1][j + 1], trunk[i + 1][j])
	var under := skin.add(Vector3(0, 1.04, 0), Vector2(0.5, 0.5), {bones.hips: 1.0}, Vector3.DOWN)
	for j in sides: skin.tri(under, trunk[0][j], trunk[0][j + 1])
	# ---- what shows through: ribs, collarbones, the points of the hips, the spine, the shoulder blades
	for sx: float in [-1.0, 1.0]:
		for i in 5:
			var y := 1.54 + i * 0.062
			_blob(skin, Vector3(sx * (0.1 + i * 0.012), y, -0.105 - i * 0.006), Vector3(0.1, 0.016, 0.03), _w({"chest": 0.7 if i > 1 else 0.4, "spine": 0.3 if i > 1 else 0.6}), 3, 6, 0.05, Basis(Vector3.BACK, sx * -0.28))
		_blob(skin, Vector3(sx * 0.16, 1.975, -0.085), Vector3(0.14, 0.018, 0.02), _w({"chest": 1.0}), 3, 6, 0.05, Basis(Vector3.BACK, sx * 0.1))     # collarbone
		_blob(skin, Vector3(sx * 0.33, 1.99, 0.0), Vector3(0.07, 0.055, 0.075), _w({"chest": 0.5, "clav." + ("L" if sx > 0 else "R"): 0.5}), 4, 8, 0.1)      # the point of the shoulder
		_blob(skin, Vector3(sx * 0.17, 1.25, -0.075), Vector3(0.055, 0.07, 0.04), _w({"hips": 1.0}), 3, 6, 0.1)                 # hip bone
		_blob(skin, Vector3(sx * 0.15, 1.8, 0.14), Vector3(0.09, 0.12, 0.03), _w({"chest": 1.0}), 3, 6, 0.1, Basis(Vector3.UP, sx * -0.3))   # shoulder blade
		_blob(skin, Vector3(sx * 0.1, 1.17, 0.1), Vector3(0.085, 0.07, 0.05), _w({"hips": 1.0}), 3, 6, 0.1)                     # what's left of a backside
	for i in 9:
		var y := 1.3 + i * 0.085
		_blob(skin, Vector3(0, y, 0.105 + 0.045 * sin((y - 1.3) * 2.6)), Vector3(0.02, 0.025, 0.022), func(p): return tw.call(p.y), 2, 5, 0.0)      # the spine's knuckles
	# ---- arms and legs: bone and cord, big at the joints
	for sd in [["L", 1.0], ["R", -1.0]]:
		var n: String = sd[0]; var x: float = sd[1]
		var ua: int = bones["uarm." + n]; var fa: int = bones["farm." + n]; var ha: int = bones["hand." + n]; var fi: int = bones["fingers." + n]
		_tube(skin, [_rest[ua], _rest[ua].lerp(_rest[fa], 0.5), _rest[fa], _rest[fa].lerp(_rest[ha], 0.35), _rest[ha]],
			[0.062, 0.05, 0.047, 0.05, 0.033], [ua, ua, fa, fa], bones["clav." + n], 8, 2, 0.14, false)
		_blob(skin, _rest[fa] + Vector3(0, 0, 0.012), Vector3(0.056, 0.062, 0.058), _w({"uarm." + n: 0.5, "farm." + n: 0.5}), 3, 6, 0.1)     # elbow
		_blob(skin, _rest[ha], Vector3(0.042, 0.035, 0.036), _w({"farm." + n: 0.5, "hand." + n: 0.5}), 3, 6, 0.1)                           # wrist
		# a hand like a shovel: the palm, four long fingers, a thumb
		_blob(skin, _rest[ha] + Vector3(0, -0.075, -0.005), Vector3(0.028, 0.075, 0.058), _w({"hand." + n: 1.0}), 3, 6, 0.08)
		for f in 4:
			var fz := -0.045 + f * 0.03
			var a: Vector3 = _rest[ha] + Vector3(0, -0.135, fz)
			_tube(skin, [a, a + Vector3(0, -0.065, 0.0), a + Vector3(-x * 0.012, -0.125 - 0.012 * sin(f * 1.3), 0.004)], [0.014, 0.012, 0.009], [ha, fi], -1, 5, 1, 0.0)
			_blob(skin, a + Vector3(0, -0.065, 0), Vector3(0.016, 0.014, 0.016), _w({"hand." + n: 0.5, "fingers." + n: 0.5}), 2, 5, 0.0)
		var th0: Vector3 = _rest[ha] + Vector3(0, -0.05, -0.06)
		_tube(skin, [th0, th0 + Vector3(0, -0.05, -0.035), th0 + Vector3(0, -0.1, -0.045)], [0.017, 0.014, 0.01], [ha, ha], -1, 5, 1, 0.0)
		var th: int = bones["thigh." + n]; var sh: int = bones["shin." + n]; var fo: int = bones["foot." + n]; var to: int = bones["toe." + n]
		_tube(skin, [_rest[th] + Vector3(0, 0.02, 0), _rest[th].lerp(_rest[sh], 0.5), _rest[sh], _rest[sh].lerp(_rest[fo], 0.3), _rest[fo]],
			[0.088, 0.066, 0.058, 0.062, 0.04], [th, th, sh, sh], bones.hips, 8, 2, 0.14, false)
		_blob(skin, _rest[sh] + Vector3(0, 0.0, -0.022), Vector3(0.07, 0.078, 0.07), _w({"thigh." + n: 0.5, "shin." + n: 0.5}), 3, 6, 0.1)    # knee
		_blob(skin, _rest[fo] + Vector3(0, 0.0, 0.01), Vector3(0.05, 0.045, 0.055), _w({"shin." + n: 0.5, "foot." + n: 0.5}), 3, 6, 0.1)      # ankle
		_tube(skin, [_rest[fo] + Vector3(0, -0.04, 0.07), _rest[fo] + Vector3(0, -0.045, -0.08), _rest[to] + Vector3(0, 0.005, -0.05)], [0.05, 0.055, 0.036], [fo, to], sh, 6, 2, 0.1)
		# ---- the skin of a much bigger man
		var fl_a: int = bones["flap_arm." + n]
		_flap(slack, [_rest[ua] + Vector3(-x * 0.03, -0.06, 0.03), _rest[ua].lerp(_rest[fa], 0.35) + Vector3(0, 0, 0.04), _rest[ua].lerp(_rest[fa], 0.7) + Vector3(0, 0, 0.04), _rest[fa] + Vector3(0, 0.03, 0.035)],
			Vector3(-x * 0.04, -0.3, 0.07), ua, fl_a, 0.02)
		var fl_c: int = bones["flap_chest." + n]
		_flap(slack, [Vector3(x * 0.03, 1.83, -0.15), Vector3(x * 0.1, 1.815, -0.155), Vector3(x * 0.18, 1.82, -0.145), Vector3(x * 0.245, 1.85, -0.11)],
			Vector3(0, -0.27, -0.03), bones.chest, fl_c, 0.03)
		_blob(dark, Vector3(x * 0.125, 1.6, -0.2), Vector3(0.016, 0.02, 0.012), func(_p): return {fl_c: 1.0}, 2, 5, 0.0)    # nipple, at the bottom of it
		var fl_f: int = bones["flap_flank." + n]
		_flap(slack, [Vector3(x * 0.2, 1.62, -0.07), Vector3(x * 0.215, 1.6, 0.0), Vector3(x * 0.2, 1.6, 0.07), Vector3(x * 0.14, 1.6, 0.115)],
			Vector3(x * 0.05, -0.3, 0.0), bones.spine, fl_f, 0.022)
		var fl_t: int = bones["flap_thigh." + n]
		_flap(slack, [Vector3(x * 0.07, 1.14, -0.04), Vector3(x * 0.075, 1.12, 0.01), Vector3(x * 0.085, 1.13, 0.06), Vector3(x * 0.12, 1.13, 0.095)],
			Vector3(-x * 0.01, -0.3, 0.01), th, fl_t, 0.02)
		_flap(slack, [Vector3(x * 0.06, 1.13, 0.125), Vector3(x * 0.11, 1.14, 0.135), Vector3(x * 0.16, 1.14, 0.125), Vector3(x * 0.2, 1.15, 0.09)],
			Vector3(0, -0.22, 0.03), bones.hips, fl_t, 0.025)                                                                             # the backside, emptied
	# the belly: an apron with nothing in it, hung from under the ribs. It stops above the hips.
	var fb: int = bones.flap_belly
	_flap(slack, [Vector3(-0.15, 1.5, -0.085), Vector3(-0.08, 1.49, -0.1), Vector3(0, 1.485, -0.105), Vector3(0.08, 1.49, -0.1), Vector3(0.15, 1.5, -0.085)],
		Vector3(0, -0.24, -0.045), bones.spine, fb, 0.03)
	_blob(dark, Vector3(0, 1.38, -0.15), Vector3(0.012, 0.02, 0.008), func(_p): return {fb: 0.6, bones.spine: 0.4}, 2, 5, 0.0)          # navel
	# ---- between his legs, in plain sight: nothing hangs over it
	var p0: int = bones.penis0; var p1: int = bones.penis1
	var pa: Vector3 = _rest[p0]; var pb: Vector3 = _rest[p1]
	_blob(hair, pa + Vector3(0, 0.05, -0.005), Vector3(0.075, 0.045, 0.025), _w({"hips": 1.0}), 3, 6, 0.5)                              # white hair above
	_blob(dark, pa + Vector3(-0.028, -0.105, 0.035), Vector3(0.04, 0.075, 0.042), _w({"penis0": 0.8, "hips": 0.2}), 4, 6, 0.12)          # scrotum, long, one side lower
	_blob(dark, pa + Vector3(0.03, -0.085, 0.035), Vector3(0.038, 0.062, 0.04), _w({"penis0": 0.8, "hips": 0.2}), 4, 6, 0.12)
	var pe := pb + Vector3(0, -0.085, -0.008)
	_tube(skin, [pa + Vector3(0, 0.015, 0.0), pa.lerp(pb, 0.5), pb, pb.lerp(pe, 0.6)], [0.03, 0.028, 0.027, 0.027], [p0, p0, p1], bones.hips, 7, 2, 0.08, false)
	_blob(dark, pb.lerp(pe, 0.82), Vector3(0.03, 0.04, 0.03), _w({"penis1": 1.0}), 4, 7, 0.04)                                           # the end of it
	_head(skin, slack, raw, bone, hair, dark)
	var m := ArrayMesh.new()
	for key in _skins: (_skins[key] as InfectedBody.SkinB).commit(m, _skin_mat[key])
	mesh_inst = MeshInstance3D.new(); mesh_inst.name = "Body"; mesh_inst.mesh = m
	skel.add_child(mesh_inst)
	mesh_inst.skeleton = NodePath("..")
	mesh_inst.extra_cull_margin = 1.0

func _head(skin: InfectedBody.SkinB, slack: InfectedBody.SkinB, raw: InfectedBody.SkinB, bone: InfectedBody.SkinB, hair: InfectedBody.SkinB, dark: InfectedBody.SkinB) -> void:
	var hb: int = bones.head; var jb: int = bones.jaw
	var c := Vector3(0, 2.225, -0.03)
	var r := Vector3(0.105, 0.155, 0.135)
	var jaw_line := 2.17
	var wf := func(p: Vector3) -> Dictionary:
		var k := smoothstep(jaw_line + 0.012, jaw_line - 0.03, p.y) * smoothstep(c.z + 0.04, c.z - 0.04, p.z)
		return {hb: 1.0 - k, jb: k}
	var noise := MeshKit.noise()
	var rows := 8; var cols := 12
	var g := []
	for i in rows + 1:
		var ph := PI * float(i) / rows
		var row := []
		for j in cols + 1:
			var th := TAU * float(j) / cols
			var dir := Vector3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th))
			var p := c + dir * r * (1.0 + 0.05 * noise.get_noise_3d(dir.x * 4.0, dir.y * 4.0 + 7.0, dir.z * 4.0))
			# a long face: temples sunk, cheeks gone, a long chin
			if dir.y < 0.2 and dir.y > -0.5 and absf(dir.x) > 0.5: p.x *= 0.86
			if dir.y < -0.5 and dir.z < 0.0: p.z -= 0.02; 
			if dir.y > 0.3:
				# the top of the skull is gone: a ragged rim, and a crater inside it
				var k := (dir.y - 0.3) / 0.7
				var rim := 0.018 * noise.get_noise_3d(dir.x * 9.0, 3.0, dir.z * 9.0)
				p = Vector3(c.x + dir.x * r.x * (1.0 - k * 0.6), c.y + r.y * (0.32 - k * 0.45) + rim * (1.0 - k), c.z + dir.z * r.z * (1.0 - k * 0.6))
			row.append(skin.add(p, Vector2(float(j) / cols, float(i) / rows), wf.call(p), dir))
		g.append(row)
	for i in rows:
		for j in cols: skin.quad(g[i][j], g[i][j + 1], g[i + 1][j + 1], g[i + 1][j])
	var hw := func(_p): return {hb: 1.0}
	var jw := func(_p): return {jb: 1.0}
	_blob(raw, c + Vector3(0, r.y * 0.04, 0), Vector3(r.x * 0.6, r.y * 0.14, r.z * 0.6), hw, 4, 10, 0.3)
	for i in 13:
		var a := TAU * i / 13.0 + 0.3
		_blob(bone, c + Vector3(cos(a) * r.x * 0.9, r.y * (0.27 + 0.03 * sin(a * 3.0)), sin(a) * r.z * 0.9), Vector3(0.014, 0.008 + 0.016 * absf(sin(a * 2.0)), 0.009), hw, 2, 5, 0.0)
	# the face
	_blob(skin, c + Vector3(0, 0.05, -r.z * 0.9), Vector3(0.085, 0.018, 0.026), hw, 3, 6, 0.05)                 # brow
	_blob(skin, c + Vector3(0, -0.005, -r.z * 0.98), Vector3(0.02, 0.05, 0.035), hw, 3, 6, 0.05)                # a long nose
	var black := _sk("black", 1.0, 0.0)
	var eye := _sk("eye", 0.3, 0.8)
	for sx: float in [-1.0, 1.0]:
		_blob(black, c + Vector3(sx * 0.042, 0.022, -r.z * 0.86), Vector3(0.026, 0.02, 0.02), hw, 3, 6, 0.0)     # the socket
		_blob(eye, c + Vector3(sx * 0.042, 0.02, -r.z * 0.9), Vector3(0.014, 0.012, 0.012), hw, 3, 6, 0.0)
		_blob(slack, c + Vector3(sx * 0.045, -0.012, -r.z * 0.9), Vector3(0.026, 0.014, 0.014), hw, 2, 6, 0.1)   # bags under them
		_blob(skin, c + Vector3(sx * r.x * 0.98, -0.005, 0.01), Vector3(0.012, 0.05, 0.028), hw, 3, 5, 0.0)      # ears, long
		_blob(slack, Vector3(sx * 0.06, jaw_line - 0.035, c.z - 0.07), Vector3(0.025, 0.05, 0.035), func(_p): return {jb: 0.7, bones.flap_neck: 0.3}, 3, 6, 0.15)   # jowls
		_blob(hair, c + Vector3(sx * 0.042, 0.062, -r.z * 0.97), Vector3(0.026, 0.007, 0.01), hw, 2, 5, 0.3)     # brows
		for hz: float in [0.3, 0.75]:
			_flap(hair, [c + Vector3(sx * r.x * 0.95, 0.03, r.z * (hz - 0.15)), c + Vector3(sx * r.x * 0.95, 0.035, r.z * hz), c + Vector3(sx * r.x * 0.9, 0.03, r.z * (hz + 0.15))],
				Vector3(sx * 0.01, -0.12, 0.02), hb, hb, 0.004, 0.6)
	_flap(hair, [c + Vector3(-0.05, 0.03, r.z * 0.95), c + Vector3(0, 0.035, r.z), c + Vector3(0.05, 0.03, r.z * 0.95)], Vector3(0, -0.16, 0.03), hb, hb, 0.004, 0.6)
	_blob(black, Vector3(0, jaw_line, c.z - r.z * 0.74), Vector3(0.042, 0.016, 0.03), func(_p): return {hb: 0.5, jb: 0.5}, 3, 8, 0.0)
	var teeth := _sk("teeth", 0.5, 0.6)
	for i: int in [0, 1, 3, 4, 6]:                                                                                   # the ones he has left
		var x := (float(i) / 6.0 - 0.5) * 0.07
		var z := c.z - r.z * 0.9 + absf(x) * 0.6
		_blob(teeth, Vector3(x, jaw_line - 0.008, z), Vector3(0.007, 0.011, 0.006), jw, 2, 5, 0.0)
		if i % 3 != 1:
			_blob(teeth, Vector3(x + 0.005, jaw_line + 0.008, z + 0.002), Vector3(0.007, 0.009, 0.006), hw, 2, 5, 0.0)
	# the neck: cords, an Adam's apple, and the wattle under the jaw
	_blob(skin, Vector3(0, 2.07, -0.062), Vector3(0.018, 0.026, 0.02), _w({"neck": 1.0}), 2, 5, 0.0)
	var fn: int = bones.flap_neck
	_flap(slack, [Vector3(-0.045, 2.14, -0.105), Vector3(0, 2.13, -0.125), Vector3(0.045, 2.14, -0.105)], Vector3(0, -0.17, 0.035), jb, fn, 0.02)

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
	var neck := Vector3(0.22 + _hunt * 0.12, 0, 0)
	var head := Vector3(0.24 + _hunt * 0.1, 0, 0.1 + sin(_t * 0.37) * 0.04)
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
		var reach := _hunt * (0.75 + 0.1 * sin(_t * 1.3 + x)) + _grab * 0.55
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
