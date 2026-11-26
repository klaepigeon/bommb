extends Node3D
## The live rail along the tracks: when the station has power, anything that steps on it (the
## player, a Feeder chasing them) is thrown off and badly hurt. Boards cover it at the crossings.

const DAMAGE := 40.0

var _cool: Dictionary = {}

func setup(def: Dictionary, xf: Transform3D, floor_y: float) -> void:
	var z: float = def.z
	var spans := []
	var x0: float = def.x[0]
	for c in def.crossings:
		spans.append([x0, c[0]])
		x0 = c[1]
	spans.append([x0, def.x[1]])
	var steel := Assets.surface("metal_worn", 1.0, Color(0.6, 0.55, 0.5))
	var wood := Assets.surface("planks", 1.0)
	var kit := MeshKit.new()
	for s in spans:
		var area := Area3D.new()
		area.collision_layer = 0
		area.collision_mask = 2 | 4
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(s[1] - s[0], 0.5, 0.45)
		cs.shape = b
		area.add_child(cs)
		add_child(area)
		area.global_position = xf * Vector3((s[0] + s[1]) * 0.5, floor_y + 0.25, z)
		kit.box(Vector3((s[0] + s[1]) * 0.5, floor_y + 0.1, z), Vector3(s[1] - s[0], 0.12, 0.12), steel, false)
	for c in def.crossings:
		kit.box(Vector3((c[0] + c[1]) * 0.5, floor_y + 0.12, z), Vector3(c[1] - c[0], 0.06, 1.0), wood, false)
	var mi := kit.build("ThirdRail")
	add_child(mi)
	mi.transform = xf

func _physics_process(_delta: float) -> void:
	if not World.power:
		return
	var now := Time.get_ticks_msec()
	for area in get_children():
		if not area is Area3D:
			continue
		for body in (area as Area3D).get_overlapping_bodies():
			if body.has_method("hurt") and now - int(_cool.get(body, 0)) > 1200:
				_cool[body] = now
				body.hurt(DAMAGE, "the third rail", body.global_position + Vector3.UP)
				Sfx.play_at("radio_static", body.global_position, 8.0, 0.2)
				Events.world_event.emit({"kind": "noise", "actor": body, "position": body.global_position, "place": "", "loudness": 14.0})
