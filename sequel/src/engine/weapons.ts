// What the newer modules do in flight. Missile racks fire homing missiles at whatever is
// shooting at you while you hold attack; drone bays launch fighter drones that fly on your
// wing and shoot what you shoot; point defence swats incoming fire; the sensor array marks
// every ship in range; the refinery turns ore into platinum while you fly.
// (The afterburner's speed and the cloaking field live in space.ts's flight and AI code.)

import { SQ, saveSequel } from './state';
import { SPACE, HOOKS, hitCraft, burst, fire, craftR, type Craft } from './space';
import { stats } from '../ship/ship';
import { addCargo } from './cargo';

interface Missile { x: number; y: number; vx: number; vy: number; a: number; life: number; target: Craft | null }
interface Drone { x: number; y: number; a: number; cool: number; slot: number }
export const WEAPONS = { missiles: [] as Missile[], drones: [] as Drone[], rackT: 0, refineT: 0 };

const dist = (ax: number, ay: number, bx: number, by: number) => Math.hypot(bx - ax, by - ay);
const angDiff = (a: number, b: number) => { let d = (b - a) % (Math.PI * 2); if (d > Math.PI) d -= Math.PI * 2; if (d < -Math.PI) d += Math.PI * 2; return d; };
const sfx = (n: string) => R.game && R.game.audio && R.game.audio.sfx(n);
// the nearest hostile (or one you're already shooting) within range
const targetNear = (x: number, y: number, range: number) => {
  let best: Craft | null = null, bd = range;
  for (const c of SPACE.crafts) if (!c.dead && !c.disabled && c.hostile) { const d = dist(x, y, c.x, c.y); if (d < bd) { bd = d; best = c; } }
  return best;
};

HOOKS.update.push((g, dt) => {
  const my = stats(SQ.ship), W = WEAPONS;
  // ---- missiles: one rack salvo every 2.5 s while you hold attack, one missile per rack
  W.rackT -= dt;
  if (my.missiles && !SPACE.cruise && g.input.held('attack') && W.rackT <= 0) {
    const t = targetNear(SPACE.x, SPACE.y, 900);
    if (t) {
      W.rackT = 2.5;
      for (let k = 0; k < Math.min(4, my.missiles); k++) {
        const a = SPACE.a + (k % 2 ? 1 : -1) * (0.9 + k * 0.2);
        W.missiles.push({ x: SPACE.x, y: SPACE.y, vx: SPACE.vx + Math.cos(a) * 120, vy: SPACE.vy + Math.sin(a) * 120, a, life: 5, target: t });
      }
      sfx('boom');
    }
  }
  for (const m of W.missiles) {
    m.life -= dt;
    if (!m.target || m.target.dead) m.target = targetNear(m.x, m.y, 700);
    if (m.target) { const d = angDiff(m.a, Math.atan2(m.target.y - m.y, m.target.x - m.x)); m.a += Math.max(-4 * dt, Math.min(4 * dt, d)); }
    const sp = 420, k = Math.min(1, dt * 3);
    m.vx += (Math.cos(m.a) * sp + (m.target ? m.target.vx : 0) - m.vx) * k; m.vy += (Math.sin(m.a) * sp + (m.target ? m.target.vy : 0) - m.vy) * k;
    m.x += m.vx * dt; m.y += m.vy * dt;
    if (Math.random() < 0.6) SPACE.sparks.push({ x: m.x, y: m.y, vx: m.vx * 0.5, vy: m.vy * 0.5, life: 0.3, col: Math.random() < 0.5 ? '#ffd060' : '#ff8030' });
    if (m.target && dist(m.x, m.y, m.target.x, m.target.y) < craftR(m.target)) { hitCraft(g, m.target, 30); burst(m.x, m.y, 16, ['#ffd060', '#ff8030', '#ffffff'], m.target.vx, m.target.vy); m.life = 0; }
  }
  W.missiles = W.missiles.filter((m) => m.life > 0);
  // ---- drones: two per bay, in formation on your wing; they shoot the nearest hostile
  const want = Math.min(6, my.drones);
  while (W.drones.length < want) W.drones.push({ x: SPACE.x, y: SPACE.y, a: SPACE.a, cool: 1, slot: W.drones.length });
  if (W.drones.length > want) W.drones.length = want;
  for (const d of W.drones) {
    const side = d.slot % 2 ? 1 : -1, back = 22 + Math.floor(d.slot / 2) * 14;
    const hx = SPACE.x - Math.cos(SPACE.a) * back - Math.sin(SPACE.a) * side * (18 + d.slot * 4), hy = SPACE.y - Math.sin(SPACE.a) * back + Math.cos(SPACE.a) * side * (18 + d.slot * 4);
    const t = SPACE.cruise ? null : targetNear(d.x, d.y, 420);
    if (SPACE.cruise) { d.x = hx; d.y = hy; d.a = SPACE.a; continue; }
    const k = Math.min(1, dt * 4);
    d.x += (hx - d.x) * k + SPACE.vx * dt * (1 - k); d.y += (hy - d.y) * k + SPACE.vy * dt * (1 - k);
    d.a = t ? Math.atan2(t.y - d.y, t.x - d.x) : SPACE.a;
    d.cool -= dt;
    if (t && d.cool <= 0) { d.cool = 0.7; fire(d.x, d.y, d.a, SPACE.vx, SPACE.vy, 'me', 5, 1); }
  }
  // ---- point defence: each mount has a fair chance a second of killing a shot in close
  if (my.pd) for (const s of SPACE.shots) {
    if (s.from === 'me' || s.life <= 0 || dist(s.x, s.y, SPACE.x, SPACE.y) > 90) continue;
    if (Math.random() < my.pd * 1.6 * dt) { s.life = 0; burst(s.x, s.y, 3, ['#d0d8e8', '#ffffff']); }
  }
  // ---- the refinery: three ore into one platinum, every 20 seconds of flight
  if (my.refinery) {
    W.refineT += dt;
    if (W.refineT >= 20) {
      W.refineT = 0;
      const lot = SQ.cargo.find((l) => l.good === 'ore' && l.n >= 3);
      if (lot) { lot.n -= 3; SQ.cargo = SQ.cargo.filter((l) => l.n > 0); addCargo('plat', 1, lot.stolen); g.ui.toast('Refinery: three ore in, one platinum out.', 'good'); saveSequel(); }
    }
  }
});

HOOKS.draw.push((v) => {
  const { g, sx, sy, Z } = v, my = stats(SQ.ship);
  for (const m of WEAPONS.missiles) {
    const x = sx(m.x), y = sy(m.y);
    g.fillStyle = '#e8e8f0'; g.fillRect(Math.round(x - Math.cos(m.a) * 2), Math.round(y - Math.sin(m.a) * 2), 2, 2);
    g.fillStyle = '#ff5a3a'; g.fillRect(Math.round(x + Math.cos(m.a) * 1), Math.round(y + Math.sin(m.a) * 1), 2, 2);
  }
  for (const d of WEAPONS.drones) {
    const x = Math.round(sx(d.x)), y = Math.round(sy(d.y)), c = Math.cos(d.a), s = Math.sin(d.a);
    g.fillStyle = '#1a1a24'; g.fillRect(x - 2, y - 2, 5, 5);
    g.fillStyle = '#f0e060'; g.fillRect(x - 1, y - 1, 3, 3);
    g.fillStyle = '#ffffff'; g.fillRect(Math.round(x + c * 2), Math.round(y + s * 2), 1, 1);
  }
  // the sensor array: every ship in range gets a marker, whatever it is
  if (my.sensor && Z > 0) for (const c of SPACE.crafts) if (!c.dead && dist(c.x, c.y, SPACE.x, SPACE.y) < 9000) v.mark(c.x, c.y, '#68f0ff', c.name.toUpperCase().slice(0, 16));
  // the cloak: a shimmer round your own ship
  if (my.cloak) { g.strokeStyle = 'rgba(200,184,255,0.35)'; g.setLineDash([1, 3]); g.beginPath(); g.arc(v.W / 2, v.H / 2, 22, 0, 7); g.stroke(); g.setLineDash([]); }
});
HOOKS.hud.push(() => {
  const my = stats(SQ.ship);
  const bits = [my.missiles ? `MISSILES x${Math.min(4, my.missiles)}` : '', my.drones ? `DRONES ${WEAPONS.drones.length}` : '', my.cloak ? 'CLOAKED' : ''].filter(Boolean);
  return bits.length ? bits.join(' · ') : null;
});
