extends SceneTree
## The way out of Flat 47: the chain, three ways through it (axe, bath key, gun), and the door
## out to the end of the chapter. godot --headless --path hysteria -s tools/escape_test.gd

var ok := true
var heard := {}

class Ear extends Node:
	var into: Dictionary
	func hear(_pos: Vector3, _loud: float, what: String, _src: Node) -> void: into[what] = true

func check(cond: bool, what: String) -> void:
	print(("  ok  " if cond else " FAIL ") + what)
	ok = ok and cond

func fresh() -> Node:
	for c in root.get_children():
		if c.name == "Main": c.free()
	heard.clear()
	await process_frame
	var g := root.get_node_or_null("Game")
	if g: g.flags.clear()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.name = "Main"
	root.add_child(main)
	await process_frame; await process_frame
	main.encounter.process_mode = Node.PROCESS_MODE_DISABLED
	return main

func face_door(p: Node) -> void:
	p.global_position = Vector3(9.45, 0.02, 4.56); p.velocity = Vector3.ZERO
	p.yaw = -PI * 0.5; p.pitch = -0.08
	for i in 6: await physics_frame

func _initialize() -> void:
	var ear := Ear.new(); ear.into = heard; ear.add_to_group("listener"); root.add_child.call_deferred(ear)
	var noises = load("res://scripts/core/noise.gd")
	# ---- the chain, and the axe
	var main: Node = await fresh()
	var p = main.player; var e = main.escape; var d = e.door
	check(d != null and d.locked == "chain", "front door is on its chain")
	check(e.links.size() == 7 and e.links[0].visible, "the chain is there to see")
	await face_door(p)
	p._aim()
	check(p.target == d, "looking at the door: it's the target (" + str(p.target) + ")")
	d.interact(p)
	for i in 40: await physics_frame
	check(absf(d.angle - 0.11) < 0.02, "it opens as far as the chain lets it (%.3f)" % d.angle)
	check(root.get_node("Game").flags.get("chain_seen", false), "told it's padlocked")
	var axe: RigidBody3D = null
	for b in main.world.find_children("*", "RigidBody3D", true, false):
		if String(b.get("title")).to_lower() == "axe": axe = b
	check(axe != null, "the axe is in the flat")
	axe.global_position = p.hold.global_position; axe.linear_velocity = Vector3.ZERO
	p.grab(axe)
	for i in 20: await physics_frame
	check(p.held == axe, "Kurt has the axe in hand")
	p._aim()
	check(p.target == d, "holding the axe, the door is still the target")
	check(d.use_with_prompt(axe) == "Cut the chain with the axe", "prompt: cut the chain")
	p.use()
	check(p.held == axe, "using it on the chain doesn't drop the axe")
	await create_timer(0.3).timeout
	check(heard.has("axe"), "the blows are loud (heard as 'axe')")
	await create_timer(2.2).timeout
	check(e.free and d.locked == "" and e.links[0].global_position.y < 0.1, "three blows: the chain falls in a heap")
	check(root.get_node("Game").flags.get("escaped_by", "") == "axe", "escaped by the axe")
	check(not p.locked, "Kurt has his hands back")
	for i in 120: await physics_frame
	check(d.angle > 1.0, "the door swings out (%.2f)" % d.angle)
	# out through it
	p.drop()
	await face_door(p)
	Input.action_press("move_forward")
	for i in 240:
		await physics_frame
		if e._ended: break
	Input.action_release("move_forward")
	check(e._ended, "walking out ends the chapter (stopped at %s)" % str(p.global_position.snapped(Vector3.ONE * 0.01)))
	await create_timer(7.5).timeout
	check(main.find_child("ChapterEnd", false, false) != null, "the end card")

	# ---- the bath and the key
	main = await fresh(); p = main.player; e = main.escape; d = e.door
	check(e.water != null, "found the bath water")
	var plug: Node = main.world.find_child("Plug", true, false)
	check(plug != null and plug.prompt() == "Pull the plug", "the plug")
	plug.interact(p)
	check(e.draining, "pulled: it drains")
	await create_timer(1.0).timeout
	check(e._level < e.WATER_TOP, "the water goes down (%.3f)" % e._level)
	check(heard.has("gurgle"), "the gurgle carries")
	e._level = e.WATER_BOTTOM + 0.002
	await create_timer(0.3).timeout
	check(e.drained and not e.water.visible, "drained")
	var keys: Node = main.world.find_child("Keys", true, false)
	var shoe: Node = main.world.find_child("Child's shoe (right)", true, false)
	check(keys != null and shoe != null and shoe.get_child_count() > 0, "the keys and the other shoe, in the silt")
	keys.interact(p)
	check(e.has_key, "took the keys")
	check(d.prompt() == "Unlock the padlock", "the door offers the padlock")
	d.interact(p)
	check(e.free and root.get_node("Game").flags.get("escaped_by", "") == "key", "unlocked: quietly")

	# ---- the gun
	main = await fresh(); p = main.player; e = main.escape; d = e.door
	var pl: Node = e.padlock
	check(pl.shot(pl.global_position, Vector3.LEFT, false, 0) and not e.free, "one round: still holds")
	check(pl.shot(pl.global_position, Vector3.LEFT, false, 0) and e.free, "two rounds: the padlock comes apart")
	check(root.get_node("Game").flags.get("escaped_by", "") == "gun", "escaped by the gun")
	print("ESCAPE ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
