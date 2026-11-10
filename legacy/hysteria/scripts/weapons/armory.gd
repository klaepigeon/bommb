class_name Armory
extends Node
## What Kurt carries: the guns he's found, in the order he found them. [Q] / D-pad up / GUN goes
## holstered → the first → the next → holstered. Only one is ever out; it's `player.gun`, the
## one his right hand holds and the HUD shows.

var player: Node
var weapons: Array[Node3D] = []

signal changed

func setup(p_player: Node) -> void:
	player = p_player
	player.set("armory", self)
	Revolver.ensure_inputs()

## A gun he's just taken: it goes in his hand.
func add(w: Node3D) -> void:
	if not weapons.has(w): weapons.append(w)
	for o in weapons: o.set("drawn", o == w)
	player.set("gun", w)
	changed.emit()

func has_kind(kind: String) -> bool:
	for w in weapons:
		if String(w.get("kind")) == kind: return true
	return false

func get_kind(kind: String) -> Node3D:
	for w in weapons:
		if String(w.get("kind")) == kind: return w
	return null

func _unhandled_input(e: InputEvent) -> void:
	if player and not player.get("locked") and e.is_action_pressed("weapon"):
		cycle()
		get_viewport().set_input_as_handled()

func cycle() -> void:
	if weapons.is_empty(): return
	var cur: Node3D = player.get("gun")
	if cur and bool(cur.get("reloading")): return
	if cur and bool(cur.get("drawn")):
		cur.set("drawn", false)
		var i := weapons.find(cur) + 1
		if i < weapons.size():
			weapons[i].set("drawn", true); player.set("gun", weapons[i])
	else:
		var w: Node3D = cur if cur else weapons[0]
		w.set("drawn", true); player.set("gun", w)
	if player.get("gun"): player.get("gun").call("_sfx", Revolver._click(0.6))
	changed.emit()
