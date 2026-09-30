// Curfew. The billboards aren't joking: from 22:00 to 05:00 nobody walks Earth's streets
// without a pass. Syndicate drones hunt the dark with searchlights. Stay in the light too
// long and one tags you: a Curfew Violation, and the Peacekeepers come. Duck indoors or into
// a car and it loses you; or shoot it down (vandalism, but who's watching?). A real pass
// costs 200 at a Syndicate Lounge and lasts the week; the Chop Shop sells forgeries that
// usually scan.

import { SQ, saveSequel, cityRect } from './state';
import { EARTH } from './earth';
import { SPACE } from './space';

const TS = R.TILE;
interface Drone { x: number; y: number; hp: number; seen: number; lost: number; dead: number; checked: boolean }
export const CURFEW = { drones: [] as Drone[], tags: 0, downed: 0, script: false }; // script: a cutscene flies them
let spawnT = 8;
const day = (g: Game) => Math.floor(g.clock.t / 1440);
export const curfewNow = (g: Game) => { const h = g.clock.hour(); return h >= 22 || h < 5; };
// the pass is stored as the day it runs out (0: never bought)
const hasPass = (g: Game) => (SQ.flags.curfewPass || 0) > 0 && SQ.flags.curfewPass >= day(g);
const LIGHT = 30;

function tag(g: Game, d: Drone): void {
  const pl = g.player;
  d.seen = 0; d.lost = 0;
  if (hasPass(g) && !d.checked) {
    d.checked = true;
    if (SQ.flags.passForged && Math.random() < 0.3) { g.ui.toast('The drone chirps twice. "FORGED DOCUMENT." Uh oh.', 'bad'); }
    else { g.ui.toast('The drone scans your pass. "CITIZEN IN GOOD STANDING. CARRY ON." It drifts off.', 'good'); d.lost = 99; return; }
  }
  CURFEW.tags++;
  SQ.flags.curfewTags = (SQ.flags.curfewTags || 0) + 1; saveSequel();
  g.ui.toast('"CURFEW VIOLATION. REMAIN WHERE YOU ARE." The drone\'s light turns red. Peacekeepers are coming.', 'bad');
  g.audio.sfx('alarm');
  const law = g.law as any;
  law.crime('trespass', pl.x, pl.y, {});
  if (!law.incident) law.startIncident({ type: 'curfew', def: { name: 'Curfew Violation', bounty: 25, lvl: 1 }, x: pl.x, y: pl.y, jur: law.jurAt(pl.x, pl.y), identified: true, t: g.clock.t, lvl: 1, bounty: 25 }, null);
  d.lost = 99;
}
function update(g: Game, dt: number): void {
  if (CURFEW.script) return;
  const pl = g.player, w = g.world;
  const on = EARTH.active && curfewNow(g);
  const exposed = on && !pl.room && !pl.inCar && !!cityRect(w, (pl.x / TS) | 0, (pl.y / TS) | 0);
  for (const d of CURFEW.drones) {
    if (d.dead > 0) { d.dead -= dt; continue; }
    const dist = Math.hypot(pl.x - d.x, pl.y - d.y);
    if (exposed && d.lost < 10) {
      // hunting: drift toward you, a little slower than a run
      const sp = dist > 120 ? 75 : 48;
      d.x += ((pl.x - d.x) / (dist || 1)) * sp * dt; d.y += ((pl.y - d.y) / (dist || 1)) * sp * dt;
      if (dist < LIGHT) { d.seen += dt; if (d.seen > 2.5) tag(g, d); } else d.seen = Math.max(0, d.seen - dt * 0.5);
    } else {
      // lost you: wander off and go home
      d.lost += dt; d.seen = 0; d.y -= 20 * dt; d.x += 12 * dt;
    }
  }
  // wrecks linger a moment; lost or distant drones go home
  CURFEW.drones = CURFEW.drones.filter((d) => (d.hp > 0 || d.dead > 0) && d.lost < 20 && Math.hypot(pl.x - d.x, pl.y - d.y) < TS * 40);
  if (!exposed) return;
  spawnT -= dt;
  if (spawnT <= 0 && CURFEW.drones.filter((d) => d.hp > 0).length < 2) {
    spawnT = 25 + Math.random() * 25;
    const a = Math.random() * 7;
    CURFEW.drones.push({ x: pl.x + Math.cos(a) * 220, y: pl.y + Math.sin(a) * 220, hp: 30, seen: 0, lost: 0, dead: 0, checked: false });
    if (!SQ.flags.curfewTold) { SQ.flags.curfewTold = 1; saveSequel(); g.ui.toast('After 22:00: curfew. A Syndicate drone is sweeping the street with a searchlight. Stay out of the light, get inside, or show a pass.', 'warn'); }
  }
}
const GP = R.Game.prototype, tick = GP.tick;
GP.tick = function (this: Game, dt: number) {
  const r = tick.call(this, dt);
  if (this.player && this.world && !this.ui.paused() && !SPACE.active) update(this, dt);
  return r;
};
// shooting them down: any shot of yours that passes within a few pixels
const C = R.combat as any, ray = C.ray;
C.ray = function (att: any, sx: number, sy: number, a: number, range: number, dmg: number) {
  const r = ray.apply(this, arguments);
  const g = R.game;
  if (att === g.player) for (const d of CURFEW.drones) {
    if (d.hp <= 0) continue;
    const dy0 = d.y - 26; // it hovers
    const rx = d.x - sx, ry = dy0 - sy, along = rx * Math.cos(a) + ry * Math.sin(a), across = Math.abs(-rx * Math.sin(a) + ry * Math.cos(a));
    if (along > 0 && along < range && across < 9) {
      d.hp -= dmg;
      g.fx.sparks(d.x, dy0, 3);
      if (d.hp <= 0) { d.dead = 1.2; CURFEW.downed++; g.fx.smoke(d.x, dy0, false); g.audio.sfx('crash', d.x, d.y); g.ui.toast('The drone spins down into the street in a shower of sparks.', 'good'); (g.law as any).crime('vandalism', d.x, d.y, { minor: true }); }
      break;
    }
  }
  return r;
};
// drawing: the drone, its searchlight on the ground
const ring = R.ring as any, draw = ring.draw;
ring.draw = function (gx: CanvasRenderingContext2D) {
  draw.apply(this, arguments);
  const t = performance.now() / 1000;
  for (const d of CURFEW.drones) {
    const x = Math.round(d.x), bob = Math.sin(t * 4 + d.x) * 1.5, y = Math.round(d.y - 26 + bob);
    if (d.hp > 0) {
      const alarm = d.seen > 1.2;
      gx.fillStyle = alarm ? 'rgba(255,60,60,0.28)' : 'rgba(255,250,210,0.22)';
      gx.beginPath(); gx.ellipse(d.x, d.y, LIGHT, LIGHT * 0.55, 0, 0, 7); gx.fill();
      gx.fillStyle = alarm ? 'rgba(255,80,80,0.12)' : 'rgba(255,250,210,0.1)';
      gx.beginPath(); gx.moveTo(x - 2, y + 3); gx.lineTo(d.x - LIGHT, d.y); gx.lineTo(d.x + LIGHT, d.y); gx.lineTo(x + 2, y + 3); gx.fill();
    }
    gx.fillStyle = '#1c1c24'; gx.fillRect(x - 6, y - 2, 12, 5);
    gx.fillStyle = '#4a4a58'; gx.fillRect(x - 5, y - 1, 10, 3);
    gx.fillStyle = '#8a8a9a'; gx.fillRect(x - 9, y - 4, 4, 1); gx.fillRect(x + 5, y - 4, 4, 1);
    gx.fillStyle = d.hp <= 0 ? '#3a3a3a' : d.seen > 1.2 ? (Math.floor(t * 8) % 2 ? '#ff3a3a' : '#8a1a1a') : '#e4f0ff';
    gx.fillRect(x - 1, y + 1, 2, 2);
  }
};
// passes
const U = R.UI.prototype as any, io = U.interiorOptions;
U.interiorOptions = function (b: any) {
  const o = io.call(this, b), g = this.game;
  if (!EARTH.active) return o;
  if (b.type === 'social') o.push({ label: hasPass(g) && !SQ.flags.passForged ? 'Curfew pass (valid)' : 'Buy a curfew pass', price: '200', small: 'Seven nights, stamped by the Syndicate. The drones let you be', fn: () => {
    if (g.player.cash < 200) return g.ui.toast('200 credits.', 'warn');
    g.player.cash -= 200; SQ.flags.curfewPass = day(g) + 7; SQ.flags.passForged = 0; saveSequel(); g.audio.sfx('cash');
    g.ui.toast('A laminated pass with your face on it, good for seven nights.', 'good');
  } });
  if (b.type === 'pawn') o.push({ label: 'A forged curfew pass', price: '80', small: 'Good for a week. Scans fine, mostly (not always)', fn: () => {
    if (g.player.cash < 80) return g.ui.toast('80 credits.', 'warn');
    g.player.cash -= 80; SQ.flags.curfewPass = day(g) + 7; SQ.flags.passForged = 1; saveSequel(); g.audio.sfx('cash');
    g.ui.toast('The laminate\'s still warm. "Don\'t let them scan it twice."', 'good');
  } });
  return o;
};

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { CURFEW, curfewNow: () => curfewNow(R.game) });
