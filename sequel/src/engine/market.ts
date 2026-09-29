// A living market. Every day a few worlds have news that moves prices: an ice shortage on
// Mars, a blaster crackdown on Venus, a pearl craze in the cloud cities. The news runs in the
// morning paper, on the pirate radio, and at the top of the Cargo tab; the price moves for a
// few days and then drifts back. Buy where it's cheap, fly it to where the news is.

import { SQ } from './state';
import { GOODS, PRICE_MODS } from './cargo';
import { SOL_PLANETS } from './planets';
import type { Good } from './state';

export interface Event { day: number; world: string; good: Good; k: number; text: string }
const today = () => Math.floor((R.game && R.game.clock ? R.game.clock.t : SQ.minutes) / 1440);
const h = (a: number, b: number) => { let x = (a * 374761393 + b * 668265263) | 0; x = Math.imul(x ^ (x >>> 13), 1274126177); return ((x ^ (x >>> 16)) >>> 0) / 4294967296; };
const UP = ['shortage', 'craze', 'blockade', 'strike at the docks', 'festival week'];
const DOWN = ['glut', 'crackdown', 'crash', 'flood of cheap imports', 'recall'];

// the news for one day, the same for every save (the day and the save's seed decide it)
export function eventsOn(day: number): Event[] {
  const worlds = Object.keys(SOL_PLANETS), goods = Object.keys(GOODS) as Good[], out: Event[] = [];
  const seed = (SQ.seed || 1) % 100000;
  for (let k = 0; k < 2; k++) {
    const r = (n: number) => h(day * 7 + k * 131 + seed, n);
    const world = worlds[Math.floor(r(1) * worlds.length)], good = goods[Math.floor(r(2) * goods.length)], up = r(3) < 0.55;
    const name = SOL_PLANETS[world].name, gn = GOODS[good].name;
    const k2 = up ? 1.5 + r(4) * 0.8 : 0.45 + r(4) * 0.25;
    out.push({ day, world, good, k: k2, text: up ? `${gn} ${UP[Math.floor(r(5) * UP.length)]} on ${name}: prices up ${Math.round((k2 - 1) * 100)}%.` : `${gn} ${DOWN[Math.floor(r(5) * DOWN.length)]} on ${name}: prices down ${Math.round((1 - k2) * 100)}%.` });
  }
  return out;
}
// news lasts three days, fading
export function activeEvents(): (Event & { left: number })[] {
  const d = today(), out: (Event & { left: number })[] = [];
  for (let back = 0; back < 3; back++) for (const e of eventsOn(d - back)) out.push({ ...e, left: 3 - back });
  return out;
}
PRICE_MODS.push((p, g) => {
  let k = 1;
  for (const e of activeEvents()) if (e.world === p && e.good === g) k *= 1 + (e.k - 1) * (e.left / 3);
  return k;
});
export const headlines = () => eventsOn(today()).map((e) => e.text);

// into the morning paper
let lastDay = -1;
const GP = R.Game.prototype, baseTick = GP.tick;
GP.tick = function (this: Game, dt: number) {
  const r = baseTick.call(this, dt);
  const d = today();
  if (d !== lastDay && this.pop && this.world && this.world.cities && this.world.cities[0]) {
    if (lastDay >= 0) for (const t of headlines()) this.pop.addNews(this.world.cities[0].id, 'MARKETS: ' + t);
    lastDay = d;
  }
  return r;
};

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { activeEvents, headlines });
