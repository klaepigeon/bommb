class_name Story
extends Node
## The story, as it reacts to the world. Scene A is played as written (no intro text; the beats wait
## for the player: the hall, the sight of her, examining her). After that nothing is on rails: beats
## fire when the world makes them true (the door's tried, the wardrobe's moved, the balcony's
## stepped onto), and the ways out are whichever ones the player finds.

var main
var kurt: Kurt
var level: Level
var hud: Hud
var socko: Socko
var mind: SockoMind
var marta_table: CreatureBody.MartaBody   ## Marta at her table, before
var marta: Marta
var super_: Super
var porter: Porter
var lamplighter: Lamplighter
var figures: Array[Figure] = []
var phase := "start"               ## knock, inside, examined, out, awake, ended
var _beats := {}
var _service: Usable
var _last_place := ""
var ambience: Ambience

func setup(m) -> void:
	main = m; kurt = m.kurt; level = m.level; hud = m.hud
	socko = Socko.new(); socko.name = "Socko"
	kurt.cam.add_child(socko)
	socko.build(kurt)
	mind = SockoMind.new(); mind.name = "SockoMind"
	add_child(mind)
	mind.setup(socko, kurt, level)
	World.event.connect(_on_event)
	World.register("story", func(): return {"phase": phase, "beats": _beats}, func(d): phase = String(d.phase); _beats = d.beats)
	_marta_at_table()
	_maze_things()
	_monsters()

func _beat(id: String) -> bool:
	if _beats.has(id): return false
	_beats[id] = true
	return true

# ------------------------------------------------------------------------------ the people
func _marta_at_table() -> void:
	marta_table = CreatureBody.MartaBody.new(); marta_table.name = "MartaAtTable"
	level.flat.add_child(marta_table)
	marta_table.build(true)
	marta_table.global_position = Flat47.MARTA_SEAT
	marta_table.rotation.y = PI * 0.5 + 0.12           # facing the table, west
	# her own chair is the one grown into her: the flat's chair at her place goes
	if level.flat.marta_chair:
		for mi in level.flat.marta_chair.find_children("*", "MeshInstance3D", true, false): (mi as MeshInstance3D).visible = false
	marta_table.set_zone(1)
	marta_table.pose({"stoop": 1.0})
	var u := Usable.make(level.flat, Transform3D(Basis(), Flat47.MARTA_SEAT + Vector3(0, 0.8, 0)), Vector3(0.6, 1.2, 0.6), [])
	u.title = "Marta"
	u.name = "MartaSpot"
	u.offer = func(_k): return [{"id": "examine", "label": "Examine"}] if phase == "inside" and _beats.has("see_marta") else []
	u.acted.connect(func(_v, _k): _examine())

func _monsters() -> void:
	var mz := level.maze
	marta = Marta.new(); marta.name = "Marta"
	level.add_child(marta)
	marta.setup("marta", level, kurt, mz.chamber_center("N"))
	marta.add_to_group("marta")
	marta.haunts = [mz.chamber_center("N"), mz.chamber_center("G"), mz.center(9, 1), mz.center(1, 9), mz.center(15, 11), mz.center(5, 17), Vector3(1.8, 0, 7.0)]
	marta.caught_kurt.connect(_caught)
	_dormant(marta, true)
	super_ = Super.new(); super_.name = "Super"
	level.add_child(super_)
	super_.setup("super", level, kurt, level.nav.pts[level.nav.tags["stair_2"]])
	super_.caught_kurt.connect(_caught)
	_dormant(super_, true)
	porter = Porter.new(); porter.name = "Porter"
	level.add_child(porter)
	porter.setup("porter", level, kurt, mz.center(10, 16) + Vector3(0.3, 0, 0))
	porter.rotation.y = PI * 0.5        # facing his board on the west wall... his back to the passage
	porter.seat_yaw = porter.rotation.y
	lamplighter = Lamplighter.new(); lamplighter.name = "Lamplighter"
	level.add_child(lamplighter)
	lamplighter.setup("lamplighter", level, kurt, mz.center(1, 7))
	# MAMA, PAPA and CHILD stand in Flat 48, where they always stood
	var fdata: Dictionary = level.flat48.puzzle.figures
	for key in ["mama", "papa", "child"]:
		var f := Figure.new(); f.tag = String(fdata[key].tag); f.name = f.tag
		f.room = AABB(Flat48.AT + Vector3(-0.2, 0, -0.2), Vector3(10.4, 3.0, 8.4))
		level.add_child(f)
		var at: Array = fdata[key].at
		f.setup("figure_" + f.tag, level, kurt, Flat48.AT + Vector3(at[0], at[1], at[2]))
		f.look_text = String(fdata[key].look)
		figures.append(f)
	# the building's own: travel, and the flats' story
	travel = func(flat: String, from_landing: bool, via := "") -> void: _travel(flat, from_landing, via)
	level.building.travel = travel
	for id in level.places: (level.places[id] as Place).story = self
	ambience = Ambience.new(); ambience.name = "Ambience"
	add_child(ambience)
	ambience.setup(self)

## Things asleep don't think (Marta's at her table until she isn't; the Super starts when Kurt's
## in the walls).
func _dormant(m: Monster, yes: bool) -> void:
	m.process_mode = Node.PROCESS_MODE_DISABLED if yes else Node.PROCESS_MODE_INHERIT
	m.visible = not yes
	m.collision_layer = 0 if yes else 32

# ------------------------------------------------------------------------------ the walls' things
func _maze_things() -> void:
	var mz := level.maze
	# the revolver, in the hanging room, up against the ceiling, turning slowly
	var g: AABB = mz.chambers["G"]
	var gun := _thing(g.get_center() + Vector3(0.3, 1.45, -0.2), Vector3(0.24, 0.12, 0.05), 1.0, "revolver", "Revolver",
		"A Nagant revolver, M1895. Seven chambers, four of them loaded. Your hand closes on it the right way without asking you.", Color(0.12, 0.12, 0.14))
	gun.add_to_group("gun")
	gun.floats = true
	gun.wake(); gun.angular_velocity = Vector3(0.1, 0.25, 0.05); gun.linear_velocity = Vector3(0.05, 0.0, -0.04)
	gun.linear_damp = 0.0; gun.angular_damp = 0.0
	# the frozen fight: chairs and stones hanging in the air round it
	var rng := RandomNumberGenerator.new(); rng.seed = 13
	for i in 9:
		var p := g.position + Vector3(rng.randf_range(0.4, g.size.x - 0.4), rng.randf_range(0.9, 2.9), rng.randf_range(0.4, g.size.z - 0.4))
		var big := i < 3
		var t := _thing(p, Vector3(0.45, 0.85, 0.45) if big else Vector3(0.18, 0.12, 0.14), 5.0 if big else 2.0, "", "Chair" if big else "Paving stone",
			"A bentwood chair, hanging in the air on nothing." if big else "A cobble, prised out of a street that isn't here.", Color(0.4, 0.28, 0.2) if big else Color(0.45, 0.45, 0.42))
		t.wake(); t.angular_velocity = Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2), 0); t.linear_damp = 0.0
	# the poster on the wall: TRICKSHOT
	var poster := Usable.make(level, Transform3D(Basis(), Vector3(g.position.x + 0.02, 1.6, g.get_center().z)), Vector3(0.06, 0.9, 0.6), [{"id": "look", "label": "Look"}])
	poster.title = "Poster"
	poster.acted.connect(func(_v, _k):
		World.set_flag("saw_poster")
		var t := "A Champion's League poster, the colours gone. A man in a black domino mask drawing a bow: TRICKSHOT. The face under the mask is younger than yours. It's yours."
		hud.say_look(t)
		if Progress.has("faces"): Progress.remember("poster", 1); hud.flash("Something comes back.")
		else: World.emit_event("looked", {"title": "Poster", "desc": "", "key": "poster"}))
	_sticker(Vector3(g.position.x + 0.03, 1.6, g.get_center().z), Vector3(1, 0, 0), Vector2(0.6, 0.9), Color(0.55, 0.15, 0.12), "TRICKSHOT")
	# the porter's lodge: his board of keys, and the photograph
	var pl: AABB = mz.chambers["P"]
	var board := Usable.make(level, Transform3D(Basis(), Vector3(pl.position.x + 0.1, 1.4, pl.get_center().z)), Vector3(0.12, 0.7, 0.9), [])
	board.title = "Key board"
	board.offer = func(_k): return [{"id": "fuse", "label": "Take the spare fuse"}] if not World.flag("took_spare_fuse") else []
	board.acted.connect(func(_v, k):
		if porter.state == Monster.S.SIT and porter.dist_to_kurt() < 2.6: porter.alarm()
		World.set_flag("took_spare_fuse"); k.give_item("fuse", "Fuse", "A ceramic fuse, 16 A. From the porter's box."))
	board.socko_offer = func(_k): return [{"id": "fetch", "label": "Get the fuse"}] if not World.flag("took_spare_fuse") else []
	board.socko_do = func(_id, k, m):
		m.socko.set_pose("talk", 0.4); m.socko.point_at(board.global_position)
		await m.bark("cmd_fetch", true)
		await get_tree().create_timer(1.5, false).timeout
		m.socko.point_at(Vector3.INF); m.socko.set_pose("up", 0.5)
		World.set_flag("took_spare_fuse"); k.give_item("fuse", "Fuse", "A ceramic fuse, 16 A. Socko brought it, in his mouth.")
		m.bark("cmd_fetch_ok", true)
		World.emit_event("socko_fetched", {})
	_sticker(Vector3(pl.position.x + 0.02, 1.4, pl.get_center().z), Vector3(1, 0, 0), Vector2(0.9, 0.7), Color(0.32, 0.22, 0.14), "")
	var photo := Usable.make(level, Transform3D(Basis(), Vector3(pl.end.x - 0.15, 1.0, pl.position.z + 0.3)), Vector3(0.2, 0.1, 0.2), [{"id": "look", "label": "Look"}])
	photo.title = "Photo strip"
	photo.acted.connect(func(_v, _k):
		World.set_flag("saw_room_four")
		hud.say_look("A photo-booth strip: a man and a woman, four frames, laughing in three. On the back, in pencil: «Room 4. T. and me. The last good night.»")
		if Progress.has("handwriting"): Progress.remember("photo_strip", 1); hud.flash("Something comes back."))
	# Sonya's door, in the nursery
	var nr: AABB = mz.chambers["N"]
	var sd := Usable.make(level, Transform3D(Basis(), Vector3(nr.position.x + 0.05, 1.0, nr.get_center().z)), Vector3(0.1, 2.0, 0.9), [{"id": "look", "label": "Look"}, {"id": "knock", "label": "Knock"}])
	sd.title = "A door"
	sd.acted.connect(func(v, k):
		if v == "knock":
			Audio.play("knock", sd.global_position, 0.0); Noises.make(sd.global_position, 9.0, "knock", k)
			await get_tree().create_timer(1.6, false).timeout
			Audio.play("knock", sd.global_position, -14.0, 1.4)
		else:
			hud.say_look("A child's door, painted white. Scratched into it, low down, at a child's height: СОНЯ. It won't open. Something on the other side is very quiet."))
	_sticker(Vector3(nr.position.x + 0.03, 1.0, nr.get_center().z), Vector3(1, 0, 0), Vector2(0.85, 1.95), Color(0.85, 0.84, 0.8), "СОНЯ")
	# the walls' own fuse box, in the breaker room
	var br: AABB = mz.chambers["B"]
	FuseBox.place(level, Vector3(br.end.x - 0.08, 1.5, br.get_center().z), Vector3(-1, 0, 0), ["M1", "M2", "M3"], "Fuse board", 23)
	# the flooded passage: a drain wheel (stiff), and a cable hanging over the water
	var wv := Usable.make(level, Transform3D(Basis(), mz.center(8, 13) + Vector3(-0.5, 0.6, 0)), Vector3(0.15, 0.4, 0.4), [])
	wv.title = "Drain wheel"
	wv.offer = func(_k): return [{"id": "turn", "label": "Turn the wheel"}] if mz.water.outflow == 0.0 else []
	wv.acted.connect(func(_v, k):
		var turns := World.count("drain_turns")
		Audio.play("scrape", wv.global_position, 0.0, 0.6)
		Noises.make(wv.global_position, 8.0, "valve", k)
		if turns >= (1 if Progress.has("coral_grip") else 3):
			mz.water.outflow = 0.02; mz.water.gurgle = true
			World.emit_event("drained", {})
		else: hud.say_look("It gives a little. Rust grinds."))
	var cable := Usable.make(level, Transform3D(Basis(), mz.center(11, 13) + Vector3(0, 2.0, 0.4)), Vector3(0.2, 0.4, 0.2), [])
	cable.title = "Cable"
	cable.offer = func(_k): return [{"id": "drop", "label": "Pull it down into the water"}] if mz.water.live_circuit == "" else [{"id": "lift", "label": "Hang it back up"}]
	cable.acted.connect(func(v, _k):
		mz.water.live_circuit = "M1" if v == "drop" else ""
		mz.water_leg.live_circuit = mz.water.live_circuit
		Audio.play("zap", cable.global_position, -4.0)
		World.emit_event("cable", {"in_water": v == "drop"}))
	# the service door out, at the north end of the service side: an electric lock
	var sx := mz.center(20, 1) + Vector3(0.6, 0, -CELLH)
	_service = Usable.make(level, Transform3D(Basis(), sx + Vector3(0, 1.0, 0.05)), Vector3(1.2, 2.0, 0.12), [], true)
	_service.title = "Service door"
	_service.offer = func(_k): return _service_verbs()
	_service.acted.connect(func(v, k): _service_act(v, k))
	_service.set_meta("hits", 0)
	var sk := Kit.new()
	sk.box(Mats.tex(Tex.get_tex("metal"), 28), sx + Vector3(0, 1.0, 0.0), Vector3(1.0, 2.0, 0.06))
	sk.box(Mats.flat(Color(0.2, 0.5, 0.25), 28, 0.0), sx + Vector3(0.62, 1.25, 0.05), Vector3(0.12, 0.18, 0.06))
	sk.commit(level, "ServiceDoor")
	# shards: the Gutterspace, coming through in pieces
	var cells := [[1, 1], [5, 9], [11, 11], [17, 13], [3, 15], [19, 9], [14, 5], [7, 17]]
	for i in cells.size():
		_shard(mz.center(cells[i][0], cells[i][1]) + Vector3(0, 0.4, 0), "shard_%d" % i)
	# a tin with three rounds in the den
	_thing(Vector3(2.2, 0.42, 7.2), Vector3(0.08, 0.06, 0.08), 0.3, "tin_rounds", "Tobacco tin", "A tobacco tin. Inside, three revolver rounds, loose.", Color(0.5, 0.45, 0.3))

const CELLH := 0.62

func _thing(at: Vector3, size: Vector3, mass: float, item: String, title: String, desc: String, col: Color) -> Prop:
	var p := Prop.make(level, Transform3D(Basis(), at), size, mass)
	p.key = title.to_lower().replace(" ", "_") + "_%d" % int(at.x * 100 + at.z)
	p.item = item; p.title = title; p.desc = desc
	p.stuff = "metal" if item in ["revolver", "tin_rounds"] else "wood"
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm
	mi.material_override = Mats.flat(col, -1)
	p.add_child(mi)
	return p

func _sticker(at: Vector3, normal: Vector3, size: Vector2, col: Color, text: String) -> void:
	var mi := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = size; mi.mesh = qm
	mi.material_override = Mats.flat(col, -1)
	level.add_child(mi)
	mi.global_position = at
	mi.look_at(at - normal, Vector3.UP)
	mi.rotate_object_local(Vector3.UP, PI)
	if text != "":
		var l := Label3D.new(); l.text = text; l.font_size = 64; l.pixel_size = size.x / 400.0
		l.modulate = Color(0.95, 0.9, 0.8) if col.v < 0.6 else Color(0.25, 0.1, 0.1); l.shaded = false; l.outline_size = 0
		l.position = Vector3(0, size.y * 0.35, -0.01)
		l.rotation.y = PI
		mi.add_child(l)

func _shard(at: Vector3, key: String) -> void:
	var u := Usable.make(level, Transform3D(Basis(), at), Vector3(0.3, 0.3, 0.3), [{"id": "take", "label": "Take it"}])
	u.title = "Something that isn't there"
	var mi := MeshInstance3D.new(); var pm := PrismMesh.new(); pm.size = Vector3(0.12, 0.2, 0.05); mi.mesh = pm
	var m := Mats.flat(Color(1.0, 0.0, 1.0), -1, 1.0)
	mi.material_override = m
	u.add_child(mi)
	u.set_meta("spin", true)
	var tw := mi.create_tween().set_loops()
	tw.tween_property(mi, "rotation:y", TAU, 2.5).from(0.0)
	u.acted.connect(func(_v, _k):
		Progress.gain_shards(key, 1)
		Audio.play("pressure", u.global_position, -4.0, 3.0)
		u.queue_free())
	if Progress.found.has(key): u.queue_free()

func _service_verbs() -> Array:
	var v: Array = []
	v.append({"id": "release", "label": "Press the release"})
	if Progress.has("coral_grip"): v.append({"id": "force", "label": "Tear it open"})
	return v

func _service_act(v: String, k) -> void:
	match v:
		"release":
			if Power.live("M2"):
				Audio.play("buzz", _service.global_position, 0.0)
				_open_service("power")
			else:
				Audio.play("dryfire", _service.global_position, -2.0)
				hud.say_look("A green button. Nothing happens. The little lamp above it is dead.")
		"force":
			Audio.play("splinter", _service.global_position, 4.0)
			Noises.make(_service.global_position, 25.0, "crash", k)
			_open_service("force")

func _open_service(how: String) -> void:
	_service.enabled = false
	World.set_flag("service_open", how)
	World.emit_event("service_open", {"how": how})
	for c in level.find_children("ServiceDoor", "MeshInstance3D", true, false): c.visible = false
	# behind it, the stairwell: just dark, and a draught
	var dark := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(1.0, 2.0); dark.mesh = qm
	dark.material_override = Mats.flat(Color(0, 0, 0), -1, 1.0)
	level.add_child(dark)
	dark.global_position = _service.global_position + Vector3(0, 0, 0.07)
	var a := Area3D.new(); a.collision_mask = 16; level.add_child(a)
	var cs := CollisionShape3D.new(); var b := BoxShape3D.new(); b.size = Vector3(1.2, 2.0, 0.5); cs.shape = b
	a.add_child(cs); a.global_position = _service.global_position + Vector3(0, 0, 0.35)
	a.body_entered.connect(func(bd):
		if bd is Kurt:
			# the service stair, down in the dark, comes out on 47's landing
			await hud.fade_to(1.0, 0.4)
			kurt.global_position = level.building.door_pos(4, 0) + Vector3(1.4, 0, 1.2); kurt.yaw = -PI * 0.5; kurt.velocity = Vector3.ZERO
			await hud.fade_to(0.0, 0.8)
			World.emit_event("reached_landing", {"via": "service_door"}))

# ------------------------------------------------------------------------------ Scene A
func begin(start: String) -> void:
	Log.mark("story begin " + start)
	match start:
		"knock": _scene_a()
		"wake":
			_after_blackout(); _wake(true)
		"door", "wardrobe", "maze", "gun":
			_after_blackout(); _wake(true)
			match start:
				"wardrobe": kurt.global_position = Vector3(2.0, 0, 3.9); kurt.yaw = 0.0
				"maze":
					level.flat.wardrobe_shoves = 2; level.flat.shove_wardrobe(); _beats["wardrobe"] = true
					kurt.global_position = level.maze.center(9, 1); kurt.yaw = PI
				"gun":
					level.flat.wardrobe_shoves = 2; level.flat.shove_wardrobe(); _beats["wardrobe"] = true
					kurt.global_position = level.maze.chamber_center("G") + Vector3(0, 0.1, 0.9); kurt.yaw = PI
		_: _scene_a()

func resume() -> void:
	Log.mark("story resume " + phase)
	if phase in ["start", "knock", "inside", "examined"]:
		_scene_a(); return
	_after_blackout()
	socko.enter(); socko.set_pose("up", 0.0)
	World.set_flag("socko_on")
	kurt.frozen = false
	_wake_monsters()

func _scene_a() -> void:
	phase = "knock"
	var fd: Door = level.flat.doors["dEntry"]
	fd.chained = false; fd.padlock = false; fd.set_angle(0.0)
	level.flat.doors["dLiving"].set_angle(1.45)
	kurt.global_position = Vector3(11.35, 0, 4.55)
	kurt.yaw = PI * 0.5; kurt.pitch = -0.05
	kurt.frozen = true
	main.screen_mat.set_shader_parameter("dark", 1.0)
	var t := create_tween(); t.tween_method(func(v): main.screen_mat.set_shader_parameter("dark", v), 1.0, 0.0, 2.5)
	await get_tree().create_timer(1.8, false).timeout
	await _knock()
	await Speech.say_id("door_1")
	await get_tree().create_timer(1.6 if not Speech.fast else 0.1, false).timeout
	await _knock()
	await Speech.say_id("door_2")
	fd.swing(1.2, 1.6)
	Audio.play("creak", fd.handle_pos(), -4.0, 0.9)
	kurt.frozen = false
	phase = "inside"
	World.emit_event("scene_a_inside", {})

func _knock() -> void:
	var p: Vector3 = level.flat.doors["dEntry"].handle_pos()
	for i in 3:
		Audio.play("knock", p, 0.0, randf_range(0.95, 1.05))
		await get_tree().create_timer(0.32 if not Speech.fast else 0.03, false).timeout
	await get_tree().create_timer(0.5 if not Speech.fast else 0.05, false).timeout

func _process(_delta: float) -> void:
	if phase == "inside":
		if not _beats.has("see_flat") and kurt.zone == 4:
			_beats["see_flat"] = true
			Speech.say_id("see_flat")
		if _beats.has("see_flat") and not _beats.has("see_marta") and _sees(Flat47.MARTA_SEAT + Vector3(0, 1.0, 0), 0.75, 6.0):
			_beats["see_marta"] = true
			if Speech.speaking != "": await Speech.line_finished
			Speech.say_id("see_marta")
	var place: String = level.place_of(kurt.global_position)
	if place != _last_place:
		_last_place = place
		World.emit_event("place", {"place": place})
	# after: beats the world makes true
	if phase == "awake":
		if kurt.zone == Flat47.BALCONY and _beat("balcony"): _balcony()

func _sees(p: Vector3, cos_min: float, max_d: float) -> bool:
	var to := p - kurt.cam.global_position
	if to.length() > max_d: return false
	if (-kurt.cam.global_transform.basis.z).dot(to.normalized()) < cos_min: return false
	var q := PhysicsRayQueryParameters3D.create(kurt.cam.global_position, p, 1)
	q.exclude = [kurt.get_rid()]
	var hit := kurt.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or (hit.position as Vector3).distance_to(p) < 0.6

## He goes round to her side and leans in. She lifts her head to him.
func _examine() -> void:
	if phase != "inside": return
	phase = "examined"
	kurt.frozen = true
	kurt.look_locked = true
	if kurt.held: kurt.drop(false)
	var side := Flat47.MARTA_SEAT + Vector3(0.55, 0, 0.45)
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(kurt, "global_position", side, 1.0)
	var face := Flat47.MARTA_SEAT + Vector3(-0.05, 1.0, 0)
	var dir := face - (side + Vector3(0, 1.4, 0))
	t.parallel().tween_property(kurt, "yaw", atan2(-dir.x, -dir.z), 1.0)
	t.parallel().tween_property(kurt, "pitch", -0.55, 1.0)
	await t.finished
	kurt.crouching = true
	await Speech.say_id("examine")
	# her head comes up
	var lift := create_tween()
	lift.tween_method(func(v): marta_table.pose({"dt": 0.05, "stoop": 1.0 - v, "look_at": kurt.cam.global_position, "twitch": 0.3 * v}), 0.0, 1.0, 1.2)
	Audio.play("coral", Flat47.MARTA_SEAT + Vector3(0, 1.2, 0), 0.0)
	await lift.finished
	await Speech.say_id("boxes")
	await Speech.say_id("marta_q")
	await Speech.say_id("little_bird")
	# she takes hold of him
	for i in 6: marta_table.pose({"dt": 0.05, "stoop": 0.0, "look_at": kurt.cam.global_position, "reach": 1.0, "twitch": 1.0})
	Audio.play("gasp", kurt.global_position + Vector3(0, 1.5, 0), 0.0)
	Audio.play("hit", kurt.global_position, -2.0)
	var yank := create_tween()
	yank.tween_property(kurt, "pitch", -0.9, 0.18)
	yank.parallel().tween_property(kurt, "global_position", kurt.global_position.lerp(Flat47.MARTA_SEAT, 0.35), 0.18)
	Speech.say_id("gasp")
	await hud.fade_to(1.0, 0.7)
	await _blackout()

func _blackout() -> void:
	phase = "out"
	Audio.play("heartbeat", null, -6.0)
	await get_tree().create_timer(1.2 if not Speech.fast else 0.05, false).timeout
	Audio.play("heartbeat", null, -9.0)
	_after_blackout()
	await get_tree().create_timer(2.2 if not Speech.fast else 0.05, false).timeout
	_wake(false)

## While he's out: she's gone from her chair; the living room door is shut and locked from the hall
## (the key still in it, on that side); the front door's chained and padlocked from the inside.
func _after_blackout() -> void:
	if is_instance_valid(marta_table):
		marta_table.vanish()            # gone: what she grew into stays (the chair, the coral, the puddle)
		var spot := level.flat.get_node_or_null("MartaSpot")
		if spot: spot.queue_free()
	var kit := Kit.new()
	var rng := RandomNumberGenerator.new(); rng.seed = 47
	for i in 9:
		kit.blob(Mats.tex(Tex.get_tex("coral"), 1), Flat47.MARTA_SEAT + Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0.0, 0.9), rng.randf_range(-0.2, 0.2)), Vector3(0.05, 0.12, 0.05), rng, 0.4)
	kit.commit(level.flat, "EmptyChair")
	var ld: Door = level.flat.doors["dLiving"]
	ld.set_angle(0.0); ld.key_locked = true; ld.key_in = ld.side_of(Vector3(6.0, 0, 4.5))
	var fd: Door = level.flat.doors["dEntry"]
	fd.set_angle(0.0); fd.chained = true; fd.padlock = true
	phase = "awake"

func _wake(instant: bool) -> void:
	kurt.global_position = Flat47.POINTS.wake
	kurt.yaw = PI * 0.25; kurt.pitch = 1.2
	kurt.crouching = true
	kurt.frozen = true; kurt.look_locked = true
	if instant:
		await hud.fade_to(0.0, 0.1)
	else:
		await hud.fade_to(0.35, 2.0)
		await hud.fade_to(0.0, 1.5)
	if not instant:
		var rub := create_tween()
		rub.tween_property(kurt, "pitch", 0.6, 1.4).set_trans(Tween.TRANS_SINE)
		await Speech.say_id("smarts")
		socko.enter()
		socko.face_kurt = 1.0
		socko.set_pose("talk", 0.8)
		World.set_flag("socko_on")
		for id in ["hey_buddy", "wtf", "who_me", "who_are_you", "im_socko", "kurt_sounds", "dont_know", "got_nothing"]:
			await Speech.say_id(id)
		# he gets up
		kurt.crouching = false
		var up := create_tween().tween_property(kurt, "pitch", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
		await Speech.say_id("too_fast")
		socko.face_kurt = 0.0
		socko.set_pose("up", 0.7)
	else:
		socko.enter(); socko.set_pose("up", 0.0); World.set_flag("socko_on")
		kurt.pitch = 0.0; kurt.crouching = false
		_beats["woke"] = true
	kurt.frozen = false; kurt.look_locked = false
	socko.torch_on = true        # the light's in his mouth from the start: nobody explains it
	if not main.args.has("autotest"): World.save_game()
	_wake_monsters()
	World.emit_event("woke", {})

func _wake_monsters() -> void:
	_dormant(marta, World.flag("killed_marta", false) and false)
	_dormant(super_, false)

# ------------------------------------------------------------------------------ the world's beats
func _on_event(name: String, d: Dictionary) -> void:
	match name:
		"door_tried":
			if d.door == "dLiving" and phase == "awake" and d.by is Kurt and _beat("door"):
				for id in ["wont_open", "locked", "thanks", "welcome"]:
					await Speech.say_id(id)
				socko.face_kurt = 0.0
				socko.look_target = kurt.global_position + Vector3(-1, 0.8, 0)
				await Speech.say_id("like_helping")
		"wardrobe_shoved":
			if d.n >= 3 and _beat("wardrobe"):
				await get_tree().create_timer(0.7 if not Speech.fast else 0.05, false).timeout
				await Speech.say_id("what_is_that")
				await Speech.say_id("dunno")
				await Speech.say_id("know_anything")
				socko.face_kurt = 0.9
				socko.cross_eyes(true)
				await Speech.say_id("can_do_this")
				await get_tree().create_timer(0.8 if not Speech.fast else 0.05, false).timeout
				socko.cross_eyes(false)
				socko.face_kurt = 0.0
				socko.point_at(mind._toward_gun())
				await Speech.say_id("smell")
				await get_tree().create_timer(1.5, false).timeout
				socko.point_at(Vector3.INF)
		"caught": pass
		"fell_into_white":
			await hud.fade_to(1.0, 0.5)
			kurt.global_position = Flat47.POINTS.balcony; kurt.velocity = Vector3.ZERO
			await hud.fade_to(0.0, 1.0)
		"reached_landing":
			if phase == "awake" and not World.flag("bolt_47"):      # (Scene A starts on the landing)
				World.set_flag("visited_47")
				level.building.slide_bolt("47")
				World.emit_event("out_of_47", {"via": d.via})
		"escaped":
			_end("street")
		"entered_flat":
			if d.flat == "basement" and _beat("basement_in"): Speech.say_id("basement_in")
		"super_down":
			if mind: mind.bark("basement_super", true)
		"heart":
			# any place's heart: the street door's bolt for it goes back
			level.building.slide_bolt(String(d.place))
		"looked":
			if String(d.key) == "figure_CHILD" and not World.flag("child_note"):
				World.set_flag("child_note")
				kurt.give_item("note:CHILD'S CELL", "Note: CHILD'S CELL", "Pinned to the back of the CHILD, under its tag: CHILD'S CELL — 44.")
				hud.flash("On its back, under the tag: CHILD'S CELL — 44.", 4.0)
		"pocketed":
			if d.item == "revolver":
				kurt.rounds = 4
				kurt.draw_gun()
			elif d.item == "tin_rounds":
				kurt.take_item("tin_rounds"); kurt.spare += 3
				hud.flash("Three rounds.")
		"gun_out": pass

func _balcony() -> void:
	if not World.flag("socko_on"): return
	for id in ["bal_1", "bal_2", "bal_3", "bal_4"]:
		await Speech.say_id(id)

## Caught: it goes dark, and he comes round somewhere else, worse for it.
func _caught(m: Monster) -> void:
	kurt.frozen = true
	Audio.play("hit", kurt.global_position, 2.0)
	World.count("caught_by_" + m.id)
	await hud.fade_to(1.0, 0.4)
	await get_tree().create_timer(1.5 if not Speech.fast else 0.05, false).timeout
	kurt.global_position = Flat47.POINTS.boxroom; kurt.yaw = PI; kurt.velocity = Vector3.ZERO
	kurt.hp = 35.0 if m is Super else 60.0
	if kurt.held: kurt.drop(false)
	if m is Marta:
		(m as Marta).away_for = 30.0; m.set_state(Monster.S.AWAY); m.go_to((m as Marta)._far_haunt())
	else:
		m.set_state(Monster.S.PATROL); m.go_to(level.maze.center(21, 12))
	await hud.fade_to(0.0, 1.2)
	kurt.frozen = false
	mind.bark("caught_super" if m is Super else "caught_marta", true)

# ------------------------------------------------------------------------------ the building
## In and out of the flats off the stairs (doors are the way between: a breath of dark).
var travel: Callable

func _travel(flat: String, from_landing: bool, via: String) -> void:
	if kurt.frozen: return
	Log.mark("travel %s %s %s" % [flat, "in" if from_landing else "out", via])
	kurt.frozen = true
	Audio.play("creak", kurt.global_position, -6.0)
	await hud.fade_to(1.0, 0.3)
	var b: Building = level.building
	var to := Vector3.ZERO; var yaw := 0.0
	var place: Place = level.places.get(flat)
	if flat == "47":
		to = Vector3(8.6, 0, 4.5); yaw = PI * 0.5        # (the pointless door, labelled 47)
	elif from_landing or via != "":
		var arr := place.arrive(via)
		to = arr[0]; yaw = arr[1]
		World.set_flag("visited_" + flat)
		World.emit_event("entered_flat", {"flat": flat})
	elif not place.exit_point().is_empty():
		var ex := place.exit_point()
		to = ex[0]; yaw = ex[1]
	else:
		# out onto its landing, facing into the stairwell
		var side := place.side()
		to = b.door_pos(place.floor_index(), side) + Vector3(0.8 if side == 0 else -0.8, 0, 0)
		yaw = -PI * 0.5 if side == 0 else PI * 0.5
		if String(place.data.get("locked", "")) == "chain": World.set_flag(flat + "_open", "inside")
	if kurt.held: kurt.held.global_position = to + Vector3(0, 1.0, 0)
	kurt.global_position = to; kurt.yaw = yaw; kurt.velocity = Vector3.ZERO
	await get_tree().physics_frame
	await hud.fade_to(0.0, 0.5)
	kurt.frozen = false

# ------------------------------------------------------------------------------ the end
func _end(via: String) -> void:
	if phase == "ended": return
	phase = "ended"
	kurt.frozen = true
	var line := "end_out"
	if World.flag("killed_marta"): line = "end_out_kill"
	elif World.flag("marta_calmed"): line = "end_out_calm"
	await Speech.say_id(line)
	await hud.fade_to(1.0, 2.0)
	var marta_fate := "killed" if World.flag("killed_marta") else ("knew you" if World.flag("marta_known") else ("calmed" if World.flag("marta_calmed") else "still in the walls"))
	var summary := "BUILDING 14\n\nOut through the street door, into the white.\nMarta: %s.\nMemories recovered: %d.   The infection: %d%%.\nSocko: %s." % [
		marta_fate, Progress.found.size() - Progress.shards, int(Progress.infection() * 100.0),
		["", "your friend", "a little confused", "insistent", "passive-aggressive", "irritated", "pleading", "not your friend"][mind.stage()]]
	World.set_flag("ended", via)
	World.emit_event("ended", {"via": via, "marta": marta_fate})
	hud.show_text("", summary)
