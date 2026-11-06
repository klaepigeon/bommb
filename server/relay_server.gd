extends SceneTree
## MEAT PARTY relay: rooms with codes, and packet forwarding between the players in a
## room. Run it anywhere with a public address (a small VPS is plenty):
##
##     godot --headless --script server/relay_server.gd -- --port=9080
##
## Players never need open ports: host and guests all dial out to this. It doesn't run
## any game logic; the host's game is authoritative and this only carries packets.
## Put it behind a TLS proxy (wss://) for production; see docs/NETWORKING.md.

const MAX_ROOM := 4

var port := 9080
var tcp := TCPServer.new()
var clients: Dictionary = {}     # conn id -> {ws, room, peer_id, last}
var rooms: Dictionary = {}       # code -> {host: conn id, members: {peer_id: conn id}}
var _next_conn := 1
var _rng := RandomNumberGenerator.new()
var _quit_after := -1.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--port="):
			port = int(a.substr(7))
		if a.begins_with("--quit-after="):
			_quit_after = float(a.substr(13))
	_rng.randomize()
	var err := tcp.listen(port)
	print("relay: listening on %d (%s)" % [port, error_string(err)])
	if err != OK:
		quit(1)


func _process(delta: float) -> bool:
	if _quit_after > 0.0:
		_quit_after -= delta
		if _quit_after <= 0.0:
			return true
	while tcp.is_connection_available():
		var ws := WebSocketPeer.new()
		ws.inbound_buffer_size = 1 << 20
		ws.outbound_buffer_size = 1 << 20
		ws.accept_stream(tcp.take_connection())
		clients[_next_conn] = {"ws": ws, "room": "", "peer_id": 0}
		_next_conn += 1
	for cid in clients.keys():
		var c: Dictionary = clients[cid]
		var ws: WebSocketPeer = c.ws
		ws.poll()
		var st := ws.get_ready_state()
		if st == WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0:
				var pkt := ws.get_packet()
				if ws.was_string_packet():
					_control(cid, pkt.get_string_from_utf8())
				else:
					_forward(cid, pkt)
		elif st == WebSocketPeer.STATE_CLOSED:
			_leave(cid)
			clients.erase(cid)
	return false


func _send(cid: int, m: Dictionary) -> void:
	if clients.has(cid):
		(clients[cid].ws as WebSocketPeer).send_text(JSON.stringify(m))


func _new_code() -> String:
	const L := "ABCDEFGHJKLMNPQRSTUVWXYZ"   # no I or O
	while true:
		var c := ""
		for i in 5:
			c += L[_rng.randi_range(0, L.length() - 1)]
		if not rooms.has(c):
			return c
	return ""


func _control(cid: int, text: String) -> void:
	var m: Variant = JSON.parse_string(text)
	if not m is Dictionary:
		return
	var c: Dictionary = clients[cid]
	match str(m.get("op", "")):
		"host":
			var code := _new_code()
			rooms[code] = {"host": cid, "members": {1: cid}}
			c.room = code
			c.peer_id = 1
			_send(cid, {"op": "hosted", "code": code, "id": 1})
			print("relay: room %s opened" % code)
		"join":
			var code := str(m.get("code", "")).to_upper()
			if not rooms.has(code):
				_send(cid, {"op": "error", "msg": "No room called %s." % code})
				return
			var r: Dictionary = rooms[code]
			if r.members.size() >= MAX_ROOM:
				_send(cid, {"op": "error", "msg": "Room %s is full." % code})
				return
			var id := _rng.randi_range(2, 2147483646)
			while r.members.has(id):
				id = _rng.randi_range(2, 2147483646)
			var others: Array = r.members.keys()
			r.members[id] = cid
			c.room = code
			c.peer_id = id
			_send(cid, {"op": "joined", "code": code, "id": id, "peers": others})
			for pid in others:
				_send(r.members[pid], {"op": "peer_connected", "id": id})
			print("relay: %d joined %s" % [id, code])
		"kick":
			if c.peer_id == 1 and rooms.has(c.room):
				var victim: Variant = rooms[c.room].members.get(int(m.get("id", 0)))
				if victim != null and clients.has(victim):
					(clients[victim].ws as WebSocketPeer).close()


func _forward(cid: int, pkt: PackedByteArray) -> void:
	if pkt.size() < 6:
		return
	var c: Dictionary = clients[cid]
	if not rooms.has(c.room):
		return
	var r: Dictionary = rooms[c.room]
	var target := pkt.decode_s32(0)
	pkt.encode_s32(0, c.peer_id)
	if target > 0:
		if r.members.has(target):
			(clients[r.members[target]].ws as WebSocketPeer).send(pkt, WebSocketPeer.WRITE_MODE_BINARY)
	else:
		# 0: everyone; -n: everyone but n
		for pid in r.members.keys():
			if pid == c.peer_id or (target < 0 and pid == -target):
				continue
			(clients[r.members[pid]].ws as WebSocketPeer).send(pkt, WebSocketPeer.WRITE_MODE_BINARY)


func _leave(cid: int) -> void:
	var c: Dictionary = clients[cid]
	if not rooms.has(c.room):
		return
	var r: Dictionary = rooms[c.room]
	r.members.erase(c.peer_id)
	if r.host == cid:
		# the host is the game: the room closes
		for pid in r.members.keys():
			if clients.has(r.members[pid]):
				(clients[r.members[pid]].ws as WebSocketPeer).close()
		rooms.erase(c.room)
		print("relay: room %s closed" % c.room)
	else:
		for pid in r.members.keys():
			_send(r.members[pid], {"op": "peer_disconnected", "id": c.peer_id})
