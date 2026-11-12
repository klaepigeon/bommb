class_name KurtBody
extends Node3D
## The rest of Kurt, for when he looks down: coat, trousers, shoes, on a small skeleton of joints
## (hips, thighs, shins, feet) that walks with him and crouches when he does. His right arm is
## the Hands' KurtArm and his left is Socko's, both on the camera; this hangs on the body and
## turns with it. Kept a little behind the eye, as first-person bodies are, so the near plane
## never cuts into the chest.

var player: Player
var hips: Node3D
var legs := {}          # "L"/"R" -> {thigh, shin, foot}
var _phase := 0.0
var _crouch := 0.0

func attach(p: Player) -> void:
	player = p
	name = "KurtBody"
	p.add_child(self)
	_build()

func _mat(tex: String, tint: Color) -> Material:
	return Tex.mat(tex, 6.0, {"tint": tint})

func _part(parent: Node3D, draw: Callable, m: Material) -> MeshInstance3D:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	draw.call(st)
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func _build() -> void:
	var coat := _mat("fabric", Color(0.42, 0.4, 0.38))
	var trousers := _mat("fabric", Color(0.42, 0.42, 0.45))
	var shoe := _mat("black", Color(1.4, 1.3, 1.2))
	hips = Node3D.new(); hips.name = "Hips"; add_child(hips); hips.position = Vector3(0, 0.95, 0.16)
	# the coat: chest and belly, hanging open a little at the front, to mid-thigh
	_part(hips, func(st):
		MeshKit.blob(st, Vector3(0, 0.36, 0.04), Vector3(0.19, 0.2, 0.1), {"sag": 0.3, "bumps": 0.06, "seed": 3})     # chest, a thin old man's
		MeshKit.blob(st, Vector3(0, 0.1, 0.02), Vector3(0.17, 0.16, 0.1), {"sag": 0.5, "bumps": 0.06, "seed": 4})
		for s in [-1.0, 1.0]:
			MeshKit.box(st, Vector3(s * 0.08, -0.14, -0.07), Vector3(0.13, 0.32, 0.02))      # the coat's skirts
		, coat)
	# shirt and belt showing where the coat's open
	_part(hips, func(st): MeshKit.box(st, Vector3(0, 0.14, -0.08), Vector3(0.05, 0.3, 0.01)), _mat("enamel", Color(0.6, 0.58, 0.54)))
	_part(hips, func(st): MeshKit.box(st, Vector3(0, -0.03, -0.085), Vector3(0.1, 0.03, 0.012)), _mat("black", Color(1.6, 1.4, 1.2)))
	for side in ["L", "R"]:
		var s := -1.0 if side == "L" else 1.0
		var thigh := Node3D.new(); thigh.name = "Thigh" + side; hips.add_child(thigh); thigh.position = Vector3(s * 0.1, -0.05, -0.04)
		_part(thigh, func(st): MeshKit.tube(st, [Vector3.ZERO, Vector3(0, -0.22, -0.01), Vector3(0, -0.44, 0)], [0.075, 0.068, 0.058], {"sides": 7}), trousers)
		var shin := Node3D.new(); shin.name = "Shin" + side; thigh.add_child(shin); shin.position = Vector3(0, -0.44, 0)
		_part(shin, func(st): MeshKit.tube(st, [Vector3.ZERO, Vector3(0, -0.22, 0.01), Vector3(0, -0.43, 0)], [0.056, 0.05, 0.045], {"sides": 7}), trousers)
		var foot := Node3D.new(); foot.name = "Foot" + side; shin.add_child(foot); foot.position = Vector3(0, -0.43, 0)
		_part(foot, func(st):
			MeshKit.blob(st, Vector3(0, -0.035, -0.06), Vector3(0.05, 0.04, 0.13), {"sag": 0.2, "seed": 9})
			MeshKit.box(st, Vector3(0, -0.07, -0.06), Vector3(0.1, 0.014, 0.27))            # the sole
			, shoe)
		legs[side] = {"thigh": thigh, "shin": shin, "foot": foot}

func _process(delta: float) -> void:
	if not player: return
	visible = player.head_override < 0.0          # (cutscenes lying on the floor manage without him)
	var hv := Vector3(player.velocity.x, 0, player.velocity.z)
	var sp := hv.length()
	_phase += delta * sp * 3.6
	var c := 1.0 if player.crouching else 0.0
	_crouch = lerpf(_crouch, c, 1.0 - exp(-7.0 * delta))
	# walking: the legs swing about the hips in the direction he's going
	var local := player.global_basis.inverse() * hv
	var fwd := clampf(-local.z / 2.0, -1.0, 1.0); var side := clampf(local.x / 2.0, -1.0, 1.0)
	var amp := clampf(sp / 2.0, 0.0, 1.0) * 0.5
	hips.position = Vector3(0, 0.95 - _crouch * 0.42 + absf(sin(_phase)) * 0.02 * amp, 0.1 + _crouch * 0.05)
	hips.rotation.x = -_crouch * 0.35
	for k in legs:
		var s := 1.0 if k == "R" else -1.0
		var ph := _phase + (0.0 if k == "R" else PI)
		var swing := sin(ph) * amp
		var L: Dictionary = legs[k]
		(L.thigh as Node3D).rotation = Vector3(swing * fwd + _crouch * 1.25, 0, -swing * side * 0.6 + s * 0.04)
		(L.shin as Node3D).rotation = Vector3(-maxf(0.0, -cos(ph)) * amp * 1.4 - _crouch * 2.1, 0, 0)
		(L.foot as Node3D).rotation = Vector3(_crouch * 0.85, 0, 0)
