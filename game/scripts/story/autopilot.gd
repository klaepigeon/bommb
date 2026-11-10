extends Node
## Plays Scene A by itself through the same controls a player uses (walks, turns, presses USE),
## then checks every line was said, in the owner's order. With --shots=<dir>, saves frames.

var main
var shots := ""
var _leg_timeout := 0.0

const EXPECTED := ["door_1", "door_2", "see_flat", "see_marta", "examine", "boxes", "marta_q",
	"little_bird", "gasp", "smarts", "hey_buddy", "wtf", "who_me", "who_are_you", "im_socko",
	"kurt_sounds", "dont_know", "got_nothing", "too_fast", "wont_open", "locked", "thanks",
	"welcome", "like_helping"]

func _ready() -> void:
	shots = main.args.get("shots", "")
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
		Speech.line_started.connect(func(_s, _t): _shot_later("line_%02d" % Speech.history.size(), 0.6))
	main.hud.controls.autopilot = true
	if main.args.has("fast"):
		Engine.time_scale = 4.0
	_run()

func _fail(why: String) -> void:
	print("AUTOTEST FAIL: ", why, "  (stage ", main.scene.stage, ", at ", main.player.global_position, ")")
	print("lines said: ", Speech.history)
	get_tree().quit(1)

func _stage(s: String) -> void:
	var t := 0.0
	while main.scene.stage != s:
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > 120.0:
			_fail("never reached stage " + s)
			return

func _walk(points: Array) -> bool:
	var p: Player = main.player
	for target in points:
		var t := 0.0
		while true:
			await get_tree().physics_frame
			var d: Vector3 = target - p.global_position
			d.y = 0
			if d.length() < 0.3:
				break
			if not p.can_move:          # a line or a scene took over: wait it out
				main.hud.controls.autopilot_move = Vector2.ZERO
				continue
			var want := atan2(-d.x, -d.z)
			p.rotation.y = lerp_angle(p.rotation.y, want, 0.5)
			main.hud.controls.autopilot_move = Vector2(0, -1)
			t += get_physics_process_delta_time()
			if t > 25.0:
				main.hud.controls.autopilot_move = Vector2.ZERO
				_fail("stuck walking to %s" % target)
				return false
	main.hud.controls.autopilot_move = Vector2.ZERO
	return true

func _use(point: Vector3) -> bool:
	var p: Player = main.player
	for i in 200:
		await get_tree().physics_frame
		if not p.can_move:
			continue
		p.face(point)
		if p.focus and p.focus.enabled:
			p.try_interact()
			return true
	_fail("couldn't use the thing at %s" % point)
	return false

func _run() -> void:
	await _stage("explore")
	if shots != "":
		_shot_later("01_hallway_entry", 0.2)
	if not await _walk([Vector3(0.0, 0, -0.9), Vector3(-0.35, 0, -2.5), Vector3(-0.35, 0, -3.95)]):
		return
	# turn into the living room doorway and look at what's there
	main.player.face(Vector3(-3.0, 1.1, -3.9))
	await get_tree().create_timer(0.5).timeout
	if not await _walk([Vector3(-1.6, 0, -3.8)]):
		return
	while not Speech.history.has("see_marta") or main.scene.busy:
		main.player.face(main.marta.head.global_position)
		await get_tree().physics_frame
	if shots != "":
		_shot_later("02_marta", 0.1)
		await get_tree().create_timer(0.5).timeout
	if not await _walk([Vector3(-2.3, 0, -2.85), Vector3(-2.95, 0, -2.85)]):
		return
	if not await _use(main.marta.head.global_position):
		return
	await _stage("wake")
	await _stage("explore")
	if shots != "":
		main.player.face(main.player.global_position + Vector3(0, -1.0, -0.6))
		await get_tree().create_timer(0.3).timeout
		await _shot("03_look_down")
	if not await _walk([Vector3(-2.0, 0, -2.8), Vector3(-1.6, 0, -3.95), Vector3(-0.35, 0, -3.9), Vector3(-0.35, 0, -2.0), Vector3(0.1, 0, -0.8)]):
		return
	if not await _use(Vector3(0.2, 1.0, 0.0)):
		return
	await _stage("scene_a_done")
	if Speech.history != EXPECTED:
		_fail("lines out of order or missing:\n  expected %s\n  got      %s" % [EXPECTED, Speech.history])
		return
	# the door must still be shut and solid
	if absf(main.flat.front_door.angle) > 0.1:
		_fail("front door isn't shut")
		return
	print("AUTOTEST PASS: Scene A played through; %d lines in order" % Speech.history.size())
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0)

func _shot_later(name: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	await _shot(name)

func _shot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shots.path_join(name + ".png"))
