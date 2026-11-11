extends SceneTree
## Generates the game's sound library as WAV assets (res://audio/*.wav). Run once after changing
## a recipe:   godot --headless --path game -s tools/gen_audio.gd
## Every sound is synthesised from noise, oscillators, filters and envelopes: PS1-era lo-fi, 22 kHz.

const SR := 22050
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.seed = 4747
	DirAccess.make_dir_recursive_absolute("res://audio")
	var made := 0
	for m in get_method_list():
		var n: String = m.name
		if n.begins_with("s_"):
			var res = call(n)
			var name := n.substr(2)
			if res is Array:            # variants
				for i in res.size():
					_save(name + "_" + str(i + 1), res[i]); made += 1
			else:
				_save(name, res); made += 1
	print("gen_audio: ", made, " sounds")
	quit()

func _save(name: String, d: Dictionary) -> void:
	var data: PackedFloat32Array = d.data
	var loop: bool = d.get("loop", false)
	var peak := 0.0001
	for v in data: peak = maxf(peak, absf(v))
	var gain := float(d.get("gain", 0.9)) / peak
	var bytes := PackedByteArray(); bytes.resize(data.size() * 2)
	for i in data.size():
		var s := int(clampf(data[i] * gain, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = data.size()
	w.save_to_wav("res://audio/%s.wav" % name)

# ---------------------------------------------------------------- primitives

func buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array(); b.resize(int(sec * SR)); return b

func white() -> float: return rng.randf() * 2.0 - 1.0

## one-pole lowpass in place
func lp(b: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * cutoff / SR)
	var y := 0.0
	for i in b.size():
		y += a * (b[i] - y); b[i] = y
	return b

func hp(b: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * cutoff / SR)
	var y := 0.0
	for i in b.size():
		y += a * (b[i] - y); b[i] = b[i] - y
	return b

## resonant bandpass (biquad, constant peak gain), centre may sweep: f(t) callable or float
func bp(b: PackedFloat32Array, f, q: float) -> PackedFloat32Array:
	var x1 := 0.0; var x2 := 0.0; var y1 := 0.0; var y2 := 0.0
	for i in b.size():
		var fc: float = f.call(float(i) / SR) if f is Callable else f
		var w0 := TAU * clampf(fc, 20.0, SR * 0.45) / SR
		var al := sin(w0) / (2.0 * q)
		var a0 := 1.0 + al
		var y := (al * b[i] - al * x2 + 2.0 * cos(w0) * y1 - (1.0 - al) * y2) / a0
		x2 = x1; x1 = b[i]; y2 = y1; y1 = y
		b[i] = y
	return b

func noise(sec: float) -> PackedFloat32Array:
	var b := buf(sec)
	for i in b.size(): b[i] = white()
	return b

func env_exp(b: PackedFloat32Array, decay: float, attack := 0.002, delay := 0.0) -> PackedFloat32Array:
	for i in b.size():
		var t := float(i) / SR - delay
		var e := 0.0 if t < 0.0 else minf(1.0, t / attack) * exp(-t / decay)
		b[i] *= e
	return b

func mix(a: PackedFloat32Array, b: PackedFloat32Array, gb := 1.0, offset := 0.0) -> PackedFloat32Array:
	var o := int(offset * SR)
	if a.size() < b.size() + o: a.resize(b.size() + o)
	for i in b.size(): a[i + o] += b[i] * gb
	return a

func sine(sec: float, f, amp := 1.0) -> PackedFloat32Array:
	var b := buf(sec); var ph := 0.0
	for i in b.size():
		var fc: float = f.call(float(i) / SR) if f is Callable else f
		ph += TAU * fc / SR; b[i] = sin(ph) * amp
	return b

func saw(sec: float, f) -> PackedFloat32Array:
	var b := buf(sec); var ph := 0.0
	for i in b.size():
		var fc: float = f.call(float(i) / SR) if f is Callable else f
		ph = fmod(ph + fc / SR, 1.0); b[i] = ph * 2.0 - 1.0
	return b

func gain(b: PackedFloat32Array, g: float) -> PackedFloat32Array:
	for i in b.size(): b[i] *= g
	return b

## crude room: a few feedback delays
func verb(b: PackedFloat32Array, tail: float, wet := 0.35) -> PackedFloat32Array:
	var out := b.duplicate(); out.resize(b.size() + int(tail * SR))
	var taps := [0.031, 0.047, 0.061, 0.083]
	for t in taps:
		var d := int(t * SR); var fb := pow(0.001, t / tail)
		var line := PackedFloat32Array(); line.resize(out.size())
		for i in out.size():
			var x := (b[i] if i < b.size() else 0.0)
			var y := x + (line[i - d] * fb if i >= d else 0.0)
			line[i] = y
			out[i] += y * wet * 0.25
	return lp(out, 5000.0)

func fade_loop(b: PackedFloat32Array, sec := 0.05) -> PackedFloat32Array:
	# crossfade the end into the start so the loop is seamless
	var n := int(sec * SR)
	for i in n:
		var k := float(i) / n
		b[i] = b[i] * k + b[b.size() - n + i] * (1.0 - k)
	b.resize(b.size() - n)
	return b

func D(b: PackedFloat32Array, extra := {}) -> Dictionary:
	var d := {"data": b}; d.merge(extra); return d

# ---------------------------------------------------------------- recipes (s_<name>)

func _step(cut: float, body: float, dec: float, click: float) -> Array:
	var v := []
	for k in 3:
		var b := env_exp(lp(noise(0.18), cut * rng.randf_range(0.85, 1.15)), dec)
		mix(b, env_exp(sine(0.18, body * rng.randf_range(0.9, 1.1)), dec * 0.8), 0.6)
		if click > 0.0: mix(b, env_exp(hp(noise(0.03), 2500.0), 0.004), click)
		v.append(D(b, {"gain": 0.7}))
	return v

func s_step_wood() -> Array: return _step(900.0, 110.0, 0.035, 0.15)
func s_step_tile() -> Array: return _step(2600.0, 180.0, 0.025, 0.5)
func s_step_carpet() -> Array: return _step(500.0, 90.0, 0.03, 0.0)
func s_step_concrete() -> Array: return _step(1700.0, 120.0, 0.03, 0.3)
func s_step_wet() -> Array:
	var v := []
	for k in 3:
		var b := env_exp(bp(noise(0.25), func(t): return 900.0 - t * 2000.0, 2.0), 0.06)
		mix(b, env_exp(lp(noise(0.2), 400.0), 0.03), 0.8)
		v.append(D(b, {"gain": 0.7}))
	return v

func s_door_open() -> Dictionary:
	var b := saw(0.9, func(t): return 340.0 + sin(t * 9.0) * 60.0 + sin(t * 23.0) * 25.0 + t * 120.0 + rng.randf_range(-15.0, 15.0))
	bp(b, 900.0, 3.0)
	for i in b.size():
		var t := float(i) / SR
		b[i] *= smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.6, 0.9, t)) * (0.6 + 0.4 * sin(t * 37.0))
	return D(verb(b, 0.4))

func s_door_close() -> Dictionary:
	var b := env_exp(sine(0.5, func(t): return 90.0 - t * 40.0), 0.12)
	mix(b, env_exp(lp(noise(0.5), 1200.0), 0.05), 0.9)
	mix(b, env_exp(hp(noise(0.05), 3000.0), 0.006), 0.4, 0.01)
	return D(verb(b, 0.5))

func s_door_locked() -> Dictionary:
	var b := buf(0.6)
	for k in 5:
		var c := env_exp(bp(noise(0.08), rng.randf_range(1800.0, 2600.0), 6.0), 0.012)
		mix(b, c, 1.0, k * 0.09 + rng.randf() * 0.03)
	mix(b, env_exp(lp(noise(0.5), 400.0), 0.08), 0.6)
	return D(b)

func s_drawer() -> Dictionary:
	var b := bp(noise(0.55), func(t): return 700.0 + t * 400.0, 1.5)
	for i in b.size():
		var t := float(i) / SR
		b[i] *= smoothstep(0.0, 0.05, t) * (1.0 - smoothstep(0.4, 0.55, t)) * (0.7 + 0.3 * sin(t * 80.0))
	mix(b, env_exp(lp(noise(0.2), 900.0), 0.03), 0.8, 0.45)
	return D(b)

func s_thud_light() -> Dictionary:
	var b := env_exp(lp(noise(0.25), 1400.0), 0.03)
	mix(b, env_exp(sine(0.25, 160.0), 0.04), 0.5)
	return D(b)

func s_thud_heavy() -> Dictionary:
	var b := env_exp(lp(noise(0.6), 700.0), 0.08)
	mix(b, env_exp(sine(0.6, func(t): return 70.0 - t * 30.0), 0.16), 1.0)
	return D(verb(b, 0.6))

func s_glass() -> Dictionary:
	var b := env_exp(hp(noise(1.1), 2000.0), 0.12)
	for k in 14:
		var tink := env_exp(sine(0.3, rng.randf_range(2500.0, 6000.0)), 0.03)
		mix(b, tink, 0.4, rng.randf() * 0.7)
	return D(verb(b, 0.5))

func s_metal() -> Dictionary:
	var b := buf(0.8)
	for f in [620.0, 1530.0, 2210.0, 3170.0]:
		mix(b, env_exp(sine(0.8, f * rng.randf_range(0.98, 1.02)), 0.18 * 600.0 / f * 2.0), 0.4)
	mix(b, env_exp(hp(noise(0.02), 3000.0), 0.003), 0.6)
	return D(b)

func s_gunshot() -> Dictionary:
	var b := env_exp(noise(1.6), 0.05, 0.0005)
	lp(b, 6000.0)
	mix(b, env_exp(sine(1.6, func(t): return 60.0 + 80.0 * exp(-t * 20.0)), 0.18), 1.6)
	mix(b, env_exp(lp(noise(1.6), 500.0), 0.5, 0.01, 0.03), 0.7)
	return D(verb(b, 1.4, 0.6), {"gain": 1.0})

func s_dry_fire() -> Dictionary:
	var b := env_exp(bp(noise(0.08), 3200.0, 4.0), 0.006)
	mix(b, env_exp(bp(noise(0.08), 1800.0, 4.0), 0.008), 0.6, 0.02)
	return D(b)

func s_reload() -> Dictionary:
	var b := buf(0.5)
	mix(b, env_exp(bp(noise(0.1), 2600.0, 5.0), 0.01), 1.0, 0.0)
	mix(b, env_exp(bp(noise(0.1), 3400.0, 6.0), 0.008), 0.8, 0.22)
	mix(b, env_exp(bp(noise(0.2), 1200.0, 2.0), 0.04), 0.3, 0.05)
	return D(b)

func s_cylinder() -> Dictionary:
	var b := buf(0.25)
	mix(b, env_exp(bp(noise(0.08), 2900.0, 8.0), 0.007), 1.0)
	mix(b, env_exp(bp(noise(0.08), 2000.0, 8.0), 0.007), 0.7, 0.06)
	return D(b)

func s_pickup() -> Dictionary:
	var b := env_exp(bp(noise(0.3), func(t): return 1500.0 + t * 1500.0, 1.2), 0.07, 0.02)
	return D(b, {"gain": 0.5})

func s_marta_clicks() -> Dictionary:
	var b := buf(2.0)
	var t := 0.05
	while t < 1.8:
		var f := rng.randf_range(1300.0, 2600.0)
		var c := env_exp(bp(noise(0.05), f, 12.0), 0.006)
		mix(c, env_exp(sine(0.05, f * 0.5), 0.004), 0.5)
		mix(b, c, rng.randf_range(0.6, 1.0), t)
		t += rng.randf_range(0.05, 0.22) if rng.randf() > 0.25 else rng.randf_range(0.3, 0.45)
	return D(verb(b, 0.8, 0.5))

func s_marta_hum() -> Dictionary:
	var notes := [0, 4, 7, 4, 2, 0, -1, 0]
	var dur := 3.2
	var b := sine(dur, func(t):
		var n: int = notes[int(t / dur * notes.size()) % notes.size()]
		return 196.0 * pow(2.0, n / 12.0) * (1.0 + 0.012 * sin(t * 31.0)))
	mix(b, gain(bp(noise(dur), 600.0, 3.0), 0.15))
	for i in b.size():
		var t := float(i) / SR
		b[i] *= smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(dur - 0.5, dur, t))
	lp(b, 900.0)
	return D(verb(b, 1.2, 0.6))

func s_static() -> Dictionary:
	var b := bp(noise(2.0), 1800.0, 0.6)
	for k in 30:
		mix(b, env_exp(hp(noise(0.02), 4000.0), 0.002), rng.randf_range(0.5, 2.0), rng.randf() * 1.95)
	return D(fade_loop(b), {"loop": true, "gain": 0.6})

func s_hum() -> Dictionary:
	var b := buf(1.0)
	for h in [1, 2, 3, 5, 7]:
		mix(b, sine(1.0, 100.0 * h, 1.0 / h))
	mix(b, gain(bp(noise(1.0), 3000.0, 1.0), 0.05))
	return D(b, {"loop": true, "gain": 0.4})

func s_drone() -> Dictionary:
	var dur := 8.0
	var b := sine(dur, 55.0, 0.6)
	mix(b, sine(dur, 55.0 * 1.0125, 0.5))
	mix(b, sine(dur, 82.5, 0.2))
	mix(b, gain(lp(noise(dur), 220.0), 2.5))
	return D(fade_loop(b, 0.5), {"loop": true, "gain": 0.5})

func s_drone_wrong() -> Dictionary:
	var dur := 8.0
	var b := sine(dur, func(t): return 49.0 + sin(t * 0.785) * 1.5, 0.6)
	mix(b, sine(dur, 69.3, 0.3))
	mix(b, sine(dur, func(t): return 233.0 + sin(t * 0.785 * 2.0) * 3.0, 0.08))
	var hiss := bp(noise(dur), 4000.0, 2.0)
	for i in hiss.size():
		hiss[i] *= 0.05 * (0.5 + 0.5 * sin(float(i) / SR * 0.785 * 3.0))
	mix(b, hiss)
	mix(b, gain(lp(noise(dur), 160.0), 2.5))
	return D(fade_loop(b, 0.5), {"loop": true, "gain": 0.5})

func s_heartbeat() -> Dictionary:
	var b := buf(0.9)
	mix(b, env_exp(sine(0.3, func(t): return 55.0 - t * 30.0), 0.06), 1.0, 0.0)
	mix(b, env_exp(sine(0.3, func(t): return 50.0 - t * 30.0), 0.07), 0.7, 0.18)
	lp(b, 300.0)
	return D(b, {"loop": true})

func s_whisper() -> Array:
	var v := []
	for k in 4:
		var dur := rng.randf_range(1.2, 2.0)
		var b := noise(dur)
		var f1 := rng.randf_range(500.0, 900.0)
		var cp := b.duplicate()
		bp(b, func(t): return f1 + 300.0 * sin(t * 13.0 + k), 4.0)
		bp(cp, func(t): return 2200.0 + 500.0 * sin(t * 7.0), 5.0)
		mix(b, cp, 0.6)
		for i in b.size():
			var t := float(i) / SR
			b[i] *= smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(dur - 0.4, dur, t)) * (0.3 + 0.7 * absf(sin(t * 9.0 + k)))
		v.append(D(verb(b, 1.0, 0.7), {"gain": 0.6}))
	return v

func s_pop() -> Dictionary:
	var b := env_exp(sine(0.15, func(t): return 300.0 + 900.0 * t), 0.03)
	return D(b, {"gain": 0.5})

func s_knock() -> Dictionary:
	var b := buf(0.9)
	for k in 3:
		var c := env_exp(lp(noise(0.15), 900.0), 0.02)
		mix(c, env_exp(sine(0.15, 140.0), 0.03), 0.8)
		mix(b, c, 1.0, k * 0.24)
	return D(verb(b, 0.4))

func s_buzz() -> Dictionary:
	var b := saw(0.6, 120.0)
	mix(b, gain(hp(noise(0.6), 3000.0), 0.6))
	for i in b.size():
		var t := float(i) / SR
		b[i] *= (1.0 - t / 0.6) * (0.5 + 0.5 * signf(sin(t * 60.0)))
	return D(b)

func s_splash() -> Dictionary:
	var b := env_exp(bp(noise(0.8), func(t): return 1200.0 - t * 800.0, 1.0), 0.18, 0.01)
	for k in 8:
		mix(b, env_exp(sine(0.1, rng.randf_range(600.0, 1400.0)), 0.02), 0.2, rng.randf() * 0.5)
	return D(b)

func s_scrape() -> Dictionary:
	var b := bp(noise(0.9), func(t): return 300.0 + 150.0 * sin(t * 23.0), 2.0)
	mix(b, gain(saw(0.9, func(t): return 85.0 + 20.0 * sin(t * 11.0)), 0.25))
	for i in b.size():
		var t := float(i) / SR
		b[i] *= smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.7, 0.9, t)) * (0.6 + 0.4 * absf(sin(t * 31.0)))
	return D(b)

func s_switch() -> Dictionary:
	var b := env_exp(bp(noise(0.08), 2400.0, 5.0), 0.005)
	mix(b, env_exp(lp(noise(0.08), 800.0), 0.01), 0.5, 0.005)
	return D(b, {"gain": 0.7})

func s_alarm() -> Dictionary:
	var dur := 1.0
	var b := buf(dur)
	for k in 8:
		var r := env_exp(sine(0.1, 2100.0), 0.05)
		mix(r, env_exp(sine(0.1, 3300.0), 0.04), 0.5)
		mix(b, r, 1.0, k * 0.06)
	return D(b, {"loop": true, "gain": 0.8})

func s_tick() -> Dictionary:
	var b := buf(1.0)
	mix(b, env_exp(bp(noise(0.03), 3500.0, 8.0), 0.003), 1.0, 0.0)
	mix(b, env_exp(bp(noise(0.03), 3000.0, 8.0), 0.003), 0.7, 0.5)
	return D(b, {"loop": true, "gain": 0.35})

func s_music_box() -> Dictionary:
	var notes := [12, 16, 19, 16, 14, 12, 11, 12, 7, 11, 14, 12]
	var dur := 4.8
	var b := buf(dur)
	for k in notes.size():
		var f := 523.25 * pow(2.0, (notes[k] - 12) / 12.0)
		var n := env_exp(sine(0.9, f), 0.35)
		mix(n, env_exp(sine(0.9, f * 3.01), 0.08), 0.15)
		mix(b, n, 0.8, k * dur / notes.size())
	return D(fade_loop(verb(b, 0.6, 0.4), 0.05), {"loop": true, "gain": 0.6})

func s_chase() -> Dictionary:
	var dur := 3.2
	var b := buf(dur)
	for k in 16:
		var f := 55.0 if k % 4 != 3 else 58.27
		var n := env_exp(saw(0.2, f), 0.09)
		lp(n, 400.0)
		mix(b, n, 1.0 if k % 2 == 0 else 0.6, k * dur / 16.0)
	mix(b, gain(sine(dur, func(t): return 880.0 + 15.0 * sin(t * 5.0)), 0.03))
	return D(b, {"loop": true, "gain": 0.6})

func s_sting() -> Dictionary:
	var b := buf(2.5)
	for f in [233.1, 246.9, 349.2, 466.2]:
		mix(b, env_exp(saw(2.5, f), 0.8, 0.005), 0.25)
	lp(b, 2500.0)
	mix(b, env_exp(noise(2.5), 0.05), 0.4)
	return D(verb(b, 1.5, 0.5))

func s_crawl() -> Dictionary:
	var b := bp(noise(1.2), 700.0, 1.0)
	for i in b.size():
		var t := float(i) / SR
		b[i] *= 0.5 + 0.5 * absf(sin(t * 5.0))
	return D(b, {"gain": 0.5})

func s_bolt() -> Dictionary:
	var b := bp(noise(0.35), func(t): return 1500.0 + t * 2000.0, 3.0)
	for i in b.size(): b[i] *= smoothstep(0.0, 0.03, float(i) / SR) * (1.0 - smoothstep(0.2, 0.3, float(i) / SR))
	mix(b, env_exp(bp(noise(0.1), 2200.0, 6.0), 0.01), 1.0, 0.27)
	return D(b)

func s_chain() -> Dictionary:
	var b := buf(0.9)
	for k in 12:
		mix(b, env_exp(bp(noise(0.06), rng.randf_range(2500.0, 4500.0), 9.0), 0.012), rng.randf_range(0.4, 1.0), rng.randf() * 0.75)
	return D(b)

func s_fuse() -> Dictionary:
	var b := env_exp(lp(noise(0.3), 1500.0), 0.03)
	mix(b, env_exp(bp(noise(0.3), 2600.0, 6.0), 0.01), 0.6)
	mix(b, gain(env_exp(saw(0.3, 100.0), 0.1, 0.01, 0.05), 0.3))
	return D(b)

func s_creak() -> Array:
	var v := []
	for k in 3:
		var dur := rng.randf_range(0.6, 1.2)
		var b := saw(dur, func(t): return rng.randf_range(80.0, 95.0) + t * 40.0)
		bp(b, rng.randf_range(400.0, 800.0), 4.0)
		for i in b.size():
			var t := float(i) / SR
			b[i] *= sin(PI * t / dur) * (0.5 + 0.5 * sin(t * 47.0))
		v.append(D(verb(b, 0.6, 0.5), {"gain": 0.5}))
	return v

func s_distant_knock() -> Dictionary:
	var b := buf(1.4)
	for k in 3:
		var c := env_exp(lp(noise(0.2), 300.0), 0.04)
		mix(c, env_exp(sine(0.2, 90.0), 0.05), 1.0)
		mix(b, c, 1.0, k * 0.33)
	return D(verb(b, 1.0, 0.7))

func s_swallow() -> Dictionary:
	var b := env_exp(bp(noise(0.4), func(t): return 500.0 - t * 400.0, 3.0), 0.08, 0.03)
	return D(b, {"gain": 0.4})

func s_grab() -> Dictionary:
	var b := env_exp(lp(noise(1.2), 900.0), 0.3, 0.005)
	mix(b, env_exp(sine(1.2, func(t): return 70.0 - t * 30.0), 0.4), 1.0)
	mix(b, env_exp(saw(1.2, func(t): return 180.0 - t * 80.0), 0.5, 0.05), 0.4)
	return D(verb(b, 1.0, 0.5))

func s_impact_flesh() -> Dictionary:
	var b := env_exp(lp(noise(0.4), 600.0), 0.05)
	mix(b, env_exp(bp(noise(0.4), 900.0, 2.0), 0.08), 0.6)
	return D(b)
