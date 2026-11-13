class_name Growth
extends StaticBody3D
## Meat grown across a way through (docs/CHAPTER2.md): the stairwell between the first and second
## floors, the door of Flat 27. It breathes. It can be hacked or shot through (it takes a lot, and
## every blow is heard), or made to let go: `recede()` (heat, or what feeds it dying).
## Solid on the wall layer, so it blocks people and paths both; gone, the level re-bakes the paths.

signal cleared(g: Growth)

var size := Vector3(2.0, 2.4, 0.4)
var hp := 220.0
var gone := false
var _parts: Array = []
var _t := 0.0
var _shrink := 0.0

func _ready() -> void:
	add_to_group("growth")
	collision_layer = 1 | 8; collision_mask = 0
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size; cs.shape = sh; cs.position.y = size.y * 0.5
	add_child(cs)
	var meat := Tex.mat("flesh", 2.0, {"pulse": 0.012})
	var dark := Tex.mat("flesh_dark", 2.0, {"pulse": 0.008})
	var rng := RandomNumberGenerator.new(); rng.seed = int(global_position.x * 100.0 + global_position.z * 7.0)
	for i in 26:
		var mi := MeshInstance3D.new(); var sp := SphereMesh.new(); sp.radius = 0.5; sp.height = 1.0; sp.radial_segments = 10; sp.rings = 6
		mi.mesh = sp; mi.material_override = meat if i % 3 else dark
		mi.position = Vector3(rng.randf_range(-0.5, 0.5) * size.x, rng.randf_range(0.05, 0.95) * size.y, rng.randf_range(-0.4, 0.4) * size.z)
		var s := rng.randf_range(0.35, 0.8)
		mi.scale = Vector3(s * rng.randf_range(0.7, 1.4), s * rng.randf_range(0.7, 1.5), s * 0.6)
		add_child(mi); _parts.append(mi)
	# cords of it, stretched to the frame
	for i in 6:
		var c := MeshInstance3D.new(); c.mesh = Build.box_mesh(Vector3(0.05, 0.05, 0.6)); c.material_override = dark
		c.position = Vector3((i % 2 * 2 - 1) * size.x * 0.5, rng.randf_range(0.2, 0.9) * size.y, 0)
		c.rotation = Vector3(rng.randf_range(-0.6, 0.6), PI * 0.5, rng.randf_range(-0.4, 0.4)); add_child(c); _parts.append(c)

func _process(delta: float) -> void:
	_t += delta
	if gone:
		_shrink = minf(1.0, _shrink + delta * 0.35)
		for i in _parts.size():
			var p: Node3D = _parts[i]
			p.scale = p.scale.lerp(Vector3.ONE * 0.01, delta * (1.2 + (i % 4) * 0.3))
		if _shrink >= 1.0: queue_free()
		return
	# it breathes: slowly, not in time with anything
	for i in _parts.size():
		var p: Node3D = _parts[i]
		p.position.z += sin(_t * 0.7 + i) * 0.0004

## Let go (heat, or what feeds it has died): it draws back into the walls.
func recede() -> void:
	if gone: return
	gone = true
	collision_layer = 0
	Sfx.play_at("groan", global_position + Vector3(0, 1.2, 0), 2.0, 0.6)
	Sfx.play_at("flesh_tear", global_position + Vector3(0, 1.0, 0), 0.0, 0.7)
	cleared.emit(self)

func _hurt(dmg: float, at: Vector3) -> void:
	if gone: return
	hp -= dmg
	Sfx.play_at("flesh_tear", at, -2.0, randf_range(0.8, 1.1))
	Fx.burst("flesh", at, Vector3.UP)
	Game.make_noise(at, 0.4)
	if hp <= 0.0: recede()

func melee_hit(dmg: float, from: Vector3, _knock: float, _by = null) -> void:
	_hurt(dmg, global_position + Vector3(0, 1.2, 0) + (from - global_position).normalized() * size.z * 0.5)

func shot(point: Vector3, _dir: Vector3) -> void:
	_hurt(24.0, point)
