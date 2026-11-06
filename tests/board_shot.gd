extends Node
## The board from above (and from your chair), for checking the drawing:
##   xvfb-run godot res://tests/board_shot.tscn -- --out=DIR --seed=N


func _ready() -> void:
	var out := "user://"
	var seed_v := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		if a.begins_with("--seed="):
			seed_v = int(a.substr(7))
	var stage := Stage.new()
	add_child(stage)
	stage.set_internal_height(720)
	var table := Node3D.new()
	table.scale = Vector3.ONE * GameView.TABLE_SCALE
	stage.hall.board_root.add_child(table)
	var tb := TableBoard.new()
	table.add_child(tb)
	tb.build(Assets.load_json("res://assets/data/board.json").get("spaces", []), seed_v)
	var top := table.to_global(Vector3(0, 0, 0.3))
	stage._base_pos = top + Vector3(0, 1.3, 0.25)
	stage._look_at = top
	stage._fov = 60.0
	stage._apply_camera()
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png(out + "/board_top_%d.png" % seed_v)
	stage.set_pose("table", 0.0)
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(out + "/board_seat_%d.png" % seed_v)
	get_tree().quit()
