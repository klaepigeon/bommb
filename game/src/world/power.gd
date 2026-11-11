class_name Power
extends Node
## Electricity. Circuits (A, B, C...) fed through the fuse box; each room has a circuit and a wall
## switch. A room is lit when its circuit is live and its switch is on. Lights matter: Marta sees
## further in lit rooms and you see her; hazards (the flooded floor, the stripped cable) are only
## dangerous while their circuit is live.

signal changed(circuit: String)

var circuits := {}            # id -> {live: bool, fuse: bool}
var room_circuit := {}        # room id -> circuit id
var room_switch := {}         # room id -> bool
var flicker := {}             # room id -> strength 0..1
var fuse_box: Node = null
var level: Node

func add_circuit(id: String, live := true, fuse := true) -> void:
	circuits[id] = {"live": live, "fuse": fuse}

func is_live(circuit: String) -> bool:
	var c: Dictionary = circuits.get(circuit, {})
	return c.get("live", false) and c.get("fuse", false)

func room_lit(room: String) -> bool:
	if not room_circuit.has(room):
		return true                      # rooms with no wiring (Flat 48's daylight) are just lit
	return is_live(room_circuit[room]) and room_switch.get(room, true)

func set_live(circuit: String, v: bool) -> void:
	if not circuits.has(circuit):
		return
	circuits[circuit].live = v
	_changed(circuit)

func set_fuse(circuit: String, v: bool) -> void:
	if not circuits.has(circuit):
		return
	circuits[circuit].fuse = v
	_changed(circuit)

func toggle_switch(room: String) -> void:
	room_switch[room] = not room_switch.get(room, true)
	Sfx.play_at("switch", level.room_center(room), -4.0, 1.0, 1.5)
	_changed(room_circuit.get(room, ""))

func _changed(circuit: String) -> void:
	changed.emit(circuit)
	Events.world_changed.emit(self, "power:" + circuit)
	if level:
		level.refresh_power()

func get_state() -> Dictionary:
	return {"circuits": circuits, "switch": room_switch}

func set_state(d: Dictionary) -> void:
	for k in d.get("circuits", {}):
		circuits[k] = d.circuits[k]
	for k in d.get("switch", {}):
		room_switch[k] = d.switch[k]
	if level:
		level.refresh_power()
