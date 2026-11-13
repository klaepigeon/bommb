class_name BathThing
extends StaticBody3D
## What's in the bath in 24 (docs/CHAPTER2.md): too big for the bath, grey-pink, mostly under the
## water, breathing. The one in 24 feeds it. The meat over 27's door grows out of it: if it dies,
## that lets go. It can't move. It can be killed (it takes a lot); it screams when hurt.

signal died(t: BathThing)

var hp := 140.0
var dead := false
var _body: Node3D
var _t := 0.0
var fed := 0.0                 # (the one who looks after it brings it meat)

func _ready() -> void:
	add_to_group("bath_thing")
	collision_layer = 8 | 32; collision_mask = 0
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(1.4, 0.7, 0.6); cs.shape = sh; cs.position.y = 0.6; add_child(cs)
	_body = Node3D.new(); add_child(_body)
	var skin := Tex.mat("skin", 2.0, {"tint": Color(0.75, 0.6, 0.6), "rough": 0.2})
	var flesh := Tex.mat("flesh", 2.0, {"pulse": 0.01})
	for i in 5:
		var mi := MeshInstance3D.new(); var sp := SphereMesh.new(); sp.radius = 0.5; sp.height = 1.0
		mi.mesh = sp; mi.material_override = skin if i != 2 else flesh
		mi.position = Vector3(-0.5 + i * 0.25, 0.55 + (0.12 if i == 2 else 0.0), 0.0)
		mi.scale = Vector3(0.42, 0.34 + (0.1 if i == 2 else 0.0), 0.5)
		_body.add_child(mi)
	# something like a face, under the surface at one end: a mouth, and no eyes
	var m := MeshInstance3D.new(); m.mesh = Build.box_mesh(Vector3(0.18, 0.02, 0.06)); m.material_override = Tex.mat("black")
	m.position = Vector3(-0.62, 0.62, 0.18); _body.add_child(m)

func _process(delta: float) -> void:
	if dead: return
	_t += delta
	_body.scale = Vector3.ONE * (1.0 + sin(_t * 0.9) * 0.03)
	if fmod(_t, 4.7) < delta: Sfx.play_at("bath_breath", global_position + Vector3(0, 0.7, 0), -4.0, randf_range(0.8, 0.95))

func _hurt(dmg: float) -> void:
	if dead: return
	hp -= dmg
	Sfx.play_at("marta_scream", global_position + Vector3(0, 0.8, 0), 2.0, 0.5)
	Fx.burst("flesh", global_position + Vector3(0, 0.8, 0), Vector3.UP)
	Game.make_noise(global_position, 0.9)
	if hp <= 0.0:
		dead = true
		Sfx.play_at("groan", global_position + Vector3(0, 0.8, 0), 4.0, 0.45)
		var tw := create_tween(); tw.tween_property(_body, "position:y", -0.35, 2.5)
		died.emit(self)

func melee_hit(dmg: float, _from: Vector3, _knock: float, _by = null) -> void:
	_hurt(dmg)

func shot(_point: Vector3, _dir: Vector3) -> void:
	_hurt(26.0)
