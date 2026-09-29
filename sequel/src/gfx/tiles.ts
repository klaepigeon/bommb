// Ground tiles in the Gen 4 style: soft 5–6 tone ramps, patterned detail instead of noise,
// animated water, and edges that respond to the neighbouring tile (shore foam, path borders,
// cliff lips).

import { Px } from './px';
import { PAL, mix } from './pal';
import { hash2, rng } from '../core/math';

export const T = {
  GRASS: 0, TALL: 1, PATH: 2, PLAZA: 3, WATER: 4, SAND: 5, DUST: 6, ROCK: 7, PAD: 8,
  FLOOR: 9, WALL: 10, FLOWERS: 11, VOID: 12, HULL: 13, TUBE: 14,
} as const;
export type Tile = (typeof T)[keyof typeof T];

// tiles you can't walk on
export const SOLID = new Set<number>([T.WATER, T.ROCK, T.WALL, T.VOID, T.HULL]);

export const TS = 16;
const VARIANTS = 6;
const cache = new Map<string, HTMLCanvasElement>();

type Painter = (p: Px, v: number, frame: number) => void;

const fill = (p: Px, c: string) => p.rect(0, 0, TS, TS, c);

// grass blades in a repeating Gen 4 pattern: little "v" pairs with a light tip
function blades(p: Px, r: readonly string[], seed: number, n: number) {
  const q = rng(seed);
  for (let k = 0; k < n; k++) {
    const x = 1 + q.int(0, 12), y = 2 + q.int(0, 11);
    p.set(x, y, r[2]); p.set(x + 2, y, r[2]); p.set(x + 1, y + 1, r[2]);
    p.set(x, y - 1, r[4]); p.set(x + 2, y - 1, r[4]);
  }
}

const PAINT: Record<number, Painter> = {
  [T.GRASS]: (p, v) => {
    const r = PAL.grass;
    fill(p, r[3]);
    // a soft checker of two greens, the way HGSS routes are shaded
    for (let y = 0; y < TS; y++) for (let x = 0; x < TS; x++) if (((x >> 2) + (y >> 2) + v) % 5 === 0) p.set(x, y, mix(r[3], r[4], 0.35));
    blades(p, r, v * 31 + 7, 3);
  },
  [T.TALL]: (p, v, f) => {
    const r = PAL.tall;
    fill(p, r[2]);
    // rows of tall blades that sway on alternate frames
    const sway = f % 2;
    for (let row = 0; row < 4; row++) {
      const y = 3 + row * 4;
      for (let x = (row % 2) * 2; x < TS; x += 4) {
        const s = (x + row + sway) % 2;
        p.vline(x + s, y - 3, y, r[4]); p.vline(x + 1 + s, y - 2, y, r[3]);
        p.set(x + s, y - 3, r[5]);
        p.hline(x, x + 3, y + 1, r[1]);
      }
    }
    if (v % 3 === 0) p.set(8, 8, r[5]);
  },
  [T.FLOWERS]: (p, v, f) => {
    PAINT[T.GRASS](p, v, f);
    const cols = [['#f05858', '#ffa8a8'], ['#f8d038', '#fff4a0'], ['#ffffff', '#dce8ff'], ['#e878d8', '#ffc0f4']][v % 4];
    for (const [x, y] of [[3, 3], [11, 5], [6, 10], [13, 12]]) {
      const bob = (f + x) % 2;
      p.set(x, y - 1 + bob, cols[1]); p.set(x - 1, y + bob, cols[0]); p.set(x + 1, y + bob, cols[0]); p.set(x, y + 1 + bob, cols[0]); p.set(x, y + bob, '#f8e060');
    }
  },
  [T.PATH]: (p, v) => {
    const r = PAL.path;
    fill(p, r[3]);
    const q = rng(v * 13 + 3);
    for (let k = 0; k < 5; k++) { const x = q.int(1, 13), y = q.int(1, 13); p.set(x, y, r[2]); p.set(x + 1, y, r[2]); p.set(x, y - 1, r[4]); }
    for (let k = 0; k < 3; k++) p.set(q.int(0, 15), q.int(0, 15), r[5]);
  },
  [T.PLAZA]: (p) => {
    const r = PAL.plaza;
    fill(p, r[3]);
    // large paving slabs with bevelled edges
    // one soft seam per slab edge, lit top-left, like HGSS town paving
    for (const [x0, y0] of [[0, 0], [8, 0], [0, 8], [8, 8]]) {
      p.hline(x0, x0 + 6, y0, r[4]);
      p.hline(x0, x0 + 7, y0 + 7, r[2]); p.vline(x0 + 7, y0, y0 + 7, r[2]);
    }
  },
  [T.WATER]: (p, v, f) => {
    const r = PAL.water;
    fill(p, r[2]);
    // drifting light bands, four frames
    for (let k = 0; k < 3; k++) {
      const y = (k * 5 + f + v) % TS, x = (k * 7 + v * 3 + f * 2) % TS;
      p.hline(x, x + 4, y, r[3]); p.hline(x + 1, x + 3, y, r[4]);
      if ((f + k) % 4 === 0) p.set(x + 2, y - 1, r[5]);
    }
  },
  [T.SAND]: (p, v) => {
    const r = PAL.sand;
    fill(p, r[3]);
    const q = rng(v * 17 + 11);
    for (let k = 0; k < 7; k++) p.set(q.int(0, 15), q.int(0, 15), k < 4 ? r[2] : r[4]);
    if (v === 0) { p.set(7, 8, '#f8a8b8'); p.set(8, 8, '#ffd0d8'); }
  },
  [T.DUST]: (p, v) => {
    const r = PAL.dust;
    fill(p, r[3]);
    // wind ripples
    for (let y = 3; y < TS; y += 5) for (let x = 0; x < TS; x++) {
      const yy = y + Math.round(Math.sin((x + v * 5) * 0.5));
      p.set(x, yy, r[2]); if (x % 3) p.set(x, yy - 1, r[4]);
    }
    if (v % 3 === 0) p.set(4 + v, 9, r[0]);
  },
  [T.ROCK]: (p, v) => {
    const r = PAL.rock;
    fill(p, r[2]);
    const q = rng(v * 19 + 5);
    for (let k = 0; k < 3; k++) {
      const x = q.int(0, 10), y = q.int(2, 12);
      p.hline(x, x + 4, y, r[1]); p.hline(x, x + 3, y - 1, r[4]); p.set(x + 4, y + 1, r[0]);
    }
  },
  [T.PAD]: (p, v) => {
    const r = PAL.pad;
    fill(p, r[2]);
    // steel deck plates with rivets and a painted hazard edge on some tiles
    p.hline(0, 15, 0, r[4]); p.vline(0, 0, 15, r[4]); p.hline(0, 15, 15, r[0]); p.vline(15, 0, 15, r[0]);
    for (const [x, y] of [[2, 2], [13, 2], [2, 13], [13, 13]]) { p.set(x, y, r[5]); p.set(x + 1, y + 1, r[0]); }
    if (v === 0) for (let k = 0; k < TS; k += 4) { p.rect(k, 6, 2, 4, '#e8b020'); p.rect(k + 2, 6, 2, 4, '#303038'); }
  },
  [T.FLOOR]: (p, v) => {
    const r = PAL.floor;
    fill(p, r[3]);
    // shag-carpet cabin floor: soft two-tone weave
    for (let y = 0; y < TS; y++) for (let x = 0; x < TS; x++) if ((x + y * 3 + v) % 4 === 0) p.set(x, y, r[2]);
    for (let x = 0; x < TS; x += 5) p.set(x, (x + v) % TS, r[4]);
  },
  [T.WALL]: (p) => {
    const r = PAL.metal;
    fill(p, r[2]);
    p.hline(0, 15, 0, r[4]); p.hline(0, 15, 1, r[3]); p.hline(0, 15, 12, r[1]); p.rect(0, 13, 16, 3, r[0]);
    p.vline(7, 2, 11, r[1]); p.set(3, 5, r[5]); p.set(11, 5, r[5]);
  },
  [T.HULL]: (p) => {
    const r = PAL.metal;
    fill(p, r[1]);
    for (let y = 2; y < TS; y += 5) p.hline(0, 15, y, r[0]);
    p.set(4, 4, r[3]); p.set(12, 9, r[3]);
  },
  [T.TUBE]: (p, v, f) => {
    const r = PAL.pad;
    fill(p, r[1]);
    for (let y = 0; y < TS; y += 4) p.hline(1, 14, y, r[3]);
    p.vline(0, 0, 15, r[0]); p.vline(15, 0, 15, r[0]);
    const c = f % 2 ? '#68f0a0' : '#38b870';
    p.set(2, 7, c); p.set(13, 7, c);
  },
  [T.VOID]: (p) => fill(p, '#0a0814'),
};

export const ANIMATED = new Set<number>([T.WATER, T.TALL, T.FLOWERS, T.TUBE]);

export function tileCanvas(t: number, v: number, frame = 0): HTMLCanvasElement {
  const f = ANIMATED.has(t) ? frame % 4 : 0;
  const key = t + ':' + v + ':' + f;
  let c = cache.get(key);
  if (!c) {
    const p = new Px(TS, TS);
    (PAINT[t] || PAINT[T.VOID])(p, v, f);
    c = p.canvas();
    cache.set(key, c);
  }
  return c;
}

export function variant(x: number, y: number): number { return Math.floor(hash2(x, y, 3) * VARIANTS); }

// neighbour-aware trims drawn over the base tile
export function drawEdges(g: CanvasRenderingContext2D, t: number, n: (dx: number, dy: number) => number, px: number, py: number, frame: number): void {
  const R = (x: number, y: number, w: number, h: number, c: string) => { g.fillStyle = c; g.fillRect(px + x, py + y, w, h); };
  if (t === T.WATER) {
    // foam where water meets land, pulsing gently
    const land = (q: number) => q !== T.WATER && q !== T.VOID;
    const foam = frame % 2 ? '#f4fbff' : '#dcefff', lip = PAL.water[4];
    if (land(n(0, -1))) { R(0, 0, 16, 1, foam); R(0, 1, 16, 1, lip); }
    if (land(n(0, 1))) { R(0, 15, 16, 1, foam); R(0, 14, 16, 1, lip); }
    if (land(n(-1, 0))) { R(0, 0, 1, 16, foam); R(1, 0, 1, 16, lip); }
    if (land(n(1, 0))) { R(15, 0, 1, 16, foam); R(14, 0, 1, 16, lip); }
    return;
  }
  if (t === T.PATH || t === T.SAND || t === T.DUST) {
    const green = (q: number) => q === T.GRASS || q === T.TALL || q === T.FLOWERS;
    const edge = t === T.PATH ? PAL.path[1] : t === T.SAND ? PAL.sand[1] : PAL.dust[1];
    if (green(n(0, -1))) { R(0, 0, 16, 1, edge); for (let k = 1; k < 16; k += 3) R(k, 1, 1, 1, PAL.grass[2]); }
    if (green(n(0, 1))) R(0, 15, 16, 1, edge);
    if (green(n(-1, 0))) R(0, 0, 1, 16, edge);
    if (green(n(1, 0))) R(15, 0, 1, 16, edge);
  }
  if (t === T.ROCK && n(0, 1) !== T.ROCK) {
    // a cliff face where rock drops to the ground below
    R(0, 11, 16, 3, PAL.rock[1]); R(0, 14, 16, 2, PAL.rock[0]);
    for (let k = 2; k < 16; k += 5) R(k, 11, 1, 4, PAL.rock[0]);
  }
  if (t === T.PLAZA) {
    const soft = (q: number) => q === T.GRASS || q === T.FLOWERS || q === T.TALL;
    if (soft(n(0, 1))) { R(0, 14, 16, 1, PAL.plaza[5]); R(0, 15, 16, 1, PAL.plaza[0]); }
  }
}
