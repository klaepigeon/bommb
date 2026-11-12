extends SceneTree
## Marta on her feet in each state, from Kurt's eye: patrol, sniffing, chase, encounter, stunned.
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/hunter_pose.gd -- out=<dir>
func _initialize() -> void:
	await process_frame
	var out := "user://hunter_pose"
	for a in OS.get_cmdline_user_args(): if a.begins_with("out="): out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	var game = root.get_node("Game")
	game.flags["flesh_stage"] = "B"; game.flags["met_marta_maze"] = true
	game.change_level("flesh47", {"card": false, "checkpoint": true, "fade": 0.01})
	await _wait(3.0)
	var F = game.level
	game._black.visible = false; root.get_node("Dialogue").stop(); F.set_cutscene(false)
	var m = F.marta
	m.active = false
	var at: Vector3 = F._p("B", Vector3(6.0, 0, 4.5))
	var eye: Vector3 = F._p("B", Vector3(8.6, 0, 4.5))
	at = F._p("B", Vector3(6.6, 0, 4.5))
	F.player.global_position = eye; F.player.torch_on = true
	var d: Vector3 = at + Vector3(0, 1.0, 0) - (eye + Vector3(0, 1.62, 0))
	F.player.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
	for s in ["patrol", "chase", "encounter", "stunned"]:
		m.global_position = at; m.set_state(s)
		for i in 3:
			var to: Vector3 = eye - at
			m.rotation.y = atan2(-to.x, -to.z) + (0.0 if i < 2 else PI / 2)     # two from the front, one side-on
			m.velocity = Vector3(0, 0, 1.0) if s != "encounter" else Vector3.ZERO
			var t0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < 500 + i * 130:
				await physics_frame
				var dt := 1.0 / 60.0
				m._state_t += dt; m._walk += dt * (9.0 if s == "chase" else 5.0)
				m._animate(dt)
			root.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%d.png" % [s, i]))
	quit()

func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0: await process_frame
