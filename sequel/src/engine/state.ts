// The sequel's own persistent state: the campaign seed, which planet you're on, your ship,
// cargo and Imperial heat, and whether you're on the ground or in space. Everything about a
// planet itself lives in game 1's save, one per planet.

import type { PlanetId, BodyId } from './planets';
import { starterShip, type Ship } from '../ship/ship';

export type Good = 'rum' | 'tea' | 'ore' | 'meds' | 'vinyl' | 'blasters' | 'ice' | 'plat' | 'pearls' | 'xeno';
export interface CargoLot { good: Good; n: number; stolen: boolean; hidden: boolean }

export interface Sequel {
  v: number;
  seed: number;
  planet: PlanetId;
  mode: 'planet' | 'space';
  arriving: boolean;
  ship: Ship;
  hull: number; // -1 = full
  cargo: CargoLot[];
  heat: { empire: number; families: number };
  space: { x: number; y: number; a: number } | null;
  visited: PlanetId[];
  portable: Record<string, unknown> | null; // the player, carried between planets
  minutes: number; // system clock for orbits when no planet is loaded
  course: BodyId | null; // where the flight computer is steering in cruise
  system: string; // 'sol' or a generated star system's id (where your ship is)
  home: string; // the system of the world that's loaded (where your feet last touched ground)
  fuel: number; // jump fuel on board (refills when you land)
  bounty: number; // the Imperial bounty on your head, system-wide
  flags: Record<string, number>; // story beats: first contact, the Choir, court dates
  eco: Record<string, Record<string, number>>; // wildlife populations per world (eco.ts)
  known: string[]; // star systems the jump drive has charts for
  sector: [number, number]; // on Earth: the sector you're standing in (earth.ts)
  shipAt: [number, number]; // on Earth: the sector your ship is parked in
  arriveEdge: { edge: 'n' | 's' | 'e' | 'w'; f: number } | null; // crossing a sector border on foot
}
// the Brass Coast's place on the planet (earth.ts)
export const HOME_SECTOR: [number, number] = [12, 10];
const homeSector = (s: [number, number] | undefined) => !s || (s[0] === HOME_SECTOR[0] && s[1] === HOME_SECTOR[1]);

const KEY = 'bs.sequel';

export function fresh(): Sequel {
  return {
    v: 2, seed: (Math.random() * 1e9) | 0, planet: 'earth', mode: 'planet', arriving: true,
    ship: starterShip('Brass Buzzard'), hull: -1, cargo: [], heat: { empire: 0, families: 0 }, space: null, visited: ['earth'], portable: null, minutes: 0, course: null,
    system: 'sol', home: 'sol', fuel: 0, bounty: 0, flags: { clamp: 1 }, eco: {}, known: ['sol'],
    sector: [HOME_SECTOR[0], HOME_SECTOR[1]], shipAt: [HOME_SECTOR[0], HOME_SECTOR[1]], arriveEdge: null,
  };
}

export const SQ: Sequel = (() => {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) { const s = JSON.parse(raw) as Sequel; if (s && s.v === 2) return Object.assign(fresh(), s); }
  } catch { /* storage blocked: play without it */ }
  return fresh();
})();

export function saveSequel(): void {
  try { localStorage.setItem(KEY, JSON.stringify(SQ)); } catch { /* storage blocked */ }
}
export function resetSequel(): void {
  const f = fresh();
  for (const k of Object.keys(SQ) as (keyof Sequel)[]) (SQ as unknown as Record<string, unknown>)[k] = (f as unknown as Record<string, unknown>)[k];
  try { for (const k of Object.keys(localStorage)) if (k.startsWith('bs.planet.')) localStorage.removeItem(k); } catch { /* storage blocked */ }
  saveSequel();
}

// a world's save and seed are per system (Sol's keys keep their original names)
const worldId = (p: PlanetId) => {
  const sec = p === 'earth' && SQ.home === 'sol' && !homeSector(SQ.sector) ? '@' + SQ.sector[0] + ',' + SQ.sector[1] : '';
  return (SQ.home === 'sol' ? p : SQ.home + '.' + p) + sec;
};
export const planetKey = (p: PlanetId) => 'bs.planet.' + worldId(p);
export function planetSeed(p: PlanetId): number {
  let h = SQ.seed >>> 0;
  const id = worldId(p);
  for (let i = 0; i < id.length; i++) h = Math.imul(h ^ id.charCodeAt(i), 16777619) >>> 0;
  return h % 1000000000;
}
