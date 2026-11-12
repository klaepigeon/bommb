extends Level
## Level 2: Flat 47 again, as something that has grown it, and remembers it wrong.
##
## Three copies of the flat, each further gone to meat (ExportedFlat with `flesh` turned up),
## joined where they shouldn't be:
##   A  he slides out of the hole in the box-room doorway into the living room, as if back where he
##      went in, except the walls are coming up red. Her chair is empty. The front door stands open
##      onto nothing.
##   B  through it, the picture tears, and he is coming out of the bathroom door into the hall of
##      another copy, worse. Marta is in this one, on her feet. The balcony door is open.
##   C  through that, another tear: out of the bedroom door into the last copy, nearly all meat.
##      Its front door is the real one. Across the landing, 48 stands open.
## Only the copy he's in is drawn. Caught in B or C: back to the start of that copy.

const COPY := {"A": Vector3(0, 0, 0), "B": Vector3(40, 0, 0), "C": Vector3(80, 0, 0)}
const FLESH := {"A": 0.45, "B": 0.75, "C": 1.0}
const CELL := 0.35
## The flat gone to meat the colour of the hole: deep blue, veins darker still, glowing.
const BLUE := {"meat_dark": Color(0.05, 0.08, 0.26), "meat_light": Color(0.24, 0.42, 0.86), "meat_vein": Color(0.04, 0.02, 0.2),
	"meat_glow": Vector3(0.05, 0.12, 0.45), "paint_tint": Vector3(0.62, 0.72, 1.0), "glass": Color(0.5, 0.6, 1.0, 1.0)}

var flats := {}
var stage := "A"
var marta: MartaHunter
var marta_head: Node3D
var exit_door: ExportDoor
var _encountered := false
var _seen_in_c := false
var _ending := false
var _near := 0.0
var _tearing := false

func build() -> void:
	var e := env.environment
	e.background_mode = Environment.BG_COLOR; e.background_color = Color("03061a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("34406e"); e.ambient_light_energy = 0.4
	e.fog_enabled = true; e.fog_light_color = Color("0a1030"); e.fog_density = 0.03
	e.tonemap_mode = Environment.TONE_MAPPER_ACES; e.tonemap_exposure = 1.25
	for k in COPY:
		var f := ExportedFlat.new(FLESH[k])
		f.meat = BLUE
		f.position = COPY[k]
		world.add_child(f)
		flats[k] = f
		for d in f.doors.values():
			(d as ExportDoor).locked = false
			if d != f.doors.dEntry: (d as ExportDoor).set_open(true)
		_grow(k)
		# the wardrobe stands where he pushed it, in every copy: it remembers that much
		var wr = f.props.get("prop_34_Wardrobe")
		if wr: (wr as Node3D).position.x -= 1.05
	# A: the front door open onto black; B: the balcony door open; C: the front door shut, real
	(flats.A.doors.dEntry as ExportDoor).set_open(true)
	(flats.A.doors.dStore as Node3D).visible = false
	(flats.C.doors.dEntry as ExportDoor).set_open(false)
	exit_door = flats.C.doors.dEntry
	_tear_zone("A", Vector3(10.55, 1.0, 4.56), Vector3(0.6, 2.0, 1.2), "B")
	_tear_zone("B", Vector3(2.3, 1.0, -1.0), Vector3(2.4, 2.0, 1.0), "C")
	_arrival_hole()
	_ammo()
	_marta()
	_landing_48()
	Sfx.set_room(0.85, 0.38, 0.4)
	ambient([2.0, 5.0], func(): Sfx.play_at("drip", player.global_position + Vector3(randf_range(-3, 3), 2.3, randf_range(-3, 3)), -8.0, randf_range(0.6, 0.8)))
	ambient([12.0, 25.0], func(): Sfx.play_at("whisper", _behind_a_wall(), -4.0, randf_range(0.7, 1.0)), 8.0)
	ambient([20.0, 40.0], func(): Sfx.play_at("groan", _behind_a_wall(), -2.0, randf_range(0.6, 0.9)), 15.0)
	ambient([7.0, 15.0], func(): Sfx.play_at("squelch", _behind_a_wall(), -8.0, randf_range(0.5, 0.8)))
	ambient([30.0, 60.0], func(): _knocking(_behind_a_wall()), 20.0)
	_show(stage)

func _p(k: String, local: Vector3) -> Vector3:
	return COPY[k] + local

## What the flat has grown, more in each copy: strands from the ceilings, lumps up the walls,
## goo pooled on the floors.
func _grow(k: String) -> void:
	var f: ExportedFlat = flats[k]
	var r := RandomNumberGenerator.new(); r.seed = k.unicode_at(0)
	var amount: float = FLESH[k]
	var goo := ShaderMaterial.new(); goo.shader = preload("res://shaders/goo.gdshader")
	var meat := ShaderMaterial.new(); meat.shader = preload("res://shaders/ps1_double.gdshader")
	meat.set_shader_parameter("albedo_tex", RotTextures.get_tex("gums")); meat.set_shader_parameter("uv_scale", Vector2(3, 3))
	meat.set_shader_parameter("pulse", 0.01); meat.set_shader_parameter("roughness", 0.25); meat.set_shader_parameter("emission", Vector3(0.06, 0.12, 0.4))
	meat.set_shader_parameter("albedo_color", Color(0.45, 0.6, 1.5))
	var coral := ShaderMaterial.new(); coral.shader = preload("res://shaders/world.gdshader")
	coral.set_shader_parameter("albedo_tex", RotTextures.get_tex("coral")); coral.set_shader_parameter("albedo_color", Color(0.55, 0.65, 0.95))
	var spots := []
	for room in f.level.rooms.values():
		for i in int(6 * amount):
			spots.append(Vector3(r.randf_range(room.x0 + 0.3, room.x1 - 0.3), 0, r.randf_range(room.z0 + 0.3, room.z1 - 0.3)))
	Build.organic(f, func(st):
		for p in spots:
			var L := r.randf_range(0.3, 1.2) * amount
			MeshKit.tube(st, [p + Vector3(0, 2.72, 0), p + Vector3(0.02, 2.72 - L * 0.5, 0), p + Vector3(0, 2.72 - L, 0.02)], [0.03, 0.012, 0.018], {"sides": 5})
			MeshKit.blob(st, p + Vector3(0, 2.7 - L, 0.02), Vector3.ONE * 0.03, {"rings": 3, "segs": 5}), meat)
	Build.organic(f, func(st):
		for p in spots:
			if r.randf() < 0.5: MeshKit.blob(st, p + Vector3(r.randf_range(-0.3, 0.3), 0.0, r.randf_range(-0.3, 0.3)), Vector3(r.randf_range(0.3, 0.6), 0.012, r.randf_range(0.3, 0.6)), {"bumps": 0.3, "freq": 3.0}), goo)
	Build.organic(f, func(st):
		for i in int(30 * amount):
			var room: Dictionary = f.level.rooms.values().pick_random()
			var on_x := r.randf() < 0.5
			var p := Vector3(r.randf_range(room.x0, room.x1) if on_x else (room.x0 + 0.06 if r.randf() < 0.5 else room.x1 - 0.06), r.randf_range(0.0, 2.6), (room.z0 + 0.06 if r.randf() < 0.5 else room.z1 - 0.06) if on_x else r.randf_range(room.z0, room.z1))
			if r.randf() < 0.6: MeshKit.lump(st, p, r.randf_range(0.06, 0.16), r)
			else: MeshKit.coral(st, p, Vector3(r.randf_range(-1, 1), r.randf_range(-0.3, 1.0), r.randf_range(-1, 1)), r.randf_range(0.15, 0.35), 0.03, r, 1), coral)
	# the glands: the copy's own light, pulsing, a few to a room
	for room in f.level.rooms.values():
		var c := Vector3((room.x0 + room.x1) * 0.5, 2.55, (room.z0 + room.z1) * 0.5)
		var col := Color("3a6aff").lerp(Color("6a4aff"), r.randf() * 0.5)
		var fit := Fitting.make(f, c, col, 1.2 + amount, 5.5, "pulse", false)
		fit.mains = false
		var gland := Build.organic(f, func(st): MeshKit.blob(st, c + Vector3(0, 0.12, 0), Vector3(0.16, 0.12, 0.16), {"bumps": 0.3}), meat)
		fit.add_glow(gland, Vector3(col.r, col.g, col.b) * 1.6)
	Air.dust(f, Vector3(5, 1.3, 4), Vector3(5, 1.2, 4), 1200, Color(0.75, 0.85, 1.0))

## The tear: walking into it, the picture rips and he's somewhere else.
func _tear_zone(from: String, local: Vector3, size: Vector3, to: String) -> void:
	var a := Area3D.new(); a.collision_layer = 0; a.collision_mask = 2
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size; cs.shape = sh
	a.add_child(cs); flats[from].add_child(a); a.position = local
	a.body_entered.connect(func(b): if b == player and stage == from and not _tearing: _tear(to))

func _tear(to: String) -> void:
	_tearing = true
	Sfx.play("sting", -6.0, 0.7); Sfx.play("squelch", 0.0, 0.5)
	Fx.kick("tear", 1.5, 1.2); Fx.kick("fringe", 2.0, 1.4); Fx.kick("drain", 0.8, 1.5)
	await Game.fade(1.0, 0.12)
	_place(to)
	await get_tree().create_timer(0.35).timeout
	Game.fade(0.0, 0.6)
	_tearing = false
	if to == "B" and not Game.flag("flesh_B"):
		Game.set_flag("flesh_B"); Game.flags["flesh_stage"] = "B"
		Game.checkpoint()
	elif to == "C":
		Game.flags["flesh_stage"] = "C"; Game.checkpoint()

## Put Kurt at the start of a copy and show only that copy.
func _place(k: String) -> void:
	stage = k
	_show(k)
	match k:
		"A":
			player.global_position = _p("A", Vector3(1.82, 0, 4.4)); player.set_view(0.0, -0.1)
		"B":
			player.global_position = _p("B", Vector3(9.1, 0, 4.7)); player.set_view(0.0, 0.0)          # out of the bathroom door
		"C":
			player.global_position = _p("C", Vector3(7.0, 0, 4.4)); player.set_view(-PI * 0.5, 0.0)    # out of the bedroom door
	player.velocity = Vector3.ZERO
	if marta and k == "C":
		# she follows him through: she's in this one now, waiting in the living room
		_move_marta("C")

func _show(k: String) -> void:
	for key in flats:
		(flats[key] as Node3D).visible = key == k
		(flats[key] as Node3D).process_mode = Node.PROCESS_MODE_INHERIT if key == k else Node.PROCESS_MODE_DISABLED
	Fx.set_k("drain", 0.05 + FLESH[k] * 0.1)

## Where he comes out: the box-room doorway of A, gone to a throat, still dribbling.
func _arrival_hole() -> void:
	var hole := _p("A", Vector3(1.82, 0, 5.2))
	var m := ShaderMaterial.new(); m.shader = preload("res://shaders/ps1_double.gdshader")
	m.set_shader_parameter("albedo_tex", RotTextures.get_tex("gums")); m.set_shader_parameter("uv_scale", Vector2(3, 3))
	m.set_shader_parameter("pulse", 0.012); m.set_shader_parameter("emission", Vector3(0.2, 0.35, 1.0))
	m.set_shader_parameter("albedo_color", Color(0.5, 0.6, 1.4))
	Build.organic(flats.A, func(st):
		for i in 26:
			var a := TAU * i / 26.0
			MeshKit.blob(st, Vector3(1.82, 0.95, 5.16) + Vector3(cos(a) * 0.36, sin(a) * 0.9, 0), Vector3(0.11, 0.13, 0.1), {"bumps": 0.3, "seed": float(i)}), m)
	var goo := ShaderMaterial.new(); goo.shader = preload("res://shaders/goo.gdshader")
	Build.organic(flats.A, func(st): MeshKit.blob(st, Vector3(1.9, 0.0, 4.5), Vector3(0.8, 0.015, 0.6), {"bumps": 0.3, "freq": 3.0}), goo)
	Build.lamp(flats.A, Vector3(1.82, 0.8, 4.6), Color("5a7aff"), 1.0, 3.0)

func _ammo() -> void:
	var a := Pickup.new(); a.item = "ammo"; a.amount = 6; a.label = "box of rounds"
	flats.A.add_child(a); a.position = Vector3(8.3, 0.93, 0.35)
	var mi := MeshInstance3D.new(); mi.mesh = Build.box_mesh(Vector3(0.14, 0.08, 0.1)); mi.material_override = Tex.mat("cardboard", 8.0, {"tint": Color(0.7, 0.8, 0.6)})
	a.add_child(mi)
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(0.3, 0.2, 0.3); cs.shape = sh; a.add_child(cs)

func _marta() -> void:
	marta = MartaHunter.new(); marta.player = player
	world.add_child(marta)
	marta_head = Node3D.new(); marta.add_child(marta_head); marta_head.position.y = 1.7
	marta.caught_player.connect(_on_caught)
	marta.spotted_player.connect(_on_spotted)
	_move_marta("B")

func _move_marta(k: String) -> void:
	var f: ExportedFlat = flats[k]
	marta.evolve(2 if k == "C" else 1)       # she's further along every time he sees her
	if marta.get_parent() != f: marta.reparent(f, false)
	marta.grid = f.nav_grid(CELL)
	marta.cell = CELL; marta.origin = _p(k, Vector3(-0.5, 0, -2.0))
	marta.global_position = _p(k, Vector3(6.2, 0, 4.5))      # the hall
	var tour := []
	for room in ["living", "bedroom", "kitchen", "hall", "child", "bath", "hall"]:
		var r: Dictionary = f.level.rooms[room]
		tour.append(_p(k, Vector3((r.x0 + r.x1) * 0.5, 0, (r.z0 + r.z1) * 0.5)))
	marta.patrol = tour
	marta.set_state("patrol")
	marta.go_to(tour[0])
	socko.points = {"marta": marta_head}

## The landing beyond C's front door: the stairwell, gone soft; 48 across it, open, lit.
func _landing_48() -> void:
	var f: ExportedFlat = flats.C
	Stairwell.build(f, {"tint": Color(0.7, 0.8, 1.0), "pulse": 0.006, "bulb": false, "open48": true})
	Build.box(f, Vector3(12.55, 1.2, 8.6), Vector3(1.6, 2.4, 0.1), Tex.mat("plaster", 1.0, {"emission": Vector3(2.0, 1.7, 1.2)}), false)
	Build.lamp(f, Vector3(12.55, 1.4, 7.8), Color("ffe0b0"), 1.8, 5.0)
	var z := Area3D.new(); z.collision_layer = 0; z.collision_mask = 2
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(3.0, 2.0, 2.0); cs.shape = sh
	z.add_child(cs); f.add_child(z); z.position = Vector3(12.2, 1.0, 5.5)
	z.body_entered.connect(func(b): if b == player: _finale())

# ------------------------------------------------------------------ the story
func begin() -> void:
	Sfx.loop("drone", "flesh_drone", -10.0)
	Sfx.loop("heart", "heart_loop", -26.0)
	Fx.reset({"grain": 0.08, "vignette": 0.62, "fringe": 0.2, "drain": 0.08})
	Fx.tint(Color(0.55, 0.7, 1.0, 0.25), 0.01)
	var at: String = Game.flags.get("flesh_stage", "A") if get_meta("from_checkpoint", false) else "A"
	if at == "A":
		Game.flags.erase("flesh_stage")
		_place("A")
		await _come_out()
	else:
		_encountered = Game.flag("met_marta_maze")
		_place(at)
		Game.fade(0.0, 1.0)
	Game.checkpoint()
	random_talk = true
	set_cutscene(false)
	objective("Find the way out.")
	if not Game.flag("torch_hint"):
		Game.set_flag("torch_hint")
		hud.hint("LIGHT / F: torch. She'll see it too." if Game.uses_touch() else "F: torch. She'll see it too.")

## He slides out of the doorway onto the living room floor, in goo, and gets up.
func _come_out() -> void:
	set_cutscene(true)
	socko.visible = true; socko.hold = "low"; socko.emotion = "nervous"
	var end := player.global_position
	player.global_position = end + Vector3(0, 0.1, 1.0)
	player.head_override = 0.35
	player.set_view(0.0, -0.3)
	Sfx.play("squelch", 2.0, 0.7)
	Game.fade(0.0, 2.5)
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(player, "global_position", end, 1.3)
	await tw.finished
	Sfx.play("thud", -6.0)
	player.shake(0.02, 0.3)
	await get_tree().create_timer(1.0).timeout
	player.head_override = -1.0
	await player.look_toward(_p("A", Vector3(3.0, 1.0, 1.4)), 1.6)
	socko.hold = "out"; socko.emotion = "neutral"

func _process(delta: float) -> void:
	super(delta)
	if not marta: return
	var here: bool = marta.get_parent() == flats[stage]
	if not _encountered and here and not cutscene and (player_sees(marta_head.global_position, 9.0, 0.55) or marta.state == "chase"):
		_encounter()
	# the first sight of her in the last copy: bigger again
	if _encountered and here and stage == "C" and not _seen_in_c and not cutscene and player_sees(marta_head.global_position, 10.0, 0.55):
		_seen_in_c = true
		Dialogue.play("marta_evolved_c")
	if _encountered and not Dialogue.busy:
		if marta.state == "chase": socko.emotion = "nervous"; socko.look = "marta"
		elif socko.look == "marta" and marta.state == "patrol": socko.look = "ahead"; socko.emotion = "neutral"
	random_talk = (not here or marta.state == "patrol") and not _ending
	var near := 0.0
	if here:
		var d := marta.global_position.distance_to(player.global_position)
		near = clampf(1.0 - (d - 2.0) / 10.0, 0.0, 1.0)
		if marta.state == "chase": near = maxf(near, 0.7)
	_near = lerpf(_near, near, 1.0 - exp(-2.0 * delta))
	Sfx.set_loop_volume("heart", lerpf(-26.0, -4.0, _near))
	Fx.set_k("pulse", _near * 0.55)
	Fx.set_k("fringe", 0.2 + FLESH[stage] * 0.2 + _near * 0.9)
	Fx.set_k("tear", 0.25 if (here and marta.state == "chase") else _near * 0.08)
	player.torch_flicker = smoothstep(0.45, 1.0, _near)

func _on_spotted() -> void:
	if not _encountered: _encounter()

## The first time they see each other she stops, and looks at him, and clicks.
func _encounter() -> void:
	_encountered = true
	Game.set_flag("met_marta_maze")
	marta.active = true
	marta.set_state("encounter")
	Sfx.play("sting", -4.0, 0.9)
	Fx.kick("tear", 0.8, 1.2); Fx.kick("drain", 0.5, 2.0)
	await Dialogue.play("marta_maze")
	if marta.state == "encounter":
		marta._last_seen = player.global_position
		marta.set_state("chase")
		marta.go_to(player.global_position)
	# Socko's noticed what's happened to her since the table
	if not Dialogue.busy: Dialogue.play("marta_evolved_b")

func on_event(n: String, _step: Dictionary) -> void:
	if n == "marta_clicks":
		for i in 6:
			Sfx.play_at("click", marta.head(), 4.0, randf_range(0.55, 0.8))
			await get_tree().create_timer(randf_range(0.08, 0.2)).timeout

## Knocking, as Kurt knocked on her door: three, then four.
func _knocking(at: Vector3) -> void:
	for i in 3:
		Sfx.play_at("knock", at, -2.0, randf_range(0.85, 0.95), 25.0); await get_tree().create_timer(0.36).timeout
	await get_tree().create_timer(1.6).timeout
	for i in 4:
		Sfx.play_at("knock", at, 0.0, randf_range(0.8, 0.9), 25.0); await get_tree().create_timer(0.3).timeout

func _behind_a_wall() -> Vector3:
	var a := randf() * TAU
	return player.global_position + Vector3(cos(a) * randf_range(3.0, 6.0), randf_range(0.5, 2.2), sin(a) * randf_range(3.0, 6.0))

## She has him. Back to the start of this copy.
func _on_caught() -> void:
	set_cutscene(true)
	Dialogue.stop()
	random_talk = false
	socko.emotion = "nervous"; socko.gesture("recoil")
	await player.look_toward(marta.head(), 0.25)
	Sfx.play("gasp", 2.0, 0.9)
	player.shake(0.05, 0.6)
	var tw := create_tween(); tw.tween_property(player, "global_position", marta.global_position, 0.5)
	await get_tree().create_timer(0.45).timeout
	Sfx.play("thud", 4.0, 0.7)
	await Game.fade(1.0, 0.1)
	await get_tree().create_timer(1.2).timeout
	Game.restart_level()

## Through the real front door, onto the landing. 48 is open.
func _finale() -> void:
	if _ending: return
	_ending = true
	marta.active = false
	set_cutscene(true)
	Dialogue.stop()
	socko.look = "ahead"; socko.emotion = "curious"
	await player.look_toward(_p("C", Vector3(12.55, 1.5, 8.5)), 1.5)
	var tw := create_tween(); tw.tween_property(player, "global_position", player.global_position + Vector3(0.3, 0, 1.2), 2.5)
	await get_tree().create_timer(2.0).timeout
	Game.set_flag("flat47_done")
	Game.checkpoint()
	await Game.end_chapter("Flat 48", "")
