// The tithe barge. Once a week, give or take, the Empire's tithe goes out: a slab-sided
// barge full of every credit the Syndicate "collected" on Earth, bound for Castra Prime,
// armoured three times over. A cantina rat will sell you its schedule. Shoot it and it calls
// its escort (two patrols, out of nowhere); cripple it and dock with your boarding tube to
// crack the vault. It's the biggest payday in the system, and the biggest bounty.

import { SQ, saveSequel } from './state';
import { SPACE, HOOKS, spawnCraft, type Craft } from './space';
import { stats } from '../ship/ship';
import { fmt } from './bounty';

export const TITHE = { barge: null as Craft | null, next: 300, tipped: false, escorts: false, hits: 0 };

export function spawnBarge(g: Game): Craft {
  const c = spawnCraft('freighter', false, 1400);
  c.name = 'Tithe Barge ' + ['Aquila', 'Dominus', 'Tribute', 'Obsequy'][Math.floor(Math.random() * 4)];
  c.flag = 'empire';
  c.maxHull = c.hull = c.maxHull * 3; c.maxShield = c.shield = c.maxShield * 2;
  c.cargo = [];
  (c as any).tithe = true; (c as any).noHail = true;
  TITHE.barge = c; TITHE.escorts = false;
  g.ui.toast(`${c.name} on the scanner: the Empire's tithe, outbound for Castra Prime. Armoured like a vault, because it is one.`, 'warn');
  return c;
}
function crack(g: Game, c: Craft): void {
  if (!stats(SQ.ship).tube) return g.ui.toast('You need a Boarding Tube to get into the vault.', 'bad');
  c.looted = true;
  const take = 4000 + Math.floor(Math.random() * 11) * 500;
  g.player.cash += take;
  SQ.bounty += 2500; SQ.heat.empire += 40;
  g.player.rep.infamy = (g.player.rep.infamy || 0) + 10;
  TITHE.hits++;
  SQ.achieved = SQ.achieved || {}; SQ.achieved.tithes = (SQ.achieved.tithes || 0) + 1;
  saveSequel();
  g.audio.sfx('cash');
  g.ui.story('The Tithe', `The tube seals, the vault door takes a thermal lance for four long minutes, and then it's just shelves. Shelves and shelves of credit chits in Syndicate wrap, the Fear Man's seal on every bundle.\n\nYou take ${fmt(take)} before the patrols' drives are close enough to hear.\n\nThe Empire puts ${fmt(2500)} more on your head. Worth it.`);
}

HOOKS.use.push((g) => {
  const c = TITHE.barge;
  if (!c || c.dead || c.looted || !c.disabled || Math.hypot(c.x - SPACE.x, c.y - SPACE.y) > 90) return null;
  return { label: 'Crack the vault', fn: () => crack(g, c) };
});
HOOKS.update.push((g, dt) => {
  if (!SPACE.active) return;
  const c = TITHE.barge;
  if (c && (c.dead || Math.hypot(c.x - SPACE.x, c.y - SPACE.y) > 25000)) { if (c.dead && !c.looted) g.ui.toast('The tithe barge breaks up. Every credit aboard burns.', 'bad'); TITHE.barge = null; }
  if (c && !c.dead && c.hostile && !TITHE.escorts) {
    TITHE.escorts = true;
    for (let k = 0; k < 2; k++) { const p = spawnCraft('patrol', true, 700); p.name = 'Tithe Escort'; }
    SQ.heat.empire += 10;
    g.ui.toast(`${c.name}: "Tithe under attack!" Two patrols drop out of cruise.`, 'bad'); g.audio.sfx('alarm');
  }
  if (TITHE.barge || SPACE.cruise || SPACE.auto || SQ.system !== 'sol') return;
  TITHE.next -= dt;
  if (TITHE.next <= 0) {
    TITHE.next = 420 + Math.random() * 300;
    if (TITHE.tipped || Math.random() < 0.2) { TITHE.tipped = false; spawnBarge(g); }
  }
});
HOOKS.draw.push((v) => {
  const c = TITHE.barge;
  if (!c || c.dead) return;
  v.mark(c.x, c.y, c.looted ? '#8a8a9a' : '#e4a92a', c.looted ? 'EMPTY BARGE' : c.disabled ? 'VAULT' : 'TITHE');
  const x = v.sx(c.x), y = v.sy(c.y);
  if (x > -40 && y > -40 && x < v.W + 40 && y < v.H + 40) { v.g.strokeStyle = 'rgba(228,169,42,0.5)'; v.g.strokeRect(Math.round(x) - 16, Math.round(y) - 12, 32, 24); }
});
// the schedule, from a cantina rat
const U = R.UI.prototype as any, io = U.interiorOptions;
U.interiorOptions = function (b: any) {
  const o = io.call(this, b), g = this.game;
  if (b.type === 'bar' && SQ.system === 'sol' && !TITHE.tipped && !TITHE.barge) o.push({ label: 'Buy the tithe schedule', price: '150', small: 'A clerk from the Syndicate Lounge drinks here. The next barge, and when', fn: () => {
    if (g.player.cash < 150) return g.ui.toast('150 credits.', 'warn');
    g.player.cash -= 150; TITHE.tipped = true; TITHE.next = Math.min(TITHE.next, 20);
    g.ui.toast('A napkin with a time on it. The next tithe barge will cross your path soon after you\'re back in space. It won\'t blow up easy, and it has friends.', 'good');
  } });
  return o;
};

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { TITHE, spawnBarge: () => spawnBarge(R.game) });
