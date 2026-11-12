extends SceneTree
func _initialize() -> void:
	await process_frame
	var out := "user://title.png"
	for a in OS.get_cmdline_user_args(): if a.begins_with("out="): out = a.substr(4)
	var t = load("res://scenes/title.tscn").instantiate(); root.add_child(t); current_scene = t
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
