class_name Sfx
## Sounds synthesised at load, like the JS build's: there are no audio files in the project.
## Each returns a 16-bit mono AudioStreamWAV.

const RATE := 22050

static var _cache := {}

static func get_sound(name: String) -> AudioStreamWAV:
	if not _cache.has(name):
		var makers := {"crack": crack, "tear": tear, "heartbeat": heartbeat, "thud": thud}
		_cache[name] = (makers[name] as Callable).call()
	return _cache[name]

static func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray(); data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.stereo = false; w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_end = samples.size()
	return w

## Her neck: a run of dry cracks, like knuckles, then the crunch of coral breaking. Sudden, loud.
static func crack() -> AudioStreamWAV:
	var n := int(RATE * 0.55); var s := PackedFloat32Array(); s.resize(n)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var clicks := [0.0, 0.018, 0.031, 0.06, 0.072, 0.11, 0.135]
	for t0 in clicks:
		var i0 := int(t0 * RATE)
		var amp := rng.randf_range(0.6, 1.0)
		for k in 220:
			if i0 + k < n:
				s[i0 + k] += rng.randf_range(-1, 1) * amp * exp(-k / 28.0) + sin(k * 0.9) * amp * 0.5 * exp(-k / 40.0)
	var lp := 0.0
	for i in n:          # the coral: band-limited crunch under the clicks
		var t := float(i) / RATE
		var env := exp(-t * 9.0) * (0.6 + 0.4 * float(rng.randf() < 0.3))
		lp += (rng.randf_range(-1, 1) - lp) * 0.35
		s[i] += lp * env * 0.7
	return _wav(s)

## Flesh tearing off the table and coral snapping out of it: wet, irregular, a second and a half.
static func tear() -> AudioStreamWAV:
	var n := int(RATE * 1.6); var s := PackedFloat32Array(); s.resize(n)
	var rng := RandomNumberGenerator.new(); rng.seed = 9
	var lp := 0.0; var lp2 := 0.0; var gate := 0.0
	for i in n:
		var t := float(i) / RATE
		if rng.randf() < 0.004: gate = rng.randf_range(0.4, 1.0)
		gate *= 0.9993
		lp += (rng.randf_range(-1, 1) - lp) * 0.12
		lp2 += (lp - lp2) * 0.3
		var wet := lp2 * gate * 2.2 * (1.0 - t / 1.6)
		var crunch := rng.randf_range(-1, 1) * 0.5 * float(rng.randf() < 0.02) * exp(-t * 2.0)
		s[i] = wet + crunch
	return _wav(s)

## One heartbeat (lub-dub), looping, for the blackout.
static func heartbeat() -> AudioStreamWAV:
	var n := int(RATE * 1.1); var s := PackedFloat32Array(); s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for b in [[0.0, 1.0], [0.22, 0.7]]:
			var tt: float = t - b[0]
			if tt >= 0.0:
				v += sin(TAU * 48.0 * tt) * exp(-tt * 18.0) * b[1]
		s[i] = v * 0.9
	return _wav(s, true)

## A body hitting a floor.
static func thud() -> AudioStreamWAV:
	var n := int(RATE * 0.5); var s := PackedFloat32Array(); s.resize(n)
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1, 1) - lp) * 0.08
		s[i] = (sin(TAU * 60.0 * t) * 0.8 + lp * 2.0) * exp(-t * 11.0)
	return _wav(s)

## Plays a sound once, at a point in the world (or flat, if `at` is null), and frees the player.
static func play(parent: Node, name: String, at = null, volume_db := 0.0) -> void:
	var p: Node
	if at == null:
		var ap := AudioStreamPlayer.new(); ap.stream = get_sound(name); ap.volume_db = volume_db; p = ap
	else:
		var ap3 := AudioStreamPlayer3D.new(); ap3.stream = get_sound(name); ap3.volume_db = volume_db; ap3.unit_size = 3.0; p = ap3
	parent.add_child(p)
	if at != null:
		(p as Node3D).global_position = at
	p.call("play")
	p.connect("finished", p.queue_free)
