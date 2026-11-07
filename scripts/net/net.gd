extends Node
## The match link, for every way of playing. It owns the MatchCore when this machine is
## the authority (offline: single-player and local; online: the host) and ticks it; it
## sends each screen what it may see, and carries everyone's input back to the core.
## Clients never run rules: they show what the host sends.
##
## Transports are swappable (modular): ENet straight to the host (LAN, or a forwarded
## port), found by room code over a LAN beacon or by address; or the relay (RelayPeer)
## for internet play, where the relay hands out the room code.
##
## Lobby: Seats is the host's; it's pushed to everyone whenever it changes. Disconnects:
## in the lobby the seat empties; in a match the Caller (an AI) plays it, and the player
## can come back with the same room code and name and take it back.

signal lobby_changed
signal status(text: String)
signal match_started
signal state(view: Dictionary, events: Array)
signal left(reason: String)
signal back_to_lobby

const SEND_HZ := 15.0

var role := "none"            # none | offline | host | client
var transport := ""           # enet | relay
var code := ""
var core: MatchCore
var my_seats: Array = []      # the seats this machine's people are in
var peer_seats: Dictionary = {}   # host: peer id -> seat
var away: Dictionary = {}     # host: name -> seat, for players who dropped out mid-match
var in_match := false
var match_seed := 0
var beacon: LanBeacon
var relay: RelayPeer
var _send_t := 0.0
var _pending: Dictionary = {}   # peer -> events waiting to go
var last_view: Dictionary = {}
var _join_info := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	beacon = LanBeacon.new()
	beacon.port = int(ProjectSettings.get_setting("meat_party/net/lan_discovery_port", 24511))
	add_child(beacon)
	beacon.found.connect(_on_beacon)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): _fail("Couldn't connect."))
	multiplayer.server_disconnected.connect(func(): _fail("The host has gone."))


func is_authority() -> bool:
	return role in ["offline", "host"]


func online() -> bool:
	return role in ["host", "client"]


# --- offline -----------------------------------------------------------------------

func start_offline() -> void:
	leave_quiet()
	role = "offline"


# --- hosting -------------------------------------------------------------------------

func host_lan() -> Error:
	leave_quiet()
	var p := ENetMultiplayerPeer.new()
	var port := int(ProjectSettings.get_setting("meat_party/net/enet_port", 24510))
	var err := p.create_server(port, Seats.MAX - 1)
	if err != OK:
		status.emit("Couldn't open port %d (%s)." % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = p
	role = "host"
	transport = "enet"
	code = _local_code()
	_host_lobby()
	beacon.shout({"game": "meatparty", "code": code, "port": port, "host": str(Settings.get_v("name"))})
	status.emit("Room %s is open on this network." % code)
	return OK


func host_relay() -> Error:
	leave_quiet()
	relay = RelayPeer.new()
	relay.room_ready.connect(func(c: String):
		code = c
		status.emit("Room %s is open. Tell your friends the code." % c)
		lobby_changed.emit())
	relay.relay_error.connect(_fail)
	var err := relay.host(Settings.relay_url())
	if err != OK:
		_fail("Couldn't reach the relay (%s)." % error_string(err))
		return err
	multiplayer.multiplayer_peer = relay
	role = "host"
	transport = "relay"
	code = "....."
	_host_lobby()
	status.emit("Opening a room on the relay...")
	return OK


func _host_lobby() -> void:
	Seats.reset("online")
	Seats.set_seat(0, {"kind": "local", "name": str(Settings.get_v("name")), "peer": 1, "ready": true, "face": int(Settings.get_v("face", 0))})
	my_seats = [0]
	peer_seats = {1: 0}
	away.clear()
	in_match = false
	lobby_changed.emit()


func _local_code() -> String:
	const L := "ABCDEFGHJKLMNPQRSTUVWXYZ"
	var c := ""
	for i in 5:
		c += L[randi() % L.length()]
	return c


# --- joining ------------------------------------------------------------------------

## A room code: look for it on this network first, then ask the relay.
func join_code(room: String) -> void:
	leave_quiet()
	room = room.strip_edges().to_upper()
	_join_info = {"code": room, "found": false}
	role = "client"
	status.emit("Looking for room %s..." % room)
	beacon.listen()
	get_tree().create_timer(2.5).timeout.connect(func():
		if role == "client" and not _join_info.get("found", false) and multiplayer.multiplayer_peer == null:
			beacon.stop()
			_join_relay(room))


func _on_beacon(info: Dictionary) -> void:
	if role != "client" or _join_info.is_empty() or _join_info.found:
		return
	if str(info.get("code", "")) == _join_info.code:
		_join_info.found = true
		beacon.stop()
		join_ip(str(info.ip), int(info.port))


func join_ip(ip: String, port: int = 0) -> void:
	if port == 0:
		port = int(ProjectSettings.get_setting("meat_party/net/enet_port", 24510))
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(ip, port)
	if err != OK:
		_fail("Couldn't connect to %s:%d." % [ip, port])
		return
	multiplayer.multiplayer_peer = p
	role = "client"
	transport = "enet"
	status.emit("Connecting to %s..." % ip)


func _join_relay(room: String) -> void:
	relay = RelayPeer.new()
	relay.relay_error.connect(_fail)
	var err := relay.join(Settings.relay_url(), room)
	if err != OK:
		_fail("No room %s nearby, and the relay can't be reached." % room)
		return
	multiplayer.multiplayer_peer = relay
	role = "client"
	transport = "relay"
	code = room
	status.emit("Asking the relay for room %s..." % room)


func _on_connected() -> void:
	status.emit("Connected. Saying hello...")
	_c_hello.rpc_id(1, str(Settings.get_v("name")), int(Settings.get_v("face", 0)))


func leave() -> void:
	leave_quiet()
	left.emit("You left.")


func leave_quiet() -> void:
	beacon.stop()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	relay = null
	role = "none"
	core = null
	in_match = false
	my_seats = []
	peer_seats = {}
	last_view = {}


func _fail(msg: String) -> void:
	var was := role
	leave_quiet()
	status.emit(msg)
	if was != "none":
		left.emit(msg)


# --- lobby RPCs -----------------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	if role == "host":
		status.emit("Someone is joining...")


func _on_peer_disconnected(id: int) -> void:
	if role != "host" or not peer_seats.has(id):
		return
	var seat: int = peer_seats[id]
	peer_seats.erase(id)
	if in_match and core:
		away[Seats.seats[seat].name] = seat
		core.seat_disconnected(seat)
		Seats.seats[seat].kind = "ai"
	else:
		Seats.clear_seat(seat)
	_push_seats()


@rpc("any_peer", "call_remote", "reliable")
func _c_hello(pname: String, face: int) -> void:
	if role != "host":
		return
	var id := multiplayer.get_remote_sender_id()
	# Coming back to a match in progress?
	if in_match and away.has(pname):
		var seat: int = away[pname]
		away.erase(pname)
		peer_seats[id] = seat
		Seats.seats[seat].kind = "remote"
		Seats.seats[seat].peer = id
		core.p(seat).kind = "remote"
		core.p(seat).peer = id
		core.toast("%s is back." % pname)
		_s_start.rpc_id(id, Seats.to_array(), match_seed, seat)
		return
	if in_match:
		_s_refuse.rpc_id(id, "That match has already started.")
		return
	var seat := Seats.first_free()
	if seat < 0:
		# an AI can be bumped for a person
		for s in Seats.seats:
			if s.kind == "ai":
				seat = s.seat
				break
	if seat < 0:
		_s_refuse.rpc_id(id, "The room is full.")
		return
	Seats.set_seat(seat, {"kind": "remote", "name": pname, "peer": id, "ready": false, "face": face})
	peer_seats[id] = seat
	_push_seats()


@rpc("authority", "call_remote", "reliable")
func _s_refuse(msg: String) -> void:
	_fail(msg)


func _push_seats() -> void:
	lobby_changed.emit()
	if role == "host":
		_s_seats.rpc(Seats.to_array(), code)


@rpc("authority", "call_remote", "reliable")
func _s_seats(arr: Array, room: String) -> void:
	Seats.from_array(arr)
	code = room
	my_seats = []
	for s in arr:
		if int(s.peer) == multiplayer.get_unique_id() and s.kind == "remote":
			my_seats.append(int(s.seat))
	status.emit("In room %s." % room)
	lobby_changed.emit()


func set_ready(on: bool) -> void:
	if role == "client":
		_c_ready.rpc_id(1, on)
	elif role == "host":
		Seats.seats[0].ready = on


@rpc("any_peer", "call_remote", "reliable")
func _c_ready(on: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if role == "host" and peer_seats.has(id):
		Seats.seats[peer_seats[id]].ready = on
		_push_seats()


## Host only: put an AI in an empty seat, or empty an AI's seat.
func toggle_ai(seat: int) -> void:
	if not is_authority() or in_match:
		return
	if Seats.seats[seat].kind == "empty":
		Seats.add_ai(seat)
	elif Seats.seats[seat].kind == "ai":
		Seats.clear_seat(seat)
	_push_seats()


func all_ready() -> bool:
	for s in Seats.seats:
		if s.kind == "remote" and not s.ready:
			return false
	return true


# --- the match ------------------------------------------------------------------------

## Authority only: fill the empty seats with AI and begin, everywhere.
func launch(seed_v: int = 0) -> void:
	if not is_authority():
		return
	Seats.fill_with_ai()
	match_seed = seed_v if seed_v != 0 else randi() % 2147483646 + 1
	if role == "offline":
		my_seats = []
		for s in Seats.seats:
			if s.kind == "local":
				my_seats.append(int(s.seat))
	else:
		beacon.stop()
		_s_seats.rpc(Seats.to_array(), code)
		_s_start.rpc(Seats.to_array(), match_seed, -1)
	_begin(Seats.to_array(), match_seed)


## An offline match from the save file (SaveManager): same seats, same round, same dice.
func resume_offline(d: Dictionary) -> void:
	start_offline()
	var arr: Array = Saves.seats_of(d)
	Seats.from_array(arr)
	my_seats = []
	for s in Seats.seats:
		if s.kind == "local":
			my_seats.append(int(s.seat))
	in_match = true
	core = MatchCore.from_snapshot(Seats.to_array(), d.get("match", {}))
	match_seed = core.seed_value
	match_started.emit()


func _begin(arr: Array, seed_v: int) -> void:
	in_match = true
	core = MatchCore.new()
	core.setup(arr, seed_v, {"turns": int(Settings.get_v("match_turns", 15)), "mode": str(Settings.get_v("match_mode", "classic")),
		"pacing": str(Settings.get_v("pacing", "standard")), "flow_step": OS.get_cmdline_user_args().has("--flow-step")})
	match_started.emit()


@rpc("authority", "call_remote", "reliable")
func _s_start(arr: Array, seed_v: int, rejoin_seat: int) -> void:
	Seats.from_array(arr)
	match_seed = seed_v
	in_match = true
	my_seats = []
	for s in arr:
		if int(s.peer) == multiplayer.get_unique_id() and s.kind == "remote":
			my_seats.append(int(s.seat))
	if rejoin_seat >= 0 and not my_seats.has(rejoin_seat):
		my_seats.append(rejoin_seat)
	match_started.emit()


## Anyone's input: straight into the core here, or up to the host.
func send_action(seat: int, a: Dictionary) -> void:
	if is_authority():
		if core and (role == "offline" or my_seats.has(seat)):
			core.action(seat, a)
	elif role == "client":
		_c_action.rpc_id(1, seat, a)


@rpc("any_peer", "call_remote", "reliable")
func _c_action(seat: int, a: Dictionary) -> void:
	if role != "host" or core == null:
		return
	var id := multiplayer.get_remote_sender_id()
	if peer_seats.get(id, -1) != seat:
		return   # you can only act for your own seat
	core.action(seat, a)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _c_move(seat: int, v: Vector2) -> void:
	if role == "host" and core and peer_seats.get(multiplayer.get_remote_sender_id(), -1) == seat:
		core.action(seat, {"t": "mg", "move": v})


## Joystick input goes unreliable (it's sent continuously, latest wins).
func send_move(seat: int, v: Vector2) -> void:
	if is_authority():
		send_action(seat, {"t": "mg", "move": v})
	elif role == "client":
		_c_move.rpc_id(1, seat, v)


func _physics_process(delta: float) -> void:
	if not is_authority() or core == null or not in_match:
		return
	core.tick(delta)
	var evs := core.take_events()
	# this machine's screen
	var mine := evs.filter(func(e): return int(e.get("to", -1)) < 0 or my_seats.has(int(e.get("to", -1))))
	last_view = core.view_for(my_seats)
	state.emit(last_view, mine)
	if role != "host":
		return
	for id in peer_seats.keys():
		if id == 1:
			continue
		var seat: int = peer_seats[id]
		if not _pending.has(id):
			_pending[id] = []
		_pending[id].append_array(evs.filter(func(e): return int(e.get("to", -1)) < 0 or int(e.get("to", -1)) == seat))
	_send_t += delta
	var realtime := core.phase == "mg_play"
	if _send_t >= (1.0 / SEND_HZ if realtime else 0.25) or _has_pending():
		_send_t = 0.0
		for id in peer_seats.keys():
			if id == 1:
				continue
			_s_state.rpc_id(id, core.view_for([peer_seats[id]]), _pending.get(id, []))
			_pending[id] = []


func _has_pending() -> bool:
	for k in _pending.keys():
		if not (_pending[k] as Array).is_empty():
			return true
	return false


@rpc("authority", "call_remote", "reliable")
func _s_state(view: Dictionary, events: Array) -> void:
	last_view = view
	state.emit(view, events)


## After an ending: everyone back to the lobby (same seats, AI kept).
func return_to_lobby() -> void:
	if not is_authority():
		return
	in_match = false
	core = null
	for s in Seats.seats:
		s.ready = s.kind != "remote"
	if role == "host":
		_s_lobby.rpc(Seats.to_array())
		if transport == "enet":
			beacon.shout({"game": "meatparty", "code": code, "port": int(ProjectSettings.get_setting("meat_party/net/enet_port", 24510)), "host": str(Settings.get_v("name"))})
	back_to_lobby.emit()


@rpc("authority", "call_remote", "reliable")
func _s_lobby(arr: Array) -> void:
	in_match = false
	Seats.from_array(arr)
	back_to_lobby.emit()
