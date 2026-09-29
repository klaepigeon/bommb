// Planets as game 1 worlds: per-planet saves, the planet profile applied to the generator,
// the spaceport pad with your ship, carrying the player between planets, and the text layer
// that renames game 1's places and people on screen.

import { renames, worldProfile, type PlanetId, type Profile } from './planets';
import { SQ, saveSequel, planetKey, planetSeed } from './state';
import { shipSprites } from '../ship/ship';
import { EARTH, citySpots, isHome, touchSector } from './earth';

const GAME1_SAVE = 'rhapsody.save.v2';
const D = R.data, T = D.T, O = D.O, TS = R.TILE;

export const current = (): Profile => worldProfile();

// ---------------------------------------------------------------- saves: one per planet
const store = R.store;
const baseGet = store.get.bind(store), baseSet = store.set.bind(store), baseDel = store.del.bind(store);
const mapKey = (k: string) => (k === GAME1_SAVE ? planetKey(SQ.planet) : k);
store.get = (k: string) => baseGet(mapKey(k));
store.set = (k: string, v: unknown) => { const ok = baseSet(mapKey(k), v); if (k === GAME1_SAVE) saveSequel(); return ok; };
store.del = (k: string) => baseDel(mapKey(k));

// ---------------------------------------------------------------- the profile over the generator
const GAME1_CITIES = D.cities.map((c: Record<string, unknown>) => ({ ...c }));
const GAME1_HAMLETS = D.hamlets.map((h: Record<string, unknown>) => ({ ...h }));

export function applyProfile(): void {
  const p = worldProfile();
  const sec = (p as { sector?: [number, number] }).sector;
  // on Earth the people themselves change (the Syndicate and the crews), and away from the
  // Brass Coast the cities stand wherever the land is
  const spots = sec && !isHome(sec) ? citySpots(sec[0], sec[1], 9) : null;
  D.cities.forEach((c: Record<string, unknown>, i: number) => {
    const base = GAME1_CITIES[i], cp = p.cities && p.cities[i];
    // names are display only; family keys stay game 1's (the systems key on them)
    Object.assign(c, base, cp ? { name: cp.name, tag: cp.tag, biome: cp.biome || base.biome } : {}, sec && cp ? { don: cp.don } : {}, spots && spots[i] ? { fx: spots[i].fx, fy: spots[i].fy } : {});
  });
  D.hamlets.forEach((h: Record<string, unknown>, i: number) => Object.assign(h, GAME1_HAMLETS[i], p.hamlets ? { name: p.hamlets[i] } : {}, spots && spots[5 + i] ? { fx: spots[5 + i].fx, fy: spots[5 + i].fy } : {}));
  R.planet = p;
  setRenames(p);
}

// terrain for each kind of planet, applied once the base generator is done
function reshape(w: World, p: Profile): void {
  const N = w.W * w.H;
  const nat = new Set([T.GRASS, T.FOREST, T.FIELD, T.MARSH, T.SAND, T.DESERT, T.DIRT, T.SNOW, T.PARK]);
  for (let i = 0; i < N; i++) {
    const t = w.tile[i];
    if (!nat.has(t)) continue;
    const x = i % w.W, y = (i / w.W) | 0, h = R.hash2(x, y, 77);
    const o = w.obj[i];
    if (p.terrain === 'earth') continue;
    if (p.terrain === 'dystopia') {
      // the green went grey: dead grass, dead woods, poisoned marsh, rubble everywhere
      if (t === T.GRASS || t === T.PARK) w.tile[i] = h < 0.72 ? T.DIRT : T.GRASS;
      else if (t === T.FOREST && h < 0.5) w.tile[i] = T.DIRT;
      else if (t === T.FIELD) w.tile[i] = T.DIRT;
      if (o === O.TREE || o === O.PALM || o === O.PINE) w.obj[i] = h < 0.55 ? O.DEADTREE : o;
      else if (o === O.FLOWERS) w.obj[i] = 0;
      else if (!o && (w.tile[i] === T.DIRT || w.tile[i] === T.DESERT) && h > 0.985) w.obj[i] = O.BOULDER;
      continue;
    }
    if (p.terrain === 'moon') {
      if (t === T.GRASS || t === T.PARK) w.tile[i] = h < 0.3 ? T.DESERT : T.DIRT;
      else if (t === T.FOREST) w.tile[i] = h < 0.35 ? T.ROCK : T.DIRT;
      else if (t === T.FIELD || t === T.SAND) w.tile[i] = T.DESERT;
      else if (t === T.MARSH) w.tile[i] = T.DIRT;
      if (o === O.TREE || o === O.PINE || o === O.BUSH || o === O.PALM || o === O.FLOWERS || o === O.REED) w.obj[i] = h < 0.25 ? O.BOULDER : h < 0.4 ? O.DEADTREE : 0;
      if (w.tile[i] === T.ROCK) w.obj[i] = 0;
    } else if (p.terrain === 'mars') {
      // terraformed: green where the money went, red dust where it didn't
      if (t === T.DIRT) w.tile[i] = h < 0.5 ? T.DESERT : T.GRASS;
      else if (t === T.FOREST && h < 0.25) w.tile[i] = T.GRASS;
      if (o === O.CACTUS) w.obj[i] = O.BUSH;
      else if (o === O.DEADTREE) w.obj[i] = O.TREE;
      else if (!o && w.tile[i] === T.GRASS && h > 0.975) w.obj[i] = O.FLOWERS;
    } else if (p.terrain === 'ice') {
      // a frozen rock: snowfields, bare stone, frost where the grass was
      w.tile[i] = T.SNOW;
      if (o === O.TREE || o === O.PALM || o === O.FLOWERS || o === O.REED || o === O.BUSH || o === O.CACTUS || o === O.DEADTREE) w.obj[i] = h < 0.25 ? O.BOULDER : 0;
    } else if (p.terrain === 'jungle') {
      // hothouse: everything that can grow, does
      if (t === T.DESERT || t === T.SAND || t === T.DIRT || t === T.SNOW) w.tile[i] = h < 0.6 ? T.GRASS : T.FOREST;
      else if (t === T.FIELD) w.tile[i] = h < 0.5 ? T.FOREST : T.GRASS;
      if (o === O.CACTUS || o === O.DEADTREE || o === O.PINE) w.obj[i] = O.PALM;
      else if (!o && (w.tile[i] === T.GRASS || w.tile[i] === T.FOREST) && h > 0.93) w.obj[i] = h > 0.97 ? O.TREE : O.BUSH;
    } else if (p.terrain === 'capital') {
      if (t === T.DIRT) w.tile[i] = T.GRASS;
      if (!o && t === T.GRASS && h > 0.985) w.obj[i] = O.FLOWERS;
    }
  }
}

// a landing pad near the first city: 14×10 tiles of open ground, stamped as apron, with the
// ship's footprint made solid
function stampPad(w: World): void {
  const c = w.cities[0];
  const PW = 14, PH = 10;
  const open = new Set([T.GRASS, T.DIRT, T.DESERT, T.FIELD, T.SAND, T.SNOW, T.FOREST]);
  const ok = (x0: number, y0: number) => {
    for (let y = y0 - 1; y <= y0 + PH; y++) for (let x = x0 - 1; x <= x0 + PW; x++) { if (!w.inb(x, y) || y >= w.H - 2 || !open.has(w.t(x, y)) || w.bid[w.idx(x, y)]) return false; }
    return true;
  };
  let found: { x: number; y: number } | null = null;
  for (let r = 0; r < 220 && !found; r += 2)
    for (let k = 0; k < Math.max(8, r * 4) && !found; k++) {
      const a = (k / Math.max(8, r * 4)) * Math.PI * 2;
      const x = Math.round(c.cx + Math.cos(a) * (r + (c.x1 - c.x0) / 2)), y = Math.round(c.cy + Math.sin(a) * (r + (c.y1 - c.y0) / 2));
      if (ok(x, y)) found = { x, y };
    }
  if (!found) found = { x: c.x1 + 4, y: c.cy };
  const { x: px, y: py } = found;
  for (let y = py; y < py + PH; y++) for (let x = px; x < px + PW; x++) { const i = w.idx(x, y); w.tile[i] = T.PARKING; w.obj[i] = 0; }
  // the ship stands on landing legs over the middle of the pad
  if (shipHere()) for (let y = py + 3; y < py + 6; y++) for (let x = px + 4; x < px + 10; x++) w.tile[w.idx(x, y)] = T.BLDG;
  w.pad = { x: px, y: py, w: PW, h: PH, sx: (px + 7) * TS, sy: (py + 4.5) * TS };
}

const WP = R.World.prototype, baseGen = WP.gen;
WP.gen = function (this: World) {
  baseGen.call(this);
  reshape(this, current());
  stampPad(this);
};

// ---------------------------------------------------------------- the player, between planets
const PORTABLE = ['hp', 'maxHp', 'cool', 'cash', 'inv', 'clip', 'outfit', 'outfits', 'style', 'wardrobe', 'will', 'willMax', 'docHp', 'relics', 'ringColor', 'rep', 'first', 'last', 'nick', 'fearQ', 'vice', 'money'];
export function capture(pl: Player): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const k of PORTABLE) if (pl[k] !== undefined) out[k] = JSON.parse(JSON.stringify(pl[k]));
  out.stats = JSON.parse(JSON.stringify(pl.stats));
  return out;
}
function restore(pl: Player, p: Record<string, unknown>): void {
  for (const k of PORTABLE) if (p[k] !== undefined) pl[k] = p[k];
  if (p.stats) Object.assign(pl.stats, p.stats);
  if (pl.ringColor && R.corps && R.corps.COL) D.weapons.ring.name = (R.corps.COL[pl.ringColor] || R.corps.COL.yellow).name;
  pl.buildLook();
}

// the load-time event listeners (a few modules register at load, not in init)
const bootListeners = new Map<string, ((...a: unknown[]) => void)[]>();
for (const [k, v] of R.bus.map) bootListeners.set(k, v.slice());

// ---------------------------------------------------------------- setup: every planet boots through here
const GP = R.Game.prototype, baseSetup = GP.setup;
GP.setup = function (this: Game, _seed: number, _save: unknown) {
  EARTH.active = SQ.planet === 'earth' && SQ.home === 'sol';
  EARTH.sector = [SQ.sector[0], SQ.sector[1]];
  if (EARTH.active) touchSector(EARTH.sector);
  applyProfile();
  const seed = planetSeed(SQ.planet);
  const save = R.store.get(GAME1_SAVE);
  baseSetup.call(this, seed, save && save.seed === seed ? save : null);
  const pl = this.player, w = this.world;
  if (SQ.portable) { restore(pl, SQ.portable); SQ.portable = null; }
  if (SQ.arriveEdge) {
    // walked (or drove) across a sector border: come in at the matching edge, on dry land
    const e = SQ.arriveEdge, M = 6;
    const tx = e.edge === 'w' ? w.W - M : e.edge === 'e' ? M : Math.round(e.f * w.W), ty = e.edge === 'n' ? w.H - M : e.edge === 's' ? M : Math.round(e.f * w.H);
    const s = w.findNear(tx, ty, 0, 60, (x: number, y: number) => !w.solidPed(x, y) && !w.isWater(x, y));
    pl.place(((s ? s.x : tx) + 0.5) * TS, ((s ? s.y : ty) + 0.5) * TS);
    SQ.arriveEdge = null; SQ.arriving = false;
  } else if (SQ.arriving && w.pad) { pl.place(w.pad.sx - 40, w.pad.sy + 44); pl.dir = 2; SQ.arriving = false; }
  if (!SQ.visited.includes(SQ.planet)) SQ.visited.push(SQ.planet);
  this.cam.x = pl.x; this.cam.y = pl.y;
  saveSequel();
};

// land on another planet: save this one, carry the player over, rebuild the world in place
export function travelTo(g: Game, to: PlanetId, force = false): void {
  if (to === SQ.planet && SQ.home === SQ.system && !force) return;
  g.save();
  SQ.portable = capture(g.player);
  SQ.planet = to; SQ.home = SQ.system; SQ.arriving = true;
  saveSequel();
  g.worldLog.length = 0;
  R.art.chunkCache.clear();
  R.bus.map.clear();
  for (const [k, v] of bootListeners) R.bus.map.set(k, v.slice());
  if (g.ui.closeSheet) g.ui.closeSheet();
  g.setup(0, null);
  g.renderer.resize();
  g.save();
}

// ---------------------------------------------------------------- the ship on its pad
// extra lines on the ship's menu (the court, the jump drive...), added by other modules
export interface MenuOpt { label: string; small?: string; fn: () => void }
export const SHIP_MENU: ((g: Game) => MenuOpt | null)[] = [];
// on Earth your ship is parked in one sector; everywhere else it's on the pad you landed at
export const shipHere = () => (!SQ.shipLoc || (SQ.shipLoc.sys === SQ.home && SQ.shipLoc.planet === SQ.planet)) &&
  (SQ.planet !== 'earth' || SQ.home !== 'sol' || (SQ.shipAt[0] === SQ.sector[0] && SQ.shipAt[1] === SQ.sector[1]));
export function nearPad(pl: Player): boolean {
  const w = R.game.world;
  return !!w.pad && !pl.room && !pl.inCar && SQ.mode !== 'space' && Math.abs(pl.x - w.pad.sx) < 70 && Math.abs(pl.y - w.pad.sy) < 42;
}
export function nearShip(pl: Player): boolean {
  const w = R.game.world;
  return shipHere() && !!w.pad && !pl.room && !pl.inCar && SQ.mode !== 'space' && Math.abs(pl.x - w.pad.sx) < 70 && Math.abs(pl.y - w.pad.sy) < 42;
}
const props = R.props, baseGround = props.drawGround;
props.drawGround = function (g: CanvasRenderingContext2D, inView: (x: number, y: number) => boolean) {
  const w = R.game && R.game.world;
  if (w && w.pad && inView(w.pad.sx, w.pad.sy)) {
    const p = w.pad;
    // painted pad markings
    g.strokeStyle = 'rgba(232,176,32,0.9)'; g.lineWidth = 2;
    g.strokeRect(p.x * TS + 3, p.y * TS + 3, p.w * TS - 6, p.h * TS - 6);
    g.beginPath(); g.arc(p.sx, p.sy, 34, 0, 7); g.stroke();
    g.fillStyle = 'rgba(232,176,32,0.9)'; g.font = '8px Silkscreen, monospace'; g.textAlign = 'center';
    g.fillText(shipHere() ? 'PAD 3 · ' + SQ.ship.name.toUpperCase() : 'PAD 3 · EMPTY', p.sx, (p.y + p.h) * TS - 8);
    if (!shipHere()) return baseGround.call(this, g, inView);
    // the ship, at twice its space scale, with a shadow
    const spr = shipSprites(SQ.ship)[24]; // nose up
    g.fillStyle = 'rgba(16,12,36,0.35)'; g.beginPath(); g.ellipse(p.sx + 4, p.sy + 10, spr.width * 0.9, spr.height * 0.5, 0, 0, 7); g.fill();
    g.imageSmoothingEnabled = false;
    g.drawImage(spr, Math.round(p.sx - spr.width), Math.round(p.sy - spr.height - 6), spr.width * 2, spr.height * 2);
  }
  return baseGround.call(this, g, inView);
};

// ---------------------------------------------------------------- the text layer
let pairs: [RegExp, string][] = [];
const fix = (s: string) => { for (const [re, to] of pairs) s = s.replace(re, to); return s; };
function setRenames(p: Profile): void {
  pairs = renames(p);
  // the police go by the world's name for them
  // Earth has no families any more: crews, bosses, and the Syndicate
  if (p.terrain === 'dystopia') pairs.push([/\bfamily\b/g, 'crew'], [/\bfamilies\b/g, 'crews'], [/\bFamily\b/g, 'Crew'], [/\bFamilies\b/g, 'Crews'], [/\bDon\b/g, 'Boss'], [/\bdon\b/g, 'boss'], [/\bThe County\b/g, 'The Wastes'], [/\bTHE COUNTY\b/g, 'THE WASTES']);
  if (p.law !== 'Police') pairs.push([/\bPolice\b/g, p.law], [/\bpolice\b/g, p.law], [/\bthe cops\b/g, p.law], [/\bcops\b/g, p.law === 'Imperial Security' ? 'Imperials' : 'security']);
  if (document.body) sweep(document.body);
}
// only words people read: never styles, scripts or inputs
const skip = (n: Node) => { const p = n.parentNode as Element | null; return !!p && (p.nodeName === 'STYLE' || p.nodeName === 'SCRIPT' || p.nodeName === 'TEXTAREA'); };
function sweep(root: Node): void {
  if (root.nodeName === 'STYLE' || root.nodeName === 'SCRIPT') return;
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, { acceptNode: (n) => (skip(n) ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT) });
  for (let n = walker.nextNode(); n; n = walker.nextNode()) { const v = n.nodeValue || ''; const f = fix(v); if (f !== v) n.nodeValue = f; }
}
const obs = new MutationObserver((muts) => {
  for (const m of muts) {
    if (m.type === 'characterData') { if (skip(m.target)) continue; const v = m.target.nodeValue || ''; const f = fix(v); if (f !== v) m.target.nodeValue = f; }
    else for (const n of m.addedNodes) { if (n.nodeType === 3 && !skip(n)) { const v = n.nodeValue || ''; const f = fix(v); if (f !== v) n.nodeValue = f; } else if (n.nodeType === 1) sweep(n); }
  }
});
addEventListener('DOMContentLoaded', () => obs.observe(document.body, { childList: true, subtree: true, characterData: true }));
if (document.body) obs.observe(document.body, { childList: true, subtree: true, characterData: true });
// canvas text (signs, the HUD)
const A = R.art, basePtext = A.ptext;
A.ptext = function (g: CanvasRenderingContext2D, s: string, ...rest: unknown[]) { return basePtext.call(this, g, typeof s === 'string' ? fix(s) : s, ...rest); };

// the ship's footprint is solid (BLDG) but should look like the pad under it
const baseTile = A.drawTile;
A.drawTile = function (g: CanvasRenderingContext2D, w: World, x: number, y: number, px: number, py: number) {
  const p = w.pad;
  if (p && x >= p.x && x < p.x + p.w && y >= p.y && y < p.y + p.h && w.t(x, y) === T.BLDG) {
    const i = w.idx(x, y);
    w.tile[i] = T.PARKING;
    try { return baseTile.call(this, g, w, x, y, px, py); } finally { w.tile[i] = T.BLDG; }
  }
  return baseTile.call(this, g, w, x, y, px, py);
};
