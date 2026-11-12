extends SceneTree
## The phone controls, by simulated touches: the stick walks him, a drag on the right turns his
## head, USE presses interact, two fingers at once work.
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/touch_test.gd
var fails := 0
func _initialize() -> void:
	await process_frame
	var game = root.get_node("Game")
	game.settings.force_touch = true
	game.change_level("flesh47", {"card": false, "checkpoint": true, "fade": 0.01})
	await _wait(1.0)
	var F = game.level
	var t0 := Time.get_ticks_msec()
	while not F.player.controls and Time.get_ticks_msec() - t0 < 20000: await process_frame
	await _wait(0.2)
	F.marta.active = false
	var p = F.player
	var t = F.touch
	_check(t.visible, "touch overlay shows")
	var sz: Vector2 = t.size
	var start: Vector3 = p.global_position
	var yaw0: float = p.get_yaw()
	# thumb down on the left, push up; finger on the right, drag sideways: both at once
	_touch(0, Vector2(sz.x * 0.2, sz.y * 0.7), true)
	_touch(1, Vector2(sz.x * 0.6, sz.y * 0.4), true)
	for i in 20:
		_drag(0, Vector2(sz.x * 0.2, sz.y * 0.7 - 60.0))
		_drag(1, Vector2(sz.x * 0.6 + i * 6.0, sz.y * 0.4))
		await _wait(0.05)
	await _wait(0.8)
	_touch(0, Vector2(sz.x * 0.2, sz.y * 0.7 - 60.0), false)
	_touch(1, Vector2(sz.x * 0.6, sz.y * 0.4), false)
	_check(p.global_position.distance_to(start) > 0.3, "the stick walks him (%.2f m)" % p.global_position.distance_to(start))
	_check(absf(p.get_yaw() - yaw0) > 0.05, "dragging on the right turns him")
	var got := [false]
	var cb := func(): got[0] = true
	# the USE button presses the interact action
	var use_pos: Vector2 = Vector2(t.layout.use[1], t.layout.use[2]) * sz
	var seen := false
	_touch(2, use_pos, true)
	await process_frame
	seen = Input.is_action_pressed("interact")
	_touch(2, use_pos, false)
	_check(seen, "USE presses interact")
	print("TOUCH_TEST fails=%d" % fails)
	quit()
func _touch(i: int, pos: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new(); e.index = i; e.position = pos; e.pressed = down
	Input.parse_input_event(e)
func _drag(i: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new(); e.index = i; e.position = pos
	Input.parse_input_event(e)
func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok: fails += 1
func _wait(secs: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < secs * 1000.0:
		await process_frame
