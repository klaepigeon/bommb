extends SceneTree
## Bakes each level's ambient-occlusion map (scripts/world/ao_map.gd) to assets/ao/<level>.png,
## so the game loads it instead of probing the physics world at start-up. Run after changing a
## level's walls or furniture:
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/bake_ao.gd
func _initialize() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://assets/ao")
	var game = root.get_node("Game")
	for lv in ["flat47", "flesh47"]:
		game.change_level(lv, {"card": false, "fade": 0.01})
		for i in 90: await process_frame
		var L = game.level
		var a: Array = L.ao_area()
		var t0 := Time.get_ticks_msec()
		var img: Image = load("res://scripts/world/ao_map.gd").bake(L.get_world_3d(), a[0], a[1], a[2])
		img.save_png("res://assets/ao/%s.png" % L.ao_name())
		printerr("AO ", L.ao_name(), " ", img.get_size(), " in ", Time.get_ticks_msec() - t0, " ms")
	quit()
