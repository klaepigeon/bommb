extends Level
## The Lab: ECHO (docs/LAB.md). An experiment: a maze in total dark, no torch. He sees by
## sound: a click of the tongue (POWER) sends out a slow wash of light from his mouth that shows
## the walls near him and fades; every noise anything makes does the same, from where it was
## (his footsteps when he runs, pale; the listener's, red). So does the listener, blind, hunting
## by sound: every click that lets him see is a click it hears. Reach the faint EXIT.
##
## Photosensitivity: the washes rise over a quarter of a second and fade over a second and a
## half, they're dim, and they're spaced (a click every 1.2 s at most; one wash per place per 0.8 s).

const CELL := 3.0
const N := 6
const SEED := 4127
var listener: Inhabitant
var _click_t := 0.0
var _recent := {}               # Vector2i (where) -> time of the last wash there
var _lights_off: Array = []
var _walls := {}                # Vector2i cell -> [n, e, s, w] has wall
var washes := 0                 # (how many: the test counts them)
var last_click: OmniLight3D     # (the last click's wash: the test watches it fade)

func build() -> void:
	add_to_group("level")
	var e := env.environment
	e.background_color = Color.BLACK
	e.ambient_light_energy = 0.0; e.ambient_light_color = Color.BLACK
	e.fog_enabled = false
	e.glow_enabled = false
	_maze()
	var floor_m := Tex.mat("concrete", 0.5, {"tint": Color(0.75, 0.72, 0.68)})
	Build.box(world, Vector3(N * CELL * 0.5, -0.05, N * CELL * 0.5), Vector3(N * CELL + 0.4, 0.1, N * CELL + 0.4), floor_m)
	Build.box(world, Vector3(N * CELL * 0.5, 3.05, N * CELL * 0.5), Vector3(N * CELL + 0.4, 0.1, N * CELL + 0.4), Tex.mat("black"))
	# the way out: the one thing that glows, faintly
	var ex := centre(Vector2i(N - 1, N - 1))
	LabKit.label(world, ex + Vector3(0, 1.6, CELL * 0.5 - 0.15), PI, "EXIT", 60, Color(0.35, 0.5, 0.35))
	var u := Use.make(world, ex + Vector3(0, 1.0, CELL * 0.5 - 0.3), Vector3(1.0, 2.0, 0.4), func(): return "Out (back to the Lab)", func(_p): Game.change_level("lab", {"card": false, "fade": 0.5}))
	u.name = "Exit"
	LabKit.bake_nav(world)
	# what hunts in here
	var prof: Dictionary = LabKit.PEOPLE["listener"].duplicate(true)
	prof["id"] = "echo_listener"; prof["faction"] = "listener"; prof["hostile_to"] = ["kurt"]
	prof["body"]["model"] = "listener"
	var pts := []
	for c in [Vector2i(N - 1, 0), Vector2i(0, N - 1), Vector2i(N - 2, N - 2), Vector2i(2, 3)]: pts.append(centre(c))
	prof["objectives"] = [{"type": "patrol", "points": pts, "wait": 3.0, "weight": 1.0}]
	listener = Inhabitant.new(prof); listener.level = self; listener.player = player
	world.add_child(listener); listener.global_position = centre(Vector2i(N - 1, 2))
	Game.noise.connect(_on_noise)
	player.position = centre(Vector2i(0, 0))
	player.set_view(PI, 0.0)
	socko.visible = true

func _exit_tree() -> void:
	super._exit_tree()
	if Game.noise.is_connected(_on_noise): Game.noise.disconnect(_on_noise)

func centre(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, 0, (c.y + 0.5) * CELL)

## A maze by depth-first carving (the same every time), walls as boxes.
func _maze() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = SEED
	var seen := {}
	for y in N: for x in N: _walls[Vector2i(x, y)] = [true, true, true, true]
	var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var stack := [Vector2i(0, 0)]; seen[Vector2i(0, 0)] = true
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var opts := []
		for i in 4:
			var n: Vector2i = c + dirs[i]
			if n.x >= 0 and n.y >= 0 and n.x < N and n.y < N and not seen.has(n): opts.append(i)
		if opts.is_empty(): stack.pop_back(); continue
		var i: int = opts[rng.randi() % opts.size()]
		var n2: Vector2i = c + dirs[i]
		_walls[c][i] = false; _walls[n2][(i + 2) % 4] = false
		seen[n2] = true; stack.append(n2)
	var wall_m := Tex.mat("plaster", 1.0, {"tint": Color(0.8, 0.78, 0.74)})
	for y in N:
		for x in N:
			var c := Vector2i(x, y)
			var o := Vector3(x * CELL, 0, y * CELL)
			if _walls[c][0]: Build.box(world, o + Vector3(CELL * 0.5, 1.5, 0), Vector3(CELL + 0.2, 3.0, 0.2), wall_m)
			if _walls[c][3]: Build.box(world, o + Vector3(0, 1.5, CELL * 0.5), Vector3(0.2, 3.0, CELL + 0.2), wall_m)
			if x == N - 1 and _walls[c][1]: Build.box(world, o + Vector3(CELL, 1.5, CELL * 0.5), Vector3(0.2, 3.0, CELL + 0.2), wall_m)
			if y == N - 1 and _walls[c][2]: Build.box(world, o + Vector3(CELL * 0.5, 1.5, CELL), Vector3(CELL + 0.2, 3.0, 0.2), wall_m)

# ------------------------------------------------------------------ seeing by sound
## A wash of light from where a sound was: rises over a quarter second, spreads, fades over a
## second and a half. Dim, steady in its change: no flash.
func wash(at: Vector3, col: Color, strength: float) -> OmniLight3D:
	var key := Vector2i(int(at.x / 2.0), int(at.z / 2.0))
	var now := Time.get_ticks_msec() * 0.001
	if now - float(_recent.get(key, -10.0)) < 0.8: return null
	_recent[key] = now
	washes += 1
	var l := OmniLight3D.new(); l.light_color = col; l.light_energy = 0.0; l.omni_range = 0.5; l.omni_attenuation = 1.4
	l.shadow_enabled = not OS.has_feature("mobile")
	world.add_child(l); l.global_position = at + Vector3(0, 1.2, 0)
	var reach := 3.0 + 6.0 * strength
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 1.1 * strength, 0.25)
	tw.parallel().tween_property(l, "omni_range", reach, 0.9)
	tw.tween_property(l, "light_energy", 0.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.queue_free)
	return l

func click() -> bool:
	if _click_t > 0.0: return false
	_click_t = 1.2
	Sfx.play("click", -2.0, randf_range(0.9, 1.1))
	Game.make_noise(player.global_position, 0.35)      # (it hears it: that's the price)
	last_click = wash(player.global_position, Color(0.85, 0.9, 1.0), 0.8)
	return true

func _on_noise(pos: Vector3, loud: float) -> void:
	if loud < 0.2 or pos.distance_to(player.global_position) < 0.5: return
	wash(pos, Color(0.85, 0.9, 1.0), clampf(loud, 0.2, 0.8))

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("power") and not cutscene: click()

var _scuttle_t := 0.0
func _process(delta: float) -> void:
	super._process(delta)
	_click_t = maxf(0.0, _click_t - delta)
	# no light but sound's: the torch won't come on, his own fill light's off
	player.torch_on = false
	if _lights_off.is_empty():
		for l in player.find_children("*", "Light3D", true, false): _lights_off.append(l)
	for l in _lights_off: if is_instance_valid(l): (l as Light3D).light_energy = 0.0
	# it moving: a dim red wash where its feet are
	if is_instance_valid(listener) and not listener.dead and listener.velocity.length() > 0.6:
		_scuttle_t -= delta
		if _scuttle_t <= 0.0:
			_scuttle_t = 1.3 if listener.velocity.length() < 2.0 else 0.8
			wash(listener.global_position, Color(1.0, 0.25, 0.2), 0.35)
			Sfx.play_at("step_flesh%d" % randi_range(0, 3), listener.global_position, -6.0, 0.8)

func on_player_down() -> void:
	set_cutscene(true)
	await Game.fade(1.0, 0.6)
	if not is_inside_tree(): return
	Game.change_level("lab_echo", {"card": false, "fade": 0.01})

func begin() -> void:
	set_cutscene(false)
	await Game.fade(0.0, 0.6)
	hud.hint("Dark. POWER (T) clicks: you see by sound, and it hears you.", 6.0)
