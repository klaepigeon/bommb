// RHAPSODY — the full Seventies closet. Dozens more jackets, shirts, slacks and hats, a
// wall of hair colours, and haircuts and whiskers the old painter never knew: pompadour,
// mullet, mohawk, buzz, Jheri curl, feathered, locs, comb-over; goatee, mutton chops,
// handlebar, Fu Manchu, soul patch, stubble. New cuts start from the nearest classic
// shape and get painted over it, so they move and turn like everything else.
'use strict';
(function () {
  const D = R.data, ST = D.style;
  const ramp = (a, b, c, d) => [a, b, c, d];
  const add = (cat, entries) => Object.assign(ST[cat], entries);

  add('jackets', {
    safari: { name: 'Safari Jacket', price: 95, c: ramp('#4a4020', '#6e6030', '#948448', '#b8a868') },
    suede: { name: 'Fringed Suede', price: 140, c: ramp('#4a2a14', '#6e4020', '#946034', '#b8844c') },
    windbreak: { name: 'Racing Windbreaker', price: 70, c: ramp('#5a0a0a', '#8a1414', '#c02424', '#e85040') },
    peacoat: { name: 'Navy Peacoat', price: 130, c: ramp('#0c1224', '#141e3a', '#1e2c54', '#2e4274'), fancy: 1 },
    tweed: { name: 'Tweed Jacket', price: 120, c: ramp('#3a3224', '#5a4c38', '#7a6a50', '#9c8a6c'), fancy: 1 },
    pinstripe: { name: 'Pinstripe Double-Breast', price: 280, c: ramp('#10101a', '#1c1c2c', '#2c2c42', '#4a4a66'), fancy: 1 },
    gold: { name: 'Gold Lamé Blazer', price: 350, c: ramp('#6a4a08', '#a07818', '#d8a830', '#ffe070'), fancy: 1 },
    lime: { name: 'Lime Leisure Suit', price: 85, c: ramp('#2a4a0a', '#4a7414', '#6ea424', '#9ad048') },
    mauve: { name: 'Mauve Tux', price: 240, c: ramp('#3a1a2a', '#5c2c44', '#844462', '#aa6a88'), fancy: 1 },
    varsity: { name: 'Varsity Letterman', price: 75, c: ramp('#1a0a0a', '#3a1010', '#5c1c1c', '#843030') },
    trench: { name: 'Trench Coat', price: 190, c: ramp('#4a3c24', '#6c5a38', '#907a50', '#b09a6c'), fancy: 1 },
    shearling: { name: 'Shearling Coat', price: 260, c: ramp('#4a2e18', '#6a4424', '#8c5e34', '#d8c8a8') },
    patchwork: { name: 'Patchwork Denim', price: 90, c: ramp('#1c2c48', '#6a3a24', '#40609a', '#c8ac48') },
    snake: { name: 'Snakeskin Jacket', price: 320, c: ramp('#2a3a18', '#4a5a24', '#6c7c38', '#a0aa60'), fancy: 1 },
    tracktop: { name: 'Track Top', price: 45, c: ramp('#0a2a4a', '#144070', '#2060a0', '#f0f0f0') },
  });
  add('shirts', {
    teal: { name: 'Teal Silk', price: 35, c: ramp('#0a3a3a', '#145a5a', '#248282', '#48b0a8') },
    brown: { name: 'Chocolate', price: 20, c: ramp('#2a1408', '#442412', '#62381e', '#86522e') },
    lavender: { name: 'Lavender', price: 30, c: ramp('#4a3a6a', '#6a5a92', '#9080bc', '#bcaee0') },
    red: { name: 'Fire Engine Red', price: 25, c: ramp('#4a0808', '#7a1010', '#b02020', '#e04848') },
    canary: { name: 'Canary Yellow', price: 25, c: ramp('#7a6a0a', '#b09a14', '#e0c828', '#fff080') },
    tan: { name: 'Tan', price: 20, c: ramp('#5a4428', '#806440', '#a8885c', '#ccac80') },
    hawaii: { name: 'Hawaiian Print', price: 40, c: ramp('#0a4a3a', '#e05a2a', '#2a8a5a', '#f0d040') },
    silver: { name: 'Silver Satin', price: 45, c: ramp('#5a5a64', '#8a8a96', '#b8b8c4', '#e8e8f4') },
    mint: { name: 'Mint', price: 25, c: ramp('#2a5a44', '#4a8468', '#72ac8c', '#a0d8b8') },
    rust: { name: 'Rust Paisley', price: 35, c: ramp('#4a1a08', '#7a2c10', '#a8461c', '#d86c34') },
    denim: { name: 'Chambray', price: 20, c: ramp('#2c3c58', '#40587c', '#5c7aa0', '#84a2c4') },
    navy: { name: 'Navy', price: 20, c: ramp('#0c1224', '#141e3a', '#1e2c54', '#2e4274') },
  });
  add('pants', {
    burgundy: { name: 'Burgundy Flares', price: 40, c: ramp('#2a060e', '#4a0c18', '#6c1626', '#942c3c') },
    olive: { name: 'Olive Cargo', price: 30, c: ramp('#242a14', '#384020', '#4e5a2e', '#6a7840') },
    grey: { name: 'Grey Wool Slacks', price: 45, c: ramp('#2a2a30', '#44444c', '#62626c', '#848490') },
    corduroy: { name: 'Corduroy Flares', price: 35, c: ramp('#3a2410', '#5a3a1c', '#7c522c', '#a0703e') },
    tan: { name: 'Tan Chinos', price: 30, c: ramp('#5a4428', '#806440', '#a8885c', '#ccac80') },
    purple: { name: 'Purple Bell-Bottoms', price: 45, c: ramp('#2a1a4a', '#44306e', '#664c98', '#9078c0') },
    leather: { name: 'Black Leather', price: 90, c: ramp('#060608', '#121216', '#202028', '#3a3a46') },
    pinstripe: { name: 'Pinstripe Slacks', price: 60, c: ramp('#10101a', '#1c1c2c', '#2c2c42', '#4a4a66') },
    red: { name: 'Red Flares', price: 40, c: ramp('#4a0808', '#7a1010', '#b02020', '#e04848') },
  });
  add('hats', {
    boater: { name: 'Straw Boater', price: 40 }, tophat: { name: 'Top Hat', price: 90 }, beret: { name: 'Beret', price: 30 },
    homburg: { name: 'Homburg', price: 75 }, panama: { name: 'Panama', price: 55 }, bucket: { name: 'Bucket Hat', price: 20 },
    trucker: { name: 'Trucker Cap', price: 15 }, captain: { name: 'Captain\'s Hat', price: 50 }, sombrero: { name: 'Sombrero', price: 45 },
  });
  add('hatCols', {
    white: { name: 'White', c: ['#b8b8b0', '#e0e0d8', '#fafaf4'], band: '#141414' },
    green: { name: 'Hunter Green', c: ['#10240e', '#1c3a18', '#2c5424'], band: '#c8ac48' },
    purple: { name: 'Purple', c: ['#1a0e2a', '#2c1c44', '#44306a'], band: '#e8e0c8' },
    straw: { name: 'Straw', c: ['#8a6a30', '#c09a50', '#e8c878'], band: '#6a1c26' },
  });
  add('hairCols', {
    platinum: { name: 'Platinum', c: ramp('#9a9488', '#cec8b8', '#ece6d6', '#ffffff') },
    ginger: { name: 'Ginger', c: ramp('#5a1a08', '#a03c14', '#d8642a', '#f8964c') },
    copper: { name: 'Copper', c: ramp('#3a1a08', '#6a3212', '#9a4e20', '#c47034') },
    saltpepper: { name: 'Salt & Pepper', c: ramp('#2a2a30', '#54545e', '#8a8a94', '#c4c4cc') },
    blueblack: { name: 'Blue-Black', c: ramp('#06081a', '#0e1430', '#1a2448', '#2e3c6a') },
    chestnut: { name: 'Chestnut', c: ramp('#2a1208', '#4a2210', '#6c361c', '#90502c') },
    pink: { name: 'Disco Pink', c: ramp('#6a1a4a', '#a0306e', '#d85098', '#ff88c8') },
  });
  // haircuts beyond the painter's own, each built on a base cut
  const HAIR_EXTRA = {
    pompadour: { name: 'Pompadour', base: 'short' },
    mullet: { name: 'Mullet', base: 'short' },
    mohawk: { name: 'Mohawk', base: 'bald' },
    buzz: { name: 'Buzz Cut', base: 'bald' },
    jheri: { name: 'Jheri Curl', base: 'afro' },
    feathered: { name: 'Feathered', base: 'shag' },
    locs: { name: 'Locs', base: 'long' },
    combover: { name: 'Comb-Over', base: 'bald' },
    bob: { name: 'Bob', base: 'bob' },
  };
  for (const k in HAIR_EXTRA) ST.hair[k] = HAIR_EXTRA[k].name;
  const FACE_EXTRA = { goatee: 'Goatee', chops: 'Mutton Chops', handlebar: 'Handlebar', fumanchu: 'Fu Manchu', soulpatch: 'Soul Patch', stubble: 'Five O\'Clock Shadow', chinstrap: 'Chin Strap' };
  Object.assign(ST.facial, FACE_EXTRA);

  // the painter gets the base shape; the rest is drawn on
  const lfs = R.lookFromStyle;
  R.lookFromStyle = function (s, masked) {
    const l = lfs.call(this, s, masked);
    const ov = l.oldOverride || (l.oldOverride = {});
    const hx = HAIR_EXTRA[s.hair];
    if (hx) { ov.style = hx.base; l.hairExtra = s.hair; }
    if (FACE_EXTRA[s.facial]) { ov.stache = s.facial === 'handlebar' || s.facial === 'fumanchu'; ov.beard = false; l.faceExtra = s.facial; }
    l.hairRamp = ov.hair;
    return l;
  };

  // [dx from face centre, row in the 16x32 cell, w, h, ramp index] for a front view
  const HAIR_PIX = {
    pompadour: [[-5, 1, 10, 2, 2], [-4, 0, 7, 1, 3], [-5, 3, 11, 1, 1], [2, 1, 2, 1, 3]],
    mohawk: [[-1, 0, 2, 7, 2], [-1, 0, 1, 7, 3], [0, -1, 1, 2, 1]],
    buzz: [[-5, 3, 10, 1, 1], [-6, 4, 12, 2, 1], [-4, 3, 1, 1, 0], [2, 4, 1, 1, 0]],
    jheri: [[-5, 2, 1, 1, 'shine'], [3, 3, 1, 1, 'shine'], [-2, 1, 1, 1, 'shine'], [-7, 8, 1, 1, 'shine'], [6, 9, 1, 1, 'shine']],
    feathered: [[-7, 6, 2, 5, 3], [5, 6, 2, 5, 3], [-6, 5, 1, 1, 3], [5, 5, 1, 1, 3]],
    locs: [[-7, 8, 1, 7, 0], [-5, 9, 1, 6, 0], [4, 9, 1, 6, 0], [6, 8, 1, 7, 0]],
    combover: [[-5, 3, 9, 1, 2], [-5, 4, 2, 1, 2], [-4, 3, 6, 1, 3]],
    mullet: [[-7, 12, 2, 4, 1], [5, 12, 2, 4, 1]],
  };
  const HAIR_BACK = { mullet: [[-5, 12, 10, 4, 1], [-4, 15, 8, 1, 0]], mohawk: [[-1, 0, 2, 8, 2]], locs: [[-6, 9, 12, 6, 1], [-5, 10, 1, 5, 0], [-2, 10, 1, 5, 0], [1, 10, 1, 5, 0], [4, 10, 1, 5, 0]] };
  const FACE_PIX = {
    goatee: [[-1, 12, 3, 1, 1], [-1, 13, 3, 1, 1]],
    chops: [[-6, 9, 1, 4, 1], [5, 9, 1, 4, 1], [-5, 12, 1, 1, 1], [4, 12, 1, 1, 1]],
    handlebar: [[-4, 11, 1, 1, 1], [3, 11, 1, 1, 1]],
    fumanchu: [[-3, 12, 1, 3, 1], [2, 12, 1, 3, 1]],
    soulpatch: [[0, 13, 1, 1, 1]],
    stubble: [[-4, 12, 1, 1, 'stub'], [-2, 13, 1, 1, 'stub'], [0, 12, 1, 1, 'stub'], [2, 13, 1, 1, 'stub'], [3, 12, 1, 1, 'stub'], [-5, 10, 1, 1, 'stub'], [4, 10, 1, 1, 'stub']],
    chinstrap: [[-6, 9, 1, 4, 1], [5, 9, 1, 4, 1], [-5, 13, 11, 1, 1]],
  };
  const DIR8 = ['right', 'downright', 'down', 'downright', 'right', 'upright', 'up', 'upright'];
  const FLIP8 = [false, false, false, true, true, true, false, false];
  const paint = (g, X, Y, list, ramp, n, flip, kid) => {
    const cx = n === 'down' || n === 'up' ? 7.5 : n === 'downright' || n === 'upright' ? 9 : 10;
    const sq = n === 'right' ? 0.6 : n === 'downright' || n === 'upright' ? 0.85 : 1;
    for (const p of list) {
      const sx = cx + p[0] * sq, x = flip ? 16 - sx - p[2] : sx;
      g.fillStyle = p[4] === 'shine' ? '#ffffff' : p[4] === 'stub' ? 'rgba(40,30,30,0.55)' : ramp[p[4]];
      g.fillRect(Math.round(X - 8 + x), Math.round(Y - 25 + p[1] + (kid ? 2 : 0)), Math.max(1, Math.round(p[2] * sq)), p[3]);
    }
  };
  const A = R.art, draw = A.drawPerson;
  A.drawPerson = function (g, x, y, dir, walk, look, st) {
    const r = draw.call(this, g, x, y, dir, walk, look, st);
    if (!look || (!look.hairExtra && !look.faceExtra) || look.mask || (st && (st.down || st.scale || st.crouch))) return r;
    const moving = walk && Math.abs(walk) > 0.01, bob = moving && (Math.floor(walk * 0.5) % 4) % 2 ? 1 : 0;
    const X = Math.round(x), Y = Math.round(y) - bob;
    const d8 = A.dir8(dir, st && st.ang), n = DIR8[d8], flip = FLIP8[d8], ramp = look.hairRamp || ['#0e0c16', '#1c1a28', '#2e2c40', '#484660'];
    const back = n === 'up' || n === 'upright';
    if (look.hairExtra) {
      const hatted = !!look.hatKind;
      const list = back ? HAIR_BACK[look.hairExtra] : HAIR_PIX[look.hairExtra];
      if (list && !(hatted && look.hairExtra !== 'mullet' && look.hairExtra !== 'locs')) paint(g, X, Y, hatted ? list.filter((p) => p[1] >= 8) : list, ramp, n, flip, look.kid);
    }
    if (look.faceExtra && !back) paint(g, X, Y, FACE_PIX[look.faceExtra] || [], ramp, n, flip, look.kid);
    return r;
  };
})();
