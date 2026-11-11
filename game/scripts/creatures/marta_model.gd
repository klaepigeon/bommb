class_name MartaModel
extends Node3D
## Marta Sokolova, at her place at the dinner table. Three weeks dead by the look of her: the
## flesh has gone soft and is sliding off her, down into her lap and off the chair into a black
## puddle; coral has grown through her back, her shoulders, her arms, her face, and down through
## the chair into the floor. Her lips are gone and her cheeks have split back toward her ears,
## so she grins, very wide, at her plate.
##
## She doesn't move. Not breathing, not twitching; only the flies. That's the point: when she
## moves (see the encounter in marta_encounter.gd) it should be the last thing the player expects.
##
## Built procedurally (MeshKit, RotTextures), segmented on a joint hierarchy the way PS1
## characters were, so the corpse can be posed and then move. Local frame: she faces -Z, the
## origin is the floor under the middle of her chair.

const PS1 := preload("res://shaders/world.gdshader")

# joint positions in the rest pose (local space)
const J := {
	"hips": Vector3(0, 0.5, 0.04),
	"neck": Vector3(0, 1.06, -0.05),
	"head": Vector3(0, 1.17, -0.08),
	"jaw": Vector3(0, 1.255, -0.05),
	"shR": Vector3(0.19, 1.03, -0.02), "elR": Vector3(0.25, 0.81, -0.22), "wrR": Vector3(0.15, 0.795, -0.46),
	"shL": Vector3(-0.19, 1.03, -0.02), "elL": Vector3(-0.25, 0.80, -0.22), "wrL": Vector3(-0.16, 0.785, -0.46),
}
# the rest pose: head hanging toward the plate, lolled to her left
const HEAD_REST := Vector3(-0.55, 0.12, 0.28)
const JAW_REST := 0.1      # hanging slack
const JAW_OPEN := 0.38     # when she looks at you

var joints := {}          # name -> Node3D pivot
var rng := RandomNumberGenerator.new()
var _mats := {}
var flies: CPUParticles3D

func _ready() -> void:
	rng.seed = 47
	_build()
	joints.head.rotation = HEAD_REST
	joints.jaw.rotation.x = -JAW_REST     # negative opens: the chin swings down and forward

## Turns her head to look at a world point (yaw and pitch, limited to what a neck can do, and
## then a little more), the jaw dropping with it.
func face(world_point: Vector3, jaw_open := JAW_OPEN) -> void:
	var neck: Node3D = joints.neck
	var local := neck.global_transform.affine_inverse() * world_point - (J.head - J.neck)
	var yaw := clampf(atan2(-local.x, -local.z), -1.5, 1.5)
	var pitch := clampf(atan2(local.y, Vector2(local.x, local.z).length()), -0.9, 0.7)
	joints.head.rotation = Vector3(pitch, yaw, -yaw * 0.15)
	joints.jaw.rotation.x = -jaw_open

# ---------------------------------------------------------------- materials
const TONE := {"flesh": 0.62, "coral": 0.72, "slime": 0.6, "cloth": 0.8, "bone": 0.75, "teeth": 0.8}

func mat(tex: String, rough := 0.85, spec := 0.5, glow := 0.0) -> ShaderMaterial:
	var key := "%s/%s/%s" % [tex, rough, glow]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new(); m.shader = PS1
	m.set_shader_parameter("albedo_tex", RotTextures.get_tex(tex))
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("specular", spec)
	var k: float = TONE.get(tex, 1.0)
	m.set_shader_parameter("albedo_color", Color(k, k, k))
	if glow > 0.0:
		m.set_shader_parameter("emission", Vector3(0.75, 0.78, 0.7) * glow)
	_mats[key] = m
	return m

# ---------------------------------------------------------------- parts
## A part is a set of SurfaceTools (one per material) that becomes one mesh on one joint.
class Part:
	var sts := {}
	var owner: MartaModel
	func _init(o: MartaModel) -> void: owner = o
	func st(m: Material) -> SurfaceTool:
		if not sts.has(m):
			var s := SurfaceTool.new(); s.begin(Mesh.PRIMITIVE_TRIANGLES); sts[m] = s
		return sts[m]
	func mesh() -> ArrayMesh:
		var am := ArrayMesh.new()
		for m in sts:
			var s: SurfaceTool = sts[m]
			s.index(); s.generate_normals()
			s.commit(am)
			am.surface_set_material(am.get_surface_count() - 1, m)
		return am

## Puts a part's mesh (built in rest-pose local space) on a joint.
func _attach(part: Part, joint: Node3D, joint_rest: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = part.mesh()
	mi.position = -joint_rest
	joint.add_child(mi)
	return mi

func _joint(name: String, parent: Node3D, parent_rest: Vector3) -> Node3D:
	var n := Node3D.new(); n.name = name
	n.position = J[name] - parent_rest
	parent.add_child(n)
	joints[name] = n
	return n

func _build() -> void:
	var flesh := mat("flesh", 0.38, 0.45)    # wet
	var flesh_dry := mat("flesh", 0.7)
	var coralm := mat("coral", 0.75)
	var cloth := mat("cloth", 0.95, 0.2)
	var slime := mat("slime", 0.15, 0.55)
	var teeth := mat("teeth", 0.4)
	var gums := mat("gums", 0.2, 0.7)
	var black := mat("black", 1.0, 0.0)
	var eye := mat("eye", 0.08, 0.9, 0.3)     # they catch what light there is
	var hair := mat("hair", 0.8)
	var bone := mat("bone", 0.6)
	var wood := mat("wood", 0.7)
	var pud := mat("puddle", 0.06, 0.9)

	var hips := _joint("hips", self, Vector3.ZERO)
	var neck := _joint("neck", hips, J.hips)
	var head := _joint("head", neck, J.neck)
	var jaw := _joint("jaw", head, J.head)
	var shR := _joint("shR", hips, J.hips); var elR := _joint("elR", shR, J.shR); var wrR := _joint("wrR", elR, J.elR)
	var shL := _joint("shL", hips, J.hips); var elL := _joint("elL", shL, J.shL); var wrL := _joint("wrL", elL, J.elL)

	# ------------------------------------------------ the chair, the puddle, the roots (don't move)
	var base := Part.new(self)
	var w := base.st(wood)
	MeshKit.box(w, Vector3(0, 0.44, 0), Vector3(0.42, 0.04, 0.42))
	for sx in [-0.18, 0.18]:
		for sz in [-0.18, 0.18]:
			MeshKit.box(w, Vector3(sx, 0.21, sz), Vector3(0.035, 0.42, 0.035))
		MeshKit.box(w, Vector3(sx, 0.72, 0.2), Vector3(0.035, 0.56, 0.035))
	MeshKit.box(w, Vector3(0, 0.9, 0.2), Vector3(0.4, 0.12, 0.025))
	# the puddle she's been draining into, spreading out under the table
	MeshKit.blob(base.st(pud), Vector3(0, 0.004, -0.12), Vector3(0.52, 0.01, 0.48), {"rings": 6, "segs": 20, "bumps": 0.35, "freq": 3.0, "seed": 3})
	for i in 7:
		var a := rng.randf() * TAU; var d := rng.randf_range(0.45, 0.75)
		MeshKit.blob(base.st(pud), Vector3(cos(a) * d, 0.003, -0.12 + sin(a) * d), Vector3.ONE * rng.randf_range(0.04, 0.1) * Vector3(1, 0.1, 1), {"rings": 4, "segs": 9, "seed": i})
	# coral rooted in the floor, climbing the chair legs and fusing into the seat and her back
	for sx in [-0.2, 0.2]:
		for sz in [-0.2, 0.2]:
			for k in 2:
				MeshKit.coral(base.st(coralm), Vector3(sx + rng.randf_range(-0.06, 0.06), 0.0, sz + rng.randf_range(-0.06, 0.06)), Vector3(-sx, 1.6, -sz * 0.3), rng.randf_range(0.1, 0.18), 0.032, rng, 1)
			MeshKit.lump(base.st(coralm), Vector3(sx, 0.02, sz), 0.06, rng)
	for i in 9:
		MeshKit.lump(base.st(coralm), Vector3(rng.randf_range(-0.22, 0.22), 0.44, rng.randf_range(-0.22, 0.24)), rng.randf_range(0.025, 0.05), rng)
	# between her back and the chair back: she's grown into it
	for i in 6:
		MeshKit.coral(base.st(coralm), Vector3(rng.randf_range(-0.14, 0.14), rng.randf_range(0.55, 0.85), 0.19), Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.2, 1.0), 1.0), rng.randf_range(0.08, 0.14), 0.03, rng, 1)
	# coral on the table that has grown up into her forearms (stays when she pulls free)
	for side in [-1.0, 1.0]:
		for i in 4:
			var p := Vector3(side * rng.randf_range(0.12, 0.26), 0.775, rng.randf_range(-0.5, -0.28))
			MeshKit.coral(base.st(coralm), p, Vector3(rng.randf_range(-0.4, 0.4), 1.0, rng.randf_range(-0.4, 0.4)), rng.randf_range(0.04, 0.07), 0.018, rng, 1)
			MeshKit.lump(base.st(coralm), p, 0.03, rng)
	# strands of her, stretched from the seat edge to the puddle
	for i in 7:
		var x := rng.randf_range(-0.2, 0.2); var z := rng.randf_range(-0.4, -0.1)
		var top := Vector3(x, 0.44, z); var bot := Vector3(x + rng.randf_range(-0.08, 0.08), 0.005, z - rng.randf_range(0.0, 0.12))
		var pts := []; var rr := []
		for k in 6:
			var t := float(k) / 5.0
			pts.append(top.lerp(bot, t) + Vector3(0, 0, -sin(t * PI) * 0.03))
			rr.append(lerpf(0.016, 0.024, t) * (1.0 - 0.8 * sin(t * PI)))
		MeshKit.tube(base.st(slime), pts, rr, {"sides": 5})
	# what she leaves behind on the seat and the cloth when she's gone (hidden under her until then)
	for i in 6:
		MeshKit.blob(base.st(flesh), Vector3(rng.randf_range(-0.15, 0.15), 0.465, rng.randf_range(-0.18, 0.12)), Vector3(0.06, 0.012, 0.07), {"rings": 4, "segs": 8, "sag": 0.5, "bumps": 0.4, "seed": 80 + i})
	for side in [-1.0, 1.0]:
		for i in 3:
			MeshKit.blob(base.st(slime), Vector3(side * rng.randf_range(0.12, 0.24), 0.773, rng.randf_range(-0.5, -0.24)), Vector3(0.05, 0.004, 0.035), {"rings": 3, "segs": 8, "bumps": 0.4, "seed": 90 + i})
	_attach(base, self, Vector3.ZERO)

	# ------------------------------------------------ hips: lap, thighs, shins, feet (melting)
	var low := Part.new(self)
	MeshKit.blob(low.st(cloth), Vector3(0, 0.51, -0.12), Vector3(0.21, 0.08, 0.25), {"sag": 0.9, "bumps": 0.18, "seed": 1})
	for s in [-1.0, 1.0]:
		MeshKit.blob(low.st(flesh), Vector3(s * 0.11, 0.49, -0.36), Vector3(0.075, 0.06, 0.1), {"sag": 0.7, "bumps": 0.25, "seed": 2 + s})
		MeshKit.blob(low.st(flesh), Vector3(s * 0.12, 0.47, -0.41), Vector3(0.062, 0.058, 0.058), {"sag": 0.5, "bumps": 0.3, "seed": 4 + s})
		MeshKit.tube(low.st(flesh), [Vector3(s * 0.12, 0.44, -0.42), Vector3(s * 0.125, 0.33, -0.43), Vector3(s * 0.13, 0.2, -0.44), Vector3(s * 0.135, 0.08, -0.45)], [0.052, 0.046, 0.04, 0.056], {"sides": 7, "bumps": 0.35, "seed": 5 + s})
		MeshKit.blob(low.st(flesh), Vector3(s * 0.14, 0.03, -0.5), Vector3(0.065, 0.035, 0.12), {"sag": 0.8, "bumps": 0.3, "seed": 6 + s})
		MeshKit.coral(low.st(coralm), Vector3(s * 0.13, 0.25, -0.47), Vector3(s, 0.3, -1), 0.07, 0.02, rng, 1)
		# drips hanging off the knee
		for k in 2:
			var top := Vector3(s * 0.12 + rng.randf_range(-0.03, 0.03), 0.43, -0.46)
			var ln := rng.randf_range(0.06, 0.16)
			MeshKit.tube(low.st(slime), [top, top + Vector3(0, -ln * 0.5, 0), top + Vector3(0, -ln, 0)], [0.007, 0.003, 0.0015], {"sides": 4})
			MeshKit.blob(low.st(slime), top + Vector3(0, -ln - 0.008, 0), Vector3.ONE * 0.005, {"rings": 4, "segs": 6})
	_attach(low, hips, J.hips)

	# ------------------------------------------------ torso (on the hips joint: it doesn't bend)
	var tor := Part.new(self)
	MeshKit.blob(tor.st(flesh), Vector3(0, 0.66, -0.06), Vector3(0.17, 0.14, 0.15), {"sag": 1.1, "bumps": 0.2, "seed": 7})        # belly, slumped into her lap
	MeshKit.blob(tor.st(cloth), Vector3(0, 0.8, -0.02), Vector3(0.188, 0.2, 0.135), {"sag": 0.5, "bumps": 0.14, "seed": 8})
	MeshKit.blob(tor.st(flesh), Vector3(0, 0.95, 0.0), Vector3(0.18, 0.1, 0.12), {"sag": 0.6, "bumps": 0.2, "seed": 9})            # upper chest, shoulders' slope
	MeshKit.blob(tor.st(flesh), Vector3(0, 0.92, 0.07), Vector3(0.17, 0.14, 0.08), {"bumps": 0.25, "seed": 10})                     # the hunched back
	for s in [-1.0, 1.0]:
		MeshKit.blob(tor.st(flesh), Vector3(s * 0.17, 1.0, -0.02), Vector3(0.075, 0.07, 0.075), {"sag": 0.4, "bumps": 0.3, "seed": 11 + s})
	# the dress has rotted through over her left ribs: a hole, and the ribs inside it
	MeshKit.blob(tor.st(black), Vector3(-0.1, 0.83, -0.125), Vector3(0.075, 0.085, 0.03), {"rings": 6, "segs": 10, "seed": 12})
	for k in 5:
		var y := 0.77 + k * 0.03
		var pts := []
		for a in 6:
			var t := float(a) / 5.0
			pts.append(Vector3(-0.03 - t * 0.15, y - t * 0.03, -0.14 + t * t * 0.07))
		MeshKit.tube(tor.st(bone), pts, [0.007, 0.008, 0.008, 0.008, 0.007, 0.006], {"sides": 4})
	# skin sloughing off down the front of the dress: loose flaps, slid and puddled at her waist
	for k in 5:
		MeshKit.blob(tor.st(flesh), Vector3(rng.randf_range(-0.13, 0.13), rng.randf_range(0.72, 0.9), -0.13), Vector3(0.035, 0.05, 0.012), {"rings": 5, "segs": 7, "sag": 1.2, "bumps": 0.4, "seed": 60 + k})
	# neck: thin, split, the tendons standing out
	MeshKit.tube(tor.st(flesh), [Vector3(0, 0.98, -0.03), Vector3(0, 1.08, -0.05), Vector3(0, 1.18, -0.08)], [0.058, 0.045, 0.042], {"sides": 7, "bumps": 0.3, "seed": 13})
	# coral out of her back and shoulders: her silhouette from the doorway
	for i in 14:
		var p := Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(0.72, 1.02), 0.11 + rng.randf_range(0.0, 0.04))
		MeshKit.coral(tor.st(coralm), p, Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.3, 1.2), 1.0), rng.randf_range(0.07, 0.15), rng.randf_range(0.024, 0.04), rng, 2)
	for s in [-1.0, 1.0]:
		for i in 3:
			MeshKit.coral(tor.st(coralm), Vector3(s * 0.19, 1.04, rng.randf_range(-0.05, 0.05)), Vector3(s * 0.8, 1.0, rng.randf_range(-0.4, 0.4)), rng.randf_range(0.07, 0.12), 0.03, rng, 1)
	for i in 40:
		var a := rng.randf_range(-PI * 0.95, PI * 0.95)
		MeshKit.lump(tor.st(coralm), Vector3(sin(a) * 0.175, rng.randf_range(0.66, 1.06), cos(a) * 0.115 + 0.01), rng.randf_range(0.02, 0.045), rng)
	_attach(tor, hips, J.hips)

	# ------------------------------------------------ head (upright here; the joint droops it)
	var hd := Part.new(self)
	var H := Vector3(0, 1.28, -0.09)
	MeshKit.blob(hd.st(flesh), H, Vector3(0.078, 0.108, 0.095), {"slide": 0.55, "sag": 0.25, "bumps": 0.16, "freq": 8.0, "seed": 20})
	MeshKit.blob(hd.st(flesh_dry), H + Vector3(0, 0.038, -0.078), Vector3(0.062, 0.016, 0.024), {"rings": 5, "segs": 10, "bumps": 0.3, "seed": 24})   # brow
	for s2 in [-1.0, 1.0]:
		MeshKit.blob(hd.st(flesh_dry), H + Vector3(s2 * 0.055, -0.012, -0.068), Vector3(0.022, 0.016, 0.026), {"rings": 5, "segs": 7, "bumps": 0.3, "seed": 25 + s2})   # cheekbones
		MeshKit.blob(hd.st(bone), H + Vector3(s2 * 0.072, 0.03, -0.04), Vector3(0.012, 0.022, 0.02), {"rings": 4, "segs": 6, "bumps": 0.2})                         # temple, worn through
	MeshKit.blob(hd.st(bone), H + Vector3(-0.025, 0.07, 0.01), Vector3(0.06, 0.04, 0.065), {"bumps": 0.1, "seed": 21})     # skull where the scalp has gone
	# eyes: sunk into black sockets, milky; her left one has slid down her cheek
	for s in [-1.0, 1.0]:
		MeshKit.blob(hd.st(black), H + Vector3(s * 0.032, 0.012, -0.085), Vector3(0.024, 0.022, 0.016), {"rings": 6, "segs": 8, "bumps": 0.35, "freq": 20.0, "seed": 22 + s})
	var eyes := [H + Vector3(0.032, 0.012, -0.093), H + Vector3(-0.035, -0.012, -0.096)]
	for e in eyes:
		MeshKit.blob(hd.st(eye), Vector3.ZERO, Vector3.ONE * 0.012, {"rings": 6, "segs": 8, "bumps": 0.0, "xf": Transform3D(Basis(Vector3.UP, -PI / 2), e)})
		# the upper lid, gone soft, hanging half over it
		MeshKit.blob(hd.st(flesh), e + Vector3(0, 0.0115, 0.001), Vector3(0.016, 0.0055, 0.011), {"rings": 5, "segs": 8, "sag": 0.6, "bumps": 0.3, "seed": e.x * 100.0})
	MeshKit.tube(hd.st(slime), [eyes[1] + Vector3(0, -0.01, -0.004), eyes[1] + Vector3(-0.004, -0.04, -0.006), eyes[1] + Vector3(-0.006, -0.075, -0.004)], [0.006, 0.004, 0.002], {"sides": 4})
	# the nose has fallen in
	for s in [-1.0, 1.0]:
		MeshKit.blob(hd.st(black), H + Vector3(s * 0.008, -0.022, -0.1), Vector3(0.008, 0.013, 0.006), {"rings": 4, "segs": 6})
	# the grin: no lips, the cheeks split back toward the ears, every tooth showing
	_grin(hd, true, H)
	# hair, what's left: wet clumps down to her shoulders
	for i in 12:
		var a := rng.randf_range(-1.35, 1.35)       # back and sides only: rigid strands over the face read as bars
		var root := H + Vector3(sin(a) * 0.08, 0.06 + rng.randf_range(-0.02, 0.02), cos(a) * 0.085)
		var hang := rng.randf_range(0.14, 0.28)
		MeshKit.tube(hd.st(hair), [root, root + Vector3(sin(a) * 0.03, -hang * 0.4, cos(a) * 0.02), root + Vector3(sin(a) * 0.04, -hang, cos(a) * 0.03)], [0.012, 0.008, 0.003], {"sides": 4})
	# coral: out of her left cheek, and up out of the crown
	MeshKit.coral(hd.st(coralm), H + Vector3(-0.075, -0.02, -0.03), Vector3(-1, 0.4, -0.3), 0.06, 0.018, rng, 1)
	for i in 3:
		MeshKit.coral(hd.st(coralm), H + Vector3(rng.randf_range(0.0, 0.05), 0.09, rng.randf_range(-0.02, 0.05)), Vector3(rng.randf_range(-0.3, 0.6), 1.0, rng.randf_range(-0.2, 0.5)), rng.randf_range(0.05, 0.09), 0.02, rng, 1)
	for i in 6:
		MeshKit.lump(hd.st(coralm), H + Vector3(rng.randf_range(-0.07, 0.07), rng.randf_range(-0.02, 0.09), rng.randf_range(0.02, 0.09)), rng.randf_range(0.01, 0.022), rng)
	_attach(hd, head, J.head)

	# ------------------------------------------------ jaw: chin, lower teeth, what hangs off it
	var jw := Part.new(self)
	MeshKit.blob(jw.st(flesh), H + Vector3(0, -0.085, -0.03), Vector3(0.06, 0.035, 0.06), {"sag": 0.9, "slide": 0.4, "bumps": 0.25, "seed": 30})
	_grin(jw, false, H)
	# beads of fluid hanging off the chin
	for i in 5:
		var top := H + Vector3(rng.randf_range(-0.04, 0.04), -0.112, -0.06 + rng.randf_range(-0.02, 0.02))
		MeshKit.blob(jw.st(slime), top, Vector3(0.004, 0.009, 0.004), {"rings": 4, "segs": 5, "sag": 1.0})
	_attach(jw, jaw, J.jaw)

	# ------------------------------------------------ arms, resting on the table, hands melted into the cloth
	for side in ["R", "L"]:
		var s := 1.0 if side == "R" else -1.0
		var sh: Vector3 = J["sh" + side]; var el: Vector3 = J["el" + side]; var wr: Vector3 = J["wr" + side]
		var up := Part.new(self)
		MeshKit.tube(up.st(flesh), [sh, sh.lerp(el, 0.5) + Vector3(s * 0.01, -0.01, 0), el], [0.05, 0.046, 0.042], {"sides": 7, "bumps": 0.35, "seed": 40 + s})
		for k in 2:
			MeshKit.coral(up.st(coralm), sh.lerp(el, rng.randf_range(0.2, 0.7)) + Vector3(s * 0.04, 0, 0.01), Vector3(s, 0.6, 0.3), rng.randf_range(0.05, 0.08), 0.02, rng, 1)
		_attach(up, joints["sh" + side], sh)
		var fo := Part.new(self)
		MeshKit.tube(fo.st(flesh), [el, el.lerp(wr, 0.5) + Vector3(0, -0.012, 0), wr], [0.043, 0.036, 0.03], {"sides": 7, "bumps": 0.4, "seed": 42 + s})
		MeshKit.blob(fo.st(flesh), el + Vector3(0, -0.02, 0), Vector3(0.05, 0.035, 0.05), {"sag": 0.8, "bumps": 0.3, "seed": 43 + s})   # the elbow, spread on the table edge
		for k in 3:
			MeshKit.lump(fo.st(coralm), el.lerp(wr, rng.randf_range(0.1, 0.9)) + Vector3(rng.randf_range(-0.03, 0.03), 0.03, 0), rng.randf_range(0.012, 0.022), rng)
		_attach(fo, joints["el" + side], el)
		var hn := Part.new(self)
		var palm := wr + Vector3(0, -0.012, -0.055)
		MeshKit.blob(hn.st(flesh), palm, Vector3(0.042, 0.014, 0.05), {"sag": 0.9, "bumps": 0.3, "seed": 44 + s})
		# fingers: too long now the flesh has let go of them, splayed flat, nails lifting
		for f in 5:
			var fan := (f - 2) * 0.22 - s * 0.1
			var k0 := palm + Vector3(sin(fan) * 0.035, 0.0, -0.04)
			var dir := Vector3(sin(fan) * 0.6, 0, -1).normalized()
			var ln := 0.1 + 0.025 * (1.0 - absf(f - 2) / 2.0)
			if f == (4 if side == "R" else 0):
				dir = Vector3(s * 1.0, 0, -0.4).normalized(); ln = 0.07         # thumb
			var pts := [k0, k0 + dir * ln * 0.45 + Vector3(0, 0.006, 0), k0 + dir * ln * 0.8, k0 + dir * ln + Vector3(0, -0.006, 0)]
			MeshKit.tube(hn.st(flesh), pts, [0.011, 0.009, 0.008, 0.006], {"sides": 5, "bumps": 0.3, "seed": 45 + f})
			MeshKit.box(hn.st(bone), k0 + dir * (ln - 0.008) + Vector3(0, 0.004, 0), Vector3(0.012, 0.003, 0.014), Basis.looking_at(dir))
		_attach(hn, joints["wr" + side], wr)

	# flies
	flies = CPUParticles3D.new()
	flies.amount = 18; flies.lifetime = 3.0; flies.preprocess = 3.0
	flies.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; flies.emission_sphere_radius = 0.22
	flies.gravity = Vector3.ZERO; flies.direction = Vector3(0, 1, 0); flies.spread = 180.0
	flies.initial_velocity_min = 0.2; flies.initial_velocity_max = 0.6
	flies.orbit_velocity_min = 0.3; flies.orbit_velocity_max = 0.9
	flies.tangential_accel_min = -2.0; flies.tangential_accel_max = 2.0
	flies.radial_accel_min = -1.2; flies.radial_accel_max = -0.6
	flies.damping_min = 0.2; flies.damping_max = 0.5
	var fm := BoxMesh.new(); fm.size = Vector3(0.006, 0.004, 0.008)
	var fmat := StandardMaterial3D.new(); fmat.albedo_color = Color(0.02, 0.02, 0.02); fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.material = fmat
	flies.mesh = fm
	flies.position = H + Vector3(0, -0.05, -0.05)
	add_child(flies)

## The grin follows the face round toward the ears with the corners turned up: no lips, the
## cheeks torn back in ragged raw edges, small crooked brown teeth in shrunken gums, and strings
## of tissue still spanning the gap. Upper half on the head, lower half on the jaw.
func _grin(part: Part, upper: bool, H: Vector3) -> void:
	const A := 1.7             # half the arc, radians: nearly ear to ear
	const N := 30              # teeth per row
	var M := H + Vector3(0, -0.05, 0.0)
	var rx := 0.088; var rz := 0.103
	var at := func(a: float, y: float, k := 1.0) -> Vector3:
		var corner := 0.026 * pow(absf(a) / A, 2.4)
		return M + Vector3(sin(a) * rx * k, y + corner, -cos(a) * rz * k)
	var teeth := mat("teeth", 0.45, 0.3); var gums := mat("gums", 0.18, 0.6); var black := mat("black", 1.0, 0.0); var slime := mat("slime", 0.1, 0.8)
	var sgn := 1.0 if upper else -1.0
	var r := RandomNumberGenerator.new(); r.seed = 471 if upper else 472
	# the black of the mouth, then shrunken gum, then the torn edge of the cheek (ragged: its
	# width wanders), each a band following the arc
	var steps := 34
	var g := []
	for i in steps + 1:
		var a := lerpf(-A, A, float(i) / steps)
		var rag := 0.006 + 0.008 * absf(sin(a * 7.3 + (0.0 if upper else 2.0))) + r.randf_range(0.0, 0.005)
		g.append([at.call(a, 0.0, 0.975), at.call(a, sgn * 0.012, 0.99), at.call(a, sgn * (0.018 + rag * 0.4), 1.0), at.call(a, sgn * (0.022 + rag), 1.015)])
	var bands := [part.st(black), part.st(gums), part.st(gums)]
	for i in steps:
		for k in 3:
			var st: SurfaceTool = bands[k]
			var a: Vector3 = g[i][k]; var b: Vector3 = g[i + 1][k]; var c: Vector3 = g[i + 1][k + 1]; var d: Vector3 = g[i][k + 1]
			for tri in [[a, b, c], [a, c, d], [a, c, b], [a, d, c]]:      # both faces: it's seen edge-on from the side
				MeshKit._tri(st, tri[0], tri[1], tri[2], Vector2.ZERO, Vector2.RIGHT, Vector2.ONE)
	# the raw rim of the torn cheek, lumpy
	var rim := []; var rr := []
	for i in steps + 1:
		rim.append(g[i][3]); rr.append(0.0035 + r.randf_range(0.0, 0.003))
	MeshKit.tube(part.st(gums), rim, rr, {"sides": 4, "cap": false})
	# teeth: small, crowded, crooked, some gone, the back ones long in the root
	for i in N:
		var a := lerpf(-A * 0.95, A * 0.95, (i + 0.5) / N)
		if r.randf() < 0.15:
			continue
		var len := r.randf_range(0.009, 0.016) * (1.0 + 0.7 * absf(a) / A)
		var c: Vector3 = at.call(a, sgn * (0.002 + len * 0.5), 0.995)
		var out := Vector3(sin(a), 0, -cos(a))
		var bas := Basis.looking_at(-out, Vector3.UP).rotated(out, r.randf_range(-0.35, 0.35)).rotated(Vector3.UP, r.randf_range(-0.3, 0.3))
		MeshKit.box(part.st(teeth), c, Vector3(r.randf_range(0.006, 0.009), len, 0.006), bas)
	# strings of tissue and spit across the gap (on the jaw, so they stretch when it drops)
	if not upper:
		for k in 7:
			var a := r.randf_range(-A * 0.8, A * 0.8)
			var top: Vector3 = at.call(a, 0.016, 0.99); var bot: Vector3 = at.call(a + r.randf_range(-0.15, 0.15), -0.014, 0.99)
			MeshKit.tube(part.st(slime), [top, top.lerp(bot, 0.5) + Vector3(0, -0.002, -0.002), bot], [0.0018, 0.0009, 0.0018], {"sides": 3})
