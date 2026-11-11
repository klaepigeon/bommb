class_name Porter
extends Monster
## The porter. He sits in his lodge with his back to the passage, facing his board of keys, and says
## the one thing he has left: "Room four. Room four." The spare fuse is in his key box. He's harmless
## sitting. Startle him (in front of his board, a light in his face, a noise in his lodge) and he's
## up, shouting the place down, which brings everything else. A noise far enough off and he gets up
## to see to it, and the lodge is empty for a while. Someone who knows faces, who's seen the room-four
## photograph, can talk him down. Or Socko can fetch the fuse: he's small, and quiet.

var seat := Vector3.ZERO
var seat_yaw := 0.0
var _say_t := 3.0
var alarmed_t := 0.0

func _init() -> void:
	radius = 0.3; height = 1.65
	walk_speed = 0.7; hunt_speed = 1.3
	hearing = 0.8; sight = 4.0; fov = 0.6
	reach = 1.0
	head_hp = 2.0; body_hp = 4.0
	can_break_doors = false
	final_sit = false

func design() -> Dictionary:
	return {"name": "porter", "height": 1.55, "neck": 0.28, "head": 0.095, "arm": 1.05, "girth": 0.95, "stoop": 0.7,
		"skin": "skin_grey", "skin_tint": Color(0.95, 0.92, 0.85), "cloth": Color(0.16, 0.18, 0.22), "cloth_to": "foot", "shoes": true,
		"face": "old", "eyes": Color(0.2, 0.2, 0.2), "hair": null,
		"growths": [["neck", 4, 0.035, "coral"]]}

func after_setup() -> void:
	seat = global_position; seat_yaw = rotation.y
	set_state(S.SIT)

func animate(delta: float) -> void:
	var spd := Vector2(velocity.x, velocity.z).length()
	var sitting := state in [S.SIT, S.CALM]
	var t := Time.get_ticks_msec() / 1000.0
	body.pose({"phase": _anim_phase, "stride": clampf(spd, 0.0, 1.0), "sit": 1.0 if sitting else 0.0,
		"look": Vector2(sin(t * 0.3) * 0.3 if sitting else 0.0, -0.2), "reach": 1.0 if state == S.HUNT and dist_to_kurt() < 2.0 else 0.0,
		"tilt": 0.6 if state == S.CALM else 0.0, "twitch": 0.3})

func think(delta: float) -> void:
	_say_t -= delta
	match state:
		S.SIT:
			velocity = Vector3.ZERO
			global_position = global_position.lerp(seat, delta * 2.0)
			rotation.y = lerp_angle(rotation.y, seat_yaw, delta * 2.0)
			if _say_t <= 0.0 and dist_to_kurt() < 6.0:
				_say_t = randf_range(5.0, 8.0)
				if Speech.speaking == "": Speech.say("porter", "Room four. Room four.", {"style": "quiet"})
			# in front of him, lit: startled
			if sees and dist_to_kurt() < 3.0: alarm()
		S.CALM:
			velocity = Vector3.ZERO
		S.INVESTIGATE:
			if follow(walk_speed, delta):
				set_state(S.SEARCH)
			if sees and dist_to_kurt() < 2.5: alarm()
		S.SEARCH:
			velocity = Vector3.ZERO
			if state_t > 12.0: go_to(seat); set_state(S.PATROL)
		S.PATROL:
			if follow(walk_speed, delta): set_state(S.SIT)
		S.HUNT:
			alarmed_t -= delta
			if alarmed_t > 0.0 and fmod(state_t, 2.0) < delta:
				Audio.play("snarl", global_position + Vector3(0, 1.5, 0), 4.0, 1.4)
				Noises.make(global_position, 30.0, "shout", self)
			go_to(kurt.global_position if sees or dist_to_kurt() < 8.0 else heard_at)
			follow(hunt_speed, delta)
			if dist_to_kurt() < reach:
				kurt.hurt(18.0, self)
				kurt.velocity += (kurt.global_position - global_position).normalized() * 6.0
				go_to(seat); set_state(S.PATROL)
			elif alarmed_t <= 0.0 and (state_t > 10.0 or dist_to_kurt() > 8.0):
				go_to(seat); set_state(S.PATROL)
		S.STAGGER:
			velocity = Vector3.ZERO
			if state_t > float(get_meta("stagger_for", 1.0)): alarm()

func alarm() -> void:
	if state == S.HUNT: return
	alarmed_t = 6.0
	set_state(S.HUNT)
	World.emit_event("porter_alarm", {})

func heard(n: Dictionary, k: float) -> void:
	if state != S.SIT: return
	var lodge: AABB = level.maze.chambers.get("P", AABB())
	var near := lodge.grow(0.3).has_point(Vector3(heard_at.x, 1.0, heard_at.z))
	if near and k > 0.25:
		alarm()
	elif not near and k > 0.3:
		go_to(heard_at); set_state(S.INVESTIGATE)

func get_verbs(k) -> Array:
	if state in [S.DEAD, S.CALM]: return []
	return [{"id": "talk", "label": "Talk to him"}]

func act(v: String, k) -> void:
	if v != "talk": return
	if Progress.has("faces") and World.flag("saw_room_four"):
		set_state(S.CALM)
		await Speech.say("kurt", "Room four. That was us. You carried her case up and you never said a word about it. It's alright. Nobody's coming down.")
		await Speech.say("porter", "...Room four.")
		World.set_flag("porter_calmed")
		World.emit_event("porter_calmed", {})
		Progress.remember("porter", 1)
	else:
		await Speech.say("kurt", "Excuse me. I'm looking for a way out of here.")
		alarm()
