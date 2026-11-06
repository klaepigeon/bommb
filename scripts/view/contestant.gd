class_name Contestant
extends Node3D
## A contestant on screen: a PS1 human (Ps1Human, RATFORMER's people) wearing their face
## photo, walking where the match says they are, and wearing what the match has done to
## them. Lost parts go (their joint shrinks to nothing; a brass prosthetic can take its
## place), broken ones get a cast, burns a scorch, a lost eye a patch. Deaths are staged,
## one animation per way to go (DEATHS), and played once.

const DEATHS := ["trapdoor", "launch", "zap", "pop", "boom", "jaws", "clapper", "prize"]
const WALK_SPEED := 3.0

var seat := 0
var human: Ps1Human
var color := Color.WHITE
var target := Vector3.ZERO
var face_dir := 0.0
var dead := false
var seated := false
var body_state: Dictionary = {}
var _phase := 0.0
var _t := 0.0
var _extras: Dictionary = {}      # part -> Node3D added for an injury
var _speed_mul := 1.0
var _tw: Tween
var _limp := 0.0
var _helmet: Node3D
var _name_tag: Label3D


func setup(s: int, face: int, c: Color, display_name: String) -> void:
	seat = s
	color = c
	var shirts := [Color("c83a2a"), Color("2a6ac8"), Color("d8a820"), Color("38a050")]
	var hairs := [Color("3a2414"), Color("8a6a3a"), Color("1a1410"), Color("b8a070")]
	human = Ps1Human.make({"face": face, "shirt": c.darkened(0.15), "trousers": Color(0.18, 0.17, 0.22).lerp(c, 0.15),
		"hair": hairs[s % 4], "long_hair": s % 2 == 1, "glasses": s == 2, "bald": s == 3,
		"skin": [Color(0.86, 0.68, 0.58), Color(0.72, 0.52, 0.4), Color(0.9, 0.74, 0.64), Color(0.55, 0.38, 0.28)][s % 4]})
	add_child(human)
	# a party hat each, in their colour
	var hat := LcMB.new()
	hat.cyl("h", LcMB.mat(LcTex.solid(c.lightened(0.2))), 0.07, 0.0, 0.18, 6, LcMB.T(), Color(1, 1, 1))
	var hm := MeshInstance3D.new()
	hm.mesh = hat.build()
	hm.position = Vector3(0.02, 0.33, 0.0)
	hm.rotation.z = 0.25
	human.head.add_child(hm)
	_name_tag = Label3D.new()
	_name_tag.text = display_name
	_name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_tag.position = Vector3(0, 2.25, 0)
	_name_tag.pixel_size = 0.006
	_name_tag.font_size = 32
	_name_tag.outline_size = 8
	_name_tag.modulate = c.lightened(0.3)
	_name_tag.no_depth_test = true
	add_child(_name_tag)


func place(p: Vector3) -> void:
	position = p
	target = p


func walk_to(p: Vector3) -> void:
	target = p


func look_toward(p: Vector3) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() > 0.05:
		face_dir = atan2(d.x, d.z)


func _process(delta: float) -> void:
	_t += delta
	if human == null or dead:
		return
	var d := target - position
	d.y = 0.0
	var moving := d.length() > 0.04 and not seated
	if moving:
		var step := minf(d.length(), WALK_SPEED * _speed_mul * delta)
		position += d.normalized() * step
		face_dir = lerp_angle(face_dir, atan2(d.x, d.z), minf(1.0, delta * 10.0))
		_phase += delta * 9.0 * _speed_mul
		human.walk(_phase, 1.0)
	elif not seated:
		human.walk(_phase, 0.0)
		human.idle(_t + seat)
	rotation.y = lerp_angle(rotation.y, face_dir, minf(1.0, delta * 8.0))
	# a limp: one leg short
	human.hips.rotation.z = sin(_phase) * 0.12 * _limp if moving else 0.0
	_apply_losses()


func sit(on: bool) -> void:
	seated = on
	if on:
		human.sit()
	else:
		human.hips.position.y = 0.92


## Show what's been done to them (a PlayerState body, as the view sends it).
func set_body(b: Dictionary, helmet: bool) -> void:
	body_state = b
	_speed_mul = Body.speed(b)
	var legs_lost := int(b.leg_l.s == "lost") + int(b.leg_r.s == "lost")
	_limp = 1.0 if legs_lost == 1 else 0.0
	for part in Body.PARTS:
		_dress(part, str(b[part].s))
	if helmet and _helmet == null:
		var hb := LcMB.new()
		hb.sphere("h", LcMB.mat(LcTex.brass()), 0.16, 3, 8, LcMB.T(Vector3(0, 0.22, 0)), Color(1, 1, 1), Vector3(1, 0.8, 1.05))
		_helmet = MeshInstance3D.new()
		(_helmet as MeshInstance3D).mesh = hb.build()
		human.head.add_child(_helmet)
	elif not helmet and _helmet:
		_helmet.queue_free()
		_helmet = null


func _joint(part: String) -> Node3D:
	match part:
		"hand_l": return human.hand_l
		"hand_r": return human.hand_r
		"arm_l": return human.arm_l
		"arm_r": return human.arm_r
		"leg_l": return human.shin_l
		"leg_r": return human.shin_r
	return human.head


func _dress(part: String, s: String) -> void:
	var key := part + ":" + s
	if _extras.has(part) and _extras[part].name == key:
		return
	if _extras.has(part):
		_extras[part].queue_free()
		_extras.erase(part)
	if s == "ok":
		return
	var mb := LcMB.new()
	var parent := _joint(part)
	var at := Vector3.ZERO
	match s:
		"bruised":
			mb.box("x", LcMB.mat(LcTex.solid(Color("6a3a7a"))), Vector3(0.09, 0.08, 0.02), LcMB.T(Vector3(0, -0.12, 0.06)), Color(1, 1, 1))
		"burned":
			mb.box("x", LcMB.mat(LcTex.grime(Color("1a1008"), Color("4a2a10"), 16, 41, 0.4)), Vector3(0.11, 0.12, 0.11), LcMB.T(Vector3(0, -0.1, 0)), Color(1, 1, 1))
		"broken":
			mb.box("x", LcMB.mat(LcTex.paper(Color("f0ece0"), 7, 16)), Vector3(0.13, 0.26, 0.13), LcMB.T(Vector3(0, -0.18, 0)), Color(1, 1, 1))
		"prosthetic":
			var brass := LcMB.mat(LcTex.brass())
			if part.begins_with("leg"):
				mb.cyl("p", brass, 0.03, 0.045, 0.42, 6, LcMB.T(Vector3(0, -0.44, 0)), Color(1, 1, 1))
				mb.cyl("p", brass, 0.05, 0.05, 0.03, 6, LcMB.T(Vector3(0, -0.46, 0)), Color(0.7, 0.7, 0.7))
			else:
				mb.cyl("p", brass, 0.03, 0.03, 0.12, 6, LcMB.T(Vector3(0, -0.12, 0)), Color(1, 1, 1))
				mb.ring("p", brass, 0.04, 0.012, 6, LcMB.T(Vector3(0.0, -0.16, 0), Vector3(0, 0, PI / 2)), Color(1, 1, 1))
			parent = parent.get_parent() if part.begins_with("hand") or part.begins_with("leg") else parent.get_parent()
			at = _joint(part).position
		"lost":
			# a bandaged stump on the joint above
			mb.box("x", LcMB.mat(LcTex.paper(Color("e8dccc"), 9, 16)), Vector3(0.1, 0.06, 0.1), LcMB.T(Vector3(0, 0.02, 0)), Color(0.9, 0.7, 0.7))
			parent = _joint(part).get_parent()
			at = _joint(part).position
	if part.begins_with("eye"):
		var sx := -0.05 if part == "eye_l" else 0.05
		mb = LcMB.new()
		var col := Color("101010") if s in ["lost", "broken"] else Color("6a3a7a")
		mb.box("e", LcMB.mat(LcTex.solid(col)), Vector3(0.06, 0.05, 0.02), LcMB.T(Vector3(sx, 0.19, 0.14)), Color(1, 1, 1))
		mb.box("e", LcMB.mat(LcTex.solid(Color("101010"))), Vector3(0.26, 0.012, 0.012), LcMB.T(Vector3(0, 0.22, 0.13), Vector3(0, 0, 0.3 if sx < 0 else -0.3)), Color(1, 1, 1))
		parent = human.head
		at = Vector3.ZERO
	elif part == "ears":
		mb = LcMB.new()
		mb.cyl("e", LcMB.mat(LcTex.paper(Color("f0ece0"), 7, 16)), 0.135, 0.135, 0.05, 8, LcMB.T(Vector3(0, 0.13, 0)), Color(1, 1, 1))
		parent = human.head
		at = Vector3.ZERO
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	mi.name = key
	mi.position = at
	parent.add_child(mi)
	_extras[part] = mi


## Lost parts shrink to nothing (the skeleton copies the joints every frame).
func _apply_losses() -> void:
	if body_state.is_empty():
		return
	for part in ["hand_l", "hand_r", "arm_l", "arm_r", "leg_l", "leg_r"]:
		var j := _joint(part)
		var gone: bool = body_state[part].s in ["lost", "prosthetic"]
		j.scale = Vector3.ONE * (0.001 if gone else 1.0)
	# no legs: he's on the floor, dragging himself
	var legs := 0
	for p in ["leg_l", "leg_r"]:
		if body_state[p].s == "lost":
			legs += 1
	if legs == 2 and not seated:
		human.hips.position.y = 0.45


# --- deaths ---------------------------------------------------------------------------

func die(anim: String, focus: Vector3 = Vector3.ZERO) -> void:
	if dead:
		return
	dead = true
	_name_tag.modulate = Color(0.5, 0.5, 0.5, 0.6)
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	var tw := _tw
	var h := human
	match anim:
		"trapdoor":
			tw.tween_callback(func():
				_hole()
				Audio.sfx("door", 0.05, -2.0))
			tw.tween_property(h.arm_l, "rotation", Vector3(-2.9, 0, -0.3), 0.12)
			tw.parallel().tween_property(h.arm_r, "rotation", Vector3(-2.9, 0, 0.3), 0.12)
			tw.tween_interval(0.25)
			tw.tween_property(self, "position:y", -3.5, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(func(): Audio.sfx("fall", 0.05, -4.0))
			tw.tween_callback(hide)
		"launch":
			tw.tween_callback(func(): Audio.sfx("spring", 0.0, 0.0, 0.8))
			tw.tween_property(h.hips, "position:y", 0.4, 0.15)
			tw.tween_property(self, "position:y", 14.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(self, "rotation:x", TAU * 2.0, 0.4)
			tw.tween_callback(func():
				Audio.sfx("break", 0.05, -6.0)
				_drop_shoe())
			tw.tween_callback(hide)
		"zap":
			tw.tween_callback(func(): Audio.sfx("sizzle", 0.05, 0.0))
			tw.tween_property(h.arm_l, "rotation", Vector3(-1.5, 0, -1.4), 0.05)
			tw.parallel().tween_property(h.arm_r, "rotation", Vector3(-1.5, 0, 1.4), 0.05)
			for i in 14:
				tw.tween_property(self, "position:x", position.x + (0.05 if i % 2 == 0 else -0.05), 0.05)
				tw.tween_callback(func(): _flash(i % 2 == 0))
			tw.tween_callback(func():
				_flash(true)
				_smoke())
			tw.tween_property(self, "rotation:x", -PI / 2, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func(): Audio.sfx("land", 0.05, -2.0))
		"pop":
			tw.tween_callback(func():
				Audio.sfx("pop", 0.05, 4.0)
				_confetti(Vector3(0, 1.7, 0.2), 60))
			tw.tween_property(h.upper, "rotation:x", -0.5, 0.1)
			tw.tween_interval(0.6)
			# stiff as a plank, backwards
			tw.tween_property(self, "rotation:x", -PI / 2, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(func(): Audio.sfx("land", 0.05, 0.0, 0.7))
			tw.tween_property(self, "position:y", 0.12, 0.1)
		"boom":
			tw.tween_callback(func():
				Audio.sfx("break", 0.0, 4.0, 0.6)
				_confetti(Vector3(0, 1.2, 0), 90)
				_smoke()
				_scatter())
			tw.tween_callback(func(): h.hide())
		"jaws":
			tw.tween_callback(func(): Audio.sfx("squish", 0.05, 2.0))
			for i in 6:
				tw.tween_property(self, "position:y", position.y - 0.18 * (i + 1), 0.1)
				tw.tween_property(self, "rotation:z", 0.2 if i % 2 == 0 else -0.2, 0.08)
			tw.tween_property(h.arm_l, "rotation", Vector3(-3.0, 0, -0.2), 0.2)
			tw.parallel().tween_property(h.arm_r, "rotation", Vector3(-3.0, 0, 0.2), 0.2)
			tw.tween_property(self, "position:y", -2.2, 0.5)
			tw.tween_callback(func(): Audio.sfx("chomp" if false else "squish", 0.05, -2.0, 0.6))
			tw.tween_callback(hide)
		"clapper":
			tw.tween_callback(func(): Audio.sfx("snap", 0.0, 4.0, 0.5))
			tw.tween_property(h.upper, "rotation:x", 1.3, 0.12).set_trans(Tween.TRANS_EXPO)
			tw.parallel().tween_property(h.head, "rotation:x", 0.6, 0.12)
			tw.tween_interval(0.5)
			tw.tween_property(self, "rotation:z", 1.4, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		"prize":
			# drawn to the Caller, the hatch opens, and that's the prize
			if focus != Vector3.ZERO:
				look_toward(focus)
				var near := focus + (global_position - focus).normalized() * 1.4
				near.y = 0.0
				tw.tween_property(self, "position", near, 1.6)
			tw.tween_interval(0.9)
			tw.tween_callback(func(): Audio.sfx("slam", 0.0, 2.0))
			tw.tween_property(h.upper, "rotation:x", 0.9, 0.15)
			tw.tween_property(self, "rotation:x", PI / 2, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		_:
			tw.tween_property(self, "rotation:x", -PI / 2, 0.6)


func _flash(on: bool) -> void:
	var m := LcMB.mat(LcTex.solid(Color.WHITE), Color.WHITE, Vector2.ONE, true) if on else LcMB.mat(LcTex.solid(Color("101010")))
	for c in human.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = m
	if not on:
		return
	get_tree().create_timer(0.04).timeout.connect(func():
		for c in human.get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).material_override = LcMB.mat(LcTex.solid(Color("181412"))))


func _hole() -> void:
	var mb := LcMB.new()
	mb.cyl("h", LcMB.mat(LcTex.solid(Color("050305"))), 0.55, 0.55, 0.02, 8, LcMB.T(), Color(1, 1, 1))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	get_parent().add_child(mi)
	mi.global_position = global_position + Vector3(0, 0.015, 0)
	var tw := mi.create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(mi, "scale", Vector3(0.01, 1, 0.01), 0.3)
	tw.tween_callback(mi.queue_free)


func _drop_shoe() -> void:
	var mb := LcMB.new()
	mb.box("s", LcMB.mat(LcTex.solid(Color("181210"))), Vector3(0.1, 0.07, 0.18), LcMB.T(), Color(1, 1, 1))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	get_parent().add_child(mi)
	var at := global_position
	at.y = 9.0
	mi.global_position = at
	var tw := mi.create_tween()
	tw.tween_property(mi, "global_position:y", 0.04, 1.0).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(0.6)
	tw.parallel().tween_property(mi, "rotation:y", 5.0, 1.0).set_delay(0.6)


## Every part they were built from, thrown about (then left where it lands).
func _scatter() -> void:
	for jname in human.part_meshes.keys():
		var j := human.find_child(jname, true, false) as Node3D
		var from := j.global_transform if j else human.global_transform
		for m in human.part_meshes[jname]:
			var mi := MeshInstance3D.new()
			mi.mesh = m
			get_parent().add_child(mi)
			mi.global_transform = from
			var v := Vector3(randf_range(-4, 4), randf_range(3, 7), randf_range(-4, 4))
			var land := from.origin + Vector3(v.x, 0, v.z) * 0.45
			land.y = 0.05
			var tw := mi.create_tween()
			var peak := from.origin + Vector3(v.x * 0.25, v.y * 0.35, v.z * 0.25)
			tw.tween_property(mi, "global_position", peak, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			tw.parallel().tween_property(mi, "rotation", Vector3(randf() * 6, randf() * 6, randf() * 6), 0.8)
			tw.tween_property(mi, "global_position", land, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	# and the party hat floats down last
	_confetti(Vector3(0, 2.0, 0), 20)


func _confetti(at: Vector3, n: int) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = n
	p.lifetime = 2.0
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -5, 0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.04)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = mat
	p.mesh = q
	var g := Gradient.new()
	g.colors = PackedColorArray([Color("e8402a"), Color("f0c020"), Color("2a8ae8"), Color("40c060"), Color("e040c0")])
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	p.color_initial_ramp = g
	get_parent().add_child(p)
	p.global_position = global_position + at
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)


func _smoke() -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 16
	p.lifetime = 1.8
	p.explosiveness = 0.8
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0, 0.5, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.4)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.2, 0.22, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = mat
	p.mesh = q
	get_parent().add_child(p)
	p.global_position = global_position + Vector3(0, 1.2, 0)
	p.emitting = true
	get_tree().create_timer(2.5).timeout.connect(p.queue_free)
