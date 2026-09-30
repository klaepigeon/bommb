// Passengers. Every pad has people who need to be somewhere else and don't ask why your ship
// smells like blaster oil. Take them aboard from the ship's menu (two bunks per set of crew
// quarters, less whoever crews for you, and a jump seat regardless), land where they're going
// before their day is up, and they pay. Not everyone is what they say: a fugitive brings a
// hunter who wants them handed over; a Choir pilgrim leaves you something to think about; a
// quiet one in good shoes tips like a senator, because she is one.

import { SQ, saveSequel, type Fare } from './state';
import { PLANETS, SOL_PLANETS, landable } from './planets';
import { SPACE, HOOKS, spawnCraft } from './space';
import { SHIP_MENU } from './travel';
import { stats } from '../ship/ship';
import { fmt } from './bounty';

const FIRST = ['Dolores', 'Rex', 'Zanna', 'Mickey', 'Oona', 'Tobias', 'Suki', 'Vance', 'Lorna', 'Kip', 'Nadia', 'Ezra', 'Maxine', 'Jojo'];
const LAST = ['Varga', 'Okafor', 'Quill', 'Starling', 'Hex', 'Moreau', 'Tanaka', 'Delacroix', 'Brandt', 'Nkemelu', 'Sato', 'Ruiz'];
const WHO = ['a nervous accountant', 'a Luna trader with too many bags', 'a cyborg dockhand', 'a mutant preacher', 'a retired Imperial clerk', 'a neon punk with a guitar', 'a Choir hybrid, humming', 'a woman in very good shoes', 'a kid with a one-way ticket'];
const today = () => Math.floor((R.game && R.game.clock ? R.game.clock.t : SQ.minutes) / 1440);
const aboard = (): Fare[] => (SQ.fares = SQ.fares || []);
export const berths = () => Math.max(1, stats(SQ.ship).crew - (SQ.crew ? SQ.crew.length : 0));
const h = (a: number, b: number) => { let x = (a * 374761393 + b * 668265263) | 0; x = Math.imul(x ^ (x >>> 13), 1274126177); return ((x ^ (x >>> 16)) >>> 0) / 4294967296; };
const strH = (s: string) => { let x = 7; for (const c of s) x = (x * 31 + c.charCodeAt(0)) | 0; return x; };

// who's waiting at this pad today
export function waiting(world: string): Fare[] {
  const d = today(), worlds = landable().filter((w) => w !== world), out: Fare[] = [];
  if (SQ.system !== 'sol' || !worlds.length) return out;
  for (let k = 0; k < 3; k++) {
    const r = (n: number) => h(d * 53 + strH(world) + k * 1231, n);
    const id = d * 100 + (strH(world) % 40) * 2 + k;
    if (aboard().some((f) => f.id === id) || (SQ.flags['fareTaken' + id])) continue;
    const who = WHO[Math.floor(r(1) * WHO.length)];
    const twist: Fare['twist'] = /Choir/.test(who) ? 'cultist' : /good shoes/.test(who) ? 'vip' : r(2) < 0.22 ? 'fugitive' : 'none';
    const to = worlds[Math.floor(r(3) * worlds.length)];
    out.push({ id, name: `${FIRST[Math.floor(r(4) * FIRST.length)]} ${LAST[Math.floor(r(5) * LAST.length)]}`, who, to, pay: Math.round((250 + r(6) * 450) * (twist === 'fugitive' ? 1.8 : 1) / 10) * 10, due: d + 3, twist });
  }
  return out;
}
export function board(g: Game, f: Fare): boolean {
  if (aboard().length >= berths()) { g.ui.toast(`No bunk free (${berths()} berth${berths() > 1 ? 's' : ''}). Fit more crew quarters.`, 'warn'); return false; }
  aboard().push(f); SQ.flags['fareTaken' + f.id] = 1; saveSequel();
  g.audio.sfx('accept');
  g.ui.toast(`${f.name} stows a bag and straps in. ${SOL_PLANETS[f.to as keyof typeof SOL_PLANETS] ? SOL_PLANETS[f.to as keyof typeof SOL_PLANETS].name : f.to} by day ${f.due + 1}: ${fmt(f.pay)}.${f.twist === 'fugitive' ? ' They pay the fare in advance-worthy cash and won\'t look at the port cameras.' : ''}`, 'good');
  return true;
}
function menu(g: Game): void {
  const here = SQ.planet, list = waiting(here), on = aboard();
  const nm = (w: string) => (PLANETS[w as keyof typeof PLANETS] ? PLANETS[w as keyof typeof PLANETS].name : w);
  g.ui.choice(`Passengers · ${on.length}/${berths()} aboard`, [
    ...list.map((f) => ({ label: `${f.name}, to ${nm(f.to)} · ${fmt(f.pay)}`, small: `${f.who} · by day ${f.due + 1}`, fn: () => { board(g, f); } })),
    ...on.map((f) => ({ label: `Aboard: ${f.name} → ${nm(f.to)}`, small: `${fmt(f.pay)} by day ${f.due + 1} · put them off here`, fn: () => { SQ.fares = aboard().filter((q) => q !== f); saveSequel(); g.ui.toast(`${f.name} takes their bag and goes, muttering.`); } })),
    { label: 'Close', fn: () => {} },
  ]);
}
SHIP_MENU.push((g) => (SQ.system === 'sol' ? { label: `Passengers (${aboard().length}/${berths()})`, small: `${waiting(SQ.planet).length} waiting at the pad`, fn: () => menu(g) } : null));

// arrivals
HOOKS.landed.push((g, id) => {
  const d = today(), off = aboard().filter((f) => f.to === id);
  if (!off.length) return;
  SQ.fares = aboard().filter((f) => f.to !== id);
  let paid = 0; const notes: string[] = [];
  for (const f of off) {
    let pay = d > f.due ? Math.round(f.pay / 2) : f.pay;
    if (f.twist === 'vip') { pay *= 2; notes.push(`${f.name} tips double and leaves a card: Senator ${f.name.split(' ')[1]}. "Discretion is a rare thing."`); SQ.heat.empire = Math.max(0, SQ.heat.empire - 15); }
    if (f.twist === 'cultist') { notes.push(`${f.name} presses a warm little crystal into your hand. "It sings when you're near the Source." (It does hum, a little.)`); SQ.flags.choirTokens = (SQ.flags.choirTokens || 0) + 1; }
    if (f.twist === 'fugitive' && !f.sprung) notes.push(`${f.name} is off the pad and gone before the engines cool.`);
    paid += pay;
  }
  g.player.cash += paid;
  SQ.achieved = SQ.achieved || {}; SQ.achieved.fares = (SQ.achieved.fares || 0) + off.length;
  saveSequel();
  setTimeout(() => g.ui.story('Passengers off', `${off.map((f) => f.name).join(', ')} ${off.length > 1 ? 'are' : 'is'} off at ${PLANETS[id].name}. ${fmt(paid)} in fares${off.some((f) => d > f.due) ? ' (half for the late ones)' : ''}.${notes.length ? '\n\n' + notes.join('\n\n') : ''}`), 600);
});
// the fugitive's hunter finds you in space
let huntT = 0;
HOOKS.update.push((g, dt) => {
  if (!SPACE.active || SPACE.cruise) return;
  const f = aboard().find((q) => q.twist === 'fugitive' && !q.sprung);
  if (!f) return;
  huntT += dt;
  if (huntT < 25) return;
  huntT = 0; f.sprung = true; saveSequel();
  g.ui.choice(`Hunter on the band`, [
    { label: `Hand over ${f.name}`, small: 'The hunter pays 500 finder\'s fee. Honor -3', fn: () => {
      SQ.fares = aboard().filter((q) => q !== f); g.player.cash += 500; g.player.rep.honor = (g.player.rep.honor || 0) - 3; saveSequel();
      g.ui.toast(`A skiff docks, two men in armour take ${f.name} off your ship without a word. 500 credits.`, 'warn');
    } },
    { label: 'Tell them to go to hell', small: 'They\'ll try to take them the hard way', fn: () => {
      for (let k = 0; k < 2; k++) { const c = spawnCraft('hunter', true, 600); c.name = 'Skip Tracer'; }
      g.player.rep.honor = (g.player.rep.honor || 0) + 2;
      g.ui.toast(`"Wrong answer." Two skip tracers light up their drives. ${f.name} is white as a sheet.`, 'bad'); g.audio.sfx('alarm');
    } },
  ]);
});

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { waiting, fares: aboard, boardFare: (f: Fare) => board(R.game, f), berths });
