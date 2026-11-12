extends SceneTree
## Kurt's right arm in each pose of a blow, and his body looking down, for judging the look.
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/arm_view.gd -- out=<dir>
var out := "user://arm_view"
func _initialize() -> void:
	await process_frame
	for a in OS.get_cmdline_user_args(): if a.begins_with("out="): out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	var game = root.get_node("Game")
	game.change_level("flat47", {"card": false, "fade": 0.01})
	await _wait(2.0)
	var L = game.level
	root.get_node("Dialogue").stop(); L.set_cutscene(false); game._black.visible = false
	var P = L.player; var H = L.hands
	P.global_position = Vector3(8.6, 0, 4.5); P.torch_on = true
	P.set_view(PI * 0.5, -0.05)
	await _wait(0.6)
	H._prof = load("res://scripts/combat/weapons.gd").profile(null)
	H.set_process(false)
	var shots := [["a_guard", H._rest_pose(), false], ["b_jab_windup", H._windup_pose(), false], ["c_jab_strike", H._strike_pose(), false]]
	for s in shots: await _shot(H, s[0], s[1])
	H.heavy = true
	await _shot(H, "d_hay_windup", H._windup_pose())
	await _shot(H, "e_hay_strike", H._strike_pose())
	H.heavy = false
	# the hammer
	var hammer = null
	for k in L.flat.props: if String(k).contains("Hammer"): hammer = L.flat.props[k]
	hammer.global_position = P.cam.global_position - P.cam.global_transform.basis.z * 0.6
	P.pick_up(hammer)
	H._prof = load("res://scripts/combat/weapons.gd").profile(hammer)
	H._wrist = H._pose(H.HOLD_AT, Vector3(-0.15, 0.35, -1.0)); H._shown = 1.0; H._process(0.0)
	H._start_swing()
	await _shot(H, "f_hammer_windup", H._windup_pose())
	await _shot(H, "g_hammer_strike", H._strike_pose())
	H._end_swing(); P.drop_held()
	H._wrist = H._rest_pose()
	H.set_process(true)
	P.set_view(PI * 0.5, -1.35)
	await _wait(1.0)
	root.get_viewport().get_texture().get_image().save_png(out.path_join("h_look_down.png"))
	P.crouching = true
	await _wait(1.2)
	root.get_viewport().get_texture().get_image().save_png(out.path_join("i_look_down_crouched.png"))
	quit()

func _shot(H, name: String, pose: Transform3D) -> void:
	H._wrist = pose; H._shown = 1.0
	H.arm.pose_name = "grip" if H.player.held else "fist"
	for i in 12:
		H._process(0.0); await process_frame
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))

func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame
