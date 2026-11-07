class_name Contestant
extends Node3D
## A contestant's puppet. The figures on the Caller's table are puppets of the people
## playing, made of meat: cartoon PS1 bodies of rotting muscle and fat, stitched together,
## no face (just more meat, a stitched slit for a mouth), and real eyes (wet, veined, the one thing on
## them that isn't crude) that follow you round the room. Strings go up from them into the
## dark. Flies. What is done to the puppet is done to the player: every injury goes in as a
## pin, a lost limb is cut off and the thread left hanging, a lost eye hangs out of its
## socket on the nerve, a brass prosthetic is screwed on in its place.
##
## Built on RATFORMER's PS1 human rig (Ps1Human), in puppet units: the table node it stands
## on is scaled down, so a 1.8-unit puppet is a hand's height on the table.

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


const IRIS := [Color("4a6a9a"), Color("5a3a1e"), Color("4a7a3a"), Color("7a6030")]

var eyes: Array[Node3D] = []      # [left, right]
var is_ghost := false
var _eye_rest: Array[Vector3] = []
var _strings: MeshInstance3D
var _string_mesh: ImmediateMesh
var _eye_state := ["ok", "ok"]


func setup(s: int, face: int, c: Color, display_name: String) -> void:
	seat = s
	color = c
	var flesh := Meat.flesh(0.25 + 0.18 * s, s + 1)
	# no face: a meat doll. The front of the head is the same meat as the rest of it.
	human = Ps1Human.make({"face": face, "face_tex": Meat.flesh(0.35 + 0.15 * s, s + 11), "skin_tex": flesh,
		"shirt": Color(1.0, 0.92, 0.9), "trousers": Color(0.8, 0.62, 0.62), "shoes": Color(0.35, 0.12, 0.12),
		"skin": Color(1.0, 0.95, 0.92), "hair": [Color("1a1008"), Color("3a2a1a"), Color("120c0a"), Color("4a3a2a")][s % 4],
		"long_hair": s == 1, "bald": s % 2 == 0})
	add_child(human)
	_stitches(c)
	_eyes()
	_mouth()
	# the base: a chipped dinner plate, smeared, with a band of the seat's colour
	var base := LcMB.new()
	base.cyl("p", LcMB.mat(LcTex.grime(Color("d8d0c0"), Color("f0ece0"), 16, 13 + s, 0.3)), 0.5, 0.42, 0.06, 12, LcMB.T(Vector3(0, -0.02, 0)), Color(1, 1, 1))
	base.cyl("r", LcMB.mat(LcTex.solid(c.darkened(0.15))), 0.5, 0.5, 0.02, 12, LcMB.T(Vector3(0, 0.035, 0)), Color(1, 1, 1))
	base.cyl("b", LcMB.mat(LcTex.grime(Color("3a0606"), Color("6a1010"), 16, 30 + s, 0.4)), 0.3, 0.26, 0.012, 9, LcMB.T(Vector3(0.05, 0.04, 0.04)), Color(1, 1, 1))
	var bm := MeshInstance3D.new()
	bm.mesh = base.build()
	add_child(bm)
	_strings_setup()
	_flies()
	_name_tag = Label3D.new()
	_name_tag.text = display_name
	_name_tag.font = load("res://assets/fonts/fell_sc.ttf")
	_name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_tag.position = Vector3(0, 2.3, 0)
	_name_tag.pixel_size = 0.006
	_name_tag.font_size = 48
	_name_tag.outline_size = 10
	_name_tag.modulate = Color("f0e6cc")
	_name_tag.outline_modulate = Color(0.1, 0.02, 0.02)
	_name_tag.no_depth_test = true
	add_child(_name_tag)


## Stitching where it was joined, a party ribbon in the seat's colour round the waist, and
## one pin already in. (There always is one.)
func _stitches(c: Color) -> void:
	var black := LcMB.mat(LcTex.solid(Color("120606")))
	var mb := LcMB.new()
	mb.cyl("r", LcMB.mat(LcTex.solid(c)), 0.16, 0.16, 0.04, 8, LcMB.T(Vector3(0, 0.1, 0), Vector3(0, PI / 8.0, 0), Vector3(1.03, 1, 0.68)), Color(1, 1, 1))
	for k in 6:
		mb.box("s", black, Vector3(0.05, 0.012, 0.012), LcMB.T(Vector3(0.0, 0.14 + k * 0.08, 0.135), Vector3(0, 0, 0.4 * (1 if k % 2 == 0 else -1))), Color(1, 1, 1))
	for k in 8:
		var a := TAU * k / 8.0
		mb.box("s", black, Vector3(0.012, 0.04, 0.012), LcMB.T(Vector3(sin(a) * 0.08, 0.6, cos(a) * 0.06)), Color(1, 1, 1))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	human.upper.add_child(mi)
	_pin(human.upper, Vector3(-0.1, 0.45, 0.1), Vector3(0.6, 0.3, 0), c)


## A mouth: a slit with crude stitches across it, and a nose that's just two holes.
func _mouth() -> void:
	var mb := LcMB.new()
	var dark := LcMB.mat(LcTex.solid(Color("1a0406")))
	mb.box("m", dark, Vector3(0.09, 0.014, 0.012), LcMB.T(Vector3(0, 0.075, 0.125)), Color(1, 1, 1))
	for k in 4:
		mb.box("s", LcMB.mat(LcTex.solid(Color("d8c8a8"))), Vector3(0.006, 0.04, 0.008), LcMB.T(Vector3(-0.033 + k * 0.022, 0.075, 0.13), Vector3(0, 0, 0.3)), Color(1, 1, 1))
	mb.box("n", dark, Vector3(0.012, 0.016, 0.01), LcMB.T(Vector3(-0.012, 0.135, 0.13)), Color(1, 1, 1))
	mb.box("n", dark, Vector3(0.012, 0.016, 0.01), LcMB.T(Vector3(0.012, 0.135, 0.13)), Color(1, 1, 1))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	human.head.add_child(mi)


## Dead: a pale, see-through copy of the puppet, hovering over its square. (The eyes keep
## following you.)
func make_ghost() -> void:
	is_ghost = true
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.85, 1.0, 0.32)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for n in find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_override = m
	if _strings:
		_strings.visible = false
	for c in get_children():
		if c is CPUParticles3D:
			c.queue_free()
	position.y = 0.6
	target.y = 0.6
	if _name_tag:
		_name_tag.text = "%s (GHOST)" % _name_tag.text
		_name_tag.modulate = Color(0.7, 0.8, 1.0, 0.8)


## Two real eyes, pushed into the meat where a face would be.
func _eyes() -> void:
	eyes.clear()
	_eye_rest.clear()
	for side in [-1.0, 1.0]:
		var e := Node3D.new()
		var rest := Vector3(0.052 * side, 0.2, 0.125)
		e.position = rest
		human.head.add_child(e)
		var mi := MeshInstance3D.new()
		mi.name = "Ball"
		mi.mesh = Meat.eyeball(0.05, IRIS[seat % 4], 0.15, seat * 2 + int(side > 0))
		e.add_child(mi)
		eyes.append(e)
		_eye_rest.append(rest)


func _set_eye(i: int, state: String) -> void:
	if _eye_state[i] == state or eyes.size() < 2:
		return
	_eye_state[i] = state
	var e := eyes[i]
	var ball := e.get_node("Ball") as MeshInstance3D
	ball.mesh = Meat.eyeball(0.05, IRIS[seat % 4], 1.0 if state in ["bruised", "burned", "broken"] else 0.15, seat * 2 + i)
	for c in e.get_children():
		if c.name == "Nerve":
			c.queue_free()
	if state == "lost":
		# out of the socket, hanging on its nerve
		e.position = _eye_rest[i] + Vector3(0, -0.13, 0.03)
		var mb := LcMB.new()
		mb.box("n", LcMB.mat(LcTex.grime(Color("6a1018"), Color("a8303a"), 16, 5, 0.4)), Vector3(0.014, 0.13, 0.014), LcMB.T(Vector3(0, 0.065, -0.02)), Color(1, 1, 1))
		var n := MeshInstance3D.new()
		n.name = "Nerve"
		n.mesh = mb.build()
		e.add_child(n)
		var sk := LcMB.new()
		sk.cyl("s", LcMB.mat(LcTex.solid(Color("140406"))), 0.034, 0.034, 0.01, 8, LcMB.T(_eye_rest[i] + Vector3(0, 0, -0.01), Vector3(PI / 2, 0, 0)), Color(1, 1, 1))
		var sm := MeshInstance3D.new()
		sm.mesh = sk.build()
		human.head.add_child(sm)
	else:
		e.position = _eye_rest[i]


## The eyes follow whoever's watching (the camera); a lost one just swings.
func _look_eyes() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for i in eyes.size():
		var e := eyes[i]
		if _eye_state[i] == "lost":
			e.rotation = Vector3(sin(_t * 2.1 + i) * 0.35, 0, sin(_t * 1.7 + i) * 0.4)
			continue
		var to := cam.global_position - e.global_position
		if to.length() < 0.001:
			continue
		var local := (e.get_parent() as Node3D).global_transform.basis.orthonormalized().inverse() * to.normalized()
		var yaw := clampf(atan2(local.x, local.z), -0.7, 0.7)
		var pitch := clampf(-atan2(local.y, Vector2(local.x, local.z).length()), -0.5, 0.5)
		e.rotation = Vector3(pitch, yaw, 0)


## Strings from the head and both hands, up out of the light.
func _strings_setup() -> void:
	_string_mesh = ImmediateMesh.new()
	_strings = MeshInstance3D.new()
	_strings.mesh = _string_mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.85, 0.8, 0.7, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_strings.material_override = m
	_strings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_strings)


func _draw_strings() -> void:
	if _string_mesh == null or not is_visible_in_tree():
		return
	_string_mesh.clear_surfaces()
	_string_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var inv := global_transform.affine_inverse()
	for j in [human.head, human.hand_l, human.hand_r]:
		if (j as Node3D).global_transform.basis.get_scale().x < 0.0005:
			continue
		var p: Vector3 = inv * (j as Node3D).global_position
		_string_mesh.surface_add_vertex(p + Vector3(0, 0.05, 0))
		_string_mesh.surface_add_vertex(p + Vector3(0, 6.0, 0))
	_string_mesh.surface_end()


func _flies() -> void:
	var p := CPUParticles3D.new()
	p.amount = 5
	p.lifetime = 1.6
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.5
	p.gravity = Vector3.ZERO
	p.direction = Vector3(1, 0.2, 0)
	p.spread = 180.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.4
	p.orbit_velocity_min = 0.6
	p.orbit_velocity_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.004, 0.004)   # billboarded: real size, the table's scale doesn't apply
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.05, 0.05, 0.04)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = mat
	p.mesh = q
	p.position = Vector3(0, 1.6, 0)
	add_child(p)


## A dressmaker's pin: steel shank, a glass bead on the end.
func _pin(parent: Node3D, at: Vector3, tilt: Vector3, bead: Color, length := 0.42) -> Node3D:
	var mb := LcMB.new()
	mb.cyl("p", LcMB.mat(LcTex.grime(Color("9a9aa0"), Color("d8d8e0"), 16, 3, 0.3)), 0.012, 0.012, length, 4, LcMB.T(), Color(1, 1, 1))
	mb.sphere("b", LcMB.mat(LcTex.solid(bead)), 0.045, 3, 6, LcMB.T(Vector3(0, length, 0)), Color(1, 1, 1))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	mi.position = at
	mi.rotation = tilt
	parent.add_child(mi)
	return mi


func place(p: Vector3) -> void:
	position = p
	target = p


func walk_to(p: Vector3) -> void:
	target = p


## A board step, Mario Party style: a quick hop to the next square that lands in `dur`.
var _hop: Tween
func hop_to(p: Vector3, dur := 0.2) -> void:
	if _hop and _hop.is_valid():
		_hop.kill()
		position = target
	var from := position
	target = p
	var d := p - from
	if Vector2(d.x, d.z).length() > 0.05:
		face_dir = atan2(d.x, d.z)
	_hop = create_tween()
	_hop.tween_method(func(t: float):
		var q := from.lerp(p, t)
		q.y += sin(t * PI) * 0.9
		position = q, 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE)


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
	if is_ghost:
		target.y = position.y
	var moving := d.length() > 0.04 and not seated and not (_hop and _hop.is_running())
	if _hop and _hop.is_running():
		_phase += delta * 14.0
		human.walk(_phase, 1.0)
	elif moving:
		var step := minf(d.length(), WALK_SPEED * _speed_mul * delta)
		position += d.normalized() * step
		face_dir = lerp_angle(face_dir, atan2(d.x, d.z), minf(1.0, delta * 10.0))
		_phase += delta * 9.0 * _speed_mul
		human.walk(_phase, 1.0)
	elif not seated:
		human.walk(_phase, 0.0)
		human.idle(_t + seat)
	rotation.y = lerp_angle(rotation.y, face_dir, minf(1.0, delta * 8.0))
	if is_ghost:
		position.y = 0.6 + sin(_t * 1.7 + seat) * 0.15
	_look_eyes()
	_draw_strings()
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
	_set_eye(0, str(b.eye_l.s))
	_set_eye(1, str(b.eye_r.s))
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
	var holder := Node3D.new()
	holder.name = key
	var parent := _joint(part)
	var at := Vector3(0, -0.12, 0.05)
	var red := Color("c81810")
	if part.begins_with("eye"):
		parent = human.head
		at = Vector3(-0.05 if part == "eye_l" else 0.05, 0.19, 0.13)
	elif part == "ears":
		parent = human.head
		at = Vector3(0.12, 0.15, 0.0)
	if s in ["lost", "prosthetic"] and not part.begins_with("eye") and part != "ears":
		at = _joint(part).position
		parent = _joint(part).get_parent()
	parent.add_child(holder)
	holder.position = at
	match s:
		"bruised":
			_pin(holder, Vector3.ZERO, Vector3(0.9, 0.2, 0.3), Color("6a3a9a"))
		"burned":
			_pin(holder, Vector3.ZERO, Vector3(0.8, -0.4, 0.2), Color("e88020"))
			var mb := LcMB.new()
			mb.box("x", LcMB.mat(LcTex.grime(Color("120a06"), Color("3a2210"), 16, 41, 0.4)), Vector3(0.13, 0.14, 0.12), LcMB.T(Vector3(0, 0.0, -0.04)), Color(1, 1, 1))
			_add(holder, mb)
		"broken":
			_pin(holder, Vector3.ZERO, Vector3(0.9, 0.6, 0.0), red)
			_pin(holder, Vector3(0.0, -0.05, 0.0), Vector3(0.9, -0.6, 0.0), red)
			var mb := LcMB.new()
			for k in 3:
				mb.cyl("t", LcMB.mat(LcTex.solid(Color("a01410"))), 0.075, 0.075, 0.015, 6, LcMB.T(Vector3(0, -0.03 - k * 0.03, -0.05)), Color(1, 1, 1))
			_add(holder, mb)
		"prosthetic":
			var brass := LcMB.mat(LcTex.brass())
			var mb := LcMB.new()
			if part.begins_with("leg"):
				mb.cyl("p", brass, 0.03, 0.045, 0.42, 6, LcMB.T(Vector3(0, -0.44, 0)), Color(1, 1, 1))
				mb.cyl("p", brass, 0.05, 0.05, 0.03, 6, LcMB.T(Vector3(0, -0.46, 0)), Color(0.7, 0.7, 0.7))
			else:
				mb.cyl("p", brass, 0.03, 0.03, 0.12, 6, LcMB.T(Vector3(0, -0.12, 0)), Color(1, 1, 1))
				mb.ring("p", brass, 0.04, 0.012, 6, LcMB.T(Vector3(0.0, -0.16, 0), Vector3(0, 0, PI / 2)), Color(1, 1, 1))
			_add(holder, mb)
		"lost":
			if part.begins_with("eye"):
				pass   # it hangs out of its socket (_set_eye)
			else:
				# cut off; the thread left hanging
				var mb := LcMB.new()
				mb.cyl("s", LcMB.mat(LcTex.solid(Color("8a6a40"))), 0.06, 0.05, 0.04, 6, LcMB.T(Vector3(0, -0.04, 0)), Color(1, 1, 1))
				mb.box("t", LcMB.mat(LcTex.solid(Color("a01410"))), Vector3(0.008, 0.18, 0.008), LcMB.T(Vector3(0.02, -0.12, 0.01), Vector3(0, 0, 0.3)), Color(1, 1, 1))
				mb.box("t", LcMB.mat(LcTex.solid(Color("a01410"))), Vector3(0.008, 0.12, 0.008), LcMB.T(Vector3(-0.02, -0.1, 0.0), Vector3(0, 0, -0.4)), Color(1, 1, 1))
				_add(holder, mb)
	if part.begins_with("eye") and s in ["bruised", "burned", "broken"]:
		_pin(holder, Vector3(0.0, 0.04, -0.01), Vector3(1.9, 0, 0.2), red, 0.28)
	_extras[part] = holder


func _add(parent: Node3D, mb: LcMB) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	parent.add_child(mi)


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
	_name_tag.modulate = Color(0.55, 0.45, 0.4, 0.7)
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
				# toward him, to the edge of the board (his hand comes down there)
				var f: Vector3 = (get_parent() as Node3D).to_local(focus)
				f.y = 0.0
				var near: Vector3 = position + (f - position).normalized() * minf(position.distance_to(f) - 1.0, 4.0)
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
	mi.position = position + Vector3(0, 0.015, 0)
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
	var at := position
	at.y = 9.0
	mi.position = at
	var tw := mi.create_tween()
	tw.tween_property(mi, "position:y", 0.04, 1.0).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(0.6)
	tw.parallel().tween_property(mi, "rotation:y", 5.0, 1.0).set_delay(0.6)


## Every part they were built from, thrown about (then left where it lands).
func _scatter() -> void:
	for jname in human.part_meshes.keys():
		var j := human.find_child(jname, true, false) as Node3D
		var inv := (get_parent() as Node3D).global_transform.affine_inverse()
		var from: Transform3D = inv * (j.global_transform if j else human.global_transform)
		for m in human.part_meshes[jname]:
			var mi := MeshInstance3D.new()
			mi.mesh = m
			get_parent().add_child(mi)
			mi.transform = from
			var v := Vector3(randf_range(-4, 4), randf_range(3, 7), randf_range(-4, 4))
			var land := from.origin + Vector3(v.x, 0, v.z) * 0.45
			land.y = 0.05
			var tw := mi.create_tween()
			var peak := from.origin + Vector3(v.x * 0.25, v.y * 0.35, v.z * 0.25)
			tw.tween_property(mi, "position", peak, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			tw.parallel().tween_property(mi, "rotation", Vector3(randf() * 6, randf() * 6, randf() * 6), 0.8)
			tw.tween_property(mi, "position", land, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
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
	p.local_coords = true
	get_parent().add_child(p)
	p.position = position + at
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
	p.local_coords = true
	get_parent().add_child(p)
	p.position = position + Vector3(0, 1.2, 0)
	p.emitting = true
	get_tree().create_timer(2.5).timeout.connect(p.queue_free)
