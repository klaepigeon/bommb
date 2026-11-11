extends Node
## The light engine. Every Lamp registers here. Each frame the eight that matter most to what the
## camera can see are written to the shader globals (world.gdshaderinc). A lamp entering or leaving
## the eight fades in or out over ~0.4 s, so nothing ever pops, and there is never a per-object
## light limit to exceed: the same eight light everything. Also: the torch (a spot), the fog,
## the world's tint, and which rooms are joined by open doors (so light spills through them).

const SLOTS := 8
var lamps: Array[Lamp] = []
var slots: Array = []                 ## Lamp or null
var links := {}                       ## Vector2i(a, b) (a < b) -> true while a door between them is open
var circuits := {}                    ## name -> bool (Power writes here)
var cam_zone := -1
var torch := {"on": false, "pos": Vector3.ZERO, "dir": Vector3.FORWARD, "cos": 0.86, "color": Color(1, 0.92, 0.75), "energy": 1.6, "reach": 9.0}
var fog_color := Color(0.02, 0.02, 0.025)
var fog_far := 16.0
var tint := Color(1, 1, 1, 1)
var _t := 0.0

func _ready() -> void:
	process_priority = 100      # after everything has moved
	slots.resize(SLOTS)
	for i in SLOTS:
		_clear(i)

func add(l: Lamp) -> void:
	if not lamps.has(l):
		lamps.append(l)

func remove(l: Lamp) -> void:
	lamps.erase(l)
	if l.slot >= 0 and l.slot < SLOTS and slots[l.slot] == l:
		slots[l.slot] = null
		_clear(l.slot)

func circuit_live(c: String) -> bool:
	return bool(circuits.get(c, true))

func set_link(a: int, b: int, open: bool) -> void:
	var k := Vector2i(mini(a, b), maxi(a, b))
	if open: links[k] = true
	else: links.erase(k)

func _zones_for(l: Lamp) -> Vector4:
	if l.zones.has(-1):
		return Vector4(-1, -1, -1, -1)
	var z: Array = Array(l.zones)
	for k in links:
		if z.size() >= 4: break
		if z.has(k.x) and not z.has(k.y): z.append(k.y)
		elif z.has(k.y) and not z.has(k.x): z.append(k.x)
	while z.size() < 4:
		z.append(z[0] if z.size() > 0 else -2)
	return Vector4(z[0], z[1], z[2], z[3])

func _clear(i: int) -> void:
	RenderingServer.global_shader_parameter_set("l%d_col" % i, Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("l%d_zone" % i, Vector4(-2, -2, -2, -2))

func _score(l: Lamp, eye: Vector3, e: float) -> float:
	var d2 := eye.distance_squared_to(l.global_position)
	var s := e * l.reach * l.reach / (1.0 + d2)
	if d2 > (l.reach + 12.0) * (l.reach + 12.0):
		return 0.0
	if cam_zone >= 0:
		var zv := _zones_for(l)
		if zv.x != -1 and not (zv.x == cam_zone or zv.y == cam_zone or zv.z == cam_zone or zv.w == cam_zone):
			s *= 0.25
	return s

func _process(delta: float) -> void:
	_t += delta
	delta = minf(delta, 0.1)
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else Vector3.ZERO
	# brightness and score for every lamp
	var cand: Array = []
	var bright := {}
	for l in lamps:
		if not is_instance_valid(l) or not l.is_inside_tree():
			continue
		var e := l.current(_t, delta)
		bright[l] = e
		if e > 0.0 and l.slot < 0:
			var sc := _score(l, eye, e)
			if sc > 0.0:
				cand.append([sc, l])
	cand.sort_custom(func(a, b): return a[0] > b[0])
	# a much better lamp waiting pushes out the weakest one (which fades, then frees its slot)
	var weakest := -1
	var weakest_s := INF
	for i in SLOTS:
		var s: Lamp = slots[i]
		if s == null: continue
		var sc := _score(s, eye, maxf(float(bright.get(s, 0.0)), 0.001))
		if sc < weakest_s:
			weakest_s = sc; weakest = i
	var ci := 0
	for i in SLOTS:
		if slots[i] == null and ci < cand.size():
			var l: Lamp = cand[ci][1]; ci += 1
			slots[i] = l; l.slot = i; l.weight = 0.0
	if ci < cand.size() and weakest >= 0 and cand[ci][0] > weakest_s * 2.5:
		(slots[weakest] as Lamp).set_meta("leaving", true)
	for i in SLOTS:
		var l: Lamp = slots[i]
		if l == null:
			continue
		if not is_instance_valid(l):
			slots[i] = null; _clear(i); continue
		var leaving: bool = l.get_meta("leaving", false) or _score(l, eye, maxf(float(bright.get(l, 0.0)), 0.001)) <= 0.0
		l.weight = move_toward(l.weight, 0.0 if leaving else 1.0, delta / 0.4)
		if leaving and l.weight <= 0.0:
			l.slot = -1; l.set_meta("leaving", false); slots[i] = null; _clear(i); continue
		var e: float = float(bright.get(l, 0.0)) * l.weight
		var p := l.global_position
		RenderingServer.global_shader_parameter_set("l%d_pos" % i, Vector4(p.x, p.y, p.z, l.reach))
		RenderingServer.global_shader_parameter_set("l%d_col" % i, Vector4(l.color.r * e, l.color.g * e, l.color.b * e, 1.0))
		RenderingServer.global_shader_parameter_set("l%d_zone" % i, _zones_for(l))
	# the torch
	if torch.on:
		var p: Vector3 = torch.pos; var d: Vector3 = torch.dir; var c: Color = torch.color
		var e: float = torch.energy
		RenderingServer.global_shader_parameter_set("torch_pos", Vector4(p.x, p.y, p.z, torch.reach))
		RenderingServer.global_shader_parameter_set("torch_dir", Vector4(d.x, d.y, d.z, torch.cos))
		RenderingServer.global_shader_parameter_set("torch_col", Vector4(c.r * e, c.g * e, c.b * e, 1))
	else:
		RenderingServer.global_shader_parameter_set("torch_pos", Vector4(0, -1000, 0, 0))
	RenderingServer.global_shader_parameter_set("fog", Vector4(fog_color.r, fog_color.g, fog_color.b, fog_far))
	var t := tint
	if Progress.has("dark_eyes"):           # the dark stops being dark (and goes green)
		t = Color(tint.r * 1.5, tint.g * 1.75, tint.b * 1.4, tint.a * 0.7)
	RenderingServer.global_shader_parameter_set("world_tint", Vector4(t.r, t.g, t.b, t.a))

## How lit a point is (0..~1.5): lamps that reach it, plus the torch. Monsters use this to see.
func light_at(p: Vector3, zone := -1) -> float:
	var sum := 0.0
	for l in lamps:
		if not is_instance_valid(l) or not l.powered():
			continue
		if zone >= 0 and not l.zones.has(-1):
			var zv := _zones_for(l)
			if not (zv.x == zone or zv.y == zone or zv.z == zone or zv.w == zone):
				continue
		var d2 := p.distance_squared_to(l.global_position)
		var r2 := l.reach * l.reach
		if d2 < r2:
			var a := 1.0 - d2 / r2
			sum += l.energy * a * a / (1.0 + d2 * 0.35)
	if torch.on:
		var tp: Vector3 = torch.pos
		var to := p - tp
		var dist := to.length()
		if dist < float(torch.reach) and to.normalized().dot(torch.dir) > float(torch.cos):
			sum += float(torch.energy) * pow(1.0 - dist / float(torch.reach), 2.0)
	return sum
