class_name ArenaWorld
extends Node3D
## The attractions: every minigame is played somewhere of its own in the robot's
## entertainment complex, away from the cluttered board (and the meat puppets go there to
## play it). Ten arenas, each its own geometry, palette, lighting and moving gimmick, built
## round the play area the game's view lays down in the middle (about 16 x 12 puppet units).
##   kitchen    THE BIRTHDAY KITCHEN: giant countertops, ovens, mixing bowls, hanging utensils
##   speedway   THE SLAUGHTERHOUSE SPEEDWAY: conveyor roads, meat rails, gates, warning signs
##   factory    THE TOY FACTORY: assembly lines, robot arms, boxes, catwalks, gears
##   clown      THE CLOWN HOUSE: mirrors, a turning room, inflatables, striped tilted walls
##   aquarium   THE AQUARIUM: glass tanks, a tunnel, mechanical fish, walkways
##   locker     THE MEAT LOCKER: freezer doors, rails of hanging meat, frost, cold light
##   carnival   THE CARNIVAL: a ferris wheel, a carousel, booths, bunting, a coaster
##   hospital   THE HOSPITAL: beds, curtains, operating lamps, a corridor of doors
##   stage      THE PARTY STAGE: a game-show set, scoreboard, audience, spotlights, confetti
##   impossible THE IMPOSSIBLE ROOM: upside-down furniture, floating rooms, impossible stairs

const THEMES := {
	"meat_grinder": "factory", "floor_is_meat": "kitchen", "last_seat": "stage", "hook_line_sinker": "aquarium", "spin_cycle": "impossible",
	"better_together": "clown", "tug_of_war": "carnival", "the_controller": "speedway", "last_man_breathing": "hospital", "dont_press_it": "locker",
	"dead_weight": "factory", "run_for_your_life": "speedway", "human_shield": "carnival", "pick_your_poison": "kitchen", "confession": "stage",
	"consensus": "stage", "wrong_answers": "clown", "hot_potato": "impossible", "musical_chairs": "stage", "organ_trail": "hospital",
}
const TITLES := {"kitchen": "THE BIRTHDAY KITCHEN", "speedway": "THE SLAUGHTERHOUSE SPEEDWAY", "factory": "THE TOY FACTORY", "clown": "THE CLOWN HOUSE",
	"aquarium": "THE AQUARIUM", "locker": "THE MEAT LOCKER", "carnival": "THE CARNIVAL", "hospital": "THE HOSPITAL", "stage": "THE PARTY STAGE",
	"impossible": "THE IMPOSSIBLE ROOM"}

var theme := "stage"
var white: Material
var glow: Material
var spin: Array = []
var bob: Array = []
var lights: Array = []
var _t := 0.0


static func theme_for(game_id: String) -> String:
	return str(THEMES.get(game_id, "stage"))


func build(th: String) -> void:
	theme = th
	white = MB.mat(Tex.solid(Color.WHITE))
	glow = MB.mat(Tex.solid(Color.WHITE), Color.WHITE, Vector2.ONE, true)
	call("_" + theme)
	var l := Label3D.new()
	l.text = TITLES.get(theme, "")
	l.font = PartyUi.title_font()
	l.font_size = 140
	l.pixel_size = 0.02
	l.modulate = Color("ffd23f")
	l.outline_size = 24
	l.outline_modulate = Color("1a0b14")
	l.position = Vector3(0, 9.5, -14.0)
	add_child(l)


func _mi(mb: MB, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	parent.add_child(mi)
	return mi


func _n(at: Vector3, parent: Node3D = self) -> Node3D:
	var n := Node3D.new()
	n.position = at
	parent.add_child(n)
	return n


func _lamp(at: Vector3, col: Color, energy := 2.0, rng := 14.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.position = at
	add_child(l)
	lights.append(l)
	return l


## The shell every arena shares: a floor out past the play area and walls with a colour.
func _shell(mb: MB, floor_a: Color, floor_b: Color, wall: Color, w := 34.0, d := 28.0, h := 12.0, tiles := 2.0) -> void:
	var nx := int(w / tiles)
	var nz := int(d / tiles)
	for i in nx:
		for j in nz:
			mb.box("w", white, Vector3(tiles, 0.2, tiles), MB.T(Vector3(-w / 2 + (i + 0.5) * tiles, -0.3, -d / 2 + (j + 0.5) * tiles)), floor_a if (i + j) % 2 == 0 else floor_b)
	mb.box("w", white, Vector3(w, h, 0.4), MB.T(Vector3(0, h / 2 - 0.4, -d / 2)), wall)
	mb.box("w", white, Vector3(0.4, h, d), MB.T(Vector3(-w / 2, h / 2 - 0.4, 0)), wall.darkened(0.12))
	mb.box("w", white, Vector3(0.4, h, d), MB.T(Vector3(w / 2, h / 2 - 0.4, 0)), wall.darkened(0.12))


func _kitchen() -> void:
	var mb := MB.new()
	_shell(mb, Color("fff4dc"), Color("ff9fd0"), Color("ffd6e8"))
	# countertops round the back and sides, ovens, a giant mixer and bowls
	mb.box("w", white, Vector3(30, 3.0, 3.5), MB.T(Vector3(0, 1.1, -11.5)), Color("c9d1d9"))
	for k in 4:
		var x := -10.5 + k * 7.0
		mb.box("w", white, Vector3(5.0, 3.6, 0.3), MB.T(Vector3(x, 1.4, -9.7)), Color("2a2a30"))
		mb.box("w", white, Vector3(3.6, 2.0, 0.1), MB.T(Vector3(x, 1.4, -9.5)), Color("ff8c2e"))
	mb.cyl("w", white, 2.6, 2.0, 2.2, 14, MB.T(Vector3(-11, 1.1, 7)), Color("bfe9ff"))
	mb.cyl("w", white, 2.2, 1.6, 1.8, 14, MB.T(Vector3(11.5, 0.9, 7.5)), Color("ffd23f"))
	mb.box("w", white, Vector3(1.0, 6.0, 1.0), MB.T(Vector3(-11, 4.2, 4.5)), Color("ff5fa2"))
	mb.box("w", white, Vector3(3.6, 1.0, 1.0), MB.T(Vector3(-11, 7.0, 5.6)), Color("ff5fa2"))
	# a cake the size of a house, with candles
	mb.cyl("w", white, 3.0, 3.0, 2.0, 16, MB.T(Vector3(12, 1.0, -4)), Color("ff9fd0"))
	mb.cyl("w", white, 2.2, 2.2, 1.6, 16, MB.T(Vector3(12, 2.8, -4)), Color("fff4dc"))
	for k in 6:
		var a := TAU * k / 6.0
		mb.cyl("w", white, 0.12, 0.12, 1.2, 6, MB.T(Vector3(12 + sin(a) * 1.4, 4.2, -4 + cos(a) * 1.4)), Color("2ec4c6"))
		mb.sphere("w", glow, 0.18, 2, 6, MB.T(Vector3(12 + sin(a) * 1.4, 4.95, -4 + cos(a) * 1.4)), Color("ffd23f"))
	_mi(mb)
	# hanging utensils that swing
	for k in 5:
		var u := _n(Vector3(-8 + k * 4.0, 10.5, -6))
		var um := MB.new()
		um.box("w", white, Vector3(0.1, 3.0, 0.1), MB.T(Vector3(0, -1.5, 0)), Color("c9d1d9"))
		um.box("w", white, [Vector3(1.2, 0.6, 0.1), Vector3(0.6, 1.4, 0.1)][k % 2], MB.T(Vector3(0, -3.2, 0)), Color("e8eef2"))
		_mi(um, u)
		bob.append([u, "swing", 0.25, k * 0.7])
	_lamp(Vector3(0, 9, 4), Color("fff0f6"), 1.3, 30.0)
	_lamp(Vector3(12, 6, -4), Color("ffd090"), 1.5, 10.0)


func _speedway() -> void:
	var mb := MB.new()
	_shell(mb, Color("3a3d44"), Color("2e3036"), Color("6a7480"))
	# a track of conveyor road round the play area, hazard stripes, gates, a meat rail overhead
	for k in 40:
		var a := TAU * k / 40.0
		var at := Vector3(sin(a) * 12.5, -0.1, cos(a) * 10.0)
		mb.box("w", white, Vector3(2.6, 0.2, 2.2), MB.T(at, Vector3(0, a, 0)), Color("1e1e22"))
		mb.box("w", white, Vector3(0.3, 0.22, 2.2), MB.T(at + Vector3(cos(a), 0, -sin(a)) * 1.2, Vector3(0, a, 0)), Color("ffd23f") if k % 2 == 0 else Color("1a0b14"))
	for s in [-1.0, 1.0]:
		mb.box("w", white, Vector3(0.6, 6.0, 0.6), MB.T(Vector3(s * 7.5, 3.0, -9.0)), Color("ff3b3b"))
	mb.box("w", white, Vector3(15.6, 0.8, 0.6), MB.T(Vector3(0, 6.2, -9.0)), Color("ff3b3b"))
	mb.box("w", white, Vector3(30, 0.3, 0.3), MB.T(Vector3(0, 10.0, 0)), Color("c9d1d9"))
	for k in 8:
		mb.box("w", white, Vector3(0.1, 1.4, 0.1), MB.T(Vector3(-12 + k * 3.4, 9.3, 0)), Color("c9d1d9"))
		mb.sphere("w", white, 0.6, 3, 6, MB.T(Vector3(-12 + k * 3.4, 8.2, 0)), Color("b0303a"), Vector3(0.8, 1.6, 0.6))
	# giant warning signs
	for k in 3:
		mb.box("w", white, Vector3(4.0, 2.4, 0.2), MB.T(Vector3(-10 + k * 10, 7.0, -13.6)), Color("ffd23f"))
	_mi(mb)
	for k in 3:
		var l := Label3D.new()
		l.text = ["CAUTION!", "FAST!", "NO STOPPING"][k]
		l.font = PartyUi.title_font()
		l.font_size = 90
		l.pixel_size = 0.02
		l.modulate = Color("1a0b14")
		l.position = Vector3(-10 + k * 10, 7.0, -13.4)
		add_child(l)
	_lamp(Vector3(0, 9, 3), Color("e0f0ff"), 1.3, 30.0)
	_lamp(Vector3(0, 4, -9), Color("ff6a5a"), 1.5, 10.0)


func _factory() -> void:
	var mb := MB.new()
	_shell(mb, Color("ffe0b0"), Color("ffcf8a"), Color("8ad0ff"))
	# assembly lines with half-made toys, packing boxes, a catwalk
	for row in [-10.5, 9.5]:
		mb.box("w", white, Vector3(30, 1.2, 2.0), MB.T(Vector3(0, 0.6, row)), Color("2a2a30"))
		for k in 10:
			var x := -13 + k * 2.9
			mb.sphere("w", white, 0.55, 3, 6, MB.T(Vector3(x, 1.7, row)), [Color("ff5fa2"), Color("ffd23f"), Color("2ec4c6"), Color("b48cff")][k % 4])
			mb.box("w", white, Vector3(0.3, 0.8, 0.3), MB.T(Vector3(x + 0.4, 1.5, row + 0.4)), Color("e8c8b0"))
	for k in 5:
		mb.box("w", white, Vector3(2.4, 2.4, 2.4), MB.T(Vector3(14, 1.2 + k * 2.4, -4 + (k % 2) * 0.3)), Color("c89a6a"))
	mb.box("w", white, Vector3(30, 0.3, 2.0), MB.T(Vector3(0, 8.0, -12.5)), Color("ff8c2e"))
	_mi(mb)
	for k in 3:
		# robot arms that sweep
		var arm := _n(Vector3(-9 + k * 9, 0, -10.5))
		var am := MB.new()
		am.cyl("w", white, 0.6, 0.8, 1.0, 8, MB.T(Vector3(0, 0.5, 0)), Color("ff5fa2"))
		am.box("w", white, Vector3(0.5, 4.0, 0.5), MB.T(Vector3(0, 2.8, 0)), Color("ffd23f"))
		am.box("w", white, Vector3(0.4, 0.4, 3.0), MB.T(Vector3(0, 4.8, 1.3)), Color("ffd23f"))
		am.box("w", white, Vector3(1.0, 0.6, 0.3), MB.T(Vector3(0, 4.8, 2.9)), Color("c9d1d9"))
		_mi(am, arm)
		bob.append([arm, "yaw", 0.8, k * 1.3])
	var gear := _n(Vector3(-14, 6, -13.5))
	var gm := MB.new()
	gm.cyl("w", white, 3.0, 3.0, 0.5, 14, MB.T(Vector3.ZERO, Vector3(PI / 2, 0, 0)), Color("2ec4c6"))
	for j in 12:
		var a := TAU * j / 12.0
		gm.box("w", white, Vector3(0.8, 0.8, 0.5), MB.T(Vector3(cos(a), sin(a), 0) * 3.2, Vector3(0, 0, a)), Color("2ec4c6"))
	_mi(gm, gear)
	spin.append([gear, Vector3.BACK, 0.4])
	_lamp(Vector3(0, 10, 2), Color("fff6e0"), 1.3, 32.0)


func _clown() -> void:
	var mb := MB.new()
	_shell(mb, Color("ff5fa2"), Color("ffd23f"), Color("2ec4c6"))
	# striped walls at angles, mirrors, inflatables, a giant clown face on the back wall
	for k in 6:
		var a := -0.4 + k * 0.16
		mb.box("w", white, Vector3(4.0, 9.0, 0.3), MB.T(Vector3(-15 + k * 6, 4.0, -12.5), Vector3(0, 0, a)), Color("ffffff") if k % 2 == 0 else Color("ff3b3b"))
	for s in [-1.0, 1.0]:
		for k in 3:
			mb.box("w", white, Vector3(0.2, 4.0, 2.2), MB.T(Vector3(s * 15.5, 2.0, -6 + k * 5), Vector3(0, s * 0.3, 0)), Color("dde8f0"))
	mb.sphere("w", white, 5.0, 6, 12, MB.T(Vector3(0, 6.5, -14)), Color("fff4dc"))
	mb.sphere("w", white, 1.2, 4, 8, MB.T(Vector3(0, 6.0, -9.2)), Color("ff3b3b"))
	for s in [-1.0, 1.0]:
		mb.sphere("w", white, 0.9, 3, 8, MB.T(Vector3(s * 2.0, 8.0, -9.6)), Color("ffffff"))
		mb.sphere("w", white, 0.4, 3, 6, MB.T(Vector3(s * 2.0, 8.0, -8.8)), Color("1a0b14"))
		mb.sphere("w", white, 2.0, 4, 8, MB.T(Vector3(s * 4.8, 8.6, -12)), Color("ff8c2e"))
	mb.box("w", white, Vector3(5.0, 0.8, 0.5), MB.T(Vector3(0, 3.6, -9.4), Vector3(0, 0, 0.1)), Color("8a0f1a"))
	_mi(mb)
	for k in 4:
		var b := _n(Vector3(-12 + k * 8, 1.5, 9.0))
		var bm := MB.new()
		bm.sphere("w", white, 1.4, 4, 8, MB.T(), [Color("b48cff"), Color("6fe3a5"), Color("ffd23f"), Color("ff5fa2")][k], Vector3(1, 1.3, 1))
		_mi(bm, b)
		bob.append([b, "bounce", 0.6, k * 0.8])
	_lamp(Vector3(0, 9, 3), Color("fff0f6"), 1.3, 30.0)
	_lamp(Vector3(-10, 5, -6), Color("ff6ad5"), 1.4, 12.0)
	_lamp(Vector3(10, 5, -6), Color("6af0ff"), 1.4, 12.0)


func _aquarium() -> void:
	var mb := MB.new()
	_shell(mb, Color("1e3a5a"), Color("234468"), Color("0e2a44"))
	_mi(mb)
	# giant tanks of water along the walls and an arched glass tunnel overhead
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.2, 0.7, 0.95, 0.35)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.05
	water.metallic_specular = 0.9
	for tank in [[Vector3(0, 4.5, -12), Vector3(30, 9, 3)], [Vector3(-14.5, 4.5, 0), Vector3(3, 9, 22)], [Vector3(14.5, 4.5, 0), Vector3(3, 9, 22)]]:
		var bm := BoxMesh.new()
		bm.size = tank[1]
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = water
		mi.position = tank[0]
		add_child(mi)
	var frame := MB.new()
	for k in 7:
		frame.ring("w", white, 7.5, 0.2, 16, MB.T(Vector3(0, 0, -9 + k * 3), Vector3(PI / 2, 0, 0)), Color("c9d1d9"))
	_mi(frame)
	# mechanical fish swimming round the tanks
	for k in 6:
		var f := _n(Vector3(0, 0, 0))
		var fm := MB.new()
		fm.sphere("w", white, 0.8, 3, 8, MB.T(Vector3(0, 0, 0)), [Color("ff8c2e"), Color("ffd23f"), Color("ff5fa2")][k % 3], Vector3(0.6, 0.8, 1.6))
		fm.cyl("w", white, 0.0, 0.6, 0.8, 4, MB.T(Vector3(0, 0, -1.4), Vector3(PI / 2, 0, 0)), Color("c9d1d9"))
		_mi(fm, f)
		bob.append([f, "orbit", 0.25 + k * 0.05, k * 1.1, Vector3(0, 3 + k * 0.8, -12 if k % 2 == 0 else 0), 13.0 if k % 2 == 0 else 14.0])
	_lamp(Vector3(0, 8, 0), Color("80d0ff"), 1.4, 30.0)
	_lamp(Vector3(0, 3, -12), Color("40a0ff"), 1.6, 14.0)


func _locker() -> void:
	var mb := MB.new()
	_shell(mb, Color("d8e8f0"), Color("c8dce6"), Color("a8c8d8"))
	# freezer doors, rails of hanging carcasses, frost on everything
	for k in 3:
		mb.box("w", white, Vector3(6.0, 8.0, 0.6), MB.T(Vector3(-10 + k * 10, 3.6, -13.4)), Color("c9d1d9"))
		mb.box("w", white, Vector3(0.4, 2.0, 0.4), MB.T(Vector3(-8 + k * 10, 3.6, -13.0)), Color("6a7480"))
	for row in [-7.0, 7.0]:
		mb.box("w", white, Vector3(30, 0.3, 0.3), MB.T(Vector3(0, 10.5, row)), Color("8a96a4"))
	_mi(mb)
	for row in [-7.0, 7.0]:
		for k in 7:
			var m := _n(Vector3(-13 + k * 4.3, 10.4, row))
			var mm := MB.new()
			mm.box("w", white, Vector3(0.08, 1.2, 0.08), MB.T(Vector3(0, -0.6, 0)), Color("c9d1d9"))
			mm.sphere("w", white, 1.0, 4, 8, MB.T(Vector3(0, -2.6, 0)), Color("c0505a"), Vector3(0.8, 1.8, 0.6))
			mm.sphere("w", white, 0.7, 3, 6, MB.T(Vector3(0, -2.4, 0.1)), Color("f0e0e0"), Vector3(0.7, 1.2, 0.5))
			_mi(mm, m)
			bob.append([m, "swing", 0.08, k * 0.9 + row])
	_lamp(Vector3(0, 9, 2), Color("bfe4ff"), 1.3, 30.0)
	_lamp(Vector3(0, 4, -12), Color("9fd8ff"), 1.2, 12.0)


func _carnival() -> void:
	var mb := MB.new()
	_shell(mb, Color("2a6a3a"), Color("2f7a42"), Color("1a1a3a"))
	# booths, bunting, a ferris wheel and carousel behind the play area, a strip of coaster
	for k in 4:
		var x := -12 + k * 8
		mb.box("w", white, Vector3(4.0, 3.0, 2.4), MB.T(Vector3(x, 1.5, -11.5)), [Color("ff3b3b"), Color("ffd23f"), Color("2ec4c6"), Color("b48cff")][k])
		for j in 6:
			mb.box("w", white, Vector3(0.66, 0.1, 2.8), MB.T(Vector3(x - 1.65 + j * 0.66, 3.3, -11.2), Vector3(-0.3, 0, 0)), Color("ffffff") if j % 2 == 0 else Color("ff3b3b"))
	for k in 20:
		mb.cyl("w", white, 0.0, 0.35, 0.6, 3, MB.T(Vector3(-14 + k * 1.5, 7.5 - absf(sin(k * 0.6)) * 0.6, 8.0), Vector3(PI, 0, 0)), [Color("ff5fa2"), Color("ffd23f"), Color("2ec4c6")][k % 3])
	_mi(mb)
	var wheel := _n(Vector3(13, 8, -10))
	var wm := MB.new()
	wm.ring("w", white, 5.0, 0.25, 20, MB.T(), Color("ffd23f"))
	for k in 10:
		var a := TAU * k / 10.0
		wm.box("w", white, Vector3(0.15, 5.0, 0.15), MB.T(Vector3(cos(a), sin(a), 0) * 2.5, Vector3(0, 0, a + PI / 2)), Color("ffffff"))
		wm.box("w", white, Vector3(1.1, 1.0, 1.1), MB.T(Vector3(cos(a), sin(a), 0) * 5.0), [Color("ff5fa2"), Color("2ec4c6"), Color("6fe3a5")][k % 3])
	_mi(wm, wheel)
	spin.append([wheel, Vector3.BACK, 0.25])
	var lamps := MB.new()
	for k in 14:
		lamps.sphere("w", glow, 0.2, 2, 5, MB.T(Vector3(-14 + k * 2.2, 7.0, 8.0)), [Color("ffd23f"), Color("ff5fa2")][k % 2])
	_mi(lamps)
	_lamp(Vector3(0, 9, 3), Color("ffe0b0"), 1.3, 30.0)
	_lamp(Vector3(13, 8, -8), Color("ff6ad5"), 1.4, 12.0)


func _hospital() -> void:
	var mb := MB.new()
	_shell(mb, Color("e8f4ee"), Color("d8ece2"), Color("bfe0d0"))
	# beds with curtains down the sides, a corridor of doors behind, operating lamps overhead
	for s in [-1.0, 1.0]:
		for k in 3:
			var at := Vector3(s * 13.0, 0, -6 + k * 6)
			mb.box("w", white, Vector3(2.4, 0.9, 4.0), MB.T(at + Vector3(0, 0.8, 0)), Color("ffffff"))
			mb.box("w", white, Vector3(2.4, 0.4, 1.0), MB.T(at + Vector3(0, 1.4, -1.5)), Color("bfe9ff"))
			mb.box("w", white, Vector3(0.1, 6.0, 4.6), MB.T(at + Vector3(-s * 1.6, 3.0, 0)), Color("8fd9c0"))
	for k in 6:
		mb.box("w", white, Vector3(2.6, 6.0, 0.3), MB.T(Vector3(-12.5 + k * 5, 3.0, -13.6)), Color("6fe3a5"))
		mb.box("w", white, Vector3(1.0, 0.6, 0.1), MB.T(Vector3(-12.5 + k * 5, 6.6, -13.4)), Color("1a0b14"))
	_mi(mb)
	for x in [-5.0, 5.0]:
		var lamp := MB.new()
		lamp.cyl("w", white, 0.1, 0.1, 3.0, 4, MB.T(Vector3(x, 10.5, 0)), Color("c9d1d9"))
		lamp.cyl("w", glow, 1.6, 2.0, 0.6, 12, MB.T(Vector3(x, 8.8, 0)), Color("f8fff8"))
		_mi(lamp)
		_lamp(Vector3(x, 8.0, 0), Color("f8fff8"), 2.0, 16.0)


func _stage() -> void:
	var mb := MB.new()
	_shell(mb, Color("2a1a3a"), Color("3a2050"), Color("1a0b24"))
	# the stage itself (the play area sits on it), steps, a scoreboard, audience seats, curtains
	mb.box("w", white, Vector3(24, 0.6, 18), MB.T(Vector3(0, -0.45, 0)), Color("ff5fa2"))
	mb.box("w", white, Vector3(24.4, 0.15, 18.4), MB.T(Vector3(0, -0.12, 0)), Color("e0b020"))
	for s in [-1.0, 1.0]:
		mb.box("w", white, Vector3(4.0, 11, 0.6), MB.T(Vector3(s * 14.5, 5.0, -10)), Color("b0102a"))
	mb.box("w", white, Vector3(14, 4.0, 0.6), MB.T(Vector3(0, 8.0, -13.4)), Color("1a0b14"))
	for k in 3:
		for j in 10:
			mb.box("w", white, Vector3(1.6, 1.0, 1.2), MB.T(Vector3(-13 + j * 2.9, 0.4 + k * 1.0, 11.5 + k * 1.4)), Color("8e5cf0"))
	_mi(mb)
	var bulbs := MB.new()
	for k in 20:
		bulbs.sphere("w", glow, 0.22, 2, 5, MB.T(Vector3(-6.5 + (k % 10) * 1.45, 6.2 if k < 10 else 9.8, -13.0)), Color("ffd23f"))
	_mi(bulbs)
	for k in 4:
		var sp := SpotLight3D.new()
		sp.light_color = [Color("ff6ad5"), Color("6af0ff"), Color("ffd23f"), Color("ffffff")][k]
		sp.light_energy = 1.6
		sp.spot_range = 30.0
		sp.spot_angle = 22.0
		sp.position = Vector3(-12 + k * 8, 11, 8)
		add_child(sp)
		bob.append([sp, "search", 0.5, k * 1.4])
	_lamp(Vector3(0, 9, 3), Color("ffe8ff"), 1.0, 30.0)


func _impossible() -> void:
	var mb := MB.new()
	_shell(mb, Color("f4e8ff"), Color("e0ccff"), Color("ffe0f0"))
	# a room on the ceiling, stairs that go nowhere, a door in mid-air, furniture upside down
	mb.box("w", white, Vector3(30, 0.3, 26), MB.T(Vector3(0, 11.5, 0)), Color("ffd6e8"))
	mb.box("w", white, Vector3(4.0, 1.0, 2.0), MB.T(Vector3(-6, 10.6, -4)), Color("8a5a3a"))
	for k in 4:
		mb.box("w", white, Vector3(0.3, 0.9, 0.3), MB.T(Vector3(-7.8 + (k % 2) * 3.6, 9.7, -4.8 + (k / 2) * 1.6)), Color("6a4a2a"))
	for k in 12:
		mb.box("w", white, Vector3(3.0, 0.6, 1.2), MB.T(Vector3(11 - k * 0.3, k * 0.7, -12 + k * 0.9), Vector3(0, 0.4, 0)), Color("b48cff"))
	mb.box("w", white, Vector3(2.6, 4.6, 0.3), MB.T(Vector3(-12, 6.0, -8), Vector3(0, 0.5, 0.3)), Color("8a5a3a"))
	_mi(mb)
	var room := _n(Vector3(9, 6, -6))
	var rm := MB.new()
	rm.box("w", white, Vector3(4, 0.2, 4), MB.T(), Color("6fe3a5"))
	rm.box("w", white, Vector3(4, 3, 0.2), MB.T(Vector3(0, 1.5, -2)), Color("ffd23f"))
	rm.box("w", white, Vector3(1.6, 1.0, 0.8), MB.T(Vector3(0, 0.6, 0)), Color("ff5fa2"))
	_mi(rm, room)
	spin.append([room, Vector3(0.3, 1, 0.2).normalized(), 0.3])
	_lamp(Vector3(0, 9, 3), Color("fff0ff"), 1.3, 30.0)
	_lamp(Vector3(9, 6, -6), Color("b0ffd0"), 1.2, 10.0)


func _process(delta: float) -> void:
	_t += delta
	for sp in spin:
		(sp[0] as Node3D).rotate(sp[1], float(sp[2]) * delta)
	for b in bob:
		var n: Node3D = b[0]
		var ph := _t * float(b[2]) * TAU + float(b[3])
		match str(b[1]):
			"swing":
				n.rotation.z = sin(ph) * 0.3
			"yaw":
				n.rotation.y = sin(ph) * 1.0
			"bounce":
				n.position.y = 1.5 + absf(sin(ph)) * 1.2
			"orbit":
				var c: Vector3 = b[4]
				var r: float = b[5]
				n.position = c + Vector3(sin(ph * 0.3) * r, sin(ph) * 0.4, cos(ph * 0.3) * 1.0)
				n.rotation.y = ph * 0.3 + PI / 2
			"search":
				(n as Node3D).rotation = Vector3(-1.0 + sin(ph) * 0.2, sin(ph * 0.7) * 0.6, 0)
