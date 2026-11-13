extends Node
## Sounds (autoload "Sfx"). Nothing is recorded: every sound is synthesised by the generators at
## the bottom of this file (filtered noise, struck resonances, stick-slip friction, buzzing
## pulses), then baked once into assets/audio/*.wav by tools/bake_audio.gd so a phone doesn't
## spend its start-up synthesising. If a baked file is missing the sound is made on the spot.
##
## World sounds go through the "World" bus, which has the room's reverb (levels set its size and
## wetness); a sound with a wall between it and Kurt is muffled and quieter, and looping sounds
## are re-checked as he moves. Voices and the player's own body are dry.

const RATE := 22050
const BAKED := "res://assets/audio/"
var streams := {}
var _loops := {}
var _rng := RandomNumberGenerator.new()
var _occ_t := 0.0
var world_bus := 0
var reverb: AudioEffectReverb
var amb_bus := 0
var _lowpass: Array[AudioEffectLowPassFilter] = []
var _duck := 0.0        # dB the world is down by, now
var _stress := 0.0      # 0..1, how close she is: the world goes thick around him

## Every sound, by name: [seconds, generator, looped]
var GEN := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1996
	_buses()
	_define()
	for name in GEN:
		var path: String = BAKED + name + ".wav"
		if ResourceLoader.exists(path):
			var st = load(path)
			var spec: Array = GEN[name]
			if st is AudioStreamWAV and spec.size() > 2 and spec[2]:
				st.loop_mode = AudioStreamWAV.LOOP_FORWARD; st.loop_begin = 0; st.loop_end = int(st.get_length() * st.mix_rate)
			streams[name] = st

func _buses() -> void:
	world_bus = AudioServer.get_bus_index("World")
	if world_bus < 0:
		AudioServer.add_bus(); world_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(world_bus, "World"); AudioServer.set_bus_send(world_bus, "Master")
		reverb = AudioEffectReverb.new()
		reverb.room_size = 0.55; reverb.damping = 0.7; reverb.wet = 0.22; reverb.dry = 0.9; reverb.spread = 0.8
		AudioServer.add_bus_effect(world_bus, reverb)
		var comp := AudioEffectCompressor.new(); comp.threshold = -14.0; comp.ratio = 4.0
		AudioServer.add_bus_effect(0, comp)
	# the beds (room tone, wind, the maze's breathing): dry, ducked with the world
	amb_bus = AudioServer.get_bus_index("Amb")
	if amb_bus < 0:
		AudioServer.add_bus(); amb_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(amb_bus, "Amb"); AudioServer.set_bus_send(amb_bus, "Master")
	for b in [world_bus, amb_bus]:
		var lp := AudioEffectLowPassFilter.new(); lp.cutoff_hz = 20000.0; lp.resonance = 0.5
		AudioServer.add_bus_effect(b, lp); _lowpass.append(lp)

## The room: small and hard (the flat), or big and wet (the flesh).
func set_room(size: float, wet: float, damping := 0.7) -> void:
	if reverb: reverb.room_size = size; reverb.wet = wet; reverb.damping = damping

# ------------------------------------------------------------------ playing
func _pick(name: String) -> AudioStream:
	# variants: step_wood -> step_wood0..2
	if not GEN.has(name) and GEN.has(name + "0"):
		var nv := 0
		while GEN.has(name + str(nv)): nv += 1
		name = name + str(_rng.randi_range(0, nv - 1))
	if not streams.has(name) and GEN.has(name): streams[name] = synth(name)   # not baked: make it now
	return streams.get(name)

## Where world sounds live: the level (even while it's still being built), else the scene.
func _scene() -> Node3D:
	var g = get_node_or_null("/root/Game")
	if g and g.level and is_instance_valid(g.level) and g.level is Node3D: return g.level
	var cs := get_tree().current_scene
	return cs if cs is Node3D else null

## A sound with no position (UI, the player's own body, voices).
func play(name: String, vol_db := 0.0, pitch := 1.0) -> AudioStreamPlayer:
	var s := _pick(name)
	if not s: return null
	var p := AudioStreamPlayer.new()
	p.stream = s; p.volume_db = vol_db; p.pitch_scale = pitch
	add_child(p); p.play()
	p.finished.connect(p.queue_free)
	return p

## A sound somewhere in the world: reverberant, muffled if there's a wall in the way.
func play_at(name: String, pos: Vector3, vol_db := 0.0, pitch := 1.0, range_m := 20.0) -> void:
	var scene := _scene()
	var s := _pick(name)
	if not s or not scene: return
	var p := AudioStreamPlayer3D.new()
	p.stream = s; p.volume_db = vol_db; p.pitch_scale = pitch
	p.max_distance = range_m; p.unit_size = 3.0; p.bus = "World"
	p.attenuation_filter_db = -6.0
	scene.add_child(p); p.global_position = pos
	_occlude(p)
	p.play()
	p.finished.connect(p.queue_free)

## A looping sound, at a place (pos) or everywhere (pos null). One per key.
func loop(key: String, name: String, vol_db := 0.0, pos = null, parent: Node = null) -> void:
	stop_loop(key)
	var s := _pick(name)
	if not s: return
	if pos == null:
		var a := AudioStreamPlayer.new(); a.stream = s; a.volume_db = vol_db; a.bus = "Amb"
		add_child(a); a.play(); _loops[key] = a
	else:
		var a := AudioStreamPlayer3D.new(); a.stream = s; a.volume_db = vol_db; a.unit_size = 2.5; a.max_distance = 16.0; a.bus = "World"
		var host: Node = parent if parent else _scene()
		if not host: return
		host.add_child(a); a.global_position = pos; a.play()
		a.play(_rng.randf() * maxf(0.0, s.get_length() - 0.1))
		a.set_meta("db", vol_db)
		_loops[key] = a
		_occlude(a)

func set_loop_volume(key: String, db: float) -> void:
	if _loops.has(key) and is_instance_valid(_loops[key]):
		_loops[key].volume_db = db; _loops[key].set_meta("db", db)

func set_loop_pitch(key: String, p: float) -> void:
	if _loops.has(key) and is_instance_valid(_loops[key]): _loops[key].pitch_scale = p

func stop_loop(key: String) -> void:
	if _loops.has(key) and is_instance_valid(_loops[key]): _loops[key].queue_free()
	_loops.erase(key)

func stop_loops() -> void:
	for k in _loops.keys(): stop_loop(k)

## A syllable of someone's voice (Dialogue calls this as the line types).
func syllable(who: String) -> void:
	var key := "v_%s%d" % [who, _rng.randi_range(0, 3)]
	if GEN.has(key):
		play(key, -6.0 if who == "socko" else (-4.0 if who == "marta" else -9.0), _rng.randf_range(0.9, 1.12) if who != "marta" else _rng.randf_range(0.8, 0.95))

## Walls between Kurt and a sound: the more solid the way, the duller and quieter.
func _occlude(p: AudioStreamPlayer3D) -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam or not p.is_inside_tree(): return
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, p.global_position, 1)
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	var blocked: bool = not hit.is_empty() and (hit.position as Vector3).distance_to(p.global_position) > 0.3
	p.attenuation_filter_cutoff_hz = 900.0 if blocked else 9000.0
	var db: float = p.get_meta("db", p.volume_db)
	if p.has_meta("db"): p.volume_db = db - (5.0 if blocked else 0.0)

## The mix: the world steps back while someone talks (6 dB, eased), and closes in around him
## as she gets near (a low-pass sliding from open to 1.5 kHz inside 10 m of her).
func _mix(delta: float) -> void:
	var dlg = get_node_or_null("/root/Dialogue")
	var want_duck := -6.0 if dlg and dlg.get("busy") else 0.0
	_duck = move_toward(_duck, want_duck, delta * (24.0 if want_duck < _duck else 8.0))
	var want_stress := 0.0
	var g = get_node_or_null("/root/Game")
	var cam := get_viewport().get_camera_3d()
	if g and g.level and is_instance_valid(g.level) and cam:
		var m = g.level.get("marta")
		if m and is_instance_valid(m) and m is Node3D and m.is_inside_tree() and m.get("active") != false:
			want_stress = clampf(1.0 - cam.global_position.distance_to(m.global_position) / 10.0, 0.0, 1.0)
	_stress = move_toward(_stress, want_stress, delta * 0.8)
	for b in [world_bus, amb_bus]: AudioServer.set_bus_volume_db(b, _duck)
	for lp in _lowpass: lp.cutoff_hz = lerpf(20000.0, 1500.0, pow(_stress, 0.7))

func _process(delta: float) -> void:
	_mix(delta)
	_occ_t -= delta
	if _occ_t <= 0.0:
		_occ_t = 0.25
		for k in _loops:
			if is_instance_valid(_loops[k]) and _loops[k] is AudioStreamPlayer3D: _occlude(_loops[k])

# ------------------------------------------------------------------ synthesis
func synth(name: String) -> AudioStreamWAV:
	var spec: Array = GEN[name]
	var looped: bool = spec.size() > 2 and spec[2]
	var rate := RATE
	var d: PackedFloat32Array
	if spec.size() > 3:
		# SoundLib: the generator makes its own buffer at its own rate
		rate = int(spec[3]); d = (spec[1] as Callable).call()
	else:
		d = PackedFloat32Array(); d.resize(int(float(spec[0]) * RATE))
		(spec[1] as Callable).call(d)
	var n := d.size()
	var fade := int(0.05 * rate)
	if looped and spec.size() > 3:
		# seamless: the tail cross-fades (equal power) into the head, then is cut off
		var xf := mini(int(0.6 * rate), n / 3)
		for i in xf:
			var k := float(i) / xf
			d[i] = d[i] * sqrt(k) + d[n - xf + i] * sqrt(1.0 - k)
		n -= xf; d.resize(n)
	elif spec.size() > 3:
		# a one-shot ends at silence (no click) and under full scale
		var tail := mini(int(0.02 * rate), n)
		for i in tail: d[n - 1 - i] *= float(i) / tail
		for i in n: d[i] *= 0.97
	var data := PackedByteArray(); data.resize(n * 2)
	for i in n:
		var v := clampf(d[i], -1.0, 1.0)
		if looped and spec.size() <= 3: v *= minf(1.0, float(mini(i, n - 1 - i)) / fade)
		data.encode_s16(i * 2, int(v * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS; s.mix_rate = rate; s.stereo = false; s.data = data
	if looped:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD; s.loop_begin = 0; s.loop_end = n
	return s

func _nz() -> float: return _rng.randf_range(-1.0, 1.0)
func _env(t: float, a: float, dcy: float) -> float: return t / a if t < a else exp(-(t - a) / dcy)

static func lp(d: PackedFloat32Array, a: float) -> void:
	var y := 0.0
	for i in d.size(): y += a * (d[i] - y); d[i] = y

static func hp(d: PackedFloat32Array, a: float) -> void:
	var y := 0.0; var x0 := 0.0
	for i in d.size():
		var x := d[i]; y = a * (y + x - x0); x0 = x; d[i] = y

## Resonant band-pass (2-pole), the workhorse: makes noise into wood, metal, wind, flies.
static func bp(d: PackedFloat32Array, f: float, q: float) -> void:
	var w := TAU * f / RATE; var al := sin(w) / (2.0 * q)
	var b0 := al; var a0 := 1.0 + al; var a1 := -2.0 * cos(w); var a2 := 1.0 - al
	var x1 := 0.0; var x2 := 0.0; var y1 := 0.0; var y2 := 0.0
	for i in d.size():
		var x := d[i]
		var y := (b0 * x - b0 * x2 - a1 * y1 - a2 * y2) / a0
		x2 = x1; x1 = x; y2 = y1; y1 = y; d[i] = y

static func norm(d: PackedFloat32Array, peak: float) -> void:
	var m := 0.0
	for v in d: m = maxf(m, absf(v))
	if m > 0.0:
		var k := peak / m
		for i in d.size(): d[i] *= k

func _thump(f: float, dec: float, click: float, amp: float) -> Callable:
	return func(d: PackedFloat32Array):
		for i in d.size():
			var t := float(i) / RATE
			d[i] = sin(TAU * f * t * (1.0 - t * 0.4)) * exp(-t / dec) + _nz() * exp(-t / click) * 0.6
		lp(d, 0.3); norm(d, amp)

func _metal(fs: Array, dec: float, amp: float) -> Callable:
	return func(d: PackedFloat32Array):
		for i in d.size():
			var t := float(i) / RATE; var v := 0.0
			for k in fs.size(): v += sin(TAU * float(fs[k]) * t) * exp(-t / (dec / (1.0 + k * 0.6))) / (1.0 + k)
			d[i] = v + _nz() * exp(-t / 0.003) * 0.5
		norm(d, amp)

func _step(lo: float, click: float, crunch: float, wet: float, amp: float) -> Callable:
	return func(d: PackedFloat32Array):
		for i in d.size():
			var t := float(i) / RATE
			d[i] = sin(TAU * lo * t) * exp(-t / 0.035) * 0.8 + _nz() * exp(-t / click) * 0.6
			if crunch > 0.0 and _rng.randf() < 0.06: d[i] += _nz() * exp(-t / 0.08) * crunch
		if wet > 0.0:
			var w := PackedFloat32Array(); w.resize(d.size())
			for i in d.size():
				var t := float(i) / RATE
				w[i] = _nz() * exp(-t / 0.09) * (0.5 + 0.5 * sin(t * 260.0))
			bp(w, 420.0, 1.4)
			for i in d.size(): d[i] = d[i] * (1.0 - wet * 0.6) + w[i] * wet * 3.0
		norm(d, amp)

func _define() -> void:
	GEN = {
		"knock": [0.32, _thump(95.0, 0.06, 0.006, 0.9)],
		"door_rattle": [0.5, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = (_nz() * 0.5 + sin(t * TAU * 180.0) * 0.3) * exp(-fposmod(t, 1.0 / 7.0) * 40.0) * exp(-t * 3.0)
			bp(d, 700.0, 0.8); norm(d, 0.6)],
		# stick-slip: a hinge squealing as it goes
		"door_creak": [1.3, func(d):
			var ph := 0.0; var f := 340.0 + _rng.randf() * 120.0
			for i in d.size():
				var t := float(i) / RATE
				f += _nz() * 3.0 + sin(t * 7.0) * 1.2; ph += f / RATE
				var stick := 1.0 if sin(t * (30.0 + sin(t * 3.0) * 12.0) * TAU) > 0.2 else 0.25
				d[i] = (sin(ph * TAU) * 0.6 + sin(ph * TAU * 2.01) * 0.3 + _nz() * 0.15) * stick * _env(t, 0.08, 0.6) * (1.0 if t < 1.1 else (1.3 - t) * 5.0)
			bp(d, 900.0, 0.7); norm(d, 0.45)],
		"door_slam": [0.9, _thump(60.0, 0.15, 0.02, 0.95)],
		"door_shut": [0.6, _thump(90.0, 0.09, 0.012, 0.8)],
		"switch": [0.12, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = (_nz() * 0.6 + sin(t * TAU * 1500.0)) * (exp(-t / 0.004) + (exp(-(t - 0.03) / 0.005) * 0.6 if t > 0.03 else 0.0))
			norm(d, 0.5)],
		"thud": [0.6, _thump(55.0, 0.12, 0.03, 1.0)],
		"thud_far": [1.2, _thump(40.0, 0.25, 0.05, 0.9)],
		"scrape": [1.4, func(d):
			for i in d.size():
				var t := float(i) / RATE
				var stick := 1.0 if sin(t * TAU * (6.0 + sin(t * 2.0) * 2.0)) > -0.2 else 0.2
				d[i] = _nz() * stick * minf(1.0, t * 8.0) * minf(1.0, (1.4 - t) * 4.0)
			lp(d, 0.06); norm(d, 0.85)],
		"squelch": [0.5, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = _nz() * sin(t * TAU * (90.0 + 160.0 * exp(-t * 6.0))) * exp(-t * 6.0)
			lp(d, 0.15); norm(d, 0.85)],
		"goo_loop": [3.0, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = _nz() * (0.35 + 0.35 * sin(t * TAU * 1.5) * sin(t * TAU * 0.5))
			lp(d, 0.05)
			for k in 9:
				var s0 := _rng.randi_range(0, d.size() - 6000)
				for j in 5000:
					var t := float(j) / RATE
					d[s0 + j] += sin(TAU * (300.0 * exp(-t * 30.0) + 120.0) * t) * exp(-t / 0.04) * 0.5
			norm(d, 0.6), true],
		"gunshot": [1.2, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = _nz() * exp(-t * 18.0) * 1.6 + sin(TAU * 80.0 * t * (1.0 - t * 0.4)) * exp(-t * 10.0) * 0.9
			var tail := PackedFloat32Array(); tail.resize(d.size())
			for i in d.size(): tail[i] = _nz() * exp(-float(i) / RATE * 2.2)
			lp(tail, 0.04)
			for i in d.size(): d[i] += tail[i] * 1.5
			norm(d, 0.98)],
		"dry_fire": [0.08, func(d):
			for i in d.size(): d[i] = _nz() * exp(-float(i) / RATE * 200.0)
			bp(d, 2600.0, 1.0); norm(d, 0.5)],
		"reload": [0.55, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = _nz() * exp(-fposmod(t, 0.27) * 120.0) + sin(TAU * 1400.0 * fposmod(t, 0.27)) * exp(-fposmod(t, 0.27) * 60.0) * 0.4
			bp(d, 1800.0, 0.8); norm(d, 0.6)],
		"pickup": [0.25, func(d):
			for i in d.size(): d[i] = _nz() * _env(float(i) / RATE, 0.02, 0.07)
			bp(d, 2500.0, 0.7); norm(d, 0.3)],
		"drawer": [0.55, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = _nz() * (0.5 * (0.6 + 0.4 * sin(t * 140.0)) if t < 0.4 else 0.0) * _env(t, 0.03, 0.4) + (sin(TAU * 140.0 * t) * exp(-(t - 0.4) / 0.03) if t > 0.4 else 0.0)
			bp(d, 600.0, 0.6); norm(d, 0.55)],
		"metal": [0.9, _metal([520.0, 1310.0, 2290.0, 3410.0], 0.25, 0.7)],
		"glass": [0.5, _metal([3200.0, 5100.0, 7300.0], 0.06, 0.5)],
		"bullet_hit": [0.35, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = _nz() * exp(-t * 35.0) + sin(TAU * 180.0 * t) * exp(-t * 30.0) * 0.6
			lp(d, 0.4); norm(d, 0.7)],
		"bullet_flesh": [0.45, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = _nz() * exp(-t * 12.0) * (1.0 + sin(t * 300.0))
			lp(d, 0.12); norm(d, 0.95)],
		# a struck iron pipe full of water: dull, ringing low
		"pipe_knock": [0.8, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = (sin(TAU * 165.0 * t) + sin(TAU * 412.0 * t) * 0.45 + sin(TAU * 797.0 * t) * 0.2) * exp(-t / 0.14) + _nz() * exp(-t / 0.004) * 0.8
			lp(d, 0.4); norm(d, 0.85)],
		"drip": [0.3, func(d):
			var ph := 0.0
			for i in d.size():
				var t := float(i) / RATE
				ph += (900.0 * exp(-t * 25.0) + 400.0) / RATE
				d[i] = sin(ph * TAU) * exp(-t / 0.05) + _nz() * exp(-t / 0.004) * 0.2
			norm(d, 0.45)],
		# the building: a long structural groan, a creak in the joists
		"groan": [3.5, func(d):
			var ph := 0.0
			for i in d.size():
				var t := float(i) / RATE
				ph += (48.0 + sin(t * 0.9) * 9.0 + _nz() * 3.0) / RATE
				d[i] = (sin(ph * TAU) + _nz() * 0.4) * _env(t, 1.0, 1.2)
			lp(d, 0.05); norm(d, 0.7)],
		"creak": [2.4, func(d):
			for i in d.size(): d[i] = _nz()
			var f0 := 70.0 + _rng.randf() * 60.0
			bp(d, f0, 6.0); bp(d, f0 * 1.02, 4.0)
			for i in d.size():
				var t := float(i) / RATE
				d[i] *= _env(t, 0.6, 0.9) * (0.6 + 0.4 * sin(t * 13.0))
			norm(d, 0.7)],
		"step_above": [0.35, _thump(55.0, 0.06, 0.02, 0.9)],
		# a two-tone siren a long way off, through the walls
		"siren": [7.0, func(d):
			var ph := 0.0
			for i in d.size():
				var t := float(i) / RATE
				var f := 620.0 + 180.0 * sin(t * TAU * 0.25)
				ph += f / RATE
				d[i] = (sin(ph * TAU) + sin(ph * TAU * 2.0) * 0.3) * minf(1.0, t * 0.5) * minf(1.0, (7.0 - t) * 0.5)
			lp(d, 0.08); norm(d, 0.5)],
		"wind": [6.0, func(d):
			for i in d.size(): d[i] = _nz()
			lp(d, 0.03)
			for i in d.size():
				var t := float(i) / RATE
				d[i] *= 0.4 + 0.6 * pow(maxf(0.0, sin(t * 0.9) * sin(t * 0.37 + 1.0)), 2.0)
			norm(d, 0.7), true],
		"paper": [0.4, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = _nz() * _env(t, 0.01, 0.12) * (1.0 if _rng.randf() < 0.3 else 0.3)
			hp(d, 0.9); norm(d, 0.3)],
		# the fluorescent tube: 100 Hz and its harmonics, a rattle in the choke
		"buzz": [2.0, func(d):
			for i in d.size():
				var t := float(i) / RATE
				var ph := fposmod(t * 100.0, 1.0)
				d[i] = (1.0 - 2.0 * ph) * 0.4 + sin(TAU * 200.0 * t) * 0.3 + _nz() * 0.05
			bp(d, 1200.0, 0.5); norm(d, 0.4), true],
		"hum": [2.0, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = sin(TAU * 50.0 * t) * 0.6 + sin(TAU * 100.0 * t) * 0.3 + sin(TAU * 150.0 * t) * 0.1 + _nz() * 0.02
			norm(d, 0.5), true],
		"tv_static": [2.0, func(d):
			for i in d.size(): d[i] = _nz() * (0.8 + 0.2 * sin(float(i) / RATE * TAU * 50.0))
			hp(d, 0.7); norm(d, 0.35), true],
		# the receiver off the hook in the hall: 425 Hz, on and off, for ever
		"busy_tone": [1.0, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = sin(TAU * 425.0 * t) * (1.0 if fposmod(t, 1.0) < 0.5 else 0.0)
			norm(d, 0.3), true],
		"flies": [3.0, func(d):
			for f in 3:
				var ph := 0.0; var base := 180.0 + f * 37.0
				for i in d.size():
					var t := float(i) / RATE
					ph += (base + sin(t * (3.0 + f) + f) * 30.0) / RATE
					d[i] += (1.0 - 2.0 * fposmod(ph, 1.0)) * (0.4 + 0.6 * absf(sin(t * (0.7 + f * 0.3) + f * 2.0)))
			bp(d, 600.0, 1.0); norm(d, 0.4), true],
		"tinnitus": [6.0, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = sin(TAU * 4100.0 * t) * exp(-t / 2.5) * minf(1.0, t * 20.0)
			norm(d, 0.25)],
		# the sting: a low cluster swelling, a metal shriek over it, cut off
		"sting": [3.2, func(d):
			var a := 0.0; var b := 0.0; var c := 0.0
			for i in d.size():
				var t := float(i) / RATE
				a += 55.0 / RATE; b += 58.3 / RATE; c += (1900.0 + sin(t * 13.0) * 300.0 + t * 400.0) / RATE
				var sw := minf(1.0, t / 0.15) * (1.0 if t < 2.6 else maxf(0.0, 1.0 - (t - 2.6) / 0.6))
				d[i] = sw * ((sin(a * TAU) + sin(b * TAU)) * 0.5 + sin(c * TAU) * 0.18 * minf(1.0, t / 0.6) + _nz() * 0.08)
			norm(d, 0.95)],
		"heartbeat": [0.9, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = (sin(TAU * 48.0 * t) * exp(-t / 0.06) if t >= 0.0 else 0.0) + (sin(TAU * 44.0 * (t - 0.22)) * exp(-(t - 0.22) / 0.07) * 0.7 if t > 0.22 else 0.0)
			lp(d, 0.2); norm(d, 0.9)],
		"heart_loop": [1.1, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = sin(TAU * 40.0 * t) * exp(-t / 0.07) + (sin(TAU * 37.0 * (t - 0.25)) * exp(-(t - 0.25) / 0.08) * 0.7 if t > 0.25 else 0.0)
			lp(d, 0.15); norm(d, 0.8), true],
		"gasp": [0.7, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = _nz() * pow(sin(PI * clampf(t / 0.7, 0.0, 1.0)), 0.5) * (1.0 if t < 0.35 else 0.5)
			bp(d, 1100.0, 0.9); norm(d, 0.6)],
		"breath": [1.6, func(d):
			for i in d.size(): d[i] = _nz() * pow(sin(minf(1.0, float(i) / RATE / 1.6) * PI), 2.0)
			bp(d, 900.0, 0.8); norm(d, 0.35)],
		"pant": [1.4, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = _nz() * pow(maxf(0.0, sin(t * TAU / 0.7)), 2.0) * (1.0 if fposmod(t, 0.7) < 0.35 else 0.6)
			bp(d, 800.0, 0.7); norm(d, 0.4), true],
		# a scream: torn, two voices a semitone apart, a whistle in the throat, sliding down
		"marta_scream": [1.6, func(d):
			var a := 0.0; var b := 0.0; var w := 0.0
			for i in d.size():
				var t := float(i) / RATE
				var f := 520.0 - t * 160.0 + sin(t * 31.0) * 25.0 + _nz() * 30.0
				a += f / RATE; b += f * 1.06 / RATE; w += (2400.0 - t * 600.0) / RATE
				var saw := (1.0 - 2.0 * fposmod(a, 1.0)) * 0.6 + (1.0 - 2.0 * fposmod(b, 1.0)) * 0.5
				d[i] = (saw + _nz() * 0.7 + sin(w * TAU) * 0.15) * minf(1.0, t * 12.0) * minf(1.0, (1.6 - t) * 2.5)
			bp(d, 1300.0, 0.6); norm(d, 0.95)],
		# something swung through the air: a short rush of noise, rising then falling
		"whoosh": [0.32, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = _nz() * sin(PI * clampf(t / 0.3, 0.0, 1.0)) * (0.5 + 0.5 * sin(t * 30.0))
			bp(d, 900.0, 0.8); norm(d, 0.7)],
		# a joint going: dry, sharp, a crunch after
		"bone_crack": [0.25, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = _nz() * exp(-t * 90.0) + (_nz() * 0.5 * exp(-(t - 0.04) * 60.0) if t > 0.04 else 0.0) + sin(TAU * 900.0 * t) * exp(-t * 120.0) * 0.4
			hp(d, 0.6); norm(d, 0.8)],
		"sniff": [0.6, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = _nz() * (exp(-fposmod(t, 0.18) * 25.0) if t < 0.5 else 0.0)
			bp(d, 3000.0, 1.2); norm(d, 0.5)],
		# her breath: wet, rattling in a throat full of something, a catch on the way in
		"marta_rattle": [3.2, func(d):
			for i in d.size():
				var t := float(i) / RATE
				var ph := fposmod(t, 3.2) / 3.2
				var env := pow(sin(PI * clampf(ph / 0.45, 0.0, 1.0)), 2.0) + 0.7 * pow(sin(PI * clampf((ph - 0.5) / 0.4, 0.0, 1.0)), 2.0) * float(ph > 0.5)
				var rattle: float = 0.5 + 0.5 * sign(sin(TAU * (22.0 + sin(t * 3.0) * 6.0) * t))
				d[i] = _nz() * env * (0.4 + 0.6 * rattle)
			bp(d, 380.0, 1.3); norm(d, 0.65), true],
		"marta_breath": [2.4, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = _nz() * pow(sin(PI * clampf(t / 2.4, 0.0, 1.0)), 2.0) * (1.0 + 0.6 * sin(t * 47.0))
			bp(d, 500.0, 1.5); norm(d, 0.5), true],
		"click": [0.05, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = (_nz() * 0.5 + sin(t * TAU * 2400.0)) * exp(-t / 0.006)
			norm(d, 0.6)],
		"whisper": [2.6, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = _nz() * maxf(0.0, sin(t * TAU * 4.3 + sin(t * 3.0) * 2.0)) * _env(t, 0.4, 1.0)
			bp(d, 2400.0, 2.0); norm(d, 0.35)],
		"crawl": [1.2, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = _nz() * (0.4 + 0.6 * absf(sin(t * TAU * 1.6)))
			lp(d, 0.2); norm(d, 0.8)],
		"flesh_drone": [6.0, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = sin(TAU * 33.0 * t + sin(t * TAU * 0.5) * 3.0) * 0.4 + _nz() * 0.3
			lp(d, 0.03)
			for i in d.size(): d[i] *= 0.6 + 0.4 * sin(float(i) / RATE * TAU * 0.333)
			norm(d, 0.7), true],
		"drone": [6.0, func(d):
			for i in d.size():
				var t := float(i) / RATE
				d[i] = sin(TAU * 41.0 * t) * 0.25 + sin(TAU * 61.5 * t) * 0.12 + _nz() * 0.5
			lp(d, 0.02)
			for i in d.size(): d[i] *= 0.7 + 0.3 * sin(float(i) / RATE * TAU / 6.0)
			norm(d, 0.6), true],
		"step_wood0": [0.22, _step(95.0, 0.01, 0.0, 0.0, 0.5)], "step_wood1": [0.22, _step(88.0, 0.012, 0.0, 0.0, 0.5)], "step_wood2": [0.22, _step(102.0, 0.009, 0.0, 0.0, 0.5)],
		"step_lino0": [0.2, _step(120.0, 0.006, 0.0, 0.0, 0.35)], "step_lino1": [0.2, _step(130.0, 0.005, 0.0, 0.0, 0.35)], "step_lino2": [0.2, _step(115.0, 0.007, 0.0, 0.0, 0.35)],
		"step_tile0": [0.2, _step(160.0, 0.004, 0.2, 0.0, 0.45)], "step_tile1": [0.2, _step(170.0, 0.004, 0.2, 0.0, 0.45)], "step_tile2": [0.2, _step(150.0, 0.004, 0.2, 0.0, 0.45)],
		"step_concrete0": [0.25, _step(110.0, 0.008, 0.6, 0.0, 0.5)], "step_concrete1": [0.25, _step(104.0, 0.008, 0.6, 0.0, 0.5)], "step_concrete2": [0.25, _step(116.0, 0.008, 0.6, 0.0, 0.5)],
		"step_soft0": [0.2, _step(80.0, 0.02, 0.0, 0.0, 0.25)], "step_soft1": [0.2, _step(76.0, 0.02, 0.0, 0.0, 0.25)], "step_soft2": [0.2, _step(84.0, 0.02, 0.0, 0.0, 0.25)],
		"step_flesh0": [0.32, _step(60.0, 0.02, 0.0, 0.8, 0.6)], "step_flesh1": [0.32, _step(56.0, 0.02, 0.0, 0.9, 0.6)], "step_flesh2": [0.32, _step(64.0, 0.02, 0.0, 0.7, 0.6)],
		"board_creak0": [0.5, _board()], "board_creak1": [0.5, _board()],
	}
	# Everything but the voices and Marta's own sounds comes from SoundLib (docs/SOUND.md)
	var L: int = SoundLib.SR
	var lib := {
		"knock": SoundLib.knock, "door_rattle": SoundLib.door_rattle, "door_creak": SoundLib.door_creak,
		"door_slam": SoundLib.door_slam, "door_shut": SoundLib.door_shut, "switch": SoundLib.switch_click,
		"thud": SoundLib.thud.bind(false), "thud_far": SoundLib.thud.bind(true), "scrape": SoundLib.scrape,
		"squelch": SoundLib.squelch, "gunshot": SoundLib.gunshot, "dry_fire": SoundLib.dry_fire,
		"reload": SoundLib.reload, "pickup": SoundLib.pickup, "drawer": SoundLib.drawer,
		"metal": SoundLib.metal_hit, "glass": SoundLib.glass_break, "bullet_hit": SoundLib.bullet_hit,
		"bullet_flesh": SoundLib.bullet_flesh, "pipe_knock": SoundLib.pipe_knock, "drip": SoundLib.drip,
		"groan": SoundLib.groan, "creak": SoundLib.creak, "step_above": SoundLib.step_above,
		"siren": SoundLib.siren, "paper": SoundLib.paper, "sting": SoundLib.sting,
		"heartbeat": SoundLib.heartbeat, "whoosh": SoundLib.whoosh, "bone_crack": SoundLib.bone_crack,
		"crawl": SoundLib.crawl, "tinnitus": SoundLib.tinnitus,
		# Chapter 2
		"washer": SoundLib.washer, "stove": SoundLib.stove, "super_breath": SoundLib.super_breath, "super_grunt": SoundLib.super_grunt,
		"super_scratch": SoundLib.super_scratch, "keys": SoundLib.keys, "lift_grind": SoundLib.lift_grind, "lift_doors": SoundLib.lift_doors,
		"radiator": SoundLib.radiator, "vent_scrabble": SoundLib.vent_scrabble, "bath_breath": SoundLib.bath_breath, "flesh_tear": SoundLib.flesh_tear,
	}
	var lib_loops := {
		"goo_loop": SoundLib.goo, "wind": SoundLib.wind, "buzz": SoundLib.tube_buzz, "hum": SoundLib.fridge,
		"tv_static": SoundLib.tv_static, "busy_tone": SoundLib.busy_tone, "flies": SoundLib.flies,
		"heart_loop": SoundLib.heart_loop, "flesh_drone": SoundLib.flesh_bed, "drone": SoundLib.room_tone,
		"lobby_bed": SoundLib.lobby_bed, "boiler_loop": SoundLib.boiler_loop,
	}
	for k in lib: GEN[k] = [0.0, lib[k], false, L]
	for k in lib_loops: GEN[k] = [0.0, lib_loops[k], true, L]
	for surf in ["wood", "lino", "tile", "concrete", "soft", "flesh"]:
		for v in 4: GEN["step_%s%d" % [surf, v]] = [0.0, SoundLib.step.bind(surf, v), false, L]
	for v in 3: GEN["board_creak%d" % v] = [0.0, SoundLib.board_creak.bind(v), false, L]
	for i in 4:
		var f0 := 300.0 + i * 37.0
		GEN["v_socko%d" % i] = [0.09, _voice(f0, 0.09, 0.55, 0.35, 1.3)]
		GEN["v_kurt%d" % i] = [0.12, _voice(105.0 + i * 9.0, 0.12, 0.25, 0.6, 1.0)]
		GEN["v_marta%d" % i] = [0.24, _marta_voice(i)]
		GEN["v_super%d" % i] = [0.15, _voice(74.0 + i * 5.0, 0.15, 0.3, 0.8, 0.55)]     # (low, breathy, close)

func _board() -> Callable:
	return func(d):
		var ph := 0.0; var f := 220.0 + _rng.randf() * 200.0
		for i in d.size():
			var t := float(i) / RATE
			f += _nz() * 2.0; ph += f / RATE
			d[i] = sin(ph * TAU) * _env(t, 0.06, 0.15) * (1.0 if sin(t * TAU * 45.0) > 0.0 else 0.3)
		bp(d, 500.0, 1.0); norm(d, 0.25)

## Marta's voice: a creaking vocal fry far too low for her, the pitch catching and slipping, a
## whisper of the same syllable under it, and a ring-modulated overtone that makes it wrong.
func _marta_voice(i: int) -> Callable:
	return func(d):
		var dur := 0.24
		var ph := 0.0
		var fry := PackedFloat32Array(); fry.resize(d.size())
		var wh := PackedFloat32Array(); wh.resize(d.size())
		var jitter := 0.0
		for k in d.size():
			var t := float(k) / RATE
			if k % 200 == 0: jitter = _rng.randf_range(-0.35, 0.35)
			ph += (48.0 + i * 6.0) * (1.0 + jitter) / RATE
			var pulse := exp(-fposmod(ph, 1.0) * 14.0)          # creak: separate glottal clicks
			fry[k] = pulse * (1.0 if _rng.randf() > 0.08 else 0.0)
			wh[k] = _nz()
		var f1 := fry.duplicate(); bp(f1, 600.0 + i * 70.0, 2.5)
		var f2 := fry.duplicate(); bp(f2, 1500.0 + i * 120.0, 3.0)
		bp(wh, 2200.0 + i * 150.0, 1.5)
		for k in d.size():
			var t := float(k) / RATE
			var env := sin(PI * clampf(t / dur, 0.0, 1.0))
			var ring := sin(TAU * (173.0 + i * 11.0) * t)
			d[k] = ((f1[k] + f2[k] * 0.7) * (0.75 + 0.25 * ring) + wh[k] * 0.35) * env
		norm(d, 0.85)

## A voiced syllable: a buzzy pulse through two formants, with breath.
func _voice(f0: float, dur: float, buzz: float, breath: float, bright: float) -> Callable:
	return func(d):
		var a := PackedFloat32Array(); a.resize(d.size())
		for i in d.size():
			var t := float(i) / RATE
			var ph := fposmod(t * f0 * (1.0 + 0.15 * t / dur), 1.0)
			a[i] = ((1.0 - 2.0 * ph) * buzz + sin(TAU * ph) * (1.0 - buzz)) * 0.8 + _nz() * breath * 0.4
		var b := a.duplicate()
		bp(a, 700.0 * bright, 3.0); bp(b, 1700.0 * bright, 4.0)
		for i in d.size():
			var t := float(i) / RATE
			d[i] = (a[i] + b[i] * 0.6) * sin(PI * clampf(t / dur, 0.0, 1.0))
		norm(d, 0.8)
