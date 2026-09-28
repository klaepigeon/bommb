// RHAPSODY — the Emerald look. A full art pass modelled on how the GBA Pokémon Emerald
// overworld is drawn (its principles, not its assets): flat saturated colours, a few tones
// per material with hue-shifted shadows, patterned pixels instead of noise, and a dark
// outline around everything that stands up off the ground.
//   characters  the same anatomy and anchors as before (so weapons, gore, hats and masks
//               still line up) with GBA palettes: every ramp saturated and widened, cool
//               shadows and warm lights and a shine on the hair (outlines already take
//               a dark shade of what they border)
//   ground      grass with tufts, forest floor, fields, paths, sand, desert ripples, snow,
//               marsh, rock with cliff lips, water with foam at the shore, pavement, brick
//               plazas, docks and asphalt; neighbour-aware edges
//   objects     round-canopy trees, tiered pines, palms, cacti, bushes, boulders, reeds,
//               flower patches and all the street furniture, outlined
//   buildings   pitched shingle roofs on small places and parapet roofs with rooftop kit on
//               big ones; bright facades, framed glass with glints (lit warm at night),
//               panelled doors and striped awnings
//   cars        the same treatment as characters
// Settings > Art style switches between Emerald and Classic.
'use strict';

type Ramp = string[];
interface OldLook { shirt: Ramp; pants: Ramp; skin: Ramp; hair: Ramp; jacket: Ramp | null; cap?: Ramp; shoes?: Ramp; maskCol?: Ramp; belt?: string; _key?: string; _src?: unknown; [k: string]: unknown }
interface Sprite { cv: HTMLCanvasElement; ox: number; oy: number }
interface BuildingArt { cv: HTMLCanvasElement; facadeTop: number; neon?: string }

(function () {
  const A = R.art, D = R.data, T = D.T, O = D.O, TS = R.TILE;
  const on = (): boolean => { const g = R.game; const s = g && g.settings && g.settings.art; return s ? s === 'emerald' : true; };

  // ---------------------------------------------------------------- colour
  const hexRgb = (h: string): [number, number, number] => { const n = parseInt(String(h).replace('#', '').slice(0, 6).padEnd(6, '0'), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; };
  const rgbHex = (r: number, g: number, b: number) => '#' + [r, g, b].map((v) => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0')).join('');
  const rgbHsl = (r: number, g: number, b: number): [number, number, number] => {
    r /= 255; g /= 255; b /= 255;
    const mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2;
    if (mx === mn) return [0, 0, l];
    const d = mx - mn, s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
    const h = mx === r ? (g - b) / d + (g < b ? 6 : 0) : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
    return [h * 60, s, l];
  };
  const hslHex = (h: number, s: number, l: number) => {
    h = ((h % 360) + 360) % 360; s = Math.max(0, Math.min(1, s)); l = Math.max(0, Math.min(1, l));
    const c = (1 - Math.abs(2 * l - 1)) * s, x = c * (1 - Math.abs(((h / 60) % 2) - 1)), m = l - c / 2;
    const [r, g, b] = h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x] : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x];
    return rgbHex((r + m) * 255, (g + m) * 255, (b + m) * 255);
  };
  // pull a hue toward a target by up to k degrees
  const pullHue = (h: number, target: number, k: number) => { let d = ((target - h + 540) % 360) - 180; d = Math.max(-k, Math.min(k, d)); return h + d; };
  // GBA treatment for one colour at a position in its ramp (0 = darkest)
  const gbaColour = (hex: string, t: number, skin: boolean): string => {
    const [r, g, b] = hexRgb(hex);
    let [h, s, l] = rgbHsl(r, g, b);
    const grey = s < 0.08;
    s = grey ? s : Math.min(skin ? 0.62 : 0.85, s * (skin ? 1.15 : 1.35) + 0.06);
    l = 0.5 + (l - 0.5) * 1.18 + (t - 0.5) * 0.1; // wider value range
    if (!grey) { if (t < 0.35) h = pullHue(h, 250, skin ? 8 : 18); else if (t > 0.7) h = pullHue(h, 50, skin ? 4 : 10); }
    else if (t < 0.35) { h = 240; s = 0.12; }
    return hslHex(h, s, l);
  };
  const gbaRamp = (ramp: Ramp | null | undefined, skin = false): Ramp | null => {
    if (!ramp || !Array.isArray(ramp)) return ramp || null;
    const n = ramp.length;
    return ramp.map((c, i) => (typeof c === 'string' && c[0] === '#' ? gbaColour(c, n > 1 ? i / (n - 1) : 0.5, skin) : c));
  };
  const shadeHex = (hex: string, k: number) => { const [r, g, b] = hexRgb(hex); const [h, s, l] = rgbHsl(r, g, b); return hslHex(k < 0 ? pullHue(h, 250, 14) : h, s, l + k); };

  // ---------------------------------------------------------------- a tiny pixel canvas
  class Px {
    w: number; h: number; d: (string | null)[];
    constructor(w: number, h: number) { this.w = w; this.h = h; this.d = new Array(w * h).fill(null); }
    in(x: number, y: number) { return x >= 0 && y >= 0 && x < this.w && y < this.h; }
    get(x: number, y: number) { return this.in(x, y) ? this.d[y * this.w + x] : null; }
    set(x: number, y: number, c: string | null) { x |= 0; y |= 0; if (this.in(x, y)) this.d[y * this.w + x] = c; return this; }
    rect(x: number, y: number, w: number, h: number, c: string | null) { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) this.set(x + i, y + j, c); return this; }
    hline(x0: number, x1: number, y: number, c: string) { for (let x = x0; x <= x1; x++) this.set(x, y, c); return this; }
    vline(x: number, y0: number, y1: number, c: string) { for (let y = y0; y <= y1; y++) this.set(x, y, c); return this; }
    // filled ellipse; fn(nx, ny) gets normalised coords (-1..1) and returns the colour
    oval(cx: number, cy: number, rx: number, ry: number, fn: (nx: number, ny: number, x: number, y: number) => string | null) {
      for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++) for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
        const nx = (x + 0.5 - cx) / rx, ny = (y + 0.5 - cy) / ry;
        if (nx * nx + ny * ny <= 1) { const c = fn(nx, ny, x, y); if (c) this.set(x, y, c); }
      }
      return this;
    }
    // a dark line around the silhouette (outside pixels touching inside ones)
    outline(c: string | ((x: number, y: number) => string)) {
      const add: [number, number][] = [];
      for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) {
        if (this.get(x, y)) continue;
        if (this.get(x - 1, y) || this.get(x + 1, y) || this.get(x, y - 1) || this.get(x, y + 1)) add.push([x, y]);
      }
      for (const [x, y] of add) this.set(x, y, typeof c === 'string' ? c : c(x, y));
      return this;
    }
    canvas(): HTMLCanvasElement {
      const cv = document.createElement('canvas'); cv.width = this.w; cv.height = this.h;
      const g = cv.getContext('2d') as CanvasRenderingContext2D, im = g.createImageData(this.w, this.h);
      const cache = new Map<string, [number, number, number]>();
      for (let i = 0; i < this.d.length; i++) {
        const c = this.d[i]; if (!c) continue;
        let rgb = cache.get(c); if (!rgb) { rgb = hexRgb(c); cache.set(c, rgb); }
        im.data[i * 4] = rgb[0]; im.data[i * 4 + 1] = rgb[1]; im.data[i * 4 + 2] = rgb[2]; im.data[i * 4 + 3] = 255;
      }
      g.putImageData(im, 0, 0);
      return cv;
    }
  }
  const hash = (x: number, y: number, s: number) => R.hash2(x, y, s);

  // ---------------------------------------------------------------- palette
  const P = {
    grass: ['#3a8a36', '#58aa46', '#80cc60', '#a8e888'],
    forest: ['#347a32', '#4a9840', '#6cba54', '#94d876'],
    park: ['#46a040', '#62b852', '#8ad468', '#b4ee90'],
    field: ['#9a8a38', '#b8a448', '#d6c468', '#f0e090'],
    dirt: ['#946c3c', '#b89050', '#d8b070', '#eccc90'],
    path: ['#a8844c', '#c8a468', '#e0c084', '#f4dca4'],
    sand: ['#c8ac70', '#e0c888', '#f4e4a8', '#fff6d4'],
    desert: ['#b88c48', '#d4ac60', '#eccc80', '#f8e4a8'],
    snow: ['#a8b8d4', '#c8d6ea', '#e6eef8', '#fafcff'],
    marsh: ['#3e7040', '#548a4c', '#6ca860', '#90c878'],
    rock: ['#6a4830', '#9a7050', '#c09870', '#e0bc94'],
    water: ['#2e60c0', '#3e80e0', '#5aa0f0', '#8cc4f8', '#d4ecff'],
    deep: ['#2658b8', '#3470d4', '#4a90e8', '#78b4f4', '#c4e4ff'],
    burnt: ['#2e2824', '#403830', '#5a5048', '#766a60'],
    asphalt: ['#50505a', '#606068', '#707078', '#84848c'],
    parking: ['#5c5c64', '#6c6c74', '#7c7c84', '#8e8e96'],
    walk: ['#a8a090', '#cfc6b8', '#e8e0d4', '#f8f2ea'],
    plaza: ['#a86844', '#c08058', '#d89c70', '#ecb88c'],
    dock: ['#6a4428', '#8a5c34', '#b07c48', '#cc9a60', '#e4b87c'],
    lot: ['#8e7040', '#ac8a50', '#c8a466', '#dcbc80'],
  };
  const INK = '#243040';

  // ---------------------------------------------------------------- characters
  const looksE = new WeakMap<object, OldLook>(); // kept off the look so saves don't carry it
  const baseOldLook = A.oldLook as (look: any) => OldLook;
  A.oldLook = function (look: any): OldLook {
    const L = baseOldLook.call(this, look);
    if (!on()) return L;
    const had = looksE.get(look);
    if (had && had._src === L) return had;
    const E: OldLook = Object.assign({}, L);
    for (const k of ['shirt', 'pants', 'hair', 'jacket', 'cap', 'shoes', 'maskCol'] as const) if (Array.isArray(L[k])) (E as any)[k] = gbaRamp(L[k] as Ramp);
    E.skin = gbaRamp(L.skin, true) as Ramp;
    if (typeof L.belt === 'string' && L.belt[0] === '#') E.belt = gbaColour(L.belt, 0.2, false);
    // the hair gets a shine: a lifted top tone
    if (Array.isArray(E.hair) && E.hair.length >= 4) E.hair = [E.hair[0], E.hair[1], E.hair[2], shadeHex(E.hair[3], 0.1)];
    E._key = undefined;
    Object.defineProperty(E, '_src', { value: L, enumerable: false });
    looksE.set(look, E);
    return E;
  };
  // ---------------------------------------------------------------- ground
  const tileCache = new Map<string, HTMLCanvasElement>();
  const tuft = (p: Px, x: number, y: number, pal: Ramp) => { p.set(x, y + 1, pal[1]); p.set(x + 1, y, pal[1]); p.set(x + 2, y + 1, pal[1]); p.set(x + 1, y + 1, pal[0]); p.set(x + 1, y - 1, pal[3]); };
  const flower = (p: Px, x: number, y: number, petal: string) => { p.set(x, y - 1, petal); p.set(x - 1, y, petal); p.set(x + 1, y, petal); p.set(x, y + 1, petal); p.set(x, y, '#f8e060'); };
  type Ground = (p: Px, v: number) => void;
  const G: Record<number, Ground> = {};
  const fill = (p: Px, c: string) => p.rect(0, 0, 16, 16, c);
  G[T.GRASS] = (p, v) => { fill(p, P.grass[2]); const r = R.mulberry(v * 97 + 1); for (let k = 0; k < 3; k++) tuft(p, 1 + ((r() * 12) | 0), 2 + ((r() * 11) | 0), P.grass); if (v % 11 === 0) flower(p, 4 + ((r() * 8) | 0), 4 + ((r() * 8) | 0), v % 2 ? '#f86858' : '#ffffff'); for (let k = 0; k < 4; k++) p.set((r() * 16) | 0, (r() * 16) | 0, P.grass[3]); };
  G[T.PARK] = (p, v) => { fill(p, P.park[2]); const r = R.mulberry(v * 71 + 3); for (let k = 0; k < 2; k++) tuft(p, 1 + ((r() * 12) | 0), 2 + ((r() * 11) | 0), P.park); if (v % 5 === 0) flower(p, 4 + ((r() * 8) | 0), 4 + ((r() * 8) | 0), ['#f86858', '#f8d040', '#ffffff', '#f890d8'][v % 4]); };
  G[T.FOREST] = (p, v) => { fill(p, P.forest[2]); const r = R.mulberry(v * 53 + 5); for (let k = 0; k < 5; k++) tuft(p, 1 + ((r() * 12) | 0), 2 + ((r() * 11) | 0), P.forest); for (let k = 0; k < 3; k++) p.set((r() * 16) | 0, (r() * 16) | 0, '#8a6a3a'); };
  G[T.FIELD] = (p, v) => { fill(p, P.field[2]); for (let y = 1; y < 16; y += 4) { p.hline(0, 15, y, P.field[1]); p.hline(0, 15, y + 1, P.field[3]); } const r = R.mulberry(v + 9); for (let k = 0; k < 4; k++) p.set((r() * 16) | 0, ((r() * 4) | 0) * 4 + 3, P.field[0]); };
  G[T.DIRT] = (p, v) => { fill(p, P.dirt[2]); const r = R.mulberry(v * 31 + 7); for (let k = 0; k < 3; k++) { const x = 1 + ((r() * 13) | 0), y = 1 + ((r() * 13) | 0); p.set(x, y, P.dirt[1]); p.set(x + 1, y, P.dirt[1]); p.set(x, y - 1, P.dirt[3]); } };
  G[T.LOT] = (p, v) => { fill(p, P.lot[2]); const r = R.mulberry(v * 29 + 3); for (let k = 0; k < 3; k++) { const x = 1 + ((r() * 13) | 0), y = 1 + ((r() * 13) | 0); p.set(x, y, P.lot[1]); p.set(x, y - 1, P.lot[3]); } if (v % 3 === 0) tuft(p, 3 + ((r() * 9) | 0), 4 + ((r() * 8) | 0), P.grass); };
  G[T.SITE] = (p, v) => { G[T.DIRT](p, v); if (v % 2 === 0) { p.rect(2, 9, 12, 2, '#c89058'); p.hline(2, 13, 9, '#e8b078'); p.hline(2, 13, 11, '#7a5030'); } };
  G[T.DIRTROAD] = (p, v) => { fill(p, P.path[2]); const r = R.mulberry(v * 43 + 11); for (let k = 0; k < 3; k++) { const x = 1 + ((r() * 13) | 0), y = 1 + ((r() * 13) | 0); p.set(x, y, P.path[1]); p.set(x, y - 1, P.path[3]); } };
  G[T.SAND] = (p, v) => { fill(p, P.sand[2]); const r = R.mulberry(v * 17 + 13); for (let k = 0; k < 5; k++) p.set((r() * 16) | 0, (r() * 16) | 0, k < 3 ? P.sand[1] : P.sand[3]); if (v % 13 === 0) { p.set(8, 8, '#f8a8a8'); p.set(9, 8, '#f8c8c8'); } };
  G[T.DESERT] = (p, v) => { fill(p, P.desert[2]); const o = v % 5; for (let y = 2; y < 16; y += 5) for (let x = 0; x < 16; x++) { const yy = y + Math.round(Math.sin((x + o * 3) * 0.55)); p.set(x, yy, P.desert[1]); p.set(x, yy - 1, P.desert[3]); } };
  G[T.SNOW] = (p, v) => { fill(p, P.snow[2]); const r = R.mulberry(v * 61 + 17); for (let k = 0; k < 4; k++) { const x = 1 + ((r() * 13) | 0), y = 1 + ((r() * 13) | 0); p.set(x, y, P.snow[1]); p.set(x + 1, y, P.snow[1]); p.set(x, y - 1, P.snow[3]); } if (v % 7 === 0) p.set(5, 5, '#ffffff'); };
  G[T.MARSH] = (p, v) => { fill(p, P.marsh[2]); const r = R.mulberry(v * 13 + 19); if (v % 3 === 0) { p.oval(8, 9, 5, 3, (nx, ny) => (ny < -0.4 ? '#88c0e0' : '#5c98c8')); p.hline(5, 10, 11, P.marsh[0]); } for (let k = 0; k < 3; k++) tuft(p, 1 + ((r() * 12) | 0), 2 + ((r() * 11) | 0), P.marsh); };
  G[T.ROCK] = (p, v) => { fill(p, P.rock[2]); const r = R.mulberry(v * 83 + 23); for (let k = 0; k < 2; k++) { const x = 1 + ((r() * 10) | 0), y = 2 + ((r() * 10) | 0); p.hline(x, x + 3, y, P.rock[1]); p.set(x + 3, y + 1, P.rock[1]); p.hline(x, x + 2, y - 1, P.rock[3]); } p.set((r() * 16) | 0, (r() * 16) | 0, P.rock[0]); };
  G[T.BURNT] = (p, v) => { fill(p, P.burnt[2]); const r = R.mulberry(v * 7 + 29); for (let k = 0; k < 6; k++) p.set((r() * 16) | 0, (r() * 16) | 0, k < 4 ? P.burnt[1] : P.burnt[3]); if (v % 4 === 0) p.set(6 + ((r() * 4) | 0), 6 + ((r() * 4) | 0), '#e86030'); };
  G[T.WATER] = (p, v) => { fill(p, P.water[2]); const o = v % 4; for (const [x, y] of [[2 + o, 4], [9 - o, 10]]) { p.hline(x, x + 3, y, P.water[3]); p.set(x + 1, y - 1, P.water[4]); } };
  G[T.DEEP] = (p, v) => { fill(p, P.deep[2]); const o = v % 4; p.hline(3 + o, 6 + o, 6, P.deep[3]); p.hline(10 - o, 12 - o, 12, P.deep[3]); };
  G[T.WALK] = (p) => { fill(p, P.walk[2]); p.hline(0, 15, 7, P.walk[1]); p.hline(0, 15, 15, P.walk[1]); p.vline(7, 0, 6, P.walk[1]); p.vline(15, 8, 15, P.walk[1]); p.hline(0, 6, 0, P.walk[3]); p.hline(8, 14, 8, P.walk[3]); p.vline(0, 1, 6, P.walk[3]); p.vline(8, 9, 14, P.walk[3]); };
  G[T.PLAZA] = (p) => { fill(p, P.plaza[2]); for (let y = 0; y < 16; y += 4) { p.hline(0, 15, y + 3, P.plaza[1]); const off = (y / 4) % 2 ? 4 : 0; for (let x = off; x < 16; x += 8) p.vline(x, y, y + 2, P.plaza[1]); p.hline(0, 15, y, P.plaza[3]); } };
  G[T.DOCK] = (p) => { fill(p, P.dock[2]); for (let y = 0; y < 16; y += 4) { p.hline(0, 15, y + 3, P.dock[0]); p.hline(0, 15, y, P.dock[3]); } for (const [x, y] of [[3, 1], [12, 1], [7, 5], [2, 9], [11, 13]]) p.set(x, y, P.dock[1]); };
  G[T.PARKING] = (p, v) => { fill(p, P.parking[2]); const r = R.mulberry(v * 5 + 31); for (let k = 0; k < 6; k++) p.set((r() * 16) | 0, (r() * 16) | 0, k % 2 ? P.parking[1] : P.parking[3]); if (v % 2 === 0) p.vline(0, 2, 13, '#e8e8e8'); };
  const asphalt: Ground = (p, v) => { fill(p, P.asphalt[2]); const r = R.mulberry(v * 3 + 37); for (let k = 0; k < 7; k++) p.set((r() * 16) | 0, (r() * 16) | 0, k % 3 ? P.asphalt[1] : P.asphalt[3]); };
  const VARS: Record<number, number> = { [T.GRASS]: 22, [T.PARK]: 10, [T.FOREST]: 8, [T.FIELD]: 3, [T.DIRT]: 6, [T.LOT]: 6, [T.SITE]: 4, [T.DIRTROAD]: 6, [T.SAND]: 13, [T.DESERT]: 5, [T.SNOW]: 7, [T.MARSH]: 6, [T.ROCK]: 6, [T.BURNT]: 4, [T.WATER]: 4, [T.DEEP]: 4, [T.WALK]: 1, [T.PLAZA]: 1, [T.DOCK]: 1, [T.PARKING]: 2 };
  const groundCanvas = (t: number, v: number): HTMLCanvasElement => {
    const key = t + ':' + v;
    let c = tileCache.get(key);
    if (!c) { const p = new Px(16, 16); (G[t] || asphalt)(p, v); c = p.canvas(); tileCache.set(key, c); }
    return c;
  };
  const isWater = (t: number) => t === T.WATER || t === T.DEEP;
  const GREENS = new Set([T.GRASS, T.PARK, T.FOREST, T.FIELD, T.MARSH]);
  const PATHS = new Set([T.DIRT, T.DIRTROAD, T.LOT, T.SAND, T.DESERT, T.SITE]);
  // edges: water foam, grass fringe over paths, cliff lips under rock, wet sand
  const edges = (g: CanvasRenderingContext2D, w: World, x: number, y: number, px: number, py: number, t: number) => {
    const n = w.t(x, y - 1), s = w.t(x, y + 1), e = w.t(x + 1, y), wv = w.t(x - 1, y);
    const r = (xx: number, yy: number, ww: number, hh: number, c: string) => { g.fillStyle = c; g.fillRect(px + xx, py + yy, ww, hh); };
    if (isWater(t)) {
      const land = (q: number) => !isWater(q) && q !== T.BRIDGE && q < T.VOID;
      if (land(n)) { r(0, 0, 16, 1, '#f4faff'); r(0, 1, 16, 1, P.water[3]); }
      if (land(s)) { r(0, 15, 16, 1, '#f4faff'); r(0, 14, 16, 1, P.water[3]); }
      if (land(e)) { r(15, 0, 1, 16, '#f4faff'); r(14, 0, 1, 16, P.water[3]); }
      if (land(wv)) { r(0, 0, 1, 16, '#f4faff'); r(1, 0, 1, 16, P.water[3]); }
      return;
    }
    if (t === T.SAND) {
      if (isWater(n)) r(0, 0, 16, 2, P.sand[1]);
      if (isWater(s)) r(0, 14, 16, 2, P.sand[1]);
      if (isWater(e)) r(14, 0, 2, 16, P.sand[1]);
      if (isWater(wv)) r(0, 0, 2, 16, P.sand[1]);
    }
    if (PATHS.has(t)) {
      const dark = t === T.SAND ? P.sand[1] : t === T.DESERT ? P.desert[1] : P.dirt[1];
      const fr = (q: number) => GREENS.has(q);
      if (fr(n)) { r(0, 0, 16, 1, dark); for (let k = 1; k < 16; k += 4) r(k, 1, 2, 1, P.grass[1]); }
      if (fr(s)) r(0, 15, 16, 1, dark);
      if (fr(e)) r(15, 0, 1, 16, dark);
      if (fr(wv)) r(0, 0, 1, 16, dark);
    }
    if (t === T.ROCK && s !== T.ROCK && s < T.VOID) { r(0, 12, 16, 2, P.rock[1]); r(0, 14, 16, 2, P.rock[0]); for (let k = 2; k < 16; k += 5) r(k, 12, 1, 3, P.rock[0]); }
    if (t === T.SNOW && s !== T.SNOW && s < T.VOID) r(0, 15, 16, 1, P.snow[1]);
    if (t === T.WALK || t === T.PARKING) {
      const rd = (q: number) => D.roadTile[q];
      if (rd(s)) { r(0, 13, 16, 1, '#ffffff'); r(0, 14, 16, 2, '#8a8478'); }
      if (rd(n)) { r(0, 0, 16, 1, '#8a8478'); r(0, 1, 16, 1, '#ffffff'); }
      if (rd(e)) { r(14, 0, 1, 16, '#ffffff'); r(15, 0, 1, 16, '#8a8478'); }
      if (rd(wv)) { r(0, 0, 1, 16, '#8a8478'); r(1, 0, 1, 16, '#ffffff'); }
    }
  };
  const baseTile = A.drawTile as (g: CanvasRenderingContext2D, w: World, x: number, y: number, px: number, py: number) => void;
  A.drawTile = function (g: CanvasRenderingContext2D, w: World, x: number, y: number, px: number, py: number) {
    const t = w.t(x, y);
    if (!on() || t >= T.VOID || t === T.BLDG || t === T.BRIDGE) return baseTile.call(this, g, w, x, y, px, py);
    if (t === T.ROAD || t === T.HWY) {
      g.drawImage(groundCanvas(-1, Math.floor(hash(x, y, 21) * 1e6) % 6), px, py);
      return A.drawRoad(g, w, x, y, px, py, t, true);
    }
    const nv = VARS[t];
    if (nv == null) return baseTile.call(this, g, w, x, y, px, py);
    g.drawImage(groundCanvas(t, Math.floor(hash(x, y, 20) * 1e6) % nv), px, py);
    edges(g, w, x, y, px, py, t);
  };

  // ---------------------------------------------------------------- objects
  const objCache = new Map<string, Sprite>();
  const sprite = (key: string, w: number, h: number, ox: number, oy: number, paint: (p: Px) => void): Sprite => {
    let s = objCache.get(key);
    if (!s) { const p = new Px(w, h); paint(p); s = { cv: p.canvas(), ox, oy }; objCache.set(key, s); }
    return s;
  };
  const lit = (nx: number, ny: number) => -nx * 0.55 - ny * 0.75; // light from the top-left
  const TREE_PALS: Ramp[] = [['#1c4a24', '#2e7a34', '#48a048', '#6cc458', '#a4e484'], ['#244a1c', '#3a7a2a', '#58a03c', '#84c450', '#c0e888'], ['#1a4232', '#2a6c4a', '#40925c', '#62b478', '#9cdcac']];
  const tree = (v: number, snow: boolean) => sprite(`tree${v}${snow ? 's' : ''}`, 24, 30, -4, -14, (p) => {
    const pal = TREE_PALS[v % 3];
    // trunk
    p.rect(10, 20, 4, 9, '#8a5a34'); p.vline(10, 20, 28, '#b07848'); p.vline(13, 20, 28, '#5a3a20');
    p.hline(9, 14, 28, '#5a3a20');
    // canopy: lobes, shaded from the top-left, with leaf clumps
    const lobes: [number, number, number][] = [[12, 12, 9.5], [6.5, 15, 5.5], [17.5, 15, 5.5], [12, 6.5, 6.5], [8, 9, 5], [16, 9, 5]];
    for (const [cx, cy, rr] of lobes) p.oval(cx, cy, rr, rr * 0.92, (nx, ny, x, y) => {
      const L = lit(nx, ny) + (cy - 12) * -0.02;
      return L > 0.55 ? pal[4] : L > 0.15 ? pal[3] : L > -0.35 ? pal[2] : pal[1];
    });
    // leaf clump arcs
    const r = R.mulberry(v * 13 + 5);
    for (let k = 0; k < 9; k++) { const x = 5 + ((r() * 14) | 0), y = 4 + ((r() * 14) | 0); if (p.get(x, y) && p.get(x, y - 2)) { p.set(x, y, pal[1]); p.set(x + 1, y, pal[1]); p.set(x, y - 1, pal[3]); } }
    if (snow) for (let x = 3; x < 22; x++) for (let y = 0; y < 14; y++) if (p.get(x, y) && !p.get(x, y - 1)) { p.set(x, y, '#f4f8fc'); p.set(x, y + 1, '#d0dcec'); break; }
    p.outline('#123a1c');
  });
  const pine = (v: number, snow: boolean) => sprite(`pine${v}${snow ? 's' : ''}`, 20, 32, -2, -16, (p) => {
    const pal = v % 2 ? ['#123a26', '#1e5a38', '#2e7a48', '#48a060', '#78c888'] : ['#143428', '#205240', '#2e7050', '#468e66', '#72b890'];
    p.rect(8, 25, 4, 6, '#7a4c2c'); p.vline(8, 25, 30, '#a06a40');
    for (let k = 0; k < 4; k++) {
      const top = 2 + k * 6, bot = top + 9, half = 3 + k * 2;
      for (let y = top; y <= bot; y++) {
        const f = (y - top) / (bot - top), wdt = Math.round(1 + f * half);
        for (let x = 10 - wdt; x <= 9 + wdt; x++) {
          const side = (x - 9.5) / (wdt + 0.5);
          p.set(x, y, y === bot ? pal[1] : side < -0.4 ? pal[4] : side < 0.1 ? pal[3] : side < 0.6 ? pal[2] : pal[1]);
        }
      }
      if (snow) for (let x = 10 - Math.round(1 + half * 0.4); x <= 9 + Math.round(1 + half * 0.4); x++) p.set(x, top + 3, '#f4f8fc');
    }
    p.outline('#0c2a1a');
  });
  const palm = (v: number) => sprite(`palm${v}`, 24, 32, -4, -16, (p) => {
    for (let y = 10; y < 31; y++) { const x = 11 + Math.round(Math.sin(y * 0.18) * 1.5); p.rect(x, y, 3, 1, (y % 3) ? '#b08050' : '#8a5c34'); p.set(x, y, '#d0a070'); }
    const fr: [number, number, number, number][] = [[12, 9, -9, 4], [12, 9, 9, 4], [12, 9, -6, -3], [12, 9, 6, -3], [12, 9, 0, -6]];
    for (const [x0, y0, dx, dy] of fr) for (let k = 0; k <= 10; k++) { const t2 = k / 10, x = Math.round(x0 + dx * t2), y = Math.round(y0 + dy * t2 + t2 * t2 * 4); p.set(x, y, '#58b848'); p.set(x, y + 1, '#3c8c38'); if (k % 3 === 0) p.set(x, y - 1, '#90e070'); }
    p.oval(12, 9, 2, 2, () => '#6a4428');
    p.outline('#1e3a1c');
  });
  const cactus = (v: number) => sprite(`cactus${v}`, 16, 22, 0, -6, (p) => {
    const C = ['#2a6a2a', '#3e8c3a', '#58a850', '#84cc70'];
    const col = (x0: number, y0: number, w: number, h: number) => { for (let y = y0; y < y0 + h; y++) for (let x = x0; x < x0 + w; x++) p.set(x, y, x === x0 ? C[3] : x === x0 + w - 1 ? C[1] : C[2]); };
    col(6, 2, 4, 19); col(2, 7, 3, 6); p.rect(2, 12, 5, 2, C[2]); col(11, 5, 3, 7); p.rect(9, 11, 4, 2, C[2]);
    for (const [x, y] of [[7, 5], [8, 9], [7, 13], [8, 17], [3, 9], [12, 7]]) p.set(x, y, '#e8f4c8');
    if (v % 3 === 0) { p.set(7, 1, '#f878b8'); p.set(8, 1, '#f878b8'); p.set(7, 0, '#ffb8e0'); }
    p.outline('#1a3e1c');
  });
  const bush = (v: number) => sprite(`bush${v}`, 18, 14, -1, 3, (p) => {
    const pal = TREE_PALS[(v + 1) % 3];
    for (const [cx, cy, rr] of [[9, 7, 6.5], [4.5, 9, 3.5], [13.5, 9, 3.5]] as [number, number, number][]) p.oval(cx, cy, rr, rr * 0.9, (nx, ny) => { const L = lit(nx, ny); return L > 0.45 ? pal[4] : L > 0 ? pal[3] : L > -0.4 ? pal[2] : pal[1]; });
    if (v % 3 === 0) for (const [x, y] of [[6, 6], [11, 8], [8, 10]]) { p.set(x, y, '#e83838'); p.set(x, y - 1, '#ff8878'); }
    p.outline('#123a1c');
  });
  const boulder = (v: number) => sprite(`boulder${v}`, 18, 16, -1, 1, (p) => {
    const C = ['#5c5650', '#7c746c', '#a8a098', '#d0c8c0', '#ece6e0'];
    p.oval(9, 9, 7.5, 5.5, (nx, ny) => { const L = lit(nx, ny); return L > 0.5 ? C[4] : L > 0.1 ? C[3] : L > -0.4 ? C[2] : C[1]; });
    p.oval(5.5, 11, 3.5, 3, (nx, ny) => (lit(nx, ny) > 0.3 ? C[3] : C[2]));
    if (v % 2) { p.set(10, 8, C[0]); p.set(11, 9, C[0]); p.set(12, 9, C[1]); }
    p.outline('#2e2a2a');
  });
  const flowers = (v: number) => sprite(`flowers${v}`, 16, 16, 0, 0, (p) => {
    const petals = [['#f85848', '#ffa090'], ['#f8c830', '#fff098'], ['#f070c8', '#ffb8e8'], ['#ffffff', '#e0e8f8']];
    const r = R.mulberry(v * 7 + 1);
    for (let k = 0; k < 4; k++) {
      const x = 2 + ((k % 2) * 7) + ((r() * 3) | 0), y = 3 + (k > 1 ? 7 : 0) + ((r() * 2) | 0), pc = petals[(v + k) % 4];
      p.set(x, y + 3, '#3e8a36'); p.set(x - 1, y + 4, '#58aa46'); p.set(x + 1, y + 4, '#58aa46');
      p.set(x, y - 1, pc[1]); p.set(x - 1, y, pc[0]); p.set(x + 1, y, pc[0]); p.set(x, y + 1, pc[0]); p.set(x, y, '#f8e060');
    }
    p.outline('#1e4a22');
  });
  const reed = (v: number) => sprite(`reed${v}`, 16, 20, 0, -4, (p) => {
    const stems: [number, number][] = [[3, 6], [6, 3], [9, 7], [12, 4]];
    for (let k = 0; k < stems.length; k++) {
      const [x, top] = stems[(k + v) % stems.length];
      const lean = k % 2 ? 1 : 0;
      for (let y = top; y < 20; y++) p.set(x + (y < top + 4 ? lean : 0), y, y > 16 ? '#4a7a2c' : '#78a840');
      if (k % 2 === 0) { p.set(x, top - 1, '#6a3e1e'); p.set(x, top - 2, '#8a5430'); p.set(x, top - 3, '#8a5430'); p.set(x + 1, top - 2, '#5a3218'); }
      p.set(x - 1, 17, '#5a8a34'); p.set(x + 1, 18, '#5a8a34');
    }
  });
  const deadtree = () => sprite('dead', 20, 26, -2, -10, (p) => {
    const C = ['#4a3a2e', '#6a5444', '#8a7058', '#a88c70'];
    p.rect(9, 6, 3, 20, C[2]); p.vline(9, 6, 25, C[3]); p.vline(11, 6, 25, C[1]);
    for (const [x0, y0, x1, y1] of [[10, 12, 3, 6], [10, 9, 17, 3], [10, 16, 16, 12], [4, 7, 3, 3], [16, 5, 18, 2]] as [number, number, number, number][]) { const n = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0)); for (let k = 0; k <= n; k++) p.set(Math.round(x0 + (x1 - x0) * k / n), Math.round(y0 + (y1 - y0) * k / n), C[2]); }
    p.outline('#261c16');
  });
  const stump = () => sprite('stump', 16, 12, 0, 5, (p) => { p.rect(3, 4, 10, 6, '#8a5a34'); p.vline(3, 4, 9, '#b07848'); p.oval(8, 4, 5, 2.4, (nx, ny) => (nx * nx + ny * ny < 0.3 ? '#b88048' : '#e0b070')); p.set(8, 4, '#8a5a34'); p.outline('#3a2414'); });
  const lamp = () => sprite('lamp', 10, 30, 3, -14, (p) => {
    p.rect(4, 7, 2, 21, '#6a7282'); p.vline(4, 7, 27, '#9aa2b2'); p.rect(2, 27, 6, 2, '#4a5262');
    p.rect(1, 2, 8, 5, '#f8f0c0'); p.hline(1, 8, 2, '#fffbe8'); p.rect(2, 0, 6, 2, '#4a5262'); p.hline(1, 8, 6, '#c8b870');
    p.outline('#1c2230');
  });
  const hydrant = () => sprite('hydrant', 12, 14, 2, 2, (p) => { const C = ['#7a1818', '#b02820', '#e84838', '#ff8870']; p.rect(3, 3, 6, 9, C[2]); p.vline(3, 3, 11, C[3]); p.vline(8, 3, 11, C[1]); p.oval(6, 3, 3, 2, (nx, ny) => (ny < 0 ? C[3] : C[2])); p.rect(1, 6, 2, 2, C[1]); p.rect(9, 6, 2, 2, C[1]); p.rect(2, 12, 8, 1, C[0]); p.outline('#3a0e0e'); });
  const phone = () => sprite('phone', 14, 26, 1, -10, (p) => {
    p.rect(1, 2, 12, 23, '#3a68c8'); p.vline(1, 2, 24, '#6a98e8'); p.vline(12, 2, 24, '#244898');
    p.rect(3, 6, 8, 14, '#a8d8f8'); p.set(4, 7, '#ffffff'); p.set(5, 8, '#ffffff'); p.rect(5, 12, 4, 4, '#2a2a30');
    p.rect(1, 0, 12, 3, '#e84838'); p.hline(2, 11, 0, '#ff8870'); p.outline('#141e3a');
  });
  const bench = () => sprite('bench', 18, 14, -1, 3, (p) => { const W = ['#7a4a24', '#9a6034', '#c88850', '#e8a868']; p.rect(1, 2, 16, 2, W[2]); p.hline(1, 16, 2, W[3]); p.rect(1, 6, 16, 3, W[2]); p.hline(1, 16, 6, W[3]); p.hline(1, 16, 8, W[1]); p.rect(2, 9, 2, 4, '#404850'); p.rect(14, 9, 2, 4, '#404850'); p.rect(2, 4, 1, 2, '#404850'); p.rect(15, 4, 1, 2, '#404850'); p.outline('#2e1c10'); });
  const fence = (mask: number) => sprite(`fence${mask}`, 16, 14, 0, 1, (p) => {
    const C = ['#9a8e7c', '#c8c0b0', '#f0ece2', '#ffffff'];
    const l = mask & 1 ? 0 : 3, r2 = mask & 2 ? 15 : 12;
    p.rect(l, 5, r2 - l + 1, 2, C[2]); p.hline(l, r2, 5, C[3]); p.rect(l, 9, r2 - l + 1, 2, C[2]); p.hline(l, r2, 10, C[1]);
    for (const x of [3, 7, 11]) { p.rect(x, 1, 2, 12, C[2]); p.set(x, 1, C[3]); p.vline(x + 1, 2, 12, C[1]); }
    p.outline('#4a4438');
  });
  const pump = () => sprite('pump', 14, 22, 1, -6, (p) => { p.rect(2, 3, 10, 18, '#e84838'); p.vline(2, 3, 20, '#ff8870'); p.vline(11, 3, 20, '#b02820'); p.rect(4, 6, 6, 4, '#202830'); p.rect(5, 7, 4, 2, '#78f0a0'); p.rect(3, 0, 8, 3, '#f0f0f0'); p.rect(12, 9, 2, 6, '#303840'); p.outline('#3a0e0e'); });
  const trash = () => sprite('trash', 14, 16, 1, 1, (p) => { const C = ['#50586a', '#7a8494', '#a0a8b8', '#ccd4e0']; p.rect(2, 4, 10, 11, C[2]); for (const x of [4, 7, 10]) p.vline(x, 5, 14, C[1]); p.vline(2, 4, 14, C[3]); p.rect(1, 2, 12, 2, C[2]); p.hline(1, 12, 2, C[3]); p.rect(6, 1, 2, 1, C[1]); p.outline('#20242c'); });
  const barrel = () => sprite('barrel', 14, 16, 1, 1, (p) => { const C = ['#5a3418', '#7e4c28', '#a86a3c', '#d09060']; p.rect(2, 2, 10, 13, C[2]); p.vline(2, 2, 14, C[3]); p.vline(11, 2, 14, C[1]); for (const y of [4, 12]) p.hline(2, 11, y, '#50586a'); p.oval(7, 2, 5, 1.5, () => C[3]); p.outline('#2a1608'); });
  const cone = () => sprite('cone', 12, 14, 2, 3, (p) => { for (let y = 1; y < 11; y++) { const wd = 1 + Math.floor(y / 2.5); for (let x = 6 - wd; x < 6 + wd; x++) p.set(x, y, x < 6 - wd / 2 ? '#ffa060' : x > 6 + wd / 3 ? '#c85010' : '#f07820'); } p.hline(3, 8, 6, '#ffffff'); p.rect(1, 11, 10, 2, '#c85010'); p.outline('#4a1a04'); });
  const mailbox = () => sprite('mailbox', 14, 18, 1, -2, (p) => { const C = ['#1c3a88', '#2e58b0', '#3e70d0', '#78a8f0']; p.rect(2, 5, 10, 8, C[2]); p.oval(7, 5, 5, 3, (nx, ny) => (ny < -0.2 ? C[3] : C[2])); p.vline(2, 5, 12, C[3]); p.vline(11, 5, 12, C[1]); p.rect(3, 13, 2, 4, C[0]); p.rect(9, 13, 2, 4, C[0]); p.hline(4, 9, 8, '#e8e8f0'); p.outline('#0e1a40'); });
  const crate = () => sprite('crate', 16, 16, 0, 0, (p) => { const W = ['#6a4424', '#9a6a3c', '#c28c58', '#e0ac78']; p.rect(2, 3, 12, 11, W[2]); p.hline(2, 13, 3, W[3]); p.vline(2, 3, 13, W[3]); p.hline(2, 13, 13, W[1]); p.vline(13, 3, 13, W[1]); for (let k = 0; k < 10; k++) p.set(3 + k, 4 + k, W[1]); p.hline(3, 12, 8, W[1]); p.outline('#2e1a0c'); });
  const signpost = () => sprite('sign', 16, 20, 0, -4, (p) => { const W = ['#6a4424', '#9a6a3c', '#c28c58', '#e0ac78']; p.rect(7, 10, 2, 9, W[1]); p.rect(1, 2, 14, 8, W[2]); p.hline(1, 14, 2, W[3]); p.hline(1, 14, 9, W[1]); for (const y of [4, 6]) p.hline(3, 12, y, W[0]); p.outline('#2e1a0c'); });

  const baseObj = A.drawObj as (g: CanvasRenderingContext2D, o: number, px: number, py: number, x: number, y: number, w: World) => void;
  const shadowUnder = (g: CanvasRenderingContext2D, x: number, y: number, rx: number, ry: number) => { g.fillStyle = 'rgba(24,40,24,0.28)'; g.beginPath(); g.ellipse(x, y, rx, ry, 0, 0, 7); g.fill(); };
  A.drawObj = function (g: CanvasRenderingContext2D, o: number, px: number, py: number, x: number, y: number, w: World) {
    if (!on() || o >= O.COUNTER || w.t(x, y) >= T.VOID) return baseObj.call(this, g, o, px, py, x, y, w);
    const v = Math.floor(hash(x, y, 5) * 1e6);
    const snow = w.t(x, y) === T.SNOW;
    let s: Sprite | null = null;
    switch (o) {
      case O.TREE: shadowUnder(g, px + 9, py + 14, 9, 4); s = tree(v % 3, snow); break;
      case O.PINE: shadowUnder(g, px + 8, py + 15, 7, 3); s = pine(v % 2, snow); break;
      case O.PALM: shadowUnder(g, px + 9, py + 15, 6, 2); s = palm(v % 2); break;
      case O.CACTUS: shadowUnder(g, px + 8, py + 15, 5, 2); s = cactus(v % 3); break;
      case O.BUSH: s = bush(v % 3); break;
      case O.BOULDER: shadowUnder(g, px + 9, py + 15, 7, 2); s = boulder(v % 2); break;
      case O.FLOWERS: s = flowers(v % 4); break;
      case O.REED: s = reed(v % 3); break;
      case O.DEADTREE: s = deadtree(); break;
      case O.STUMP: s = stump(); break;
      case O.LAMP: s = lamp(); break;
      case O.HYDRANT: s = hydrant(); break;
      case O.PHONE: s = phone(); break;
      case O.BENCH: s = bench(); break;
      case O.FENCE: s = fence((w.o(x - 1, y) === O.FENCE ? 1 : 0) | (w.o(x + 1, y) === O.FENCE ? 2 : 0)); break;
      case O.PUMP: s = pump(); break;
      case O.TRASH: s = trash(); break;
      case O.BARREL: s = barrel(); break;
      case O.CONE: s = cone(); break;
      case O.MAILBOX: s = mailbox(); break;
      case O.CRATE: s = crate(); break;
      case O.SIGNPOST: s = signpost(); break;
    }
    if (!s) return baseObj.call(this, g, o, px, py, x, y, w);
    g.drawImage(s.cv, px + s.ox, py + s.oy);
  };

  // ---------------------------------------------------------------- buildings
  const ROOF: Record<string, Ramp> = {
    red: ['#5a1a12', '#8a2a1e', '#c0402e', '#e86a50', '#ffa080'],
    blue: ['#16285a', '#243e86', '#3860b8', '#5a88e0', '#98c0f8'],
    green: ['#143e24', '#1e5a34', '#2e804a', '#4aa868', '#88d49c'],
    teal: ['#123e48', '#1a5a68', '#287c8c', '#44a2b0', '#84d0d8'],
    brown: ['#3e2410', '#5e3a1c', '#84542c', '#a87444', '#d0a070'],
    purple: ['#2e1648', '#48246e', '#6a3a9c', '#9060c8', '#c098ec'],
    slate: ['#2a2e38', '#3e4450', '#5a6270', '#7c8494', '#b0b8c4'],
  };
  const FLAT: Record<string, Ramp> = {
    grey: ['#4a4e56', '#6a6e78', '#8c9098', '#aeb2ba', '#d4d8de'],
    sand: ['#6a5a40', '#8e7c5a', '#b09c78', '#cebc96', '#ecdcb8'],
    white: ['#7c8490', '#a8b0bc', '#ccd2da', '#e8ecf0', '#ffffff'],
    blue: ['#1e3050', '#2e4a74', '#46689a', '#6a8cc0', '#a0c0e8'],
    maroon: ['#3a121a', '#5a1e2a', '#80304a', '#a84868', '#d880a0'],
    purple: ['#26143e', '#3c2262', '#583690', '#7e58be', '#b890e8'],
  };
  const WALL: Record<string, Ramp> = {
    cream: ['#8a7a60', '#c8b898', '#eee0c0', '#fff8e8'],
    white: ['#8898a0', '#c8d0d8', '#eef2f4', '#ffffff'],
    brick: ['#5a2418', '#8a3c2a', '#b85a3c', '#d87c58'],
    wood: ['#5a3a1e', '#8a5e34', '#b88450', '#d8a470'],
    blue: ['#34465a', '#566e88', '#86a0bc', '#b4cce0'],
    mint: ['#3a6a5a', '#5a9a84', '#8cc8b0', '#c0ecdc'],
    pink: ['#8a4a5a', '#c07488', '#e8a4b4', '#fcd4dc'],
  };
  const PITCHED = new Set(['house', 'cabin', 'barn', 'church', 'general', 'tailor', 'barber', 'butcher', 'liquor', 'pawn', 'pharmacy', 'laundry', 'gunshop', 'diner', 'costume']);
  const SHOP = new Set(['general', 'tailor', 'barber', 'butcher', 'liquor', 'pawn', 'pharmacy', 'laundry', 'gunshop', 'diner', 'bar', 'club', 'arcade', 'costume', 'strip', 'casino', 'bank', 'social']);
  const bArt = new Map<string, BuildingArt>();
  const baseBArt = A.buildingArt as (b: Building) => BuildingArt;
  const pick = <T2>(arr: T2[], n: number) => arr[((n % arr.length) + arr.length) % arr.length];
  const paintBuilding = (b: Building, night: boolean, neon?: string): BuildingArt => {
    const W = b.w * TS + 4, H = b.h * TS + 6, ft = H - 30;
    const p = new Px(W, H);
    const seed = (b.seedArt || b.id) as number;
    const type = b.type;
    const pitched = PITCHED.has(type) && b.w <= 12;
    // ---- roof
    if (pitched) {
      const rp = type === 'barn' ? ROOF.red : type === 'church' ? ROOF.slate : type === 'cabin' ? ROOF.brown : type === 'diner' ? ROOF.teal : pick(Object.values(ROOF), seed);
      const ridge = Math.max(4, Math.round(ft * 0.3));
      for (let y = 0; y <= ft + 1; y++) for (let x = 0; x < W; x++) {
        let c: string;
        if (y < ridge) c = y < 2 ? rp[4] : rp[3];
        else { const row = Math.floor((y - ridge) / 4), yy = (y - ridge) % 4; c = yy === 3 ? rp[1] : yy === 0 ? rp[3] : rp[2]; if (yy !== 3 && (x + row * 3) % 7 === 0 && yy > 0) c = rp[1]; }
        p.set(x, y, c);
      }
      p.hline(0, W - 1, ridge, rp[0]); p.hline(0, W - 1, ridge + 1, rp[4]);
      p.hline(0, W - 1, ft + 1, rp[0]);
      // chimney
      if (seed % 3 === 0 && W > 40) { const cx = 8 + (seed % Math.max(1, W - 24)); p.rect(cx, 1, 6, ridge + 3, '#b85a3c'); p.hline(cx, cx + 5, 1, '#d87c58'); p.rect(cx - 1, 0, 8, 2, '#5a2418'); }
      // church spire cross, barn loft
      if (type === 'church') { const cx = (W / 2) | 0; p.rect(cx - 1, 2, 3, ridge + 2, '#e8e8f0'); p.rect(cx - 3, 5, 7, 2, '#e8e8f0'); }
    } else {
      const fp = type === 'hospital' ? FLAT.white : type === 'police' ? FLAT.blue : type === 'club' || type === 'casino' || type === 'strip' ? FLAT.purple : type === 'bar' || type === 'social' ? FLAT.maroon : type === 'bank' || type === 'office' ? FLAT.grey : pick(Object.values(FLAT), seed);
      for (let y = 0; y <= ft + 1; y++) for (let x = 0; x < W; x++) {
        const rim = x < 3 || x >= W - 3 || y < 3 || y > ft - 2;
        let c = rim ? (y < 1 || x < 1 ? fp[4] : y > ft - 2 ? fp[1] : fp[3]) : fp[2];
        if (!rim && (y - 3) % 12 === 0) c = shadeHex(fp[2], -0.04);
        else if (!rim && hash(x, y, seed & 255) < 0.05) c = hash(x, y, 7) < 0.5 ? fp[1] : fp[3];
        if (!rim && (y === 3 || x === 3)) c = fp[1]; // the parapet's shadow on the slab
        p.set(x, y, c);
      }
      // rooftop kit: AC units, vents, a skylight
      const r = R.mulberry(seed * 31 + 7);
      const box = (x: number, y: number, w: number, h: number, col: Ramp) => { p.rect(x, y, w, h, col[2]); p.hline(x, x + w - 1, y, col[3]); p.vline(x + w - 1, y, y + h - 1, col[1]); p.hline(x, x + w - 1, y + h - 1, col[1]); for (let k = -1; k <= w; k++) { p.set(x + k, y - 1, INK); p.set(x + k, y + h, INK); } for (let k = 0; k < h; k++) { p.set(x - 1, y + k, INK); p.set(x + w, y + k, INK); } };
      const metal = ['#50586a', '#7a8494', '#a0a8b8', '#ccd4e0'];
      const n = 1 + Math.floor(W / 48);
      for (let k = 0; k < n; k++) { const x = 6 + ((r() * Math.max(1, W - 22)) | 0), y = 6 + ((r() * Math.max(1, ft - 18)) | 0); box(x, y, 10, 7, metal); p.oval(x + 5, y + 3.5, 2.3, 2.3, () => metal[0]); }
      if (type === 'hospital') { const cx = (W / 2) | 0, cy = (ft / 2) | 0; p.rect(cx - 2, cy - 7, 5, 15, '#e83838'); p.rect(cx - 7, cy - 2, 15, 5, '#e83838'); }
      if (type === 'police') { const cx = (W / 2) | 0; p.rect(cx - 6, 5, 6, 3, '#e83838'); p.rect(cx, 5, 6, 3, '#3868e8'); }
      if (ft > 30 && W > 60) { const x = W - 22, y = ft - 18; box(x, y, 12, 8, ['#406070', '#6aa0c0', night ? '#f8e090' : '#98d0f0', '#d8f0ff']); }
    }
    // ---- facade
    const wp = type === 'police' ? WALL.blue : type === 'hospital' ? WALL.white : type === 'bank' ? WALL.white : type === 'cabin' || type === 'barn' ? WALL.wood : type === 'warehouse' || type === 'factory' || type === 'bar' || type === 'social' ? WALL.brick : type === 'diner' ? WALL.mint : type === 'club' || type === 'strip' ? WALL.pink : pick([WALL.cream, WALL.cream, WALL.white, WALL.brick, WALL.blue, WALL.mint], seed >> 2);
    const y0 = ft + 2, y1 = H - 1;
    for (let y = y0; y <= y1; y++) for (let x = 0; x < W; x++) {
      let c = y === y0 ? wp[1] : y >= y1 - 1 ? wp[0] : wp[2];
      if (wp === WALL.brick && y > y0 && y < y1 - 1) { if ((y - y0) % 4 === 0) c = wp[1]; else if ((x + (Math.floor((y - y0) / 4) % 2) * 4) % 8 === 0) c = wp[1]; }
      if (wp === WALL.wood && y > y0 && y < y1 - 1 && (y - y0) % 4 === 0) c = wp[1];
      if (y === y0 + 1 && wp !== WALL.brick) c = wp[3];
      p.set(x, y, c);
    }
    // the roof's shadow under the eave
    p.hline(0, W - 1, y0, shadeHex(wp[1], -0.08));
    // door (on the front for south-facing places)
    const doorX = b.face === 'S' ? 2 + (b.door.x - b.x) * TS + 2 : -99;
    const shop = SHOP.has(type);
    const glass = night ? ['#c89040', '#f8d878', '#fff0b8'] : ['#3c78c0', '#68a8e8', '#b8e0ff'];
    const win = (x: number, y: number, w: number, h: number) => {
      p.rect(x - 1, y - 1, w + 2, h + 2, '#2a3440');
      p.rect(x, y, w, h, glass[1]); p.rect(x, y, w, 2, glass[2]);
      p.hline(x, x + w - 1, y + h - 1, glass[0]);
      if (!night) { p.set(x + 1, y + 3, '#ffffff'); p.set(x + 2, y + 2, '#ffffff'); if (w > 6) p.set(x + w - 3, y + h - 3, '#ffffff'); }
      else for (let k = 0; k < w; k += 3) p.set(x + k, y + h - 2, '#ffe8a0');
      if (w > 8) p.vline(x + (w >> 1), y, y + h - 1, '#2a3440');
    };
    const wy = y0 + 6;
    if (shop) {
      // display windows either side of the door, and a striped awning over them
      const awn = type === 'bar' || type === 'social' ? ['#8a1e2a', '#f0e0c0'] : type === 'diner' ? ['#e84838', '#ffffff'] : type === 'pharmacy' ? ['#3aa060', '#ffffff'] : type === 'club' || type === 'strip' ? ['#a040c0', '#ffd0f0'] : type === 'bank' ? ['#304a80', '#e8d080'] : pick([['#3868c8', '#ffffff'], ['#e8a030', '#fff4d0'], ['#2e8a58', '#f0f8e8']], seed);
      for (let x = 2; x < W - 2; x += 18) { const ww = Math.min(14, W - 3 - x); if (ww < 6 || (doorX > 0 && x < doorX + 14 && x + ww > doorX - 2)) continue; win(x + 1, wy + 2, ww - 2, 12); }
      for (let x = 1; x < W - 1; x++) { const c = ((x >> 2) % 2) ? awn[0] : awn[1]; p.set(x, y0 + 1, c); p.set(x, y0 + 2, c); p.set(x, y0 + 3, c); p.set(x, y0 + 4, x % 4 === 0 ? INK : c); }
      p.hline(1, W - 2, y0 + 5, shadeHex(awn[0], -0.15));
    } else {
      const step = type === 'warehouse' || type === 'factory' ? 24 : 16;
      for (let x = 5; x < W - 10; x += step) { if (doorX > 0 && x < doorX + 14 && x + 10 > doorX - 2) continue; win(x, wy, 9, 10); }
    }
    if (doorX > 0) {
      const dx = doorX, dy = H - 19;
      p.rect(dx - 1, dy - 1, 14, 19, '#2a1c14');
      if (shop) { p.rect(dx, dy, 12, 17, glass[1]); p.rect(dx, dy, 12, 3, glass[2]); p.vline(dx + 6, dy, dy + 16, '#2a3440'); }
      else { p.rect(dx, dy, 12, 17, '#8a5430'); p.rect(dx + 1, dy + 1, 4, 6, '#a86a3c'); p.rect(dx + 7, dy + 1, 4, 6, '#a86a3c'); p.rect(dx + 1, dy + 9, 4, 6, '#a86a3c'); p.rect(dx + 7, dy + 9, 4, 6, '#a86a3c'); p.set(dx + 10, dy + 9, '#f8d040'); }
      if (type === 'warehouse' || type === 'garage' || type === 'factory') { p.rect(dx - 1, dy - 1, 14, 19, '#2a3440'); for (let y = dy; y < dy + 17; y++) p.hline(dx, dx + 11, y, y % 2 ? '#8a94a4' : '#aab4c4'); }
    }
    // outline the whole building and the line where the roof meets the wall
    for (let x = 0; x < W; x++) { p.set(x, 0, INK); p.set(x, H - 1, INK); }
    for (let y = 0; y < H; y++) { p.set(0, y, INK); p.set(W - 1, y, INK); }
    p.hline(0, W - 1, y0 - 1, INK);
    return { cv: p.canvas(), facadeTop: ft, neon };
  };
  A.buildingArt = function (b: Building): BuildingArt {
    if (!on()) return baseBArt.call(this, b);
    const night = !!(R.game && R.game.clock && R.game.clock.isNight());
    const key = b.id + '|' + b.w + 'x' + b.h + b.face + (night ? 'L' : '') + b.type;
    let c = bArt.get(key);
    if (!c) {
      const neon = baseBArt.call(this, b).neon; // the shop's neon colour, as before
      c = paintBuilding(b, night, neon);
      if (bArt.size > 700) bArt.clear();
      bArt.set(key, c);
    }
    return c;
  };

  // ---------------------------------------------------------------- cars
  const baseCar = A.carArt as (m: any, color: string, wrecked: boolean) => Sprite;
  const carE = new WeakMap<HTMLCanvasElement, HTMLCanvasElement>();
  A.carArt = function (m: any, color: string, wrecked: boolean): Sprite {
    const a = baseCar.call(this, m, color, wrecked);
    if (!on()) return a;
    let cv = carE.get(a.cv);
    if (!cv) {
      // saturate the paint and give the body a dark outline
      const w = a.cv.width, h = a.cv.height, src = a.cv.getContext('2d') as CanvasRenderingContext2D;
      const im = src.getImageData(0, 0, w, h), d = im.data;
      const p = new Px(w, h);
      for (let i = 0; i < w * h; i++) {
        if (d[i * 4 + 3] < 128) continue;
        const [hh, ss, ll] = rgbHsl(d[i * 4], d[i * 4 + 1], d[i * 4 + 2]);
        p.d[i] = ss < 0.08 ? rgbHex(d[i * 4], d[i * 4 + 1], d[i * 4 + 2]) : hslHex(hh, Math.min(0.85, ss * 1.3 + 0.05), 0.5 + (ll - 0.5) * 1.12);
      }
      p.outline('#1c2230');
      cv = p.canvas();
      carE.set(a.cv, cv);
    }
    return { cv, ox: a.ox, oy: a.oy };
  };

  // ---------------------------------------------------------------- interiors
  // Rooms keep their layouts and furniture; once a chunk holding interior floor is painted,
  // its colours get the same GBA treatment as the people (cached per colour, and chunks
  // are cached, so this runs once per chunk).
  const gbaPx = new Map<number, number>();
  const gbaPixel = (r: number, g: number, b: number): number => {
    const k = (r << 16) | (g << 8) | b;
    let o = gbaPx.get(k);
    if (o === undefined) {
      let [h, s2, l] = rgbHsl(r, g, b);
      if (s2 >= 0.06) { s2 = Math.min(0.8, s2 * 1.3 + 0.04); if (l < 0.3) h = pullHue(h, 250, 10); else if (l > 0.7) h = pullHue(h, 50, 6); }
      l = 0.5 + (l - 0.5) * 1.12 + 0.03;
      const [rr, gg, bb] = hexRgb(hslHex(h, s2, l));
      o = (rr << 16) | (gg << 8) | bb;
      if (gbaPx.size > 20000) gbaPx.clear();
      gbaPx.set(k, o);
    }
    return o;
  };
  const baseChunk = A.renderChunk as (world: World, cx: number, cy: number, cv: HTMLCanvasElement) => void;
  A.renderChunk = function (world: World, cx: number, cy: number, cv: HTMLCanvasElement) {
    baseChunk.call(this, world, cx, cy, cv);
    if (!on()) return;
    const CH = A.CH as number, x0 = cx * CH, y0 = cy * CH;
    let inside = false;
    for (let y = y0; y < y0 + CH && !inside; y += 2) for (let x = x0; x < x0 + CH; x += 2) if (world.t(x, y) >= T.VOID) { inside = true; break; }
    if (!inside) return;
    const g = cv.getContext('2d') as CanvasRenderingContext2D, im = g.getImageData(0, 0, cv.width, cv.height), d = im.data;
    for (let i = 0; i < d.length; i += 4) {
      if (!d[i + 3]) continue;
      const o = gbaPixel(d[i], d[i + 1], d[i + 2]);
      d[i] = o >> 16; d[i + 1] = (o >> 8) & 255; d[i + 2] = o & 255;
    }
    g.putImageData(im, 0, 0);
  };

  // ---------------------------------------------------------------- minimap, settings
  const classicColours: Record<number, string> = Object.assign({}, A.tileColor);
  const emeraldColours = (): Record<number, string> => {
    const c = Object.assign({}, classicColours);
    const set = (t: number, col: string) => { c[t] = col; };
    set(T.GRASS, P.grass[2]); set(T.PARK, P.park[2]); set(T.FOREST, P.forest[1]); set(T.FIELD, P.field[2]); set(T.DIRT, P.dirt[2]); set(T.DIRTROAD, P.path[2]);
    set(T.SAND, P.sand[2]); set(T.DESERT, P.desert[2]); set(T.SNOW, P.snow[2]); set(T.MARSH, P.marsh[2]); set(T.ROCK, P.rock[2]); set(T.WATER, P.water[2]); set(T.DEEP, P.deep[2]);
    set(T.ROAD, P.asphalt[2]); set(T.HWY, P.asphalt[1]); set(T.WALK, P.walk[2]); set(T.PLAZA, P.plaza[2]); set(T.DOCK, P.dock[2]); set(T.PARKING, P.parking[2]); set(T.LOT, P.lot[2]);
    return c;
  };
  R.emerald = {
    on,
    // switch styles: repaint the world, the people and the minimap
    apply(game: Game) {
      const src = on() ? emeraldColours() : classicColours;
      Object.assign(A.tileColor, src);
      A.chunkCache.clear();
      if (game.world) game.miniDirty = true;
    },
    P,
  };
  // the settings menu gets an Art style switch
  const hookSettings = () => {
    const U = R.UI && R.UI.prototype;
    if (!U || U._emeraldHook) return;
    U._emeraldHook = true;
    const bTab = U.openMenuTab;
    U.openMenuTab = function (this: { game: Game }, tab: string) {
      const r = bTab.apply(this, arguments);
      if (tab !== 'settings') return r;
      const body = document.getElementById('mbody'), st = this.game.settings;
      if (!body || body.querySelector('#sArt')) return r;
      const cur = st.art || 'emerald';
      body.insertAdjacentHTML('afterbegin', `<div class="set"><label for="sArt">Art style</label><select id="sArt"><option value="emerald" ${cur === 'emerald' ? 'selected' : ''}>Emerald (GBA)</option><option value="classic" ${cur === 'classic' ? 'selected' : ''}>Classic</option></select></div>`);
      body.querySelector('#sArt')?.addEventListener('change', (e) => { st.art = (e.target as HTMLSelectElement).value; this.game.saveSettings(); R.emerald.apply(this.game); });
      return r;
    };
  };
  // UI is defined later in the bundle: hook it once the game boots
  const wait = () => { if (R.UI && R.game) { hookSettings(); R.emerald.apply(R.game); } else setTimeout(wait, 50); };
  wait();
})();
