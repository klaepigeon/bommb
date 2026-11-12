class_name Level
extends Node3D
## What every level has: the player (Kurt), his HUD, the touch overlay, pause, the pistol, Socko
## on his left hand (hidden until he's there), the environment, trigger zones, and the
## between-the-beats conversations. A level subclass builds its geometry in build() and runs its
## story from begin() (Game calls it once the loading card is gone; the screen is black).

var player: Player
var socko: Socko
var pistol: Pistol
var hands: Hands
var skills_menu: SkillsMenu
var powers: Powers
var nerve: Nerve
var shotgun: Shotgun
var body: KurtBody
var hud: Hud
var touch: TouchControls
var pause: PauseMenu
var env: WorldEnvironment
var world: Node3D               # geometry goes here
var cutscene := false
var random_talk := false        # Socko and Kurt pass the time when nothing else is happening
var _quiet_t := 0.0
const RANDOM := ["random_a", "random_b", "random_c"]

func _ready() -> void:
	world = Node3D.new(); world.name = "World"; add_child(world)
	env = WorldEnvironment.new(); env.environment = Environment.new()
	var e := env.environment
	e.background_mode = Environment.BG_COLOR; e.background_color = Color.BLACK
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color("3a322b"); e.ambient_light_energy = 1.0
	e.fog_enabled = true; e.fog_light_color = Color("100c0a"); e.fog_density = 0.06
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# bulbs, tubes and lampshades bloom a little, like they do on old tape
	e.glow_enabled = true; e.glow_intensity = 0.5; e.glow_bloom = 0.0; e.glow_hdr_threshold = 1.0
	e.adjustment_enabled = true; e.adjustment_contrast = 1.08; e.adjustment_saturation = 0.9
	add_child(env)
	player = Player.new(); player.name = "Kurt"; add_child(player)
	socko = Socko.new(); add_child(socko); socko.attach(player)
	pistol = Pistol.new(); pistol.attach(player)
	shotgun = Shotgun.new(); shotgun.attach(player)
	hands = Hands.new(); hands.attach(player)
	body = KurtBody.new(); body.attach(player)
	skills_menu = SkillsMenu.new(); add_child(skills_menu)
	powers = Powers.new(); powers.attach(player, self)
	nerve = Nerve.new(); nerve.attach(player, self)
	Game.fear = 0.0
	hud = Hud.new(); hud.player = player; add_child(hud)
	var tl := CanvasLayer.new(); tl.layer = 30; add_child(tl)
	touch = TouchControls.new(); touch.player = player; tl.add_child(touch)
	pause = PauseMenu.new(); pause.touch = touch; add_child(pause)
	Dialogue.event.connect(_on_event)
	Fx.reset()
	build()
	set_cutscene(true)     # nothing moves until begin() says so
	_ao.call_deferred()

## Subclasses: where the ambient-occlusion map covers, [Rect2 (XZ), floor y, ceiling y], or []
## for none (scripts/world/ao_map.gd).
func ao_area() -> Array:
	return []

func ao_name() -> String:
	return String(name).to_snake_case()

func _ao() -> void:
	var a := ao_area()
	if a.is_empty(): AoMap.clear(world); return
	await get_tree().physics_frame; await get_tree().physics_frame      # (the walls into the physics world)
	if not is_inside_tree(): return
	AoMap.apply(world, ao_name(), a[0], a[1], a[2])

func _exit_tree() -> void:
	if Dialogue.event.is_connected(_on_event): Dialogue.event.disconnect(_on_event)

## Subclasses: make the place.
func build() -> void:
	pass

## Subclasses: the story starts (the screen is black).
func begin() -> void:
	set_cutscene(false)
	await Game.fade(0.0, 1.0)

## Subclasses: a stage direction from a conversation.
func on_event(_name: String, _step: Dictionary) -> void:
	pass

func _on_event(n: String, step: Dictionary) -> void:
	on_event(n, step)

func set_cutscene(on: bool) -> void:
	cutscene = on
	player.controls = not on
	player.look_enabled = not on
	if on: player.velocity = Vector3.ZERO

func objective(t: String) -> void:
	hud.set_objective(t)

func _process(delta: float) -> void:
	touch.visible = Game.uses_touch() and not cutscene
	if not Game.uses_touch() and not pause.visible and not Game.busy and not Dialogue.choosing() and not (skills_menu and skills_menu.visible):
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.window_is_focused():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.is_action_just_pressed("skip"): Dialogue.skip_line()
	if Input.is_action_just_pressed("skills") and not cutscene and not pause.visible and not skills_menu.visible: skills_menu.open()
	_tick_ambience(delta)
	# idle conversations: after a long enough quiet stretch of free play, the next one not yet had
	if random_talk and not cutscene and not Dialogue.busy and socko.visible:
		_quiet_t += delta
		if _quiet_t > 75.0 / Game.stat("talk_rate"):
			_quiet_t = 0.0
			for id in RANDOM:
				if not Game.flag("talked_" + id):
					Game.set_flag("talked_" + id); Dialogue.play(id); break
	else:
		_quiet_t = minf(_quiet_t, 40.0) if Dialogue.busy else _quiet_t

## Ambience: something that happens now and then, somewhere. `every` is [min, max] seconds.
var _amb: Array = []
func ambient(every: Array, f: Callable, first := -1.0) -> void:
	_amb.append({"every": every, "f": f, "t": first if first >= 0.0 else randf_range(every[0], every[1])})

func _tick_ambience(delta: float) -> void:
	for a in _amb:
		a.t -= delta
		if a.t <= 0.0:
			a.t = randf_range(a.every[0], a.every[1])
			a.f.call()

## Someone walking about in the flat upstairs: steps across the ceiling, and sometimes they stop
## right over you.
func walk_above(from: Vector3, to: Vector3) -> void:
	var n := randi_range(5, 10)
	for i in n:
		var p := from.lerp(to, float(i) / n)
		Sfx.play_at("step_above", p, -6.0, randf_range(0.9, 1.1), 14.0)
		await get_tree().create_timer(randf_range(0.5, 0.7)).timeout
	if randf() < 0.3:
		await get_tree().create_timer(2.0).timeout
		Sfx.play_at("thud_far", player.global_position + Vector3(0, 2.8, 0), -4.0)

## A wall switch: a bakelite rocker that toggles some fittings.
func switch(pos: Vector3, rot_y: float, fittings: Array) -> void:
	var plate := Build.box(world, pos, Vector3(0.075, 0.075, 0.012), Tex.mat("enamel", 8.0, {"tint": Color(0.85, 0.8, 0.7)}), false, rot_y)
	var h := Hotspot.make(world, pos, Vector3(0.2, 0.2, 0.15), "Light switch", func():
		for f in fittings: f.toggle()
		Sfx.play_at("switch", pos, -4.0))
	h.rotation.y = rot_y

## A box of space that calls `cb` the first time Kurt walks into it.
func zone(pos: Vector3, size: Vector3, cb: Callable, once := true) -> Area3D:
	var a := Area3D.new(); a.collision_layer = 0; a.collision_mask = 2
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size; cs.shape = sh
	a.add_child(cs); world.add_child(a); a.global_position = pos
	a.body_entered.connect(func(b):
		if b == player and a.get_meta("armed", true):
			if once: a.set_meta("armed", false)
			cb.call())
	return a

## Can Kurt see this point right now (in front of him, nothing in the way)?
func player_sees(p: Vector3, max_dist := 8.0, cone := 0.6) -> bool:
	var c := player.cam.global_position
	var d := p - c
	if d.length() > max_dist: return false
	if (-player.cam.global_transform.basis.z).dot(d.normalized()) < cone: return false
	var q := PhysicsRayQueryParameters3D.create(c, p, 1, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.position.distance_to(p) < 0.35
