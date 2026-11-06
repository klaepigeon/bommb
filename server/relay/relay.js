// LAST CALL 3 relay (Node.js). The same protocol as server/relay_server.gd, so it runs on
// any cheap host without Godot: rooms of up to four with five-letter codes, and packets
// forwarded between the players in a room. No game logic here: the host's game is
// authoritative; this only carries packets. Both ends dial out to it, so nobody needs to
// open ports.
//
//   PORT=9080 node relay.js
//
// Control messages are JSON text frames:
//   -> {"op":"host"} | {"op":"join","code":"ABCDE"} | {"op":"kick","id":N}
//   <- {"op":"hosted","code","id":1} | {"op":"joined","code","id","peers":[...]}
//      {"op":"peer_connected","id"} | {"op":"peer_disconnected","id"} | {"op":"error","msg"}
// Game packets are binary frames: [int32 LE peer][u8 channel][u8 mode][payload]; the peer is
// the target on the way up (0 = everyone, -n = everyone but n) and the sender on the way down.
const http = require("http");
const { WebSocketServer } = require("ws");

const PORT = parseInt(process.env.PORT || "9080", 10);
const MAX_ROOM = 4;
const LETTERS = "ABCDEFGHJKLMNPQRSTUVWXYZ";
const rooms = new Map(); // code -> {host: ws, members: Map(peerId -> ws)}

const server = http.createServer((req, res) => {
  // hosts like Render and Fly check the service is up over plain HTTP
  res.writeHead(200, { "content-type": "text/plain" });
  res.end(`LAST CALL 3 relay: ${rooms.size} room(s) open\n`);
});
const wss = new WebSocketServer({ server, maxPayload: 1 << 20 });

function send(ws, msg) {
  if (ws.readyState === ws.OPEN) ws.send(JSON.stringify(msg));
}

function newCode() {
  for (;;) {
    let c = "";
    for (let i = 0; i < 5; i++) c += LETTERS[Math.floor(Math.random() * LETTERS.length)];
    if (!rooms.has(c)) return c;
  }
}

wss.on("connection", (ws) => {
  ws.room = "";
  ws.peerId = 0;
  ws.isAlive = true;
  ws.on("pong", () => (ws.isAlive = true));
  ws.on("message", (data, isBinary) => {
    if (!isBinary) return control(ws, data.toString());
    forward(ws, Buffer.from(data));
  });
  ws.on("close", () => leave(ws));
  ws.on("error", () => {});
});

function control(ws, text) {
  let m;
  try { m = JSON.parse(text); } catch { return; }
  if (!m || typeof m !== "object") return;
  if (m.op === "host") {
    const code = newCode();
    rooms.set(code, { host: ws, members: new Map([[1, ws]]) });
    ws.room = code;
    ws.peerId = 1;
    send(ws, { op: "hosted", code, id: 1 });
    log(`room ${code} opened`);
  } else if (m.op === "join") {
    const code = String(m.code || "").toUpperCase();
    const r = rooms.get(code);
    if (!r) return send(ws, { op: "error", msg: `No room called ${code}.` });
    if (r.members.size >= MAX_ROOM) return send(ws, { op: "error", msg: `Room ${code} is full.` });
    let id;
    do { id = 2 + Math.floor(Math.random() * 2147483644); } while (r.members.has(id));
    const others = [...r.members.keys()];
    r.members.set(id, ws);
    ws.room = code;
    ws.peerId = id;
    send(ws, { op: "joined", code, id, peers: others });
    for (const pid of others) send(r.members.get(pid), { op: "peer_connected", id });
    log(`${id} joined ${code}`);
  } else if (m.op === "kick") {
    const r = rooms.get(ws.room);
    if (r && ws.peerId === 1) {
      const victim = r.members.get(Number(m.id));
      if (victim) victim.close();
    }
  }
}

function forward(ws, pkt) {
  if (pkt.length < 6) return;
  const r = rooms.get(ws.room);
  if (!r) return;
  const target = pkt.readInt32LE(0);
  pkt.writeInt32LE(ws.peerId, 0);
  if (target > 0) {
    const to = r.members.get(target);
    if (to && to.readyState === to.OPEN) to.send(pkt, { binary: true });
  } else {
    for (const [pid, to] of r.members) {
      if (pid === ws.peerId || (target < 0 && pid === -target)) continue;
      if (to.readyState === to.OPEN) to.send(pkt, { binary: true });
    }
  }
}

function leave(ws) {
  const r = rooms.get(ws.room);
  if (!r) return;
  r.members.delete(ws.peerId);
  if (r.host === ws) {
    // the host is the game: the room closes
    for (const to of r.members.values()) to.close();
    rooms.delete(ws.room);
    log(`room ${ws.room} closed`);
  } else {
    for (const to of r.members.values()) send(to, { op: "peer_disconnected", id: ws.peerId });
  }
}

// drop connections that have silently died (phones sleeping, networks changing)
setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.isAlive) { ws.terminate(); continue; }
    ws.isAlive = false;
    ws.ping();
  }
}, 30000);

function log(s) {
  console.log(new Date().toISOString(), s);
}

server.listen(PORT, () => log(`LAST CALL 3 relay listening on ${PORT}`));
