// What the protagonist wears in XX8X. Streets of Fire is the reference: Tom Cody's long
// duster over a black tee, dark jeans, boots; the soldier of fortune walking back into a
// neon city to settle things. The Protomen give the rest: a red visor helmet with a white
// fin, for the nights you'd rather not be recognised. Both are in the tailor's racks, and
// the duster is what you start in.

const A = R.art as any;
const r = R as any;
const ST = R.data.style as any;
const INK = '#1b1410';
const ramp = (a: string, b: string, c: string, d: string) => [a, b, c, d];

ST.jackets.duster = { name: 'Road Duster', price: 240, c: ramp('#2a2418', '#453a26', '#645538', '#86744e'), fancy: 1, duster: 1 };
ST.jackets.duster_black = { name: 'Black Duster', price: 260, c: ramp('#0a0a0e', '#18181e', '#2a2a32', '#44444e'), fancy: 1, duster: 1 };
ST.jackets.duster_red = { name: 'Protoman Red Duster', price: 300, c: ramp('#3a0808', '#6a1010', '#9a1c1c', '#d04040'), fancy: 1, duster: 1 };
ST.shirts.tank = { name: 'Black Tee', price: 15, c: ramp('#060608', '#101014', '#1c1c22', '#2e2e38') };
ST.pants.jeans = { name: 'Dark Jeans', price: 35, c: ramp('#0e1420', '#18223a', '#26345a', '#3a4c7a') };
ST.hats.protohelm = { name: 'Visor Helmet', price: 180 };
ST.hatCols.proto = { name: 'Proto Red', c: ['#6a1010', '#b02020', '#e04848'], band: '#f0f0f0' };

// you start as Cody
const baseDefault = r.styleDefault;
r.styleDefault = () => Object.assign(baseDefault(), { jacket: 'duster', shirt: 'tank', pants: 'jeans', top: 'tee' });

const baseLook = r.lookFromStyle;
r.lookFromStyle = function (s: any, masked: boolean) {
  const l = baseLook.call(this, s, masked);
  const j = ST.jackets[s.jacket];
  if (j && j.duster) l.duster = j.c;
  if (s.hat === 'protohelm' && !masked && !s.hatCol) l.hatCol = ST.hatCols.proto;
  return l;
};

// ---------------------------------------------------------------- the visor helmet
const baseHat = A.drawHat;
A.drawHat = function (g: CanvasRenderingContext2D, x: number, top: number, kind: string, d8: number, col: any) {
  if (kind !== 'protohelm') return baseHat.call(this, g, x, top, kind, d8, col);
  const c = (col && col.c && col !== ST.hatCols.black ? col.c : ST.hatCols.proto.c), X = Math.round(x), Y = Math.round(top);
  const back = d8 === 5 || d8 === 6 || d8 === 7, facing = d8 === 0 || d8 === 1 || d8 === 7 ? 1 : d8 === 3 || d8 === 4 || d8 === 5 ? -1 : 0;
  // the dome, down over the ears
  const dome: [number, number, number, number][] = [[-6, 3, 12, 8], [-5, 2, 10, 1], [-7, 5, 1, 6], [6, 5, 1, 6]];
  g.fillStyle = INK; for (const [dx, dy, w, h] of dome) g.fillRect(X + dx - 1, Y + dy - 1, w + 2, h + 2);
  g.fillStyle = c[1]; for (const [dx, dy, w, h] of dome) g.fillRect(X + dx, Y + dy, w, h);
  g.fillStyle = c[2]; g.fillRect(X - 4, Y + 3, 5, 1); g.fillRect(X - 5, Y + 4, 2, 2);
  g.fillStyle = c[0]; g.fillRect(X - 6, Y + 10, 12, 1);
  // the white fin down the middle (off to one side when you're side-on)
  g.fillStyle = '#f0f0f0'; g.fillRect(X - 1 - facing * 2, Y + 1, 2, back ? 8 : 5);
  if (back) return;
  // the visor: a black band with a light streak
  const vx = facing > 0 ? X - 1 : facing < 0 ? X - 6 : X - 5, vw = facing ? 7 : 10;
  g.fillStyle = INK; g.fillRect(vx - 1, Y + 8, vw + 2, 4);
  g.fillStyle = '#10141e'; g.fillRect(vx, Y + 9, vw, 2);
  g.fillStyle = '#68c8ff'; g.fillRect(vx + 1, Y + 9, 2, 1);
};

// ---------------------------------------------------------------- the duster's tails
// The base sprite ends the jacket at the waist; a duster falls to the knee. It's painted into
// each generated frame from that frame's own pixels (not pasted on top at guessed offsets), so
// it swings with the legs, never floats off the body, and never covers the hands.
const hex = (c: string) => parseInt(c.slice(1), 16);
const coated = new WeakMap<HTMLCanvasElement, HTMLCanvasElement>();
// facing: +1 = right, -1 = left, 0 = toward or away from you (after the sprite's flip)
const FACING = [1, 1, 0, -1, -1, -1, 0, 1];
const BACK = [false, false, false, false, false, true, true, true];
export function coatSprite(src: HTMLCanvasElement, ramp: string[], d8: number, frame: number): HTMLCanvasElement {
  const w = src.width, h = src.height;
  const cv = document.createElement('canvas'); cv.width = w; cv.height = h; (cv as any).res = (src as any).res;
  const g = cv.getContext('2d')!; g.drawImage(src, 0, 0);
  const im = g.getImageData(0, 0, w, h), d = im.data;
  const at = (x: number, y: number) => (y * w + x) * 4;
  const rgb = (i: number) => (d[i] << 16) | (d[i + 1] << 8) | d[i + 2];
  const cloth = new Set(ramp.map(hex));
  const set = (x: number, y: number, c: number) => { const i = at(x, y); d[i] = c >> 16; d[i + 1] = (c >> 8) & 255; d[i + 2] = c & 255; d[i + 3] = 255; };
  // the waist: the lowest row of jacket
  let waist = -1, jl = w, jr = -1;
  for (let y = 0; y < h; y++) { let n = 0; for (let x = 0; x < w; x++) { const i = at(x, y); if (d[i + 3] && cloth.has(rgb(i))) n++; } if (n >= 2) waist = y; }
  if (waist < 0) return src;
  for (let x = 0; x < w; x++) { const i = at(x, waist); if (d[i + 3] && cloth.has(rgb(i))) { jl = Math.min(jl, x); jr = Math.max(jr, x); } }
  let bottom = waist;
  for (let y = waist; y < h; y++) for (let x = 0; x < w; x++) if (d[at(x, y) + 3]) bottom = y;
  const legLen = bottom - waist;
  if (legLen < 4) return src;
  const end = waist + Math.max(2, Math.round(legLen * 0.55));
  // what the legs are made of (below the hem: trousers and boots); only those, gaps and the
  // outline get covered, so hands and whatever's in them stay on top
  const legs = new Set<number>();
  for (let y = end + 1; y <= bottom; y++) for (let x = 0; x < w; x++) { const i = at(x, y); if (d[i + 3]) legs.add(rgb(i)); }
  const covers = (x: number, y: number) => { const i = at(x, y); if (!d[i + 3]) return true; const c = rgb(i); return legs.has(c) || cloth.has(c) || ((c >> 16) + ((c >> 8) & 255) + (c & 255) < 90); };
  const ink = hex(INK), c0 = hex(ramp[1]), c1 = hex(ramp[2]), c2 = hex(ramp[3]);
  const face = FACING[d8], back = BACK[d8], cx = Math.round((jl + jr) / 2);
  // the tail swings behind with the stride
  const sway = frame === 1 ? 2 : frame === 2 ? 0 : 1;
  let pl = jl, pr = jr;
  const cols: [number, number, number][] = [];
  for (let y = waist + 1; y <= end; y++) {
    let l = w, r = -1;
    for (let x = 0; x < w; x++) if (d[at(x, y) + 3]) { l = Math.min(l, x); r = Math.max(r, x); }
    if (r < 0) { l = pl; r = pr; }
    const k = y - waist, flare = k >= 2 ? 1 : 0;
    let left = Math.min(l, jl) - flare, right = Math.max(r, jr) + flare;
    const tailL = face > 0 ? Math.min(sway, k) : 0, tailR = face < 0 ? Math.min(sway, k) : 0;
    left -= tailL; right += tailR;
    // a coat hangs; it doesn't stretch across a stride: legs step out from under it
    left = Math.max(1, left, jl - 1 - tailL); right = Math.min(w - 2, right, jr + 1 + tailR);
    cols.push([y, left, right]); pl = l; pr = r;
  }
  for (const [y, left, right] of cols) {
    for (let x = left; x <= right; x++) {
      if (!covers(x, y)) continue;
      // open at the front: the legs show between the panels
      if (!back && face === 0 && (x === cx || x === cx - 1)) continue;
      if (!back && face !== 0 && x === cx + face * 2) continue;
      const edge = x === left || x === right;
      set(x, y, edge ? ink : y === end ? c0 : back && x === cx ? c0 : x === left + 1 || (face === 0 && !back && (x === cx - 2 || x === cx + 1)) ? c2 : c1);
    }
  }
  // the hem's outline
  const hem = cols[cols.length - 1];
  if (hem && hem[0] + 1 < h) for (let x = hem[1]; x <= hem[2]; x++) { const i = at(x, hem[0] + 1); if (!d[i + 3]) set(x, hem[0] + 1, ink); }
  g.putImageData(im, 0, 0);
  return cv;
}
const baseSprite = A.oldSprite;
A.oldSprite = function (look: any, d8: number, frame: number, pose: string | null) {
  const c = baseSprite.call(this, look, d8, frame, pose);
  if (!look || !look.duster || look.kid) return c;
  let e = coated.get(c);
  // the sprite generator shades the jacket in its own ramp (dark to light): match and paint in that
  if (!e) { const L = A.oldLook(look), j = L && L.jacket && L.jacket.length >= 4 ? L.jacket : look.duster; e = coatSprite(c, j, d8, frame); coated.set(c, e); }
  return e;
};

export {};
