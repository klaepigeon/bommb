class_name Basement
extends Place
## The basement: the Super's. Down the steps from the lobby, a low concrete cellar, the boiler
## still going, warm water the colour of tea on the floor, and the Super's corner: his cot, his
## ledger, his calendar with the 15th ringed. He's been feeding the furnace. Children's shoes in
## the coal. On the grate, not burnt yet, a drawing: a house with black windows. (Its heart: getting
## the drawing out.)
##
## Ways to the drawing: shut the gas off and wait for it to die down (quiet, slow); turn the hose on
## it (instant, and the steam screams up the stairwell); rake it out with the poker while it's hot;
## or just reach in and pay for it. Anything loud down here brings the Super down his own stairs.
## The padlock on the way in is the Building's (the lobby): his key's in his post box, or break it.

const ZONE := 90
const W := 12.0
const D := 8.0
const H := 2.4
const FURNACE := Vector3(0.95, 0.0, 4.0)       ## (local) its middle, on the floor
const GRATE := Vector3(1.78, 0.62, 4.0)        ## the furnace door
const VALVE := Vector3(2.3, 1.25, 1.1)
const HOSE := Vector3(3.6, 1.0, 7.0)       ## on the tank's face
const ENTRY := Vector3(10.8, 0.0, 6.6)

var heat := 1.0                ## the furnace: 1 roaring, 0 cold
var gas_on := true
var drawing_out := false
var _glow: Lamp
var _glow_mat: ShaderMaterial
var _roar: AudioStreamPlayer3D
var _super_coming := -1.0
var _nav_pts: Array[int] = []

func L(p: Vector3) -> Vector3:
	return at + p

func build_content() -> void:
	name = "Basement"
	var concrete := Mats.tex(Tex.get_tex("concrete"), ZONE, Color(0.62, 0.6, 0.55))
	var damp := Mats.tex(Tex.get_tex("damp"), ZONE, Color(0.7, 0.66, 0.58))
	var iron := Mats.tex(Tex.get_tex("metal"), ZONE, Color(0.32, 0.3, 0.28))
	var rust := Mats.tex(Tex.get_tex("rust"), ZONE)
	var wood := Mats.tex(Tex.get_tex("floorboards"), ZONE, Color(0.7, 0.55, 0.42))
	var k := Kit.new()
	# the room
	k.box(concrete, L(Vector3(W * 0.5, -0.1, D * 0.5)), Vector3(W, 0.2, D))
	k.box(damp, L(Vector3(W * 0.5, H + 0.1, D * 0.5)), Vector3(W, 0.2, D))
	k.box(damp, L(Vector3(W * 0.5, H * 0.5, -0.1)), Vector3(W, H, 0.2))
	k.box(damp, L(Vector3(W * 0.5, H * 0.5, D + 0.1)), Vector3(W, H, 0.2))
	k.box(damp, L(Vector3(-0.1, H * 0.5, D * 0.5)), Vector3(0.2, H, D))
	k.box(damp, L(Vector3(W + 0.1, H * 0.5, D * 0.5)), Vector3(0.2, H, D))
	# the steps up to the lobby, in the north-east corner
	for i in 7:
		k.box(concrete, L(Vector3(11.0 + i * 0.16, 0.1 + i * 0.22, 7.3)), Vector3(0.3, 0.22 + i * 0.44, 1.2))
	k.box(iron, L(Vector3(11.95, 1.9, 7.3)), Vector3(0.06, 1.9, 0.85))            # the door at the top
	# the furnace: iron, riveted, a flue up through the ceiling
	k.box(iron, L(FURNACE + Vector3(0, 0.9, 0)), Vector3(1.5, 1.8, 1.5))
	k.box(rust, L(FURNACE + Vector3(0, 1.85, 0)), Vector3(1.2, 0.12, 1.2))
	k.box(rust, L(FURNACE + Vector3(-0.2, 2.15, 0)), Vector3(0.4, 0.5, 0.4))
	k.box(iron, L(GRATE + Vector3(0.04, -0.3, 0)), Vector3(0.06, 0.08, 0.7))      # the ash lip
	# pipes along the ceiling, and the gas pipe down to the valve
	for z in [1.1, 2.0, 6.2]:
		k.box(rust, L(Vector3(W * 0.5, H - 0.18, z)), Vector3(W, 0.1, 0.1))
	k.box(Mats.flat(Color(0.75, 0.68, 0.2), ZONE), L(Vector3(VALVE.x, 1.3, VALVE.z - 0.12)), Vector3(0.07, 2.2, 0.07))
	# the tank and the hose
	k.box(rust, L(Vector3(3.6, 0.85, 7.45)), Vector3(1.2, 1.7, 0.7))
	k.box(Mats.flat(Color(0.12, 0.12, 0.1), ZONE), L(HOSE + Vector3(0, -0.4, 0.07)), Vector3(0.4, 0.4, 0.06))
	# the coal, and what's in it
	var rng := RandomNumberGenerator.new(); rng.seed = 90
	var coal := Mats.flat(Color(0.07, 0.065, 0.06), ZONE)
	for i in 14:
		k.blob(coal, L(Vector3(1.4 + rng.randf_range(-0.7, 0.7), rng.randf_range(0.05, 0.35), 6.8 + rng.randf_range(-0.6, 0.6))), Vector3(0.35, 0.25, 0.35), rng, 0.4)
	for i in 4:
		var c: Color = [Color(0.5, 0.1, 0.08), Color(0.25, 0.3, 0.5), Color(0.7, 0.66, 0.6), Color(0.45, 0.35, 0.2)][i]
		k.box(Mats.flat(c, ZONE), L(Vector3(1.0 + i * 0.3, 0.42, 6.4 + (i % 2) * 0.3)), Vector3(0.09, 0.07, 0.17), Basis(Vector3.UP, i * 0.9))
	# his corner: a cot, a table, a chair, a shelf
	k.box(wood, L(Vector3(10.9, 0.35, 1.0)), Vector3(1.9, 0.12, 0.8))
	k.box(Mats.tex(Tex.get_tex("cloth"), ZONE, Color(0.45, 0.42, 0.36)), L(Vector3(10.9, 0.45, 1.0)), Vector3(1.8, 0.1, 0.75))
	k.box(wood, L(Vector3(8.6, 0.74, 1.0)), Vector3(1.1, 0.05, 0.7))
	for sx in [-0.5, 0.5]:
		for sz in [-0.3, 0.3]: k.box(wood, L(Vector3(8.6 + sx, 0.36, 1.0 + sz)), Vector3(0.05, 0.72, 0.05))
	k.box(wood, L(Vector3(8.6, 0.45, 1.75)), Vector3(0.42, 0.04, 0.42))
	k.box(wood, L(Vector3(10.0, 1.5, 0.12)), Vector3(1.6, 0.04, 0.24))
	k.box(Mats.tex(Tex.get_tex("paper"), ZONE, Color(0.92, 0.88, 0.75)), L(Vector3(9.2, 1.55, 0.02)), Vector3(0.42, 0.55, 0.02))   # the calendar
	k.box(Mats.flat(Color(0.35, 0.22, 0.14), ZONE), L(Vector3(8.5, 0.8, 0.95)), Vector3(0.3, 0.05, 0.4))      # the ledger
	k.box(Mats.flat(Color(0.5, 0.15, 0.1), ZONE), L(Vector3(10.2, 1.6, 0.12)), Vector3(0.22, 0.14, 0.14))    # the shells
	k.box(Mats.flat(Color(1.0, 0.9, 0.7), ZONE, 1.0), L(Vector3(9.4, 2.12, 1.3)), Vector3(0.07, 0.1, 0.07))
	k.box(Mats.flat(Color(0.05, 0.05, 0.05), ZONE), L(Vector3(9.4, 2.28, 1.3)), Vector3(0.012, 0.22, 0.012))
	k.commit(self, "Rooms")
	# the furnace door: lit from inside
	var dk := Kit.new()
	_glow_mat = Mats.flat(Color(1.0, 0.45, 0.12), ZONE, 1.0).duplicate() as ShaderMaterial
	dk.box(_glow_mat, L(GRATE), Vector3(0.03, 0.42, 0.55))
	var bars := Mats.flat(Color(0.06, 0.05, 0.05), ZONE)
	for i in 5: dk.box(bars, L(GRATE + Vector3(0.03, 0, -0.22 + i * 0.11)), Vector3(0.025, 0.44, 0.03))
	dk.box(bars, L(GRATE + Vector3(0.03, 0.22, 0)), Vector3(0.03, 0.04, 0.6))
	dk.box(bars, L(GRATE + Vector3(0.03, -0.22, 0)), Vector3(0.03, 0.04, 0.6))
	dk.commit(self, "FurnaceDoor")
	_colliders()
	_glow = Lamp.make(self, L(GRATE + Vector3(0.6, 0.2, 0)), Color(1.0, 0.5, 0.2), 2.2, 9.0, PackedInt32Array([ZONE]), "", "candle")
	Lamp.make(self, L(Vector3(9.4, 2.15, 1.3)), Color(1.0, 0.85, 0.6), 1.0, 6.5, PackedInt32Array([ZONE]), "", "")
	Lamp.make(self, L(Vector3(11.4, 2.2, 6.8)), Color(0.9, 0.85, 0.75), 0.6, 5.0, PackedInt32Array([ZONE]), "", "")
	for p in [Vector3(4.0, 0.03, 3.5), Vector3(7.0, 0.03, 5.5), Vector3(2.8, 0.03, 2.0)]:
		Puddle.spill(self, L(p), 3.0)
	_roar = Audio.loop("furnace", self, -6.0, 3.0)
	_roar.position = L(FURNACE + Vector3(0, 1, 0))
	_usables()
	_props()
	_nav()
	Noises.made.connect(_heard)
	World.register("basement", func(): return {"heat": heat, "gas": gas_on, "drawing": drawing_out},
		func(d): heat = float(d.get("heat", 1.0)); gas_on = bool(d.get("gas", true)); drawing_out = bool(d.get("drawing", false)))

func _colliders() -> void:
	var b := StaticBody3D.new(); b.name = "Walls"; add_child(b)
	var box := func(c: Vector3, s: Vector3):
		var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = s; cs.shape = sh
		cs.position = L(c); b.add_child(cs)
	box.call(Vector3(W * 0.5, -0.2, D * 0.5), Vector3(W + 1, 0.4, D + 1))
	box.call(Vector3(W * 0.5, H + 0.2, D * 0.5), Vector3(W + 1, 0.4, D + 1))
	box.call(Vector3(W * 0.5, H * 0.5, -0.2), Vector3(W + 1, H, 0.4))
	box.call(Vector3(W * 0.5, H * 0.5, D + 0.2), Vector3(W + 1, H, 0.4))
	box.call(Vector3(-0.2, H * 0.5, D * 0.5), Vector3(0.4, H, D + 1))
	box.call(Vector3(W + 0.2, H * 0.5, D * 0.5), Vector3(0.4, H, D + 1))
	box.call(FURNACE + Vector3(0, 0.9, 0), Vector3(1.5, 1.8, 1.5))
	box.call(Vector3(3.6, 0.85, 7.45), Vector3(1.2, 1.7, 0.7))
	box.call(Vector3(11.5, 1.0, 7.3), Vector3(1.2, 2.0, 1.2))          # the steps (you leave by them)
	box.call(Vector3(10.9, 0.25, 1.0), Vector3(1.9, 0.5, 0.8))
	box.call(Vector3(8.6, 0.4, 1.0), Vector3(1.1, 0.8, 0.7))
	box.call(Vector3(1.4, 0.2, 6.8), Vector3(1.6, 0.4, 1.3))           # the coal

func _nav() -> void:
	var nav: Nav = level.nav
	var pts := [ENTRY, Vector3(8.5, 0, 5.2), Vector3(6.0, 0, 4.0), Vector3(3.2, 0, 4.0), Vector3(9.6, 0, 2.6),
		Vector3(6.0, 0, 1.6), Vector3(2.8, 0, 2.0), Vector3(5.5, 0, 6.6), Vector3(2.6, 0, 5.6)]
	for i in pts.size(): _nav_pts.append(nav.add(L(pts[i]), "basement_%d" % i))
	for pair in [[0, 1], [1, 2], [2, 3], [1, 4], [4, 5], [2, 5], [5, 6], [3, 6], [2, 7], [7, 8], [3, 8], [1, 7]]:
		nav.join(_nav_pts[pair[0]], _nav_pts[pair[1]])

func zone_of(_p: Vector3) -> int:
	return ZONE

# ------------------------------------------------------------------------------ the things to do
func _usables() -> void:
	var up := Usable.make(self, Transform3D(Basis(), L(Vector3(10.78, 0.8, 7.2))), Vector3(0.16, 1.4, 1.0), [{"id": "leave", "label": "Go back up"}])
	up.title = "Steps"
	up.acted.connect(func(_v, _k): story.travel.call(id, false))
	# the furnace door
	var fd := Usable.make(self, Transform3D(Basis(), L(GRATE + Vector3(0.06, 0, 0))), Vector3(0.1, 0.5, 0.65), [])
	fd.title = "Furnace"
	fd.offer = _furnace_verbs
	fd.acted.connect(_furnace)
	fd.socko_offer = func(_k): return [] if drawing_out else [{"id": "fetch", "label": "Get the drawing"}]
	fd.socko_do = func(_id, _k, m):
		await m.bark("cmd_fire", true)
		m.defy(0.2, "fire")
	# the gas
	var valve := Usable.make(self, Transform3D(Basis(), L(VALVE)), Vector3(0.3, 0.3, 0.3), [])
	valve.title = "Gas valve"
	valve.offer = func(_k): return [{"id": "gas", "label": "Turn the gas off" if gas_on else "Turn the gas back on"}]
	valve.acted.connect(func(_v, _k):
		gas_on = not gas_on
		Audio.play("rattle", L(VALVE), -4.0, 0.7)
		Noises.make(L(VALVE), 4.0, "valve", self)
		World.emit_event("gas", {"on": gas_on}))
	# the hose
	var hose := Usable.make(self, Transform3D(Basis(), L(HOSE)), Vector3(0.5, 0.6, 0.12), [])
	hose.title = "Hose"
	hose.desc = "A canvas hose on the tank's tap. Long enough to reach the furnace."
	hose.offer = func(_k): return [] if heat < 0.05 else [{"id": "flood", "label": "Turn the hose on the furnace"}]
	hose.acted.connect(func(_v, _k): _flood())
	# his corner
	var ledger := Usable.make(self, Transform3D(Basis(), L(Vector3(8.5, 0.82, 0.95))), Vector3(0.35, 0.1, 0.45), [{"id": "read", "label": "Read"}])
	ledger.title = "Ledger"
	ledger.acted.connect(func(_v, k): k.read_doc("super_ledger", "Ledger"))
	var cal := Usable.make(self, Transform3D(Basis(), L(Vector3(9.2, 1.55, 0.06))), Vector3(0.45, 0.6, 0.06), [{"id": "read", "label": "Read"}])
	cal.title = "Calendar"
	cal.acted.connect(func(_v, k): k.read_doc("super_calendar", "Calendar"))
	var shells := Usable.make(self, Transform3D(Basis(), L(Vector3(10.2, 1.6, 0.14))), Vector3(0.26, 0.18, 0.18), [])
	shells.title = "Box of shells"
	shells.offer = func(_k): return [] if World.flag("basement_shells") else [{"id": "take", "label": "Take"}]
	shells.acted.connect(func(_v, k):
		World.set_flag("basement_shells")
		k.shells += 6
		Audio.play("pickup", shells.global_position, -6.0)
		World.emit_event("looked", {"title": "Box of shells", "desc": "Twelve-bore, six left in a box of twenty-five. For rats, it says on the side, in his hand.", "key": "shells"}))
	var coal := Usable.make(self, Transform3D(Basis(), L(Vector3(1.4, 0.5, 6.6))), Vector3(1.4, 0.6, 1.0), [{"id": "look", "label": "Look"}])
	coal.title = "Coal"
	coal.acted.connect(func(_v, _k):
		World.emit_event("looked", {"title": "Coal", "desc": "Coal, and in it, shoes. Small ones. A red sandal, a felt boot, a school shoe with the laces still done up. He was feeding them in a few at a time.", "key": "coal_shoes"})
		Progress.remember("coal_shoes", 1))

func _props() -> void:
	var poker := Prop.make(self, Transform3D(Basis(Vector3.BACK, 0.25), L(Vector3(2.5, 0.55, 5.9))), Vector3(0.04, 1.1, 0.04), 1.8)
	poker.key = "basement_poker"; poker.title = "Poker"; poker.stuff = "metal"
	var pk := Kit.new()
	pk.box(Mats.tex(Tex.get_tex("metal"), -1, Color(0.3, 0.28, 0.27)), Vector3.ZERO, Vector3(0.035, 1.1, 0.035))
	pk.box(Mats.tex(Tex.get_tex("metal"), -1, Color(0.3, 0.28, 0.27)), Vector3(0.05, -0.52, 0), Vector3(0.1, 0.03, 0.03))
	pk.commit(poker, "Mesh")

func _furnace_verbs(k) -> Array:
	if drawing_out: return [{"id": "look", "label": "Look in"}]
	var v: Array = [{"id": "look", "label": "Look in"}]
	if k and k.held and "poker" in String(k.held.title).to_lower():
		v.push_front({"id": "rake", "label": "Rake it out with the poker", "held": true})
	v.append({"id": "reach", "label": "Reach in" if heat > 0.3 else "Take the drawing"})
	return v

func _furnace(v: String, k) -> void:
	match v:
		"look":
			var t := "Ash and coals. "
			if not drawing_out:
				t += "On the grate, lying on top where the draught's held it, a child's drawing: a house with black windows. " + ("The edges are going brown." if heat > 0.3 else "The fire under it is out.")
			World.emit_event("looked", {"title": "Furnace", "desc": t, "key": "furnace"})
		"rake":
			Audio.play("scrape", L(GRATE), -2.0)
			Noises.make(L(GRATE), 3.0, "rake", self)
			_take(k, "One corner burnt. Raked out with his poker, onto his floor.")
		"reach":
			if heat > 0.3:
				Audio.play("hiss", L(GRATE), 0.0, 1.4)
				k.hurt(35.0 * heat, self)
				await Speech.say_id("basement_burn")
			_take(k, "One corner burnt." if heat > 0.3 else "Warm still. Not burnt.")

func _take(k, how: String) -> void:
	drawing_out = true
	k.give_item("sonya_drawing", "Sonya's drawing", "Crayon on squared paper: a house with black windows, a sun with a face, three people, the smallest holding a red balloon. " + how)
	Progress.remember("sonya_drawing", 2)
	await Speech.say_id("basement_drawing")
	reached_heart()

func _flood() -> void:
	heat = 0.0
	Audio.play("hiss", L(GRATE), 8.0, 0.6)
	Audio.play("splash", L(GRATE), 0.0)
	Audio.play("pressure", L(GRATE), 0.0, 0.5)
	Noises.make(L(GRATE), 24.0, "steam", self)          # it screams up the stairwell
	World.emit_event("flooded", {})
	Speech.say_id("basement_steam")

# ------------------------------------------------------------------------------------------ frame
func _process(delta: float) -> void:
	if not gas_on: heat = maxf(heat - delta / 25.0, 0.0)
	elif heat > 0.0: heat = minf(heat + delta / 40.0, 1.0)
	if _glow: _glow.energy = 2.2 * heat + 0.05
	if _glow_mat: _glow_mat.set_shader_parameter("albedo_color", Color(1.0, 0.45, 0.12).lerp(Color(0.08, 0.06, 0.05), 1.0 - heat))
	if _roar: _roar.volume_db = -80.0 if heat < 0.05 else lerpf(-24.0, -6.0, heat)
	if _super_coming > 0.0:
		_super_coming -= delta
		if _super_coming <= 0.0: _super_arrives()
	# once Kurt's gone back up and he's lost him, he goes back to his stairs
	var s = story.super_ if story else null
	if s and is_instance_valid(s) and contains(s.global_position) and not contains(story.kurt.global_position) and s.state != Monster.S.HUNT:
		s.global_position = level.nav.pts[level.nav.tags["stair_1"]]
		s.velocity = Vector3.ZERO
		s.set_state(Monster.S.PATROL)

## Anything loud down here, and he comes down his own steps.
func _heard(n: Dictionary) -> void:
	if not contains(n.pos) or float(n.loud) < 8.0 or _super_coming > 0.0: return
	var s = story.super_ if story else null
	if s == null or not is_instance_valid(s) or s.state == Monster.S.DEAD or contains(s.global_position): return
	_super_coming = 6.0 if not Speech.fast else 1.0
	for i in 4:
		get_tree().create_timer(i * 0.9 + 2.0, false).timeout.connect(func(): Audio.play("step_heavy", L(Vector3(11.9, 1.6, 7.3)), -6.0 + i * 2.0, 0.85))

func _super_arrives() -> void:
	var s: Super = story.super_
	story._dormant(s, false)
	Audio.play("slam", L(Vector3(11.9, 1.6, 7.3)), 0.0, 0.8)
	s.global_position = L(ENTRY) + Vector3(0, 0.05, 0)
	s.velocity = Vector3.ZERO
	s.go_to(story.kurt.global_position)
	s.set_state(Monster.S.INVESTIGATE)
	World.emit_event("super_down", {})
