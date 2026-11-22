extends Level
## The Lab (docs/LAB.md): development only. A bare room with a door to each experiment and one
## back to the title. Reached from the title's LAB button in a debug build from the editor or run
## with --dev; never in a release build.

const EXPERIMENTS := [
	["lab_sandbox", "AI SANDBOX", "spawn the building's people, set them on him, watch them think"],
	["lab_echo", "ECHO", "a blind maze: he sees by sound, so does it"],
	["lab_mirror", "MIRROR", "the mirror shows someone the room doesn't"],
]

func build() -> void:
	var e := env.environment
	e.ambient_light_color = Color("4a4640"); e.ambient_light_energy = 0.7
	e.fog_density = 0.01
	LabKit.room(world, Vector3.ZERO, 14.0, 8.0, 3.2, Tex.mat("plaster", 1.0, {"tint": Color(0.62, 0.62, 0.58)}))
	for x in [-4.0, 0.0, 4.0]: LabKit.lamp(world, Vector3(x, 2.9, 0.0))
	LabKit.label(world, Vector3(0, 2.4, 3.88), PI, "THE LAB", 96)
	LabKit.label(world, Vector3(0, 1.9, 3.88), PI, "development only: experiments, not the game", 26, Color(0.7, 0.66, 0.56))
	var i := 0
	for ex in EXPERIMENTS:
		LabKit.portal(world, Vector3(-4.0 + i * 4.0, 0, -3.95), 0.0, ex[1], ex[0], ex[2])
		i += 1
	var back := Use.make(world, Vector3(6.9, 1.05, 0.0), Vector3(0.3, 2.1, 1.0), func(): return "Back to the title", func(_p): Game.to_title())
	back.name = "Back"
	Build.box(world, Vector3(6.95, 1.05, 0.0), Vector3(0.08, 2.1, 1.0), Tex.mat("door_padded", 1.0), false)
	LabKit.label(world, Vector3(6.88, 2.4, 0.0), -PI * 0.5, "TITLE", 40)
	player.position = Vector3(0, 0, 2.0)
	player.set_view(0.0, 0.0)
	socko.visible = true

func begin() -> void:
	set_cutscene(false)
	await Game.fade(0.0, 0.5)
	hud.set_objective("The Lab. Pick an experiment.")
