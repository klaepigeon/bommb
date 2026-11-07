class_name TableCaller
extends Node3D
## The Caller, as he lives in the table: the robot that built MURDERLAND. His head comes up
## out of the Control System in the middle of the board on hydraulics (and goes back down
## when he's done, so he never sits on the board for long), and his arms come out of
## hatches in the table's rim. Built in puppet units, under the board.
##
## Gestures (play(name)): emerge, retract, tilt, point (at a space or a puppet), grab (lift a
## puppet and set it down), tap (drums his fingers), dispense (Teeth fall from his palm),
## slam (the table), laugh, stare (silent: he just looks), disapprove, excited, angry,
## sympathy (fake), malfunction, seizure, trophy, roulette (he presents the gun), execute,
## interrupt (stops everything), celebrate. Mechanical weight: everything has a wind-up and
## an overshoot; the hydraulics hiss, the gears grind. He sometimes reacts in silence.

signal busy_done

var head: Node3D
var jaw: Node3D
var eyes: Array = []
var neck: Node3D
var arms: Array = []         # [{root, upper, fore, claw, home}]
var up := false
var _talk := 0.0
var _t := 0.0
var _look := Vector3.INF
var _tw: Tween
var white: Material
var glow: StandardMaterial3D
var _eye_col := Color("6af0ff")
var _seizure := 0.0


func build(arm_spots: Array) -> void:
	white = MB.mat(Tex.solid(Color.WHITE))
	glow = StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = _eye_col
	neck = Node3D.new()
	add_child(neck)
	var nmb := MB.new()
	for k in 4:
		nmb.cyl("w", white, 0.45 - k * 0.06, 0.5 - k * 0.06, 1.2, 10, MB.T(Vector3(0, -k * 1.1, 0)), Color("c9d1d9") if k % 2 == 0 else Color("8a96a4"))
	var nm := MeshInstance3D.new()
	nm.mesh = nmb.build()
	neck.add_child(nm)
	head = Node3D.new()
	head.position = Vector3(0, 0.9, 0)
	neck.add_child(head)
	var hmb := MB.new()
	hmb.sphere("w", white, 1.15, 6, 12, MB.T(Vector3(0, 0.7, 0)), Color("e8eef2"), Vector3(1.1, 0.95, 1.0))
	hmb.box("w", white, Vector3(1.9, 0.5, 1.5), MB.T(Vector3(0, 0.15, 0.1)), Color("ff5fa2"))
	hmb.cyl("w", white, 0.0, 0.55, 1.1, 10, MB.T(Vector3(0.3, 2.1, 0), Vector3(0, 0, -0.25)), Color("ffd23f"))
	hmb.sphere("w", white, 0.16, 3, 6, MB.T(Vector3(0.58, 2.62, 0)), Color("2ec4c6"))
	for s in [-1.0, 1.0]:
		hmb.cyl("w", white, 0.36, 0.36, 0.2, 12, MB.T(Vector3(s * 0.45, 0.9, 0.98), Vector3(PI / 2, 0, 0)), Color("1a0b14"))
		hmb.box("w", white, Vector3(0.12, 0.5, 0.12), MB.T(Vector3(s * 1.15, 0.8, 0)), Color("8a96a4"))
	var hm := MeshInstance3D.new()
	hm.mesh = hmb.build()
	head.add_child(hm)
	for s in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.22
		sm.height = 0.44
		e.mesh = sm
		e.material_override = glow
		e.position = Vector3(s * 0.45, 0.9, 1.08)
		head.add_child(e)
		eyes.append(e)
	jaw = Node3D.new()
	jaw.position = Vector3(0, 0.0, 0.6)
	head.add_child(jaw)
	var jmb := MB.new()
	jmb.box("w", white, Vector3(1.4, 0.3, 0.9), MB.T(Vector3(0, -0.15, 0.1)), Color("c9d1d9"))
	for k in 6:
		jmb.box("w", white, Vector3(0.12, 0.14, 0.05), MB.T(Vector3(-0.5 + k * 0.2, 0.02, 0.56)), Color("fff4dc"))
	var jm := MeshInstance3D.new()
	jm.mesh = jmb.build()
	jaw.add_child(jm)
	for at in arm_spots:
		_arm(at)
	neck.position = Vector3(0, -4.5, 0)
	visible = false


func _arm(at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = atan2(-at.x, -at.z)
	add_child(root)
	var upper := Node3D.new()
	root.add_child(upper)
	var umb := MB.new()
	umb.box("w", white, Vector3(0.45, 0.45, 3.0), MB.T(Vector3(0, 0, 1.5)), Color("c9d1d9"))
	umb.cyl("w", white, 0.35, 0.35, 0.5, 10, MB.T(Vector3.ZERO, Vector3(0, 0, PI / 2)), Color("ff5fa2"))
	var um := MeshInstance3D.new()
	um.mesh = umb.build()
	upper.add_child(um)
	var fore := Node3D.new()
	fore.position = Vector3(0, 0, 3.0)
	upper.add_child(fore)
	var fmb := MB.new()
	fmb.box("w", white, Vector3(0.38, 0.38, 2.4), MB.T(Vector3(0, 0, 1.2)), Color("e8eef2"))
	fmb.cyl("w", white, 0.3, 0.3, 0.45, 10, MB.T(Vector3.ZERO, Vector3(0, 0, PI / 2)), Color("ffd23f"))
	var fm := MeshInstance3D.new()
	fm.mesh = fmb.build()
	fore.add_child(fm)
	var claw := Node3D.new()
	claw.position = Vector3(0, 0, 2.4)
	fore.add_child(claw)
	var cmb := MB.new()
	for s in [-1.0, 1.0]:
		cmb.box("w", white, Vector3(0.12, 0.12, 0.8), MB.T(Vector3(s * 0.22, 0, 0.35), Vector3(0, s * 0.35, 0)), Color("8a96a4"))
	cmb.box("w", white, Vector3(0.5, 0.3, 0.3), MB.T(), Color("8a96a4"))
	var cm := MeshInstance3D.new()
	cm.mesh = cmb.build()
	claw.add_child(cm)
	# folded away in its hatch
	upper.rotation = Vector3(1.4, 0, 0)
	fore.rotation = Vector3(-2.6, 0, 0)
	root.position.y = -1.5
	arms.append({"root": root, "upper": upper, "fore": fore, "claw": claw, "home": at})


func _kill_tween() -> Tween:
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	return _tw


func emerge() -> void:
	if up:
		return
	up = true
	visible = true
	var tw := _kill_tween()
	tw.tween_property(neck, "position:y", -4.8, 0.25).set_trans(Tween.TRANS_SINE)   # the wind-up
	tw.tween_property(neck, "position:y", 3.3, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if get_node_or_null("/root/Audio"):
		Audio.sfx("door", 0.0, -8.0, 0.6)


func retract() -> void:
	if not up:
		return
	up = false
	var tw := _kill_tween()
	tw.tween_property(neck, "position:y", 3.6, 0.2)
	tw.tween_property(neck, "position:y", -4.5, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for a in arms:
		_fold(a)
	tw.tween_callback(func(): visible = false)


func speak(seconds: float) -> void:
	_talk = maxf(_talk, seconds)


func look(p: Vector3) -> void:
	_look = p


func mood(c: String) -> void:
	_eye_col = {"angry": Color("ff3b3b"), "excited": Color("ffd23f"), "sad": Color("6a8aff"), "glitch": Color("ffffff"), "intense": Color("ff5fa2")}.get(c, Color("6af0ff"))
	glow.albedo_color = _eye_col


## Reach an arm out over the board to a point (puppet units), and fold it back after.
func reach(at: Vector3, hold := 1.2, then := Callable()) -> void:
	if arms.is_empty():
		return
	var best: Dictionary = arms[0]
	for a in arms:
		if (a.home as Vector3).distance_to(at) < (best.home as Vector3).distance_to(at):
			best = a
	var root: Node3D = best.root
	var d := at - Vector3(root.position.x, 0, root.position.z)
	var yaw := atan2(d.x, d.z)
	var dist := Vector2(d.x, d.z).length()
	var tw := create_tween()
	tw.tween_property(root, "position:y", 1.2, 0.3).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(root, "rotation:y", yaw, 0.5)
	var bend := clampf(1.0 - dist / 5.4, 0.0, 1.0)
	tw.tween_property(best.upper, "rotation:x", -0.2 + bend * 0.6, 0.45).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(best.fore, "rotation:x", 0.6 + bend * 1.0, 0.45).set_trans(Tween.TRANS_BACK)
	if then.is_valid():
		tw.tween_callback(then)
	tw.tween_interval(hold)
	tw.tween_callback(func(): _fold(best))


func _fold(a: Dictionary) -> void:
	var tw := create_tween()
	tw.tween_property(a.upper, "rotation:x", 1.4, 0.5)
	tw.parallel().tween_property(a.fore, "rotation:x", -2.6, 0.5)
	tw.tween_property(a.root, "position:y", -1.5, 0.4)


func play(name: String, target := Vector3.INF) -> void:
	match name:
		"emerge":
			emerge()
		"retract":
			retract()
		"tilt":
			_head_tween(Vector3(0, 0, 0.35), 0.6)
		"point":
			emerge()
			if target != Vector3.INF:
				look(target)
				reach(target, 1.4)
		"grab":
			emerge()
			if target != Vector3.INF:
				reach(target, 1.6)
		"tap":
			for a in arms:
				var tw := create_tween()
				tw.tween_property(a.root, "position:y", 0.2, 0.2)
				for k in 4:
					tw.tween_property(a.fore, "rotation:x", -1.8, 0.08)
					tw.tween_property(a.fore, "rotation:x", -2.2, 0.08)
				tw.tween_property(a.root, "position:y", -1.5, 0.3)
				break
		"dispense":
			emerge()
			if target != Vector3.INF:
				reach(target, 1.0)
		"slam":
			emerge()
			for a in arms:
				var tw := create_tween()
				tw.tween_property(a.root, "position:y", 2.5, 0.25)
				tw.tween_property(a.root, "position:y", 0.0, 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
				tw.tween_interval(0.4)
				tw.tween_property(a.root, "position:y", -1.5, 0.4)
		"laugh":
			emerge()
			speak(1.8)
			_head_tween(Vector3(-0.3, 0, 0), 1.2, 3)
		"stare":
			emerge()
			_talk = 0.0
			if target != Vector3.INF:
				look(target)
		"disapprove":
			emerge()
			mood("sad")
			_head_tween(Vector3(0, 0.4, 0), 1.2, 3)
		"excited":
			emerge()
			mood("excited")
			_head_tween(Vector3(0, 0, 0.2), 0.8, 4)
		"angry":
			emerge()
			mood("angry")
			_head_tween(Vector3(0.3, 0, 0), 0.4, 2)
		"sympathy":
			emerge()
			mood("sad")
			_head_tween(Vector3(0.2, 0, 0.3), 1.4)
		"malfunction":
			emerge()
			mood("glitch")
			_seizure = 1.0
		"seizure":
			emerge()
			mood("glitch")
			_seizure = 2.5
		"trophy", "celebrate":
			emerge()
			mood("excited")
			for a in arms:
				var tw := create_tween()
				tw.tween_property(a.root, "position:y", 2.0, 0.4).set_trans(Tween.TRANS_BACK)
				tw.parallel().tween_property(a.upper, "rotation:x", -1.2, 0.5)
				tw.tween_interval(1.5)
				tw.tween_callback(func(): _fold(a))
		"roulette", "execute":
			emerge()
			mood("intense")
			if target != Vector3.INF:
				look(target)
				reach(target, 2.0)
		"interrupt":
			emerge()
			mood("intense")
			play("slam")


func _head_tween(rot: Vector3, dur: float, wobbles := 1) -> void:
	var tw := create_tween()
	for k in wobbles:
		tw.tween_property(head, "rotation", rot * (1.0 if k % 2 == 0 else -0.6), dur / (wobbles * 2.0)).set_trans(Tween.TRANS_SINE)
	tw.tween_property(head, "rotation", Vector3.ZERO, dur * 0.5).set_trans(Tween.TRANS_BACK)


func _process(delta: float) -> void:
	_t += delta
	if not visible:
		return
	if _talk > 0.0:
		_talk -= delta
		jaw.rotation.x = absf(sin(_t * 14.0)) * 0.5
	else:
		jaw.rotation.x = lerpf(jaw.rotation.x, 0.0, minf(1.0, delta * 8.0))
	if _seizure > 0.0:
		_seizure -= delta
		head.rotation = Vector3(randf_range(-0.3, 0.3), randf_range(-0.5, 0.5), randf_range(-0.3, 0.3))
		for e in eyes:
			(e as Node3D).visible = randf() > 0.3
		if _seizure <= 0.0:
			head.rotation = Vector3.ZERO
			for e in eyes:
				(e as Node3D).visible = true
			mood("")
	elif _look != Vector3.INF:
		var d := to_local(_look) - (neck.position + head.position)
		neck.rotation.y = lerp_angle(neck.rotation.y, atan2(d.x, d.z), minf(1.0, delta * 3.0))
	# idle: a slow mechanical breathing, the eyes pulsing
	neck.position.x = sin(_t * 0.7) * 0.05
	for e in eyes:
		(e as Node3D).scale = Vector3.ONE * (1.0 + sin(_t * 3.0) * 0.06)
