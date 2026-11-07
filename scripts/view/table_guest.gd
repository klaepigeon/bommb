class_name TableGuest
extends Node3D
## One of the four people at the Caller's table: the real players, in RATFORMER's PS1
## people (Ps1Human), wearing the player's photograph for a face, sat on a hall chair. The
## puppets on the board are theirs: whatever is done to a puppet happens to the person it
## belongs to, so the people at the table come apart as the game goes on (casts, scorches,
## a bandaged socket, stumps, brass), and when a puppet dies, its person goes face-down on
## the table and stays there.
##
## Your own seat is the camera: for you, only your forearms and hands on the table edge.

const SLOTS := [  # in hall coordinates, around the (operating) table; slot 0 is yours
	[Vector3(0, 0, 1.72), PI], [Vector3(-2.02, 0, -0.1), PI / 2], [Vector3(0, 0, -1.78), 0.0], [Vector3(2.02, 0, -0.1), -PI / 2]]

var seat := 0
var slot := 0
var human: Ps1Human
var first_person := false
var dead := false
var _t := 0.0
var _extras: Dictionary = {}
var _hands: Dictionary = {}      # first person: "l"/"r" -> Node3D
var _lean := 0.0
var _want_lean := 0.0


func setup(s: int, slot_i: int, face: int, c: Color) -> void:
	seat = s
	slot = slot_i
	first_person = slot_i == 0
	position = SLOTS[slot_i][0]
	rotation.y = SLOTS[slot_i][1]
	_chair()
	if first_person:
		_my_hands(c)
		return
	human = Ps1Human.make({"face": face, "shirt": c.darkened(0.2), "trousers": Color(0.16, 0.15, 0.18),
		"hair": [Color("3a2414"), Color("8a6a3a"), Color("1a1410"), Color("b8a070")][s % 4], "long_hair": s % 2 == 1,
		"glasses": s == 2, "bald": s == 3, "face_gain": 1.3,
		"skin": [Color(0.86, 0.68, 0.58), Color(0.72, 0.52, 0.4), Color(0.9, 0.74, 0.64), Color(0.55, 0.38, 0.28)][s % 4]})
	add_child(human)
	human.sit()
	human.hips.position.y = 0.5
	_rest_arms()


var chair: Node3D


func _chair() -> void:
	# the chair stays where it is when they get up (it's the room's, not theirs)
	chair = Node3D.new()
	chair.position = position
	chair.rotation = rotation
	get_parent().add_child(chair)
	var mb := LcMB.new()
	var seat_m := LcMB.mat(LcTex.wood(Color("7a4a2a"), 7, 32, 2))
	var leg_m := LcMB.mat(LcTex.grime(Color("4a4a48"), Color("6a6a66"), 16, 8, 0.4))
	mb.box("s", seat_m, Vector3(0.44, 0.05, 0.44), LcMB.T(Vector3(0, 0.45, 0.05)), Color(1, 1, 1))
	mb.box("s", seat_m, Vector3(0.44, 0.44, 0.04), LcMB.T(Vector3(0, 0.72, -0.17), Vector3(-0.08, 0, 0)), Color(0.95, 0.95, 0.95))
	for p in [Vector3(-0.19, 0.22, -0.15), Vector3(0.19, 0.22, -0.15), Vector3(-0.19, 0.22, 0.24), Vector3(0.19, 0.22, 0.24)]:
		mb.box("l", leg_m, Vector3(0.03, 0.45, 0.03), LcMB.T(p), Color(1, 1, 1))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	chair.add_child(mi)
	# a party hat, on the seat back
	var hat := LcMB.new()
	hat.cyl("h", LcMB.mat(LcTex.grime(Color("c83a6a"), Color("f06a9a"), 16, 7 + seat, 0.4)), 0.07, 0.0, 0.18, 6, LcMB.T(Vector3(0.16, 0.95, -0.18), Vector3(0, 0, 0.4)), Color(1, 1, 1))
	var hm := MeshInstance3D.new()
	hm.mesh = hat.build()
	chair.add_child(hm)


## Forearms on the table, as if waiting. (Arms reach forward: -x rotation.)
func _rest_arms() -> void:
	for a in [human.arm_l, human.arm_r]:
		a.rotation = Vector3(-0.95, 0, 0)
	for f in [human.fore_l, human.fore_r]:
		f.rotation = Vector3(-0.75, 0, 0)
	human.arm_l.rotation.z = -0.15
	human.arm_r.rotation.z = 0.15


## Your own hands, at the edge of the table in front of you.
func _my_hands(c: Color) -> void:
	var skin := Color(0.86, 0.68, 0.58)
	for side in ["l", "r"]:
		var sx := -1.0 if side == "l" else 1.0
		var h := Node3D.new()
		h.position = Vector3(0.24 * sx, 0.8, -0.3)
		h.rotation.y = 0.25 * sx
		add_child(h)
		var mb := LcMB.new()
		mb.box("c", LcMB.mat(LcTex.solid(c.darkened(0.25))), Vector3(0.09, 0.08, 0.34), LcMB.T(Vector3(0, 0, 0.3)), Color(1, 1, 1))
		mb.box("a", LcMB.mat(LcTex.solid(skin)), Vector3(0.07, 0.06, 0.18), LcMB.T(Vector3(0, -0.005, 0.06)), Color(1, 1, 1))
		mb.box("a", LcMB.mat(LcTex.solid(skin)), Vector3(0.085, 0.035, 0.1), LcMB.T(Vector3(0, -0.015, -0.07)), Color(0.95, 0.95, 0.95))
		var mi := MeshInstance3D.new()
		mi.name = "Hand"
		mi.mesh = mb.build()
		h.add_child(mi)
		_hands[side] = h


func lean_in(on: bool) -> void:
	_want_lean = 0.35 if on else 0.0


func _process(delta: float) -> void:
	_t += delta
	if human == null or dead:
		return
	if _walk(delta):
		return
	_lean = lerpf(_lean, _want_lean, minf(1.0, delta * 3.0))
	human.upper.rotation.x = _lean + sin(_t * 1.3 + seat) * 0.02
	# glance at the board, at the stage, at you
	var phase := fmod(_t + seat * 3.1, 11.0)
	var yaw := 0.0
	var pitch := 0.45
	if phase > 7.0:
		yaw = (0.6 if slot == 1 else (-0.6 if slot == 3 else 0.0))
		pitch = -0.1
	elif phase > 5.5:
		yaw = (-0.5 if slot == 1 else (0.5 if slot == 3 else 0.3))
		pitch = 0.15
	human.head.rotation.y = lerpf(human.head.rotation.y, yaw, minf(1.0, delta * 3.0))
	human.head.rotation.x = lerpf(human.head.rotation.x, pitch, minf(1.0, delta * 3.0))


## What's happened to their puppet, on them.
func set_body(b: Dictionary) -> void:
	if first_person:
		for side in ["l", "r"]:
			var gone: bool = b["hand_" + side].s == "lost" or b["arm_" + side].s == "lost"
			(_hands[side] as Node3D).visible = not gone
			var m := (_hands[side] as Node3D).get_node("Hand") as MeshInstance3D
			m.material_override = LcMB.mat(LcTex.solid(Color("a8b8a0"))) if b["hand_" + side].s == "prosthetic" else null
		return
	for part in Body.PARTS:
		_mark(part, str(b[part].s))
	for part in ["hand_l", "hand_r", "arm_l", "arm_r", "leg_l", "leg_r"]:
		var j := _joint(part)
		j.scale = Vector3.ONE * (0.001 if b[part].s == "lost" else 1.0)


func _joint(part: String) -> Node3D:
	match part:
		"hand_l": return human.hand_l
		"hand_r": return human.hand_r
		"arm_l": return human.arm_l
		"arm_r": return human.arm_r
		"leg_l": return human.shin_l
		"leg_r": return human.shin_r
	return human.head


func _mark(part: String, s: String) -> void:
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
	var at := Vector3(0, -0.12, 0)
	var blood := LcMB.mat(LcTex.grime(Color("3a0606"), Color("8a1010"), 16, 31, 0.4))
	if part.begins_with("eye"):
		parent = human.head
		at = Vector3(-0.045 if part == "eye_l" else 0.045, 0.19, 0.135)
	elif part == "ears":
		parent = human.head
		at = Vector3(0, 0.15, 0)
	match s:
		"bruised":
			mb.box("x", LcMB.mat(LcTex.solid(Color("5a2a6a"))), Vector3(0.08, 0.06, 0.1), LcMB.T(), Color(1, 1, 1))
		"burned":
			mb.box("x", LcMB.mat(LcTex.grime(Color("120a06"), Color("4a2a10"), 16, 41, 0.4)), Vector3(0.12, 0.12, 0.12), LcMB.T(), Color(1, 1, 1))
		"broken":
			mb.box("x", LcMB.mat(LcTex.paper(Color("f0ece0"), 7, 16)), Vector3(0.13, 0.24, 0.13), LcMB.T(Vector3(0, -0.04, 0)), Color(1, 1, 1))
		"prosthetic":
			mb.cyl("p", LcMB.mat(LcTex.brass()), 0.03, 0.04, 0.3, 6, LcMB.T(Vector3(0, -0.3, 0)), Color(1, 1, 1))
			parent = _joint(part).get_parent()
			at = _joint(part).position
		"lost":
			mb.box("x", blood, Vector3(0.1, 0.05, 0.1), LcMB.T(), Color(1, 1, 1))
			mb.box("x", LcMB.mat(LcTex.paper(Color("e8dccc"), 9, 16)), Vector3(0.11, 0.05, 0.11), LcMB.T(Vector3(0, 0.04, 0)), Color(0.9, 0.7, 0.7))
			parent = _joint(part).get_parent()
			at = _joint(part).position
	if part.begins_with("eye"):
		mb = LcMB.new()
		var c := blood if s in ["lost", "broken"] else LcMB.mat(LcTex.solid(Color("6a3a7a")))
		mb.box("e", c, Vector3(0.06, 0.05, 0.02), LcMB.T(), Color(1, 1, 1))
		if s == "lost":
			mb.box("b", LcMB.mat(LcTex.paper(Color("f0ece0"), 5, 16)), Vector3(0.28, 0.04, 0.02), LcMB.T(Vector3(-at.x, 0.0, -0.005), Vector3(0, 0, 0.35 if at.x < 0 else -0.35)), Color(1, 1, 1))
			mb.box("d", blood, Vector3(0.012, 0.08, 0.01), LcMB.T(Vector3(0, -0.06, 0.005)), Color(1, 1, 1))
	elif part == "ears":
		mb = LcMB.new()
		mb.cyl("e", LcMB.mat(LcTex.paper(Color("f0ece0"), 7, 16)), 0.135, 0.135, 0.05, 8, LcMB.T(), Color(1, 1, 1))
	var mi := MeshInstance3D.new()
	mi.name = key
	mi.mesh = mb.build()
	mi.position = at
	parent.add_child(mi)
	_extras[part] = mi


## Their puppet died. They go down onto the table, and stay there.
func die() -> void:
	if dead:
		return
	dead = true
	if first_person:
		for h in _hands.values():
			var tw := (h as Node3D).create_tween()
			tw.tween_property(h, "position:y", 0.79, 0.2)
		return
	var tw := create_tween()
	tw.tween_property(human.upper, "rotation:x", 1.05, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(human.head, "rotation:x", 0.3, 0.35)
	tw.parallel().tween_property(human.arm_l, "rotation", Vector3(-0.3, 0, -0.5), 0.35)
	tw.parallel().tween_property(human.arm_r, "rotation", Vector3(-0.3, 0, 0.5), 0.35)
	tw.tween_callback(func():
		Audio.sfx("land", 0.1, -2.0, 0.8)
		var mb := LcMB.new()
		mb.cyl("b", LcMB.mat(LcTex.grime(Color("2a0404"), Color("6a0a0a"), 16, 61, 0.3)), 0.2, 0.2, 0.004, 10, LcMB.T(), Color(1, 1, 1))
		var pool := MeshInstance3D.new()
		pool.mesh = mb.build()
		pool.position = Vector3(0, 0.783, 0.45)
		pool.scale = Vector3(0.1, 1, 0.1)
		add_child(pool)
		pool.create_tween().tween_property(pool, "scale", Vector3.ONE, 3.0))


var _home := Vector3.ZERO
var _home_rot := 0.0
var _walk_to := Vector3.INF
var _walk_phase := 0.0


## Up from the chair (leaving the table).
func get_up() -> void:
	if human == null or dead:
		return
	_home = position
	_home_rot = rotation.y
	human.hips.position.y = 0.92
	for l in [human.leg_l, human.leg_r, human.shin_l, human.shin_r]:
		(l as Node3D).rotation.x = 0.0
	for a in [human.arm_l, human.arm_r, human.fore_l, human.fore_r]:
		(a as Node3D).rotation = Vector3.ZERO


func walk_to(p: Vector3) -> void:
	if human == null or dead:
		return
	if _walk_to == Vector3.INF and _home == Vector3.ZERO:
		get_up()
	_walk_to = p


func sit_back() -> void:
	if human == null or dead or _home == Vector3.ZERO:
		return
	_walk_to = _home


func _walk(delta: float) -> bool:
	if _walk_to == Vector3.INF:
		return false
	var d := _walk_to - position
	d.y = 0.0
	if d.length() < 0.05:
		position = Vector3(_walk_to.x, 0, _walk_to.z)
		if _walk_to == _home:
			rotation.y = _home_rot
			_home = Vector3.ZERO
			_walk_to = Vector3.INF
			human.sit()
			human.hips.position.y = 0.5
			_rest_arms()
		human.walk(_walk_phase, 0.0)
		return true
	position += d.normalized() * minf(d.length(), 1.6 * Body.speed(Body.fresh()) * delta)
	rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), minf(1.0, delta * 8.0))
	_walk_phase += delta * 9.0
	human.walk(_walk_phase, 1.0)
	return true


## They got out: up from the chair.
func stand() -> void:
	if human == null or dead:
		return
	var tw := create_tween()
	tw.tween_property(human.hips, "position:y", 0.92, 0.6)
	for l in [human.leg_l, human.leg_r, human.shin_l, human.shin_r]:
		tw.parallel().tween_property(l, "rotation:x", 0.0, 0.6)
	tw.parallel().tween_property(self, "position:z", position.z + (0.5 if slot == 2 else 0.0), 0.6)


func _exit_tree() -> void:
	if chair and is_instance_valid(chair) and not chair.is_queued_for_deletion():
		chair.queue_free()
