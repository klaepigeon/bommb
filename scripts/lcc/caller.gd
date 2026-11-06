class_name CallerFigure
extends Node3D
## THE CALLER: a brass bingo cage for a head, on a yoke on a thin bolted neck, full of dice
## that watch you (see DiceCage); plaid jacket, white shirt, red bow tie, white gloves. Animation is deliberately stiff: pivots and tweens, never smooth IK.

var head: Node3D
var cage: DiceCage
var arm_l: Node3D
var arm_r: Node3D
var fore_l: Node3D
var fore_r: Node3D
var torso: Node3D
var t := 0.0
var talking := 0.0
var mood := "idle"          # idle | pleased | displeased | intense
var gesture_tween: Tween
var look_yaw := 0.0        # where his head points: 0 = at you
var look_pitch := 0.0
var _yaw := 0.0
var _pitch := 0.0

const BRASS := Color("b08a3a")
const BRASS_DARK := Color("7a5a22")
const IVORY := Color("e8dcc0")
const GLOVE := Color("e8e4d8")

func _ready() -> void:
	build()

func build() -> void:
	for c in get_children():
		c.queue_free()
	var plaid := MB.mat(Tex.plaid(), Color.WHITE, Vector2(2, 2))
	var plain := MB.mat(Tex.grime(Color("d8d0bc"), Color("f0eadc"), 16, 3, 0.3))
	var brass := MB.mat(Tex.brass())
	var dark := MB.mat(Tex.grime(Color("1a1612"), Color("2e2620"), 16, 4, 0.3))
	var red := MB.mat(Tex.solid(Color("a8221a")))

	# Below the waist he is not one thing. A small brass cage for hips, and out of it a bundle
	# of legs that don't match: a red high heel, a white trainer, a work boot, a grey bare foot,
	# a child's sandal that doesn't reach the floor. Knees bend the wrong ways. They were other
	# people's. You only see it when you get up.
	_build_legs(brass, dark)
	torso = Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0, 0.85, 0)
	add_child(torso)
	var tb := MB.new()
	# jacket: wider at the shoulders, a little hunched
	tb.box("p", plaid, Vector3(0.62, 0.28, 0.34), MB.T(Vector3(0, 0.14, 0)), Color(1, 1, 1))
	tb.box("p", plaid, Vector3(0.74, 0.32, 0.38), MB.T(Vector3(0, 0.44, 0)), Color(1, 1, 1))
	tb.box("p", plaid, Vector3(0.9, 0.26, 0.42), MB.T(Vector3(0, 0.72, 0.0)), Color(1, 1, 1))
	# shirt front and pleats
	tb.box("w", plain, Vector3(0.2, 0.62, 0.02), MB.T(Vector3(0, 0.5, 0.2)), Color(1, 1, 1))
	for i in range(4):
		tb.box("w", plain, Vector3(0.01, 0.5, 0.025), MB.T(Vector3(-0.06 + i * 0.04, 0.47, 0.205)), Color(0.75, 0.73, 0.7))
	# lapels
	tb.box("p", plaid, Vector3(0.12, 0.5, 0.04), MB.T(Vector3(-0.15, 0.55, 0.2), Vector3(0, 0, -0.25)), Color(0.7, 0.7, 0.7))
	tb.box("p", plaid, Vector3(0.12, 0.5, 0.04), MB.T(Vector3(0.15, 0.55, 0.2), Vector3(0, 0, 0.25)), Color(0.7, 0.7, 0.7))
	# breast pocket card (a little white rectangle, like the screenshot)
	tb.box("w", plain, Vector3(0.08, 0.05, 0.02), MB.T(Vector3(0.22, 0.6, 0.215)), Color(1, 1, 1))
	# bow tie
	tb.box("r", red, Vector3(0.07, 0.07, 0.04), MB.T(Vector3(-0.055, 0.8, 0.22), Vector3(0, 0, 0.3)), Color(1, 1, 1))
	tb.box("r", red, Vector3(0.07, 0.07, 0.04), MB.T(Vector3(0.055, 0.8, 0.22), Vector3(0, 0, -0.3)), Color(1, 1, 1))
	tb.box("r", red, Vector3(0.03, 0.04, 0.05), MB.T(Vector3(0, 0.8, 0.225)), Color(0.8, 0.8, 0.8))
	# collar
	tb.box("w", plain, Vector3(0.22, 0.06, 0.18), MB.T(Vector3(0, 0.86, 0.06)), Color(1, 1, 1))
	_add_mesh(tb.build(), torso)

	arm_l = _arm(plaid, plain, -1)
	arm_r = _arm(plaid, plain, 1)

	# neck: a thin bolted column
	var neck := MB.new()
	neck.cyl("w", plain, 0.045, 0.04, 0.42, 6, MB.T(Vector3(0, 0.86, 0.04)), Color(0.85, 0.85, 0.82))
	for i in range(3):
		neck.cyl("b", brass, 0.06, 0.06, 0.03, 6, MB.T(Vector3(0, 0.92 + i * 0.12, 0.04)), Color(1, 1, 1))
	_add_mesh(neck.build(), torso)

	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.3, 0.04)
	torso.add_child(head)
	# the cage full of dice (see DiceCage): his eyes are two of the dice
	cage = DiceCage.new()
	cage.name = "DiceCage"
	head.add_child(cage)
	cage.clack.connect(func(k: float): if get_node_or_null("/root/Sfx"): Sfx.play("dice_clack", -26.0 + k * 6.0, 0.25))

# ------------------------------------------------------------------ masks
## Every face at the table is his: for each character he plays, the Caller hangs a painted
## paper mask over the front of the cage. No mask means he is speaking as himself. Behind a
## mask his eyes don't light, but the dice in the cage still turn toward you.
var mask_node: Node3D
var mask_id := ""

func set_mask(persona: Dictionary) -> void:
	var id: String = persona.get("id", "")
	if id == mask_id:
		return
	mask_id = id
	if mask_node:
		mask_node.queue_free()
		mask_node = null
	cage.set_masked(not (persona.is_empty() or id == "caller"))
	if persona.is_empty() or id == "caller" or not persona.has("mask"):
		return
	# a face cut out of magazines and taped to the wire: two eyes and a mouth, a bit crooked
	mask_node = Node3D.new()
	mask_node.position = Vector3(0, 0.02, 0)
	head.add_child(mask_node)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var dir := "res://assets/ink/faces/" + id
	var eye_t: Texture2D = load(dir + "_eye.png") if ResourceLoader.exists(dir + "_eye.png") else mask_tex(persona)
	var lip_t: Texture2D = load(dir + "_lips.png") if ResourceLoader.exists(dir + "_lips.png") else mask_tex(persona)
	var tape_t: Texture2D = load("res://assets/ink/faces/tape.png")
	var m: Dictionary = persona.get("mask", {})
	var gap := 0.13 + float(m.get("eye_w", 9)) * 0.003
	_cutout(eye_t, Vector2(-gap, 0.07), Vector2(0.21, 0.145), rng, tape_t, false)
	_cutout(eye_t, Vector2(gap, 0.07 + rng.randf_range(-0.02, 0.02)), Vector2(0.21, 0.145), rng, tape_t, true)
	_cutout(lip_t, Vector2(rng.randf_range(-0.02, 0.02), -0.17), Vector2(0.26, 0.16), rng, tape_t, false)
	mask_node.scale = Vector3(1, 0.01, 1)
	var tw := create_tween()
	tw.tween_property(mask_node, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## One cut-out picture on the front of the cage, bent a little round it, with a strip or two
## of tape holding it on.
func _cutout(tex: Texture2D, at: Vector2, size: Vector2, rng: RandomNumberGenerator, tape_t: Texture2D, flip: bool) -> void:
	const R := 0.4
	var piece := Node3D.new()
	var z := sqrt(maxf(0.0, R * R - at.x * at.x - at.y * at.y)) + 0.012
	piece.position = Vector3(at.x, at.y, z)
	piece.rotation = Vector3(-asin(clampf(at.y / R, -1, 1)) * 0.8, asin(clampf(at.x / R, -1, 1)) * 0.8, rng.randf_range(-0.18, 0.18))
	mask_node.add_child(piece)
	var mb := MB.new()
	var m := MB.mat(tex, Color(0.95, 0.93, 0.9), Vector2.ONE, true)
	var u0 := 1.0 if flip else 0.0
	var u1 := 0.0 if flip else 1.0
	mb.quad("c", m, Vector3(-size.x / 2, -size.y / 2, 0), Vector3(size.x / 2, -size.y / 2, 0), Vector3(size.x / 2, size.y / 2, 0), Vector3(-size.x / 2, size.y / 2, 0), Color(1, 1, 1), Vector2(u0, 0), Vector2(u1, 1))
	var tm := MB.mat(tape_t, Color(0.95, 0.9, 0.78), Vector2.ONE, true)
	for k in range(rng.randi_range(1, 2)):
		var corner := Vector2(size.x * (0.45 if (k + rng.randi()) % 2 == 0 else -0.45), size.y * (0.4 if k == 0 else -0.4))
		var ang := rng.randf_range(-0.9, 0.9) + (0.7 if corner.x * corner.y > 0 else -0.7)
		var tw := Vector2(0.11, 0.04)
		var c := cos(ang)
		var s2 := sin(ang)
		var pts := []
		for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var v := Vector2(q.x * tw.x / 2, q.y * tw.y / 2)
			pts.append(Vector3(corner.x + v.x * c - v.y * s2, corner.y + v.x * s2 + v.y * c, 0.004))
		mb.quad("t", tm, pts[0], pts[1], pts[2], pts[3], Color(1, 1, 1))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.add_child(mi)

## A boss is dead: he takes its face off, crumples it in his glove, and drops it.
func tear_mask() -> void:
	if mask_node == null:
		return
	var m := mask_node
	mask_node = null
	mask_id = ""
	gesture("reach")
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(m, "position", m.position + Vector3(0.25, -0.05, 0.35), 0.25).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(m, "rotation", Vector3(0.4, 0.8, 0.3), 0.25)
	tw.tween_callback(func():
		cage.set_masked(false)
		if get_node_or_null("/root/Sfx"):
			Sfx.play("paper", 0.0))
	tw.tween_property(m, "scale", Vector3(0.25, 0.3, 0.25), 0.18).set_trans(Tween.TRANS_BACK)
	tw.tween_property(m, "position", m.position + Vector3(0.4, -1.6, 0.5), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(m.queue_free)
	await tw.finished

static func mask_tex(p: Dictionary) -> Texture2D:
	# his drawings of them, in ink on card (tools/gen_ink.py)
	var drawn := "res://assets/ink/masks/%s.png" % str(p.get("id", ""))
	if ResourceLoader.exists(drawn):
		return load(drawn)
	var m: Dictionary = p.get("mask", {})
	return Tex.cached("mask_" + str(p.get("id", "")), func():
		var W := 48
		var H := 56
		var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var skin := Color(m.get("skin", "#e0d0b0"))
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(p.get("id", ""))
		# torn paper outline
		for y in range(H):
			var inset_l := 2 + int(abs(sin(y * 0.7 + rng.randf())) * 2.0)
			var inset_r := 2 + int(abs(cos(y * 0.5 + rng.randf())) * 2.0)
			for x in range(inset_l, W - inset_r):
				var n := Tex.fbm(x * 0.15, y * 0.15, 7)
				var c := skin.lerp(skin.darkened(0.25), clampf(n - 0.35, 0, 1))
				if (y < 3 or y > H - 4) and rng.randf() < 0.4:
					continue
				img.set_pixel(x, y, c)
		var ink := Color(m.get("ink", "#2a1a14"))
		var iris := Color(m.get("iris", "#4a6a5a"))
		var lip := Color(m.get("lips", "#b06a5a"))
		var hair := Color(m.get("hair", "#00000000"))
		# hair streak / fringe
		if hair.a > 0.0:
			for x in range(4, W - 4):
				var t := 3 + int(2 + sin(x * 0.4) * 2)
				for y in range(2, t + int(m.get("fringe", 2))):
					img.set_pixel(x, y, hair.darkened(rng.randf() * 0.2))
		# eyes: whites, iris, heavy lid line
		var ey := int(m.get("eye_y", 20))
		var eye_w := int(m.get("eye_w", 9))
		for side in [-1, 1]:
			var cx = W / 2 + side * 10
			for x in range(cx - eye_w / 2, cx + eye_w / 2 + 1):
				for y in range(ey - 2, ey + 3):
					img.set_pixel(x, y, Color("e8e4d8"))
				img.set_pixel(x, ey - 3, ink)
				if m.get("tired", false):
					img.set_pixel(x, ey - 2, skin.darkened(0.35))
			for x in range(cx - 1, cx + 2):
				for y in range(ey - 1, ey + 2):
					img.set_pixel(x, y, iris)
			img.set_pixel(cx, ey, Color("1a1410"))
			# brow
			var tilt: int = int(m.get("brow", 0))
			for x in range(cx - eye_w / 2, cx + eye_w / 2 + 1):
				img.set_pixel(x, ey - 6 + (tilt * side * (x - cx)) / 6, ink)
		# nose
		for y in range(ey + 4, ey + 11):
			img.set_pixel(W / 2 + 1, y, skin.darkened(0.3))
		img.set_pixel(W / 2 - 1, ey + 11, skin.darkened(0.4))
		# mouth
		var my := int(m.get("mouth_y", 40))
		var mw := int(m.get("mouth_w", 12))
		var smile: int = int(m.get("smile", 0))
		for x in range(W / 2 - mw / 2, W / 2 + mw / 2):
			var dy := (smile * (x - W / 2) * (x - W / 2)) / 40
			img.set_pixel(x, my - dy, lip.darkened(0.3))
			img.set_pixel(x, my + 1 - dy, lip)
			if m.get("teeth", false) and x % 2 == 0:
				img.set_pixel(x, my + 2 - dy, Color("e8e0c8"))
		# extras
		if m.get("mustache", false):
			for x in range(W / 2 - 7, W / 2 + 8):
				img.set_pixel(x, my - 3, hair if hair.a > 0 else ink)
				img.set_pixel(x, my - 4, hair if hair.a > 0 else ink)
		if m.get("glasses", false):
			for side2 in [-1, 1]:
				var gx = W / 2 + side2 * 10
				for x in range(gx - 6, gx + 7):
					img.set_pixel(x, ey - 4, ink)
					img.set_pixel(x, ey + 4, ink)
				for y in range(ey - 4, ey + 5):
					img.set_pixel(gx - 6, y, ink)
					img.set_pixel(gx + 6, y, ink)
		if m.get("crown", false):
			for x in range(8, W - 8):
				var hh := 4 if (x / 5) % 2 == 0 else 1
				for y in range(0, hh + 2):
					img.set_pixel(x, y, Color("c8a040"))
		if m.get("veil", false):
			for y in range(my - 6, H - 2):
				for x in range(6, W - 6):
					if (x + y) % 2 == 0:
						img.set_pixel(x, y, Color("1a1a1a"))
		if m.get("stitches", false):
			for y in range(8, H - 8, 3):
				img.set_pixel(W / 2 + 6, y, ink)
				img.set_pixel(W / 2 + 7, y + 1, ink)
		if m.get("blush", false):
			for side3 in [-1, 1]:
				for x in range(W / 2 + side3 * 13 - 2, W / 2 + side3 * 13 + 3):
					img.set_pixel(x, ey + 8, Color("c87a6a"))
		# a red stain, like the receptionist's
		if m.get("stain", true):
			var sx := 14 + rng.randi() % 20
			var sy := 26 + rng.randi() % 10
			img.set_pixel(sx, sy, Color("8a1a12"))
			img.set_pixel(sx + 1, sy, Color("8a1a12"))
		return img)

const ARM_REST := Vector3(-0.7, 0, 0.1)
const FORE_REST := Vector3(-0.55, 0, 0)

func _limb(mb: MB, key: String, m: Material, a: Vector3, b: Vector3, thick: float, col := Color(1, 1, 1)) -> void:
	var d := b - a
	var basis := Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.FORWARD)
	mb.box(key, m, Vector3(thick, thick, d.length()), Transform3D(basis, (a + b) / 2.0), col)

func _build_legs(brass: Material, dark: Material) -> void:
	var lower := MB.new()
	var hip_y := 0.86
	# the hip cage
	for k in range(4):
		lower.ring("h", brass, 0.2, 0.012, 12, MB.T(Vector3(0, hip_y, 0), Vector3(PI / 2 * (k % 2), PI * k / 4.0, 0)), Color(1, 1, 1))
	lower.cyl("h", brass, 0.03, 0.03, 0.2, 6, MB.T(Vector3(0, hip_y - 0.05, 0)), Color(1, 1, 1))
	var legs := [
		# [hip offset, knee, foot, trouser colour, shoe]
		[Vector3(-0.12, 0, 0.05), Vector3(-0.42, 0.55, 0.22), Vector3(-0.5, 0.0, 0.34), Color("b8a898"), "heel"],
		[Vector3(0.12, 0, 0.05), Vector3(0.38, 0.5, 0.3), Vector3(0.46, 0.0, 0.22), Color("5a7ab0"), "trainer"],
		[Vector3(0.05, 0, -0.1), Vector3(0.3, 0.62, -0.38), Vector3(0.28, 0.0, -0.52), Color("7a6a3e"), "boot"],
		# this one bends the wrong way
		[Vector3(-0.08, 0, -0.1), Vector3(-0.12, 0.52, 0.12), Vector3(-0.42, 0.0, -0.4), Color("b0a89a"), "bare"],
		[Vector3(0.0, -0.05, 0.12), Vector3(0.05, 0.5, 0.28), Vector3(0.08, 0.2, 0.42), Color("d8c8a8"), "sandal"],
	]
	var skin := MB.mat(Tex.grime(Color("a8a094"), Color("c4bcae"), 16, 311, 0.3))
	var tape := MB.mat(Tex.grime(Color("b8a878"), Color("d8c898"), 16, 313, 0.2))
	for L in legs:
		var hip: Vector3 = Vector3(0, hip_y, 0) + L[0]
		var knee: Vector3 = L[1]
		var foot: Vector3 = L[2]
		var tm := MB.mat(Tex.grime(L[3].darkened(0.25), L[3], 16, int(L[3].r * 100) + 320, 0.3))
		var thick := 0.075 if L[4] != "sandal" else 0.05
		_limb(lower, "t%d" % legs.find(L), tm if L[4] != "bare" else skin, hip, knee, thick)
		_limb(lower, "s%d" % legs.find(L), tm if L[4] != "bare" else skin, knee, foot, thick * 0.85)
		# joined on with parcel tape, like the faces
		_limb(lower, "tp", tape, knee + (hip - knee).normalized() * 0.05, knee + (foot - knee).normalized() * 0.05, thick + 0.025)
		_limb(lower, "tp", tape, hip, hip + (knee - hip).normalized() * 0.08, thick + 0.02)
		match L[4]:
			"heel":
				lower.box("hl", MB.mat(Tex.solid(Color("a8141a"))), Vector3(0.07, 0.04, 0.16), MB.T(foot + Vector3(0, 0.05, 0.05), Vector3(0.35, 0, 0)), Color(1, 1, 1))
				lower.box("hl", MB.mat(Tex.solid(Color("a8141a"))), Vector3(0.015, 0.09, 0.015), MB.T(foot + Vector3(0, 0.04, -0.03)), Color(1, 1, 1))
			"trainer":
				lower.box("tr", MB.mat(Tex.solid(Color("e8e4dc"))), Vector3(0.1, 0.06, 0.22), MB.T(foot + Vector3(0, 0.03, 0.06)), Color(1, 1, 1))
			"boot":
				lower.box("bt", dark, Vector3(0.12, 0.12, 0.24), MB.T(foot + Vector3(0, 0.06, 0.05)), Color(0.9, 0.9, 0.9))
			"bare":
				lower.box("bf", skin, Vector3(0.09, 0.04, 0.2), MB.T(foot + Vector3(0, 0.02, 0.06)), Color(0.85, 0.85, 0.85))
				for tq in range(5):
					lower.box("bf", skin, Vector3(0.015, 0.02, 0.03), MB.T(foot + Vector3(-0.035 + tq * 0.018, 0.015, 0.17)), Color(0.8, 0.8, 0.8))
			"sandal":
				lower.box("sd", MB.mat(Tex.solid(Color("8a5a2a"))), Vector3(0.06, 0.015, 0.13), MB.T(foot + Vector3(0, -0.01, 0.03)), Color(1, 1, 1))
	_add_mesh(lower.build(), self)
	# and one more that doesn't reach the floor: a child's, in a school sock, one shoe lost.
	# It swings a little, on its own.
	dangle = Node3D.new()
	dangle.position = Vector3(0.0, hip_y - 0.04, -0.16)
	add_child(dangle)
	var dm := MB.new()
	var sock := MB.mat(Tex.grime(Color("c8c4b8"), Color("e8e4d8"), 16, 317, 0.2))
	_limb(dm, "d", skin, Vector3.ZERO, Vector3(0.02, -0.3, -0.04), 0.045)
	_limb(dm, "d", tape, Vector3.ZERO, Vector3(0.0, -0.06, -0.01), 0.07)
	_limb(dm, "k", sock, Vector3(0.02, -0.3, -0.04), Vector3(0.0, -0.56, 0.02), 0.04)
	dm.box("k", sock, Vector3(0.05, 0.03, 0.1), MB.T(Vector3(0.0, -0.58, 0.05)), Color(1, 1, 1))
	_add_mesh(dm.build(), dangle)

var dangle: Node3D

func _arm(plaid: Material, plain: Material, sx: int) -> Node3D:
	var shoulder := Node3D.new()
	shoulder.name = "ArmL" if sx < 0 else "ArmR"
	shoulder.position = Vector3(0.46 * sx, 0.74, 0)
	torso.add_child(shoulder)
	var up := MB.new()
	up.box("p", plaid, Vector3(0.17, 0.46, 0.18), MB.T(Vector3(0, -0.22, 0)), Color(1, 1, 1))
	_add_mesh(up.build(), shoulder)
	var fore := Node3D.new()
	fore.position = Vector3(0, -0.44, 0)
	shoulder.add_child(fore)
	var fb := MB.new()
	var brass := MB.mat(Tex.brass())
	fb.box("p", plaid, Vector3(0.15, 0.22, 0.16), MB.T(Vector3(0, -0.1, 0)), Color(0.9, 0.9, 0.9))
	# the sleeve ends and the arm carries on as brass, a telescope pulled out too far
	fb.cyl("b", brass, 0.035, 0.035, 0.24, 6, MB.T(Vector3(0, -0.45, 0)), Color(1, 1, 1))
	fb.cyl("b", brass, 0.026, 0.026, 0.26, 6, MB.T(Vector3(0, -0.69, 0)), Color(0.85, 0.85, 0.85))
	fb.ring("b", brass, 0.04, 0.01, 8, MB.T(Vector3(0, -0.45, 0)), Color(1, 1, 1))
	fb.box("w", plain, Vector3(0.13, 0.05, 0.14), MB.T(Vector3(0, -0.72, 0)), Color(1, 1, 1))
	# glove: palm and four stiff fingers, thumb
	fb.box("g", plain, Vector3(0.14, 0.12, 0.06), MB.T(Vector3(0, -0.8, 0)), GLOVE)
	for i in range(4):
		fb.box("g", plain, Vector3(0.028, 0.1, 0.035), MB.T(Vector3(-0.05 + i * 0.033, -0.9, 0)), GLOVE)
	fb.box("g", plain, Vector3(0.03, 0.07, 0.035), MB.T(Vector3(0.08 * -sx, -0.79, 0.02), Vector3(0, 0, 0.6 * sx)), GLOVE)
	_add_mesh(fb.build(), fore)
	shoulder.rotation = Vector3(ARM_REST.x, 0, ARM_REST.z * sx)
	fore.rotation = FORE_REST
	if sx < 0:
		fore_l = fore
	else:
		fore_r = fore
	return shoulder

func _add_mesh(m: Mesh, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	parent.add_child(mi)
	return mi

## He points at something with his right glove (a world position), until told to stop.
var point_target = null

func point_at(target) -> void:
	point_target = target
	if gesture_tween and gesture_tween.is_valid():
		gesture_tween.kill()

func stop_pointing() -> void:
	point_target = null
	var tw := create_tween()
	tw.tween_property(arm_r, "rotation", Vector3(ARM_REST.x, 0, ARM_REST.z), 0.35)

func _point(delta: float) -> void:
	var wp: Vector3
	if point_target is Node3D:
		if not is_instance_valid(point_target):
			point_target = null
			return
		wp = point_target.global_position
	else:
		wp = point_target
	var dir: Vector3 = (wp - arm_r.global_position).normalized()
	if dir.length() < 0.5:
		return
	var want := Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.RIGHT, PI / 2)
	var cur := arm_r.global_transform.basis.orthonormalized()
	var b := cur.slerp(want.orthonormalized(), minf(1.0, delta * 6.0))
	arm_r.global_transform = Transform3D(b.scaled(arm_r.global_transform.basis.get_scale()), arm_r.global_position)
	# a little jab every second, so the eye goes to it
	arm_r.position.z = 0.04 * maxf(0.0, sin(t * 6.0))

## He stops, mid-movement, for a moment too long. Then carries on as if he hadn't.
var _frozen := 0.0
var _twitch_at := 5.0
var _twitch_z := 0.0

func freeze(seconds: float) -> void:
	_frozen = seconds

func _process(delta: float) -> void:
	if _frozen > 0.0:
		_frozen -= delta
		return
	t += delta
	if point_target != null:
		_point(delta)
	# a twitch now and then: the head snaps a few degrees and back
	if t > _twitch_at:
		_twitch_at = t + randf_range(4.0, 11.0)
		var tw := create_tween()
		var z := randf_range(-0.3, 0.3)
		tw.tween_property(self, "_twitch_z", z, 0.04)
		tw.tween_interval(randf_range(0.05, 0.3))
		tw.tween_property(self, "_twitch_z", 0.0, 0.12)
	# the left glove drums on the table when nothing else is happening
	if gesture_tween == null or not gesture_tween.is_valid():
		arm_l.rotation.x = ARM_REST.x + 0.06 * maxf(0.0, sin(t * 11.0)) * float(int(t * 0.5) % 3 == 0)
	torso.position.y = 0.85 + sin(t * 1.1) * 0.006
	if dangle:
		dangle.rotation.x = sin(t * 0.9) * 0.18
		dangle.rotation.z = sin(t * 0.63 + 1.0) * 0.06
	_yaw = lerpf(_yaw, look_yaw, minf(1.0, delta * 5.0))
	_pitch = lerpf(_pitch, look_pitch, minf(1.0, delta * 5.0))
	var shiver := cage.tremble * 0.04 * sin(t * 47.0)
	head.rotation.y = _yaw + shiver
	head.rotation.z = sin(t * 0.37) * 0.03 + (sin(t * 9.0) * 0.02 if talking > 0.0 else 0.0) + _twitch_z
	head.rotation.x = -0.08 + _pitch + (sin(t * 7.0) * 0.03 if talking > 0.0 else 0.0)
	talking = max(0.0, talking - delta)

## The attention cycle, made visible. WATCHING: the head squares up to you and the dice turn
## their pips on you. Otherwise he looks somewhere else and the dice rattle.
const LOOKS := {"you": [0.0, 0.0], "tv": [1.25, 0.15], "clock": [-1.1, -0.35], "exit": [-1.6, 0.05],
	"ceiling": [0.2, -0.6], "floor": [0.3, 0.45], "board": [0.0, 0.35], "drink": [0.6, 0.4]}

func set_attention(watching: bool, target: String = "") -> void:
	cage.set_watching(watching)
	var tg := "you" if watching else (target if LOOKS.has(target) else "tv")
	look_yaw = LOOKS[tg][0]
	look_pitch = LOOKS[tg][1]

func set_suspicion(v: float) -> void:
	cage.set_suspicion(v)

## The tell, a second before he turns: a shudder through the cage.
func tell() -> void:
	cage.shudder(1.0)

func speak(seconds: float = 2.0) -> void:
	talking = seconds

## Stiff, readable gestures. Each returns to rest on its own.
func gesture(kind: String) -> void:
	if gesture_tween and gesture_tween.is_valid():
		gesture_tween.kill()
	gesture_tween = create_tween()
	var tw := gesture_tween
	match kind:
		"reach":  # into the cage, like drawing a ball
			tw.tween_property(arm_r, "rotation", Vector3(-2.6, 0, 0.5), 0.5).set_trans(Tween.TRANS_QUAD)
			tw.parallel().tween_property(fore_r, "rotation", Vector3(-0.8, 0, 0), 0.5)
			tw.tween_interval(0.7)
		"point":
			tw.tween_property(arm_r, "rotation", Vector3(-1.4, 0, 0.1), 0.35)
			tw.parallel().tween_property(fore_r, "rotation", Vector3(-0.1, 0, 0), 0.35)
			tw.tween_interval(0.8)
		"tap":
			tw.tween_property(arm_l, "rotation", Vector3(-1.0, 0, -0.1), 0.25)
			tw.tween_property(fore_l, "rotation", Vector3(-0.5, 0, 0), 0.12)
			tw.tween_property(fore_l, "rotation", Vector3(-1.1, 0, 0), 0.12)
			tw.tween_property(fore_l, "rotation", Vector3(-0.5, 0, 0), 0.12)
		"spread":
			tw.tween_property(arm_l, "rotation", Vector3(-0.9, 0, -0.9), 0.4)
			tw.parallel().tween_property(arm_r, "rotation", Vector3(-0.9, 0, 0.9), 0.4)
			tw.tween_interval(1.0)
		"lean":
			tw.tween_property(torso, "rotation", Vector3(0.25, 0, 0), 0.6)
			tw.tween_interval(1.0)
			tw.tween_property(torso, "rotation", Vector3.ZERO, 0.6)
		"slam":
			# CAUGHT: the right hand goes up and comes down flat on the table
			tw.tween_property(arm_r, "rotation", Vector3(-2.5, 0, 0.3), 0.18).set_trans(Tween.TRANS_QUAD)
			tw.parallel().tween_property(fore_r, "rotation", Vector3(-0.4, 0, 0), 0.18)
			tw.parallel().tween_property(torso, "rotation", Vector3(0.18, 0, 0), 0.18)
			tw.tween_property(arm_r, "rotation", Vector3(-1.2, 0, 0.15), 0.08).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(fore_r, "rotation", Vector3(-0.15, 0, 0), 0.08)
			tw.parallel().tween_property(torso, "rotation", Vector3(0.32, 0, 0), 0.08)
			tw.tween_callback(func(): cage.shudder(2.0))
			tw.tween_interval(0.8)
			tw.tween_property(torso, "rotation", Vector3.ZERO, 0.4)
		"wag":
			# a slow finger wag: he knows
			tw.tween_property(arm_l, "rotation", Vector3(-1.9, 0, -0.1), 0.3)
			tw.parallel().tween_property(fore_l, "rotation", Vector3(-0.6, 0, 0), 0.3)
			for i in range(3):
				tw.tween_property(fore_l, "rotation", Vector3(-0.6, 0, 0.35), 0.16)
				tw.tween_property(fore_l, "rotation", Vector3(-0.6, 0, -0.35), 0.16)
			tw.tween_interval(0.3)
		"spin":
			cage.whirl(1.2)
			tw.tween_interval(1.2)
	tw.tween_property(arm_l, "rotation", Vector3(ARM_REST.x, 0, -ARM_REST.z), 0.5)
	tw.parallel().tween_property(arm_r, "rotation", Vector3(ARM_REST.x, 0, ARM_REST.z), 0.5)
	tw.parallel().tween_property(fore_l, "rotation", FORE_REST, 0.5)
	tw.parallel().tween_property(fore_r, "rotation", FORE_REST, 0.5)
