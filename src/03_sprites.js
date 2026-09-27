// RHAPSODY — GBA-style pixel art, matching the original Port Hollow build:
// chibi characters with 1px ink outlines (cached per look), interior floors and
// walls, furniture, and pixel-font text helpers.
'use strict';
(function () {
  const D = R.data, T = D.T, O = D.O, TS = R.TILE;
  const A = R.art;
  const INK = '#2a1a12';
  const shade = A.shade;

  // ---------------------------------------------------------------- pixel fonts
  A.PIX = '"Silkscreen", "Courier New", monospace';
  A.READ = '"Pixelify Sans", "Trebuchet MS", sans-serif';
  // Crisp pixel text: glyphs are rasterised from Silkscreen at its native 8px, hard-
  // thresholded (no anti-aliasing), cached, and scaled by whole pixels.
  const ptCache = new Map();
  A.ptextCanvas = function (str, color) {
    const key = str + '\u0001' + color;
    let c = ptCache.get(key);
    if (c) return c;
    if (ptCache.size > 1500) ptCache.clear();
    const m = document.createElement('canvas').getContext('2d');
    m.font = `8px ${A.PIX}`;
    const w = Math.max(1, Math.ceil(m.measureText(str).width) + 1);
    c = document.createElement('canvas');
    c.width = w; c.height = 10;
    const g = c.getContext('2d');
    g.font = `8px ${A.PIX}`;
    g.textBaseline = 'alphabetic';
    g.fillStyle = '#000';
    g.fillText(str, 0, 8);
    const img = g.getImageData(0, 0, w, 10);
    const n = parseInt(color.slice(1), 16);
    for (let i = 0; i < img.data.length; i += 4) {
      const on = img.data[i + 3] > 110;
      img.data[i] = n >> 16; img.data[i + 1] = (n >> 8) & 255; img.data[i + 2] = n & 255; img.data[i + 3] = on ? 255 : 0;
    }
    g.putImageData(img, 0, 0);
    ptCache.set(key, c);
    return c;
  };
  A.ptWidth = function (str, scale) { return (A.ptextCanvas(str, '#000000').width - 1) * (scale || 1); };
  // draws with its top-left at (x, y) (align: left | center | right)
  A.ptext = function (g, str, x, y, opts) {
    opts = opts || {};
    const sc = opts.scale || 1;
    const c = A.ptextCanvas(String(str), opts.color || '#f6ecd0');
    const w = (c.width - 1) * sc;
    let X = opts.align === 'center' ? x - w / 2 : opts.align === 'right' ? x - w : x;
    X = Math.round(X); const Y = Math.round(y);
    g.imageSmoothingEnabled = false;
    if (opts.shadow) g.drawImage(A.ptextCanvas(String(str), opts.shadow), X + sc, Y + sc, c.width * sc, c.height * sc);
    g.drawImage(c, X, Y, c.width * sc, c.height * sc);
    return w;
  };
  A.clearTextCache = function () { ptCache.clear(); };
  A.text = function (g, s, x, y, opts) {
    // legacy baseline-positioned text now routes through the pixel renderer
    opts = opts || {};
    const sc = Math.max(1, Math.round((opts.size || 8) / 8));
    return A.ptext(g, s, x, y - 8 * sc, { scale: sc, color: opts.color, align: opts.align, shadow: opts.shadow === false ? null : opts.shadowColor || INK });
  };
  A.textOld = function (g, s, x, y, opts) {
    opts = opts || {};
    g.font = `${opts.size || 8}px ${opts.read ? A.READ : A.PIX}`;
    g.textAlign = opts.align || 'left';
    g.textBaseline = 'alphabetic';
    if (opts.shadow !== false) {
      g.fillStyle = opts.shadowColor || INK;
      g.fillText(s, Math.round(x) + 1, Math.round(y) + 1);
    }
    g.fillStyle = opts.color || '#f6ecd0';
    g.fillText(s, Math.round(x), Math.round(y));
  };

  // ---------------------------------------------------------------- chibi sprites
  // Sprite canvas: 18 x 25 world px. Feet at (9, 24).
  const SW = 18, SH = 25;
  const cache = new Map();
  A.spriteCacheSize = () => cache.size;

  function outline(cv, col) {
    const g = cv.getContext('2d');
    const img = g.getImageData(0, 0, cv.width, cv.height);
    const d = img.data, w = cv.width, h = cv.height;
    const solid = (x, y) => x >= 0 && y >= 0 && x < w && y < h && d[(y * w + x) * 4 + 3] > 128;
    const add = [];
    for (let y = 0; y < h; y++)
      for (let x = 0; x < w; x++) {
        if (solid(x, y)) continue;
        if (solid(x - 1, y) || solid(x + 1, y) || solid(x, y - 1) || solid(x, y + 1)) add.push(y * w + x);
      }
    const n = parseInt(col.slice(1), 16);
    for (const i of add) {
      d[i * 4] = n >> 16; d[i * 4 + 1] = (n >> 8) & 255; d[i * 4 + 2] = n & 255; d[i * 4 + 3] = 255;
    }
    g.putImageData(img, 0, 0);
  }

  function buildSprite(look, dir, frame) {
    const cv = document.createElement('canvas');
    cv.width = SW; cv.height = SH;
    const g = cv.getContext('2d');
    const P = (x, y, w, h, c) => { g.fillStyle = c; g.fillRect(x, y, w, h); };
    const kid = look.kid;
    const big = look.build === 2, thin = look.build === 0;
    const side = dir === 1 || dir === 3;
    // geometry (x measured from the sprite's left edge)
    const headW = kid ? 9 : 10, headH = kid ? 8 : 9;
    const hx = Math.floor((SW - headW) / 2);
    const bodyW = kid ? 6 : big ? 10 : thin ? 7 : 8;
    const bodyH = kid ? 4 : 6;
    const legH = kid ? 3 : 4;
    const footY = SH - 2; // shoe row (last opaque row = SH-2, outline below)
    const legTop = footY - legH;
    const bodyTop = legTop - bodyH;
    const headTop = bodyTop - headH + 1;
    const bx = Math.floor((SW - (side ? bodyW - 2 : bodyW)) / 2);
    const bw = side ? bodyW - 2 : bodyW;
    const skinD = shade(look.skin, -28);
    const top = look.top, topD = shade(look.top, -30), topL = shade(look.top, 22);
    const bot = look.bottom, botD = shade(look.bottom, -25);
    // legs & shoes
    const step = frame === 1 ? 1 : frame === 2 ? -1 : 0;
    if (look.dress && look.fem && !kid) {
      P(bx - 1, legTop, bw + 2, 2, top);
      P(bx - 1, legTop + 1, bw + 2, 1, topD);
      if (side) { P(bx + 1 + step, legTop + 2, 2, legH - 2, look.skin); P(bx + 1 + step, footY, 3, 1, INK); }
      else { P(bx + 1, legTop + 2 - (step > 0 ? 1 : 0), 2, legH - 2, look.skin); P(bx + bw - 3, legTop + 2 - (step < 0 ? 1 : 0), 2, legH - 2, look.skin); P(bx + 1, footY, 2, 1, INK); P(bx + bw - 3, footY, 2, 1, INK); }
    } else if (side) {
      const f = dir === 1 ? 1 : -1;
      P(bx + 1 + step * f, legTop, 3, legH, botD);
      P(bx + 1 - step * f, legTop, 3, legH, bot);
      P(bx + step * f + (f > 0 ? 1 : 0), footY, 4, 1, '#1a1210');
      P(bx - step * f + (f > 0 ? 1 : 0), footY, 4, 1, '#1a1210');
    } else {
      const lw = Math.max(2, Math.floor(bw / 2) - 1);
      P(bx + 1, legTop - (step > 0 ? 1 : 0), lw, legH, bot);
      P(bx + bw - 1 - lw, legTop - (step < 0 ? 1 : 0), lw, legH, bot);
      P(bx + 1 + lw - 1, legTop, 1, legH, botD);
      P(bx + 1, footY - (step > 0 ? 1 : 0), lw, 1, '#1a1210');
      P(bx + bw - 1 - lw, footY - (step < 0 ? 1 : 0), lw, 1, '#1a1210');
    }
    // torso
    P(bx, bodyTop, bw, bodyH, top);
    P(bx, bodyTop + bodyH - 1, bw, 1, topD);
    P(bx, bodyTop, bw, 1, topL);
    if (look.stripe) for (let x = bx + 1; x < bx + bw - 1; x += 2) P(x, bodyTop + 1, 1, bodyH - 2, look.stripe);
    if (!side && dir === 2) {
      if (look.lapel) { P(bx + Math.floor(bw / 2) - 1, bodyTop, 2, 3, look.lapel); P(bx + Math.floor(bw / 2) - 2, bodyTop, 1, 1, look.lapel); P(bx + Math.floor(bw / 2) + 1, bodyTop, 1, 1, look.lapel); }
      if (look.chain) P(bx + Math.floor(bw / 2) - 1, bodyTop + 2, 2, 1, '#f0c040');
      if (look.uniformBadge) P(bx + 1, bodyTop + 1, 1, 1, '#f0c040');
    }
    // belt
    if (!look.dress) P(bx, legTop - 1, bw, 1, shade(bot, -40));
    // arms
    const swing = frame === 1 ? 1 : frame === 2 ? -1 : 0;
    if (side) {
      const ax = bx + Math.floor(bw / 2) - 1 + swing * (dir === 1 ? 1 : -1);
      P(ax, bodyTop + 1, 2, bodyH - 2, topD);
      P(ax, bodyTop + bodyH - 1, 2, 1, look.skin);
    } else {
      P(bx - 2, bodyTop + 1 + (swing > 0 ? 1 : 0), 2, bodyH - 2, topD);
      P(bx + bw, bodyTop + 1 + (swing < 0 ? 1 : 0), 2, bodyH - 2, topD);
      P(bx - 2, bodyTop + bodyH - 1 + (swing > 0 ? 1 : 0), 2, 1, look.skin);
      P(bx + bw, bodyTop + bodyH - 1 + (swing < 0 ? 1 : 0), 2, 1, look.skin);
    }
    // head
    const face = look.mask ? '#2b2b30' : look.skin;
    P(hx + 1, headTop, headW - 2, headH, face);
    P(hx, headTop + 1, headW, headH - 2, face);
    P(hx + 1, headTop + headH - 1, headW - 2, 1, look.mask ? '#1e1e22' : skinD);
    const hair = look.hair, hairD = shade(look.hair, -25);
    if (!look.mask) {
      if (look.hairStyle === 2) {
        // afro: bigger round mass
        P(hx - 1, headTop - 1, headW + 2, 5, hair);
        P(hx, headTop - 2, headW, 1, hair);
        if (dir === 0) P(hx - 1, headTop + 3, headW + 2, headH - 3, hair);
        else { P(hx - 1, headTop + 3, 2, 3, hair); P(hx + headW - 1, headTop + 3, 2, 3, hair); }
      } else if (dir === 0) {
        P(hx, headTop, headW, headH - 1, hair);
        P(hx + 1, headTop + headH - 3, headW - 2, 1, hairD);
        if (look.hairStyle === 1 || look.fem) P(hx, headTop + headH - 2, headW, 3, hair);
      } else {
        P(hx + 1, headTop, headW - 2, 3, hair);
        P(hx, headTop + 1, headW, 2, hair);
        P(hx + 2, headTop + 3, headW - 4, 1, hairD);
        if (side) {
          const back = dir === 1 ? hx : hx + headW - 4;
          P(back, headTop + 1, 4, look.hairStyle === 1 || look.fem ? headH + 1 : 5, hair);
        } else {
          P(hx, headTop + 2, 1, look.hairStyle === 1 || look.fem ? headH : 4, hair);
          P(hx + headW - 1, headTop + 2, 1, look.hairStyle === 1 || look.fem ? headH : 4, hair);
        }
      }
    }
    // face details
    const eyeY = headTop + (kid ? 4 : 5);
    if (dir === 2) {
      if (look.mask) { P(hx + 2, eyeY - 1, 2, 2, look.skin); P(hx + headW - 4, eyeY - 1, 2, 2, look.skin); P(hx + 2, eyeY, 1, 1, INK); P(hx + headW - 3, eyeY, 1, 1, INK); }
      else if (look.shades) { P(hx + 1, eyeY - 1, headW - 2, 2, '#141418'); P(hx + 2, eyeY - 1, 1, 1, '#6a7aa0'); }
      else { P(hx + 2, eyeY - 1, 2, 2, INK); P(hx + headW - 4, eyeY - 1, 2, 2, INK); P(hx + 2, eyeY - 1, 1, 1, '#f6ecd0'); P(hx + headW - 4, eyeY - 1, 1, 1, '#f6ecd0'); }
      if (!look.mask && look.beard) P(hx + 2, eyeY + 2, headW - 4, 1, hair);
      else if (!look.mask && look.fem) P(hx + 4, eyeY + 2, 2, 1, '#c85a5a');
      if (!look.mask && !kid && (look.fem || look.blush)) { P(hx + 1, eyeY + 1, 1, 1, '#e89a8a'); P(hx + headW - 2, eyeY + 1, 1, 1, '#e89a8a'); }
    } else if (side) {
      const ex = dir === 1 ? hx + headW - 3 : hx + 1;
      if (look.mask) { P(ex, eyeY - 1, 2, 2, look.skin); P(ex + (dir === 1 ? 1 : 0), eyeY, 1, 1, INK); }
      else if (look.shades) P(dir === 1 ? hx + headW - 5 : hx, eyeY - 1, 5, 2, '#141418');
      else { P(ex, eyeY - 1, 2, 2, INK); P(ex + (dir === 1 ? 0 : 1), eyeY - 1, 1, 1, '#f6ecd0'); }
      if (!look.mask && look.beard) P(dir === 1 ? hx + headW - 5 : hx + 1, eyeY + 2, 4, 1, hair);
      // nose bump
      if (!look.mask) P(dir === 1 ? hx + headW : hx - 1, eyeY + 1, 1, 1, look.skin);
    }
    // hats
    if (look.hat && !look.mask) {
      const hc = look.hatCol || '#2a2020', hcL = shade(hc, 25);
      if (look.hat === 'fedora') {
        P(hx - 2, headTop + 2, headW + 4, 2, hc);
        P(hx + 1, headTop - 2, headW - 2, 4, hc);
        P(hx + 2, headTop - 3, headW - 4, 1, hc);
        P(hx + 1, headTop + 1, headW - 2, 1, '#8a2a1a');
        P(hx + 2, headTop - 2, headW - 4, 1, hcL);
      } else if (look.hat === 'cap') {
        P(hx, headTop - 1, headW, 4, hc);
        P(hx + 1, headTop - 2, headW - 2, 1, hc);
        if (dir === 2) P(hx, headTop + 3, headW, 1, shade(hc, -20));
        else if (dir === 1) P(hx + headW - 1, headTop + 2, 3, 1, hc);
        else if (dir === 3) P(hx - 2, headTop + 2, 3, 1, hc);
        P(hx + 2, headTop - 1, headW - 4, 1, hcL);
      } else if (look.hat === 'cowboy') {
        P(hx - 3, headTop + 1, headW + 6, 2, hc);
        P(hx + 1, headTop - 3, headW - 2, 5, hc);
        P(hx + 1, headTop, headW - 2, 1, shade(hc, -30));
      } else if (look.hat === 'police') {
        P(hx, headTop - 1, headW, 3, '#1a2a4a');
        P(hx - 1, headTop + 2, headW + 2, 1, '#10182a');
        P(hx + Math.floor(headW / 2) - 1, headTop, 2, 1, '#e4c040');
      } else if (look.hat === 'beanie') {
        P(hx, headTop - 1, headW, 4, hc);
        P(hx, headTop + 2, headW, 1, hcL);
      }
    }
    outline(cv, INK);
    return cv;
  }

  function keyOf(look) {
    return [look.skin, look.hair, look.hairStyle, look.top, look.bottom, look.hat, look.hatCol, look.build, look.fem ? 1 : 0, look.kid ? 1 : 0, look.beard ? 1 : 0, look.shades ? 1 : 0, look.stripe, look.lapel, look.chain ? 1 : 0, look.mask ? 1 : 0, look.dress ? 1 : 0].join('|');
  }
  A.sprite = function (look, dir, frame) {
    const k = keyOf(look);
    let set = cache.get(k);
    if (!set) {
      if (cache.size > 600) cache.clear();
      set = [];
      cache.set(k, set);
    }
    const i = dir * 3 + frame;
    return set[i] || (set[i] = buildSprite(look, dir, frame));
  };
  A.invalidateLook = function (look) { look._sk = null; };

  // ---------------------------------------------------------------- the original's characters
  // Every look is turned into the original build's look object and painted with its own
  // Ks routine (see 03_oldsprites.js). Canvases are 16x32 (32x32 for poses); feet at row 25.
  const OLD = R.old;
  const oldCache = new Map();
  const lum = (hex) => { const n = parseInt(hex.slice(1), 16); return ((n >> 16) * 0.3 + ((n >> 8) & 255) * 0.59 + (n & 255) * 0.11) / 255; };
  const hairKey = (hex) => {
    const n = parseInt(hex.slice(1), 16), r = n >> 16, gg = (n >> 8) & 255, b = n & 255;
    if (Math.abs(r - gg) < 18 && Math.abs(gg - b) < 18 && r > 110) return 'hairGrey';
    if (r > gg * 1.6 && r > 80) return 'hairRed';
    if (r + gg + b < 110) return 'hairBlack';
    return 'hair';
  };
  A.oldLook = function (look) {
    if (look.old) return look.old;
    const seed = look.seedStr || [look.skin, look.hair, look.top, look.bottom, look.hat, look.fem ? 1 : 0, look.build].join('|');
    const O2 = OLD, xx = O2.x;
    const skins = xx.skin;
    const sk = skins[Math.min(skins.length - 1, Math.floor((1 - lum(look.skin)) * skins.length * 1.15))] || skins[1];
    const ov = { skin: sk, kid: !!look.kid };
    const h = O2.Re(seed);
    let shirt = O2.npcShirts[h % O2.npcShirts.length];
    if (look.fem) ov.style = ['long', 'bob', 'ponytail', 'bun', 'long', 'afro', 'shag'][h % 7];
    else ov.style = ['short', 'shag', 'afro', 'short', 'long', 'shag', 'short', 'bald'][h % 8];
    if (look.hairStyle === 2) ov.style = 'afro';
    if (look.hat === 'police') Object.assign(ov, { shirt: xx.blue.slice(0, 4), pants: O2.na[1], style: 'cap', cap: xx.black, stache: true, flare: false });
    else if (look.hat === 'cap' || look.hat === 'beanie' || look.hat === 'cowboy') Object.assign(ov, { style: 'cap', cap: [xx.blue, xx.red, xx.olive, xx.black][h % 4] });
    if (look.lapel && look.stripe) Object.assign(ov, { jacket: O2.ko[0], top: 'collar', shirt: ['#1a1822', '#2c2a38', '#44425a', '#6a6886'], style: ov.style === 'bald' ? 'short' : ov.style }); // made men
    if (look.uniform) Object.assign(ov, look.uniform);
    if (look.fem && !look.kid && look.dress) ov.dress = true;
    if (look.mask) ov.mask = true;
    if (look.beard) ov.stache = true;
    if (look.shades) ov.glasses = true;
    if (look.oldOverride) Object.assign(ov, look.oldOverride);
    const shirtHex = Array.isArray(shirt[0]) ? shirt[0] : shirt;
    look.old = O2.Qr(seed, shirtHex.map ? shirtHex.map((c) => (typeof c === 'number' ? c : parseInt(String(c).slice(1), 16))) : shirtHex, hairKey(look.hair), ov);
    look.old.mask = !!look.mask;
    return look.old;
  };
  A.invalidateLook = function (look) { look.old = null; };
  const DIR8 = ['right', 'downright', 'down', 'downright', 'right', 'upright', 'up', 'upright'];
  const FLIP8 = [false, false, false, true, true, true, false, false];
  A.oldSprite = function (look, d8, frame, pose) {
    const L = A.oldLook(look);
    const key = (look.seedStr || '') + '|' + JSON.stringify(L).length + '|' + L.shirt[2] + L.hair[1] + L.style + (L.mask ? 1 : 0) + (L.jacket ? L.jacket[1] : '') + '|' + d8 + frame + (pose || '');
    let c = oldCache.get(key);
    if (!c) {
      if (oldCache.size > 2500) oldCache.clear();
      let grid = OLD.Ks(L, DIR8[d8], frame, pose || null);
      if (FLIP8[d8]) grid = grid.flipX();
      c = grid.toCanvas(2);
      oldCache.set(key, c);
    }
    return c;
  };
  // 8-way facing from an angle (or the 4-way dir)
  A.dir8 = function (dir, ang) {
    if (ang !== undefined && ang !== null && !isNaN(ang)) return ((Math.round(ang / (Math.PI / 4)) % 8) + 8) % 8;
    return [6, 0, 2, 4][dir];
  };
  A.drawPerson = function (g, x, y, dir, walk, look, st) {
    st = st || {};
    const moving = walk && Math.abs(walk) > 0.01;
    const phase = moving ? Math.floor(walk * 0.9) % 4 : 0;
    const frame = phase === 1 ? 1 : phase === 3 ? 2 : 0;
    const d8 = A.dir8(dir, st.ang);
    const X = Math.round(x), Y = Math.round(y);
    // the original's soft shadow
    g.fillStyle = 'rgba(16,12,36,0.45)';
    g.fillRect(X - 4, Y - 1, 8, 2);
    g.fillRect(X - 3, Y - 2, 6, 4);
    let pose = st.pose || null;
    if (!pose && st.weapon && st.weapon !== 'fists') pose = D.weapons[st.weapon] && D.weapons[st.weapon].gun ? 'g' : null;
    const spr = A.oldSprite(look, d8, pose ? 0 : frame, pose);
    if (st.down) {
      g.save();
      g.translate(X, Y - 3);
      g.rotate(Math.PI / 2);
      g.drawImage(spr, -spr.width / 2, -22);
      g.restore();
      return;
    }
    g.drawImage(spr, X - spr.width / 2, Y - 25);
    if (st.weapon && st.weapon !== 'fists' && pose !== 'g' || pose === 'g') drawWeapon8(g, X, Y, d8, st.weapon);
  };
  function drawWeapon8(g, X, Y, d8, w) {
    if (!w || w === 'fists') return;
    const def = D.weapons[w];
    const col = w === 'bat' ? '#b08050' : w === 'knife' ? '#d8d8e0' : w === 'molotov' ? '#6aa060' : w === 'dynamite' ? '#c83a1a' : '#2a2a34';
    const len = w === 'bat' ? 8 : w === 'shotgun' || w === 'rifle' ? 9 : w === 'chopper' ? 7 : 4;
    const hand = { 0: [6, -9], 1: [5, -7], 2: [4, -8], 3: [-5, -7], 4: [-6, -9], 5: [-5, -11], 6: [4, -12], 7: [5, -11] }[d8];
    const ang = d8 * Math.PI / 4;
    const hx = X + hand[0], hy = Y + hand[1];
    g.fillStyle = INK;
    for (let k = -1; k <= len; k++) g.fillRect(Math.round(hx + Math.cos(ang) * k) - 1, Math.round(hy + Math.sin(ang) * k) - 1, 3, 3);
    g.fillStyle = col;
    for (let k = 0; k < len; k++) g.fillRect(Math.round(hx + Math.cos(ang) * k), Math.round(hy + Math.sin(ang) * k), 1, 1);
    if (def && def.gun) { g.fillStyle = '#6a4a2a'; g.fillRect(Math.round(hx) , Math.round(hy), 1, 2); }
  }
  function drawWeapon(g, X, Y, dir, w) {
    const col = w === 'bat' ? '#b08050' : w === 'knife' ? '#d8d8e0' : w === 'molotov' ? '#6aa060' : w === 'dynamite' ? '#c83a1a' : '#2a2a30';
    const len = w === 'bat' ? 9 : w === 'shotgun' || w === 'rifle' ? 10 : w === 'chopper' ? 8 : 5;
    g.fillStyle = INK;
    const hy = Y - 9;
    if (dir === 1) { g.fillRect(X + 3, hy - 1, len + 1, 3); g.fillStyle = col; g.fillRect(X + 3, hy, len, 1); }
    else if (dir === 3) { g.fillRect(X - 4 - len, hy - 1, len + 1, 3); g.fillStyle = col; g.fillRect(X - 3 - len, hy, len, 1); }
    else if (dir === 2) { g.fillRect(X + 5, hy - 2, 3, len + 1); g.fillStyle = col; g.fillRect(X + 6, hy - 1, 1, len); }
    else { g.fillRect(X + 5, hy - len, 3, len + 1); g.fillStyle = col; g.fillRect(X + 6, hy - len + 1, 1, len); }
  }

  // ---------------------------------------------------------------- interiors: floors & walls
  const ROOMPAL = {
    bar: { wall: '#6a3a2a', trim: '#3a1e14', floor: '#7a5234' }, club: { wall: '#3a2a5a', trim: '#1a1030', floor: '#2a2040' },
    diner: { wall: '#e0c8a0', trim: '#b84a3a', floor: '#e8e0d0' }, police: { wall: '#9aa8b8', trim: '#3a4a6a', floor: '#8a8e96' },
    hospital: { wall: '#dce8e4', trim: '#6aa0a0', floor: '#e8ecea' }, bank: { wall: '#c8b890', trim: '#6a5a3a', floor: '#b8a888' },
    church: { wall: '#d8d0c0', trim: '#6a5a4a', floor: '#8a5a3a' }, social: { wall: '#5a2a24', trim: '#2a1210', floor: '#6a1e1e' },
    casino: { wall: '#6a2a2a', trim: '#c8a040', floor: '#2a5a3a' }, garage: { wall: '#8a8478', trim: '#4a4640', floor: '#6e6a64' },
    house: { wall: '#c8a878', trim: '#7a5a3a', floor: '#9a6a44' }, shop: { wall: '#d8c8a0', trim: '#7a5a3a', floor: '#c8bca8' },
    work: { wall: '#8a8070', trim: '#4a4438', floor: '#7a7468' }, arcade: { wall: '#2a2a4a', trim: '#e040a0', floor: '#1e1e34' },
  };
  A.roomPal = function (type) {
    const map = { bar: 'bar', club: 'club', diner: 'diner', police: 'police', hospital: 'hospital', bank: 'bank', church: 'church', social: 'social', casino: 'casino',
      garage: 'garage', house: 'house', cabin: 'house', apartment: 'house', barn: 'house', hotel: 'bank', motel: 'house', arcade: 'arcade', factory: 'work', warehouse: 'work', office: 'police', school: 'house' };
    return ROOMPAL[map[type] || 'shop'];
  };
  A.drawInteriorTile = function (g, w, x, y, px, py, t) {
    const b = w.bid[w.idx(x, y)] ? w.buildings[w.bid[w.idx(x, y)]] : null;
    const pal = A.roomPal(b ? b.type : 'shop');
    const h = R.hash2(x, y, 3);
    if (t === T.VOID) { g.fillStyle = '#140c0a'; g.fillRect(px, py, TS, TS); return; }
    if (t === T.WALL) {
      const below = w.t(x, y + 1);
      const isFace = below !== T.WALL && below !== T.VOID;
      if (isFace) {
        // wallpaper face with baseboard + a picture now and then
        g.fillStyle = pal.wall;
        g.fillRect(px, py, TS, TS);
        g.fillStyle = shade(pal.wall, -14);
        for (let k = 1; k < TS; k += 4) g.fillRect(px + k, py, 1, TS - 3);
        g.fillStyle = pal.trim;
        g.fillRect(px, py + TS - 3, TS, 3);
        g.fillStyle = shade(pal.wall, 25);
        g.fillRect(px, py, TS, 1);
        if (h < 0.12) { g.fillStyle = INK; g.fillRect(px + 4, py + 3, 8, 6); g.fillStyle = ['#4a7a9a', '#c8783a', '#6a8a3a'][(h * 30 | 0) % 3]; g.fillRect(px + 5, py + 4, 6, 4); }
        else if (h > 0.9) { g.fillStyle = '#a8c8e0'; g.fillRect(px + 3, py + 2, 10, 7); g.fillStyle = INK; g.fillRect(px + 7, py + 2, 1, 7); g.fillRect(px + 3, py + 5, 10, 1); }
      } else {
        g.fillStyle = shade(pal.trim, -10);
        g.fillRect(px, py, TS, TS);
        g.fillStyle = shade(pal.trim, 12);
        g.fillRect(px, py, TS, 1);
      }
      return;
    }
    let col = pal.floor;
    if (t === T.TILEF) {
      g.fillStyle = (x + y) % 2 ? '#e8e0d0' : '#2a2a30';
      if (b && (b.type === 'hospital' || b.type === 'pharmacy')) g.fillStyle = (x + y) % 2 ? '#e8ecea' : '#bcd4d0';
      g.fillRect(px, py, TS, TS);
      return;
    }
    if (t === T.DANCE) {
      const cols = ['#e040a0', '#e4a92a', '#2a7d7a', '#6a4ac0'];
      g.fillStyle = cols[(x * 3 + y * 5) % 4];
      g.fillRect(px, py, TS, TS);
      g.fillStyle = 'rgba(255,255,255,0.25)';
      g.fillRect(px + 1, py + 1, TS - 2, 2);
      g.fillStyle = INK;
      g.fillRect(px, py + TS - 1, TS, 1);
      g.fillRect(px + TS - 1, py, 1, TS);
      return;
    }
    if (t === T.CARPET) col = b && b.type === 'casino' ? '#6a1e2a' : b && b.type === 'church' ? '#8a2a2a' : pal.floor;
    if (t === T.CONCRETE) col = '#7a766e';
    g.fillStyle = col;
    g.fillRect(px, py, TS, TS);
    if (t === T.WOOD) {
      g.fillStyle = shade(col, -18);
      for (let k = 3; k < TS; k += 4) g.fillRect(px, py + k, TS, 1);
      g.fillRect(px + ((y * 5) % 16), py, 1, 4);
      g.fillRect(px + ((y * 5 + 8) % 16), py + 8, 1, 4);
    } else if (t === T.CARPET) {
      g.fillStyle = shade(col, 14);
      if ((x + y) % 2 === 0) { g.fillRect(px + 6, py + 6, 4, 4); }
      g.fillStyle = shade(col, -12);
      g.fillRect(px + 2, py + 2, 1, 1); g.fillRect(px + 12, py + 12, 1, 1);
    } else if (t === T.CONCRETE) {
      g.fillStyle = shade(col, -10);
      if (h < 0.3) g.fillRect(px + 3, py + 9, 5, 1);
      if (h > 0.8) { g.fillStyle = 'rgba(40,30,20,0.25)'; g.fillRect(px + 4, py + 4, 7, 5); }
    } else if (t === T.EXITMAT) {
      g.fillStyle = '#7a2a1a';
      g.fillRect(px + 1, py + 2, TS - 2, TS - 4);
      g.fillStyle = '#c8783a';
      g.fillRect(px + 3, py + 4, TS - 6, 1);
      g.fillRect(px + 3, py + TS - 6, TS - 6, 1);
    }
    // wall shadow on the row under a wall
    if (w.t(x, y - 1) === T.WALL) { g.fillStyle = 'rgba(20,10,20,0.25)'; g.fillRect(px, py, TS, 3); }
  };

  // ---------------------------------------------------------------- furniture
  const box = (g, x, y, w, h, c, hi) => {
    g.fillStyle = INK; g.fillRect(x - 1, y - 1, w + 2, h + 2);
    g.fillStyle = c; g.fillRect(x, y, w, h);
    if (hi !== false) { g.fillStyle = shade(c, 22); g.fillRect(x, y, w, 1); g.fillStyle = shade(c, -25); g.fillRect(x, y + h - 1, w, 1); }
  };
  A.drawFurniture = function (g, o, px, py, x, y, w) {
    const same = (dx, dy) => w.o(x + dx, y + dy) === o;
    const h = R.hash2(x, y, 11);
    switch (o) {
      case O.COUNTER: {
        const l = same(-1, 0) || w.o(x - 1, y) === O.REGISTER, r = same(1, 0) || w.o(x + 1, y) === O.REGISTER;
        g.fillStyle = INK; g.fillRect(px - (l ? 0 : 1), py + 3, TS + (l ? 0 : 1) + (r ? 0 : 1), 13);
        g.fillStyle = '#7a4a2a'; g.fillRect(px + (l ? 0 : 0), py + 4, TS - (r ? 0 : 0), 11);
        g.fillStyle = '#c89a5a'; g.fillRect(px, py + 4, TS, 4);
        g.fillStyle = '#e0b878'; g.fillRect(px, py + 4, TS, 1);
        g.fillStyle = '#5a3218'; g.fillRect(px, py + 12, TS, 1);
        if (h < 0.2) { g.fillStyle = '#6a9a60'; g.fillRect(px + 5, py + 1, 2, 4); g.fillStyle = '#e8d8a0'; g.fillRect(px + 9, py + 2, 2, 3); }
        break;
      }
      case O.REGISTER:
        A.drawFurniture(g, O.COUNTER, px, py, x, y, { o: () => O.COUNTER });
        box(g, px + 3, py - 1, 10, 7, '#5a5a62');
        g.fillStyle = '#9ad070'; g.fillRect(px + 5, py + 1, 6, 2);
        g.fillStyle = '#e4a92a'; g.fillRect(px + 4, py + 4, 8, 1);
        break;
      case O.STOOL: box(g, px + 5, py + 5, 6, 4, '#c83a2a'); g.fillStyle = INK; g.fillRect(px + 7, py + 10, 2, 4); break;
      case O.CHAIR: box(g, px + 4, py + 4, 8, 6, '#8a5a3a'); box(g, px + 4, py + 1, 8, 2, '#6a4028'); break;
      case O.TABLE: box(g, px + 2, py + 3, 12, 9, '#9a6a3a'); g.fillStyle = '#f6ecd0'; g.fillRect(px + 4, py + 5, 3, 2); if (h > 0.5) { g.fillStyle = '#c83a2a'; g.fillRect(px + 9, py + 5, 2, 3); } break;
      case O.BED: {
        const head = !same(0, -1);
        g.fillStyle = INK; g.fillRect(px + 1, py + (head ? 0 : -1), 14, head ? 16 : 16);
        g.fillStyle = '#7a4a2a'; g.fillRect(px + 2, py + (head ? 1 : 0), 12, head ? 15 : 14);
        g.fillStyle = h < 0.5 ? '#4a6aa0' : '#a8402a'; g.fillRect(px + 2, py + (head ? 7 : 0), 12, head ? 9 : 13);
        g.fillStyle = shade(h < 0.5 ? '#4a6aa0' : '#a8402a', 20); g.fillRect(px + 2, py + (head ? 7 : 0), 12, 1);
        if (head) { g.fillStyle = '#f6ecd0'; g.fillRect(px + 3, py + 2, 10, 4); }
        break;
      }
      case O.HOSPBED: box(g, px + 2, py + 1, 12, 14, '#e8ecea'); g.fillStyle = '#a8c8e0'; g.fillRect(px + 2, py + 6, 12, 9); g.fillStyle = '#9aa0a8'; g.fillRect(px + 3, py + 1, 10, 1); break;
      case O.DRESSER: box(g, px + 1, py + 2, 14, 12, '#8a5a34'); g.fillStyle = '#5a3218'; g.fillRect(px + 2, py + 7, 12, 1); g.fillRect(px + 2, py + 10, 12, 1); g.fillStyle = '#e4a92a'; g.fillRect(px + 7, py + 5, 2, 1); g.fillRect(px + 7, py + 8, 2, 1); g.fillRect(px + 7, py + 11, 2, 1); break;
      case O.SHELF: case O.BOOKCASE: {
        box(g, px + 1, py + 0, 14, 15, o === O.BOOKCASE ? '#6a4028' : '#a88a5a');
        const cols = o === O.BOOKCASE ? ['#a83a2a', '#3a6a8a', '#6a8a3a', '#e4a92a', '#5c2a4a'] : ['#e4a92a', '#c83a2a', '#6a9a30', '#f6ecd0', '#3a6a9a'];
        for (let r = 0; r < 3; r++) { g.fillStyle = shade(o === O.BOOKCASE ? '#6a4028' : '#a88a5a', -30); g.fillRect(px + 2, py + 4 + r * 4, 12, 1); for (let k = 0; k < 5; k++) { g.fillStyle = cols[(k + r + (h * 5 | 0)) % 5]; g.fillRect(px + 3 + k * 2 + (r % 2), py + 1 + r * 4, 1, 3); } }
        break;
      }
      case O.FRIDGE: box(g, px + 3, py + 0, 10, 15, '#e8e4d8'); g.fillStyle = '#b8b4a8'; g.fillRect(px + 3, py + 5, 10, 1); g.fillStyle = '#6a6a6a'; g.fillRect(px + 11, py + 2, 1, 2); g.fillRect(px + 11, py + 7, 1, 3); break;
      case O.STOVE: box(g, px + 2, py + 2, 12, 12, '#d8d4c8'); g.fillStyle = INK; g.fillRect(px + 4, py + 4, 3, 3); g.fillRect(px + 9, py + 4, 3, 3); g.fillRect(px + 4, py + 9, 8, 3); break;
      case O.DESK: box(g, px + 1, py + 3, 14, 10, '#7a5030'); g.fillStyle = '#f6ecd0'; g.fillRect(px + 3, py + 5, 4, 3); g.fillStyle = '#2a2a30'; g.fillRect(px + 9, py + 4, 4, 3); break;
      case O.LOCKER: box(g, px + 2, py + 0, 12, 15, '#5a7a8a'); g.fillStyle = '#3a5a6a'; g.fillRect(px + 7, py + 0, 1, 15); for (let k = 2; k < 7; k += 2) { g.fillRect(px + 3, py + k, 3, 1); g.fillRect(px + 9, py + k, 3, 1); } break;
      case O.CABINET: box(g, px + 2, py + 2, 12, 12, '#6a6e74'); g.fillStyle = '#4a4e54'; g.fillRect(px + 2, py + 6, 12, 1); g.fillRect(px + 2, py + 10, 12, 1); g.fillStyle = '#c8c8c8'; g.fillRect(px + 7, py + 4, 2, 1); g.fillRect(px + 7, py + 8, 2, 1); g.fillRect(px + 7, py + 12, 2, 1); break;
      case O.SAFE: box(g, px + 2, py + 2, 12, 12, '#3a3a40'); g.fillStyle = '#8a8a90'; g.beginPath(); g.arc(px + 8, py + 8, 3, 0, 7); g.fill(); g.fillStyle = '#e4a92a'; g.fillRect(px + 12, py + 7, 1, 3); break;
      case O.VAULT: box(g, px + 0, py + 0, 16, 15, '#6a6a70'); g.fillStyle = '#9a9aa0'; g.beginPath(); g.arc(px + 8, py + 8, 6, 0, 7); g.fill(); g.fillStyle = INK; g.fillRect(px + 4, py + 7, 8, 2); g.fillRect(px + 7, py + 4, 2, 8); break;
      case O.POOL: {
        const l = same(-1, 0), r = same(1, 0);
        g.fillStyle = INK; g.fillRect(px - (l ? 0 : 1), py + 1, TS + (l ? 0 : 1) + (r ? 0 : 1), 14);
        g.fillStyle = '#6a3a1e'; g.fillRect(px, py + 2, TS, 12);
        g.fillStyle = '#2a7a4a'; g.fillRect(px + (l ? 0 : 2), py + 4, TS - (l ? 0 : 2) - (r ? 0 : 2), 8);
        g.fillStyle = '#f6ecd0'; if (!l) g.fillRect(px + 5, py + 7, 2, 2); else { g.fillStyle = '#c83a2a'; g.fillRect(px + 6, py + 6, 2, 2); g.fillStyle = '#e4a92a'; g.fillRect(px + 9, py + 8, 2, 2); }
        break;
      }
      case O.JUKEBOX: box(g, px + 2, py + 0, 12, 15, '#c83a2a'); g.fillStyle = '#e4a92a'; g.beginPath(); g.arc(px + 8, py + 5, 4, Math.PI, 0); g.fill(); g.fillStyle = '#6ac0e0'; g.fillRect(px + 4, py + 7, 8, 4); g.fillStyle = '#e040a0'; g.fillRect(px + 4, py + 12, 8, 1); break;
      case O.PEW: { const l = same(-1, 0); g.fillStyle = INK; g.fillRect(px - (l ? 0 : 1), py + 3, TS + 1, 10); g.fillStyle = '#7a4a2a'; g.fillRect(px, py + 4, TS, 8); g.fillStyle = '#5a3218'; g.fillRect(px, py + 4, TS, 2); break; }
      case O.ALTAR: box(g, px + 1, py + 3, 14, 11, '#f0ece0'); g.fillStyle = '#c8a040'; g.fillRect(px + 7, py - 3, 2, 8); g.fillRect(px + 5, py - 1, 6, 2); g.fillStyle = '#a82a2a'; g.fillRect(px + 1, py + 6, 14, 2); break;
      case O.BARS: g.fillStyle = INK; for (let k = 1; k < TS; k += 3) g.fillRect(px + k, py, 1, TS); g.fillRect(px, py + 2, TS, 1); g.fillRect(px, py + 12, TS, 1); break;
      case O.RACK: g.fillStyle = INK; g.fillRect(px + 1, py + 2, 14, 1); for (let k = 0; k < 4; k++) box(g, px + 2 + k * 3, py + 3, 2, 10, ['#2b2f3a', '#5c2a4a', '#b88a3a', '#8ab0d0'][(k + (h * 4 | 0)) % 4], false); break;
      case O.GUNRACK: box(g, px + 1, py + 0, 14, 14, '#6a4028'); g.fillStyle = '#2a2a30'; for (let k = 0; k < 3; k++) g.fillRect(px + 3 + k * 4, py + 2, 2, 11); g.fillStyle = '#9a6a3a'; for (let k = 0; k < 3; k++) g.fillRect(px + 3 + k * 4, py + 9, 2, 4); break;
      case O.SLOT: box(g, px + 3, py + 0, 10, 15, '#c8a040'); g.fillStyle = INK; g.fillRect(px + 4, py + 4, 8, 4); g.fillStyle = '#f6ecd0'; g.fillRect(px + 5, py + 5, 2, 2); g.fillStyle = '#c83a2a'; g.fillRect(px + 9, py + 5, 2, 2); g.fillStyle = '#c83a2a'; g.fillRect(px + 13, py + 3, 1, 5); break;
      case O.CARDTABLE: box(g, px + 1, py + 2, 14, 11, '#2a6a3a'); g.fillStyle = '#6a3a1e'; g.fillRect(px + 1, py + 2, 14, 1); g.fillStyle = '#f6ecd0'; g.fillRect(px + 4, py + 5, 2, 3); g.fillRect(px + 9, py + 6, 2, 3); g.fillStyle = '#e4a92a'; g.fillRect(px + 7, py + 9, 2, 2); break;
      case O.ARCADE: box(g, px + 3, py + 0, 10, 15, h < 0.5 ? '#2a3a8a' : '#8a2a6a'); g.fillStyle = '#101018'; g.fillRect(px + 4, py + 2, 8, 6); g.fillStyle = ['#9ad070', '#e040a0', '#6ac0e0'][h * 3 | 0]; g.fillRect(px + 5, py + 3, 3, 2); g.fillRect(px + 8, py + 5, 2, 2); g.fillStyle = '#e4a92a'; g.fillRect(px + 5, py + 10, 2, 2); break;
      case O.WASHER: box(g, px + 2, py + 2, 12, 12, '#e8e8e0'); g.fillStyle = '#6a8aa0'; g.beginPath(); g.arc(px + 8, py + 9, 4, 0, 7); g.fill(); g.fillStyle = '#b0b0a8'; g.fillRect(px + 3, py + 3, 10, 2); break;
      case O.BCHAIR: box(g, px + 3, py + 3, 10, 9, '#a82a2a'); box(g, px + 4, py + 0, 8, 3, '#8a1a1a'); g.fillStyle = '#c8c8c8'; g.fillRect(px + 7, py + 12, 2, 3); break;
      case O.PLANT: box(g, px + 5, py + 9, 6, 6, '#a8583a'); g.fillStyle = '#4a7a3a'; g.beginPath(); g.arc(px + 8, py + 6, 5, 0, 7); g.fill(); g.fillStyle = '#6a9a4a'; g.fillRect(px + 5, py + 3, 3, 2); break;
      case O.TV: box(g, px + 2, py + 3, 12, 10, '#6a4a2a'); g.fillStyle = '#1a2a2a'; g.fillRect(px + 3, py + 4, 8, 7); g.fillStyle = '#6ac0b0'; g.fillRect(px + 4, py + 5, 3, 2); g.fillStyle = '#c8a040'; g.fillRect(px + 12, py + 5, 1, 1); g.fillRect(px + 12, py + 8, 1, 1); break;
      case O.SOFA: { const l = same(-1, 0), r = same(1, 0); g.fillStyle = INK; g.fillRect(px - (l ? 0 : 1), py + 3, TS + (l ? 0 : 1) + (r ? 0 : 1), 12); g.fillStyle = '#8a6a2a'; g.fillRect(px, py + 4, TS, 10); g.fillStyle = '#a8883a'; g.fillRect(px, py + 8, TS, 5); g.fillStyle = '#6a4a1a'; if (!l) g.fillRect(px, py + 4, 2, 10); if (!r) g.fillRect(px + 14, py + 4, 2, 10); break; }
      case O.PIANO: box(g, px + 0, py + 1, 16, 13, '#1a1414'); g.fillStyle = '#f6ecd0'; g.fillRect(px + 1, py + 10, 14, 3); g.fillStyle = INK; for (let k = 2; k < 15; k += 2) g.fillRect(px + k, py + 10, 1, 2); break;
      case O.LIFT: g.fillStyle = '#e4a92a'; g.fillRect(px, py + 2, TS, 2); g.fillRect(px, py + 12, TS, 2); g.fillStyle = INK; for (let k = 0; k < TS; k += 4) { g.fillRect(px + k, py + 2, 2, 2); g.fillRect(px + k + 2, py + 12, 2, 2); } g.fillStyle = '#5a5a5a'; g.fillRect(px + 6, py + 4, 4, 8); break;
      case O.MIC: g.fillStyle = INK; g.fillRect(px + 7, py + 4, 2, 11); g.fillStyle = '#8a8a90'; g.fillRect(px + 6, py + 2, 4, 3); break;
      case O.FLOORLAMP: g.fillStyle = INK; g.fillRect(px + 7, py + 4, 2, 11); g.fillRect(px + 5, py + 14, 6, 2); box(g, px + 4, py - 1, 8, 5, '#f0d890'); break;
      case O.RUG: g.fillStyle = '#8a3a2a'; g.fillRect(px, py + 2, TS, 12); g.fillStyle = '#e4a92a'; g.fillRect(px + 2, py + 4, TS - 4, 1); g.fillRect(px + 2, py + 11, TS - 4, 1); break;
      default: return false;
    }
    return true;
  };

  // hook the new tiles/objects into the chunk renderer
  const baseTile = A.drawTile;
  A.drawTile = function (g, w, x, y, px, py) {
    const t = w.t(x, y);
    if (t >= T.VOID) return A.drawInteriorTile(g, w, x, y, px, py, t);
    return baseTile(g, w, x, y, px, py);
  };
  const baseObj = A.drawObj;
  A.drawObj = function (g, o, px, py, x, y, w) {
    if (o >= O.COUNTER) return A.drawFurniture(g, o, px, py, x, y, w);
    if (o === O.PHONE && w.t(x, y) >= T.VOID) {
      box(g, px + 4, py + 3, 8, 10, '#2a2a30');
      g.fillStyle = '#c83a2a'; g.fillRect(px + 5, py + 4, 6, 3);
      return;
    }
    return baseObj(g, o, px, py, x, y, w);
  };

  // GBA-style storefronts: taller facade with glass, door, neon, dark outline
  const baseBuilding = A.drawBuilding;
  A.drawBuilding = function (g, b, px, py) {
    baseBuilding(g, b, px, py);
    const bw = b.w * TS, bh = b.h * TS;
    const bt = D.btypes[b.type];
    // facade tall enough for a person to stand in the doorway
    const fh = Math.max(16, Math.min(40, Math.round(bh * 0.42)));
    const fy = py + bh - fh;
    const shopfront = bt.hours && b.type !== 'police' && b.type !== 'hospital' && b.type !== 'school' && b.type !== 'factory' && b.type !== 'warehouse';
    const lit = shade(b.wall, 12), dark = shade(b.wall, -45);
    // facade with brick/siding rhythm
    g.fillStyle = b.wall;
    g.fillRect(px, fy, bw, fh);
    g.fillStyle = shade(b.wall, -12);
    for (let yy = fy + 5; yy < fy + fh - 2; yy += 5) g.fillRect(px, yy, bw, 1);
    g.fillStyle = dark;
    g.fillRect(px, fy, bw, 3);
    g.fillStyle = lit;
    g.fillRect(px, fy + 3, bw, 1);
    g.fillStyle = shade(b.wall, -25);
    g.fillRect(px, py + bh - 2, bw, 2);
    const doorX = (b.door.x - b.x) * TS;
    const doorW = 16, doorH = Math.min(fh - 6, 28);
    const winTop = fy + 6, winH = Math.max(6, fh - 14);
    const nearDoor = (x, w) => b.face === 'S' && x + w > doorX - 3 && x < doorX + doorW + 3;
    if (shopfront) {
      // awning stripe over big glass windows
      const aw = bt.neon ? '#6a3a8a' : R.hash2(b.id, 3, 9) < 0.5 ? '#b83a2a' : '#2a6a5a';
      for (let x = 0; x < bw; x += 4) { g.fillStyle = (x >> 2) & 1 ? '#f0e4c8' : aw; g.fillRect(px + x, fy + 3, 4, 3); }
      g.fillStyle = INK; g.fillRect(px, fy + 6, bw, 1);
      for (let x = 4; x + 18 <= bw - 3; x += 22) {
        if (nearDoor(x, 18)) continue;
        g.fillStyle = INK; g.fillRect(px + x - 1, winTop + 1, 20, winH);
        g.fillStyle = '#3a5a78'; g.fillRect(px + x, winTop + 2, 18, winH - 2);
        g.fillStyle = '#5a7a98'; g.fillRect(px + x, winTop + 2, 18, 2);
        g.fillStyle = '#9ac8e8'; g.fillRect(px + x + 2, winTop + 4, 3, 1); g.fillRect(px + x + 2, winTop + 5, 1, 2);
        // goods on the sill
        g.fillStyle = shade(b.wall, -30); g.fillRect(px + x, winTop + winH - 2, 18, 1);
      }
    } else {
      for (let x = 5; x + 8 <= bw - 4; x += 12) {
        if (nearDoor(x, 8)) continue;
        g.fillStyle = INK; g.fillRect(px + x - 1, winTop, 10, Math.min(12, winH));
        g.fillStyle = '#4a6a88'; g.fillRect(px + x, winTop + 1, 8, Math.min(12, winH) - 2);
        g.fillStyle = '#8ab0d0'; g.fillRect(px + x + 1, winTop + 2, 2, 1);
        g.fillStyle = INK; g.fillRect(px + x + 3, winTop + 1, 1, Math.min(12, winH) - 2);
      }
    }
    if (b.face === 'S') {
      const dy = py + bh - doorH;
      g.fillStyle = INK; g.fillRect(px + doorX - 1, dy - 1, doorW + 2, doorH + 1);
      g.fillStyle = bt.neon ? '#6a3a8a' : '#6a3a1e'; g.fillRect(px + doorX, dy, doorW, doorH);
      g.fillStyle = bt.neon ? '#8a5aaa' : '#8a5230'; g.fillRect(px + doorX + 1, dy + 1, doorW - 2, 1);
      if (shopfront) { g.fillStyle = '#3a5a78'; g.fillRect(px + doorX + 2, dy + 3, doorW - 4, Math.min(8, doorH - 8)); }
      g.fillStyle = '#e4a92a'; g.fillRect(px + doorX + doorW - 3, dy + (doorH >> 1), 1, 2);
    }
    // ink outline around the whole footprint
    g.strokeStyle = INK;
    g.lineWidth = 1;
    g.strokeRect(px + 0.5, py + 0.5, bw - 1, bh - 1);
    // neon / sign in pixel font
    if (b.type !== 'house' && b.type !== 'cabin' && b.type !== 'apartment') {
      const lines = A.fitSign((b.name || bt.name).toUpperCase(), bw - 6);
      const lh = 10, boxH = lines.length * lh + 2;
      const ty = fy - boxH - 2;
      const tw = Math.max(...lines.map((l) => A.ptWidth(l))) + 6;
      const col = bt.neon ? '#ff70c8' : b.type === 'police' ? '#a8c8ff' : b.type === 'social' ? '#f0b838' : '#f6ecd0';
      g.fillStyle = INK;
      g.fillRect(Math.round(px + bw / 2 - tw / 2) - 1, ty - 1, tw + 2, boxH + 2);
      g.fillStyle = '#140c0a';
      g.fillRect(Math.round(px + bw / 2 - tw / 2), ty, tw, boxH);
      lines.forEach((l, i) => A.ptext(g, l, px + bw / 2, ty + 1 + i * lh, { align: 'center', color: col }));
    }
  };

  // Break a sign into at most two lines that fit, dropping filler words before
  // abbreviating, so names are never chopped mid-word.
  A.fitSign = function (txt, maxW) {
    const fits = (t) => A.ptWidth(t) <= maxW;
    if (fits(txt)) return [txt];
    let words = txt.split(/\s+/);
    for (let i = 1; i < words.length; i++) {
      const a = words.slice(0, i).join(' '), b = words.slice(i).join(' ');
      if (fits(a) && fits(b)) return [a, b];
    }
    const trimmed = words.filter((w) => !/^(THE|&|AND|OF|CO\.?)$/.test(w));
    if (trimmed.length && trimmed.length < words.length) return A.fitSign(trimmed.join(' '), maxW);
    // last resort: shorten the longest word with a period
    words = words.slice();
    let guard = 40;
    while (guard-- > 0) {
      let li = 0;
      words.forEach((w, i) => { if (w.length > words[li].length) li = i; });
      if (words[li].length <= 3) break;
      words[li] = words[li].replace(/\.$/, '').slice(0, -1) + '.';
      const t = words.join(' ');
      if (fits(t)) return [t];
      for (let i = 1; i < words.length; i++) {
        const a = words.slice(0, i).join(' '), b = words.slice(i).join(' ');
        if (fits(a) && fits(b)) return [a, b];
      }
    }
    return [words.join(' ')];
  };

  // cars get an ink outline too
  const baseCar = A.drawCar;
  A.drawCar = function (g, v) {
    g.save();
    g.translate(Math.round(v.x), Math.round(v.y));
    g.rotate(v.angle);
    g.strokeStyle = INK;
    g.lineWidth = 1;
    g.strokeRect(-v.model.w / 2 - 0.5, -v.model.h / 2 - 0.5, v.model.w + 1, v.model.h + 1);
    g.restore();
    baseCar(g, v);
  };
})();
