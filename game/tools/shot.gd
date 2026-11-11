extends Node
## Renders views for checking: --shots=DIR --views="x,y,z,yaw,pitch;..."
## --gallery: each creature in turn, standing in the white room in front of the camera.
func run(main) -> void:
	await get_tree().create_timer(1.5).timeout
	var dir := String(main.args.get("shots", "user://shots"))
	DirAccess.make_dir_recursive_absolute(dir)
	var views := String(main.args.get("views", "")).split(";", false)
	var i := 0
	for v in views:
		var p := v.split(",")
		main.kurt.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		main.kurt.yaw = float(p[3]); main.kurt.pitch = float(p[4]) if p.size() > 4 else 0.0
		for f in 30: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s/view%02d.png" % [dir, i])
		i += 1
	if main.args.has("gallery"):
		var st = main.story
		var fr: AABB = main.level.maze.chambers["F"]
		var eye := Vector3(3.4, 0, 3.4)        # the living room: known light
		for m in [st.marta, st.super_, st.porter, st.lamplighter, st.figures[0], st.figures[2]]:
			for o in [st.marta, st.super_, st.porter, st.lamplighter] + st.figures:
				o.process_mode = Node.PROCESS_MODE_DISABLED
				o.visible = o == m
				if o != m: o.global_position = Vector3(0, -50, 0)
			m.visible = true
			st.socko.visible = false
			var key_light := Lamp.make(main.level, eye + Vector3(-0.6, 2.2, 0.8), Color(1, 0.95, 0.9), 1.4, 6.0)
			m.global_position = eye + Vector3(-2.2 if m is Super else -1.7, 0, 0)
			m.rotation.y = -PI * 0.5
			m.sees = true; m.state = Monster.S.TALK if m is Marta else Monster.S.IDLE
			m.body.set_zone(1)
			for f in 30: m.animate(0.033)
			main.kurt.global_position = eye; main.kurt.yaw = PI * 0.5; main.kurt.pitch = 0.05 if not (m is Super) else 0.2
			for f in 70: await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("%s/creature_%s.png" % [dir, m.id])
			key_light.queue_free()
	get_tree().quit()
