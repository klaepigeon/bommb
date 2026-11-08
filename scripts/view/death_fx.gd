class_name DeathFx
extends RefCounted
## The mess a death leaves: sprays, pools, clouds, bubbles. Reduced gore turns blood into
## dark ink (the drawing's own ink) and keeps everything else. All in the parent's space.

static var _soft_tex: Texture2D
## A soft round blob (so a cloud is puffs and a spray is drops, not squares).
static func _soft() -> Texture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0)])
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 32
		gt.height = 32
		_soft_tex = gt
	return _soft_tex


static func gore() -> bool:
	var ml := Engine.get_main_loop()
	var ui = (ml as SceneTree).root.get_node_or_null("Ui") if ml is SceneTree else null
	return not (ui and ui.reduced_gore)


static func blood_colour() -> Color:
	return Color("8a0c10") if gore() else Color("1e120e")


static func _particles(parent: Node3D, at: Vector3, n: int, col: Color, size: float, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = n
	p.lifetime = life
	p.explosiveness = 0.95
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.albedo_texture = _soft()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	p.mesh = q
	p.local_coords = true
	parent.add_child(p)
	p.position = at
	p.emitting = true
	parent.get_tree().create_timer(life + 1.0).timeout.connect(p.queue_free)
	return p


## A burst of blood (or ink) out of a wound, along `dir`.
static func spray(parent: Node3D, at: Vector3, dir: Vector3, n := 40) -> void:
	var p := _particles(parent, at, n, blood_colour(), 0.07, 1.1)
	p.direction = dir.normalized()
	p.spread = 28.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.5
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.6


## A pool spreading under a body, left on the floor.
static func pool(parent: Node3D, at: Vector3, radius := 0.9, secs := 2.0) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.01
	cm.radial_segments = 12
	var m := StandardMaterial3D.new()
	m.albedo_color = blood_colour().darkened(0.15)
	m.roughness = 0.15
	m.metallic_specular = 0.9
	cm.material = m
	mi.mesh = cm
	parent.add_child(mi)
	mi.position = Vector3(at.x, at.y + 0.02, at.z)
	mi.scale = Vector3(0.05, 1, 0.05)
	mi.rotation.y = randf() * TAU
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(1.0, 1, 0.8), secs).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


## A cloud that hangs and drifts (gas: sick green; dust: grey).
static func cloud(parent: Node3D, at: Vector3, col: Color, n := 24, life := 2.6) -> void:
	var p := _particles(parent, at, n, col, 0.22, life)
	p.explosiveness = 0.4
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.45
	p.gravity = Vector3(0, 0.1, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.8


static func bubbles(parent: Node3D, at: Vector3, n := 30) -> void:
	var p := _particles(parent, at, n, Color(0.75, 0.9, 0.85, 0.75), 0.09, 1.8)
	p.explosiveness = 0.2
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, 1.0, 0)


## Something heavy, dropped from above: a box that slams down at `at` and stays.
static func slab(parent: Node3D, at: Vector3, size: Vector3, col: Color, from_h := 8.0, secs := 0.18) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	bm.material = m
	mi.mesh = bm
	parent.add_child(mi)
	mi.position = at + Vector3(0, from_h, 0)
	var tw := mi.create_tween()
	tw.tween_property(mi, "position", at + Vector3(0, size.y * 0.5, 0), secs).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# it lifts away again after a while, leaving what it did
	tw.tween_interval(1.6)
	tw.tween_property(mi, "position", at + Vector3(0, from_h, 0), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	return mi
