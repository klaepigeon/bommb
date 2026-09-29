// Cargo: your holds, what goods are worth on each planet, and what customs will take.

import { SQ, type Good } from './state';
import { stats } from '../ship/ship';
import { PLANETS, type PlanetId } from './planets';

export const GOODS: Record<Good, { name: string; base: number; contraband?: boolean }> = {
  rum: { name: 'Synth-Rum', base: 40 },
  tea: { name: 'Spice Tea', base: 25 },
  ore: { name: 'Raw Ore', base: 15 },
  meds: { name: 'Medkits', base: 60 },
  vinyl: { name: 'Holo-Vinyl', base: 35 },
  blasters: { name: 'Blasters', base: 120, contraband: true },
};
const PRICES: Record<PlanetId, Record<Good, number>> = {
  mars: { rum: 1.35, tea: 0.7, ore: 1.5, meds: 1.1, vinyl: 0.8, blasters: 1.2 },
  venus: { rum: 1.1, tea: 1.2, ore: 1.2, meds: 0.8, vinyl: 1.4, blasters: 1.6 },
  luna: { rum: 0.8, tea: 1.4, ore: 0.6, meds: 1.6, vinyl: 1.3, blasters: 1.8 },
  earth: { rum: 1.0, tea: 1.1, ore: 1.3, meds: 1.3, vinyl: 1.6, blasters: 1.4 },
};
export const price = (p: PlanetId, g: Good) => Math.round(GOODS[g].base * PRICES[p][g]);
// the black market pays full price for stolen goods; legit exchanges won't touch them
export const blackMarket = (p: PlanetId) => PLANETS[p].black;

export function used(): { open: number; hidden: number } {
  let open = 0, hidden = 0;
  for (const l of SQ.cargo) if (l.hidden) hidden += l.n; else open += l.n;
  return { open, hidden };
}

// stolen goods go into the smuggler's hold first
export function addCargo(good: Good, n: number, stolen: boolean): number {
  const s = stats(SQ.ship), u = used();
  let left = n, put = 0;
  const into = (hidden: boolean, room: number) => {
    const k = Math.min(left, room);
    if (k <= 0) return;
    const lot = SQ.cargo.find((l) => l.good === good && l.stolen === stolen && l.hidden === hidden);
    if (lot) lot.n += k; else SQ.cargo.push({ good, n: k, stolen, hidden });
    left -= k; put += k;
  };
  if (stolen) { into(true, s.hidden - u.hidden); into(false, s.cargo - u.open); }
  else { into(false, s.cargo - u.open); into(true, s.hidden - u.hidden); }
  return put;
}
