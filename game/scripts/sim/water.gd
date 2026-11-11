class_name WaterBody
extends Node3D
## Standing water over a rectangle of floor (or in a bath): a level that rises and falls. It
## slows whoever wades in it and makes every step loud; light things float in it; what's at the
## bottom can't be seen until it's low; it carries a current if a live wire is in it. Fed by a
## tap or a burst pipe (fill), emptied by a drain or a pump (drain). Overflowing, it spills into
## the floor water next to it (`overflow_to`).

signal level_changed(level: float)

var key := ""
var rect := Rect2()              ## x, z
var floor_y := 0.0
var top_y := 0.5                 ## the brim: past this it overflows
var level := 0.0                 ## metres above floor_y
var inflow := 0.0                ## m/s while a source runs
var outflow := 0.0               ## m/s while a drain is open
var overflow_to: WaterBody
var live_circuit := ""           ## a cable in the water on this circuit
var colour := Color(0.03, 0.035, 0.03, 0.9)
var zone := -1
var gurgle := false              ## draining makes the pipes gurgle (loud, every few seconds)
var _surface: MeshInstance3D
var _gurgle_t := 0.0
var _shock_t := 0.0
static var all: Array[WaterBody] = []

func setup(p_key: String, r: Rect2, fy: float, top: float, lvl: float, z := -1) -> void:
	key = p_key; rect = r; floor_y = fy; top_y = top; level = lvl; zone = z
	_surface = MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = r.size; _surface.mesh = pm
	var m := ShaderMaterial.new(); m.shader = Mats.ALPHA
	m.set_shader_parameter("albedo_color", colour); m.set_shader_parameter("zone", float(z))
	_surface.material_override = m
	add_child(_surface)
	_place()
	World.register("water_" + key, func(): return {"level": level, "in": inflow, "out": outflow}, func(d):
		level = float(d.level); inflow = float(d["in"]); outflow = float(d.out); _place())

func _enter_tree() -> void:
	all.append(self)

func _exit_tree() -> void:
	all.erase(self)

func surface_y() -> float:
	return floor_y + level

func contains(p: Vector3, margin := 0.0) -> bool:
	return rect.grow(margin).has_point(Vector2(p.x, p.z)) and p.y < surface_y() + 0.3 and p.y > floor_y - 0.6

## How deep the water is at a point (0 if dry or outside).
func depth_at(p: Vector3) -> float:
	if not rect.has_point(Vector2(p.x, p.z)): return 0.0
	return maxf(surface_y() - maxf(p.y, floor_y), 0.0)

static func depth_anywhere(p: Vector3) -> float:
	var d := 0.0
	for w in all:
		d = maxf(d, w.depth_at(p))
	return d

static func at(p: Vector3) -> WaterBody:
	for w in all:
		if w.level > 0.01 and w.rect.has_point(Vector2(p.x, p.z)) and p.y < w.surface_y() + 0.2 and p.y > w.floor_y - 0.5:
			return w
	return null

func electrified() -> bool:
	return level > 0.01 and live_circuit != "" and Power.live(live_circuit)

func _place() -> void:
	if not _surface: return
	_surface.visible = level > 0.004
	_surface.global_position = Vector3(rect.get_center().x, surface_y(), rect.get_center().y)

func _physics_process(delta: float) -> void:
	var before := level
	level += (inflow - outflow) * delta
	if level < 0.0: level = 0.0
	var brim := top_y - floor_y
	if level > brim:
		var extra := level - brim
		level = brim
		if overflow_to:
			var k := (rect.get_area() / maxf(overflow_to.rect.get_area(), 0.01))
			overflow_to.level += extra * k
	if absf(level - before) > 1e-5:
		_place()
		level_changed.emit(level)
	if outflow > 0.0 and level > 0.01 and gurgle:
		_gurgle_t -= delta
		if _gurgle_t <= 0.0:
			_gurgle_t = randf_range(2.5, 4.0)
			var p := Vector3(rect.get_center().x, floor_y, rect.get_center().y)
			Audio.play("gurgle", p, -2.0, randf_range(0.85, 1.1))
			Noises.make(p, 9.0, "gurgle", self)
	# a current through it: everything standing in it gets it, and the breaker gives after a bit
	if electrified():
		_shock_t += delta
		if randf() < delta * 3.0:
			Audio.play("zap", Vector3(rect.get_center().x, surface_y(), rect.get_center().y), -6.0, randf_range(0.8, 1.2))
		for n in get_tree().get_nodes_in_group("shockable"):
			if n is Node3D and depth_at((n as Node3D).global_position + Vector3(0, 0.05, 0)) > 0.0 and n.has_method("shock"):
				n.shock(delta, self)
		if _shock_t > 2.5:
			Power.trip(live_circuit, "water")
			_shock_t = 0.0
	else:
		_shock_t = 0.0

## Something moving in the water: a splash anybody near can hear.
func splash(p: Vector3, how := 1.0) -> void:
	Audio.play("step_water", p, -6.0 + how * 4.0, randf_range(0.85, 1.15))
	Noises.make(p, 6.0 + how * 6.0, "splash", self)
