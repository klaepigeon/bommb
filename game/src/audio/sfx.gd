extends Node
## Sound. Audio is a gameplay system here: every sound that carries can also be a noise (Events.noise)
## that Marta hears, and every sound the player hears tells them something (direction, distance,
## whether there's a wall between).
##
## - play(name)                 2D (UI, Kurt's own body)
## - play_at(name, pos, ...)    3D, pooled players, occlusion-muffled, optional noise radius
## - loop_at(name, pos)         a looping 3D emitter (radio static, fluorescent hum, alarm clock)
## - set_room(acoustics)        room-dependent reverb (the player's current room)
## - set_ambience(name)         the bed under everything (crossfaded)
## - set_tension(x)             dynamic music: silence at 0, the chase layer at 1
##
## Sounds are WAV assets made by tools/gen_audio.gd. "name" picks name.wav, or a random one of
## name_1.wav, name_2.wav ... when there are variants.

const POOL_3D := 20
const POOL_2D := 6

var _streams := {}            # name -> Array[AudioStream]
var _pool3: Array[AudioStreamPlayer3D] = []
var _pool2: Array[AudioStreamPlayer] = []
var _amb: Array[AudioStreamPlayer] = []
var _amb_i := 0
var _music: AudioStreamPlayer
var _heart: AudioStreamPlayer
var _tension := 0.0
var _tension_target := 0.0
var _whisper_t := 8.0
var _reverb: AudioEffectReverb
var _occ_t := 0.0
var listener_override: Node3D = null   ## tests / cutscenes
var _world: World3D
var _loops: Array = []
var _loop_i := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	_index_streams()
	for i in POOL_2D:
		var p := AudioStreamPlayer.new(); p.bus = "SFX"; add_child(p); _pool2.append(p)
	for i in 2:
		var a := AudioStreamPlayer.new(); a.bus = "Ambience"; a.volume_db = -80.0; add_child(a); _amb.append(a)
	_music = AudioStreamPlayer.new(); _music.bus = "Music"; _music.volume_db = -80.0; add_child(_music)
	_heart = AudioStreamPlayer.new(); _heart.bus = "SFX"; _heart.volume_db = -80.0; add_child(_heart)
	_apply_volumes()
	Settings.changed.connect(func(k): if k.begins_with("vol_"): _apply_volumes())

## the 3D pool lives in whatever world is current (main.gd calls this when a level loads)
func attach_world(parent: Node) -> void:
	for p in _pool3:
		if is_instance_valid(p): p.queue_free()
	_pool3.clear()
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 3.0
		p.max_distance = 40.0
		p.attenuation_filter_cutoff_hz = 9000.0
		p.attenuation_filter_db = -12.0
		parent.add_child(p)
		_pool3.append(p)
	_world = (parent as Node3D).get_world_3d() if parent is Node3D else null

func _make_buses() -> void:
	for n in ["SFX", "Music", "Ambience", "Muffled", "Room"]:
		if AudioServer.get_bus_index(n) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, n)
	# Room: the reverb every world sound sends into, retuned per room
	var room := AudioServer.get_bus_index("Room")
	_reverb = AudioEffectReverb.new()
	_reverb.room_size = 0.4; _reverb.damping = 0.6; _reverb.wet = 0.25; _reverb.dry = 0.0
	AudioServer.add_bus_effect(room, _reverb)
	AudioServer.set_bus_send(room, "Master")
	# SFX: dry to master; its reverb send is approximated by routing through Room's dry=0 copy
	AudioServer.set_bus_send(AudioServer.get_bus_index("SFX"), "Master")
	var muf := AudioServer.get_bus_index("Muffled")
	var lpf := AudioEffectLowPassFilter.new(); lpf.cutoff_hz = 700.0
	AudioServer.add_bus_effect(muf, lpf)
	AudioServer.set_bus_send(muf, "Room")
	AudioServer.set_bus_send(AudioServer.get_bus_index("Music"), "Master")
	AudioServer.set_bus_send(AudioServer.get_bus_index("Ambience"), "Master")

func _apply_volumes() -> void:
	var m := float(Settings.get_v("vol_master"))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(m, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(float(Settings.get_v("vol_sfx")), 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Muffled"), linear_to_db(maxf(float(Settings.get_v("vol_sfx")), 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(float(Settings.get_v("vol_music")), 0.0001)))

func _index_streams() -> void:
	var dir := DirAccess.open("res://audio")
	if not dir:
		return
	var files := {}
	for f in dir.get_files():
		var n := f
		if n.ends_with(".import"):
			n = n.trim_suffix(".import")    # exported builds only list the .import files
		if n.ends_with(".wav"):
			files[n] = true
	for f in files:
		var base: String = f.trim_suffix(".wav")
		var stream := load("res://audio/" + f) as AudioStream
		if not stream:
			continue
		var key := base
		var parts := base.rsplit("_", true, 1)
		if parts.size() == 2 and parts[1].is_valid_int():
			key = parts[0]
		if not _streams.has(key):
			_streams[key] = []
		_streams[key].append(stream)

func has(name: String) -> bool:
	return _streams.has(name)

func stream(name: String) -> AudioStream:
	var a: Array = _streams.get(name, [])
	return null if a.is_empty() else a[randi() % a.size()]

func play(name: String, db := 0.0, pitch := 1.0) -> void:
	var s := stream(name)
	if not s:
		return
	for p in _pool2:
		if not p.playing:
			p.stream = s; p.volume_db = db; p.pitch_scale = pitch; p.play()
			return

## A sound in the world. noise_radius > 0 also reports it to anything listening (Events.noise).
func play_at(name: String, pos: Vector3, db := 0.0, pitch := 1.0, noise_radius := 0.0, kind := "", source: Node = null) -> AudioStreamPlayer3D:
	if noise_radius > 0.0:
		Events.noise.emit(pos, noise_radius, kind if kind != "" else name, source)
	var s := stream(name)
	if not s or _pool3.is_empty():
		return null
	var best: AudioStreamPlayer3D = null
	for p in _pool3:
		if is_instance_valid(p) and not p.playing:
			best = p
			break
	if not best:
		best = _pool3[randi() % _pool3.size()]       # steal one
	best.stream = s
	best.global_position = pos
	best.volume_db = db
	best.pitch_scale = pitch * randf_range(0.96, 1.04)
	best.bus = "Muffled" if _occluded(pos) else "SFX"
	best.play()
	return best

## A persistent looping emitter; the caller owns it (queue_free to stop).
func loop_at(name: String, parent: Node3D, db := 0.0, unit := 2.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(name)
	p.volume_db = db
	p.unit_size = unit
	p.max_distance = 30.0
	p.bus = "SFX"
	p.autoplay = true
	parent.add_child(p)
	_loops.append(p)
	return p

func _listener_pos() -> Vector3:
	if listener_override:
		return listener_override.global_position
	var vp := get_viewport()
	if _world and _pool3.size() > 0 and is_instance_valid(_pool3[0]):
		vp = _pool3[0].get_viewport()
	var cam := vp.get_camera_3d() if vp else null
	return cam.global_position if cam else Vector3.ZERO

func _occluded(pos: Vector3) -> bool:
	if _pool3.is_empty() or not is_instance_valid(_pool3[0]) or not _pool3[0].is_inside_tree():
		return false
	var space := _pool3[0].get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(_listener_pos(), pos, 1)   # layer 1: architecture
	var hit := space.intersect_ray(q)
	return not hit.is_empty() and hit.position.distance_to(pos) > 0.3

## acoustics: {size 0..1, damp 0..1, wet 0..1}
func set_room(ac: Dictionary) -> void:
	if not _reverb:
		return
	_reverb.room_size = float(ac.get("size", 0.4))
	_reverb.damping = float(ac.get("damp", 0.6))
	_reverb.wet = float(ac.get("wet", 0.2))
	# SFX dry + a share into Room
	AudioServer.set_bus_send(AudioServer.get_bus_index("SFX"), "Room" if _reverb.wet > 0.05 else "Master")
	_reverb.dry = 1.0

func set_ambience(name: String, db := -14.0) -> void:
	var cur := _amb[_amb_i]
	if name != "" and cur.stream == stream(name) and cur.playing:
		return
	_amb_i = 1 - _amb_i
	var nxt := _amb[_amb_i]
	var tw := create_tween().set_parallel()
	tw.tween_property(cur, "volume_db", -80.0, 2.5)
	if name != "" and has(name):
		nxt.stream = stream(name); nxt.volume_db = -80.0; nxt.play()
		tw.tween_property(nxt, "volume_db", db, 3.0)

func set_tension(x: float) -> void:
	_tension_target = clampf(x, 0.0, 1.0)

func stinger() -> void:
	play("sting", -4.0)

func _process(delta: float) -> void:
	# dynamic music: nothing when calm; the chase layer and the heart come up with tension
	_tension = move_toward(_tension, _tension_target, delta * (0.8 if _tension_target > _tension else 0.15))
	if _tension > 0.02:
		if not _music.playing and has("chase"):
			_music.stream = stream("chase"); _music.play()
		_music.volume_db = linear_to_db(maxf(_tension, 0.0001)) - 6.0
	elif _music.playing:
		_music.stop()
	var hb := clampf((_tension - 0.4) / 0.6, 0.0, 1.0)
	if hb > 0.01:
		if not _heart.playing and has("heartbeat"):
			_heart.stream = stream("heartbeat"); _heart.play()
		_heart.volume_db = linear_to_db(hb) - 4.0
		_heart.pitch_scale = 1.0 + hb * 0.4
	elif _heart.playing:
		_heart.stop()
	# the infection: whispers from nowhere, more often the further it's got
	if Infection.stage >= 1 and not get_tree().paused:
		_whisper_t -= delta
		if _whisper_t <= 0.0:
			_whisper_t = randf_range(25.0, 50.0) / float(Infection.stage)
			var cam_pos := _listener_pos()
			var dir := Vector3(randf_range(-1, 1), 0.2, randf_range(-1, 1)).normalized()
			play_at("whisper", cam_pos + dir * 1.2, -10.0 + Infection.stage * 3.0, randf_range(0.8, 1.1))
	# loops behind walls get muffled (cheap: one emitter re-checked per frame, round robin)
	_occ_t += delta
	if _occ_t > 0.1 and not _loops.is_empty():
		_occ_t = 0.0
		_loop_i = (_loop_i + 1) % _loops.size()
		var lp = _loops[_loop_i]                  # untyped: it may already be freed
		if not is_instance_valid(lp):
			_loops.remove_at(_loop_i)
		elif (lp as AudioStreamPlayer3D).is_inside_tree():
			(lp as AudioStreamPlayer3D).bus = "Muffled" if _occluded((lp as AudioStreamPlayer3D).global_position) else "SFX"
