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
	l.shadow_bias = 0.1; l.shadow_normal_bias = 2.5
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
	pass

func _process(delta: float) -> void:
	_t += delta
	var fr := Engine.get_process_frames()
	if fr != Fitting._frame:
		Fitting._frame = fr
		pass          # (no brownouts: the building's supply holds)
	var k := _flick(delta) if on else 0.0
	if on and mains: k *= Fitting._brown
	_k = k
	light.light_energy = base * k
	light.visible = k > 0.0
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

func _flick(_delta: float) -> float:
	# Steady. Nothing flickers: the old characters ("bulb", "dying", "fluoro", "candle") are kept
	# as names but all hold still. Only two move, and slowly enough to read as breathing, not
	# flicker: the TV's light (a slow drift, a few seconds a cycle) and the flesh's pulse.
	var seed := float(get_instance_id() % 997)
	match kind:
		"tv":
			return 0.88 + 0.07 * _n(0.12, seed)
		"pulse":
			return 0.92 + 0.08 * (0.5 + 0.5 * sin(_t * TAU / 5.0))
	return 1.0
