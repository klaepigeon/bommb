extends Node
## The ground floor. Every way out of the maze ends the same way: Kurt walks in through Building
## 14's front door, into the lobby. Apartment 13 is down the corridor (Socko read it on the wall in
## the Backrooms and remembers it, so the player never has to). The Super walks this floor: a
## stealth sequence, solved by listening, the dark, doors, distractions, hiding, or the gun.
##
## Then Apartment 13: the convergence. What Kurt arrives with is what he did on the way, played
## back through the world and the dialogue, and written out for the next chapter.

var main: Node
var level: Level
var player: Player
var super_: SuperHunter
var arrived := false
var seen_super := false
var _remind_t := 50.0
var _check := 0.0
var _handling_catch := false
var _card: Control
var _fail_ui: Control

func begin(p_main: Node, spawn: String) -> void:
	main = p_main
	level = main.level
	player = main.player
	if SockoDirector.inst:
		SockoDirector.inst.setup(player)
	level.trigger_entered.connect(_on_trigger)
	Events.player_caught.connect(_on_caught)
	super_ = SuperHunter.new()
	super_.name = "TheSuper"
	level.dynamic_root().add_child(super_)
	var a: Array = level.data.super_start
	super_.setup(level, player, Vector3(a[0], a[1], a[2]), level.data.patrol)
	_world_state()
	if spawn == "restore":
		super_.wake()
		return
	_walk_in()

## he just walks in through the front door: it swings shut behind him on the white
func _walk_in() -> void:
	var d: Door = level.doors["street_door"]
	main.set_blackout(1.0)
	d.open_instant(0.7)
	player.global_position = Vector3(6.0, 0.0, 16.2)
	player.rotation.y = 0.0
	player.locked = true
	main.set_blackout(0.0, 1.6)
	var t := create_tween()
	t.tween_property(player, "global_position", Vector3(6.0, 0.0, 15.2), 1.4)
	await t.finished
	d.close(true)
	d.open_k = 0.0
	d._target = 0.0
	player.locked = false
	Story.set_flag("knows_13", true)
	await get_tree().create_timer(0.8).timeout
	await Speech.speak(["gf_enter_k", "gf_enter_s"])
	super_.wake()
	SaveGame.save_game(main, "ground_floor")

## what came with him: Marta's fate is audible from the stairwell
func _world_state() -> void:
	var ms := String(Story.flag("marta_state", "hunting"))
	var n := Node3D.new(); level.add_child(n); n.global_position = Vector3(10.0, 1.5, 3.0)
	match ms:
		"hunting", "wounded":
			Sfx.loop_at("marta_clicks", n, -16.0, 1.5)
		"calm":
			Sfx.loop_at("marta_hum", n, -18.0, 1.5)

func _on_trigger(id: String) -> void:
	match id:
		"arrive13":
			_arrive()

func _process(delta: float) -> void:
	if not player or arrived:
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.25
	# the first sight of him
	if not seen_super and _sees(super_.eye() - Vector3(0, 0.6, 0), 14.0, 30.0):
		seen_super = true
		Story.record("super.seen")
		Speech.queue(["super_k", "super_s", "super_hint"])
		if player.gun and SockoDirector.inst:
			Speech.queue(["s_bonk"])
	# Socko remembers 13 so the player doesn't have to
	_remind_t -= 0.25
	var d13 := player.global_position.distance_to(Vector3(26.5, 0, 8.5))
	if d13 < 3.5 and not Story.flag("saw_13_door", false):
		Story.set_flag("saw_13_door", true)
		Speech.bark("s_13_here")
		if player.socko: player.socko.point_at(Vector3(26.5, 1.5, 8.0))
	elif _remind_t <= 0.0 and d13 > 8.0 and super_.state in ["patrol", "dormant"] and not Speech.busy():
		_remind_t = 75.0
		Speech.bark("s_13_remind")
		if player.socko: player.socko.point_at(Vector3(26.5, 1.5, 8.0))

func _sees(p: Vector3, dist: float, angle: float) -> bool:
	var cam := player.camera
	var to := p - cam.global_position
	if to.length() > dist or rad_to_deg((-cam.global_transform.basis.z).angle_to(to)) > angle:
		return false
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, p, 1)
	q.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

# ---------------------------------------------------------------------------------- caught

func _on_caught(_by: Node) -> void:
	if arrived or _handling_catch:
		return
	_handling_catch = true
	var far: Array = level.data.patrol[4]
	super_.reset_to(Vector3(far[0], far[1], far[2]))
	player.locked = true
	player.look_locked = true
	Sfx.play("grab", 2.0)
	player.shake(1.5)
	await main.set_blackout(1.0, 0.4)
	Speech.stop_all()
	if Story.count("caught") >= 3:
		_fail()
		return
	Story.record("super.caught_kurt")
	player.injure(1)
	player.global_transform = level.spawns["caught"]
	player._pitch = 0.0
	await get_tree().create_timer(1.5 if not Speech.fast else 0.1).timeout
	main.set_blackout(0.0, 1.5)
	player.locked = false
	player.look_locked = false
	_handling_catch = false
	await Speech.speak(["k_caught_wake", "s_caught"])

func _fail() -> void:
	Events.beat.emit("failed")
	Story.record("failed")
	_fail_ui = Control.new()
	_fail_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fail_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	_fail_ui.add_child(UIKit.fullscreen_dim(1.0))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 22)
	vb.add_child(UIKit.label("Kurt doesn't get up this time.", 30, Color(0.85, 0.75, 0.7)))
	var retry := UIKit.button("  Try again from the last checkpoint  ")
	retry.pressed.connect(func():
		_fail_ui.queue_free()
		get_tree().paused = false
		Story.counters["caught"] = 0
		SaveGame.load_game(main))
	vb.add_child(retry)
	_fail_ui.add_child(vb)
	main.hud.root.add_child(_fail_ui)
	_fail_ui.size = main.hud.root.size
	await get_tree().process_frame
	vb.position = main.hud.root.size * 0.5 - vb.size * 0.5

# ---------------------------------------------------------------------------------- 13

func _arrive() -> void:
	if arrived:
		return
	arrived = true
	Events.beat.emit("arrived13")
	Story.record("arrived13")
	Story.set_flag("super_state", _super_state())
	super_.set_state("dormant")
	super_.velocity = Vector3.ZERO
	Sfx.set_tension(0.0)
	await Speech.speak(arrival_lines())
	await get_tree().create_timer(1.5 if not Speech.fast else 0.1).timeout
	_end_card()

func _super_state() -> String:
	if super_.state == "dead":
		return "dead"
	if Story.count("super.caught_kurt") > 0:
		return "caught you"
	if super_.hit_count > 0:
		return "hurt"
	if Story.has("super.spotted"):
		return "saw you"
	return "never knew"

## the convergence: one destination, the journey decides what's said on arrival
static func arrival_lines() -> Array:
	var lines := ["k_13"]
	match String(Story.flag("marta_state", "hunting")):
		"dead": lines += ["a13_killed_k", "a13_killed_s"]
		"wounded": lines += ["a13_wounded_s"]
		"calm": lines += ["a13_calm_k", "a13_calm_s"]
		_: lines += ["a13_evaded_s"]
	if Story.count("resource.fired") == 0:
		lines += ["a13_clean_k", "a13_clean_s"]
	if Infection.stage >= 2:
		lines += ["a13_infected_k", "a13_infected_s"]
	lines.append("a13_end_s")
	return lines

func summary() -> Dictionary:
	var p := player
	return {
		"route": Story.flag("route_out", "?"),
		"way_into_13": _way_in(),
		"marta": Story.flag("marta_state", "?"),
		"marta_hits": Story.flag("marta_hits", 0),
		"super": Story.flag("super_state", "?"),
		"rounds_loaded": p.gun.loaded if p.gun else 0,
		"rounds_loose": p.inv.count("ammo"),
		"shots_fired": Story.count("resource.fired"),
		"injury": p.injury,
		"infection": snappedf(Infection.level, 0.01),
		"memories": Story.memory_points,
		"clues": Story.count_prefix("clue."),
		"caught": Story.count("caught"),
		"socko_obeyed": Story.count("socko.obeyed"),
		"socko_ignored": Story.count("socko.ignored"),
		"inventory": p.inv.list(),
		"play_time": int(Story.play_time),
	}

static func _way_in() -> String:
	if Story.has("used:key"): return "key"
	if Story.has("stealth.picked_lock"): return "picked"
	if Story.has("route.forced_door"): return "forced"
	if Story.has("route.shot_lock"): return "shot"
	return "?"

func _end_card() -> void:
	var s := summary()
	var f := FileAccess.open("user://chapter1_end.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"summary": s, "story": Story.to_dict(), "infection": Infection.to_dict()}))
	print("CHAPTER1_END ", JSON.stringify(s))
	_card = Control.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := UIKit.fullscreen_dim(0.0)
	_card.add_child(dim)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	vb.add_child(UIKit.label("APARTMENT 13", 44, Color(0.92, 0.9, 0.85)))
	vb.add_child(UIKit.label("End of the first chapter.", 24, Color(0.8, 0.78, 0.72)))
	var marta_txt: String = {"dead": "dead, by his hand", "wounded": "hurt, and still out there", "calm": "asleep, for now", "hunting": "still hunting", "unmet": "never saw him"}.get(String(s.marta), String(s.marta))
	for r in ["Marta: " + marta_txt, "The Super: " + String(s.super),
			"Rounds: %d in the cylinder, %d loose. %d fired." % [s.rounds_loaded, s.rounds_loose, s.shots_fired],
			"Memories recovered: %d" % s.memories]:
		vb.add_child(UIKit.label(r, 22, Color(0.75, 0.72, 0.66)))
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 20)
	var stay := UIKit.button("  Stay a while  ")
	stay.pressed.connect(func(): _card.queue_free(); get_tree().paused = false)
	var again := UIKit.button("  Start again  ")
	again.pressed.connect(func():
		get_tree().paused = false
		SaveGame.delete()
		get_tree().reload_current_scene())
	hb.add_child(stay); hb.add_child(again)
	vb.add_child(hb)
	_card.add_child(vb)
	main.hud.root.add_child(_card)
	_card.size = main.hud.root.size
	await get_tree().process_frame
	vb.position = main.hud.root.size * 0.5 - vb.size * 0.5
	dim.color.a = 0.0
	_card.create_tween().tween_property(dim, "color:a", 0.9, 2.0)
	get_tree().paused = true

func get_state() -> Dictionary:
	return {"arrived": arrived, "super": super_.get_state() if super_ else {}}

func set_state(d: Dictionary) -> void:
	arrived = d.get("arrived", false)
	if super_ and d.has("super"):
		super_.set_state_dict(d.super)
