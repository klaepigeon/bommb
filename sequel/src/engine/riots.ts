// Riots. Every few days, somewhere on Earth, people have had enough: a crowd with pipes and
// napalm cans against a line of Peacekeepers, hover cars burning in the street, and every
// shop door kicked in. While it lasts (two hours) the shelves are free for anyone. Pick a side
// if you like: put down rioters and the Peacekeepers wipe your local sheet; put down
// Peacekeepers and the crowd carries you on its shoulders (and the Empire notices).

import { SQ, saveSequel, cityRect } from './state';
import { EARTH } from './earth';
import { SPACE } from './space';

const TS = R.TILE;
interface Riot { city: string; name: string; x: number; y: number; until: number; crowd: any[]; line: any[]; looted: Record<number, number>; killsCrowd: number; killsLine: number }
export const RIOT = { cur: null as Riot | null, count: 0 };
const CHANTS = ['NO MORE TITHES!', 'FEAR IS A LIE!', 'WE ARE NOT CATTLE!', 'BREAD NOT BATONS!', 'BURN IT DOWN!', 'WHOSE STREETS?'];
const pick = <T>(a: T[]) => a[Math.floor(Math.random() * a.length)];
const today = (g: Game) => Math.floor(g.clock.t / 1440);

export function startRiot(g: Game): Riot | null {
  const pl = g.player, w = g.world, tx = (pl.x / TS) | 0, ty = (pl.y / TS) | 0;
  const city = cityRect(w, tx, ty);
  if (!city) return null;
  const free = (x: number, y: number) => !w.solidPed(x, y) && !w.isWater(x, y);
  const at = w.findNear(tx, ty, 6, 12, free) || w.findNear(tx, ty, 3, 16, free);
  if (!at) return null;
  const r: Riot = { city: city.id, name: city.name, x: at.x * TS + 8, y: at.y * TS + 8, until: g.clock.t + 120, crowd: [], line: [], looted: {}, killsCrowd: 0, killsLine: 0 };
  for (let k = 0; k < 9; k++) {
    const s = w.findNear(at.x, at.y, 0, 4, free); if (!s) continue;
    const a = g.actors.makeHuman(s.x * TS + 8, s.y * TS + 8, { arch: 'tough', tag: 'rioter', weapon: pick(['bat', 'bat', 'knife', 'crowbar', 'fists', 'molotov']), cash: 10 });
    if (!a) continue;
    a.keep = true; a.rioter = true; a.strangerName = 'Rioter'; a.tr.brave = 0.95; a.hostileLocked = false;
    r.crowd.push(a);
  }
  const ang = Math.random() * 7, lx = at.x + Math.round(Math.cos(ang) * 10), ly = at.y + Math.round(Math.sin(ang) * 10);
  for (let k = 0; k < 6; k++) {
    const s = w.findNear(lx, ly, 0, 4, free) || w.findNear(at.x, at.y, 6, 12, free); if (!s) continue;
    const c = g.actors.makeHuman(s.x * TS + 8, s.y * TS + 8, { cop: true, role: 'cop', city: city.id, tag: 'riotcop' });
    if (!c) continue;
    g.actors.arm(c, pick(['revolver', 'shotgun', 'bat']));
    c.keep = true; c.riotCop = true; c.strangerName = 'Peacekeeper';
    r.line.push(c);
  }
  // the cars go up
  let burned = 0;
  for (const v of g.traffic.list) { if (burned >= 2) break; if (!v.removed && !v.wrecked && v !== pl.inCar && Math.hypot(v.x - r.x, v.y - r.y) < TS * 14) { v.burning = 0.01; burned++; } }
  RIOT.cur = r; RIOT.count++;
  SQ.flags.riotNext = today(g) + 3 + Math.floor(Math.random() * 4); saveSequel();
  g.ui.banner('RIOT', `${city.name} is burning. The shops are open to anyone. Pick a side, or pick the shelves.`);
  g.audio.sfx('alarm');
  g.waypoint = { x: r.x, y: r.y };
  return r;
}
function endRiot(g: Game, r: Riot): void {
  RIOT.cur = null;
  const pl = g.player;
  for (const a of r.crowd.concat(r.line)) if (a && !a.dead && !a.removed) { a.keep = false; if (a.state === 'fight' && a.target !== pl) { a.state = 'idle'; a.target = null; } }
  g.pop.addNews(r.city, `NIGHT OF FIRE IN ${r.name.toUpperCase()}. ${r.killsCrowd + 3 + Math.floor(Math.random() * 9)} dead, ${40 + Math.floor(Math.random() * 90)} arrested. The Syndicate blames "outside agitators" and raises the tithe.`);
  if (r.killsCrowd >= 3) {
    const jur = g.law.jurAt(pl.x, pl.y); g.law.bounty[jur] = 0; pl.cash += 300;
    g.ui.story('Commendation', `A Peacekeeper captain finds you in the smoke and shakes your hand. "Citizen. We saw what you did." Your sheet in ${r.name} is wiped clean, and there's 300 credits for your trouble.\n\nThe crowd saw it too.`);
    pl.rep.honor = (pl.rep.honor || 0) - 3;
  } else if (r.killsLine >= 3) {
    pl.rep.infamy = (pl.rep.infamy || 0) + 5; pl.rep.honor = (pl.rep.honor || 0) + 3; SQ.heat.empire += 10;
    SQ.flags.riotHero = (SQ.flags.riotHero || 0) + 1;
    g.ui.story('The Crowd', `When the Peacekeeper line breaks, the crowd picks you up and carries you down the middle of the street, chanting a name that isn't quite yours.\n\nBy morning your face is spray-painted on three walls in ${r.name}. The Empire has seen them too.`);
  } else g.ui.toast(`The riot in ${r.name} burns itself out. Smoke and broken glass till morning.`);
  saveSequel();
}
// keep them at each other's throats
function pair(g: Game, r: Riot): void {
  const alive = (q: any) => q && !q.dead && !q.removed && !(q.down > 0);
  const crowd = r.crowd.filter(alive), line = r.line.filter(alive);
  for (const a of crowd) if (a.state !== 'fight' || !a.target || a.target.dead) { const t = line.sort((p, q) => Math.hypot(p.x - a.x, p.y - a.y) - Math.hypot(q.x - a.x, q.y - a.y))[0]; if (t) g.actors.setFight(a, t); }
  for (const c of line) if (c.state !== 'fight' || !c.target || c.target.dead) { const t = crowd.sort((p, q) => Math.hypot(p.x - c.x, p.y - c.y) - Math.hypot(q.x - c.x, q.y - c.y))[0]; if (t) g.actors.setFight(c, t); }
  if (Math.random() < 0.25 && crowd.length) g.actors.say(pick(crowd), pick(CHANTS));
}

let t = 0;
const GP = R.Game.prototype, tick = GP.tick;
GP.tick = function (this: Game, dt: number) {
  const res = tick.call(this, dt);
  if (!this.player || !this.world || this.ui.paused() || SPACE.active) return res;
  t -= dt;
  if (t > 0) return res;
  t = 1;
  const r = RIOT.cur;
  if (r) {
    if (!EARTH.active || this.clock.t > r.until || (!r.crowd.some((a) => !a.dead) || !r.line.some((c) => !c.dead))) endRiot(this, r);
    else pair(this, r);
    return res;
  }
  if (!EARTH.active || this.player.room) return res;
  const h = this.clock.hour(), day = today(this);
  if (SQ.flags.riotNext == null) { SQ.flags.riotNext = day + 2 + Math.floor(Math.random() * 3); saveSequel(); }
  if (day >= SQ.flags.riotNext && h >= 11 && h < 22 && Math.random() < 0.02) startRiot(this);
  return res;
};
// who you put down
const C = R.combat as any, kill = C.kill;
C.kill = function (h: any, source: any, kind: string) {
  const was = h && h.dead, res = kill.apply(this, arguments);
  const r = RIOT.cur;
  if (r && !was && h && h.dead && source === R.game.player) { if (h.rioter) r.killsCrowd++; else if (h.riotCop) r.killsLine++; }
  return res;
};
// the shelves
const U = R.UI.prototype as any, io = U.interiorOptions;
const SHOPS = new Set(['general', 'liquor', 'pharmacy', 'pawn', 'gunshop', 'tailor', 'diner', 'bar', 'barber', 'costume', 'arcade', 'laundry']);
U.interiorOptions = function (b: any) {
  const o = io.call(this, b), g = this.game, r = RIOT.cur;
  if (r && SHOPS.has(b.type) && b.cityId === r.city && !r.looted[b.id]) o.push({ label: 'Loot the shelves', small: 'The riot: the owner\'s long gone, and so are the Peacekeepers', fn: () => {
    r.looted[b.id] = 1;
    const n = 40 + Math.floor(Math.random() * 160);
    g.player.cash += n; g.audio.sfx('cash');
    if (b.type === 'gunshop') { g.player.inv.ammo.pistol = (g.player.inv.ammo.pistol || 0) + 24; g.ui.toast(`${n} credits from the till and two boxes of blaster cells.`, 'good'); }
    else g.ui.toast(`Arms full: ${n} credits' worth. Nobody even looks at you.`, 'good');
  } });
  return o;
};

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { RIOT, startRiot: () => startRiot(R.game), endRiot: () => RIOT.cur && endRiot(R.game, RIOT.cur) });
