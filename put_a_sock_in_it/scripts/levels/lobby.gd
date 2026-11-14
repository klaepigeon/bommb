extends Level
## Chapter 2: the Lobby (docs/CHAPTER2.md). Kurt comes out of "outside" into the ground floor of
## a building that goes on without him, and has to get to Flat 27, two floors up.
##
## The way up, and the ways round each thing in the way:
##   the stairs        ground to first: open. First to second: meat across the half-landing
##                     (hack / shoot through it: slow, loud, it costs).
##   the lift          needs the mains (the breaker, in maintenance) and a good fuse in the LIFT
##                     slot of the box on the first floor. Fuses: the LIGHT slot has one (take it
##                     and the first floor goes dark, and the things in the walls come out), the
##                     super's desk drawer, a drawer in 14.
##   maintenance       locked: the super's key (if he gives it), the crowbar (from 12, where the
##                     cook lives), or the vent from the laundry (something lives in the vents).
##   the ladder        the closets at the west end: ground (locked like maintenance) to first
##                     (open) to second (the hatch bolted: the crowbar).
##   27's door         meat over it, grown from the thing in the bath in 24: kill it (the one who
##                     feeds it won't let you near), or light the boiler (the mains, a good fuse in
##                     BOILER, the boiler in maintenance) and the heat on the second floor makes it
##                     let go.
## The super's conversation decides what he does about Kurt for the rest of it (Game.rel.super).
## Socko guides, and suggests; what Kurt does about it is kept (flags ch2_obey_* / ch2_defy_*).

const B := preload("res://scripts/levels/chapter2/lobby_build.gd")
const FH := 3.2
const START := Vector3(12.0, 0.0, 1.4)

var built := {}
var nav: NavigationRegion3D
var lift: Lift
var kit: ExportedFlat
var kit_rot: ExportedFlat
var power_on := false
var fuses := {"LIGHT": "good", "LIFT": "", "BOILER": "blown"}
var boiler_on := false
var heat := 0.0
var lights: Array = []          # [OmniLight3D, on Callable, range]
var people := {}                # id -> Inhabitant
var super_npc: Inhabitant
var barricade: Growth
var door27: Growth
var bath: BathThing
var hatch_open := false
var _talked := false
var _said := {}
var _rebake_t := -1.0
var _breaker_pos := Vector3(17.0, 1.3, 0.35)
var _radiators: Array = []
var _steam: Array = []
var _book: Node3D
var _floor_seen := {}
var _socko_watch := {}

func build() -> void:
	add_to_group("level")
	_environment()
	built = B.build(world)
	kit = ExportedFlat.new(0.0, [], true); world.add_child(kit)
	kit_rot = ExportedFlat.new(0.85, [], true); world.add_child(kit_rot)
	_furnish()
	_lights()
	_power_bits()
	_lift()
	_ladder()
	_vent()
	_growths()
	_discoveries()
	_people()
	_restore()
	_batch()
	_bake_nav()
	for d in built.doors.values() + built.closet_doors:
		d.tried.connect(_on_door_tried)
	player.position = START
	player.set_view(0.0, 0.0)
	socko.visible = true

func ao_area() -> Array:
	return [Rect2(-0.5, -0.5, 25.0, 15.0), 0.0, B.CH]      # (the ground floor's)

func ao_name() -> String: return "lobby"

func _environment() -> void:
	var e := env.environment
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.01, 0.01, 0.012)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("2a2a30"); e.ambient_light_energy = 0.32
	e.fog_enabled = true; e.fog_light_color = Color("0b0b0d"); e.fog_density = 0.055
	e.tonemap_mode = Environment.TONE_MAPPER_ACES; e.tonemap_exposure = 1.1
	e.glow_enabled = true; e.glow_intensity = 0.35; e.glow_hdr_threshold = 1.1
	e.adjustment_enabled = true; e.adjustment_saturation = 0.72; e.adjustment_contrast = 1.12

# ------------------------------------------------------------------ the rooms' things
func _piece(src: ExportedFlat, n: String, at: Vector3, rot := 0.0, solid := true) -> Node3D:
	var p := src.piece(n)
	if not p: return null
	world.add_child(p); p.position = at; p.rotation.y = rot
	var s: Vector3 = p.get_meta("size")
	if solid and s.y > 0.25:
		var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := BoxShape3D.new()
		sh.size = Vector3(s.x, s.y, s.z); cs.shape = sh; cs.position.y = s.y * 0.5; sb.add_child(cs); p.add_child(sb)
	return p

func _furnish() -> void:
	var y1 := FH; var y2 := FH * 2.0
	# the lobby: the mailboxes, the directory, a bench, the reception window's counter
	_box(Vector3(15.8, 1.35, 3.0), Vector3(0.3, 1.0, 3.6), Tex.mat("metal", 3.0, {"tint": Color(0.5, 0.55, 0.5)}), true)
	_box(Vector3(9.0, 0.24, 1.0), Vector3(1.6, 0.45, 0.45), Tex.mat("wood", 2.0), true)
	_box(Vector3(7.75, 0.95, 3.5), Vector3(0.6, 0.08, 2.0), Tex.mat("wood_light", 2.0), false)
	# the office: his desk, his chair, the visitors' book
	_box(Vector3(6.2, 0.4, 3.2), Vector3(1.0, 0.8, 1.8), Tex.mat("wood", 2.0), true)
	_piece(kit, "prop_9_Chair", Vector3(5.6, 0.0, 3.0), PI * 0.5, false)
	_book = Node3D.new(); world.add_child(_book); _book.position = Vector3(7.8, 1.0, 3.4)
	var bk := MeshInstance3D.new(); bk.mesh = Build.box_mesh(Vector3(0.3, 0.03, 0.42)); bk.material_override = Tex.mat("paper_boxes", 4.0); _book.add_child(bk)
	# his flat: his bed, her wardrobe, the table
	_piece(kit, "Mesh448", Vector3(2.5, 0.0, 3.0))
	_piece(kit, "prop_34_Wardrobe", Vector3(0.6, 0.0, 1.2), PI * 0.5)
	_piece(kit, "Node135", Vector3(3.8, 0.0, 1.0), PI * 0.5)
	# the laundry: three machines along the north wall, a folding table, lines across
	for i in 3: _box(Vector3(2.4 + i * 0.85, 0.42, 13.55), Vector3(0.7, 0.85, 0.7), Tex.mat("enamel", 2.0, {"tint": Color(0.8, 0.8, 0.75)}), true)
	_box(Vector3(4.5, 0.45, 10.5), Vector3(1.6, 0.9, 0.8), Tex.mat("wood", 2.0), true)
	for i in 3: _box(Vector3(4.2, 2.3, 9.2 + i * 1.3), Vector3(5.0, 0.01, 0.01), Tex.mat("black"), false)
	# maintenance: the breaker panel, the boiler, the freezer
	_box(Vector3(17.0, 1.3, 0.2), Vector3(0.7, 0.9, 0.15), Tex.mat("gunmetal", 2.0), false)
	_box(Vector3(16.8, 1.0, 2.0), Vector3(1.0, 2.0, 1.0), Tex.mat("metal", 2.0, {"tint": Color(0.45, 0.4, 0.35)}), true)
	_box(Vector3(18.6, 0.45, 2.6), Vector3(1.4, 0.9, 0.7), Tex.mat("enamel", 2.0, {"tint": Color(0.85, 0.85, 0.82)}), true)
	# 3, where the big one sleeps: nothing, and what's left of things
	_piece(kit, "Mesh882", Vector3(15.5, 0.0, 12.8), PI)
	# first floor: the cook's kitchen (12), the rearranger's flat (13), storage, 14, 15, 16
	_piece(kit, "Node109", Vector3(6.0, y1, 0.45))
	_piece(kit, "Node102", Vector3(6.7, y1, 0.45))
	_piece(kit, "Node114", Vector3(7.5, y1, 0.45))
	_piece(kit, "Mesh448", Vector3(8.0, y1, 3.0))
	_piece(kit, "Node28", Vector3(10.4, y1, 2.5))
	_piece(kit, "Mesh892", Vector3(1.8, y1, 12.5))
	_piece(kit, "Node137", Vector3(9.4, y1, 13.4))
	_piece(kit, "prop_34_Wardrobe", Vector3(12.0, y1, 13.6))
	_piece(kit, "Mesh882", Vector3(2.0, y1, 2.0))
	for p in [Vector3(12.0, y1, 3.0), Vector3(13.5, y1, 4.5), Vector3(14.5, y1, 2.0)]: _pushable(p)
	# second floor: 22's fridge, 24's bath, rot everywhere
	_piece(kit_rot, "Node114", Vector3(7.0, y2, 0.45))
	_piece(kit_rot, "Mesh448", Vector3(3.0, y2, 3.0))
	_piece(kit_rot, "Node141", Vector3(3.6, y2, 13.5), 0.0)
	_piece(kit_rot, "Node135", Vector3(12.5, y2, 12.0), PI * 0.5)
	_piece(kit_rot, "Node28", Vector3(19.5, y2, 11.0))

## A chair or a box the one in 13 moves about (and anyone can push): RigidBody, group "pushable".
func _pushable(at: Vector3) -> void:
	var p := Prop.make(world, at + Vector3(0, 0.45, 0), Vector3(0.6, 0.9, 0.6), Tex.mat("cardboard", 3.0), "box", 14.0, 0.6)
	p.add_to_group("pushable")
	p.liftable = false

func _box(at: Vector3, size: Vector3, m: Material, solid: bool) -> MeshInstance3D:
	return Build.box(world, at, size, m, solid)

# ------------------------------------------------------------------ light
## Steady bulbs. The ground floor's are on their own circuit (always); the first floor's corridor
## and rooms on the mains and the LIGHT fuse; the second floor has none but what grows there.
func _lights() -> void:
	var warm := Color("ffcf8a"); var cold := Color("c8d0ff")
	var always := func(): return true
	var floor1 := func(): return power_on and fuses.LIGHT == "good"
	var main := func(): return power_on
	for p in [Vector3(12.0, 2.6, 3.0), Vector3(9.0, 2.6, 7.0), Vector3(4.0, 2.6, 11.0), Vector3(6.5, 2.5, 3.0), Vector3(17.5, 2.6, 7.0)]:
		_bulb(p, warm, 1.2, 6.0, always)
	_bulb(Vector3(17.0, 2.5, 1.5), cold, 0.9, 4.5, main)                   # maintenance
	_bulb(Vector3(2.5, 2.5, 3.0), Color("ffb070"), 0.7, 4.0, always)       # his flat (the lamp he leaves on)
	for x in [4.0, 10.0, 16.0]: _bulb(Vector3(x, FH + 2.6, 7.0), warm, 1.0, 6.0, floor1)
	for id in ["flat12", "flat14"]: _bulb(B.centre(id, 2.5), warm, 0.9, 5.0, floor1)
	_bulb(Vector3(19.2, FH + 2.5, 4.8), cold, 0.7, 3.0, main)              # the fuse closet
	# the second floor: what grows there gives a little sick light, here and there
	for p in [Vector3(5.0, FH * 2 + 2.4, 7.0), Vector3(14.0, FH * 2 + 2.4, 7.0), Vector3(3.8, FH * 2 + 2.0, 11.0)]:
		_bulb(p, Color("ff8a8a"), 0.35, 3.5, always)
	_bulb(Vector3(22.0, 2.8, 7.0), warm, 0.8, 6.0, always)                 # the stairwell, ground
	_bulb(Vector3(22.0, FH + 2.8, 7.0), warm, 0.6, 6.0, main)

func _bulb(at: Vector3, col: Color, energy: float, rng: float, on: Callable) -> void:
	var o := OmniLight3D.new(); o.light_color = col; o.light_energy = energy; o.omni_range = rng; o.omni_attenuation = 1.1
	o.shadow_enabled = false
	world.add_child(o); o.position = at
	var b := MeshInstance3D.new(); b.mesh = Build.box_mesh(Vector3(0.05, 0.07, 0.05))
	b.material_override = Tex.mat("enamel", 1.0, {"emission": Vector3(1.4, 1.2, 0.8)}); world.add_child(b); b.position = at + Vector3(0, 0.15, 0)
	lights.append([o, on, rng, energy, b])

func _update_lights() -> void:
	Sfx.set_loop_volume("water15", -6.0 if power_on else -80.0)
	for l in lights:
		var on: bool = (l[1] as Callable).call()
		(l[0] as OmniLight3D).light_energy = l[3] if on else 0.0
		(l[4] as MeshInstance3D).visible = on

## Lit enough to be seen by (and to keep the things in the walls away).
func lit(p: Vector3) -> bool:
	var f := B.floor_of(p)
	for l in lights:
		var lp: Vector3 = (l[0] as Node3D).global_position
		if (l[0] as OmniLight3D).light_energy > 0.0 and B.floor_of(lp - Vector3(0, 2.0, 0)) == f and p.distance_to(lp) < float(l[2]) * 0.6: return true
	return false

## Somewhere dark near p, on its floor (the ones who hate the light go there).
func dark_spot_near(p: Vector3) -> Vector3:
	var f := B.floor_of(p)
	var best := p; var bd := INF
	for id in ["flat11", "flat13", "flat15", "storage", "flat21", "flat23", "flat25", "flat26"]:
		var c := B.centre(id)
		if B.floor_of(c) != f: continue
		if lit(c + Vector3(0, 0.6, 0)): continue
		var d := c.distance_to(p)
		if d < bd: bd = d; best = c
	return best

# ------------------------------------------------------------------ the mains, the fuses, the boiler
func _power_bits() -> void:
	Use.make(world, _breaker_pos + Vector3(0, 0, 0.12), Vector3(0.7, 0.9, 0.2),
		func(): return "Throw the breaker off" if power_on else "Throw the breaker on",
		func(_p): set_power(not power_on, player))
	Use.make(world, Vector3(16.8, 1.0, 2.55), Vector3(1.0, 1.6, 0.2),
		func(): return "" if boiler_on else ("Light the boiler" if power_on and fuses.BOILER == "good" else "The boiler (dead)"),
		func(_p): if power_on and fuses.BOILER == "good": light_boiler())
	# the fuse box: three slots on the closet's back wall, first floor
	var y := FH + 1.4
	var i := 0
	for slot in ["LIGHT", "LIFT", "BOILER"]:
		var at := Vector3(18.75 + i * 0.4, y, 3.78)
		_box(at + Vector3(0, 0, -0.02), Vector3(0.3, 0.4, 0.04), Tex.mat("gunmetal"), false)
		var lb := Label3D.new(); lb.text = slot; lb.font_size = 20; lb.pixel_size = 0.0012; lb.modulate = Color(0.85, 0.85, 0.8)
		lb.shaded = true; world.add_child(lb); lb.position = at + Vector3(0, 0.27, 0.01)
		var s: String = slot
		Use.make(world, at + Vector3(0, 0, 0.06), Vector3(0.3, 0.4, 0.1), func(): return _fuse_prompt(s), func(_p): _fuse_use(s))
		i += 1
	# radiators along the second floor's corridor (cold until the boiler's lit)
	for x in [3.0, 9.0, 15.0]:
		var r := _box(Vector3(x, FH * 2 + 0.5, 6.2), Vector3(1.0, 0.6, 0.1), Tex.mat("enamel", 3.0, {"tint": Color(0.6, 0.55, 0.5)}), false)
		_radiators.append(r)

func _fuse_prompt(slot: String) -> String:
	match String(fuses[slot]):
		"good": return "Take the fuse (%s)" % slot
		"blown": return "Take the burnt-out fuse (%s)" % slot
	return ("Fit a fuse (%s)" % slot) if Game.count("fuse") > 0 else ""

func _fuse_use(slot: String) -> void:
	match String(fuses[slot]):
		"good": fuses[slot] = ""; Game.add_item("fuse")
		"blown": fuses[slot] = ""; Game.add_item("burnt fuse")
		_:
			if not Game.take_item("fuse"): return
			fuses[slot] = "good"
	Sfx.play_at("switch", Vector3(19.2, FH + 1.4, 3.8), -2.0, 0.8)
	Game.flags["ch2_fuses"] = fuses.duplicate()
	_update_lights()
	if fuses.LIGHT != "good" and power_on: _line_once("socko_dark")

func set_power(on: bool, by: Node = null) -> void:
	if on == power_on: return
	power_on = on
	Game.flags["ch2_power"] = on
	Sfx.play_at("door_slam", _breaker_pos, -2.0, 1.6)
	Sfx.play_at("buzz", _breaker_pos, -6.0, 0.7)
	Game.make_noise(_breaker_pos, 0.7)
	_update_lights()
	if not on and boiler_on: boiler_on = false; Game.flags["ch2_boiler"] = false
	if by == player and on:
		# he hears it go on: unless it was his idea, he minds
		var d := Game.disposition("super")
		if d != "cooperative" and d != "deceived" and super_npc and not super_npc.dead:
			Game.rel_of("super").suspicion += 1.5
			if super_npc.global_position.distance_to(_breaker_pos) < 16.0: Dialogue.play("super_sees_power")
		_super_react()
		Game.checkpoint()

## The super's way of turning it back off (hostile).
func sabotage_point() -> Vector3:
	return Vector3(17.0, 0.0, 1.0)

func sabotage(_npc) -> void:
	if power_on: set_power(false, _npc)

func light_boiler() -> void:
	boiler_on = true
	Game.flags["ch2_boiler"] = true
	Sfx.play_at("pipe_knock", Vector3(16.8, 1.2, 2.0), 2.0, 0.6)
	Sfx.loop("boiler", "boiler_loop", -6.0, Vector3(16.8, 1.0, 2.0))
	Game.make_noise(Vector3(16.8, 1.0, 2.0), 0.6)
	_line_once("heat_on")
	Game.checkpoint()

# ------------------------------------------------------------------ the lift, the ladder, the vent
func _lift() -> void:
	lift = Lift.new(); lift.floors = [0.0, FH, FH * 2.0]; lift.size = Vector2(1.9, 2.25)
	lift.powered = func(): return power_on and fuses.LIFT == "good"
	world.add_child(lift); lift.position = Vector3(B.SHAFT.get_center().x, 0.0, B.SHAFT.get_center().y)
	for f in 3:
		var ff: int = f
		Use.make(world, Vector3(18.45, f * FH + 1.25, 6.12), Vector3(0.25, 0.3, 0.15),
			func(): return "Call the lift" if not lift.moving else "",
			func(_p): _ride_call(ff))
	var up := Use.make(lift.car, lift.car.global_position + Vector3(0.85, 1.25, -0.4), Vector3(0.15, 0.3, 0.3),
		func(): return ("Up" if lift.at < 2 else "Down to the ground") if not lift.moving else "",
		func(_p): _ride(lift.at + 1 if lift.at < 2 else 0))
	var down := Use.make(lift.car, lift.car.global_position + Vector3(0.85, 1.0, -0.8), Vector3(0.15, 0.25, 0.3),
		func(): return "Down" if lift.at > 0 and not lift.moving else "",
		func(_p): _ride(lift.at - 1))
	lift.arrived.connect(func(f): if f == 2: _reached_second())

func _ride_call(f: int) -> void:
	if not lift.is_powered():
		Sfx.play_at("switch", Vector3(18.45, f * FH + 1.25, 6.12), -4.0, 1.3)
		if Game.flag("ch2_seen_fusebox"): _line_once("socko_fuse_hint")
		return
	lift.call_to(f)

func _ride(f: int) -> void:
	if not lift.is_powered():
		Sfx.play("switch", -6.0, 1.3); return
	set_cutscene(true)
	await lift.ride(f)
	set_cutscene(false)

func _ladder() -> void:
	for f in 3:
		var ff: int = f
		var at := Vector3(0.5, f * FH, 7.0)
		_box(at + Vector3(-0.35, 1.5, 0), Vector3(0.05, 3.0, 0.5), Tex.mat("gunmetal"), false)
		if f < 2:
			Use.make(world, at + Vector3(0, 1.5, 0), Vector3(0.6, 1.6, 0.8),
				func(): return _ladder_up_prompt(ff),
				func(_p): _climb(ff, ff + 1))
		if f > 0:
			Use.make(world, at + Vector3(0, 0.4, 0), Vector3(0.6, 0.6, 0.8),
				func(): return "Climb down" if (ff != 2 or hatch_open) else "",
				func(_p): _climb(ff, ff - 1))

func _ladder_up_prompt(f: int) -> String:
	if f == 1 and not hatch_open:
		return "Pry the hatch open (crowbar)" if Game.count("crowbar") > 0 else ""
	return "Climb up"

func _climb(from: int, to: int) -> void:
	if from == 1 and to == 2 and not hatch_open:
		if Game.count("crowbar") <= 0: return
		hatch_open = true; Game.flags["ch2_hatch"] = true
		Sfx.play_at("door_slam", Vector3(0.5, FH * 2, 7.0), 0.0, 0.7)
		Game.make_noise(Vector3(0.5, FH * 2, 7.0), 0.8)
		return
	set_cutscene(true)
	var tw := create_tween()
	for i in 4: tw.tween_callback(func(): Sfx.play_at("metal", player.global_position + Vector3(0, 1, 0), -10.0, randf_range(1.3, 1.6))).set_delay(0.35)
	await Game.fade(1.0, 0.4)
	player.global_position = Vector3(0.8, to * FH + 0.05, 7.0)
	await Game.fade(0.0, 0.5)
	set_cutscene(false)
	if to == 2: _reached_second()

func _vent() -> void:
	var a := Vector3(6.6, 0.3, 13.8); var b := Vector3(19.6, 0.3, 0.3)
	for v in [[a, b], [b, a]]:
		_box(v[0] + Vector3(0, 0.05, 0), Vector3(0.6, 0.4, 0.05), Tex.mat("metal", 4.0), false)
		var from: Vector3 = v[0]; var to: Vector3 = v[1]
		Use.make(world, from + Vector3(0, 0.1, 0), Vector3(0.7, 0.6, 0.3), func(): return "Crawl into the vent", func(_p): _crawl(from, to))

func _crawl(from: Vector3, to: Vector3) -> void:
	set_cutscene(true)
	Sfx.play_at("drawer", from, -2.0, 0.6)
	Game.make_noise(from, 0.35)
	await Game.fade(1.0, 0.5)
	for i in 5:
		Sfx.play("scrape", -8.0, randf_range(1.2, 1.4))
		Sfx.play("thud", -16.0, randf_range(1.5, 1.8))
		await get_tree().create_timer(0.7).timeout
	# something lives in here
	var c: Inhabitant = people.get("crawler_vent")
	if c and not c.dead:
		Sfx.play("vent_scrabble", 2.0, 1.0); Sfx.play("marta_rattle", 0.0, 1.3)
		await get_tree().create_timer(0.4).timeout
		player.hurt(0.2, player.global_position + Vector3(0, 0, 1))
		c.set_physics_process(true); c.visible = true; c.collision_layer = 8 | 32
		c.global_position = to + (Vector3(0, 0, 1.2) if to.z < 7.0 else Vector3(0, 0, -1.2))
		c.awareness = 1.0; c.target = player; c.objective = "attack"
	player.global_position = to + (Vector3(0, -0.25, 0.9) if to.z < 7.0 else Vector3(0, -0.25, -0.9))
	player.set_view(PI if to.z < 7.0 else 0.0, 0.0)
	await Game.fade(0.0, 0.6)
	set_cutscene(false)

# ------------------------------------------------------------------ meat
func _growths() -> void:
	barricade = Growth.new(); barricade.size = Vector3(3.9, 2.6, 0.7)
	world.add_child(barricade); barricade.position = Vector3(22.0, FH + 1.6, 13.45)
	barricade.cleared.connect(func(_g): Game.flags["ch2_barricade"] = true; _rebake_t = 1.0)
	door27 = Growth.new(); door27.size = Vector3(1.5, 2.3, 0.5)
	world.add_child(door27); door27.position = Vector3(17.5, FH * 2, 7.75)
	door27.hp = 99999.0       # (no: not this one. It lets go, or it doesn't)
	door27.cleared.connect(func(_g): Game.flags["ch2_door27"] = true; _rebake_t = 1.0; _line_once("door27_clear"); Game.checkpoint())
	bath = BathThing.new(); world.add_child(bath); bath.position = Vector3(3.6, FH * 2 + 0.05, 13.5)
	bath.died.connect(func(_b):
		Game.flags["ch2_bath_dead"] = true
		_socko_outcome("bath", true)
		await get_tree().create_timer(2.5).timeout
		door27.recede())

# ------------------------------------------------------------------ what there is to find
func _discoveries() -> void:
	# the directory by the door: names, and one scratched out
	var dir := _box(Vector3(8.12, 1.6, 1.2), Vector3(0.04, 0.9, 0.7), Tex.mat("wood", 3.0, {"tint": Color(0.4, 0.3, 0.2)}), false)
	var names := "1  VOROBYOV  G. & L.\n2  KRAVETS\n3  —\n11  BELOVA\n12  ORLOV\n13  ZAITSEV\n14  LEBEDEV\n15  —\n16  POPOVA\n21  —\n22  —\n24  KOSTINA\n27  ████████"
	var lb := Label3D.new(); lb.text = names; lb.font_size = 22; lb.pixel_size = 0.0011; lb.modulate = Color(0.9, 0.86, 0.75)
	lb.shaded = true; lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT; world.add_child(lb)
	lb.position = Vector3(8.15, 1.6, 1.2); lb.rotation.y = PI * 0.5
	# the mailboxes: his (1) is stuffed with letters from Tula; 2 has a key taped inside
	Use.make(world, Vector3(15.6, 1.6, 1.6), Vector3(0.2, 0.25, 0.3),
		func(): return "Mailbox 1" if not Game.flag("ch2_letters") else "",
		func(_p): _letters())
	Use.make(world, Vector3(15.6, 1.6, 2.0), Vector3(0.2, 0.25, 0.3),
		func(): return "Mailbox 2" if not Game.flag("ch2_took_key2") else "",
		func(_p): Game.set_flag("ch2_took_key2"); Game.add_item("key2"); Sfx.play("pickup", -4.0))
	# his desk drawer (a spare fuse), 14's drawer (another), the crowbar in 12, 16's key in 14
	_take_spot("office_fuse", Vector3(6.2, 0.75, 3.9), "Search the drawer", "fuse")
	_take_spot("f14_fuse", Vector3(9.4, FH + 0.4, 13.0), "Search the drawer", "fuse")
	_take_spot("crowbar", Vector3(5.6, FH + 1.3, 0.2), "Take the crowbar", "crowbar")
	_take_spot("f14_key16", Vector3(6.0, FH + 0.9, 13.6), "Take the key", "key16")
	_take_spot("f16_shells", Vector3(19.0, FH + 0.9, 13.6), "Take the shells", "shells", 4)
	_take_spot("f2_battery", Vector3(10.5, 0.9, 13.5), "Take the battery", "battery")
	# his flat: her coat, her bag, the wedding photograph with her face scratched away
	Use.make(world, Vector3(0.4, 1.4, 3.2), Vector3(0.4, 1.0, 0.6), func(): return "Her coat", func(_p): _note("ch2_coat", "A woman's winter coat on the hook by the door. Her gloves are still in the pockets."))
	Use.make(world, Vector3(2.5, 0.9, 3.4), Vector3(0.5, 0.3, 0.4), func(): return "Handbag", func(_p): _note("ch2_bag", "Her handbag. Her passport is in it, and her purse, and a train ticket to Tula, never punched.\n\nVorobyova L. A."))
	Use.make(world, Vector3(4.9, 1.6, 1.0), Vector3(0.1, 0.4, 0.4), func(): return "Photograph", func(_p): _note("ch2_photo", "A wedding photograph. Him, younger, in a suit. Her face has been scratched out with something sharp, carefully, all the way through."))
	# the freezer in maintenance: padlocked, humming; her slippers beside it
	_box(Vector3(18.0, 0.03, 2.1), Vector3(0.25, 0.05, 0.1), Tex.mat("fabric", 3.0, {"tint": Color(0.7, 0.5, 0.6)}), false)
	Use.make(world, Vector3(18.6, 0.95, 2.6), Vector3(1.4, 0.2, 0.7), func(): return "Chest freezer" if not Game.flag("ch2_freezer") else "", func(_p): Game.set_flag("ch2_freezer"); Dialogue.play("wife_freezer"))
	Sfx.loop("freezer", "hum", -14.0, Vector3(18.6, 0.5, 2.6))
	# 15: the floor under water, a cable down in it from the ceiling. Dead till the mains are on;
	# then it fizzes, and anything that walks in it (it or Kurt) gets the lot
	var wc := B.centre("flat15")
	var water := _box(Vector3(wc.x, FH + 0.02, wc.z), Vector3(4.6, 0.02, 5.6), Tex.mat("glass", 2.0, {"tint": Color(0.25, 0.28, 0.3), "rough": 0.05}), false)
	water.name = "Water15"
	_box(Vector3(wc.x + 0.6, FH + 1.5, wc.z), Vector3(0.03, 3.0, 0.03), Tex.mat("black"), false)
	var hz := Hazard.new(); hz.half = Vector3(2.3, 0.3, 2.8); hz.dps = 70.0; hz.kind = "shock"
	hz.on = func(): return power_on
	world.add_child(hz); hz.position = Vector3(wc.x, FH, wc.z)
	Sfx.loop("water15", "buzz", -80.0, Vector3(wc.x, FH + 0.3, wc.z))
	# the end: 27's door, once it's clear
	var d27: Door = built.doors.get("flat27")
	if d27: d27.opened.connect(func(_d): _enter_27())

func _take_spot(key: String, at: Vector3, prompt: String, item: String, n := 1) -> void:
	if Game.flag("ch2_took_" + key): return
	var u := Use.make(world, at, Vector3(0.4, 0.3, 0.4), func(): return "" if Game.flag("ch2_took_" + key) else prompt,
		func(_p):
			Game.set_flag("ch2_took_" + key)
			if item == "battery": Game.torch_charge = 1.0
			else: Game.add_item(item, n)
			Sfx.play("pickup", -4.0)
			_took(key))
	u.name = "Take_" + key

func _letters() -> void:
	Game.set_flag("ch2_letters")
	Sfx.play("paper", -4.0)
	var r := NoteReader.open(self, "Lyuda,\n\nWhy don't you write? Mama asks every Sunday. Gena says you're fine and too busy to come to the telephone. Too busy for three years?\n\nWrite, or I'm coming myself.\n\nVera\nTula, March 1996", {"ink": Color("2e3a5e"), "font_size": 24})
	await r.closed
	Dialogue.play("wife_letter")
	Game.rel_of("kurt")
	Dialogue.apply([{"know": ["kurt", "wife_letters"]}])

func _note(key: String, text: String) -> void:
	Game.set_flag(key)
	NoteReader.open(self, text, {"ink": Color("2a2a2a"), "font_size": 24})
	_trespass_check()

func _took(key: String) -> void:
	if key == "office_fuse": _trespass_check()
	if key == "crowbar": _cook_notices()

# ------------------------------------------------------------------ the people
## The building's population (profiles: Inhabitant's header). Each goes about its business
## from the start, Kurt or no Kurt.
func _people() -> void:
	var y1 := FH; var y2 := FH * 2.0
	# stations: where they do what they do
	for i in 3: Station.make(world, "washer", Vector3(2.4 + i * 0.85, 0.0, 12.9), 0.0, {"activity": "bang", "secs": 9.0, "sound": "washer", "sound_db": -4.0, "noise": 0.25, "noise_every": 4.0})
	Station.make(world, "fold", Vector3(4.5, 0.0, 11.3), 0.0, {"activity": "work", "secs": 8.0, "sound": "paper", "sound_db": -14.0})
	Station.make(world, "line", Vector3(3.0, 0.0, 9.5), 0.0, {"activity": "stir", "secs": 6.0})
	Station.make(world, "desk", Vector3(5.6, 0.0, 3.0), -PI * 0.5, {"activity": "sit", "secs": 30.0, "sound": "super_breath", "sound_db": -8.0})
	Station.make(world, "mailbox", Vector3(15.0, 0.0, 2.0), -PI * 0.5, {"activity": "work", "secs": 7.0, "sound": "keys", "sound_db": -8.0})
	Station.make(world, "laundry_watch", Vector3(4.2, 0.0, 8.6), 0.0, {"activity": "stand", "secs": 14.0, "sound": "super_breath", "sound_db": -10.0})
	Station.make(world, "maint", Vector3(17.2, 0.0, 1.0), 0.0, {"activity": "work", "secs": 8.0, "sound": "keys", "sound_db": -8.0})
	Station.make(world, "stove", Vector3(6.0, y1, 1.0), 0.0, {"activity": "stir", "secs": 14.0, "sound": "stove", "sound_db": -4.0, "noise": 0.15, "noise_every": 5.0})
	Station.make(world, "chop", Vector3(8.0, y1, 2.2), 0.0, {"activity": "bang", "secs": 8.0, "sound": "bone_crack", "sound_db": -6.0, "noise": 0.3, "noise_every": 2.0})
	Station.make(world, "chute", Vector3(19.0, y1, 7.0), PI * 0.5, {"activity": "work", "secs": 4.0, "sound": "metal", "sound_db": -6.0, "noise": 0.4, "noise_every": 3.5})
	Station.make(world, "meat", Vector3(7.0, y2, 1.0), 0.0, {"activity": "work", "secs": 4.0, "sound": "flesh_tear", "sound_db": -8.0, "item": "meat"})
	Station.make(world, "bath", Vector3(3.6, y2, 12.8), 0.0, {"activity": "feed", "secs": 9.0, "sound": "flesh_tear", "sound_db": -6.0})
	var corridor0 := [Vector3(3.0, 0, 7.0), Vector3(10.0, 0, 7.0), Vector3(17.0, 0, 7.0), Vector3(12.0, 0, 3.0)]
	var corridor1 := [Vector3(3.0, y1, 7.0), Vector3(10.0, y1, 7.0), Vector3(17.0, y1, 7.0), Vector3(22.0, y1, 7.0)]
	var skin := Color(0.82, 0.74, 0.66)
	_spawn({"id": "laundress", "faction": "residents", "hostile_to": [], "hp": 45, "speed": 0.8, "run": 2.0, "hearing": 0.6,
		"body": {"height": 1.98, "girth": 0.8, "arm": 1.35, "neck": 1.6, "head": 0.85, "hunch": 0.5, "eyes": "sewn", "mouth": 0.7, "apron": Color(0.6, 0.6, 0.55), "dress": Color(0.35, 0.3, 0.32), "hair": true, "hair_tint": Color(0.5, 0.5, 0.48), "tint": skin, "fingers": 1.5},
		"territory": [Vector3(1.5, -0.5, 8.0), Vector3(7.0, 3.0, 14.0)], "voice": "whisper", "attack": {"dmg": 0.12, "reach": 1.2, "windup": 0.6, "cool": 1.6},
		"objectives": [{"type": "work", "stations": ["washer", "fold", "line"], "weight": 1.0}]}, Vector3(4.0, 0, 12.0))
	_spawn({"id": "hunter", "faction": "hunter", "asleep": true, "hostile_to": ["kurt", "residents"], "hp": 130, "poise": 55, "speed": 1.2, "run": 2.9, "hearing": 0.8,
		"sight": {"range": 11.0, "cos": 0.45}, "attack": {"dmg": 0.34, "reach": 1.55, "windup": 0.55, "cool": 1.5},
		"body": {"height": 2.05, "girth": 1.4, "arm": 1.45, "head": 0.65, "neck": 0.5, "mouth": 1.7, "eyes": "many", "hunch": 0.75, "lumps": 0.6, "tint": Color(0.68, 0.58, 0.52), "fingers": 1.6, "naked": true},
		"voice": "marta_breath", "voice_attack": "marta_rattle", "step": "step_concrete",
		"objectives": [{"type": "hunt", "targets": ["residents"], "weight": 1.0}, {"type": "patrol", "points": corridor0 + corridor1, "wait": 4.0, "weight": 0.6}]}, Vector3(15.0, 0, 11.0))
	_spawn({"id": "listener", "faction": "listener", "hostile_to": ["kurt", "residents", "hunter", "super"], "blind": true, "hearing": 1.9, "hp": 70, "speed": 0.7, "run": 3.1,
		"attack": {"dmg": 0.3, "reach": 1.4, "windup": 0.35, "cool": 1.3},
		"body": {"height": 1.85, "girth": 0.75, "neck": 2.2, "head": 1.25, "eyes": "none", "mouth": 1.3, "arm": 1.2, "fingers": 1.8, "tint": Color(0.86, 0.8, 0.78), "naked": true},
		"voice": "sniff", "voice_every": 0.6,
		"objectives": [{"type": "patrol", "points": corridor1, "wait": 6.0, "weight": 1.0}]}, Vector3(4.0, y1, 7.0))
	_spawn({"id": "rearranger", "faction": "residents", "hostile_to": [], "hp": 80, "speed": 0.9, "run": 2.0, "hearing": 0.5,
		"body": {"height": 1.5, "girth": 1.35, "belly": 0.5, "extra_joint": true, "eyes": "normal", "dress": Color(0.3, 0.32, 0.4), "tint": skin, "hunch": 0.3},
		"voice": "groan", "voice_every": 1.5,
		"objectives": [{"type": "push", "to": [Vector3(12.0, y1, 4.5), Vector3(14.5, y1, 1.5), Vector3(11.0, y1, 6.9), Vector3(13.5, y1, 6.9)], "weight": 1.0}]}, Vector3(13.0, y1, 3.0))
	_spawn({"id": "cook", "faction": "residents", "hostile_to": [], "hp": 90, "poise": 40, "speed": 1.0, "run": 2.4, "hearing": 0.9,
		"territory": [Vector3(5.0, y1 - 0.5, 0.0), Vector3(10.0, y1 + 3.0, 6.0)], "attack": {"dmg": 0.3, "reach": 1.4, "windup": 0.5, "cool": 1.4},
		"body": {"height": 1.8, "girth": 1.2, "belly": 0.8, "mouth": 1.4, "eyes": "normal", "apron": Color(0.7, 0.65, 0.6), "tint": skin, "fingers": 1.3, "head": 0.9},
		"voice": "marta_breath",
		"objectives": [{"type": "work", "stations": ["stove", "chop", "stove", "chute"], "weight": 1.0}]}, Vector3(7.0, y1, 2.0))
	_spawn({"id": "crawler_f1", "faction": "walls", "hostile_to": ["kurt"], "fear_light": true, "hp": 28, "poise": 10, "speed": 1.4, "run": 3.4,
		"sight": {"range": 8.0, "cos": 0.3}, "hearing": 1.2, "attack": {"dmg": 0.17, "reach": 1.1, "windup": 0.25, "cool": 0.9},
		"body": {"height": 1.0, "hunch": 1.3, "arm": 1.7, "extra_joint": true, "eyes": "many", "mouth": 1.5, "tint": Color(0.6, 0.55, 0.6), "naked": true, "neck": 0.4},
		"voice": "vent_scrabble", "step": "step_flesh",
		"objectives": [{"type": "patrol", "points": corridor1, "wait": 2.0, "weight": 1.0}]}, B.centre("flat15"))
	_spawn({"id": "crawler_vent", "faction": "walls", "hostile_to": ["kurt"], "fear_light": true, "hp": 24, "poise": 10, "speed": 1.4, "run": 3.4,
		"sight": {"range": 8.0, "cos": 0.3}, "hearing": 1.2, "attack": {"dmg": 0.17, "reach": 1.1, "windup": 0.25, "cool": 0.9},
		"body": {"height": 0.95, "hunch": 1.3, "arm": 1.7, "extra_joint": true, "eyes": "many", "mouth": 1.5, "tint": Color(0.55, 0.5, 0.55), "naked": true, "neck": 0.4},
		"voice": "vent_scrabble", "objectives": [{"type": "patrol", "points": [Vector3(19.0, 0, 2.0), Vector3(17.5, 0, 0.8)], "weight": 0.2}]}, Vector3(-30, 0, -30))
	_spawn({"id": "crawler_f2", "faction": "walls", "hostile_to": ["kurt"], "fear_light": true, "hp": 28, "poise": 10, "speed": 1.4, "run": 3.4,
		"sight": {"range": 8.0, "cos": 0.3}, "hearing": 1.2, "attack": {"dmg": 0.17, "reach": 1.1, "windup": 0.25, "cool": 0.9},
		"body": {"height": 1.0, "hunch": 1.3, "arm": 1.7, "extra_joint": true, "eyes": "many", "mouth": 1.5, "tint": Color(0.6, 0.45, 0.5), "naked": true},
		"voice": "vent_scrabble", "objectives": [{"type": "patrol", "points": [B.centre("flat23"), B.centre("flat21"), Vector3(9.0, y2, 7.0)], "wait": 3.0, "weight": 1.0}]}, B.centre("flat23"))
	_spawn({"id": "caretaker", "faction": "carers", "hostile_to": [], "hp": 85, "poise": 35, "speed": 0.9, "run": 2.6, "hearing": 1.0,
		"territory": [Vector3(1.5, y2 - 0.5, 8.0), Vector3(6.0, y2 + 3.0, 14.0)], "attack": {"dmg": 0.28, "reach": 1.3, "windup": 0.45, "cool": 1.3},
		"body": {"height": 1.62, "girth": 0.95, "hunch": 0.65, "eyes": "sewn", "mouth": 0.6, "dress": Color(0.18, 0.12, 0.14), "hair": true, "hair_tint": Color(0.15, 0.1, 0.1), "tint": Color(0.8, 0.7, 0.68), "lumps": 0.3},
		"voice": "whisper",
		"objectives": [{"type": "carry", "from": "meat", "to": "bath", "weight": 1.0}]}, B.centre("flat22"))
	# the super: naked, starved-thin, wet, his keys on a cord round his neck. Nobody here is human; he
	# was the least human of them before any of it
	super_npc = _spawn({"id": "super", "faction": "super", "hostile_to": [], "keys": true, "hp": 220, "poise": 90, "speed": 0.95, "run": 2.3, "hearing": 1.1,
		"sight": {"range": 13.0, "cos": 0.4}, "attack": {"dmg": 0.4, "reach": 1.5, "windup": 0.6, "cool": 1.7},
		"body": {"height": 1.84, "girth": 0.82, "mouth": 1.9, "eyes": "normal", "head": 1.05, "neck": 1.35, "hunch": 0.35, "keys_front": 0.1, "fingers": 1.55,
			"tint": Color(0.52, 0.49, 0.38), "wet": 0.85, "naked": true, "keys": true, "lumps": 0.15, "repugnant": true, "slide": 0.55},
		"voice": "super_breath", "voice_attack": "super_grunt", "voice_die": "groan", "step": "step_flesh", "twitch": false,
		"objectives": [{"type": "work", "stations": ["desk", "mailbox", "desk", "laundry_watch", "desk", "maint"], "weight": 1.0},
			{"type": "follow", "who_rel": "super", "weight": 1.0},
			{"type": "relock", "doors": [built.doors.get("maint"), built.closet_doors[0], built.doors.get("flat1")], "weight": 1.0},
			{"type": "sabotage", "weight": 1.0}, {"type": "hunt_kurt", "weight": 1.0}]}, Vector3(5.6, 0, 3.0))
	super_npc.rotation.y = -PI * 0.5
	# the one in the vents isn't anywhere until it is (the crawl)
	var cv: Inhabitant = people.crawler_vent
	cv.set_physics_process(false); cv.visible = false; cv.collision_layer = 0
	super_npc.attacked.connect(func(_w, t): if t == player: Game.rel_of("super").hostility = maxf(4.0, float(Game.rel_of("super").hostility)))
	super_npc.died.connect(func(_w): Game.set_flag("ch2_super_dead"); _socko_outcome("super", true))
	for id in people:
		var n: Inhabitant = people[id]
		n.died.connect(func(w): Game.flags["ch2_dead_" + w.id] = true)
	people.hunter.attacked.connect(func(_w, t): if t == people.laundress: _socko_suggest("laundress"))

func _spawn(prof: Dictionary, at: Vector3) -> Inhabitant:
	var n := Inhabitant.new(prof); n.level = self; n.player = player
	world.add_child(n); n.global_position = at
	people[prof.id] = n
	return n

## Their work, done (stations call back): the laundry, the meat to the bath.
func station_done(_n, _s) -> void:
	pass

func delivered(n, s, _item) -> void:
	if n.id == "caretaker" and s.kind == "bath" and bath and not bath.dead:
		bath.fed += 1.0
		Sfx.play_at("flesh_tear", bath.global_position + Vector3(0, 0.8, 0), -2.0, 0.6)

# ------------------------------------------------------------------ the super
func begin() -> void:
	Sfx.loop("bed", "lobby_bed", -10.0)
	Sfx.set_room(0.7, 0.3, 0.5)
	Fx.reset({"grain": 0.07, "vignette": 0.55, "drain": 0.05})
	_update_lights()
	Game.chapter = 2
	await Game.fade(0.0, 1.2)
	if Game.flag("ch2_talked"):
		_talked = true
		_after_talk()
		set_cutscene(false)
		objective("Flat 27.")
		return
	set_cutscene(false)
	objective("")
	# he's seen him already; he calls him over
	await get_tree().create_timer(2.0).timeout
	await _talk()

func _talk() -> void:
	if _talked: return
	_talked = true
	set_cutscene(true)
	super_npc.set_physics_process(false)
	super_npc.global_position = Vector3(6.9, 0.0, 3.4); super_npc.rotation.y = -PI * 0.5 + PI
	await player.look_toward(super_npc.eye(), 0.9)
	player.global_position = Vector3(8.9, 0, 3.4)
	await player.look_toward(super_npc.eye(), 0.5)
	await Dialogue.play("super_hello")
	Game.set_flag("ch2_talked")
	_after_talk()
	set_cutscene(false)
	objective("Flat 27.")
	Game.checkpoint()

## The conversation's events.
func on_event(n: String, _step: Dictionary) -> void:
	match n:
		"super_looks", "super_stare":
			super_npc.body.pose["head"] = Vector3(0.1, 0, 0.0)
			super_npc.body.pose["neck"] = Vector3(0.15, 0, 0)
			if n == "super_stare": Sfx.play_at("super_breath", super_npc.eye(), 0.0, 0.7); player.shake(0.004, 0.6)
		"super_scratch":
			Sfx.play_at("super_scratch", super_npc.eye() + Vector3(0, -0.6, 0), -4.0, 1.0)
			super_npc.body.pose["sh_r"] = Vector3(0.6, 0, -0.4); super_npc.body.pose["el_r"] = Vector3(-1.6, 0, 0)
		"super_book":
			_book.visible = true
			Sfx.play_at("paper", _book.global_position, -6.0, 0.9)
		"super_decides":
			Game.disposition("super")
		"super_gives_key":
			Game.add_item("maint_key")
			Sfx.play_at("keys", super_npc.eye() + Vector3(0, -0.5, 0), 0.0, 1.0)
		"super_done":
			pass

## What he does about Kurt now (and the rest of the chapter, as it changes).
func _after_talk() -> void:
	super_npc.set_physics_process(true)
	_super_react()
	# the big one in 3 has been asleep; not for long (through the wall: the bed going, a door)
	var hu: Inhabitant = people.get("hunter")
	if hu and hu.asleep:
		await get_tree().create_timer(45.0).timeout
		if is_instance_valid(hu) and hu.asleep:
			Sfx.play_at("door_slam", Vector3(14.5, 1.0, 8.0), -2.0, 0.6)
			hu.wake()

func _super_react() -> void:
	if not super_npc or super_npc.dead: return
	var d := Game.disposition("super")
	var h: Array = []
	if d == "hostile": h = ["kurt"]
	super_npc.prof["hostile_to"] = h
	if d == "hostile" and not Game.flag("ch2_super_turned"):
		Game.set_flag("ch2_super_turned")
		Sfx.play_at("super_grunt", super_npc.eye(), 2.0, 0.7)
		# and he lets the one in 11 out (it hears everything)
		if people.has("listener"): people.listener.prof["hearing"] = 2.4
		_socko_suggest("super")

## He finds Kurt in his office, or his flat.
func _trespass_check() -> void:
	if not super_npc or super_npc.dead: return
	var inside := B.in_room("flat1", player.global_position) or B.in_room("office", player.global_position)
	if inside and super_npc.sees(player):
		if Game.flag("ch2_caught_in_flat"): return
		Game.set_flag("ch2_caught_in_flat")
		var deceived := Game.disposition("super") == "deceived"
		Dialogue.play("super_found_out" if deceived else "super_found_in_flat")
		await get_tree().create_timer(3.0).timeout
		_super_react()

func _cook_notices() -> void:
	var c: Inhabitant = people.get("cook")
	if c and not c.dead and c.sees(player):
		c.prof["hostile_to"] = ["kurt"]; c.target = player; c.objective = "attack"; c.awareness = 1.0

func _on_door_tried(d: Door) -> void:
	var id := ""
	for k in built.doors: if built.doors[k] == d: id = k
	if d == built.closet_doors[0]: id = "closet0"
	# keys first, then the crowbar (loud)
	var key: String = {"maint": "maint_key", "closet0": "maint_key", "flat2": "key2", "flat16": "key16"}.get(id, "")
	if key != "" and Game.count(key) > 0:
		d.locked = false; Sfx.play_at("keys", d.global_position + Vector3(0, 1, 0), -2.0, 1.0); d.set_open(true)
		Game.flags["ch2_unlocked_" + id] = true; _rebake_t = 0.5
		return
	if id in ["maint", "closet0", "flat1", "flat2", "flat16"] and Game.count("crowbar") > 0:
		d.locked = false
		Sfx.play_at("door_slam", d.global_position + Vector3(0, 1, 0), 0.0, 1.4); Sfx.play_at("bone_crack", d.global_position + Vector3(0, 1, 0), -2.0, 1.6)
		Game.make_noise(d.global_position, 0.75)
		d.set_open(true)
		Game.flags["ch2_unlocked_" + id] = true; _rebake_t = 0.5
		if id == "flat1": Game.rel_of("super").suspicion += 2.0; _super_react()

# ------------------------------------------------------------------ Socko's ideas
## He suggests; Kurt does, or doesn't. Each kept: flags ch2_obey_<what> / ch2_defy_<what>; his
## anger (Game.rel.socko.anger) climbs with each refusal, and it shows.
func _socko_suggest(what: String) -> void:
	if _socko_watch.has(what): return
	_socko_watch[what] = Time.get_ticks_msec()
	_line_once("socko_suggest_" + what)

func _socko_outcome(what: String, obeyed: bool) -> void:
	if Game.flag("ch2_obey_" + what) or Game.flag("ch2_defy_" + what): return
	Game.set_flag(("ch2_obey_" if obeyed else "ch2_defy_") + what)
	var r := Game.rel_of("socko")
	if obeyed:
		_line_once("socko_obeyed")
	else:
		r["anger"] = float(r.get("anger", 0.0)) + 1.0
		var n := int(r.anger)
		_line_once("socko_defied_%d" % clampi(n, 1, 3))
	_socko_mood()

func _socko_mood() -> void:
	var a := float(Game.rel_of("socko").get("anger", 0.0))
	if Dialogue.busy: return
	socko.emotion = "neutral" if a < 1.0 else ("artificial" if a < 2.0 else ("irritated" if a < 3.0 else "angry"))

func _line_once(id: String) -> void:
	if _said.has(id) or not Dialogue.has(id): return
	_said[id] = true
	if Dialogue.busy: await get_tree().create_timer(2.0).timeout
	if not Dialogue.busy: Dialogue.play(id)

# ------------------------------------------------------------------ going on
func _process(delta: float) -> void:
	super._process(delta)
	if _rebake_t > 0.0:
		_rebake_t -= delta
		if _rebake_t <= 0.0: _bake_nav()
	# heat: the boiler on, the second floor warms; the meat on 27's door lets go of it
	heat = move_toward(heat, 1.0 if (boiler_on and power_on) else 0.0, delta / 25.0)
	if heat > 0.6 and door27 and not door27.gone:
		door27.recede()
		_socko_outcome("bath", false)
	for r in _radiators: (r as MeshInstance3D).material_override = Tex.mat("enamel", 3.0, {"tint": Color(0.6, 0.55, 0.5).lerp(Color(0.95, 0.55, 0.4), heat)})
	if heat > 0.2 and fmod(Time.get_ticks_msec() * 0.001, 3.3) < delta:
		Sfx.play_at("radiator", _radiators[randi() % _radiators.size()].global_position, -6.0, randf_range(0.9, 1.1))
	# hazards hurt him too
	for hz in get_tree().get_nodes_in_group("hazard"):
		if hz.hurts(player.global_position): player.hurt(float(hz.dps) * delta / 100.0, hz.global_position)
	# Socko notices things
	var pf := B.floor_of(player.global_position)
	if not _floor_seen.has(pf): _floor_seen[pf] = true
	if people.has("laundress") and not people.laundress.dead and player.global_position.distance_to(people.laundress.global_position) < 6.0 and lit(people.laundress.global_position + Vector3(0, 1, 0)):
		_line_once("socko_first_inhabitant")
	if people.has("listener") and not people.listener.dead and pf == 1 and player.global_position.distance_to(people.listener.global_position) < 8.0:
		_line_once("socko_listener")
	if pf == 1 and player.global_position.distance_to(Vector3(19.2, FH, 4.8)) < 2.0: Game.set_flag("ch2_seen_fusebox")
	if bath and not bath.dead and pf == 2 and player.global_position.distance_to(bath.global_position) < 4.0: _socko_suggest("bath")
	# the laundry: he said shut them in; did Kurt?
	if _socko_watch.has("laundress") and not (Game.flag("ch2_obey_laundress") or Game.flag("ch2_defy_laundress")):
		var lw: Inhabitant = people.laundress; var hu: Inhabitant = people.hunter
		var ld: Door = built.doors.get("laundry")
		if lw.dead and ld and not ld.is_open: _socko_outcome("laundress", true)
		elif hu.dead or (hu.target == player): _socko_outcome("laundress", false)
		elif Time.get_ticks_msec() - int(_socko_watch.laundress) > 40000 and not lw.dead: _socko_outcome("laundress", false)
	if not Dialogue.busy and fmod(Time.get_ticks_msec() * 0.001, 2.0) < delta: _socko_mood()

func _reached_second() -> void:
	if Game.flag("ch2_reached_2"): return
	Game.set_flag("ch2_reached_2")
	Game.checkpoint()

func _enter_27() -> void:
	if _ending: return
	_ending = true
	set_cutscene(true)
	if super_npc and not super_npc.dead: _socko_outcome("super", false)
	await Dialogue.play("flat27")
	# through the door: 27 (scripts/levels/cathedral.gd), where the chapter ends
	Game.set_flag("ch2_reached_27")
	Game.checkpoint()
	Game.change_level("cathedral")
var _ending := false

## Draw calls: the walls, slabs, stairs and furniture boxes merged into one mesh per material per
## floor per 6 m square (small enough that each still gets its own lights). Not the bulbs (they're
## switched), not the water in 15.
func _batch() -> void:
	var keep := []
	for l in lights: keep.append(l[4])
	var w15 := world.get_node_or_null("Water15")
	if w15: keep.append(w15)
	var buckets := {}
	for n in world.get_children():
		if not (n is MeshInstance3D) or keep.has(n): continue
		var mi := n as MeshInstance3D
		var c: Vector3 = mi.position + mi.get_aabb().get_center()
		var k := Vector3i(int(floor(c.x / 6.0)), int(floor(c.y / FH)), int(floor(c.z / 6.0)))
		if not buckets.has(k): buckets[k] = []
		buckets[k].append(n)
	for k in buckets: Build.merge(world, buckets[k], keep)

## Down: back to the last checkpoint (the building remembers what he changed).
func on_player_down() -> void:
	set_cutscene(true)
	Sfx.play("thud", 2.0, 0.6)
	await Game.fade(1.0, 0.8)
	if not is_inside_tree() or Game.level != self: return      # (something else has the screen now)
	Game.restart_level()

# ------------------------------------------------------------------ remembering
## A checkpoint restores what he did to the building: the mains, the fuses, the boiler, the
## hatch, the doors he opened, the meat he cleared, what he took, who's dead.
func _restore() -> void:
	power_on = bool(Game.flags.get("ch2_power", false))
	boiler_on = bool(Game.flags.get("ch2_boiler", false))
	if boiler_on: heat = 1.0
	var fz = Game.flags.get("ch2_fuses", null)
	if typeof(fz) == TYPE_DICTIONARY: fuses = (fz as Dictionary).duplicate()
	hatch_open = bool(Game.flags.get("ch2_hatch", false))
	for k in Game.flags:
		var key := String(k)
		if key.begins_with("ch2_unlocked_"):
			var id := key.substr(13)
			var d: Door = built.closet_doors[0] if id == "closet0" else built.doors.get(id)
			if d: d.locked = false
		if key.begins_with("ch2_dead_"):
			var who := key.substr(9)
			if people.has(who): people[who].queue_free(); people.erase(who)
	if Game.flag("ch2_barricade"): barricade.queue_free(); barricade = null
	if Game.flag("ch2_door27"): door27.queue_free(); door27 = null
	if Game.flag("ch2_bath_dead"): bath.dead = true; bath.collision_layer = 0; bath.position.y -= 0.35
	if Game.flag("ch2_super_dead"): super_npc = null

## Paths for the inhabitants: baked from the building's walls and floors when it's built, and
## again when a way opens (a door unlocked, meat cleared).
func _bake_nav() -> void:
	if not nav:
		nav = NavigationRegion3D.new(); world.add_child(nav)
	var nm := NavigationMesh.new()
	# (a fine grid: a doorway is barely wider than two of them standing side by side)
	nm.cell_size = 0.1; nm.cell_height = 0.1
	nm.agent_radius = 0.2; nm.agent_height = 1.6; nm.agent_max_climb = 0.3; nm.agent_max_slope = 50.0
	var map := world.get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, 0.1); NavigationServer3D.map_set_cell_height(map, 0.1)
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, world)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	nav.navigation_mesh = nm
