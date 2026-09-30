// Skimming. Any ship can drop into the cloud tops of a gas giant and scoop hydrogen for the
// jump drive: get low (under a quarter of its radius over the clouds), stay out of cruise,
// and ride it. A jump cell fills every eight seconds. The turbulence strips your shields,
// and once they're gone it starts on the hull. Out past the last station, it's the only
// fuel there is.

import { SQ, saveSequel } from './state';
import { SPACE, HOOKS } from './space';
import { BODY } from './planets';
import { stats } from '../ship/ship';

export const SKIM = { world: null as string | null, fill: 0, told: false };
const PER_CELL = 8;

HOOKS.update.push((g, dt) => {
  SKIM.world = null;
  const G = SPACE.g;
  if (!SPACE.active || SPACE.cruise || SQ.ringFly || !G) return;
  const n = G.near, def = BODY[n.id];
  if (!def || !def.bands) return;
  const alt = Math.hypot(SPACE.x - n.x, SPACE.y - n.y) - n.r;
  if (alt > n.r * 0.25) return;
  SKIM.world = def.name;
  if (!SKIM.told) { SKIM.told = true; g.ui.toast(`Skimming ${def.name}'s cloud tops. The scoops are filling your jump cells; the turbulence is eating your shields. Climb out before it eats the hull.`, 'warn'); }
  // the buffeting
  if (SPACE.shield > 0) SPACE.shield = Math.max(0, SPACE.shield - 12 * dt); else SQ.hull -= 2 * dt;
  if (Math.random() < dt * 10) { const a = Math.random() * 7; SPACE.sparks.push({ x: SPACE.x + Math.cos(a) * 20, y: SPACE.y + Math.sin(a) * 20, vx: SPACE.vx - Math.cos(SPACE.a) * 90, vy: SPACE.vy - Math.sin(SPACE.a) * 90, life: 0.4, col: Math.random() < 0.5 ? '#e8d0a0' : '#c8a878' }); }
  const cap = stats(SQ.ship).fuel;
  if (SQ.fuel >= cap) { SKIM.fill = 0; return; }
  SKIM.fill += dt;
  if (SKIM.fill >= PER_CELL) {
    SKIM.fill = 0; SQ.fuel++; saveSequel();
    g.audio.sfx('equip');
    g.ui.toast(SQ.fuel >= cap ? `Jump cells full (${SQ.fuel}/${cap}). Climb out.` : `Jump cell ${SQ.fuel}/${cap} full.`, 'good');
  }
});
HOOKS.hud.push(() => {
  if (!SKIM.world) return null;
  const cap = stats(SQ.ship).fuel;
  return `SKIMMING ${SKIM.world.toUpperCase()} · FUEL ${SQ.fuel}/${cap}${SQ.fuel < cap ? ' · ' + '#'.repeat(Math.floor((SKIM.fill / PER_CELL) * 8)).padEnd(8, '.') : ' · FULL'}`;
});

(window as any).BS2 = Object.assign((window as any).BS2 || {}, { SKIM });
