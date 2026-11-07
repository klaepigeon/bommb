extends Node
## Touch regression: runs the real app, taps PLAY, SIT DOWN, then ROLL with screen touches
## (as a phone sends them) and exits 1 if a button didn't fire. Run it at a phone size:
## xvfb-run -a -s "-screen 0 2400x1080x24" godot --rendering-driver opengl3 --resolution 2400x1080 res://tests/click_probe.tscn
var fired := {}
var rolled := false
var dead := 0

func _ready() -> void:
	var main: Node = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _wait(60)
	await _probe("menu")
	# go into a match
	var play := _btn_named("PLAY")
	if play: await _touch(play)
	await _wait(60)
	await _probe("after PLAY")
	var sit := _btn_named("SIT")
	if sit: await _touch(sit)
	for k in 6:
		await _wait(90)
		await _probe("match %d" % k)
		if rolled:
			break
	print("TOUCH PROBE: ", "PASS" if rolled and dead == 0 else "FAIL", " (rolled=", rolled, " dead=", dead, ")")
	get_tree().quit(0 if rolled and dead == 0 else 1)


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _btn_named(s: String) -> Button:
	var all: Array = []
	_find(get_tree().root, all)
	for b in all:
		if b.text.contains(s):
			return b
	return null


func _touch(b: Control) -> bool:
	var pos: Vector2 = get_viewport().get_final_transform() * b.get_global_rect().get_center()
	var ok := [false]
	var cb := func(): ok[0] = true
	if b is BaseButton:
		b.pressed.connect(cb)
		b.button_down.connect(cb)
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	mm.global_position = pos
	Input.parse_input_event(mm)
	await get_tree().process_frame
	var top := get_viewport().gui_get_hovered_control()
	for t in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.position = pos
		touch.pressed = t
		Input.parse_input_event(touch)
		await get_tree().process_frame
		await get_tree().process_frame
	await _wait(30)
	print("   after touch, sub=", Net.core.rules.sub if Net.core else "?", " roll=", Net.core.rules.roll if Net.core else "?")
	if is_instance_valid(b) and b is BaseButton and b.pressed.is_connected(cb):
		b.pressed.disconnect(cb)
		b.button_down.disconnect(cb)
	if not ok[0]:
		dead += 1
		print("   DEAD: '", (b as Button).text.replace("\n", " ") if b is Button else b.name, "' top=", top, " ", top.get_path() if top else "")
	return ok[0]


func _probe(tag: String) -> void:
	var all: Array = []
	_find(get_tree().root, all)
	print(tag, ": ", all.size(), " buttons: ", all.map(func(b): return b.text.replace("\n", " ").left(18)))
	# only probe in-match prompt buttons (pressing menu buttons would navigate away)
	if tag.begins_with("match"):
		for b in all:
			if is_instance_valid(b) and b.is_visible_in_tree() and not b.disabled and b.text.begins_with("ROLL"):
				var ok := await _touch(b)
				rolled = rolled or ok
				if ok:
					print("   ok: ", b.text.replace("\n", " ").left(20) if is_instance_valid(b) else "?")
				return


func _find(n: Node, out: Array) -> void:
	if n is Button and n.is_visible_in_tree():
		out.append(n)
	for c in n.get_children():
		_find(c, out)
