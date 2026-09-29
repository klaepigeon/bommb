// Gore in the future. Game 1's wounds, severed limbs, burst heads and the knife's work on a
// body all carry over; XX8X adds what the future does to a body.
//   Every weapon takes people apart its own way: the rail rifle bursts heads, the hand cannon
//   takes heads and arms, a scatter blaster up close tears a body apart, pulse guns saw off
//   arms, the plasma machete and arc hatchet lop off heads and limbs (and cauterise the
//   stumps: smoke, not spray), the mono-wire razor takes heads clean, the napalm canister
//   chars people black.
//   Bodies bleed what they're made of: robots and androids leak black oil and spit sparks,
//   cyborgs bleed and spark, Greys bleed green, the Choir violet, Martians orange, Saurians
//   yellow, the Fear Man gold. Generated peoples bleed their own accent colour.
//   And the knife does more: rip the implants out of a cyborg, strip a robot for parts, take
//   a tissue sample from an alien (the Greys buy them), or harvest organs from anyone.

import { saveSequel } from './state';
import { SPECIES } from './aliens';
import { addCargo } from './cargo';

const D = R.data, C = R.combat, FP = R.FX ? R.FX.prototype : null;
const on = () => R.game && R.game.settings.gore !== false;
const TS = R.TILE;

// ---------------------------------------------------------------- what they bleed
const BLOOD_BY: Record<string, string[]> = {
  robot: ['#16161c', '#2a2a34', '#0c0c10'], android: ['#e8e8f0', '#b8c8d8', '#8898a8'],
  grey: ['#3a9a4a', '#58c878', '#2a7a3a'], choir: ['#8a4ac8', '#b878ff', '#6a2aa8'], martian: ['#c85a1a', '#e8742a', '#a84410'],
  saurian: ['#b8a020', '#d8c040', '#8a7810'], fearman: ['#c89a10', '#f0c020', '#a07808'], mutant: ['#6a9a28', '#8ac838', '#4a7a18'],
};
const SPARKY = new Set(['robot', 'android', 'cyborg']);
export function bloodOf(look: any): string[] | null {
  const x = look && look.xeno;
  if (!x || x === 'cyborg' || x === 'belter') return null;
  if (BLOOD_BY[x]) return BLOOD_BY[x];
  const sp = SPECIES[x];
  return sp && !sp.keepSkin ? [look.xenoAccent || sp.accent, sp.accent, sp.skin] : null;
}
const RED = /^#(8a1a14|a8201a|6a1410|b8302a|7a1410|5a0c0c)$/i, REDA = /^rgba\((9\d|1[0-4]\d),\s*(1[0-4]|2\d|30),\s*(1[0-6]|30),/;
let TINT: string[] | null = null, SPARK = false;
const tintA = (c: string, t: string) => { const n = parseInt(t.slice(1), 16), a = (c.match(/,\s*([\d.]+)\)$/) || [0, '0.6'])[1]; return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`; };
if (FP) {
  const baseAdd = FP.add, baseDecal = FP.decal;
  FP.add = function (this: any, p: any) {
    if (TINT && p && typeof p.c === 'string' && RED.test(p.c)) p.c = TINT[Math.floor(Math.random() * TINT.length)];
    return baseAdd.call(this, p);
  };
  FP.decal = function (this: any, d: any) {
    if (TINT && d && typeof d.c === 'string' && REDA.test(d.c)) d.c = tintA(d.c, TINT[0]);
    return baseDecal.call(this, d);
  };
}
// run something with a body's blood colour in force
function as<T>(h: any, fn: () => T): T {
  const was = TINT, ws = SPARK;
  TINT = bloodOf(h && h.look); SPARK = !!(h && h.look && SPARKY.has(h.look.xeno));
  try { return fn(); } finally { TINT = was; SPARK = ws; }
}
const baseDamage = C.damage;
C.damage = function (this: unknown, target: any, amt: number, source: any, kind: string) {
  return as(target, () => {
    const r = baseDamage.call(this, target, amt, source, kind);
    if (SPARK && on() && target && R.game) R.game.fx.sparks(target.x, target.y - 12, 5);
    return r;
  });
};

// ---------------------------------------------------------------- how each weapon takes a body apart
// [head, arm, tear apart]: chances on the killing blow, on top of game 1's own
type Cut = { head?: number; burst?: number; arm?: number; tear?: number; close?: boolean; hot?: boolean; char?: boolean };
const CUTS: Record<string, Cut> = {
  rifle: { burst: 0.5 }, magnum: { head: 0.3, arm: 0.2, hot: true }, revolver: { arm: 0.1, hot: true }, colt45: { arm: 0.1, hot: true }, derringer: { arm: 0.06, hot: true },
  shotgun: { tear: 0.35, burst: 0.2, close: true }, sawedoff: { tear: 0.5, burst: 0.25, close: true },
  chopper: { arm: 0.2, hot: true }, tommy: { arm: 0.25, head: 0.08, hot: true }, carbine: { head: 0.12, arm: 0.12, hot: true }, crossbow: { head: 0.1 },
  machete: { head: 0.3, arm: 0.4, hot: true }, hatchet: { head: 0.15, arm: 0.3, hot: true }, knife: { arm: 0.12 }, razor: { head: 0.22 },
  molotov: { char: true },
};
const baseKill = C.kill;
C.kill = function (this: any, h: any, source: any, kind?: string) {
  const was = !!(h && h.dead);
  const r = as(h, () => baseKill.call(this, h, source, kind));
  if (was || !h || h.kind !== 'h' || h.gibbed || !on()) return r;
  const g = R.game, w = (h.wnd = h.wnd || { bruise: 0, bleed: 0 });
  if (h.look) h.look._w = w;
  const wpn = source && source.weapon, cut = (wpn && CUTS[wpn]) || (kind === 'fire' ? CUTS.molotov : null);
  const ang = source && source.x != null ? Math.atan2(h.y - source.y, h.x - source.x) : Math.random() * 6.28;
  const d = source && source.x != null ? Math.hypot(source.x - h.x, source.y - h.y) : 999;
  as(h, () => {
    if (SPARK) { g.fx.sparks(h.x, h.y - 12, 16); g.fx.smoke(h.x, h.y - 10, true); }
    if (!cut) return;
    if (cut.char || kind === 'fire') { w.charred = true; for (let k = 0; k < 4; k++) g.fx.smoke(h.x + (Math.random() - 0.5) * 8, h.y - 8, true); return; }
    if (w.headless || w.limbs) return;
    const near = !cut.close || d < TS * 3.4;
    const BU = R.butcher;
    if (cut.tear && near && Math.random() < cut.tear && BU) {
      // torn apart: arms, legs and all
      w.limbs = true; w.armless = true;
      BU.drop(h, 'arm', 2); BU.drop(h, 'leg', 2);
      for (let k = 0; k < 3; k++) g.fx.spray(h.x, h.y - 10, ang + (k - 1) * 0.5, 16);
      g.cam.shake(3);
    } else if (cut.burst && near && Math.random() < cut.burst && BU) BU.burst(h, ang);
    else if (cut.head && Math.random() < cut.head) C.decap(h, ang, w);
    else if (cut.arm && Math.random() < cut.arm) C.sever(h, ang, w);
    if (cut.hot && (w.headless || w.armless)) {
      // plasma and blaster wounds cauterise: a hiss of smoke and a glowing stump
      w.cauterised = true;
      for (let k = 0; k < 5; k++) g.fx.add({ x: h.x + (Math.random() - 0.5) * 6, y: h.y - 14, vx: (Math.random() - 0.5) * 20, vy: -30 - Math.random() * 20, life: 0.7, max: 0.7, c: Math.random() < 0.5 ? '#ff9a3a' : '#ffe070', s: 1.5, glow: 1 });
      g.fx.smoke(h.x, h.y - 14, false);
    }
  });
  return r;
};

// ---------------------------------------------------------------- the look of it
const A = R.art as any, baseDraw = A.drawPerson;
A.drawPerson = function (g: CanvasRenderingContext2D, x: number, y: number, dir: number, walk: number, look: any, st: any) {
  const w = look && look._w;
  if (w && w.charred && on()) {
    // burned black: draw the body, then scorch it
    const res = baseDraw.call(this, g, x, y, dir, walk, look, st);
    const X = Math.round(x), Y = Math.round(y);
    g.fillStyle = 'rgba(20,14,10,0.78)';
    if (st && st.down) g.fillRect(X - 12, Y - 6, 24, 9); else g.fillRect(X - 6, Y - 24, 12, 24);
    g.fillStyle = 'rgba(255,120,40,0.5)'; if (Math.floor(performance.now() / 200 + X) % 3 === 0) g.fillRect(X - 2 + (X % 5), Y - 3, 1, 1);
    return res;
  }
  const res = baseDraw.call(this, g, x, y, dir, walk, look, st);
  if (w && w.cauterised && on() && st && st.down && (w.headless || w.armless)) {
    const X = Math.round(x), Y = Math.round(y);
    g.fillStyle = '#ff9a3a'; g.fillRect(X + (w.headless ? 8 : 2), Y - 4, 1, 2);
  }
  return res;
};

// ---------------------------------------------------------------- the knife, in the future
Object.assign(D.loot, {
  implant: { name: 'Ripped Cyber-Implant', v: 240 },
  servo: { name: 'Robot Servo Pack', v: 150 },
  organs: { name: 'Cold-Packed Organs', v: 420 },
});
const BU = R.butcher;
if (BU) {
  const baseMenu = BU.menu;
  BU.menu = function (this: any, a: any) {
    const g = R.game, pl = g.player, x = a.look && a.look.xeno, w = (a.wnd = a.wnd || {});
    const extra: { label: string; small?: string; fn: () => void }[] = [];
    const loot = (k: string, n = 1) => { pl.inv.loot[k] = (pl.inv.loot[k] || 0) + n; };
    if (x === 'cyborg' && !w.gutted) extra.push({ label: 'Rip out the implants', small: 'A Chop Shop pays well, and asks nothing', fn: () => as(a, () => this.work(a, 'The chrome comes out wet. Some of it is still twitching.', () => { w.gutted = true; loot('implant', 1 + (Math.random() < 0.5 ? 1 : 0)); g.fx.sparks(a.x, a.y - 4, 10); })) });
    if ((x === 'robot' || x === 'android') && !w.gutted) extra.push({ label: 'Strip it for parts', small: 'Servos, wiring, a power cell', fn: () => as(a, () => this.work(a, 'You pull it apart like a radio. The eyes stay lit a while.', () => { w.gutted = true; w.limbs = true; w.armless = true; this.drop(a, 'arm', 2); loot('servo', 2); g.fx.sparks(a.x, a.y - 4, 14); })) });
    else if (x && SPECIES[x] && !w.sampled && x !== 'cyborg') extra.push({ label: 'Take a tissue sample', small: 'Xeno-samples: the Greys on Luna collect them', fn: () => as(a, () => this.work(a, 'A vial of something that is not quite blood.', () => { w.sampled = true; const put = addCargo('xeno', 1, true); if (!put) g.ui.toast('No room in the ship\'s hold for the sample.', 'warn'); saveSequel(); })) });
    if (!w.organs && x !== 'robot' && x !== 'android') extra.push({ label: 'Harvest organs', small: 'Worth a fortune in a Chrome Clinic back room. You won\'t sleep.', fn: () => as(a, () => this.work(a, 'Heart, kidneys, liver, into the cold pack. You\'re not the same person who knelt down.', () => { w.organs = true; loot('organs'); pl.cool = Math.max(0, pl.cool - 25); pl.rep.infamy = (pl.rep.infamy || 0) + 3; })) });
    if (!extra.length) return as(a, () => baseMenu.call(this, a));
    // show game 1's menu, then add ours above "Leave it"
    const ui = g.ui, baseChoice = ui.choice;
    ui.choice = function (this: any, title: string, opts: any[]) { ui.choice = baseChoice; const i = opts.findIndex((o) => /Leave it/.test(o.label)); opts.splice(i < 0 ? opts.length : i, 0, ...extra); return baseChoice.call(this, title, opts); };
    try { return as(a, () => baseMenu.call(this, a)); } finally { ui.choice = baseChoice; }
  };
}
(window as any).BS2 = Object.assign((window as any).BS2 || {}, { bloodOf, CUTS });
