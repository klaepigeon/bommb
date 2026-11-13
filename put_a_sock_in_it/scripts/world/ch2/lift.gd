class_name Lift
extends Node3D
## The lift (docs/CHAPTER2.md): a Soviet cage of a car in a shaft, three stops. Dead without
## power (`powered` returns false: the mains off, or no good fuse in the LIFT slot): its buttons
## click and nothing happens. Powered, a call brings the car grinding to the floor, the doors open;
## inside, its button takes him to the next floor up (or back down from the top).
## The car carries whoever stands in it (Kurt; an inhabitant who wanders in goes too).

signal arrived(floor: int)

var floors: Array = []          # floor heights (world y)
var size := Vector2(2.0, 2.4)  # inside, x by z
var powered: Callable
var at := 0                     # the floor the car is at
var moving := false
var car: AnimatableBody3D
var _doors: Array = []          # per floor: [left, right] panels (shaft doors)
var _open := -1

func _ready() -> void:
	add_to_group("lift")
	car = AnimatableBody3D.new(); car.sync_to_physics = true; car.collision_layer = 1; add_child(car)
	var fl := CollisionShape3D.new(); var fs := BoxShape3D.new(); fs.size = Vector3(size.x, 0.1, size.y); fl.shape = fs; fl.position.y = -0.05; car.add_child(fl)
	var steel := Tex.mat("metal", 2.0, {"tint": Color(0.55, 0.55, 0.5)})
	var lino := Tex.mat("lino", 1.5, {"tint": Color(0.6, 0.55, 0.5)})
	_slab(car, Vector3(0, -0.05, 0), Vector3(size.x, 0.1, size.y), lino)
	_slab(car, Vector3(0, 2.25, 0), Vector3(size.x, 0.06, size.y), steel)
	for s in [-1, 1]: _slab(car, Vector3(s * size.x * 0.5, 1.1, 0), Vector3(0.04, 2.2, size.y), steel)
	_slab(car, Vector3(0, 1.1, -size.y * 0.5), Vector3(size.x, 2.2, 0.04), steel)
	var bulb := OmniLight3D.new(); bulb.light_color = Color("e8f0d0"); bulb.light_energy = 0.0; bulb.omni_range = 2.6; bulb.shadow_enabled = false
	bulb.name = "Bulb"; car.add_child(bulb); bulb.position = Vector3(0, 2.1, 0)
	for i in floors.size():
		var y: float = floors[i]
		var pair := []
		for s in [-1, 1]:
			var d := AnimatableBody3D.new(); d.sync_to_physics = false; d.collision_layer = 1; add_child(d)
			var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(size.x * 0.5, 2.1, 0.05); cs.shape = sh; cs.position.y = 1.05; d.add_child(cs)
			_slab(d, Vector3(0, 1.05, 0), Vector3(size.x * 0.5, 2.1, 0.05), steel)
			d.position = Vector3(s * size.x * 0.25, y - global_position.y, size.y * 0.5 + 0.06)
			d.set_meta("closed_x", s * size.x * 0.25)
			pair.append(d)
		_doors.append(pair)
	car.position.y = float(floors[at]) - global_position.y

func _slab(parent: Node3D, p: Vector3, s: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new(); mi.mesh = Build.box_mesh(s); mi.material_override = m; mi.position = p; parent.add_child(mi)

func is_powered() -> bool:
	return powered.is_valid() and bool(powered.call())

func _set_doors(f: int, open: bool) -> void:
	if f < 0 or f >= _doors.size(): return
	for d in _doors[f]:
		var x: float = d.get_meta("closed_x")
		var tw := create_tween().set_trans(Tween.TRANS_SINE)
		tw.tween_property(d, "position:x", x * 3.4 if open else x, 1.0)
	Sfx.play_at("lift_doors", global_position + Vector3(0, float(floors[f]) - global_position.y + 1.2, size.y * 0.5), -2.0, 1.0)
	_open = f if open else -1

## Someone on floor `f` pressed the call button (or the one in the car: go on).
func call_to(f: int) -> void:
	if moving: return
	if not is_powered():
		Sfx.play_at("switch", global_position + Vector3(0, float(floors[f]) - global_position.y + 1.2, size.y * 0.5 + 0.3), -4.0, 1.3)
		return
	if at == f:
		_set_doors(f, true); return
	await ride(f)

func ride(f: int) -> void:
	moving = true
	(car.get_node("Bulb") as OmniLight3D).light_energy = 0.9
	if _open >= 0:
		_set_doors(_open, false)
		await get_tree().create_timer(1.1).timeout
	Sfx.play_at("lift_grind", global_position + Vector3(0, car.position.y + 1.2, 0), 0.0, 1.0)
	var from := car.position.y
	var to: float = float(floors[f]) - global_position.y
	var secs := absf(to - from) / 0.9
	var riders := _riders()
	var t := 0.0
	while t < secs:
		var dt := get_process_delta_time()
		t += dt
		var y := lerpf(from, to, smoothstep(0.0, 1.0, t / secs))
		var dy := y - car.position.y
		car.position.y = y
		for r in riders: if is_instance_valid(r): r.global_position.y += dy
		if fmod(t, 1.6) < dt: Sfx.play_at("lift_grind", car.global_position + Vector3(0, 1.2, 0), -3.0, randf_range(0.9, 1.05))
		await get_tree().process_frame
	at = f
	Sfx.play_at("thud", car.global_position + Vector3(0, 0.2, 0), -4.0, 0.7)
	_set_doors(f, true)
	moving = false
	arrived.emit(f)

func _riders() -> Array:
	var out := []
	var c := car.global_position
	for n in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("inhabitant"):
		var l: Vector3 = (n as Node3D).global_position - c
		if absf(l.x) < size.x * 0.5 and absf(l.z) < size.y * 0.5 and l.y > -0.3 and l.y < 2.0: out.append(n)
	return out

## Is this point inside the car?
func inside(p: Vector3) -> bool:
	var l := p - car.global_position
	return absf(l.x) < size.x * 0.5 and absf(l.z) < size.y * 0.5 and l.y > -0.3 and l.y < 2.2
