class_name Figure
extends Monster
## The white room's three: MAMA, PAPA, CHILD. White as the plaster, the wrong length in the neck and
## the arm, faces like nothing. They move only when Kurt isn't looking at them. Keep them in view and
## they're furniture. Look away and they're closer. One that reaches him shoves him out of its room.
## Shooting them does nothing but end them, which Socko would like very much.

var tag := "MAMA"
var place := Vector3.ZERO
var room := AABB()

func _init() -> void:
	radius = 0.25; walk_speed = 2.4; hunt_speed = 2.4
	hearing = 0.0; sight = 30.0; fov = -1.0
	reach = 0.8
	head_hp = 1.0; body_hp = 2.0
	can_break_doors = false

func design() -> Dictionary:
	var child := tag == "CHILD"
	return {"name": "figure_" + tag, "height": 1.15 if child else 1.9, "neck": 0.3 if not child else 0.18, "head": 0.075, "arm": 1.35,
		"girth": 0.75, "skin": "draft", "cloth": null, "face": "blank", "stoop": 0.0}

func after_setup() -> void:
	place = global_position
	height = 1.15 if tag == "CHILD" else 1.9
	set_state(S.IDLE)

func _looked_at() -> bool:
	var cam := kurt.cam
	var to := (global_position + Vector3(0, height * 0.6, 0)) - cam.global_position
	if (-cam.global_transform.basis.z).dot(to.normalized()) < 0.55: return false
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, global_position + Vector3(0, height * 0.6, 0), 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func animate(_delta: float) -> void:
	body.pose({"stoop": 0.0, "look": Vector2.ZERO, "reach": 0.4 if state == S.HUNT else 0.0})

func think(delta: float) -> void:
	if state in [S.DEAD]: return
	var inside := room.grow(0.6).has_point(kurt.global_position + Vector3(0, 0.5, 0))
	if _looked_at() or not inside:
		velocity = Vector3.ZERO
		if not inside and global_position.distance_to(place) > 0.3 and not _looked_at():
			global_position = global_position.move_toward(place, delta * 3.0)
		return
	# unseen: closer
	var to := kurt.global_position - global_position; to.y = 0
	var step := minf(to.length() - 0.3, walk_speed * delta)
	if step > 0.0:
		velocity = to.normalized() * walk_speed
		move_and_slide()
		_face(kurt.global_position, 1.0)
	if dist_to_kurt() < reach:
		kurt.hurt(14.0, self)
		var out := kurt.global_position - room.get_center(); out.y = 0
		kurt.velocity += out.normalized() * 8.0 + Vector3.UP * 2.0
		Audio.play("thud", kurt.global_position, 0.0)
		World.emit_event("figure_shove", {"tag": tag})
		global_position = place

func get_verbs(_k) -> Array:
	return [{"id": "look", "label": "Look"}] if state != S.DEAD else []

func act(_v: String, _k) -> void:
	World.emit_event("looked", {"title": tag, "desc": "A tag hangs round its neck on string: %s." % tag, "key": "figure_" + tag})
