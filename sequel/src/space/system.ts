// The solar system: a star, planets on circular orbits that move with the in-game clock, and
// hand-painted planet art (Gen 4 shading: banded light, a rim, a soft terminator).

import { PLANETS, type PlanetId } from '../world/planets';
import { Px } from '../gfx/px';
import { rampOf, mix } from '../gfx/pal';
import { hash2 } from '../core/math';

export interface Body { id: PlanetId; x: number; y: number; r: number }

export function bodies(minutes: number): Body[] {
  return (Object.keys(PLANETS) as PlanetId[]).map((id, i) => {
    const d = PLANETS[id];
    const a = i * 2.1 + (minutes / d.period) * Math.PI * 2 * 0.25;
    return { id, x: Math.cos(a) * d.orbit, y: Math.sin(a) * d.orbit, r: d.radius };
  });
}

// smooth value noise (bilinear between hashed lattice points) for continents
function vnoise(x: number, y: number, s: number): number {
  const xi = Math.floor(x), yi = Math.floor(y), fx = x - xi, fy = y - yi;
  const u = fx * fx * (3 - 2 * fx), v = fy * fy * (3 - 2 * fy);
  const a = hash2(xi, yi, s), b = hash2(xi + 1, yi, s), c = hash2(xi, yi + 1, s), d = hash2(xi + 1, yi + 1, s);
  return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}

const art = new Map<string, HTMLCanvasElement>();
export function planetArt(id: PlanetId): HTMLCanvasElement {
  let c = art.get(id);
  if (c) return c;
  const d = PLANETS[id], R = d.radius, p = new Px(R * 2 + 4, R * 2 + 4);
  const base = rampOf(d.color);
  const sea = rampOf(id === 'veridia' ? '#3a7ed0' : id === 'castra' ? '#6a78a8' : '#8a5e48');
  p.oval(R + 2, R + 2, R, R, (nx, ny, x, y) => {
    // continents from layered noise; latitude bands; lit from the upper left
    const n = vnoise(x / 9, y / 9, 7) * 0.6 + vnoise(x / 22, y / 22, 3) * 0.4;
    const land = id === 'hollow' ? true : n > 0.5;
    const l = -nx * 0.55 - ny * 0.55 + (1 - Math.hypot(nx, ny)) * 0.4;
    const r = land ? base : sea;
    let col = l > 0.55 ? r[4] : l > 0.2 ? r[3] : l > -0.25 ? r[2] : l > -0.6 ? r[1] : r[0];
    if (id === 'castra' && land && (x + y) % 6 === 0) col = mix(col, '#fff8d0', 0.5); // city lights and marble
    if (id === 'hollow' && vnoise(x / 4, y / 4, 9) > 0.8) col = r[0]; // craters
    if (id === 'veridia' && Math.abs(ny) > 0.85) col = mix(col, '#ffffff', 0.7); // ice caps
    return col;
  });
  // atmosphere rim
  if (id !== 'hollow') for (let a = 0; a < 360; a += 1) {
    const t = (a * Math.PI) / 180, x = Math.round(R + 2 + Math.cos(t) * (R + 1)), y = Math.round(R + 2 + Math.sin(t) * (R + 1));
    if (!p.has(x, y)) p.set(x, y, Math.cos(t) + Math.sin(t) < 0 ? '#c8ecff' : '#4a6a9a');
  }
  c = p.canvas();
  art.set(id, c);
  return c;
}

let sun: HTMLCanvasElement | null = null;
export function sunArt(): HTMLCanvasElement {
  if (sun) return sun;
  const R = 110, p = new Px(R * 2 + 2, R * 2 + 2);
  p.oval(R + 1, R + 1, R, R, (nx, ny, x, y) => {
    const k = Math.hypot(nx, ny), f = hash2(Math.floor(x / 4), Math.floor(y / 4), 5);
    return k > 0.94 ? '#f8a030' : k > 0.8 ? (f > 0.5 ? '#ffc848' : '#f8b038') : f > 0.8 ? '#fff4c0' : k < 0.5 ? '#fffbe8' : '#ffe890';
  });
  sun = p.canvas();
  return sun;
}
