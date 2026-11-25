extends Node
## Renders fixed views of the world to PNGs (real renderer, needs a display: xvfb-run).
## Used to check the look after every art change. Views can be extended freely.

const VIEWS := {
	"street_west": [Vector3(-20, 1.7, 2), Vector3(-45, 2.5, 0)],
	"street_east": [Vector3(0, 1.7, -2), Vector3(30, 3, 0)],
	"north_facades": [Vector3(-20, 3, 6), Vector3(-20, 5, -9)],
	"south_facades": [Vector3(0, 3, -6), Vector3(10, 4, 9)],
	"bar_inside": [Vector3(-18, 1.6, -11), Vector3(-24, 1.0, -16)],
	"diner_inside": [Vector3(-36, 1.6, 10.6), Vector3(-41, 1.0, 15)],
	"apartment": [Vector3(-32, 1.6, -12), Vector3(-34, 0.8, -20)],
	"yard": [Vector3(-12, 1.7, -14), Vector3(-12, 1.2, -28)],
	"facade_close": [Vector3(-36, 4.5, -2.5), Vector3(-38, 5.5, -9)],
	"club": [Vector3(13, 1.6, 10.5), Vector3(20, 1.0, 17)],
}

## Third-person views from the player's own camera: [player position, yaw, pitch].
const PLAY := {
	"play_start": [Vector3(17, 0.2, -7.5), 180.0, -8.0],
	"play_bar": [Vector3(-19, 0.2, -11.2), 200.0, -10.0],
	"play_diner": [Vector3(-44, 0.2, 10.6), 230.0, -12.0],
	"play_pawn": [Vector3(-2, 0.2, -10.5), 160.0, -10.0],
	"play_street_night": [Vector3(-30, 0.2, 6.5), 90.0, -5.0],
}

func run(main: Node, dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var only_play: String = main.args.get("view", "")
	if main.player:
		for name in PLAY:
			if only_play != "" and name != only_play:
				continue
			var v: Array = PLAY[name]
			main.player.global_position = v[0]
			main.player.yaw = v[1]
			main.player.pitch = v[2]
			for i in 30:
				await get_tree().physics_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
			print("SHOT ", name)
	var cam := Camera3D.new()
	cam.fov = 70
	main.world.add_child(cam)
	cam.current = true
	var only: String = main.args.get("view", "")
	for name in VIEWS:
		if only != "" and name != only:
			continue
		var v: Array = VIEWS[name]
		cam.position = v[0]
		cam.look_at(v[1])
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
		print("SHOT ", name)
	get_tree().quit()
