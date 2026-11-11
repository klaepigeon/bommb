class_name CreatureBody
extends Node3D
## The one shape every creature's body has for the AI: pose(p) each frame, set_zone (which room's
## lamps light it), set_glow, head_pos. Underneath, each creature keeps its own model and its own
## way of moving: the previous build's sculpted rigs (SuperRig, MartaModel, InfectedBody), ported
## onto the game's lighting and improved, or the new Body.
##
## p (all optional): dt, speed (m/s), mode ("idle", "walk", "hunt", "stagger", "grab", "dead",
## "calm", "talk"), look_at (world point or null), reach (0..1), sit, stoop, look (Vector2), twitch.

var head_pos := Vector3.ZERO
var mats: Array[ShaderMaterial] = []

func _collect() -> void:
	mats.clear()
	var seen := {}
	for mi in find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if m.material_override is ShaderMaterial and not seen.has(m.material_override):
			seen[m.material_override] = true; mats.append(m.material_override)
		for i in m.get_surface_override_material_count():
			var o := m.get_surface_override_material(i)
			if o is ShaderMaterial and not seen.has(o): seen[o] = true; mats.append(o)
		if m.mesh:
			for i in m.mesh.get_surface_count():
				var s := m.mesh.surface_get_material(i)
				if s is ShaderMaterial and not seen.has(s): seen[s] = true; mats.append(s)

func set_zone(z: int) -> void:
	for m in mats: m.set_shader_parameter("zone", float(z))

func set_glow(c: Color) -> void:
	for m in mats: m.set_shader_parameter("emission", Vector3(c.r, c.g, c.b))

func set_ambient(a: Vector3) -> void:
	for m in mats: m.set_shader_parameter("ambient", a)

func pose(_p: Dictionary) -> void:
	pass

static func mode_of(state_name: String) -> String:
	match state_name:
		"hunt", "investigate": return "hunt"
		"grab": return "grab"
		"stagger", "stunned": return "stagger"
		"dead": return "dead"
	return "idle"


## ---------------------------------------------------------------- the Super (SuperRig, ported)
class SuperBody extends CreatureBody:
	var rig: SuperRig
	func build() -> void:
		rig = SuperRig.new(); rig.name = "SuperRig"
		add_child(rig)
		rig.build()
		_collect()
	func pose(p: Dictionary) -> void:
		var look = p.get("look_at")
		var ctx := {"speed": float(p.get("speed", 0.0)), "mode": String(p.get("mode", "idle"))}
		if look != null: ctx["look"] = rig.to_local(look)
		rig.animate(float(p.get("dt", 0.016)), ctx)
		head_pos = rig.bone_global("head").origin + Vector3(0, 0.12, 0)
	func flinch(from: Vector3, head := false) -> void:
		rig.flinch(rig.global_transform.basis.inverse() * from, 1.0, head)


## ---------------------------------------------------------------- an infected (InfectedBody, ported)
class InfectedFlesh extends CreatureBody:
	var flesh: InfectedBody
	func build(genome: Dictionary) -> void:
		flesh = InfectedBody.new(); flesh.name = "Flesh"
		add_child(flesh)
		flesh.build(genome)
		_collect()
	func pose(p: Dictionary) -> void:
		var mode := String(p.get("mode", "idle"))
		var speed := float(p.get("speed", 0.0))
		if mode == "idle" and speed > 0.05: mode = "walk"
		var ctx := {"speed": speed, "mode": mode, "attack": float(p.get("reach", 0.0))}
		var look = p.get("look_at")
		if look != null: ctx["look"] = look
		flesh.animate(float(p.get("dt", 0.016)), ctx)
		var hb: Transform3D = flesh.skel.global_transform * flesh.skel.get_bone_global_pose(flesh.bones.head)
		head_pos = hb.origin + Vector3(0, 0.08 * flesh.s, 0)
	func flinch(from: Vector3, _head := false) -> void:
		flesh.flinch(from, 1.0)


## ---------------------------------------------------------------- Marta (MartaModel, ported)
## At her table: the chair, the roots, the puddle, the flies. Hunting: the chair gone, still seated
## on nothing, coral roots trailing from under her where they tore out of the floor.
class MartaBody extends CreatureBody:
	var model: MartaModel
	var chair: Array[Node] = []
	var head_lift := 0.0
	var _t := 0.0
	var _reach := 0.0
	var _roots: Node3D
	func build(at_table: bool) -> void:
		model = MartaModel.new(); model.name = "Model"
		add_child(model)
		for c in model.get_children():
			if c is MeshInstance3D or c is CPUParticles3D: chair.append(c)
		if not at_table:
			for c in chair: (c as Node3D).visible = false
			_trailing_roots()
		_collect()
	## What she tore out of the floor when she got up: coral, hanging from under her, swinging.
	func _trailing_roots() -> void:
		_roots = Node3D.new(); _roots.name = "Roots"
		model.joints.hips.add_child(_roots)
		var kit := Kit.new()
		var rng := RandomNumberGenerator.new(); rng.seed = 1947
		var coral := Mats.tex(Tex.get_tex("coral"), -1).duplicate() as ShaderMaterial
		for i in 7:
			var top := Vector3(rng.randf_range(-0.16, 0.16), 0.42, rng.randf_range(-0.12, 0.2))
			var p := top
			for j in 4:
				var q := p + Vector3(rng.randf_range(-0.05, 0.05), -rng.randf_range(0.07, 0.13), rng.randf_range(-0.04, 0.05))
				kit.blob(coral, (p + q) * 0.5, Vector3(0.022, 0.07, 0.022) * (1.0 - j * 0.18), rng, 0.3)
				p = q
		kit.commit(_roots, "Roots")
	func pose(p: Dictionary) -> void:
		var dt := float(p.get("dt", 0.016))
		_t += dt
		var j: Dictionary = model.joints
		# her head hangs (stoop) or comes up to look at him
		var want_lift := 1.0 - clampf(float(p.get("stoop", 0.0)), 0.0, 1.0)
		if p.has("look_at") and p.look_at != null: want_lift = maxf(want_lift, 0.8)
		head_lift = move_toward(head_lift, want_lift, dt * 2.5)
		var rest := MartaModel.HEAD_REST
		var lifted := rest
		var target = p.get("look_at")
		if target == null and p.has("look"):
			var lv: Vector2 = p.look
			lifted = Vector3(lv.y * 0.6, lv.x * 0.9, -lv.x * 0.1)
		elif target != null:
			var saved: Vector3 = j.head.rotation
			model.face(target)
			lifted = j.head.rotation
			j.head.rotation = saved
		var tw := float(p.get("twitch", 0.0))
		var tremor := Vector3(sin(_t * 13.0), sin(_t * 9.0), 0) * (0.008 + 0.03 * tw * (1.0 if fmod(_t, 2.1) < 0.2 else 0.0)) * maxf(head_lift, 0.3)
		j.head.rotation = rest.lerp(lifted, head_lift) + tremor
		j.jaw.rotation.x = -(lerpf(MartaModel.JAW_REST, MartaModel.JAW_OPEN, head_lift) + Speech.mouth("marta") * 0.18)
		j.hips.position.y = MartaModel.J.hips.y + sin(_t * TAU / 4.2) * 0.004
		# the right arm comes up and out at him
		_reach = move_toward(_reach, clampf(float(p.get("reach", 0.0)), 0.0, 1.0), dt * 4.0)
		j.shR.rotation = Vector3(-1.1 * _reach, -0.3 * _reach, 0.25 * _reach)
		j.elR.rotation = Vector3(0.4 * _reach, 0, 0)
		j.shL.rotation = Vector3(-0.35 * _reach, 0.2 * _reach, -0.1 * _reach)
		if _roots:
			_roots.rotation = Vector3(sin(_t * 1.3) * 0.12 + float(p.get("speed", 0.0)) * 0.25, 0, sin(_t * 0.9) * 0.1)
		head_pos = (j.head as Node3D).global_position + Vector3(0, 0.1, 0)
	func vanish() -> void:
		model.joints.hips.visible = false
		if model.flies: model.flies.emitting = false; model.flies.visible = false
