// The Red Pit. In the back room of any Neon Club (on Mars they call it the Red Pit, on Earth
// just the Pit), the house runs fights: three waves, bare-knuckle first, then blades, then
// blasters. Clear a wave and the next comes through the door. Clear all three for the purse,
// and the house doubles it if you did it without a scratch past half your health. Walk out
// mid-fight and you forfeit.

import { SQ, saveSequel } from './state';
import { fmt } from './bounty';

const TS = R.TILE;
interface Fight { wave: number; foes: any[]; room: any; purse: number; low: boolean }
let fight: Fight | null = null;
export const arenaState = () => fight;
const WAVES: { n: number; weapons: string[] }[] = [{ n: 2, weapons: ['fists', 'knuckles'] }, { n: 3, weapons: ['bat', 'knife', 'machete'] }, { n: 3, weapons: ['revolver', 'shotgun', 'chopper'] }];
const NAMES = ['Mad Dog', 'The Butcher', 'Tiny', 'Rust', 'Chrome Jaw', 'Kid Voltage', 'Big Mama', 'Scrapper', 'Iron Mike', 'The Surgeon'];

function spawnWave(g: Game): void {
  const f = fight!, pl = g.player, room = f.room, W = WAVES[f.wave];
  f.foes = [];
  for (let k = 0; k < W.n; k++) {
    const x = (room.x0 + 1 + ((k * 3 + 2) % Math.max(2, room.w - 2))) * TS + 8, y = (room.y0 + 1 + (k % 2)) * TS + 8;
    const h = g.actors.makeHuman(x, y, { weapon: W.weapons[k % W.weapons.length], arch: 'tough', tag: 'pit', cash: 10 });
    if (!h) continue;
    h.room = pl.room; h.hostile = true; h.hostileLocked = true; if (h.tr) h.tr.brave = 1;
    h.strangerName = NAMES[Math.floor(Math.random() * NAMES.length)];
    g.actors.setFight(h, pl);
    f.foes.push(h);
  }
  g.ui.banner(`THE PIT · ROUND ${f.wave + 1}`, W.weapons.includes('revolver') ? 'Blasters. Find cover.' : W.weapons.includes('bat') ? 'Blades and bats.' : 'Bare knuckles.');
  g.audio.sfx('alarm');
}
export function startFight(g: Game): boolean {
  const pl = g.player;
  if (fight) return false;
  if (!pl.room) { g.ui.toast('The Pit is in the back room.'); return false; }
  g.ui.closeSheet();
  fight = { wave: 0, foes: [], room: pl.room, purse: 1500 + (SQ.planet === 'mars' ? 1000 : 0), low: false };
  pl.hp = pl.maxHp;
  spawnWave(g);
  return true;
}
const GP = R.Game.prototype, baseTick = GP.tick;
GP.tick = function (this: Game, dt: number) {
  const r = baseTick.call(this, dt);
  const f = fight;
  if (!f || !this.player) return r;
  const pl = this.player;
  if (pl.dead) { fight = null; return r; }
  if (pl.room !== f.room) { fight = null; this.ui.toast('You walked out of the Pit. Forfeit, and the crowd boos you into the street.', 'bad'); return r; }
  if (pl.hp < pl.maxHp * 0.5) f.low = true;
  if (f.foes.every((h) => h.dead || h.down > 0 || h.state === 'surrender')) {
    f.wave++;
    if (f.wave >= WAVES.length) {
      const pay = f.low ? f.purse : f.purse * 2;
      pl.cash += pay; fight = null; saveSequel();
      SQ.achieved = SQ.achieved || {}; SQ.achieved.pit = (SQ.achieved.pit || 0) + 1;
      this.audio.sfx('cash');
      this.ui.story(SQ.planet === 'mars' ? 'Champion of the Red Pit' : 'Champion of the Pit', `The last one goes down and the room goes insane. The house pays ${fmt(pay)}${f.low ? '' : ' (doubled: you barely got touched)'}, and somebody's already painting your name on the wall.`);
    } else spawnWave(this);
  }
  return r;
};
const U = (R as any).UI.prototype, baseOpts = U.interiorOptions;
U.interiorOptions = function (this: any, b: any) {
  const opts = baseOpts.call(this, b);
  if (b && (b.type === 'club' || b.type === 'casino')) opts.push({ label: SQ.planet === 'mars' ? 'Fight in the Red Pit' : 'Fight in the Pit', small: `Three rounds. Purse ${fmt(1500 + (SQ.planet === 'mars' ? 1000 : 0))}, doubled if you stay healthy.`, fn: () => startFight(this.game) });
  return opts;
};

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { startFight: () => startFight(R.game), arenaState });
