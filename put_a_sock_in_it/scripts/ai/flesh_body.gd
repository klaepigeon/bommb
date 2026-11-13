class_name FleshBody
extends Node3D
## A body for the building's inhabitants (docs/CHAPTER2.md): jointed, built from the numbers in
## `p`, and never quite human: the proportions are off in a way you notice before you know why.
## Joints (Node3D, rotated each frame toward `pose` with springs, like Marta's):
##   hips  spine  chest  neck  head  jaw   sh_l/sh_r  el_l/el_r  hip_l/hip_r  kn_l/kn_r
## p (all optional):
##   height 1.75   girth 1.0 (width)   belly 0.0 (0..1: how far it hangs)   arm 1.0 (length)
##   neck 1.0   head 1.0 (size)   hunch 0.0   skin "skin"   tint Color   wet 0.0 (sheen)
##   mouth 1.0 (width: the super's goes round)   eyes "normal" | "none" | "sewn" | "many"
##   fingers 1.0 (length)   naked false   apron/dress/coat Color   keys false   lumps 0.0 (growths)
##   extra_joint false (the arms bend twice)   barefoot true

var p := {}
var pose := {}                  # joint -> Vector3 (euler), the target
var snap := 10.0                # how fast joints go to the pose
var J := {}                     # joint name -> Node3D
var _rest := {}

func _init(params := {}) -> void:
	p = params

func _ready() -> void:
	_build()
	for k in J: pose[k] = Vector3.ZERO

func g(k: String, d):
	return p.get(k, d)

func _mat(name: String, tint: Color, extra := {}) -> Material:
	var o := {"tint": tint}
	for k in extra: o[k] = extra[k]
	return Tex.mat(name, 2.0, o)

func _part(parent: Node3D, at: Vector3, size: Vector3, m: Material, ball := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if ball:
		var sp := SphereMesh.new(); sp.radius = 0.5; sp.height = 1.0; sp.radial_segments = 10; sp.rings = 6
		mi.mesh = sp; mi.scale = size
	else:
		mi.mesh = Build.box_mesh(size)
	mi.material_override = m; mi.position = at; parent.add_child(mi)
	return mi

func _joint(name: String, parent: Node3D, at: Vector3) -> Node3D:
	var j := Node3D.new(); j.name = name; parent.add_child(j); j.position = at
	J[name] = j
	return j

func _build() -> void:
	var h: float = g("height", 1.75); var k := h / 1.75
	var gw: float = g("girth", 1.0); var belly: float = g("belly", 0.0)
	var arm: float = g("arm", 1.0); var neckl: float = g("neck", 1.0); var headk: float = g("head", 1.0)
	# skin: pallid and close-grained (plaster's grain, tinted), not the camouflage of the old skin map
	var skin := _mat(String(g("skin", "plaster")), g("tint", Color(0.9, 0.82, 0.72)) * Color(1.15, 1.1, 1.05), {"rough": lerpf(0.9, 0.25, float(g("wet", 0.0)))})
	var dark := _mat("black", Color(1, 1, 1))
	var leg := 0.86 * k; var torso := 0.56 * k
	var hips := _joint("hips", self, Vector3(0, leg, 0))
	# legs
	for s in [-1, 1]:
		var side := "l" if s < 0 else "r"
		var hj := _joint("hip_" + side, hips, Vector3(s * 0.1 * gw * k, 0, 0))
		_part(hj, Vector3(0, -leg * 0.25, 0), Vector3(0.13 * gw, leg * 0.5, 0.14 * gw) * Vector3(k, 1, k), _cloth("legs", skin))
		var kn := _joint("kn_" + side, hj, Vector3(0, -leg * 0.5, 0))
		_part(kn, Vector3(0, -leg * 0.25, 0), Vector3(0.1, leg * 0.5, 0.11) * Vector3(k, 1, k), skin)
		_part(kn, Vector3(0, -leg * 0.5 + 0.03, 0.06), Vector3(0.1, 0.05, 0.24) * k, skin if g("barefoot", true) else dark)
	var spine := _joint("spine", hips, Vector3(0, 0.02, 0))
	_part(spine, Vector3(0, torso * 0.25, 0), Vector3(0.34 * gw, torso * 0.5, 0.2 * gw) * Vector3(k, 1, k), _cloth("dress", skin))
	if belly > 0.01:
		# the belly: hangs, and hangs over
		var b := _part(spine, Vector3(0, torso * 0.12 - belly * 0.08, 0.1 + belly * 0.12) * Vector3(1, k, k),
			Vector3(0.38 * gw + belly * 0.22, 0.32 + belly * 0.28, 0.24 + belly * 0.3) * k, skin, true)
		b.set_meta("belly", true)
	var chest := _joint("chest", spine, Vector3(0, torso * 0.5, 0))
	_part(chest, Vector3(0, torso * 0.25, 0), Vector3(0.4 * gw, torso * 0.5, 0.22 * gw) * Vector3(k, 1, k), _cloth("dress", skin))
	if float(g("belly", 0.0)) > 0.3:
		for s in [-1, 1]: _part(chest, Vector3(s * 0.11 * gw * k, torso * 0.12, 0.11 * gw * k), Vector3(0.15, 0.17, 0.12) * gw * k, skin, true)   # sagging
	if g("keys", false):
		var cord := _part(chest, Vector3(0, torso * 0.2, 0.12 * gw * k), Vector3(0.01, torso * 0.6, 0.01), dark)
		cord.rotation.x = -0.15
		for i in 6: _part(chest, Vector3(randf_range(-0.03, 0.03), -0.02 - i * 0.012, 0.15 * gw * k), Vector3(0.012, 0.05, 0.004), Tex.mat("brass"))
	if float(g("lumps", 0.0)) > 0.0:
		var lm := _mat("coral", Color(0.9, 0.85, 0.8))
		var rng := RandomNumberGenerator.new(); rng.seed = int(h * 1000.0)
		for i in int(float(g("lumps", 0.0)) * 8.0):
			var parent: Node3D = [spine, chest][i % 2]
			_part(parent, Vector3(rng.randf_range(-0.18, 0.18) * gw, rng.randf_range(0.0, torso * 0.5), rng.randf_range(-0.12, 0.13) * gw) * Vector3(k, 1, k), Vector3.ONE * rng.randf_range(0.05, 0.12), lm, true)
	# arms
	for s in [-1, 1]:
		var side := "l" if s < 0 else "r"
		var sh := _joint("sh_" + side, chest, Vector3(s * 0.22 * gw * k, torso * 0.45, 0))
		var up := 0.32 * k * arm
		_part(sh, Vector3(0, -up * 0.5, 0), Vector3(0.09, up, 0.09) * Vector3(k, 1, k), _cloth("dress", skin))
		var el := _joint("el_" + side, sh, Vector3(0, -up, 0))
		var lo := 0.3 * k * arm
		_part(el, Vector3(0, -lo * 0.5, 0), Vector3(0.075, lo, 0.075) * Vector3(k, 1, k), skin)
		if g("extra_joint", false):
			var ex := _joint("ex_" + side, el, Vector3(0, -lo, 0))
			_part(ex, Vector3(0, -lo * 0.4, 0), Vector3(0.06, lo * 0.8, 0.06) * k, skin)
			_hand(ex, Vector3(0, -lo * 0.8, 0), skin, k)
		else:
			_hand(el, Vector3(0, -lo, 0), skin, k)
	# neck, head, jaw
	var nl := 0.11 * k * neckl
	var neck := _joint("neck", chest, Vector3(0, torso * 0.5, 0))
	_part(neck, Vector3(0, nl * 0.5, 0), Vector3(0.09, nl, 0.09) * k, skin)
	var head := _joint("head", neck, Vector3(0, nl, 0))
	var hs := 0.22 * k * headk
	_part(head, Vector3(0, hs * 0.5, 0), Vector3(hs * 0.8, hs, hs * 0.9), skin, true)
	var jaw := _joint("jaw", head, Vector3(0, hs * 0.3, hs * 0.2))
	var mw := 0.07 * k * float(g("mouth", 1.0))
	_part(jaw, Vector3(0, -0.02, 0.06 * k), Vector3(mw * 1.2, 0.03, 0.1 * k), skin)
	_part(head, Vector3(0, hs * 0.3, hs * 0.44), Vector3(mw * 1.15, 0.012, 0.01), _mat("cloth_red", Color(0.35, 0.05, 0.06)))   # the mouth's line
	match String(g("eyes", "normal")):
		"normal":
			for s in [-1, 1]: _part(head, Vector3(s * hs * 0.18, hs * 0.58, hs * 0.42), Vector3(0.025, 0.018, 0.01) * k, dark)
		"sewn":
			for s in [-1, 1]:
				for i in 3: _part(head, Vector3(s * hs * 0.18 + (i - 1) * 0.01, hs * 0.58, hs * 0.43), Vector3(0.004, 0.03, 0.004), dark)
		"many":
			for i in 7: _part(head, Vector3(randf_range(-0.3, 0.3) * hs, randf_range(0.45, 0.8) * hs, hs * 0.43), Vector3(0.018, 0.014, 0.01) * k, dark)
		_:
			pass
	if g("hair", false):
		_part(head, Vector3(0, hs * 0.9, -0.01), Vector3(hs * 0.8, hs * 0.35, hs * 0.85), _mat("fabric", g("hair_tint", Color(0.2, 0.17, 0.14))), true)
	for k2 in J: _rest[k2] = J[k2].rotation

## Clothes, if they wear any: a colour for apron/dress/coat, or skin.
func _cloth(where: String, skin: Material) -> Material:
	if g("naked", false): return skin
	if where == "dress" and p.has("dress"): return _mat("fabric", p.dress)
	if where == "legs" and p.has("trousers"): return _mat("fabric", p.trousers)
	if where == "dress" and p.has("apron"): return _mat("fabric", p.apron)
	return skin

func _hand(parent: Node3D, at: Vector3, skin: Material, k: float) -> void:
	var f: float = g("fingers", 1.0)
	_part(parent, at + Vector3(0, -0.04, 0), Vector3(0.08, 0.08, 0.04) * k, skin)
	for i in 4:
		_part(parent, at + Vector3(-0.03 + i * 0.02, -0.08 - 0.05 * f, 0), Vector3(0.012, 0.1 * f, 0.012) * k, skin)

## Joint name -> world position (attacks, gaze, the hit point).
func at(j: String) -> Vector3:
	return (J[j] as Node3D).global_position if J.has(j) else global_position

func _process(delta: float) -> void:
	var t := 1.0 - exp(-snap * delta)
	for k in J:
		var want: Vector3 = _rest[k] + pose.get(k, Vector3.ZERO)
		var jn: Node3D = J[k]
		jn.rotation = jn.rotation.lerp(want, t)
