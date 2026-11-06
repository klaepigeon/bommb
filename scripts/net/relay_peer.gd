class_name RelayPeer
extends MultiplayerPeerExtension
## A MultiplayerPeer that talks through the MEAT PARTY relay (server/relay_server.gd) over
## a WebSocket. Both ends only ever dial out, so it works from behind home routers and
## phone networks with no port forwarding: this is the internet transport. Godot's
## high-level multiplayer (RPCs, authority) runs on top unchanged; the host is peer 1.
##
## Wire format: control messages are JSON text frames; game packets are binary frames
##   [int32 peer][u8 channel][u8 mode][payload]
## where `peer` is the target on the way up (0 = everyone) and the sender on the way down.

signal room_ready(code: String)
signal relay_error(msg: String)

var ws := WebSocketPeer.new()
var url := ""
var want := {}                 # the hello: {"op": "host"} or {"op": "join", "code": ...}
var code := ""
var my_id := 0
var status := MultiplayerPeer.CONNECTION_DISCONNECTED
var peers: Array[int] = []
var _in: Array = []            # [peer, channel, mode, PackedByteArray]
var _target := 0
var _channel := 0
var _mode := MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _cur: Array = []
var _sent_hello := false
var _refuse := false


func host(relay_url: String) -> Error:
	return _open(relay_url, {"op": "host", "game": "meatparty"})


func join(relay_url: String, room: String) -> Error:
	return _open(relay_url, {"op": "join", "game": "meatparty", "code": room.to_upper()})


func _open(relay_url: String, hello: Dictionary) -> Error:
	url = relay_url
	want = hello
	ws.inbound_buffer_size = 1 << 20
	ws.outbound_buffer_size = 1 << 20
	var err := ws.connect_to_url(url)
	status = MultiplayerPeer.CONNECTION_CONNECTING if err == OK else MultiplayerPeer.CONNECTION_DISCONNECTED
	return err


func _poll() -> void:
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN and not _sent_hello:
		_sent_hello = true
		ws.send_text(JSON.stringify(want))
	while ws.get_available_packet_count() > 0:
		var pkt := ws.get_packet()
		if ws.was_string_packet():
			_control(pkt.get_string_from_utf8())
		elif pkt.size() >= 6:
			var from := pkt.decode_s32(0)
			_in.append([from, pkt[4], pkt[5], pkt.slice(6)])
	if st == WebSocketPeer.STATE_CLOSED and status != MultiplayerPeer.CONNECTION_DISCONNECTED:
		var was := status
		status = MultiplayerPeer.CONNECTION_DISCONNECTED
		for p in peers.duplicate():
			peers.erase(p)
			emit_signal("peer_disconnected", p)
		if was == MultiplayerPeer.CONNECTION_CONNECTING:
			relay_error.emit("Couldn't reach the relay at %s" % url)


func _control(text: String) -> void:
	var m: Variant = JSON.parse_string(text)
	if not m is Dictionary:
		return
	match str(m.get("op", "")):
		"hosted", "joined":
			my_id = int(m.id)
			code = str(m.get("code", code))
			status = MultiplayerPeer.CONNECTION_CONNECTED
			room_ready.emit(code)
			for p in m.get("peers", []):
				_add_peer(int(p))
		"peer_connected":
			_add_peer(int(m.id))
		"peer_disconnected":
			var id := int(m.id)
			if peers.has(id):
				peers.erase(id)
				emit_signal("peer_disconnected", id)
		"error":
			relay_error.emit(str(m.get("msg", "relay error")))
			ws.close()


func _add_peer(id: int) -> void:
	if id != my_id and not peers.has(id):
		peers.append(id)
		emit_signal("peer_connected", id)


func _get_available_packet_count() -> int:
	return _in.size()


func _get_max_packet_size() -> int:
	return 1 << 20


# Godot asks who sent the next packet (and on which channel) before it reads it, so
# these answer for the front of the queue, as ENet's do.
func _get_packet_script() -> PackedByteArray:
	if _in.is_empty():
		return PackedByteArray()
	_cur = _in.pop_front()
	return _cur[3]


func _front() -> Array:
	return _in[0] if not _in.is_empty() else _cur


func _put_packet_script(buf: PackedByteArray) -> Error:
	if status != MultiplayerPeer.CONNECTION_CONNECTED:
		return ERR_UNCONFIGURED
	var head := PackedByteArray()
	head.resize(6)
	head.encode_s32(0, _target)
	head[4] = _channel
	head[5] = _mode
	return ws.send(head + buf, WebSocketPeer.WRITE_MODE_BINARY)


func _get_packet_channel() -> int:
	var f := _front()
	return int(f[1]) if f.size() > 1 else 0


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	var f := _front()
	return int(f[2]) if f.size() > 2 else MultiplayerPeer.TRANSFER_MODE_RELIABLE


func _get_packet_peer() -> int:
	var f := _front()
	return int(f[0]) if f.size() > 0 else 0


func _set_transfer_channel(ch: int) -> void:
	_channel = ch


func _get_transfer_channel() -> int:
	return _channel


func _set_transfer_mode(m: MultiplayerPeer.TransferMode) -> void:
	_mode = m


func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _mode


func _set_target_peer(p: int) -> void:
	_target = p


func _is_server() -> bool:
	return my_id == 1


func _get_unique_id() -> int:
	return my_id


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return status


func _close() -> void:
	ws.close()
	status = MultiplayerPeer.CONNECTION_DISCONNECTED


func _disconnect_peer(p: int, _force: bool) -> void:
	ws.send_text(JSON.stringify({"op": "kick", "id": p}))


func _set_refuse_new_connections(v: bool) -> void:
	_refuse = v


func _is_refusing_new_connections() -> bool:
	return _refuse


func _is_server_relay_supported() -> bool:
	return true
