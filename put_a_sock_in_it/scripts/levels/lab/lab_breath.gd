extends Level
## The Lab: BREATH (docs/LAB.md). An experiment for the flesh: a room of meat that breathes
## (shaders/breath.gdshader) and closes in on him while he stands still. Moving makes it ease
## back. Its breathing and the heartbeat quicken as it closes. To open the door: turn the three
## valves, and turning a valve means standing still. If it closes all the way, it lets him go
## (back to the door, the valves undone).
##
## Photosensitivity: only the walls' shape moves, and slowly (a breath every 4 s at rest, every
## 1.6 s at its closest); the light on them doesn't change.

const W := 7.0
const D := 9.0
const H := 3.0
const REACH := 1.6              # how far mid-wall comes in, at close = 1
const TURN := 2.5               # seconds to turn a valve
var close := 0.0
var breath_phase := 0.0
var _walls: Array = []          # [MeshInstance3D, inward normal (Vector3), centre, along axis, half width]
var _mats: Array = []
var valves := {}                # name -> turned
var _beat_t := 0.0
var _turning := false
var opened := false
var _caught := false
const VALVES := {"V1": Vector3(-3.4, 1.2, -2.5), "V2": Vector3(3.4, 1.2, 1.5), "V3": Vector3(0.0, 1.2, -4.4)}

func build() -> void:
	add_to_group("level")
	var e := env.environment
	e.ambient_light_color = Color("3a2422"); e.ambient_light_energy = 0.6
	e.fog_light_color = Color("1a0a0a"); e.fog_density = 0.04
	Build.box(world, Vector3(0, -0.05, 0), Vector3(W + 0.4, 0.1, D + 0.4), Tex.mat("flesh_dark", 1.5))
	# the walls and the ceiling: fine grids that can bulge (the colliders stay put: he's held in by
	# the bulge in _process instead)
	_wall(Vector3(0, H * 0.5, -D * 0.5), Vector3(0, 0, 1), W, H)
	_wall(Vector3(0, H * 0.5, D * 0.5), Vector3(0, 0, -1), W, H)
	_wall(Vector3(-W * 0.5, H * 0.5, 0), Vector3(1, 0, 0), D, H)
	_wall(Vector3(W * 0.5, H * 0.5, 0), Vector3(-1, 0, 0), D, H)
	_wall(Vector3(0, H, 0), Vector3(0, -1, 0), W, D, 0.45)
	for s in [-1, 1]:
		Build.box(world, Vector3(s * (W * 0.5 + 0.1), H * 0.5, 0), Vector3(0.2, H, D + 0.4), Tex.mat("black"), true).visible = false
		Build.box(world, Vector3(0, H * 0.5, s * (D * 0.5 + 0.1)), Vector3(W + 0.4, H, 0.2), Tex.mat("black"), true).visible = false
	LabKit.lamp(world, Vector3(0, H - 0.4, 0), Color("ffb08a"), 1.3, 9.0)
	# the valves: iron wheels on the meat
	for v in VALVES:
		var at: Vector3 = VALVES[v]
		valves[v] = false
		var wheel := Build.box(world, at, Vector3(0.45, 0.45, 0.08), Tex.mat("metal", 1.0), false)
		wheel.name = "Wheel_" + v
		if absf(at.x) > 3.0: wheel.rotation.y = PI * 0.5
		var u := Use.make(world, at, Vector3(0.7, 0.7, 0.7), func(): return "" if valves[v] or _turning else "Turn the valve (stand still)", func(_p): _turn(v))
		u.name = v
	LabKit.portal(world, Vector3(0, 0, D * 0.5 - 0.02), PI, "LAB", "lab", "", func(): return opened)
	player.position = Vector3(0, 0, D * 0.5 - 1.4)
	player.set_view(0.0, 0.0)
	socko.visible = true

func _wall(c: Vector3, n: Vector3, w: float, h: float, reach_k := 1.0) -> void:
	var pm := PlaneMesh.new(); pm.size = Vector2(w, h); pm.subdivide_width = 28; pm.subdivide_depth = 14
	var mi := MeshInstance3D.new(); mi.mesh = pm
	var sh: Shader = load("res://shaders/breath.gdshader")
	var m := ShaderMaterial.new(); m.shader = sh
	m.set_shader_parameter("albedo_tex", Tex.tex("flesh"))
	m.set_shader_parameter("uv_scale", Vector2(w / 2.0, h / 2.0))
	m.set_shader_parameter("reach", REACH * reach_k)
	mi.material_override = m
	world.add_child(mi); mi.position = c
	# a PlaneMesh faces +y; turn it to face n (into the room)
	if n.y < -0.5: mi.rotation.x = PI
	else:
		mi.rotation.x = PI * 0.5
		mi.rotation.y = atan2(n.x, n.z)
	_mats.append(m)
	_walls.append([mi, n, c, Vector3(absf(n.z), 0, absf(n.x)), w * 0.5, reach_k])

## How far in a wall has come at a point on it (u along it, v up it, both -1..1).
func bulge(u: float, v: float, reach_k := 1.0) -> float:
	return close * REACH * reach_k * (1.0 - u * u) * (1.0 - v * v)

func _turn(v: String) -> void:
	if valves[v] or _turning: return
	_turning = true
	set_cutscene(true)
	Sfx.play("creak", -4.0, 0.7)
	var wheel: Node3D = world.get_node("Wheel_" + v)
	var tw := create_tween(); tw.tween_property(wheel, "rotation:z", wheel.rotation.z + TAU * 1.5, TURN).set_trans(Tween.TRANS_SINE)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < TURN * 1000.0:
		close = minf(1.0, close + get_process_delta_time() * 0.1)      # (still: it closes faster)
		await get_tree().process_frame
		if not is_inside_tree() or _caught: _turning = false; return
	valves[v] = true
	_turning = false
	set_cutscene(false)
	if valves.values().all(func(x): return x):
		opened = true
		Sfx.play("door_creak", -2.0, 0.8)
		hud.hint("The door's open.", 3.0)
	else: hud.hint("%d of 3." % valves.values().count(true), 2.0)

func _process(delta: float) -> void:
	super._process(delta)
	if _caught: return
	var still := player.velocity.length() < 0.5
	if not cutscene: close = clampf(close + (0.055 if still else -0.11) * delta, 0.0, 1.0)
	# breathing: 0.25 Hz at rest, 0.62 Hz at its closest
	breath_phase += delta * TAU * lerpf(0.25, 0.62, close)
	var b := sin(breath_phase)
	for m in _mats:
		(m as ShaderMaterial).set_shader_parameter("close", close)
		(m as ShaderMaterial).set_shader_parameter("breath", b)
	_beat_t -= delta
	if _beat_t <= 0.0:
		_beat_t = 60.0 / lerpf(52.0, 120.0, close)
		Sfx.play("heartbeat", lerpf(-16.0, -3.0, close), 1.0)
	Game.fear = maxf(Game.fear, close * 0.8)
	_hold_in()
	if close >= 0.98: _let_go()

## Hold him inside the bulge (the shader moves the walls, not the colliders).
func _hold_in() -> void:
	var p := player.global_position
	var vy := clampf((p.y + 1.0) / H * 2.0 - 1.0, -1.0, 1.0)
	var pad := 0.35
	var bx := bulge(clampf(p.z / (D * 0.5), -1, 1), vy)
	var bz := bulge(clampf(p.x / (W * 0.5), -1, 1), vy)
	p.x = clampf(p.x, -W * 0.5 + bx + pad, W * 0.5 - bx - pad)
	p.z = clampf(p.z, -D * 0.5 + bz + pad, D * 0.5 - bz - pad)
	if p != player.global_position:
		player.global_position = p
		if close > 0.6: player.hurt(0.002, p)

func _let_go() -> void:
	_caught = true
	set_cutscene(true)
	Sfx.play("thud", -2.0, 0.6)
	await Game.fade(1.0, 1.2)
	if not is_inside_tree(): return
	close = 0.0
	for v in valves: valves[v] = false
	opened = false
	player.global_position = Vector3(0, 0, D * 0.5 - 1.4); player.set_view(0.0, 0.0)
	await Game.fade(0.0, 1.0)
	if not is_inside_tree(): return
	_caught = false
	set_cutscene(false)
	hud.hint("It let you go. Keep moving.", 3.0)

func begin() -> void:
	set_cutscene(false)
	await Game.fade(0.0, 0.6)
	hud.hint("It closes in while you stand still. Three valves open the door.", 6.0)
