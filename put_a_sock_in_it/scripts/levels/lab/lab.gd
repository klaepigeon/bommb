extends Level
## The Lab (docs/LAB.md): development only. A bare room with a door to each experiment and one
## back to the title. Reached from the title's LAB button in a debug build from the editor or run
## with --dev; never in a release build.

const EXPERIMENTS := [
	["lab_sandbox", "AI SANDBOX", "spawn the building's people, set them on him, watch them think"],
	["lab_echo", "ECHO", "a blind maze: he sees by sound, so does it"],
	["lab_mirror", "MIRROR", "the mirror shows someone the room doesn't"],
	["lab_still", "STILL", "they only move while nothing sees them"],
	["lab_through", "THROUGH", "both doorways open on this room"],
	["lab_breath", "BREATH", "it closes in while you stand still"],
]

func build() -> void:
	var e := env.environment
	e.ambient_light_color = Color("4a4640"); e.ambient_light_energy = 0.7
	e.fog_density = 0.01
	LabKit.room(world, Vector3.ZERO, 20.0, 8.0, 3.2, Tex.mat("plaster", 1.0, {"tint": Color(0.62, 0.62, 0.58)}))
	for x in [-6.0, 0.0, 6.0]: LabKit.lamp(world, Vector3(x, 2.9, 0.0))
	LabKit.label(world, Vector3(-9.88, 2.2, 0), PI * 0.5, "THE LAB", 96)
	LabKit.label(world, Vector3(-9.88, 1.7, 0), PI * 0.5, "development only: experiments, not the game", 26, Color(0.7, 0.66, 0.56))
	# three doors on the north wall, three on the south; what each is shows when he's at it
	var i := 0
	for ex in EXPERIMENTS:
		var north := i < 3
		var x := -6.0 + (i % 3) * 6.0
		LabKit.portal(world, Vector3(x, 0, -3.95 if north else 3.95), 0.0 if north else PI, ex[1], ex[0], ex[2])
		i += 1
	var back := Use.make(world, Vector3(9.9, 1.05, 0.0), Vector3(0.3, 2.1, 1.0), func(): return "Back to the title", func(_p): Game.to_title())
	back.name = "Back"
	Build.box(world, Vector3(9.95, 1.05, 0.0), Vector3(0.08, 2.1, 1.0), Tex.mat("door_padded", 1.0), false)
	LabKit.label(world, Vector3(9.88, 2.4, 0.0), -PI * 0.5, "TITLE", 40)
	player.position = Vector3(0, 0, 2.0)
	player.set_view(0.0, 0.0)
	socko.visible = true

func begin() -> void:
	set_cutscene(false)
	await Game.fade(0.0, 0.5)
	hud.set_objective("The Lab. Pick an experiment.")
