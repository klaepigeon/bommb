extends Level
## The Lab: AI SANDBOX (docs/LAB.md). An arena (pillars, a wall with a doorway, low cover, loose
## boxes, a wardrobe to hide in) to spawn the building's people in and watch them think: what
## they see and hear, who they go for, how they lose him. The developer overlay (F3) shows each
## one's state. Keys (listed on screen):
##   1-8  spawn (super, hunter, listener, laundress, cook, rearranger, crawler, caretaker) where
##        he's looking        J  they hate him / they don't        N  a noise where he's looking
##   U    kill them all       V  clear them all     L  lights on / off     I  god mode
##   Y    time: 1x, 0.5x, 0.25x, 2x                 O  freeze / unfreeze them
## (keys the game doesn't use: H, K, C, G, T and P are its own)
## Exit: the door marked LAB.

const TYPES := ["super", "hunter", "listener", "laundress", "cook", "rearranger", "crawler", "caretaker"]
const SIZE := 24.0
var people: Array = []
var hostile := true
var lights_on := true
var god := false
var frozen := false
var _scale_i := 0
const SCALES := [1.0, 0.5, 0.25, 2.0]
var _lamps: Array = []
var _panel: Label
var _n := 0

func build() -> void:
	add_to_group("level")
	var e := env.environment
	e.ambient_light_color = Color("3a3832"); e.ambient_light_energy = 0.5
	e.fog_density = 0.02
	LabKit.room(world, Vector3.ZERO, SIZE, SIZE, 4.0, Tex.mat("concrete", 0.5, {"tint": Color(0.6, 0.58, 0.55)}))
	# cover: pillars, a wall with a doorway across the middle, low walls, loose boxes
	for p in [Vector3(-6, 0, -6), Vector3(6, 0, -6), Vector3(-6, 0, 6), Vector3(6, 0, 6)]:
		Build.box(world, p + Vector3(0, 2.0, 0), Vector3(0.8, 4.0, 0.8), Tex.mat("concrete", 0.5))
	Build.box(world, Vector3(-7.5, 1.5, 0), Vector3(9.0, 3.0, 0.2), Tex.mat("wallpaper", 0.6))
	Build.box(world, Vector3(7.5, 1.5, 0), Vector3(9.0, 3.0, 0.2), Tex.mat("wallpaper", 0.6))
	Build.box(world, Vector3(0, 2.6, 0), Vector3(6.0, 0.8, 0.2), Tex.mat("wallpaper", 0.6))     # over the gap: a wide doorway
	for p in [Vector3(-3, 0, 8), Vector3(3, 0, -8), Vector3(9, 0, 3)]:
		Build.box(world, p + Vector3(0, 0.5, 0), Vector3(2.4, 1.0, 0.3), Tex.mat("wood", 1.0))
	for i in 6:
		Prop.make(world, Vector3(-9.0 + i * 1.2, 0.3, -9.0), Vector3(0.5, 0.6, 0.5), Tex.mat("cardboard", 3.0), "box", 6.0, 0.6)
	var w := HideSpot.new(); world.add_child(w); w.position = Vector3(-10.8, 0, 8.0); w.rotation.y = PI * 0.5
	for p in [Vector3(-6, 3.6, -6), Vector3(6, 3.6, -6), Vector3(-6, 3.6, 6), Vector3(6, 3.6, 6), Vector3(0, 3.6, 0)]:
		_lamps.append(LabKit.lamp(world, p, Color("ffe0b0"), 1.6, 11.0))
	LabKit.portal(world, Vector3(0, 0, SIZE * 0.5 - 0.05), PI, "LAB", "lab")
	LabKit.bake_nav(world)
	var cl := CanvasLayer.new(); cl.layer = 20; add_child(cl)
	_panel = Label.new(); _panel.position = Vector2(14, 14); _panel.add_theme_font_size_override("font_size", 15)
	_panel.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75)); _panel.add_theme_constant_override("outline_size", 6)
	_panel.add_theme_color_override("font_outline_color", Color.BLACK)
	cl.add_child(_panel)
	player.position = Vector3(0, 0, 9.0)
	player.set_view(0.0, 0.0)
	socko.visible = true

func begin() -> void:
	set_cutscene(false)
	await Game.fade(0.0, 0.4)

# ------------------------------------------------------------------ what the inhabitants ask of a level
func lit(p: Vector3) -> bool:
	if not lights_on: return false
	for l in _lamps: if p.distance_to((l as Node3D).global_position) < 7.0: return true
	return false

func dark_spot_near(p: Vector3) -> Vector3:
	var best := Vector3(SIZE * 0.45, 0, SIZE * 0.45); var bd := INF
	for c in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
		var q: Vector3 = c * SIZE * 0.45
		if q.distance_to(p) < bd: bd = q.distance_to(p); best = q
	return best

func on_player_down() -> void:
	player.health = 1.0
	player.global_position = Vector3(0, 0, 9.0)
	hud.hint("Down. Back at the door.", 3.0)

# ------------------------------------------------------------------ the keys
func spawn(type: String, at: Vector3) -> Inhabitant:
	var prof: Dictionary = LabKit.PEOPLE[type].duplicate(true)
	_n += 1
	prof["id"] = "%s_%d" % [type, _n]
	prof["faction"] = type
	prof["hostile_to"] = ["kurt"] if hostile else []
	var body: Dictionary = prof.get("body", {})
	body["model"] = type; body["speaker"] = prof.id
	prof["body"] = body
	var pts := [Vector3(-8, 0, -8), Vector3(8, 0, -8), Vector3(8, 0, 8), Vector3(-8, 0, 8)]
	pts.shuffle()
	prof["objectives"] = [{"type": "patrol", "points": pts, "wait": 2.0, "weight": 1.0}]
	var n := Inhabitant.new(prof); n.level = self; n.player = player
	world.add_child(n); n.global_position = at
	n.set_physics_process(not frozen)
	people.append(n)
	return n

func aim_point(reach := 25.0) -> Vector3:
	var from := player.cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - player.cam.global_transform.basis.z * reach, 1, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty(): return from - player.cam.global_transform.basis.z * 6.0 * Vector3(1, 0, 1)
	var p: Vector3 = hit.position
	return Vector3(p.x, 0.0, p.z) + ((from - p) * Vector3(1, 0, 1)).normalized() * 0.5

func set_hostile(on: bool) -> void:
	hostile = on
	for n in people:
		if is_instance_valid(n): n.prof["hostile_to"] = ["kurt"] if on else []; n.awareness = 0.0 if not on else n.awareness

func set_lights(on: bool) -> void:
	lights_on = on
	for l in _lamps: (l as OmniLight3D).light_energy = 1.6 if on else 0.0

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo or cutscene: return
	var k: int = (e as InputEventKey).physical_keycode
	if k >= KEY_1 and k <= KEY_8: spawn(TYPES[k - KEY_1], aim_point())
	elif k == KEY_J: set_hostile(not hostile)
	elif k == KEY_N: Game.make_noise(aim_point(), 0.7); Sfx.play_at("knock", aim_point() + Vector3(0, 1, 0), 0.0)
	elif k == KEY_U: for a in people: if is_instance_valid(a) and not a.dead: a.die()
	elif k == KEY_V:
		for b in people: if is_instance_valid(b): b.queue_free()
		people.clear()
	elif k == KEY_L: set_lights(not lights_on)
	elif k == KEY_I: god = not god
	elif k == KEY_Y: _scale_i = (_scale_i + 1) % SCALES.size(); Engine.time_scale = SCALES[_scale_i]
	elif k == KEY_O:
		frozen = not frozen
		for n in people: if is_instance_valid(n): n.set_physics_process(not frozen)

func _process(delta: float) -> void:
	super._process(delta)
	if god: player.health = 1.0
	people = people.filter(func(n): return is_instance_valid(n))
	var alive := people.filter(func(n): return not n.dead).size()
	_panel.text = "AI SANDBOX   %d here (%d alive)\n1-8 spawn: super hunter listener laundress cook rearranger crawler caretaker\nJ hate him: %s   N noise   U kill all   V clear   L lights: %s   I god: %s   Y time: %sx   O frozen: %s\nF3: what they're thinking" % [
		people.size(), alive, "yes" if hostile else "no", "on" if lights_on else "off", "on" if god else "off", str(SCALES[_scale_i]), "yes" if frozen else "no"]

func _exit_tree() -> void:
	super._exit_tree()
	Engine.time_scale = 1.0
