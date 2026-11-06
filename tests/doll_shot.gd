extends Node
## Close-up of the dolls on the table, injured, for checking the look:
##   xvfb-run godot res://tests/doll_shot.tscn -- --out=FILE.png


func _ready() -> void:
	var out := "user://dolls.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var stage := Stage.new()
	add_child(stage)
	var table := Node3D.new()
	table.scale = Vector3.ONE * GameView.TABLE_SCALE
	stage.hall.board_root.add_child(table)
	var tb := TableBoard.new()
	table.add_child(tb)
	tb.build(Assets.load_json("res://assets/data/board.json").get("spaces", []))
	var hurts := [{}, {"leg_l": "lost", "eye_r": "broken"}, {"arm_r": "broken", "hand_l": "burned", "ears": "broken"}, {"leg_r": "prosthetic", "eye_l": "lost", "hand_r": "lost"}]
	for i in 4:
		var c := Contestant.new()
		table.add_child(c)
		c.setup(i, i, Seats.COLORS[i], ["DORIS", "KEVIN", "GAIL", "YOU"][i])
		c.place(Vector3(-2.4 + i * 1.6, 0.05, 2.0))
		c.face_dir = 0.0
		var b := Body.fresh()
		for k in hurts[i]:
			b[k].s = hurts[i][k]
		c.set_body(b, i == 0)
	var cam_at := table.to_global(Vector3(0, 1.2, 2.0))
	stage._base_pos = cam_at + Vector3(0, 0.08, 0.42)
	stage._look_at = cam_at + Vector3(0, -0.02, 0)
	stage._fov = 50.0
	stage._apply_camera()
	await get_tree().create_timer(2.0).timeout
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
