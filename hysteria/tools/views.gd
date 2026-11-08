extends SceneTree
## Renders named views of the flat to PNGs (for checking the look of things).
## xvfb-run godot --rendering-driver opengl3 --path hysteria -s tools/views.gd -- out=<dir> set=outside
var out := "user://views"
const SETS := {
	"fightclose": [["fc_1", 10.1, 9.0, PI * 0.85, 0.25, false], ["fc_gun", 10.05, 9.55, PI * 0.75, -1.0, false]],
	"fight": [["f_from_lane", 10.5, 7.3, PI, 0.08, false], ["f_archer", 8.9, 8.5, PI * 0.75, 0.1, false],
		["f_mid", 9.6, 9.0, PI * 0.8, 0.25, false], ["f_cafe", 10.6, 10.4, -PI * 0.6, 0.2, false],
		["f_gun", 9.9, 9.35, PI * 0.95, -0.9, false], ["f_poster", 8.9, 8.85, PI * 0.5, 0.05, true]],
	"hole": [["hole_lab", 6.5, 1.75, 0.0, -0.12, true], ["hole_lab_dark", 6.4, 1.9, 0.15, -0.05, false]],
	"shops": [["s_pharmacy", 2.5, 5.0, 0.0, 0.12, false], ["s_bakery", 8.5, 5.0, 0.0, 0.12, false], ["s_tavern", 11.5, 5.0, 0.0, 0.12, false],
		["s_photo", 3.5, 4.0, PI, 0.12, false], ["s_clock", 7.5, 4.0, PI, 0.12, false], ["s_hotel", 11.0, 8.5, -PI / 2, 0.1, false]],
	"lab": [["lab_arrive", 6.5, 1.4, PI, 0.0, false], ["lab_lane_out", 6.5, 2.6, PI, 0.05, false],
		["lab_main_east", 6.0, 4.6, -PI / 2, 0.02, false], ["lab_main_west", 7.0, 5.4, PI / 2, 0.02, false],
		["lab_shop", 8.5, 4.9, 0.25, 0.08, false], ["lab_photo", 3.6, 4.6, PI - 0.3, 0.05, false],
		["lab_square", 10.5, 7.6, PI, -0.05, false], ["lab_square_hotel", 9.0, 9.5, -PI / 2 - 0.2, 0.05, false],
		["lab_plaza", 10.5, 13.8, PI, 0.1, false], ["lab_izba", 7.4, 15.5, PI / 2, 0.02, false], ["lab_dome", 10.5, 9.0, PI, 0.45, false]],
	"outside": [["living_window", 3.0, 3.6, 0.15, 0.05, false], ["balcony", 2.2, -0.9, 0.2, 0.05, false],
		["balcony_down", 2.6, -1.4, 0.3, -0.55, false], ["kitchen_window", 8.6, 2.2, -0.1, 0.0, false],
		["bedroom_window", 6.0, 2.2, 0.0, 0.05, false], ["child_window", 4.6, 6.6, PI, 0.0, false]],
}

func _initialize() -> void:
	var which := "outside"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.get_slice("=", 1)
		if a.begins_with("set="): which = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame; await process_frame
	var p = main.player
	var lab: bool = which in ["lab", "shops", "hole", "fight", "fightclose"]
	if lab: main.enter_labyrinth()
	for v in SETS[which]:
		var at := Vector3(v[1], 0, v[2])
		if lab: at = main.labyrinth.to_global(at * 4.0)
		p.global_position = at; p.velocity = Vector3.ZERO
		p.yaw = v[3]; p.pitch = v[4]; p.torch.visible = v[5]
		for i in 30: await process_frame
		root.get_viewport().get_texture().get_image().save_png(out.path_join(v[0] + ".png"))
		print("view ", v[0])
	quit()
