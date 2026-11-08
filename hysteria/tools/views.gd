extends SceneTree
## Renders named views of the flat to PNGs (for checking the look of things).
## xvfb-run godot --rendering-driver opengl3 --path hysteria -s tools/views.gd -- out=<dir> set=outside
var out := "user://views"
const SETS := {
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
	for v in SETS[which]:
		p.global_position = Vector3(v[1], 0, v[2]); p.velocity = Vector3.ZERO
		p.yaw = v[3]; p.pitch = v[4]; p.torch.visible = v[5]
		for i in 30: await process_frame
		root.get_viewport().get_texture().get_image().save_png(out.path_join(v[0] + ".png"))
		print("view ", v[0])
	quit()
