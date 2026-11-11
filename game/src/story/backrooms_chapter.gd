extends Node
## The Backrooms. Directs only what has to be directed: the arrival, the first sight of Marta (the
## owner's maze lines), the gun as a moment, getting caught, and the ways out. Everything between
## is the systems: Marta's senses, the doors, the light, the noise, the tools.
##
## Routes to Flat 48 (each recorded; all converge):
##   door     the padlock on 48: key (box room, via kitchen B's drawer or the box room's lock),
##            bolt cutters (quiet), crowbar (loud), hammer (loud), a bullet (loudest)
##   vent     the bathroom panel: unscrew it (quiet, slow), smash it, or shoot it; crawl through
##   balcony  carry the plank from the corridor to the living room's balcony; walk across

var main: Node
var level: Level
var player: Player
var marta: MartaHunter
var gun_taken := false
var encounter_done := false
var bridged := false
var _plank: Prop
var _t := 0.0
var _check := 0.0
var _corridor_t := -1.0
var _leaving := false
var _said_same := false
var _fail_ui: Control

func begin(p_main: Node, spawn: String) -> void:
	main = p_main
	level = main.level
	player = main.player
	if SockoDirector.inst:
		SockoDirector.inst.setup(player)
	level.trigger_entered.connect(_on_trigger)
	Events.player_caught.connect(_on_caught)
	Story.recorded.connect(_on_record)
	for b in level.breakables:
		if b.break_id == "vent":
			b.broke.connect(func(_x): _vent_open(b))
	for p in level.get_tree().get_nodes_in_group("props"):
		if p is Prop and (p as Prop).persist_id == "the_plank":
			_plank = p
	_spawn_marta()
	_ensure_music_box()
	_scrawl_13()
	Sfx.set_ambience("drone_wrong", -12.0)
	if spawn == "restore":
		return
	_arrive()

func _spawn_marta() -> void:
	marta = MartaHunter.new()
	marta.name = "MartaHunter"
	level.dynamic_root().add_child(marta)
	var a: Array = level.data.marta_start
	marta.setup(level, player, Vector3(a[0], a[1], a[2]), level.data.patrol)
	marta.rotation.y = PI * 0.5        # facing west, down the corridor
	marta._yaw = marta.rotation.y

## "13", over and over, on the arrival room's wall (readable; Socko reads it out anyway)
func _scrawl_13() -> void:
	Kit.place(level, {"t": "paper", "room": "arrival", "p": [1.2, 4.93], "r": 0, "h": 1.5, "doc": "scrawl_13"})
	for i in 5:
		var lb := Label3D.new()
		lb.text = "13"
		lb.font_size = 64 - i * 10
		lb.pixel_size = 0.01
		lb.modulate = Color(0.25, 0.05, 0.04)
		lb.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		level.add_child(lb)
		lb.global_position = Vector3(0.7 + i * 0.32, 1.95 - i * 0.28, 4.93)
		lb.rotation.y = PI

## if Kurt left the music box in Flat 47, there's one here too (on the middle bed)
func _ensure_music_box() -> void:
	if player.inv.has("music_box"):
		return
	Kit.place(level, {"t": "prop", "room": "sonya_w", "kind": "music_box", "p": [1.6, 8.6], "y": 0.42, "lift": 0.05})

func _arrive() -> void:
	player.crouching = true
	player.locked = true
	main.set_blackout(0.92)
	main.set_blackout(0.0, 2.2)
	var t := create_tween()
	t.tween_property(player, "global_position", Vector3(1.0, 0.0, 3.4), 1.2)
	await t.finished
	player.locked = false
	player.crouching = false
	await get_tree().create_timer(1.0).timeout
	if player.socko:
		player.socko.set_pose("talk", 0.5)
	await Speech.speak(["k_same_room", "s_after_crawl"])
	# the wall says where to go, and Socko keeps it for him
	if player.socko:
		player.socko.point_at(Vector3(1.2, 1.8, 4.95))
	await Speech.speak(["s_13_spot"])
	Story.set_flag("knows_13", true)
	Story.record("clue.found:thirteen")
	if player.socko:
		player.socko.point_at(Vector3(15.0, 1.0, 2.0))
	if SockoDirector.inst:
		SockoDirector.inst.suggest("go_gun")
	await get_tree().create_timer(1.5).timeout
	if player.socko:
		player.socko.set_pose("low", 0.8)
	SaveGame.save_game(main, "backrooms")

# ---------------------------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	if not player or _leaving:
		return
	_t += delta
	Infection.expose(0.0012, delta)
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.2
	# the first sight of her
	if not encounter_done and marta.state == "dormant" and _corridor_t >= 0.0:
		if _sees(marta.eye(), 15.0, 30.0) or _t - _corridor_t > 75.0 or gun_taken:
			_encounter()
	# the plank: let go of it across the gap and it settles into a bridge
	if not bridged and _plank and is_instance_valid(_plank) and not _plank.held:
		var pp := _plank.global_position
		if Vector2(pp.x - 15.5, pp.z - 13.0).length() < 1.6 and pp.y > -1.5 and pp.y < 1.5:
			_bridge()
	# Socko's ideas
	if SockoDirector.inst and player.gun and player.gun.loaded > 0:
		var lock: Node = level.doors.get("flat48_door").padlock if level.doors.has("flat48_door") else null
		if lock and lock.is_locked() and player.global_position.distance_to((lock as Node3D).global_position) < 3.0:
			SockoDirector.inst.suggest("shoot_lock")
		if marta.state == "chase" and marta._sees > 0.0:
			SockoDirector.inst.suggest("shoot_her")
	if SockoDirector.inst and player.inv.with_tag("strike") != "":
		for b in level.breakables:
			if b.break_id == "vent" and not b.done and player.global_position.distance_to(b.global_position) < 2.0:
				SockoDirector.inst.suggest("smash")

func _sees(p: Vector3, dist: float, angle: float) -> bool:
	var cam := player.camera
	var to := p - cam.global_position
	if to.length() > dist or rad_to_deg((-cam.global_transform.basis.z).angle_to(to)) > angle:
		return false
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, p, 1)
	q.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _encounter() -> void:
	encounter_done = true
	Story.record("marta.encountered")
	Events.beat.emit("marta")
	if player.socko:
		player.socko.set_pose("talk", 0.4)
	await Speech.speak(["maze_1", "maze_2", "maze_3", "maze_4"])
	if player.socko:
		player.socko.set_pose("low", 0.6)
	marta.wake()
	marta.suspicion = 0.5
	marta._investigate(player.global_position, null)

func _on_trigger(id: String) -> void:
	match id:
		"corridor_first":
			_corridor_t = _t
		"living_again":
			if not _said_same:
				_said_same = true
				Speech.bark("k_wrong")
		"to48_door":
			_leave("door")
		"to48_balcony":
			_leave("balcony")
		"fall":
			_fell()
		"crawlspace":
			Story.record("clue.found:crawlspace")

func _on_record(key: String, _d: Dictionary) -> void:
	if key == "took:revolver" and not gun_taken:
		give_gun(true)

## the revolver becomes a weapon Kurt carries
func give_gun(fresh: bool) -> void:
	gun_taken = true
	if player.gun:
		return
	var g := Revolver.new()
	g.name = "Revolver"
	player.add_child(g)
	g.setup(player)
	player.gun = g
	if not player.inv.has("revolver"):
		player.inv.add("revolver")
	if fresh:
		Events.beat.emit("gun")
		await Speech.speak(["k_gun", "s_gun_found"])
		SaveGame.save_game(main, "gun")

# ---------------------------------------------------------------------------------- the routes

func _bridge() -> void:
	bridged = true
	_plank.freeze = true
	_plank.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	var t := create_tween()
	t.tween_property(_plank, "global_transform", Transform3D(Basis.IDENTITY, Vector3(15.5, 0.0, 13.0)), 0.35).set_trans(Tween.TRANS_QUAD)
	Sfx.play_at("thud_heavy", Vector3(15.5, 0.2, 13.0), 0.0, 0.9, 6.0)
	Story.record("route.plank_bridge")
	_plank.collision_layer = 1 | 2

func _vent_open(b: Node) -> void:
	var body := StaticBody3D.new(); body.collision_layer = 32
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(0.6, 0.6, 0.4); cs.shape = bs
	body.add_child(cs)
	level.add_child(body)
	body.global_position = (b as Node3D).global_position + Vector3(0, 0, 0.1)
	var dark := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(0.6, 0.6)
	dark.mesh = qm; dark.material_override = Mats.flat("black", Color(0, 0, 0))
	level.add_child(dark)
	dark.global_position = (b as Node3D).global_position + Vector3(0, 0, 0.3)
	Hook.attach(body, VentTarget.new(self), "The vent")

func _leave(route: String) -> void:
	if _leaving:
		return
	_leaving = true
	var how := route
	if route == "door":
		for k in ["route.padlock_key", "route.padlock_cut", "route.padlock_pried", "route.padlock_smashed", "route.padlock_shot"]:
			if Story.has(k):
				how = "door:" + k.trim_prefix("route.padlock_")
	Story.record("route." + route)
	Story.set_flag("route_out", how)
	Story.set_flag("marta_state", _marta_state())
	Story.set_flag("marta_hits", marta.hit_count)
	Events.beat.emit("leaving")
	player.locked = true
	if route == "vent":
		Sfx.play("crawl", -2.0)
	await main.set_blackout(1.0, 1.2)
	player.locked = false
	# down the stairs, round and round, and out: the building's own front door
	for i in 8:
		Sfx.play("step_concrete", -8.0, 0.9)
		await get_tree().create_timer(0.28 if not Speech.fast else 0.02).timeout
	main.load_level("ground_floor", "entrance")

func _marta_state() -> String:
	if marta.state == "dead":
		return "dead"
	if marta.state == "pacified" or (Story.has("stealth.pacified") and marta.hit_count == 0):
		return "calm"
	if marta.hit_count > 0:
		return "wounded"
	if not encounter_done:
		return "unmet"
	return "hunting"

func _fell() -> void:
	player.locked = true
	await main.set_blackout(1.0, 0.3)
	player.global_position = Vector3(15.5, 0.0, 9.5)
	player.velocity = Vector3.ZERO
	player.injure(1)
	Infection.add(0.05)
	Story.record("hurt.fell")
	await get_tree().create_timer(0.8).timeout
	main.set_blackout(0.0, 1.0)
	player.locked = false

# ---------------------------------------------------------------------------------- caught

var _handling_catch := false

func _on_caught(_by: Node) -> void:
	if _leaving or _handling_catch:
		return
	_handling_catch = true
	# she's moved off him at once (the scene goes dark over it)
	var far: Array = level.data.patrol[2]
	marta.reset_to(Vector3(far[0], far[1], far[2]))
	player.locked = true
	player.look_locked = true
	Sfx.play("grab", 2.0)
	player.shake(1.5)
	main.set_post("hurt", 1.0)
	await main.set_blackout(1.0, 0.4)
	Speech.stop_all()
	var n := Story.count("caught")
	if n >= 3:
		_fail()
		return
	player.injure(1)
	player.global_transform = level.spawns["caught"]
	player._pitch = 0.0
	await get_tree().create_timer(1.5 if not Speech.fast else 0.1).timeout
	main.set_blackout(0.0, 1.5)
	player.locked = false
	player.look_locked = false
	main.set_post("hurt", 0.0, 2.0)
	_handling_catch = false
	await Speech.speak(["k_caught_wake", "s_caught"])

## the third time: the boxes have him. Try again from the last checkpoint.
func _fail() -> void:
	Events.beat.emit("failed")
	Story.record("failed")
	_fail_ui = Control.new()
	_fail_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fail_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := UIKit.fullscreen_dim(1.0); _fail_ui.add_child(bg)
	var vb := VBoxContainer.new(); vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.add_theme_constant_override("separation", 22)
	var l := UIKit.label("Kurt doesn't get up this time.", 30, Color(0.85, 0.75, 0.7))
	var retry := UIKit.button("  Try again from the last checkpoint  ")
	retry.pressed.connect(func():
		_fail_ui.queue_free()
		get_tree().paused = false
		Story.counters["caught"] = 0
		SaveGame.load_game(main))
	vb.add_child(l); vb.add_child(retry)
	_fail_ui.add_child(vb)
	main.hud.root.add_child(_fail_ui)
	vb.position = main.hud.root.get_viewport_rect().size * 0.5 - Vector2(300, 60)

# ---------------------------------------------------------------------------------- save

func get_state() -> Dictionary:
	return {"gun": gun_taken, "encounter": encounter_done, "bridged": bridged, "marta": marta.get_state() if marta else {},
		"plank": var_to_str(_plank.global_transform) if _plank and is_instance_valid(_plank) else ""}

func set_state(d: Dictionary) -> void:
	encounter_done = d.get("encounter", false)
	_corridor_t = 0.0
	if d.get("gun", false):
		give_gun(false)
	if marta and d.has("marta"):
		marta.set_state_dict(d.marta)
	if d.get("bridged", false) and _plank:
		_bridge()
	elif _plank and String(d.get("plank", "")) != "":
		_plank.global_transform = str_to_var(d.plank)


class VentTarget:
	extends RefCounted
	var d: Node
	func _init(p_d: Node) -> void:
		d = p_d
	func iverbs(_p: Node) -> Array:
		return [Interactable.v("crawl", "Crawl into the vent")]
	func iverb(id: String, _p: Node) -> void:
		if id == "crawl":
			d._leave("vent")
	func ifocus() -> Vector3:
		return Vector3(9.6, 0.6, 10.0)
