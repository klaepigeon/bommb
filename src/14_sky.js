// RHAPSODY — the air between you and the ground. Colour grading that follows the sun
// (rose-and-lavender dawns, a fat orange golden hour with glare off the low side, a blue
// dusk), streets that stay wet and glossy after rain with puddles that ring when it's
// still coming down, water that moves (glints, breathing foam on the shore, a slow
// swell), cloud shadows sliding across the ground, and birds going somewhere.
'use strict';
(function () {
  const D = R.data, TS = R.TILE;
  const G = () => R.game;
  const SK = (R.sky = { wet: 0, flocks: [], nextFlock: 8 });
  const clamp01 = (v) => (v < 0 ? 0 : v > 1 ? 1 : v);

  // ---------------------------------------------------------------- under the lighting: things on the ground
  SK.ground = function (g, left, top, z) {
    const game = G(), cam = game.cam, w = game.world, pl = game.player, t = game.clock.real;
    if (pl.room) return;
    const vw = cam.vw / z, vh = cam.vh / z;
    const tx0 = Math.floor(left / TS) - 1, ty0 = Math.floor(top / TS) - 1, tx1 = Math.ceil((left + vw) / TS) + 1, ty1 = Math.ceil((top + vh) / TS) + 1;
    const S = (x, y) => [(x - left) * z, (y - top) * z];
    const we = game.env.weather, rain = we.rain || 0, wet = this.wet;
    const px = Math.max(1, Math.round(z)); // one art pixel on screen
    g.save();
    for (let ty = ty0; ty <= ty1; ty++) for (let tx = tx0; tx <= tx1; tx++) {
      const h = R.hash2(tx, ty, 71);
      if (w.isWater(tx, ty)) {
        // a slow swell: bands of lighter water rolling through
        const sw = Math.sin(tx * 0.55 + ty * 0.35 - t * 0.9);
        if (sw > 0.55) { g.fillStyle = `rgba(190,230,245,${((sw - 0.55) * 0.22).toFixed(3)})`; const [sx, sy] = S(tx * TS, ty * TS); g.fillRect(sx, sy, TS * z, TS * z); }
        // glints drifting with the current
        if (h < 0.22) {
          const ph = (t * 0.35 + h * 7) % 1, gx = tx * TS + ((h * 97 + t * 3) % TS), gy = ty * TS + ((h * 53) % TS);
          const a = Math.sin(ph * Math.PI);
          if (a > 0.25) { g.fillStyle = `rgba(245,252,255,${(a * 0.75).toFixed(2)})`; const [sx, sy] = S(gx, gy); g.fillRect(sx, sy, px * (h < 0.08 ? 3 : 2), px); }
        }
        // foam where water meets land, breathing in and out
        const land = (x, y) => !w.isWater(x, y);
        const foam = 0.35 + Math.sin(t * 1.6 + tx * 0.9 + ty * 0.7) * 0.25;
        g.fillStyle = `rgba(240,248,250,${foam.toFixed(2)})`;
        const reach = 1 + Math.round((Math.sin(t * 1.6 + tx + ty) + 1) * 1.2);
        if (land(tx, ty - 1)) for (let k = 0; k < 16; k += 2) if (R.hash2(tx * 16 + k, ty, 3) < 0.7) { const [sx, sy] = S(tx * TS + k, ty * TS); g.fillRect(sx, sy, px * 2, px * reach); }
        if (land(tx, ty + 1)) for (let k = 0; k < 16; k += 2) if (R.hash2(tx * 16 + k, ty, 5) < 0.7) { const [sx, sy] = S(tx * TS + k, ty * TS + TS - reach); g.fillRect(sx, sy, px * 2, px * reach); }
        if (land(tx - 1, ty)) for (let k = 0; k < 16; k += 2) if (R.hash2(tx, ty * 16 + k, 7) < 0.7) { const [sx, sy] = S(tx * TS, ty * TS + k); g.fillRect(sx, sy, px * reach, px * 2); }
        if (land(tx + 1, ty)) for (let k = 0; k < 16; k += 2) if (R.hash2(tx, ty * 16 + k, 9) < 0.7) { const [sx, sy] = S(tx * TS + TS - reach, ty * TS + k); g.fillRect(sx, sy, px * reach, px * 2); }
        continue;
      }
      // wet streets: a sheen on paved ground, and puddles in the low spots
      if (wet > 0.05) {
        const tile = w.t(tx, ty), paved = D.roadTile[tile] || tile === D.T.WALK || tile === D.T.PLAZA || tile === D.T.PARKING;
        if (!paved) continue;
        if (h < 0.18) {
          const cx = tx * TS + 4 + (h * 60) % 8, cy = ty * TS + 5 + (h * 90) % 6, rx = 3 + (h * 40) % 4, ry = 1.6 + (h * 30) % 1.5;
          const [sx, sy] = S(cx, cy);
          g.fillStyle = `rgba(120,140,170,${(0.35 * wet).toFixed(2)})`;
          g.beginPath(); g.ellipse(sx, sy, rx * z, ry * z, 0, 0, Math.PI * 2); g.fill();
          g.fillStyle = `rgba(210,225,245,${(0.28 * wet).toFixed(2)})`; g.fillRect(sx - rx * z * 0.5, sy - ry * z * 0.4, rx * z * 0.6, px);
          // rain landing in it
          if (rain > 0.3) { const rp = (t * 1.3 + h * 5) % 1; g.strokeStyle = `rgba(220,235,250,${((1 - rp) * 0.5).toFixed(2)})`; g.lineWidth = px * 0.6; g.beginPath(); g.ellipse(sx + (h * 7 % 3 - 1) * z, sy, rp * rx * z, rp * ry * z, 0, 0, Math.PI * 2); g.stroke(); }
        }
      }
    }
    // the whole paved world goes darker and glossier when it's wet
    if (wet > 0.05) { g.fillStyle = `rgba(20,30,50,${(wet * 0.14).toFixed(3)})`; g.fillRect(0, 0, cam.vw, cam.vh); }
    // cloud shadows sliding across the land on a broken-cloud day
    const cloud = we.cloud || 0, day = 1 - game.clock.darkness();
    if (cloud > 0.25 && day > 0.4 && rain < 0.4) {
      const wx = (we.wind ? we.wind.x : 0.6) * 18, wy = (we.wind ? we.wind.y : 0.2) * 18;
      for (let i = 0; i < 6; i++) {
        // world-anchored, wrapped into a band around the camera so they drift past and come round again
        const bx = i * 331 + t * wx, by = i * 173 + t * wy;
        const cx = left - 300 + (((bx - (left - 300)) % 900) + 900) % 900, cy = top - 120 + (((by - (top - 120)) % 500) + 500) % 500;
        const [sx, sy] = S(cx, cy);
        const r = (90 + (i * 37) % 70) * z;
        const gr = g.createRadialGradient(sx, sy, r * 0.2, sx, sy, r);
        const a = (0.13 * clamp01((cloud - 0.25) * 2) * day).toFixed(3);
        gr.addColorStop(0, `rgba(20,24,40,${a})`); gr.addColorStop(1, 'rgba(20,24,40,0)');
        g.fillStyle = gr; g.beginPath(); g.ellipse(sx, sy, r * 1.4, r * 0.8, 0, 0, Math.PI * 2); g.fill();
      }
    }
    g.restore();
  };

  // ---------------------------------------------------------------- over the lighting: the colour of the air
  SK.grade = function (g) {
    const game = G(), cam = game.cam, pl = game.player, h = game.clock.hour(), W = cam.vw, H = cam.vh;
    if (pl.room) return;
    const we = game.env.weather, clear = clamp01(1 - (we.cloud || 0) * 0.8 - (we.rain || 0));
    g.save();
    // dawn: rose and lavender, a cool lift in the shadows
    const dawn = clamp01(1 - Math.abs(h - 6.3) / 1.3) * clear;
    if (dawn > 0.02) {
      g.globalCompositeOperation = 'soft-light'; g.fillStyle = `rgba(255,150,190,${(dawn * 0.55).toFixed(2)})`; g.fillRect(0, 0, W, H);
      g.globalCompositeOperation = 'source-over';
      const gr = g.createLinearGradient(W, 0, 0, 0); gr.addColorStop(0, `rgba(255,190,200,${(dawn * 0.22).toFixed(2)})`); gr.addColorStop(0.6, 'rgba(255,190,200,0)');
      g.fillStyle = gr; g.fillRect(0, 0, W, H);
    }
    // golden hour: everything goes amber, glare off the low western sun
    const gold = clamp01(1 - Math.abs(h - 18.4) / 1.6) * clear;
    if (gold > 0.02) {
      g.globalCompositeOperation = 'soft-light'; g.fillStyle = `rgba(255,140,40,${(gold * 0.48).toFixed(2)})`; g.fillRect(0, 0, W, H);
      g.globalCompositeOperation = 'source-over';
      const gr = g.createLinearGradient(0, 0, W * 0.7, H * 0.4); gr.addColorStop(0, `rgba(255,190,90,${(gold * 0.22).toFixed(2)})`); gr.addColorStop(1, 'rgba(255,190,90,0)');
      g.fillStyle = gr; g.fillRect(0, 0, W, H);
    }
    // dusk: the blue hour between the sun going and the streetlights winning
    const dusk = clamp01(1 - Math.abs(h - 20.2) / 0.9);
    if (dusk > 0.02) { g.globalCompositeOperation = 'soft-light'; g.fillStyle = `rgba(70,90,200,${(dusk * 0.6).toFixed(2)})`; g.fillRect(0, 0, W, H); }
    g.restore();
  };

  // ---------------------------------------------------------------- birds
  SK.birds = function (g, left, top, z, dt) {
    const game = G(), cam = game.cam, pl = game.player, w = game.world;
    if (pl.room) return;
    const h = game.clock.hour();
    this.nextFlock -= dt;
    if (this.nextFlock <= 0 && h > 5.5 && h < 20 && (game.env.weather.rain || 0) < 0.5) {
      this.nextFlock = 25 + Math.random() * 40;
      const nearWater = w.isWater(((pl.x / TS) | 0) + 8, (pl.y / TS) | 0) || w.isWater(((pl.x / TS) | 0) - 8, (pl.y / TS) | 0) || w.isWater((pl.x / TS) | 0, ((pl.y / TS) | 0) + 8);
      const dir = Math.random() < 0.5 ? 1 : -1, y0 = pl.y - 60 + Math.random() * 120, n = 3 + ((Math.random() * 5) | 0);
      const kind = nearWater ? 'gull' : 'crow';
      const birds = [];
      for (let i = 0; i < n; i++) birds.push({ dx: -i * 9 * dir + (Math.random() - 0.5) * 6, dy: (i % 2 ? 1 : -1) * i * 4 + (Math.random() - 0.5) * 4, ph: Math.random() * 6 });
      this.flocks.push({ x: pl.x - dir * (cam.vw / z / 2 + 40), y: y0, vx: dir * (kind === 'gull' ? 34 : 46), vy: (Math.random() - 0.5) * 8, kind, birds, alt: 40 + Math.random() * 20, life: 30 });
    }
    const t = game.clock.real;
    for (const f of this.flocks) {
      f.x += f.vx * dt; f.y += f.vy * dt; f.life -= dt;
      for (const b of f.birds) {
        const bx = f.x + b.dx, by = f.y + b.dy;
        // the shadow on the ground, offset by altitude
        const sx = (bx - left + f.alt * 0.25) * z, sy = (by - top + f.alt) * z;
        g.fillStyle = 'rgba(20,16,30,0.18)'; g.fillRect(sx - 2 * z, sy, 5 * z, z);
        // the bird itself: a flapping V
        const flap = Math.sin(t * (f.kind === 'gull' ? 7 : 11) + b.ph) > 0;
        const X = (bx - left) * z, Y = (by - top) * z;
        g.fillStyle = f.kind === 'gull' ? '#f4f0e6' : '#1c1820';
        if (flap) { g.fillRect(X - 3 * z, Y - z, z, z); g.fillRect(X - 2 * z, Y, z, z); g.fillRect(X - z, Y, 3 * z, z); g.fillRect(X + 2 * z, Y, z, z); g.fillRect(X + 3 * z, Y - z, z, z); }
        else { g.fillRect(X - 3 * z, Y + z, z, z); g.fillRect(X - 2 * z, Y, z, z); g.fillRect(X - z, Y, 3 * z, z); g.fillRect(X + 2 * z, Y, z, z); g.fillRect(X + 3 * z, Y + z, z, z); }
        if (f.kind === 'gull') { g.fillStyle = '#6a6a70'; g.fillRect(X - 3 * z, Y + (flap ? -z : z), z, z); g.fillRect(X + 3 * z, Y + (flap ? -z : z), z, z); }
      }
    }
    this.flocks = this.flocks.filter((f) => f.life > 0);
  };

  SK.tick = function (dt) {
    const we = G().env.weather, rain = we.rain || 0;
    // puddles form fast and dry slowly (about two in-game hours after the rain stops)
    if (rain > 0.25) this.wet = Math.min(1, this.wet + dt * 0.25 * rain);
    else this.wet = Math.max(0, this.wet - dt * G().clock.rate / 120);
  };

  SK.init = function () {
    this.wet = 0; this.flocks = []; this.nextFlock = 8;
    if (this.wrapped) return;
    this.wrapped = true;
    const P = R.Renderer.prototype, dl = P.drawLighting;
    let last = performance.now();
    P.drawLighting = function (g, left, top, z) {
      const now = performance.now(), dt = Math.min(0.05, (now - last) / 1000); last = now;
      try { SK.ground(g, left, top, z); SK.birds(g, left, top, z, dt); } catch (e) { if (!SK.warned) { SK.warned = true; console.warn(e); } }
      const r = dl.call(this, g, left, top, z);
      SK.grade(g);
      return r;
    };
  };
})();
