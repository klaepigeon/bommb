class_name Super
extends Monster
## The Super. Building 14's superintendent, gone the way the building's gone: the height of a
## doorway, starved to the bone, the skin of a much heavier man hanging off him in flaps, naked,
## the top of his head gone. He walks the service ring that holds the building's fuses and its
## way out, and he does not stop. Nothing kills him: a shot staggers him (in what's left of his
## head, for longer). He hears what the infection lets him hear: the more of it Kurt takes, the
## keener he is; the more Kurt remembers, the slower. He's too big for the holes into the flat.
## If he gets hold of Kurt, Kurt comes round in the box room, hurt, and he's gone back to his round.

var ring: Array[Vector3] = []
var ring_i := 0
var _step_t := 0.0

func _init() -> void:
	radius = 0.42; height = 2.25
	walk_speed = 0.95; hunt_speed = 1.45
	hearing = 1.1; sight = 12.0; fov = 0.4
	killable = false
	reach = 1.35
	can_break_doors = true

func design() -> Dictionary:
	return {"name": "super", "height": 2.3, "neck": 0.08, "head": 0.105, "arm": 1.3, "hands": 1.6, "girth": 0.62, "leg": 1.08,
		"skin": "skin_pale", "skin_tint": Color(0.95, 0.88, 0.85), "cloth": null, "bare_arms": true, "face": "old",
		"eyes": Color(0.75, 0.75, 0.7), "stoop": 0.55, "flaps": 9,
		"growths": [["head", 4, 0.06, "flesh"], ["chest", 3, 0.05, "flesh"]]}

func after_setup() -> void:
	for key in level.maze.cells:
		if level.maze.cells[key] == "X": ring.append(level.maze.center(key.x, key.y))
	ring.sort_custom(func(a, b): return atan2(a.z - 18.0, a.x - 18.0) < atan2(b.z - 18.0, b.x - 18.0))
	allowed = func(i): return true
	set_state(S.PATROL)

func _door_cost(door) -> float:
	if door is Flat47: return -1.0          # he doesn't fit
	return super(door)

func animate(delta: float) -> void:
	var spd := Vector2(velocity.x, velocity.z).length()
	_step_t -= delta * spd
	if _step_t <= 0.0 and spd > 0.1:
		_step_t = 0.75
		Audio.play("step_heavy", global_position, -4.0, randf_range(0.8, 1.0))
		Noises.make(global_position, 0.1, "super_step", self)
	var reach_k := 1.0 if state == S.HUNT and dist_to_kurt() < 3.0 else 0.0
	body.pose({"phase": _anim_phase * 0.8, "stride": clampf(spd / 1.2, 0.0, 1.0), "reach": reach_k, "stoop": 0.55 + (0.2 if state == S.STAGGER else 0.0),
		"twitch": 0.15, "look": Vector2.ZERO})

func think(delta: float) -> void:
	var agg := Progress.aggression()
	if state != S.HUNT and sees and seen_t > 0.6 / agg:
		set_state(S.HUNT)
		World.emit_event("hunted", {"id": id, "m": self})
	match state:
		S.GRAB:
			velocity = Vector3.ZERO
			if state_t > 3.0: set_state(S.PATROL); _next_ring_point()
		S.STAGGER:
			velocity = Vector3.ZERO
			if state_t > float(get_meta("stagger_for", 1.0)): set_state(S.HUNT if sees else S.SEARCH)
		S.PATROL:
			if path.is_empty() or follow(walk_speed * lerpf(0.8, 1.2, (agg - 0.5) / 1.5), delta):
				_next_ring_point()
		S.INVESTIGATE:
			if follow(walk_speed * 1.2 * agg, delta): set_state(S.SEARCH)
		S.SEARCH:
			velocity = Vector3.ZERO
			if state_t > 8.0 / agg: set_state(S.PATROL); _next_ring_point()
		S.HUNT:
			_repath_t -= delta
			if sees and (_repath_t <= 0.0 or goal.distance_to(kurt.global_position) > 1.2):
				go_to(kurt.global_position); _repath_t = 0.7
			follow(hunt_speed * agg, delta)
			if dist_to_kurt() < reach: grab()
			elif not sees and (global_position.distance_to(last_known) < 0.9 or state_t > 20.0): set_state(S.SEARCH)

func _next_ring_point() -> void:
	if ring.is_empty(): return
	ring_i = (ring_i + 3) % ring.size()
	go_to(ring[ring_i])

func heard(n: Dictionary, k: float) -> void:
	if state in [S.PATROL, S.SEARCH, S.INVESTIGATE] and k > 0.2 / Progress.aggression():
		go_to(heard_at); set_state(S.INVESTIGATE)

func shot(part: String, by, at: Vector3) -> void:
	Audio.play("hit", at, 0.0)
	World.emit_event("monster_shot", {"id": id, "part": part, "m": self})
	stagger(3.0 if part == "head" else 1.2)
