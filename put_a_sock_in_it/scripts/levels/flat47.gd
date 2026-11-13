extends Level
## Level 1: Flat 47, Building 14, Kerzhansk, 1996.
##
## Kurt knocks; Marta's sister asked him to look in on her. He goes in. Marta is at her place at
## the dinner table by the window, grown into her chair by coral, alive. She asks about the boxes.
## She takes hold of him and throws him across the room, into the dark.
##
## He comes to on the living room floor without his name, and his left hand is a sock puppet,
## and the puppet is talking. The front door is shut and won't give: something outside holds it.
## The wardrobe she pushed across the box-room door: behind it, the doorway has become a hole,
## fleshy, running with blue goo. Socko smells something in the kitchen (a pistol, in a drawer).
## Out on the balcony the world has been replaced by a sticky note that says "outside". The only
## way on is into the hole.
##
## The flat is the exported apartment (ExportedFlat): living room x 0-4.4 z 0-5.2 (the table by
## the window), bedroom and kitchen along the courtyard side, the hall x 4.4-10 z 3.8-5.2 with
## the front door in its east wall, the box room, Sonya's room and the bathroom along the back,
## the balcony north of the living room, the landing east of the front door.

const MARTA_POS := Vector3(3.0, 0, 1.42)
const HOLE := Vector3(1.82, 0, 5.2)          # the box-room doorway
const FRONT := Vector3(10.06, 0, 4.56)        # the middle of the front doorway (the hinge is at z 4.145)
const LAND := Vector3(2.9, 0, 3.0)           # where she throws him: across the room, onto the open floor by the wall unit

var flat: ExportedFlat
var marta: MartaSeated
var marta_spot: Hotspot
var hole_spot: Hotspot
var front_door: ExportDoor
var balcony_door: ExportDoor
var wardrobe: AnimatableBody3D
var gun_drawer: ExportDrawer
var hole_parts: Node3D
var goo_seep: MeshInstance3D
var goo_spurt: CPUParticles3D
var table_lamp: Fitting
var landing_bulb: Fitting
var outside: Node3D
var hand: KurtArm
var _seen_marta := false
var _woke := false
var _wardrobe_moved := false
var _marta_t := 0.0
# the scare (docs/SCARE.md)
var jumper: MartaSeated          # her on her feet, for the moment the light comes back
var _murmur_t := 2.0
var _unseen_t := 0.0
var _tells := 0
var _world_db := 0.0
var _chair_line := false

# ------------------------------------------------------------------ the place
func build() -> void:
	flat = ExportedFlat.new(0.0, ["prop_34_Wardrobe", "prop_8_Chair"])
	world.add_child(flat)
	_environment()
	front_door = flat.doors.dEntry
	front_door.locked = false; front_door.name_text = "door"
	front_door.angle = 0.0; front_door.target = 0.0; front_door._apply(); front_door.is_open = false
	balcony_door = flat.doors.balDoor
	balcony_door.locked = true; balcony_door.angle = 0.0; balcony_door.target = 0.0; balcony_door._apply(); balcony_door.is_open = false
	balcony_door.name_text = "balcony door"
	var store: ExportDoor = flat.doors.dStore
	store.locked = true; store.angle = 0.0; store.target = 0.0; store._apply()
	front_door.tried.connect(_on_front_door_tried)
	_landing()
	_marta()
	_wardrobe()
	_hole()
	_gun()
	_outside()
	_lights()
	_atmosphere()
	_sonya_note()
	# things of hers and Sonya's that bring something back to him (a memory point each, once)
	for k in ["pick_123_Photo_album", "pick_144_Drawing", "prop_0_Wedding_photograph"]:
		if flat.props.has(k): (flat.props[k] as Node).set_meta("memory_item", k)
	player.position = Vector3(11.9, 0, 4.56)
	player.set_view(PI * 0.5, -0.04)
	socko.points = {"chair": MARTA_POS + Vector3(0, 0.7, 0), "door": FRONT + Vector3(0, 1.2, 0), "hole": HOLE + Vector3(0, 0.8, 0), "gun": gun_drawer, "wardrobe": wardrobe}

func ao_area() -> Array:
	return [Rect2(-0.6, -1.95, 14.8, 10.4), 0.0, ExportedFlat.H]

func ao_name() -> String: return "flat47"

## The JS version's evening: a dusk the colour of slate through the courtyard windows, almost no
## light of its own; what light there is comes from her fittings.
func _environment() -> void:
	var e := env.environment
	e.background_mode = Environment.BG_COLOR; e.background_color = Color("262a31")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("46505e"); e.ambient_light_energy = 0.14
	e.fog_enabled = true; e.fog_light_color = Color("262a31"); e.fog_density = 0.012
	e.tonemap_mode = Environment.TONE_MAPPER_ACES; e.tonemap_exposure = 1.2
	e.glow_enabled = true; e.glow_intensity = 0.45; e.glow_hdr_threshold = 1.1

## The landing: the stairwell's green paint, the stair going down, the rail, 48 next door, the
## bulb on its way out.
func _landing() -> void:
	var sw := Stairwell.build(flat)
	landing_bulb = sw.bulb

## Marta, in her chair at the table, the light over the table on her.
func _marta() -> void:
	flat.hide_near(Vector3(3.02, 0.5, 1.45), 0.3, 1.4)        # the chair she's grown into replaces the export's
	marta = MartaSeated.new(); marta.name = "Marta"
	world.add_child(marta)
	marta.position = MARTA_POS; marta.rotation.y = PI / 2
	marta_spot = Hotspot.make(world, MARTA_POS + Vector3(0.0, 1.0, 0.0), Vector3(0.6, 1.0, 0.6), "", _investigate)
	marta_spot.enabled = false
	jumper = MartaSeated.new(true, 0); jumper.name = "MartaRisen"; jumper.visible = false; jumper.snap = 60.0
	world.add_child(jumper)

## The wardrobe she pushed across the box-room door. It can be pushed back along the wall.
func _wardrobe() -> void:
	var n := flat.node("prop_34_Wardrobe")
	wardrobe = AnimatableBody3D.new(); wardrobe.sync_to_physics = false; wardrobe.name = "Wardrobe"
	world.add_child(wardrobe)
	wardrobe.global_transform = n.global_transform
	n.reparent(wardrobe, true)
	wardrobe.add_to_group("nav_block")
	var ex: Dictionary = n.get_meta("extras", {})
	var size: Array = ex.get("size", [1.2, 2.0, 0.6]); var centre: Array = ex.get("centre", [0, 1.0, 0])
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(size[0], size[1], size[2]); cs.shape = b
	cs.position = Vector3(centre[0], centre[1], centre[2]); wardrobe.add_child(cs)
	var h := Hotspot.make(world, wardrobe.global_position + Vector3(0, 1.0, -0.35), Vector3(1.0, 1.4, 0.3), "Heavy wardrobe", _push_wardrobe)
	h.name = "WardrobeSpot"
	# blue goo seeping out from under it
	goo_seep = Build.organic(world, func(st): MeshKit.blob(st, wardrobe.global_position + Vector3(0.1, 0.0, -0.4), Vector3(0.5, 0.012, 0.2), {"bumps": 0.3, "freq": 3.0}), _goo())

func _push_wardrobe() -> void:
	if _wardrobe_moved or not _woke: return
	_wardrobe_moved = true
	var spot := world.get_node("WardrobeSpot") as Hotspot
	spot.enabled = false
	spot.queue_free()
	set_cutscene(true)
	player.shake(0.01, 1.6)
	for i in 3:
		Sfx.play_at("scrape", wardrobe.global_position + Vector3(0, 0.3, 0), 2.0, randf_range(0.85, 1.0))
		Game.make_noise(wardrobe.global_position, 0.6)
		var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(wardrobe, "position", wardrobe.position + Vector3(-0.35, 0, 0), 0.55)   # west, into the corner: the way to the hall stays clear
		await tw.finished
		await get_tree().create_timer(0.25).timeout
	await _on_wardrobe_pushed()

## Her flesh (the textures painted for Marta), wet, both sides, glowing a little from inside.
func _rot(tex: String, rough: float, glow: Vector3) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = preload("res://shaders/ps1_double.gdshader")
	m.set_shader_parameter("albedo_tex", RotTextures.get_tex(tex)); m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("uv_scale", Vector2(3, 3)); m.set_shader_parameter("pulse", 0.012); m.set_shader_parameter("emission", glow)
	return m

func _goo() -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = preload("res://shaders/goo.gdshader"); return m

## The box-room doorway, gone to flesh: a ring of meat round a throat that runs back into the
## dark where the boxes were, blue goo coming out of it in spurts. Hidden until the wardrobe moves.
func _hole() -> void:
	hole_parts = Node3D.new(); world.add_child(hole_parts)
	var flesh := _rot("gums", 0.2, Vector3(0.9, 0.25, 0.28))
	var throat := _rot("flesh", 0.35, Vector3(0.35, 0.12, 0.14))
	var c := HOLE + Vector3(0, 0.95, 0)
	Build.organic(hole_parts, func(st):
		var g := RandomNumberGenerator.new(); g.seed = 33
		for i in 26:
			var a := TAU * i / 26.0
			MeshKit.blob(st, c + Vector3(cos(a) * 0.36, sin(a) * 0.9, -0.04), Vector3(0.11, 0.13, 0.1) * g.randf_range(0.8, 1.4), {"bumps": 0.3, "seed": float(i)}), flesh)
	Build.organic(hole_parts, func(st):
		var pts := []; var rs := []
		for i in 9:
			var k := i / 8.0
			pts.append(Vector3(HOLE.x + sin(k * 2.5) * 0.25, 0.9 - k * k * 0.5, HOLE.z + 0.05 + k * 2.5)); rs.append(0.55 - k * 0.15)
		MeshKit.tube(st, pts, rs, {"sides": 10, "bumps": 0.25, "cap": true}), throat)
	var l := Build.lamp(hole_parts, HOLE + Vector3(0, 0.6, 1.3), Color("3a6aff"), 1.4, 3.5)
	Build.lamp(hole_parts, HOLE + Vector3(0, 0.7, -0.7), Color("5a7aff"), 1.3, 3.2)        # its glow on the room
	Build.organic(hole_parts, func(st):
		MeshKit.tube(st, [HOLE + Vector3(0, 0.1, 0.6), HOLE + Vector3(0.05, 0.05, -0.1), HOLE + Vector3(0.1, 0.01, -0.7)], [0.12, 0.09, 0.15], {"sides": 8, "cap": false})
		MeshKit.blob(st, HOLE + Vector3(0.1, 0.0, -0.8), Vector3(0.7, 0.015, 0.5), {"bumps": 0.3, "freq": 3.0}), _goo())
	goo_spurt = CPUParticles3D.new(); hole_parts.add_child(goo_spurt)
	goo_spurt.position = HOLE + Vector3(0, 0.45, 0.1)
	goo_spurt.amount = 40; goo_spurt.lifetime = 1.1; goo_spurt.emitting = false
	goo_spurt.direction = Vector3(0, 0.5, -1); goo_spurt.spread = 18.0; goo_spurt.initial_velocity_min = 1.4; goo_spurt.initial_velocity_max = 2.6
	goo_spurt.gravity = Vector3(0, -9.8, 0); goo_spurt.scale_amount_min = 0.5; goo_spurt.scale_amount_max = 1.2
	var dm := SphereMesh.new(); dm.radius = 0.025; dm.height = 0.05; dm.radial_segments = 6; dm.rings = 3; dm.material = _goo()
	goo_spurt.mesh = dm
	hole_parts.visible = false
	hole_spot = Hotspot.make(world, HOLE + Vector3(0, 0.9, -0.05), Vector3(0.7, 1.6, 0.3), "", _crawl)
	hole_spot.enabled = false

## The pistol: in the kitchen, in the drawer under the counter.
func _gun() -> void:
	gun_drawer = flat.drawer_near(Vector3(9.0, 0.7, 0.4))
	var gun := Pickup.new(); gun.item = "pistol"; gun.amount = 4; gun.label = "pistol"
	gun_drawer.add_child(gun); gun.position = Vector3(0, 0.08, 0.0)
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(0.25, 0.06, 0.18); cs.shape = sh; gun.add_child(cs)
	for spec in [[Vector3(0, 0, 0), Vector3(0.17, 0.03, 0.03)], [Vector3(0.06, -0.005, 0.03), Vector3(0.04, 0.025, 0.07)]]:
		var mi := MeshInstance3D.new(); mi.mesh = Build.box_mesh(spec[1]); mi.material_override = Tex.mat("gunmetal", 8.0, {"rough": 0.35}); mi.position = spec[0]; gun.add_child(mi)
	gun.taken.connect(_on_gun_taken)

## Outside the windows, after: nothing. White, even, and a sticky note that says "outside".
func _outside() -> void:
	outside = Node3D.new(); world.add_child(outside)
	outside.visible = false
	var white := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(80, 40, 80); white.mesh = bm
	var wm := StandardMaterial3D.new(); wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; wm.albedo_color = Color(0.93, 0.93, 0.92)     # (under full white: clipped, the window frames broke into hard shards)
	wm.cull_mode = BaseMaterial3D.CULL_FRONT; wm.disable_fog = true
	white.material_override = wm; white.position = Vector3(5, 5, 4); outside.add_child(white)
	_sticky_note(Vector3(3.0, 2.2, -12.0), 0.0, 7.0, -0.035)
	_sticky_note(Vector3(4.8, 2.0, 20.0), PI, 6.0, 0.03)
	var glow := OmniLight3D.new(); glow.light_color = Color(0.93, 0.95, 1.0); glow.light_energy = 0.9; glow.omni_range = 3.2
	glow.position = Vector3(2.25, 1.6, -2.2); outside.add_child(glow)

func _sticky_note(at: Vector3, yaw: float, size: float, tilt: float) -> void:
	var note := Node3D.new(); outside.add_child(note)
	note.position = at; note.rotation = Vector3(0, yaw, tilt)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const N := 12
	var pts := []
	for j in N + 1:
		var row := []
		for i in N + 1:
			var u := float(i) / N; var v := float(j) / N
			var curl := pow(maxf(0.0, v - 0.55) / 0.45, 2.2) * size * 0.07 + pow(maxf(0.0, u - 0.7) / 0.3, 2.0) * pow(maxf(0.0, v - 0.6) / 0.4, 1.5) * size * 0.05
			row.append(Vector3((u - 0.5) * size, (0.5 - v) * size, curl))
		pts.append(row)
	for j in N:
		for i in N:
			var c := Color("f4e06a") if (j + 0.5) / N > 0.14 else Color("e9d35a")
			c = c.darkened(0.06 * smoothstep(0.55, 1.0, (j + 0.5) / N))
			for p in [pts[j][i], pts[j][i + 1], pts[j + 1][i + 1], pts[j][i], pts[j + 1][i + 1], pts[j + 1][i]]:
				st.set_color(c); st.add_vertex(p)
	var paper := MeshInstance3D.new(); paper.mesh = st.commit()
	var pm := StandardMaterial3D.new(); pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.vertex_color_use_as_albedo = true; pm.cull_mode = BaseMaterial3D.CULL_DISABLED; pm.disable_fog = true
	paper.material_override = pm
	note.add_child(paper)
	var word := Label3D.new(); word.text = "“outside”"
	word.font_size = 160; word.pixel_size = size / 900.0; word.outline_size = 0
	word.modulate = Color("1d2333"); word.shaded = false; word.double_sided = true
	word.position = Vector3(0, -size * 0.03, size * 0.004)
	note.add_child(word)
var sticky_at := Vector3(3.0, 2.2, -12.0)

## Sonya's story, folded, half under her bed: you have to look down to see it.
const SONYA_NOTE := "Pembis\n\nA story by pee pee\n\nPembis went to poop town.\n\n- Sonya age 10"
func _sonya_note() -> void:
	var at := Vector3(4.1, 0.003, 7.25)
	var note := Node3D.new(); note.name = "SonyaNote"; world.add_child(note)
	note.position = at; note.rotation.y = 0.45
	var pm := StandardMaterial3D.new(); pm.albedo_color = Color("e9e2cc"); pm.roughness = 0.95
	var sheet := MeshInstance3D.new(); sheet.mesh = Build.box_mesh(Vector3(0.21, 0.004, 0.15)); sheet.material_override = pm
	note.add_child(sheet)
	# folded once: the top half lifting off the bottom
	var flap := MeshInstance3D.new(); flap.mesh = Build.box_mesh(Vector3(0.21, 0.003, 0.075)); flap.material_override = pm
	note.add_child(flap); flap.position = Vector3(0, 0.012, 0.035); flap.rotation.x = -0.18
	var scrawl := Label3D.new(); scrawl.text = "PEMBIS"; scrawl.font_size = 40; scrawl.pixel_size = 0.0011
	scrawl.modulate = Color("5a4c8a"); scrawl.shaded = true; scrawl.outline_size = 0
	flap.add_child(scrawl); scrawl.position = Vector3(0.0, 0.003, 0.0); scrawl.rotation = Vector3(-PI * 0.5, 0, 0.12)
	Hotspot.make(world, at + Vector3(0, 0.05, 0), Vector3(0.3, 0.12, 0.26), "Read the note", _read_sonya_note)

func _read_sonya_note() -> void:
	if not Game.flag("read_pembis"): Skills.award("memory", 1, "a child's story")
	Game.flags["read_pembis"] = true
	var r := NoteReader.open(self, SONYA_NOTE, {"ink": Color("4b3f78"), "font_size": 30, "tilt": 2.0})
	await r.closed
	if _woke and socko.visible and not Game.flag("socko_read_pembis"):
		Game.set_flag("socko_read_pembis")
		Dialogue.play("pembis_socko")

## The key light: the shade over the table, on her, throwing her coral up the wall.
func _lights() -> void:
	for f in flat.fittings:
		if f.light.global_position.distance_to(Vector3(2.48, 2.13, 2.6)) < 0.2:
			table_lamp = f
	# the shade over the dinner table: low, warm, on her and the three places laid
	var over := Vector3(2.42, 1.78, 1.4)
	Build.box(world, over + Vector3(0, 0.48, 0), Vector3(0.01, 0.95, 0.01), Tex.mat("black"), false)
	var shade := Build.organic(world, func(st):
		MeshKit.tube(st, [over + Vector3(0, 0.12, 0), over + Vector3(0, 0.0, 0), over + Vector3(0, -0.1, 0)], [0.05, 0.17, 0.24], {"sides": 12, "cap": false}),
		Tex.mat("cloth_red", 4.0, {"tint": Color(1.0, 0.75, 0.5), "emission": Vector3(0.9, 0.5, 0.25), "double": true}))
	var lamp := Fitting.make(world, over + Vector3(0, -0.06, 0), Color("ffc27a"), 2.2, 4.0, "bulb", true)
	lamp.add_glow(shade, Vector3(0.9, 0.5, 0.25))
	shade.name = "LampShade"
	lamp.light.shadow_bias = 0.04
	var cone := Air.beam(lamp, 1.6, 0.9, Color("ffc27a"), 0.025); cone.rotation.x = -PI * 0.5
	cone.name = "LampCone"
	if table_lamp: table_lamp.base *= 0.6
	table_lamp = lamp
	# a cold fill through the window behind her, so she reads against the glass
	Build.lamp(world, Vector3(2.8, 1.6, 0.4), Color("8fa2c0"), 0.5, 2.6)

## The air and the sound of the place.
func _atmosphere() -> void:
	for r in [[Vector3(2.2, 1.4, 2.6), Vector3(2.0, 1.2, 2.4), 900], [Vector3(7.2, 1.4, 4.5), Vector3(2.7, 1.2, 0.7), 300],
			[Vector3(8.8, 1.4, 1.9), Vector3(1.1, 1.2, 1.8), 300], [Vector3(6.0, 1.4, 1.9), Vector3(1.5, 1.2, 1.8), 300]]:
		Air.dust(world, r[0], r[1], r[2])
	Sfx.set_room(0.45, 0.2)
	Sfx.loop("busy", "busy_tone", -26.0, Vector3(9.8, 1.0, 5.0))
	Sfx.loop("tv", "tv_static", -24.0, Vector3(3.38, 1.03, 2.06))
	Sfx.loop("fridge", "hum", -20.0, Vector3(9.6, 1.0, 3.2))
	Sfx.loop("flies", "flies", -14.0, MARTA_POS + Vector3(0, 1.2, 0))
	Sfx.loop("wind", "wind", -26.0, Vector3(2.0, 1.5, -0.3))
	ambient([1.5, 4.0], func(): Sfx.play_at("drip", Vector3(8.0, 0.5, 6.8), -10.0, randf_range(0.9, 1.15)))
	ambient([6.0, 11.0], func(): Sfx.play_at("drip", Vector3(9.2, 0.9, 0.4), -14.0, randf_range(1.2, 1.4)))
	ambient([25.0, 55.0], func(): walk_above(Vector3(randf_range(1, 9), 2.9, randf_range(1, 7)), Vector3(randf_range(1, 9), 2.9, randf_range(1, 7))), 12.0)
	ambient([40.0, 80.0], func(): _pipes(Vector3(1.65, 1.4, 0.2), randi_range(2, 4)), 30.0)
	ambient([20.0, 45.0], func(): Sfx.play_at("groan" if randf() < 0.5 else "creak", Vector3(randf_range(0, 10), 2.6, randf_range(0, 8)), -10.0))
	ambient([90.0, 160.0], func(): Sfx.play_at("siren", Vector3(5.0, 5.0, -30.0), 2.0, 1.0, 60.0), 45.0)
	Hotspot.make(world, Vector3(1.65, 0.45, 0.15), Vector3(0.9, 0.5, 0.25), "Knock on the pipe", _knock_pipe)

func _pipes(at: Vector3, n: int) -> void:
	for i in n:
		Sfx.play_at("pipe_knock", at, -2.0, randf_range(0.92, 1.05), 25.0)
		await get_tree().create_timer(randf_range(0.28, 0.45)).timeout

func _knock_pipe() -> void:
	player.shake(0.003, 0.1)
	for i in 3:
		Sfx.play_at("pipe_knock", Vector3(1.65, 0.5, 0.15), 0.0, 1.0)
		await get_tree().create_timer(0.35).timeout
	Game.make_noise(player.global_position, 0.5)
	await get_tree().create_timer(randf_range(2.0, 3.5)).timeout
	_pipes(Vector3(randf_range(2, 9), randf_range(2.0, 4.0), randf_range(-2.0, 10.0)), 3 if randf() < 0.6 else randi_range(2, 5))

# ------------------------------------------------------------------ the story
func begin() -> void:
	if Game.flag("lobby_note") and not Game.flag("lobby_done"):
		await _return_from_48()
		return
	Game.checkpoint()
	Sfx.loop("drone", "drone", -18.0)
	Fx.reset({"grain": 0.06, "vignette": 0.5})
	set_cutscene(true)
	player.look_enabled = true
	Game.fade(0.0, 3.0)
	await Dialogue.play("knock")
	set_cutscene(false)
	zone(Vector3(9.4, 1.0, 4.5), Vector3(0.8, 2.0, 1.4), func(): Dialogue.play("see_flat"))

func on_event(n: String, _step: Dictionary) -> void:
	match n:
		"knock":
			for i in 3:
				Sfx.play_at("knock", FRONT + Vector3(0.1, 1.3, 0), 0.0, randf_range(0.95, 1.05)); player.shake(0.004, 0.08)
				await get_tree().create_timer(0.36).timeout
		"knock_again":
			for i in 4:
				Sfx.play_at("knock", FRONT + Vector3(0.1, 1.3, 0), 3.0, randf_range(0.9, 1.0)); player.shake(0.006, 0.08)
				await get_tree().create_timer(0.3).timeout
		"marta_stirs":
			# the first movement, and it's small: a finger on the cloth. Then the breath, rattling,
			# as if it had never stopped. The voice will come from under the hair.
			marta.seated_alive = true; marta.agitation = 0.0
			marta._tap = 0.0
			Sfx.loop("marta", "marta_rattle", -16.0, MARTA_POS + Vector3(0, 1.2, 0))
			Sfx.play_at("bone_crack", _face(), -8.0, 0.7)
			Fx.kick("fringe", 0.4, 2.0)
			_reach(0.55)
		"marta_turns":
			marta.agitation = 0.4
			# her head comes up: slowly, the neck cracking on the way, the hair falling off her face;
			# then on past where a head stops. Her good eye finds him.
			var from: Vector3 = marta.base.head
			marta.face(player.cam.global_position, 0.25)
			var to: Vector3 = marta.base.head
			marta.base.head = from
			marta.reveal(1.0, 2.0)
			var tw := create_tween()
			tw.tween_method(func(k): marta.base.head = from.lerp(to, k), 0.0, 1.0, 2.2).set_trans(Tween.TRANS_SINE)
			tw.tween_method(func(k): marta.base.head = to + Vector3(0, 0, 0.55 * k), 0.0, 1.0, 1.4).set_trans(Tween.TRANS_QUAD)
			for i in 4: get_tree().create_timer(0.4 + i * 0.7).timeout.connect(func(): Sfx.play_at("bone_crack", _face(), -4.0, randf_range(0.7, 1.0)))
			get_tree().create_timer(1.6).timeout.connect(_eye_on_him)
			Sfx.set_loop_volume("flies", -30.0)
			Fx.set_k("pulse", 0.35); Fx.set_k("fringe", 0.35)
			_reach(0.85)
		"rub_head":
			Sfx.play("breath", -8.0, 0.85)
			socko.visible = true; socko.hold = "rub"; socko.emotion = "neutral"
			socko.rig.jaw = 0.0
		"socko_reveal":
			socko.hold = "low"
			player.head_override = 1.0
			player.set_roll(0.0)
			await get_tree().create_timer(0.7).timeout
			player.head_override = -1.0
			Sfx.play("sting", -16.0, 1.6)
			socko.look = "kurt"; socko.hold = "face"; socko.emotion = "happy"
		"cross_eyed":
			Sfx.play("board_creak", -6.0, 2.2)
			socko.set_cross_eyed(true)
			await get_tree().create_timer(1.6).timeout
			socko.set_cross_eyed(false)

func _face() -> Vector3:
	return (marta.joints.head as Node3D).global_position + Vector3(0, 0.05, 0)

## Kurt's right hand, reaching out toward her face (k: 0 down out of sight .. 1 at her cheek).
func _reach(k: float) -> void:
	if not hand:
		hand = KurtArm.new(); hand.name = "Hand"
		player.cam.add_child(hand)
		hand.transform = _hand_at(0.0)
		hand.pose_name = "reach"
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var from := hand.get_meta("k", 0.0) as float
	tw.tween_method(func(v): hand.transform = _hand_at(v); hand.set_meta("k", v), from, k, 2.2)

func _hand_at(k: float) -> Transform3D:
	var face := player.cam.global_transform.affine_inverse() * _face()
	var toward := face.normalized()
	var rest := Vector3(0.14, -0.42, -0.25)
	# the hand comes up into view low and right, and goes out toward her face, but never further
	# than an arm's length from the eye: we see the back of it, the fingers reaching
	var near := toward * 0.42 + Vector3(0.06, -0.1, 0.0)
	var at := rest.lerp(near, k)
	var dir := (toward + Vector3(-0.15, 0.35, 0)).normalized()
	return Transform3D(Basis.looking_at(dir, Vector3(0.1, 0.25, 1.0)), at)

func _process(delta: float) -> void:
	_lobby_tick()
	super(delta)
	if not _seen_marta and not _woke and not cutscene and player_sees(_face(), 7.0, 0.8):
		_seen_marta = true
		Fx.kick("fringe", 0.8, 3.0); Fx.kick("pulse", 0.4, 3.0)
		Sfx.play("heartbeat", -12.0)
		Dialogue.play("see_marta")
		marta_spot.prompt = "Look at her"; marta_spot.enabled = true
	_murmur(delta)
	_tells_unseen(delta)
	# after: Socko sees the empty chair
	if _woke and not _chair_line and not cutscene and not Dialogue.busy and player_sees(MARTA_POS + Vector3(0, 0.7, 0), 5.0, 0.8):
		_chair_line = true
		Dialogue.play("socko_chair")
	if _woke and socko.visible and not cutscene and not Dialogue.busy and socko.look != "ahead" and socko.look != "gun":
		socko.look = "ahead"
	if hole_parts.visible and not cutscene:
		Fx.set_k("fringe", clampf(1.0 - player.global_position.distance_to(HOLE) / 4.0, 0.0, 1.0) * 0.8)

## Kurt goes to her and bends to look; she talks; she takes hold of him.
func _investigate() -> void:
	marta_spot.enabled = false
	set_cutscene(true)
	Sfx.set_loop_volume("marta", -14.0)
	Sfx.loop("heart", "heart_loop", -20.0)
	var tvh := create_tween(); tvh.tween_method(func(v): Sfx.set_loop_volume("heart", v), -20.0, -8.0, 14.0)
	var stand := marta.to_global(Vector3(0.0, 0, -1.25))      # across the table from her, leaning over it
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(player, "global_position", stand, 1.4)
	player.look_toward(_face() + Vector3(0, -0.03, 0), 1.4)
	player.crouching = false       # standing, leaning over the table: looking down at the crown of her head
	await tw.finished
	await player.look_toward(_face(), 0.6)
	await Dialogue.play("investigate_marta")
	await _grab()

func _eye_on_him() -> void:
	marta.gaze = player.cam.global_position
	Sfx.play_at("click", _face(), -10.0, 1.4)

func _grab() -> void:
	await _dead_air()
	await _the_jump()
	if hand: hand.visible = false
	var toward := (MARTA_POS - player.global_position) * Vector3(1, 0, 1)
	var tw := create_tween()
	tw.tween_property(player, "global_position", player.global_position + toward.normalized() * 0.3, 0.12)
	player.shake(0.03, 0.6)
	await tw.finished
	await get_tree().create_timer(0.55).timeout
	# and throws him: across the room, end over end, into the wall by the hall door
	var start := player.global_position
	var y0 := player.get_yaw(); var p0 := player.get_pitch()
	player.crouching = false
	Sfx.play("thud", -6.0, 1.4)
	var fly := create_tween()
	fly.tween_method(func(k):
		player.global_position = start.lerp(LAND, k) + Vector3(0, sin(k * PI) * 0.9, 0)
		player.set_view(y0 + k * 0.6, p0 + k * 1.6)
		player.set_roll(k * 1.1), 0.0, 1.0, 0.75).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await fly.finished
	Sfx.play("thud", 4.0, 0.8); Sfx.play("glass", -4.0, 0.7)
	player.shake(0.06, 0.3)
	Fx.kick("drain", 1.0, 0.3)
	await Game.fade(1.0, 0.06)
	await _blackout()

# ------------------------------------------------------------------ the scare
## Before he's seen her: murmuring, under her breath, from the living room. It stops the moment
## he sees her (she's heard him).
func _murmur(delta: float) -> void:
	if _seen_marta or _woke: return
	_murmur_t -= delta
	if _murmur_t > 0.0: return
	_murmur_t = randf_range(1.8, 3.6)
	if player.global_position.x < 10.2:
		Sfx.play_at("whisper", _face(), -13.0, randf_range(0.72, 0.86))

## While he's in the room with her and not looking, she changes. Never on camera; twice at most:
## her head has come round toward him; her hand has moved, and a nail ticks on the plate.
func _tells_unseen(delta: float) -> void:
	if not _seen_marta or _woke or cutscene or _tells >= 2: return
	if player.global_position.distance_to(MARTA_POS) > 6.5: _unseen_t = 0.0; return
	if player_sees(_face(), 8.0, 0.7): _unseen_t = minf(_unseen_t, 0.0); return
	_unseen_t += delta
	if _unseen_t < 1.4: return
	_unseen_t = -2.5
	_tells += 1
	var head: Node3D = marta.joints.head
	if _tells == 1:
		var r: Vector3 = head.rotation
		marta.face(player.cam.global_position, MartaSeated.JAW_REST)
		head.rotation = Vector3(r.x, lerpf(r.y, head.rotation.y, 0.7), r.z * 0.4)
		marta.base.head = head.rotation
		(marta.joints.jaw as Node3D).rotation = Vector3(-MartaSeated.JAW_REST, 0, 0); marta.base.jaw = (marta.joints.jaw as Node3D).rotation
	else:
		var w: Node3D = marta.joints.wrR; var e: Node3D = marta.joints.elR
		w.rotation += Vector3(0.35, -0.2, 0.0); e.rotation += Vector3(0.12, -0.1, 0.0)
		marta.base.wrR = w.rotation; marta.base.elR = e.rotation
		Sfx.play_at("click", _face() + Vector3(0, -0.45, 0), -15.0, 0.55)

## Dead air. Everything she's been doing stops; the flat's own sounds fall away; she's still,
## the eye on him. Then the jaw: down, and down, past where a jaw stops.
func _dead_air() -> void:
	marta.seated_alive = false
	for l in ["marta", "flies", "heart", "drone", "tv", "busy", "fridge", "wind"]: Sfx.stop_loop(l)
	var wb := AudioServer.get_bus_index("World")
	_world_db = AudioServer.get_bus_volume_db(wb)
	create_tween().tween_method(func(v): AudioServer.set_bus_volume_db(wb, v), _world_db, _world_db - 18.0, 0.6)
	Fx.set_k("pulse", 0.0)
	Sfx.play("breath", -16.0, 0.75)          # his, held
	await get_tree().create_timer(0.9).timeout
	Sfx.play("creak", -12.0, 0.5)
	marta.unhinge(1.15, 1.6)
	await get_tree().create_timer(1.9).timeout

## The bulb goes, and it's dark: really dark, not a fade. All that's left of her is the faint sick
## light of the coral. In the dark she gets up: the wet tearing as she comes loose of the chair,
## then up in three jerks, each with a crack. She stands across the table, the head tilting. Then
## she comes over the table at him. His torch snaps on in his hand and she's there, her face in his,
## her hands either side of his head. (One change from dark to light: inside the photosensitivity
## rule.)
func _the_jump() -> void:
	var wb := AudioServer.get_bus_index("World")
	# the bulb, and with it every light in the room: dark
	Sfx.play("glass", -2.0, 1.7); Sfx.play("switch", 0.0, 0.6)
	_room_dark(true)
	player.torch_on = false; player.torch.light_energy = 0.0
	if hand: hand.visible = false          # he snatches it back
	# her, on her feet, in place of her at the table: still folded into the chair's shape
	(marta.joints.hips as Node3D).visible = false
	jumper.global_position = MARTA_POS; jumper.rotation.y = marta.rotation.y
	jumper.position.y = -0.42
	_pose_jumper({"hip_l": Vector3(1.45, 0, 0.08), "hip_r": Vector3(1.4, 0, -0.08), "kn_l": Vector3(-1.5, 0, 0), "kn_r": Vector3(-1.45, 0, 0),
		"spine": Vector3(-0.35, 0, 0), "neck": Vector3(-0.3, 0, 0), "head": Vector3(-0.5, 0.2, 0.3), "jaw": Vector3(1.6, 0, 0),
		"sh_l": Vector3(0.2, 0, 0.1), "sh_r": Vector3(0.2, 0, -0.1), "el_l": Vector3(-0.3, 0, 0), "el_r": Vector3(-0.3, 0, 0)})
	jumper.snap = 60.0
	jumper.gaze = player.cam.global_position
	jumper.visible = true
	var glow := OmniLight3D.new(); glow.name = "CoralGlow"; glow.light_color = Color("9adfb0"); glow.light_energy = 0.4; glow.omni_range = 1.8
	glow.shadow_enabled = false; jumper.add_child(glow); glow.position = Vector3(0, 1.25, -0.15)
	Sfx.play("breath", -10.0, 0.7)                         # his
	await get_tree().create_timer(0.7).timeout
	# coming loose of the chair
	Sfx.play_at("squelch", MARTA_POS + Vector3(0, 0.6, 0), 0.0, 0.6)
	Sfx.play_at("scrape", MARTA_POS + Vector3(0, 0.3, 0), -4.0, 0.6)
	await get_tree().create_timer(0.5).timeout
	# up, in three jerks
	jumper.snap = 22.0
	for i in 3:
		var k := float(i + 1) / 3.0
		Sfx.play_at("bone_crack", MARTA_POS + Vector3(0, 1.0, 0), -2.0, randf_range(0.6, 0.9))
		var tw := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(jumper, "position:y", lerpf(-0.42, 0.0, k), 0.12)
		_pose_jumper({"hip_l": Vector3(1.45 * (1.0 - k), 0, 0.08), "hip_r": Vector3(1.4 * (1.0 - k), 0, -0.08),
			"kn_l": Vector3(-1.5 * (1.0 - k), 0, 0), "kn_r": Vector3(-1.45 * (1.0 - k), 0, 0),
			"spine": Vector3(-0.35 + 0.3 * k, 0, 0.1 * k), "head": Vector3(-0.5 + 0.55 * k, 0.2, 0.3 + 0.2 * k)})
		await get_tree().create_timer(0.45).timeout
	# still, standing across the table: the head going over
	jumper.snap = 3.0
	_pose_jumper({"head": Vector3(0.15, 0, 0.95), "neck": Vector3(0.1, 0, 0.3)})
	Sfx.play_at("click", MARTA_POS + Vector3(0, 1.5, 0), -6.0, 0.6)
	await get_tree().create_timer(0.9).timeout
	# over the table at him
	var c: Transform3D = player.cam.global_transform
	var fwd := -c.basis.z; fwd.y = 0.0; fwd = fwd.normalized()
	var to := c.origin + fwd * 0.75
	var land := Vector3(to.x, 0.0, to.z)
	var from := jumper.global_position
	jumper.snap = 40.0
	_pose_jumper({"spine": Vector3(-0.6, 0, 0.1), "neck": Vector3(0.45, 0, 0.1), "head": Vector3(0.25, 0, 0.5), "jaw": Vector3(1.8, 0, 0),
		"sh_l": Vector3(1.25, 0.35, 0.3), "sh_r": Vector3(1.25, -0.35, -0.3), "el_l": Vector3(-0.35, 0, 0), "el_r": Vector3(-0.35, 0, 0),
		"hip_l": Vector3(-0.5, 0, 0.1), "hip_r": Vector3(-0.3, 0, -0.1), "kn_l": Vector3(-0.9, 0, 0), "kn_r": Vector3(-0.6, 0, 0)})
	Sfx.play_at("whoosh", MARTA_POS + Vector3(0, 1.2, 0), 0.0, 0.6)
	var lunge := create_tween()
	lunge.tween_method(func(k):
		jumper.global_position = from.lerp(land, k) + Vector3(0, sin(k * PI) * 0.45, 0), 0.0, 1.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await lunge.finished
	# her face at his: settle her so her eyes are level with his
	var dy: float = (c.origin.y + 0.02) - jumper.head_pos().y
	jumper.global_position.y += dy
	# the torch, in his hand, on: her (not at full: at this range it would blow her out white)
	player.torch_on = true; player.torch.light_energy = 1.6
	glow.light_energy = 0.0
	AudioServer.set_bus_volume_db(wb, _world_db)
	Sfx.play("switch", -4.0, 1.2)
	Sfx.play("marta_scream", 6.0, 0.92); nerve.spike(0.8)
	Sfx.play("gasp", 2.0, 1.1)
	player.shake(0.05, 0.9)
	player.set_view(player.get_yaw(), player.get_pitch() + 0.12)     # he flinches back
	Fx.kick("fringe", 2.5, 1.5); Fx.kick("tear", 1.0, 1.2); Fx.set_k("pulse", 0.6)
	Engine.time_scale = 0.4
	get_tree().create_timer(0.45, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)
	await get_tree().create_timer(0.5).timeout
	player.torch_on = false

## Every light within six metres of her out (the bulb took the circuit with it), remembered so the
## blackout can put them back.
var _darkened: Array = []
var _shade_glow = Vector3.ZERO
func _room_dark(dark: bool) -> void:
	if dark:
		_darkened = []
		var fits: Array = flat.fittings.duplicate()
		if table_lamp and not fits.has(table_lamp): fits.append(table_lamp)
		for fi in fits:
			if is_instance_valid(fi) and (fi as Node3D).global_position.distance_to(MARTA_POS) < 6.0 and fi.on:
				_darkened.append(fi); fi.on = false
		for l in world.find_children("*", "Light3D", true, false):
			var lt := l as Light3D
			if lt.visible and lt.global_position.distance_to(MARTA_POS) < 6.0 and not player.is_ancestor_of(lt) and not (lt.get_parent() is Fitting) and not jumper.is_ancestor_of(lt):
				_darkened.append(lt); lt.visible = false
		var cone := world.find_child("LampCone", true, false)
		if cone: _darkened.append(cone); (cone as Node3D).visible = false
		var shade := world.find_child("LampShade", true, false) as MeshInstance3D
		if shade and shade.material_override is ShaderMaterial:
			_shade_glow = (shade.material_override as ShaderMaterial).get_shader_parameter("emission")
			(shade.material_override as ShaderMaterial).set_shader_parameter("emission", Vector3.ZERO)
			set_meta("shade_off", true)
	else:
		set_meta("shade_off", false)
		for x in _darkened:
			if not is_instance_valid(x): continue
			if x is Fitting: x.on = true
			else: (x as Node3D).visible = true
		_darkened = []

func _pose_jumper(p: Dictionary) -> void:
	for k in p: jumper.pose[k] = p[k]

## Dark. Ringing. His heart. Somewhere, the front door slams. When he comes to, she isn't there.
func _blackout() -> void:
	Sfx.stop_loop("drone"); Sfx.stop_loop("heart"); Sfx.stop_loop("tv"); Sfx.stop_loop("busy")
	Fx.set_k("pulse", 0.0); Fx.set_k("fringe", 0.0)
	Sfx.play("tinnitus", -6.0)
	for i in 3:
		Sfx.play("heartbeat", -6.0 - i * 3.0); await get_tree().create_timer(1.1).timeout
	front_door.slam(); front_door.blocked = true
	await get_tree().create_timer(1.6).timeout
	for i in 2:
		Sfx.play("heartbeat", -12.0); await get_tree().create_timer(1.3).timeout
	# she's gone; where she was, the chair and the coral, broken where she tore loose
	(marta.joints.hips as Node3D).visible = false
	jumper.visible = false
	_room_dark(false)
	if table_lamp: table_lamp.kind = "bulb"
	if hand: hand.queue_free(); hand = null
	balcony_door.locked = false
	if world.has_node("WardrobeSpot"): (world.get_node("WardrobeSpot") as Hotspot).prompt = "Push wardrobe"
	outside.visible = true
	env.environment.background_color = Color(0.93, 0.93, 0.92); env.environment.background_energy_multiplier = 1.0
	# on the floor, on his back, looking at the ceiling
	player.global_position = LAND
	player.head_override = 0.28
	player.set_view(-PI * 0.55, 1.1); player.set_roll(0.35)
	player.crouching = false
	await get_tree().create_timer(0.8).timeout
	Sfx.loop("drone", "drone", -16.0)
	Sfx.loop("tv", "tv_static", -22.0, Vector3(3.38, 1.03, 2.06))
	Sfx.loop("goo", "goo_loop", -12.0, HOLE + Vector3(0, 0.3, -0.2))
	Fx.set_k("double_k", 1.0); Fx.set_k("fringe", 0.8); Fx.set_k("drain", 0.35)
	var clear := create_tween()
	clear.tween_method(func(k): Fx.set_k("double_k", k); Fx.set_k("fringe", 0.8 * k); Fx.set_k("drain", 0.35 * k), 1.0, 0.0, 16.0).set_delay(3.0)
	Fitting._brown = 0.15
	get_tree().create_timer(2.5).timeout.connect(func(): Fitting._brown = 1.0)
	Game.fade(0.0, 3.5)
	player.look_toward(Vector3(2.0, 1.6, 3.0), 3.0)
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
	if not Game.flag("award_woke"): Game.set_flag("award_woke"); Skills.award("infection", 1, "something in you")

func _on_front_door_tried(_d) -> void:
	if not _woke or Game.flag("door_tried"): return
	Game.set_flag("door_tried")
	await Dialogue.play("door_locked")
	objective("Find another way out.")
	socko.interest = wardrobe.global_position + Vector3(0, 1.0, 0)

func _on_wardrobe_pushed() -> void:
	goo_seep.visible = false
	(flat.doors.dStore as Node3D).visible = false
	hole_parts.visible = true
	socko.interest = null
	Sfx.play("sting", -10.0, 0.8); nerve.spike(0.4)
	Fx.kick("tear", 0.5, 0.8)
	Sfx.stop_loop("goo"); Sfx.loop("goo", "goo_loop", -2.0, HOLE + Vector3(0, 0.5, 0))
	_spurts()
	await player.look_toward(HOLE + Vector3(0, 0.9, 0), 0.9)
	await Dialogue.play("wardrobe_hole")
	set_cutscene(false)
	hole_spot.prompt = "Crawl in"; hole_spot.enabled = true
	if not Game.pistol.have:
		objective("Go where Socko's pointing.")
		socko.look = "gun"
	else:
		objective("The hole where the box room was.")

func _spurts() -> void:
	while is_inside_tree():
		goo_spurt.emitting = true
		Sfx.play_at("squelch", HOLE + Vector3(0, 0.5, 0), -2.0, randf_range(0.8, 1.1))
		await get_tree().create_timer(randf_range(0.4, 0.9)).timeout
		goo_spurt.emitting = false
		await get_tree().create_timer(randf_range(1.5, 4.0)).timeout

func _on_gun_taken(_p) -> void:
	socko.look = "ahead"
	socko.gesture("bounce")
	if hole_parts.visible: objective("The hole where the box room was.")

func _on_balcony() -> void:
	if not _woke or Game.flag("balcony_seen"): return
	Game.set_flag("balcony_seen")
	set_cutscene(true)
	await player.look_toward(sticky_at, 1.0)
	set_cutscene(false)
	Dialogue.play("balcony")

func _ready() -> void:
	super()
	zone(Vector3(2.25, 1.0, -1.1), Vector3(3.0, 2.0, 1.1), _on_balcony, false)

## Kurt gets down and crawls into it. The light goes blue, then there is only the sound of it.
## The next level loads behind the black at the end of this.
func _crawl() -> void:
	hole_spot.enabled = false
	random_talk = false
	set_cutscene(true)
	socko.hold = "low"; socko.look = "ahead"; socko.emotion = "nervous"
	var front := HOLE + Vector3(0, 0, -0.9)
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(player, "global_position", front, 0.9)
	player.look_toward(HOLE + Vector3(0, 0.6, 1.0), 0.9)
	await tw.finished
	player.head_override = 0.45
	await get_tree().create_timer(0.6).timeout
	Sfx.play("crawl", -2.0)
	Fx.tint(Color(0.45, 0.6, 1.0, 0.6), 3.0)
	Fx.set_k("fringe", 1.2)
	var tr := create_tween(); tr.tween_method(func(v): Fx.set_k("tear", v), 0.0, 0.8, 4.0)
	var in_t := create_tween()
	in_t.tween_property(player, "global_position", HOLE + Vector3(0.05, 0.25, 1.0), 2.6)
	player.look_toward(HOLE + Vector3(0.2, 0.4, 3.0), 2.0)
	await get_tree().create_timer(1.3).timeout
	Sfx.play("crawl", -2.0, 0.9)
	Sfx.play("squelch", 0.0, 0.7)
	await get_tree().create_timer(0.6).timeout
	Game.set_flag("crawled_in")
	var on := create_tween(); on.tween_property(player, "global_position", HOLE + Vector3(0.2, 0.15, 2.2), 3.0)
	Game.change_level("flesh47", {"fade": 1.4})


# ------------------------------------------------------------------ back from 48 (docs/FLAT48.md)
## Across the landing from 48 with LOBBY in his hand: 47 as he left it (her gone from the chair,
## the white where outside was, the sticky note that says "outside" past the balcony). LOBBY on
## "outside", and outside is the lobby.
var lobby_spot: Hotspot
var lobby: Node3D
var _lobby_zone := false
func _return_from_48() -> void:
	_woke = true
	(marta.joints.hips as Node3D).visible = false
	jumper.visible = false
	_room_dark(false)
	if table_lamp: table_lamp.kind = "bulb"
	if hand: hand.queue_free(); hand = null
	marta_spot.enabled = false
	hole_spot.enabled = false
	balcony_door.locked = false
	front_door.blocked = false; front_door.locked = false
	outside.visible = true
	env.environment.background_color = Color(0.93, 0.93, 0.92); env.environment.background_energy_multiplier = 1.0
	socko.visible = true; socko.hold = "out"; socko.look = "ahead"; socko.emotion = "neutral"
	Sfx.loop("drone", "drone", -18.0)
	Fx.reset({"grain": 0.06, "vignette": 0.5})
	# on the landing, in front of 47's door, the note in his hand
	player.global_position = Vector3(11.9, 0, 4.56)
	player.set_view(PI * 0.5, 0.0)
	_hand_note("LOBBY")
	# the railing's edge: where the note goes on "outside"
	lobby_spot = Hotspot.make(world, Vector3(2.25, 1.3, -1.6), Vector3(3.3, 1.8, 0.1), "Stick \"LOBBY\" on outside", _to_lobby)
	lobby_spot.enabled = false
	Game.checkpoint()
	random_talk = true
	set_cutscene(false)
	objective("The balcony.")
	await Game.fade(0.0, 1.0)
	Dialogue.play("f47_back")

## A sticky note in his hand, the word on it (as he took it off 48's wall).
func _hand_note(word: String) -> void:
	var n := Prop.make(world, player.global_position + Vector3(0, 1.4, 0), Vector3(0.08, 0.08, 0.004), Tex.mat("enamel", 1.0, {"tint": Color(1.0, 0.92, 0.42)}), "note: %s" % word, 0.02, 0.05)
	n.collision_layer = 16
	var l := Label3D.new(); l.text = word; l.font_size = 30; l.pixel_size = 0.001
	l.modulate = Color(0.12, 0.12, 0.16); l.outline_size = 0; l.position = Vector3(0, 0, 0.003); l.double_sided = true
	n.add_child(l)
	n.set_meta("word", word)
	player.pick_up(n)

func _holding(word: String) -> bool:
	return player.held != null and String(player.held.get_meta("word", "")) == word

func _lobby_tick() -> void:
	if lobby_spot and is_instance_valid(lobby_spot) and not Game.flag("lobby_done"):
		lobby_spot.enabled = _holding("LOBBY") and lobby == null
	if lobby and not _lobby_zone and player.global_position.z < -3.6:
		_lobby_zone = true
		_into_lobby()

## The note goes out over the rail and onto "outside", over the word; the white goes; the lobby.
func _to_lobby() -> void:
	if not _holding("LOBBY") or lobby: return
	set_cutscene(true)
	lobby_spot.enabled = false
	var n: RigidBody3D = player.held
	player.drop_held()
	n.freeze = true; n.collision_layer = 0; n.liftable = false
	Sfx.play("paper", -2.0, 0.9)
	await player.look_toward(sticky_at, 0.8)
	# (out in the white there's no light to see it by: paper that shows like the big one does)
	var lit := StandardMaterial3D.new(); lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lit.albedo_color = Color("f4e06a"); lit.disable_fog = true; lit.cull_mode = BaseMaterial3D.CULL_DISABLED
	for mi in n.find_children("*", "MeshInstance3D", true, false): (mi as MeshInstance3D).material_override = lit
	for lb in n.find_children("*", "Label3D", true, false): (lb as Label3D).shaded = false; (lb as Label3D).modulate = Color("1d2333")
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var to: Vector3 = sticky_at + Vector3(0, -0.21, 0.15)       # over the word
	tw.tween_property(n, "global_position", to, 1.8)
	tw.parallel().tween_property(n, "scale", Vector3(52, 52, 1), 1.8)
	tw.parallel().tween_property(n, "global_rotation", Vector3(0, 0, -0.035), 1.8)
	await tw.finished
	Sfx.play("paper", 0.0, 0.6)
	await get_tree().create_timer(1.2).timeout
	# the white comes up, and goes, and outside is the lobby
	Game._black.color = Color(0.93, 0.93, 0.92, Game._black.color.a)
	await Game._fade(1.0, 1.4)
	var q := PhysicsRayQueryParameters3D.create(Vector3(2.25, 1.0, -1.2), Vector3(2.25, -1.0, -1.2), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var fy: float = (hit.position as Vector3).y if not hit.is_empty() else 0.0
	outside.visible = false
	n.queue_free()
	env.environment.background_color = Color(0.05, 0.05, 0.06)
	_open_the_rail()
	lobby = Lobby.build(world, fy)
	Sfx.set_room(0.75, 0.32)
	await get_tree().create_timer(0.6).timeout
	await Game._fade(0.0, 1.8)
	Game._black.color = Color(0, 0, 0, 0)
	Game.set_flag("lobby_made")
	set_cutscene(false)
	objective("")
	Dialogue.play("f47_lobby")

## The balcony's rail and its invisible wall: gone, so he can step off into it.
func _open_the_rail() -> void:
	for cs in flat.find_children("*", "CollisionShape3D", true, false):
		var c := cs as CollisionShape3D
		if c.shape is BoxShape3D:
			var p := c.global_position; var sz: Vector3 = (c.shape as BoxShape3D).size
			if absf(p.z + 1.75) < 0.12 and absf(p.x - 2.25) < 0.3 and sz.x > 3.0: c.disabled = true
	for mi in flat.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.mesh: continue
		var a: AABB = m.global_transform * m.get_aabb()
		var ctr := a.get_center()
		if ctr.z < -1.6 and ctr.z > -1.95 and ctr.x > 0.4 and ctr.x < 4.1 and a.size.y < 1.4: m.visible = false

## In: that's as far as it goes, for now.
func _into_lobby() -> void:
	Game.set_flag("lobby_done")
	await get_tree().create_timer(1.5).timeout
	set_cutscene(true)
	await Dialogue.play("f47_lobby_in")
	Game.checkpoint()
	# into it: Chapter 2
	Game.change_level("lobby")
