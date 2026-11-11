class_name Ambience
extends Node
## The building between the things that happen in it. Reads content/ambience.json: for whichever
## place Kurt is in, a bed of loops (crossfaded when he moves), its air (fog), and one-shot sounds
## now and then, somewhere around him (in the walls, the flat above, down the stairwell). One-shots
## wait while anyone is talking or anything is hunting him; then the tension layer takes over
## (heartbeat, pressure) and rises the nearer it gets. Dust hangs in the air round him: it only
## shows where there's light on it (the torch, a lamp), as dust does.
##
## New sounds: add them to Audio._make and name them here. New places: give their entry in
## places.json an "ambience" profile name and "fog"; see docs/EXPANDING.md.

const FADE := 2.5                  ## seconds for beds to cross over

var story
var data := {}
var profile_id := ""
var _beds: Array = []              ## [{player, want_db}]
var _timers := {}                  ## event index -> seconds left
var _events: Array = []
var _fog_want := [Color(0.02, 0.02, 0.025), 16.0]
var _hb_t := 0.0
var _pressure: AudioStreamPlayer
var tension := 0.0                 ## 0..1, how close the nearest hunter is
var _rng := RandomNumberGenerator.new()
var _dust: CPUParticles3D
var _queue: Array = []             ## [time_left, sound, pos, db, pitch] (repeats)

func setup(p_story) -> void:
	story = p_story
	_rng.randomize()
	data = JSON.parse_string(FileAccess.get_file_as_string("res://content/ambience.json"))
	_pressure = AudioStreamPlayer.new(); _pressure.stream = Audio.stream("pressure")
	_pressure.volume_db = -80.0; _pressure.bus = "Master"
	add_child(_pressure); _pressure.play()
	_make_dust()

## Which profile a place uses: a Place's own "ambience", else the place id itself (47, maze, stairs).
func profile_for(place: String) -> String:
	var pl: Place = story.level.places.get(place)
	if pl: return pl.ambience()
	return place

func _process(delta: float) -> void:
	if story == null or story.kurt == null: return
	var kurt: Node3D = story.kurt
	var place: String = story.level.place_of(kurt.global_position)
	var want := profile_for(place)
	if want != profile_id: _switch(want, place)
	_fade_beds(delta)
	# the air
	Lights.fog_color = Lights.fog_color.lerp(_fog_want[0], minf(delta * 2.0, 1.0))
	Lights.fog_far = lerpf(Lights.fog_far, _fog_want[1], minf(delta * 2.0, 1.0))
	_background(kurt)
	_tension(delta, kurt)
	_tick_events(delta, kurt)
	if _dust: _dust.global_position = kurt.global_position + Vector3(0, 1.3, 0)

# ----------------------------------------------------------------------------------- beds and air
func _switch(id: String, place: String) -> void:
	profile_id = id
	var prof: Dictionary = data.profiles.get(id, data.profiles.get("47", {}))
	Log.mark("ambience " + id)
	for b in _beds: b.want = -80.0               # everything playing fades out...
	for spec in prof.get("bed", []):              # ...except what this place shares, which stays
		var found = null
		for b in _beds:
			if b.sound == spec[0]: found = b
		if found == null:
			var p := AudioStreamPlayer.new(); p.stream = Audio.stream(String(spec[0])); p.volume_db = -80.0
			add_child(p); p.play()
			found = {"sound": String(spec[0]), "player": p, "want": -80.0}
			_beds.append(found)
		found.want = float(spec[1])
	var pl: Place = story.level.places.get(place)
	if pl: _fog_want = pl.fog()
	elif prof.has("fog"): _fog_want = [Color(String(prof.fog[0])), float(prof.fog[1])]
	_events = prof.get("events", [])
	_timers.clear()
	for i in _events.size():
		var e: Dictionary = _events[i]
		_timers[i] = _rng.randf_range(e.every[0] * 0.3, e.every[1] * 0.6)   # first one comes sooner

func _fade_beds(delta: float) -> void:
	var calm := 1.0 - tension * 0.6                # hunted, the building holds its breath
	for b in _beds.duplicate():
		var p: AudioStreamPlayer = b.player
		var target: float = b.want + (20.0 * log(calm) / log(10.0) if b.want > -79.0 else 0.0)
		p.volume_db = move_toward(p.volume_db, target, delta * 60.0 / FADE)
		if b.want <= -80.0 and p.volume_db <= -79.0:
			p.queue_free(); _beds.erase(b)

## Behind everything: white where the outside can be seen (it's all there is out there), and the
## place's own air everywhere else, so a hairline gap between two walls doesn't shine.
func _background(kurt: Node3D) -> void:
	var main = story.main
	if main == null or main.env == null or main.args.has("bg"): return
	var outside := false
	if profile_id == "47":
		var p := kurt.global_position
		outside = p.z < 1.2 and p.x < 7.8         # on the balcony or the ledge, or near the windows
	var want: Color = Color(0.93, 0.94, 0.95) if outside else Lights.fog_color
	main.env.background_color = main.env.background_color.lerp(want, 1.0 if outside else minf(get_process_delta_time() * 3.0, 1.0))

# ------------------------------------------------------------------------------------- one-shots
func quiet() -> bool:
	return Speech.speaking != "" or tension > 0.05

func _tick_events(delta: float, kurt: Node3D) -> void:
	for q in _queue.duplicate():
		q[0] -= delta
		if q[0] <= 0.0:
			Audio.play(q[1], q[2], q[3], q[4]); _queue.erase(q)
	if quiet(): return
	for i in _events.size():
		_timers[i] = float(_timers[i]) - delta
		if _timers[i] > 0.0: continue
		var e: Dictionary = _events[i]
		_timers[i] = _rng.randf_range(e.every[0], e.every[1])
		if e.has("needs") and not World.flag(String(e.needs)): continue
		fire(e, kurt.global_position)

## Play one event now (tests and scripted moments can call this too).
func fire(e: Dictionary, near: Vector3) -> void:
	var pos := where(e, near)
	var pr: Array = e.get("pitch", [0.9, 1.1])
	var pitch := _rng.randf_range(pr[0], pr[1])
	var db := float(e.get("db", -18.0))
	var n := int(e.get("repeat", 1))
	for k in n:
		_queue.append([float(e.get("gap", 0.4)) * k, String(e.sound), pos, db, pitch])
	World.emit_event("ambience", {"sound": e.sound, "at": pos})

func where(e: Dictionary, near: Vector3) -> Vector3:
	if e.has("at"):
		var a: Array = e.at
		var base := Vector3.ZERO
		var pl: Place = story.level.places.get(story.level.place_of(near))
		if pl: base = pl.at
		return base + Vector3(a[0], a[1], a[2])
	var dir := Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU)
	match String(e.get("where", "wall")):
		"above": return near + dir * _rng.randf_range(0.0, 3.0) + Vector3(0, 3.4, 0)
		"below": return near + dir * _rng.randf_range(0.0, 3.0) + Vector3(0, -3.0, 0)
		"far": return near + dir * _rng.randf_range(12.0, 20.0) + Vector3(0, _rng.randf_range(-6.0, 6.0), 0)
		"here": return near
	return near + dir * _rng.randf_range(3.0, 6.5) + Vector3(0, _rng.randf_range(0.3, 2.2), 0)

# --------------------------------------------------------------------------------------- tension
func _tension(delta: float, kurt: Node3D) -> void:
	var reach := float(data.get("tension", {}).get("reach", 14.0))
	var want := 0.0
	for m in get_tree().get_nodes_in_group("monsters"):
		if not (m is Monster) or not m.is_inside_tree(): continue
		if not (m.state in [Monster.S.HUNT, Monster.S.GRAB]): continue
		var d: float = m.global_position.distance_to(kurt.global_position)
		want = maxf(want, clampf(1.0 - d / reach, 0.0, 1.0) * 0.8 + 0.2)
	tension = move_toward(tension, want, delta * (1.5 if want > tension else 0.25))
	var t: Dictionary = data.get("tension", {})
	var pdb: Array = t.get("pressure_db", [-40, -14])
	_pressure.volume_db = -80.0 if tension < 0.02 else lerpf(pdb[0], pdb[1], tension)
	if tension > 0.05:
		_hb_t -= delta
		if _hb_t <= 0.0:
			var hdb: Array = t.get("heartbeat_db", [-40, -6])
			Audio.play("heartbeat", null, lerpf(hdb[0], hdb[1], tension))
			_hb_t = lerpf(1.3, 0.45, tension)

# ------------------------------------------------------------------------------------------ dust
func _make_dust() -> void:
	_dust = CPUParticles3D.new(); _dust.name = "Dust"
	_dust.amount = 70; _dust.lifetime = 9.0; _dust.preprocess = 9.0
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(3.0, 1.4, 3.0)
	_dust.direction = Vector3(0, -1, 0); _dust.spread = 180.0
	_dust.gravity = Vector3(0, -0.006, 0)
	_dust.initial_velocity_min = 0.0; _dust.initial_velocity_max = 0.04
	_dust.local_coords = false
	_dust.scale_amount_min = 0.6; _dust.scale_amount_max = 1.4
	var q := QuadMesh.new(); q.size = Vector2(0.012, 0.012)
	var m := Mats.flat(Color(0.75, 0.72, 0.65), -1).duplicate() as ShaderMaterial
	m.set_shader_parameter("two_sided", true)
	q.material = m
	_dust.mesh = q
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dust)
	_dust.top_level = true
