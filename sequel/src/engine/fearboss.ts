// The Fear Man runs Earth. Game 1's gaunt magenta alien came down from his dead tree and
// took the whole underworld, and ten years on he's old and his mind is going: he forgets
// names, repeats himself, and fights like an old man (low health, slow, easily rattled).
// Kill him and you take his yellow ring and the Sinestro Corps uniform off the body.
//
// That's also the only way into the rings now. In XX8X nobody hands out a ring at a dead
// tree: every lantern ring waits until the Fear Man's is on your finger.

import { SQ, saveSequel } from './state';

const CP = (R as any).corps, Ring = (R as any).ring;
const onEarth = () => SQ.planet === 'earth' && SQ.home === 'sol';
export const fearDead = () => !!SQ.flags.fearDead;
const isFearMan = (h: any) => h && h.look && h.look.xeno === 'fearman';

// ---------------------------------------------------------------- the rings, locked away
// no stranger at the dead tree any more: he's in his club, running Earth
Ring.updateFearMan = function () { /* he moved to town */ };
const baseTick = CP.tick;
CP.tick = function (this: unknown) { if (!fearDead()) return; return baseTick.apply(this, arguments); };
let allow = false;
// a ring earned the hard way (Parallax's, off his hand on Mars) comes through regardless
export function giveRingAnyway(col: string, wear = true): void { allow = true; try { CP.give(col, true); if (wear) CP.wear(col, true); } finally { allow = false; } }
const baseGive = CP.give;
CP.give = function (this: unknown, col: string, quiet?: boolean) {
  if (!fearDead() && !allow) {
    R.game.ui.toast('The ring won\'t come to you. Not while the Fear Man rules Earth and wears the first light.', 'warn');
    return;
  }
  return baseGive.call(this, col, quiet);
};

// ---------------------------------------------------------------- an old man now
const SENILE = [
  'Where did I put... ah. On my hand. Of course.',
  'Hal? Is that you, Hal? No. You\'re too short.',
  'I kept order across a thousand worlds. Which one is this?',
  'Fear is... fear is... I had a speech about fear.',
  'Who let you in? Did I let you in? I let everyone in now.',
  'I remember you. You were younger. So was I.',
];
const AP = R.Actors.prototype, baseManage = AP.manage;
AP.manage = function (this: { list: any[] }) {
  const r = baseManage.apply(this, arguments as any);
  if (!onEarth() || fearDead()) return r;
  const g = R.game, pl = g && g.player;
  for (const a of this.list) {
    if (a.kind !== 'h' || a.dead || !isFearMan(a)) continue;
    if (!a.senile) {
      // ninety-odd and frail: a third of a man's health, slow on his feet, slow to shoot
      a.senile = true; a.maxHp = 45; a.hp = Math.min(a.hp, 45);
      if (a.tr) a.tr.brave = 0.35;
      a.speedMul = 0.55;
      a.strangerName = 'The Fear Man';
    }
    if (pl && Math.hypot(a.x - pl.x, a.y - pl.y) < 60 && Math.random() < 0.004) g.actors.say(a, SENILE[Math.floor(Math.random() * SENILE.length)]);
  }
  return r;
};

// ---------------------------------------------------------------- the kill
const C = R.combat, baseKill = C.kill;
C.kill = function (h: any, source: any, kind?: string) {
  const was = !!(h && h.dead);
  const r = baseKill.call(this, h, source, kind);
  if (was || !isFearMan(h) || !onEarth() || fearDead()) return r;
  const g = R.game, pl = g.player;
  SQ.flags.fearDead = 1; saveSequel();
  allow = true;
  try { CP.give('yellow', true); CP.wear('yellow', true); } finally { allow = false; }
  pl.wardrobe = pl.wardrobe || {};
  pl.wardrobe['unlock:fearsuit'] = 1; pl.wardrobe['unlock:scsuit'] = 1; pl.wardrobe['unlock:corpssuit'] = 1;
  pl.will = Math.max(pl.will || 0, 100);
  for (let k = 0; k < 60; k++) g.fx.add({ x: h.x, y: h.y - 10, vx: (Math.random() - 0.5) * 200, vy: (Math.random() - 0.5) * 200, life: 1.2, max: 1.2, c: Math.random() < 0.5 ? '#f0c020' : '#fff27a', s: 2, glow: 1 });
  g.audio.sfx('promote');
  g.pop.addNews('port', 'THE FEAR MAN IS DEAD. The boss of Earth found dead in his own club. The Syndicate is leaderless; the streets are very quiet.');
  setTimeout(() => g.ui.story('The Yellow Ring', 'He goes down easier than a legend should. At the end he looks up at you, and for a second he knows exactly who you are.\n\n"Good," he says. "Someone should be afraid of you."\n\nThe ring slides off his finger as if it had been waiting. You take the Sinestro Corps uniform from the wardrobe in his office: blue and black, yellow at the belt, pressed and ready for ten years.\n\nThe yellow ring is yours, and the other lights of the spectrum can find you now. From the construct menu (USE with nothing around), you can TAKE OFF into space with no ship at all.'), 400);
  return r;
};

// ---------------------------------------------------------------- where he is
// once your ship's free, his club goes on the map
export function markFearMan(g: Game): void {
  if (!onEarth() || fearDead() || !R.poi) return;
  const don = g.pop.people.find((q: any) => q.isDon && q.faction === 'Vane' && q.alive);
  const b = don && don.home != null ? g.world.buildings[don.home] : null;
  if (b) R.poi.add(b.out.x, b.out.y, 'tip', 'The Fear Man', 'Boss of Earth. Old, and wearing the first ring.');
}
