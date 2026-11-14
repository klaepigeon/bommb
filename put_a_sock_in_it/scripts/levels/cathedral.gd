extends Level
## Flat 27: the cathedral, the end of Chapter 2 (docs/CATHEDRAL.md).
##
## Through 27's door: a flat's hallway, coats and shoes, and at the end of it a cathedral far
## bigger than the building it's in. A nave of ribbed columns grown with coral, pews down both
## sides and the same pews hanging upside down from the vault with people sitting in them, who
## watch. At the far end, on a dais under a rose window: STIGMATA, the priest who nailed himself
## to his cross, the feet and the right hand; the left hand, free, holding out the last nail.
##
## The nave won't let him get there: walk up it toward the altar and somewhere in the middle it's
## the same bay again (he's moved back two bays, and every bay is the same). Two ways through:
##   the bells    three ropes in the narthex under three windows, MANUS, PEDES, LATUS (hand,
##                feet, side). Rung in the order he nailed himself (his pages say: the feet, then
##                the right hand, the side left open for whoever comes), the loop lets go. Wrong,
##                and the bell clanks dead and it starts again.
##   backwards    over the door: WHOSOEVER TURNETH HIS BACK UPON THE ALTAR SHALL COME UNTO IT.
##                Walk the nave facing the door and it lets you through.
## Then the conversation (data/dialogue/cathedral.json), and what Kurt does: drive the last nail
## (the hammer at his feet: three strikes), pull the nails and take him down, or walk away. The
## door behind the altar is a flat's front door, 27; through it, the chapter ends. What he did is
## kept (flags c27_nailed / c27_freed / c27_left; Socko's obey/defy as ch2_obey_nail / ch2_defy_nail).

const BAY := 12.0               # (the loop's period: two bays of the nave)
const LOOP_FROM := -26.0        # facing the altar past here: back by BAY
const LOOP_OUT := -40.0         # past here (any way): through
const NAVE_END := -56.0
const CROSS_Z := -60.4
const DAIS_Y := 0.6
const VAULT := 17.0
const HANG := 11.6           # where the upside-down pews hang from (their "floor")

var loop_broken := false
var stig: FleshBody
var stig_pose := {}
var _loops_seen := 0
var _bells: Array = []           # rung so far
const BELL_ORDER := ["PEDES", "MANUS", "LATUS"]
var _decided := ""               # "nail" / "free" / "leave" (what he chose in the conversation)
var _done := ""                  # "nailed" / "freed" (what he did)
var _strikes := 0
var _pulled := {}
var _met := false
var _ending := false
var _rose: MeshInstance3D
var _rose_light: OmniLight3D
var _congregation: Array = []
var _nail_l: MeshInstance3D
var _stone: Material
var _bone: Material
var _wood: Material

func build() -> void:
	add_to_group("level")
	_environment()
	_stone = Tex.mat("concrete", 0.6, {"tint": Color(0.5, 0.46, 0.42)})
	_bone = Tex.mat("plaster", 1.0, {"tint": Color(0.68, 0.6, 0.48)})
	_wood = Tex.mat("wood", 1.5, {"tint": Color(0.7, 0.52, 0.4)})
	_hallway()
	_west_wall()
	_nave()
	_vault()
	_apse()
	_stigmata()
	_bell_ropes()
	_pages()
	_restore()
	player.position = Vector3(0, 0, 2.4)
	player.set_view(0.0, 0.0)
	socko.visible = true

func _environment() -> void:
	var e := env.environment
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.008, 0.006, 0.006)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("4a3e34"); e.ambient_light_energy = 0.75
	e.fog_enabled = true; e.fog_light_color = Color("2a1c16"); e.fog_density = 0.035
	e.tonemap_mode = Environment.TONE_MAPPER_ACES; e.tonemap_exposure = 1.15
	e.glow_enabled = true; e.glow_intensity = 0.45; e.glow_hdr_threshold = 1.0
	e.adjustment_enabled = true; e.adjustment_saturation = 0.8; e.adjustment_contrast = 1.12

func _box(at: Vector3, size: Vector3, m: Material, solid := true, rot := 0.0) -> MeshInstance3D:
	return Build.box(world, at, size, m, solid, rot)

# ------------------------------------------------------------------ the flat's hallway
func _hallway() -> void:
	var wp := Tex.mat("wallpaper", 2.0)
	_box(Vector3(0, -0.05, 1.6), Vector3(1.4, 0.1, 3.4), Tex.mat("parquet", 2.0))
	_box(Vector3(0, 2.65, 1.6), Vector3(1.4, 0.1, 3.4), Tex.mat("plaster", 2.0))
	_box(Vector3(-0.7, 1.3, 1.6), Vector3(0.1, 2.6, 3.4), wp)
	_box(Vector3(0.7, 1.3, 1.6), Vector3(0.1, 2.6, 3.4), wp)
	_box(Vector3(0, 1.2, 3.3), Vector3(1.0, 2.4, 0.08), Tex.mat("door_padded", 1.0))     # 27's door, shut behind him
	# coats on hooks, shoes: somebody's mother's
	_box(Vector3(-0.6, 1.5, 2.2), Vector3(0.12, 0.8, 0.4), Tex.mat("fabric", 2.0, {"tint": Color(0.3, 0.25, 0.22)}), false)
	_box(Vector3(-0.55, 0.05, 2.6), Vector3(0.25, 0.08, 0.1), Tex.mat("black"), false)
	_box(Vector3(0.6, 1.6, 1.4), Vector3(0.04, 0.5, 0.35), Tex.mat("glass", 1.0, {"tint": Color(0.5, 0.5, 0.55), "rough": 0.1}), false)
	Build.lamp(world, Vector3(0, 2.3, 1.8), Color("ffc27a"), 0.6, 4.0)
	zone(Vector3(0, 1, -1.0), Vector3(2.0, 2.0, 1.0), func(): if not Game.flag("c27_entered"): Game.set_flag("c27_entered"); Dialogue.play("c27_enter"))
	# under the first of them: Socko, quietly
	zone(Vector3(0, 1, -10.0), Vector3(8.0, 2.0, 1.0), func(): if not Game.flag("c27_look_up") and not Dialogue.busy: Game.set_flag("c27_look_up"); Dialogue.play("c27_look_up"))
	# and now and then one of them up there lets go of a hymn book
	ambient([16.0, 32.0], _hymnal, 22.0)

# ------------------------------------------------------------------ the west wall, the narthex
func _west_wall() -> void:
	# a wall the height of the vault with a flat's doorway in the bottom of it
	_box(Vector3(-4.85, VAULT * 0.5, 0.05), Vector3(8.5, VAULT, 0.4), _stone)
	_box(Vector3(4.85, VAULT * 0.5, 0.05), Vector3(8.5, VAULT, 0.4), _stone)
	_box(Vector3(0, (VAULT + 2.6) * 0.5, 0.05), Vector3(1.2, VAULT - 2.6, 0.4), _stone)
	# the three windows over it, and what they show (the words under them)
	var words := {"MANUS": -4.0, "PEDES": 0.0, "LATUS": 4.0}
	for w in words:
		var x: float = words[w]
		_window(Vector3(x, 9.5, -0.2), Vector2(2.0, 6.0), w, PI)
		var lb := Label3D.new(); lb.text = w; lb.font_size = 64; lb.pixel_size = 0.006; lb.modulate = Color(0.75, 0.68, 0.55)
		lb.shaded = false; world.add_child(lb); lb.position = Vector3(x, 6.1, -0.3); lb.rotation.y = PI
	# over the door
	var ins := Label3D.new()
	ins.text = "WHOSOEVER TURNETH HIS BACK UPON THE ALTAR\nSHALL COME UNTO IT"
	ins.font_size = 40; ins.pixel_size = 0.005; ins.modulate = Color(0.7, 0.62, 0.5); ins.shaded = false
	world.add_child(ins); ins.position = Vector3(0, 3.6, -0.3); ins.rotation.y = PI
	# the narthex floor, the font
	_box(Vector3(0, -0.05, -3.0), Vector3(18.0, 0.1, 6.2), Tex.mat("metlakh", 1.0, {"tint": Color(0.45, 0.4, 0.36)}))
	_box(Vector3(-6.0, 0.5, -3.0), Vector3(1.0, 1.0, 1.0), _stone)
	_box(Vector3(-6.0, 1.02, -3.0), Vector3(0.8, 0.06, 0.8), Tex.mat("glass", 1.0, {"tint": Color(0.25, 0.05, 0.04), "rough": 0.05}), false)  # what's in the font
	Build.lamp(world, Vector3(0, 4.0, -3.0), Color("c8a07a"), 1.4, 11.0)

## A stained-glass window: lead and colour, lit from nowhere, steady.
func _window(at: Vector3, size: Vector2, motif: String, rot_y: float) -> void:
	var img: Image = _glass_cache.get(motif, null)
	if img == null:
		img = _glass(motif)
		_glass_cache[motif] = img
	var tex: ImageTexture = _glass_tex.get(motif, null)
	if tex == null:
		tex = ImageTexture.create_from_image(img); _glass_tex[motif] = tex
	var m := StandardMaterial3D.new(); m.albedo_texture = tex; m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color = Color(1.4, 1.3, 1.25)
	var q := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = size; q.mesh = qm; q.material_override = m
	world.add_child(q); q.position = at; q.rotation.y = rot_y
	# the pointed head of the lancet: dark stone either side
	if motif != "":
		var l := Build.lamp(world, at + Basis(Vector3.UP, rot_y) * Vector3(0, -2.0, -1.6), Color("b0603a"), 0.8, 9.0)
		l.omni_attenuation = 1.3

var _glass_cache := {}
var _glass_tex := {}

## The glass for a window (64 x 192): a lancet with a pointed head, cells of dark colour in lead,
## and the motif in bone-white glass with its wound in red:
##   MANUS  a hand, the fingers spread, the nail's wound in the palm, a run of blood from it
##   PEDES  the feet, one over the other, one nail through both
##   LATUS  the ribs, and the spear's wound under them
##   ""     (the nave's) a figure with its arms out on a cross, haloed, red at the hands
func _glass(motif: String) -> Image:
	var W := 64; var H := 192
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var cols := [Color("5a1010"), Color("1a2a5a"), Color("6a5a1a"), Color("2a4a2a"), Color("4a1a4a"), Color("3a1a10")]
	var rng := RandomNumberGenerator.new()
	var bone := Color("e0d0a8"); var wound := Color("ff2a1a"); var lead := Color(0.02, 0.02, 0.02); var gold := Color("d8a040")
	for y in H:
		for x in W:
			var cell := Vector2i((x + (y / 12) % 2 * 5) / 10, y / 12)
			rng.seed = hash(cell) ^ hash(motif)
			var c: Color = cols[rng.randi() % cols.size()]
			if (x + (y / 12) % 2 * 5) % 10 == 0 or y % 12 == 0: c = lead
			var p := Vector2(x, y)
			var shape := _motif(motif, p)
			if shape == 1: c = bone
			elif shape == 2: c = wound
			elif shape == 3: c = gold
			elif shape == 4: c = lead
			# the lancet's pointed head: two arcs meeting at the top
			if y < 40:
				var dl := p.distance_to(Vector2(W, 40)); var dr := p.distance_to(Vector2(0, 40))
				if dl > W or dr > W: c = Color(0.03, 0.025, 0.02)
			if x < 2 or x > W - 3 or y > H - 3: c = lead
			img.set_pixel(x, y, c)
	return img

func _cap(p: Vector2, a: Vector2, b: Vector2, r: float) -> bool:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t) < r

func _ell(p: Vector2, c: Vector2, r: Vector2) -> float:
	var q := (p - c) / r
	return q.length()

## 0 nothing, 1 bone glass, 2 the wound, 3 gold, 4 lead outline
func _motif(motif: String, p: Vector2) -> int:
	match motif:
		"MANUS":
			if _ell(p, Vector2(32, 112), Vector2(4, 4)) < 1.0: return 2
			if _cap(p, Vector2(32, 116), Vector2(33, 160), 1.6) and p.y > 116: return 2            # the run of blood
			var hand := _ell(p, Vector2(32, 112), Vector2(14, 19)) < 1.0
			for f in 4:
				var fx := 22.0 + f * 6.6
				if _cap(p, Vector2(fx, 100), Vector2(fx + (f - 1.5) * 2.0, 58 + absf(f - 1.5) * 8.0), 3.0): hand = true
			if _cap(p, Vector2(20, 116), Vector2(9, 96), 3.2): hand = true
			if _cap(p, Vector2(28, 130), Vector2(28, 160), 7.0) or _cap(p, Vector2(36, 130), Vector2(36, 160), 7.0): hand = true   # the wrist
			if hand: return 1
		"PEDES":
			if _ell(p, Vector2(32, 118), Vector2(4, 4)) < 1.0: return 2
			if _cap(p, Vector2(14, 118), Vector2(50, 118), 2.0): return 4                                # the nail
			if _cap(p, Vector2(32, 122), Vector2(31, 165), 1.6) and p.y > 122: return 2
			var f1 := _ell(p, Vector2(26, 110), Vector2(9, 34)) < 1.0
			var f2 := _ell(p, Vector2(38, 116), Vector2(9, 34)) < 1.0
			for t in 4:
				if _ell(p, Vector2(22 + t * 3, 77 + absf(t - 1.5) * 2.0), Vector2(2, 3)) < 1.0: f1 = true
				if _ell(p, Vector2(34 + t * 3, 83 + absf(t - 1.5) * 2.0), Vector2(2, 3)) < 1.0: f2 = true
			if f1 or f2: return 1
		"LATUS":
			if _ell(p, Vector2(42, 128), Vector2(3, 10)) < 1.0: return 2
			if _cap(p, Vector2(43, 138), Vector2(44, 170), 1.6) and p.y > 138: return 2
			if _cap(p, Vector2(32, 64), Vector2(32, 132), 2.6): return 1                                 # the sternum
			for k in 7:
				var c := Vector2(32, 68 + k * 9)
				var e := _ell(p, c, Vector2(24 - k * 0.8, 10))
				if absf(e - 1.0) < 0.12 and p.y > c.y - 2: return 1
		"":
			if absf(_ell(p, Vector2(32, 52), Vector2(12, 12)) - 1.0) < 0.12: return 3                    # the halo
			if _ell(p, Vector2(32, 52), Vector2(6, 7)) < 1.0: return 1
			if _cap(p, Vector2(10, 74), Vector2(54, 74), 2.6): return 1                                  # the arms, out
			if _ell(p, Vector2(10, 74), Vector2(3, 3)) < 1.0 or _ell(p, Vector2(54, 74), Vector2(3, 3)) < 1.0: return 2
			var t := (p.y - 62.0) / 100.0
			if t > 0.0 and t < 1.0 and absf(p.x - 32.0) < 5.0 + t * 9.0: return 1                        # the robe
	return 0

# ------------------------------------------------------------------ the nave
func _nave() -> void:
	var floor_m := Tex.mat("metlakh", 1.0, {"tint": Color(0.75, 0.68, 0.6)})
	_box(Vector3(0, -0.05, -31.0), Vector3(18.0, 0.1, 50.0), floor_m)
	_box(Vector3(0, 0.005, -31.0), Vector3(1.6, 0.01, 50.0), Tex.mat("rug", 1.0, {"tint": Color(0.45, 0.08, 0.06)}), false)    # the runner
	for s in [-1, 1]:
		_box(Vector3(s * 9.2, VAULT * 0.5, -31.0), Vector3(0.4, VAULT, 50.0), _stone)       # the outer walls
	var rng := RandomNumberGenerator.new(); rng.seed = 27
	# columns and windows, every 6 m (the same every 12: the loop)
	var z := -6.0
	while z >= NAVE_END:
		for s in [-1, 1]:
			_column(Vector3(s * 4.6, 0, z), rng)
			_window(Vector3(s * 8.95, 8.0, z - 3.0), Vector2(1.6, 5.0), "", -s * PI * 0.5)
			_sconce(Vector3(s * 4.0, 2.6, z))
		# a light hanging in each bay, steady: candles in an iron ring
		var l := Build.lamp(world, Vector3(0, 5.0, z - 3.0), Color("ffb070"), 3.2, 11.0)
		l.omni_attenuation = 0.9
		var up := Build.lamp(world, Vector3(0, HANG - 2.2, z - 3.0), Color("d8906a"), 2.8, 9.0)       # up in the vault: them
		up.omni_attenuation = 0.9
		_box(Vector3(0, 5.1, z - 3.0), Vector3(1.4, 0.05, 1.4), Tex.mat("gunmetal", 2.0), false)
		_box(Vector3(0, 11.05, z - 3.0), Vector3(0.03, 11.9, 0.03), Tex.mat("black"), false)
		for c in 6:
			var a := c / 6.0 * TAU
			_box(Vector3(cos(a) * 0.65, 5.22, z - 3.0 + sin(a) * 0.65), Vector3(0.03, 0.06, 0.03), Tex.mat("enamel", 1.0, {"emission": Vector3(3.0, 1.8, 0.6)}), false)
		z -= 6.0
	# pews: both sides of the aisle, every 1.2 m
	z = -8.0
	while z > NAVE_END + 1.0:
		for s in [-1, 1]:
			_pew(Vector3(s * 2.6, 0, z), false)
			_pew(Vector3(s * 2.6, HANG, z), true)                 # the same, upside down, up there
		z -= 1.2
	# the congregation, up in the inverted pews: sitting, hanging, heads turning after him
	var who := ["caretaker", "laundress", "crawler", "rearranger"]
	var k := 0
	for zz in [-10.4, -16.4]:
		for rep in 4:
			var zr: float = zz - rep * BAY
			if zr < NAVE_END + 1.0: continue
			for s in [-1, 1]:
				var fb := FleshBody.new({"model": who[k % who.size()], "height": 1.6})
				world.add_child(fb)
				fb.position = Vector3(s * (1.8 + (k % 3) * 0.7), HANG + 0.02, zr - 0.1)
				fb.rotation = Vector3(0, 0, PI)          # (hanging from the seat)
				fb.snap = 3.0
				_congregation.append(fb)
				k += 1

func _column(at: Vector3, rng: RandomNumberGenerator) -> void:
	# a ribbed column: a tube whose radius goes in and out like ducting, up into the vault
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := []; var radii := []
	var n := 30
	for i in n + 1:
		var y := VAULT * float(i) / n
		pts.append(at + Vector3(0, y, 0))
		radii.append((0.5 if i % 2 else 0.42) * (1.25 - 0.35 * float(i) / n))
	MeshKit.tube(st, pts, radii, {"sides": 8, "cap": false})
	# coral up its foot
	var crng := RandomNumberGenerator.new(); crng.seed = 9           # (every column the same: the loop)
	for c in 6:
		var a := float(c) / 6.0 * TAU
		MeshKit.coral(st, at + Vector3(cos(a) * 0.45, 0.2 + c * 0.25, sin(a) * 0.45), Vector3(cos(a), 0.9, sin(a)), 0.7, 0.07, crng, 2)
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = _bone; world.add_child(mi)
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 0.55; cy.height = VAULT
	cs.shape = cy; sb.add_child(cs); world.add_child(sb); sb.position = at + Vector3(0, VAULT * 0.5, 0)

func _sconce(at: Vector3) -> void:
	_box(at, Vector3(0.12, 0.25, 0.12), Tex.mat("gunmetal", 2.0), false)
	_box(at + Vector3(0, 0.22, 0), Vector3(0.05, 0.2, 0.05), Tex.mat("enamel", 1.0, {"tint": Color(0.85, 0.8, 0.65)}), false)
	_box(at + Vector3(0, 0.35, 0), Vector3(0.025, 0.05, 0.025), Tex.mat("enamel", 1.0, {"emission": Vector3(3.0, 1.8, 0.6)}), false)

func _pew(at: Vector3, upside_down: bool) -> void:
	var f := -1.0 if upside_down else 1.0
	_box(at + Vector3(0, 0.45 * f, 0), Vector3(2.6, 0.06, 0.45), _wood, not upside_down)
	_box(at + Vector3(0, 0.75 * f, 0.22), Vector3(2.6, 0.6, 0.05), _wood, false)
	for s in [-1, 1]: _box(at + Vector3(s * 1.28, 0.4 * f, 0), Vector3(0.06, 0.8, 0.5), _wood, false)

# ------------------------------------------------------------------ the vault
func _vault() -> void:
	# ribbed pointed arches over every pair of columns, and across, and a ceiling of dark above
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := -6.0
	while z >= NAVE_END:
		var pts := []; var radii := []
		for i in 21:
			var t := float(i) / 20.0
			var a := t * PI
			var x := -cos(a) * 4.6
			var y := VAULT - 4.0 + sin(a) * 3.6 + (1.0 - absf(x) / 4.6) * 0.6
			pts.append(Vector3(x, y, z)); radii.append(0.22 if i % 2 else 0.16)
		MeshKit.tube(st, pts, radii, {"sides": 6, "cap": false})
		z -= 6.0
	for s in [-1, 1]:
		var pts2 := []; var r2 := []
		for i in 41:
			pts2.append(Vector3(s * 4.6, VAULT - 4.2, -6.0 + (NAVE_END + 6.0) * float(i) / 40.0)); r2.append(0.2 if i % 2 else 0.15)
		MeshKit.tube(st, pts2, r2, {"sides": 6, "cap": false})
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit(); mi.material_override = _bone; world.add_child(mi)
	_box(Vector3(0, VAULT + 0.2, -31.0), Vector3(18.4, 0.4, 66.0), Tex.mat("black"), false)

# ------------------------------------------------------------------ the apse, the cross
func _apse() -> void:
	# the dais: three steps up
	for i in 3:
		_box(Vector3(0, 0.1 + i * 0.2, -59.0 - i * 0.4), Vector3(8.0, 0.2, 6.0 - i * 0.8), _stone)
	_box(Vector3(0, -0.05, -60.0), Vector3(18.0, 0.1, 9.0), Tex.mat("metlakh", 1.0, {"tint": Color(0.4, 0.35, 0.32)}))
	_box(Vector3(0, VAULT * 0.5, -64.4), Vector3(18.4, VAULT, 0.4), _stone)      # the east wall
	# the cross
	_box(Vector3(0, DAIS_Y + 2.6, CROSS_Z - 0.2), Vector3(0.32, 5.2, 0.26), _wood)
	_box(Vector3(0, DAIS_Y + 3.05, CROSS_Z - 0.2), Vector3(3.4, 0.28, 0.24), _wood)
	_box(Vector3(0, DAIS_Y + 0.55, CROSS_Z + 0.02), Vector3(0.5, 0.06, 0.3), _wood)       # the footrest
	# under it: what's run down
	_box(Vector3(0, DAIS_Y + 0.005, CROSS_Z + 0.6), Vector3(1.6, 0.01, 1.2), Tex.mat("glass", 1.0, {"tint": Color(0.18, 0.02, 0.02), "rough": 0.05}), false)
	# the rose window
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5)
			var r := d.length(); var a := atan2(d.y, d.x)
			var c := Color(0, 0, 0)
			if r < 31:
				var petal := absf(sin(a * 6.0))
				c = Color("5a0a08") if petal > 0.5 else Color("1a1a4a")
				if r < 8: c = Color("c8a060")
				if absf(r - 20.0) < 1.0 or absf(r - 8.0) < 0.8 or (petal < 0.08 and r > 8): c = Color(0.02, 0.02, 0.02)
			img.set_pixel(x, y, c)
	var m := StandardMaterial3D.new(); m.albedo_texture = ImageTexture.create_from_image(img); m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color = Color(0.9, 0.85, 0.8)
	_rose = MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(9.0, 9.0); _rose.mesh = qm; _rose.material_override = m
	world.add_child(_rose); _rose.position = Vector3(0, 10.5, -64.15)
	_rose_light = Build.lamp(world, Vector3(0, 7.0, -61.0), Color("c84a30"), 0.9, 14.0)
	# candles along the dais, steady
	for i in 9:
		var x := -3.6 + i * 0.9
		var h := 0.25 + 0.2 * float((i * 7) % 3)
		_box(Vector3(x, DAIS_Y + h * 0.5, -57.2), Vector3(0.07, h, 0.07), Tex.mat("enamel", 1.0, {"tint": Color(0.85, 0.8, 0.65)}), false)
		_box(Vector3(x, DAIS_Y + h + 0.04, -57.2), Vector3(0.025, 0.05, 0.025), Tex.mat("enamel", 1.0, {"emission": Vector3(3.0, 1.8, 0.6)}), false)
	Build.lamp(world, Vector3(0, DAIS_Y + 1.2, -57.0), Color("ffb060"), 1.1, 7.0)
	var key := SpotLight3D.new(); key.light_color = Color("ffd8b0"); key.light_energy = 3.0; key.spot_range = 9.0; key.spot_angle = 24.0
	key.shadow_enabled = not OS.has_feature("mobile")
	world.add_child(key); key.position = Vector3(0, DAIS_Y + 6.5, -55.5); key.look_at(Vector3(0, DAIS_Y + 2.0, CROSS_Z), Vector3.UP)
	Build.lamp(world, Vector3(0, DAIS_Y + 2.5, -58.0), Color("ff9a60"), 0.9, 5.0)
	# the door behind the altar: a flat's front door. 27.
	_box(Vector3(5.0, 1.2, -64.15), Vector3(1.0, 2.4, 0.1), Tex.mat("door_padded", 1.0))
	var no := Label3D.new(); no.text = "27"; no.font_size = 48; no.pixel_size = 0.004; no.modulate = Color(0.8, 0.7, 0.4)
	world.add_child(no); no.position = Vector3(5.0, 1.75, -64.08)
	var u := Use.make(world, Vector3(5.0, 1.2, -63.9), Vector3(1.0, 2.4, 0.3), func(): return "Open the door" if _decided != "" else "", func(_p): _leave())
	u.name = "Door27"
	# the hammer at his feet
	var hm := _box(Vector3(0.3, DAIS_Y + 0.03, CROSS_Z + 0.5), Vector3(0.32, 0.04, 0.06), _wood, false)
	hm.name = "Hammer"
	var hu := Use.make(world, Vector3(0.3, DAIS_Y + 0.1, CROSS_Z + 0.5), Vector3(0.5, 0.3, 0.4),
		func(): return "Take the hammer" if Game.count("hammer") == 0 and not Game.flag("c27_took_hammer") else "",
		func(_p):
			Game.set_flag("c27_took_hammer"); Game.add_item("hammer"); Sfx.play("pickup", -4.0)
			if is_instance_valid(hm): hm.visible = false)
	hu.name = "Take_hammer"
	zone(Vector3(0, 1.0, -55.0), Vector3(8.0, 2.0, 1.5), _meet)

func _stigmata() -> void:
	stig = FleshBody.new({"model": "stigmata", "speaker": "stigmata", "height": 1.92})
	world.add_child(stig)
	stig.position = Vector3(0, DAIS_Y + 0.62, CROSS_Z + 0.02)
	stig.rotation.y = PI
	stig.snap = 4.0
	stig_pose = {"sh_r": Vector3(0, 0, 1.42), "el_r": Vector3(0, 0, 0.1), "sh_l": Vector3(0.9, 0, -0.25), "el_l": Vector3(-0.5, 0, 0),
		"head": Vector3(-0.35, 0.15, 0.25), "neck": Vector3(-0.2, 0, 0.1), "spine": Vector3(0.05, 0, 0.05), "kn_l": Vector3(-0.2, 0, 0), "kn_r": Vector3(-0.25, 0, 0),
		"hip_l": Vector3(0.12, 0, 0.06), "hip_r": Vector3(0.1, 0, -0.06)}
	await get_tree().process_frame
	_apply_pose()
	# the nails: through the right palm, through the feet; the last one in the free left hand
	var nail_m := Tex.mat("gunmetal", 2.0)
	var nr := MeshInstance3D.new(); nr.mesh = Build.box_mesh(Vector3(0.015, 0.015, 0.16)); nr.material_override = nail_m
	stig.J["el_r"].add_child(nr); nr.position = Vector3(0.03, -0.45, 0.0)
	for side in ["l", "r"]:
		var nf := MeshInstance3D.new(); nf.mesh = Build.box_mesh(Vector3(0.015, 0.015, 0.16)); nf.material_override = nail_m
		stig.J["kn_" + side].add_child(nf); nf.position = Vector3(0, -0.47, -0.08)
	_nail_l = MeshInstance3D.new(); _nail_l.mesh = Build.box_mesh(Vector3(0.012, 0.15, 0.012)); _nail_l.material_override = nail_m
	stig.J["el_l"].add_child(_nail_l); _nail_l.position = Vector3(0.0, -0.46, 0.0)
	# breathing, the drip
	ambient([3.0, 5.0], func(): if stig and _done != "freed": Sfx.play_at("stig_breath", stig.at("head"), -10.0, randf_range(0.92, 1.05), 14.0))
	ambient([1.5, 3.0], func(): Sfx.play_at("drip", Vector3(0, DAIS_Y + 0.1, CROSS_Z + 0.5), -8.0, randf_range(0.8, 1.1), 10.0))
	# what Kurt does with his hands, after
	Use.make(world, Vector3(-0.9, DAIS_Y + 2.3, CROSS_Z + 0.25), Vector3(0.5, 0.6, 0.5), func(): return _left_prompt(), func(_p): _strike())
	Use.make(world, Vector3(0.95, DAIS_Y + 2.45, CROSS_Z + 0.25), Vector3(0.4, 0.4, 0.4), func(): return _pull_prompt("hand"), func(_p): _pull("hand"))
	Use.make(world, Vector3(0, DAIS_Y + 0.45, CROSS_Z + 0.2), Vector3(0.5, 0.4, 0.4), func(): return _pull_prompt("feet"), func(_p): _pull("feet"))

func _apply_pose() -> void:
	if not stig: return
	for k in stig.pose: stig.pose[k] = stig_pose.get(k, Vector3.ZERO)

func _process(delta: float) -> void:
	super._process(delta)
	if cutscene: return
	_loop(delta)
	# the congregation watches him: each head turns after him, slowly
	for fb in _congregation:
		if not is_instance_valid(fb): continue
		var to: Vector3 = player.global_position - fb.global_position
		var yaw := atan2(to.x, to.z)
		fb.pose["head"] = Vector3(0.4, clampf(-yaw, -1.2, 1.2), 0.0)
		fb.pose["neck"] = Vector3(0.3, clampf(-yaw * 0.4, -0.5, 0.5), 0.0)
		fb.pose["hip_l"] = Vector3(1.4, 0, 0); fb.pose["hip_r"] = Vector3(1.4, 0, 0)
		fb.pose["kn_l"] = Vector3(-1.5, 0, 0); fb.pose["kn_r"] = Vector3(-1.5, 0, 0)

var _hymnals: Array = []

## A hymn book falls from the pews hanging in the vault and lands near him (they stay where they
## land: the floor fills up the longer he's in here).
func _hymnal() -> void:
	if cutscene or not player: return
	var pz := player.global_position.z
	if pz > -7.0 or pz < NAVE_END + 2.0: return
	var at := Vector3(player.global_position.x + randf_range(-1.5, 1.5), HANG - 0.6, pz - randf_range(1.0, 3.0))
	at.x = clampf(at.x, -3.8, 3.8)
	var b := Build.box(world, at, Vector3(0.14, 0.04, 0.2), Tex.mat("cloth_red", 2.0, {"tint": Color(0.35, 0.25, 0.2)}), false)
	b.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	Sfx.play_at("paper", at, -10.0, 0.8, 20.0)
	var tw := create_tween()
	tw.tween_property(b, "position:y", 0.03, 1.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(b, "rotation", Vector3(0, randf() * TAU, 0), 1.15)
	tw.tween_callback(func(): Sfx.play_at("thud", Vector3(at.x, 0.1, at.z), -4.0, 1.6, 22.0))
	_hymnals.append(b)
	if _hymnals.size() > 14:
		var old = _hymnals.pop_front()
		if is_instance_valid(old): old.queue_free()

# ------------------------------------------------------------------ the loop
func facing_altar() -> bool:
	return (-player.cam.global_transform.basis.z).dot(Vector3(0, 0, -1)) > 0.2

func _loop(_delta: float) -> void:
	var z := player.global_position.z
	if loop_broken: return
	if z < LOOP_OUT:
		_break_loop("backwards")
		return
	if z < LOOP_FROM and facing_altar():
		player.global_position.z += BAY
		_loops_seen += 1
		if _loops_seen in [1, 3, 6] and not Dialogue.busy:
			Dialogue.play(["c27_loop_1", "c27_loop_2", "c27_loop_3"][[1, 3, 6].find(_loops_seen)])

func _break_loop(how: String) -> void:
	if loop_broken: return
	loop_broken = true
	Game.set_flag("c27_loop_broken"); Game.set_flag("c27_broken_" + how)
	Game.checkpoint()
	if how == "bells": Dialogue.play("c27_bells_right")
	else: Dialogue.play("c27_backwards")

# ------------------------------------------------------------------ the bells
func _bell_ropes() -> void:
	var words := {"MANUS": -4.0, "PEDES": 0.0, "LATUS": 4.0}
	for w in words:
		var x: float = words[w]
		var z := -1.6 if w == "PEDES" else -0.8
		var rope := _box(Vector3(x, (VAULT + 1.0) * 0.5, z), Vector3(0.04, VAULT - 1.0, 0.04), Tex.mat("fabric", 4.0, {"tint": Color(0.55, 0.45, 0.32)}), false)
		var sally := _box(Vector3(x, 1.45, z), Vector3(0.09, 0.4, 0.09), Tex.mat("cloth_red", 2.0), false)
		var u := Use.make(world, Vector3(x, 1.4, z), Vector3(0.4, 0.8, 0.4), func(): return "" if loop_broken else "Pull the rope (%s)" % w, func(_p): _ring(w, rope, sally))
		u.name = "Rope_" + w

func ring(word: String) -> void:
	_ring(word, null, null)

func _ring(word: String, rope, sally) -> void:
	if loop_broken: return
	for n in [rope, sally]:
		if n:
			var tw := create_tween(); tw.tween_property(n, "position:y", n.position.y - 0.25, 0.25); tw.tween_property(n, "position:y", n.position.y, 0.6)
	var x := {"MANUS": -4.0, "PEDES": 0.0, "LATUS": 4.0}[word] as float
	if BELL_ORDER[_bells.size()] == word:
		_bells.append(word)
		Sfx.play_at("bell_toll", Vector3(x, VAULT - 2.0, -2.0), -2.0 + _bells.size() * 2.0, [1.0, 0.89, 0.75][_bells.size() - 1], 80.0)
		if _bells.size() == 3: _break_loop("bells")
	else:
		_bells.clear()
		Sfx.play_at("bell_dull", Vector3(x, VAULT - 2.0, -2.0), -2.0, 1.0, 40.0)
		if not Game.flag("c27_wrong_bell"): Game.set_flag("c27_wrong_bell"); Dialogue.play("c27_bell_wrong")

# ------------------------------------------------------------------ his pages
func _pages() -> void:
	_page("c27_page1", Vector3(-6.0, 1.1, -2.4), "They stopped coming. First the young ones, then the old ones, then the ones who only came for the warm.\n\nI kept the doors open. I kept the candles. Nobody came up the stairs but the water.\n\nSo I had to be the congregation as well.")
	_box(Vector3(2.5, 0.55, -4.0), Vector3(0.5, 1.1, 0.4), _wood)        # the lectern
	_page("c27_page2", Vector3(2.5, 1.15, -4.0), "First the feet, because they will not need to walk again.\n\nThen the right hand, while I still had the left to hold the hammer.\n\nThe side I leave open. Whoever comes will want to see inside.")
	_page("c27_page3", Vector3(-2.2, DAIS_Y + 0.75, -57.2), "I cannot do the last one.\n\nNobody can do the last one alone. That is the whole of it. That was always the whole of it.\n\nSomebody will come up the stairs. Somebody always comes up the stairs, eventually.")

func _page(key: String, at: Vector3, text: String) -> void:
	_box(at + Vector3(0, -0.02, 0), Vector3(0.22, 0.01, 0.3), Tex.mat("newspaper", 4.0, {"tint": Color(0.85, 0.8, 0.7)}), false)
	Use.make(world, at, Vector3(0.4, 0.25, 0.4), func(): return "Read", func(_p):
		Game.set_flag(key); Sfx.play("paper", -4.0)
		NoteReader.open(self, text, {"ink": Color("2a1a14"), "font_size": 24}))

# ------------------------------------------------------------------ him
func _meet() -> void:
	if _met or not loop_broken: return
	_met = true
	set_cutscene(true)
	var d: Vector3 = stig.at("head") - player.cam.global_position
	player.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	await Dialogue.play("c27_meet")
	set_cutscene(false)

func on_event(n: String, _step: Dictionary) -> void:
	match n:
		"stig_look": stig_pose["head"] = Vector3(0.0, 0.0, 0.1); _apply_pose()
		"stig_socko": stig_pose["head"] = Vector3(-0.1, 0.5, 0.1); _apply_pose()
		"stig_up": stig_pose["head"] = Vector3(0.6, 0.0, 0.0); _apply_pose()
		"stig_offer": stig_pose["sh_l"] = Vector3(1.3, 0, -0.1); stig_pose["el_l"] = Vector3(-0.3, 0, 0); stig_pose["head"] = Vector3(-0.1, 0, 0); _apply_pose()
		"stig_give": stig_pose["sh_l"] = Vector3(0, 0, -1.42); stig_pose["el_l"] = Vector3(0, 0, -0.1); _apply_pose()     # the arm out along the beam, for it
		"stig_decided": _decide()

func _decide() -> void:
	if Game.flag("c27_chose_nail"): _decided = "nail"
	elif Game.flag("c27_chose_free"): _decided = "free"
	else: _decided = "leave"
	objective({"nail": "Drive the last nail.", "free": "Get him down.", "leave": "The door behind the altar."}[_decided])

func _left_prompt() -> String:
	if _decided != "nail" or _done != "": return ""
	return "Drive the nail" if Game.count("hammer") > 0 else "The nail"

func _strike() -> void:
	if Game.count("hammer") == 0: Dialogue.play("c27_need_hammer"); return
	_strikes += 1
	Sfx.play_at("nail_strike", stig.at("el_l"), 0.0, randf_range(0.95, 1.05))
	Fx.hitstop(0.08); Fx.burst("flesh", stig.at("el_l"), Vector3(0, 0, 1))
	# he goes rigid with it, then sags
	stig.snap = 30.0
	stig.pose["spine"] = Vector3(0.25, 0, 0); stig.pose["head"] = Vector3(0.7, 0.2, 0.0); stig.pose["kn_l"] = Vector3(-0.6, 0, 0)
	await get_tree().create_timer(0.25).timeout
	stig.snap = 4.0
	_apply_pose()
	if _strikes >= 3: _resolve("nailed")

func _pull_prompt(which: String) -> String:
	if _decided != "free" or _done != "" or _pulled.get(which, false): return ""
	return "Pull the nail" + (" (hand)" if which == "hand" else " (feet)")

func _pull(which: String) -> void:
	if Game.count("hammer") == 0: Dialogue.play("c27_need_hammer"); return
	_pulled[which] = true
	Sfx.play_at("flesh_tear", stig.at("chest"), 0.0)
	Sfx.play_at("metal", stig.at("chest"), -6.0, 0.8)
	Fx.burst("flesh", stig.at("el_r" if which == "hand" else "kn_l"), Vector3(0, 0, 1))
	if which == "hand": stig_pose["sh_r"] = Vector3(0.2, 0, 0.3)            # the arm drops
	_apply_pose()
	if _pulled.size() >= 2: _resolve("freed")

func _resolve(how: String) -> void:
	_done = how
	Game.set_flag("c27_" + how)
	set_cutscene(true)
	if how == "nailed":
		Game.set_flag("ch2_obey_nail")
		var tw := create_tween(); tw.tween_property(_rose_light, "light_energy", 2.2, 6.0)
		await Dialogue.play("c27_nailed")
	else:
		Game.set_flag("ch2_defy_nail")
		# he comes down: slides off the footrest, folds onto the dais
		var tw := create_tween(); tw.tween_property(stig, "position", Vector3(0, DAIS_Y, CROSS_Z + 0.5), 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		stig_pose = {"hip_l": Vector3(1.5, 0, 0), "hip_r": Vector3(1.4, 0, 0), "kn_l": Vector3(-1.9, 0, 0), "kn_r": Vector3(-1.8, 0, 0), "spine": Vector3(-0.9, 0, 0.2),
			"head": Vector3(-0.5, 0.3, 0.2), "sh_l": Vector3(0.4, 0, 0.3), "sh_r": Vector3(0.3, 0, -0.4)}
		_apply_pose()
		Sfx.play_at("thud", stig.global_position, 0.0)
		await tw.finished
		await Dialogue.play("c27_freed")
	objective("The door behind the altar.")
	set_cutscene(false)

func _leave() -> void:
	if _ending: return
	_ending = true
	set_cutscene(true)
	if _done == "":
		Game.set_flag("c27_left")
		if _decided != "nail": Game.set_flag("ch2_defy_nail")
		await Dialogue.play("c27_left")
	Sfx.play("door_creak", -4.0)
	await Dialogue.play("c27_door")
	Game.set_flag("ch2_done")
	Game.checkpoint()
	Game.demo_over = bool(Game.demo.get("is_demo", false))
	await Game.end_chapter("Flat 27", "End of Chapter Two")

# ------------------------------------------------------------------ start, and coming back
func begin() -> void:
	Sfx.loop("cath", "cath_bed", -4.0)
	set_cutscene(false)
	Game.checkpoint()
	await Game.fade(0.0, 1.5)

func _restore() -> void:
	loop_broken = Game.flag("c27_loop_broken")

func on_player_down() -> void:
	set_cutscene(true)
	await Game.fade(1.0, 0.8)
	if not is_inside_tree() or Game.level != self: return
	Game.restart_level()
