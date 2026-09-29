// Planet definitions and the district generator. Each landable planet is generated from a seed
// plus its definition: ground, what grows, what's built, who walks the streets. The prototype
// generates one spaceport district per planet; the full game will stitch several together.

import { T, SOLID } from '../gfx/tiles';
import type { BuildingKind, PropKind } from '../gfx/buildings';
import { randomLook, type Look, type Outfit } from '../gfx/people';
import { rng, type Rng } from '../core/math';

export type PlanetId = 'veridia' | 'castra' | 'hollow';

export interface PlanetDef {
  id: PlanetId; name: string; blurb: string; faction: string;
  ground: number; street: number; soft: number[]; // soft = patches (tall grass, flowers, sand)
  water: boolean; trees: PropKind[]; street_props: PropKind[];
  buildings: { kind: BuildingKind; name: string; w: number; h: number }[];
  outfits: Outfit[]; color: string; radius: number; orbit: number; period: number; landable: boolean;
  lines: string[];
}

export const PLANETS: Record<PlanetId, PlanetDef> = {
  veridia: {
    id: 'veridia', name: 'Veridia', faction: 'the Solari families', blurb: 'A green trade world. Casinos, gardens and money that never sleeps.',
    ground: T.GRASS, street: T.PLAZA, soft: [T.TALL, T.FLOWERS], water: true, trees: ['tree', 'tree', 'bush'], street_props: ['lamp', 'bench', 'lamp', 'sign'],
    buildings: [
      { kind: 'terminal', name: 'Pad Control', w: 8, h: 4 }, { kind: 'shipyard', name: 'Solari Shipworks', w: 8, h: 4 }, { kind: 'market', name: 'Emerald Exchange', w: 6, h: 3 },
      { kind: 'casino', name: 'The Green Mile Casino', w: 8, h: 4 }, { kind: 'cantina', name: 'Cantina Veridia', w: 6, h: 3 }, { kind: 'shop', name: 'Outfitter', w: 5, h: 3 },
      { kind: 'house', name: 'Villa', w: 5, h: 3 }, { kind: 'house', name: 'Villa', w: 4, h: 3 }, { kind: 'house', name: 'Villa', w: 5, h: 3 }, { kind: 'house', name: 'Villa', w: 4, h: 3 },
    ],
    outfits: ['casual', 'suit', 'suit', 'flight', 'casual', 'officer'], color: '#58b458', radius: 90, orbit: 1500, period: 900, landable: true,
    lines: [
      'The Solari run the pads, the cards and the cops. In that order.',
      'Lost my shirt at the Green Mile. Literally. Bet it on red.',
      'Freighters out of Castra run heavy on Tuesdays. Just saying.',
      'You smell like engine grease and bad decisions. Welcome to Veridia.',
      'Don Solari\'s nephew got made last week. Big party. Bigger funeral after.',
      'My cousin swears he saw a green light in the sky over the gardens. Like a lantern.',
    ],
  },
  castra: {
    id: 'castra', name: 'Castra Prime', faction: 'the Galactic Empire', blurb: 'The Empire\'s marble capital. Landing clearance required (next build).',
    ground: T.PLAZA, street: T.PLAZA, soft: [T.FLOWERS], water: true, trees: ['tree'], street_props: ['lamp', 'sign'],
    buildings: [], outfits: ['trooper', 'officer'], color: '#d8d4e8', radius: 120, orbit: 2700, period: 1500, landable: false, lines: [],
  },
  hollow: {
    id: 'hollow', name: 'Hollow Moon', faction: 'nobody (the Choir, the rebels)', blurb: 'A dusty mining moon. No law, a black market, and hymns on the radio at night.',
    ground: T.DUST, street: T.PATH, soft: [T.SAND], water: false, trees: ['crystal', 'rock', 'rock'], street_props: ['antenna', 'lamp', 'crate'],
    buildings: [
      { kind: 'terminal', name: 'Dust Port', w: 8, h: 4 }, { kind: 'market', name: 'Black Market', w: 6, h: 3 }, { kind: 'cantina', name: 'The Last Shift', w: 6, h: 3 },
      { kind: 'dome', name: 'Choir Dome', w: 7, h: 4 }, { kind: 'hab', name: 'Hab Block', w: 5, h: 3 }, { kind: 'hab', name: 'Hab Block', w: 5, h: 3 }, { kind: 'dome', name: 'Hydro Dome', w: 6, h: 4 },
      { kind: 'shipyard', name: 'Salvage Yard', w: 7, h: 4 },
    ],
    outfits: ['miner', 'miner', 'rebel', 'robe', 'casual'], color: '#bc8c6c', radius: 60, orbit: 3900, period: 2200, landable: true,
    lines: [
      'The Choir says the signal\'s getting louder. I say it\'s the air recyclers.',
      'Black market buys anything. No questions. No refunds.',
      'Rebels pay in promises. Promises don\'t buy air.',
      'Imperial patrols don\'t come out this far. Usually.',
      'You hear the hymn at night? From the dome? Don\'t go listening.',
      'Mine shaft four sings when the wind blows. Everybody pretends it doesn\'t.',
    ],
  },
};

export interface Building { kind: BuildingKind; name: string; x: number; y: number; w: number; h: number; seed: number; door: { x: number; y: number } }
export interface Prop { kind: PropKind; x: number; y: number; v: number }
export interface Npc { id: number; x: number; y: number; look: Look; facing: 0 | 1 | 2 | 3; walk: number; tx: number; ty: number; wait: number; line: string; name: string }

export interface District {
  def: PlanetDef; W: number; H: number;
  tile: Uint8Array; block: Int16Array; // block: building index + 1, or -1 for a solid prop
  buildings: Building[]; props: Prop[]; npcs: Npc[];
  pad: { x: number; y: number; w: number; h: number }; ship: { x: number; y: number };
  t(x: number, y: number): number;
  solid(x: number, y: number): boolean;
}

const FIRST = ['Rico', 'Dolly', 'Vance', 'Mira', 'Otis', 'Lux', 'Tanya', 'Barnaby', 'Cleo', 'Dex', 'Faye', 'Gus', 'Iris', 'Jojo', 'Kit', 'Lolo', 'Moss', 'Nova', 'Pip', 'Roxy', 'Sly', 'Tex', 'Vera', 'Zed'];
const LAST = ['Solari', 'Venn', 'Kade', 'Orlov', 'Marsh', 'Dune', 'Quill', 'Strand', 'Holt', 'Voss', 'Crane', 'Lark'];

export function generate(id: PlanetId, seed: number): District {
  const def = PLANETS[id];
  const q = rng(seed ^ 0x51f00d);
  const W = 72, H = 56;
  const tile = new Uint8Array(W * H).fill(def.ground);
  const block = new Int16Array(W * H);
  const idx = (x: number, y: number) => y * W + x;
  const inb = (x: number, y: number) => x >= 0 && y >= 0 && x < W && y < H;
  const set = (x: number, y: number, t: number) => { if (inb(x, y)) tile[idx(x, y)] = t; };
  const rect = (x: number, y: number, w: number, h: number, t: number) => { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) set(x + i, y + j, t); };

  // soft patches: blobs of tall grass / flowers / sand
  for (let k = 0; k < 26; k++) {
    const cx = q.int(2, W - 3), cy = q.int(2, H - 3), r = q.int(2, 4), t = q.pick(def.soft);
    for (let j = -r; j <= r; j++) for (let i = -r; i <= r; i++) if (i * i + j * j <= r * r + q.int(-1, 1)) set(cx + i, cy + j, t);
  }
  // Veridia: a lake in one corner and a river out of it; Hollow Moon: rock ridges
  if (def.water) {
    const lx = q.chance(0.5) ? 10 : W - 12, ly = H - 11;
    for (let j = -6; j <= 6; j++) for (let i = -8; i <= 8; i++) if ((i * i) / 64 + (j * j) / 36 <= 1 + q.int(-1, 0) * 0.08) set(lx + i, ly + j, T.WATER);
    for (let y = ly; y < H; y++) { set(lx + Math.round(Math.sin(y * 0.4) * 2), y, T.WATER); set(lx + 1 + Math.round(Math.sin(y * 0.4) * 2), y, T.WATER); }
  } else {
    for (let k = 0; k < 7; k++) { const x = q.int(3, W - 10), y = q.int(3, H - 6), w = q.int(3, 7); rect(x, y, w, 2, T.ROCK); }
  }

  // the spaceport: a landing pad in the middle with the terminal north of it
  const pad = { x: Math.floor(W / 2) - 6, y: Math.floor(H / 2) - 3, w: 12, h: 8 };
  rect(pad.x - 2, pad.y - 2, pad.w + 4, pad.h + 4, def.street);
  rect(pad.x, pad.y, pad.w, pad.h, T.PAD);
  // main streets: a cross through the pad plus a ring road
  const sx = Math.floor(W / 2), sy = Math.floor(H / 2);
  rect(sx - 1, 1, 3, H - 2, def.street); rect(1, sy - 1, W - 2, 3, def.street);
  rect(6, 6, W - 12, 2, def.street); rect(6, H - 8, W - 12, 2, def.street); rect(6, 6, 2, H - 12, def.street); rect(W - 8, 6, 2, H - 12, def.street);

  // buildings: fit each onto a free lot beside a street, door facing the street
  const buildings: Building[] = [];
  const free = (x: number, y: number, w: number, h: number) => {
    if (x < 2 || y < 2 || x + w > W - 2 || y + h + 1 > H - 2) return false;
    for (let j = -1; j <= h + 1; j++) for (let i = -1; i <= w; i++) {
      if (!inb(x + i, y + j)) return false;
      const t = tile[idx(x + i, y + j)];
      if (block[idx(x + i, y + j)] || t === T.WATER || t === T.PAD || t === T.ROCK) return false;
      if (j < h && t === def.street) return false;
    }
    return true;
  };
  const place = (b: { kind: BuildingKind; name: string; w: number; h: number }, prefer?: { x: number; y: number }) => {
    for (let tries = 0; tries < 900; tries++) {
      const x = prefer && tries < 40 ? prefer.x + q.int(-2, 2) : q.int(3, W - b.w - 3);
      const y = prefer && tries < 40 ? prefer.y + q.int(-1, 1) : q.int(3, H - b.h - 4);
      if (!free(x, y, b.w, b.h)) continue;
      // the door opens onto the row below the building; make sure it's a street, or lay a path to one
      const dx = x + Math.floor(b.w / 2), dy = y + b.h;
      const bi = buildings.length;
      for (let j = 0; j < b.h; j++) for (let i = 0; i < b.w; i++) block[idx(x + i, y + j)] = bi + 1;
      if (tile[idx(dx, dy)] !== def.street) {
        for (let yy = dy; yy < H - 1; yy++) { if (tile[idx(dx, yy)] === def.street) break; set(dx, yy, def.id === 'hollow' ? T.PATH : T.PATH); }
      }
      buildings.push({ ...b, x, y, seed: q.int(1, 1e6), door: { x: dx, y: dy } });
      return true;
    }
    return false;
  };
  const [terminal, ...rest] = def.buildings;
  if (terminal) place(terminal, { x: sx - Math.floor(terminal.w / 2), y: pad.y - terminal.h - 3 });
  for (const b of rest) place(b);

  // props: trees and rocks in the open, lamps and furniture along streets, a border of trees
  const props: Prop[] = [];
  const addProp = (kind: PropKind, x: number, y: number) => {
    if (!inb(x, y) || block[idx(x, y)] || SOLID.has(tile[idx(x, y)]) || tile[idx(x, y)] === T.PAD) return;
    if (tile[idx(x, y)] === def.street && kind !== 'lamp' && kind !== 'bench' && kind !== 'sign' && kind !== 'crate' && kind !== 'antenna') return;
    block[idx(x, y)] = -1;
    props.push({ kind, x, y, v: q.int(0, 5) });
  };
  for (let x = 0; x < W; x++) { addProp(def.trees[0], x, 0); addProp(def.trees[0], x, H - 1); }
  for (let y = 0; y < H; y++) { addProp(def.trees[0], 0, y); addProp(def.trees[0], W - 1, y); }
  for (let k = 0; k < 110; k++) {
    const x = q.int(1, W - 2), y = q.int(1, H - 2);
    if (tile[idx(x, y)] === def.street || tile[idx(x, y)] === T.PATH) continue;
    // keep a ring around the pad clear
    if (x > pad.x - 4 && x < pad.x + pad.w + 4 && y > pad.y - 4 && y < pad.y + pad.h + 4) continue;
    addProp(q.pick(def.trees), x, y);
  }
  // street furniture on the street edges
  for (let k = 0; k < 60; k++) {
    const x = q.int(2, W - 3), y = q.int(2, H - 3);
    if (tile[idx(x, y)] !== def.street) continue;
    const edge = tile[idx(x, y - 1)] !== def.street || tile[idx(x, y + 1)] !== def.street || tile[idx(x - 1, y)] !== def.street || tile[idx(x + 1, y)] !== def.street;
    if (!edge || (x > pad.x - 3 && x < pad.x + pad.w + 3 && y > pad.y - 3 && y < pad.y + pad.h + 3)) continue;
    if (buildings.some((b) => Math.abs(b.door.x - x) <= 1 && Math.abs(b.door.y - y) <= 1)) continue;
    addProp(q.pick(def.street_props), x, y);
  }

  const d: District = {
    def, W, H, tile, block, buildings, props, npcs: [], pad, ship: { x: (pad.x + pad.w / 2) * 16, y: (pad.y + pad.h / 2) * 16 },
    t: (x, y) => (inb(x, y) ? tile[idx(x, y)] : T.VOID),
    solid: (x, y) => !inb(x, y) || SOLID.has(tile[idx(x, y)]) || block[idx(x, y)] !== 0,
  };
  d.npcs = makeNpcs(d, q);
  return d;
}

function makeNpcs(d: District, q: Rng): Npc[] {
  const out: Npc[] = [];
  for (let k = 0; k < 22; k++) {
    for (let tries = 0; tries < 50; tries++) {
      const x = q.int(3, d.W - 4), y = q.int(3, d.H - 4);
      if (d.solid(x, y) || d.t(x, y) === T.PAD) continue;
      const outfit = q.pick(d.def.outfits);
      out.push({
        id: k, x: x * 16 + 8, y: y * 16 + 8, look: randomLook(d.def.id + k * 7919, outfit), facing: 0, walk: 0, tx: x * 16 + 8, ty: y * 16 + 8, wait: q.int(0, 3),
        line: q.pick(d.def.lines), name: `${q.pick(FIRST)} ${q.pick(LAST)}`,
      });
      break;
    }
  }
  return out;
}
