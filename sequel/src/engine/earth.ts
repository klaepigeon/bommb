// Earth, at planet scale. A tech demo for huge planets in game 1's engine.
// The planet is a grid of 72 x 36 sectors (5 degrees each). Every sector is a full game 1
// map (880 x 880 tiles: cities, roads, countryside, people, traffic, law, the lot), generated
// on demand from the sector's place on a real map of the continents. That's 2,592 counties,
// about two billion tiles. The Brass Coast, game 1's whole map, is one of them (on the
// California coast). Coastlines, biomes, deserts, ice caps and jungles run continuously across
// sector borders, so you can walk or drive from one to the next; open ocean stops you.
// Real cities are still there, after a fashion: Neo-Tokyo, the London Arcology, the Cairo
// Sprawl. Each sector remembers what you did there (the last few you visited keep full saves;
// older ones regrow from their seed).

import { SQ, saveSequel, HOME_SECTOR, COAST_SECTOR } from './state';
import { SOL_PLANETS, SECTORED, type Profile } from './planets';

export const NX = 72, NY = 36;
export const HOME: [number, number] = HOME_SECTOR;
export const isHome = (s: [number, number] | null | undefined) => !s || (s[0] === HOME[0] && s[1] === HOME[1]);
export const isCoast = (s: [number, number] | null | undefined) => !!s && s[0] === COAST_SECTOR[0] && s[1] === COAST_SECTOR[1];

// ---------------------------------------------------------------- the continents
// land cells per 5-degree row, north (85-90N) to south (85-90S), as [first, last] columns;
// column 0 is 180W, column 36 is the Greenwich meridian
const ROWS: [number, number][][] = [
  [],
  [[18, 22], [24, 32], [46, 47]],
  [[12, 32], [38, 41], [47, 49], [55, 56]],
  [[4, 7], [11, 20], [24, 32], [40, 41], [50, 50], [54, 57], [62, 71]],
  [[3, 24], [25, 32], [38, 71]],
  [[3, 16], [21, 23], [26, 28], [31, 32], [37, 71]],
  [[9, 16], [20, 23], [34, 35], [37, 39], [41, 63], [67, 68]],
  [[10, 24], [34, 35], [36, 63], [64, 64], [67, 67]],
  [[11, 23], [35, 44], [47, 63], [64, 64]],
  [[11, 22], [34, 36], [37, 40], [44, 44], [47, 59], [60, 61], [64, 64]],
  [[12, 20], [34, 35], [41, 50], [51, 60], [61, 61], [62, 63]],
  [[12, 19], [34, 42], [43, 50], [52, 60], [62, 62]],
  [[13, 15], [19, 19], [33, 41], [43, 53], [55, 60]],
  [[14, 16], [19, 20], [32, 42], [43, 47], [49, 53], [54, 59]],
  [[15, 18], [32, 43], [44, 46], [50, 52], [54, 57], [60, 60]],
  [[17, 19], [32, 44], [45, 46], [51, 51], [55, 57], [60, 60]],
  [[20, 23], [33, 35], [36, 45], [52, 52], [55, 56], [60, 60]],
  [[20, 26], [37, 44], [55, 59]],
  [[20, 29], [37, 43], [56, 59], [62, 65]],
  [[20, 29], [38, 43], [57, 58], [64, 65]],
  [[20, 28], [38, 43], [45, 45], [62, 64]],
  [[21, 28], [38, 43], [44, 45], [60, 65]],
  [[22, 27], [38, 43], [44, 45], [58, 66]],
  [[21, 26], [39, 42], [58, 66]],
  [[21, 25], [39, 41], [59, 60], [63, 66]],
  [[21, 24], [64, 65], [70, 71]],
  [[21, 23], [65, 65], [69, 71]],
  [[21, 22], [69, 69]],
  [[21, 22]],
  [],
  [],
  [[23, 24]],
  [[6, 23], [32, 71]],
  [[5, 25], [31, 71]],
  [[0, 71]],
  [[0, 71]],
];
const MASK = new Uint8Array(NX * NY);
ROWS.forEach((row, y) => { for (const [a, b] of row) for (let x = a; x <= b; x++) MASK[y * NX + x] = 1; });
export const landCell = (x: number, y: number) => (y < 0 || y >= NY ? (y < 0 ? 0 : 1) : MASK[y * NX + (((x % NX) + NX) % NX)]);

// the land value anywhere on the planet, in sector units (fractional): the mask, smoothed,
// roughened by noise so coasts are coasts and not a chessboard
const noise = R.makeNoise(90210), noise2 = R.makeNoise(4077);
export function landValue(u: number, v: number): number {
  const x = u - 0.5, y = v - 0.5, x0 = Math.floor(x), y0 = Math.floor(y), fx = x - x0, fy = y - y0;
  const s = (a: number) => a * a * (3 - 2 * a), sx = s(fx), sy = s(fy);
  const a = landCell(x0, y0), b = landCell(x0 + 1, y0), c = landCell(x0, y0 + 1), d = landCell(x0 + 1, y0 + 1);
  const m = a + (b - a) * sx + (c - a) * sy + (a - b - c + d) * sx * sy;
  return m + (noise.fbm(u * 4.5, v * 4.5, 4) - 0.5) * 0.7 + (noise2.fbm(u * 22, v * 22, 3) - 0.5) * 0.18;
}
export const lonOf = (u: number) => (u / NX) * 360 - 180;
export const latOf = (v: number) => 90 - (v / NY) * 180;

// how much of a sector is land (for landing and crossing)
const fracCache = new Map<string, number>();
export function landFrac(sx: number, sy: number): number {
  const k = sx + ',' + sy;
  if (fracCache.has(k)) return fracCache.get(k)!;
  let n = 0;
  for (let j = 0; j < 8; j++) for (let i = 0; i < 8; i++) if (landValue(sx + (i + 0.5) / 8, sy + (j + 0.5) / 8) > 0.5) n++;
  fracCache.set(k, n / 64);
  return n / 64;
}

// ---------------------------------------------------------------- climate
const cnoise = R.makeNoise(1985);
export function climate(lon0: number, lat0: number): 'ice' | 'desert' | 'jungle' | 'temperate' | 'tundra' {
  // ragged edges: the bands and deserts wander by a few degrees
  const lon = lon0 + (cnoise.fbm(lon0 / 9, lat0 / 9, 3) - 0.5) * 16, lat = lat0 + (cnoise.fbm(lon0 / 7 + 40, lat0 / 7, 3) - 0.5) * 10;
  const al = Math.abs(lat);
  if (al > 66) return 'ice';
  if (al > 58) return 'tundra';
  const desert = (lat > 15 && lat < 35 && lon > -18 && lon < 60) || (lat > -32 && lat < -18 && lon > 115 && lon < 142) || (lat > 25 && lat < 42 && lon > -120 && lon < -103)
    || (lat > 36 && lat < 48 && lon > 55 && lon < 110) || (lat > -30 && lat < -16 && lon > -72 && lon < -66) || (lat > -28 && lat < -17 && lon > 13 && lon < 25);
  if (desert) return 'desert';
  if (al < 16) return 'jungle';
  return 'temperate';
}

// ---------------------------------------------------------------- the real cities, after the collapse
// [name, lat, lon]
const CITIES: [string, number, number][] = [
  ['Los Angeles', 34, -118], ['San Francisco', 37.8, -122.4], ['Seattle', 47.6, -122.3], ['Vancouver', 49.3, -123.1], ['Las Vegas', 36.2, -115.1], ['Phoenix', 33.4, -112],
  ['Denver', 39.7, -105], ['Houston', 29.8, -95.4], ['Dallas', 32.8, -96.8], ['Chicago', 41.9, -87.6], ['Detroit', 42.3, -83], ['New Orleans', 30, -90],
  ['Miami', 25.8, -80.2], ['Atlanta', 33.7, -84.4], ['New York', 40.7, -74], ['Boston', 42.4, -71], ['Toronto', 43.7, -79.4], ['Montreal', 45.5, -73.6],
  ['Mexico City', 19.4, -99.1], ['Havana', 23.1, -82.4], ['Bogota', 4.7, -74.1], ['Lima', -12, -77], ['Rio', -22.9, -43.2], ['Sao Paulo', -23.5, -46.6],
  ['Buenos Aires', -34.6, -58.4], ['Santiago', -33.4, -70.6], ['London', 51.5, -0.1], ['Paris', 48.9, 2.3], ['Berlin', 52.5, 13.4], ['Madrid', 40.4, -3.7],
  ['Rome', 41.9, 12.5], ['Moscow', 55.8, 37.6], ['Stockholm', 59.3, 18.1], ['Istanbul', 41, 29], ['Cairo', 30, 31.2], ['Lagos', 6.5, 3.4],
  ['Nairobi', -1.3, 36.8], ['Kinshasa', -4.3, 15.3], ['Johannesburg', -26.2, 28], ['Cape Town', -33.9, 18.4], ['Casablanca', 33.6, -7.6], ['Dubai', 25.3, 55.3],
  ['Tehran', 35.7, 51.4], ['Karachi', 24.9, 67], ['Mumbai', 19, 72.8], ['Delhi', 28.6, 77.2], ['Kolkata', 22.6, 88.4], ['Bangkok', 13.8, 100.5],
  ['Singapore', 1.3, 103.8], ['Jakarta', -6.2, 106.8], ['Manila', 14.6, 121], ['Hong Kong', 22.3, 114.2], ['Shanghai', 31.2, 121.5], ['Beijing', 39.9, 116.4],
  ['Seoul', 37.6, 127], ['Tokyo', 35.7, 139.7], ['Osaka', 34.7, 135.5], ['Vladivostok', 43.1, 131.9], ['Sydney', -33.9, 151.2], ['Melbourne', -37.8, 145],
  ['Perth', -32, 115.9], ['Auckland', -36.8, 174.8], ['Anchorage', 61.2, -149.9], ['Reykjavik', 64.1, -21.9], ['Novosibirsk', 55, 82.9], ['Ulaanbaatar', 47.9, 106.9],
];
const STYLES = ['Neo-{c}', '{c} Sprawl', '{c} Arcology', 'Old {c}', '{c} Megablock', '{c} Undercity', 'Greater {c}', '{c} Free Zone'];
const SYL = ['ka', 'zo', 'rex', 'vin', 'tal', 'mor', 'dex', 'ul', 'sen', 'kor', 'lux', 'tri', 'nak', 'ven', 'os', 'ark'];
const ZONES = ['Hab', 'Zone', 'Block', 'Stack', 'Dome', 'Yard', 'Camp', 'Station'];
const TAGS = ['neon, noodles and nerve gas', 'rain that never stops', 'the arcology looms over everything', 'scrap towers and satellite dishes', 'corporate enclaves behind the wall', 'where the smog is thickest', 'a dead city with the lights still on', 'mutant markets and chrome clinics', 'the water is not water anymore', 'hover traffic twelve lanes deep'];
const CREWS = ['Chrome Jackals', 'Neon Saints', 'Rust Nomads', 'Glass Widows', 'Static Kings', 'Iron Lotus', 'Void Rats', 'Gutter Angels', 'Black Sun', 'Scrap Choir', 'Red Circuit', 'Dust Devils'];
const BOSSES = ['Razor Kade', 'Mama Volt', 'Deacon Chrome', 'Lady Sable', 'Nix Ortega', 'Big Zero', 'Juno Grieve', 'Tex Cobalt', 'Sister Ash', 'Oyelaran Vex', 'Mako Stone', 'Kid Halogen'];
function rng(seed: number) { let s = seed >>> 0; return () => { s = (s + 0x6d2b79f5) >>> 0; let t = s; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
const cap = (s: string) => s[0].toUpperCase() + s.slice(1);

// the Syndicate: one boss for the whole planet
export const BOSS = { family: 'Dread', don: 'The Fear Man', name: 'The Fear Man' };

const profCache = new Map<string, Profile>();
export function earthProfile(sx: number, sy: number): Profile {
  const key = sx + ',' + sy;
  const hit = profCache.get(key);
  if (hit) return hit;
  const home = isHome([sx, sy]);
  const r = rng(sx * 7919 + sy * 104729 + 17), pick = <T>(a: T[]) => a[Math.floor(r() * a.length)];
  const lon0 = lonOf(sx), lat0 = latOf(sy), lon1 = lonOf(sx + 1), lat1 = latOf(sy + 1);
  const real = CITIES.filter(([, la, lo]) => lo >= lon0 && lo < lon1 && la <= lat0 && la > lat1).map(([n]) => pick(STYLES).replace('{c}', n));
  const gen = () => `${cap(pick(SYL) + pick(SYL))} ${pick(ZONES)}${r() < 0.4 ? ' ' + (1 + Math.floor(r() * 99)) : ''}`;
  const coast = isCoast([sx, sy]);
  const names = home ? ['Port Hollow', 'New Avalon', 'Dustwater', 'Pinecrest', 'Bayou Clair'] : coast ? ['Coast City', 'Ferris Heights', 'Jordan Point', 'Old Airfield', 'Harbor Row'] : [...real.slice(0, 5)];
  while (names.length < 5) names.push(gen());
  const crews = [...CREWS].sort(() => r() - 0.5).slice(0, 4), bosses = [...BOSSES].sort(() => r() - 0.5).slice(0, 4);
  const cl = climate((lon0 + lon1) / 2, (lat0 + lat1) / 2);
  const cities = names.map((n, i) => ({
    name: n, tag: coast ? ['the yellow city: Hal Jordan\'s hometown, rebuilt as a shrine to Parallax', 'the aircraft plant, shut since the fall', 'the point where the memorial used to be', 'the dead airfield', 'the harbour, lit gold all night'][i] : home ? ['the harbour where it all started', 'the megablock that ate the old downtown', 'the desert scrapyards', 'the dead pine country', 'the flooded bayou stacks'][i] : pick(TAGS),
    family: i === 0 ? BOSS.family : crews[i - 1], don: i === 0 ? (coast ? BOSS.don : home ? 'Tav "Big Tav" Morrow' : 'Syndicate Boss ' + pick(BOSSES)) : bosses[i - 1], biome: cl === 'desert' ? 'desert' : undefined,
  })) as Profile['cities'];
  const region = coast ? 'Coast City' : real.length ? real[0] : `${Math.abs(Math.round((lat0 + lat1) / 2))}°${lat0 > 0 ? 'N' : 'S'} ${Math.abs(Math.round((lon0 + lon1) / 2))}°${lon0 < 0 ? 'W' : 'E'}`;
  const p: Profile = {
    ...SOL_PLANETS.earth,
    name: 'Earth', faction: `${BOSS.name}'s Syndicate`, blurb: coast ? 'Coast City: Hal Jordan\'s hometown. Parallax burned it once; the Fear Man rebuilt it in yellow, for him.' : home ? 'The Brass Coast, ten years on: the same streets under a dirtier sky.' : `Earth, ${region}.`,
    cities, hamlets: [gen(), gen(), gen(), gen()], law: 'Peacekeepers', terrain: 'dystopia' as Profile['terrain'], fauna: 'earth',
    species: [['cyborg', 0.12], ['robot', 0.07], ['mutant', 0.08], ['punk', 0.08], ['bomber', 0.05], ['android', 0.04], ['grey', 0.02], ['martian', 0.02]],
  };
  (p as any).sector = [sx, sy]; (p as any).climate = cl; (p as any).region = region;
  profCache.set(key, p);
  return p;
}
export const sectorName = (sx: number, sy: number) => { const p = earthProfile(sx, sy) as any; return isHome([sx, sy]) ? 'the Brass Coast' : p.region; };

// ---------------------------------------------------------------- generating a sector
// city spots: the landiest places in the sector, spread out
export function citySpots(sx: number, sy: number, n: number): { fx: number; fy: number }[] {
  const r = rng(sx * 31 + sy * 977 + 5);
  const cand: { fx: number; fy: number; s: number }[] = [];
  for (let j = 0; j < 12; j++) for (let i = 0; i < 12; i++) {
    const fx = 0.12 + (i / 11) * 0.76, fy = 0.12 + (j / 11) * 0.76;
    let s = 0;
    for (const [dx, dy] of [[0, 0], [-0.07, -0.07], [0.07, -0.07], [-0.07, 0.07], [0.07, 0.07]]) s += landValue(sx + fx + dx, sy + fy + dy);
    cand.push({ fx, fy, s: s + r() * 0.3 });
  }
  cand.sort((a, b) => b.s - a.s);
  const out: { fx: number; fy: number }[] = [];
  for (const c of cand) { if (out.every((o) => Math.hypot(o.fx - c.fx, o.fy - c.fy) > 0.24)) out.push(c); if (out.length >= n) break; }
  for (const c of cand) { if (out.length >= n) break; if (out.every((o) => Math.hypot(o.fx - c.fx, o.fy - c.fy) > 0.14)) out.push(c); }
  return out;
}

const D = R.data, T = D.T, O = D.O;
const WP = R.World.prototype, baseTerrain = WP.genTerrain;
export const EARTH = { active: false as boolean, sector: HOME as [number, number] };
WP.genTerrain = function (this: World, rnd: () => number) {
  if (!EARTH.active || isHome(EARTH.sector)) return baseTerrain.call(this, rnd);
  const [sx, sy] = EARTH.sector, w = this.W, h = this.H, nE = R.makeNoise(sx * 131 + sy * 7 + 1), nM = R.makeNoise(sx * 17 + sy * 311 + 2);
  // the cities (already planned) sit on land, even if the land had to be built
  const rects = this.cities.concat(this.hamlets).map((c: any) => [c.x0 - 10, c.y0 - 10, c.x1 + 10, c.y1 + 10]);
  for (let y = 0; y < h; y++) {
    const v = sy + y / h, lat = latOf(v);
    for (let x = 0; x < w; x++) {
      const u = sx + x / w, i = y * w + x;
      let lv = landValue(u, v);
      if (lv < 0.56) for (const q of rects) if (x >= q[0] && y >= q[1] && x <= q[2] && y <= q[3]) { lv = 0.56; break; }
      let t: number;
      if (lv < 0.47) t = T.DEEP;
      else if (lv < 0.5) t = T.WATER;
      else if (lv < 0.525) t = T.SAND;
      else {
        const e = nE.fbm(x / 95, y / 95, 5), m = nM.fbm(x / 80, y / 80, 4), cl = climate(lonOf(u), lat);
        if (e > 0.84) t = T.ROCK;
        else if (cl === 'ice') t = e > 0.7 ? T.ROCK : T.SNOW;
        else if (cl === 'tundra') t = m > 0.55 ? T.FOREST : e > 0.6 ? T.SNOW : T.DIRT;
        else if (cl === 'desert') t = m > 0.7 ? T.DIRT : T.DESERT;
        else if (cl === 'jungle') t = m > 0.42 ? T.FOREST : m < 0.3 ? T.MARSH : T.GRASS;
        else t = m > 0.56 ? T.FOREST : m < 0.3 && e < 0.4 ? T.MARSH : T.GRASS;
      }
      this.tile[i] = t;
      const r = R.hash2(x, y, sx * 100 + sy + 5);
      let o = 0;
      if (t === T.FOREST) o = r < 0.36 ? (Math.abs(lat) > 45 ? O.PINE : Math.abs(lat) < 16 ? O.PALM : O.TREE) : r < 0.42 ? O.BUSH : 0;
      else if (t === T.GRASS) o = r < 0.018 ? O.TREE : r < 0.03 ? O.BUSH : r < 0.034 ? O.BOULDER : 0;
      else if (t === T.DESERT) o = r < 0.01 ? O.CACTUS : r < 0.018 ? O.BOULDER : r < 0.021 ? O.DEADTREE : 0;
      else if (t === T.MARSH) o = r < 0.12 ? O.REED : r < 0.15 ? O.DEADTREE : 0;
      else if (t === T.SNOW) o = r < 0.04 ? O.PINE : r < 0.06 ? O.BOULDER : 0;
      else if (t === T.DIRT) o = r < 0.02 ? O.BOULDER : r < 0.03 ? O.BUSH : 0;
      else if (t === T.SAND) o = r < 0.006 && Math.abs(lat) < 30 ? O.PALM : 0;
      this.obj[i] = o;
    }
  }
};
// no river cutting through open sea
const baseRiver = WP.genRiver;
WP.genRiver = function (this: World, rnd: () => number) { if (EARTH.active && !isHome(EARTH.sector) && landFrac(EARTH.sector[0], EARTH.sector[1]) < 0.5) return; return baseRiver.call(this, rnd); };

// ---------------------------------------------------------------- saves: keep the last few sectors
export function sectorKeyPart(s: [number, number]): string { return isHome(s) ? '' : '@' + s[0] + ',' + s[1]; }
export function touchSector(s: [number, number]): void {
  const list = ((SQ as any).sectorLRU = (SQ as any).sectorLRU || []) as string[];
  const k = s[0] + ',' + s[1];
  const i = list.indexOf(k);
  if (i >= 0) list.splice(i, 1);
  list.unshift(k);
  // the Brass Coast always keeps its save; other sectors beyond the last 8 regrow from seed
  while (list.length > 9) {
    const old = list.pop()!;
    const [x, y] = old.split(',').map(Number);
    if (!isHome([x, y])) try { localStorage.removeItem('bs.planet.earth@' + old); } catch { /* storage blocked */ }
  }
  saveSequel();
}
SECTORED.earth = (s) => earthProfile(s[0], s[1]);
