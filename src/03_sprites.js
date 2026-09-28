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
  const lum = (hex) => { const n = parseInt(String(hex || '#c89070').slice(1), 16); return ((n >> 16) * 0.3 + ((n >> 8) & 255) * 0.59 + (n & 255) * 0.11) / 255; };
  const hairKey = (hex) => {
    const n = parseInt(String(hex || '#3a2a1a').slice(1), 16), r = n >> 16, gg = (n >> 8) & 255, b = n & 255;
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
    if (ov.maskCol) look.old.maskCol = ov.maskCol;
    // overrides the original's look roller doesn't take directly
    if (ov.hair) look.old.hair = ov.hair;
    if ('beard' in ov) look.old.beard = ov.beard;
    if ('stache' in ov) look.old.stache = ov.stache;
    return look.old;
  };
  A.invalidateLook = function (look) { look.old = null; };
  const DIR8 = ['right', 'downright', 'down', 'downright', 'right', 'upright', 'up', 'upright'];
  const FLIP8 = [false, false, false, true, true, true, false, false];
  A.oldSprite = function (look, d8, frame, pose) {
    const L = A.oldLook(look);
    const key = (look.seedStr || '') + '|' + (L._key || (L._key = JSON.stringify(L))) + '|' + d8 + frame + (pose || '');
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
    const phase = moving ? Math.floor(walk * 0.5) % 4 : 0; // ~8 frames a second at a walk
    const frame = phase === 1 ? 1 : phase === 3 ? 2 : 0;
    const d8 = A.dir8(dir, st.ang);
    const bob = moving && (phase === 1 || phase === 3) && !st.down ? 1 : 0; // a step lifts the body a pixel
    let X = Math.round(x), Y = Math.round(y) - bob;
    const fx = st.scale || st.alpha != null || st.crouch;
    if (fx) {
      g.save();
      g.translate(X, Y);
      if (st.scale) g.scale(st.scale, st.scale);
      if (st.crouch) g.scale(1.08, 0.8); // hunched low, knees bent
      if (st.alpha != null) g.globalAlpha = st.alpha;
      X = 0; Y = 0;
    }
    // the original's soft shadow
    g.fillStyle = 'rgba(16,12,36,0.45)';
    g.fillRect(X - 4, Y - 1 + bob, 8, 2);
    g.fillRect(X - 3, Y - 2 + bob, 6, 4);
    let pose = st.pose || null;
    const wdef = st.weapon && st.weapon !== 'fists' ? D.weapons[st.weapon] : null;
    if (!pose && wdef) pose = wdef.gun || wdef.ring ? 'g' : st.weapon === 'knuckles' ? null : 'k';
    if (!pose && st.held) pose = A.heldPose(st.held, 0, 1);
    // slamming an overhead prop: the arms come down with it
    const slamming = pose === 'h' && st.held && st.swing >= 0.5;
    // seen from behind, a windup is the raised frame and the follow-through the low one
    if (DIR8[d8] === 'up' || DIR8[d8] === 'upright') { if (pose === 'b1') pose = 'b2'; else if (pose === 'b2') pose = 'b1'; else if (pose === 'w1') pose = 'w2'; }
    // legs keep walking whatever the arms are doing
    const spr = A.oldSprite(look, d8, st.down ? 0 : frame, st.down ? null : slamming ? 'p2' : pose);
    if (st.down) {
      g.save();
      g.translate(X, Y - 3);
      g.rotate(Math.PI / 2);
      g.drawImage(spr, -spr.width / 2, -22);
      g.restore();
      if (fx) g.restore();
      return;
    }
    // things in the hand go behind the body when the hand is on the far side
    const hand = () => {
      if (wdef) drawWeapon8(g, X, Y, d8, st.weapon, st.ang, pose, look.kid);
      else if (st.held) A.drawHeldItem(g, X, Y, d8, st.held, pose, look.kid, { phase: moving ? phase : -1, swing: st.swing, skin: look.skin });
    };
    A._sil = !!st.silenced;
    const behind = (wdef || st.held) && (wdef && wdef.gun ? DIR8[d8] === 'up' || DIR8[d8] === 'upright' : A.itemBehind(d8, pose));
    if (behind) hand();
    g.drawImage(spr, X - spr.width / 2, Y - 25);
    if (look.hatKind && A.drawHat) A.drawHat(g, X, Y - 25 + (look.kid ? 2 : 0), look.hatKind, d8, look.hatCol);
    if (!behind) hand();
    if (fx) g.restore();
  };
  // ---------------------------------------------------------------- held items
  // Guns are built from the original's gun definitions (barrel, slide, drum, grip, mag,
  // pump, stock) and rotated around a real grip point so shots leave the muzzle.
  // Props, bats, knives and bottles use the original's hand anchors (ea / Zi) and its
  // grip-rotation maths (Xs), so they sit in the fist instead of floating by the hip.
  const GUNDEF = {
    revolver: { barrel: [6, 14, 5, 2], drum: [5, 6], grip: [2, 7, 3, 5], wood: 1, sc: 0.62 },
    magnum: { barrel: [5, 15, 5, 2], drum: [5, 6], grip: [2, 7, 3, 5], wood: 1, sc: 0.7, dark: 1 },
    chopper: { barrel: [2, 14, 5, 3], grip: [5, 8, 2, 4], mag: [8, 8, 2, 5], drum2: 1, sc: 0.72 },
    shotgun: { barrel: [5, 15, 5, 2], pump: [9, 7, 3, 1], stock: [0, 6, 6, 3], wood: 1, sc: 0.85 },
    rifle: { barrel: [4, 15, 5, 2], stock: [0, 5, 6, 3], scope: [7, 11, 3, 1], wood: 1, sc: 0.95 },
    derringer: { barrel: [7, 12, 6, 2], grip: [5, 7, 3, 4], wood: 1, sc: 0.5 },
    colt45: { barrel: [5, 14, 5, 3], grip: [5, 7, 3, 5], wood: 1, sc: 0.62 },
    sawedoff: { barrel: [6, 12, 5, 3], stock: [2, 6, 6, 3], wood: 1, sc: 0.8 },
    carbine: { barrel: [4, 15, 5, 2], stock: [0, 6, 6, 3], mag: [8, 8, 2, 3], wood: 1, sc: 0.92 },
    crossbow: { barrel: [3, 14, 6, 2], stock: [0, 5, 6, 3], bow: 12, wood: 1, sc: 0.85 },
    tommy: { barrel: [2, 15, 5, 2], grip: [5, 8, 2, 4], mag: [7, 8, 4, 4], stock: [0, 3, 5, 3], pump: [11, 7, 2, 1], wood: 1, sc: 0.85 },
  };
  const gunCache = {};
  A.gunArt = function (w) {
    if (gunCache[w]) return gunCache[w];
    const d = GUNDEF[w];
    if (!d) return null;
    const xx = OLD.x, sc = d.sc, off = Math.round(8 - 8 * sc);
    const metal = d.dark ? xx.black : xx.metal, wood = xx.wood;
    const o = new OLD.O(16, 16);
    const R_ = (x, y, ww, hh, ramp) => o.shadedRect(Math.round(x * sc) + off, Math.round(y * sc) + off, Math.max(1, Math.round(ww * sc)), Math.max(1, Math.round(hh * sc)), ramp);
    const [b0, b1, by, bh] = d.barrel;
    R_(b0, by, b1 - b0 + 1, bh, metal);
    if (d.drum) R_(d.drum[0] - 1, d.drum[1], 4, 3, metal);
    if (d.grip) R_(d.grip[0], d.grip[1] + 1, d.grip[2], d.grip[3], d.wood ? wood : metal);
    if (d.mag) R_(d.mag[0], d.mag[1], d.mag[2], d.mag[3], metal);
    if (d.pump) R_(d.pump[0], d.pump[1], d.pump[2], 2, wood);
    if (d.stock) R_(d.stock[0], d.stock[2], d.stock[1] - d.stock[0], d.stock[3], wood);
    if (d.scope) R_(d.scope[0], d.scope[2], d.scope[1] - d.scope[0], d.scope[3] + 1, xx.black);
    if (d.bow) { R_(d.bow, by - 5, 1, bh + 10, wood); o.line(Math.round(d.bow * sc) + off, Math.round((by - 5) * sc) + off, Math.round(3 * sc) + off, Math.round((by + 1) * sc) + off, '#d8d0b8'); o.line(Math.round(d.bow * sc) + off, Math.round((by + bh + 5) * sc) + off, Math.round(3 * sc) + off, Math.round((by + 1) * sc) + off, '#d8d0b8'); }
    o.outline('#282828');
    const px = (v) => Math.round(v * sc) + off;
    // where the hand goes and where the bullet comes out
    const grip = d.grip ? [px(d.grip[0] + d.grip[2] / 2), px(d.grip[1] + 2)] : d.pump ? [px(d.pump[0] + 1), px(d.pump[1] + 1)] : [px(d.stock[1]), px(d.stock[2] + 1)];
    const muzzle = [px(b1) + 1, px(by + bh / 2)];
    return (gunCache[w] = { cv: o.toCanvas(), grip, muzzle });
  };
  // gun-pose fist positions (from the original's pose 'g'), in 16x32 sprite cells
  const GUN_HAND = { down: [11, 20], downright: [14, 19], right: [14, 16], upright: [13, 10], up: [11, 6] };
  const handWorld = (X, Y, d8, cell, kid) => {
    const flip = FLIP8[d8];
    return [X + (flip ? 15 - cell[0] : cell[0]) - 8 + 0.5, Y - 25 + cell[1] + 0.5 + (kid ? 2 : 0)];
  };
  // world-space muzzle for someone holding a gun and aiming at ang
  A.muzzle = function (actor, weapon, ang) {
    const art = A.gunArt(weapon === 'revolver' || !GUNDEF[weapon] ? 'revolver' : weapon);
    const d8 = A.dir8(actor.dir, ang);
    const [hx, hy] = handWorld(actor.x, actor.y, d8, GUN_HAND[DIR8[d8]], actor.look && actor.look.kid);
    const flip = Math.cos(ang) < 0 ? -1 : 1;
    const sil = actor.silencedGun && actor.silencedGun(weapon);
    const mx = art.muzzle[0] - art.grip[0] + (sil ? 4 : 0), my = (art.muzzle[1] - art.grip[1]) * flip;
    const c = Math.cos(ang), s_ = Math.sin(ang);
    return [hx + mx * c - my * s_, hy + mx * s_ + my * c];
  };
  // the original's grip maths: bucket the angle, flip for left, rotate around the grip
  A.gripXs = function (grip, e) {
    const t = ((Math.round(e / (Math.PI * 2) * 16) % 16) + 16) % 16, s2 = (t / 16) * Math.PI * 2, flip = Math.cos(s2) < -0.01;
    const o = grip[0] + 0.5 - 8, r = (flip ? 15 - grip[1] : grip[1]) + 0.5 - 8;
    const n = s2 - Math.atan2(-r, -o), h = Math.cos(n), l = Math.sin(n);
    return { k: t, flip, rot: n, ox: h * o - l * r, oy: l * o + h * r };
  };
  // small melee/throwable items, painted in the original's style
  const ITEM = {
    bat: [(o) => { const w = OLD.x.wood; o.line(2, 13, 12, 3, w[4]); o.line(3, 13, 13, 3, w[3]); o.line(3, 14, 13, 4, w[2]); o.rect(12, 2, 2, 2, w[4]); o.line(2, 13, 4, 11, OLD.x.black[2]); }, [3, 12]],
    knife: [(o) => { const m = OLD.x.metal; o.line(7, 8, 13, 2, m[4]); o.line(7, 9, 13, 3, m[2]); o.line(3, 12, 6, 9, OLD.x.wood[1]); o.line(4, 12, 6, 10, OLD.x.wood[2]); }, [4, 11]],
    molotov: [(o) => { o.shadedRect(6, 6, 5, 8, OLD.x.glass); o.rect(7, 3, 3, 3, OLD.x.glass[2]); o.rect(8, 1, 2, 3, '#e8d8b0'); o.set(9, 0, '#ffb030'); }, [8, 10]],
    dynamite: [(o) => { o.shadedRect(5, 5, 6, 9, OLD.x.red); o.hline(5, 10, 9, OLD.x.red[0]); o.line(8, 5, 10, 1, '#9a9a9a'); o.set(10, 1, '#ffd040'); }, [8, 10]],
    gascan: [(o) => { o.shadedRect(3, 5, 10, 9, OLD.x.red); o.rect(10, 3, 3, 2, OLD.x.metal[2]); o.rect(5, 3, 4, 2, OLD.x.black[2]); }, [7, 4]],
    razor: [(o) => { const m = OLD.x.metal; o.line(3, 12, 7, 8, OLD.x.black[2]); o.line(4, 12, 7, 9, OLD.x.black[3]); o.line(7, 8, 12, 3, m[4]); o.line(8, 8, 12, 4, m[2]); o.line(8, 9, 13, 4, m[3]); }, [4, 11]],
    machete: [(o) => { const m = OLD.x.metal, w = OLD.x.wood; o.line(2, 14, 5, 11, w[1]); o.line(3, 14, 5, 12, w[2]); o.line(5, 10, 14, 1, m[4]); o.line(6, 10, 14, 2, m[3]); o.line(6, 11, 15, 2, m[2]); o.line(4, 10, 6, 12, OLD.x.black[2]); }, [3, 13]],
    hatchet: [(o) => { const m = OLD.x.metal, w = OLD.x.wood; o.line(3, 14, 11, 6, w[2]); o.line(4, 14, 12, 6, w[1]); o.shadedRect(9, 2, 4, 6, m); o.line(13, 2, 13, 7, m[4]); }, [4, 13]],
    crowbar: [(o) => { const b = OLD.x.black; o.line(2, 14, 12, 4, b[3]); o.line(3, 14, 13, 4, b[2]); o.set(13, 3, b[3]); o.set(12, 2, b[3]); o.set(11, 2, b[2]); o.set(2, 14, '#b02a20'); }, [3, 13]],
    sap: [(o) => { const b = OLD.x.black; o.line(4, 12, 8, 8, b[2]); o.shadedEllipse(10, 6, 2.6, 2.6, b); o.set(9, 5, b[4] || b[3]); }, [5, 11]],
    knuckles: [(o) => { const m = OLD.x.yellow; for (let i = 0; i < 4; i++) o.shadedEllipse(5 + i * 2, 8, 1.3, 1.6, m); o.shadedRect(4, 9, 8, 2, m); }, [8, 9]],
  };
  const itemCache = {};
  A.itemArt = function (k) {
    if (itemCache[k]) return itemCache[k];
    let cv, grip;
    if (ITEM[k]) { const o = new OLD.O(16, 16); ITEM[k][0](o); cv = o.outline('#282828').toCanvas(); grip = ITEM[k][1]; }
    else if (OLD.props[k]) { cv = OLD.paintProp(k); grip = PROP_GRIP[k] || null; }
    else return null;
    return (itemCache[k] = { cv, grip });
  };
  // the original's grip points for one-handed props (heavy things are held overhead)
  const PROP_GRIP = { pan: [15, 6], bottle: [7, 4], chair: [8, 2], stool: [5, 13], broom: [3, 1], plank: [1, 12], pipe: [2, 13], wrench: [3, 13], sign: [7, 14], guitar: [14, 1], fish: [14, 9], shovel: [2, 0], flare: [4, 13], extinguisher: [8, 3], paint: [8, 2], bucket: [8, 1], lamp: [8, 12], cone: [8, 3], gnome: [8, 2], plant: [8, 9], dumbbell: [8, 10], bowling: [8, 5], cake: [8, 12] };
  A.propGrip = (k) => PROP_GRIP[k];
  // which pose a held item needs: 'k' holds it out, 'h' hoists it overhead, 'w1/w2' swing
  A.heldPose = function (k, swingT, swingDur) {
    const art = A.itemArt(k);
    if (swingT > 0) return swingT / swingDur > 0.55 ? 'w1' : 'w2';
    return art && art.grip ? 'k' : 'h';
  };
  // draw an item in the hand. behind: true when the hand is on the far side of the body
  A.drawHeldItem = function (g, X, Y, d8, k, pose, kid, anim) {
    const art = A.itemArt(k);
    if (!art) return;
    const dirName = DIR8[d8], flip = FLIP8[d8], sgn = flip ? -1 : 1;
    if (!art.grip || pose === 'h') {
      // overhead, both hands up. It lags a step behind your stride, and a swing hoists it
      // back over your head before slamming it down in front of you.
      let ox = 0, oy = 0, rot = 0, slam = false;
      const ph = anim ? anim.phase : -1, sw = anim && anim.swing >= 0 ? anim.swing : -1;
      if (ph >= 0) { oy = ph === 0 || ph === 2 ? 1 : -1; ox = ph === 1 ? 1 : ph === 3 ? -1 : 0; rot = ph === 1 ? 0.06 : ph === 3 ? -0.06 : 0; }
      if (sw >= 0) {
        const up = dirName === 'up' || dirName === 'upright', side = dirName !== 'down' && dirName !== 'up';
        const fx = side ? sgn : 0, fy = up ? -1 : dirName === 'down' || dirName === 'downright' ? 1 : 0;
        if (sw < 0.4) { const t = sw / 0.4; oy -= 4 * t; ox -= fx * 3 * t; rot -= fx * 0.35 * t; }
        else {
          const t = Math.min(1, (sw - 0.4) / 0.25), e = t * t * (3 - 2 * t);
          const dx = fx * 10, dy = up ? -3 : fy > 0 ? 10 : 8;
          oy += -4 + (4 + dy) * e; ox += -fx * 3 + (fx * 3 + dx) * e; rot += fx * (-0.35 + 1.1 * e);
          slam = sw >= 0.5;
        }
      }
      const cx = X + ox, cy = Y - 25 + 1 + oy + (kid ? 2 : 0);
      g.save();
      g.translate(Math.round(cx), Math.round(cy));
      if (rot) g.rotate(rot);
      g.drawImage(art.cv, -8, -8);
      // mid-slam the arms are down with it, fists gripping the sides
      if (slam && anim.skin) { g.fillStyle = '#140e10'; g.fillRect(-9, -1, 4, 4); g.fillRect(5, -1, 4, 4); g.fillStyle = anim.skin; g.fillRect(-8, 0, 2, 2); g.fillRect(6, 0, 2, 2); }
      g.restore();
      return;
    }
    let hx, hy, h;
    // long things (pipes, planks, shovels) ride on the shoulder instead of dragging on the ground
    const carry = CARRY[k] || (Math.hypot(art.grip[0] - 7.5, art.grip[1] - 7.5) > 5.5 ? CARRY.bat : null);
    if (carry && pose === 'k') {
      // knives point ahead of you, bats rest on the shoulder
      [hx, hy] = OLD.ea(dirName, kid);
      const side = dirName !== 'down' && dirName !== 'up';
      if (carry.fwd) h = side ? (sgn > 0 ? 0.45 : Math.PI - 0.45) : dirName === 'down' ? 1.25 : -1.9;
      else h = side ? -Math.PI / 2 + 0.35 * sgn : dirName === 'down' ? -Math.PI / 2 + 0.4 : -Math.PI / 2 - 0.4;
      const u = X + (hx + 0.5 - 8) * sgn, p = Y - 25 + hy + 0.5;
      const vx = 7.5 - art.grip[0], vy = 7.5 - art.grip[1], flipIt = Math.cos(h) < -0.01;
      g.save();
      g.translate(Math.round(u), Math.round(p));
      g.rotate(h - Math.atan2(flipIt ? -vy : vy, vx));
      g.scale(carry.sc || 1, (carry.sc || 1) * (flipIt ? -1 : 1));
      g.drawImage(art.cv, -art.grip[0] - 0.5, -art.grip[1] - 0.5);
      g.restore();
      return;
    }
    if (pose === 'w1' || pose === 'w2') {
      const [x0, y0, x1, y1] = OLD.Zi(dirName, pose === 'w1' ? 1 : 2, kid);
      hx = x0; hy = y0; h = Math.atan2(y1 - y0, (x1 - x0) * sgn);
    } else {
      [hx, hy] = OLD.ea(dirName, kid);
      const long = Math.hypot(art.grip[0] - 7.5, art.grip[1] - 7.5) > 5.5;
      const kk = dirName === 'down' || dirName === 'up' ? 0 : sgn;
      h = Math.PI / 2 - (long ? 0.5 * kk : 0);
    }
    const d = A.gripXs(art.grip, h);
    const u = X + (hx + 0.5 - 8) * sgn, p = Y - 25 + hy + 0.5 - (kid ? 0 : 0);
    g.save();
    g.translate(Math.round(u - d.ox), Math.round(p - d.oy));
    g.rotate(d.rot);
    if (d.flip) g.scale(1, -1);
    g.drawImage(art.cv, -8, -8);
    g.restore();
  };
  const CARRY = { knife: { fwd: 1, sc: 0.7 }, razor: { fwd: 1, sc: 0.75 }, sap: { fwd: 1, sc: 0.8 }, bat: { sc: 0.9 } };
  // ---------------------------------------------------------------- sneaking in plain sight
  // Sneak and you duck into something: a cardboard box, a bush, a trash can, a barrel or a
  // potted fern. Your shoes stick out of the bottom and shuffle along when you move.
  const DISG = {
    box(o) { const c = ['#4a2e12', '#7a5424', '#a87c40', '#d0a468']; o.shadedRect(1, 3, 14, 12, c); o.hline(1, 14, 3, c[3]); o.line(3, 3, 5, 1, c[2]); o.line(12, 3, 10, 1, c[1]); o.hline(6, 9, 3, '#e0d0a0'); o.rect(10, 11, 3, 2, '#b02a20'); o.rect(5, 7, 6, 2, '#1a1008'); o.set(6, 7, '#ffffff'); o.set(9, 7, '#ffffff'); o.set(7, 8, '#101010'); o.set(10, 8, '#101010'); },
    bush(o) { const l = OLD.x.leaf; o.ellipse(8, 9, 7.5, 6.5, (x, y, h, v) => (h * -0.6 - v * 0.7 > 0.35 ? l[3] : h * -0.6 - v * 0.7 < -0.4 ? l[1] : l[2])); for (const [x, y] of [[4, 6], [10, 5], [6, 11], [12, 10], [3, 10]]) o.set(x, y, l[4] || l[3]); o.set(7, 8, '#ffffff'); o.set(9, 8, '#ffffff'); o.set(7, 9, '#101010'); o.set(9, 9, '#101010'); o.set(12, 4, '#e84a6a'); o.set(4, 12, '#e84a6a'); },
    trash(o) { const m = OLD.x.metal; o.shadedRect(3, 5, 10, 10, m); for (const x of [5, 8, 11]) o.line(x, 6, x, 14, m[1]); o.shadedRect(2, 3, 12, 2, m); o.rect(7, 2, 2, 1, m[1]); o.set(9, 4, '#7a9a3a'); o.set(10, 3, '#e8e0c8'); },
    barrel(o) { const w = OLD.x.wood, m = OLD.x.metal; o.shadedRect(3, 2, 10, 13, w); o.hline(3, 12, 4, m[1]); o.hline(3, 12, 12, m[1]); for (const x of [6, 9]) o.line(x, 2, x, 14, w[1]); o.hline(4, 11, 2, w[3]); o.set(5, 7, '#ffffff'); o.set(10, 7, '#ffffff'); },
    plant(o) { const l = OLD.x.leaf, t = ['#6a2a14', '#9a4424', '#c86434', '#e8905a']; o.shadedRect(4, 10, 8, 5, t); o.hline(3, 12, 10, t[3]); for (let i = 0; i < 7; i++) { const a = -Math.PI / 2 + (i - 3) * 0.42; o.line(8, 10, Math.round(8 + Math.cos(a) * 7), Math.round(9 + Math.sin(a) * 8), l[1 + (i % 3)]); } o.set(8, 6, '#ffffff'); o.set(8, 7, '#101010'); },
  };
  A.DISGUISES = Object.keys(DISG);
  const disgCache = {};
  A.drawDisguise = function (g, pl, kind) {
    if (!disgCache[kind]) { const o = new OLD.O(16, 16); (DISG[kind] || DISG.box)(o); disgCache[kind] = o.outlineBy(OLD.Ue).toCanvas(); }
    const X = Math.round(pl.x), Y = Math.round(pl.y);
    const moving = pl.walk && Math.abs(pl.walk) > 0.01;
    const phase = moving ? Math.floor(pl.walk * 0.5) % 4 : 0;
    // shoes peeking out underneath, still doing their little walk
    g.save();
    g.beginPath(); g.rect(X - 8, Y - 4, 16, 6); g.clip();
    A.drawPerson(g, pl.x, pl.y, pl.dir, pl.walk, pl.look, { ang: pl.ang });
    g.restore();
    g.save();
    g.translate(X, Y - 3 - (phase === 1 || phase === 3 ? 1 : 0));
    if (moving) g.rotate((phase === 1 ? 0.07 : phase === 3 ? -0.07 : 0));
    g.scale(1.3, 1.3);
    g.drawImage(disgCache[kind], -8, -16);
    g.restore();
  };

  A.itemBehind = function (d8, pose) {
    const n = DIR8[d8];
    if (pose === 'w2') return n === 'up' || n === 'upright';
    if (pose === 'w1') return n === 'right' || n === 'downright';
    return n === 'up' || n === 'upright';
  };
  // where someone's (right) hand is, in world space; third value true when it's hidden behind them
  const IDLE_HAND = { down: [12.5, 20], downright: [11.5, 20], right: [7.5, 20], upright: [4.5, 19], up: [3.5, 19] };
  A.handPos = function (actor, pose) {
    const d8 = A.dir8(actor.dir, actor.ang);
    const n = DIR8[d8], kid = actor.look && actor.look.kid;
    const cell = pose === 'g' ? GUN_HAND[n] : pose === 'k' ? OLD.ea(n, kid) : IDLE_HAND[n];
    const [x, y] = handWorld(actor.x, actor.y, d8, cell, kid);
    return [x, y, pose !== 'g' && (n === 'up' || n === 'upright')];
  };
  // guns: pointed along the aim, grip in the fist
  A.drawGun = function (g, X, Y, d8, w, ang, kid) {
    const art = A.gunArt(GUNDEF[w] ? w : 'revolver');
    const [hx, hy] = handWorld(X, Y, d8, GUN_HAND[DIR8[d8]], kid);
    const a = ang == null ? d8 * Math.PI / 4 : ang;
    g.save();
    g.translate(Math.round(hx), Math.round(hy));
    g.rotate(a);
    if (Math.cos(a) < 0) g.scale(1, -1);
    // aimed at the camera (or away) the barrel is foreshortened instead of hanging off the hand
    const vert = Math.abs(Math.sin(a));
    if (vert > 0.92) g.scale(Math.sin(a) > 0 ? 0.5 : 0.65, 1);
    g.drawImage(art.cv, -art.grip[0], -art.grip[1]);
    if (A._sil) { const mx = art.muzzle[0] - art.grip[0], my = art.muzzle[1] - art.grip[1]; g.fillStyle = '#141414'; g.fillRect(mx - 1, my - 1.5, 6, 3); g.fillStyle = '#4a4a50'; g.fillRect(mx - 1, my - 1, 5, 2); g.fillStyle = '#7a7a84'; g.fillRect(mx, my - 1, 3, 1); }
    g.restore();
  };
  function drawWeapon8(g, X, Y, d8, w, ang, pose, kid) {
    if (!w || w === 'fists' || w === 'ring') return;
    const def = D.weapons[w];
    if (def && def.gun) return A.drawGun(g, X, Y, d8, w, ang, kid);
    if (w === 'bat' && pose && pose[0] === 'b') return; // the swing pose paints the bat itself
    A.drawHeldItem(g, X, Y, d8, w, pose === 'p1' || pose === 'p2' ? 'w1' : pose, kid);
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
      garage: 'garage', house: 'house', cabin: 'house', apartment: 'house', barn: 'house', hotel: 'bank', motel: 'house', arcade: 'arcade', strip: 'club', costume: 'arcade', factory: 'work', warehouse: 'work', office: 'police', school: 'house' };
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
  // the original's own ground textures, 16 texels a tile like the characters
  const tcache = {};
  const otex = (k, v) => tcache[k + v] || (tcache[k + v] = OLD.tiles[k](v).toCanvas());
  const OLDGROUND = {
    [T.GRASS]: ['grass', 10], [T.PARK]: ['grass', 10], [T.WALK]: ['walk', 6], [T.PLAZA]: ['plaza', 4], [T.DOCK]: ['board', 1],
    [T.SAND]: ['sand', 6], [T.DIRT]: ['dirt', 3], [T.DIRTROAD]: ['path', 4], [T.LOT]: ['path', 4], [T.PARKING]: ['parking', 1], [T.BURNT]: ['scorch', 4],
  };
  A.drawTile = function (g, w, x, y, px, py) {
    const t = w.t(x, y);
    if (t >= T.VOID) return A.drawInteriorTile(g, w, x, y, px, py, t);
    // asphalt: the original's seamless road texture, then our lane paint on top
    if (t === T.ROAD || t === T.HWY) {
      g.drawImage(otex('road', Math.floor(R.hash2(x, y, 21) * 1e6) % 8), px, py);
      return A.drawRoad(g, w, x, y, px, py, t, true);
    }
    const og = OLDGROUND[t];
    if (!og) return baseTile(g, w, x, y, px, py);
    const v = Math.floor(R.hash2(x, y, 20) * 1e6) % og[1];
    g.drawImage(otex(og[0], v), px, py);
    // the original's curb: a bright lip and a dark edge where sidewalk meets road
    if (t === T.WALK || t === T.PARKING) {
      const rd = (xx, yy) => D.roadTile[w.t(xx, yy)];
      const lip = OLD.x.walk[4], edge = OLD.x.walk[0];
      if (rd(x, y + 1)) { g.fillStyle = lip; g.fillRect(px, py + 14, TS, 1); g.fillStyle = edge; g.fillRect(px, py + 15, TS, 1); }
      if (rd(x, y - 1)) { g.fillStyle = lip; g.fillRect(px, py + 1, TS, 1); g.fillStyle = edge; g.fillRect(px, py, TS, 1); }
      if (rd(x + 1, y)) { g.fillStyle = lip; g.fillRect(px + 14, py, 1, TS); g.fillStyle = edge; g.fillRect(px + 15, py, 1, TS); }
      if (rd(x - 1, y)) { g.fillStyle = lip; g.fillRect(px + 1, py, 1, TS); g.fillStyle = edge; g.fillRect(px, py, 1, TS); }
    }
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

  // Buildings are painted by the original build's own building routine (03_oldbuild.js):
  // roof, wall material, awning, shop glass, door, rooftop vents, lit windows at night.
  const KIND = {
    house: 'home', cabin: 'home', barn: 'home', apartment: 'apartment', hotel: 'hotel', motel: 'hotel',
    general: 'shop', liquor: 'shop', pawn: 'pawn', tailor: 'shop', barber: 'shop', butcher: 'shop', gunshop: 'shop',
    diner: 'diner', bar: 'bar', social: 'bar', club: 'club', casino: 'club', arcade: 'arcade', pharmacy: 'pharmacy',
    hospital: 'clinic', church: 'chapel', police: 'police', bank: 'bank', garage: 'garage', gas: 'garage',
    warehouse: 'warehouse', factory: 'warehouse', office: 'office', school: 'office', laundry: 'laundromat',
  };
  const WALLS = ['houseWallA', 'houseWallB', 'houseWallC', 'houseWallD', 'houseWallE'];
  const ROOFS = ['roof', 'roofBlue', 'roofTerra'];
  const bcache = new Map();
  A.buildingArt = function (b) {
    const lit = !!(R.game && R.game.clock && R.game.clock.isNight());
    const key = b.id + '|' + b.w + 'x' + b.h + b.face + (lit ? 'L' : '') + b.type;
    let c = bcache.get(key);
    if (!c) {
      const a = { id: b.id + 1, w: b.w, h: b.h, kind: KIND[b.type] || 'shop', wall: WALLS[b.seedArt % 5], doorOffset: b.face === 'S' ? b.door.x - b.x : -99, roof: ROOFS[b.seedArt % 3] };
      const r = OLD.paintBuilding(a, lit);
      c = { cv: r.P.toCanvas(), facadeTop: r.facadeTop, neon: r.neon };
      if (r.flat) A.roofPass(c.cv, b, r.facadeTop, lit);
      if (bcache.size > 700) bcache.clear();
      bcache.set(key, c);
    }
    return c;
  };
  // Flat roofs: the original sprinkled grey gravel noise over the whole slab. Repaint the
  // inside of the parapet as tar-paper membrane with seams, the parapet's cast shadow,
  // and rooftop furniture (bulkhead, skylights, AC units, vents, a water tank on tall
  // buildings, puddles), all in the same four-tone shaded, outlined style.
  const ROOFPAL = [
    ['#2e2c30', '#3a383c', '#46444a', '#56545a', '#6a686e'], // charcoal tar
    ['#2c3034', '#363c42', '#424a50', '#525c62', '#687278'], // blue slate
    ['#34302a', '#403a32', '#4e463c', '#5e554a', '#72685a'], // warm gravel
    ['#2e322c', '#383e36', '#444c42', '#545e50', '#687264'], // green-grey
  ];
  const INKR = '#140e10';
  A.roofPass = function (cv, b, facadeTop, lit) {
    const g = cv.getContext('2d');
    const W = cv.width, x0 = 3, y0 = 3, x1 = W - 3, y1 = facadeTop - 4;
    if (x1 - x0 < 12 || y1 - y0 < 10) return;
    const rnd = R.mulberry(b.id * 977 + 13);
    const pal = ROOFPAL[(b.seedArt || b.id) % ROOFPAL.length];
    const px = (x, y, c) => { g.fillStyle = c; g.fillRect(x, y, 1, 1); };
    const rect = (x, y, w, h, c) => { g.fillStyle = c; g.fillRect(x, y, w, h); };
    // membrane: lit from the top-left, darker towards the bottom
    for (let y = y0; y < y1; y++) {
      const band = (y - y0) / (y1 - y0);
      rect(x0, y, x1 - x0, 1, pal[band < 0.25 ? 3 : band < 0.7 ? 2 : 1]);
    }
    // sheet seams every 16px, with a soft highlight on the upper lip
    for (let y = y0 + 12; y < y1 - 2; y += 16) { rect(x0, y, x1 - x0, 1, pal[0]); rect(x0, y + 1, x1 - x0, 1, pal[3]); }
    for (let x = x0 + 20 + ((rnd() * 8) | 0); x < x1 - 4; x += 24 + ((rnd() * 10) | 0)) for (let y = y0; y < y1; y++) if ((y - y0) % 16 < 12) px(x, y, pal[1]);
    // grain, sparse and in-palette
    for (let k = 0; k < (x1 - x0) * (y1 - y0) / 28; k++) px(x0 + ((rnd() * (x1 - x0)) | 0), y0 + ((rnd() * (y1 - y0)) | 0), pal[rnd() < 0.5 ? 1 : 3]);
    // the parapet casts a shadow onto the roof (light from the top-left)
    rect(x0, y0, x1 - x0, 2, 'rgba(10,6,10,0.35)');
    rect(x0, y0, 2, y1 - y0, 'rgba(10,6,10,0.28)');
    const shadow = (x, y, w, h) => { g.fillStyle = 'rgba(10,6,10,0.35)'; g.fillRect(x + 2, y + 2, w, h); };
    const boxS = (x, y, w, h, ramp) => {
      shadow(x, y, w, h);
      rect(x - 1, y - 1, w + 2, h + 2, INKR);
      rect(x, y, w, h, ramp[2]); rect(x, y, w, 1, ramp[4]); rect(x, y + 1, 1, h - 1, ramp[3]);
      rect(x + w - 1, y + 1, 1, h - 1, ramp[1]); rect(x, y + h - 1, w, 1, ramp[0]);
    };
    const metal = ['#3a3e46', '#565c66', '#7a808a', '#a4aab2', '#d0d4d8'];
    const brick = ['#4a1e14', '#6e2e1e', '#8e4028', '#b05a38', '#cc7a52'];
    const used = [];
    const free = (x, y, w, h) => x >= x0 + 2 && y >= y0 + 2 && x + w <= x1 - 2 && y + h <= y1 - 2 && !used.some((u) => x < u[0] + u[2] + 3 && x + w + 3 > u[0] && y < u[1] + u[3] + 3 && y + h + 3 > u[1]);
    const place = (w, h, tries, fn) => { for (let i = 0; i < (tries || 30); i++) { const x = x0 + 2 + ((rnd() * (x1 - x0 - w - 4)) | 0), y = y0 + 2 + ((rnd() * (y1 - y0 - h - 4)) | 0); if (free(x, y, w, h)) { used.push([x, y, w, h]); fn(x, y); return true; } } return false; };
    // stair bulkhead with a door on its south face
    place(14, 11, 40, (x, y) => { boxS(x, y, 14, 11, brick); rect(x - 1, y - 2, 16, 3, INKR); rect(x, y - 1, 14, 2, pal[4]); rect(x + 4, y + 4, 6, 7, '#3a2418'); rect(x + 5, y + 5, 4, 5, '#5a3a24'); px(x + 8, y + 8, '#e0c060'); });
    // water tank on tall buildings
    if (b.type === 'apartment' || b.type === 'hotel' || b.type === 'office' || b.h >= 4) place(16, 18, 40, (x, y) => {
      g.fillStyle = 'rgba(10,6,10,0.35)'; g.beginPath(); g.ellipse(x + 11, y + 15, 8, 4, 0, 0, 7); g.fill();
      rect(x + 3, y + 10, 1, 8, INKR); rect(x + 12, y + 10, 1, 8, INKR);
      const wood = ['#4a2c16', '#6a4222', '#8a5a30', '#a8743e', '#c89056'];
      rect(x + 1, y + 2, 14, 11, INKR); rect(x + 2, y + 3, 12, 9, wood[2]); rect(x + 2, y + 3, 3, 9, wood[3]); rect(x + 11, y + 3, 3, 9, wood[1]);
      rect(x + 2, y + 5, 12, 1, metal[1]); rect(x + 2, y + 9, 12, 1, metal[1]);
      rect(x + 1, y, 14, 3, INKR); rect(x + 2, y, 12, 2, wood[4]); rect(x + 7, y - 2, 2, 2, wood[1]);
    });
    // skylights
    const nSky = Math.min(3, Math.floor((x1 - x0) / 36));
    for (let i = 0; i < nSky; i++) place(10, 7, 20, (x, y) => {
      shadow(x, y, 10, 7); rect(x - 1, y - 1, 12, 9, INKR); rect(x, y, 10, 7, metal[2]);
      const glass = lit ? ['#f8e8a0', '#e8c060'] : ['#8ab8c8', '#3e6474'];
      rect(x + 1, y + 1, 8, 5, glass[1]); rect(x + 1, y + 1, 8, 2, glass[0]); rect(x + 5, y + 1, 1, 5, metal[1]);
      if (!lit) { px(x + 2, y + 4, '#c8e8f0'); px(x + 3, y + 3, '#c8e8f0'); }
    });
    // AC units with a fan grille
    const nAC = 1 + Math.floor((x1 - x0) / 60);
    for (let i = 0; i < nAC; i++) place(11, 9, 25, (x, y) => {
      boxS(x, y, 11, 9, metal);
      g.fillStyle = metal[0]; g.beginPath(); g.arc(x + 5.5, y + 4.5, 3, 0, 7); g.fill();
      rect(x + 5, y + 2, 1, 5, metal[3]); rect(x + 3, y + 4, 5, 1, metal[3]);
    });
    // vent pipes
    for (let i = 0; i < 3; i++) place(3, 3, 15, (x, y) => { shadow(x, y, 3, 3); rect(x - 1, y - 1, 5, 5, INKR); rect(x, y, 3, 3, metal[3]); px(x + 1, y + 1, metal[0]); });
    // a puddle or two in the low spots
    for (let i = 0; i < 2; i++) place(9, 4, 10, (x, y) => { g.fillStyle = pal[0]; g.beginPath(); g.ellipse(x + 4.5, y + 2, 4.5, 2, 0, 0, 7); g.fill(); px(x + 3, y + 1, pal[4]); });
    // police get a light bar, banks a flagpole
    if (b.type === 'police') { rect(((x0 + x1) / 2 | 0) - 7, y0 + 4, 14, 4, INKR); rect(((x0 + x1) / 2 | 0) - 6, y0 + 5, 6, 2, '#d83a2a'); rect(((x0 + x1) / 2 | 0), y0 + 5, 6, 2, '#3a6ad8'); }
  };
  A.drawBuilding = function (g, b, px, py) {
    const bw = b.w * TS;
    const bt = D.btypes[b.type];
    const art = A.buildingArt(b);
    // soft drop shadow, then the painted building (2px wall margin, 6px roof overhang)
    g.fillStyle = 'rgba(20,12,8,0.32)';
    g.fillRect(px + 4, py + 2, bw, b.h * TS);
    g.drawImage(art.cv, px - 2, py - 6);
    const facadeY = py - 6 + art.facadeTop;
    // a door on the far side: an awning and a mat on the sidewalk so you know it's there
    if (b.face === 'N') {
      const dx = (b.door.x - b.x) * TS + px;
      g.fillStyle = INK; g.fillRect(dx, py - 5, 16, 5);
      g.fillStyle = bt && bt.neon ? '#6a3a8a' : '#8a3a24'; g.fillRect(dx + 1, py - 4, 14, 3);
      g.fillStyle = '#f0e2c0'; for (let k = 2; k < 14; k += 4) g.fillRect(dx + k, py - 4, 2, 3);
    }
    // name sign in pixel font, where the original hung it: just above the facade
    if (b.type !== 'house' && b.type !== 'cabin' && b.type !== 'apartment' && b.type !== 'barn') {
      const lines = A.fitSign((b.name || bt.name).toUpperCase(), bw - 6);
      const lh = 10, boxH = lines.length * lh + 2;
      const ty = b.face === 'S' ? facadeY - boxH - 3 : py + 24; // far-side door: sign sits below the door's icon board
      const tw = Math.max(...lines.map((l) => A.ptWidth(l))) + 6;
      const col = bt.neon ? '#ff70c8' : b.type === 'police' ? '#a8c8ff' : b.type === 'social' ? '#f0b838' : art.neon || '#f6ecd0';
      g.fillStyle = INK;
      g.fillRect(Math.round(px + bw / 2 - tw / 2) - 1, ty - 1, tw + 2, boxH + 2);
      g.fillStyle = '#1c1418';
      g.fillRect(Math.round(px + bw / 2 - tw / 2), ty, tw, boxH);
      g.fillStyle = '#3a2c30';
      g.fillRect(Math.round(px + bw / 2 - tw / 2), ty, tw, 1);
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

  // ---------------------------------------------------------------- vehicles
  // Cars are painted once per model and colour, top-down and facing +x, in the same
  // shaded, ink-outlined style as the people and buildings: a five-tone body lit from
  // the top-left, glass with a sky glint, chrome bumpers, tyres, lamps and each model's
  // trim (stripes, woodgrain, vinyl roof, checker band, light bar, ladder...).
  const carCache = new Map();
  const ramp5 = (c) => [shade(c, -52), shade(c, -30), c, shade(c, 22), shade(c, 44)];
  const GLASS = ['#16202c', '#22364a', '#34546c', '#6a92a8', '#b8d8e4'];
  const CHROME = ['#4a4e56', '#7a808a', '#aab0b8', '#d8dce0', '#ffffff'];
  A.carArt = function (m, color, wrecked) {
    const key = m.name + color + (wrecked ? 'W' : '');
    let c = carCache.get(key);
    if (c) return c;
    const L = m.w, H = m.h, o = new OLD.O(L + 2, H + 4);
    const B = ramp5(wrecked ? '#3a3230' : color);
    const X = 1, Y = 2; // body origin inside the canvas (room for tyres)
    const set = (x, y, col) => o.set(X + x, Y + y, col);
    const rect = (x, y, w, h, col) => { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) set(x + i, y + j, col); };
    // tyres peeking out past the body
    const tw = Math.max(5, Math.round(L * 0.14));
    for (const tx of [Math.round(L * 0.14), Math.round(L * 0.72)]) { rect(tx, -1, tw, 2, '#101014'); rect(tx, H - 1, tw, 2, '#101014'); rect(tx + 1, -1, tw - 2, 1, '#2a2a30'); rect(tx + 1, H, tw - 2, 1, '#2a2a30'); }
    // body, lit from the top-left: highlight along the top edge, shade along the bottom
    for (let y = 0; y < H; y++) for (let x = 0; x < L; x++) {
      if ((x === 0 || x === L - 1) && (y === 0 || y === H - 1)) continue; // rounded corners
      const t = y / (H - 1);
      set(x, y, t < 0.12 ? B[4] : t < 0.3 ? B[3] : t > 0.88 ? B[0] : t > 0.7 ? B[1] : B[2]);
    }
    const heavy = m.bus || m.box || m.fire;
    if (heavy) {
      // cab at the front, long body behind
      const cab = 12;
      rect(L - cab, 1, 1, H - 2, B[0]);
      rect(L - cab + 2, 2, 5, H - 4, GLASS[1]); rect(L - cab + 2, 2, 5, 2, GLASS[3]); set(L - cab + 3, 4, GLASS[4]);
      rect(2, 2, L - cab - 4, H - 4, B[3]); rect(2, 2, L - cab - 4, 1, B[4]); rect(2, H - 3, L - cab - 4, 1, B[1]);
      if (m.bus) { for (let k = 4; k < L - cab - 4; k += 7) { rect(k, 0, 5, 2, GLASS[2]); set(k, 0, GLASS[4]); rect(k, H - 2, 5, 2, GLASS[1]); } rect(6, H / 2 - 1 | 0, 4, 2, CHROME[2]); rect(L - cab - 12, H / 2 - 1 | 0, 4, 2, CHROME[2]); }
      if (m.box) { for (let k = 6; k < L - cab - 4; k += 8) rect(k, 2, 1, H - 4, B[2]); }
      if (m.fire) { rect(4, H / 2 - 2 | 0, L - cab - 8, 4, CHROME[3]); for (let k = 5; k < L - cab - 5; k += 3) rect(k, H / 2 - 2 | 0, 1, 4, CHROME[1]); rect(L - cab - 3, 2, 2, H - 4, '#f0c020'); }
    } else {
      // hood crease, windshield, roof, rear glass, side windows
      const fg = Math.round(L * 0.62), rg = Math.round(L * 0.26), roofL = fg - rg - 5;
      rect(fg + 3, (H / 2 | 0), L - fg - 6, 1, B[3]);
      rect(fg + 3, (H / 2 | 0) + 1, L - fg - 6, 1, B[1]);
      // windshield (towards +x), a trapezoid with a glint
      for (let j = 2; j < H - 2; j++) { const inset = j === 2 || j === H - 3 ? 1 : 0; rect(fg - inset, j, 4, 1, j < H / 2 ? GLASS[2] : GLASS[1]); }
      set(fg + 1, 3, GLASS[4]); set(fg + 2, 4, GLASS[3]);
      // roof
      const roofC = m.vinyl ? ['#c8bca8', '#e4dac8', '#f4ecdc'] : [B[2], B[3], B[4]];
      rect(rg + 3, 2, roofL, H - 4, roofC[1]); rect(rg + 3, 2, roofL, 1, roofC[2]); rect(rg + 3, H - 3, roofL, 1, m.vinyl ? '#a89c88' : B[1]);
      // rear glass
      rect(rg, 2, 3, H - 4, GLASS[1]); rect(rg, 2, 3, 1, GLASS[3]);
      // side windows along both edges of the cabin
      rect(rg + 3, 1, roofL, 1, GLASS[3]); rect(rg + 3, H - 2, roofL, 1, GLASS[0]);
      rect(rg + 3 + (roofL / 2 | 0), 1, 1, 1, B[1]); rect(rg + 3 + (roofL / 2 | 0), H - 2, 1, 1, B[0]);
      // mirrors
      set(fg + 1, -1, B[1]); set(fg + 1, H, B[0]);
      if (m.stripes && !wrecked) { rect(1, (H / 2 | 0) - 2, L - 2, 1, '#f4f0e8'); rect(1, (H / 2 | 0) + 1, L - 2, 1, '#f4f0e8'); rect(rg + 3, (H / 2 | 0) - 2, roofL, 1, '#fffaf0'); }
      if (m.wood && !wrecked) { const wd = ['#5a3418', '#7a4a22', '#9a6430']; rect(2, 1, rg - 1, 2, wd[1]); rect(2, H - 3, rg - 1, 2, wd[0]); for (let k = 3; k < rg; k += 4) { set(k, 1, wd[2]); set(k, H - 3, wd[1]); } }
      if (m.bed) { rect(1, 2, rg - 2, H - 4, B[0]); rect(2, 3, rg - 4, H - 6, '#2a241e'); for (let k = 3; k < rg - 2; k += 3) rect(k, 3, 1, H - 6, '#3a3228'); }
      if (m.mural && !wrecked) { rect(rg + 3, 2, roofL, H - 4, B[3]); for (let k = 0; k < roofL; k++) set(rg + 3 + k, 3 + Math.round(Math.sin(k * 0.5) * 1.5 + 2), '#e4a92a'); for (let k = 0; k < roofL; k += 2) set(rg + 3 + k, H - 5, '#f06a2a'); }
      if (m.checker) { for (let k = 2; k < L - 2; k++) { set(k, 1, ((k >> 1) % 2) ? '#141414' : '#f0e8c0'); set(k, H - 2, ((k >> 1) % 2) ? '#f0e8c0' : '#141414'); } rect(rg + 3 + (roofL / 2 | 0) - 2, (H / 2 | 0) - 2, 5, 4, '#141414'); rect(rg + 4 + (roofL / 2 | 0) - 2, (H / 2 | 0) - 1, 3, 2, '#f0e0a0'); }
      if (m.police) { rect(1, 1, rg - 1, H - 2, '#e8e8ec'); rect(fg + 4, 1, L - fg - 5, H - 2, '#e8e8ec'); rect(1, H - 2, rg - 1, 1, '#b8b8c0'); rect(fg + 4, H - 2, L - fg - 5, 1, '#b8b8c0'); }
      if (m.medic) { rect(rg + 3, 2, roofL, H - 4, '#f4f4f4'); const cx = rg + 3 + (roofL / 2 | 0); rect(cx - 3, (H / 2 | 0) - 1, 7, 2, '#c02020'); rect(cx - 1, (H / 2 | 0) - 3, 2, 6, '#c02020'); }
    }
    // chrome bumpers, headlights, taillights
    rect(L - 1, 1, 1, H - 2, CHROME[2]); set(L - 1, 1, CHROME[4]);
    rect(0, 1, 1, H - 2, CHROME[1]);
    rect(L - 2, 1, 1, 2, '#fff4c0'); rect(L - 2, H - 3, 1, 2, '#fff4c0');
    rect(1, 1, 1, 2, '#b02018'); rect(1, H - 3, 1, 2, '#b02018');
    if (wrecked) for (let k = 0; k < L * H / 6; k++) set((Math.random() * L) | 0, (Math.random() * H) | 0, Math.random() < 0.5 ? '#1a1412' : '#4a3a30');
    const cv = o.outlineBy(OLD.Ue).toCanvas();
    c = { cv, ox: -X - L / 2, oy: -Y - H / 2 };
    if (carCache.size > 300) carCache.clear();
    carCache.set(key, c);
    return c;
  };
  A.drawCar = function (g, v) {
    const m = v.model, L = m.w, H = m.h;
    const art = A.carArt(m, v.color, v.wrecked);
    g.save();
    g.translate(Math.round(v.x), Math.round(v.y));
    // shadow falls down-right, whatever way the car points
    g.fillStyle = 'rgba(15,10,5,0.35)';
    g.save(); g.translate(2, 3); g.rotate(v.angle); g.fillRect(-L / 2, -H / 2, L, H); g.restore();
    g.rotate(v.angle);
    g.imageSmoothingEnabled = false;
    g.drawImage(art.cv, art.ox, art.oy);
    // live bits: headlights, brake lights, sirens, engine smoke
    if (v.lights) { g.fillStyle = '#fffbe0'; g.fillRect(L / 2 - 2, -H / 2 + 1, 2, 2); g.fillRect(L / 2 - 2, H / 2 - 3, 2, 2); }
    if (v.braking) { g.fillStyle = '#ff3a20'; g.fillRect(-L / 2, -H / 2 + 1, 2, 2); g.fillRect(-L / 2, H / 2 - 3, 2, 2); }
    if (m.police) {
      const on = v.siren && (performance.now() / 150) % 2 < 1;
      g.fillStyle = INK; g.fillRect(-3, -H / 2 + 2, 5, H - 4);
      g.fillStyle = on ? '#ff3030' : '#7a1818'; g.fillRect(-2, -H / 2 + 3, 3, (H - 6) / 2);
      g.fillStyle = on ? '#3050ff' : '#18286a'; g.fillRect(-2, 0, 3, (H - 6) / 2);
    }
    if ((m.medic || m.fire) && v.siren) { const on = (performance.now() / 150) % 2 < 1; g.fillStyle = on ? '#ff3030' : '#ffffff'; g.fillRect(L / 2 - 14, -H / 2 + 2, 2, H - 4); }
    if (v.hp < 35 && !v.wrecked) { g.fillStyle = 'rgba(40,40,40,0.45)'; g.fillRect(L / 2 - 9, -3, 5, 6); }
    g.restore();
  };
})();
