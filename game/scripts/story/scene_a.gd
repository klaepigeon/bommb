class_name SceneA
extends Node
## Scene A, beat by beat, as the owner wrote it:
##   knocks → "Ms. Sokolov?…" → knocks again → "Marta? It's Kurt. I'm coming in." → he goes in;
##   the apartment → "Christ..."; her body → "Oh... oh no."; examining her → "What the hell is
##   this?", her boxes, "Marta?", "my little bird", the grab, a gasp, black;
##   waking → "Oh, jeez, that smarts" (rubbing his head) → Socko → … → "Shouldn't have stood up so fast.";
##   the front door, now shut → "It won't open." → "Maybe it's locked?" → … → "I like helping."
## No intro text. Lines live in content/scene_a.json.

signal stage_changed(stage: String)
signal into_town

var flat: Flat47
var marta: Marta
var player: Player
var hud: Hud
var stage := ""
var busy := false
var _seen_flat := false
var _seen_marta := false
var _door_tried := false

## The flat's own things (the first build's text): a line for small things, the paper for notes.
func _look_at(r: Node) -> void:
	var title := String(r.get_meta("title", ""))
	var desc := String(r.get_meta("desc", ""))
	if desc == "":
		desc = title
	if String(r.get("prompt")) == "Read" and desc.length() > 90:
		hud.reader.open({"title": title, "text": desc})
		get_tree().paused = true
		await hud.reader.closed
		get_tree().paused = false
	else:
		hud.caption(desc, clampf(desc.length() * 0.06, 3.0, 9.0))

func _set_stage(s: String) -> void:
	stage = s
	print("[scene_a] ", s)
	Trail.mark("stage " + s)
	stage_changed.emit(s)

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout

func say(id: String) -> void:
	await Speech.say_id(id)

func start(from := "") -> void:
	marta.spot.used.connect(_examine)
	flat.room_door.tried.connect(func(_d): _try_room_door())
	flat.wardrobe_spot.used.connect(_push_wardrobe)
	for r in flat.readables:
		r.connect("used", _look_at.bind(r))
	flat.hole_spot.used.connect(_crawl)
	if from == "wake":
		hud.fade.color.a = 1.0
		_seen_flat = true; _seen_marta = true
		marta.vanish()
		flat.room_door.set_angle(0.0)
		_wake()
		return
	if from == "door" or from == "wardrobe":
		_seen_flat = true; _seen_marta = true
		marta.vanish()
		flat.room_door.set_angle(0.0)
		flat.room_door.locked = true
		player.global_position = Flat47.POINTS["by_door"]
		player.face(flat.room_door.handle_position())
		player.socko.visible = true
		player.socko.set_pose("low", 0.0)
		hud.fade.color.a = 0.0
		if from == "wardrobe":
			_door_tried = true
			flat.wardrobe_spot.enabled = true
			player.face(flat.wardrobe.global_position + Vector3(0, 1, 0))
		_free()
		return
	_arrival()

# --- 1. the door -------------------------------------------------------------------------------

func _arrival() -> void:
	busy = true
	_set_stage("arrival")
	hud.fade.color.a = 1.0
	hud.set_crosshair(false)
	player.global_position = Flat47.POINTS["landing"]
	player.face(Flat47.POINTS["door_out"])
	await wait(1.4)
	var knock_at := flat.front_door.handle_position() + Vector3(0.05, 0.3, 0)
	_knocks(knock_at, 3, 0.0)
	hud.fade_to(0.0, 3.0)
	await wait(1.8)
	await say("door_1")
	await wait(2.2)                            # nothing
	_knocks(knock_at, 3, 3.0)                  # harder
	await wait(1.6)
	await say("door_2")
	await wait(0.4)
	# he pushes it; it isn't locked
	player.arm.set_pose("push", 0.6)
	await wait(0.55)
	Sfx.play_at("creak", flat.front_door.handle_position(), -2.0)
	flat.front_door.swing(80.0, 2.6)
	await wait(0.8)
	player.arm.set_pose("down", 0.7)
	await wait(0.6)
	_control(true)
	busy = false
	_set_stage("explore")

func _knocks(at: Vector3, count: int, louder: float) -> void:
	for i in count:
		Sfx.play_at("knock", at, -2.0 + louder, randf_range(0.95, 1.05))
		await wait(0.32 if i < count - 1 else 0.0)

func _control(on: bool) -> void:
	player.can_move = on
	player.can_look = on
	hud.set_crosshair(on)
	if not on:
		hud.set_prompt("")

# --- 2. what he sees ---------------------------------------------------------------------------

func _process(_d: float) -> void:
	# gutterspace nuggets in the room (they're only there after he wakes)
	if player.socko.visible:
		for n in flat.flat_nuggets:
			n.visible = true
			if not n.taken and n.global_position.distance_to(player.global_position + Vector3(0, 0.6, 0)) < 0.9:
				n.take()
				Game.add_nuggets(1)
	if stage != "explore" or busy:
		return
	var p := player.global_position
	if not _seen_flat and p.x < 9.7 and p.z > 3.8 and p.z < 5.2:
		_seen_flat = true
		_line_in_play("see_flat")
	elif _seen_flat and not _seen_marta and _can_see_marta():
		_seen_marta = true
		_line_in_play("see_marta", func(): marta.spot.enabled = true)

func _line_in_play(id: String, after := Callable()) -> void:
	busy = true
	await say(id)
	busy = false
	if after.is_valid():
		after.call()

func _can_see_marta() -> bool:
	var cam := player.camera
	var target := marta.head.global_position
	if cam.global_position.distance_to(target) > 7.5 or not cam.is_position_in_frustum(target):
		return false
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, target, 1, [player.get_rid()])
	return player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

# --- 3. her ------------------------------------------------------------------------------------

func _examine() -> void:
	if busy or stage != "explore":
		return
	busy = true
	_set_stage("marta")
	_control(false)
	marta.spot.enabled = false
	# he goes close: round to her side of the table, down to her level
	var face := marta.head.global_position + Vector3(0, 0.05, 0)
	var stand := marta.global_transform * Vector3(-0.75, 0, 0.05)    # at her left, beside the table
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(player, "global_position", Vector3(stand.x, player.global_position.y, stand.z), 1.4)
	player.look_toward(face, 1.4)
	await tw.finished
	var lean := create_tween()
	lean.tween_property(player.head, "position:y", Player.EYE - 0.35, 1.2).set_trans(Tween.TRANS_SINE)
	player.look_toward(face, 1.2)
	player.arm.set_pose("reach", 1.2)
	await wait(1.0)
	await say("examine")
	await wait(1.6)
	# she lifts her head to him
	marta.look_target = player.camera.global_position
	var lift := create_tween()
	lift.tween_property(marta, "head_lift", 1.0, 2.6).set_trans(Tween.TRANS_SINE)
	player.arm.set_pose("down", 0.8)
	player.look_toward(marta.head.global_position + Vector3(0, 0.12, 0), 2.0)
	await wait(2.4)
	await say("boxes")
	await wait(0.5)
	await say("marta_q")
	await wait(0.6)
	await say("little_bird")
	await wait(1.1)
	# the grab: no warning
	Sfx.play("sting", 0.0)
	marta.grab(player.camera.global_position)
	player.arm.set_pose("brace", 0.15)
	player.shake(0.035, 0.6)
	var pull := create_tween().set_parallel(true)
	pull.tween_property(player, "global_position", player.global_position.lerp(Vector3(marta.global_position.x, player.global_position.y, marta.global_position.z), 0.35), 0.25)
	player.look_toward(marta.head.global_position, 0.2)
	await wait(0.12)
	Sfx.play("gasp", 2.0)
	Speech.say_id("gasp")
	await wait(0.55)
	hud.fade.color.a = 1.0
	Sfx.play("thud", 0.0)
	Sfx.set_muffle(1.0)
	await wait(1.0)
	# while he's out: she goes; the front door shuts
	marta.vanish()
	flat.room_door.set_angle(0.0)
	flat.room_door.locked = true
	Sfx.play_at("slam", flat.room_door.handle_position(), -6.0, 0.9)
	await wait(2.4)
	_wake()

# --- 4. waking, and Socko ----------------------------------------------------------------------

func _wake() -> void:
	busy = true
	_set_stage("wake")
	_control(false)
	player.arm.set_pose("down", 0.0)
	player.head.position.y = Player.EYE
	var where := marta.global_transform * Vector3(0.55, 0, -0.1)    # on the floor at her right, where she let him fall
	player.global_position = Vector3(where.x, 0, where.z)
	player.face(marta.global_transform * Vector3(0.0, 0.6, 0.2))
	# on the floor, on his side, looking at the ceiling
	player.head.position.y = 0.28
	player.shake_node.rotation.z = 0.9
	player.head.rotation.x = 1.1
	player.body_mesh.visible = false
	Sfx.play("tinnitus", -8.0)
	var clear := create_tween()
	clear.tween_method(Sfx.set_muffle, 1.0, 0.0, 6.0)
	hud.fade_to(0.0, 3.5)
	await wait(2.0)
	# he sits up
	var up := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	up.tween_property(player.head, "position:y", 0.95, 2.6)
	up.tween_property(player.shake_node, "rotation:z", 0.08, 2.6)
	up.tween_method(player._set_pitch, 1.1, -0.15, 2.6)
	await wait(2.0)
	player.arm.set_pose("rub", 0.7)
	await wait(0.5)
	player.arm.rub = 1.0
	await say("smarts")
	await wait(0.4)
	player.arm.rub = 0.0
	player.arm.set_pose("down", 0.8)
	await wait(1.0)
	# the left hand comes up. It's got a sock on it.
	var sk := player.socko
	sk.enter()
	await wait(0.7)
	sk.set_pose("talk", 0.8)
	sk.face_kurt = 0.0
	create_tween().tween_property(sk, "face_kurt", 1.0, 0.7)
	sk.emotion = "happy"
	await wait(0.5)
	await say("hey_buddy")
	# Kurt recoils from his own hand
	player.shake(0.02, 0.35)
	var recoil := create_tween()
	recoil.tween_property(player.head, "position:z", 0.12, 0.15)
	sk.gesture("startle", 0.6)
	await say("wtf")
	sk.emotion = "curious"
	sk.gesture("tilt", 1.0)
	await say("who_me")
	await say("who_are_you")
	sk.emotion = "proud"
	sk.gesture("bounce", 1.0)
	sk.gesture("wiggle", 0.8)
	await say("im_socko")
	sk.emotion = "neutral"
	await say("kurt_sounds")
	sk.emotion = "curious"
	sk.gesture("tilt", -1.0)
	sk.divided_glance(flat.room_door.handle_position(), 1.3)
	await say("dont_know")
	await say("got_nothing")
	# he gets up too fast
	var stand := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	stand.tween_property(player.head, "position:y", Player.EYE, 1.0)
	stand.tween_property(player.head, "position:z", 0.0, 1.0)
	stand.tween_property(player.shake_node, "rotation:z", 0.0, 1.6)
	player.shake(0.02, 1.6)
	sk.set_pose("up", 0.8)
	await wait(0.5)
	var sway := create_tween().set_trans(Tween.TRANS_SINE)
	sway.tween_property(player.shake_node, "rotation:z", -0.12, 0.6)
	sway.tween_property(player.shake_node, "rotation:z", 0.06, 0.7)
	sway.tween_property(player.shake_node, "rotation:z", 0.0, 0.8)
	sk.emotion = "neutral"
	sk.gesture("nod", 0.6)
	await say("too_fast")
	await wait(0.3)
	player.body_mesh.visible = true
	create_tween().tween_property(sk, "face_kurt", 0.0, 0.8)
	sk.set_pose("low", 1.0)
	_free()

func _free() -> void:
	_control(true)
	busy = false
	_set_stage("explore")

# --- 5. the door they came in by (the living room's, shut while he was out) ---------------------

func _try_room_door() -> void:
	if busy:
		return
	busy = true
	var first := not _door_tried
	_door_tried = true
	player.can_move = false
	player.arm.set_pose("handle", 0.4)
	await wait(0.35)
	player.arm.rattle = 1.0
	await wait(0.9)
	player.arm.rattle = 0.0
	if not first:
		player.arm.set_pose("down", 0.5)
		player.can_move = true
		busy = false
		return
	_set_stage("door")
	_control(false)
	await say("wont_open")
	player.arm.set_pose("down", 0.5)
	var sk := player.socko
	sk.set_pose("talk", 0.6)
	create_tween().tween_property(sk, "face_kurt", 1.0, 0.5)
	sk.emotion = "curious"
	sk.gesture("tilt", 1.0)
	await say("locked")
	await say("thanks")
	# genuine
	sk.emotion = "happy"
	sk.gesture("bounce", 1.0)
	sk.gesture("nod", 0.8)
	await say("welcome")
	# to himself: eyes drift off, head turns away a little
	create_tween().tween_property(sk, "face_kurt", 0.35, 0.6)
	sk.emotion = "proud"
	sk.gesture("wiggle", 0.4)
	await say("like_helping")
	await wait(0.4)
	sk.emotion = "neutral"
	create_tween().tween_property(sk, "face_kurt", 0.0, 0.8)
	sk.set_pose("low", 1.0)
	flat.wardrobe_spot.enabled = true
	_set_stage("scene_a_done")
	_control(true)
	busy = false

# --- 6. the wardrobe ---------------------------------------------------------------------------

func _push_wardrobe() -> void:
	if busy:
		return
	busy = true
	player.can_move = false
	# he steps to its free end and puts his shoulder and hand to it
	player.arm.set_pose("push", 0.3)
	player.shake(0.01, 0.4)
	await wait(0.25)
	var clear := flat.shove_wardrobe()
	await wait(0.7)
	player.arm.set_pose("down", 0.4)
	if not clear:
		player.can_move = true
		busy = false
		return
	flat.wardrobe_spot.enabled = false
	_set_stage("hole")
	_control(false)
	await wait(0.4)
	player.look_toward(flat.hole_center + Vector3(0, 0.1, 0), 1.2)
	var crouch := create_tween()
	crouch.tween_property(player.head, "position:y", Player.EYE - 0.4, 1.2).set_trans(Tween.TRANS_SINE)
	await wait(1.4)
	await say("what_is_that")
	var sk := player.socko
	sk.set_pose("talk", 0.6)
	create_tween().tween_property(sk, "face_kurt", 1.0, 0.5)
	sk.emotion = "neutral"
	sk.gesture("tilt", -0.6)
	await say("dunno")
	await say("know_anything")
	sk.emotion = "proud"
	sk.gesture("bounce", 0.8)
	await say("can_do_this")
	# he goes cross-eyed
	sk.cross_eyes(true)
	sk.emotion = "happy"
	await wait(1.6)
	sk.cross_eyes(false)
	await wait(0.3)
	sk.gesture("startle", 0.4)
	sk.emotion = "happy"
	sk.point_at(flat.hole_center)
	await say("smell")
	await wait(0.4)
	sk.point_at(Vector3.INF)
	create_tween().tween_property(sk, "face_kurt", 0.0, 0.6)
	sk.set_pose("low", 0.8)
	create_tween().tween_property(player.head, "position:y", Player.EYE, 0.8)
	flat.hole_spot.enabled = true
	_set_stage("hole_open")
	_control(true)
	busy = false

func _crawl() -> void:
	if busy:
		return
	busy = true
	_control(false)
	flat.hole_spot.enabled = false
	player.look_toward(flat.hole_center, 0.5)
	var down := create_tween()
	down.tween_property(player.head, "position:y", 0.6, 0.8).set_trans(Tween.TRANS_SINE)
	Sfx.play("scrape", -6.0, 0.7)
	await wait(0.5)
	await hud.fade_to(1.0, 0.6).finished
	player.head.position.y = Player.EYE
	busy = false
	_set_stage("town")
	into_town.emit()
