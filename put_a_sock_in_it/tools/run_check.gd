extends SceneTree
## Loads a level as the game would and runs it for a while: errors show in the log.
## godot --path . -s tools/run_check.gd -- level=flat47 secs=8 shot=<png>
func _initialize() -> void:
	await process_frame
	var lvl := "flat47"; var secs := 6.0; var shot := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="): lvl = a.substr(6)
		if a.begins_with("secs="): secs = float(a.substr(5))
		if a.begins_with("shot="): shot = a.substr(5)
	var game = root.get_node("Game")
	game.change_level(lvl, {"card": false, "fade": 0.01})
	var t := 0.0
	while t < secs:
		await process_frame; t += 1.0 / 60.0
	if shot != "": root.get_viewport().get_texture().get_image().save_png(shot)
	print("RUN_CHECK DONE")
	quit()
