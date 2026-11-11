extends Node
var main: Node
func _ready() -> void:
	main = load("res://src/main.tscn").instantiate()
	main.args = {"autotest": "none"}
	add_child(main)
	await get_tree().process_frame
	await main.load_level("flat47", "")
	for i in 20: await get_tree().process_frame
	var hud = main.hud
	var tb := Button.new(); tb.text = "TEST"; tb.position = Vector2(500, 500); tb.size = Vector2(200, 80)
	tb.pressed.connect(func(): print("PROBE bare button pressed"))
	get_tree().root.add_child(tb)
	await get_tree().process_frame
	var bc := tb.get_global_rect().get_center()
	for pr in [true, false]:
		var m := InputEventMouseButton.new(); m.button_index = MOUSE_BUTTON_LEFT; m.position = bc; m.global_position = bc; m.pressed = pr; m.button_mask = 1 if pr else 0
		get_viewport().push_input(m)
		await get_tree().process_frame
	print("PROBE bare done; HUD visible ", hud.visible, " root size ", hud.root.size, " pause size ", hud.pause.size)
	hud.open_pause()
	for i in 5: await get_tree().process_frame
	var res: Button
	for b in hud.root.find_children("*", "Button", true, false):
		if (b as Button).text.strip_edges() == "Resume": res = b
	print("PROBE resume rect ", res.get_global_rect(), " visible ", res.is_visible_in_tree(), " paused ", get_tree().paused)
	res.pressed.connect(func(): print("PROBE PRESSED"))
	res.gui_input.connect(func(e): print("PROBE gui_input ", e))
	var c := res.get_global_rect().get_center()
	for n in get_tree().root.find_children("*", "Control", true, false):
		var cc := n as Control
		if cc.is_visible_in_tree() and cc.get_global_rect().has_point(c) and cc.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			print("PROBE ctl under point: ", cc.get_path(), " filter ", cc.mouse_filter, " pm ", cc.process_mode, " can_process ", cc.can_process())
			cc.gui_input.connect(func(e): if e is InputEventMouseButton: print("PROBE gui at ", cc.name))
	var hit = get_viewport().gui_get_hovered_control()
	print("PROBE hovered before ", hit)
	var vm := InputEventMouseMotion.new(); vm.position = c; vm.global_position = c
	get_viewport().push_input(vm)
	await get_tree().process_frame
	print("PROBE hovered after motion ", get_viewport().gui_get_hovered_control())
	var pm := InputEventMouseButton.new(); pm.button_index = MOUSE_BUTTON_LEFT; pm.position = c; pm.global_position = c; pm.pressed = true; pm.button_mask = 1
	get_viewport().push_input(pm)
	await get_tree().process_frame
	pm = pm.duplicate(); pm.pressed = false; pm.button_mask = 0
	get_viewport().push_input(pm)
	await get_tree().process_frame
	print("PROBE after push_input: pause visible ", hud.pause.visible)
	hud.open_pause()
	await get_tree().process_frame
	for kind in ["touch", "mouse"]:
		if kind == "touch":
			var e := InputEventScreenTouch.new(); e.index = 0; e.position = c; e.pressed = true
			Input.parse_input_event(e)
			for i in 3: await get_tree().process_frame
			e = InputEventScreenTouch.new(); e.index = 0; e.position = c; e.pressed = false
			Input.parse_input_event(e)
		else:
			var m := InputEventMouseButton.new(); m.button_index = MOUSE_BUTTON_LEFT; m.position = c; m.global_position = c; m.pressed = true; m.button_mask = 1
			Input.parse_input_event(m)
			for i in 3: await get_tree().process_frame
			m = InputEventMouseButton.new(); m.button_index = MOUSE_BUTTON_LEFT; m.position = c; m.global_position = c; m.pressed = false
			Input.parse_input_event(m)
		for i in 3: await get_tree().process_frame
		print("PROBE after ", kind, ": pause visible ", hud.pause.visible, " control at point: ", get_viewport().gui_find_control(c) if get_viewport().has_method("gui_find_control") else "?")
	get_tree().quit()
