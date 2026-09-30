// Landing and takeoff. When you set down from orbit, you see it: the ship drops out of the
// sky over the pad on its retros, a long shadow shrinking under it, dust and grit blasting out
// across the apron, the landing legs unfolding in the last few metres, a thump and a shake as
// it settles, and then you walking down the ramp. Launching runs it the other way: engines
// spool up, the dust goes, and the ship climbs out of sight before the view cuts to orbit.
// While the ship's on the pad with the Fear Man's clamp on it, you can see the clamp.

import { SQ } from './state';
import { HOOKS } from './space';
import { shipHere } from './travel';
import { shipSprites } from '../ship/ship';

interface Dust { x: number; y: number; vx: number; vy: number; life: number; max: number; c: string; s: number }
export const LAND = { mode: null as null | 'land' | 'takeoff', t: 0, dur: 0, done: null as null | (() => void), dust: [] as Dust[], thumped: false, walk: 0, loc: null as any };
const ALT = 280, TS = R.TILE;
const OP = () => (R as any).opening;
const animate = () => !/quick/.test(location.search) || (window as any).BS2_ANIM;

// the audio: a thruster roar and a clank, built from game 1's synth
const AP = (R as any).Audio.prototype, sfx = AP.sfx;
AP.sfx = function (this: any, name: string, x?: number, y?: number) {
  if (!this.ctx) return;
  if (name === 'thrust') { this.burst(1.4, 0.32, 160, 0.7, null, null, 'lowpass'); this.tone('sawtooth', 55, 40, 1.4, 0.08); return; }
  if (name === 'clank') { this.tone('square', 220, 90, 0.12, 0.25); this.burst(0.06, 0.4, 2400, 2, null, null, 'bandpass'); return; }
  return sfx.call(this, name, x, y);
};

function begin(g: Game, mode: 'land' | 'takeoff', dur: number, done?: () => void): void {
  const pl = g.player, w = g.world;
  LAND.mode = mode; LAND.t = 0; LAND.dur = dur; LAND.done = done || null; LAND.thumped = false; LAND.walk = 0;
  // the parked ship isn't parked while it's in the air: the pad reads EMPTY underneath
  LAND.loc = SQ.shipLoc === undefined ? undefined : SQ.shipLoc;
  SQ.shipLoc = { sys: '~', planet: SQ.planet };
  const op = OP();
  if (op) op.lock = { x: 0, y: 0 };
  // the camera rides on you: stand just off the apron to watch it
  if (w.pad) { pl.place(w.pad.sx, w.pad.sy + 50); g.cam.x = pl.x; g.cam.y = pl.y - 30; }
  pl.hidden = mode === 'takeoff' || mode === 'land';
  g.audio.sfx('thrust');
}
export function landShip(g: Game, done?: () => void): void {
  if (!animate() || !g.world.pad) { if (done) done(); return; }
  begin(g, 'land', 3.4, done);
}
export function takeOff(g: Game, done: () => void): void {
  if (!animate() || !g.world.pad || !shipHere()) { done(); return; }
  begin(g, 'takeoff', 2.6, done);
}
function finish(g: Game): void {
  const mode = LAND.mode, done = LAND.done, pl = g.player, w = g.world, op = OP();
  LAND.mode = null; LAND.done = null;
  if (LAND.loc === undefined) delete (SQ as any).shipLoc; else SQ.shipLoc = LAND.loc;
  if (mode === 'land') {
    // down the ramp and out onto the apron
    pl.hidden = false;
    // out of the hatch at the foot of the hull (the ship's drawn at 2x, bottom at sy - 6 + h)
    if (w.pad) { const spr = shipSprites(SQ.ship)[24], hb = hullOf(spr); pl.place(w.pad.sx - spr.width + hb.cx * 2, w.pad.sy - spr.height - 6 + hb.bottom * 2 + 10); }
    pl.dir = 0;
    LAND.walk = 0.7;
    if (op) op.lock = { x: 0, y: 0.9 };
  } else {
    pl.hidden = false;
    if (op) op.lock = null;
  }
  if (done) done();
}
// where the hull really is inside its (padded) sprite: the bottom row, and the nozzles at its corners
const hulls = new WeakMap<HTMLCanvasElement, { bottom: number; nozL: number; nozR: number; cx: number }>();
export function hullOf(spr: HTMLCanvasElement): { bottom: number; nozL: number; nozR: number; cx: number } {
  let h = hulls.get(spr);
  if (h) return h;
  const w = spr.width, H = spr.height, d = spr.getContext('2d')!.getImageData(0, 0, w, H).data;
  let bottom = 0, x0 = w, x1 = 0;
  for (let y = 0; y < H; y++) for (let x = 0; x < w; x++) if (d[(y * w + x) * 4 + 3] > 128) bottom = y;
  for (let y = Math.max(0, bottom - 2); y <= bottom; y++) for (let x = 0; x < w; x++) if (d[(y * w + x) * 4 + 3] > 128) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); }
  h = { bottom, nozL: x0 + 1, nozR: x1 - 1, cx: (x0 + x1) / 2 };
  hulls.set(spr, h);
  return h;
}
// where the clamp sits: the right-hand landing leg, at the foot of the hull
export function clampSpot(): { x: number; y: number } | null {
  const p = R.game && R.game.world && R.game.world.pad;
  if (!p) return null;
  const spr = shipSprites(SQ.ship)[24], hb = hullOf(spr);
  return { x: Math.round(p.sx - spr.width + hb.nozR * 2 - 7), y: Math.round(p.sy - spr.height - 6 + hb.bottom * 2 - 5) };
}
const ease = (x: number) => 1 - Math.pow(1 - Math.min(1, Math.max(0, x)), 3);
export const shipAlt = () => (!LAND.mode ? 0 : LAND.mode === 'land' ? ALT * Math.pow(1 - ease(LAND.t / LAND.dur), 1.6) : ALT * Math.pow(Math.min(1, LAND.t / LAND.dur), 2.2));

// ---------------------------------------------------------------- the step
const GP = R.Game.prototype, tick = GP.tick;
GP.tick = function (this: Game, dt: number) {
  const r = tick.call(this, dt);
  if (this.ui.paused() || !this.world) return r;
  // nobody parks on a landing pad (it's painted like a car park, and the traffic thinks so too)
  const pad = this.world.pad;
  if (pad && this.traffic && (LAND.mode || (this.clock.real | 0) % 2 === 0)) for (const v of this.traffic.list) {
    if (v.removed || v.keep || (v.driver && !v.parked) || v === this.player.inCar) continue;
    if (v.x > pad.x * TS - 8 && v.x < (pad.x + pad.w) * TS + 8 && v.y > pad.y * TS - 8 && v.y < (pad.y + pad.h) * TS + 8) this.traffic.remove(v);
  }
  if (LAND.walk > 0) { LAND.walk -= dt; if (LAND.walk <= 0) { const op = OP(); if (op && op.lock && op.lock.y > 0.5 && !op.cineOn) op.lock = null; } }
  for (const d of LAND.dust) { d.x += d.vx * dt; d.y += d.vy * dt; d.vx *= 1 - dt * 1.8; d.vy *= 1 - dt * 1.8; d.life -= dt; }
  LAND.dust = LAND.dust.filter((d) => d.life > 0);
  if (!LAND.mode) return r;
  const p = this.world.pad;
  if (!p) { finish(this); return r; }
  LAND.t += dt;
  const alt = shipAlt();
  // the camera: hold on the pad, a little above it while the ship is high
  this.cam.x += (p.sx - this.cam.x) * Math.min(1, dt * 3); this.cam.y += (p.sy - Math.min(90, alt * 0.35) - this.cam.y) * Math.min(1, dt * 3);
  // grit blown out from under the engines, more as it gets close to the ground
  const blast = Math.max(0, 1 - alt / 170);
  for (let k = 0; k < Math.round(blast * 14 * dt * 60) / 10 + (Math.random() < blast ? 1 : 0); k++) {
    const a = Math.random() * Math.PI * 2, sp = 90 + Math.random() * 160 * blast;
    LAND.dust.push({ x: p.sx + Math.cos(a) * 14, y: p.sy + 6 + Math.sin(a) * 6, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp * 0.45, life: 0.6 + Math.random() * 0.7, max: 1.3, c: Math.random() < 0.5 ? '#9a8a78' : '#c8b8a0', s: 1 + (Math.random() < 0.3 ? 1 : 0) });
  }
  if (LAND.mode === 'land' && !LAND.thumped && LAND.t >= LAND.dur * 0.97) {
    LAND.thumped = true;
    this.cam.shake(4); this.audio.sfx('bump'); this.audio.sfx('clank');
    for (let k = 0; k < 40; k++) { const a = (k / 40) * Math.PI * 2; LAND.dust.push({ x: p.sx + Math.cos(a) * 18, y: p.sy + 6 + Math.sin(a) * 8, vx: Math.cos(a) * 220, vy: Math.sin(a) * 100, life: 1.1, max: 1.1, c: '#b8a890', s: 2 }); }
  }
  if (LAND.mode === 'takeoff' && LAND.t > 0.2 && LAND.t < 0.25) this.cam.shake(3);
  if (LAND.t >= LAND.dur + (LAND.mode === 'land' ? 0.5 : 0)) finish(this);
  return r;
};

// ---------------------------------------------------------------- drawing: over everything on the ground
function drawFlame(g: CanvasRenderingContext2D, x: number, y: number, len: number): void {
  const f = 0.75 + Math.random() * 0.35, L = len * f;
  const gr = g.createLinearGradient(x, y, x, y + L);
  gr.addColorStop(0, 'rgba(255,255,230,0.95)'); gr.addColorStop(0.25, 'rgba(255,210,90,0.9)'); gr.addColorStop(0.6, 'rgba(255,110,40,0.55)'); gr.addColorStop(1, 'rgba(255,60,20,0)');
  g.fillStyle = gr;
  g.beginPath(); g.moveTo(x - 3, y); g.lineTo(x + 3, y); g.lineTo(x + 1, y + L); g.lineTo(x - 1, y + L); g.fill();
  g.fillStyle = 'rgba(255,240,200,0.35)'; g.beginPath(); g.ellipse(x, y + 2, 5, 3, 0, 0, 7); g.fill();
}
const ring = (R as any).ring, draw = ring.draw;
ring.draw = function (gx: CanvasRenderingContext2D) {
  draw.apply(this, arguments);
  const w = R.game && R.game.world, p = w && w.pad;
  for (const d of LAND.dust) { gx.globalAlpha = Math.max(0, Math.min(1, d.life / d.max)) * 0.8; gx.fillStyle = d.c; gx.fillRect(Math.round(d.x), Math.round(d.y), d.s, d.s); }
  gx.globalAlpha = 1;
  if (!LAND.mode || !p) return;
  const alt = shipAlt(), spr = shipSprites(SQ.ship)[24], t = performance.now() / 1000;
  const sway = Math.sin(t * 2.3) * Math.min(2, alt / 60);
  // the shadow: small and faint high up, dark and full-size on the ground
  const k = 1 - Math.min(1, alt / ALT);
  gx.fillStyle = `rgba(16,12,36,${0.1 + 0.3 * k})`;
  gx.beginPath(); gx.ellipse(p.sx + 4 + alt * 0.15, p.sy + 10, spr.width * (0.45 + 0.45 * k), spr.height * (0.25 + 0.25 * k), 0, 0, 7); gx.fill();
  // under-glow on the apron
  if (alt < 180) { const gl = gx.createRadialGradient(p.sx, p.sy + 6, 2, p.sx, p.sy + 6, 50); gl.addColorStop(0, `rgba(255,170,80,${0.35 * (1 - alt / 180)})`); gl.addColorStop(1, 'rgba(255,120,40,0)'); gx.fillStyle = gl; gx.fillRect(p.sx - 50, p.sy - 44, 100, 100); }
  const sx = Math.round(p.sx - spr.width + sway), sy = Math.round(p.sy - spr.height - 6 - alt);
  // engines: two plumes, longest when braking hard near the ground (or climbing out)
  const burn = LAND.mode === 'land' ? 10 + 22 * Math.max(0, 1 - alt / 200) : 26 + LAND.t * 8;
  const hb = hullOf(spr), ey = sy + hb.bottom * 2 + 1, nzL = sx + hb.nozL * 2 + 1, nzR = sx + hb.nozR * 2 + 1;
  if (!(LAND.mode === 'land' && LAND.thumped)) { drawFlame(gx, nzL, ey, burn); drawFlame(gx, nzR, ey, burn); }
  gx.imageSmoothingEnabled = false;
  gx.drawImage(spr, sx, sy, spr.width * 2, spr.height * 2);
  // landing legs unfold for the last stretch
  const legs = LAND.mode === 'land' ? Math.max(0, 1 - alt / 60) : Math.max(0, 1 - LAND.t / 0.6);
  if (legs > 0) {
    gx.strokeStyle = '#3a3a48'; gx.lineWidth = 2;
    for (const s of [-1, 1]) { const lx = s < 0 ? nzL + 4 : nzR - 4; gx.beginPath(); gx.moveTo(lx, ey - 6); gx.lineTo(lx + s * 6 * legs, ey - 6 + 10 * legs); gx.stroke(); gx.fillStyle = '#5a5a68'; gx.fillRect(lx + s * 6 * legs - 2, ey - 6 + 10 * legs, 4, 2); }
    gx.lineWidth = 1;
  }
};
// the clamp on the parked ship: yellow and black, bolted to a landing leg
const props = (R as any).props, ground = props.drawGround;
props.drawGround = function (g: CanvasRenderingContext2D, inView: (x: number, y: number) => boolean) {
  const r = ground.call(this, g, inView);
  const w = R.game && R.game.world, p = w && w.pad;
  if (p && SQ.flags.clamp && !LAND.mode && shipHere() && inView(p.sx, p.sy)) {
    const c = clampSpot()!;
    const x = c.x - 5, y = c.y - 3, blink = Math.floor(performance.now() / 500) % 2;
    g.fillStyle = '#1a1410'; g.fillRect(x - 1, y - 1, 12, 8);
    for (let i = 0; i < 5; i++) { g.fillStyle = i % 2 ? '#1a1a1a' : '#e8b020'; g.fillRect(x + i * 2, y, 2, 6); }
    g.fillStyle = blink ? '#ff3030' : '#6a1010'; g.fillRect(x + 4, y - 3, 2, 2);
  }
  return r;
};
// don't draw the player while they're aboard
const RP = (R as any).Renderer.prototype, dp = RP.drawPlayer;
RP.drawPlayer = function (g: CanvasRenderingContext2D, pl: any) { if (LAND.mode && pl.hidden) return; return dp.call(this, g, pl); };

HOOKS.touchdown.push((g) => { if (shipHere()) landShip(g); });

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { LAND, landShip: (d?: () => void) => landShip(R.game, d), shipTakeOff: (d: () => void) => takeOff(R.game, d), shipAlt });
