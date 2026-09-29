// Ten years on: the same protagonist as game 1, drawn older. The wardrobe still works
// (every hat, jacket and haircut from game 1), but the hair is salt-and-pepper, the
// temples have gone grey, there's always a shadow of stubble, and the face has lines:
// crow's feet at the eyes and folds from nose to mouth.

const A = R.art as any;
const r = R as any;

// blend a hex colour toward grey
const grey = (hex: string, k: number): string => {
  const n = parseInt(hex.slice(1), 16);
  const c = [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  const g = [150, 146, 150];
  return '#' + c.map((v, i) => Math.round(v + (g[i] - v) * k).toString(16).padStart(2, '0')).join('');
};

const baseLook = r.lookFromStyle;
r.lookFromStyle = function (s: any, masked: boolean) {
  const l = baseLook.call(this, s, masked);
  const ov = l.oldOverride || (l.oldOverride = {});
  if (Array.isArray(ov.hair)) {
    // salt and pepper: the whole ramp drifts toward grey, the highlights most
    ov.hair = ov.hair.map((c: string, i: number) => (typeof c === 'string' && c[0] === '#' ? grey(c, 0.18 + i * 0.1) : c));
    l.hairRamp = ov.hair;
  }
  // a clean-shaven face at forty-odd still shows a shadow by noon
  if (!s.facial || s.facial === 'none') { l.faceExtra = 'stubble'; }
  l.aged = true;
  l.seedStr = (l.seedStr || 'player') + '-aged';
  return l;
};

// [dx from face centre, row in the 16x32 cell, w, h, colour]
const TEMPLES = [[-6, 6, 1, 3, 'g'], [5, 6, 1, 3, 'g'], [-5, 5, 1, 1, 'g'], [4, 5, 1, 1, 'g']];
const LINES = [
  [-5, 9, 1, 1, 'l'], [4, 9, 1, 1, 'l'], // crow's feet
  [-3, 11, 1, 2, 'l'], [2, 11, 1, 2, 'l'], // nose-to-mouth folds
];
const SIDE_TEMPLE = [[-2, 6, 2, 3, 'g']];
const SIDE_LINES = [[2, 9, 1, 1, 'l'], [0, 11, 1, 2, 'l']];

const DIR8 = ['right', 'downright', 'down', 'downright', 'right', 'upright', 'up', 'upright'];
const FLIP8 = [false, false, false, true, true, true, false, false];
const paint = (g: CanvasRenderingContext2D, X: number, Y: number, list: (number | string)[][], n: string, flip: boolean) => {
  const cx = n === 'down' || n === 'up' ? 7.5 : n === 'downright' || n === 'upright' ? 9 : 10;
  const sq = n === 'right' ? 0.6 : n === 'downright' || n === 'upright' ? 0.85 : 1;
  for (const p of list) {
    const [dx, row, w, h, c] = p as [number, number, number, number, string];
    const sx = cx + dx * sq, x = flip ? 16 - sx - w : sx;
    g.fillStyle = c === 'g' ? 'rgba(200,198,204,0.8)' : 'rgba(90,50,40,0.45)';
    g.fillRect(Math.round(X - 8 + x), Math.round(Y - 25 + row), Math.max(1, Math.round(w * sq)), h);
  }
};

const draw = A.drawPerson;
A.drawPerson = function (g: CanvasRenderingContext2D, x: number, y: number, dir: number, walk: number, look: any, st: any) {
  const res = draw.call(this, g, x, y, dir, walk, look, st);
  if (!look || !look.aged || look.mask || (st && (st.down || st.scale || st.crouch))) return res;
  const moving = walk && Math.abs(walk) > 0.01, bob = moving && (Math.floor(walk * 0.5) % 4) % 2 ? 1 : 0;
  const X = Math.round(x), Y = Math.round(y) - bob;
  const d8 = A.dir8(dir, st && st.ang), n = DIR8[d8], flip = FLIP8[d8];
  if (n === 'up' || n === 'upright') return res;
  const side = n === 'right';
  if (!look.hatKind) paint(g, X, Y, side ? SIDE_TEMPLE : TEMPLES, n, flip);
  paint(g, X, Y, side ? SIDE_LINES : LINES, n, flip);
  return res;
};

export {};
