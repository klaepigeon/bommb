// Buildings and props in the Gen 4 (Platinum/HGSS) look: a roof seen from above at an angle
// with the lit and shaded planes, a tall front facade, and a soft cast shadow to the lower
// right. Each is cached as one canvas and drawn with its foot on the map.

import { Px } from './px';
import { PAL, ink, rampOf, mix } from './pal';
import { rng } from '../core/math';

export type BuildingKind = 'house' | 'shop' | 'casino' | 'terminal' | 'shipyard' | 'market' | 'dome' | 'cantina' | 'hab';

export interface BuildingArt { cv: HTMLCanvasElement; w: number; h: number; roofH: number; doorX: number }

const cache = new Map<string, BuildingArt>();

// wTiles × hTiles footprint; the art is taller than the footprint (roofs rise above it)
export function buildingArt(kind: BuildingKind, wT: number, hT: number, seed: number, night: boolean): BuildingArt {
  const key = `${kind}:${wT}x${hT}:${seed}:${night ? 'n' : 'd'}`;
  let a = cache.get(key);
  if (a) return a;
  const q = rng(seed);
  const W = wT * 16, H = hT * 16 + 16; // one extra tile of roof above the footprint
  const p = new Px(W + 6, H + 4);
  const roofH = kind === 'dome' ? Math.round(H * 0.62) : Math.round(H * 0.5);
  const roofCol = kind === 'casino' ? '#b83a78' : kind === 'terminal' ? '#e8e4dc' : kind === 'shipyard' ? '#d8842a' : kind === 'market' ? '#3a9a8a' : kind === 'cantina' ? '#a85a2a' : kind === 'hab' ? '#8a96a8' : q.pick(['#c84a3a', '#3a6ac8', '#3a9a58', '#8a5ac8', '#d8a030']);
  const wallCol = kind === 'casino' ? '#f0d8e8' : kind === 'terminal' ? '#c8d8e8' : kind === 'shipyard' ? '#b8bcc8' : kind === 'dome' ? '#d8c8b8' : kind === 'hab' ? '#c8ccd4' : q.pick(['#f4ecd8', '#e8dcc4', '#dce8f0', '#f0e0d0']);
  const roof = rampOf(roofCol), wall = rampOf(wallCol);

  if (kind === 'dome') {
    // a moon-colony dome: a glass half-sphere on a ring wall
    p.oval(W / 2, roofH, W / 2 - 1, roofH - 1, (nx, ny, x, y) => {
      if (y > roofH) return null;
      const l = -nx * 0.6 - ny * 0.6;
      const glass = l > 0.6 ? '#e8f6ff' : l > 0.2 ? '#9ccce8' : l > -0.3 ? '#6aa0c8' : '#4a78a0';
      return ((x + y) % 7 === 0 || Math.abs(nx) > 0.95) ? '#3a5a78' : glass;
    });
    for (let k = 1; k < 4; k++) { const yy = Math.round(roofH * (k / 4)); p.hline(2, W - 3, yy, '#3a5a78'); }
  } else {
    // a pitched roof seen from above-front: lit back plane, a ridge, then the front slope
    const ridge = Math.round(roofH * 0.38);
    for (let y = 0; y < roofH; y++)
      for (let x = 0; x < W; x++) {
        let c: string;
        if (y < ridge) c = y < 2 ? roof[4] : roof[3];
        else {
          const row = Math.floor((y - ridge) / 3), yy = (y - ridge) % 3;
          c = yy === 2 ? roof[1] : roof[2];
          if (yy !== 2 && (x + row * 4) % 8 === 0) c = roof[1]; // shingle joints
          if (yy === 0) c = mix(roof[2], roof[3], 0.5);
        }
        // the right end is in shade
        if (x > W - 5) c = mix(c, roof[0], 0.35);
        p.set(x, y, c);
      }
    p.hline(0, W - 1, ridge, roof[4]);
    p.hline(0, W - 1, roofH - 1, roof[0]);
    if (kind === 'terminal' || kind === 'shipyard') {
      // flat-topped: a control tower or a gantry crane on top
      const tx = kind === 'terminal' ? W - 22 : 6;
      p.rect(tx, 0, 14, ridge + 2, '#e0e4ec'); p.rect(tx + 2, 2, 10, 5, '#68b8f0'); p.hline(tx + 2, tx + 11, 2, '#c8ecff'); p.set(tx + 7, -1, '#f04040');
      if (kind === 'shipyard') { p.rect(W - 16, 0, 3, roofH, '#e8b020'); p.rect(W - 30, 2, 17, 3, '#e8b020'); p.vline(W - 28, 5, 12, '#303038'); }
    }
  }

  // --- the facade
  const fy0 = roofH, fy1 = H - 1;
  for (let y = fy0; y <= fy1; y++)
    for (let x = 0; x < W; x++) {
      let c = y === fy0 ? wall[0] : y === fy0 + 1 ? wall[1] : y > fy1 - 2 ? wall[1] : wall[2];
      if (x < 2) c = wall[3];
      if (x > W - 4) c = wall[1];
      if (kind === 'shipyard' && (y - fy0) % 4 === 0) c = wall[1];
      p.set(x, y, c);
    }
  // windows: framed glass with a highlight; warm at night
  const glass = night ? ['#c89040', '#f8d070', '#fff4c0'] : ['#3a70b8', '#68a8e8', '#c0e4ff'];
  const win = (x: number, y: number, w: number, h: number) => {
    p.rect(x - 1, y - 1, w + 2, h + 2, ink(wallCol));
    p.rect(x, y, w, h, glass[1]); p.hline(x, x + w - 1, y, glass[2]); p.hline(x, x + w - 1, y + h - 1, glass[0]);
    if (!night) { p.set(x + 1, y + 1, '#ffffff'); p.set(x + 2, y + 2, '#ffffff'); }
  };
  const doorW = kind === 'terminal' || kind === 'shipyard' ? 16 : 10;
  const doorX = Math.round(W / 2 - doorW / 2) + (kind === 'house' ? q.int(-8, 8) : 0);
  const fh = fy1 - fy0;
  if (kind !== 'dome') {
    for (let x = 5; x < W - 10; x += 14) if (x + 9 < doorX - 1 || x > doorX + doorW + 1) win(x, fy0 + 4, 9, Math.min(8, fh - 12));
  } else {
    for (let x = 6; x < W - 10; x += 16) if (x + 7 < doorX - 1 || x > doorX + doorW + 1) { p.oval(x + 4, fy0 + 6, 3, 3, () => glass[1]); p.set(x + 3, fy0 + 5, glass[2]); }
  }
  // door
  const dy = fy1 - 13;
  p.rect(doorX - 1, dy - 1, doorW + 2, 15, ink(wallCol));
  if (kind === 'terminal' || kind === 'shipyard' || kind === 'casino' || kind === 'market') {
    // sliding glass doors
    p.rect(doorX, dy, doorW, 13, glass[1]); p.rect(doorX, dy, doorW, 3, glass[2]); p.vline(doorX + doorW / 2, dy, dy + 12, ink(wallCol));
  } else {
    p.rect(doorX, dy, doorW, 13, '#8a5430'); p.rect(doorX + 1, dy + 1, doorW - 2, 5, '#a86a3c'); p.rect(doorX + 1, dy + 7, doorW - 2, 5, '#a86a3c'); p.set(doorX + doorW - 3, dy + 7, '#f8d040');
  }
  // an awning over shops, the casino's lights
  if (kind === 'shop' || kind === 'cantina' || kind === 'market') {
    const aw = kind === 'cantina' ? ['#a83a2a', '#f4e0c0'] : kind === 'market' ? ['#2a8a7a', '#f0fff8'] : ['#3a6ac8', '#ffffff'];
    for (let x = 0; x < W; x++) { const c = (x >> 2) % 2 ? aw[0] : aw[1]; p.vline(x, fy0 + 1, fy0 + 3, c); if (x % 4 === 1) p.set(x, fy0 + 4, c); }
  }
  if (kind === 'casino') for (let x = 1; x < W - 1; x += 3) p.set(x, fy0 + 1, (x / 3) % 2 < 1 ? '#fff080' : '#ff70c0');

  // outline the silhouette (the cast shadow is drawn under it on the map)
  p.outline(ink);
  a = { cv: p.canvas(), w: W, h: H, roofH, doorX: doorX + doorW / 2 };
  if (cache.size > 300) cache.clear();
  cache.set(key, a);
  return a;
}

// ---------------------------------------------------------------- props
export type PropKind = 'tree' | 'palm' | 'lamp' | 'crystal' | 'rock' | 'antenna' | 'bench' | 'crate' | 'sign' | 'bush';
const propCache = new Map<string, { cv: HTMLCanvasElement; ox: number; oy: number }>();

export function propArt(kind: PropKind, v: number, night: boolean): { cv: HTMLCanvasElement; ox: number; oy: number } {
  const key = kind + v + (night ? 'n' : '');
  let s = propCache.get(key);
  if (s) return s;
  let p: Px, ox = 0, oy = 0;
  const lit = (nx: number, ny: number) => -nx * 0.55 - ny * 0.7;
  switch (kind) {
    case 'tree': {
      // the HGSS round tree: a layered canopy of leaf clumps over a short trunk
      p = new Px(32, 40); ox = -8; oy = -26;
      const r = PAL.leaf, b = PAL.bark;
      p.rect(14, 28, 5, 10, b[2]); p.vline(14, 28, 37, b[4]); p.vline(18, 28, 37, b[1]); p.hline(12, 20, 37, b[1]);
      const clumps: [number, number, number][] = [[16, 20, 10], [9, 17, 6], [23, 17, 6], [16, 10, 8], [11, 12, 5], [21, 12, 5]];
      for (const [cx, cy, rr] of clumps) p.oval(cx, cy, rr, rr * 0.88, (nx, ny) => { const l = lit(nx, ny) - (cy - 16) * 0.015; return l > 0.6 ? r[5] : l > 0.25 ? r[4] : l > -0.2 ? r[3] : l > -0.55 ? r[2] : r[1]; });
      // clump shadows: little arcs that separate the leaf masses
      for (const [cx, cy, rr] of clumps.slice(1)) for (let k = -2; k <= 2; k++) p.set(cx + k, Math.round(cy + rr * 0.8), r[1]);
      p.set(12, 9, '#ffffff'); p.set(13, 8, r[5]);
      if (v % 3 === 0) for (const [x, y] of [[9, 18], [20, 22], [24, 14]]) { p.set(x, y, '#f04848'); p.set(x, y - 1, '#ff9a8a'); }
      break;
    }
    case 'palm': {
      p = new Px(32, 44); ox = -8; oy = -30;
      for (let y = 14; y < 43; y++) { const x = 15 + Math.round(Math.sin(y * 0.16) * 2); p.rect(x, y, 4, 1, y % 3 ? '#b0845a' : '#8a6040'); p.set(x, y, '#d8aa78'); }
      for (const [dx, dy] of [[-12, 5], [12, 5], [-9, -4], [9, -4], [0, -8], [-5, 8], [6, 8]]) for (let k = 0; k <= 12; k++) { const t = k / 12, x = Math.round(16 + dx * t), y = Math.round(13 + dy * t + t * t * 5); p.set(x, y, '#58b848'); p.set(x, y + 1, '#388838'); if (k % 3 === 0) p.set(x, y - 1, '#98e070'); }
      p.oval(16, 13, 2.5, 2.5, () => '#6a4428');
      break;
    }
    case 'lamp': {
      // a seventies space-age street lamp: a pole and a glowing orb
      p = new Px(16, 36); ox = 0; oy = -22;
      p.rect(7, 10, 2, 24, '#5a6272'); p.vline(7, 10, 33, '#8a92a2'); p.rect(4, 33, 8, 2, '#3a4252');
      p.oval(8, 6, 5, 5, (nx, ny) => (night ? (lit(nx, ny) > 0 ? '#fffbe0' : '#f8e090') : lit(nx, ny) > 0.3 ? '#ffffff' : lit(nx, ny) > -0.3 ? '#d0e4f0' : '#98b0c8'));
      p.hline(3, 13, 11, '#3a4252');
      break;
    }
    case 'crystal': {
      p = new Px(24, 28); ox = -4; oy = -14;
      const r = PAL.crystal;
      const spike = (x: number, h: number, w: number) => { for (let y = 0; y < h; y++) { const ww = Math.max(1, Math.round(w * (y / h))); for (let k = -ww; k <= ww; k++) p.set(x + k, 26 - h + y, k < 0 ? r[4] : k === 0 ? r[5] : r[2]); } };
      spike(12, 22, 4); spike(6, 13, 3); spike(18, 15, 3);
      if (night) p.set(12, 8, '#ffffff');
      break;
    }
    case 'rock': {
      p = new Px(20, 16); ox = -2; oy = 2;
      const r = PAL.rock;
      p.oval(10, 9, 8.5, 6, (nx, ny) => { const l = lit(nx, ny); return l > 0.5 ? r[5] : l > 0.1 ? r[4] : l > -0.4 ? r[3] : r[2]; });
      p.set(11, 8, r[1]); p.set(12, 9, r[1]);
      break;
    }
    case 'bush': {
      p = new Px(20, 16); ox = -2; oy = 2;
      const r = PAL.leaf;
      for (const [cx, cy, rr] of [[10, 8, 7], [5, 10, 4], [15, 10, 4]] as [number, number, number][]) p.oval(cx, cy, rr, rr * 0.85, (nx, ny) => { const l = lit(nx, ny); return l > 0.5 ? r[5] : l > 0.1 ? r[4] : l > -0.4 ? r[3] : r[2]; });
      break;
    }
    case 'antenna': {
      p = new Px(20, 40); ox = -2; oy = -26;
      p.line(10, 38, 4, 12, '#8a92a2'); p.line(10, 38, 16, 12, '#8a92a2'); p.vline(10, 4, 38, '#b0b8c8');
      for (let y = 16; y < 36; y += 6) p.line(6, y, 14, y + 3, '#5a6272');
      p.oval(10, 4, 3, 3, () => (v % 2 ? '#f04040' : '#ff9090'));
      break;
    }
    case 'bench': {
      p = new Px(20, 14); ox = -2; oy = 2;
      p.rect(1, 2, 18, 3, '#e8742a'); p.hline(1, 18, 2, '#ffa860'); p.rect(1, 7, 18, 3, '#e8742a'); p.hline(1, 18, 7, '#ffa860'); p.rect(2, 10, 2, 3, '#3a4252'); p.rect(16, 10, 2, 3, '#3a4252');
      break;
    }
    case 'crate': {
      p = new Px(16, 16);
      p.rect(2, 3, 12, 11, '#c89048'); p.hline(2, 13, 3, '#e8b068'); p.hline(2, 13, 13, '#8a5c28'); p.line(3, 4, 12, 12, '#8a5c28'); p.line(12, 4, 3, 12, '#8a5c28');
      break;
    }
    case 'sign': {
      p = new Px(24, 26); ox = -4; oy = -10;
      p.rect(11, 12, 2, 13, '#5a6272'); p.rect(1, 2, 22, 10, '#2a3a5a'); p.hline(2, 21, 3, '#4a6a9a');
      for (let x = 4; x < 20; x += 3) p.set(x, 7, night ? '#ffe080' : '#e8e8f0');
      break;
    }
  }
  p.outline(ink);
  s = { cv: p.canvas(), ox, oy };
  propCache.set(key, s);
  return s;
}
