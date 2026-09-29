// People in the HeartGold/SoulSilver overworld style: 32×32 cells, a big head, a short body,
// soft 5-tone shading lit from the top-left, and a dark hue-shifted outline. Four facings
// (left is right mirrored), three frames (stand, step, step) with a head bob on the steps.
// Outfits cover the seventies space-opera factions.

import { Px } from './px';
import { ink, rampOf, mix } from './pal';
import { rng, strHash } from '../core/math';

export type Facing = 0 | 1 | 2 | 3; // down, left, right, up
export type HairStyle = 'short' | 'long' | 'afro' | 'bob' | 'bun' | 'spiky' | 'bald';
export type Outfit = 'flight' | 'suit' | 'trooper' | 'officer' | 'robe' | 'rebel' | 'lantern' | 'casual' | 'miner';

export interface Look {
  skin: string; hair: string; style: HairStyle;
  top: string; bottom: string; shoes: string;
  outfit: Outfit;
  accent?: string; // lantern colour, officer braid, rebel scarf
  visor?: boolean; // tinted shades or a trooper visor
  stache?: boolean;
}

const SKINS = ['#fce0c8', '#f4c8a4', '#e0a880', '#c08058', '#9a6040', '#6e4430'];
const HAIRS = ['#2a2230', '#4a3024', '#7a4a28', '#b07838', '#e0c070', '#c85838', '#e8e4e0', '#5a78c8'];

// a random civilian or faction member, stable per seed
export function randomLook(seed: number | string, outfit?: Outfit): Look {
  const q = rng(typeof seed === 'string' ? strHash(seed) : seed);
  const o: Outfit = outfit || q.pick(['casual', 'casual', 'suit', 'flight', 'miner', 'rebel'] as Outfit[]);
  const tops: Record<Outfit, string[]> = {
    flight: ['#e8742a', '#d8c040', '#4a7ad0', '#c83a48'],
    suit: ['#3a2a4a', '#5a3a28', '#2a3a5a', '#7a2a3a', '#e8dcc0'],
    trooper: ['#eceef4'],
    officer: ['#3a4250'],
    robe: ['#6a3a8a', '#8a2a4a'],
    rebel: ['#8a6a3a', '#5a6a3a', '#7a4a2a'],
    lantern: ['#2a2a30'],
    casual: ['#e85a8a', '#4ab8a8', '#f0a030', '#7a5ad0', '#58b050', '#e8e0c8'],
    miner: ['#d88a2a', '#6a7a88'],
  };
  const bottoms: Record<Outfit, string[]> = {
    flight: ['#3a3a48'], suit: ['#2a2230', '#4a3a2a'], trooper: ['#dfe2ea'], officer: ['#2a3040'], robe: ['#4a2a6a'],
    rebel: ['#4a4a38', '#3a3a4a'], lantern: ['#2a2a30'], casual: ['#3a5a9a', '#6a4a2a', '#2a2a38', '#8a6a4a'], miner: ['#4a4a50'],
  };
  return {
    skin: q.pick(SKINS), hair: q.pick(HAIRS), style: q.pick(['short', 'long', 'afro', 'bob', 'bun', 'spiky', 'short', 'bald'] as HairStyle[]),
    top: q.pick(tops[o]), bottom: q.pick(bottoms[o]), shoes: q.pick(['#2a2028', '#5a3a28', '#e8e4dc']),
    outfit: o, accent: o === 'lantern' ? '#58e058' : o === 'officer' ? '#e8c040' : o === 'rebel' ? '#e85838' : undefined,
    visor: o === 'trooper' || q.chance(0.15), stache: q.chance(0.2),
  };
}

const cache = new Map<string, HTMLCanvasElement>();

export function personSprite(L: Look, facing: Facing, frame: number): HTMLCanvasElement {
  const key = JSON.stringify(L) + facing + ':' + frame;
  let c = cache.get(key);
  if (!c) {
    const right = facing === 1 ? paint(L, 2, frame).flipX() : paint(L, facing, frame);
    c = right.canvas();
    if (cache.size > 3000) cache.clear();
    cache.set(key, c);
  }
  return c;
}

// light from the top-left: pick a tone from a 5-step ramp by a normalised position
const shade = (r: string[], nx: number, ny: number) => {
  const l = -nx * 0.5 - ny * 0.7;
  return l > 0.55 ? r[4] : l > 0.15 ? r[3] : l > -0.35 ? r[2] : r[1];
};

function paint(L: Look, f: Facing, frame: number): Px {
  const p = new Px(32, 32);
  const skin = rampOf(L.skin), hair = rampOf(L.hair), top = rampOf(L.top), bot = rampOf(L.bottom), shoe = rampOf(L.shoes);
  const step = frame === 0 ? 0 : frame === 1 ? 1 : -1;
  const bob = step ? 1 : 0; // the head and body drop a pixel mid-stride
  const side = f === 2, back = f === 3;
  const cx = 16;
  const trooper = L.outfit === 'trooper', robe = L.outfit === 'robe';

  // --- legs and shoes (feet on row 30)
  const legTop = 22 + bob;
  if (!robe) {
    if (side) {
      // one leg forward, one back
      const fwd = step, a = cx - 1 + fwd, b = cx - 1 - fwd;
      p.rect(b, legTop, 3, 30 - legTop - 1, bot[1]); p.rect(b, 29, 4, 2, shoe[1]);
      p.rect(a, legTop, 3, 30 - legTop - 1, bot[2]); p.vline(a, legTop, 28, bot[3]); p.rect(a, 29, 4, 2, shoe[2]); p.set(a + 3, 29, shoe[3]);
    } else {
      const lOff = step === 1 ? -1 : 0, rOff = step === -1 ? -1 : 0;
      p.rect(cx - 4, legTop, 3, 29 - legTop + lOff, bot[2]); p.vline(cx - 4, legTop, 28 + lOff, bot[3]);
      p.rect(cx + 1, legTop, 3, 29 - legTop + rOff, bot[1]); p.vline(cx + 3, legTop, 28 + rOff, bot[0]);
      p.rect(cx - 5, 29 + lOff, 4, 2, shoe[2]); p.set(cx - 5, 29 + lOff, shoe[3]);
      p.rect(cx + 1, 29 + rOff, 4, 2, shoe[1]);
    }
  }

  // --- body
  const bodyTop = 15 + bob, bodyH = robe ? 30 - bodyTop : 8;
  const bw = side ? 7 : 10, bx = cx - Math.floor(bw / 2);
  for (let y = 0; y < bodyH; y++)
    for (let x = 0; x < bw; x++) {
      const nx = (x - bw / 2 + 0.5) / (bw / 2), ny = (y - bodyH / 2) / bodyH;
      let c = shade(top, nx, ny);
      if (robe && y > 8) { const flare = Math.floor((y - 8) / 3); if (x === 0 || x === bw - 1) c = top[1]; if (x < -flare || x > bw + flare) continue; }
      p.set(bx + x, bodyTop + y, c);
    }
  if (robe) { for (let y = 8; y < bodyH; y++) { const flare = Math.floor((y - 8) / 4); p.hline(bx - flare, bx - 1, bodyTop + y, top[1]); p.hline(bx + bw, bx + bw - 1 + flare, bodyTop + y, top[1]); } }
  // outfit details
  if (!back) {
    if (L.outfit === 'suit') { p.vline(cx, bodyTop + 1, bodyTop + 6, '#f4ecdc'); p.set(cx, bodyTop + 2, '#c83a3a'); p.set(cx, bodyTop + 3, '#c83a3a'); if (!side) { p.set(cx - 2, bodyTop + 1, top[0]); p.set(cx + 2, bodyTop + 1, top[0]); } }
    if (L.outfit === 'flight') { p.hline(bx, bx + bw - 1, bodyTop + 5, '#303040'); p.set(cx + (side ? 1 : 2), bodyTop + 2, '#e8e0c8'); if (!side) p.vline(cx - 1, bodyTop, bodyTop + 4, top[3]); }
    if (L.outfit === 'officer') { p.hline(bx, bx + bw - 1, bodyTop, L.accent || '#e8c040'); p.set(cx + 2, bodyTop + 2, L.accent || '#e8c040'); p.set(cx + 3, bodyTop + 2, '#c83a3a'); p.hline(bx, bx + bw - 1, bodyTop + 6, '#1a1a22'); }
    if (L.outfit === 'trooper') { p.hline(bx + 1, bx + bw - 2, bodyTop + 3, '#9aa0b0'); p.set(cx, bodyTop + 1, '#3a3e4a'); p.hline(bx, bx + bw - 1, bodyTop + 6, '#3a3e4a'); }
    if (L.outfit === 'rebel') { p.hline(bx, bx + bw - 1, bodyTop, L.accent || '#e85838'); p.set(bx + 1, bodyTop + 1, L.accent || '#e85838'); p.vline(bx + bw - 2, bodyTop + 1, bodyTop + 7, '#3a2a1a'); }
    if (L.outfit === 'lantern') { const a = L.accent || '#58e058'; p.oval(cx + (side ? 1 : 0), bodyTop + 3, 2, 2, () => a); p.set(cx + (side ? 1 : 0), bodyTop + 3, '#1a1a22'); p.hline(bx, bx + bw - 1, bodyTop + 6, a); }
    if (L.outfit === 'miner') { p.hline(bx, bx + bw - 1, bodyTop + 3, '#f0e060'); p.hline(bx, bx + bw - 1, bodyTop + 4, '#b0b0b0'); }
    if (L.outfit === 'robe') { p.vline(cx, bodyTop + 1, bodyTop + bodyH - 1, top[0]); p.set(cx, bodyTop + 3, '#f0e080'); }
  }
  // arms swing opposite the legs
  const armC = trooper ? top : L.outfit === 'casual' || L.outfit === 'miner' ? top : top;
  if (side) {
    const sw = -step;
    p.rect(cx + sw, bodyTop + 1, 2, 6, armC[1]); p.rect(cx + sw, bodyTop + 7, 2, 2, trooper ? '#3a3e4a' : skin[2]);
  } else {
    const sl = step === 1 ? 1 : 0, sr = step === -1 ? 1 : 0;
    p.rect(bx - 2, bodyTop + 1 + sl, 2, 6, armC[3]); p.rect(bx - 2, bodyTop + 7 + sl, 2, 2, trooper ? '#3a3e4a' : skin[3]);
    p.rect(bx + bw, bodyTop + 1 + sr, 2, 6, armC[1]); p.rect(bx + bw, bodyTop + 7 + sr, 2, 2, trooper ? '#3a3e4a' : skin[1]);
  }

  // --- head: 14×13, the HGSS big-head proportion
  const hcx = cx + (side ? 1 : 0), hcy = 9 + bob, hrx = side ? 6.2 : 7, hry = 6.6;
  if (trooper) {
    // a white helmet with a dark visor band
    p.oval(hcx, hcy, hrx, hry, (nx, ny) => shade(['#8a90a0', '#b8bec8', '#dfe2ea', '#f4f6fa', '#ffffff'], nx, ny));
    if (!back) { const vx = side ? hcx - 1 : hcx - 5; p.rect(vx, hcy - 1, side ? 7 : 10, 3, '#1c2030'); p.set(vx + 1, hcy - 1, '#5a6a90'); p.hline(hcx - 2, hcx + 2, hcy + 4, '#6a7080'); }
    else p.hline(hcx - 5, hcx + 5, hcy + 2, '#9aa0b0');
  } else {
    p.oval(hcx, hcy + 0.5, hrx, hry, (nx, ny) => shade(skin, nx, ny));
    // hair
    const H = (nx: number, ny: number) => shade(hair, nx, ny);
    const st = L.style;
    if (st !== 'bald') {
      if (back) {
        p.oval(hcx, hcy, hrx + 0.3, hry + 0.3, H);
        if (st === 'long' || st === 'bob') p.rect(hcx - 6, hcy + 2, 13, st === 'long' ? 7 : 4, hair[1]);
      } else {
        // a fringe over the top third, sides down past the ears
        p.oval(hcx, hcy - 1.5, hrx + 0.4, hry - 1.2, (nx, ny, x, y) => (y < hcy - 1 + (side ? 0 : Math.abs(nx) * 2) ? H(nx, ny) : null));
        if (side) { p.rect(hcx - 6, hcy - 3, 3, 6, hair[1]); if (st === 'long' || st === 'bob') p.rect(hcx - 6, hcy + 2, 4, st === 'long' ? 6 : 3, hair[1]); }
        else {
          p.rect(hcx - 7, hcy - 2, 2, st === 'long' ? 11 : st === 'bob' ? 7 : 4, hair[2]);
          p.rect(hcx + 6, hcy - 2, 2, st === 'long' ? 11 : st === 'bob' ? 7 : 4, hair[1]);
        }
      }
      if (st === 'afro') p.oval(hcx, hcy - 2, hrx + 2.5, hry + 0.5, (nx, ny, x, y) => (y < hcy + 1 || Math.abs(nx) > 0.78 ? H(nx, ny) : null));
      if (st === 'bun') p.oval(hcx + (side ? -3 : 0), hcy - 7, 3, 2.5, H);
      if (st === 'spiky') for (let k = -2; k <= 2; k++) p.line(hcx + k * 2, hcy - 5, hcx + k * 3, hcy - 9, hair[k < 0 ? 3 : 2]);
      // the Gen 4 shine: a bright arc across the crown
      p.hline(hcx - 3, hcx, hcy - 5 - (st === 'afro' ? 2 : 0), mix(hair[4], '#ffffff', 0.4));
      p.set(hcx - 4, hcy - 4 - (st === 'afro' ? 2 : 0), hair[4]);
    }
    if (L.outfit === 'robe') p.oval(hcx, hcy - 1, hrx + 1, hry + 0.8, (nx, ny, x, y) => (back || y < hcy - 2 || Math.abs(nx) > 0.72 ? shade(top, nx, ny) : null));
    if (L.outfit === 'miner') { p.oval(hcx, hcy - 3, hrx + 0.5, 4, (nx, ny, x, y) => (y < hcy - 1 ? shade(['#8a6a1a', '#b88a2a', '#e0b030', '#f0d060', '#fff0a0'], nx, ny) : null)); if (!back) { p.rect(hcx - 1 + (side ? 3 : 0), hcy - 6, 3, 2, '#fffbe0'); } }
    // face
    if (!back) {
      const ey = hcy + 1;
      const eye = (x: number) => { p.set(x, ey, '#1c1828'); p.set(x, ey + 1, '#1c1828'); p.set(x, ey - 1, '#3a3050'); };
      if (L.visor) { if (side) p.hline(hcx + 1, hcx + 5, ey, '#2a2438'); else { p.hline(hcx - 4, hcx + 4, ey, '#2a2438'); p.set(hcx - 3, ey, '#8aa0d0'); } }
      else if (side) eye(hcx + 3);
      else { eye(hcx - 3); eye(hcx + 3); p.set(hcx - 5, ey + 3, mix(skin[3], '#f08080', 0.45)); p.set(hcx + 5, ey + 3, mix(skin[2], '#f08080', 0.45)); }
      if (L.stache) { if (side) p.hline(hcx + 2, hcx + 5, ey + 3, hair[1]); else p.hline(hcx - 2, hcx + 2, ey + 3, hair[1]); }
      else if (!side) p.set(hcx, ey + 3, skin[0]);
    }
  }
  p.outline(ink);
  return p;
}
