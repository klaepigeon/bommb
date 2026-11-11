extends Node
## Every sound in the game is synthesised here, the first time it's asked for (no audio files).
## play() places it in the world (muffled if there's a wall between it and the listener); loop()
## keeps one going on a node (water, hum, the TV, a radio).

const RATE := 22050
var streams := {}
var _pool: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1947
	for i in 20:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 4.0; p.max_distance = 40.0; p.attenuation_filter_cutoff_hz = 20500
		add_child(p); _pool.append(p)
	for i in 8:
		var p := AudioStreamPlayer.new(); add_child(p); _pool2d.append(p)

func stream(name: String) -> AudioStream:
	if not streams.has(name):
		streams[name] = _make(name)
	return streams[name]

func play(name: String, at = null, db := 0.0, pitch := 1.0) -> void:
	var s := stream(name)
	if s == null:
		return
	if at is Vector3:
		var p: AudioStreamPlayer3D = null
		for c in _pool:
			if not c.playing: p = c; break
		if p == null: p = _pool[0]
		p.stream = s; p.global_position = at; p.pitch_scale = pitch
		var muff := _blocked(at)
		p.volume_db = db - (7.0 if muff else 0.0)
		p.attenuation_filter_cutoff_hz = 1800.0 if muff else 20500.0
		p.play()
	else:
		var p: AudioStreamPlayer = null
		for c in _pool2d:
			if not c.playing: p = c; break
		if p == null: p = _pool2d[0]
		p.stream = s; p.volume_db = db; p.pitch_scale = pitch
		p.play()

func loop(name: String, on: Node3D, db := 0.0, unit := 3.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(name); p.volume_db = db; p.unit_size = unit; p.max_distance = 30.0
	p.autoplay = true
	on.add_child(p)
	return p

func _blocked(at: Vector3) -> bool:
	var cam: Camera3D = Lights.camera if is_instance_valid(Lights.camera) else get_viewport().get_camera_3d()
	if cam == null or not cam.is_inside_tree():
		return false
	var space := cam.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, at, 1)
	var hit := space.intersect_ray(q)
	return not hit.is_empty() and (hit.position as Vector3).distance_to(at) > 0.4

# ------------------------------------------------------------------------------------------ synth
func _wav(data: PackedFloat32Array, looped := false) -> AudioStreamWAV:
	var b := PackedByteArray(); b.resize(data.size() * 2)
	for i in data.size():
		b.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.stereo = false; w.data = b
	if looped:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_begin = 0; w.loop_end = data.size()
	return w

func _buf(sec: float) -> PackedFloat32Array:
	var a := PackedFloat32Array(); a.resize(int(sec * RATE)); return a

## Noise through a one-pole low-pass, shaped by an attack/decay envelope.
func _noise(sec: float, cutoff: float, attack: float, decay: float, gain := 1.0) -> PackedFloat32Array:
	var a := _buf(sec); var y := 0.0
	var k := clampf(cutoff / RATE * TAU, 0.0, 1.0)
	for i in a.size():
		var t := float(i) / RATE
		y += (_rng.randf_range(-1, 1) - y) * k
		var env := minf(t / maxf(attack, 1e-4), 1.0) * exp(-t / decay)
		a[i] = y * env * gain * (1.0 + 0.5 / maxf(k * 6.0, 0.2))
	return a

func _tone(sec: float, f0: float, f1: float, decay: float, gain := 0.6, harm := 0.0) -> PackedFloat32Array:
	var a := _buf(sec); var ph := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var f := lerpf(f0, f1, t / sec)
		ph += TAU * f / RATE
		a[i] = (sin(ph) + harm * sin(ph * 2.03) + harm * 0.5 * sin(ph * 3.1)) * exp(-t / decay) * gain
	return a

func _mix(a: PackedFloat32Array, b: PackedFloat32Array, at := 0.0, g := 1.0) -> PackedFloat32Array:
	var off := int(at * RATE)
	if a.size() < off + b.size():
		a.resize(off + b.size())
	for i in b.size():
		a[off + i] += b[i] * g
	return a

func _make(name: String) -> AudioStream:
	match name:
		"knock":
			var a := _mix(_noise(0.25, 900, 0.001, 0.03, 1.3), _tone(0.25, 140, 90, 0.05, 0.8))
			return _wav(a)
		"step_wood": return _wav(_mix(_noise(0.12, 1400, 0.002, 0.025, 0.7), _tone(0.12, 110, 80, 0.03, 0.4)))
		"step_tile": return _wav(_noise(0.1, 4200, 0.001, 0.018, 0.6))
		"step_soft": return _wav(_noise(0.12, 700, 0.004, 0.03, 0.5))
		"step_water":
			var a := _noise(0.3, 2500, 0.01, 0.09, 0.6)
			return _wav(_mix(a, _tone(0.2, 600, 300, 0.05, 0.15)))
		"step_heavy": return _wav(_mix(_noise(0.4, 300, 0.005, 0.12, 1.4), _tone(0.4, 60, 40, 0.15, 1.0)))
		"thud": return _wav(_mix(_noise(0.3, 600, 0.002, 0.06, 1.2), _tone(0.3, 90, 50, 0.08, 0.9)))
		"clink": return _wav(_mix(_tone(0.4, 2400, 2350, 0.08, 0.3, 0.4), _noise(0.05, 6000, 0.001, 0.01, 0.4)))
		"glass":
			var a := _noise(0.7, 7000, 0.001, 0.12, 0.9)
			for i in 6:
				a = _mix(a, _tone(0.3, _rng.randf_range(2500, 5200), _rng.randf_range(2400, 5000), 0.06, 0.18), _rng.randf() * 0.2)
			return _wav(a)
		"creak":
			var a := _buf(0.9); var ph := 0.0
			for i in a.size():
				var t := float(i) / RATE
				var f := 180.0 + 60.0 * sin(t * 7.0) + 30.0 * sin(t * 23.0)
				ph += TAU * f / RATE
				a[i] = (fmod(ph, TAU) / TAU - 0.5) * 0.35 * sin(PI * t / 0.9) * (0.6 + 0.4 * sin(t * 51.0))
			return _wav(a)
		"rattle":
			var a := _buf(0.5)
			for j in 5:
				a = _mix(a, _noise(0.08, 2200, 0.001, 0.015, 0.9), j * 0.08 + _rng.randf() * 0.02)
			return _wav(a)
		"latch": return _wav(_mix(_noise(0.15, 3000, 0.001, 0.02, 0.8), _tone(0.15, 900, 800, 0.03, 0.3)))
		"slam": return _wav(_mix(_noise(0.6, 900, 0.001, 0.12, 1.5), _tone(0.6, 70, 45, 0.2, 1.0)))
		"kick": return _wav(_mix(_mix(_noise(0.5, 1200, 0.001, 0.08, 1.5), _tone(0.5, 80, 50, 0.12, 1.0)), _noise(0.3, 4000, 0.001, 0.04, 0.6), 0.02))
		"splinter":
			var a := _noise(0.8, 3000, 0.001, 0.2, 1.2)
			for j in 8:
				a = _mix(a, _noise(0.05, 5000, 0.001, 0.01, 0.8), _rng.randf() * 0.5)
			return _wav(a)
		"scrape":
			var a := _buf(0.8); var y := 0.0
			for i in a.size():
				var t := float(i) / RATE
				y += (_rng.randf_range(-1, 1) - y) * 0.08
				a[i] = y * 3.0 * sin(PI * t / 0.8) * (0.7 + 0.3 * sin(t * 90.0))
			return _wav(a)
		"pickup": return _wav(_noise(0.12, 2000, 0.01, 0.03, 0.4))
		"splash": return _wav(_mix(_noise(0.8, 2400, 0.005, 0.2, 1.0), _noise(0.4, 600, 0.01, 0.1, 0.8)))
		"gurgle":
			var a := _buf(1.4)
			for j in 9:
				a = _mix(a, _tone(0.18, _rng.randf_range(180, 420), _rng.randf_range(500, 900), 0.05, 0.4), _rng.randf() * 1.2)
			return _wav(_mix(a, _noise(1.4, 500, 0.1, 0.6, 0.3)))
		"water_loop":
			var a := _buf(2.0); var y := 0.0
			for i in a.size():
				y += (_rng.randf_range(-1, 1) - y) * 0.25
				a[i] = y * 0.6
			return _wav(a, true)
		"hum":
			var a := _buf(1.0)
			for i in a.size():
				var t := float(i) / RATE
				a[i] = (sin(TAU * 50.0 * t) * 0.3 + sin(TAU * 100.0 * t) * 0.2 + sin(TAU * 150.0 * t) * 0.08) * 0.5
			return _wav(a, true)
		"static":
			var a := _buf(1.0)
			for i in a.size():
				a[i] = _rng.randf_range(-1, 1) * 0.25 * (0.8 + 0.2 * sin(float(i) / RATE * 13.0))
			return _wav(a, true)
		"radio":
			var a := _buf(3.0); var ph := 0.0
			for i in a.size():
				var t := float(i) / RATE
				ph += TAU * (330.0 + 30.0 * sin(t * 2.0)) / RATE
				a[i] = _rng.randf_range(-1, 1) * 0.12 + sin(ph) * 0.15 * (0.5 + 0.5 * sin(t * 3.3)) * (1.0 if fmod(t, 1.5) < 1.1 else 0.0)
			return _wav(a, true)
		"zap":
			var a := _buf(0.6)
			for i in a.size():
				var t := float(i) / RATE
				a[i] = (_rng.randf_range(-1, 1) * 0.6 + sign(sin(TAU * 120.0 * t)) * 0.4) * exp(-t / 0.2) * (1.0 if _rng.randf() > 0.2 else 0.0)
			return _wav(a)
		"breaker": return _wav(_mix(_noise(0.25, 2500, 0.001, 0.02, 1.2), _tone(0.25, 300, 200, 0.03, 0.4)))
		"buzz":
			var a := _buf(1.0)
			for i in a.size():
				var t := float(i) / RATE
				a[i] = sign(sin(TAU * 100.0 * t)) * 0.12 + _rng.randf_range(-1, 1) * 0.05
			return _wav(a, true)
		"gunshot":
			var a := _mix(_noise(1.2, 5000, 0.0005, 0.08, 1.8), _noise(1.2, 400, 0.002, 0.35, 1.2))
			return _wav(_mix(a, _tone(0.3, 120, 40, 0.06, 1.0)))
		"dryfire": return _wav(_noise(0.08, 5000, 0.0005, 0.01, 0.7))
		"reload": return _wav(_mix(_noise(0.2, 3500, 0.001, 0.02, 0.7), _tone(0.2, 1200, 1100, 0.02, 0.2), 0.05))
		"chain":
			var a := _buf(0.9)
			for j in 10:
				a = _mix(a, _tone(0.12, _rng.randf_range(1800, 3200), _rng.randf_range(1700, 3100), 0.03, 0.25, 0.3), _rng.randf() * 0.7)
			return _wav(a)
		"axe": return _wav(_mix(_mix(_noise(0.5, 2000, 0.001, 0.06, 1.6), _tone(0.5, 160, 90, 0.08, 0.7)), _noise(0.4, 4500, 0.002, 0.08, 0.5), 0.03))
		"heartbeat":
			var a := _mix(_tone(0.25, 55, 40, 0.06, 1.0), _tone(0.25, 50, 38, 0.05, 0.7), 0.22)
			a.resize(int(RATE * 0.9))
			return _wav(a)
		"breath":
			var a := _buf(2.2)
			a = _mix(a, _noise(0.9, 900, 0.3, 0.35, 0.35), 0.0)
			a = _mix(a, _noise(1.0, 600, 0.3, 0.4, 0.25), 1.1)
			return _wav(a)
		"pop": return _wav(_mix(_tone(0.15, 300, 900, 0.03, 0.5), _noise(0.06, 2000, 0.001, 0.01, 0.3)))
		"blip": return _wav(_tone(0.09, 520, 560, 0.04, 0.45, 0.35))
		"snarl":
			var a := _buf(1.2); var ph := 0.0; var y := 0.0
			for i in a.size():
				var t := float(i) / RATE
				ph += TAU * (70.0 + 25.0 * sin(t * 11.0) + 15.0 * sin(t * 37.0)) / RATE
				y += (_rng.randf_range(-1, 1) - y) * 0.15
				a[i] = (sign(sin(ph)) * 0.25 + y * 1.4) * sin(PI * t / 1.2) * (0.6 + 0.4 * sin(t * 23.0))
			return _wav(a)
		"hiss": return _wav(_noise(1.0, 5000, 0.08, 0.4, 0.5))
		"coral": return _wav(_mix(_noise(0.5, 3500, 0.001, 0.05, 1.0), _noise(0.4, 1200, 0.01, 0.1, 0.6), 0.1))
		"drone":
			var a := _buf(8.0)
			for i in a.size():
				var t := float(i) / RATE
				a[i] = (sin(TAU * 41.0 * t) * 0.25 + sin(TAU * 61.5 * t + sin(t * 0.785) * 2.0) * 0.12 + sin(TAU * 82.0 * t) * 0.05) * (0.8 + 0.2 * sin(t * TAU / 8.0))
			return _wav(a, true)
		"pipes":
			var a := _buf(1.5)
			for j in 3:
				a = _mix(a, _mix(_noise(0.3, 700, 0.001, 0.05, 1.0), _tone(0.4, 220, 200, 0.15, 0.4, 0.5)), j * 0.35)
			return _wav(a)
		"pressure":
			var a := _buf(3.0)
			for i in a.size():
				var t := float(i) / RATE
				a[i] = sin(TAU * 34.0 * t) * 0.6 * (0.7 + 0.3 * sin(t * TAU / 3.0))
			return _wav(a, true)
		"rumble": return _wav(_mix(_noise(1.6, 200, 0.2, 0.5, 1.4), _tone(1.6, 45, 30, 0.6, 0.6)))
		"gasp": return _wav(_noise(0.5, 2600, 0.03, 0.15, 0.7))
		"hit": return _wav(_mix(_noise(0.3, 800, 0.001, 0.05, 1.4), _tone(0.3, 110, 60, 0.07, 0.8)))
		"drip":
			var a := _tone(0.25, 1400, 700, 0.04, 0.35)
			return _wav(_mix(a, _tone(0.3, 900, 500, 0.08, 0.12), 0.06))
		"engaged":
			# a telephone off the hook: the engaged tone, 425 Hz, on and off
			var a := _buf(1.0)
			for i in a.size():
				var t := float(i) / RATE
				a[i] = sin(TAU * 425.0 * t) * 0.18 * (1.0 if fmod(t, 1.0) < 0.5 else 0.0)
			return _wav(a, true)
		"furnace":
			# a boiler going: a low roar with the fire breathing in it
			var a := _buf(4.0); var y := 0.0; var y2 := 0.0
			for i in a.size():
				var t := float(i) / RATE
				y += (randf() * 2.0 - 1.0 - y) * 0.03
				y2 += (y - y2) * 0.05
				a[i] = y2 * 2.2 * (0.8 + 0.2 * sin(TAU * t * 0.75)) + sin(TAU * 38.0 * t) * 0.05
			return _wav(a, true)
		"ring":
			# an old bell telephone: two bursts of a hammered bell
			var a := _buf(2.2)
			for i in a.size():
				var t := float(i) / RATE
				var on := 1.0 if (t < 0.4 or (t > 0.6 and t < 1.0)) else 0.0
				var hammer: float = 0.5 + 0.5 * signf(sin(TAU * 20.0 * t))
				a[i] = (sin(TAU * 1100.0 * t) * 0.5 + sin(TAU * 1340.0 * t) * 0.3) * 0.35 * on * hammer
			return _wav(a)
		"wind":
			var a := _buf(6.0); var y := 0.0; var y2 := 0.0
			for i in a.size():
				var t := float(i) / RATE
				y += (_rng.randf_range(-1, 1) - y) * 0.02
				y2 += (y - y2) * 0.05
				a[i] = y2 * 6.0 * (0.6 + 0.4 * sin(t * TAU / 6.0) * sin(t * 0.7))
			return _wav(a, true)
		"steps_above":
			var a := _buf(3.2)
			for j in 6:
				a = _mix(a, _mix(_noise(0.25, 250, 0.004, 0.06, 1.0), _tone(0.25, 60, 45, 0.07, 0.7)), j * 0.52 + _rng.randf() * 0.05)
			return _wav(a)
		"door_far":
			var a := _mix(_noise(1.2, 300, 0.003, 0.25, 1.2), _tone(1.2, 55, 40, 0.3, 0.8))
			return _wav(_mix(a, _noise(0.4, 1500, 0.001, 0.05, 0.3), 0.02))
		"floor_creak":
			var a := _buf(0.7); var ph := 0.0
			for i in a.size():
				var t := float(i) / RATE
				ph += TAU * (90.0 + 40.0 * sin(t * 5.0)) / RATE
				a[i] = (fmod(ph, TAU) / TAU - 0.5) * 0.3 * sin(PI * t / 0.7)
			return _wav(a)
		"whisper":
			var a := _buf(2.0); var y := 0.0
			for i in a.size():
				var t := float(i) / RATE
				y += (_rng.randf_range(-1, 1) - y) * (0.35 + 0.3 * sin(t * 23.0))
				a[i] = y * 0.4 * sin(PI * t / 2.0) * (0.5 + 0.5 * sin(t * 9.0 + sin(t * 3.0) * 3.0))
			return _wav(a)
		"hum_low":
			var a := _buf(4.0)
			for i in a.size():
				var t := float(i) / RATE
				a[i] = (sin(TAU * 31.0 * t) * 0.2 + sin(TAU * 62.3 * t) * 0.07) * (0.85 + 0.15 * sin(t * TAU / 4.0))
			return _wav(a, true)
		"fluoro_buzz":
			var a := _buf(1.0)
			for i in a.size():
				var t := float(i) / RATE
				a[i] = (sin(TAU * 100.0 * t) * 0.06 + sin(TAU * 200.0 * t) * 0.03 + _rng.randf_range(-1, 1) * 0.01)
			return _wav(a, true)
		"child_count":
			var a := _buf(3.0)
			for j in 5:
				a = _mix(a, _tone(0.22, 520 + j * 15, 480 + j * 15, 0.08, 0.12, 0.6), j * 0.55)
			return _wav(a)
	push_warning("Audio: no sound named " + name)
	return null
