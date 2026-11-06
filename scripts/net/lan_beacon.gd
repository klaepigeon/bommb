class_name LanBeacon
extends Node
## Room codes on a local network: the host shouts its code (UDP broadcast, once a second)
## and anyone joining with that code listens for it, then connects straight to the host
## over ENet. (Phones on the same Wi-Fi, or a PC and a phone.)

signal found(info: Dictionary)

var port := 24511
var udp := PacketPeerUDP.new()
var shouting := {}
var listening := false
var _t := 0.0


func shout(info: Dictionary) -> void:
	shouting = info
	udp.close()
	udp.set_broadcast_enabled(true)
	udp.set_dest_address("255.255.255.255", port)
	_t = 1.0


func listen() -> Error:
	udp.close()
	listening = true
	return udp.bind(port, "0.0.0.0")


func stop() -> void:
	shouting = {}
	listening = false
	udp.close()


func _process(delta: float) -> void:
	if not shouting.is_empty():
		_t += delta
		if _t >= 1.0:
			_t = 0.0
			udp.put_packet(JSON.stringify(shouting).to_utf8_buffer())
	if listening:
		while udp.get_available_packet_count() > 0:
			var pkt := udp.get_packet()
			var ip := udp.get_packet_ip()
			var m: Variant = JSON.parse_string(pkt.get_string_from_utf8())
			if m is Dictionary and m.get("game", "") == "meatparty":
				m.ip = ip
				found.emit(m)
