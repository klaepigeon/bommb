extends Level
## The Lab: STILL (docs/LAB.md). An experiment: a hall of pillars and figures that only move
## while nothing sees them. "Seen" is honest: in his view, not behind a pillar, and lit (the
## room's lamps, or his torch's cone). The lamps sag every so often (a slow dim and back, two
## seconds down: never a flicker), and the torch has a battery. A figure that reaches him knocks
## him down and they all go back. At the far end: a switch. Throw it.

const SIZE := 18.0
const STEP := 2.6               # m/s, unseen
const START := [Vector3(-6, 0, -7), Vector3(0, 0, -6), Vector3(6, 0, -7), Vector3(-7, 0, 1), Vector3(7, 0, 0)]
const MODELS := ["caretaker", "laundress", "rearranger", "cook", "caretaker"]
const POSES := [
	{"sh_l": Vector3(1.3, 0, -0.2), "sh_r": Vector3(1.3, 0, 0.2), "el_l": Vector3(0.2, 0, 0), "el_r": Vector3(0.2, 0, 0), "head": Vector3(0.1, 0, 0)},
	{"sh_r": Vector3(2.6, 0, 0.3), "el_r": Vector3(0.6, 0, 0), "head": Vector3(-0.3, 0.4, 0.2), "spine": Vector3(0.2, 0, 0)},
	{"head": Vector3(0.5, 0, 0.6), "neck": Vector3(0.3, 0, 0.3), "sh_l": Vector3(0, 0, -1.2), "sh_r": Vector3(0, 0, 1.2)},
	{"spine": Vector3(0.6, 0, 0), "chest": Vector3(0.3, 0, 0), "sh_l": Vector3(1.6, 0, 0), "sh_r": Vector3(1.6, 0, 0), "kn_l": Vector3(-0.5, 0, 0), "kn_r": Vector3(-0.5, 0, 0)},
	{"head": Vector3(-0.6, 0, 0), "sh_l": Vector3(0.4, 0, -0.3), "sh_r": Vector3(-0.3, 0, 0.6), "el_r": Vector3(1.2, 0, 0)},
]
var figures: Array = []         # FleshBody
var _path := {}                 # figure -> PackedVector3Array
var _repath := {}
var _lamps: Array = []
var lamp_k := 1.0               # how lit the room is (0..1)
var _sag_t := 9.0
var moved := 0.0                # (how far they've gone in all: the test reads it)
var done := false
var _resetting := false

func build() -> void:
	add_to_group("level")
	var e := env.environment
	e.ambient_light_color = Color("2c2a28"); e.ambient_light_energy = 0.35
	e.fog_density = 0.03
	LabKit.room(world, Vector3.ZERO, SIZE, SIZE, 4.0, Tex.mat("plaster", 1.0, {"tint": Color(0.55, 0.53, 0.5)}), Tex.mat("parquet", 2.0))
	for x in [-4.5, 0.0, 4.5]:
		for z in [-4.5, 0.0, 4.5]:
			if x == 0.0 and z == 0.0: continue
			Build.box(world, Vector3(x, 2.0, z), Vector3(1.0, 4.0, 1.0), Tex.mat("concrete", 0.6))
	for p in [Vector3(-4.5, 3.6, -2.2), Vector3(4.5, 3.6, -2.2), Vector3(-4.5, 3.6, 2.2), Vector3(4.5, 3.6, 2.2), Vector3(0, 3.6, -7), Vector3(0, 3.6, 7)]:
		_lamps.append(LabKit.lamp(world, p, Color("ffe2b8"), 1.3, 9.0))
	# the switch, on the far wall
	Build.box(world, Vector3(0, 1.3, -SIZE * 0.5 + 0.05), Vector3(0.3, 0.45, 0.1), Tex.mat("metal", 1.0), false)
	LabKit.label(world, Vector3(0, 1.75, -SIZE * 0.5 + 0.12), 0.0, "SWITCH", 36)
	var u := Use.make(world, Vector3(0, 1.3, -SIZE * 0.5 + 0.25), Vector3(0.6, 0.8, 0.4), func(): return "" if done else "Throw the switch", func(_p): _win())
	u.name = "Switch"
	LabKit.portal(world, Vector3(0, 0, SIZE * 0.5 - 0.05), PI, "LAB", "lab")
	LabKit.bake_nav(world)
	for i in START.size():
		var f := FleshBody.new({"model": MODELS[i], "height": 1.85})
		world.add_child(f); f.snap = 0.0
		figures.append(f)
	_place()
	player.position = Vector3(2.25, 0, SIZE * 0.5 - 1.5)
	player.set_view(0.0, 0.0)
	socko.visible = true

func _place() -> void:
	for i in figures.size():
		var f: FleshBody = figures[i]
		f.position = START[i]; f.rotation.y = randf() * TAU
		f.pose = POSES[i % POSES.size()].duplicate()
		_path.erase(f)

# ------------------------------------------------------------------ seeing
## Is any part of it in his view, unblocked and lit?
func seen(f: FleshBody) -> bool:
	var cam := player.cam
	for h in [0.3, 1.0, 1.7]:
		var pt := f.global_position + Vector3(0, h, 0)
		if not cam.is_position_in_frustum(pt): continue
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(cam.global_position, pt, 1, [player.get_rid()]))
		if not hit.is_empty(): continue
		if lit_at(pt): return true
	return false

func lit_at(pt: Vector3) -> bool:
	if lamp_k > 0.45:
		for l in _lamps: if pt.distance_to((l as Node3D).global_position) < 8.5: return true
	if player.torch_on and player.torch and player.torch.light_energy > 0.5:
		var t: Node3D = player.torch
		var d := pt - t.global_position
		if d.length() < 13.0 and (-t.global_transform.basis.z).dot(d.normalized()) > cos(deg_to_rad(17.0)): return true
	return false

func _process(delta: float) -> void:
	super._process(delta)
	_lights(delta)
	if cutscene or done or _resetting: return
	var me := player.global_position * Vector3(1, 0, 1)
	for f in figures:
		var fig: FleshBody = f
		if seen(fig):
			fig.snap = 0.0          # (stone: not even a joint)
			_path.erase(fig)
			continue
		# unseen: a new pose at once, and nearer
		if randf() < delta * 1.5: fig.pose = POSES[randi() % POSES.size()].duplicate()
		fig.snap = 40.0
		_repath[fig] = float(_repath.get(fig, 0.0)) - delta
		if not _path.has(fig) or _repath[fig] <= 0.0:
			_repath[fig] = 0.4
			_path[fig] = NavigationServer3D.map_get_path(get_world_3d().navigation_map, fig.global_position, me, true)
		var path: PackedVector3Array = _path[fig]
		var at := fig.global_position * Vector3(1, 0, 1)
		var next := me
		for p in path:
			if (p * Vector3(1, 0, 1)).distance_to(at) > 0.3: next = p * Vector3(1, 0, 1); break
		var dir := next - at
		if dir.length() > 0.01:
			var stepv := dir.normalized() * minf(STEP * delta, dir.length())
			fig.global_position += stepv
			moved += stepv.length()
			fig.rotation.y = atan2(-(me - at).x, -(me - at).z)
		if fig.global_position.distance_to(me) < 0.9: _caught(fig)

## The lamps: steady, and now and then a slow sag (down over 1.5 s, two seconds low, back up).
func _lights(delta: float) -> void:
	_sag_t -= delta
	if _sag_t <= 0.0 and not done:
		_sag_t = randf_range(11.0, 17.0)
		var tw := create_tween()
		tw.tween_property(self, "lamp_k", 0.15, 1.5).set_trans(Tween.TRANS_SINE)
		tw.tween_interval(2.0)
		tw.tween_property(self, "lamp_k", 1.0, 1.5).set_trans(Tween.TRANS_SINE)
	for l in _lamps: (l as OmniLight3D).light_energy = 1.3 * lamp_k

func _caught(f: FleshBody) -> void:
	if _resetting: return
	_resetting = true
	player.hurt(0.25, f.global_position)
	Sfx.play("thud", -2.0, 0.8)
	set_cutscene(true)
	await Game.fade(1.0, 0.8)
	if not is_inside_tree(): return
	_place()
	player.global_position = Vector3(2.25, 0, SIZE * 0.5 - 1.5); player.set_view(0.0, 0.0)
	player.health = maxf(player.health, 0.6)
	await Game.fade(0.0, 0.8)
	if not is_inside_tree(): return
	set_cutscene(false)
	_resetting = false

func _win() -> void:
	if done: return
	done = true
	Sfx.play("click", 0.0, 0.7)
	for f in figures:
		var tw := create_tween(); tw.tween_property(f, "scale", Vector3(1, 0.02, 1), 2.0).set_trans(Tween.TRANS_SINE)
	var tw2 := create_tween(); tw2.tween_property(self, "lamp_k", 1.0, 0.8)
	hud.hint("They're down. The door's behind you.", 5.0)

func on_player_down() -> void:
	player.health = 1.0
	_caught(figures[0])

func begin() -> void:
	set_cutscene(false)
	await Game.fade(0.0, 0.6)
	hud.hint("They only move while nothing sees them. The switch is at the far end. F: torch.", 6.0)
