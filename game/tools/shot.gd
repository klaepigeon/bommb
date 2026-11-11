extends Node
## Renders views for checking: --shots=DIR --views=a;b  (each view: x,y,z,yaw,pitch)
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
	get_tree().quit()
