// Earth's look: Streets of Fire and The Protomen. A rock-and-roll fable city in a permanent
// wet night: neon over every door, marquees with chasing bulbs, the elevated train rattling
// over the main drag on iron girders, a crimson sky full of smog, searchlights sweeping it,
// the boss's face on screens over the towers, and robot Peacekeepers on the corners.

import { SQ } from './state';
import { EARTH } from './earth';
import { SPACE } from './space';

const TS = R.TILE;
const on = () => EARTH.active && !SPACE.active && R.game && R.game.world && !(R.game.player && R.game.player.room);
const hash = (a: number, b: number, c: number) => R.hash2(a, b, c);
const NEON = ['#ff3a7a', '#3af0ff', '#ffb030', '#ff5ad0', '#68f0a0', '#ff4030'];
// the storefronts that get a big marquee, and the ones that get a plain neon sign
const MARQUEE = new Set(['bar', 'club', 'casino', 'strip', 'arcade', 'hotel', 'motel', 'diner']);
const SIGNS = new Set(['general', 'liquor', 'pharmacy', 'pawn', 'gunshop', 'tailor', 'bank', 'garage', 'gas', 'butcher', 'laundry', 'barber', 'costume', 'police', 'hospital', 'social', 'church']);

function view(g: CanvasRenderingContext2D) {
  const m = g.getTransform();
  return { left: -m.e / m.a, top: -m.f / m.d, vw: g.canvas.width / m.a, vh: g.canvas.height / m.d };
}

// ---------------------------------------------------------------- the elevated train (under the night light)
// the El's iron pillars stand in the street, so they're drawn with the ground: people walk in
// front of them
function drawPillars(g: CanvasRenderingContext2D): void {
  const w = R.game.world, v = view(g);
  for (const c of w.cities) {
    if (c.hamlet) continue;
    const y = c.rowY * TS - 2, x0 = (c.x0 - 6) * TS, x1 = (c.x1 + 6) * TS;
    if (y < v.top - 60 || y > v.top + v.vh + 40) continue;
    for (let x = x0; x <= x1; x += TS * 6) {
      if (x < v.left - 20 || x > v.left + v.vw + 20) continue;
      g.fillStyle = 'rgba(0,0,0,0.35)'; g.fillRect(x - 6, y + 3, 13, 3);
      g.fillStyle = '#3a2e36'; g.fillRect(x - 2, y - 30, 5, 34);
      g.fillStyle = '#7a6270'; g.fillRect(x - 2, y - 30, 1, 34);
      g.fillStyle = '#1a1418'; g.fillRect(x - 3, y + 1, 7, 3);
    }
  }
}
const P = R.props, baseGround = P.drawGround;
P.drawGround = function (g: CanvasRenderingContext2D, inView: (x: number, y: number) => boolean) {
  const r = baseGround.call(this, g, inView);
  if (on()) drawPillars(g);
  return r;
};
function drawEl(g: CanvasRenderingContext2D, t: number): void {
  const w = R.game.world, v = view(g);
  for (const c of w.cities) {
    if (c.hamlet) continue;
    const y = c.rowY * TS - 2, x0 = (c.x0 - 6) * TS, x1 = (c.x1 + 6) * TS;
    if (y < v.top - 60 || y > v.top + v.vh + 40 || x1 < v.left || x0 > v.left + v.vw) continue;
    // the deck: two girders with lattice between, riveted
    const a = Math.max(x0, v.left - 20), b = Math.min(x1, v.left + v.vw + 20);
    g.fillStyle = '#2e2228'; g.fillRect(a, y - 36, b - a, 10);
    g.fillStyle = '#7a5a64'; g.fillRect(a, y - 36, b - a, 1); g.fillRect(a, y - 27, b - a, 1);
    g.fillStyle = '#120c10';
    for (let x = Math.floor(a / 8) * 8; x < b; x += 8) { g.fillRect(x, y - 35, 1, 8); g.fillRect(x + 4, y - 32, 1, 3); }
    g.fillStyle = '#8a7a6a';
    for (let x = Math.floor(a / 12) * 12; x < b; x += 12) { g.fillRect(x + 2, y - 34, 1, 1); g.fillRect(x + 2, y - 29, 1, 1); }
    // the train: every so often it comes through, lit windows and sparks from the rail
    const len = x1 - x0 + 600, pos = ((t * 110 + c.idx * 900) % (len * 2)) - 300;
    if (pos < len) {
      const tx = x0 + pos - 300;
      for (let k = 0; k < 4; k++) {
        const cx = tx + k * 58;
        if (cx + 56 < v.left || cx > v.left + v.vw) continue;
        g.fillStyle = '#5a1a22'; g.fillRect(cx, y - 52, 54, 17);
        g.fillStyle = '#8a2a32'; g.fillRect(cx, y - 52, 54, 2);
        g.fillStyle = '#2a0c10'; g.fillRect(cx, y - 37, 54, 2);
        for (let wdw = 0; wdw < 6; wdw++) { g.fillStyle = hash(c.idx, k * 10 + wdw, 3) < 0.8 ? '#ffd890' : '#3a2a20'; g.fillRect(cx + 4 + wdw * 8, y - 47, 5, 5); }
      }
      if (Math.floor(t * 20) % 3 === 0) { g.fillStyle = '#fff4a0'; g.fillRect(tx + 230 + Math.random() * 6, y - 36, 2, 2); g.fillRect(tx + 10 + Math.random() * 6, y - 36, 1, 1); }
    }
  }
}

// ---------------------------------------------------------------- neon, marquees, screens (over the night)
function neonText(g: CanvasRenderingContext2D, s: string, x: number, y: number, col: string, lit: boolean): void {
  g.save();
  if (lit) { g.shadowColor = col; g.shadowBlur = 8; }
  R.art.ptext(g, s, x, y, { align: 'center', scale: 1, color: lit ? col : '#3a2a30', shadow: null });
  g.restore();
}
function drawSigns(g: CanvasRenderingContext2D, t: number): void {
  const w = R.game.world, v = view(g);
  for (const b of w.buildings) {
    if (!b || b.destroyed || b.fake) continue;
    const bx = b.x * TS, by = b.y * TS, bw = b.w * TS, bh = b.h * TS;
    if (bx + bw < v.left - 20 || bx > v.left + v.vw + 20 || by + bh < v.top - 40 || by > v.top + v.vh + 20) continue;
    const col = NEON[Math.floor(hash(b.id, 1, 5) * NEON.length)];
    // some signs are dying: they stutter
    const flicker = hash(b.id, 2, 5) < 0.2 && Math.sin(t * 17 + b.id) > 0.6;
    const cx = bx + bw / 2, fy = by + bh - TS * 1.6;
    const name = String(b.name || '').toUpperCase().slice(0, 16);
    if (MARQUEE.has(b.type)) {
      // a Streets of Fire marquee: a lit box, chasing bulbs round the edge, the name in neon
      const mw = Math.min(bw - 4, name.length * 5 + 14), mx = cx - mw / 2, my = fy - 10;
      g.fillStyle = '#12080c'; g.fillRect(mx, my, mw, 13);
      g.fillStyle = col; g.globalAlpha = 0.25; g.fillRect(mx - 2, my - 2, mw + 4, 17); g.globalAlpha = 1;
      const step = 4, per = Math.floor((mw * 2 + 26) / step), chase = Math.floor(t * 10);
      for (let k = 0; k < per; k++) {
        const d = k * step, px = d < mw ? mx + d : d < mw + 13 ? mx + mw : d < mw * 2 + 13 ? mx + mw - (d - mw - 13) : mx, py = d < mw ? my : d < mw + 13 ? my + (d - mw) : d < mw * 2 + 13 ? my + 13 : my + 13 - (d - mw * 2 - 13);
        g.fillStyle = (k + chase) % 3 === 0 ? '#fff4c0' : '#6a4a20'; g.fillRect(Math.round(px) - 1, Math.round(py) - 1, 2, 2);
      }
      neonText(g, name, cx, my + 3, col, !flicker);
    } else if (SIGNS.has(b.type)) {
      // a plain neon tube sign on the facade
      neonText(g, name, cx, fy - 4, col, !flicker);
    }
    // the tallest towers carry the boss's face
    if ((b.type === 'office' || b.type === 'bank') && hash(b.id, 3, 5) < 0.6) drawScreen(g, cx, by - 6, t, b.id);
  }
}
const SLOGANS = ['FEAR IS ORDER', 'OBEY', 'WORK. PAY. SLEEP.', 'CURFEW 22:00', 'THE SYNDICATE LOVES YOU', 'REPORT DISSENT'];
function drawScreen(g: CanvasRenderingContext2D, x: number, y: number, t: number, id: number): void {
  const W = 40, H = 26, sx = Math.round(x - W / 2), sy = Math.round(y - H);
  g.fillStyle = '#0a0608'; g.fillRect(sx - 2, sy - 2, W + 4, H + 4);
  g.fillStyle = '#1a0a18'; g.fillRect(sx, sy, W, H);
  const phase = Math.floor(t / 3 + id) % 3;
  if (phase < 2) {
    // the Fear Man's face: magenta, a widow's peak going grey, a pencil moustache, the ring
    g.fillStyle = '#b04a7c'; g.fillRect(sx + 13, sy + 4, 14, 16);
    g.fillStyle = '#8a8a90'; g.fillRect(sx + 13, sy + 3, 14, 3); g.fillRect(sx + 19, sy + 6, 2, 2);
    g.fillStyle = '#f0f0f0'; g.fillRect(sx + 15, sy + 10, 3, 2); g.fillRect(sx + 22, sy + 10, 3, 2);
    g.fillStyle = '#1a1020'; g.fillRect(sx + 16, sy + 10, 1, 2); g.fillRect(sx + 23, sy + 10, 1, 2); g.fillRect(sx + 16, sy + 15, 8, 1);
    g.fillStyle = '#f0c020'; g.fillRect(sx + 29, sy + 14, 3, 3);
  } else R.art.ptext(g, SLOGANS[(Math.floor(t / 9) + id) % SLOGANS.length], sx + W / 2, sy + 10, { align: 'center', scale: 1, color: '#ff3a7a', shadow: null });
  // scanlines and a roll bar
  g.fillStyle = 'rgba(0,0,0,0.3)'; for (let k = 0; k < H; k += 2) g.fillRect(sx, sy + k, W, 1);
  const roll = (t * 12) % H; g.fillStyle = 'rgba(255,255,255,0.08)'; g.fillRect(sx, sy + roll, W, 3);
  g.save(); g.shadowColor = '#ff3a7a'; g.shadowBlur = 10; g.strokeStyle = 'rgba(255,58,122,0.5)'; g.strokeRect(sx - 1.5, sy - 1.5, W + 3, H + 3); g.restore();
}
// the sky: crimson smog, and searchlights sweeping it (in screen space, over everything)
function drawSky(g: CanvasRenderingContext2D, t: number): void {
  const cv = g.canvas, W = cv.width, H = cv.height;
  g.save();
  g.setTransform(1, 0, 0, 1, 0, 0);
  const h = R.game.clock.hour(), day = h > 6 && h < 19 ? 1 : 0;
  // the day never really comes: a dark crimson lid on everything
  const sky = g.createLinearGradient(0, 0, 0, H);
  sky.addColorStop(0, `rgba(120,10,40,${0.35 + day * 0.15})`);
  sky.addColorStop(0.5, `rgba(30,0,30,${0.1 + day * 0.3})`);
  sky.addColorStop(1, `rgba(60,20,10,${0.15 + day * 0.2})`);
  g.fillStyle = sky; g.fillRect(0, 0, W, H);
  // searchlights, Protomen style
  g.globalCompositeOperation = 'lighter';
  for (let k = 0; k < 3; k++) {
    const bx = W * (0.15 + k * 0.35), a = -Math.PI / 2 + Math.sin(t * 0.35 + k * 2.1) * 0.7, len = H * 1.6, spread = 0.07;
    const grd = g.createLinearGradient(bx, H, bx + Math.cos(a) * len, H + Math.sin(a) * len);
    grd.addColorStop(0, 'rgba(255,240,210,0.16)'); grd.addColorStop(1, 'rgba(255,240,210,0)');
    g.fillStyle = grd;
    g.beginPath(); g.moveTo(bx, H);
    g.lineTo(bx + Math.cos(a - spread) * len, H + Math.sin(a - spread) * len);
    g.lineTo(bx + Math.cos(a + spread) * len, H + Math.sin(a + spread) * len);
    g.closePath(); g.fill();
  }
  g.restore();
}
const RING = R.ring, baseRing = RING.draw;
RING.draw = function (g: CanvasRenderingContext2D) {
  const r = baseRing.call(this, g);
  // drawn over the night light: the El as a silhouette with lit windows, then the neon
  if (on()) { const t = performance.now() / 1000; drawEl(g, t); drawSigns(g, t); drawSky(g, t); }
  return r;
};

// ---------------------------------------------------------------- robot Peacekeepers
// on Earth the law walks on servos: every cop is a Peacekeeper unit
const POP = R.Population.prototype, baseLook = POP.makeLook;
POP.makeLook = function (this: unknown, rnd: () => number, p: any) {
  const look = baseLook.call(this, rnd, p);
  if (p && (p.role === 'cop' || p.role === 'detective') && SQ.planet === 'earth' && SQ.home === 'sol') {
    const seed = p.seed != null ? p.seed : Math.floor(Math.random() * 1e9);
    look.xeno = 'robot'; look.xenoSeed = seed; look.xenoAccent = '#3a8aff'; look.xenoSkin = '#2a3440';
    look.skin = '#2a3440'; look.hair = '#2a3440'; look.hat = null; look.beard = false; look.shades = false;
    look.seedStr = 'peacekeeper-' + seed;
    look.oldOverride = Object.assign({}, look.oldOverride || {}, { skin: ['#10141a', '#1c232c', '#2a3440', '#46546a'], style: 'bald', stache: false, glasses: false });
    look.old = null;
  }
  return look;
};
