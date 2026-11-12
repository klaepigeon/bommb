extends SceneTree
## Sonya's note: under her bed, the prompt when Kurt looks at it, and the note held up.
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/note_view.gd -- out=<dir>
var out := "user://note_view"
func _initialize() -> void:
	await process_frame
	for a in OS.get_cmdline_user_args(): if a.begins_with("out="): out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	var game = root.get_node("Game")
	game.change_level("flat47", {"card": false, "fade": 0.01})
	await _wait(2.0)
	var L = game.level
	root.get_node("Dialogue").stop(); L.set_cutscene(false); game._black.visible = false
	L.player.torch_on = true
	L.player.global_position = Vector3(4.6, 0, 6.9); L.player.velocity = Vector3.ZERO
	await _wait(0.4)
	var d: Vector3 = Vector3(4.1, 0.0, 7.25) - L.player.cam.global_position
	L.player.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	await _wait(1.2)
	root.get_node("Dialogue").stop(); L.set_cutscene(false)
	await _wait(0.3)
	var t = L.player.target
	printerr("NOTE target: ", t, " controls ", L.player.controls, " ray hits ", L.player.ray.get_collider())
	root.get_viewport().get_texture().get_image().save_png(out.path_join("a_under_bed.png"))
	if t == null or not t.has_method("interact"):
		printerr("NOTE FAIL: nothing under the crosshair"); quit(1); return
	t.interact()
	await _wait(1.0)
	root.get_viewport().get_texture().get_image().save_png(out.path_join("b_reading.png"))
	var ev := InputEventAction.new(); ev.action = "interact"; ev.pressed = true
	Input.parse_input_event(ev)
	await _wait(0.5)
	printerr("NOTE closed: ", L.player.controls, " flag ", game.flags.get("read_pembis"))
	quit()
func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame
