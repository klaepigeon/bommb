// RHAPSODY — wardrobe and grooming. Mix and match jackets, shirts, trousers and hats at
// the tailor; change your hair, its colour and your facial hair at the barber. Every
// piece is painted by the original's character routine, hats are drawn over the top.
(function () {
  const D = R.data, A = R.art;
  const INK = '#1b1410';
  const ramp = (a, b, c, d) => [a, b, c, d];

  const ST = (D.style = {
    jackets: {
      none: { name: 'No jacket', price: 0, c: null },
      mook: { name: 'Charcoal Two-Piece', price: 0, c: ramp('#14141c', '#24243a', '#383852', '#54547a'), fancy: 1 },
      velvet: { name: 'Crushed Velvet', price: 120, c: ramp('#2a1024', '#4a1c40', '#6c2c5e', '#945084'), fancy: 1 },
      leisure: { name: 'Leisure Suit', price: 80, c: ramp('#1c3c5c', '#2c5c88', '#4880b0', '#78a8d8') },
      leather: { name: 'Leather Jacket', price: 150, c: ramp('#2a1a12', '#44281a', '#624028', '#86583a') },
      tux: { name: 'Powder Blue Tux', price: 250, c: ramp('#3a5a78', '#5a80a8', '#80a8cc', '#a8cce8'), fancy: 1 },
      camelcoat: { name: 'Camel Overcoat', price: 300, c: ramp('#4a3418', '#7a5a2c', '#a88048', '#ceaa70'), fancy: 1 },
      disco: { name: 'White Disco Suit', price: 220, c: ramp('#8a8680', '#c0bcb4', '#e4e0d8', '#fffcf4'), fancy: 1 },
      corduroy: { name: 'Corduroy Blazer', price: 90, c: ramp('#3a2410', '#5a3a1c', '#7c522c', '#a0703e') },
      denim: { name: 'Denim Jacket', price: 60, c: ramp('#1c2c48', '#2c4470', '#40609a', '#6488c0') },
      plaid: { name: 'Green Plaid Sport Coat', price: 110, c: ramp('#1c3420', '#2c4c30', '#44683e', '#6a8c56') },
      maroon: { name: 'Maroon Dinner Jacket', price: 180, c: ramp('#3a0c14', '#5c1420', '#842434', '#aa3c4c'), fancy: 1 },
    },
    shirts: {
      maroon: { name: 'Maroon', price: 0, c: ramp('#4a1018', '#6c1c26', '#92303a', '#b8505a') },
      cream: { name: 'Cream', price: 20, c: ramp('#8a8068', '#b8ae90', '#dcd4b8', '#f0ead4') },
      black: { name: 'Black', price: 20, c: ramp('#141418', '#24242e', '#383846', '#50505e') },
      white: { name: 'White', price: 20, c: ramp('#b8b8b0', '#d8d8d0', '#f0f0e8', '#ffffff') },
      sky: { name: 'Sky Blue', price: 25, c: ramp('#3a6a8a', '#5a8aaa', '#80b0d0', '#b0d8f0') },
      mustard: { name: 'Mustard', price: 25, c: ramp('#6a5a20', '#9a8430', '#c8ac48', '#ecd070') },
      orange: { name: 'Burnt Orange', price: 25, c: ramp('#5a2408', '#8c3c10', '#c85c1c', '#f08c40') },
      olive: { name: 'Olive', price: 20, c: ramp('#2c3418', '#44502a', '#5e6c3a', '#7c8c50') },
      pink: { name: 'Salmon Pink', price: 30, c: ramp('#7a3a3a', '#a85a58', '#d88078', '#f8b0a0') },
      purple: { name: 'Paisley Purple', price: 35, c: ramp('#2a1a4a', '#44306e', '#664c98', '#9078c0') },
    },
    pants: {
      mook: { name: 'Charcoal Slacks', price: 0, c: ramp('#14141c', '#24243a', '#383852', '#54547a') },
      black: { name: 'Black Slacks', price: 30, c: ramp('#0c0c10', '#1a1a20', '#2a2a34', '#40404c') },
      navy: { name: 'Navy Bell-Bottoms', price: 35, c: ramp('#141c34', '#1c2c50', '#2c4274', '#44609a') },
      brown: { name: 'Brown Flares', price: 35, c: ramp('#2a1a0c', '#442c16', '#644224', '#865a34') },
      denim: { name: 'Denim Flares', price: 30, c: ramp('#1c2c48', '#2c4470', '#40609a', '#6488c0') },
      cream: { name: 'Cream Trousers', price: 40, c: ramp('#8a8068', '#b8ae90', '#dcd4b8', '#f0ead4') },
      white: { name: 'White Trousers', price: 45, c: ramp('#9a9890', '#c8c6be', '#e8e6de', '#fffdf6') },
      plaid: { name: 'Check Trousers', price: 40, c: ramp('#3a2418', '#5a3a24', '#7c5634', '#a07448') },
    },
    tops: { collar: { name: 'Wide Collar', price: 0 }, turtle: { name: 'Turtleneck', price: 25 }, stripe: { name: 'Striped Tee', price: 15 }, tee: { name: 'Plain Tee', price: 10 } },
    hats: {
      none: { name: 'No hat', price: 0 },
      fedora: { name: 'Fedora', price: 60 },
      trilby: { name: 'Trilby', price: 50 },
      porkpie: { name: 'Pork Pie', price: 45 },
      bowler: { name: 'Bowler', price: 55 },
      flatcap: { name: 'Flat Cap', price: 25 },
      cowboy: { name: 'Stetson', price: 70 },
      beanie: { name: 'Watch Cap', price: 15 },
    },
    hatCols: {
      black: { name: 'Black', c: ['#0c0c10', '#1e1e26', '#34343e'], band: '#6a1c26' },
      brown: { name: 'Brown', c: ['#2a1a0c', '#4a3018', '#6c4a28'], band: '#1a0e06' },
      grey: { name: 'Grey', c: ['#34343c', '#585862', '#80808c'], band: '#141418' },
      cream: { name: 'Cream', c: ['#8a8068', '#c8bea0', '#ece4c8'], band: '#3a2418' },
      navy: { name: 'Navy', c: ['#10162a', '#1c2a4a', '#2c4270'], band: '#c8ac48' },
      tan: { name: 'Tan', c: ['#5a4020', '#8c6a38', '#b89058'], band: '#3a2010' },
      red: { name: 'Red', c: ['#4a0c0c', '#8a1c1c', '#c03030'], band: '#141414' },
    },
    hair: { short: 'Slicked Back', shag: 'Shag', long: 'Long', afro: 'Afro', spiky: 'Spiked', bald: 'Shaved', ponytail: 'Ponytail', bun: 'Top Knot' },
    hairCols: {
      black: { name: 'Jet Black', c: ramp('#0e0c16', '#1c1a28', '#2e2c40', '#484660') },
      brown: { name: 'Brown', c: ramp('#2a1810', '#4a2c1c', '#70462a', '#94643c') },
      auburn: { name: 'Auburn', c: ramp('#4a1410', '#8a2c18', '#c04a24', '#e8783c') },
      blond: { name: 'Blond', c: ramp('#6a4a1a', '#a07a2a', '#d0a848', '#f0d888') },
      grey: { name: 'Silver Fox', c: ramp('#4a4a58', '#7a7a88', '#a8a8b4', '#d4d4dc') },
      bleach: { name: 'Bleached', c: ramp('#8a8070', '#c0b8a0', '#e8e0c8', '#fffaf0') },
    },
    facial: { clean: 'Clean-shaven', stache: 'Moustache', beard: 'Full Beard' },
  });

  const DEFAULT = { jacket: 'mook', shirt: 'maroon', pants: 'mook', top: 'collar', hat: 'none', hatCol: 'black', hair: 'short', hairCol: 'black', facial: 'clean', glasses: false };
  R.styleDefault = () => Object.assign({}, DEFAULT);

  // the look the painter needs, from a style
  R.lookFromStyle = function (s, masked) {
    const j = ST.jackets[s.jacket] || ST.jackets.mook, sh = ST.shirts[s.shirt] || ST.shirts.maroon, pa = ST.pants[s.pants] || ST.pants.mook;
    const hc = ST.hatCols[s.hatCol] || ST.hatCols.black;
    const seed = 'player-' + [s.jacket, s.shirt, s.pants, s.top, s.hair, s.hairCol, s.facial, s.glasses ? 1 : 0, masked ? 'm' : ''].join('-');
    return {
      skin: '#e0ac7e', hair: '#141010', hairStyle: 0, top: sh.c[2], bottom: pa.c[2], build: 1, fem: false, mask: masked, seedStr: seed,
      hatKind: s.hat && s.hat !== 'none' && !masked ? s.hat : null, hatCol: hc,
      oldOverride: {
        shirt: sh.c, jacket: j.c, pants: pa.c, style: s.hair || 'short', hair: (ST.hairCols[s.hairCol] || ST.hairCols.black).c,
        top: s.top || 'collar', flare: true, stache: s.facial === 'stache', beard: s.facial === 'beard', glasses: !!s.glasses, dress: false,
        shoes: ['#141418', '#24242c', '#3a3a46'], kid: false, mask: masked,
      },
    };
  };

  // ---------------------------------------------------------------- hats
  // Drawn over the sprite. (x, top) is the top-centre of the 16x32 character cell.
  const HATS = {
    fedora: [[-8, 5, 16, 2, 1], [-5, 0, 10, 5, 1], [-4, 0, 8, 1, 2], [-5, 3, 10, 1, 'band'], [-1, 0, 2, 1, 0], [-8, 6, 16, 1, 0]],
    trilby: [[-7, 5, 14, 1, 1], [-4, 1, 8, 4, 1], [-3, 1, 6, 1, 2], [-4, 3, 8, 1, 'band'], [5, 4, 2, 1, 1]],
    porkpie: [[-7, 5, 14, 1, 1], [-5, 2, 10, 3, 1], [-5, 2, 10, 1, 2], [-5, 4, 10, 1, 'band']],
    bowler: [[-7, 5, 14, 1, 1], [-5, 1, 10, 4, 1], [-4, 0, 8, 1, 1], [-3, 0, 5, 2, 2], [-5, 4, 10, 1, 'band']],
    flatcap: [[-6, 2, 12, 4, 1], [-5, 1, 10, 1, 1], [-4, 2, 6, 1, 2], [-6, 5, 12, 1, 0]],
    cowboy: [[-9, 5, 18, 2, 1], [-9, 4, 2, 1, 1], [7, 4, 2, 1, 1], [-4, 0, 8, 5, 1], [-3, 0, 6, 1, 2], [-1, 0, 2, 1, 0], [-4, 3, 8, 1, 'band']],
    beanie: [[-6, 1, 12, 5, 1], [-5, 0, 10, 1, 1], [-4, 1, 5, 1, 2], [-6, 5, 12, 2, 2], [-1, -2, 2, 2, 2]],
  };
  A.drawHat = function (g, x, top, kind, d8, col) {
    const rects = HATS[kind];
    if (!rects) return;
    const c = (col && col.c) || ST.hatCols.black.c, band = (col && col.band) || '#6a1c26';
    const facing = d8 === 0 || d8 === 1 || d8 === 7 ? 1 : d8 === 3 || d8 === 4 || d8 === 5 ? -1 : 0;
    const X = Math.round(x), Y = Math.round(top);
    const fill = (r) => (r[4] === 'band' ? band : c[r[4]]);
    g.fillStyle = INK;
    for (const r of rects) g.fillRect(X + r[0] - 1, Y + r[1] - 1, r[2] + 2, r[3] + 2);
    for (const r of rects) { g.fillStyle = fill(r); g.fillRect(X + r[0], Y + r[1], r[2], r[3]); }
    // a flat cap's bill points where you look
    if (kind === 'flatcap' && facing) { g.fillStyle = INK; g.fillRect(X + (facing > 0 ? 5 : -10), Y + 3, 6, 3); g.fillStyle = c[0]; g.fillRect(X + (facing > 0 ? 6 : -9), Y + 4, 4, 1); }
    else if (kind === 'flatcap' && d8 === 2) { g.fillStyle = c[0]; g.fillRect(X - 5, Y + 6, 10, 1); }
  };

  // ---------------------------------------------------------------- shops
  const CATS = {
    tailor: [['jackets', 'Jackets', 'jacket'], ['shirts', 'Shirts', 'shirt'], ['tops', 'Collar', 'top'], ['pants', 'Trousers', 'pants'], ['hats', 'Hats', 'hat'], ['hatCols', 'Hat colour', 'hatCol'], ['glasses', 'Shades', 'glasses']],
    barber: [['hair', 'Haircut', 'hair'], ['hairCols', 'Colour', 'hairCol'], ['facial', 'Face', 'facial']],
  };
  const priceOf = (cat, key) => {
    if (cat === 'hair') return 10;
    if (cat === 'hairCols') return key === 'black' ? 12 : 18;
    if (cat === 'facial') return key === 'clean' ? 5 : 25;
    if (cat === 'hatCols') return 10;
    if (cat === 'glasses') return 20;
    const e = ST[cat][key];
    return e ? e.price : 0;
  };
  const nameOf = (cat, key) => (cat === 'glasses' ? (key ? 'Aviator shades' : 'No shades') : typeof ST[cat][key] === 'string' ? ST[cat][key] : ST[cat][key].name);
  const swatch = (cat, key) => {
    const e = ST[cat] && ST[cat][key];
    if (!e) return '';
    const c = e.c ? (Array.isArray(e.c) ? e.c[2] : null) : null;
    return c ? `<i class="sw" style="background:${c}"></i>` : '';
  };

  R.openWardrobe = function (mode) {
    const g = R.game, ui = g.ui, pl = g.player;
    const orig = Object.assign({}, pl.style);
    const prev = Object.assign({}, pl.style);
    pl.wardrobe = pl.wardrobe || {};
    let cat = CATS[mode][0][0];
    const owned = (c, k) => priceOf(c, k) === 0 || pl.wardrobe[c + ':' + k] || (c === 'hair' || c === 'hairCols' || c === 'facial' ? false : false);
    const bill = () => {
      let t = 0;
      for (const [c, , field] of CATS[mode]) {
        const k = prev[field];
        if (k !== orig[field] && !owned(c, k)) t += priceOf(c, k);
      }
      return t;
    };
    const render = () => {
      const cdef = CATS[mode].find((c) => c[0] === cat), field = cdef[2];
      const keys = cat === 'glasses' ? [false, true] : Object.keys(ST[cat]);
      const cost = bill();
      const html = ui.header(mode === 'tailor' ? 'Tailor' : 'Barber', mode === 'tailor' ? 'Try things on. You only pay for what you walk out in. A new look throws off anyone hunting the old one.' : 'Sit down, relax. A new look throws off anyone hunting the old one.') +
        `<div class="body wardrobe"><div class="wtop"><canvas class="wport" width="48" height="60"></canvas><div class="wcats">${CATS[mode].map(([k, l]) => `<button data-c="${k}" class="${k === cat ? 'sel' : ''}">${l}</button>`).join('')}</div></div>` +
        `<div class="wlist">${keys.map((k) => { const on = prev[field] === k; const p = priceOf(cat, k); const own = owned(cat, k); return `<button class="wi ${on ? 'sel' : ''}" data-k="${k}">${swatch(cat, k)}<span>${nameOf(cat, k)}</span><em>${own || !p ? (on ? 'ON' : '') : '$' + p}</em></button>`; }).join('')}</div>` +
        `<div class="wfoot"><button class="opt" data-a="cancel">Put it all back</button><button class="opt good" data-a="buy">${cost ? `Buy & wear  ${R.fmtMoney(cost)}` : 'Wear it'}</button></div></div>`;
      const s = ui.openSheet('wardrobe', html);
      const cv = s.querySelector('.wport'), cg = cv.getContext('2d');
      cg.imageSmoothingEnabled = false;
      cg.fillStyle = '#e6d0a4'; cg.fillRect(0, 0, 48, 60);
      const look = R.lookFromStyle(prev, false);
      cg.save(); cg.scale(1.5, 1.5); A.drawPerson(cg, 16, 37, 2, 0, look, {}); cg.restore();
      s.querySelectorAll('[data-c]').forEach((b) => b.addEventListener('click', () => { cat = b.dataset.c; render(); }));
      s.querySelectorAll('.wi').forEach((b) => b.addEventListener('click', () => { const k = b.dataset.k; prev[field] = cat === 'glasses' ? k === 'true' : k; g.audio.sfx('click'); render(); }));
      s.querySelector('[data-a="cancel"]').addEventListener('click', () => { ui.closeSheet(); });
      s.querySelector('[data-a="buy"]').addEventListener('click', () => {
        const c = bill();
        if (c && !pl.pay(c)) return ui.toast(`That comes to ${R.fmtMoney(c)}. You're short.`, 'warn');
        for (const [cc, , f] of CATS[mode]) if (!/^hair|facial/.test(cc)) pl.wardrobe[cc + ':' + prev[f]] = 1;
        const changed = CATS[mode].some(([, , f]) => prev[f] !== orig[f]);
        pl.style = Object.assign({}, prev);
        pl.buildLook();
        if (changed) { pl.outfitChangedSince = 900; pl.bloody = 0; g.audio.sfx('cash'); ui.toast(mode === 'tailor' ? 'Looking sharp. The cops will need a second look.' : 'Fresh look. Your own mother would walk past you.', 'good'); }
        ui.closeSheet();
      });
    };
    render();
  };
})();
