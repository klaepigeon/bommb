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
	if on and not was and kind == "fluoro": _startup = 1.4

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

func _flick(delta: float) -> float:
	match kind:
		"bulb":
			return 0.94 + sin(_t * 7.1) * 0.02 + sin(_t * 23.3) * 0.015 + (-0.4 if randf() < delta * 0.4 else 0.0)
		"dying":
			if _hold > 0.0: _hold -= delta; return _state
			if randf() < delta * 1.5: _hold = randf_range(0.03, 0.33); _state = randf() * 0.4; return _state
			return 0.8 + sin(_t * 11.0) * 0.08
		"fluoro":
			if _startup > 0.0:
				_startup -= delta
				return 1.0 if randf() < 0.35 else (0.25 if randf() < 0.4 else 0.0)
			if _hold > 0.0: _hold -= delta; return _state
			if randf() < delta * 0.35: _hold = randf_range(0.04, 0.29); _state = 0.0 if randf() < 0.6 else 0.4; return _state
			if randf() < delta * 0.03: _startup = randf_range(0.8, 2.3)
			return 0.96 + sin(_t * 314.0) * 0.03
		"candle":
			return 0.82 + sin(_t * 9.7) * 0.06 + sin(_t * 23.1 + 1.0) * 0.05 + randf_range(-0.06, 0.06)
		"tv":
			return 0.55 + randf() * 0.35 + sin(_t * 2.2) * 0.1
		"pulse":
			var b := fposmod(_t, 1.25)
			return 0.55 + 0.45 * (exp(-b * 9.0) + 0.6 * exp(-maxf(0.0, b - 0.28) * 9.0) * float(b > 0.28))
	return 1.0
