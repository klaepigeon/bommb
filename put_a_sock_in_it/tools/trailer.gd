extends SceneTree
## A trailer, shot in the real game: run each part through Godot's Movie Maker (fixed 30 fps,
## sound captured), then tools/trailer.sh trims the loading off each and joins them.
##   part=flat   the landing and the knock, the hall, Marta in her chair, the jump, Socko, the hole
##   part=maze   the maze, her coming down a corridor and for him, the wardrobe, her at the doors
##   part=card   the title room, the name
## Everything here is staging (cameras, timing); no words but the game's name.
## Prints TRAILER_START <seconds> when the first shot begins, so the loading can be cut.

var game
var sfx
var part := "flat"
var fade: ColorRect
var title_lb: Label
var sub_lb: Label
var t_start := 0.0
var clock := 0.0

func _initialize() -> void:
	await process_frame
	for a in OS.get_cmdline_user_args(): if a.begins_with("part="): part = a.substr(5)
	game = root.get_node("Game"); sfx = root.get_node("Sfx")
	game.demo["hide_placeholders"] = true
	game.settings.sway = false
	process_frame.connect(func(): clock += 1.0 / 30.0)
	var layer := CanvasLayer.new(); layer.layer = 120; root.add_child.call_deferred(layer)
	fade = ColorRect.new(); fade.color = Color.BLACK; fade.set_anchors_preset(Control.PRESET_FULL_RECT); layer.add_child(fade)
	title_lb = _label(84, Color("e2d6b8")); layer.add_child(title_lb)
	sub_lb = _label(26, Color("a39780")); sub_lb.offset_top = 70; sub_lb.offset_bottom = 130; layer.add_child(sub_lb)
	for l in [title_lb, sub_lb]: l.offset_left += 330; l.offset_right += 330      # (right of Socko)
	await process_frame
	match part:
		"flat": await _flat()
		"maze": await _maze()
		"card": await _card()
	quit()

func _label(size: int, c: Color) -> Label:
	var l := Label.new(); l.set_anchors_preset(Control.PRESET_CENTER)
	l.offset_left = -600; l.offset_right = 600; l.offset_top = -60; l.offset_bottom = 60
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", c)
	l.modulate.a = 0.0
	return l

func _start() -> void:
	printerr("TRAILER_START %.3f" % clock)

func _hold(s: float) -> void:
	await create_timer(s).timeout

func _fade_to(a: float, s: float) -> void:
	var tw := create_tween(); tw.tween_property(fade, "color:a", a, s)
	await tw.finished

## The level, ready to shoot: no HUD, no subtitles, no touch buttons, nothing scripted starting.
func _level(id: String):
	game.change_level(id, {"card": false, "fade": 0.01, "checkpoint": id == "flesh47"})
	while game.level == null or game.busy: await process_frame
	await _hold(1.5)
	var L = game.level
	var dlg = root.get_node("Dialogue")
	dlg.stop()
	if not dlg.line_started.is_connected(_hush): dlg.line_started.connect(_hush)
	L.set_cutscene(true)
	L.random_talk = false
	L.hud.visible = false
	if L.touch: L.touch.visible = false
	# (the scripted beats start when he walks into places or sees her: not in a trailer)
	if "_seen_marta" in L: L._seen_marta = true
	for a in L.world.find_children("*", "Area3D", true, false): a.set_meta("armed", false)
	game._black.visible = false
	return L

## No words in the trailer: any line that starts is stopped.
func _hush(_step) -> void:
	root.get_node("Dialogue").stop.call_deferred()

## A camera move: from a to b over s seconds, looking from at_a to at_b.
func _move(P, a: Vector3, b: Vector3, look_a: Vector3, look_b: Vector3, s: float) -> void:
	var t := 0.0
	while t < s:
		var k := smoothstep(0.0, 1.0, t / s)
		P.global_position = a.lerp(b, k) - Vector3(0, P.head.position.y, 0)
		var d: Vector3 = look_a.lerp(look_b, k) - (a.lerp(b, k))
		P.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
		await process_frame
		t += 1.0 / 30.0

# ------------------------------------------------------------------ the flat
func _flat() -> void:
	var L = await _level("flat47")
	var P = L.player
	root.get_node("Dialogue").stop()
	_start()
	# black; the knocking
	for i in 3:
		sfx.play("knock", -2.0, randf_range(0.95, 1.05)); await _hold(0.45)
	await _hold(0.8)
	# the landing: in on the padded door
	var eye := 1.6
	_fade_to(0.0, 1.2)
	_move(P, Vector3(12.9, eye, 5.0), Vector3(11.4, eye, 4.4), Vector3(10.06, 1.35, 4.2), Vector3(10.06, 1.3, 4.2), 4.0)
	await _hold(1.8)
	for i in 2: sfx.play_at("knock", Vector3(10.1, 1.2, 4.3), 0.0, 1.0); await _hold(0.4)
	await _hold(1.4)
	await _fade_to(1.0, 0.25)
	# the hall, dark, down to where she sits
	L.front_door.set_open(true)
	_fade_to(0.0, 0.4)
	await _move(P, Vector3(9.4, eye, 4.5), Vector3(7.4, eye, 4.5), Vector3(4.0, 1.2, 4.5), Vector3(4.0, 1.1, 4.0), 3.2)
	await _fade_to(1.0, 0.25)
	# her, in the chair: in, slowly, and at the last her eyes come up to him
	var face: Vector3 = L._face()
	var from: Vector3 = L.marta.to_global(Vector3(0.35, 0, -2.4)) + Vector3(0, 1.55, 0)
	var to: Vector3 = L.marta.to_global(Vector3(0.0, 0, -1.25)) + Vector3(0, 1.5, 0)
	_fade_to(0.0, 0.6)
	sfx.loop("heart", "heart_loop", -14.0)
	_move(P, from, to, face + Vector3(0, -0.1, 0), face, 5.0)
	await _hold(3.6)
	L._eye_on_him()
	await _hold(1.45)
	await _hold(0.6)
	# the jump
	L._the_jump()
	await _hold(4.6)
	await _fade_to(1.0, 0.05)
	sfx.stop_loop("heart")
	await _hold(1.0)
	# Socko: on the floor, the sock over him
	L.jumper.visible = false; L._room_dark(false)
	P.global_position = L.LAND; P.head_override = 0.55
	P.set_view(-PI * 0.55, 0.15); P.set_roll(0.12)
	L.socko.visible = true; L.socko.hold = "face"; L.socko.look = "kurt"; L.socko.emotion = "happy"
	_fade_to(0.0, 0.8)
	await _hold(1.0)
	L.socko.gesture("tilt")
	await _hold(1.6)
	L.socko.emotion = "nervous"; L.socko.gesture("recoil")
	await _hold(1.2)
	await _fade_to(1.0, 0.3)
	# the hole where the box room was
	P.head_override = -1.0; P.set_roll(0.0)
	L.socko.visible = false
	L._push_wardrobe()
	await _hold(1.0)
	L.hole_parts.visible = true
	_fade_to(0.0, 0.5)
	await _move(P, L.HOLE + Vector3(2.2, 1.5, -1.0), L.HOLE + Vector3(1.3, 1.1, -0.45), L.HOLE + Vector3(0, 0.8, 0), L.HOLE + Vector3(-0.3, 0.75, 0), 3.0)
	await _fade_to(1.0, 0.4)
	await _hold(0.5)

# ------------------------------------------------------------------ the maze
func _maze() -> void:
	game.flags["maze_safe"] = 0; game.flags["met_marta_maze"] = true
	var F = await _level("flesh47")
	F._encountered = true
	var P = F.player; var m = F.marta
	m.set_physics_process(false)
	if m.caught_player.is_connected(F._on_caught): m.caught_player.disconnect(F._on_caught)
	var run: Array = F.straight(3)
	_start()
	# blue: down a corridor of the flat that goes on and on
	P.toggle_torch(true)
	var a: Vector3 = F.centre(run[0], 1.6); var b: Vector3 = F.centre(run[1], 1.6)
	_fade_to(0.0, 1.0)
	await _move(P, a + (a - b) * 0.3, a, b, F.centre(run[2], 1.3), 3.5)
	# at the far end of it, her; she comes
	m.global_position = F.centre(run[2]) + (F.centre(run[2]) - F.centre(run[1])) * 0.3
	m.look_at(Vector3(a.x, 0, a.z), Vector3.UP)
	m.set_physics_process(true); m.active = true
	m.set_state("patrol"); m.go_to(Vector3(a.x, 0, a.z))
	P.controls = false
	await _hold(2.8)
	m.set_state("chase"); m.go_to(Vector3(a.x, 0, a.z))
	sfx.play_at("marta_scream", m.head(), 2.0, 1.0)
	var t := 0.0
	while t < 4.0 and m.global_position.distance_to(Vector3(a.x, 0, a.z)) > 1.5:
		var d: Vector3 = m.head() - P.cam.global_position
		P.set_view(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))
		await process_frame; t += 1.0 / 30.0
	# a step short of him: hold on her, then cut
	m.set_physics_process(false); m.velocity = Vector3.ZERO
	await _hold(0.35)
	await _fade_to(1.0, 0.04)
	await _hold(0.8)
	# the wardrobe: inside, through the gap, her at the doors
	var hs = F.hide_spots[0]
	P.toggle_torch(false)
	hs.interact(P)
	m.global_position = hs.front() + hs.global_basis.z * 0.55
	m.look_at(hs.global_position, Vector3.UP)
	m._spot = hs; m.set_state("listen"); m._heard = 0.0
	m.set_physics_process(true)
	game.fear = 0.8
	m.listening.emit(hs)
	F.hud.visible = false
	_fade_to(0.0, 0.5)
	Input.action_press("hold_breath")
	await _hold(5.5)
	Input.action_release("hold_breath")
	await _fade_to(1.0, 0.6)
	await _hold(0.5)

# ------------------------------------------------------------------ the card
func _card() -> void:
	var t = load("res://scenes/title.tscn").instantiate(); root.add_child(t); current_scene = t
	await _hold(0.5)
	for c in t.find_children("*", "CanvasLayer", true, false): (c as CanvasLayer).visible = false
	_start()
	_fade_to(0.0, 1.2)
	await _hold(1.0)
	title_lb.text = "PUT A SOCK IN IT"
	sub_lb.text = "Playable demo"
	var tw := create_tween(); tw.tween_property(title_lb, "modulate:a", 1.0, 1.0)
	tw.parallel().tween_property(sub_lb, "modulate:a", 1.0, 1.6)
	await _hold(4.5)
	await _fade_to(1.0, 1.0)
