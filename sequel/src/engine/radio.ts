// Radio Free Luna. A pirate DJ broadcasting from a crater, who has heard about everything you
// have done. In space the station runs along the top of the screen; on the ground the DJ cuts
// in now and then. The patter follows the news: your bounty, your colonies, the Fear Man, the
// Choir, the markets, and the songs (all synth, all the time).

import { SQ } from './state';
import { HOOKS, SPACE } from './space';
import { headlines } from './market';
import { fmt } from './bounty';

const SONGS = ['"Neon Heart (Burning Slow)"', '"Tonight Is What It Means To Be Young"', '"Chrome Boulevard"', '"Light Up the Night"', '"Last Train to Titan"', '"Hot Fuel, Cold Stars"', '"Nowhere Fast"', '"Signal from the Deep"'];
const pick = <T>(a: T[]) => a[Math.floor(Math.random() * a.length)];
export function patter(): string {
  const pl = R.game && R.game.player, name = pl ? (pl.nick || pl.first || 'stranger') : 'stranger', f = SQ.flags;
  const lines: string[] = [
    `That was ${pick(SONGS)}. This is Radio Free Luna, the only station the Empire can't find.`,
    `Coming up: ${pick(SONGS)}. Keep it locked, space cowboys.`,
    ...headlines().map((h) => `Market wire: ${h}`),
  ];
  if (SQ.bounty > 0) lines.push(`Word is the Empire wants ${name} for ${fmt(SQ.bounty)}. We never heard of 'em. This one's for you, ${name}.`);
  if (f.fearDead) lines.push('Earth\'s boss is dead. The Fear Man, gone. Somebody out there has his ring. Somebody out there should be careful.');
  else lines.push('Down on Earth the Fear Man still runs the show. Old man, big ring. Pay your dues, kids.');
  if (SQ.colonies && Object.keys(SQ.colonies).length) lines.push(`Shout out to the good people of ${Object.values(SQ.colonies)[0].name}. Frontier living, baby.`);
  if (f.ending === 1) lines.push('The Choir are singing on every frequency tonight. Can\'t get them off the air. Don\'t want to.');
  if (f.ending === 2) lines.push('Anybody else notice the Choir went quiet? Just... quiet. Spooky.');
  if (f.dreadDead) lines.push('The Castra Invicta, blown to glitter over Venus. We are playing this next one LOUD.');
  if ((SQ.bases || []).length) lines.push(`There's a new station out there flying no flag. ${SQ.bases![0].name}. Respect.`);
  return pick(lines);
}
let t = 20, line = '', lineT = 0;
HOOKS.update.push((g, dt) => {
  t -= dt; lineT -= dt;
  if (t <= 0) { t = 45 + Math.random() * 40; line = patter(); lineT = 14; }
});
HOOKS.hud.push(() => (lineT > 0 && SPACE.active ? `RADIO FREE LUNA · ${line.toUpperCase().slice(0, 90)}` : null));
// on the ground, the DJ cuts in now and then (in a car, more often)
let groundT = 90;
const GP = R.Game.prototype, baseTick = GP.tick;
GP.tick = function (this: Game, dt: number) {
  const r = baseTick.call(this, dt);
  if (SPACE.active || !this.player || this.ui.paused()) return r;
  groundT -= dt * (this.player.inCar ? 3 : 1);
  if (groundT <= 0) { groundT = 150 + Math.random() * 120; this.ui.toast('Radio Free Luna: ' + patter()); }
  return r;
};

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { patter });
