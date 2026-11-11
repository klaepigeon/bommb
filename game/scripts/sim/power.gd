extends Node
## Electricity. Circuits, each behind a breaker and a fuse. A circuit is live when its breaker is
## up, its fuse is in and it hasn't tripped. Lamps on a circuit (Lamp.circuit) light with it;
## appliances (the TV, the radio, a pump, an electric lock, a cut cable) ask live(). A live wire in
## water electrifies the water until the circuit trips (which it does, after a moment, the way
## breakers do). Fuses are things: pull one out of one circuit and it'll make another work.

signal changed(circuit: String)

var circuits := {}              ## id -> {"breaker": bool, "fuse": bool, "tripped": bool, "label": String}

func add(id: String, label: String, breaker := true, fuse := true) -> void:
	circuits[id] = {"breaker": breaker, "fuse": fuse, "tripped": false, "label": label}
	_sync(id)

func live(id: String) -> bool:
	if id == "": return true
	var c: Dictionary = circuits.get(id, {})
	return not c.is_empty() and c.breaker and c.fuse and not c.tripped

func set_breaker(id: String, up: bool) -> void:
	if not circuits.has(id): return
	var c: Dictionary = circuits[id]
	c.breaker = up
	if up: c.tripped = false
	_sync(id)

func set_fuse(id: String, present: bool) -> void:
	if not circuits.has(id): return
	circuits[id].fuse = present
	_sync(id)

func trip(id: String, why := "") -> void:
	if not live(id): return
	circuits[id].tripped = true
	circuits[id].breaker = false
	Log.mark("trip %s %s" % [id, why])
	World.emit_event("tripped", {"circuit": id, "why": why})
	_sync(id)

func _sync(id: String) -> void:
	Lights.circuits[id] = live(id)
	changed.emit(id)

func _ready() -> void:
	World.register("power", func(): return circuits.duplicate(true), func(d):
		for k in d:
			circuits[k] = d[k]
			_sync(k))
