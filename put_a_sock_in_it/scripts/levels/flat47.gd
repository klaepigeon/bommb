extends Level
## Level 1: Flat 47, Building 14, Kerzhansk, 1996.
##
## Kurt knocks; Marta's sister asked him to look in on her. He goes in. The flat is full of
## cardboard boxes and drawings of boxes inside boxes; the windows are papered over with them.
## Marta is in her armchair in the corner of the living room, and the coral has grown out of her
## and through the chair into the floor. She is alive. She asks about the boxes. She takes hold of
## him and throws him across the room, into the dark.
##
## He comes to on the living room floor without his name, and his left hand is a sock puppet,
## and the puppet is talking. The front door is shut and won't give: something outside holds it.
## Behind the bedroom wardrobe there's a hole in the wall, fleshy, running with blue goo. Socko
## smells something in the kitchen (a pistol, in a drawer). The balcony has been replaced by a
## sticky note that says "outside". The only way on is into the hole.
##
## Plan (metres; x east, z south; the flat is x 0..10, z 0..8; the landing is south of z = 8):
##   hall x0-3.2 z5-8 · bathroom x0-1.6 z2.8-5 · corridor x1.6-3.2 z2.8-5 · kitchen x0-3.2 z0-2.8
##   living room x3.2-10 z3.4-8 · box room x3.2-6 z0-3.4 · bedroom x6-10 z0-3.4 · balcony x10-11.4

const H := 2.7
var marta: MartaBody
var marta_spot: Hotspot
var hole_spot: Hotspot
var front_door: Door
var balcony_door: Door
var wardrobe: Wardrobe
var gun_drawer: Drawer
var goo_seep: MeshInstance3D
var hole_parts: Node3D
var goo_spurt: CPUParticles3D
var landing_bulb: OmniLight3D
var living_lamp: OmniLight3D
var sticky: Node3D
var _seen_marta := false
var _woke := false
var _flicker_t := 0.0

const MARTA_POS := Vector3(8.75, 0, 4.25)
const HOLE := Vector3(8.4, 0, 0.0)

# ------------------------------------------------------------------ the place
func build() -> void:
	var wall := Tex.mat("wallpaper"); var wall_bed := Tex.mat("wallpaper_bed")
	var plaster := Tex.mat("plaster", 0.7); var tiles := Tex.mat("tiles", 2.0)
	# floors and ceilings
	Build.room(world, 0, 5, 3.2, 8, Tex.mat("parquet", 1.2), plaster, H)
	Build.room(world, 0, 2.8, 1.6, 5, tiles, plaster, H)
	Build.room(world, 1.6, 2.8, 3.2, 5, Tex.mat("lino", 1.5), plaster, H)
	Build.room(world, 0, 0, 3.2, 2.8, Tex.mat("lino", 1.5), plaster, H)
	Build.room(world, 3.2, 3.4, 10, 8, Tex.mat("parquet", 1.2), plaster, H)
	Build.room(world, 3.2, 0, 6, 3.4, Tex.mat("parquet", 1.2), plaster, H)
	Build.room(world, 6, 0, 10, 3.4, Tex.mat("parquet", 1.2), plaster, H)
	# outer walls
	Build.wall(world, Vector2(-0.06, 0), Vector2(10.06, 0), wall, [{"at": HOLE.x + 0.06, "w": 1.0, "bottom": 0.0, "top": 1.15}], H, 0.15)
	Build.wall(world, Vector2(-0.06, 8), Vector2(10.06, 8), wall, [{"at": 1.96, "w": 0.95}, {"at": 6.06, "w": 1.1, "bottom": 0.9, "top": 2.0}, {"at": 8.56, "w": 1.1, "bottom": 0.9, "top": 2.0}], H, 0.15)
	Build.wall(world, Vector2(0, 0), Vector2(0, 8), wall, [{"at": 1.4, "w": 0.9, "bottom": 0.9, "top": 2.0}], H, 0.15)
	Build.wall(world, Vector2(10, 0), Vector2(10, 8), wall_bed, [{"at": 1.7, "w": 1.0, "bottom": 0.9, "top": 2.0}, {"at": 6.0, "w": 0.85}], H, 0.15)
	# inner walls
	Build.wall(world, Vector2(3.2, 3.4), Vector2(3.2, 8), wall, [{"at": 3.2, "w": 1.3, "top": 2.2}], H)
	Build.wall(world, Vector2(0, 5), Vector2(3.2, 5), wall, [{"at": 0.8, "w": 0.75}, {"at": 2.4, "w": 0.85}], H)
	Build.wall(world, Vector2(1.6, 2.8), Vector2(1.6, 5), tiles, [], H)
	Build.wall(world, Vector2(0, 2.8), Vector2(3.2, 2.8), wall, [{"at": 2.4, "w": 0.9, "top": 2.1}], H)
	Build.wall(world, Vector2(3.2, 0), Vector2(3.2, 3.4), wall, [], H)
	Build.wall(world, Vector2(3.2, 3.4), Vector2(10, 3.4), wall, [{"at": 1.4, "w": 0.8}, {"at": 4.0, "w": 0.85}], H)
	Build.wall(world, Vector2(6, 0), Vector2(6, 3.4), wall_bed, [], H)
	_landing()
	_doors()
	_windows()
	_hall()
	_kitchen()
	_bathroom()
	_living()
	_box_room()
	_bedroom()
	_balcony()
	_lights()
	player.position = Vector3(1.96, 0, 9.4)
	player.set_view(0.0, -0.05)
	socko.points = {"door": Vector3(1.96, 1.2, 8.0), "hole": HOLE + Vector3(0, 0.5, 0), "gun": gun_drawer, "wardrobe": wardrobe}

func _landing() -> void:
	var sw := Tex.mat("stairwell", 0.5)
	# the landing side of the flat's front wall is the stairwell's paint, not her wallpaper
	Build.wall(world, Vector2(-1.2, 8.085), Vector2(5.2, 8.085), sw, [{"at": 3.16, "w": 0.95}], 2.9, 0.01)
	Build.room(world, -1.2, 8.08, 5.2, 10.8, Tex.mat("concrete", 1.5), Tex.mat("plaster", 0.7), 2.9)
	Build.wall(world, Vector2(-1.2, 10.8), Vector2(5.2, 10.8), sw, [], 2.9)
	Build.wall(world, Vector2(-1.2, 8.0), Vector2(-1.2, 10.8), sw, [{"at": 1.4, "w": 0.95}], 2.9)
	Build.wall(world, Vector2(5.2, 8.0), Vector2(5.2, 10.8), sw, [{"at": 1.4, "w": 0.95}], 2.9)
	# the neighbours' doors: 46 and 48, both padded, both shut
	for spec in [[Vector3(-1.13, 0, 9.4 - 0.475), PI * 0.5, "46"], [Vector3(5.13, 0, 9.4 + 0.475), -PI * 0.5, "48"]]:
		var d := Door.new(); d.material = Tex.mat("door_padded", 2.0); d.width = 0.95; d.locked = true
		d.name_text = "door"; world.add_child(d); d.position = spec[0]; d.rotation.y = spec[1]
		var num := Label3D.new(); num.text = spec[2]; num.font_size = 48; num.pixel_size = 0.002; num.modulate = Color("c8b878")
		d.panel.add_child(num); num.position = Vector3(0.47, 1.62, 0.04)
	# the stair down, behind a rail
	Build.box(world, Vector3(2.0, 0.5, 10.75), Vector3(2.6, 1.0, 0.06), Tex.mat("metal"))
	Build.box(world, Vector3(4.6, 0.02, 10.3), Vector3(1.1, 0.04, 0.9), Tex.mat("concrete", 2.0))

func _door(pos: Vector3, rot: float, w: float, mat: Material, open_angle: float, name_text := "door") -> Door:
	var d := Door.new(); d.material = mat; d.width = w; d.open_angle = open_angle; d.name_text = name_text
	world.add_child(d); d.position = pos; d.rotation.y = rot
	return d

func _doors() -> void:
	front_door = _door(Vector3(1.96 - 0.475, 0, 8.0), 0.0, 0.95, Tex.mat("door_padded", 2.0), 1.65, "door")
	var num := Label3D.new(); num.text = "47"; num.font_size = 48; num.pixel_size = 0.002; num.modulate = Color("c8b878")
	front_door.panel.add_child(num); num.position = Vector3(0.47, 1.62, 0.035)
	_door(Vector3(0.8 - 0.375, 0, 5.0), 0.0, 0.75, Tex.mat("wood_light", 2.0), -1.5, "bathroom door")
	_door(Vector3(2.4 - 0.425, 0, 5.0), 0.0, 0.85, Tex.mat("wood_light", 2.0), -1.5)
	_door(Vector3(3.2 + 1.4 - 0.4, 0, 3.4), 0.0, 0.8, Tex.mat("wood_light", 2.0), 1.5)
	_door(Vector3(3.2 + 4.0 - 0.425, 0, 3.4), 0.0, 0.85, Tex.mat("wood_light", 2.0), 1.5, "bedroom door")
	balcony_door = _door(Vector3(10.0, 0, 6.0 + 0.425), PI * 0.5, 0.85, Tex.mat("wood_light", 2.0), -1.5, "balcony door")
	balcony_door.locked = true
	front_door.tried.connect(_on_front_door_tried)

## Every window is papered over from inside: newspaper, and over it her drawings of boxes.
func _windows() -> void:
	var paper := Tex.mat("paper_boxes", 1.4); var news := Tex.mat("newspaper", 2.0)
	for spec in [[Vector3(6.06, 1.45, 7.94), Vector3(1.1, 1.1, 0.02)], [Vector3(8.56, 1.45, 7.94), Vector3(1.1, 1.1, 0.02)],
			[Vector3(0.06, 1.45, 1.4), Vector3(0.02, 1.1, 0.9)], [Vector3(9.94, 1.45, 1.7), Vector3(0.02, 1.1, 1.0)]]:
		Build.box(world, spec[0], spec[1], news)
		var inner: Vector3 = spec[1] * Vector3(0.8, 0.75, 1.0)
		var off := Vector3(0, 0.05, -0.012) if spec[1].z < 0.05 else Vector3(0.012 * (1 if spec[0].x < 5 else -1), 0.05, 0)
		Build.box(world, spec[0] + off, inner, paper, false)

func _cardboard(pos: Vector3, size: Vector3, rot := 0.0, loose := false) -> Node3D:
	if loose:
		return Prop.make(world, pos, size, Tex.mat("cardboard", 3.0), "box", 0.6, 0.3)
	return Build.box(world, pos, size, Tex.mat("cardboard", 3.0), true, rot)

## Drawings of boxes pinned to a wall: sheets of paper, a few askew.
func _drawings(at: Vector3, normal_axis: String, count: int, spread: float, seed: int) -> void:
	var r := RandomNumberGenerator.new(); r.seed = seed
	for i in count:
		var p := at + (Vector3(r.randf_range(-spread, spread), r.randf_range(-0.35, 0.45), 0) if normal_axis == "z" else Vector3(0, r.randf_range(-0.35, 0.45), r.randf_range(-spread, spread)))
		var size := Vector3(0.21, 0.29, 0.004) if normal_axis == "z" else Vector3(0.004, 0.29, 0.21)
		var mi := Build.box(world, p, size, Tex.mat("paper_boxes", 3.0 + r.randf()), false)
		mi.rotation = Vector3(0, 0, r.randf_range(-0.15, 0.15)) if normal_axis == "z" else Vector3(r.randf_range(-0.15, 0.15), 0, 0)

func _hall() -> void:
	# coat hooks with a woman's coats, a shoe rack, the telephone table, a mirror
	Build.box(world, Vector3(0.09, 1.7, 6.6), Vector3(0.04, 0.06, 1.0), Tex.mat("wood", 2.0))
	for i in 3:
		Build.box(world, Vector3(0.2, 1.25, 6.25 + i * 0.32), Vector3(0.18, 0.85, 0.28), Tex.mat("fabric_green" if i != 1 else "cloth_red", 3.0), false)
	Build.box(world, Vector3(0.25, 0.15, 7.4), Vector3(0.35, 0.3, 0.8), Tex.mat("wood", 2.0))
	Build.box(world, Vector3(2.9, 0.4, 5.6), Vector3(0.45, 0.8, 0.45), Tex.mat("wood", 2.0))
	Build.box(world, Vector3(2.9, 0.86, 5.6), Vector3(0.22, 0.1, 0.2), Tex.mat("enamel", 4.0, {"tint": Color(0.5, 0.15, 0.12)}))
	Build.box(world, Vector3(3.12, 1.5, 7.0), Vector3(0.02, 0.7, 0.5), Tex.mat("metal", 1.0, {"tint": Color(0.75, 0.8, 0.85), "rough": 0.15}), false)
	# boxes even here, along the wall, and her drawings
	_cardboard(Vector3(2.85, 0.25, 6.4), Vector3(0.5, 0.5, 0.5))
	_cardboard(Vector3(2.85, 0.68, 6.45), Vector3(0.4, 0.36, 0.4), 0.3)
	_cardboard(Vector3(1.2, 0.2, 5.4), Vector3(0.4, 0.4, 0.4), 0.0, true)
	_drawings(Vector3(1.6, 1.5, 5.07), "z", 6, 0.7, 3)

func _kitchen() -> void:
	var counter := Tex.mat("wood_light", 2.0); var top := Tex.mat("enamel", 3.0, {"tint": Color(0.75, 0.72, 0.62)})
	Build.box(world, Vector3(1.4, 0.43, 0.32), Vector3(2.6, 0.86, 0.6), counter)
	Build.box(world, Vector3(1.4, 0.88, 0.32), Vector3(2.62, 0.04, 0.62), top)
	Build.box(world, Vector3(0.7, 0.86, 0.32), Vector3(0.5, 0.06, 0.4), Tex.mat("metal"), false)          # sink
	Build.box(world, Vector3(2.75, 0.45, 2.3), Vector3(0.6, 0.9, 0.6), Tex.mat("enamel", 3.0))             # gas stove
	for i in 4:
		Build.box(world, Vector3(2.6 + (i % 2) * 0.3, 0.91, 2.15 + (i / 2) * 0.3), Vector3(0.14, 0.02, 0.14), Tex.mat("gunmetal"), false)
	Build.box(world, Vector3(0.35, 0.85, 2.4), Vector3(0.6, 1.7, 0.6), Tex.mat("enamel", 3.0))             # ZIL fridge
	Build.box(world, Vector3(1.8, 0.38, 1.5), Vector3(0.9, 0.04, 0.7), Tex.mat("cloth_red", 4.0))           # table, oilcloth
	Build.box(world, Vector3(1.8, 0.18, 1.5), Vector3(0.06, 0.36, 0.06), Tex.mat("wood"))
	for x in [1.3, 2.3]:
		Build.box(world, Vector3(x, 0.22, 1.5), Vector3(0.32, 0.44, 0.32), Tex.mat("wood_light", 2.0))
	# the drawer: Socko smells something in it
	gun_drawer = Drawer.new(); gun_drawer.size = Vector3(0.55, 0.16, 0.5)
	world.add_child(gun_drawer); gun_drawer.position = Vector3(2.2, 0.72, 0.31)
	var gun := Pickup.new(); gun.item = "pistol"; gun.amount = 4; gun.label = "pistol"
	gun_drawer.add_child(gun); gun.position = Vector3(0, 0.1, 0.02)
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(0.25, 0.05, 0.15); cs.shape = sh; gun.add_child(cs)
	for spec in [[Vector3(0, 0, 0), Vector3(0.17, 0.03, 0.03)], [Vector3(0.06, -0.005, 0.03), Vector3(0.04, 0.025, 0.07)]]:
		var mi := MeshInstance3D.new(); mi.mesh = Build.box_mesh(spec[1]); mi.material_override = Tex.mat("gunmetal"); mi.position = spec[0]; gun.add_child(mi)
	gun.taken.connect(_on_gun_taken)
	# things to pick up and throw
	Prop.make(world, Vector3(1.6, 0.98, 0.3), Vector3(0.08, 0.2, 0.08), Tex.mat("glass", 1.0, {"tint": Color(0.4, 0.6, 0.4)}), "bottle", 0.4, 0.9)
	Prop.make(world, Vector3(2.65, 0.98, 2.15), Vector3(0.25, 0.08, 0.25), Tex.mat("gunmetal"), "pan", 0.9, 0.9)
	Prop.make(world, Vector3(1.9, 0.45, 1.4), Vector3(0.08, 0.1, 0.08), Tex.mat("enamel", 4.0), "cup", 0.2, 0.7)
	_cardboard(Vector3(0.4, 0.2, 1.0), Vector3(0.4, 0.4, 0.4), 0.2)

func _bathroom() -> void:
	Build.box(world, Vector3(0.38, 0.28, 3.6), Vector3(0.7, 0.56, 1.5), Tex.mat("enamel", 3.0))   # tub
	Build.box(world, Vector3(0.38, 0.5, 3.6), Vector3(0.56, 0.06, 1.36), Tex.mat("mould", 3.0), false)  # what's in it
	Build.box(world, Vector3(1.3, 0.2, 4.6), Vector3(0.4, 0.4, 0.5), Tex.mat("enamel", 3.0))      # toilet
	Build.box(world, Vector3(1.4, 0.8, 3.2), Vector3(0.35, 0.12, 0.45), Tex.mat("enamel", 3.0))   # basin
	Build.organic(world, func(st):
		var r := RandomNumberGenerator.new(); r.seed = 9
		for i in 18: MeshKit.lump(st, Vector3(r.randf_range(0.05, 1.5), r.randf_range(1.6, 2.65), 2.85 + r.randf() * 0.05), r.randf_range(0.04, 0.12), r), Tex.mat("mould", 4.0))

func _living() -> void:
	# the rug, the wall unit, the sofa, the television
	Build.box(world, Vector3(6.4, 0.005, 5.8), Vector3(3.0, 0.01, 2.2), Tex.mat("rug", 0.33), false)
	Build.box(world, Vector3(6.6, 1.05, 3.68), Vector3(3.2, 2.1, 0.45), Tex.mat("wood", 2.0))
	for i in 4:
		_cardboard(Vector3(5.4 + i * 0.8, 2.3, 3.7), Vector3(0.5, 0.36, 0.4), i * 0.2)
	Build.box(world, Vector3(3.7, 0.25, 5.8), Vector3(0.8, 0.5, 1.9), Tex.mat("fabric", 3.0))
	Build.box(world, Vector3(3.45, 0.6, 5.8), Vector3(0.3, 0.7, 1.9), Tex.mat("fabric", 3.0))
	Build.box(world, Vector3(9.4, 0.3, 7.3), Vector3(0.8, 0.6, 0.5), Tex.mat("wood", 2.0))
	Build.box(world, Vector3(9.4, 0.85, 7.3), Vector3(0.6, 0.5, 0.5), Tex.mat("gunmetal"))         # TV
	Build.box(world, Vector3(9.4, 0.87, 7.04), Vector3(0.44, 0.34, 0.02), Tex.mat("glass", 1.0, {"emission": Vector3(0.3, 0.35, 0.4)}), false)
	Build.box(world, Vector3(6.4, 0.22, 5.8), Vector3(1.0, 0.44, 0.6), Tex.mat("wood_light", 2.0))  # coffee table
	_drawings(Vector3(6.4, 0.45, 5.8), "z", 0, 0.0, 1)
	for i in 5:
		var mi := Build.box(world, Vector3(6.0 + i * 0.18, 0.445, 5.7 + (i % 2) * 0.15), Vector3(0.21, 0.004, 0.29), Tex.mat("paper_boxes", 3.0), false)
		mi.rotation.y = i * 0.4
	# boxes, everywhere, and boxes inside the open ones
	var r := RandomNumberGenerator.new(); r.seed = 47
	for spec in [[4.2, 7.4], [4.8, 7.5], [5.5, 4.2], [7.6, 7.5], [4.3, 4.2], [8.0, 5.9]]:
		var s := r.randf_range(0.35, 0.6)
		_cardboard(Vector3(spec[0], s * 0.5, spec[1]), Vector3(s, s, s), r.randf_range(-0.4, 0.4))
	for i in 3:
		_cardboard(Vector3(5.2 + i * 0.7, 0.2, 6.9), Vector3(0.3, 0.3, 0.3), 0.0, true)
	_drawings(Vector3(3.27, 1.4, 4.6), "x", 7, 0.8, 5)
	_drawings(Vector3(9.93, 1.4, 4.6), "x", 9, 0.9, 6)
	_drawings(Vector3(6.6, 1.5, 7.93), "z", 5, 1.5, 7)
	# Marta, in her armchair in the corner, facing the room
	var chair := Node3D.new(); world.add_child(chair); chair.position = MARTA_POS; chair.rotation.y = PI * 0.5
	var cm := Tex.mat("fabric", 3.0)
	for spec in [[Vector3(0, 0.22, 0.05), Vector3(0.8, 0.44, 0.7)], [Vector3(0, 0.7, 0.36), Vector3(0.8, 0.9, 0.16)],
			[Vector3(-0.36, 0.55, 0.05), Vector3(0.14, 0.3, 0.7)], [Vector3(0.36, 0.55, 0.05), Vector3(0.14, 0.3, 0.7)]]:
		var mi := MeshInstance3D.new(); mi.mesh = Build.box_mesh(spec[1]); mi.material_override = cm; mi.position = spec[0]; chair.add_child(mi)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(0.9, 1.2, 0.8); cs.shape = sh; cs.position = Vector3(0, 0.6, 0.05); sb.add_child(cs); chair.add_child(sb)
	marta = MartaBody.new("seated"); chair.add_child(marta); marta.position = Vector3(0, 0.0, -0.02)
	marta.snap = 3.0
	marta_spot = Hotspot.make(world, MARTA_POS + Vector3(-0.35, 0.9, 0), Vector3(0.6, 1.2, 0.8), "", _investigate)
	marta_spot.enabled = false
	# the growth went into the wall behind her too
	Build.organic(world, func(st):
		var g := RandomNumberGenerator.new(); g.seed = 12
		for i in 8: MeshKit.coral(st, Vector3(9.92, g.randf_range(0.3, 1.6), 4.25 + g.randf_range(-0.6, 0.6)), Vector3(-0.6, g.randf_range(-0.3, 0.6), g.randf_range(-0.6, 0.6)), 0.3, 0.03, g, 1)
		for i in 10: MeshKit.lump(st, Vector3(9.95, g.randf_range(0.2, 2.2), 4.25 + g.randf_range(-0.9, 0.9)), g.randf_range(0.06, 0.15), g), Tex.mat("coral", 4.0))
	Build.organic(world, func(st):
		var g := RandomNumberGenerator.new(); g.seed = 13
		for i in 20: MeshKit.lump(st, Vector3(9.95, g.randf_range(0.0, 2.6), 4.25 + g.randf_range(-1.4, 1.4)), g.randf_range(0.04, 0.12), g), Tex.mat("mould", 4.0))

func _box_room() -> void:
	# the box room is nothing but boxes: stacked to the ceiling, boxes inside boxes
	var r := RandomNumberGenerator.new(); r.seed = 70
	for gx in 4:
		for gz in 4:
			var y := 0.0
			for k in r.randi_range(1, 4):
				var s := r.randf_range(0.35, 0.6)
				if (gx == 1 and gz == 3): continue   # a gap by the door to stand in
				_cardboard(Vector3(3.6 + gx * 0.62, y + s * 0.5, 0.45 + gz * 0.72), Vector3(s, s, s), r.randf_range(-0.3, 0.3))
				y += s

func _bedroom() -> void:
	Build.box(world, Vector3(9.0, 0.25, 2.3), Vector3(1.6, 0.5, 2.0), Tex.mat("wood", 2.0))
	Build.box(world, Vector3(9.0, 0.55, 2.3), Vector3(1.5, 0.12, 1.9), Tex.mat("fabric_green", 3.0))
	Build.box(world, Vector3(9.0, 0.8, 3.3), Vector3(1.6, 1.0, 0.08), Tex.mat("wood", 2.0))
	Build.box(world, Vector3(7.9, 0.3, 3.0), Vector3(0.45, 0.6, 0.4), Tex.mat("wood", 2.0))
	Build.box(world, Vector3(9.9, 2.2, 0.12), Vector3(0.12, 0.2, 0.12), Tex.mat("wood_light", 4.0, {"tint": Color(1.2, 1.0, 0.5)}), false)  # an icon in the corner
	_drawings(Vector3(6.07, 1.4, 1.7), "x", 6, 0.9, 9)
	# the wardrobe, against the north wall, over the hole
	wardrobe = Wardrobe.new(); world.add_child(wardrobe)
	wardrobe.position = Vector3(HOLE.x, 0, 0.38); wardrobe.slide = Vector3(-1.4, 0, 0)
	wardrobe.pushed.connect(_on_wardrobe_pushed)
	# blue goo seeping out from under it
	goo_seep = Build.organic(world, func(st): MeshKit.blob(st, Vector3(HOLE.x + 0.1, 0.0, 0.72), Vector3(0.5, 0.012, 0.22), {"bumps": 0.3, "freq": 3.0}), _goo())
	_hole()

func _goo() -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = preload("res://shaders/goo.gdshader"); return m

## The hole behind the wardrobe: a ring of flesh round a ragged gap, and a throat going down into
## the dark beyond the wall, running with blue goo.
func _hole() -> void:
	hole_parts = Node3D.new(); world.add_child(hole_parts)
	var flesh := Tex.mat("flesh", 3.0, {"pulse": 0.012, "double": true})
	Build.organic(hole_parts, func(st):
		var g := RandomNumberGenerator.new(); g.seed = 33
		for i in 22:
			var a := TAU * i / 22.0
			MeshKit.blob(st, Vector3(HOLE.x + cos(a) * 0.55, 0.55 + sin(a) * 0.55, 0.06), Vector3(0.14, 0.14, 0.1) * g.randf_range(0.8, 1.4), {"bumps": 0.3, "seed": float(i)}), flesh)
	Build.organic(hole_parts, func(st):
		var pts := []; var rs := []
		for i in 9:
			var k := i / 8.0
			pts.append(Vector3(HOLE.x + sin(k * 2.0) * 0.3, 0.5 - k * k * 0.6, 0.1 - k * 4.5)); rs.append(0.62 - k * 0.12)
		MeshKit.tube(st, pts, rs, {"sides": 10, "bumps": 0.25, "cap": false}), flesh)
	Build.box(hole_parts, Vector3(HOLE.x, -0.1, -2.0), Vector3(1.6, 0.1, 4.4), Tex.mat("flesh_dark", 2.0))   # what you crawl on
	var l := Build.lamp(hole_parts, Vector3(HOLE.x, 0.4, -1.8), Color("3a6aff"), 1.4, 3.5)
	l.name = "HoleLight"
	# goo coming out of it, in spurts, and the pool it's made on the floor
	Build.organic(hole_parts, func(st):
		MeshKit.tube(st, [Vector3(HOLE.x, 0.08, -0.4), Vector3(HOLE.x + 0.05, 0.05, 0.3), Vector3(HOLE.x + 0.1, 0.01, 0.9)], [0.12, 0.09, 0.15], {"sides": 8, "cap": false})
		MeshKit.blob(st, Vector3(HOLE.x + 0.1, 0.0, 1.0), Vector3(0.8, 0.015, 0.55), {"bumps": 0.3, "freq": 3.0}), _goo())
	goo_spurt = CPUParticles3D.new(); hole_parts.add_child(goo_spurt)
	goo_spurt.position = Vector3(HOLE.x, 0.35, -0.1)
	goo_spurt.amount = 40; goo_spurt.lifetime = 1.1; goo_spurt.emitting = false
	goo_spurt.direction = Vector3(0, 0.5, 1); goo_spurt.spread = 18.0; goo_spurt.initial_velocity_min = 1.4; goo_spurt.initial_velocity_max = 2.6
	goo_spurt.gravity = Vector3(0, -9.8, 0); goo_spurt.scale_amount_min = 0.5; goo_spurt.scale_amount_max = 1.2
	var dm := SphereMesh.new(); dm.radius = 0.025; dm.height = 0.05; dm.radial_segments = 6; dm.rings = 3
	dm.material = _goo(); goo_spurt.mesh = dm
	hole_parts.visible = false
	hole_spot = Hotspot.make(world, HOLE + Vector3(0, 0.55, -0.1), Vector3(0.9, 1.0, 0.4), "", _crawl)
	hole_spot.enabled = false

func _balcony() -> void:
	Build.box(world, Vector3(10.7, -0.08, 5.8), Vector3(1.4, 0.16, 3.2), Tex.mat("concrete", 1.5))
	Build.box(world, Vector3(11.37, 0.5, 5.8), Vector3(0.06, 1.0, 3.2), Tex.mat("metal"))
	Build.box(world, Vector3(10.7, 0.5, 4.23), Vector3(1.4, 1.0, 0.06), Tex.mat("metal"))
	Build.box(world, Vector3(10.7, 0.5, 7.37), Vector3(1.4, 1.0, 0.06), Tex.mat("metal"))
	Build.box(world, Vector3(10.4, 0.15, 7.0), Vector3(0.4, 0.3, 0.4), Tex.mat("cardboard", 3.0))
	Build.box(world, Vector3(10.2, 0.8, 4.4), Vector3(0.08, 1.6, 0.08), Tex.mat("wood_light", 3.0))   # old skis
	# beyond the railing, where the courtyard and the city should be: a sticky note
	sticky = Node3D.new(); world.add_child(sticky); sticky.position = Vector3(13.2, 1.4, 5.8)
	var note := MeshInstance3D.new(); note.mesh = Build.box_mesh(Vector3(0.05, 6.0, 6.0)); note.material_override = Tex.mat("sticky", 1.0, {"emission": Vector3(0.6, 0.55, 0.3)})
	sticky.add_child(note); note.rotation.z = 0.04
	var txt := Label3D.new(); txt.text = "outside"; txt.font_size = 260; txt.pixel_size = 0.006; txt.modulate = Color("1f2a6a")
	txt.outline_size = 0; sticky.add_child(txt); txt.position = Vector3(-0.04, 0.2, 0); txt.rotation.y = -PI * 0.5; txt.rotation.z = 0.04
	var l := Build.lamp(world, Vector3(12.0, 2.0, 5.8), Color("fff2c0"), 1.2, 5.0)
	zone(Vector3(10.7, 1.0, 5.8), Vector3(1.2, 2.0, 2.8), _on_balcony)

func _lights() -> void:
	landing_bulb = Build.lamp(world, Vector3(2.0, 2.7, 9.6), Color("ffe0a0"), 1.3, 6.0)
	Build.box(world, Vector3(2.0, 2.78, 9.6), Vector3(0.08, 0.12, 0.08), Tex.mat("enamel", 1.0, {"emission": Vector3(2.0, 1.8, 1.2)}), false)
	Build.lamp(world, Vector3(1.6, 2.4, 6.5), Color("ffcf90"), 0.7, 5.0)
	Build.lamp(world, Vector3(1.6, 2.2, 1.4), Color("a8b8c8"), 0.45, 4.5)
	Build.lamp(world, Vector3(0.8, 2.2, 3.9), Color("a8c0a0"), 0.25, 3.0)
	Build.lamp(world, Vector3(4.6, 2.2, 1.6), Color("c0a080"), 0.25, 3.5)
	Build.lamp(world, Vector3(7.9, 1.2, 3.0), Color("ffc080"), 0.6, 4.0)
	# her standard lamp, beside her: the brightest thing in the flat, aimed at her
	Build.box(world, Vector3(8.4, 0.75, 3.75), Vector3(0.04, 1.5, 0.04), Tex.mat("metal"), false)
	Build.box(world, Vector3(8.4, 1.55, 3.75), Vector3(0.36, 0.25, 0.36), Tex.mat("fabric", 4.0, {"emission": Vector3(1.2, 0.9, 0.5)}), false)
	living_lamp = Build.lamp(world, Vector3(8.4, 1.5, 3.85), Color("ffb870"), 1.6, 5.5)
	Build.lamp(world, Vector3(5.8, 2.3, 6.4), Color("c8a888"), 0.35, 5.0)

# ------------------------------------------------------------------ the story
func begin() -> void:
	Game.checkpoint()
	Sfx.loop("drone", "drone", -16.0)
	set_cutscene(true)
	player.look_enabled = true      # he can look round the landing while he knocks
	Game.fade(0.0, 3.0)
	await Dialogue.play("knock")
	set_cutscene(false)
	zone(Vector3(1.6, 1.0, 6.9), Vector3(3.0, 2.0, 0.6), func(): Dialogue.play("see_flat"))

func on_event(n: String, _step: Dictionary) -> void:
	match n:
		"knock":
			for i in 3:
				Sfx.play_at("knock", Vector3(1.96, 1.3, 8.0), 0.0, randf_range(0.95, 1.05)); player.shake(0.004, 0.08)
				await get_tree().create_timer(0.36).timeout
		"knock_again":
			for i in 4:
				Sfx.play_at("knock", Vector3(1.96, 1.3, 8.0), 3.0, randf_range(0.9, 1.0)); player.shake(0.006, 0.08)
				await get_tree().create_timer(0.3).timeout
		"marta_stirs":
			Sfx.play_at("marta_breath", marta.head_pos(), -4.0)
			marta.pose.head = marta.pose.head + Vector3(0.25, 0, 0.1)
			marta.pose.sh_l = Vector3(0.9, 0, 0.12)
		"marta_turns":
			marta.snap = 1.6
			marta.face_toward(player.cam.global_position, 1.0)
			marta.pose.jaw = Vector3(0.35, 0, 0)
			Sfx.play_at("click", marta.head_pos(), -6.0, 0.7)
		"grab":
			pass   # _investigate runs the grab once the conversation is over
		"rub_head":
			socko.visible = true; socko.hold = "rub"; socko.emotion = "neutral"
			socko.rig.jaw = 0.0
		"socko_reveal":
			socko.hold = "low"
			player.head_override = 1.0
			player.set_roll(0.0)
			await get_tree().create_timer(0.7).timeout
			player.head_override = -1.0
			socko.look = "kurt"; socko.hold = "face"; socko.emotion = "happy"
		"cross_eyed":
			socko.set_cross_eyed(true)
			await get_tree().create_timer(1.6).timeout
			socko.set_cross_eyed(false)

func _process(delta: float) -> void:
	super(delta)
	# the landing bulb is on its way out
	_flicker_t -= delta
	if _flicker_t <= 0.0:
		_flicker_t = randf_range(0.05, 1.8)
		landing_bulb.light_energy = 1.3 if randf() > 0.2 else randf_range(0.1, 0.6)
	# seeing her
	if not _seen_marta and not _woke and not cutscene and player_sees(marta.head_pos(), 6.5, 0.8):
		_seen_marta = true
		Dialogue.play("see_marta")
		marta_spot.prompt = "Look closer"; marta_spot.enabled = true
	if _woke and socko.visible and not cutscene and not Dialogue.busy and socko.look != "ahead" and socko.look != "gun":
		socko.look = "ahead"

## Kurt kneels to look at her; she talks; she takes hold of him.
func _investigate() -> void:
	marta_spot.enabled = false
	set_cutscene(true)
	Sfx.loop("marta", "marta_breath", -12.0, marta.head_pos())
	var stand := MARTA_POS + Vector3(-1.05, 0, 0.1)
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(player, "global_position", stand, 1.2)
	player.look_toward(marta.head_pos() + Vector3(0, -0.05, 0), 1.2)
	player.crouching = true
	await tw.finished
	await Dialogue.play("investigate_marta")
	await _grab()

func _grab() -> void:
	Sfx.stop_loop("marta")
	# she comes up out of the chair at him: the arm, the face, all at once
	marta.snap = 30.0
	marta.pose.sh_r = Vector3(PI * 0.5 + 0.35, 0, -0.15); marta.pose.el_r = Vector3(0.15, 0, 0)
	marta.pose.sh_l = Vector3(PI * 0.5 + 0.2, 0, 0.2); marta.pose.el_l = Vector3(0.2, 0, 0)
	marta.pose.chest = Vector3(0.25, 0, 0); marta.pose.jaw = Vector3(0.6, 0, 0)
	marta.face_toward(player.cam.global_position, 1.0)
	Sfx.play("gasp", 0.0, 1.05)
	Sfx.play_at("click", marta.head_pos(), 2.0, 0.6)
	var toward := (MARTA_POS - player.global_position) * Vector3(1, 0, 1)
	var tw := create_tween()
	tw.tween_property(player, "global_position", player.global_position + toward.normalized() * 0.45, 0.12)
	player.shake(0.03, 0.6)
	await tw.finished
	await get_tree().create_timer(0.55).timeout
	# and throws him: backwards across the room, end over end, into the far wall
	var start := player.global_position
	var land := Vector3(3.75, 0.0, 5.4)
	var y0 := player.get_yaw(); var p0 := player.get_pitch()
	player.crouching = false
	Sfx.play("thud", -6.0, 1.4)
	var fly := create_tween()
	fly.tween_method(func(k):
		player.global_position = start.lerp(land, k) + Vector3(0, sin(k * PI) * 0.9, 0)
		player.set_view(y0 + k * 0.6, p0 + k * 1.6)
		player.set_roll(k * 1.1), 0.0, 1.0, 0.75).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await fly.finished
	Sfx.play("thud", 4.0, 0.8)
	player.shake(0.06, 0.3)
	await Game.fade(1.0, 0.06)
	await _blackout()

## Dark. His heart. Somewhere, the front door slams. When he comes to, she isn't there.
func _blackout() -> void:
	Sfx.stop_loop("drone")
	for i in 3:
		Sfx.play("heartbeat", -6.0 - i * 3.0); await get_tree().create_timer(1.1).timeout
	front_door.slam(); front_door.blocked = true
	await get_tree().create_timer(1.6).timeout
	for i in 2:
		Sfx.play("heartbeat", -12.0); await get_tree().create_timer(1.3).timeout
	# she's gone. The chair, the coral, broken where she tore herself loose
	marta.visible = false
	marta_spot.enabled = false
	living_lamp.light_energy = 0.8
	balcony_door.locked = false
	wardrobe.pushable = true
	# on the floor, on his back, looking at the ceiling
	player.global_position = Vector3(3.8, 0, 5.3)
	player.head_override = 0.28
	player.set_view(-PI * 0.55, 1.1); player.set_roll(0.35)
	player.crouching = false
	await get_tree().create_timer(0.8).timeout
	Sfx.loop("drone", "drone", -18.0)
	Sfx.loop("goo", "goo_loop", -10.0, HOLE + Vector3(0, 0.3, 0.3))
	Game.fade(0.0, 3.5)
	player.look_toward(Vector3(5.0, 1.6, 5.0), 3.0)
	await get_tree().create_timer(1.6).timeout
	await _wake()

func _wake() -> void:
	await Dialogue.play("wake")
	_woke = true
	Game.set_flag("woke")
	player.head_override = -1.0
	socko.hold = "out"; socko.look = "ahead"; socko.emotion = "neutral"
	set_cutscene(false)
	random_talk = true
	objective("Get out of the flat.")

func _on_front_door_tried(_d: Door) -> void:
	if not _woke or Game.flag("door_tried"): return
	Game.set_flag("door_tried")
	await Dialogue.play("door_locked")
	objective("Find another way out.")
	socko.interest = wardrobe.global_position + Vector3(0, 1.0, 0)   # one eye keeps going to it

func _on_wardrobe_pushed(_w: Wardrobe) -> void:
	goo_seep.visible = false
	hole_parts.visible = true
	socko.interest = null
	Sfx.stop_loop("goo"); Sfx.loop("goo", "goo_loop", -2.0, HOLE + Vector3(0, 0.3, 0.2))
	_spurts()
	set_cutscene(true)
	await player.look_toward(HOLE + Vector3(0, 0.45, 0), 0.9)
	await Dialogue.play("wardrobe_hole")
	set_cutscene(false)
	hole_spot.prompt = "Crawl in"; hole_spot.enabled = true
	if not Game.pistol.have:
		objective("Go where Socko's pointing.")
		socko.look = "gun"
	else:
		objective("The hole in the bedroom wall.")

func _spurts() -> void:
	while is_inside_tree():
		goo_spurt.emitting = true
		Sfx.play_at("squelch", HOLE + Vector3(0, 0.3, 0), -2.0, randf_range(0.8, 1.1))
		await get_tree().create_timer(randf_range(0.4, 0.9)).timeout
		goo_spurt.emitting = false
		await get_tree().create_timer(randf_range(1.5, 4.0)).timeout

func _on_gun_taken(_p: Pickup) -> void:
	socko.look = "ahead"
	socko.gesture("bounce")
	objective("The hole in the bedroom wall." if hole_parts.visible else hud._objective.text)

func _on_balcony() -> void:
	if not _woke:
		return
	set_cutscene(true)
	await player.look_toward(sticky.global_position, 1.0)
	set_cutscene(false)
	Dialogue.play("balcony")

## Kurt gets down and crawls into it. The light goes blue, then there is only the sound of it.
## The next level loads behind the black at the end of this.
func _crawl() -> void:
	hole_spot.enabled = false
	random_talk = false
	set_cutscene(true)
	socko.hold = "low"; socko.look = "ahead"; socko.emotion = "nervous"
	var front := Vector3(HOLE.x, 0, 0.9)
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(player, "global_position", front, 0.9)
	player.look_toward(HOLE + Vector3(0, 0.4, -1.0), 0.9)
	await tw.finished
	player.head_override = 0.45
	await get_tree().create_timer(0.6).timeout
	Sfx.play("crawl", -2.0)
	var in_t := create_tween()
	in_t.tween_property(player, "global_position", Vector3(HOLE.x + 0.1, -0.05, -1.2), 2.6)
	player.look_toward(Vector3(HOLE.x + 0.4, 0.0, -4.0), 2.0)
	await get_tree().create_timer(1.3).timeout
	Sfx.play("crawl", -2.0, 0.9)
	Sfx.play("squelch", 0.0, 0.7)
	await get_tree().create_timer(0.6).timeout
	Game.set_flag("crawled_in")
	var on := create_tween(); on.tween_property(player, "global_position", Vector3(HOLE.x + 0.25, -0.1, -3.4), 3.0)
	Game.change_level("flesh47", {"fade": 1.4})
