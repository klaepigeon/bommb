// Contracts. Every pad has a board: cargo runs (legal freight to another world by a deadline)
// and smuggling runs (contraband in the hold, double the pay, and customs to dodge). The
// Imperial customs platform posts bounties: named pirates hiding near a world. Take a job,
// the cargo loads straight into your hold; land at the destination with it and get paid
// (half if you're late). Sell it or lose it and the job's gone. Kill a wanted pirate and the
// Empire wires the reward.

import { SQ, saveSequel, type Contract, type Good } from './state';
import { SOL_PLANETS, BODY } from './planets';
import { SPACE, HOOKS, spawnCraft } from './space';
import { SHIP_MENU } from './travel';
import { DOCK } from './stations';
import { addCargo, GOODS } from './cargo';
import { fmt } from './bounty';

const today = () => Math.floor((R.game && R.game.clock ? R.game.clock.t : SQ.minutes) / 1440);
const list = (): Contract[] => (SQ.contracts = SQ.contracts || []);
const open = () => list().filter((c) => !c.done);
const h = (a: number, b: number) => { let x = (a * 374761393 + b * 668265263) | 0; x = Math.imul(x ^ (x >>> 13), 1274126177); return ((x ^ (x >>> 16)) >>> 0) / 4294967296; };
const strH = (s: string) => { let x = 7; for (const c of s) x = (x * 31 + c.charCodeAt(0)) | 0; return x; };
const LEGAL: Good[] = ['rum', 'tea', 'meds', 'vinyl', 'ice', 'ore'], HOT: Good[] = ['blasters', 'xeno'];
const PIRATES = ['"Red" Varga', 'The Lamplighter', 'Captain Scald', 'Mother Hex', 'Jet Morrow', 'the Kessler Twins', 'Dead-Eye Oona', 'Baron Klaxon'];
const auBetween = (a: string, b: string) => Math.abs(((BODY[a] && BODY[a].au) || 1) - ((BODY[b] && BODY[b].au) || 1)) || 0.3;

// the offers on a world's board today: the same for anyone who looks
export function offers(world: string): Contract[] {
  const d = today(), worlds = Object.keys(SOL_PLANETS).filter((w) => w !== world), out: Contract[] = [];
  if (!worlds.length || SQ.system !== 'sol') return out;
  for (let k = 0; k < 4; k++) {
    const r = (n: number) => h(d * 31 + strH(world) + k * 977, n);
    const smuggle = r(1) < 0.3, to = worlds[Math.floor(r(2) * worlds.length)];
    const good = smuggle ? HOT[Math.floor(r(3) * HOT.length)] : LEGAL[Math.floor(r(3) * LEGAL.length)], n = 3 + Math.floor(r(4) * 6);
    const pay = Math.round((500 + auBetween(world, to) * 900 + n * 60) * (smuggle ? 2.5 : 1) / 10) * 10;
    const id = d * 100 + strH(world) % 50 * 2 + k;
    if (list().some((c) => c.id === id)) continue;
    out.push({ id, kind: smuggle ? 'smuggle' : 'cargo', from: world, to, good, n, pay, due: d + 2 + Math.floor(auBetween(world, to) * 1.5), name: `${n} ${GOODS[good].name} to ${SOL_PLANETS[to].name}` });
  }
  return out;
}
function take(g: Game, c: Contract): void {
  if (c.kind !== 'bounty') {
    const before = new Map(SQ.cargo.map((l) => [l, l.n]));
    const put = addCargo(c.good!, c.n!, c.kind === 'smuggle');
    // split what just loaded into lots of its own, tagged with the job
    const fresh: typeof SQ.cargo = [];
    for (const l of SQ.cargo) { const d = l.n - (before.get(l) || 0); if (l.good === c.good && d > 0) { l.n -= d; fresh.push({ good: l.good, n: d, stolen: l.stolen, hidden: l.hidden, job: c.id }); } }
    SQ.cargo = SQ.cargo.filter((l) => l.n > 0);
    if (put < c.n!) { saveSequel(); return g.ui.toast(`No room: that's ${c.n} units. Clear some space in the holds.`, 'warn'); }
    SQ.cargo.push(...fresh);
  }
  list().push(c); saveSequel();
  g.audio.sfx('accept');
  g.ui.toast(c.kind === 'bounty' ? `Contract: ${c.name}. They're near ${BODY[c.to] ? BODY[c.to].name : c.to}.` : `Loaded. Deliver to ${SOL_PLANETS[c.to].name} by day ${c.due + 1} for ${fmt(c.pay)}.`, 'good');
}
function board(g: Game): void {
  const here = SQ.planet, mine = open();
  const opts = offers(here).map((c) => ({ label: `${c.kind === 'smuggle' ? 'SMUGGLE: ' : ''}${c.name} · ${fmt(c.pay)}`, small: `Due by day ${c.due + 1}${c.kind === 'smuggle' ? ' · contraband: customs will look' : ''}`, fn: () => take(g, c) }));
  if (mine.length) opts.push({ label: `Your contracts (${mine.length})`, small: mine.map((c) => c.name).join(' · '), fn: () => g.ui.choice('Your contracts', mine.map((c) => ({ label: c.name, small: `${fmt(c.pay)} · due day ${c.due + 1}`, fn: () => {} })).concat([{ label: 'Close', small: '', fn: () => {} }])) });
  if (!opts.length) return g.ui.toast('Nothing on the board today.');
  g.ui.choice(`Contracts board · ${SOL_PLANETS[here] ? SOL_PLANETS[here].name : here}`, opts);
}
SHIP_MENU.push((g) => (SQ.system === 'sol' && SOL_PLANETS[SQ.planet] ? { label: 'Contracts board', small: `Cargo and smuggling runs from ${SOL_PLANETS[SQ.planet].name}`, fn: () => board(g) } : null));

// deliveries: land with the goods
HOOKS.landed.push((g, id) => {
  const d = today();
  for (const c of open()) {
    if (c.kind === 'bounty') continue;
    const lot = SQ.cargo.filter((l) => l.job === c.id).reduce((a, l) => a + l.n, 0);
    if (lot < (c.n || 0)) { c.done = true; g.ui.toast(`Contract failed: ${c.name}. The goods are gone.`, 'bad'); continue; }
    if (id !== c.to) { if (d > c.due + 3) { c.done = true; for (const l of SQ.cargo) if (l.job === c.id) l.job = undefined; g.ui.toast(`Contract expired: ${c.name}. The cargo's yours now, for what it's worth.`, 'warn'); } continue; }
    SQ.cargo = SQ.cargo.filter((l) => l.job !== c.id);
    const pay = d > c.due ? Math.round(c.pay / 2) : c.pay;
    g.player.cash += pay; c.done = true;
    SQ.achieved = SQ.achieved || {}; SQ.achieved.deliveries = (SQ.achieved.deliveries || 0) + 1;
    setTimeout(() => g.ui.toast(`Delivered: ${c.name}. ${fmt(pay)}${d > c.due ? ' (late: half pay)' : ''}.`, 'good'), 600);
    g.audio.sfx('cash');
  }
  saveSequel();
});

// ---------------------------------------------------------------- bounties from the customs platform
function bounties(): Contract[] {
  const d = today(), worlds = ['mars', 'ceres', 'luna', 'venus', 'io', 'callisto', 'titan'];
  const out: Contract[] = [];
  for (let k = 0; k < 3; k++) {
    const r = (n: number) => h(Math.floor(d / 2) * 17 + k * 311, n);
    const id = 900000 + Math.floor(d / 2) * 10 + k;
    if (list().some((c) => c.id === id)) continue;
    const to = worlds[Math.floor(r(1) * worlds.length)], target = PIRATES[Math.floor(r(2) * PIRATES.length)];
    out.push({ id, kind: 'bounty', from: 'customs', to, target, pay: Math.round((3000 + r(3) * 6000) / 100) * 100, due: d + 6, name: `Wanted: ${target}` });
  }
  return out;
}
const baseCustoms = DOCK.customs;
DOCK.customs = (g, st) => {
  baseCustoms(g, st);
  // add the bounty board to the platform's menu
  const sheet = document.querySelector('.sheet');
  if (!sheet || !/papers, please/.test(sheet.textContent || '')) return;
  const b = bounties();
  const opts = b.map((c) => ({ label: `${c.name} · ${fmt(c.pay)}`, small: `Last seen near ${BODY[c.to] ? BODY[c.to].name : c.to}. Dead, not alive.`, fn: () => take(g, c) }));
  if (!opts.length) return;
  const btn = document.createElement('button');
  btn.className = 'opt'; btn.innerHTML = `Bounty board (${b.length})<small>Pirates the Empire wants dead</small>`;
  btn.addEventListener('click', () => g.ui.choice('Imperial bounty board', opts));
  const optsEl = sheet.querySelector('.opts'); if (optsEl) optsEl.insertBefore(btn, optsEl.firstChild);
};
// the targets turn up when you get near their world
let huntT = 0;
HOOKS.update.push((g, dt) => {
  huntT -= dt;
  if (huntT > 0 || SQ.system !== 'sol') return;
  huntT = 2;
  for (const c of open()) {
    if (c.kind !== 'bounty') continue;
    const w = SPACE.B.find((b) => b.id === c.to);
    const ship = SPACE.crafts.find((k) => (k as any).wanted === c.id);
    if (ship && ship.dead) {
      c.done = true; g.player.cash += c.pay; saveSequel();
      SQ.achieved = SQ.achieved || {}; SQ.achieved.bounties = (SQ.achieved.bounties || 0) + 1;
      g.ui.story('Bounty collected', `${c.target} is scrap and vapour. The Empire wires ${fmt(c.pay)} before the wreck stops glowing.`);
      continue;
    }
    if (!ship && w && Math.hypot(SPACE.x - w.x, SPACE.y - w.y) < w.r + 4000 && !SPACE.cruise) {
      const k = spawnCraft('hunter', true, 700);
      (k as any).wanted = c.id; k.name = c.target!; k.hull *= 1.6; k.maxHull *= 1.6;
      g.ui.toast(`${c.target!.toUpperCase()}: "You're a long way from anywhere, friend. Let's make it permanent."`, 'bad');
      g.audio.sfx('alarm');
    }
  }
});
HOOKS.hud.push(() => { const b = open().filter((c) => c.kind === 'bounty'); return b.length ? `HUNTING ${b.map((c) => c.target!.toUpperCase()).join(', ')}` : null; });

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { offers, contracts: list, takeContract: (c: Contract) => take(R.game, c), bounties });
