extends Node
## Screenshots of THE SEARCH (forced): first person in the showroom, then the choice card.
func _ready() -> void:
	var out := "user://search_shots"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
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
		await get_tree().create_timer(0.5).timeout
	Net.core.rules.sub = "search"
	Net.core.search.start(Net.core.rules.current())
	await get_tree().create_timer(3.0).timeout
	get_viewport().get_texture().get_image().save_png(out + "/search_fp.png")
	# turn to face a scrap
	var gv = get_tree().root.find_child("*", true, false)
	for sc in Net.core.search.scraps:
		pass
	# put me next to a scrap, facing it
	var sc0: Dictionary = Net.core.search.scraps.filter(func(x): return int(x.by) < 0)[0] if Net.core.search.scraps.any(func(x): return int(x.by) < 0) else Net.core.search.scraps[0]
	for n in get_tree().root.find_children("*", "GameView", true, false):
		n.fp_pos = sc0.pos + Vector2(0, 2.2)
		n.fp_yaw = 0.0
	await get_tree().create_timer(1.5).timeout
	for n in get_tree().root.find_children("*", "GameView", true, false):
		print("SCRAP0 ", sc0.pos, " fp ", n.fp_pos, " nodes ", n._scrap_nodes.size(), " vis ", n._scrap_nodes.map(func(x): return [x.visible, x.global_position]) if n._scrap_nodes.size() > 0 else [], " active ", n._fp_active)
	get_viewport().get_texture().get_image().save_png(out + "/search_scrap.png")
	Net.core.search.t = 999.0
	await get_tree().create_timer(2.0).timeout
	get_viewport().get_texture().get_image().save_png(out + "/search_choice.png")
	if Net.core.search.stage == "choice":
		Net.send_action(0, {"t": "search_choice", "keep": false})
	await get_tree().create_timer(2.5).timeout
	get_viewport().get_texture().get_image().save_png(out + "/search_reveal.png")
	get_tree().quit()
