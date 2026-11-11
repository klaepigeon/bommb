extends Node
## Flat 48: where every route converges. What Kurt arrives with is what he did on the way: his
## injuries, his rounds, what he knows, how far the infection's got, what happened to Marta, how
## Socko feels about him. The arrival plays those back through the world and the dialogue, not
## through a score. Then the chapter ends, and its state is written out for the next one.

var main: Node
var level: Level
var player: Player
var arrived := false
var _card: Control
var _marta_sound: AudioStreamPlayer3D

func begin(p_main: Node, spawn: String) -> void:
	main = p_main
	level = main.level
	player = main.player
	if SockoDirector.inst:
		SockoDirector.inst.setup(player)
	level.trigger_entered.connect(func(id): if id == "arrive": _arrive())
	for l in level.data.get("labels", []):
		var lb := Label3D.new(); lb.text = String(l[0]); lb.font_size = 22; lb.pixel_size = 0.004
		lb.modulate = Color(0.3, 0.3, 0.33); lb.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		level.add_child(lb)
		lb.global_position = Vector3(l[1][0], l[1][1], l[1][2])
		lb.rotation.y = deg_to_rad(float(l[2]))
	_world_state()
	if spawn == "restore":
		return
	main.set_blackout(1.0)
	main.set_blackout(0.0, 2.0)
	if spawn == "vent":
		player.crouching = true
	await get_tree().create_timer(1.0).timeout
	Speech.queue(["k_48"] if spawn != "door" else ["f48_open", "k_48"])
	SaveGame.save_game(main, "flat48")

## the world remembers: what's behind the walls depends on what happened to her
func _world_state() -> void:
	var ms := String(Story.flag("marta_state", "hunting"))
	match ms:
		"hunting", "wounded":
			# she's still out there; through the wall, sometimes, the clicking
			var n := Node3D.new(); level.add_child(n); n.global_position = Vector3(7.0, 1.2, 11.5)
			_marta_sound = Sfx.loop_at("marta_clicks", n, -12.0, 2.0)
		"calm":
			var n := Node3D.new(); level.add_child(n); n.global_position = Vector3(12.0, 1.2, 5.8)
			Sfx.loop_at("marta_hum", n, -16.0, 2.0)
		"dead":
			Sfx.set_ambience("", -80.0)        # nothing at all
	if Infection.stage >= 2:
		for id in level.rooms:
			for m in (level.rooms[id].mats as Mats.RoomMats).mats.values():
				(m as ShaderMaterial).set_shader_parameter("breathe", true)

func _arrive() -> void:
	if arrived:
		return
	arrived = true
	Events.beat.emit("arrived48")
	Story.record("arrived48")
	await Speech.speak(arrival_lines())
	await get_tree().create_timer(1.5 if not Speech.fast else 0.1).timeout
	_end_card()

## the convergence: one destination, the journey decides what's said on arrival
static func arrival_lines() -> Array:
	var lines := []
	var ms := String(Story.flag("marta_state", "hunting"))
	match ms:
		"dead": lines += ["f48_killed_k", "f48_killed_s"]
		"wounded": lines += ["f48_wounded_s"]
		"calm": lines += ["f48_calm_k", "f48_calm_s"]
		_: lines += ["f48_evaded_s"]
	if Story.count("resource.fired") == 0:
		lines += ["f48_clean_k", "f48_clean_s"]
	if Infection.stage >= 2:
		lines += ["f48_infected_k", "f48_infected_s"]
	lines.append("f48_end_s")
	return lines

## what Kurt brings with him: written out for the next chapter, and shown once, plainly
func summary() -> Dictionary:
	var p := player
	return {
		"route": Story.flag("route48", "?"),
		"marta": Story.flag("marta_state", "?"),
		"marta_hits": Story.flag("marta_hits", 0),
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

func _end_card() -> void:
	var s := summary()
	var f := FileAccess.open("user://chapter1_end.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"summary": s, "story": Story.to_dict(), "infection": Infection.to_dict()}))
	print("CHAPTER1_END ", JSON.stringify(s))
	_card = Control.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.process_mode = Node.PROCESS_MODE_ALWAYS
	_card.add_child(UIKit.fullscreen_dim(0.0))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	var title := UIKit.label("FLAT 48", 44, Color(0.92, 0.9, 0.85))
	var sub := UIKit.label("End of the first chapter.", 24, Color(0.8, 0.78, 0.72))
	var rows := [
		"Marta: %s" % {"dead": "dead, by his hand", "wounded": "hurt, and still out there", "calm": "asleep, for now", "hunting": "still hunting", "unmet": "never saw him"}.get(String(s.marta), String(s.marta)),
		"Rounds: %d in the cylinder, %d loose. %d fired." % [s.rounds_loaded, s.rounds_loose, s.shots_fired],
		"Memories recovered: %d" % s.memories,
	]
	vb.add_child(title); vb.add_child(sub)
	for r in rows:
		vb.add_child(UIKit.label(r, 22, Color(0.75, 0.72, 0.66)))
	var stay := UIKit.button("  Stay a while  ")
	stay.pressed.connect(func(): _card.queue_free(); get_tree().paused = false)
	var again := UIKit.button("  Start again  ")
	again.pressed.connect(func():
		get_tree().paused = false
		SaveGame.delete()
		get_tree().reload_current_scene())
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 20)
	hb.add_child(stay); hb.add_child(again)
	vb.add_child(hb)
	_card.add_child(vb)
	main.hud.root.add_child(_card)
	await get_tree().process_frame
	vb.position = main.hud.root.get_viewport_rect().size * 0.5 - vb.size * 0.5
	var t := _card.create_tween()
	(_card.get_child(0) as ColorRect).color.a = 0.0
	t.tween_property(_card.get_child(0), "color:a", 0.9, 2.0)
	get_tree().paused = true

func get_state() -> Dictionary:
	return {"arrived": arrived}

func set_state(d: Dictionary) -> void:
	arrived = d.get("arrived", false)
