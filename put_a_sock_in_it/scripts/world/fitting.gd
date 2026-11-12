class_name Fitting
extends Node3D
## A light fitting: the light, the thing that glows (bulb, tube, shade, screen), and how it
## behaves. Kinds: "steady", "bulb" (old filament, wavers), "dying" (cuts out), "fluoro" (strikes
## and stutters, buzzes), "candle", "tv" (jumps about), "pulse" (the flesh: a slow heartbeat).
## Mains lights share the building's supply, which sags now and then: everything on it dims
## together, then comes back. A fitting can be switched (Hotspot switches call toggle()).

static var _brown := 1.0
static var _brown_t := 30.0
static var _frame := -1

var light: Light3D
var kind := "steady"
var mains := true
var on := true
var base := 1.0
var glow: Array = []          # [material, emission colour] pairs that follow the light
var buzz_key := ""
var _t := 0.0
var _hold := 0.0
var _state := 1.0
var _startup := 0.0
var _k := 1.0
var _dip := 1.0
var near := 1.0               # 0..1: faded out when Kurt is far from its room (light budget)
var room := ""

## Wrap a light that already exists (the exported flat's), giving it a character.
static func wrap(l: Light3D, kind_name: String, on_mains: bool) -> Fitting:
	var f := Fitting.new(); f.kind = kind_name; f.mains = on_mains
	var parent := l.get_parent(); var xf := l.global_transform
	parent.add_child(f); f.global_transform = Transform3D(Basis(), xf.origin)
	l.reparent(f, true)
	f.light = l; f.base = l.light_energy
	return f

## A point light with a glowing fixture. `shadow` only if the quality setting allows it.
static func make(parent: Node, pos: Vector3, color: Color, energy: float, range_m: float, kind_name := "steady", shadow := false) -> Fitting:
	var f := Fitting.new()
	f.kind = kind_name
	var l := OmniLight3D.new()
	l.light_color = color; l.light_energy = energy; l.omni_range = range_m; l.omni_attenuation = 1.3
	l.shadow_enabled = shadow and bool(Game.settings.get("shadows", true))
	l.shadow_bias = 0.06; l.shadow_normal_bias = 1.5
	f.light = l; f.base = energy
	f.add_child(l)
	parent.add_child(f); f.position = pos
	return f

## A mesh of the fitting that glows with it (bulb, tube, lampshade). Its material is its own.
func add_glow(mesh: MeshInstance3D, emission: Vector3) -> void:
	var m: Material = mesh.material_override.duplicate() if mesh.material_override else Tex.mat("enamel").duplicate()
	mesh.material_override = m
	glow.append([m, emission])

func toggle(v = null) -> void:
	var was := on
	on = (not on) if v == null else bool(v)
	if on and not was and kind == "fluoro": _startup = 2.0

func _process(delta: float) -> void:
	_t += delta
	var fr := Engine.get_process_frames()
	if fr != Fitting._frame:
		Fitting._frame = fr
		Fitting._brown_t -= delta
		if Fitting._brown_t <= 0.0:
			Fitting._brown_t = randf_range(35.0, 90.0)
			_sag()
	var k := _flick(delta) if on else 0.0
	if on and mains: k *= Fitting._brown
	_k = k
	light.light_energy = base * k * smoothstep(0.0, 1.0, near)
	light.visible = near > 0.001 and k > 0.0
	for g in glow:
		(g[0] as ShaderMaterial).set_shader_parameter("emission", g[1] * k)
	if buzz_key != "":
		Sfx.set_loop_volume(buzz_key, -24.0 + 14.0 * minf(1.0, k + 0.2) if on else -80.0)

static func _sag() -> void:
	Fitting._brown = randf_range(0.25, 0.5)
	await Engine.get_main_loop().create_timer(randf_range(0.3, 1.0)).timeout
	Fitting._brown = 0.65
	await Engine.get_main_loop().create_timer(randf_range(1.0, 2.5)).timeout
	Fitting._brown = 1.0

## How bright the fitting is this frame (0..1). Everything here changes smoothly and slowly:
## nothing flashes more than about twice a second (photosensitivity guidance is under 3), and
## with "Reduce flashing" on (the default) dips are shallower and never reach black.
static var _noise: FastNoiseLite
func _n(f: float, seed: float) -> float:
	if not Fitting._noise:
		Fitting._noise = FastNoiseLite.new(); Fitting._noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH; Fitting._noise.frequency = 1.0
	return Fitting._noise.get_noise_2d(_t * f, seed)          # -1..1, smooth

func _flick(delta: float) -> float:
	var safe: bool = Game.settings.get("reduce_flashing", true)
	var seed := float(get_instance_id() % 997)
	# a dip: chosen now and then, eased in and out over at least 0.4 s
	if _hold > 0.0: _hold -= delta
	match kind:
		"bulb":
			return 0.95 + 0.04 * _n(0.3, seed)
		"dying":
			if _hold <= 0.0 and randf() < delta * (0.25 if safe else 0.5):
				_hold = randf_range(0.5, 1.4); _state = randf_range(0.55, 0.75) if safe else randf_range(0.2, 0.5)
			_dip = move_toward(_dip, (_state if _hold > 0.0 else 1.0), delta * 1.5)
			return _dip * (0.85 + 0.08 * _n(0.7, seed))
		"fluoro":
			# a tired tube: now and then it sags and comes back; a restart is a slow, uneven climb
			if _startup > 0.0:
				_startup -= delta
				return clampf(1.0 - _startup / 2.0, 0.0, 1.0) * (0.75 + 0.25 * absf(sin(_t * PI * 1.2))) if not safe else clampf(1.0 - _startup / 2.0, 0.3, 1.0)
			if _hold <= 0.0 and randf() < delta * 0.08:
				_hold = randf_range(0.5, 1.2); _state = 0.65 if safe else 0.35
			_dip = move_toward(_dip, (_state if _hold > 0.0 else 1.0), delta * 1.2)
			return _dip * (0.96 + 0.02 * _n(0.5, seed))
		"candle":
			return 0.85 + 0.08 * _n(1.2, seed)
		"tv":
			return 0.65 + (0.12 if safe else 0.25) * _n(1.4, seed)
		"pulse":
			# a heartbeat, slow (48 a minute), never dark
			var b := fposmod(_t, 1.25)
			var beat := exp(-b * 5.0) + 0.6 * exp(-maxf(0.0, b - 0.3) * 5.0) * float(b > 0.3)
			return 0.7 + 0.3 * clampf(beat, 0.0, 1.0)
	return 1.0
