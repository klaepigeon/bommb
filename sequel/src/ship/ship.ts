// Ships are grids of modules. The grid decides everything: stats, the sprite you fly, and the
// interior you (or boarders) walk through. Nose points right (+x); engines belong at the back.

import { Px } from '../gfx/px';
import { ink, rampOf } from '../gfx/pal';

export type Mod = 'cockpit' | 'engine' | 'reactor' | 'fuel' | 'cargo' | 'hold' | 'gun' | 'shield' | 'quarters' | 'med' | 'tube' | 'lounge' | 'battery' | 'armor' | 'tractor' | 'jump'
  | 'missile' | 'burner' | 'cloak' | 'pd' | 'sensor' | 'cryo' | 'drone' | 'plate' | 'refinery';

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
  tractor: { name: 'Tractor Beam', price: 600, mass: 2, power: -1, col: '#a8f0ff', blurb: 'Pulls in ore, ice and loose cargo from a distance.' },
  jump: { name: 'Jump Drive', price: 5000, mass: 4, power: -3, col: '#ff5ad0', blurb: 'Folds space to the nearby stars. Needs clear space and jump fuel.' },
  missile: { name: 'Missile Rack', price: 1400, mass: 3, power: -1, col: '#ffb040', blurb: 'Homing missiles: they launch on their own at hostiles while you hold fire.' },
  burner: { name: 'Afterburner', price: 900, mass: 2, power: -2, col: '#ff7a3a', blurb: 'More thrust and a higher top speed outside cruise.' },
  cloak: { name: 'Cloaking Field', price: 6000, mass: 3, power: -3, col: '#9a88c8', blurb: 'Patrols and hunters lose you past close range. Rebel tech.' },
  pd: { name: 'Point Defence', price: 1100, mass: 2, power: -1, col: '#d0d8e8', blurb: 'Swats incoming shots and missiles out of the sky, some of the time.' },
  sensor: { name: 'Sensor Array', price: 800, mass: 2, power: -1, col: '#68f0ff', blurb: 'Every ship and platinum rock in range, on your screen.' },
  cryo: { name: 'Cryo Pods', price: 700, mass: 2, power: -1, col: '#a8d8ff', blurb: 'Sleep four more crew. They wake up grumpy.' },
  drone: { name: 'Drone Bay', price: 3200, mass: 3, power: -2, col: '#f0e060', blurb: 'Two fighter drones that fly with you and shoot what you shoot.' },
  plate: { name: 'Neutronium Plate', price: 1600, mass: 5, power: 0, col: '#5a6272', blurb: 'The heaviest armour money can buy. Very, very heavy.' },
  refinery: { name: 'Ore Refinery', price: 2600, mass: 4, power: -2, col: '#c8a070', blurb: 'Turns three ore into one platinum while you fly.' },
};

export type HullId = 'skiff' | 'dart' | 'cutter' | 'clipper' | 'freighter' | 'gunship' | 'corvette' | 'hauler' | 'frigate' | 'destroyer' | 'dreadnought';
// from a one-seat skiff to a capital ship: bigger grids, more of everything, heavier
export const HULLS: Record<HullId, { name: string; w: number; h: number; price: number; paint: string; cls: string; blurb: string }> = {
  skiff: { name: 'Skiff', w: 5, h: 3, price: 0, paint: '#d8d4c8', cls: 'light', blurb: 'Cheap, cramped, yours.' },
  dart: { name: 'Dart', w: 6, h: 3, price: 2500, paint: '#e84848', cls: 'light', blurb: 'An interceptor: all engine and guns.' },
  cutter: { name: 'Cutter', w: 7, h: 4, price: 4000, paint: '#e8742a', cls: 'light', blurb: 'The smuggler\'s favourite.' },
  clipper: { name: 'Clipper', w: 8, h: 3, price: 6000, paint: '#e8d098', cls: 'medium', blurb: 'A long, fast trader.' },
  freighter: { name: 'Freighter', w: 9, h: 5, price: 9000, paint: '#8a96a8', cls: 'medium', blurb: 'Room for a real cargo run.' },
  gunship: { name: 'Gunship', w: 8, h: 5, price: 12000, paint: '#4a5a3a', cls: 'medium', blurb: 'Wide wings, lots of hardpoints.' },
  corvette: { name: 'Corvette', w: 9, h: 6, price: 18000, paint: '#3a4a6a', cls: 'heavy', blurb: 'A proper warship, small.' },
  hauler: { name: 'Bulk Hauler', w: 12, h: 5, price: 22000, paint: '#b89060', cls: 'heavy', blurb: 'A flying warehouse.' },
  frigate: { name: 'Frigate', w: 11, h: 7, price: 45000, paint: '#6a6a7a', cls: 'heavy', blurb: 'Navy steel, crew for a dozen.' },
  destroyer: { name: 'Destroyer', w: 13, h: 7, price: 90000, paint: '#2a3a5a', cls: 'capital', blurb: 'The ship patrols run from.' },
  dreadnought: { name: 'Dreadnought', w: 16, h: 9, price: 250000, paint: '#d8dce8', cls: 'capital', blurb: 'A capital ship. A small city with guns.' },
};

export interface Ship { name: string; hull: HullId; grid: (Mod | null)[]; paint: string }

export function blankShip(hull: HullId, name: string): Ship {
  const H = HULLS[hull];
  return { name, hull, grid: new Array(H.w * H.h).fill(null), paint: H.paint };
}

// NPC ships: a hull for the role and a loadout laid out on its grid (cockpit forward, engines
// aft, guns on the leading edge, the middle filled for the job)
export type Role = 'trader' | 'patrol' | 'hunter' | 'capital' | 'rebel' | 'miner';
const ROLE_HULLS: Record<Role, HullId[]> = { trader: ['clipper', 'freighter', 'hauler', 'cutter'], patrol: ['corvette', 'gunship', 'frigate'], hunter: ['dart', 'gunship', 'cutter'], capital: ['destroyer', 'dreadnought'], rebel: ['cutter', 'gunship', 'dart'], miner: ['clipper', 'hauler'] };
const ROLE_FILL: Record<Role, Mod[]> = {
  trader: ['cargo', 'cargo', 'cargo', 'cargo', 'fuel', 'quarters', 'shield', 'cargo'],
  patrol: ['armor', 'shield', 'missile', 'pd', 'quarters', 'plate', 'sensor', 'shield'],
  hunter: ['armor', 'tube', 'missile', 'shield', 'burner', 'sensor'],
  capital: ['plate', 'shield', 'missile', 'pd', 'quarters', 'drone', 'shield', 'armor', 'cryo', 'missile'],
  rebel: ['cloak', 'shield', 'missile', 'cargo', 'burner'],
  miner: ['cargo', 'refinery', 'tractor', 'cargo', 'fuel', 'cargo'],
};
export function npcShip(role: Role, rnd: () => number = Math.random, name = 'Ship', hullOverride?: HullId): Ship {
  const hulls = ROLE_HULLS[role], hull = hullOverride || hulls[Math.floor(rnd() * hulls.length)], H = HULLS[hull];
  const s = blankShip(hull, name), W = H.w, mid = Math.floor(H.h / 2);
  const set = (x: number, y: number, m: Mod) => { if (x >= 0 && y >= 0 && x < W && y < H.h) s.grid[y * W + x] = m; };
  set(W - 1, mid, 'cockpit');
  for (let y = 0; y < H.h; y++) if (y !== mid || H.h < 3) set(0, y, 'engine');
  const reactors = Math.max(2, Math.ceil((H.w * H.h) / 9));
  for (let k = 0; k < reactors; k++) set(1 + (k % 2), (mid + Math.ceil(k / 2) * (k % 2 ? 1 : -1) + H.h * 4) % H.h, 'reactor');
  const gunsN = role === 'trader' || role === 'miner' ? 1 : Math.max(2, Math.floor(H.h * 0.7));
  for (let k = 0; k < gunsN; k++) set(W - 2, (mid + (k % 2 ? 1 : -1) * Math.ceil((k + 1) / 2) + H.h * 4) % H.h, 'gun');
  const fill = ROLE_FILL[role];
  let i = 0;
  for (let x = 2; x < W - 1; x++) for (let y = 0; y < H.h; y++) if (!s.grid[y * W + x] && rnd() < 0.85) set(x, y, fill[i++ % fill.length]);
  // power it properly
  for (let guard = 0; guard < 40 && stats(s).power < 0; guard++) {
    const j = s.grid.findIndex((m, n) => !!m && m !== 'cockpit' && m !== 'engine' && m !== 'reactor' && m !== 'gun' && n % W > 1);
    if (j < 0) break;
    s.grid[j] = 'reactor';
  }
  s.paint = role === 'capital' ? '#d8dce8' : role === 'patrol' ? '#eceef4' : role === 'hunter' ? '#2a2a34' : role === 'rebel' ? '#c86a3a' : H.paint;
  return s;
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
  guns: number; shield: number; hull: number; crew: number; fuel: number; tube: boolean; battery: boolean; med: boolean; tractor: boolean; jump: boolean;
  missiles: number; burner: boolean; cloak: boolean; pd: number; sensor: boolean; drones: number; refinery: boolean;
  dmg: number; // damage per laser bolt
  problems: string[];
}
// things outside the grid that change a ship (your crew): applied after the grid's stats
export const STAT_HOOKS: ((st: Stats, s: Ship) => void)[] = [];

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
  const out: Stats = {
    mass, power, dmg: 10,
    thrust: (power < 0 ? live * 45 : (live * 180) / Math.sqrt(mass)) * (count('burner') ? 1.4 : 1),
    turn: 3.2 / Math.sqrt(mass / 10),
    cargo: count('cargo') * 10, hidden: count('hold') * 6,
    guns: count('gun'), shield: count('shield') * 40, hull: 40 + s.grid.filter(Boolean).length * 8 + count('armor') * 30 + count('plate') * 80,
    crew: count('quarters') * 2 + count('cryo') * 4, fuel: 2 + count('fuel') * 2, tube: count('tube') > 0, battery: count('battery') > 0, med: count('med') > 0, tractor: count('tractor') > 0, jump: count('jump') > 0,
    missiles: count('missile'), burner: count('burner') > 0, cloak: count('cloak') > 0, pd: count('pd'), sensor: count('sensor') > 0, drones: count('drone') * 2, refinery: count('refinery') > 0,
    problems: risky ? [...problems, 'Warning: a reactor sits next to cargo.'] : problems,
  };
  for (const h of STAT_HOOKS) h(out, s);
  return out;
}

// ---------------------------------------------------------------- sprites
// Drawn like the rest of the game: a real hull silhouette (the modules decide its shape),
// shaded in the paint's ramp with light from above, panel lines and rivets, swept wings on
// the bigger hulls, an 80s racing stripe, and the ink outline every game 1 sprite has.
const C = 8; // pixels per module cell in space
const spriteCache = new Map<string, HTMLCanvasElement[]>();

function paintTop(s: Ship): Px {
  const H = HULLS[s.hull];
  const PADX = 8, PADY = 6, W = H.w * C + PADX * 2, Hh = H.h * C + PADY * 2;
  const p = new Px(W, Hh);
  const hull = rampOf(s.paint), dark = rampOf('#3a3e4a');
  const cy = PADY + (H.h * C) / 2;
  const occ = (gx: number, gy: number) => gx >= 0 && gy >= 0 && gx < H.w && gy < H.h && !!s.grid[gy * H.w + gx];
  // the body's half-height along its length, from the modules in each column, smoothed
  const half: number[] = [];
  for (let gx = 0; gx < H.w; gx++) {
    let lo = H.h, hi = -1;
    for (let gy = 0; gy < H.h; gy++) if (occ(gx, gy)) { lo = Math.min(lo, gy); hi = Math.max(hi, gy); }
    half.push(hi < 0 ? 0 : Math.max(Math.abs(lo * C - H.h * C / 2), Math.abs((hi + 1) * C - H.h * C / 2)));
  }
  const noseCol = (() => { for (let gx = H.w - 1; gx >= 0; gx--) if (half[gx] > 0) return gx; return H.w - 1; })();
  const tailCol = half.findIndex((h) => h > 0);
  const hAt = (x: number) => {
    const u = (x - PADX) / C, gx = Math.floor(u);
    if (gx < tailCol || gx > noseCol) return 0;
    const a = half[Math.max(tailCol, Math.min(noseCol, gx))], b = half[Math.max(tailCol, Math.min(noseCol, gx + 1))] || a;
    let h = a + (b - a) * Math.max(0, u - gx - 0.5);
    // the nose tapers to a wedge over its last cell and a half
    const toNose = (noseCol + 1) * C + PADX - x;
    if (toNose < C * 1.6) h *= Math.max(0.15, toNose / (C * 1.6));
    return h;
  };
  // wings: bigger hulls get swept wings from mid-body back
  if (H.h >= 4) {
    const wx0 = PADX + Math.floor(H.w * 0.2) * C, wx1 = PADX + Math.floor(H.w * 0.62) * C, span = H.h * C / 2 + 5;
    for (let x = wx0; x < wx1; x++) {
      const t = (x - wx0) / (wx1 - wx0), reach = span * (1 - t * 0.85);
      for (let dy = 0; dy <= reach; dy++) for (const sgn of [-1, 1]) {
        const y = Math.round(cy + sgn * dy);
        if (y < 1 || y >= Hh - 1) continue;
        p.set(x, y, dy > reach - 2 ? hull[4] : dy > reach * 0.6 ? dark[2] : hull[1]);
      }
    }
  }
  // the body, lit from above, panel seams on the cell grid, rivets
  for (let x = PADX - 2; x < W - 2; x++) {
    const h = hAt(x);
    if (h <= 0) continue;
    for (let y = Math.ceil(cy - h); y < cy + h; y++) {
      const ny = (y - cy) / h;
      let col = ny < -0.55 ? hull[4] : ny < -0.1 ? hull[3] : ny < 0.45 ? hull[2] : hull[1];
      if ((x - PADX) % C === 0 && Math.abs(ny) < 0.85) col = hull[1];
      if ((x - PADX) % C === 3 && (y - PADY) % C === 2) col = hull[4];
      p.set(x, y, col);
    }
  }
  // the 80s racing stripe down the flank, and a pinstripe
  const accent = s.paint === '#eceef4' ? '#3a8aff' : s.paint === '#2a2a34' ? '#e84848' : '#ff9a3a';
  for (let x = PADX; x < W - 4; x++) { const h = hAt(x); if (h > 3) { p.set(x, Math.round(cy + h * 0.35), accent); p.set(x, Math.round(cy + h * 0.35) + 1, accent); if (x % 2) p.set(x, Math.round(cy - h * 0.3), hull[4]); } }
  // module details, in place on the grid
  for (let gy = 0; gy < H.h; gy++)
    for (let gx = 0; gx < H.w; gx++) {
      const m = s.grid[gy * H.w + gx];
      if (!m) continue;
      const x0 = gx * C + PADX, y0 = gy * C + PADY, col = MODS[m].col, mx = x0 + C / 2, my = y0 + C / 2;
      if (m === 'cockpit') {
        // a bubble canopy: dark glass, a sky reflection, a hot highlight
        p.oval(mx + 1, cy, 3, Math.min(3, hAt(mx) - 1), (nx, ny) => (ny < -0.3 ? '#a8e8ff' : ny < 0.3 ? '#3a78b8' : '#1a3a68'));
        p.set(mx, Math.round(cy) - 2, '#ffffff');
      } else if (m === 'engine') {
        // a bell nozzle out the back, glowing
        const bx = PADX + tailCol * C - 1;
        p.rect(bx - 3, my - 2, 4, 5, dark[1]); p.rect(bx - 3, my - 1, 1, 3, dark[3]);
        p.set(bx - 4, my - 1, '#ffb040'); p.set(bx - 4, my, '#fff0a0'); p.set(bx - 4, my + 1, '#ffb040'); p.set(bx - 5, my, '#ff6a20');
      } else if (m === 'gun') {
        // a long barrel forward from the hardpoint
        for (let x = x0 + 2; x < Math.min(W - 1, x0 + C + 5); x++) { p.set(x, my, dark[1]); p.set(x, my - 1, dark[3]); }
        p.set(Math.min(W - 2, x0 + C + 5), my, '#ff5a5a');
      } else if (m === 'cargo' || m === 'hold') {
        p.rect(x0 + 1, y0 + 1, C - 2, C - 2, m === 'hold' ? hull[1] : '#8a6030');
        p.hline(x0 + 1, x0 + C - 2, y0 + 3, m === 'hold' ? hull[0] : '#c89050');
        p.hline(x0 + 1, x0 + C - 2, y0 + 5, m === 'hold' ? hull[0] : '#c89050');
      } else if (m === 'shield') {
        p.oval(mx, my, 2, 2, (nx, ny) => (nx * nx + ny * ny < 0.3 ? '#ffffff' : '#58a8e8'));
      } else if (m === 'reactor') {
        p.rect(x0 + 1, y0 + 1, C - 2, C - 2, dark[1]); p.oval(mx, my, 2, 2, (nx, ny) => (nx * nx + ny * ny < 0.3 ? '#fffbe0' : '#f0d040'));
      } else if (m === 'tube') {
        p.oval(mx, my, 3, 3, (nx, ny) => (nx * nx + ny * ny > 0.5 ? dark[3] : '#68f0a0'));
      } else if (m === 'tractor') {
        p.oval(mx, my, 3, 3, (nx, ny) => (nx * nx + ny * ny > 0.5 ? '#c8c8d0' : '#a8f0ff'));
      } else if (m === 'jump') {
        p.oval(mx, my, 3, 3, (nx, ny) => (nx * nx + ny * ny > 0.45 ? '#ff5ad0' : '#2a0a3a')); p.set(mx, my, '#ffffff');
      } else if (m === 'armor' || m === 'plate') {
        for (let k = 1; k < C - 1; k += 2) p.hline(x0 + 1, x0 + C - 2, y0 + k, m === 'plate' ? dark[0] : hull[0]);
      } else if (m === 'missile') {
        // a pod of warheads
        for (let k = 0; k < 3; k++) { p.hline(x0 + 1, x0 + C - 2, y0 + 1 + k * 2, '#d0d0d8'); p.set(x0 + C - 2, y0 + 1 + k * 2, '#ff5a3a'); }
      } else if (m === 'burner') {
        p.rect(x0, my - 1, C - 1, 3, dark[1]); p.set(x0 + C - 2, my, '#ff7a3a');
      } else if (m === 'pd') {
        p.rect(mx - 1, my - 1, 3, 3, dark[2]); p.hline(mx + 1, mx + 3, my - 1, dark[3]);
      } else if (m === 'sensor') {
        p.oval(mx, my, 3, 2, (nx, ny) => (ny < 0 ? '#c8f8ff' : '#68b8c8'));
      } else if (m === 'drone') {
        // a hangar door with a drone parked in it
        p.rect(x0 + 1, y0 + 1, C - 2, C - 2, dark[0]); p.rect(mx - 1, my - 1, 3, 2, '#f0e060');
      } else if (m === 'cloak') {
        for (let k = 0; k < C; k += 2) p.set(x0 + k, y0 + ((k * 3) % C), '#c8b8ff');
      } else if (m === 'refinery') {
        p.rect(x0 + 1, y0 + 1, C - 2, C - 2, '#5a3a1a'); p.oval(mx, my, 1, 1, () => '#ffd060');
      } else {
        p.rect(mx - 1, my - 1, 2, 2, col);
      }
    }
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
    case 'tractor': p.oval(8, 8, 5, 5, (nx, ny) => (nx * nx + ny * ny > 0.55 ? '#a8f0ff' : null)); p.oval(8, 8, 2, 2, () => '#ffffff'); break;
    case 'jump': p.oval(8, 8, 5, 5, (nx, ny) => (nx * nx + ny * ny > 0.4 ? '#ff5ad0' : '#2a0a3a')); p.set(8, 8, '#ffffff'); break;
    case 'missile': for (let k = 0; k < 3; k++) { p.rect(3 + k * 4, 5, 2, 7, '#d0d0d8'); p.set(3 + k * 4, 4, '#ff5a3a'); p.set(4 + k * 4, 4, '#ff5a3a'); } break;
    case 'burner': p.rect(3, 6, 6, 4, g); p.rect(9, 5, 2, 6, '#ff7a3a'); p.rect(11, 6, 2, 4, '#ffd060'); break;
    case 'cloak': for (let y = 3; y < 13; y++) for (let x = 3; x < 13; x++) if ((x + y) % 3 === 0) p.set(x, y, '#e8e0ff'); break;
    case 'pd': p.rect(6, 8, 4, 4, g); p.rect(7, 3, 2, 5, '#d0d8e8'); break;
    case 'sensor': p.oval(8, 9, 5, 3, () => '#68f0ff'); p.rect(7, 3, 2, 5, g); break;
    case 'cryo': p.rect(4, 3, 3, 10, '#a8d8ff'); p.rect(9, 3, 3, 10, '#a8d8ff'); break;
    case 'drone': p.rect(6, 6, 4, 4, '#f0e060'); p.hline(3, 12, 8, g); break;
    case 'plate': for (let y = 3; y < 14; y += 2) p.hline(3, 12, y, '#2a303a'); break;
    case 'refinery': p.rect(4, 4, 8, 8, '#6a4a2a'); p.oval(8, 8, 2, 2, () => '#ffd060'); break;
  }
  c = p.canvas();
  iconCache.set(m, c);
  return c;
}
