extends Node
## The shared world state: places people go, rooms and who they belong to, every simulated
## person. Host-authoritative in multiplayer: only the host mutates this; clients mirror it.

## id → Place dictionary: {id, pos: Vector3, yaw: float, room: String, pose: "stand"|"sit"|"sleep"|"work",
## tags: Array, occupant: String ("" = free)}
var places: Dictionary = {}
## id → Room dictionary: {id, building, name, aabb: AABB, owners: Array[String], public: bool,
## open: [from, to] minutes or []}
var rooms: Dictionary = {}
## id → NPC node
var npcs: Dictionary = {}
var players: Array[Node3D] = []
## Street-level walking loop (patrols, wandering) and the two ends of the street, where people
## who live elsewhere come from and go to.
var patrol: Array = []
var edges: Array = []
## Rectangles (x0, z0, x1, z1) of the alley and back yard: gravel underfoot.
var yard_rects: Array = []
## Owned things taken from where they were: {item, owner, room, time}. Owners discover these
## only when they look (see npc.gd), never by being told by the game.
var missing: Array = []
## Money that changed hands: {time, from, to, amount, what}. Business owners' takings and every
## NPC's purse change only through pay().
var ledger: Array = []
## People who are gone (missing, dead): their businesses don't open, their places stay empty.
var gone: Dictionary = {}
## room id → Array of people invited in (on top of the owners).
var guests: Dictionary = {}
## Station power under the street (one lever): lights the platform, and makes the third rail live.
var power := false
var hood: Node                         ## the Neighbourhood (rooms' lights live there)
var power_lights: Array = []
signal power_changed(on: bool)
var purses: Dictionary = {}           ## id → dollars (NPCs and businesses' owners)

func clear() -> void:
	places.clear()
	rooms.clear()
	npcs.clear()
	players.clear()
	missing.clear()
	ledger.clear()
	gone.clear()
	power = false
	power_lights.clear()
	guests.clear()
	purses.clear()

func add_place(p: Dictionary) -> void:
	p.occupant = ""
	places[p.id] = p

func add_room(r: Dictionary) -> void:
	rooms[r.id] = r

## The room a point is in ("" = outdoors / street).
func room_at(pos: Vector3) -> String:
	for id in rooms:
		var a: AABB = rooms[id].aabb
		if a.grow(0.05).has_point(pos):
			return id
	return ""

## True if `who` (an NPC id, or "" for a stranger such as the player) may be in `room_id` now.
func may_enter(who: String, room_id: String) -> bool:
	if room_id == "" or not rooms.has(room_id):
		return true
	var r: Dictionary = rooms[room_id]
	if who != "" and (who in r.owners or who in guests.get(room_id, [])):
		return true
	if not r.public:
		return false
	if not r.owners.is_empty() and r.owners.all(func(o): return gone.has(o)):
		return false        # nobody left to open up
	if r.open.is_empty():
		return true
	return Clock.in_span(Clock.minute_of_day(), r.open[0], r.open[1])

## Claim a place for an NPC; false if someone else holds it.
func reserve(place_id: String, who: String) -> bool:
	var p: Dictionary = places.get(place_id, {})
	if p.is_empty() or (p.occupant != "" and p.occupant != who):
		return false
	p.occupant = who
	return true

func release(place_id: String, who: String) -> void:
	if places.has(place_id) and places[place_id].occupant == who:
		places[place_id].occupant = ""

## Free places carrying all of `tags`, nearest to `from` first.
func find_places(tags: Array, from: Vector3, who := "") -> Array:
	var out := []
	for id in places:
		var p: Dictionary = places[id]
		if p.occupant != "" and p.occupant != who:
			continue
		var ok := true
		for t in tags:
			if not t in p.tags:
				ok = false
				break
		if ok:
			out.append(p)
	out.sort_custom(func(a, b): return a.pos.distance_squared_to(from) < b.pos.distance_squared_to(from))
	return out

## Move money between people (NPC nodes or ids). Fails if the payer can't afford it.
func pay(from, to: String, amount: int, what: String) -> bool:
	var fid: String = from if from is String else from.id
	if purses.get(fid, 0) < amount:
		return false
	purses[fid] = purses.get(fid, 0) - amount
	purses[to] = purses.get(to, 0) + amount
	ledger.append({"time": Clock.total_minutes, "from": fid, "to": to, "amount": amount, "what": what})
	return true

func in_yard(p: Vector3) -> bool:
	for r in yard_rects:
		if p.x > r[0] and p.x < r[2] and p.z > r[1] and p.z < r[3]:
			return true
	return false

func nearest_edge(from: Vector3) -> Vector3:
	var best: Vector3 = edges[0] if not edges.is_empty() else Vector3.ZERO
	for e in edges:
		if e.distance_squared_to(from) < best.distance_squared_to(from):
			best = e
	return best

func set_power(on: bool) -> void:
	power = on
	for l in power_lights:
		if is_instance_valid(l):
			l.visible = on
	power_changed.emit(on)

## How lit a point is (0 dark .. 1 bright): the room's light, if it's on. The street counts as lit.
func light_at(pos: Vector3) -> float:
	var room := room_at(pos + Vector3.UP * 0.5)
	if room == "":
		return 1.0
	var l = hood
	if l and l.room_lights.has(room):
		var light: OmniLight3D = l.room_lights[room]
		return clampf(light.light_energy, 0.0, 1.0) if light.visible else 0.05
	return 0.3
