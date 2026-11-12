extends Node
## Sounds (autoload "Sfx"). There are no recorded assets yet, so every sound is synthesised once at
## startup into a small 16-bit buffer: knocks, the door, the body hitting the wall, the wardrobe's
## scrape, the goo, the pistol, footsteps on boards and on flesh, Marta's clicks, and the voices'
## syllables (Socko's squeaky felt voice, Kurt's low murmur). Replace any entry with a recording by
## putting an AudioStream under the same name in `streams`.

const RATE := 22050
var streams := {}
var _loops := {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1996
	streams.knock = _make(0.32, func(t): return _thump(t, 95.0, 22.0) * 0.9 + _noise() * exp(-t * 60.0) * 0.4)
	streams.door_rattle = _make(0.5, func(t): return (_noise() * 0.5 + sin(t * TAU * 180.0) * 0.3) * _bursts(t, 7.0, 40.0) * exp(-t * 3.0))
	streams.door_slam = _make(0.9, func(t): return _thump(t, 70.0, 9.0) + _noise() * exp(-t * 25.0) * 0.6 + sin(t * TAU * 310.0) * exp(-t * 14.0) * 0.2)
	streams.thud = _make(0.6, func(t): return _thump(t, 55.0, 12.0) * 1.1 + _noise() * exp(-t * 30.0) * 0.5)
	streams.scrape = _make(1.4, func(t): return _lp_noise(0.25) * (0.5 + 0.5 * sin(t * TAU * 6.0 + sin(t * 13.0))) * minf(1.0, t * 8.0) * minf(1.0, (1.4 - t) * 4.0) * 0.8)
	streams.squelch = _make(0.5, func(t): return _lp_noise(0.12) * sin(t * TAU * (90.0 + 120.0 * exp(-t * 6.0))) * exp(-t * 6.0) * 1.4)
	streams.goo_loop = _make(2.0, func(t): return _lp_noise(0.05) * (0.35 + 0.35 * sin(t * TAU * 1.5) * sin(t * TAU * 0.5)) + sin(t * TAU * 48.0) * 0.08, true)
	streams.gunshot = _make(0.9, func(t): return clampf((_noise() * exp(-t * 18.0) * 1.6 + _thump(t, 80.0, 10.0) * 0.9 + _lp_noise(0.1) * exp(-t * 3.5) * 0.4), -1.0, 1.0))
	streams.dry_fire = _make(0.08, func(t): return _noise() * exp(-t * 200.0) * 0.6)
	streams.reload = _make(0.55, func(t): return (_noise() * exp(-fposmod(t, 0.27) * 120.0)) * 0.6)
	streams.pickup = _make(0.18, func(t): return _noise() * exp(-t * 40.0) * 0.35 + sin(t * TAU * 600.0) * exp(-t * 50.0) * 0.1)
	streams.drawer = _make(0.6, func(t): return _lp_noise(0.4) * minf(1.0, t * 20.0) * exp(-t * 4.0) * 0.6 + _thump(maxf(0.0, t - 0.45), 120.0, 30.0) * 0.4 * float(t > 0.45))
	streams.step_wood = _make(0.16, func(t): return _thump(t, 110.0, 45.0) * 0.5 + _noise() * exp(-t * 90.0) * 0.18)
	streams.step_flesh = _make(0.3, func(t): return _lp_noise(0.15) * exp(-t * 14.0) * 0.8 + _thump(t, 60.0, 30.0) * 0.3)
	streams.click = _make(0.05, func(t): return (_noise() * 0.7 + sin(t * TAU * 2400.0) * 0.5) * exp(-t * 160.0))
	streams.heartbeat = _make(0.9, func(t): return _thump(t, 48.0, 18.0) * 0.8 + _thump(maxf(0.0, t - 0.28), 44.0, 20.0) * 0.5 * float(t > 0.28))
	streams.gasp = _make(0.6, func(t): return _lp_noise(0.5) * sin(PI * clampf(t / 0.6, 0.0, 1.0)) * (0.6 + 0.4 * sin(t * TAU * 3.0)) * 0.7)
	streams.drone = _make(4.0, func(t): return (sin(t * TAU * 41.0) * 0.25 + sin(t * TAU * 61.5) * 0.15 + _lp_noise(0.02) * 0.4) * (0.7 + 0.3 * sin(t * TAU * 0.25)), true)
	streams.flesh_drone = _make(4.0, func(t): return (sin(t * TAU * 33.0 + sin(t * TAU * 0.5) * 3.0) * 0.3 + _lp_noise(0.03) * 0.5) * (0.6 + 0.4 * sin(t * TAU * 0.75)), true)
	streams.crawl = _make(1.2, func(t): return _lp_noise(0.2) * (0.4 + 0.6 * absf(sin(t * TAU * 1.6))) * 0.8)
	streams.bullet_hit = _make(0.25, func(t): return _noise() * exp(-t * 35.0) * 0.6 + _thump(t, 160.0, 40.0) * 0.4)
	streams.bullet_flesh = _make(0.35, func(t): return _lp_noise(0.2) * exp(-t * 12.0) * 1.1)
	streams.marta_breath = _make(1.8, func(t): return _lp_noise(0.35) * pow(sin(PI * clampf(t / 1.8, 0.0, 1.0)), 2.0) * 0.6)
	# voice syllables: a few each, picked at random as the subtitles type
	for i in 4:
		var f0 := 300.0 + i * 37.0
		streams["v_socko%d" % i] = _make(0.09, func(t): return _voice(t, f0 * (1.0 + 0.3 * t), 0.09, 0.55, 0.35))
		var k0 := 105.0 + i * 9.0
		streams["v_kurt%d" % i] = _make(0.12, func(t): return _voice(t, k0, 0.12, 0.25, 0.6))
		var m0 := 180.0 + i * 13.0
		streams["v_marta%d" % i] = _make(0.16, func(t): return _voice(t, m0 * (1.0 - 0.15 * t), 0.16, 0.15, 0.85))

# ------------------------------------------------------------------ playing
## A sound with no position (UI, the player's own body, voices).
func play(name: String, vol_db := 0.0, pitch := 1.0) -> AudioStreamPlayer:
	if not streams.has(name): return null
	var p := AudioStreamPlayer.new()
	p.stream = streams[name]; p.volume_db = vol_db; p.pitch_scale = pitch
	add_child(p); p.play()
	p.finished.connect(p.queue_free)
	return p

## A sound somewhere in the world.
func play_at(name: String, pos: Vector3, vol_db := 0.0, pitch := 1.0, range_m := 18.0) -> void:
	var scene := get_tree().current_scene
	if not streams.has(name) or not scene: return
	var p := AudioStreamPlayer3D.new()
	p.stream = streams[name]; p.volume_db = vol_db; p.pitch_scale = pitch
	p.max_distance = range_m; p.unit_size = 3.0
	scene.add_child(p); p.global_position = pos; p.play()
	p.finished.connect(p.queue_free)

## A looping sound, at a place (pos) or everywhere (pos null). One per key.
func loop(key: String, name: String, vol_db := 0.0, pos = null, parent: Node = null) -> void:
	stop_loop(key)
	var p: Node
	if pos == null:
		var a := AudioStreamPlayer.new(); a.stream = streams[name]; a.volume_db = vol_db; p = a
		add_child(a); a.play()
	else:
		var a := AudioStreamPlayer3D.new(); a.stream = streams[name]; a.volume_db = vol_db; a.unit_size = 2.5; a.max_distance = 14.0
		(parent if parent else get_tree().current_scene).add_child(a); a.global_position = pos; a.play(); p = a
	_loops[key] = p

func stop_loop(key: String) -> void:
	if _loops.has(key) and is_instance_valid(_loops[key]): _loops[key].queue_free()
	_loops.erase(key)

func stop_loops() -> void:
	for k in _loops.keys(): stop_loop(k)

## A syllable of someone's voice (Dialogue calls this as the line types).
func syllable(who: String) -> void:
	var key := "v_%s%d" % [who, _rng.randi_range(0, 3)]
	if streams.has(key):
		play(key, -8.0 if who != "socko" else -6.0, _rng.randf_range(0.9, 1.12))

# ------------------------------------------------------------------ synthesis
func _make(secs: float, f: Callable, looped := false) -> AudioStreamWAV:
	var n := int(secs * RATE)
	var data := PackedByteArray(); data.resize(n * 2)
	_lp = 0.0
	for i in n:
		var t := float(i) / RATE
		var v: float = clampf(f.call(t), -1.0, 1.0)
		if looped:   # crossfade the ends so it loops without a click
			v *= minf(1.0, minf(t, secs - t) / 0.05)
		data.encode_s16(i * 2, int(v * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS; s.mix_rate = RATE; s.stereo = false; s.data = data
	if looped:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD; s.loop_begin = 0; s.loop_end = n
	return s

func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)

var _lp := 0.0
func _lp_noise(k: float) -> float:
	_lp += (_noise() - _lp) * k
	return _lp * (1.0 / sqrt(k)) * 0.5

func _thump(t: float, f: float, decay: float) -> float:
	return sin(TAU * f * t * (1.0 - 0.4 * minf(1.0, t * 4.0))) * exp(-t * decay)

func _bursts(t: float, rate: float, sharp: float) -> float:
	return exp(-fposmod(t, 1.0 / rate) * sharp)

## A voiced syllable: a buzzy pulse at f0 through a crude formant, with breath.
func _voice(t: float, f0: float, dur: float, buzz: float, breath: float) -> float:
	var env := sin(PI * clampf(t / dur, 0.0, 1.0))
	var ph := fposmod(t * f0, 1.0)
	var src := (1.0 - 2.0 * ph) * buzz + sin(TAU * ph) * (1.0 - buzz)
	return (src * 0.7 + _lp_noise(0.4) * breath * 0.5) * env * 0.8
