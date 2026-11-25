extends Node
## All sound. One-shots come from a pool of 3D players; places have loops (a radio, a hum, a
## crowd). Everything is driven by the world rather than scripted:
## - a loop belongs to a room ("" = the street); heard from anywhere else it is muffled
##   (low-pass, quieter), so the Vesper's music thumps through the wall and the street goes dull
##   when you shut yourself in;
## - music marked `when_open` plays only while the room is open;
## - a `crowd` loop is as loud as the room is full (no people, no murmur).
## Sounds are named in data/asset_registry.json ("sounds"), like props.

const POOL := 24
const MUFFLED_HZ := 650.0
const CLEAR_HZ := 20500.0

var _streams: Dictionary = {}       ## id → Array[AudioStream]
var _pool: Array[AudioStreamPlayer3D] = []
var _next := 0
var _ui: AudioStreamPlayer
var _loops: Array[Dictionary] = []  ## {player, room, base_db, when_open, crowd}
var _root: Node3D
var _t := 0.0
var listener_room := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui = AudioStreamPlayer.new()
	add_child(_ui)

## The 3D world the sounds live in (called by main once the world exists).
func attach(world: Node3D) -> void:
	_root = Node3D.new()
	_root.name = "Sfx"
	world.add_child(_root)
	_pool.clear()
	_loops.clear()
	for i in POOL:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 4.0
		p.max_distance = 40.0
		p.attenuation_filter_cutoff_hz = CLEAR_HZ
		_root.add_child(p)
		_pool.append(p)

func _variants(id: String) -> Array:
	if _streams.has(id):
		return _streams[id]
	var out := []
	var def: Dictionary = Assets.registry.get("sounds", {}).get(id, {})
	for path in def.get("paths", []):
		var s := load(path)
		if s:
			out.append(s)
	_streams[id] = out
	return out

func _db(id: String) -> float:
	return float(Assets.registry.get("sounds", {}).get(id, {}).get("volume_db", 0.0))

## A one-shot at a point in the world. Returns the player (or null if the sound is unknown).
func play_at(id: String, pos: Vector3, db := 0.0, pitch_jitter := 0.08) -> AudioStreamPlayer3D:
	var v := _variants(id)
	if v.is_empty() or _pool.is_empty():
		return null
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = v[randi() % v.size()]
	p.volume_db = _db(id) + db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.global_position = pos
	var room := World.room_at(pos + Vector3.UP * 0.5)
	p.attenuation_filter_cutoff_hz = CLEAR_HZ if room == listener_room else MUFFLED_HZ
	p.play()
	return p

func ui(id: String) -> void:
	var v := _variants(id)
	if v.is_empty():
		return
	_ui.stream = v[0]
	_ui.volume_db = _db(id)
	_ui.play()

## A looping sound belonging to `room` ("" = outdoors), placed at `pos`.
## opts: {when_open: bool, crowd: bool, size: float (metres it fills)}
func loop_at(id: String, pos: Vector3, room: String, opts := {}) -> void:
	var v := _variants(id)
	if v.is_empty() or _root == null:
		return
	var s: AudioStream = v[0]
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.unit_size = float(opts.get("size", 6.0))
	p.max_distance = float(opts.get("size", 6.0)) * 5.0
	p.volume_db = -80.0
	_root.add_child(p)
	p.global_position = pos
	p.play(randf() * maxf(s.get_length() - 1.0, 0.0))
	_loops.append({"player": p, "room": room, "base_db": _db(id), "when_open": opts.get("when_open", false), "crowd": opts.get("crowd", false)})

func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or World.players.is_empty():
		return
	_t = 0.2
	listener_room = World.room_at(World.players[0].global_position + Vector3.UP * 0.5)
	for l in _loops:
		var p: AudioStreamPlayer3D = l.player
		var target: float = l.base_db
		if l.when_open and l.room != "" and not World.may_enter("", l.room):
			target = -80.0
		if l.crowd:
			var n := _occupants(l.room)
			target = -80.0 if n == 0 else target + linear_to_db(clampf(n / 5.0, 0.15, 1.2))
		var here: bool = l.room == listener_room
		if not here and target > -79.0:
			target -= 9.0
		p.attenuation_filter_cutoff_hz = CLEAR_HZ if here else MUFFLED_HZ
		p.volume_db = lerpf(p.volume_db, target, 0.35) if target > -79.0 else maxf(p.volume_db - 6.0, -80.0)

func _occupants(room: String) -> int:
	var n := 0
	for npc in World.npcs.values():
		if not npc.hidden_away and World.room_at(npc.global_position + Vector3.UP * 0.5) == room:
			n += 1
	return n

## Footstep surface for a point: from the room's floor, or the street / yard outside.
func surface_at(pos: Vector3) -> String:
	var room := World.room_at(pos + Vector3.UP * 0.5)
	if room == "":
		return "gravel" if World.in_yard(pos) else "boots"
	var floor: String = World.rooms[room].get("floor", "")
	if floor.begins_with("tile"):
		return "tile"
	if floor.begins_with("wood") or floor in ["planks", "carpet"]:
		return "wood"
	if floor == "diamond_plate":
		return "metal"
	return "boots"
