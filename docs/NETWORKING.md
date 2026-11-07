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

## The live relay

`wss://lc3onlinebeta.onrender.com` (Render, free tier; the game's default). Tested from
here with real game processes over the internet: `RELAY_URL=wss://lc3onlinebeta.onrender.com
tools/net_test.sh remote 3` (3 humans + 1 AI, full match, everyone saw the same ending).
Free tier: it sleeps after 15 idle minutes; the first host after that waits 30-60 s.

## Deploying the relay (for internet play)

The relay is `server/relay/relay.js`: one small Node.js file (the same protocol as the
Godot version, `server/relay_server.gd`, and tested against the game the same way:
`tools/net_test.sh noderelay 4`). It needs no Godot and no database. Pick one:

**Render (free, easiest, no card).**
1. Make an account at render.com and connect your GitHub.
2. Dashboard > **New > Blueprint**, pick this repository (`klaepigeon/bommb`). It reads
   `render.yaml` and creates the `last-call-3-relay` web service.
3. When it's live it has a URL like `https://last-call-3-relay.onrender.com`.
   The relay address is the same with **wss://**: `wss://last-call-3-relay.onrender.com`.
4. In the game: Settings > RELAY, paste it. (Or put it in `project.godot` under
   `meat_party/net/relay_url` and rebuild, so everyone's copy has it.)

Render's free services sleep after 15 minutes idle; the first person to host after that
waits ~30-60 s while it wakes. A paid instance ($7/month) stays awake.

**Fly.io** (needs a card; small machines are cheap, wakes faster).
```
cd server/relay
fly launch --copy-config --no-deploy    # choose an app name; it rewrites fly.toml
fly deploy
```
Address: `wss://<app-name>.fly.dev`.

**Any VPS** (DigitalOcean, Hetzner, a Raspberry Pi with a public address...):
```
cd server/relay && npm install && PORT=9080 node relay.js
```
or `docker build -t lc3-relay server/relay && docker run -p 9080:9080 lc3-relay`. Put it
behind a TLS proxy (Caddy: `relay.example.com { reverse_proxy localhost:9080 }`) and use
`wss://relay.example.com`. Plain `ws://ip:9080` works too, but some phone networks
interfere with unencrypted WebSockets.

**The Godot relay** (`server/relay_server.gd`) runs no game logic: rooms of up to four, packets
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

| Run | Result |
|---|---|
| `relay 3` (3 humans + 1 AI) | passed, every process saw the same ending |
| `relay 4` (4 humans) | passed (failed once in a back-to-back batch; didn't reproduce) |
| `ip 3` (ENet by address) | passed |
| `rejoin 3` (a client drops mid-match, AI covers, it rejoins by code) | passed |
| `lan 2` (room code found by UDP broadcast) | passed |
| `lan 4` | timed out: on one machine only one client can listen on the discovery port (separate devices don't share it) |

## NOT tested yet (needs hardware / a deployed relay): the real acceptance tests

1. 3 and 4 humans on separate Android devices; 3 PC players; mixed Android + PC;
   Android host with PC clients and the reverse.
2. Players on genuinely different home/mobile connections (the relay is deployed and
   tested over the internet from one machine; not yet from separate homes/phones).
3. LAN discovery on Android: the export asks for CHANGE_WIFI_MULTICAST_STATE, but some
   phones filter UDP broadcast; join by address works regardless.
