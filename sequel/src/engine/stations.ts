// Stations and the belt.
//   Stations orbit their worlds. Dock with USE: the Red Velvet Orbital over Mars is a full game
//   1 casino (dealers, tables, slots, the house security) hung in orbit; the Haulyard Assay
//   Station at Ceres buys what you dig up, sells jump fuel and patches hulls.
//   The asteroid belt lies between Mars and Jupiter (2.2 to 3.3 AU), for real: rocks sit in
//   every stretch of it, generated as you fly. Shoot one to crack it open, then fly through
//   the pieces to scoop them up (a tractor beam pulls them in from further). Most rock is ore,
//   some is ice, a little is platinum. Hit one at speed and your hull knows about it.

import { SQ, saveSequel, type Good } from './state';
import { BODY, AU, systemData } from './planets';
import { SPACE, HOOKS, shipBody } from './space';
import { enterDock } from './board';
import { addCargo, GOODS, price } from './cargo';
import { stats } from '../ship/ship';

export interface Station { id: string; name: string; parent: string; alt: number; hours: number; kind: 'casino' | 'assay'; col: string; blurb: string }
export const STATIONS: Record<string, Station[]> = {
  sol: [
    { id: 'redvelvet', name: 'The Red Velvet Orbital', parent: 'mars', alt: 520, hours: 9, kind: 'casino', col: '#ff5a8a', blurb: 'A casino wheel over Mars. What happens in orbit burns up on re-entry.' },
    { id: 'haulyard', name: 'Haulyard Assay Station', parent: 'ceres', alt: 320, hours: 6, kind: 'assay', col: '#f0b838', blurb: 'The belt\'s buyer of last resort: ore, ice, platinum. Fuel and patches too.' },
  ],
};
const stationsHere = () => STATIONS[SQ.system] || [];
const minutes = () => (R.game && R.game.clock ? R.game.clock.t : SQ.minutes);
export function stationPos(st: Station): { x: number; y: number; vx: number; vy: number } | null {
  const p = shipBody(st.parent);
  if (!p) return null;
  const a = (minutes() / 60 / st.hours) * Math.PI * 2 + st.id.length, r = p.r + st.alt, w = (Math.PI * 2) / (st.hours * 60);
  return { x: p.x + Math.cos(a) * r, y: p.y + Math.sin(a) * r, vx: p.vx - Math.sin(a) * r * w, vy: p.vy + Math.cos(a) * r * w };
}
const near = (x: number, y: number, r: number) => Math.hypot(SPACE.x - x, SPACE.y - y) < r;
export function nearStation(): Station | null {
  for (const st of stationsHere()) { const p = stationPos(st); if (p && near(p.x, p.y, 90)) return st; }
  return null;
}

// ---------------------------------------------------------------- docking
function dock(g: Game, st: Station): void {
  const p = stationPos(st)!;
  const rel = Math.hypot(SPACE.vx - p.vx / 60, SPACE.vy - p.vy / 60);
  if (rel > 200) return g.ui.toast(`Too fast to dock (${Math.round(rel)}). Match the station's speed.`, 'warn');
  if (st.kind === 'casino') {
    SPACE.vx = p.vx / 60; SPACE.vy = p.vy / 60;
    enterDock(g, 'casino', st.name, 'normal', (g2) => { g2.ui.toast(`You undock from the ${st.name}.`, 'good'); });
    g.ui.toast(`Docked at the ${st.name}. The tables never close.`, 'good');
  } else assay(g, st);
}
function assay(g: Game, st: Station): void {
  const pl = g.player, s = stats(SQ.ship);
  const sell = (good: Good) => {
    const n = SQ.cargo.filter((l) => l.good === good).reduce((a, l) => a + l.n, 0), each = Math.round(price('ceres', good) * 1.25);
    return { label: `Sell ${GOODS[good].name} (${n})`, small: n ? `$${each} each` : 'None aboard', fn: () => {
      if (!n) return;
      SQ.cargo = SQ.cargo.filter((l) => l.good !== good);
      pl.cash += each * n; g.audio.sfx('cash'); saveSequel();
      g.ui.toast(`+$${each * n} for ${n} ${GOODS[good].name}.`, 'good');
      assay(g, st);
    } };
  };
  const fuelCost = 120, need = Math.max(0, s.fuel - SQ.fuel), hullCost = Math.max(0, Math.ceil((s.hull - Math.max(0, SQ.hull)) * 1.5));
  g.ui.choice(st.name, [
    sell('ore'), sell('ice'), sell('plat'),
    { label: `Jump fuel (${SQ.fuel}/${s.fuel})`, small: need ? `$${fuelCost} a cell` : 'Tanks full', fn: () => {
      if (!need) return;
      const k = Math.min(need, Math.floor(pl.cash / fuelCost));
      if (!k) return g.ui.toast("You can't afford a cell.", 'warn');
      SQ.fuel += k; pl.cash -= k * fuelCost; saveSequel(); g.audio.sfx('equip'); assay(g, st);
    } },
    { label: 'Patch the hull', small: hullCost ? `$${hullCost}` : 'Hull\'s fine', fn: () => {
      if (!hullCost) return;
      if (pl.cash < hullCost) return g.ui.toast("You can't afford the patch.", 'warn');
      pl.cash -= hullCost; SQ.hull = s.hull; saveSequel(); g.audio.sfx('equip'); assay(g, st);
    } },
    { label: 'Undock', fn: () => {} },
  ]);
}
HOOKS.nav.push(() => stationsHere().map((st) => ({ id: st.id, name: st.name, kind: 'station' as const, via: st.parent, r: 0, pos: () => { const p = stationPos(st) || { x: 0, y: 0, vx: 0, vy: 0 }; return { x: p.x, y: p.y, vx: p.vx / 60, vy: p.vy / 60 }; } })));
HOOKS.use.push((g) => { const st = nearStation(); return st ? { label: st.kind === 'casino' ? 'Dock' : 'Trade', fn: () => dock(g, st) } : null; });

// ---------------------------------------------------------------- the belt
interface Rock { key: string; x: number; y: number; r: number; hp: number; good: Good; spin: number; seed: number }
interface Chunk { x: number; y: number; vx: number; vy: number; good: Good; n: number; life: number }
const CELL = 1400;
const broken = new Set<string>();
let rocks: Rock[] = [], chunks: Chunk[] = [], scanT = 0, told = false;
const h3 = (a: number, b: number, c: number) => { let h = (a * 374761393 + b * 668265263 + c * 2147483647) | 0; h = Math.imul(h ^ (h >>> 13), 1274126177); return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };
export function belt(): [number, number] | null { const b = systemData(SQ.system).belt; return b ? [b[0] * AU, b[1] * AU] : null; }
export const inBelt = () => { const b = belt(); if (!b) return false; const d = Math.hypot(SPACE.x, SPACE.y); return d > b[0] && d < b[1]; };
function scan(): void {
  const b = belt();
  rocks = rocks.filter((r) => !broken.has(r.key) && near(r.x, r.y, CELL * 4));
  if (!b) return;
  const cx = Math.floor(SPACE.x / CELL), cy = Math.floor(SPACE.y / CELL), have = new Set(rocks.map((r) => r.key));
  const ceres = BODY.ceres ? shipBody('ceres') : null;
  for (let gy = cy - 3; gy <= cy + 3; gy++) for (let gx = cx - 3; gx <= cx + 3; gx++) {
    const mx = (gx + 0.5) * CELL, my = (gy + 0.5) * CELL, d = Math.hypot(mx, my);
    if (d < b[0] || d > b[1]) continue;
    // thicker toward the middle of the belt, and around Ceres
    const mid = 1 - Math.abs((d - (b[0] + b[1]) / 2) / ((b[1] - b[0]) / 2));
    const crowd = ceres && Math.hypot(mx - ceres.x, my - ceres.y) < 6000 ? 2 : 0;
    const n = Math.floor(h3(gx, gy, 1) * (2 + mid * 3)) + crowd;
    for (let k = 0; k < n; k++) {
      const key = `${SQ.system}:${gx}:${gy}:${k}`;
      if (broken.has(key) || have.has(key)) continue;
      const r = 8 + h3(gx, gy, k * 7 + 2) * 30, q = h3(gx, gy, k * 7 + 3);
      rocks.push({ key, x: gx * CELL + h3(gx, gy, k * 7 + 4) * CELL, y: gy * CELL + h3(gx, gy, k * 7 + 5) * CELL, r, hp: r * 3, good: q < 0.06 ? 'plat' : q < 0.24 ? 'ice' : 'ore', spin: h3(gx, gy, k * 7 + 6) - 0.5, seed: (h3(gx, gy, k * 7 + 8) * 1e6) | 0 });
    }
  }
}
function crack(rk: Rock): void {
  broken.add(rk.key);
  rocks = rocks.filter((r) => r !== rk);
  const n = 2 + Math.floor(rk.r / 10);
  for (let k = 0; k < n; k++) { const a = Math.random() * 7, s = 20 + Math.random() * 40; chunks.push({ x: rk.x, y: rk.y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, good: rk.good, n: rk.good === 'plat' ? 1 : 1 + Math.floor(Math.random() * 2), life: 90 }); }
  for (let k = 0; k < 14; k++) { const a = Math.random() * 7, s = 30 + Math.random() * 90; SPACE.sparks.push({ x: rk.x, y: rk.y, vx: Math.cos(a) * s, vy: Math.sin(a) * s, life: 0.5 + Math.random() * 0.6, col: k % 2 ? '#8a7a6a' : rk.good === 'plat' ? '#ffffff' : rk.good === 'ice' ? '#a8e8ff' : '#c8a070' }); }
  R.game.audio.sfx('crash');
}
HOOKS.shot.push((x, y, dmg) => {
  for (const rk of rocks) if (Math.hypot(x - rk.x, y - rk.y) < rk.r) { rk.hp -= dmg; if (rk.hp <= 0) crack(rk); return true; }
  return false;
});
HOOKS.update.push((g, dt) => {
  scanT -= dt;
  if (scanT <= 0) { scanT = 0.5; scan(); }
  if (!told && inBelt() && !SPACE.cruise) { told = true; g.ui.toast('The asteroid belt. Shoot rocks to crack them, fly through the pieces to scoop them up. Mind your hull.', 'good'); }
  const my = stats(SQ.ship), reach = my.tractor ? 90 : 20;
  // rocks: you hit them, they hurt (the cruise bubble brushes them aside)
  if (!SPACE.cruise) for (const rk of rocks) {
    const d = Math.hypot(SPACE.x - rk.x, SPACE.y - rk.y);
    if (d < rk.r + 7) {
      const nx = (SPACE.x - rk.x) / (d || 1), ny = (SPACE.y - rk.y) / (d || 1), vn = SPACE.vx * nx + SPACE.vy * ny, sp = Math.hypot(SPACE.vx, SPACE.vy);
      SPACE.x = rk.x + nx * (rk.r + 8); SPACE.y = rk.y + ny * (rk.r + 8);
      if (vn < 0) { SPACE.vx -= vn * nx * 1.5; SPACE.vy -= vn * ny * 1.5; }
      if (sp > 80) { SQ.hull -= sp * 0.08; g.audio.sfx('crash'); if (g.ui.hurtFlash) g.ui.hurtFlash(10); }
    }
  }
  // chunks drift; the scoop (or tractor) pulls them in
  for (const c of chunks) {
    c.life -= dt;
    const d = Math.hypot(SPACE.x - c.x, SPACE.y - c.y);
    if (my.tractor && d < reach * 2.5) { c.vx += ((SPACE.x - c.x) / d) * 160 * dt; c.vy += ((SPACE.y - c.y) / d) * 160 * dt; }
    c.x += c.vx * dt; c.y += c.vy * dt; c.vx *= Math.pow(0.7, dt); c.vy *= Math.pow(0.7, dt);
    if (d < reach) {
      const put = addCargo(c.good, c.n, false);
      c.life = 0;
      if (put) { g.audio.sfx('loot'); g.ui.toast(`+${put} ${GOODS[c.good].name}`, 'good'); }
      else g.ui.toast('Holds full. Sell at the Haulyard or dump cargo.', 'warn');
    }
  }
  chunks = chunks.filter((c) => c.life > 0);
});
HOOKS.draw.push((v) => {
  const { g, sx, sy, Z, W, H } = v;
  for (const rk of rocks) {
    const x = sx(rk.x), y = sy(rk.y), r = Math.max(1, rk.r * Z);
    if (x < -r - 4 || x > W + r + 4 || y < -r - 4 || y > H + r + 4) continue;
    if (r < 2) { g.fillStyle = '#8a7a6a'; g.fillRect(Math.round(x), Math.round(y), 1, 1); continue; }
    // a lumpy polygon, lit from the Sun
    const t = (performance.now() / 1000) * rk.spin, pts = 9;
    const base = rk.good === 'ice' ? ['#5a7a8a', '#8ab8c8', '#c8f0ff'] : rk.good === 'plat' ? ['#6a6a78', '#a8a8b8', '#ffffff'] : ['#4a3e34', '#7a6a58', '#a8947a'];
    g.fillStyle = base[0]; g.beginPath();
    for (let k = 0; k < pts; k++) { const a = t + (k / pts) * Math.PI * 2, rr = r * (0.72 + h3(rk.seed, k, 3) * 0.35); if (k) g.lineTo(x + Math.cos(a) * rr, y + Math.sin(a) * rr); else g.moveTo(x + Math.cos(a) * rr, y + Math.sin(a) * rr); }
    g.fill();
    const sa = Math.atan2(-rk.y, -rk.x);
    g.fillStyle = base[1]; g.beginPath(); g.arc(x + Math.cos(sa) * r * 0.2, y + Math.sin(sa) * r * 0.2, r * 0.55, 0, 7); g.fill();
    g.fillStyle = base[2]; g.fillRect(Math.round(x + Math.cos(sa) * r * 0.35), Math.round(y + Math.sin(sa) * r * 0.35), Math.max(1, Math.round(r * 0.15)), Math.max(1, Math.round(r * 0.15)));
    if (rk.good === 'plat' && Math.floor(performance.now() / 250 + rk.seed) % 5 === 0) { g.fillStyle = '#ffffff'; g.fillRect(Math.round(x), Math.round(y - r * 0.4), 1, 1); }
  }
  for (const c of chunks) { g.fillStyle = c.good === 'plat' ? '#ffffff' : c.good === 'ice' ? '#a8e8ff' : '#c8a070'; g.fillRect(Math.round(sx(c.x)) - 1, Math.round(sy(c.y)) - 1, 2, 2); }
  // stations: an 80s wheel with neon spokes
  for (const st of stationsHere()) {
    const p = stationPos(st); if (!p) continue;
    const x = sx(p.x), y = sy(p.y), r = Math.max(2, 26 * Z);
    if (x > -r && x < W + r && y > -r && y < H + r) {
      if (r < 4) { g.fillStyle = st.col; g.fillRect(Math.round(x) - 1, Math.round(y) - 1, 3, 3); }
      else {
        const t = performance.now() / 2000;
        g.strokeStyle = '#c8c8d8'; g.lineWidth = Math.max(1, r * 0.18); g.beginPath(); g.arc(x, y, r, 0, 7); g.stroke();
        g.strokeStyle = st.col; g.lineWidth = 1;
        for (let k = 0; k < 4; k++) { const a = t + (k * Math.PI) / 2; g.beginPath(); g.moveTo(x, y); g.lineTo(x + Math.cos(a) * r, y + Math.sin(a) * r); g.stroke(); }
        g.fillStyle = '#e8e8f0'; g.fillRect(Math.round(x - r * 0.2), Math.round(y - r * 0.2), Math.ceil(r * 0.4), Math.ceil(r * 0.4));
        for (let k = 0; k < 8; k++) if (Math.floor(performance.now() / 180 + k) % 3 === 0) { const a = t + (k * Math.PI) / 4; g.fillStyle = st.col; g.fillRect(Math.round(x + Math.cos(a) * r) - 1, Math.round(y + Math.sin(a) * r) - 1, 2, 2); }
        if (Z > 0.3) R.art.ptext(g, st.name.toUpperCase(), Math.round(x), Math.round(y + r + 4), { align: 'center', scale: 1, color: st.col, shadow: '#07051a' });
      }
    }
    if (Math.hypot(SPACE.x - p.x, SPACE.y - p.y) < 20000) v.mark(p.x, p.y, st.col, st.name.split(' ').slice(-1)[0].toUpperCase());
  }
});
HOOKS.hud.push(() => (inBelt() ? `ASTEROID BELT · ${rocks.length} ROCKS NEARBY` : null));

export const beltState = () => ({ rocks, chunks, broken });
(window as any).BS2 = Object.assign((window as any).BS2 || {}, { STATIONS, stationPos, beltState, inBelt });
