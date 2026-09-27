// RHAPSODY — renderer: chunked world, y-sorted entities, fire, weather, night
// lighting (lamps, headlights, neon, windows), speech bubbles and markers.
'use strict';
(function () {
  const D = R.data, T = D.T, O = D.O, TS = R.TILE;
  const A = R.art;

  const Renderer = (R.Renderer = function (game, canvas) {
    this.game = game;
    this.cv = canvas;
    this.g = canvas.getContext('2d', { alpha: false });
    this.light = document.createElement('canvas');
    this.lg = this.light.getContext('2d');
    this.dpr = 1;
    this.rainDrops = [];
    for (let i = 0; i < 160; i++) this.rainDrops.push({ x: Math.random(), y: Math.random(), s: 0.6 + Math.random() * 0.8 });
  });
  const P = Renderer.prototype;

  P.resize = function () {
    const g = this.game;
    const w = window.innerWidth, h = window.innerHeight;
    this.dpr = Math.min(window.devicePixelRatio || 1, 2);
    this.cv.width = Math.round(w * this.dpr);
    this.cv.height = Math.round(h * this.dpr);
    this.light.width = Math.ceil(w / 2);
    this.light.height = Math.ceil(h / 2);
    g.cam.vw = w;
    g.cam.vh = h;
    const tiles = R.clamp(Math.min(w, h) / 36, 19, 32);
    this.baseZoom = (Math.min(w, h) / (tiles * TS)) * g.settings.zoom;
    g.cam.zoom = this.baseZoom;
  };

  P.render = function () {
    const game = this.game, g = this.g, cam = game.cam, w = game.world, pl = game.player;
    const dpr = this.dpr;
    // zoom out with speed
    const sp = pl.inCar ? Math.abs(pl.inCar.speed) : 0;
    const targetZoom = this.baseZoom * (pl.inCar ? R.clamp(1 - sp / 600, 0.62, 0.9) : 1);
    cam.zoom += (targetZoom - cam.zoom) * 0.05;
    const z = cam.zoom;
    const left = cam.left() + cam.ox, top = cam.top() + cam.oy;
    const vw = cam.vw / z, vh = cam.vh / z;
    g.setTransform(1, 0, 0, 1, 0, 0);
    g.imageSmoothingEnabled = false;
    g.fillStyle = '#1f5566';
    g.fillRect(0, 0, this.cv.width, this.cv.height);
    const sc = dpr * z;
    g.setTransform(sc, 0, 0, sc, Math.round(-left * sc), Math.round(-top * sc));
    // chunks
    const CPX = A.CH * TS;
    const cx0 = Math.max(0, Math.floor(left / CPX)), cy0 = Math.max(0, Math.floor(top / CPX));
    const cx1 = Math.min(Math.floor(w.W / A.CH) - 1, Math.floor((left + vw) / CPX)), cy1 = Math.min(Math.floor(w.H / A.CH) - 1, Math.floor((top + vh) / CPX));
    for (let cy = cy0; cy <= cy1; cy++)
      for (let cx = cx0; cx <= cx1; cx++) g.drawImage(A.getChunk(w, cx, cy), cx * CPX, cy * CPX);
    // animated water glints, gas stains, decals
    const tx0 = Math.floor(left / TS), ty0 = Math.floor(top / TS), tx1 = Math.ceil((left + vw) / TS), ty1 = Math.ceil((top + vh) / TS);
    const t = game.clock.real;
    g.fillStyle = 'rgba(200,235,240,0.35)';
    for (let ty = ty0; ty <= ty1; ty += 1)
      for (let tx = tx0; tx <= tx1; tx += 1) {
        const tt = w.t(tx, ty);
        if (tt !== T.WATER && tt !== T.DEEP) continue;
        const ph = R.hash2(tx, ty, 8);
        if (ph < 0.25) {
          const o = ((t * 6 + ph * 40) % 16);
          g.fillRect(tx * TS + o, ty * TS + 4 + ph * 8, 3, 1);
        }
      }
    for (const [i] of game.env.gas) {
      const x = i % w.W, y = (i / w.W) | 0;
      if (x < tx0 - 1 || x > tx1 || y < ty0 - 1 || y > ty1) continue;
      g.fillStyle = 'rgba(40,30,20,0.45)';
      g.beginPath(); g.ellipse(x * TS + 8, y * TS + 8, 7, 4, 0, 0, 7); g.fill();
    }
    game.fx.drawDecals(g);
    // entities
    const ents = [];
    const margin = 40;
    const inView = (x, y) => x > left - margin && x < left + vw + margin && y > top - margin && y < top + vh + margin;
    for (const a of game.actors.list) if (!a.inCar && !a.insideProxy && inView(a.x, a.y)) ents.push(a);
    for (const v of game.traffic.list) if (inView(v.x, v.y)) ents.push(v);
    if (!pl.inCar && !pl.inside && !pl.deadHidden) ents.push(pl);
    ents.sort((a, b) => (a.kind === 'v' ? a.y - 4 : a.y) - (b.kind === 'v' ? b.y - 4 : b.y));
    // dead bodies first (they lie on the ground)
    for (const e of ents) if (e.dead && e.kind === 'h') A.drawPerson(g, e.x, e.y, e.dir, 0, e.look, { down: true });
    for (const e of ents) if (e.dead && e.kind === 'a') A.drawAnimal(g, e);
    // focus ring
    const f = pl.focus;
    if (f && !f.dead && !pl.inCar) {
      g.strokeStyle = f.hostile && f.state === 'fight' ? '#c8321e' : '#e4a92a';
      g.lineWidth = 1;
      g.beginPath(); g.ellipse(f.x, f.y + 1, 7, 3, 0, 0, 7); g.stroke();
    }
    for (const e of ents) {
      if (e.dead && e.kind !== 'v') continue;
      if (e.kind === 'v') A.drawCar(g, e);
      else if (e.kind === 'a') A.drawAnimal(g, e);
      else if (e === pl) this.drawPlayer(g, pl);
      else this.drawHuman(g, e);
    }
    // projectiles
    for (const p of R.combat.projectiles) {
      g.fillStyle = p.id === 'molotov' ? '#6aa060' : '#c83a1a';
      g.fillRect(p.x - 1.5, p.y - 2, 3, 4);
      if (p.id === 'molotov' || p.landed) { g.fillStyle = '#ffd040'; g.fillRect(p.x - 1, p.y - 4, 2, 2); }
    }
    // fire
    for (const fr of game.env.fires.values()) {
      if (fr.x < tx0 - 1 || fr.x > tx1 + 1 || fr.y < ty0 - 1 || fr.y > ty1 + 1) continue;
      this.drawFire(g, fr, t);
    }
    game.fx.draw(g);
    // job target marker above head
    const m = game.jobs.marker();
    if (m && inView(m.x, m.y)) {
      const bob = Math.sin(t * 4) * 2;
      g.fillStyle = '#e4a92a'; g.strokeStyle = '#1b1410'; g.lineWidth = 1;
      g.beginPath(); g.moveTo(m.x, m.y - 22 + bob); g.lineTo(m.x - 4, m.y - 30 + bob); g.lineTo(m.x + 4, m.y - 30 + bob); g.closePath(); g.fill(); g.stroke();
    }
    // weather + lighting in screen space
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    this.drawLighting(g, left, top, z);
    this.drawWeather(g);
    this.drawBubbles(g, left, top, z);
    if (game.env.lightning > 0.6) { g.fillStyle = `rgba(230,235,255,${(game.env.lightning - 0.6) * 1.2})`; g.fillRect(0, 0, cam.vw, cam.vh); }
    if (pl.coolOn) {
      g.fillStyle = 'rgba(40,120,120,0.16)';
      g.fillRect(0, 0, cam.vw, cam.vh);
    }
    if (pl.drunk > 0.3) {
      g.fillStyle = `rgba(200,120,40,${pl.drunk * 0.08})`;
      g.fillRect(0, 0, cam.vw, cam.vh);
    }
    // vignette
    const vg = g.createRadialGradient(cam.vw / 2, cam.vh / 2, Math.min(cam.vw, cam.vh) * 0.35, cam.vw / 2, cam.vh / 2, Math.max(cam.vw, cam.vh) * 0.75);
    vg.addColorStop(0, 'rgba(0,0,0,0)');
    vg.addColorStop(1, 'rgba(20,8,0,0.45)');
    g.fillStyle = vg;
    g.fillRect(0, 0, cam.vw, cam.vh);
  };

  P.drawHuman = function (g, h) {
    const st = { weapon: h.drawn || h.state === 'fight' ? h.weapon : null, down: h.down > 0 };
    let walk = h.walk;
    if (h.state === 'perform') walk = Math.sin(h.walk * 3) * 2 + h.walk;
    if (h.state === 'cower' || h.state === 'surrender') {
      // crouch with hands up
      A.drawPerson(g, h.x, h.y + 2, h.dir, 0, h.look, st);
      g.fillStyle = h.look.skin;
      g.fillRect(h.x - 5, h.y - 22, 2, 4);
      g.fillRect(h.x + 3, h.y - 22, 2, 4);
    } else A.drawPerson(g, h.x, h.y, h.dir, walk, h.look, st);
    if (h.state === 'work' && h.tag === 'worker') { g.fillStyle = '#e4a92a'; g.fillRect(h.x - 3, h.y - 22, 6, 2); }
  };
  P.drawPlayer = function (g, pl) {
    const w = pl.weaponOut || pl.punchT > 0 ? pl.weapon : null;
    A.drawPerson(g, pl.x, pl.y, pl.dir, pl.walk, pl.look, { weapon: w === 'gascan' ? 'bat' : w });
    if (pl.punchT > 0) {
      pl.punchT -= 1 / 60;
      g.fillStyle = pl.look.skin;
      g.fillRect(pl.x + Math.cos(pl.ang) * 9 - 1.5, pl.y - 12 + Math.sin(pl.ang) * 5, 3, 3);
    }
  };

  P.drawFire = function (g, fr, t) {
    const x = fr.x * TS + 8, y = fr.y * TS + 12;
    const n = 3;
    for (let k = 0; k < n; k++) {
      const ph = t * 9 + k * 2.1 + fr.x * 3.3 + fr.y;
      const hgt = (6 + Math.sin(ph) * 3 + k * 2) * (0.5 + fr.i * 0.6);
      const ox = (k - 1) * 4 + Math.sin(ph * 1.3) * 1.5;
      g.fillStyle = k === 1 ? '#ffd040' : '#ff7a20';
      g.beginPath();
      g.moveTo(x + ox - 3, y);
      g.lineTo(x + ox, y - hgt);
      g.lineTo(x + ox + 3, y);
      g.fill();
    }
    if (R.rng() < 0.04) this.game.fx.smoke(x, y - 10, true);
  };

  // ------------------------------------------------ lighting
  P.drawLighting = function (g, left, top, z) {
    const game = this.game, cam = game.cam, w = game.world, pl = game.player;
    const dark = game.clock.darkness();
    const gold = game.clock.golden();
    const we = game.env.weather;
    // daytime grade: warm film look, overcast desaturation, heat shimmer
    if (gold > 0.02) {
      g.fillStyle = `rgba(230,110,30,${gold * 0.16})`;
      g.fillRect(0, 0, cam.vw, cam.vh);
    }
    const overcast = we.cloud * 0.18 + we.rain * 0.12;
    if (overcast > 0.02) { g.fillStyle = `rgba(40,50,70,${overcast})`; g.fillRect(0, 0, cam.vw, cam.vh); }
    if (we.heat > 0.1) { g.fillStyle = `rgba(255,200,120,${we.heat * 0.08})`; g.fillRect(0, 0, cam.vw, cam.vh); }
    if (dark < 0.05) return;
    const lg = this.lg, LW = this.light.width, LH = this.light.height;
    const k = LW / cam.vw; // light canvas scale
    const toL = (x, y) => [(x - left) * z * k, (y - top) * z * k];
    lg.globalCompositeOperation = 'source-over';
    lg.fillStyle = `rgba(12,10,32,${dark})`;
    lg.clearRect(0, 0, LW, LH);
    lg.fillRect(0, 0, LW, LH);
    lg.globalCompositeOperation = 'destination-out';
    const hole = (x, y, r, a) => {
      const [lx, ly] = toL(x, y);
      const rr = r * z * k;
      if (!(rr > 0.5) || !(a > 0)) return;
      if (lx < -rr || ly < -rr || lx > LW + rr || ly > LH + rr) return;
      const gr = lg.createRadialGradient(lx, ly, 0, lx, ly, rr);
      gr.addColorStop(0, `rgba(0,0,0,${a})`);
      gr.addColorStop(1, 'rgba(0,0,0,0)');
      lg.fillStyle = gr;
      lg.beginPath(); lg.arc(lx, ly, rr, 0, 7); lg.fill();
    };
    const glows = [];
    const vw = cam.vw / z, vh = cam.vh / z;
    const tx0 = Math.floor(left / TS) - 3, ty0 = Math.floor(top / TS) - 3, tx1 = Math.ceil((left + vw) / TS) + 3, ty1 = Math.ceil((top + vh) / TS) + 3;
    const t = game.clock.real;
    for (let ty = ty0; ty <= ty1; ty++)
      for (let tx = tx0; tx <= tx1; tx++) {
        if (w.o(tx, ty) !== O.LAMP) continue;
        const flick = R.hash2(tx, ty, 2) < 0.06 ? (Math.sin(t * 20 + tx) > 0.3 ? 1 : 0.3) : 1;
        hole(tx * TS + 8, ty * TS + 6, 58, 0.9 * flick);
        glows.push([tx * TS + 8, ty * TS + 3, 22, 'rgba(255,200,110,0.22)']);
      }
    // lit windows & neon
    for (const b of w.buildings) {
      if (!b || b.destroyed) continue;
      if (b.x + b.w < tx0 || b.x > tx1 || b.y + b.h < ty0 || b.y > ty1) continue;
      const bt = D.btypes[b.type];
      const fy = (b.y + b.h) * TS - 4;
      const lit = b.occ > 0 || (bt.hours && game.ui.isOpen(b));
      if (lit) {
        for (let wx = 3; wx < b.w * TS - 4; wx += 6) if (R.hash2(b.id, wx, 3) < 0.7) hole(b.x * TS + wx + 1, fy, 10, 0.8);
        hole((b.door.x + 0.5) * TS, (b.door.y + (b.face === 'N' ? 0 : 1)) * TS, 26, 0.7);
      }
      if (bt.neon) {
        const pulse = 0.75 + Math.sin(t * 3 + b.id) * 0.25;
        hole((b.x + b.w / 2) * TS, b.y * TS + 8, 60, 0.8 * pulse);
        glows.push([(b.x + b.w / 2) * TS, b.y * TS + 8, 40, `rgba(255,70,190,${0.22 * pulse})`]);
      }
    }
    // headlights
    for (const v of game.traffic.list) {
      if (!v.lights || v.wrecked || !cam.onScreen(v.x, v.y, 120)) continue;
      const ca = Math.cos(v.angle), sa = Math.sin(v.angle);
      for (let d = 18; d <= 70; d += 18) hole(v.x + ca * d, v.y + sa * d, 12 + d * 0.35, 0.55);
      if (v.siren) {
        const on = (performance.now() / 150) % 2 < 1;
        glows.push([v.x, v.y, 40, on ? 'rgba(255,40,40,0.35)' : 'rgba(40,80,255,0.35)']);
        hole(v.x, v.y, 40, 0.5);
      }
      glows.push([v.x - ca * v.model.w * 0.5, v.y - sa * v.model.w * 0.5, 8, 'rgba(255,40,20,0.3)']);
    }
    // fire, flashes, the player
    for (const fr of game.env.fires.values()) {
      if (fr.x < tx0 || fr.x > tx1 || fr.y < ty0 || fr.y > ty1) continue;
      hole(fr.x * TS + 8, fr.y * TS + 8, 44 * fr.i, 0.95);
      glows.push([fr.x * TS + 8, fr.y * TS + 6, 26 * fr.i, 'rgba(255,140,40,0.2)']);
    }
    for (const f of game.fx.flashes) hole(f.x, f.y, f.big ? f.big * 3 : 40, 1);
    hole(pl.x, pl.y - 8, 34, 0.55);
    lg.globalCompositeOperation = 'source-over';
    g.imageSmoothingEnabled = true;
    g.drawImage(this.light, 0, 0, cam.vw, cam.vh);
    // additive glows
    g.globalCompositeOperation = 'lighter';
    for (const [x, y, r, c] of glows) {
      const sx = (x - left) * z, sy = (y - top) * z, sr = r * z;
      if (sx < -sr || sy < -sr || sx > cam.vw + sr || sy > cam.vh + sr) continue;
      if (!(sr > 0.5)) continue;
      const gr = g.createRadialGradient(sx, sy, 0, sx, sy, sr);
      gr.addColorStop(0, c);
      gr.addColorStop(1, 'rgba(0,0,0,0)');
      g.fillStyle = gr;
      g.beginPath(); g.arc(sx, sy, sr, 0, 7); g.fill();
    }
    g.globalCompositeOperation = 'source-over';
  };

  P.drawWeather = function (g) {
    const game = this.game, cam = game.cam, we = game.env.weather;
    if (we.rain > 0.05) {
      const n = Math.floor(this.rainDrops.length * Math.min(1, we.rain));
      const t = game.clock.real;
      const snow = we.snow;
      g.strokeStyle = snow ? 'rgba(240,244,250,0.85)' : 'rgba(190,210,230,0.45)';
      g.fillStyle = 'rgba(240,244,250,0.85)';
      g.lineWidth = 1;
      const wx = we.wind.x * 60;
      g.beginPath();
      for (let i = 0; i < n; i++) {
        const d = this.rainDrops[i];
        const speed = snow ? 40 : 700;
        const x = ((d.x * cam.vw + wx * t * (snow ? 0.5 : 1) + Math.sin(t + i) * (snow ? 12 : 0)) % cam.vw + cam.vw) % cam.vw;
        const y = ((d.y * cam.vh + t * speed * d.s) % cam.vh + cam.vh) % cam.vh;
        if (snow) g.rect(x, y, 2, 2);
        else { g.moveTo(x, y); g.lineTo(x + wx * 0.02 - 2, y + 12 * d.s); }
      }
      if (snow) g.fill(); else g.stroke();
    }
    if (we.fog > 0.05) {
      const t = game.clock.real;
      g.fillStyle = `rgba(200,200,190,${we.fog * 0.45})`;
      g.fillRect(0, 0, cam.vw, cam.vh);
      for (let i = 0; i < 4; i++) {
        const x = ((t * 8 + i * 300) % (cam.vw + 400)) - 200;
        const gr = g.createRadialGradient(x, cam.vh * (0.2 + i * 0.2), 0, x, cam.vh * (0.2 + i * 0.2), 220);
        gr.addColorStop(0, `rgba(220,220,210,${we.fog * 0.25})`);
        gr.addColorStop(1, 'rgba(220,220,210,0)');
        g.fillStyle = gr;
        g.fillRect(0, 0, cam.vw, cam.vh);
      }
    }
  };

  P.drawBubbles = function (g, left, top, z) {
    const game = this.game, cam = game.cam;
    g.textAlign = 'center';
    g.textBaseline = 'alphabetic';
    const list = game.actors.list.filter((a) => (a.bubble || a.alert) && !a.dead && !a.inCar && cam.onScreen(a.x, a.y, 10));
    const pl = game.player;
    if (pl.bubble && !pl.inCar) list.push(pl);
    for (const a of list) {
      const sx = (a.x - left) * z, sy = (a.y - top) * z - 22 * z - 6;
      if (a.alert) {
        g.font = 'bold 18px "Barlow Condensed", sans-serif';
        g.fillStyle = '#1b1410';
        const icon = a.alert === 'thief' ? '$' : '!';
        g.beginPath(); g.arc(sx, sy - 6, 9, 0, 7); g.fill();
        g.fillStyle = a.alert === 'thief' ? '#9ad070' : '#e4a92a';
        g.fillText(icon, sx, sy);
      }
      if (!a.bubble) continue;
      const text = a.bubble.text;
      g.font = '600 14px "Barlow Condensed", "Arial Narrow", sans-serif';
      const maxW = Math.min(200, cam.vw * 0.55);
      const words = text.split(' ');
      const lines = [];
      let cur = '';
      for (const wd of words) {
        const test = cur ? cur + ' ' + wd : wd;
        if (g.measureText(test).width > maxW && cur) { lines.push(cur); cur = wd; }
        else cur = test;
      }
      if (cur) lines.push(cur);
      const lh = 16;
      const bw = Math.max(...lines.map((l) => g.measureText(l).width)) + 14;
      const bh = lines.length * lh + 8;
      let bx = R.clamp(sx - bw / 2, 6, cam.vw - bw - 6);
      const by = sy - bh - (a.alert ? 16 : 4);
      const alpha = Math.min(1, a.bubble.t * 2);
      g.globalAlpha = alpha;
      g.fillStyle = a === pl ? '#e4a92a' : '#f2e2c0';
      g.strokeStyle = '#1b1410';
      g.lineWidth = 2;
      this.roundRect(g, bx, by, bw, bh, 7);
      g.fill(); g.stroke();
      g.beginPath(); g.moveTo(R.clamp(sx, bx + 8, bx + bw - 8) - 4, by + bh); g.lineTo(R.clamp(sx, bx + 8, bx + bw - 8), by + bh + 6); g.lineTo(R.clamp(sx, bx + 8, bx + bw - 8) + 4, by + bh); g.fill();
      g.fillStyle = '#1b1410';
      lines.forEach((l, i) => g.fillText(l, bx + bw / 2, by + 4 + (i + 1) * lh - 3));
      g.globalAlpha = 1;
    }
  };
  P.roundRect = function (g, x, y, w, h, r) {
    g.beginPath();
    g.moveTo(x + r, y);
    g.arcTo(x + w, y, x + w, y + h, r);
    g.arcTo(x + w, y + h, x, y + h, r);
    g.arcTo(x, y + h, x, y, r);
    g.arcTo(x, y, x + w, y, r);
    g.closePath();
  };
})();
