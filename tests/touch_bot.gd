extends Node
## Touch audit: plays a whole QUICK match from the real app using nothing but screen touches
## (no signals, no Net calls), the way a phone does. On the way it checks every visible input
## control (buttons, hold pads, swipe pads, timing rings, trace pads, sticks) is the topmost
## thing under its own centre, and that every button it taps actually fires.
## xvfb-run -a -s "-screen 0 2400x1080x24" godot --rendering-driver opengl3 --resolution 2400x1080 res://tests/touch_bot.tscn [-- --secs=240]

const SKIP := ["≡", "LEAVE", "LEAVE THE MATCH", "SETTINGS", "ONLINE", "LOCAL PARTY", "FACE", "ADD AI", "UI ", "TEXT ", "REDUCED", "LEFT-HANDED", "SCREEN SHAKE", "GET UP", "LOOK UP", "CONTINUE"]
var unreachable := {}
var dead := {}
var taps := 0
var fired := 0
var kinds := {}
var phases := {}
var _audit_i := 0


func _ready() -> void:
	Settings.set_v("match_turns", 10)
	var main: Node = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	get_tree().root.add_child.call_deferred(main)
	var secs := 240.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--secs="):
			secs = float(a.substr(7))
	await _wait(40)
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) / 1000.0 < secs:
		var all := _inputs()
		if Net.core:
			phases[str(Net.core.phase)] = true
		# audit everything on screen, a few per tick
		for k in mini(4, all.size()):
			var c = all[(_audit_i + k) % all.size()]
			if is_instance_valid(c):
				await _audit(c)
		_audit_i += 4
		all = _inputs()
		var pick = _choose(all.filter(func(x): return is_instance_valid(x)))
		if pick and is_instance_valid(pick):
			await _use(pick)
		await _wait(6)
		if Net.core and Net.core.ending != "":
			print("match ended: ", Net.core.ending)
			break
	print("TOUCH BOT: taps=%d fired=%d phases=%s kinds=%s" % [taps, fired, phases.keys(), kinds.keys()])
	for k in unreachable:
		print("  UNREACHABLE: ", k, " -> covered by ", unreachable[k])
	for k in dead:
		print("  DEAD TAP: ", k)
	var ok := unreachable.is_empty() and dead.is_empty() and fired > 0
	print("TOUCH BOT: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _label(c) -> String:
	if not is_instance_valid(c):
		return "?"
	var t := ""
	if c is Button:
		t = (c as Button).text.replace("\n", " ").left(28)
	return "%s '%s' [%s]" % [c.get_class() if c.get_script() == null else str(c.get_script().get_global_name() if c.get_script().get_global_name() != "" else c.get_script().resource_path.get_file()), t, Net.core.phase if Net.core else "menu"]


func _is_input(c: Node) -> bool:
	if not (c is Control) or not c.is_visible_in_tree():
		return false
	if c is BaseButton:
		return not (c as BaseButton).disabled
	return c.mouse_filter == Control.MOUSE_FILTER_STOP and c.get_script() != null and not (c is PanelContainer) and not (c is ColorRect)


func _inputs() -> Array:
	var out: Array = []
	_find(get_tree().root, out)
	return out


func _find(n: Node, out: Array) -> void:
	if _is_input(n):
		var r := (n as Control).get_global_rect()
		var shown := r.size.x > 4 and r.size.y > 4 and get_viewport().get_visible_rect().encloses(Rect2(r.get_center(), Vector2.ONE))
		# scrolled out of its list: the player scrolls to it, not a bug
		var a: Node = n.get_parent()
		while shown and a:
			if a is ScrollContainer and not (a as Control).get_global_rect().has_point(r.get_center()):
				shown = false
			a = a.get_parent()
		if shown:
			out.append(n)
	for c in n.get_children():
		_find(c, out)


func _screen(p: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * p


func _audit(c) -> void:
	if not is_instance_valid(c) or not c.is_visible_in_tree():
		return
	var mm := InputEventMouseMotion.new()
	mm.position = _screen(c.get_global_rect().get_center())
	mm.global_position = mm.position
	Input.parse_input_event(mm)
	await get_tree().process_frame
	if not is_instance_valid(c) or not c.is_visible_in_tree():
		return
	var top := get_viewport().gui_get_hovered_control()
	if top != c and not (top and c.is_ancestor_of(top)):
		var key := _label(c)
		if not unreachable.has(key):
			unreachable[key] = str(top.get_path()) if top else "nothing (input dropped)"


func _choose(all: Array) -> Control:
	var cands: Array = []
	for c in all:
		var txt: String = (c as Button).text if c is Button else ""
		var skip := false
		for s in SKIP:
			if txt.begins_with(s):
				skip = true
		if skip:
			continue
		cands.append(c)
	if cands.is_empty():
		return null
	for pref in ["PLAY", "SIT DOWN", "ROLL", "READY"]:
		for c in cands:
			if c is Button and (c as Button).text.begins_with(pref):
				return c
	return cands[randi() % cands.size()]


func _touch(p: Vector2, down: bool, idx := 0) -> void:
	var t := InputEventScreenTouch.new()
	t.position = _screen(p)
	t.pressed = down
	t.index = idx
	Input.parse_input_event(t)


func _drag(p: Vector2, rel: Vector2, idx := 0) -> void:
	var d := InputEventScreenDrag.new()
	d.position = _screen(p)
	d.relative = rel
	d.index = idx
	Input.parse_input_event(d)


func _use(c) -> void:
	if not is_instance_valid(c):
		return
	var r: Rect2 = c.get_global_rect()
	var p := r.get_center()
	var kind: String = _label(c).get_slice(" ", 0)
	kinds[kind] = true
	taps += 1
	if c is BaseButton:
		var hit := [false]
		var cb := func(): hit[0] = true
		(c as BaseButton).pressed.connect(cb)
		(c as BaseButton).button_down.connect(cb)
		var key: String = _label(c)
		_touch(p, true)
		await _wait(2)
		if is_instance_valid(c) and c.get_script() != null and str(c.get_script().resource_path).ends_with("controls.gd"):
			await _wait(30)    # a hold button: hold it a moment
		_touch(p, false)
		await _wait(2)
		if hit[0]:
			fired += 1
		else:
			dead[key] = true
		if is_instance_valid(c) and (c as BaseButton).pressed.is_connected(cb):
			(c as BaseButton).pressed.disconnect(cb)
			(c as BaseButton).button_down.disconnect(cb)
	else:
		# pads, rings, sticks: press, drag across, release
		_touch(p, true)
		await _wait(2)
		var dir := Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * minf(r.size.x, r.size.y) * 0.35
		for i in 8:
			_drag(p + dir * (i + 1) / 8.0, dir / 8.0)
			await get_tree().process_frame
		_touch(p + dir, false)
		fired += 1
