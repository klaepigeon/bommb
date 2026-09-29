// Crew. Anyone you can talk to can be asked aboard (aliens most willingly): a signing fee,
// a bunk (quarters sleep two, cryo pods four), and their trade works for you in space.
//   Pilot: the ship turns and pushes harder.     Gunner: every bolt hits harder.
//   Engineer: more shield and hull.              Navigator: more jump fuel, longer jumps.
//   Medic: patches you up between fights (on the ground and aboard).
// The roster is under the ship editor (Menu > Ship); let people go there.

import { SQ, saveSequel, type CrewMember } from './state';
import { SPECIES } from './aliens';
import { STAT_HOOKS, stats } from '../ship/ship';
import { SHIP_TAB_EXTRA } from './watch';
import { fmt } from './bounty';

type Role = CrewMember['role'];
const ROLE_BY_SPECIES: Record<string, Role> = { robot: 'engineer', cyborg: 'gunner', grey: 'navigator', choir: 'medic', martian: 'pilot', belter: 'engineer', android: 'pilot', saurian: 'gunner', mutant: 'gunner' };
const ROLES: Role[] = ['pilot', 'gunner', 'engineer', 'navigator', 'medic'];
const WHAT: Record<Role, string> = { pilot: 'turn and thrust +12%', gunner: 'bolts +3 damage', engineer: 'shield +20, hull +40', navigator: 'jump fuel +2, jump range +3 ly', medic: 'heals you between fights' };
export const crew = (): CrewMember[] => (SQ.crew = SQ.crew || []);
const count = (r: Role) => crew().filter((c) => c.role === r).length;

// the crew's trades, on your ship only
STAT_HOOKS.push((st, s) => {
  if (s !== SQ.ship || !SQ.crew || !SQ.crew.length) return;
  const k = (r: Role) => Math.min(3, count(r));
  st.thrust *= 1 + 0.12 * k('pilot'); st.turn *= 1 + 0.12 * k('pilot');
  st.dmg += 3 * k('gunner');
  st.shield += 20 * k('engineer'); st.hull += 40 * k('engineer');
  st.fuel += 2 * k('navigator');
});

const roleFor = (h: any): Role => {
  const x = h.look && h.look.xeno;
  if (x && ROLE_BY_SPECIES[x]) return ROLE_BY_SPECIES[x];
  return ROLES[(h.person ? h.person.id : 0) % ROLES.length];
};
const fee = (h: any) => 600 + (h.person ? (h.person.age % 7) * 100 : 300);

function recruit(g: Game, h: any): void {
  const room = stats(SQ.ship).crew;
  if (crew().length >= room) return g.ui.toast(`No bunk free (${crew().length}/${room}). Fit Crew Quarters or Cryo Pods.`, 'warn');
  const cost = fee(h);
  if (g.player.cash < cost) return g.ui.toast(`They want ${fmt(cost)} to sign on.`, 'warn');
  g.player.cash -= cost;
  const name = h.person ? g.pop.name(h.person) : h.strangerName || 'Stranger';
  const sp = h.look && h.look.xeno ? SPECIES[h.look.xeno] : null;
  crew().push({ name, species: sp ? sp.name : 'Human', role: roleFor(h), wage: 0, seed: (h.person && h.person.seed) || 1 });
  if (h.person) h.person.jailed = g.pop.day + 100000; // off-world, with you
  g.actors.remove(h);
  saveSequel();
  g.ui.closeSheet();
  g.audio.sfx('accept');
  g.ui.toast(`${name} signs on as your ${roleFor(h)} (${WHAT[roleFor(h)]}).`, 'good');
}

// "Join my crew?" in anyone's talk menu
const tree = R.dialog.tree;
R.dialog.tree = function (h: any) {
  const t = tree.call(this, h);
  if (t && t.options && h && !h.hostile && h.person && !h.person.isDon && h.person.role !== 'cop' && h.person.age >= 18) {
    const role = roleFor(h);
    t.options.splice(Math.max(0, t.options.length - 1), 0, { label: '"Want to fly with me?"', small: `${role} · ${WHAT[role]} · ${fmt(fee(h))} to sign`, fn: () => recruit(R.game, h) });
  }
  return t;
};

// the medic: a slow heal on the ground, and hull patching in space
let healT = 0;
const GP = R.Game.prototype, baseTick = GP.tick;
GP.tick = function (this: Game, dt: number) {
  const r = baseTick.call(this, dt);
  if (!SQ.crew || !count('medic')) return r;
  healT -= dt;
  if (healT <= 0) {
    healT = 2;
    const pl = this.player;
    if (pl && !pl.dead && pl.hp < pl.maxHp && (!this.law || !this.law.incident)) pl.hp = Math.min(pl.maxHp, pl.hp + count('medic'));
  }
  return r;
};

// the roster
SHIP_TAB_EXTRA.push((g, body) => {
  const room = stats(SQ.ship).crew, list = crew();
  const div = document.createElement('div');
  div.innerHTML = `<div class="sect">Crew · ${list.length}/${room} bunks</div>` + (list.length
    ? list.map((c, i) => `<p class="sw-info"><b>${c.name}</b> · ${c.species} ${c.role} (${WHAT[c.role]}) <button data-fire="${i}">Let go</button></p>`).join('')
    : '<p class="sw-info">Nobody yet. Talk to people (aliens especially) and ask them to fly with you. Quarters sleep two, Cryo Pods four.</p>');
  body.appendChild(div);
  div.querySelectorAll<HTMLElement>('[data-fire]').forEach((b) => b.addEventListener('click', (e) => {
    e.stopPropagation();
    const c = list[+(b.dataset.fire as string)];
    list.splice(+(b.dataset.fire as string), 1); saveSequel();
    g.ui.toast(`${c.name} takes their bag and goes.`);
    g.ui.openMenuTab('ship', document.querySelector('.sheet') as HTMLElement);
  }));
});

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { crew, recruit });
