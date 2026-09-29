// The Imperial bounty. Game 1's law keeps its per-city bounties on each world; on top of that
// the Empire keeps one number for the whole system, and it follows you everywhere:
//   - Crimes on Imperial worlds (Mars, Venus) add to it, and so does piracy against Imperial
//     ships and shooting down patrols.
//   - Bounty hunters come for it: on the ground as armed crews that track you down, and in
//     space as fast gunships that try to disable you, dock, and board. Fight them off in your
//     own hold, or get dragged to court.
//   - The Imperial Court sits on Venus. Walk up to your ship there to answer the bounty: pay
//     it, plead (a good name helps), or stand trial and serve the sentence in game 1's jail
//     (with game 1's jailbreaks).

import { SQ, saveSequel } from './state';
import { worldProfile, PLANETS } from './planets';
import { SPACE, HOOKS, type Craft } from './space';
import { enterDock } from './board';
import { SHIP_MENU, travelTo } from './travel';
import { blankShip, stats, type Mod } from '../ship/ship';

const TS = R.TILE;
const HUNTERS = ['Kade "Dust" Morrow', 'The Widow Sable', 'Ossian Varga', 'Jet Calloway', 'Silas Frane', 'Marguerite Vex', 'Two-Moons Okoro', 'Lucky Petrov'];
const rnd = () => Math.random();
const pick = <T>(a: T[]) => a[Math.floor(rnd() * a.length)];
export const fmt = (n: number) => '$' + Math.round(n).toLocaleString();

// ---------------------------------------------------------------- crimes on Imperial worlds
let lastLaw = -1, lawT = 0, groundT = 90, hunted: any[] = [];
const lawSum = (g: Game) => Object.values((g.law && g.law.bounty) || {}).reduce((s: number, v) => s + (Number(v) || 0), 0);
const GP = R.Game.prototype, baseSetup = GP.setup, baseTick = GP.tick;
GP.setup = function (this: Game, seed: number, save: unknown) {
  const r = baseSetup.call(this, seed, save);
  lastLaw = -1; hunted = []; groundT = 90 + rnd() * 60;
  return r;
};
GP.tick = function (this: Game, dt: number) {
  const r = baseTick.call(this, dt);
  if (SPACE.active || !this.player || this.ui.paused()) return r;
  lawT -= dt;
  if (lawT <= 0) {
    lawT = 1;
    const sum = lawSum(this);
    if (worldProfile().imperial && lastLaw >= 0 && sum > lastLaw) { SQ.bounty += (sum - lastLaw) * 2; saveSequel(); }
    lastLaw = sum;
  }
  groundHunters(this, dt);
  return r;
};

// ---------------------------------------------------------------- hunters on the ground
function groundHunters(g: Game, dt: number): void {
  hunted = hunted.filter((h) => !h.dead && h.down <= 0 && g.actors.list.includes(h));
  if (SQ.bounty < 300 || hunted.length || g.player.room || g.cutscene) return;
  groundT -= dt;
  if (groundT > 0) return;
  groundT = 150 + rnd() * 120 - Math.min(90, SQ.bounty / 50);
  const pl = g.player, w = g.world, tx = (pl.x / TS) | 0, ty = (pl.y / TS) | 0;
  const s = w.findNear(tx, ty, 16, 26, (x: number, y: number) => !w.solidPed(x, y) && !w.isWater(x, y));
  if (!s) return;
  const n = SQ.bounty > 1500 ? 3 : 2, name = pick(HUNTERS);
  for (let k = 0; k < n; k++) {
    const h = g.actors.makeHuman(s.x * TS + 8 + k * 10, s.y * TS + 8, { weapon: pick(['rifle', 'magnum', 'shotgun', 'carbine']), arch: 'tough', tag: 'hunter', cash: 60 + Math.floor(rnd() * 140) });
    if (!h) continue;
    h.hostile = true; h.hostileLocked = true; h.tr.brave = 0.9;
    h.strangerName = k ? `${name.split(' ')[0]}'s gun` : 'Bounty Hunter ' + name;
    h.look.uniform = { shirt: ['#3a2410', '#5a3a1a', '#7a5228', '#a07038'], pants: ['#141418', '#24242e', '#383846', '#50505e'], style: 'cap', cap: ['#1a1410', '#2a2018', '#3a2e22', '#4a3c2c'] };
    h.look.old = null;
    g.actors.setFight(h, pl);
    hunted.push(h);
  }
  g.ui.toast(`${name} is here for the ${fmt(SQ.bounty)} on your head.`, 'bad');
  g.audio.sfx('alarm');
}

// ---------------------------------------------------------------- hunters in space
function hunterShip() {
  const s = blankShip('cutter', 'Hunter'), W = 7;
  const set = (x: number, y: number, m: Mod) => { s.grid[y * W + x] = m; };
  set(6, 1, 'cockpit'); set(6, 2, 'gun'); set(5, 1, 'gun'); set(0, 1, 'engine'); set(0, 2, 'engine'); set(1, 1, 'engine');
  set(1, 2, 'reactor'); set(2, 1, 'reactor'); set(3, 1, 'shield'); set(3, 2, 'armor'); set(2, 2, 'tube'); set(4, 2, 'quarters');
  s.paint = '#2a2a34';
  return s;
}
let spaceT = 40, boardedT = 0;
HOOKS.update.push((g, dt) => {
  boardedT -= dt;
  if (SQ.bounty >= 300 && !SPACE.cruise && !SPACE.crafts.some((c) => c.kind === 'hunter' && !c.dead)) {
    spaceT -= dt;
    if (spaceT <= 0) {
      spaceT = 100 + rnd() * 80;
      const sh = hunterShip(), st = stats(sh), a = rnd() * Math.PI * 2;
      const c: Craft = {
        id: SPACE.nextId++, kind: 'hunter', ship: sh, flag: 'hunter', x: SPACE.x + Math.cos(a) * 700, y: SPACE.y + Math.sin(a) * 700, vx: SPACE.vx, vy: SPACE.vy, a: a + Math.PI,
        hull: st.hull * 1.3, maxHull: st.hull * 1.3, shield: st.shield, maxShield: st.shield, disabled: false, looted: false, dead: false, target: Object.keys(PLANETS)[0], cool: 2, hostile: true, name: pick(HUNTERS), cargo: [],
      };
      SPACE.crafts.push(c);
      g.ui.toast(`BOUNTY HUNTER ${c.name.toUpperCase()}: "${fmt(SQ.bounty)}, dead or breathing. I prefer breathing."`, 'bad');
      g.audio.sfx('alarm');
    }
  }
  // a hunter that gets you low docks and boards
  const my = stats(SQ.ship);
  if (boardedT <= 0 && SQ.hull < my.hull * 0.3) {
    const c = SPACE.crafts.find((k) => k.kind === 'hunter' && !k.dead && Math.hypot(k.x - SPACE.x, k.y - SPACE.y) < 200);
    if (c) { boardedT = 60; boarded(g, c); }
  }
});
HOOKS.hud.push(() => (SQ.bounty > 0 ? `IMPERIAL BOUNTY ${fmt(SQ.bounty)}` : null));

function boarded(g: Game, c: Craft): void {
  const crew: any[] = [];
  enterDock(g, 'warehouse', 'Your hold · boarders!', 'breakin', (g2) => {
    const alive = crew.filter((h) => !h.dead && h.down <= 0);
    if (alive.length) { capture(g2, c.name); return; }
    c.dead = true;
    const prize = 300 + Math.floor(rnd() * 400);
    g2.player.cash += prize;
    g2.ui.story('Boarders Repelled', `You clear your own hold, space what's left, and take ${c.name}'s ship strongbox: ${fmt(prize)}.\n\nTheir gunship drifts off, dead in space. Someone will come looking for them. Someone always does.`);
  });
  g.ui.banner('BOARDED', `${c.name}'s crew is in your hold`);
  g.ui.toast('Clear the hold. If you walk out with them still standing, you go to court.', 'bad');
  const room = g.player.room, w = g.world;
  const floor: { x: number; y: number }[] = [];
  for (let y = room.y0 + 2; y < room.y0 + room.h - 3; y++) for (let x = room.x0 + 1; x < room.x0 + room.w - 1; x++) if (!w.solidPed(x, y)) floor.push({ x, y });
  for (let k = 0; k < 3 && floor.length; k++) {
    const s = floor.splice(Math.floor(rnd() * floor.length), 1)[0];
    const h = g.interiors.spawnAt(room, null, s, { weapon: pick(['magnum', 'shotgun', 'carbine']), arch: 'tough', tag: 'hunter' });
    if (!h) continue;
    h.hostile = true; h.hostileLocked = true; h.tr.brave = 0.9; h.strangerName = k ? 'Hunter' : c.name;
    g.actors.setFight(h, g.player);
    crew.push(h);
  }
}

// ---------------------------------------------------------------- the court
export function capture(g: Game, by: string): void {
  SPACE.active = false; SPACE.cruise = false; SQ.mode = 'planet'; SQ.space = null; SQ.course = null;
  const go = () => {
    if (SQ.planet !== 'venus' || SQ.home !== 'sol') travelTo(g, 'venus');
    trial(g, `${by} drags you in front of the Imperial Court in chains.`);
  };
  if (SQ.system !== 'sol') { const gx = (window as any).BS2 && (window as any).BS2.enterSystem; if (gx) gx('sol'); }
  go();
}
function trial(g: Game, opening: string): void {
  const days = Math.max(1, Math.min(7, Math.round(SQ.bounty / 500)));
  const pl = g.player;
  g.ui.story('The Imperial Court', `${opening}\n\nThe charge sheet runs to ${Math.max(3, Math.round(SQ.bounty / 80))} pages. A Saurian magistrate reads all of it, slowly, without blinking.\n\nSentence: ${days} day${days > 1 ? 's' : ''} in the Ashfall quarries.`, () => {
    SQ.bounty = 0; saveSequel();
    const jur = g.law.jurAt(pl.x, pl.y);
    R.slammer.book(jur, days);
  });
}
SHIP_MENU.push((g) => {
  if (SQ.home !== 'sol' || SQ.planet !== 'venus' || SQ.bounty <= 0) return null;
  return { label: `Imperial Court · ${fmt(SQ.bounty)} bounty`, small: 'Answer for it: pay, plead, or stand trial', fn: () => court(g) };
});
function court(g: Game): void {
  const pl = g.player, honor = (pl.rep && pl.rep.honor) || 0;
  g.ui.choice(`Imperial Court · ${fmt(SQ.bounty)}`, [
    { label: `Pay it (${fmt(SQ.bounty)})`, small: pl.cash >= SQ.bounty ? 'Walk out clean' : 'You can\'t cover it', fn: () => {
      if (pl.cash < SQ.bounty) return g.ui.toast('The clerk looks at your purse, then at you.', 'warn');
      pl.cash -= SQ.bounty; SQ.bounty = 0; SQ.heat.empire = 0; saveSequel();
      g.ui.story('The Imperial Court', 'The clerk stamps your file three times and slides it into a drawer marked RESOLVED. The Empire\'s memory is long, but its paperwork is shorter.');
    } },
    { label: 'Plead your case', small: honor >= 20 ? 'Your good name might carry weight' : 'Your name precedes you', fn: () => {
      if (honor >= 20 && !SQ.flags.pleaded) { SQ.flags.pleaded = 1; SQ.bounty = Math.round(SQ.bounty / 2); saveSequel(); g.ui.story('The Imperial Court', `Character witnesses. A clean record on three worlds. The magistrate halves it: ${fmt(SQ.bounty)}.`); }
      else { SQ.bounty = Math.round(SQ.bounty * 1.1); saveSequel(); g.ui.story('The Imperial Court', `The magistrate adds ten percent for wasting the court's time. It's ${fmt(SQ.bounty)} now.`); }
    } },
    { label: 'Stand trial', small: 'Serve the time, keep your money', fn: () => trial(g, 'You surrender your weapons at the door.') },
    { label: 'Walk away', fn: () => {} },
  ]);
}

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { huntersNow: () => { groundT = 0; spaceT = 0; }, hunted: () => hunted, capture });
