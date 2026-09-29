// Ships are grids of modules. The grid decides everything: stats, the sprite you fly, and the
// interior you (or boarders) walk through. Nose points right (+x); engines belong at the back.

import { Px } from '../gfx/px';
import { ink, rampOf } from '../gfx/pal';

export type Mod = 'cockpit' | 'engine' | 'reactor' | 'fuel' | 'cargo' | 'hold' | 'gun' | 'shield' | 'quarters' | 'med' | 'tube' | 'lounge' | 'battery' | 'armor';

export interface ModDef { name: string; price: number; mass: number; power: number; col: string; blurb: string }
export const MODS: Record<Mod, ModDef> = {
  cockpit: { name: 'Cockpit', price: 0, mass: 2, power: -1, col: '#68b8f0', blurb: 'Where you sit. Every ship needs exactly one.' },
  engine: { name: 'Ion Engine', price: 400, mass: 3, power: -2, col: '#e8742a', blurb: 'Thrust. Fit at the back, facing aft.' },
  reactor: { name: 'Fusion Reactor', price: 600, mass: 4, power: 6, col: '#f0d040', blurb: 'Power for everything else. Don\'t stack it next to cargo.' },
  fuel: { name: 'Fuel Tank', price: 150, mass: 2, power: 0, col: '#c83a48', blurb: 'More hyperlane jumps between refuels.' },
  cargo: { name: 'Cargo Bay', price: 200, mass: 2, power: 0, col: '#b89060', blurb: '10 units of cargo. Customs can scan it.' },
  hold: { name: 'Smuggler\'s Hold', price: 700, mass: 2, power: -1, col: '#6a4a3a', blurb: '6 units, hidden from Imperial scans.' },
  gun: { name: 'Laser Cannon', price: 500, mass: 2, power: -2, col: '#e84848', blurb: 'Forward guns. Aim with the nose.' },
  shield: { name: 'Deflector', price: 650, mass: 2, power: -2, col: '#58a8e8', blurb: 'A recharging shield in front of the hull.' },
  quarters: { name: 'Crew Quarters', price: 250, mass: 2, power: -1, col: '#a878c8', blurb: 'Two bunks. Crew need a bed.' },
  med: { name: 'Med Bay', price: 450, mass: 2, power: -1, col: '#f0f0f0', blurb: 'Heals you and your crew between fights.' },
  tube: { name: 'Boarding Tube', price: 550, mass: 2, power: -1, col: '#68f0a0', blurb: 'Dock with a disabled ship and walk aboard.' },
  lounge: { name: 'Shag Lounge', price: 350, mass: 2, power: -1, col: '#e878a8', blurb: 'Orange carpet, a bar, a hi-fi. Crew morale.' },
  battery: { name: 'Lantern Battery', price: 1200, mass: 3, power: 0, col: '#58e058', blurb: 'Recharges your ring in flight.' },
  armor: { name: 'Armour Plate', price: 180, mass: 3, power: 0, col: '#8a92a2', blurb: 'Dead weight that keeps you alive.' },
};

export type HullId = 'skiff' | 'cutter' | 'freighter' | 'corvette';
export const HULLS: Record<HullId, { name: string; w: number; h: number; price: number; paint: string }> = {
  skiff: { name: 'Skiff', w: 5, h: 3, price: 0, paint: '#d8d4c8' },
  cutter: { name: 'Cutter', w: 7, h: 4, price: 4000, paint: '#e8742a' },
  freighter: { name: 'Freighter', w: 9, h: 5, price: 9000, paint: '#8a96a8' },
  corvette: { name: 'Corvette', w: 9, h: 6, price: 18000, paint: '#3a4a6a' },
};

export interface Ship { name: string; hull: HullId; grid: (Mod | null)[]; paint: string }

export function blankShip(hull: HullId, name: string): Ship {
  const H = HULLS[hull];
  return { name, hull, grid: new Array(H.w * H.h).fill(null), paint: H.paint };
}

// the starter: a scrappy skiff
export function starterShip(name: string): Ship {
  const s = blankShip('skiff', name);
  const set = (x: number, y: number, m: Mod) => { s.grid[y * 5 + x] = m; };
  set(4, 1, 'cockpit'); set(0, 0, 'engine'); set(0, 2, 'engine'); set(1, 1, 'reactor');
  set(2, 1, 'cargo'); set(3, 0, 'gun'); set(3, 2, 'gun'); set(2, 0, 'tube'); set(2, 2, 'quarters'); set(0, 1, 'fuel');
  return s;
}

export interface Stats {
  mass: number; power: number; thrust: number; turn: number; cargo: number; hidden: number;
  guns: number; shield: number; hull: number; crew: number; fuel: number; tube: boolean; battery: boolean; med: boolean;
  problems: string[];
}

export function stats(s: Ship): Stats {
  const H = HULLS[s.hull];
  const count = (m: Mod) => s.grid.filter((g) => g === m).length;
  let mass = 6, power = 0;
  for (const g of s.grid) if (g) { mass += MODS[g].mass; power += MODS[g].power; }
  const engines = count('engine');
  const problems: string[] = [];
  if (count('cockpit') !== 1) problems.push('Needs exactly one cockpit.');
  if (!engines) problems.push('Needs at least one engine.');
  if (power < 0) problems.push(`Power short by ${-power}. Add a reactor.`);
  // engines only push if nothing sits behind them (toward the tail, lower x)
  let blocked = 0;
  for (let y = 0; y < H.h; y++) for (let x = 0; x < H.w; x++) if (s.grid[y * H.w + x] === 'engine') for (let k = 0; k < x; k++) if (s.grid[y * H.w + k]) { blocked++; break; }
  if (blocked) problems.push(`${blocked} engine${blocked > 1 ? 's are' : ' is'} blocked from behind.`);
  // reactors next to cargo are a fire risk (a warning, not a blocker)
  const risky = s.grid.some((g, i) => g === 'reactor' && [i - 1, i + 1, i - H.w, i + H.w].some((j) => s.grid[j] === 'cargo' && Math.abs((j % H.w) - (i % H.w)) <= 1));
  const live = Math.max(0, engines - blocked);
  return {
    mass, power,
    thrust: power < 0 ? live * 45 : (live * 180) / Math.sqrt(mass),
    turn: 3.2 / Math.sqrt(mass / 10),
    cargo: count('cargo') * 10, hidden: count('hold') * 6,
    guns: count('gun'), shield: count('shield') * 40, hull: 40 + s.grid.filter(Boolean).length * 8 + count('armor') * 30,
    crew: count('quarters') * 2, fuel: 2 + count('fuel') * 2, tube: count('tube') > 0, battery: count('battery') > 0, med: count('med') > 0,
    problems: risky ? [...problems, 'Warning: a reactor sits next to cargo.'] : problems,
  };
}

// ---------------------------------------------------------------- sprites
const C = 6; // pixels per module cell in space
const spriteCache = new Map<string, HTMLCanvasElement[]>();

function paintTop(s: Ship): Px {
  const H = HULLS[s.hull];
  const W = H.w * C + 8, Hh = H.h * C + 6;
  const p = new Px(W, Hh);
  const hull = rampOf(s.paint);
  // the hull: rounded at the nose, flat at the tail
  for (let y = 0; y < H.h * C; y++)
    for (let x = 0; x < H.w * C; x++) {
      const gx = Math.floor(x / C), gy = Math.floor(y / C);
      if (!s.grid[gy * H.w + gx]) {
        // a filled cell next to it? draw a thin strut, otherwise empty space
        continue;
      }
      const ny = (y - (H.h * C) / 2) / ((H.h * C) / 2);
      const nose = x > H.w * C - 5 && Math.abs(ny) > 0.55 + (H.w * C - x) * 0.08;
      if (nose) continue;
      const l = -ny * 0.8;
      p.set(x + 4, y + 3, l > 0.4 ? hull[3] : l > -0.3 ? hull[2] : hull[1]);
    }
  // module details
  for (let gy = 0; gy < H.h; gy++)
    for (let gx = 0; gx < H.w; gx++) {
      const m = s.grid[gy * H.w + gx];
      if (!m) continue;
      const x0 = gx * C + 4, y0 = gy * C + 3;
      const col = MODS[m].col;
      if (m === 'cockpit') { p.rect(x0 + 1, y0 + 1, 4, 4, col); p.set(x0 + 3, y0 + 1, '#e8f8ff'); p.set(x0 + 4, y0 + 2, '#e8f8ff'); }
      else if (m === 'engine') { p.rect(x0, y0 + 1, 3, 4, '#4a4e5a'); p.set(x0 - 1, y0 + 2, '#f8a040'); p.set(x0 - 1, y0 + 3, '#f8a040'); }
      else if (m === 'gun') { p.hline(x0 + 2, x0 + 7, y0 + 2, '#3a3e4a'); p.hline(x0 + 2, x0 + 6, y0 + 3, '#6a6e7a'); p.set(x0 + 1, y0 + 2, col); }
      else if (m === 'cargo' || m === 'hold') { p.rect(x0 + 1, y0 + 1, 4, 4, m === 'hold' ? hull[1] : col); p.set(x0 + 1, y0 + 1, hull[4]); }
      else if (m === 'shield') { p.oval(x0 + 3, y0 + 3, 2, 2, () => col); }
      else if (m === 'reactor') { p.rect(x0 + 1, y0 + 1, 4, 4, '#3a3e4a'); p.rect(x0 + 2, y0 + 2, 2, 2, col); }
      else { p.set(x0 + 2, y0 + 2, col); p.set(x0 + 3, y0 + 3, col); }
    }
  // a paint stripe along the spine
  const mid = Math.floor((H.h * C) / 2) + 3;
  for (let x = 4; x < H.w * C; x++) if (p.has(x, mid) && x % 3) p.set(x, mid, hull[4]);
  p.outline(ink);
  return p;
}

// 32 rotations, nearest-neighbour sampled so they stay pixel-crisp
export function shipSprites(s: Ship): HTMLCanvasElement[] {
  const key = s.hull + s.paint + s.grid.join(',');
  let arr = spriteCache.get(key);
  if (arr) return arr;
  const src = paintTop(s);
  const R = Math.ceil(Math.hypot(src.w, src.h) / 2) + 1;
  arr = [];
  for (let k = 0; k < 32; k++) {
    const a = (k / 32) * Math.PI * 2, ca = Math.cos(a), sa = Math.sin(a);
    const out = new Px(R * 2, R * 2);
    for (let y = 0; y < R * 2; y++)
      for (let x = 0; x < R * 2; x++) {
        const dx = x - R + 0.5, dy = y - R + 0.5;
        const sx = Math.floor(dx * ca + dy * sa + src.w / 2), sy = Math.floor(-dx * sa + dy * ca + src.h / 2);
        const n = src.raw(sx, sy);
        if (n) out.d[y * out.w + x] = n;
      }
    arr.push(out.canvas());
  }
  if (spriteCache.size > 40) spriteCache.clear();
  spriteCache.set(key, arr);
  return arr;
}

// a module icon for the editor
const iconCache = new Map<string, HTMLCanvasElement>();
export function modIcon(m: Mod): HTMLCanvasElement {
  let c = iconCache.get(m);
  if (c) return c;
  const p = new Px(16, 16), r = rampOf(MODS[m].col);
  p.rect(1, 1, 14, 14, r[2]); p.hline(1, 14, 1, r[4]); p.vline(1, 1, 14, r[3]); p.hline(1, 14, 14, r[0]); p.vline(14, 1, 14, r[1]);
  const g = '#1c1828';
  switch (m) {
    case 'cockpit': p.rect(5, 4, 7, 5, '#e8f8ff'); p.rect(6, 5, 5, 3, '#68b8f0'); break;
    case 'engine': p.rect(4, 5, 5, 6, g); p.rect(9, 6, 3, 4, '#f8e060'); break;
    case 'reactor': p.oval(8, 8, 4, 4, () => g); p.oval(8, 8, 2, 2, () => '#fff8a0'); break;
    case 'fuel': p.rect(5, 3, 6, 10, r[4]); p.hline(5, 10, 6, g); break;
    case 'cargo': p.rect(4, 4, 8, 8, '#8a6030'); p.line(4, 4, 11, 11, '#e0b070'); break;
    case 'hold': p.rect(4, 4, 8, 8, g); p.set(8, 8, '#e0b070'); break;
    case 'gun': p.rect(3, 7, 10, 2, g); p.rect(3, 6, 4, 4, g); break;
    case 'shield': p.oval(8, 8, 5, 5, (nx, ny) => (nx * nx + ny * ny > 0.5 ? '#e8f8ff' : null)); break;
    case 'quarters': p.rect(3, 5, 10, 3, '#f0f0f8'); p.rect(3, 9, 10, 3, '#f0f0f8'); break;
    case 'med': p.rect(7, 3, 2, 10, '#e84848'); p.rect(3, 7, 10, 2, '#e84848'); break;
    case 'tube': p.oval(8, 8, 5, 5, (nx, ny) => (nx * nx + ny * ny > 0.45 ? g : '#a8ffc8')); break;
    case 'lounge': p.rect(3, 8, 10, 4, '#e8742a'); p.rect(3, 6, 2, 6, '#e8742a'); p.rect(11, 6, 2, 6, '#e8742a'); break;
    case 'battery': p.rect(5, 3, 6, 10, g); p.rect(6, 5, 4, 6, '#58e058'); p.hline(6, 9, 3, '#58e058'); break;
    case 'armor': for (let y = 3; y < 14; y += 3) p.hline(3, 12, y, r[0]); break;
  }
  c = p.canvas();
  iconCache.set(m, c);
  return c;
}
