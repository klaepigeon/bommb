// Ecosystems. Every world has its own wildlife, built on game 1's animals (the same AI:
// grazing, fleeing, packs, ambushes, hunting you at night), and a living food chain:
//   - A daily predator-prey model per world (grazers breed up to what the land can feed;
//     predators breed on what they catch and starve without it). What you meet on the ground
//     follows those numbers.
//   - Predators get hungry and go hunting; a kill feeds them for a while.
//   - Herds migrate with the seasons, drifting across the map.
//   - You're part of it: shoot out the predators and the grazers boom, then strip the land;
//     overhunt the grazers and the predators come for easier meat (you).
// Mars wildlife lives where the terraforming took: striders graze the green, and the red dust
// belongs to things that were never meant to be there.

import { SQ, saveSequel } from './state';
import { worldProfile } from './planets';

type Shape = 'quad' | 'worm' | 'strider' | 'crab' | 'blob';
export interface Beast {
  name: string; size: number; hp: number; speed: number; col: string; biome: string[];
  prey?: 1; predator?: 1; angry?: 1; bird?: 1; ambush?: 1; herd?: [number, number]; dmg?: number; night?: number; pelt?: string;
  shape?: Shape; fauna?: string; role?: 'prey' | 'pred' | 'bird' | 'pest';
}

// each world's species; 'crow', 'gull' and 'dog' are the town animals game 1 spawns in cities
export const FAUNA: Record<string, Record<string, Beast>> = {
  mars: {
    dusthare: { name: 'Dust Hare', size: 5, hp: 8, speed: 100, prey: 1, col: '#c8703a', biome: ['desert', 'grass', 'field'], pelt: 'pelt_rabbit', role: 'prey' },
    strider: { name: 'Strider', size: 10, hp: 45, speed: 105, prey: 1, col: '#d8b070', biome: ['grass', 'field', 'forest'], herd: [3, 6], shape: 'strider', pelt: 'pelt_deer', role: 'prey' },
    rustwolf: { name: 'Rust Wolf', size: 9, hp: 55, speed: 118, predator: 1, dmg: 12, col: '#8a3a2a', biome: ['desert', 'grass', 'forest'], herd: [2, 4], night: 1.8, pelt: 'pelt_wolf', role: 'pred' },
    sandworm: { name: 'Sand Worm', size: 12, hp: 110, speed: 70, predator: 1, dmg: 26, ambush: 1, col: '#b87a48', biome: ['desert'], shape: 'worm', role: 'pred' },
    crow: { name: 'Dust Kite', size: 4, hp: 3, speed: 140, bird: 1, col: '#d8603a', biome: ['desert', 'grass', 'city'], herd: [2, 5], role: 'bird' },
    gull: { name: 'Canal Gull', size: 4, hp: 3, speed: 140, bird: 1, col: '#e8e0d0', biome: ['coast', 'city'], herd: [3, 6], role: 'bird' },
    dog: { name: 'Dome Dog', size: 7, hp: 30, speed: 110, dmg: 6, col: '#b0785a', biome: ['city'], role: 'pest' },
  },
  venus: {
    gardenbuck: { name: 'Garden Buck', size: 9, hp: 40, speed: 110, prey: 1, col: '#e8d0a0', biome: ['grass', 'forest', 'field'], herd: [2, 4], pelt: 'pelt_deer', role: 'prey' },
    marblecat: { name: 'Marble Cat', size: 8, hp: 40, speed: 125, predator: 1, dmg: 10, col: '#e8e8e0', biome: ['grass', 'forest'], night: 2, role: 'pred' },
    lurker: { name: 'Acid Lurker', size: 12, hp: 120, speed: 70, predator: 1, dmg: 28, ambush: 1, col: '#9ac83a', biome: ['marsh', 'coast'], shape: 'blob', role: 'pred' },
    crow: { name: 'Acid Moth', size: 4, hp: 3, speed: 120, bird: 1, col: '#f0e060', biome: ['grass', 'city', 'field'], herd: [3, 7], role: 'bird' },
    gull: { name: 'Cloud Swift', size: 4, hp: 3, speed: 150, bird: 1, col: '#f8f0e0', biome: ['coast', 'city'], herd: [3, 6], role: 'bird' },
    dog: { name: 'Court Hound', size: 8, hp: 35, speed: 115, dmg: 8, col: '#3a3a4a', biome: ['city'], role: 'pest' },
  },
  luna: {
    domerat: { name: 'Dome Rat', size: 4, hp: 6, speed: 95, prey: 1, col: '#9a9088', biome: ['desert', 'grass', 'field', 'forest', 'marsh'], herd: [2, 5], role: 'prey' },
    cratercrab: { name: 'Crater Crab', size: 9, hp: 60, speed: 60, angry: 1, dmg: 12, col: '#b8b0a8', biome: ['desert', 'forest'], herd: [1, 3], shape: 'crab', role: 'pred' },
    crow: { name: 'Vent Moth', size: 4, hp: 3, speed: 110, bird: 1, col: '#c8c8d8', biome: ['desert', 'city'], herd: [2, 5], role: 'bird' },
    gull: { name: 'Vent Moth', size: 4, hp: 3, speed: 110, bird: 1, col: '#c8c8d8', biome: ['coast', 'city'], herd: [2, 5], role: 'bird' },
    dog: { name: 'Dome Rat', size: 4, hp: 6, speed: 95, col: '#9a9088', biome: ['city'], role: 'pest' },
  },
  ceres: {
    icebug: { name: 'Ice Bug', size: 6, hp: 14, speed: 80, prey: 1, col: '#a8d8e8', biome: ['snow', 'desert', 'grass', 'forest'], herd: [3, 6], shape: 'crab', role: 'prey' },
    tunnelworm: { name: 'Tunnel Worm', size: 13, hp: 130, speed: 75, predator: 1, dmg: 24, ambush: 1, col: '#7a6a5a', biome: ['snow', 'desert', 'forest'], shape: 'worm', role: 'pred' },
    crow: { name: 'Frost Mite', size: 3, hp: 2, speed: 120, bird: 1, col: '#e0f0f8', biome: ['snow', 'city'], herd: [3, 7], role: 'bird' },
    gull: { name: 'Frost Mite', size: 3, hp: 2, speed: 120, bird: 1, col: '#e0f0f8', biome: ['coast', 'city'], herd: [3, 7], role: 'bird' },
    dog: { name: 'Claim Dog', size: 7, hp: 30, speed: 110, dmg: 7, col: '#6a5a4a', biome: ['city'], role: 'pest' },
  },
};

// register them with game 1's animal table (keys prefixed by world so they never clash)
const D = R.data, GAME1 = Object.keys(D.animals);
export function registerFauna(id: string, set: Record<string, Beast>): void {
  FAUNA[id] = set;
  for (const [k, b] of Object.entries(set)) { b.fauna = id; D.animals[id + ':' + k] = b; }
}
for (const [id, set] of Object.entries(FAUNA)) registerFauna(id, set);

const faunaId = () => worldProfile().fauna || 'earth';

// ---------------------------------------------------------------- the food chain
interface Eco { prey: number; pred: number; land: number; day: number; hunted: number; culled: number }
export function eco(id = faunaId()): Eco {
  const e = (SQ.eco[id] = SQ.eco[id] || {}) as unknown as Eco;
  if (e.prey == null) Object.assign(e, { prey: 60, pred: 12, land: 1, day: -1, hunted: 0, culled: 0 });
  return e;
}
// one day of Lotka-Volterra with a carrying capacity set by the land, which the grazers wear down
export function stepEco(e: Eco): void {
  const K = 100 * e.land;
  const born = 0.35 * e.prey * (1 - e.prey / Math.max(1, K));
  const eaten = 0.012 * e.prey * e.pred;
  const fed = 0.004 * e.prey * e.pred, starve = 0.18 * e.pred;
  e.prey = Math.max(2, Math.min(200, e.prey + born - eaten));
  // a few stragglers wander in from elsewhere, so a wiped-out predator comes back, slowly
  e.pred = Math.max(0.5, Math.min(60, e.pred + fed - starve + 0.05));
  // too many mouths strip the land; a rested land grows back
  e.land = Math.max(0.35, Math.min(1.2, e.land + (e.prey > K * 0.75 ? -0.05 : 0.02)));
}
export function describe(id = faunaId()): string[] {
  const e = eco(id), out: string[] = [];
  out.push(e.prey > 110 ? 'Grazers are booming' : e.prey < 25 ? 'Grazers are scarce' : 'Grazers are holding steady');
  out.push(e.pred > 22 ? 'predators are everywhere' : e.pred < 5 ? 'the predators are nearly gone' : 'predators in balance');
  if (e.land < 0.7) out.push('the land is overgrazed');
  return out;
}

// the day turns over: step every world you've been to (the ones you're not on still live)
const GP = R.Game.prototype, baseTick = GP.tick;
GP.tick = function (this: Game, dt: number) {
  const r = baseTick.call(this, dt);
  if (this.pop) {
    const e = eco();
    if (e.day !== this.pop.day) {
      const days = e.day < 0 ? 0 : Math.min(30, this.pop.day - e.day);
      for (const id of Object.keys(SQ.eco)) { const o = eco(id); for (let k = 0; k < days; k++) stepEco(o); o.day = this.pop.day; }
      e.day = this.pop.day;
      saveSequel();
    }
  }
  return r;
};

// what you meet follows the numbers: only this world's species, predators as common as they are
const AP = R.Actors.prototype, baseManage = AP.manage;
AP.manage = function (this: { list: any[] }) {
  const id = faunaId();
  const all = D.animals, e = eco(id);
  const view: Record<string, Beast> = {};
  const predOdds = Math.min(0.9, e.pred / 20), preyOdds = Math.min(1, e.prey / 60);
  if (id === 'earth') { for (const k of GAME1) view[k] = all[k]; }
  else for (const [k, b] of Object.entries(FAUNA[id] || {})) {
    const on = b.role === 'pred' ? Math.random() < predOdds : b.role === 'prey' ? Math.random() < preyOdds + 0.15 : true;
    // town animals keep game 1's names (it spawns them by name); wildlife keeps its registered key
    const town = k === 'crow' || k === 'gull' || k === 'dog';
    if (on || town) view[town ? k : id + ':' + k] = b;
  }
  D.animals = view;
  try { return baseManage.call(this); } finally { D.animals = all; }
};

// hunger, the hunt, and migration
const baseUpd = AP.updateAnimal;
AP.updateAnimal = function (this: any, a: any, dt: number) {
  const d = a.def;
  if (!a.dead && d.predator && !d.bird) {
    a.hunger = Math.min(1, (a.hunger || Math.random() * 0.5) + dt / 90);
    if (a.state === 'wander' && a.hunger > 0.55 && Math.random() < dt * a.hunger) {
      const prey = this.near(a.x, a.y, R.TILE * 16, (o: any) => o.kind === 'a' && !o.dead && o.def.prey && o !== a)[0];
      if (prey) { a.state = 'attack'; a.target = prey; a.timer = 14; }
    }
    if (a.state === 'attack' && a.target && a.target.kind === 'a' && a.target.dead) { a.hunger = 0; a.state = 'wander'; a.pause = true; a.timer = 25; }
  }
  // grazing herds drift with the season
  if (!a.dead && d.prey && d.herd && a.state === 'wander' && !a.pause && R.game.pop) {
    const heading = ((R.game.pop.day / 20) % 4) * (Math.PI / 2) + 0.4;
    a.angle += Math.sin(heading - a.angle) * Math.min(1, dt * 0.6);
  }
  return baseUpd.call(this, a, dt);
};

// the hunter's toll
const C = R.combat, baseKill = C.kill;
C.kill = function (h: any, source: any, kind?: string) {
  const was = h && h.dead;
  const r = baseKill.call(this, h, source, kind);
  if (h && h.kind === 'a' && !was && h.def && !h.def.bird) {
    const e = eco(), byYou = source === R.game.player || (source && source.driver === R.game.player);
    if (h.def.predator) { e.pred = Math.max(0.5, e.pred - (byYou ? 1.2 : 0.4)); if (byYou) e.culled++; }
    else if (h.def.prey) { e.prey = Math.max(2, e.prey - (byYou ? 1.5 : 0.5)); if (byYou) e.hunted++; }
  }
  return r;
};

// ---------------------------------------------------------------- bodies
const A = R.art as any, baseDraw = A.drawAnimal;
const shade = (hex: string, k: number) => { const n = parseInt(hex.slice(1), 16); const c = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((v) => Math.max(0, Math.min(255, Math.round(v + k)))); return `rgb(${c[0]},${c[1]},${c[2]})`; };
A.drawAnimal = function (g: CanvasRenderingContext2D, a: any) {
  const d = a.def as Beast;
  if (!d.shape || d.shape === 'quad' || (d.bird && a.flying)) return baseDraw.call(this, g, a);
  const s = d.size, t = a.t || 0, mv = a.moving && !a.dead;
  g.save();
  g.translate(Math.round(a.x), Math.round(a.y));
  g.scale(Math.cos(a.angle) >= 0 ? 1 : -1, 1);
  if (a.dead) g.rotate(Math.PI / 2 * 0.9);
  g.fillStyle = 'rgba(15,10,5,0.3)'; g.beginPath(); g.ellipse(0, 1, s * 0.9, s * 0.3, 0, 0, 7); g.fill();
  if (d.shape === 'worm') {
    // a segmented body that surfaces in a wave, with a round mouth of teeth
    const up = a.state === 'attack' ? 1 : 0.6;
    for (let k = 0; k < 6; k++) {
      const x = -s + k * (s * 0.4), y = -2 - Math.max(0, Math.sin(t * 5 + k * 0.9)) * 4 * up;
      g.fillStyle = k % 2 ? d.col : shade(d.col, -25); g.fillRect(x, y - 3, s * 0.42, 5);
    }
    g.fillStyle = '#2a1010'; g.fillRect(s * 1.3, -6, 4, 5);
    g.fillStyle = '#f0e8d0'; g.fillRect(s * 1.3, -6, 1, 1); g.fillRect(s * 1.3 + 3, -6, 1, 1); g.fillRect(s * 1.3, -2, 1, 1); g.fillRect(s * 1.3 + 3, -2, 1, 1);
  } else if (d.shape === 'strider') {
    // tall and thin-legged, a long neck, a crest
    const leg = mv ? Math.sin(t * 12) * 2 : 0;
    g.fillStyle = shade(d.col, -35);
    g.fillRect(-s * 0.4 + leg, -8, 1, 9); g.fillRect(s * 0.3 - leg, -8, 1, 9);
    g.fillStyle = d.col; g.fillRect(-s * 0.55, -13, s * 1.1, 5);
    g.fillRect(s * 0.45, -20, 2, 8); g.fillRect(s * 0.45, -21, 5, 3);
    g.fillStyle = shade(d.col, 30); g.fillRect(-s * 0.55, -13, s * 1.1, 1);
    g.fillStyle = '#ff9a3a'; g.fillRect(s * 0.45, -23, 2, 2);
  } else if (d.shape === 'crab') {
    const leg = mv ? Math.sin(t * 16) : 0;
    g.fillStyle = shade(d.col, -30);
    for (let k = 0; k < 3; k++) { g.fillRect(-s * 0.7 - 1, -3 + k * 2 + (k % 2 ? leg : -leg), 2, 1); g.fillRect(s * 0.7 - 1, -3 + k * 2 + (k % 2 ? -leg : leg), 2, 1); }
    g.fillStyle = d.col; g.fillRect(-s * 0.6, -6, s * 1.2, 6);
    g.fillStyle = shade(d.col, 30); g.fillRect(-s * 0.6, -6, s * 1.2, 1);
    g.fillStyle = d.col; g.fillRect(s * 0.6, -8, 3, 3);
    g.fillStyle = '#101010'; g.fillRect(-1, -8, 1, 2); g.fillRect(2, -8, 1, 2);
  } else if (d.shape === 'blob') {
    const wob = Math.sin(t * 4) * 1.5;
    g.fillStyle = shade(d.col, -30); g.beginPath(); g.ellipse(0, -3, s * 0.9 + wob, s * 0.5 - wob * 0.3, 0, 0, 7); g.fill();
    g.fillStyle = d.col; g.beginPath(); g.ellipse(0, -4, s * 0.75 + wob, s * 0.4 - wob * 0.3, 0, 0, 7); g.fill();
    g.fillStyle = 'rgba(255,255,255,0.5)'; g.fillRect(-3, -7, 2, 1);
    g.fillStyle = '#101010'; g.fillRect(s * 0.4, -6, 1, 1); g.fillRect(s * 0.4 - 3, -6, 1, 1);
  }
  g.restore();
};

export const faunaHere = () => { const id = faunaId(); return id === 'earth' ? GAME1.map((k) => D.animals[k]) : Object.values(FAUNA[id] || {}); };

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { eco, stepEco, FAUNA });
