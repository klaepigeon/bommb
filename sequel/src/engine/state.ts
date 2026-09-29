// The sequel's own persistent state: the campaign seed, which planet you're on, your ship,
// cargo and Imperial heat, and whether you're on the ground or in space. Everything about a
// planet itself lives in game 1's save, one per planet.

import type { PlanetId, BodyId } from './planets';
import { starterShip, type Ship } from '../ship/ship';

export type Good = 'rum' | 'tea' | 'ore' | 'meds' | 'vinyl' | 'blasters';
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
}

const KEY = 'bs.sequel';

export function fresh(): Sequel {
  return {
    v: 2, seed: (Math.random() * 1e9) | 0, planet: 'mars', mode: 'planet', arriving: true,
    ship: starterShip('Brass Buzzard'), hull: -1, cargo: [], heat: { empire: 0, families: 0 }, space: null, visited: ['mars'], portable: null, minutes: 0, course: null,
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

export const planetKey = (p: PlanetId) => 'bs.planet.' + p;
export function planetSeed(p: PlanetId): number {
  let h = SQ.seed >>> 0;
  for (let i = 0; i < p.length; i++) h = Math.imul(h ^ p.charCodeAt(i), 16777619) >>> 0;
  return h % 1000000000;
}
