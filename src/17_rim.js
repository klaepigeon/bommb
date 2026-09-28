// RHAPSODY — rim light. At night and indoors every person picks up light from whatever is
// brightest nearby: a street lamp, a neon sign, headlights, a burning car, a muzzle flash, a
// siren, a jukebox. The sprite's edge on that side catches the light in its colour, the
// way a normal-mapped sprite would, so a man walking under a pink sign goes pink along one
// shoulder. Rim masks are worked out once per sprite frame and light direction and cached.
'use strict';
(function () {
  const D = R.data, T = D.T, O = D.O, TS = R.TILE, A = R.art;
  const RL = (R.rim = { calls: [], cache: new Map(), ids: new WeakMap(), nid: 1, on: true });
  const SW = 48, SH = 60, OX = 24, OY = 48;
  const scratch = document.createElement('canvas'); scratch.width = SW; scratch.height = SH;
  const sg = scratch.getContext('2d', { willReadFrequently: true });
  const OCT = [[1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1], [0, -1], [1, -1]];

  // record the people drawn in the world pass this frame
  let capturing = false;
  const bDraw = A.drawPerson;
  A.drawPerson = function (g, x, y, dir, walk, look, st) {
    if (!capturing && RL.on && RL.world === g && look && !(st && (st.down || st.alpha != null))) RL.calls.push([x, y, dir, walk, look, st ? Object.assign({}, st) : {}]);
    return bDraw.apply(this, arguments);
  };

  const idOf = (look) => { let i = RL.ids.get(look); if (!i) { i = RL.nid++; RL.ids.set(look, i); } return i; };
  // the rim mask: solid sprite pixels whose neighbour toward the light is empty
  RL.rim = function (c, oct, col) {
    const [x, y, dir, walk, look, st] = c;
    const moving = walk && Math.abs(walk) > 0.01, phase = moving ? Math.floor(walk * 0.5) % 4 : 0;
    const key = `${idOf(look)}|${A.dir8 ? A.dir8(dir, st.ang) : dir}|${phase}|${st.pose || ''}|${st.weapon || ''}|${st.held ? st.held.id || st.held : ''}|${st.crouch ? 1 : 0}|${look.old ? 1 : 0}|${oct}|${col}`;
    let cv = this.cache.get(key);
    if (cv) return cv;
    sg.setTransform(1, 0, 0, 1, 0, 0);
    sg.clearRect(0, 0, SW, SH);
    capturing = true;
    try { A.drawPerson(sg, OX, OY, dir, walk, look, st); } catch (e) { capturing = false; return null; }
    capturing = false;
    const src = sg.getImageData(0, 0, SW, SH).data;
    cv = document.createElement('canvas'); cv.width = SW; cv.height = SH;
    const cg = cv.getContext('2d'), out = cg.createImageData(SW, SH), d = out.data;
    const [dx, dy] = OCT[oct];
    const n = parseInt(col.slice(1), 16), r = n >> 16, gg = (n >> 8) & 255, b = n & 255;
    const solid = (px, py) => px >= 0 && py >= 0 && px < SW && py < SH && src[(py * SW + px) * 4 + 3] > 200;
    for (let py = 0; py < SH; py++) for (let px = 0; px < SW; px++) {
      if (!solid(px, py)) continue;
      const edge = !solid(px + dx, py + dy);
      const edge2 = !edge && !solid(px + dx * 2, py + dy * 2);
      if (!edge && !edge2) continue;
      const i = (py * SW + px) * 4;
      d[i] = r; d[i + 1] = gg; d[i + 2] = b; d[i + 3] = edge ? 255 : 90;
    }
    cg.putImageData(out, 0, 0);
    if (this.cache.size > 900) this.cache.clear();
    this.cache.set(key, cv);
    return cv;
  };

  // light sources in view: [x, y, radius, strength, colour]
  RL.lights = function (game, left, top, vw, vh) {
    const w = game.world, L = [], pl = game.player, room = pl.room, t = game.clock.real;
    const tx0 = Math.floor(left / TS) - 4, ty0 = Math.floor(top / TS) - 4, tx1 = Math.ceil((left + vw) / TS) + 4, ty1 = Math.ceil((top + vh) / TS) + 4;
    for (let ty = ty0; ty <= ty1; ty++) for (let tx = tx0; tx <= tx1; tx++) {
      const ob = w.o(tx, ty);
      if (room) {
        if (ob === O.FLOORLAMP) L.push([tx * TS + 8, ty * TS - 4, 70, 0.8, '#ffd08a']);
        else if (ob === O.JUKEBOX) L.push([tx * TS + 8, ty * TS, 50, 0.8, '#ff60b8']);
        else if (ob === O.TV || ob === O.ARCADE || ob === O.SLOT) L.push([tx * TS + 8, ty * TS, 40, 0.6, '#8ad0ff']);
        else if (w.t(tx, ty) === T.DANCE && (tx + ty + Math.floor(t * 4)) % 3 === 0) L.push([tx * TS + 8, ty * TS + 8, 30, 0.7, ['#ff50c0', '#f0c040', '#60c8ff'][(tx + ty) % 3]]);
      } else if (ob === O.LAMP) L.push([tx * TS + 8, ty * TS - 6, 64, 0.75, '#ffd08a']);
    }
    if (!room) {
      const NEON = ['#ff46be', '#5adcff', '#ff7828', '#8cff78', '#c86eff'];
      for (const b of w.buildings) {
        if (!b || b.destroyed || !D.btypes[b.type].neon) continue;
        if (b.x + b.w < tx0 || b.x > tx1 || b.y + b.h < ty0 || b.y > ty1) continue;
        const dead = R.hash2(b.id, 7, 9) < 0.15 && Math.sin(t * 13 + b.id) > 0.55;
        if (!dead) L.push([(b.x + b.w / 2) * TS, (b.y + b.h) * TS, 80, 0.9, NEON[Math.floor(R.hash2(b.id, 2, 9) * NEON.length)]]);
      }
      for (const v of game.traffic.list) {
        if (v.removed || v.wrecked && !v.burning) continue;
        if (Math.abs(v.x - (left + vw / 2)) > vw || Math.abs(v.y - (top + vh / 2)) > vh) continue;
        if (v.lights) { const ca = Math.cos(v.angle), sa = Math.sin(v.angle); L.push([v.x + ca * 34, v.y + sa * 34, 70, 1, '#fff4c8']); }
        if (v.siren) L.push([v.x, v.y, 60, 1, (performance.now() / 150) % 2 < 1 ? '#ff3030' : '#3060ff']);
        if (v.burning > 0) L.push([v.x, v.y, 70, 1, '#ff8a30']);
      }
      for (const fr of game.env.fires.values()) if (fr.x >= tx0 && fr.x <= tx1 && fr.y >= ty0 && fr.y <= ty1) L.push([fr.x * TS + 8, fr.y * TS + 8, 60 * fr.i, 1, '#ff9030']);
    }
    for (const f of game.fx.flashes) L.push([f.x, f.y, f.big ? f.big * 3 : 50, 1.2, '#fff0b0']);
    // hard light from rings, and allies of the spectrum
    if (R.ring && R.ring.beam && game.clock.real - R.ring.beam.t < 0.1 && R.ringPal) L.push([R.ring.beam.ex, R.ring.beam.ey, 70, 1, R.ringPal().core]);
    return L;
  };

  const RP = R.Renderer.prototype, bLight = RP.drawLighting;
  RP.drawLighting = function (g, left, top, z) {
    const r = bLight.apply(this, arguments);
    const game = this.game, cam = game.cam, pl = game.player;
    const calls = RL.calls; RL.calls = [];
    RL.world = this.wg || RL.world;
    if (!RL.on || !calls.length) return r;
    const dark = pl.room ? 0.5 : game.clock.darkness();
    if (dark < 0.15) return r;
    const vw = cam.vw / z, vh = cam.vh / z;
    const L = RL.lights(game, left, top, vw, vh);
    if (!L.length) return r;
    g.save();
    g.imageSmoothingEnabled = false;
    g.globalCompositeOperation = 'lighter';
    let n = 0;
    for (const c of calls) {
      if (n > 40) break;
      const x = c[0], y = c[1] - 12;
      let best = null, bi = 0;
      for (const l of L) {
        const d = Math.hypot(l[0] - x, l[1] - y);
        if (d > l[2] || d < 2) continue;
        const i = l[3] * (1 - d / l[2]);
        if (i > bi) { bi = i; best = l; }
      }
      if (!best || bi < 0.12) continue;
      const a = Math.atan2(best[1] - y, best[0] - x);
      const oct = ((Math.round(a / (Math.PI / 4)) % 8) + 8) % 8;
      const cv = RL.rim(c, oct, best[4]);
      if (!cv) continue;
      g.globalAlpha = Math.min(0.8, bi * dark * 1.15);
      g.drawImage(cv, (Math.round(x) - OX - left) * z, (Math.round(c[1]) - OY - top) * z, SW * z, SH * z);
      n++;
    }
    g.restore();
    return r;
  };
  // know which context is the world pass: the renderer's main canvas
  const bRender = RP.render;
  if (bRender) RP.render = function () { RL.world = this.g; RL.calls = []; return bRender.apply(this, arguments); };
})();
