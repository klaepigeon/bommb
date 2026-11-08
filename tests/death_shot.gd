extends Node
## Screenshots of the death animations in a real match: each cause on a puppet, at the impact
## and in the aftermath. -- --out=DIR --anims=shot,crushed,gassed,blood_loss
func _ready() -> void:
	var out := "user://death_shots"
	var anims := ["shot", "crushed", "gassed"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		if a.begins_with("--anims="):
			anims = a.substr(8).split(",")
	DirAccess.make_dir_recursive_absolute(out)
	var main: Node = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(1.0).timeout
	Seats.reset("single")
	Seats.set_seat(0, {"kind": "local", "name": "YOU", "device": "primary"})
	Net.start_offline()
	Net.launch()
	while Net.core == null or Net.core.phase != "turn":
		Net.send_action(0, {"t": "ready"})
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(1.5).timeout
	Net.paused = true      # hold the board still while we kill people
	for i in anims.size():
		var s := i % 4
		Net.core.players[s].helmet = false
		Net.core.kill(s, anims[i], [], true)
		# the view runs on Net's ticks: let one through to deliver the event
		Net.paused = false
		await get_tree().physics_frame
		Net.paused = true
		await get_tree().create_timer(0.45).timeout
		var gv = get_tree().root.find_children("*", "GameView", true, false)[0]
		print("CAM ", anims[i], " shot=", gv.director.current, " reqs=", gv.director.requests.map(func(r): return [r.name, r.priority]))
		get_viewport().get_texture().get_image().save_png("%s/%s_a.png" % [out, anims[i]])
		await get_tree().create_timer(1.8).timeout
		get_viewport().get_texture().get_image().save_png("%s/%s_b.png" % [out, anims[i]])
	get_tree().quit()
