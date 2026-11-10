extends Node
## Every sound in the game, synthesised once at start-up into AudioStreamWAVs (no audio files,
## nothing to fail to import on a phone). 2D and positional playback, loops, and a "World" bus
## that can be muffled (the blackout).

const RATE := 22050

var streams := {}
var world: Node3D            ## where positional sounds are parented (set by the scene)
var _rng := RandomNumberGenerator.new()
var _lowpass: AudioEffectLowPassFilter
var _world_bus := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 47
	AudioServer.add_bus()
	_world_bus = AudioServer.bus_count - 1
	AudioServer.set_bus_name(_world_bus, "World")
	AudioServer.set_bus_send(_world_bus, "Master")
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(_world_bus, _lowpass)
	var t := Time.get_ticks_msec()
	streams["knock"] = _wav(_knock())
	streams["creak"] = _wav(_creak(2.4))
	streams["slam"] = _wav(_slam())
	streams["rattle"] = _wav(_rattle())
	streams["thud"] = _wav(_thud())
	streams["gasp"] = _wav(_gasp())
	streams["step"] = _wav(_step())
	streams["tinnitus"] = _wav(_tinnitus())
	streams["sting"] = _wav(_sting())
	streams["pop"] = _wav(_pop())
	streams["shot"] = _wav(_shot())
	streams["click"] = _wav(_click())
	streams["load"] = _wav(_load())
	streams["clatter"] = _wav(_clatter())
	streams["whoosh"] = _wav(_whoosh())
	streams["scrape"] = _wav(_scrape())
	streams["pressure"] = _wav(_pressure(), true)
	streams["wind"] = _wav(_wind(), true)
	streams["room"] = _wav(_room(), true)
	streams["breath"] = _wav(_breath(), true)
	print("[sfx] synthesised %d sounds in %d ms" % [streams.size(), Time.get_ticks_msec() - t])

## How muffled the world is: 0 = clear, 1 = through a pillow.
func set_muffle(amount: float) -> void:
	_lowpass.cutoff_hz = lerpf(20000.0, 350.0, clampf(amount, 0.0, 1.0))

func play(name: String, db := 0.0, pitch := 1.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = streams[name]
	p.volume_db = db
	p.pitch_scale = pitch
	p.bus = "World"
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p

func play_at(name: String, pos: Vector3, db := 0.0, pitch := 1.0) -> AudioStreamPlayer3D:
	var p := loop_at(name, pos, db, pitch)
	p.finished.connect(p.queue_free)
	return p

## A positional player that keeps going (for looped streams) until freed.
func loop_at(name: String, pos: Vector3, db := 0.0, pitch := 1.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = streams[name]
	p.volume_db = db
	p.pitch_scale = pitch
	p.unit_size = 4.0
	p.max_distance = 25.0
	p.bus = "World"
	var parent: Node = world if is_instance_valid(world) else self
	parent.add_child(p)
	if parent is Node3D:
		p.global_position = pos
	p.play()
	return p

# --- synthesis ---------------------------------------------------------------------------------

func _wav(data: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = data.size()
	return w

func _buf(seconds: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(seconds * RATE))
	return a

func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)

## Adds a struck wooden/metal body: decaying partials plus a filtered noise transient.
func _strike(a: PackedFloat32Array, at: float, amp: float, partials: Array, decay: float, click := 0.6, click_lp := 0.25) -> void:
	var start := int(at * RATE)
	var n := int(decay * 6.0 * RATE)
	var lp := 0.0
	for i in n:
		var j := start + i
		if j >= a.size():
			break
		var t := float(i) / RATE
		var env := exp(-t / decay)
		var s := 0.0
		for k in partials.size():
			var f: float = partials[k]
			s += sin(TAU * f * t) / (1.0 + k * 0.8)
		lp += click_lp * (_noise() - lp)
		var transient := lp * click * exp(-t / 0.012)
		a[j] += amp * (s * env * 0.5 + transient)

func _knock() -> PackedFloat32Array:
	var a := _buf(0.45)
	_strike(a, 0.0, 0.9, [96.0, 171.0, 262.0, 410.0], 0.045, 1.0, 0.18)
	return a

func _creak(seconds: float) -> PackedFloat32Array:
	# Stick-slip: an irregular train of impulses through two resonances, the rate wandering.
	var a := _buf(seconds)
	var y1 := 0.0; var y2 := 0.0; var z1 := 0.0; var z2 := 0.0
	var w1 := TAU * 620.0 / RATE; var w2 := TAU * 1340.0 / RATE
	var r := 0.995
	var phase := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var rate := 38.0 + 30.0 * sin(t * 2.1) + 18.0 * sin(t * 5.3 + 1.0)
		phase += rate / RATE
		var x := 0.0
		if phase >= 1.0:
			phase -= 1.0
			x = _rng.randf_range(0.5, 1.0)
		var y := x + 2.0 * r * cos(w1) * y1 - r * r * y2
		y2 = y1; y1 = y
		var z := x + 2.0 * r * cos(w2) * z1 - r * r * z2
		z2 = z1; z1 = z
		var env := smoothstep(0.0, 0.15, t) * smoothstep(seconds, seconds - 0.4, t)
		a[i] = (y * 0.012 + z * 0.006) * env
	return a

func _slam() -> PackedFloat32Array:
	var a := _buf(1.4)
	_strike(a, 0.0, 1.0, [55.0, 83.0, 140.0, 233.0], 0.12, 1.0, 0.12)
	_strike(a, 0.09, 0.25, [1900.0, 2650.0], 0.03, 0.2, 0.6)   # the latch
	_strike(a, 0.16, 0.15, [2100.0, 3100.0], 0.02, 0.1, 0.6)
	return a

func _rattle() -> PackedFloat32Array:
	var a := _buf(1.3)
	var times := [0.0, 0.17, 0.33, 0.52, 0.71]
	for k in times.size():
		var t: float = times[k]
		_strike(a, t, 0.35, [2300.0 + k * 90.0, 3400.0], 0.018, 0.4, 0.7)   # handle
		_strike(a, t + 0.02, 0.55, [70.0, 118.0, 190.0], 0.05, 0.8, 0.15)    # door against the frame
	return a

func _thud() -> PackedFloat32Array:
	var a := _buf(1.0)
	_strike(a, 0.0, 1.0, [48.0, 72.0, 115.0], 0.14, 1.2, 0.06)
	_strike(a, 0.11, 0.4, [60.0, 95.0], 0.08, 0.8, 0.08)
	return a

func _gasp() -> PackedFloat32Array:
	var a := _buf(0.8)
	var y1 := 0.0; var y2 := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var f := 900.0 + 900.0 * smoothstep(0.0, 0.35, t)
		var w := TAU * f / RATE
		var r := 0.97
		var y := _noise() + 2.0 * r * cos(w) * y1 - r * r * y2
		y2 = y1; y1 = y
		var env := smoothstep(0.0, 0.05, t) * exp(-maxf(t - 0.12, 0.0) / 0.16)
		a[i] = y * 0.06 * env
	return a

func _step() -> PackedFloat32Array:
	var a := _buf(0.2)
	_strike(a, 0.0, 0.5, [120.0, 210.0], 0.025, 1.0, 0.3)
	return a

func _tinnitus() -> PackedFloat32Array:
	var a := _buf(6.0)
	for i in a.size():
		var t := float(i) / RATE
		a[i] = sin(TAU * 3900.0 * t) * 0.05 * smoothstep(0.0, 0.3, t) * smoothstep(6.0, 1.5, t)
	return a

func _sting() -> PackedFloat32Array:
	var a := _buf(2.6)
	var freqs := [41.0, 43.5, 61.7, 87.0, 92.5]
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var s := 0.0
		for f in freqs:
			s += sin(TAU * f * t + sin(t * 3.0) * 0.5)
		lp += 0.08 * (_noise() - lp)
		var env := exp(-t / 0.9)
		a[i] = (s * 0.14 + lp * 0.6 * exp(-t / 0.25)) * env
	return a

func _pop() -> PackedFloat32Array:
	var a := _buf(0.3)
	var ph := 0.0
	for i in a.size():
		var t := float(i) / RATE
		ph += TAU * lerpf(320.0, 110.0, minf(t / 0.12, 1.0)) / RATE
		a[i] = sin(ph) * 0.35 * exp(-t / 0.06) + _noise() * 0.05 * exp(-t / 0.03)
	return a

func _room() -> PackedFloat32Array:
	# Four seconds that loop cleanly: brown-ish noise, a faint 50 Hz mains hum and its harmonic.
	var a := _buf(4.0)
	var b := 0.0
	for i in a.size():
		var t := float(i) / RATE
		b = (b + 0.02 * _noise()) * 0.995
		a[i] = b * 0.5 + sin(TAU * 50.0 * t) * 0.012 + sin(TAU * 100.0 * t) * 0.006
	# cross-fade the tail into the head so the loop has no click
	var fade := int(0.2 * RATE)
	for i in fade:
		var k := float(i) / fade
		a[i] = a[i] * k + a[a.size() - fade + i] * (1.0 - k)
	a.resize(a.size() - fade)
	return a

func _breath() -> PackedFloat32Array:
	# Slow, wet, laboured: in through a narrow throat, a catch, out with a crackle.
	var a := _buf(4.2)
	var y1 := 0.0; var y2 := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var inhale := smoothstep(0.0, 0.5, t) * smoothstep(1.6, 1.1, t)
		var exhale := smoothstep(1.9, 2.2, t) * smoothstep(3.9, 2.8, t)
		var f := 700.0 if t < 1.7 else 420.0
		var w := TAU * f / RATE
		var r := 0.96
		var y := _noise() + 2.0 * r * cos(w) * y1 - r * r * y2
		y2 = y1; y1 = y
		var crackle := 0.0
		if exhale > 0.1 and _rng.randf() < 0.004:
			crackle = _rng.randf_range(-1.0, 1.0)
		a[i] = y * 0.02 * (inhale * 0.8 + exhale) + crackle * 0.3 * exhale
	return a

func _shot() -> PackedFloat32Array:
	# A black-powder-era crack and a long slap back off the houses.
	var a := _buf(1.6)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += 0.35 * (_noise() - lp)
		var crack := _noise() * exp(-t / 0.008)
		var body := lp * exp(-t / 0.09)
		var boom := sin(TAU * 52.0 * t) * exp(-t / 0.18)
		var echo := lp * 0.35 * exp(-maxf(t - 0.22, 0.0) / 0.35) * smoothstep(0.2, 0.26, t)
		a[i] = (crack * 0.9 + body * 1.4 + boom * 0.6 + echo) * 0.8
	return a

func _click() -> PackedFloat32Array:
	var a := _buf(0.12)
	_strike(a, 0.0, 0.6, [2600.0, 4100.0], 0.006, 0.6, 0.8)
	return a

func _load() -> PackedFloat32Array:
	var a := _buf(0.25)
	_strike(a, 0.0, 0.4, [1800.0, 3000.0], 0.01, 0.4, 0.7)
	_strike(a, 0.06, 0.3, [900.0, 1500.0], 0.015, 0.3, 0.5)
	return a

func _clatter() -> PackedFloat32Array:
	var a := _buf(0.9)
	var t := 0.0
	for k in 5:
		_strike(a, t, 0.7 / (k + 1), [180.0 + k * 40.0, 420.0, 900.0], 0.03, 1.0, 0.4)
		t += 0.07 + 0.09 * k
	return a

func _whoosh() -> PackedFloat32Array:
	var a := _buf(0.3)
	var lp := 0.0
	for i in a.size():
		var tt := float(i) / RATE
		lp += 0.15 * (_noise() - lp)
		a[i] = lp * sin(PI * tt / 0.3) * 0.8
	return a

func _scrape() -> PackedFloat32Array:
	# A heavy wardrobe dragged a hand's breadth over parquet.
	var a := _buf(0.9)
	var lp := 0.0
	var y1 := 0.0; var y2 := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += 0.2 * (_noise() - lp)
		var w := TAU * (140.0 + 30.0 * sin(t * 37.0)) / RATE
		var y := lp + 2.0 * 0.98 * cos(w) * y1 - 0.98 * 0.98 * y2
		y2 = y1; y1 = y
		a[i] = y * 0.02 * smoothstep(0.0, 0.1, t) * smoothstep(0.9, 0.6, t)
	return a

func _pressure() -> PackedFloat32Array:
	# Like the ears before a storm: two close low tones beating. Loops on whole cycles.
	var a := _buf(2.0)
	for i in a.size():
		var t := float(i) / RATE
		a[i] = (sin(TAU * 38.0 * t) + sin(TAU * 39.5 * t)) * 0.18
	return a

func _wind() -> PackedFloat32Array:
	var a := _buf(5.0)
	var lp := 0.0
	var lp2 := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += 0.03 * (_noise() - lp)
		lp2 += 0.3 * (lp - lp2)
		a[i] = lp2 * (0.6 + 0.4 * sin(TAU * t / 5.0)) * 1.2
	var fade := int(0.3 * RATE)
	for i in fade:
		var k := float(i) / fade
		a[i] = a[i] * k + a[a.size() - fade + i] * (1.0 - k)
	a.resize(a.size() - fade)
	return a
