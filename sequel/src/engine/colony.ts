// Frontier worlds and the colonies you found on them. A frontier world (galaxy.ts) is built
// by the same generator as everywhere else, but its towns are small claim camps. Land on
// one, walk up to your ship, and buy a colony charter: the first camp becomes your colony,
// with your name on it. Colonists arrive every day; they pay a tithe into the colony
// treasury whether you're there or not. Come back to collect, build domes (more room), a
// mine (more income) and guns (raiders stay away), and watch the town grow block by block.

import { SQ, saveSequel, type Colony } from './state';
import { systemData, worldProfile, type Profile } from './planets';
import { SHIP_MENU } from './travel';
import { fmt } from './bounty';

const CHARTER = 15000;
const key = () => SQ.home + ':' + SQ.planet;
const today = () => Math.floor((R.game && R.game.clock ? R.game.clock.t : SQ.minutes) / 1440);
export const colonyHere = (): Colony | null => (SQ.colonies && SQ.colonies[key()]) || null;
const cap = (c: Colony) => 150 * c.level * c.level;
const perHead = (c: Colony) => 2 + c.mine * 2;

// ---------------------------------------------------------------- growth, while you're away
export function growColonies(): void {
  const now = today();
  for (const c of Object.values(SQ.colonies || {})) {
    const days = Math.min(365, now - c.day);
    if (days <= 0) continue;
    for (let d = 0; d < days; d++) {
      c.pop = Math.min(cap(c), Math.round(c.pop * 1.06 + 4 + c.level * 2));
      c.bank += c.pop * perHead(c);
      // an undefended colony loses a little to raiders
      if (!c.guns && c.pop > 80 && Math.random() < 0.08) c.bank = Math.round(c.bank * 0.7);
    }
    c.day = now;
  }
}

// your colony's name on the first camp, and you as its boss
function stamp(p: Profile, c: Colony): void {
  if (!p.cities) return;
  const pl = R.game && R.game.player;
  p.cities[0] = Object.assign({}, p.cities[0], { name: c.name, tag: `your colony · ${c.pop} souls`, family: (pl && pl.last) || 'Colonist', don: 'Deputy ' + String(p.cities[0].don).split(' ').slice(-1)[0] });
}
export function stampAll(): void {
  for (const [k, c] of Object.entries(SQ.colonies || {})) {
    const [sys, pid] = k.split(':');
    const p = systemData(sys).planets[pid];
    if (p) stamp(p, c);
  }
}

// ---------------------------------------------------------------- the camps (and your colony) on the ground
const WP = R.World.prototype, basePlan = WP.planCities;
const RW = 4, P = 22 + RW;
WP.planCities = function (this: World, rnd: () => number) {
  basePlan.call(this, rnd);
  const p = R.planet as Profile | undefined;
  if (!p || !p.frontier) return;
  const col = colonyHere();
  for (const c of this.cities) {
    if (c.hamlet) continue;
    // camps are three blocks square; a colony grows a block a side per level
    const n = c.idx === 0 && col ? Math.min(7, 3 + col.level) : 3;
    const nbx = n, nby = n;
    c.nbx = nbx; c.nby = nby;
    c.x0 = c.cx - Math.floor((nbx * P) / 2); c.y0 = c.cy - Math.floor((nby * P) / 2);
    c.x1 = c.x0 + nbx * P + RW - 1; c.y1 = c.y0 + nby * P + RW - 1;
    c.rowY = c.y0 + Math.floor(nby / 2) * P; c.colX = c.x0 + Math.floor(nbx / 2) * P;
  }
};

// ---------------------------------------------------------------- the charter and the ledger
function found(g: Game): void {
  const pl = g.player, p = worldProfile();
  if (pl.cash < CHARTER) return g.ui.toast(`A colony charter costs ${fmt(CHARTER)}. You have ${fmt(pl.cash)}.`, 'warn');
  pl.cash -= CHARTER;
  const c: Colony = { name: `New ${pl.last || 'Hope'}`, founded: today(), day: today(), pop: 12, level: 1, mine: 0, guns: 0, bank: 0 };
  SQ.colonies = SQ.colonies || {};
  SQ.colonies[key()] = c;
  stamp(p, c);
  saveSequel();
  g.audio.sfx('promote');
  g.ui.story(c.name, `You plant a flag, sign the charter with the Claim Marshals, and a dropship full of colonists comes down behind you: twelve families with prefab huts and more hope than sense.\n\n${c.name} is yours. They'll grow, and they'll pay a tithe every day, whether you're here or not. Walk up to your ship to see the colony ledger: collect the treasury, build domes, a mine, and guns.\n\n(The town grows on the ground the next time you land.)`);
}
function ledger(g: Game): void {
  growColonies();
  const c = colonyHere()!, pl = g.player;
  const up = (label: string, cost: number, small: string, fn: () => void) => ({ label: `${label} · ${fmt(cost)}`, small, fn: () => { if (pl.cash < cost) return g.ui.toast(`That's ${fmt(cost)}. You have ${fmt(pl.cash)}.`, 'warn'); pl.cash -= cost; fn(); saveSequel(); g.audio.sfx('equip'); ledger(g); } });
  const opts = [
    { label: `Collect the treasury (${fmt(c.bank)})`, small: `${c.pop} colonists · room for ${cap(c)} · ${fmt(c.pop * perHead(c))} a day`, fn: () => { if (!c.bank) return; pl.cash += c.bank; g.audio.sfx('cash'); g.ui.toast(`+${fmt(c.bank)} from ${c.name}.`, 'good'); c.bank = 0; saveSequel(); ledger(g); } },
  ];
  if (c.level < 5) opts.push(up(`Build domes (level ${c.level + 1})`, 12000 * c.level, `Room for ${150 * (c.level + 1) * (c.level + 1)}. The town grows a block.`, () => { c.level++; }));
  if (c.mine < 3) opts.push(up(`Dig a mine (${c.mine + 1}/3)`, 8000 * (c.mine + 1), 'Each colonist pays 2 more a day.', () => { c.mine++; }));
  if (c.guns < 2) opts.push(up(`Mount guns (${c.guns + 1}/2)`, 6000, 'Raiders stop skimming the treasury.', () => { c.guns++; }));
  opts.push({ label: `Rename ${c.name}`, small: 'Something catchier', fn: () => { const n = window.prompt('Name your colony', c.name); if (n && n.trim()) { c.name = n.trim().slice(0, 24); stamp(worldProfile(), c); saveSequel(); } ledger(g); } });
  opts.push({ label: 'Close the ledger', small: '', fn: () => {} });
  g.ui.choice(`${c.name} · founded day ${c.founded + 1}`, opts);
}
SHIP_MENU.push((g) => {
  const p = worldProfile();
  if (!p.frontier) return null;
  if (colonyHere()) return { label: `Colony ledger: ${colonyHere()!.name}`, small: 'Collect the treasury, build it up', fn: () => ledger(g) };
  return { label: `Found a colony here (${fmt(CHARTER)})`, small: 'A charter, a dropship of colonists, and your name on the map', fn: () => found(g) };
});

// grow on every landing, and keep names stamped on the profiles
const GP = R.Game.prototype, baseSetup = GP.setup;
GP.setup = function (this: Game, seed: number, save: unknown) {
  growColonies();
  stampAll();
  return baseSetup.call(this, seed, save);
};

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { colonyHere, growColonies });
