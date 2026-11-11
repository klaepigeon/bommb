extends Node
## Scene A: Flat 47. The owner's opening, as written (docs/SCRIPT_OPENING.md), and the flat as an
## ordinary place first. Nothing here is a tutorial: the flat is there to explore, its drawers and
## cupboards open, its papers can be read, and the systems (doors, locks, light, weight, noise)
## show themselves by being used.
##
## Beats:  intro (knocks) → explore → seen (Marta in view) → examine → black → awake (Socko) →
##         [door won't open] [balcony] → revealed (the wardrobe moved) → crawl → the Backrooms

const MARTA_POS := Vector3(2.5, 0.0, 1.3)
const HOLE := Vector3(0.0, 0.7, 3.4)

var main: Node
var level: Level
var player: Player
var state := "intro"
var marta: MartaModel
var marta_hook: Hook
var wardrobe: Prop
var _wardrobe_start := Vector3.ZERO
var _plug: StaticBody3D
var _hole_body: StaticBody3D
var _tried_door := false
var _balcony_done := false
var _check_t := 0.0
var _socko_dir: SockoDirector

func begin(p_main: Node, spawn: String) -> void:
	main = p_main
	level = main.level
	player = main.player
	_socko_dir = _ensure_socko_director()
	_place_marta()
	_find_wardrobe()
	_plug_hole()
	level.trigger_entered.connect(_on_trigger)
	for id in ["living_door", "kitchen_side", "balcony_door"]:
		if level.doors.has(id):
			(level.doors[id] as Door).tried.connect(_on_tried)
	if spawn == "restore":
		return       # set_state() follows
	Story.reset()
	Infection.reset()
	player.inv.add("telegram")
	_intro()

func _ensure_socko_director() -> SockoDirector:
	if SockoDirector.inst and is_instance_valid(SockoDirector.inst):
		SockoDirector.inst.setup(player)
		return SockoDirector.inst
	var s := SockoDirector.new()
	s.name = "SockoDirector"
	main.add_child(s)
	s.setup(player)
	return s

# ---------------------------------------------------------------------------------- setup

func _place_marta() -> void:
	marta = MartaModel.new()
	marta.name = "Marta"
	level.dynamic_root().add_child(marta)
	marta.global_transform = Transform3D(Basis(Vector3.UP, PI), MARTA_POS)
	Player.set_layer(marta, Level.CHAR_LAYER)
	var b := StaticBody3D.new(); b.collision_layer = 32 | 1
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(0.6, 1.3, 0.6); cs.shape = bs
	b.add_child(cs); marta.add_child(b); b.position = Vector3(0, 0.65, 0)
	marta_hook = Hook.attach(b, self, "Marta Sokolova")

func _find_wardrobe() -> void:
	for p in level.get_tree().get_nodes_in_group("props"):
		if p is Prop and (p as Prop).persist_id == "living_wardrobe":
			wardrobe = p
			_wardrobe_start = p.global_position

## until the blackout the wall behind the wardrobe is just a wall
func _plug_hole() -> void:
	_plug = StaticBody3D.new(); _plug.name = "HolePlug"; _plug.collision_layer = 1
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(0.14, 1.2, 0.84); cs.shape = bs
	_plug.add_child(cs)
	var mb := MB.new()
	mb.plane("damask", Vector3(0.061, 0.11, 3.0 + 0.42), Vector3(0, 0, -0.84), Vector3(0, 1.17, 0), Vector3(1, 0, 0), Mats.uvm("damask"), 0.5, Vector2(-3.0, -0.1) / Mats.uvm("damask"))
	var rm: Mats.RoomMats = level.rooms["living"].mats
	var mi := MeshInstance3D.new(); mi.mesh = mb.commit(rm.dict_for(mb), func(pos, n): return level.bake("living", pos, n))
	_plug.add_child(mi)
	level.add_child(_plug)
	_plug.position = Vector3(0, 0, 0.0)
	cs.position = Vector3(0.0, 0.7, 3.4)

func _open_hole() -> void:
	if _plug:
		_plug.queue_free()
		_plug = null
	# the dark inside the hole, and something to crawl into
	_hole_body = StaticBody3D.new(); _hole_body.collision_layer = 32
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(0.3, 1.0, 0.7); cs.shape = bs
	_hole_body.add_child(cs)
	level.add_child(_hole_body)
	_hole_body.position = HOLE + Vector3(-0.12, 0, 0)
	var dark := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(0.8, 1.15)
	dark.mesh = qm; dark.material_override = Mats.flat("black", Color(0, 0, 0))
	dark.rotation.y = PI * 0.5
	level.add_child(dark)
	dark.position = Vector3(-0.28, 0.12 + 0.575, 3.4)
	# a glimmer, a long way off
	var glim := OmniLight3D.new(); glim.light_color = Color(0.9, 0.85, 0.5); glim.light_energy = 0.4; glim.omni_range = 1.2
	level.add_child(glim); glim.position = Vector3(-0.8, 0.6, 3.4)

# ---------------------------------------------------------------------------------- the intro

func _intro() -> void:
	state = "intro"
	player.locked = true
	main.set_blackout(1.0)
	await get_tree().create_timer(0.8).timeout
	main.set_blackout(0.0, 2.5)
	var door: Door = level.doors["front_door"]
	await get_tree().create_timer(1.6).timeout
	Sfx.play_at("knock", door.ifocus(), 2.0, 1.0, 6.0)
	await get_tree().create_timer(1.2).timeout
	await Speech.speak(["door_1"])
	await get_tree().create_timer(1.4).timeout
	Sfx.play_at("knock", door.ifocus(), 4.0, 0.95, 6.0)
	await get_tree().create_timer(1.3).timeout
	await Speech.speak(["door_2"])
	# the door's not on the latch: it gives a little under his hand
	door.open_instant(0.0)
	door._target = 0.18
	Sfx.play_at("door_open", door.ifocus(), -4.0, 0.8, 3.0)
	player.locked = false
	state = "explore"
	Events.beat.emit("explore")

func _on_trigger(id: String) -> void:
	match id:
		"see_flat":
			if state in ["explore", "intro"]:
				Speech.queue(["see_flat"])
		"balcony":
			if state in ["awake", "revealed"] and not _balcony_done:
				_balcony_done = true
				player.face_point(Vector3(2.5, 1.5, -2.6), 1.2)
				Speech.queue(["balcony_1", "balcony_2", "balcony_3", "balcony_4"])
				Story.record("clue.examined:outside")

func _process(delta: float) -> void:
	if not player:
		return
	_check_t += delta
	if _check_t < 0.2:
		return
	_check_t = 0.0
	if state == "explore" and _sees_marta():
		state = "seen"
		Speech.queue(["see_marta"])
		Events.beat.emit("seen")
	if state == "awake" and wardrobe and is_instance_valid(wardrobe):
		if wardrobe.global_position.distance_to(_wardrobe_start) > 0.55 and _can_see(HOLE, 5.0, 45.0):
			_reveal()

func _sees_marta() -> bool:
	return _can_see(MARTA_POS + Vector3(0, 1.1, 0), 7.0, 32.0)

func _can_see(p: Vector3, dist: float, angle: float) -> bool:
	var cam := player.camera
	var to := p - cam.global_position
	if to.length() > dist:
		return false
	if rad_to_deg((-cam.global_transform.basis.z).angle_to(to)) > angle:
		return false
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, p, 1)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or (hit.position as Vector3).distance_to(p) < 0.6

# ---------------------------------------------------------------------------------- Marta

func iverbs(_p: Node) -> Array:
	if state in ["explore", "seen"]:
		return [Interactable.v("examine", "Examine her")]
	return []

func iverb(id: String, _p: Node) -> void:
	if id == "examine" and state in ["explore", "seen"]:
		if state == "explore":
			await Speech.speak(["see_marta"])
		_examine()

func ifocus() -> Vector3:
	return MARTA_POS + Vector3(0, 1.0, 0)

func _examine() -> void:
	state = "examine"
	Events.beat.emit("examine")
	Story.record("clue.examined:marta")
	player.locked = true
	player.look_locked = true
	if player.held:
		player.drop()
	# he goes round to her side and leans in
	var side := MARTA_POS + Vector3(0.7, 0, 0.45)
	var t := create_tween()
	t.tween_property(player, "global_position", Vector3(side.x, player.global_position.y, side.z), 1.3).set_trans(Tween.TRANS_SINE)
	player.face_point(MARTA_POS + Vector3(0, 1.0, 0), 1.3)
	await t.finished
	player.crouching = true
	await Speech.speak(["examine"])
	# she lifts her head to him
	var cam := player.camera.global_position
	var k := {"v": 0.0}
	var ft := create_tween()
	ft.tween_method(func(v):
		marta.joints.head.rotation = MartaModel.HEAD_REST.lerp(Vector3.ZERO, v)
		if v > 0.5: marta.face(cam, MartaModel.JAW_OPEN * v), 0.0, 1.0, 2.2).set_trans(Tween.TRANS_SINE)
	Sfx.play_at("creak", MARTA_POS + Vector3(0, 1, 0), -6.0, 0.6)
	await Speech.speak(["boxes", "marta_q", "little_bird"])
	# she takes hold of him
	player.shake(1.2)
	Sfx.play("grab", 0.0)
	player.arm.set_pose("brace", 0.1)
	var tw := create_tween()
	tw.tween_property(player, "global_position", MARTA_POS + Vector3(0.35, player.global_position.y, 0.3), 0.25)
	Speech.queue(["gasp"])
	await main.set_blackout(1.0, 0.35)
	_world_shift()
	await get_tree().create_timer(3.0 if not Speech.fast else 0.3).timeout
	_wake()

## what's different when he opens his eyes
func _world_shift() -> void:
	state = "black"
	Story.set_flag("woke", true)
	Story.record("beat.blackout")
	Infection.add(0.08)
	marta.joints.hips.visible = false            # her chair is empty, still grown through
	if marta.flies:
		marta.flies.emitting = false
	marta_hook.enabled = false
	for id in ["living_door", "kitchen_side"]:
		var d: Door = level.doors[id]
		d.open_instant(0.0)
		d.jammed = "wall"
		d.state_changed.emit(d)
	(level.doors["balcony_door"] as Door).jammed = ""
	_open_hole()
	_beyond_balcony()
	level.power.flicker["living"] = 0.2
	player.crouching = false

## nothing past the railing: pale, flat, and a note
func _beyond_balcony() -> void:
	var mb := MB.new()
	mb.plane("void", Vector3(-15, -12, -4.0), Vector3(30, 0, 0), Vector3(0, 30, 0), Vector3(0, 0, 1), 4.0, 8.0)
	mb.plane("void", Vector3(-15, -0.4, -4.0), Vector3(30, 0, 0), Vector3(0, 0, 3.0), Vector3.UP, 4.0, 8.0)
	var mi := MeshInstance3D.new(); mi.mesh = mb.commit({"void": Mats.flat("void", Color(0.5, 0.5, 0.48))})
	level.add_child(mi)
	Kit.place(level, {"t": "sticky", "room": "balcony", "p": [2.5, -2.4], "h": 1.45, "text": "OUTSIDE", "doc": "sticky_outside"})

func _wake() -> void:
	state = "waking"
	var spawn: Transform3D = level.spawns["wake"]
	player.global_transform = spawn
	player.set_mode("downed")
	player.look_locked = true
	player.head.position = Vector3(0, 0.22, 0)
	player.head.rotation = Vector3(0.15, 0, 0.9)
	main.set_post("wake", 1.0)
	main.set_blackout(0.0, 3.5)
	var ring := Sfx.loop_at("hum", player.head, -18.0, 1.0)
	if ring: ring.pitch_scale = 4.0
	await get_tree().create_timer(2.5 if not Speech.fast else 0.2).timeout
	player.arm.rub = 1.0
	player.arm.set_pose("rub", 0.6)
	await Speech.speak(["smarts"])
	player.set_socko(true)
	_socko_dir.awake = true
	player.socko.set_pose("up", 0.8)
	await Speech.speak(["hey_buddy", "wtf", "who_me", "who_are_you"])
	player.socko.set_pose("talk", 0.6)
	await Speech.speak(["im_socko", "kurt_sounds", "dont_know", "got_nothing"])
	# he gets up, through "Shouldn't have stood up so fast."
	player.arm.rub = 0.0
	player.arm.set_pose("down", 0.6)
	var t := create_tween().set_parallel()
	t.tween_property(player.head, "position", Vector3(0, Player.EYE, 0), 2.2).set_trans(Tween.TRANS_SINE)
	t.tween_property(player.head, "rotation", Vector3(0, 0, 0), 2.2).set_trans(Tween.TRANS_SINE)
	main.set_post("wake", 0.0, 4.0)
	await Speech.speak(["too_fast"])
	if is_instance_valid(ring):
		ring.queue_free()
	player.socko.set_pose("low", 0.8)
	player._pitch = 0.0
	player.set_mode("normal")
	player.look_locked = false
	player.locked = false
	state = "awake"
	Events.beat.emit("awake")
	SaveGame.save_game(main, "awake")

func _on_tried(d: Door, why: String) -> void:
	if why != "wall" or state not in ["awake", "revealed"]:
		return
	if not _tried_door:
		_tried_door = true
		player.socko.set_pose("talk", 0.4)
		await Speech.speak(["wont_open", "locked", "thanks", "welcome", "like_helping"])
		player.socko.set_pose("low", 0.6)
	else:
		Speech.bark("k_still_wont")

func _reveal() -> void:
	state = "revealed"
	Events.beat.emit("revealed")
	Story.set_flag("revealed", true)
	player.face_point(HOLE, 0.8)
	player.socko.set_pose("talk", 0.4)
	await Speech.speak(["what_is_that", "dunno", "know_anything"])
	player.socko.cross_eyes(true)
	await Speech.speak(["can_do_this"])
	player.socko.cross_eyes(false)
	player.socko.point_at(HOLE + Vector3(-2.0, 0, 0))
	await Speech.speak(["smell"])
	player.socko.set_pose("low", 0.8)
	Hook.attach(_hole_body, HoleTarget.new(self), "The hole")
	# the flat stops behaving: the radio comes on by itself, the lights go, something knocks
	for p in level.get_tree().get_nodes_in_group("props"):
		if p is Prop and (p as Prop).behaviour and (p as Prop).behaviour.has_method("silence") and p.name == "radio":
			(p as Prop).behaviour.set_on(true)
	level.power.flicker["corridor"] = 0.5
	Sfx.play_at("distant_knock", Vector3(13, 1, 8), -2.0)

func _crawl() -> void:
	state = "crawl"
	Events.beat.emit("crawl")
	player.locked = true
	player.crouching = true
	player.face_point(HOLE + Vector3(-1, -0.3, 0), 0.6)
	await get_tree().create_timer(0.6).timeout
	Sfx.play("crawl", -2.0)
	var t := create_tween()
	t.tween_property(player, "global_position", Vector3(0.3, 0.0, 3.4), 1.0)
	main.set_blackout(0.92, 1.4)
	await t.finished
	await get_tree().create_timer(0.4).timeout
	Story.record("backrooms.entered")
	player.locked = false
	main.load_level("backrooms", "arrival")

func get_state() -> Dictionary:
	return {"state": state, "balcony": _balcony_done, "tried": _tried_door,
		"wardrobe": var_to_str(wardrobe.global_position) if wardrobe and is_instance_valid(wardrobe) else ""}

func set_state(d: Dictionary) -> void:
	var s := String(d.get("state", "explore"))
	_balcony_done = d.get("balcony", false)
	_tried_door = d.get("tried", false)
	if wardrobe and String(d.get("wardrobe", "")) != "":
		wardrobe.global_position = str_to_var(d.wardrobe)
	if s in ["intro", "explore", "seen", "examine"]:
		state = "explore" if s != "seen" else "seen"
		return
	_world_shift()
	player.set_socko(true)
	_socko_dir.awake = true
	player.set_mode("normal")
	state = "awake"
	if s in ["revealed", "crawl"]:
		_reveal()


class HoleTarget:
	extends RefCounted
	var d: Node
	func _init(p_d: Node) -> void:
		d = p_d
	func iverbs(_p: Node) -> Array:
		return [Interactable.v("crawl", "Crawl through")] if d.state == "revealed" else []
	func iverb(id: String, _p: Node) -> void:
		if id == "crawl" and d.state == "revealed":
			d._crawl()
	func ifocus() -> Vector3:
		return d.HOLE
