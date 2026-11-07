class_name PartyVenue
extends Node3D
## THE PERFECT PARTY: the slaughterhouse after the robot got at it. The industrial bones
## stay (white tiles to shoulder height, drains in the floor, meat rails and hooks across
## the ceiling, a big refrigeration door, a processing machine in the corner) and over all
## of it, the robot's idea of a children's party: the MURDERLAND brand on everything, a
## game-show stage with screens and spotlights and the mascot, bunting from the meat rails,
## a prize counter, a buffet with a cake in a refrigerated display case, an arcade corner,
## the escape room's cheerful front ("CAN YOU ESCAPE BEFORE THE PARTY ENDS?"), the way
## to the attractions, bleachers for the spectators. Bright from across the room;
## unpleasant up close. Built over the Hall (LAST CALL's room), in its metres.

const W := 15.0
const FRONT := 7.0
const BACK := -10.0
const H := 3.6

var white: Material
var glow: Material
var font: Font
var screens: Array = []
var spots: Array = []
var bulbs: Array = []
var _t := 0.0
var facility: Dictionary = {}


func build(hall: Node3D) -> void:
	white = MB.mat(Tex.solid(Color.WHITE))
	glow = MB.mat(Tex.solid(Color.WHITE), Color.WHITE, Vector2.ONE, true)
	font = PartyUi.title_font()
	facility = Assets.load_json("res://assets/data/facility.json").get("things", {})
	_tiles()
	_rails()
	_host_stage()
	_prize_counter()
	_buffet()
	_arcade_corner()
	_escape_front()
	_attractions_arch()
	_machinery()
	_facility_props()
	_lights()


func _mi(mb: MB, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _sign(text: String, at: Vector3, rot_y: float, size: int, col: Color, neon := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = col
	l.outline_size = 14
	l.outline_modulate = Color(col.r, col.g, col.b, 0.5) if neon else Color("1a0b14")
	l.shaded = false
	l.double_sided = false
	l.position = at
	l.rotation.y = rot_y
	add_child(l)
	return l


func _lamp(at: Vector3, col: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.position = at
	add_child(l)
	return l


## White slaughterhouse tiles to shoulder height on every wall (with a stained grout line),
## a pink party stripe above them; the floor's drains.
func _tiles() -> void:
	var mb := MB.new()
	var tile_h := 1.5
	for side in [-1.0, 1.0]:
		var x: float = side * (W / 2 - 0.03)
		var z := BACK + 0.2
		while z < FRONT - 0.2:
			for j in 6:
				var y := 0.13 + j * 0.25
				var c := Color("eef2f0") if (int(z * 4) + j) % 7 != 0 else Color("d8d0c0")
				mb.box("w", white, Vector3(0.02, 0.23, 0.48), MB.T(Vector3(x, y, z + 0.25)), c)
			z += 0.5
		mb.box("w", white, Vector3(0.03, 0.18, FRONT - BACK), MB.T(Vector3(x, tile_h + 0.12, (FRONT + BACK) / 2)), Color("ff5fa2"))
	var x0 := -W / 2 + 0.2
	while x0 < W / 2 - 0.2:
		for j in 6:
			var c := Color("eef2f0") if (int(x0 * 4) + j) % 5 != 0 else Color("e0d8c8")
			mb.box("w", white, Vector3(0.48, 0.23, 0.02), MB.T(Vector3(x0 + 0.25, 0.13 + j * 0.25, BACK + 0.03)), c)
		x0 += 0.5
	mb.box("w", white, Vector3(W, 0.18, 0.03), MB.T(Vector3(0, tile_h + 0.12, BACK + 0.03)), Color("ffd23f"))
	# drains in the floor, and the stains running to them
	for at in [Vector3(-3.5, 0, 2.5), Vector3(3.8, 0, -2.2), Vector3(-4.8, 0, -6.5), Vector3(2.2, 0, 3.6)]:
		mb.cyl("w", white, 0.22, 0.22, 0.012, 10, MB.T(at + Vector3(0, 0.006, 0)), Color("4a4f55"))
		for k in 5:
			mb.box("w", white, Vector3(0.3, 0.004, 0.025), MB.T(at + Vector3(0, 0.014, -0.1 + k * 0.05)), Color("1a1a1a"))
		mb.cyl("w", white, 0.6, 0.6, 0.003, 10, MB.T(at + Vector3(0.2, 0.004, 0.25)), Color("7a2a2a"))
	_mi(mb)


## Meat rails across the ceiling, hooks on them; bunting and banners hung off the hooks.
func _rails() -> void:
	var mb := MB.new()
	var cols := [Color("ff5fa2"), Color("ffd23f"), Color("2ec4c6"), Color("6fe3a5"), Color("8e5cf0"), Color("ff8c2e")]
	for z in [-7.5, -3.5, 0.5, 4.5]:
		mb.box("w", white, Vector3(W - 0.4, 0.08, 0.08), MB.T(Vector3(0, H - 0.35, z)), Color("9aa4ae"))
		for k in 12:
			var x := -6.6 + k * 1.2
			mb.box("w", white, Vector3(0.02, 0.3, 0.02), MB.T(Vector3(x, H - 0.52, z)), Color("8a929c"))
			mb.ring("w", white, 0.06, 0.012, 6, MB.T(Vector3(x, H - 0.7, z + 0.04), Vector3(0, PI / 2, 0)), Color("8a929c"))
		# bunting between the hooks
		for k in 26:
			var x2 := -7.0 + k * 0.55
			var sag := sin(fmod(x2 + 7.0, 1.2) / 1.2 * PI) * 0.18
			mb.tri("w", white, Vector3(x2 - 0.18, H - 0.42 - sag, z), Vector3(x2 + 0.18, H - 0.42 - sag, z), Vector3(x2, H - 0.75 - sag, z), cols[k % cols.size()])
	_mi(mb)
	_sign("WELCOME, GUESTS!", Vector3(0, H - 0.95, 4.5), PI, 64, Color("2ec4c6"))


## The host's game-show stage: the MURDERLAND sign, two screens, spotlights, the mascot.
func _host_stage() -> void:
	var mb := MB.new()
	# a backdrop of coloured panels behind the stage
	for k in 9:
		mb.box("w", white, Vector3(1.4, 3.2, 0.06), MB.T(Vector3(-5.6 + k * 1.4, 1.9, BACK + 0.12)), [Color("ff5fa2"), Color("ffd23f"), Color("2ec4c6")][k % 3])
	# a lit rim round the stage front
	for k in 24:
		mb.sphere("w", glow, 0.05, 2, 5, MB.T(Vector3(-3.4 + k * 0.296, 0.31, -4.52)), Color("ffd23f"))
	# the screens
	for s in [-1.0, 1.0]:
		mb.box("w", white, Vector3(1.5, 1.0, 0.12), MB.T(Vector3(s * 3.6, 2.35, BACK + 0.25)), Color("1a1a1a"))
		mb.box("w", white, Vector3(0.12, 1.6, 0.12), MB.T(Vector3(s * 3.6, 0.8, BACK + 0.25)), Color("c9d1d9"))
	# the mascot: a grinning thing in a party hat, taller than a man
	var mx := -5.6
	mb.cyl("w", white, 0.35, 0.5, 1.2, 10, MB.T(Vector3(mx, 0.9, -6.5)), Color("ff5fa2"))
	mb.sphere("w", white, 0.55, 5, 10, MB.T(Vector3(mx, 1.9, -6.5)), Color("ffe0ec"))
	mb.cyl("w", white, 0.0, 0.32, 0.7, 8, MB.T(Vector3(mx, 2.7, -6.5)), Color("2ec4c6"))
	for s in [-1.0, 1.0]:
		mb.sphere("w", white, 0.12, 3, 6, MB.T(Vector3(mx + s * 0.2, 2.0, -6.0)), Color("ffffff"))
		mb.sphere("w", white, 0.06, 3, 6, MB.T(Vector3(mx + s * 0.2, 2.0, -5.9)), Color("000000"))
	mb.box("w", white, Vector3(0.6, 0.08, 0.08), MB.T(Vector3(mx, 1.75, -5.97)), Color("8a0f1a"))
	_mi(mb)
	for s in [-1.0, 1.0]:
		var scr := Label3D.new()
		scr.text = "PARTY\nTIME!"
		scr.font = font
		scr.font_size = 40
		scr.pixel_size = 0.006
		scr.modulate = Color("6fe3a5")
		scr.shaded = false
		scr.position = Vector3(s * 3.6, 2.35, BACK + 0.33)
		add_child(scr)
		screens.append(scr)
	_sign("MURDERLAND!", Vector3(0, 3.05, BACK + 0.2), 0.0, 150, Color("ffd23f"), true)
	for k in 3:
		var sp := SpotLight3D.new()
		sp.light_color = [Color("ff6ad5"), Color("6af0ff"), Color("fff0b0")][k]
		sp.light_energy = 3.0
		sp.spot_range = 9.0
		sp.spot_angle = 18.0
		sp.position = Vector3(-3.0 + k * 3.0, H - 0.2, -2.0)
		add_child(sp)
		spots.append(sp)


## The prize counter: shelves of jars of Teeth, trophies, wrapped things (left wall, front).
func _prize_counter() -> void:
	var mb := MB.new()
	var at := Vector3(-6.7, 0, 1.6)
	mb.box("w", white, Vector3(0.9, 1.0, 3.2), MB.T(at + Vector3(0, 0.5, 0)), Color("ff8c2e"))
	mb.box("w", white, Vector3(1.0, 0.06, 3.3), MB.T(at + Vector3(0, 1.03, 0)), Color("ffd23f"))
	for j in 3:
		mb.box("w", white, Vector3(0.4, 0.04, 3.2), MB.T(Vector3(-7.25, 1.4 + j * 0.45, at.z)), Color("8a5a3a"))
		for k in 7:
			var z := at.z - 1.4 + k * 0.45
			match (j + k) % 4:
				0:
					mb.cyl("w", white, 0.09, 0.09, 0.22, 8, MB.T(Vector3(-7.25, 1.53 + j * 0.45, z)), Color("dff4ff"))
					mb.sphere("w", white, 0.05, 2, 5, MB.T(Vector3(-7.25, 1.5 + j * 0.45, z)), Color("fff4dc"))
				1:
					mb.cyl("w", white, 0.04, 0.1, 0.25, 6, MB.T(Vector3(-7.25, 1.55 + j * 0.45, z)), Color("ffd23f"))
				2:
					mb.box("w", white, Vector3(0.2, 0.2, 0.2), MB.T(Vector3(-7.25, 1.52 + j * 0.45, z)), [Color("ff5fa2"), Color("8e5cf0"), Color("2ec4c6")][k % 3])
				3:
					mb.sphere("w", white, 0.1, 3, 6, MB.T(Vector3(-7.25, 1.52 + j * 0.45, z)), Color("c84a5a"), Vector3(1, 0.7, 1.4))
	_mi(mb)
	_sign("PRIZES!", Vector3(-7.38, 3.0, at.z), PI / 2, 90, Color("ff8c2e"), true)


## The buffet: a cake in a refrigerated display case, jelly, drinks (right wall, middle).
func _buffet() -> void:
	var mb := MB.new()
	var at := Vector3(6.7, 0, -4.8)
	mb.box("w", white, Vector3(0.9, 0.9, 3.0), MB.T(at + Vector3(0, 0.45, 0)), Color("fff4dc"))
	for k in 6:
		mb.box("w", white, Vector3(0.92, 0.05, 0.5), MB.T(at + Vector3(0, 0.88, -1.25 + k * 0.5)), Color("ff5fa2") if k % 2 == 0 else Color("ffffff"))
	# jellies, cupcakes, punch
	for k in 5:
		var z := at.z - 1.2 + k * 0.6
		mb.cyl("w", white, 0.13, 0.16, 0.18, 8, MB.T(Vector3(at.x - 0.15, 1.0, z)), [Color("ff3b3b"), Color("6fe3a5"), Color("ffd23f")][k % 3])
		mb.cyl("w", white, 0.07, 0.06, 0.08, 8, MB.T(Vector3(at.x + 0.2, 0.96, z + 0.2)), Color("f4c6a6"))
		mb.sphere("w", white, 0.06, 3, 6, MB.T(Vector3(at.x + 0.2, 1.03, z + 0.2)), Color("ff9fd0"))
	mb.cyl("w", white, 0.2, 0.16, 0.25, 10, MB.T(Vector3(at.x, 1.02, at.z + 1.1)), Color("c0102a"))
	# the display fridge with the cake in it
	var fz := at.z - 2.4
	mb.box("w", white, Vector3(1.0, 2.2, 1.0), MB.T(Vector3(at.x, 1.1, fz)), Color("c9d1d9"))
	mb.box("w", white, Vector3(0.05, 1.6, 0.8), MB.T(Vector3(at.x - 0.5, 1.2, fz)), Color("bfe9ff"))
	mb.cyl("w", white, 0.3, 0.3, 0.35, 12, MB.T(Vector3(at.x, 1.0, fz)), Color("ff9fd0"))
	mb.cyl("w", white, 0.22, 0.22, 0.28, 12, MB.T(Vector3(at.x, 1.32, fz)), Color("fff4dc"))
	mb.sphere("w", white, 0.06, 3, 6, MB.T(Vector3(at.x - 0.1, 1.5, fz)), Color("c84a5a"))
	_mi(mb)
	_lamp(Vector3(at.x - 0.4, 1.5, fz), Color("bfe9ff"), 0.8, 2.0)
	_sign("BUFFET!", Vector3(7.38, 2.8, at.z), -PI / 2, 90, Color("6fe3a5"), true)


func _arcade_corner() -> void:
	var mb := MB.new()
	for k in 3:
		var at := Vector3(6.9, 0, -0.4 + k * 0.9)
		if k == 0:
			continue   # the broken one is a facility thing (placed with the others)
		mb.box("w", white, Vector3(0.7, 1.8, 0.75), MB.T(at + Vector3(0, 0.9, 0)), [Color("8e5cf0"), Color("2ec4c6"), Color("ff3b3b")][k])
		mb.box("w", white, Vector3(0.05, 0.45, 0.5), MB.T(at + Vector3(-0.36, 1.35, 0)), Color("1a1a1a"))
	_mi(mb)
	_sign("ARCADE", Vector3(7.38, 2.6, 0.5), -PI / 2, 80, Color("2ec4c6"), true)


## The escape room's front, on the front wall: a ticket booth, a big clock, a novelty key,
## the heavy door, and the sign.
func _escape_front() -> void:
	var mb := MB.new()
	var door := Vector3(6.0, 0, FRONT - 0.05)
	for s in [-1.0, 1.0]:
		mb.box("w", white, Vector3(0.35, 2.6, 0.2), MB.T(door + Vector3(s * 0.85, 1.3, -0.1)), Color("ff5fa2"))
	mb.box("w", white, Vector3(2.1, 0.5, 0.2), MB.T(door + Vector3(0, 2.75, -0.1)), Color("ffd23f"))
	mb.box("w", white, Vector3(0.9, 1.2, 0.8), MB.T(Vector3(4.2, 0.6, FRONT - 0.6)), Color("2ec4c6"))
	mb.box("w", white, Vector3(1.0, 0.1, 0.9), MB.T(Vector3(4.2, 1.25, FRONT - 0.6)), Color("ff5fa2"))
	mb.cyl("w", white, 0.45, 0.45, 0.08, 14, MB.T(Vector3(3.3, 2.4, FRONT - 0.06), Vector3(PI / 2, 0, 0)), Color("fff4dc"))
	mb.box("w", white, Vector3(0.05, 0.3, 0.02), MB.T(Vector3(3.3, 2.5, FRONT - 0.11)), Color("1a0b14"))
	# a giant novelty key leaning on the wall
	mb.ring("w", white, 0.25, 0.07, 10, MB.T(Vector3(7.2, 1.6, FRONT - 0.2), Vector3(PI / 2, 0, 0)), Color("ffd23f"))
	mb.box("w", white, Vector3(0.1, 1.2, 0.1), MB.T(Vector3(7.2, 0.8, FRONT - 0.2)), Color("ffd23f"))
	_mi(mb)
	_sign("CAN YOU ESCAPE\nBEFORE THE PARTY ENDS?", door + Vector3(0, 3.25, -0.25), PI, 60, Color("ffd23f"), true)


func _attractions_arch() -> void:
	# the back corridor (toward the attractions and the back rooms)
	var mb := MB.new()
	var at := Vector3(5.8, 0, BACK + 0.06)
	for s in [-1.0, 1.0]:
		mb.cyl("w", white, 0.14, 0.16, 2.6, 8, MB.T(at + Vector3(s * 0.75, 1.3, 0.12)), Color("2ec4c6"))
	_mi(mb)
	_sign("THE ATTRACTIONS →", at + Vector3(0, 2.75, 0.2), 0.0, 52, Color("ff5fa2"), true)


## The slaughterhouse under it: a big refrigeration door and a processing machine, both
## decorated (badly).
func _machinery() -> void:
	var mb := MB.new()
	var at := Vector3(-6.6, 0, -1.6)
	mb.box("w", white, Vector3(0.9, 1.6, 1.6), MB.T(at + Vector3(0, 0.8, 0)), Color("9aa4ae"))
	mb.cyl("w", white, 0.45, 0.45, 0.5, 10, MB.T(at + Vector3(0.2, 1.85, 0), Vector3(0, 0, PI / 2)), Color("6a7480"))
	mb.box("w", white, Vector3(0.6, 0.12, 2.2), MB.T(at + Vector3(0.6, 0.85, 0)), Color("2a2a2a"))
	for k in 4:
		mb.sphere("w", white, 0.16, 3, 6, MB.T(at + Vector3(0.55, 1.05, -0.7 + k * 0.45)), [Color("ff5fa2"), Color("ffd23f")][k % 2])
	mb.box("w", white, Vector3(1.6, 2.6, 0.18), MB.T(Vector3(-2.8, 1.3, BACK + 0.12)), Color("c9d1d9"))
	mb.box("w", white, Vector3(0.12, 0.7, 0.12), MB.T(Vector3(-2.2, 1.3, BACK + 0.25)), Color("6a7480"))
	_mi(mb)
	_sign("FREEZER\n(PARTY FOOD)", Vector3(-2.8, 2.9, BACK + 0.25), 0.0, 40, Color("2ec4c6"))


## Everything you can walk up to and use in the showroom (facility.json things in the hall).
func _facility_props() -> void:
	for id in facility.keys():
		var th: Dictionary = facility[id]
		if str(th.get("area", "hall")) != "hall":
			continue
		var p: Array = th.pos
		var at := Vector3(float(p[0]), 0, float(p[1]))
		var mb := MB.new()
		var face := atan2(-at.x, -at.z)
		match id:
			"vending":
				mb.box("w", white, Vector3(0.9, 1.9, 0.75), MB.T(at + Vector3(0, 0.95, 0)), Color("ff3b3b"))
				mb.box("w", white, Vector3(0.65, 1.1, 0.04), MB.T(at + Vector3(0, 1.15, 0.38)), Color("bfe9ff"))
			"phone":
				mb.box("w", white, Vector3(0.3, 0.45, 0.15), MB.T(at + Vector3(0.2, 1.5, 0)), Color("2a2a2a"))
				mb.box("w", white, Vector3(0.08, 0.3, 0.08), MB.T(at + Vector3(0.2, 1.45, 0.1)), Color("1a1a1a"))
			"arcade":
				mb.box("w", white, Vector3(0.7, 1.8, 0.75), MB.T(at + Vector3(0, 0.9, 0)), Color("3a3a4a"))
				mb.box("w", white, Vector3(0.05, 0.45, 0.5), MB.T(at + Vector3(-0.36, 1.35, 0)), Color("0a0a0a"))
			"drain":
				mb.cyl("w", white, 0.28, 0.28, 0.02, 10, MB.T(at + Vector3(0, 0.01, 0)), Color("3a3f44"))
			"props":
				mb.box("w", white, Vector3(1.2, 2.1, 0.6), MB.T(at + Vector3(0, 1.05, 0)), Color("8e5cf0"))
				mb.box("w", white, Vector3(0.04, 0.2, 0.04), MB.T(at + Vector3(0.1, 1.1, 0.32)), Color("ffd23f"))
			"fusebox":
				mb.box("w", white, Vector3(0.6, 0.8, 0.2), MB.T(at + Vector3(0, 1.5, 0)), Color("9aa4ae"))
				mb.box("w", white, Vector3(0.1, 0.1, 0.05), MB.T(at + Vector3(0, 1.5, 0.12)), Color("ff3b3b"))
			"panel":
				mb.box("w", white, Vector3(0.05, 1.2, 0.9), MB.T(at + Vector3(-0.4, 0.8, 0)), Color("e8eae6"))
			"stairs_door", "pinata":
				pass
		if mb.surfaces.is_empty():
			continue
		_mi(mb)


func _lights() -> void:
	# bright party lighting: colour washes on every wall, warm light on the table
	_lamp(Vector3(0, 3.2, 0.2), Color("fff2e0"), 0.7, 5.0)
	_lamp(Vector3(-5.5, 2.6, 2.0), Color("ff8fc8"), 1.4, 7.0)
	_lamp(Vector3(5.5, 2.6, 2.0), Color("8fe8ff"), 1.4, 7.0)
	_lamp(Vector3(-5.5, 2.6, -5.5), Color("ffe08f"), 1.3, 7.0)
	_lamp(Vector3(5.5, 2.6, -5.5), Color("b48cff"), 1.3, 7.0)
	_lamp(Vector3(0, 2.8, -7.0), Color("ffd0f0"), 1.6, 6.0)


func _process(delta: float) -> void:
	_t += delta
	for k in spots.size():
		var sp: SpotLight3D = spots[k]
		sp.rotation = Vector3(-1.1 + sin(_t * 0.6 + k) * 0.25, sin(_t * 0.4 + k * 2.0) * 0.7, 0)
	if int(_t * 2.0) % 6 == 0:
		for s in screens:
			(s as Label3D).text = ["PARTY\nTIME!", "SMILE!", "HAVE\nFUN!", "NOBODY\nLEAVES"][int(_t / 3.0) % 4]
