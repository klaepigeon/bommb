class_name SoundLib
## Every sound in the game but the voices (docs/SOUND.md), made from a few physical ideas rather
## than shaped noise:
##   modes     a struck thing rings at its own frequencies, each dying at its own rate (wood:
##             few, low, quick; metal: many, inharmonic, long; glass: high and bright)
##   friction  a hinge, a floorboard, a dragged chair: stick-slip, a train of little releases
##             whose rate wanders, through the body's resonances
##   grains    grit, shards, paper, bubbles: many tiny events scattered in time
##   beds      rooms are never silent: pink and brown noise, mains hum, the building
## Baked at 32 kHz by tools/bake_audio.gd (Sfx.GEN entries carry the rate). Deterministic: each
## sound seeds its own generator.

const SR := 32000

# ================================================================== DSP
static func buf(secs: float) -> PackedFloat32Array:
	var d := PackedFloat32Array(); d.resize(int(secs * SR)); return d

## Biquad, in place. kind: "lp", "hp", "bp" (constant 0 dB peak), "peak" (gain_db).
static func biquad(d: PackedFloat32Array, kind: String, f: float, q := 0.707, gain_db := 0.0) -> void:
	f = clampf(f, 10.0, SR * 0.45)
	var w := TAU * f / SR; var cw := cos(w); var sw := sin(w); var al := sw / (2.0 * q)
	var A := pow(10.0, gain_db / 40.0)
	var b0 := 0.0; var b1 := 0.0; var b2 := 0.0; var a0 := 1.0; var a1 := 0.0; var a2 := 0.0
	match kind:
		"lp": b0 = (1.0 - cw) * 0.5; b1 = 1.0 - cw; b2 = b0; a0 = 1.0 + al; a1 = -2.0 * cw; a2 = 1.0 - al
		"hp": b0 = (1.0 + cw) * 0.5; b1 = -(1.0 + cw); b2 = b0; a0 = 1.0 + al; a1 = -2.0 * cw; a2 = 1.0 - al
		"bp": b0 = al; b1 = 0.0; b2 = -al; a0 = 1.0 + al; a1 = -2.0 * cw; a2 = 1.0 - al
		"peak": b0 = 1.0 + al * A; b1 = -2.0 * cw; b2 = 1.0 - al * A; a0 = 1.0 + al / A; a1 = -2.0 * cw; a2 = 1.0 - al / A
	b0 /= a0; b1 /= a0; b2 /= a0; a1 /= a0; a2 /= a0
	var x1 := 0.0; var x2 := 0.0; var y1 := 0.0; var y2 := 0.0
	for i in d.size():
		var x := d[i]
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1; x1 = x; y2 = y1; y1 = y; d[i] = y

static func white(n: int, r: RandomNumberGenerator) -> PackedFloat32Array:
	var d := PackedFloat32Array(); d.resize(n)
	for i in n: d[i] = r.randf_range(-1.0, 1.0)
	return d

## Pink (Paul Kellet's filter): air, rooms, wind.
static func pink(n: int, r: RandomNumberGenerator) -> PackedFloat32Array:
	var d := PackedFloat32Array(); d.resize(n)
	var b0 := 0.0; var b1 := 0.0; var b2 := 0.0; var b3 := 0.0; var b4 := 0.0; var b5 := 0.0; var b6 := 0.0
	for i in n:
		var w := r.randf_range(-1.0, 1.0)
		b0 = 0.99886 * b0 + w * 0.0555179; b1 = 0.99332 * b1 + w * 0.0750759; b2 = 0.969 * b2 + w * 0.153852
		b3 = 0.8665 * b3 + w * 0.3104856; b4 = 0.55 * b4 + w * 0.5329522; b5 = -0.7616 * b5 - w * 0.016898
		d[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362) * 0.11; b6 = w * 0.115926
	return d

## Brown: rumble, distance, the building's weight.
static func brown(n: int, r: RandomNumberGenerator) -> PackedFloat32Array:
	var d := PackedFloat32Array(); d.resize(n)
	var y := 0.0
	for i in n:
		y = (y + r.randf_range(-1.0, 1.0) * 0.02) * 0.998; d[i] = y * 3.5
	return d

static func mix(into: PackedFloat32Array, src: PackedFloat32Array, gain := 1.0, at := 0) -> void:
	for i in src.size():
		var j := i + at
		if j >= 0 and j < into.size(): into[j] += src[i] * gain

static func env_ad(d: PackedFloat32Array, attack: float, decay: float, at := 0.0) -> void:
	for i in d.size():
		var t := float(i) / SR - at
		d[i] *= 0.0 if t < 0.0 else (t / attack if t < attack else exp(-(t - attack) / decay))

static func norm(d: PackedFloat32Array, peak: float) -> void:
	var m := 0.0
	for v in d: m = maxf(m, absf(v))
	if m > 1e-9:
		var k := peak / m
		for i in d.size(): d[i] *= k

static func sat(d: PackedFloat32Array, drive: float) -> void:
	var k := tanh(drive)
	for i in d.size(): d[i] = tanh(d[i] * drive) / k

## A struck body: an excitation into a bank of resonators (damped sinusoids). freqs/decays/amps
## per mode; `excite` the impulse's softness (seconds: 0.0005 hard .. 0.01 soft).
static func strike(d: PackedFloat32Array, at: float, freqs: Array, decays: Array, amps: Array, r: RandomNumberGenerator, excite := 0.001, gain := 1.0) -> void:
	var s0 := int(at * SR)
	for k in freqs.size():
		var f: float = freqs[k] * r.randf_range(0.985, 1.015)
		var dc: float = decays[k]; var a: float = amps[k] * gain
		var ph := r.randf() * TAU
		var n := mini(d.size() - s0, int(dc * 7.0 * SR))
		for i in n:
			var t := float(i) / SR
			var att := 1.0 - exp(-t / maxf(excite, 0.0002))
			d[s0 + i] += sin(TAU * f * t + ph) * exp(-t / dc) * att * a
	# the contact itself: a short tick of noise
	var tick := int(0.004 * SR)
	for i in mini(tick, d.size() - s0):
		d[s0 + i] += r.randf_range(-1.0, 1.0) * exp(-float(i) / (excite * SR + 1.0)) * gain * 0.4

## Stick-slip: little releases at a rate that wanders around `f` (Hz), as `f_path` (a Callable
## t -> rate) says; each release rings the resonances given.
static func friction(d: PackedFloat32Array, at: float, secs: float, f_path: Callable, res: Array, r: RandomNumberGenerator, gain := 1.0, jitter := 0.15) -> void:
	var src := PackedFloat32Array(); src.resize(int(secs * SR))
	var next := 0.0; var t := 0.0
	while t < secs:
		var f: float = maxf(5.0, float(f_path.call(t / secs)))
		var i := int(t * SR)
		if i < src.size(): src[i] += r.randf_range(0.6, 1.0)
		t += (1.0 / f) * r.randf_range(1.0 - jitter, 1.0 + jitter)
	var out := PackedFloat32Array(); out.resize(src.size())
	for rr in res:
		var band := src.duplicate()
		biquad(band, "bp", rr[0], rr[1])
		mix(out, band, rr[2])
	mix(d, out, gain, int(at * SR))

## Grains: `count` little events between t0 and t1, each a few ms of noise through a band
## (freq range), louder early if `fade`.
static func grains(d: PackedFloat32Array, t0: float, t1: float, count: int, f_lo: float, f_hi: float, len_ms: float, r: RandomNumberGenerator, gain := 1.0, fade := true) -> void:
	for g in count:
		var at := r.randf_range(t0, t1)
		var n := int(len_ms * 0.001 * SR * r.randf_range(0.5, 1.5))
		var gr := PackedFloat32Array(); gr.resize(n)
		for i in n: gr[i] = r.randf_range(-1.0, 1.0) * exp(-float(i) / (n * 0.3 + 1.0))
		biquad(gr, "bp", r.randf_range(f_lo, f_hi), r.randf_range(2.0, 6.0))
		var a := gain * r.randf_range(0.4, 1.0) * ((1.0 - (at - t0) / maxf(0.001, t1 - t0)) if fade else 1.0)
		mix(d, gr, a, int(at * SR))

## A bubble (Minnaert): a sine whose pitch rises as it closes.
static func bubble(d: PackedFloat32Array, at: float, f: float, dur: float, gain: float) -> void:
	var s0 := int(at * SR); var ph := 0.0
	for i in mini(int(dur * SR), d.size() - s0):
		var t := float(i) / SR
		ph += TAU * f * (1.0 + t / dur * 1.2) / SR
		d[s0 + i] += sin(ph) * exp(-t / (dur * 0.35)) * gain

static func thump(d: PackedFloat32Array, at: float, f: float, dur: float, gain: float, drop := 0.5) -> void:
	var s0 := int(at * SR); var ph := 0.0
	for i in mini(int(dur * SR), d.size() - s0):
		var t := float(i) / SR
		ph += TAU * f * (1.0 - drop * minf(1.0, t / dur)) / SR
		d[s0 + i] += sin(ph) * exp(-t / (dur * 0.3)) * minf(1.0, t * 800.0) * gain

static func rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = seed; return r

# ================================================================== footsteps
## A step: the heel, then the rest of the foot a moment later; what it lands on decides the rest.
static func step(surface: String, variant: int) -> PackedFloat32Array:
	var r := rng(1000 + variant * 31 + surface.hash() % 997)
	var d := buf(0.42)
	var toe := r.randf_range(0.055, 0.085)
	match surface:
		"wood":
			for a in [[0.0, 1.0], [toe, 0.55]]:
				strike(d, a[0], [118, 236, 410, 640, 980], [0.06, 0.035, 0.022, 0.014, 0.009], [1.0, 0.5, 0.3, 0.18, 0.1], r, 0.0025, a[1])
			thump(d, 0.0, 70.0, 0.09, 0.5)
			if variant == 3: friction(d, toe + 0.02, 0.18, func(k): return 160.0 + k * 90.0, [[700.0, 4.0, 1.0], [1500.0, 5.0, 0.4]], r, 0.05)
			biquad(d, "lp", 4200.0)
		"lino":
			for a in [[0.0, 1.0], [toe, 0.6]]:
				var s := white(int(0.03 * SR), r); env_ad(s, 0.0005, 0.006); biquad(s, "bp", 2400.0, 1.2)
				mix(d, s, 0.6 * a[1], int(a[0] * SR))
				thump(d, a[0], 95.0, 0.06, 0.5 * a[1])
			if variant == 2: friction(d, toe + 0.03, 0.06, func(k): return 900.0, [[2600.0, 8.0, 1.0]], r, 0.04)    # a squeak
		"tile":
			for a in [[0.0, 1.0], [toe, 0.65]]:
				strike(d, a[0], [1850, 2950, 4300, 5600], [0.02, 0.014, 0.01, 0.007], [0.5, 0.4, 0.3, 0.2], r, 0.0003, a[1])
				thump(d, a[0], 110.0, 0.05, 0.4 * a[1])
			grains(d, 0.0, 0.12, 6, 3000.0, 7000.0, 2.0, r, 0.15)
		"concrete":
			for a in [[0.0, 1.0], [toe, 0.6]]:
				thump(d, a[0], 90.0, 0.07, 0.6 * a[1])
				var s := white(int(0.025 * SR), r); env_ad(s, 0.0005, 0.004); biquad(s, "bp", 1800.0, 0.9)
				mix(d, s, 0.4 * a[1], int(a[0] * SR))
			grains(d, 0.0, 0.18, 22, 1500.0, 5500.0, 3.0, r, 0.22)       # grit under the sole
		"soft":
			for a in [[0.0, 1.0], [toe, 0.5]]:
				thump(d, a[0], 75.0, 0.08, 0.5 * a[1])
			var s := pink(int(0.2 * SR), r); env_ad(s, 0.01, 0.05); biquad(s, "lp", 900.0)
			mix(d, s, 0.4)
			biquad(d, "lp", 1400.0)
		"flesh":
			thump(d, 0.0, 60.0, 0.12, 0.7)
			var s := white(int(0.3 * SR), r)
			for i in s.size():
				var t := float(i) / SR
				s[i] *= exp(-t / 0.07) * (0.6 + 0.4 * sin(t * TAU * 38.0))      # the suck of it
			biquad(s, "bp", 380.0, 2.5); biquad(s, "peak", 900.0, 3.0, 6.0)
			mix(d, s, 1.4)
			bubble(d, toe + 0.07, 320.0 + variant * 40.0, 0.05, 0.35)          # coming unstuck
			bubble(d, toe + 0.1, 520.0, 0.03, 0.2)
	norm(d, 0.7)
	return d

## A floorboard giving under him.
static func board_creak(variant: int) -> PackedFloat32Array:
	var r := rng(77 + variant)
	var d := buf(0.7)
	var base := r.randf_range(140.0, 220.0)
	friction(d, 0.02, 0.55, func(k): return base + sin(k * PI) * 120.0, [[base * 3.1, 6.0, 1.0], [base * 6.7, 8.0, 0.5], [1900.0, 4.0, 0.2]], r, 1.0, 0.08)
	env_ad(d, 0.05, 0.25)
	biquad(d, "lp", 3500.0)
	norm(d, 0.45)
	return d

# ================================================================== doors, the flat's things
## Knuckles on a padded front door: a dull wooden knock, the padding taking the edge off.
static func knock() -> PackedFloat32Array:
	var r := rng(11)
	var d := buf(0.45)
	strike(d, 0.0, [165, 312, 590, 880], [0.09, 0.05, 0.025, 0.015], [1.0, 0.6, 0.35, 0.15], r, 0.0012)
	thump(d, 0.0, 95.0, 0.1, 0.7)
	strike(d, 0.004, [2350, 3720], [0.02, 0.012], [0.05, 0.03], r, 0.0005)       # the latch, just
	biquad(d, "lp", 2400.0)
	norm(d, 0.85)
	return d

## The handle down, the door against its frame: the latch ticking, the leaf thudding.
static func door_rattle() -> PackedFloat32Array:
	var r := rng(12)
	var d := buf(0.7)
	strike(d, 0.0, [1900, 3100, 4700], [0.05, 0.03, 0.02], [0.4, 0.3, 0.2], r, 0.0004)        # the handle
	for k in 4:
		var t := 0.08 + k * r.randf_range(0.07, 0.11)
		strike(d, t, [140, 290, 560], [0.06, 0.03, 0.02], [0.7, 0.4, 0.2], r, 0.002, r.randf_range(0.6, 1.0))
		strike(d, t + 0.003, [2400, 3800], [0.025, 0.015], [0.25, 0.15], r, 0.0004)
	biquad(d, "lp", 5000.0)
	norm(d, 0.8)
	return d

## A hinge, dry: a slow rising creak.
static func door_creak() -> PackedFloat32Array:
	var r := rng(13)
	var d := buf(1.3)
	friction(d, 0.0, 1.2, func(k): return 90.0 + k * 140.0 + sin(k * 9.0) * 20.0, [[820.0, 7.0, 1.0], [1650.0, 9.0, 0.6], [2900.0, 6.0, 0.3]], r, 1.0, 0.1)
	env_ad(d, 0.15, 0.6)
	norm(d, 0.5)
	return d

## Slammed: the leaf into the frame, the latch, the wall taking it.
static func door_slam() -> PackedFloat32Array:
	var r := rng(14)
	var d := buf(1.2)
	thump(d, 0.0, 62.0, 0.35, 1.0, 0.35)
	strike(d, 0.0, [128, 265, 520, 790, 1210], [0.18, 0.11, 0.06, 0.04, 0.025], [1.0, 0.7, 0.4, 0.25, 0.15], r, 0.0008)
	strike(d, 0.012, [2600, 4100, 5900], [0.05, 0.03, 0.02], [0.3, 0.2, 0.1], r, 0.0003)
	var tail := brown(int(0.9 * SR), r); env_ad(tail, 0.005, 0.25); biquad(tail, "lp", 300.0)
	mix(d, tail, 0.4)
	sat(d, 1.6)
	norm(d, 0.95)
	return d

static func door_shut() -> PackedFloat32Array:
	var r := rng(15)
	var d := buf(0.5)
	strike(d, 0.0, [150, 300, 610], [0.08, 0.04, 0.02], [0.8, 0.4, 0.2], r, 0.002)
	strike(d, 0.03, [2200, 3500], [0.03, 0.02], [0.35, 0.2], r, 0.0003)        # the latch catching
	norm(d, 0.6)
	return d

## A switch (the light, the torch): press, release.
static func switch_click() -> PackedFloat32Array:
	var r := rng(16)
	var d := buf(0.2)
	for t in [0.0, 0.055]:
		strike(d, t, [3100, 4700, 6900], [0.012, 0.008, 0.005], [0.6, 0.4, 0.25], r, 0.0002)
		thump(d, t, 180.0, 0.02, 0.2)
	norm(d, 0.55)
	return d

## Something heavy on the floor; and the same through a wall or two.
static func thud(far := false) -> PackedFloat32Array:
	var r := rng(17 if not far else 18)
	var d := buf(0.9)
	thump(d, 0.0, 58.0, 0.25, 1.0, 0.4)
	strike(d, 0.0, [140, 230, 410], [0.08, 0.05, 0.03], [0.6, 0.4, 0.2], r, 0.003)
	grains(d, 0.02, 0.2, 5, 400.0, 1800.0, 6.0, r, 0.2)
	if far:
		biquad(d, "lp", 260.0); biquad(d, "lp", 400.0)
		var tail := brown(int(0.8 * SR), r); env_ad(tail, 0.02, 0.3); biquad(tail, "lp", 150.0)
		mix(d, tail, 0.5)
	norm(d, 0.9 if not far else 0.7)
	return d

## A chair dragged on the floor.
static func scrape() -> PackedFloat32Array:
	var r := rng(19)
	var d := buf(0.9)
	friction(d, 0.0, 0.85, func(k): return 55.0 + sin(k * 7.0) * 18.0 + k * 30.0, [[420.0, 3.0, 1.0], [980.0, 4.0, 0.6], [2100.0, 5.0, 0.25]], r, 1.0, 0.35)
	env_ad(d, 0.05, 0.4)
	norm(d, 0.6)
	return d

## A drawer: the runners, the stop.
static func drawer() -> PackedFloat32Array:
	var r := rng(20)
	var d := buf(0.6)
	friction(d, 0.0, 0.35, func(k): return 70.0 + k * 40.0, [[650.0, 3.0, 1.0], [1500.0, 4.0, 0.4]], r, 0.7, 0.4)
	strike(d, 0.36, [180, 360, 720], [0.06, 0.03, 0.02], [0.8, 0.4, 0.2], r, 0.002)
	strike(d, 0.37, [2500, 3900], [0.03, 0.02], [0.2, 0.12], r, 0.0004)      # things inside it
	norm(d, 0.6)
	return d

## A thing in a hand: cloth, the thing knocking against a knuckle.
static func pickup() -> PackedFloat32Array:
	var r := rng(21)
	var d := buf(0.3)
	var s := pink(int(0.2 * SR), r); env_ad(s, 0.02, 0.05); biquad(s, "bp", 1800.0, 0.8)
	mix(d, s, 0.5)
	strike(d, 0.07, [900, 1700, 2600], [0.03, 0.02, 0.012], [0.4, 0.3, 0.2], r, 0.001)
	norm(d, 0.45)
	return d

static func paper() -> PackedFloat32Array:
	var r := rng(22)
	var d := buf(0.6)
	grains(d, 0.0, 0.5, 70, 2500.0, 8000.0, 4.0, r, 0.5, false)
	var air := pink(d.size(), r); env_ad(air, 0.05, 0.2); biquad(air, "hp", 1500.0)
	mix(d, air, 0.25)
	norm(d, 0.5)
	return d

## A metal thing hit (the ammo tin, a pan): bright, inharmonic, long.
static func metal_hit() -> PackedFloat32Array:
	var r := rng(23)
	var d := buf(1.2)
	strike(d, 0.0, [520, 1347, 2412, 3981, 5220, 6730], [0.35, 0.25, 0.18, 0.12, 0.08, 0.05], [1.0, 0.7, 0.5, 0.35, 0.25, 0.15], r, 0.0003)
	norm(d, 0.6)
	return d

## Glass going: the crack, the shards, the bits settling.
static func glass_break() -> PackedFloat32Array:
	var r := rng(24)
	var d := buf(1.4)
	var crack := white(int(0.02 * SR), r); env_ad(crack, 0.0003, 0.004); biquad(crack, "hp", 2000.0)
	mix(d, crack, 1.0)
	for k in 26:
		var t := r.randf_range(0.0, 0.5) * r.randf()
		var f := r.randf_range(2600.0, 8800.0)
		strike(d, t, [f, f * 1.47, f * 2.13], [0.06, 0.04, 0.02], [0.5, 0.3, 0.15], r, 0.0002, r.randf_range(0.2, 0.7) * (1.0 - t))
	for k in 10:             # bits settling on the floor
		var t := r.randf_range(0.5, 1.2)
		var f := r.randf_range(3500.0, 7000.0)
		strike(d, t, [f, f * 1.6], [0.03, 0.015], [0.3, 0.15], r, 0.0002, r.randf_range(0.05, 0.2))
	norm(d, 0.8)
	return d

## A pipe in the wall, knocked (the building's heating): the iron ringing, through plaster.
static func pipe_knock() -> PackedFloat32Array:
	var r := rng(25)
	var d := buf(1.6)
	strike(d, 0.0, [212, 589, 1143, 1890, 2830], [0.6, 0.45, 0.3, 0.2, 0.12], [1.0, 0.7, 0.45, 0.25, 0.12], r, 0.0008)
	biquad(d, "lp", 1600.0)
	norm(d, 0.7)
	return d

## A drop into a puddle.
static func drip() -> PackedFloat32Array:
	var r := rng(26)
	var d := buf(0.35)
	bubble(d, 0.0, r.randf_range(900.0, 1400.0), 0.06, 0.8)
	var s := white(int(0.02 * SR), r); env_ad(s, 0.0005, 0.004); biquad(s, "bp", 4000.0, 1.5)
	mix(d, s, 0.25)
	norm(d, 0.5)
	return d

## The building settling, or the flesh: a long, low, stressed creak.
static func groan() -> PackedFloat32Array:
	var r := rng(27)
	var d := buf(3.2)
	friction(d, 0.0, 3.0, func(k): return 22.0 + sin(k * PI) * 30.0 + sin(k * 13.0) * 4.0, [[180.0, 3.0, 1.0], [420.0, 5.0, 0.5], [95.0, 2.0, 0.7]], r, 1.0, 0.2)
	env_ad(d, 0.6, 1.4)
	biquad(d, "lp", 900.0)
	norm(d, 0.7)
	return d

## A slow creak (a joint, a jaw, a chair taking weight).
static func creak() -> PackedFloat32Array:
	var r := rng(28)
	var d := buf(1.6)
	friction(d, 0.0, 1.5, func(k): return 35.0 + k * 50.0, [[560.0, 6.0, 1.0], [1240.0, 7.0, 0.5]], r, 1.0, 0.15)
	env_ad(d, 0.3, 0.6)
	norm(d, 0.5)
	return d

## Someone walking in the flat upstairs: two heavy steps through the ceiling.
static func step_above() -> PackedFloat32Array:
	var r := rng(29)
	var d := buf(1.4)
	for t in [0.0, 0.62]:
		thump(d, t, 48.0, 0.3, 1.0, 0.3)
		strike(d, t, [110, 190], [0.12, 0.08], [0.5, 0.3], r, 0.004)
	biquad(d, "lp", 220.0); biquad(d, "lp", 300.0)
	norm(d, 0.7)
	return d

## A siren a long way off across the city.
static func siren() -> PackedFloat32Array:
	var r := rng(30)
	var d := buf(7.0)
	var ph := 0.0
	for i in d.size():
		var t := float(i) / SR
		var f := 620.0 + 340.0 * (0.5 - 0.5 * cos(t * TAU / 3.5))
		ph += TAU * f / SR
		d[i] = (sin(ph) + 0.3 * sin(ph * 2.0) + 0.15 * sin(ph * 3.0)) * minf(1.0, t / 1.5) * minf(1.0, (7.0 - t) / 1.5)
	biquad(d, "lp", 1300.0)
	var air := pink(d.size(), r); biquad(air, "lp", 500.0)
	mix(d, air, 0.15)
	norm(d, 0.4)
	return d

# ================================================================== the air
## Outside: gusts, and a whistle in the balcony door's gap. Loops.
static func wind() -> PackedFloat32Array:
	var r := rng(31)
	var d := pink(int(9.0 * SR), r)
	var w := d.duplicate()
	biquad(d, "lp", 700.0)
	var whistle := w.duplicate(); biquad(whistle, "bp", 950.0, 25.0)
	for i in d.size():
		var t := float(i) / SR
		var gust := 0.55 + 0.45 * sin(t * TAU / 9.0) * sin(t * TAU / 4.5 + 1.0)
		d[i] = d[i] * gust + whistle[i] * maxf(0.0, gust - 0.6) * 4.0
	norm(d, 0.6)
	return d

## The flat's own sound: soft air, the mains under everything, the city's rumble. Loops.
static func room_tone() -> PackedFloat32Array:
	var r := rng(32)
	var n := int(10.0 * SR)
	var d := pink(n, r); biquad(d, "lp", 1800.0); for i in n: d[i] *= 0.25
	var rumble := brown(n, r); biquad(rumble, "lp", 110.0)
	mix(d, rumble, 0.6)
	for i in n:
		var t := float(i) / SR
		d[i] += (sin(TAU * 50.0 * t) * 0.02 + sin(TAU * 100.0 * t) * 0.012 + sin(TAU * 150.0 * t) * 0.006) * (0.8 + 0.2 * sin(t * TAU / 5.0))
	norm(d, 0.5)
	return d

## The maze's own sound: a slow throb a little out of tune with itself, and the breathing of
## the walls. Loops.
static func flesh_bed() -> PackedFloat32Array:
	var r := rng(33)
	var n := int(10.0 * SR)
	var d := PackedFloat32Array(); d.resize(n)
	for i in n:
		var t := float(i) / SR
		d[i] = sin(TAU * 36.0 * t) * 0.35 + sin(TAU * 37.5 * t) * 0.3 + sin(TAU * 54.2 * t) * 0.12
	var breath := pink(n, r)
	var b2 := breath.duplicate()
	biquad(breath, "bp", 260.0, 1.8); biquad(b2, "bp", 620.0, 2.5)
	for i in n:
		var t := float(i) / SR
		var inhale := maxf(0.0, sin(t * TAU / 5.0))
		d[i] += breath[i] * (0.15 + 0.5 * inhale) + b2[i] * 0.2 * inhale
	var wet := white(n, r); biquad(wet, "bp", 1200.0, 6.0)
	for i in n: d[i] += wet[i] * 0.03 * (0.5 + 0.5 * sin(float(i) / SR * 1.3))
	norm(d, 0.6)
	return d

## Goo, bubbling. Loops.
static func goo() -> PackedFloat32Array:
	var r := rng(34)
	var d := brown(int(4.0 * SR), r); biquad(d, "lp", 260.0); for i in d.size(): d[i] *= 0.4
	for k in 34: bubble(d, r.randf_range(0.0, 3.9), r.randf_range(140.0, 420.0), r.randf_range(0.03, 0.09), r.randf_range(0.2, 0.6))
	norm(d, 0.6)
	return d

## A fluorescent tube: 100 Hz and its harmonics, a fizz.
static func tube_buzz() -> PackedFloat32Array:
	var r := rng(35)
	var n := int(3.0 * SR)
	var d := PackedFloat32Array(); d.resize(n)
	for i in n:
		var t := float(i) / SR
		d[i] = sin(TAU * 100.0 * t) * 0.5 + sin(TAU * 200.0 * t) * 0.3 + sin(TAU * 300.0 * t) * 0.2 + sin(TAU * 500.0 * t) * 0.08
	var fizz := white(n, r); biquad(fizz, "bp", 6000.0, 1.0)
	mix(d, fizz, 0.04)
	norm(d, 0.35)
	return d

## The fridge: compressor hum and a rattle in its panel. Loops.
static func fridge() -> PackedFloat32Array:
	var r := rng(36)
	var n := int(6.0 * SR)
	var d := PackedFloat32Array(); d.resize(n)
	for i in n:
		var t := float(i) / SR
		d[i] = sin(TAU * 50.0 * t) * 0.5 + sin(TAU * 100.0 * t) * 0.35 + sin(TAU * 150.0 * t) * 0.12 + sin(TAU * 49.3 * t) * 0.2
	var rattle := white(n, r)
	for i in n: rattle[i] *= 0.5 + 0.5 * sign(sin(TAU * 25.0 * float(i) / SR))
	biquad(rattle, "bp", 1400.0, 5.0)
	mix(d, rattle, 0.05)
	biquad(d, "lp", 1200.0)
	norm(d, 0.4)
	return d

## A television with no station: hiss, the line whine, the picture's flutter. Loops.
static func tv_static() -> PackedFloat32Array:
	var r := rng(37)
	var n := int(4.0 * SR)
	var d := white(n, r); biquad(d, "hp", 300.0); biquad(d, "lp", 9000.0)
	for i in n:
		var t := float(i) / SR
		d[i] = d[i] * (0.8 + 0.2 * sin(t * TAU * 50.0)) + sin(TAU * 15625.0 * t) * 0.03
	norm(d, 0.4)
	return d

## The telephone off its hook: 425 Hz, on and off, down an old line. Loops.
static func busy_tone() -> PackedFloat32Array:
	var n := int(2.0 * SR)
	var d := PackedFloat32Array(); d.resize(n)
	for i in n:
		var t := float(i) / SR
		var on := 1.0 if fposmod(t, 0.7) < 0.35 else 0.0
		d[i] = sin(TAU * 425.0 * t) * on
	sat(d, 2.0); biquad(d, "bp", 1000.0, 0.6)
	norm(d, 0.35)
	return d

## Flies: a few, each its own wing-buzz, wandering in and out. Loops.
static func flies() -> PackedFloat32Array:
	var r := rng(38)
	var n := int(6.0 * SR)
	var d := PackedFloat32Array(); d.resize(n)
	for f in 4:
		var base := r.randf_range(170.0, 240.0); var ph := 0.0
		var a := r.randf_range(0.0, TAU); var sp := r.randf_range(0.25, 0.6)
		for i in n:
			var t := float(i) / SR
			var near := 0.5 + 0.5 * sin(t * TAU * sp / 6.0 * 6.0 / 6.0 + a)       # coming and going
			ph += TAU * base * (1.0 + 0.04 * sin(t * 5.0 + a)) / SR
			var saw := 1.0 - 2.0 * fposmod(ph / TAU, 1.0)
			d[i] += saw * near * near * 0.3
	biquad(d, "bp", 900.0, 0.8)
	norm(d, 0.4)
	return d

## His ears after the blow: a high whine, the world gone thick under it.
static func tinnitus() -> PackedFloat32Array:
	var r := rng(39)
	var n := int(5.0 * SR)
	var d := PackedFloat32Array(); d.resize(n)
	for i in n:
		var t := float(i) / SR
		d[i] = (sin(TAU * 6800.0 * t) + 0.6 * sin(TAU * 6812.0 * t)) * 0.4 * exp(-t / 2.5)
	var thick := brown(n, r); biquad(thick, "lp", 200.0)
	mix(d, thick, 0.4)
	norm(d, 0.45)
	return d

# ================================================================== the body, the violence
## A heartbeat: lub, then dub, felt in the chest.
static func heartbeat() -> PackedFloat32Array:
	var d := buf(0.6)
	thump(d, 0.0, 55.0, 0.14, 1.0, 0.35)
	thump(d, 0.17, 48.0, 0.12, 0.7, 0.35)
	biquad(d, "lp", 180.0)
	norm(d, 0.9)
	return d

static func heart_loop() -> PackedFloat32Array:
	var d := buf(3.333)       # 72 a minute, four beats
	for k in 4:
		mix(d, heartbeat(), 1.0, int((k * 0.8333) * SR))
	norm(d, 0.9)
	return d

## Something swung through the air.
static func whoosh() -> PackedFloat32Array:
	var r := rng(40)
	var d := pink(int(0.4 * SR), r)
	var out := PackedFloat32Array(); out.resize(d.size())
	for seg in 8:
		var part := d.duplicate()
		var k := (seg + 0.5) / 8.0
		biquad(part, "bp", 400.0 + 1600.0 * sin(k * PI), 2.0)
		for i in part.size():
			var kk := float(i) / part.size()
			part[i] *= maxf(0.0, 1.0 - absf(kk - k) * 8.0)
		mix(out, part)
	env_ad(out, 0.12, 0.12)
	norm(out, 0.6)
	return out

## A joint going: a dry snap, the crackle after.
static func bone_crack() -> PackedFloat32Array:
	var r := rng(41)
	var d := buf(0.3)
	var snap := white(int(0.008 * SR), r); env_ad(snap, 0.0002, 0.0015); biquad(snap, "hp", 1200.0)
	mix(d, snap, 1.0)
	strike(d, 0.0, [1300, 2600], [0.012, 0.007], [0.5, 0.3], r, 0.0002)
	grains(d, 0.01, 0.12, 9, 1500.0, 5000.0, 1.5, r, 0.45)
	thump(d, 0.0, 140.0, 0.04, 0.3)
	norm(d, 0.8)
	return d

## Wet: something soft giving.
static func squelch() -> PackedFloat32Array:
	var r := rng(42)
	var d := buf(0.6)
	var s := white(int(0.5 * SR), r)
	var out := PackedFloat32Array(); out.resize(s.size())
	for seg in 6:
		var part := s.duplicate()
		var k := (seg + 0.5) / 6.0
		biquad(part, "bp", 280.0 + 700.0 * k, 4.0)
		for i in part.size():
			var kk := float(i) / part.size()
			part[i] *= maxf(0.0, 1.0 - absf(kk - k) * 6.0)
		mix(out, part)
	env_ad(out, 0.01, 0.15)
	mix(d, out, 2.0)
	for k in 5: bubble(d, r.randf_range(0.05, 0.4), r.randf_range(250.0, 600.0), 0.04, 0.3)
	thump(d, 0.0, 70.0, 0.08, 0.4)
	norm(d, 0.7)
	return d

## Kurt crawling through the hole: wet drags, the hands.
static func crawl() -> PackedFloat32Array:
	var r := rng(43)
	var d := buf(2.4)
	for k in 5:
		var at := k * 0.45 + r.randf_range(0.0, 0.1)
		mix(d, squelch(), 0.6, int(at * SR))
		friction(d, at + 0.1, 0.3, func(_k): return 40.0, [[350.0, 2.0, 1.0]], r, 0.3, 0.5)
	norm(d, 0.7)
	return d

## The pistol, in a small flat: the crack, the body, the slide, the room.
static func gunshot() -> PackedFloat32Array:
	var r := rng(44)
	var d := buf(1.6)
	var crack := white(int(0.012 * SR), r); env_ad(crack, 0.0001, 0.002)
	mix(d, crack, 1.0)
	thump(d, 0.0, 85.0, 0.16, 1.2, 0.5)
	var body := white(int(0.2 * SR), r); env_ad(body, 0.0005, 0.03); biquad(body, "lp", 1800.0)
	mix(d, body, 0.8)
	strike(d, 0.035, [2100, 3400, 5100], [0.03, 0.02, 0.012], [0.4, 0.3, 0.2], r, 0.0003)     # the slide
	# the room giving it back
	var tail := pink(int(1.3 * SR), r); env_ad(tail, 0.01, 0.35); biquad(tail, "lp", 1400.0)
	mix(d, tail, 0.35, int(0.01 * SR))
	for e in [[0.011, 0.45], [0.019, 0.3], [0.031, 0.2]]:
		var echo := d.slice(0, int(0.08 * SR)); biquad(echo, "lp", 2500.0)
		mix(d, echo, e[1], int(e[0] * SR))
	sat(d, 2.4)
	norm(d, 1.0)
	return d

static func dry_fire() -> PackedFloat32Array:
	var r := rng(45)
	var d := buf(0.25)
	strike(d, 0.0, [2800, 4300, 6100], [0.02, 0.014, 0.008], [0.6, 0.4, 0.2], r, 0.0002)
	strike(d, 0.012, [900, 1500], [0.02, 0.012], [0.2, 0.1], r, 0.0005)
	norm(d, 0.5)
	return d

## The magazine out, in, the slide racked.
static func reload() -> PackedFloat32Array:
	var r := rng(46)
	var d := buf(1.0)
	friction(d, 0.0, 0.12, func(_k): return 300.0, [[2400.0, 3.0, 1.0]], r, 0.3)
	strike(d, 0.13, [1700, 2900, 4400], [0.03, 0.02, 0.012], [0.5, 0.3, 0.2], r, 0.0003)
	strike(d, 0.45, [1500, 2600, 4000], [0.04, 0.025, 0.015], [0.8, 0.5, 0.3], r, 0.0003)     # in
	thump(d, 0.45, 160.0, 0.03, 0.3)
	friction(d, 0.68, 0.08, func(_k): return 500.0, [[3000.0, 3.0, 1.0]], r, 0.35)
	strike(d, 0.77, [2000, 3300, 5200], [0.03, 0.02, 0.01], [0.7, 0.45, 0.25], r, 0.0003)    # home
	norm(d, 0.6)
	return d

## A bullet into plaster: the crack, the plaster crumbling.
static func bullet_hit() -> PackedFloat32Array:
	var r := rng(47)
	var d := buf(0.7)
	var c := white(int(0.01 * SR), r); env_ad(c, 0.0002, 0.002); biquad(c, "hp", 1500.0)
	mix(d, c, 1.0)
	thump(d, 0.0, 120.0, 0.05, 0.5)
	grains(d, 0.01, 0.5, 30, 800.0, 4500.0, 4.0, r, 0.4)
	norm(d, 0.7)
	return d

static func bullet_flesh() -> PackedFloat32Array:
	var r := rng(48)
	var d := buf(0.6)
	thump(d, 0.0, 70.0, 0.1, 1.0)
	mix(d, squelch(), 0.7)
	var c := white(int(0.006 * SR), r); env_ad(c, 0.0002, 0.0015); biquad(c, "bp", 2500.0, 1.0)
	mix(d, c, 0.5)
	norm(d, 0.8)
	return d

## A stinger: low brass a semitone apart, a high scrape over it, swelling and hitting.
static func sting() -> PackedFloat32Array:
	var r := rng(49)
	var d := buf(3.0)
	var ph := [0.0, 0.0, 0.0]
	var fs := [55.0, 58.3, 82.4]
	for i in d.size():
		var t := float(i) / SR
		var e := minf(1.0, t / 0.08) * exp(-t / 1.1)
		var v := 0.0
		for k in 3:
			ph[k] += fs[k] / SR
			v += (1.0 - 2.0 * fposmod(ph[k], 1.0)) * 0.35
		d[i] = v * e
	biquad(d, "lp", 900.0)
	var scrape := white(d.size(), r); biquad(scrape, "bp", 2900.0, 18.0); biquad(scrape, "bp", 2900.0, 18.0)
	for i in scrape.size():
		var t := float(i) / SR
		scrape[i] *= minf(1.0, t / 0.3) * exp(-t / 0.9)
	mix(d, scrape, 6.0)
	thump(d, 0.0, 45.0, 0.5, 0.8, 0.3)
	sat(d, 1.3)
	norm(d, 0.9)
	return d

# ================================================================== Chapter 2 (docs/SOUND.md)
## Nothing cartoonish here: no bubbles, no pitch-drops. Low, dry, close, and wrong.

## The building at night: a mains drone that never sits still in pitch, pipes moaning somewhere
## above, and now and then a knock through a wall. Loops.
static func lobby_bed() -> PackedFloat32Array:
	var r := rng(201)
	var n := int(16.0 * SR)
	var d := PackedFloat32Array(); d.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / SR
		var f := 49.6 + sin(t * 0.11) * 0.6 + sin(t * 0.037) * 0.4
		ph += TAU * f / SR
		d[i] = sin(ph) * 0.18 + sin(ph * 2.0) * 0.08 + sin(ph * 3.01) * 0.04
	var air := brown(n, r); biquad(air, "lp", 160.0); mix(d, air, 0.7)
	var hiss := pink(n, r); biquad(hiss, "bp", 2400.0, 0.7); mix(d, hiss, 0.025)
	# pipes, far off: a slow friction moan through the iron
	for k in 3:
		var at := r.randf_range(1.0, 13.0)
		var tmp := PackedFloat32Array(); tmp.resize(n)
		friction(tmp, at, r.randf_range(2.0, 3.5), func(x): return 18.0 + sin(x * PI) * 10.0, [[210.0, 12.0, 1.0], [630.0, 14.0, 0.4]], r, 0.5, 0.05)
		env_ad(tmp, 0.8, 1.5, at)
		biquad(tmp, "lp", 800.0)
		mix(d, tmp, 0.4)
	# a knock through the wall, twice
	for k in 2:
		var at2 := r.randf_range(2.0, 14.0)
		thump(d, at2, 70.0, 0.2, 0.25, 0.2); thump(d, at2 + 0.32, 66.0, 0.2, 0.18, 0.2)
	norm(d, 0.5)
	return d

## A washing machine on its spin: the drum thudding round, the case rattling.
static func washer() -> PackedFloat32Array:
	var r := rng(202)
	var d := buf(2.6)
	for i in 5:
		var t := i * 0.5
		thump(d, t, 55.0, 0.25, 0.9, 0.15)
		strike(d, t + 0.02, [180, 340, 720], [0.08, 0.05, 0.03], [0.5, 0.3, 0.15], r, 0.003, 0.6)
	var hum := buf(2.6)
	for i in hum.size(): hum[i] = sin(TAU * 98.0 * float(i) / SR) * 0.12
	mix(d, hum, 1.0)
	grains(d, 0.0, 2.5, 30, 900.0, 2500.0, 3.0, r, 0.12, false)
	biquad(d, "lp", 2000.0)
	norm(d, 0.7)
	return d

## Fat on a gas ring: a hiss that crackles, low.
static func stove() -> PackedFloat32Array:
	var r := rng(203)
	var d := pink(int(2.5 * SR), r); biquad(d, "hp", 1500.0); biquad(d, "lp", 6000.0)
	for i in d.size(): d[i] *= 0.25
	grains(d, 0.0, 2.4, 60, 2000.0, 7000.0, 1.5, r, 0.5, false)
	env_ad(d, 0.1, 2.0)
	norm(d, 0.45)
	return d

## His breathing: heavy, through the mouth, wet at the back of the throat.
static func super_breath() -> PackedFloat32Array:
	var r := rng(204)
	var d := buf(2.8)
	for k in 2:
		var at := k * 1.35
		var b := pink(int(1.2 * SR), r)
		biquad(b, "bp", 520.0 if k == 0 else 380.0, 1.4)
		for i in b.size():
			var t := float(i) / SR
			b[i] *= sin(minf(1.0, t / 1.1) * PI) * (1.0 + 0.35 * sin(t * TAU * 23.0))      # the wet rattle in it
		mix(d, b, 1.0, int(at * SR))
	var low := brown(d.size(), r); biquad(low, "lp", 140.0); mix(d, low, 0.5)
	norm(d, 0.6)
	return d

static func super_grunt() -> PackedFloat32Array:
	var r := rng(205)
	var d := buf(0.7)
	var ph := 0.0
	for i in d.size():
		var t := float(i) / SR
		ph += TAU * (95.0 - t * 30.0) / SR
		var saw := 1.0 - 2.0 * fposmod(ph / TAU, 1.0)
		d[i] = saw * exp(-t / 0.25) * minf(1.0, t * 40.0)
	biquad(d, "bp", 420.0, 1.2); biquad(d, "lp", 1500.0)
	var n := white(d.size(), r); env_ad(n, 0.01, 0.12); biquad(n, "bp", 900.0, 2.0); mix(d, n, 0.3)
	sat(d, 2.5)
	norm(d, 0.8)
	return d

## Nails on skin, slowly.
static func super_scratch() -> PackedFloat32Array:
	var r := rng(206)
	var d := buf(1.6)
	for k in 4:
		var at := k * 0.36
		grains(d, at, at + 0.22, 40, 2500.0, 6000.0, 1.2, r, 0.5, true)
	biquad(d, "lp", 7000.0)
	norm(d, 0.5)
	return d

## A ring of keys on a cord, against a body.
static func keys() -> PackedFloat32Array:
	var r := rng(207)
	var d := buf(0.9)
	for k in 9:
		var t := r.randf_range(0.0, 0.6)
		var f := r.randf_range(2800.0, 5200.0)
		strike(d, t, [f, f * 1.37, f * 2.21], [0.05, 0.03, 0.02], [0.4, 0.25, 0.12], r, 0.0002, r.randf_range(0.3, 0.8))
	norm(d, 0.5)
	return d

## The lift: steel cable over a wheel, the cage grinding in its guides. Two seconds of it.
static func lift_grind() -> PackedFloat32Array:
	var r := rng(208)
	var d := buf(2.0)
	friction(d, 0.0, 1.9, func(k): return 40.0 + sin(k * 7.0) * 6.0, [[160.0, 6.0, 1.0], [460.0, 8.0, 0.6], [1250.0, 10.0, 0.25]], r, 1.0, 0.2)
	var hum := brown(d.size(), r); biquad(hum, "lp", 90.0); mix(d, hum, 0.8)
	env_ad(d, 0.2, 1.4)
	norm(d, 0.7)
	return d

## The lift's doors: a shove of sheet steel, the rattle of the rollers, the clang.
static func lift_doors() -> PackedFloat32Array:
	var r := rng(209)
	var d := buf(1.4)
	friction(d, 0.0, 0.9, func(_k): return 70.0, [[700.0, 4.0, 1.0], [1700.0, 6.0, 0.4]], r, 0.7, 0.3)
	strike(d, 0.95, [210, 520, 1130, 2300], [0.2, 0.12, 0.07, 0.04], [1.0, 0.6, 0.35, 0.2], r, 0.0008)
	norm(d, 0.7)
	return d

## A radiator coming up to heat: the ticks of the iron expanding, a far knock in the pipe.
static func radiator() -> PackedFloat32Array:
	var r := rng(210)
	var d := buf(1.8)
	for k in 6:
		var t := r.randf_range(0.0, 1.5)
		strike(d, t, [1400.0 + r.randf() * 600.0, 3300.0], [0.03, 0.015], [0.4, 0.2], r, 0.0003, r.randf_range(0.3, 0.9))
	strike(d, 0.9, [212, 589], [0.4, 0.25], [0.5, 0.3], r, 0.002, 0.4)
	biquad(d, "lp", 5000.0)
	norm(d, 0.45)
	return d

## The boiler, lit: a low roar in its firebox, the casing ticking. Loops.
static func boiler_loop() -> PackedFloat32Array:
	var r := rng(211)
	var n := int(6.0 * SR)
	var d := brown(n, r); biquad(d, "lp", 260.0)
	var roar := pink(n, r); biquad(roar, "bp", 380.0, 0.8)
	for i in n: d[i] = d[i] * 0.9 + roar[i] * (0.35 + 0.1 * sin(float(i) / SR * 1.7))
	norm(d, 0.55)
	return d

## Something small with too many joints in the ductwork: claws on sheet metal, fast.
static func vent_scrabble() -> PackedFloat32Array:
	var r := rng(212)
	var d := buf(1.4)
	var t := 0.0
	while t < 1.2:
		strike(d, t, [1900.0 + r.randf() * 900.0, 4100.0], [0.02, 0.012], [0.35, 0.2], r, 0.0002, r.randf_range(0.4, 1.0))
		thump(d, t, 260.0, 0.02, 0.15, 0.3)
		t += r.randf_range(0.03, 0.09)
	biquad(d, "lp", 6000.0)
	norm(d, 0.6)
	return d

## What's in the bath, breathing: slow, huge, through water.
static func bath_breath() -> PackedFloat32Array:
	var r := rng(213)
	var d := buf(4.0)
	var b := brown(d.size(), r); biquad(b, "lp", 220.0)
	for i in d.size():
		var t := float(i) / SR
		var k := maxf(0.0, sin(t * TAU / 4.0))
		d[i] = b[i] * (0.25 + 1.2 * k)
	var wet := pink(d.size(), r); biquad(wet, "bp", 700.0, 3.0)
	for i in d.size(): wet[i] *= maxf(0.0, sin(float(i) / SR * TAU / 4.0)) * 0.5
	mix(d, wet, 0.6)
	norm(d, 0.6)
	return d

## Meat coming apart: fibres tearing, a wet give with no comedy in it.
static func flesh_tear() -> PackedFloat32Array:
	var r := rng(214)
	var d := buf(0.9)
	friction(d, 0.0, 0.6, func(k): return 120.0 + k * 200.0, [[650.0, 2.5, 1.0], [1800.0, 4.0, 0.5]], r, 0.8, 0.5)
	var w := white(int(0.6 * SR), r); env_ad(w, 0.02, 0.15); biquad(w, "bp", 1100.0, 1.2); mix(d, w, 0.4)
	thump(d, 0.0, 80.0, 0.1, 0.4, 0.2)
	norm(d, 0.7)
	return d

# ================================================================== Flat 27 (docs/CATHEDRAL.md)
## The cathedral: an organ's lowest pipe held forever, and a fifth above it that won't settle;
## under it a choir with no words, far off, breathing in and out of tune; air moving in a space
## too big for a building. Loops. Steady: nothing pulses.
static func cath_bed() -> PackedFloat32Array:
	var r := rng(271)
	var n := int(20.0 * SR)
	var d := PackedFloat32Array(); d.resize(n)
	var ph := [0.0, 0.0, 0.0, 0.0]
	var fs := [32.7, 49.05, 65.4, 98.3]
	for i in n:
		var t := float(i) / SR
		var v := 0.0
		for k in 4:
			ph[k] += TAU * fs[k] * (1.0 + 0.0015 * sin(t * (0.05 + k * 0.013) * TAU)) / SR
			v += (sin(ph[k]) + 0.35 * sin(ph[k] * 2.0) + 0.15 * sin(ph[k] * 3.0)) * [0.22, 0.12, 0.08, 0.05][k]
		d[i] = v
	# the choir: breath through vowel formants, swelling slowly
	for f in [[520.0, 1.0], [880.0, 0.7], [1180.0, 0.5]]:
		var c := pink(n, r); biquad(c, "bp", f[0], 6.0); biquad(c, "bp", f[0], 6.0)
		for i in n:
			var t := float(i) / SR
			c[i] *= (0.55 + 0.45 * sin(t * TAU / 20.0 + f[0])) * f[1]
		mix(d, c, 0.35)
	var air := brown(n, r); biquad(air, "lp", 120.0); mix(d, air, 0.6)
	norm(d, 0.5)
	return d

## A great bell, struck once: the hum, the strike note, the minor third that makes a bell sound
## like a bell, all decaying for seconds.
static func bell_toll() -> PackedFloat32Array:
	var r := rng(272)
	var d := buf(9.0)
	strike(d, 0.0, [110.0, 220.0, 262.0, 330.0, 440.0, 587.0, 880.0], [7.0, 5.5, 4.5, 3.5, 2.5, 1.8, 1.0], [0.6, 0.8, 0.5, 0.35, 0.3, 0.2, 0.12], r, 0.002, 1.0)
	thump(d, 0.0, 60.0, 0.3, 0.5, 0.2)
	norm(d, 0.85)
	return d

## A bell rung out of turn: it clanks, dead, and the clapper rattles.
static func bell_dull() -> PackedFloat32Array:
	var r := rng(273)
	var d := buf(1.4)
	strike(d, 0.0, [180.0, 410.0, 690.0], [0.5, 0.3, 0.2], [0.7, 0.4, 0.3], r, 0.004, 1.0)
	strike(d, 0.09, [300.0, 620.0], [0.2, 0.12], [0.3, 0.2], r, 0.003, 0.5)
	biquad(d, "lp", 1800.0)
	norm(d, 0.7)
	return d

## A hammer on a nail, the nail going into wood through something that isn't wood.
static func nail_strike() -> PackedFloat32Array:
	var r := rng(274)
	var d := buf(1.0)
	strike(d, 0.0, [1850.0, 3100.0, 4700.0], [0.25, 0.15, 0.08], [0.6, 0.35, 0.2], r, 0.0008, 1.0)
	thump(d, 0.0, 85.0, 0.18, 0.9, 0.3)
	var wet := pink(int(0.3 * SR), r); biquad(wet, "bp", 700.0, 1.5); env_ad(wet, 0.005, 0.2)
	mix(d, wet, 0.5, int(0.01 * SR))
	sat(d, 1.4)
	norm(d, 0.9)
	return d

## His breath on the cross: shallow, through the teeth, catching at the top.
static func stig_breath() -> PackedFloat32Array:
	var r := rng(275)
	var d := buf(3.2)
	for k in 3:
		var at := k * 1.0
		var b := pink(int(0.7 * SR), r)
		biquad(b, "bp", 2100.0 if k % 2 == 0 else 1500.0, 2.0)
		for i in b.size():
			var t := float(i) / SR
			b[i] *= sin(minf(1.0, t / 0.65) * PI) * (1.0 if t < 0.5 else 0.3)
		mix(d, b, 0.8, int(at * SR))
	norm(d, 0.45)
	return d
