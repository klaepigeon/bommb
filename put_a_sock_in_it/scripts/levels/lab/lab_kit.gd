class_name LabKit
## Pieces for the Lab's experiments (docs/LAB.md): rooms in a void, lights, signs, doors that
## change level, the inhabitants' navigation. The Lab is for development: it's only reachable
## from the title in a debug build run from the editor or with --dev (DevOverlay.wanted()).

## A box room: floor, ceiling, four walls (inside faces), w x d, h tall, centred on `c` (its floor).
static func room(world: Node3D, c: Vector3, w: float, d: float, h := 3.0, wall: Material = null, floor_m: Material = null, ceil_m: Material = null) -> void:
	var wm: Material = wall if wall else Tex.mat("plaster", 1.0, {"tint": Color(0.7, 0.68, 0.62)})
	var fm: Material = floor_m if floor_m else Tex.mat("metlakh", 1.0)
	var cm: Material = ceil_m if ceil_m else Tex.mat("plaster", 1.0, {"tint": Color(0.6, 0.6, 0.58)})
	Build.box(world, c + Vector3(0, -0.05, 0), Vector3(w, 0.1, d), fm)
	Build.box(world, c + Vector3(0, h + 0.05, 0), Vector3(w, 0.1, d), cm)
	for s in [-1, 1]:
		Build.box(world, c + Vector3(s * (w * 0.5 + 0.1), h * 0.5, 0), Vector3(0.2, h, d + 0.4), wm)
		Build.box(world, c + Vector3(0, h * 0.5, s * (d * 0.5 + 0.1)), Vector3(w + 0.4, h, 0.2), wm)

## A sign on a wall: big, plain, readable.
static func label(world: Node3D, at: Vector3, rot_y: float, text: String, size := 56, col := Color(0.92, 0.86, 0.7)) -> Label3D:
	var lb := Label3D.new(); lb.text = text; lb.font_size = size; lb.pixel_size = 0.004; lb.modulate = col
	lb.outline_size = 8; lb.shaded = false
	world.add_child(lb); lb.position = at; lb.rotation.y = rot_y
	return lb

## A door that takes him to another level (a panel, its frame, a Use to go).
static func portal(world: Node3D, at: Vector3, rot_y: float, label: String, to_level: String, note := "") -> Use:
	var basis := Basis(Vector3.UP, rot_y)
	var mi := Build.box(world, at + Vector3(0, 1.05, 0), Vector3(1.0, 2.1, 0.08), Tex.mat("door_padded", 1.0), false, rot_y)
	mi.name = "Portal_" + to_level
	label(world, at + Vector3(0, 2.45, 0) + basis * Vector3(0, 0, 0.06), rot_y, label, 44)
	if note != "": label(world, at + Vector3(0, 2.2, 0) + basis * Vector3(0, 0, 0.06), rot_y, note, 30, Color(0.7, 0.66, 0.56))
	var u := Use.make(world, at + Vector3(0, 1.05, 0) + basis * Vector3(0, 0, 0.12), Vector3(1.0, 2.1, 0.3),
		func(): return "Go: " + label, func(_p): Game.change_level(to_level, {"card": false, "fade": 0.4}))
	u.name = "Go_" + to_level
	return u

## A steady light, and a bulb you can see.
static func lamp(world: Node3D, at: Vector3, col := Color("ffd9a8"), energy := 1.4, rng := 9.0) -> OmniLight3D:
	var l := Build.lamp(world, at, col, energy, rng)
	Build.box(world, at + Vector3(0, 0.12, 0), Vector3(0.08, 0.1, 0.08), Tex.mat("enamel", 1.0, {"emission": Vector3(1.6, 1.4, 1.0)}), false)
	return l

## Navigation for inhabitants over `world` (as the lobby does: a fine grid, static colliders).
static func bake_nav(world: Node3D) -> NavigationRegion3D:
	var nav := NavigationRegion3D.new(); world.add_child(nav)
	var nm := NavigationMesh.new()
	nm.cell_size = 0.1; nm.cell_height = 0.1
	nm.agent_radius = 0.2; nm.agent_height = 1.6; nm.agent_max_climb = 0.3; nm.agent_max_slope = 50.0
	var map := world.get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, 0.1); NavigationServer3D.map_set_cell_height(map, 0.1)
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, world)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	nav.navigation_mesh = nm
	return nav

## The building's people, as templates for the sandbox (bodies are the models in assets/people).
const PEOPLE := {
	"super": {"hp": 220, "poise": 90, "speed": 0.95, "run": 2.3, "hearing": 1.1, "sight": {"range": 13.0, "cos": 0.4},
		"attack": {"dmg": 0.4, "reach": 1.5, "windup": 0.6, "cool": 1.7}, "body": {"height": 1.84, "keys": true, "keys_front": 0.1, "hunch": 0.35},
		"voice": "super_breath", "voice_attack": "super_grunt", "step": "step_flesh"},
	"hunter": {"hp": 130, "poise": 55, "speed": 1.2, "run": 2.9, "hearing": 0.8, "sight": {"range": 11.0, "cos": 0.45},
		"attack": {"dmg": 0.34, "reach": 1.55, "windup": 0.55, "cool": 1.5}, "body": {"height": 2.05, "hunch": 0.75},
		"voice": "marta_breath", "voice_attack": "marta_rattle", "step": "step_concrete"},
	"listener": {"blind": true, "hearing": 1.9, "hp": 70, "speed": 0.7, "run": 3.1, "attack": {"dmg": 0.3, "reach": 1.4, "windup": 0.35, "cool": 1.3},
		"body": {"height": 1.85}, "voice": "sniff", "voice_every": 0.6},
	"laundress": {"hp": 45, "speed": 0.8, "run": 2.0, "hearing": 0.6, "attack": {"dmg": 0.12, "reach": 1.2, "windup": 0.6, "cool": 1.6},
		"body": {"height": 1.98, "hunch": 0.5}, "voice": "whisper"},
	"cook": {"hp": 90, "poise": 40, "speed": 1.0, "run": 2.4, "hearing": 0.9, "attack": {"dmg": 0.3, "reach": 1.4, "windup": 0.5, "cool": 1.4},
		"body": {"height": 1.8}, "voice": "marta_breath"},
	"rearranger": {"hp": 80, "speed": 0.9, "run": 2.0, "hearing": 0.5, "attack": {"dmg": 0.2, "reach": 1.3, "windup": 0.6, "cool": 1.6},
		"body": {"height": 1.5, "hunch": 0.3}, "voice": "groan", "voice_every": 1.5},
	"crawler": {"gait": "crawl", "fear_light": true, "hp": 28, "poise": 10, "speed": 1.4, "run": 3.4, "sight": {"range": 8.0, "cos": 0.3}, "hearing": 1.2,
		"attack": {"dmg": 0.17, "reach": 1.1, "windup": 0.25, "cool": 0.9}, "body": {"height": 1.0, "hunch": 1.3}, "voice": "vent_scrabble", "step": "step_flesh"},
	"caretaker": {"hp": 85, "poise": 35, "speed": 0.9, "run": 2.6, "hearing": 1.0, "attack": {"dmg": 0.28, "reach": 1.3, "windup": 0.45, "cool": 1.3},
		"body": {"height": 1.62, "hunch": 0.65}, "voice": "whisper"},
}
