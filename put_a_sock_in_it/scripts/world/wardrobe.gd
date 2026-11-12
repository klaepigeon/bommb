class_name Wardrobe
extends AnimatableBody3D
## A big Soviet wardrobe (a "stenka" piece): heavy, lacquered, two doors and a mirror. It can be
## pushed along `slide` when `pushable`: Kurt sets his shoulder to it and it grinds across the
## floor in shoves.

signal pushed(w: Wardrobe)
var size := Vector3(1.3, 2.1, 0.6)
var slide := Vector3(1.3, 0, 0)       # world-space distance it moves when pushed
var pushable := false
var moved := false
var _busy := false

func _ready() -> void:
	sync_to_physics = false
	var body := Build.box_mesh(size)
	var mi := MeshInstance3D.new(); mi.mesh = body; mi.material_override = Tex.mat("wood", 2.0); mi.position.y = size.y * 0.5
	add_child(mi)
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size; cs.shape = sh; cs.position.y = size.y * 0.5
	add_child(cs)
	# doors, a mirror, feet, a cornice: so it reads as a wardrobe, not a crate
	for sx in [-1, 1]:
		var d := MeshInstance3D.new(); d.mesh = Build.box_mesh(Vector3(size.x * 0.48, size.y * 0.8, 0.02))
		d.material_override = Tex.mat("wood_light", 2.0); d.position = Vector3(sx * size.x * 0.25, size.y * 0.47, size.z * 0.5 + 0.01)
		add_child(d)
		var k := MeshInstance3D.new(); k.mesh = Build.box_mesh(Vector3(0.03, 0.12, 0.03)); k.material_override = Tex.mat("metal")
		k.position = Vector3(sx * 0.06, size.y * 0.5, size.z * 0.5 + 0.035); add_child(k)
	var mirror := MeshInstance3D.new(); mirror.mesh = Build.box_mesh(Vector3(size.x * 0.3, size.y * 0.5, 0.01))
	mirror.material_override = Tex.mat("metal", 1.0, {"tint": Color(0.7, 0.75, 0.8), "rough": 0.1}); mirror.position = Vector3(size.x * 0.25, size.y * 0.5, size.z * 0.5 + 0.025)
	add_child(mirror)
	var top := MeshInstance3D.new(); top.mesh = Build.box_mesh(Vector3(size.x + 0.06, 0.08, size.z + 0.06)); top.material_override = Tex.mat("wood", 2.0)
	top.position.y = size.y; add_child(top)

func get_prompt() -> String:
	if _busy or moved: return ""
	return "Push wardrobe" if pushable else "Heavy wardrobe"

func interact(p = null) -> void:
	if _busy or moved or not pushable: return
	_busy = true
	if p and p.has_method("shake"): p.shake(0.01, 1.6)
	# three shoves, each a grind and a stop
	for i in 3:
		Sfx.play_at("scrape", global_position + Vector3(0, 0.3, 0), 2.0, randf_range(0.85, 1.0))
		Game.make_noise(global_position, 0.6)
		var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "position", position + slide / 3.0, 0.55)
		await tw.finished
		await get_tree().create_timer(0.25).timeout
	moved = true; _busy = false
	pushed.emit(self)
