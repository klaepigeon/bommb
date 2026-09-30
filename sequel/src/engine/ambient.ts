// The city moving over your head. None of this is gameplay; all of it is the future:
//   Sky lanes: hover skiffs and air-cabs crossing high over the streets, nav lights blinking,
//     their shadows sliding over the rooftops a long way below.
//   Ad blimps: a slow Syndicate blimp with a scrolling neon slogan, now and then.
//   Steam: street grates on Earth breathing warm fog.
//   Rain: splashes where the acid rain hits the pavement.
//   People: robots' antenna lights blink, Choir halos breathe.

import { EARTH } from './earth';
import { SPACE } from './space';
import { SQ, cityRect } from './state';

const TS = R.TILE;
interface Flyer { x: number; y: number; vx: number; alt: number; kind: 'skiff' | 'cab' | 'blimp'; col: string; seed: number; text?: string }
export const AMB = { flyers: [] as Flyer[], splashes: [] as { x: number; y: number; t: number }[], steamT: 0, flyT: 2, blimpT: 30 };
const SLOGANS = ['FEAR IS ORDER', 'OBEY', 'WORK · PAY · SLEEP', 'CURFEW 22:00', 'THE SYNDICATE LOVES YOU', 'REPORT DISSENT', 'SYNTH-SHINE: TASTE THE FUTURE', 'OFF-WORLD JOBS · MARS NEEDS YOU'];
const PAL = ['#ff5ad0', '#5ad0ff', '#ffe070', '#e8e8f0', '#ff8a3a', '#68f0a0'];
// around the player (the camera can lag a teleport by a few frames)
const view = (g: Game) => ({ x0: g.player.x - 280, x1: g.player.x + 280, y0: g.player.y - 180, y1: g.player.y + 180 });
const hash = (x: number, y: number) => { let h = Math.imul(x, 73856093) ^ Math.imul(y, 19349663); h = Math.imul(h ^ (h >>> 13), 1274126177); return (h >>> 0) % 1000; };
const inCity = (g: Game) => !!cityRect(g.world, (g.player.x / TS) | 0, (g.player.y / TS) | 0);

function step(g: Game, dt: number): void {
  const v = view(g), city = inCity(g);
  // sky traffic in lanes
  AMB.flyT -= dt;
  if (city && AMB.flyT <= 0 && AMB.flyers.filter((f) => f.kind !== 'blimp').length < 5) {
    AMB.flyT = 1.2 + Math.random() * 2.5;
    const dir = Math.random() < 0.5 ? 1 : -1, lane = Math.floor(Math.random() * 4);
    AMB.flyers.push({ x: dir > 0 ? v.x0 - 40 : v.x1 + 40, y: g.player.y - 40 + lane * 45 + Math.random() * 20, vx: dir * (90 + Math.random() * 90), alt: 60 + lane * 12, kind: Math.random() < 0.35 ? 'cab' : 'skiff', col: PAL[Math.floor(Math.random() * PAL.length)], seed: Math.random() * 10 });
  }
  AMB.blimpT -= dt;
  if (city && EARTH.active && AMB.blimpT <= 0 && !AMB.flyers.some((f) => f.kind === 'blimp')) {
    AMB.blimpT = 70 + Math.random() * 60;
    const dir = Math.random() < 0.5 ? 1 : -1;
    AMB.flyers.push({ x: dir > 0 ? v.x0 - 120 : v.x1 + 120, y: g.player.y + 10 + Math.random() * 60, vx: dir * 14, alt: 110, kind: 'blimp', col: '#ff5ad0', seed: 0, text: SLOGANS[Math.floor(Math.random() * SLOGANS.length)] });
  }
  for (const f of AMB.flyers) f.x += f.vx * dt;
  AMB.flyers = AMB.flyers.filter((f) => f.x > v.x0 - 300 && f.x < v.x1 + 300 && Math.abs(f.y - g.player.y) < 500);
  // steam from street grates (the same grates every time: they're part of the street)
  AMB.steamT -= dt;
  if (EARTH.active && AMB.steamT <= 0) {
    AMB.steamT = 0.12;
    const w = g.world, tx0 = (v.x0 / TS) | 0, ty0 = (v.y0 / TS) | 0;
    for (let k = 0; k < 6; k++) {
      const tx = tx0 + Math.floor(Math.random() * 35), ty = ty0 + Math.floor(Math.random() * 22);
      if (hash(tx, ty) < 12 && R.data.roadTile[w.t(tx, ty)]) {
        const x = tx * TS + 8, y = ty * TS + 8;
        g.fx.add({ x: x + (Math.random() - 0.5) * 4, y, vx: (Math.random() - 0.5) * 6 + ((g.env.weather.wind && g.env.weather.wind.x) || 0) * 4, vy: -14 - Math.random() * 8, life: 1.6, max: 1.6, c: 'rgba(200,200,210,0.35)', s: 3 });
      }
    }
  }
  // rain on the pavement
  const rain = (g.env && g.env.weather.rain) || 0;
  if (rain > 0.3 && !g.player.room) for (let k = 0; k < Math.round(rain * 8 * dt * 60) / 6; k++) AMB.splashes.push({ x: v.x0 + Math.random() * (v.x1 - v.x0), y: v.y0 + Math.random() * (v.y1 - v.y0), t: 0 });
  for (const s of AMB.splashes) s.t += dt;
  AMB.splashes = AMB.splashes.filter((s) => s.t < 0.25).slice(-160);
}

const GP = R.Game.prototype, tick = GP.tick;
GP.tick = function (this: Game, dt: number) {
  const r = tick.call(this, dt);
  if (this.world && this.player && !SPACE.active && !this.ui.paused() && !this.player.room) step(this, dt);
  return r;
};
function drawFlyer(g: CanvasRenderingContext2D, f: Flyer, t: number): void {
  const x = Math.round(f.x), y = Math.round(f.y - f.alt), blink = Math.floor(t * 3 + f.seed) % 2;
  // the shadow, a long way below
  g.fillStyle = 'rgba(10,8,24,0.25)';
  g.beginPath(); g.ellipse(x + 10, f.y + 4, f.kind === 'blimp' ? 44 : 9, f.kind === 'blimp' ? 12 : 3, 0, 0, 7); g.fill();
  const d = Math.sign(f.vx) || 1;
  if (f.kind === 'blimp') {
    g.fillStyle = '#2a2438'; g.beginPath(); g.ellipse(x, y, 46, 13, 0, 0, 7); g.fill();
    g.fillStyle = '#3a3450'; g.beginPath(); g.ellipse(x, y - 3, 42, 8, 0, 0, 7); g.fill();
    g.fillStyle = '#2a2438'; g.fillRect(x - d * 44 - 4, y - 12, 8, 24);
    // the sign: a scrolling neon strip along the gondola
    const W = 60, H = 8, txt = (f.text || '') + '   ·   ', off = (t * 20) % (txt.length * 6);
    g.fillStyle = '#10081a'; g.fillRect(x - W / 2, y + 8, W, H);
    g.save(); g.beginPath(); g.rect(x - W / 2, y + 8, W, H); g.clip();
    for (let k = 0; k < 2; k++) (R.art as any).ptext(g, txt + txt, x - W / 2 + 2 - off + k * txt.length * 6, y + 8, { scale: 1, color: Math.floor(t * 2) % 5 === 0 ? '#ffffff' : f.col });
    g.restore();
    g.fillStyle = blink ? '#ff3030' : '#601010'; g.fillRect(x + d * 44, y - 2, 2, 2);
    return;
  }
  const L = f.kind === 'cab' ? 9 : 7;
  g.fillStyle = '#16141e'; g.fillRect(x - L - 1, y - 3, L * 2 + 2, 6);
  g.fillStyle = f.kind === 'cab' ? '#e8c030' : f.col; g.fillRect(x - L, y - 2, L * 2, 4);
  g.fillStyle = '#a8e8ff'; g.fillRect(x + d * (L - 4) - (d < 0 ? 2 : 0), y - 2, 3, 2);
  // thruster glow behind, nav lights blinking
  g.fillStyle = 'rgba(120,220,255,0.6)'; g.fillRect(x - d * (L + 2) - 1, y - 1, 2, 2);
  g.fillStyle = blink ? '#ff3030' : '#30ff60'; g.fillRect(x - 1, y - 4, 2, 1);
}
const ring = (R as any).ring, draw = ring.draw;
ring.draw = function (gx: CanvasRenderingContext2D) {
  draw.apply(this, arguments);
  const g = R.game;
  if (!g || !g.world || SPACE.active || g.player.room) return;
  const t = performance.now() / 1000;
  for (const s of AMB.splashes) { const k = s.t / 0.25; gx.strokeStyle = `rgba(200,220,255,${0.5 * (1 - k)})`; gx.beginPath(); gx.ellipse(s.x, s.y, 1 + k * 3, 0.5 + k * 1.2, 0, 0, 7); gx.stroke(); }
  for (const f of AMB.flyers) drawFlyer(gx, f, t);
};

// ---------------------------------------------------------------- people: lights that blink and breathe
const A = R.art as any, drawPerson = A.drawPerson;
A.drawPerson = function (g: CanvasRenderingContext2D, x: number, y: number, dir: number, walk: number, look: any, st: any) {
  if (!look || !look.xeno) return drawPerson.call(this, g, x, y, dir, walk, look, st);
  const t = performance.now() / 1000, seed = look.xenoSeed || 0;
  if (look.xeno === 'robot' || look.xeno === 'android') {
    // the antenna light blinks on its own clock, once a second or so
    const on = (t + (seed % 7) * 0.13) % 1.1 < 0.55, keep = look.xenoAccent;
    if (!on) look.xenoAccent = '#3a1a1a';
    try { return drawPerson.call(this, g, x, y, dir, walk, look, st); } finally { look.xenoAccent = keep; }
  }
  if (look.xeno === 'choir') {
    // the halo breathes
    const keep = g.globalAlpha;
    const r = drawPerson.call(this, g, x, y, dir, walk, look, st);
    g.globalAlpha = 0.25 + 0.2 * Math.sin(t * 2 + seed);
    g.fillStyle = '#c878ff'; g.beginPath(); g.ellipse(Math.round(x), Math.round(y) - 28, 6, 2, 0, 0, 7); g.fill();
    g.globalAlpha = keep;
    return r;
  }
  return drawPerson.call(this, g, x, y, dir, walk, look, st);
};

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { AMB, SQflags: () => SQ.flags });
