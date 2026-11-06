# Networking

**Model.** Host-authoritative. The host runs `MatchCore` (all rules, one seeded RNG);
clients only send input (`Net.send_action`, `Net.send_move`) and draw the views the host
sends (`MatchCore.view_for(seat)`, which hides other players' private info: clue numbers,
Peeker results). Every input is checked against the sender's seat. Godot's high-level
multiplayer (RPCs on the `Net` autoload) runs over a swappable `MultiplayerPeer`:

| Transport | Use | Room code |
|---|---|---|
| ENet, direct (`Net.host_lan`, `Net.join_ip`) | same Wi-Fi / LAN, or a forwarded port | host broadcasts its code on UDP 24511 (`LanBeacon`), joiners listen for it |
| Relay (`Net.host_relay`, `RelayPeer`) | the internet, behind any NAT / mobile network | handed out by the relay |

`Net.join_code` tries the LAN first (2.5 s), then the relay. Ports and the default relay
URL are in `project.godot` (`meat_party/net/*`); players can set a relay in Settings.

**The relay** (`server/relay_server.gd`) runs no game logic: rooms of up to four, packets
forwarded between members, the room closes when its host leaves. Both ends dial out, so
there's no NAT traversal to do. Run it on any public machine:

    godot --headless --script server/relay_server.gd -- --port=9080

For production put it behind TLS (e.g. Caddy/nginx terminating `wss://` and proxying to
the port), then set `meat_party/net/relay_url` to `wss://your.host/`.

**Disconnects.** Lobby: the seat empties. Match: the seat is played by AI at once (the
Caller announces it). The same player can rejoin with the same room code and name and
gets their seat back. Host leaving ends the match for everyone (the host *is* the game).

## Tested (on one Linux machine, separate processes)

`tools/net_test.sh`: a relay, a host, and clients that play their seats only through
`Net` (a `ViewBot` pressing the same actions as the buttons), to the end of a match.

## NOT tested yet (needs hardware / a deployed relay): the real acceptance tests

1. 3 and 4 humans on separate Android devices; 3 PC players; mixed Android + PC;
   Android host with PC clients and the reverse.
2. Players on different internet connections: **needs the relay deployed somewhere
   public** (no relay is running anywhere yet; the default URL is localhost).
3. LAN discovery on Android: the export asks for CHANGE_WIFI_MULTICAST_STATE, but some
   phones filter UDP broadcast; join by address works regardless.
