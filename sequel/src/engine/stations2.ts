// The Empire, the rebels, and you.
//   Imperial Customs Platform (over Venus): dock and they scan you. Stolen cargo in the open
//   hold is seized with a fine. Pay your bounty off here (at a markup), buy a trade licence
//   (customs on the Imperial worlds wave you through), or grease an inspector.
//   Free Ganymede Shipyard (over Ganymede): the rebels' drydock. They fence anything, sell a
//   clean transponder (your heat gone, your bounty halved), refit your ship on the spot, and
//   they're the only yard that fits a Cloaking Field. They sell the frame for an orbital base.
//   The Imperial Star Dreadnought: a capital ship on patrol round Venus. It ignores small fry,
//   until your heat or your bounty is high enough to be worth its time.
//   Your bases: buy a base frame, fly anywhere near a world, and build (from "Where to?"). A
//   base is a station of your own: a free refuel and repair, a stash for cargo, a drydock
//   (refit, and capital hulls at a discount), rent from the hab ring every day, and turrets
//   that shoot anything hostile that comes near.

import { SQ, saveSequel, type Base, type Good } from './state';
import { BODY, PLANETS } from './planets';
import { SPACE, HOOKS, spawnCraft, fire, craftR, type Craft } from './space';
import { STATIONS, EXTRA, DOCK, stationPos, type Station } from './stations';
import { REFIT, openWatch } from './watch';
import { price, used } from './cargo';
import { fmt } from './bounty';
import { stats } from '../ship/ship';

const today = () => Math.floor((R.game && R.game.clock ? R.game.clock.t : SQ.minutes) / 1440);
const cash = (g: Game, n: number) => { if (g.player.cash < n) { g.ui.toast(`That's ${fmt(n)}. You have ${fmt(g.player.cash)}.`, 'warn'); return false; } g.player.cash -= n; g.audio.sfx('cash'); return true; };
const openCargo = () => SQ.cargo.filter((l) => !l.hidden);

// ---------------------------------------------------------------- Imperial customs
DOCK.customs = (g, st) => {
  const hot = openCargo().filter((l) => l.stolen);
  if (hot.length && !SQ.flags.licence) {
    const n = hot.reduce((a, l) => a + l.n, 0), fine = Math.min(g.player.cash, 100 + n * 40);
    SQ.cargo = SQ.cargo.filter((l) => !(l.stolen && !l.hidden));
    g.player.cash -= fine; SQ.heat.empire += 10; saveSequel();
    g.ui.story(st.name, `The scanner arch lights up red. ${n} crates of stolen cargo, seized, and a ${fmt(fine)} fine for the paperwork.\n\n(A smuggler's hold hides cargo from the scan. So does a trade licence.)`);
    return;
  }
  const pay = Math.round(SQ.bounty * 1.25);
  g.ui.choice(`${st.name} · papers, please`, [
    { label: SQ.bounty ? `Pay off your bounty (${fmt(pay)})` : 'No bounty on file', small: SQ.bounty ? 'The court\'s price plus the Empire\'s markup. Hunters stand down.' : 'Clean as a whistle', fn: () => { if (!SQ.bounty || !cash(g, pay)) return; SQ.bounty = 0; SQ.heat.empire = 0; saveSequel(); g.ui.toast('Bounty cleared. The Empire thanks you for your business.', 'good'); } },
    { label: SQ.flags.licence ? 'Trade licence: yours' : `Buy a trade licence (${fmt(6000)})`, small: 'Customs on Imperial worlds (and here) wave you through', fn: () => { if (SQ.flags.licence || !cash(g, 6000)) return; SQ.flags.licence = 1; saveSequel(); g.ui.toast('Licensed. Your cargo is now officially none of their business.', 'good'); } },
    { label: `Grease an inspector (${fmt(500)})`, small: `Imperial heat ${Math.round(SQ.heat.empire)} → 0`, fn: () => { if (!SQ.heat.empire || !cash(g, 500)) return; SQ.heat.empire = 0; saveSequel(); g.ui.toast('He pockets it without looking up. You were never here.', 'good'); } },
    { label: 'Undock', fn: () => {} },
  ]);
};

// ---------------------------------------------------------------- the rebels' yard
DOCK.rebel = (g, st) => {
  const stolen = SQ.cargo.filter((l) => l.stolen), n = stolen.reduce((a, l) => a + l.n, 0);
  const worth = stolen.reduce((a, l) => a + Math.round(price('luna', l.good) * 1.1) * l.n, 0);
  g.ui.choice(`${st.name} · no questions`, [
    { label: `Fence stolen cargo (${n})`, small: n ? `${fmt(worth)} for the lot` : 'Nothing hot aboard', fn: () => { if (!n) return; SQ.cargo = SQ.cargo.filter((l) => !l.stolen); g.player.cash += worth; g.audio.sfx('cash'); saveSequel(); g.ui.toast(`+${fmt(worth)}. "For the cause," says the quartermaster, and winks.`, 'good'); } },
    { label: `A clean transponder (${fmt(2500)})`, small: `Heat → 0, bounty ${fmt(SQ.bounty)} → ${fmt(Math.round(SQ.bounty / 2))}`, fn: () => { if (!cash(g, 2500)) return; SQ.heat.empire = 0; SQ.bounty = Math.round(SQ.bounty / 2); saveSequel(); g.ui.toast('New codes, new name on the registry. The Empire loses half your file.', 'good'); } },
    { label: 'Refit in the drydock', small: 'Modules, hulls, repairs. The only yard that fits a Cloaking Field.', fn: () => { REFIT.yard = 'rebel'; openWatch(g, 'ship'); } },
    { label: SQ.flags.baseKit ? 'Base frame: in your hold' : `Buy an orbital base frame (${fmt(40000)})`, small: 'Fly near any world, then build it from "Where to?"', fn: () => { if (SQ.flags.baseKit || !cash(g, 40000)) return; SQ.flags.baseKit = 1; saveSequel(); g.ui.toast('The frame is folded into your hold. Fly near a world and build it from "Where to?" (USE).', 'good'); } },
    { label: 'Undock', fn: () => {} },
  ]);
};
// the yard's refit only lasts while the sheet's open
HOOKS.update.push((g) => { if (REFIT.yard && !g.ui.sheetOpen) REFIT.yard = ''; });

// ---------------------------------------------------------------- the dreadnought over Venus
let dreadT = 5;
HOOKS.update.push((g, dt) => {
  if (SQ.system !== 'sol') return;
  dreadT -= dt;
  if (dreadT > 0) return;
  dreadT = 3;
  const venus = SPACE.B.find((b) => b.id === 'venus');
  if (!venus) return;
  let d = SPACE.crafts.find((c) => c.kind === 'capital' && !c.dead);
  const near = Math.hypot(SPACE.x - venus.x, SPACE.y - venus.y) < 25000;
  if (!d && near && !SQ.flags.dreadDead) {
    d = spawnCraft('capital', false, 2500);
    d.name = 'ISD Castra Invicta'; d.target = 'venus';
    const a = Math.random() * 7; d.x = venus.x + Math.cos(a) * (venus.r + 900); d.y = venus.y + Math.sin(a) * (venus.r + 900);
  }
  const wreck = SPACE.crafts.find((c) => c.kind === 'capital' && c.dead && c.name === 'ISD Castra Invicta');
  if (wreck && !SQ.flags.dreadDead) {
    SQ.flags.dreadDead = 1; SQ.bounty += 5000; g.player.cash += 20000; saveSequel();
    g.ui.story('The Castra Invicta', 'The dreadnought comes apart over Venus in a chain of white flashes you can see from the cloud cities. Salvage worth 20,000 credits drifts into your scoops before the Empire can stop you.\n\nThey will never forgive this. (+$5,000 on your head.)');
  }
  if (d && !d.hostile && (SQ.heat.empire >= 60 || SQ.bounty >= 3000) && Math.hypot(d.x - SPACE.x, d.y - SPACE.y) < 3000) {
    d.hostile = true;
    g.ui.toast(`${d.name.toUpperCase()}: "Wanted vessel. You will be reduced to your component atoms."`, 'bad');
    g.audio.sfx('alarm');
  }
});

// ---------------------------------------------------------------- your bases
const baseStation = (b: Base): Station => ({ id: b.id, name: b.name, parent: b.parent, alt: b.alt, hours: b.hours, kind: 'base', col: '#68f0a0', blurb: 'Yours.' });
EXTRA.push(() => (SQ.bases || []).filter((b) => b.sys === SQ.system).map(baseStation));
const RENT = [0, 150, 400, 900];
function accrue(): void {
  const now = today();
  for (const b of SQ.bases || []) { const days = Math.min(365, now - b.day); if (days > 0) { b.bank += days * RENT[b.level]; b.day = now; } }
}
export function buildBase(g: Game): boolean {
  const G = SPACE.g;
  if (!SQ.flags.baseKit) return false;
  if (!G || G.near.id === 'sun' || G.alt > 3000) { g.ui.toast('Get within 3,000 of a world to build a base in its orbit.', 'warn'); return false; }
  const near = G.near, alt = Math.max(150, Math.round(Math.hypot(SPACE.x - near.x, SPACE.y - near.y) - near.r));
  SQ.bases = SQ.bases || [];
  const b: Base = { id: 'base' + (SQ.bases.length + 1) + '-' + near.id, sys: SQ.system, parent: near.id, alt, hours: 6 + SQ.bases.length, name: `${g.player.last || 'Free'} Station ${['I', 'II', 'III', 'IV', 'V'][SQ.bases.length] || SQ.bases.length + 1}`, level: 1, stash: [], turrets: 1, day: today(), bank: 0 };
  SQ.bases.push(b);
  SQ.flags.baseKit = 0; saveSequel();
  g.audio.sfx('promote');
  g.ui.story(b.name, `The frame unfolds in ${BODY[near.id].name}'s orbit like a paper lantern: a docking ring, a hab module, one turret, and your name on the airlock.\n\nDock with USE. It refuels and repairs you free, keeps your cargo, rents out bunks, and the turret shoots anything that comes at you. Build it up from the dock.`);
  return true;
}
DOCK.base = (g, st) => {
  accrue();
  const b = (SQ.bases || []).find((x) => x.id === st.id);
  if (!b) return;
  const my = stats(SQ.ship);
  SQ.hull = my.hull; SQ.fuel = Math.max(SQ.fuel, my.fuel); SPACE.shield = my.shield;
  const stashN = b.stash.reduce((a, l) => a + l.n, 0);
  const up = (label: string, cost: number, small: string, fn: () => void) => ({ label: `${label} · ${fmt(cost)}`, small, fn: () => { if (!cash(g, cost)) return; fn(); saveSequel(); DOCK.base(g, st); } });
  const opts = [
    { label: `Collect rent (${fmt(b.bank)})`, small: `${fmt(RENT[b.level])} a day from the hab ring`, fn: () => { if (!b.bank) return; g.player.cash += b.bank; b.bank = 0; g.audio.sfx('cash'); saveSequel(); DOCK.base(g, st); } },
    { label: `Stash your cargo (${used().open + used().hidden} aboard)`, small: `${stashN} in the stash. Safe from customs and pirates.`, fn: () => { for (const l of SQ.cargo) { const s = b.stash.find((x) => x.good === l.good && x.stolen === l.stolen); if (s) s.n += l.n; else b.stash.push({ ...l, hidden: false }); } SQ.cargo = []; saveSequel(); DOCK.base(g, st); } },
    { label: `Load the stash (${stashN})`, small: 'As much as the hold takes', fn: () => { const room = () => my.cargo + my.hidden - (used().open + used().hidden); for (const s of b.stash) { const k = Math.min(s.n, room()); if (k <= 0) break; const lot = SQ.cargo.find((l) => l.good === s.good && l.stolen === s.stolen && !l.hidden); if (lot) lot.n += k; else SQ.cargo.push({ good: s.good as Good, n: k, stolen: s.stolen, hidden: false }); s.n -= k; } b.stash = b.stash.filter((s) => s.n > 0); saveSequel(); DOCK.base(g, st); } },
    { label: 'Drydock', small: b.level >= 3 ? 'Refit, and capital hulls at 30% off' : 'Refit and repair', fn: () => { REFIT.yard = 'base'; openWatch(g, 'ship'); } },
  ];
  if (b.level < 3) opts.push(up(`Expand to level ${b.level + 1}`, [0, 25000, 60000][b.level], `Rent ${fmt(RENT[b.level + 1])} a day${b.level + 1 === 3 ? ', and a capital drydock' : ''}`, () => { b.level++; }));
  if (b.turrets < 4) opts.push(up(`Mount a turret (${b.turrets + 1}/4)`, 8000, 'Shoots anything hostile within 900', () => { b.turrets++; }));
  opts.push({ label: 'Undock', small: '', fn: () => {} });
  g.ui.choice(`${b.name} · level ${b.level} · over ${BODY[b.parent] ? BODY[b.parent].name : b.parent}`, opts);
};
// the turrets
let turretT = 0;
HOOKS.update.push((g, dt) => {
  turretT -= dt;
  if (turretT > 0) return;
  turretT = 0.45;
  for (const b of SQ.bases || []) {
    if (b.sys !== SQ.system) continue;
    const p = stationPos(baseStation(b));
    if (!p || Math.hypot(p.x - SPACE.x, p.y - SPACE.y) > 6000) continue;
    const foes = SPACE.crafts.filter((c: Craft) => !c.dead && !c.disabled && c.hostile && Math.hypot(c.x - p.x, c.y - p.y) < 900 + craftR(c));
    for (let k = 0; k < Math.min(b.turrets, foes.length); k++) { const c = foes[k]; fire(p.x, p.y, Math.atan2(c.y - p.y, c.x - p.x), p.vx / 60, p.vy / 60, 'me', 8, 1); }
  }
});
// build from the nav menu
HOOKS.navExtra.push((g) => (SQ.flags.baseKit ? { label: 'Build your base here', small: SPACE.g && SPACE.g.near.id !== 'sun' && SPACE.g.alt < 3000 ? `In orbit over ${BODY[SPACE.g.near.id].name}` : 'Get within 3,000 of a world first', fn: () => { buildBase(g); } } : null));

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { buildBase, STATIONS, PLANETS });
