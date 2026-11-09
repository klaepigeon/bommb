extends SceneTree
## Renders named views of the flat to PNGs (for checking the look of things).
## xvfb-run godot --rendering-driver opengl3 --path hysteria -s tools/views.gd -- out=<dir> set=outside
var out := "user://views"
const SETS := {
	"fightclose": [["fc_1", 10.1, 9.0, PI * 0.85, 0.25, false], ["fc_gun", 10.05, 9.55, PI * 0.75, -1.0, false]],
	"fight": [["f_from_lane", 10.5, 7.3, PI, 0.08, false], ["f_archer", 8.9, 8.5, PI * 0.75, 0.1, false],
		["f_mid", 9.6, 9.0, PI * 0.8, 0.25, false], ["f_cafe", 10.6, 10.4, -PI * 0.6, 0.2, false],
		["f_gun", 9.9, 9.35, PI * 0.95, -0.9, false], ["f_poster", 8.9, 8.85, PI * 0.5, 0.05, true]],
	"rooms": [["r_salon_door", 4.5, 4.9, PI, 0.0, false], ["r_salon_in", 4.5, 6.35, PI, -0.08, false], ["r_salon_corner", 3.8, 7.4, -0.95, -0.15, false],
		["r_hotel_in", 13.25, 9.5, -PI * 0.5, -0.12, false], ["r_hotel_corner", 14.45, 9.95, 1.08, -0.1, false],
		["r_nursery_in", 2.85, 15.5, PI * 0.5, -0.1, false], ["r_nursery_corner", 1.9, 15.35, -2.39, -0.05, false]],
	"marta": [["m_lane", 6.5, 2.7, PI, 0.12, false], ["m_close", 6.4, 3.55, PI, 0.18, true], ["m_side", 7.6, 4.3, PI * 0.5 + 0.6, 0.12, false]],
	"hole": [["hole_lab", 6.5, 1.75, 0.0, -0.12, true], ["hole_lab_dark", 6.4, 1.9, 0.15, -0.05, false]],
	"shops": [["s_pharmacy", 2.5, 5.0, 0.0, 0.12, false], ["s_bakery", 8.5, 5.0, 0.0, 0.12, false], ["s_tavern", 11.5, 5.0, 0.0, 0.12, false],
		["s_photo", 3.5, 4.0, PI, 0.12, false], ["s_clock", 7.5, 4.0, PI, 0.12, false], ["s_hotel", 11.0, 8.5, -PI / 2, 0.1, false]],
	"lab": [["lab_arrive", 6.5, 1.4, PI, 0.0, false], ["lab_lane_out", 6.5, 2.6, PI, 0.05, false],
		["lab_main_east", 6.0, 4.6, -PI / 2, 0.02, false], ["lab_main_west", 7.0, 5.4, PI / 2, 0.02, false],
		["lab_shop", 8.5, 4.9, 0.25, 0.08, false], ["lab_photo", 3.6, 4.6, PI - 0.3, 0.05, false],
		["lab_square", 10.5, 7.6, PI, -0.05, false], ["lab_square_hotel", 9.0, 9.5, -PI / 2 - 0.2, 0.05, false],
		["lab_plaza", 10.5, 13.8, PI, 0.1, false], ["lab_izba", 7.4, 15.5, PI / 2, 0.02, false], ["lab_dome", 10.5, 9.0, PI, 0.45, false]],
	"flat": [["fl_living", 3.9, 4.6, 0.75, -0.05, true, ""], ["fl_living_back", 0.7, 0.8, PI + 0.7, -0.05, true, ""],
		["fl_hall", 9.5, 4.5, PI * 0.5, -0.05, true, ""], ["fl_kitchen", 8.0, 3.4, -0.35, -0.1, true, ""],
		["fl_bedroom", 5.0, 3.3, -0.5, -0.05, true, ""], ["fl_child", 3.3, 5.7, PI + 0.5, -0.1, true, ""],
		["fl_bath", 7.0, 5.7, PI - 0.4, -0.25, true, ""], ["fl_living_dark", 3.9, 4.6, 0.75, -0.05, false, ""]],
	"f48": [["f48_hall", 9.5, 4.5, PI * 0.5, -0.05, false, ""], ["f48_wall", 5.5, 4.75, 0.0, 0.05, false, ""],
		["f48_living", 3.9, 4.6, 0.75, -0.1, false, ""], ["f48_kitchen", 8.3, 3.4, -0.6, -0.1, false, ""],
		["f48_bedroom", 5.0, 3.3, -0.4, -0.1, false, ""], ["f48_box", 1.8, 6.0, PI - 0.3, -0.15, false, ""],
		["f48_safe_real", 1.6, 6.5, PI - 0.15, -0.2, false, "safe"], ["f48_safe_open", 1.55, 6.55, PI - 0.1, -0.35, false, "open"],
		["f48_sofa_real", 2.2, 3.4, 1.05, -0.35, false, "sofa"],
		["f48_gun_hand", 5.5, 1.9, 0.0, -0.05, true, "gun"], ["f48_papa_aim", 6.0, 2.6, 0.0, 0.05, true, "gun"],
		["f48_kurt_mannequin", 6.3, 1.9, 0.25, -0.05, false, "dress"], ["f48_marta_mannequin", 8.3, 3.2, -1.1, -0.1, false, "dress"],
		["f48_kurt_back", 6.6, 0.95, 1.9, -0.15, false, "dress"]],
	"body": [["b_look_down", 5.6, 3.2, PI + 0.4, -1.3, true, "socko"], ["b_down_ahead", 5.6, 2.9, 0.4, -0.8, true, "socko"],
		["b_crouch_down", 5.6, 3.2, PI + 0.4, -1.2, true, "crouch"], ["b_ahead", 5.6, 2.9, 0.4, -0.1, true, "socko"]],
	"escape": [["e_chain", 9.45, 4.56, -PI * 0.5, -0.05, true, "ajar"], ["e_chain_close", 9.75, 4.75, -PI * 0.5 - 0.35, -0.12, true, "ajar"],
		["e_bath_full", 7.4, 6.75, PI, -0.95, true, ""], ["e_bath_drained", 7.4, 6.75, PI, -0.95, true, "drain"],
		["e_door_out", 9.4, 4.56, -PI * 0.5, 0.0, false, "free"], ["e_heap", 9.55, 4.9, -PI * 0.5 - 0.5, -0.9, true, ""]],
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
	var lab: bool = which in ["lab", "shops", "hole", "fight", "fightclose", "rooms", "marta"]
	if lab: main.enter_labyrinth()
	if which == "marta":
		main.hunter.wake(Vector2i(6, 4))
		main.hunter.position = main.labyrinth.center(6, 4) + Vector3(0, 0, 1.0)
		main.hunter._yaw = 0.0
		await process_frame
		main.hunter.set_process(false)
		main.hunter.marta.face(main.player.cam.global_position)
	for v in SETS[which]:
		var at := Vector3(v[1], 0, v[2])
		if lab: at = main.labyrinth.to_global(at * 4.0)
		if which == "f48":
			if not main.in_flat48: main.enter_flat48()
			at = main.flat48.to_global(at)
			match v[6] if v.size() > 6 else "":
				"safe": main.flat48.safe.make_real(true)
				"open": main.flat48.safe.set_open(true, true)
				"dress":
					for g in main.flat48.figures:
						if g.id != "child": g.dress(true)
						g.set_process(false)
				"gun":
					main.flat48.safe.make_real(true); main.flat48.safe.set_open(true, true); main.flat48.safe.take_gun(true)
				"sofa":
					for b in main.flat48.blocks:
						if b.identity == "SOFA": b.make_real(true)
		p.global_position = at; p.velocity = Vector3.ZERO
		p.yaw = v[3]; p.pitch = v[4]; p.torch.visible = v[5]
		if which == "body":
			main.encounter.skip(); main.socko_intro.skip()
			p.crouched = v[6] == "crouch"
		if v.size() > 6:
			main.encounter.process_mode = Node.PROCESS_MODE_DISABLED
			match v[6]:
				"ajar": main.escape.door.target = 0.11
				"drain": main.escape._level = main.escape.WATER_BOTTOM + 0.001; main.escape.draining = true
				"free": main.escape._free("axe"); main.escape._ended = true
			for i in 90: await physics_frame
		for i in 30: await process_frame
		root.get_viewport().get_texture().get_image().save_png(out.path_join(v[0] + ".png"))
		print("view ", v[0])
	quit()
