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
// the base sprite ends the jacket at the waist; a duster falls to the knee, open at the front
const baseDraw = A.drawPerson;
A.drawPerson = function (g: CanvasRenderingContext2D, x: number, y: number, dir: number, walk: number, look: any, st: any) {
  const res = baseDraw.call(this, g, x, y, dir, walk, look, st);
  const c = look && look.duster;
  if (!c || (st && (st.down || st.scale || st.crouch || st.swim || st.ride))) return res;
  const moving = walk && Math.abs(walk) > 0.01, step = moving ? Math.floor(walk * 0.5) % 4 : 0, bob = moving && step % 2 ? 1 : 0;
  const X = Math.round(x), Y = Math.round(y) - bob, sway = moving ? (step < 2 ? 1 : -1) : 0;
  const d8 = A.dir8(dir, st && st.ang);
  const box = (x0: number, y0: number, w: number, h: number, shade: number) => {
    g.fillStyle = INK; g.fillRect(x0 - 1, y0, w + 2, h + 1);
    g.fillStyle = c[shade]; g.fillRect(x0, y0, w, h);
  };
  const top = Y - 5, h = 3;
  if (d8 === 2) { // facing you: two panels under the arms, the legs showing between
    box(X - 6, top, 3, h, 1); box(X + 3, top, 3, h, 1);
    g.fillStyle = c[2]; g.fillRect(X - 4, top, 1, h - 1); g.fillRect(X + 3, top, 1, h - 1);
  } else if (d8 === 1 || d8 === 3) { // three-quarter front
    const f = d8 === 1 ? 1 : -1;
    box(f > 0 ? X - 6 : X + 3, top, 3, h, 1); box(f > 0 ? X + 3 : X - 5, top, 2, h - 1, 2);
  } else if (d8 === 6 || d8 === 5 || d8 === 7) { // from behind: one sheet with a vent up the middle
    box(X - 6, top, 12, h, 1);
    g.fillStyle = c[0]; g.fillRect(X, top + 1, 1, h - 1);
    g.fillStyle = c[2]; g.fillRect(X - 5, top, 4, 1); g.fillRect(X + 1, top, 4, 1);
  } else { // side-on: the tail swings out behind, a flap in front
    const f = d8 === 0 ? 1 : -1;
    box(f > 0 ? X - 6 - sway : X + 2 + sway, top, 4, h, 1);
    g.fillStyle = c[2]; g.fillRect(f > 0 ? X - 5 - sway : X + 2 + sway, top, 3, 1);
    box(f > 0 ? X + 1 : X - 3, top, 2, h - 1, 2);
  }
  return res;
};

export {};
