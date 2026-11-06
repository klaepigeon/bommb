class_name DiceCage
extends Node3D
## The Caller's head: a brass bingo cage full of dice. The dice are his eyes.
##
## They are simulated in the head's frame (so when his head turns, they really roll), they
## can't leave the cage, and the spinning bars drag them round. When he is WATCHING you, every
## d6 in the cage turns its single pip toward you, and two of them roll up into the sockets
## where eyes would be and burn red; the redder they are, the more he suspects. When he looks
## away they drop and go back to rattling around.
##
## Front is +Z. The cage turns on its X axle (the crank is on his right, +X).

signal clack(strength: float)

const R := 0.36          # bar radius
const RI := 0.325        # inside the bars
const N_D6 := 13
const OTHERS := [20, 8, 4, 12]
const SOCKETS := [Vector3(-0.12, 0.05, 0.2), Vector3(0.12, 0.05, 0.2)]
const BONE := Color("e8dcc0")
const INK := Color("2a1410")
const EYE := Color("c8281c")

var cage: Node3D
var crank: Node3D
var dice: Array = []        # {node, p, v, rot, w, r, d6, eye_dir}
var spin := 0.0             # cage angular velocity about X (rad/s)
var idle_spin := 0.35
var angle := 0.0
var watching := false
var suspicion := 0.0        # 0..1: eyes redder, pips tremble
var tremble := 0.0
var masked := false
var eye_pair := [0, 1]
var eye_glows: Array = []
var eye_light: OmniLight3D
var gaze: SpotLight3D
var _acc := 0.0
var _clack_cd := 0.0
var _rng := RandomNumberGenerator.new()
var _t := 0.0

func _ready() -> void:
	_rng.seed = 1979
	_build()

func _build() -> void:
	var brass := MB.mat(Tex.brass())
	var dark := MB.mat(Tex.grime(Color("1a1612"), Color("2e2620"), 16, 4, 0.3))
	# the yoke: a U of strap from the neck up to the axle ends, riveted
	var yoke := MB.new()
	var y0 := -R - 0.09
	for sx in [-1.0, 1.0]:
		yoke.box("b", brass, Vector3(0.04, -y0 + 0.02, 0.05), MB.T(Vector3(sx * (R + 0.06), y0 * 0.5, 0)), Color(0.85, 0.8, 0.7))
		yoke.cyl("d", dark, 0.035, 0.035, 0.05, 8, MB.T(Vector3(sx * (R + 0.085), 0, 0), Vector3(0, 0, PI / 2)), Color(1, 1, 1))
	yoke.box("b", brass, Vector3(2 * (R + 0.08), 0.04, 0.06), MB.T(Vector3(0, y0, 0)), Color(0.8, 0.7, 0.6))
	yoke.box("d", dark, Vector3(0.12, 0.07, 0.12), MB.T(Vector3(0, y0 - 0.04, 0)), Color(1, 1, 1))
	_mi(yoke.build(), self)
	cage = Node3D.new()
	cage.name = "Cage"
	add_child(cage)
	var cb := MB.new()
	# meridians through the axle ends, so it really turns on its axle
	for k in range(8):
		var a := PI * k / 8.0
		var tone := Color(1, 1, 1) if k % 2 == 0 else Color(0.72, 0.62, 0.5)
		cb.ring("b", brass, R, 0.014, 18, MB.T(Vector3.ZERO, Vector3(a, 0, 0)), tone)
	for xr in [-0.2, 0.0, 0.2]:
		var rr := sqrt(R * R - xr * xr)
		cb.ring("b", brass, rr, 0.016, 18, MB.T(Vector3(xr, 0, 0), Vector3(0, 0, PI / 2)), Color(0.8, 0.7, 0.6))
	for sx in [-1.0, 1.0]:
		cb.cyl("b", brass, 0.06, 0.06, 0.02, 8, MB.T(Vector3(sx * (R - 0.01), 0, 0), Vector3(0, 0, PI / 2)), Color(1, 1, 1))
	# the hatch, low on the front
	cb.box("b", brass, Vector3(0.16, 0.012, 0.012), MB.T(Vector3(0, -R * 0.5, R * 0.86)), Color(1, 1, 1))
	cb.box("b", brass, Vector3(0.16, 0.012, 0.012), MB.T(Vector3(0, -R * 0.75, R * 0.66)), Color(1, 1, 1))
	_mi(cb.build(), cage)
	crank = Node3D.new()
	crank.position = Vector3(R + 0.11, 0, 0)
	var kb := MB.new()
	kb.box("d", dark, Vector3(0.06, 0.02, 0.02), MB.T(Vector3(0.0, 0, 0)), Color(1, 1, 1))
	kb.box("d", dark, Vector3(0.02, 0.2, 0.03), MB.T(Vector3(0.03, 0.09, 0)), Color(1, 1, 1))
	kb.cyl("d", MB.mat(Tex.wood(Color("4a2a18"), 3, 16, 1)), 0.022, 0.022, 0.12, 6, MB.T(Vector3(0.03, 0.18, 0), Vector3(0, 0, -PI / 2)), Color(1, 1, 1))
	_mi(kb.build(), crank)
	add_child(crank)
	# dice
	var d6: Array = Dice3D.build_mesh(6, BONE, INK, 0.07, EYE)
	for i in range(N_D6 + OTHERS.size()):
		var is6 := i < N_D6
		var sides: int = 6 if is6 else OTHERS[i - N_D6]
		var info: Array = d6 if is6 else Dice3D.build_mesh(sides, Color("d8c8a0") if sides != 20 else Color("8a1a12"), INK if sides != 20 else Color("e8dcc0"), 0.075)
		var mi := MeshInstance3D.new()
		mi.mesh = info[0]
		add_child(mi)
		var p := Vector3(_rng.randf_range(-0.15, 0.15), _rng.randf_range(-0.25, -0.05), _rng.randf_range(-0.15, 0.15))
		var rot := Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU))
		dice.append({"node": mi, "p": p, "v": Vector3.ZERO, "rot": rot, "w": Vector3.ZERO, "r": 0.05, "d6": is6,
			"one": (info[1][0]["normal"] as Vector3) if is6 else Vector3.UP})
	# the two lit pupils: small unlit red discs that sit on the eye dice's single pip
	for k in range(2):
		var g := MB.new()
		g.cyl("e", MB.mat(Tex.solid(Color(1, 1, 1)), Color(1, 1, 1), Vector2.ONE, true), 0.022, 0.022, 0.004, 10, MB.T(Vector3.ZERO, Vector3(PI / 2, 0, 0)), Color(1, 1, 1), true)
		var gm := _mi(g.build(), self)
		gm.visible = false
		gm.material_override = (gm.mesh.surface_get_material(0) as ShaderMaterial).duplicate()
		eye_glows.append(gm)
	# the gaze: a red beam onto the table that follows the head round
	gaze = SpotLight3D.new()
	gaze.light_color = Color("ff3020")
	gaze.light_energy = 0.0
	gaze.spot_range = 9.0
	gaze.spot_angle = 34.0
	gaze.spot_attenuation = 0.35
	gaze.shadow_enabled = false
	gaze.position = Vector3(0, 0, 0.3)
	add_child(gaze)
	gaze.look_at_from_position(Vector3(0, 0, 0.3), Vector3(0, -1.6, 1.8), Vector3.UP)
	eye_light = OmniLight3D.new()
	eye_light.light_color = Color("ff3a20")
	eye_light.light_energy = 0.0
	eye_light.omni_range = 3.2
	eye_light.omni_attenuation = 1.4
	eye_light.position = Vector3(0, 0.05, 0.45)
	add_child(eye_light)

func _mi(m: Mesh, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	parent.add_child(mi)
	return mi

## WATCHING: the pips turn to you and two dice climb into the sockets. Not: they drop.
func set_watching(on: bool) -> void:
	if on == watching:
		return
	watching = on
	if on:
		var free: Array = []
		for i in range(N_D6):
			free.append(i)
		free.shuffle()
		eye_pair = [free[0], free[1]]
		for d in dice:
			d["v"] += Vector3(0, 0.6, 0.3)
	else:
		jostle(0.9)

func set_suspicion(v: float) -> void:
	suspicion = clampf(v, 0.0, 1.0)

func set_masked(on: bool) -> void:
	masked = on

## A shiver through the whole cage: the tell before he turns.
func shudder(amount: float = 1.0) -> void:
	tremble = maxf(tremble, amount)
	jostle(0.35 * amount)

func jostle(amount: float) -> void:
	for d in dice:
		d["v"] += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.3, 1.3), _rng.randf_range(-1, 1)) * amount
		d["w"] += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * 18.0 * amount

## Spin it hard for a moment, like drawing a number.
func whirl(seconds: float = 1.0) -> void:
	spin = 9.0
	jostle(1.2)
	var tw := create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(self, "spin", idle_spin, 0.6)

func _physics_process(delta: float) -> void:
	_acc += delta
	_t += delta
	_clack_cd = maxf(0.0, _clack_cd - delta)
	tremble = maxf(0.0, tremble - delta * 1.5)
	var step := 1.0 / 60.0
	var guard := 0
	while _acc >= step and guard < 4:
		_acc -= step
		guard += 1
		_step(step)
	for d in dice:
		d["node"].position = d["p"]
		d["node"].basis = d["rot"]
	_update_eyes()

## Where the viewer is, in this node's frame: the eyes follow the camera, even when you walk.
func _viewer_dir() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return Vector3(0, 0, 1)
	var local := global_transform.affine_inverse() * cam.global_position
	return local.normalized()

func _step(dt: float) -> void:
	if spin == 0.0 and idle_spin > 0.0:
		spin = idle_spin
	angle += spin * dt
	cage.rotation.x = angle
	crank.rotation.x = angle
	var g := global_transform.basis.orthonormalized().inverse() * Vector3(0, -7.0, 0)
	var w := Vector3(spin, 0, 0)
	var view := _viewer_dir()
	for i in range(dice.size()):
		var d: Dictionary = dice[i]
		var r: float = d["r"]
		var lim := RI - r
		var eye := watching and eye_pair.has(i)
		if eye:
			var target: Vector3 = SOCKETS[eye_pair.find(i)]
			var tr := tremble * 0.6 + suspicion * 0.35
			if tr > 0.0:
				target += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * 0.012 * tr
			d["v"] += (target - d["p"]) * 110.0 * dt
			d["v"] *= 1.0 - 10.0 * dt
		else:
			d["v"] += g * dt
			d["v"] *= 1.0 - 0.35 * dt
		d["p"] += d["v"] * dt
		var dist: float = d["p"].length()
		if dist > lim:
			var n: Vector3 = d["p"] / dist
			d["p"] = n * lim
			var vn: float = d["v"].dot(n)
			if vn > 0.0:
				d["v"] -= 1.4 * vn * n
				d["w"] += n.cross(d["v"]) * 40.0 * vn
				if vn > 0.5 and not eye:
					_hit(vn)
			var vt: Vector3 = w.cross(d["p"])
			d["v"] += (vt - (d["v"] - n * d["v"].dot(n))) * 0.08
		# rotation: watching d6s turn their pip to you; everything else tumbles
		if watching and d["d6"] and not masked:
			var want := Quaternion(d["one"], view)
			var k := 0.35 if eye else 0.12
			d["rot"] = Basis(Quaternion(d["rot"].orthonormalized()).slerp(want, k)).orthonormalized()
			d["w"] *= 0.5
		else:
			d["w"] *= 1.0 - 1.6 * dt
			var wl: float = d["w"].length()
			if wl > 0.01:
				d["rot"] = (Basis(d["w"] / wl, wl * dt) * d["rot"]).orthonormalized()
	# dice against dice
	for i in range(dice.size()):
		var a: Dictionary = dice[i]
		for j in range(i + 1, dice.size()):
			var c: Dictionary = dice[j]
			var dv: Vector3 = c["p"] - a["p"]
			var dd: float = dv.length()
			var rr: float = a["r"] + c["r"]
			if dd < rr and dd > 0.0001:
				var n: Vector3 = dv / dd
				var push: float = (rr - dd) * 0.5
				var a_eye := watching and eye_pair.has(i)
				var c_eye := watching and eye_pair.has(j)
				if not a_eye:
					a["p"] -= n * push * (2.0 if c_eye else 1.0)
				if not c_eye:
					c["p"] += n * push * (2.0 if a_eye else 1.0)
				var rel: float = (c["v"] - a["v"]).dot(n)
				if rel < 0.0:
					a["v"] += n * rel * 0.9
					c["v"] -= n * rel * 0.9
					a["w"] += n.cross(Vector3.UP) * rel * 20.0
					c["w"] -= n.cross(Vector3.UP) * rel * 20.0
					if -rel > 0.7:
						_hit(-rel * 0.6)

func _update_eyes() -> void:
	var lit := watching and not masked
	var red := Color(1.0, 0.75 - suspicion * 0.6, 0.6 - suspicion * 0.55)
	for k in range(2):
		var gm: MeshInstance3D = eye_glows[k]
		gm.visible = lit
		if not lit:
			continue
		var d: Dictionary = dice[eye_pair[k]]
		var face_n: Vector3 = (d["rot"] * d["one"]).normalized()
		var pos: Vector3 = d["p"] + face_n * 0.042
		gm.position = pos
		gm.basis = Basis(Quaternion(Vector3(0, 0, 1), face_n))
		var pulse := 0.85 + 0.15 * sin(_t * (6.0 + suspicion * 14.0))
		gm.scale = Vector3.ONE * (0.8 + suspicion * 0.5) * pulse
		var m: ShaderMaterial = gm.material_override
		if m:
			m.set_shader_parameter("albedo", red)
	var gz := (5.0 + suspicion * 4.0) if watching else 0.0
	if tremble > 0.0 and watching:
		gz *= 0.5 + 0.5 * absf(sin(_t * 40.0))
	gaze.light_energy = lerpf(gaze.light_energy, gz, 0.2)
	var target := (0.9 + suspicion * 1.6) if lit else 0.0
	eye_light.light_energy = lerpf(eye_light.light_energy, target, 0.15)
	eye_light.light_color = Color(1.0, 0.3 - suspicion * 0.2, 0.15)

func _hit(strength: float) -> void:
	if _clack_cd > 0.0:
		return
	_clack_cd = 0.06
	clack.emit(strength)
