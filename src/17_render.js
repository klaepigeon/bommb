// RHAPSODY — renderer: chunked world, y-sorted entities, fire, weather, night
// lighting (lamps, headlights, neon, windows), speech bubbles and markers.
'use strict';
(function () {
  const D = R.data, T = D.T, O = D.O, TS = R.TILE;
  const A = R.art;

  // The game renders into a fixed 480x320 buffer (a 240x160 GBA view at 2x, like the
  // original) which is then scaled onto the on-screen canvas with nearest-neighbour.
  const BW = 480, BH = 320;
  const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];
  const Renderer = (R.Renderer = function (game, canvas) {
    this.game = game;
    this.display = canvas;
    this.dg = canvas.getContext('2d', { alpha: false });
    this.cv = document.createElement('canvas');
    this.cv.width = BW;
    this.cv.height = BH;
    this.g = this.cv.getContext('2d', { alpha: false });
    this.light = document.createElement('canvas');
    this.lg = this.light.getContext('2d');
    this.dpr = 1;
    this.rainDrops = [];
    for (let i = 0; i < 160; i++) this.rainDrops.push({ x: Math.random(), y: Math.random(), s: 0.6 + Math.random() * 0.8 });
  });
  const P = Renderer.prototype;

  P.resize = function () {
    const g = this.game;
    const r = this.display.getBoundingClientRect();
    const dpr = Math.min(window.devicePixelRatio || 1, 3);
    // an integer multiple of the buffer when it fits, otherwise the nearest size
    let w = Math.max(BW, Math.round(r.width * dpr)), h = Math.round(w * BH / BW);
    const k = Math.floor(w / BW);
    if (k >= 1 && Math.abs(k * BW - w) < BW * 0.2) { w = k * BW; h = k * BH; }
    this.display.width = w;
    this.display.height = h;
    this.dpr = 1;
    this.light.width = BW / 2;
    this.light.height = BH / 2;
    g.cam.vw = BW;
    g.cam.vh = BH;
    this.baseZoom = 2 * g.settings.zoom;
    g.cam.zoom = this.baseZoom;
  };
  P.present = function () {
    const dg = this.dg;
    dg.imageSmoothingEnabled = false;
    dg.drawImage(this.cv, 0, 0, this.display.width, this.display.height);
  };

  P.render = function () {
    const game = this.game, g = this.g, cam = game.cam, w = game.world, pl = game.player;
    const dpr = this.dpr;
    // zoom out with speed
    const sp = pl.inCar ? Math.abs(pl.inCar.speed) : 0;
    const targetZoom = this.baseZoom * (pl.inCar ? R.clamp(1 - sp / 500, 0.72, 0.9) : 1);
    cam.zoom += (targetZoom - cam.zoom) * 0.05;
    const z = cam.zoom;
    const left = cam.left() + cam.ox, top = cam.top() + cam.oy;
    const vw = cam.vw / z, vh = cam.vh / z;
    g.setTransform(1, 0, 0, 1, 0, 0);
    g.imageSmoothingEnabled = false;
    g.fillStyle = pl.room ? '#140c0a' : '#1f5566';
    g.fillRect(0, 0, this.cv.width, this.cv.height);
    const sc = dpr * z;
    g.setTransform(sc, 0, 0, sc, Math.round(-left * sc), Math.round(-top * sc));
    // chunks
    const CPX = A.CH * TS;
    const cx0 = Math.max(0, Math.floor(left / CPX)), cy0 = Math.max(0, Math.floor(top / CPX));
    const cx1 = Math.min(Math.floor(w.W / A.CH) - 1, Math.floor((left + vw) / CPX)), cy1 = Math.min(Math.floor(w.TH / A.CH) - 1, Math.floor((top + vh) / CPX));
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
    R.route.drawWorld(g, game, left, top, vw, vh);
    R.gore.draw(g);
    R.heist.draw(g);
    R.poi.drawSigns(g, left, top, vw, vh, t);
    R.props.drawGround(g, (x, y) => x > left - 40 && x < left + vw + 40 && y > top - 40 && y < top + vh + 40);
    // entities
    const ents = [];
    const margin = 40;
    const inView = (x, y) => x > left - margin && x < left + vw + margin && y > top - margin && y < top + vh + margin;
    for (const a of game.actors.list) if (!a.inCar && !a.insideProxy && inView(a.x, a.y)) ents.push(a);
    for (const v of game.traffic.list) if (inView(v.x, v.y)) ents.push(v);
    if (!pl.inCar && !pl.inside && !pl.deadHidden) ents.push(pl);
    ents.sort((a, b) => (a.kind === 'v' ? a.y - 4 : a.y) - (b.kind === 'v' ? b.y - 4 : b.y));
    // dead bodies first (they lie on the ground)
    for (const e of ents) if (e.dead && e.kind === 'h' && !e.gibbed) { if (e.hidden) R.bodies.drawHidden(g, e); else A.drawPerson(g, e.x, e.y, e.dir, 0, e.look, { down: true }); }
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
    R.props.drawFlying(g);
    // fire: char burning buildings, flames out of the front windows as it takes hold
    for (const b of w.buildings) {
      if (!b || !b.burning || b.destroyed) continue;
      if (b.x + b.w < tx0 - 1 || b.x > tx1 + 1 || b.y + b.h < ty0 - 1 || b.y > ty1 + 2) continue;
      const lvl = 1 - b.hp / 100;
      const a = Math.min(0.62, lvl * 0.7 + 0.12);
      g.fillStyle = `rgba(22,10,6,${a})`;
      g.fillRect(b.x * TS - 2, b.y * TS - 6, b.w * TS + 4, b.h * TS + 6);
      g.fillStyle = `rgba(10,6,4,${a * 0.8})`;
      for (let k = 0; k < b.w; k++) if (R.hash2(b.id, k, 9) < 0.5) g.fillRect(b.x * TS + k * TS + 5, (b.y + b.h) * TS - 24, 3, 20);
      for (let k = 0; k < b.w; k++) if (R.hash2(b.id, k, 11) < 0.25 + lvl * 1.2) this.drawFire(g, { x: b.x + k, y: b.y + b.h - 1, i: 0.6 + lvl * 0.4, facade: true }, t);
    }
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
    // hard light and alien light glow through the dark
    g.setTransform(sc, 0, 0, sc, Math.round(-left * sc), Math.round(-top * sc));
    R.ring.draw(g);
    R.legends.draw(g);
    R.fearQuest.draw(g);
    R.campaign.draw(g);
    if (R.ring.fearMan && R.ring.fearMan.x) { const fm = R.ring.fearMan; g.fillStyle = 'rgba(255,226,60,' + (0.25 + Math.sin(t * 3) * 0.1) + ')'; g.fillRect(Math.round(fm.x + 4), Math.round(fm.y - 12), 2, 2); }
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    R.goods.overlay(g, cam.vw, cam.vh, t);
    if (!pl.room) this.drawWeather(g);
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
    g.setTransform(1, 0, 0, 1, 0, 0);
    game.ui.drawHud(g);
    this.present();
  };

  P.drawHuman = function (g, h) {
    // test-room mannequins hold a fixed pose
    if (h.testPose && !h.dead && h.state !== 'fight') {
      const tp = h.testPose, isW = tp.weapon && D.weapons[tp.weapon];
      return A.drawPerson(g, h.x, h.y, h.dir, 0, h.look, { weapon: isW ? tp.weapon : null, held: tp.held || null, pose: tp.pose || null, ang: tp.ang });
    }
    // made men favour a fedora
    if (h.look.hatKind === undefined) h.look.hatKind = h.faction && h.faction !== 'law' && (R.hash2(h.x | 0, h.y | 0, 3) < 0.55) ? R.rng.pick(['fedora', 'fedora', 'trilby', 'porkpie']) : null;
    const st = { weapon: h.drawn || h.state === 'fight' ? h.weapon : null, down: h.down > 0 || h.state === 'sleep', scale: h.scale, alpha: h.ghost ? 0.4 + Math.sin(this.game.clock.real * 3) * 0.15 : null };
    if (h.state === 'sleep') {
      A.drawPerson(g, h.x + 4, h.y + 4, 2, 0, h.look, st);
      if (Math.floor(this.game.clock.real * 1.5) % 2 === 0) A.ptext(g, 'z', h.x + 6, h.y - 18, { color: '#f6ecd0', shadow: '#2a1a12' });
      return;
    }
    if (h.state === 'fight' || h.state === 'travel' || h.state === 'flee' || h.state === 'report') st.ang = h.ang;
    if (h.state === 'cower' || h.state === 'surrender') st.pose = 'h';
    else if (h.swingT > 0 && h.state === 'fight') {
      // wind up, then follow through
      const sw = 1 - h.swingT / 0.22;
      if (h.weapon === 'bat') { st.pose = sw < 0.45 ? 'b1' : 'b2'; st.weapon = null; }
      else if (h.weapon === 'knife') { st.pose = sw < 0.45 ? 'w1' : 'w2'; st.weapon = null; st.held = 'knife'; }
      else { st.pose = h.swingN % 2 ? 'p2' : 'p1'; st.weapon = null; }
    }
    if (st.down) { st.weapon = null; st.pose = null; }
    let walk = h.walk;
    if (h.state === 'perform') walk = Math.sin(h.walk * 3) * 2 + h.walk;
    A.drawPerson(g, h.x, h.y, h.dir, walk, h.look, st);
  };
  P.drawPlayer = function (g, pl) {
    const w = pl.weaponOut || pl.punchT > 0 ? pl.weapon : null;
    const st = { weapon: w === 'gascan' ? null : w, ang: pl.ang };
    if (w === 'gascan') st.held = 'gascan';
    const swing = pl.punchT > 0 ? 1 - pl.punchT / 0.22 : -1; // 0..1 through the blow
    if (pl.held) {
      // an improvised weapon, held at its grip; swung through the original's arcs
      st.weapon = null;
      st.held = pl.held.k;
      if (swing >= 0) st.pose = A.itemArt(pl.held.k) && A.itemArt(pl.held.k).grip ? (swing < 0.45 ? 'w1' : 'w2') : 'h';
    } else if (swing >= 0) {
      if (pl.weapon === 'bat') { st.pose = swing < 0.45 ? 'b1' : 'b2'; st.weapon = null; }
      else if (pl.weapon === 'knife') { st.pose = swing < 0.45 ? 'w1' : 'w2'; st.weapon = null; st.held = 'knife'; }
      else if (pl.weapon === 'fists' || pl.weapon === 'knuckles' || !D.weapons[pl.weapon] || !D.weapons[pl.weapon].gun) st.pose = (pl.punchN || 0) % 2 ? 'p2' : 'p1';
      if (pl.weapon === 'fists' || pl.weapon === 'knuckles') st.weapon = null;
    }
    pl._pose = st.pose || (st.held ? 'k' : null);
    if (pl.sneak && !pl.inCar && !pl.held && !(swing >= 0)) { A.drawDisguise(g, pl, pl.disguise || 'box'); pl._pose = 'hidden'; return; }
    A.drawPerson(g, pl.x, pl.y, pl.dir, pl.walk, pl.look, st);
    R.bodies.drawCarried(g, pl);
    R.ring.drawSwing(g, pl);
  };

  // pixel flames: tongues built from one-pixel rows in a five-tone ramp, swaying and
  // licking upward; buildings burn taller and smoke black, and embers drift off
  const FLAME = ['#fff6c0', '#ffc838', '#f87818', '#c82c0c', '#5a140a'];
  P.drawFire = function (g, fr, t) {
    const w = this.game.world;
    const onB = !!w.bid[w.idx(fr.x, fr.y)];
    const x = fr.x * TS + 8, y = fr.y * TS + (fr.facade ? 4 : onB ? 10 : 13);
    const n = onB ? 4 : 3, big = onB ? 1.9 : 1;
    for (let k = 0; k < n; k++) {
      const ph = t * 8 + k * 2.3 + fr.x * 3.3 + fr.y * 1.7;
      const hgt = Math.max(3, Math.round((7 + Math.sin(ph) * 3 + (k % 2) * 3) * (0.45 + fr.i * 0.65) * big));
      const bx = x + Math.round((k - (n - 1) / 2) * 4);
      for (let yy = 0; yy < hgt; yy++) {
        const f = yy / hgt;
        const wd = f < 0.3 ? 4 : f < 0.6 ? 3 : f < 0.85 ? 2 : 1;
        const sway = Math.round(Math.sin(ph * 1.4 + yy * 0.35) * f * 2);
        g.fillStyle = f < 0.18 ? FLAME[0] : f < 0.42 ? FLAME[1] : f < 0.68 ? FLAME[2] : f < 0.88 ? FLAME[3] : FLAME[4];
        g.fillRect(bx - (wd >> 1) + sway, y - yy, wd, 1);
      }
    }
    const fx = this.game.fx;
    if (R.rng() < (onB ? 0.12 : 0.04)) fx.smoke(x + (R.rng() - 0.5) * 8, y - 12 * big, true);
    if (R.rng() < 0.08) fx.add({ x: x + (R.rng() - 0.5) * 10, y: y - 6 * big, vx: (R.rng() - 0.5) * 16, vy: -28 - R.rng() * 30, life: 0.9, max: 0.9, c: R.rng() < 0.5 ? '#ffc838' : '#f87818', s: 1, glow: 1 });
  };

  // ------------------------------------------------ lighting
  P.drawLighting = function (g, left, top, z) {
    const game = this.game, cam = game.cam, w = game.world, pl = game.player;
    const room = pl.room;
    const dark = room ? 0.28 + game.clock.darkness() * 0.25 : game.clock.darkness();
    const gold = room ? 0 : game.clock.golden();
    const we = room ? { cloud: 0, rain: 0, heat: 0 } : game.env.weather;
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
        const ob = w.o(tx, ty);
        if (room) {
          if (ob === O.FLOORLAMP || ob === O.JUKEBOX || ob === O.SLOT || ob === O.ARCADE || ob === O.TV) {
            hole(tx * TS + 8, ty * TS + 6, ob === O.FLOORLAMP ? 60 : 30, 0.85);
            glows.push([tx * TS + 8, ty * TS + 4, 18, ob === O.FLOORLAMP ? 'rgba(255,200,110,0.22)' : ob === O.JUKEBOX ? 'rgba(255,80,160,0.25)' : 'rgba(110,200,255,0.2)']);
          } else if (w.t(tx, ty) === T.DANCE && (tx + ty + Math.floor(t * 4)) % 3 === 0) {
            hole(tx * TS + 8, ty * TS + 8, 18, 0.7);
            glows.push([tx * TS + 8, ty * TS + 8, 12, ['rgba(255,70,190,0.3)', 'rgba(240,184,56,0.3)', 'rgba(90,200,255,0.3)'][(tx + ty) % 3]]);
          }
          continue;
        }
        if (ob !== O.LAMP) continue;
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
    if (room) {
      // the room is lit from above; a soft pool of light in the middle
      hole((room.x0 + room.w / 2) * TS, (room.y0 + room.h / 2) * TS, Math.max(room.w, room.h) * TS * 0.6, 0.75);
      hole(pl.x, pl.y - 8, 50, 0.6);
    } else hole(pl.x, pl.y - 8, 34, 0.55);
    lg.globalCompositeOperation = 'source-over';
    this.dither(lg, LW, LH, dark);
    g.imageSmoothingEnabled = false;
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

  // title screen: the harbor at night, like the original's
  P.renderTitle = function (t) {
    const g = this.g;
    g.setTransform(1, 0, 0, 1, 0, 0);
    g.imageSmoothingEnabled = false;
    const bands = ['#120a26', '#1a1034', '#241640', '#2e1c4a', '#3a2254', '#4a2a5a'];
    for (let i = 0; i < bands.length; i++) { g.fillStyle = bands[i]; g.fillRect(0, i * 34, BW, 34); }
    // dithered band edges
    for (let i = 1; i < bands.length; i++) { g.fillStyle = bands[i]; for (let x = (i % 2) * 2; x < BW; x += 4) g.fillRect(x, i * 34 - 2, 2, 2); }
    const rnd = R.mulberry(7);
    for (let k = 0; k < 90; k++) {
      const x = rnd() * BW, y = rnd() * 170;
      g.fillStyle = Math.sin(t * 2 + k) > 0.6 ? '#fff6c0' : '#b8a8d8';
      g.fillRect(x | 0, y | 0, 1, 1);
    }
    // moon
    g.fillStyle = 'rgba(246,236,208,0.08)'; g.beginPath(); g.arc(70, 150, 30, 0, 7); g.fill();
    g.fillStyle = '#f6ecd0'; g.beginPath(); g.arc(70, 150, 17, 0, 7); g.fill();
    g.fillStyle = '#d8ccb0'; g.fillRect(63, 143, 5, 4); g.fillRect(74, 156, 4, 3); g.fillRect(77, 141, 3, 3);
    // lighthouse beam
    const la = Math.sin(t * 0.8) * 0.6 - 1.2;
    g.fillStyle = 'rgba(246,236,208,0.12)';
    g.beginPath(); g.moveTo(420, 128); g.lineTo(420 + Math.cos(la - 0.08) * 400, 128 + Math.sin(la - 0.08) * 400); g.lineTo(420 + Math.cos(la + 0.08) * 400, 128 + Math.sin(la + 0.08) * 400); g.closePath(); g.fill();
    // skyline
    const sk = R.mulberry(11);
    let x = 0;
    while (x < BW) {
      const w = 24 + (sk() * 34) | 0, h = 40 + (sk() * 80) | 0;
      if (x > 400 && x < 440) { x += 44; continue; }
      g.fillStyle = '#0e0818';
      g.fillRect(x, 215 - h, w - 2, h);
      for (let wy = 215 - h + 6; wy < 210; wy += 7) for (let wx = x + 3; wx < x + w - 5; wx += 5) {
        if (sk() < 0.35) { g.fillStyle = sk() < 0.8 ? '#f0c848' : '#8ab8e8'; g.fillRect(wx, wy, 2, 3); }
      }
      x += w;
    }
    // lighthouse
    for (let y = 128; y < 215; y += 10) { g.fillStyle = (y / 10) % 2 ? '#c83a2a' : '#f6ecd0'; g.fillRect(412, y, 16, 10); }
    g.fillStyle = '#f6ecd0'; g.fillRect(410, 118, 20, 10); g.fillStyle = '#fff6a0'; g.fillRect(414, 120, 12, 6);
    // water
    g.fillStyle = '#12183a'; g.fillRect(0, 215, BW, BH - 215);
    for (let k = 0; k < 60; k++) {
      const wx = (rnd() * BW + t * 6 * (k % 3 + 1)) % BW, wy = 220 + rnd() * 100;
      g.fillStyle = k % 3 ? '#243a6a' : '#3a5a9a'; g.fillRect(wx | 0, wy | 0, 6 + (k % 4) * 3, 1);
    }
    for (let y = 222; y < BH; y += 5) { g.fillStyle = 'rgba(246,236,208,0.5)'; const w2 = 8 + Math.sin(t * 3 + y) * 3; g.fillRect(420 - w2 / 2, y, w2, 1); }
    // pier
    g.fillStyle = '#0a0610'; g.fillRect(0, 262, 190, 5);
    for (let px = 6; px < 190; px += 24) g.fillRect(px, 262, 4, 60);
    g.fillRect(122, 240, 3, 22); g.fillStyle = '#f0c848'; g.fillRect(120, 238, 7, 3);
    // title
    A.ptext(g, 'RHAPSODY', BW / 2 + 4, 44 + 4, { align: 'center', scale: 5, color: '#2a1a12' });
    A.ptext(g, 'RHAPSODY', BW / 2 + 2, 44 + 2, { align: 'center', scale: 5, color: '#c83a2a' });
    A.ptext(g, 'RHAPSODY', BW / 2, 44, { align: 'center', scale: 5, color: '#f0b838' });
    A.ptext(g, 'THE BRASS COAST - 2026', BW / 2, 104, { align: 'center', scale: 2, color: '#f6ecd0', shadow: '#2a1a12' });
    A.ptext(g, 'THE SEVENTIES NEVER ENDED', BW / 2, 126, { align: 'center', scale: 1, color: '#b8a8d8' });
    this.present();
  };

  // ordered (Bayer) dithering of the darkness, like the original
  P.dither = function (lg, W, H, dmax) {
    const img = lg.getImageData(0, 0, W, H);
    const d = img.data;
    const top = Math.max(0.05, dmax) * 255;
    for (let y = 0; y < H; y++)
      for (let x = 0; x < W; x++) {
        const i = (y * W + x) * 4 + 3;
        const a = d[i] / top;
        // eight bands: still reads as retro banding, but neighbouring pixels only
        // differ by an eighth, so the pattern stops looking like a checkerboard
        const lv = a * 8;
        const base = Math.floor(lv);
        const frac = lv - base;
        d[i] = (Math.min(8, base + (frac > BAYER[(y & 3) * 4 + (x & 3)] / 16 ? 1 : 0)) / 8) * top;
      }
    lg.putImageData(img, 0, 0);
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

  // speech bubbles, alerts and the original's "[A] action" tags, in pixel fonts
  P.tag = function (g, sx, sy, label, key) {
    const tw = A.ptWidth(label);
    const w = tw + (key ? 17 : 8), h = 13;
    const x = Math.round(R.clamp(sx - w / 2, 2, this.cv.width - w - 2)), y = Math.round(sy - h);
    g.fillStyle = '#2a1a12'; g.fillRect(x - 1, y - 1, w + 2, h + 2);
    g.fillStyle = '#f6ecd0'; g.fillRect(x, y, w, h);
    g.fillStyle = 'rgba(20,12,10,0.35)'; g.fillRect(x, y + h + 1, w + 1, 1);
    let tx = x + 4;
    if (key) {
      g.fillStyle = '#c83a2a'; g.fillRect(x + 2, y + 2, 10, 9);
      A.ptext(g, key, x + 7, y + 2, { align: 'center', color: '#f6ecd0' });
      tx = x + 14;
    }
    A.ptext(g, label, tx, y + 2, { color: '#3a2418' });
    g.fillStyle = '#2a1a12'; g.fillRect(Math.round(sx) - 2, y + h + 1, 5, 1); g.fillRect(Math.round(sx) - 1, y + h + 2, 3, 1);
  };
  const wrap = (text, maxW) => {
    const words = String(text).split(' ');
    const lines = [];
    let cur = '';
    for (const wd of words) {
      const test = cur ? cur + ' ' + wd : wd;
      if (A.ptWidth(test) > maxW && cur) { lines.push(cur); cur = wd; }
      else cur = test;
    }
    if (cur) lines.push(cur);
    return lines;
  };
  P.wrap = wrap;
  P.drawBubbles = function (g, left, top, z) {
    const game = this.game, cam = game.cam;
    const list = game.actors.list.filter((a) => (a.bubble || a.alert) && !a.dead && !a.inCar && cam.onScreen(a.x, a.y, 10));
    const pl = game.player;
    if (pl.bubble && !pl.inCar) list.push(pl);
    const toS = (x, y) => [(x - left) * z, (y - top) * z];
    if (!pl.inCar && !pl.dead && !game.ui.sheetOpen) {
      const act = pl.contextAction();
      const f = pl.focus;
      if (f && !f.dead && !pl.bubble) { const [fx, fy] = toS(f.x, f.y - 27); this.tag(g, fx, fy, game.actors.displayName(f).slice(0, 22), game.input.lastTouch ? null : 'T'); }
      if (act && !(f && !f.dead)) { const [px, py] = toS(pl.x, pl.y - 29); this.tag(g, px, py, act.label.slice(0, 24), 'A'); }
    }
    for (const a of list) {
      const [sx, sy0] = toS(a.x, a.y);
      const sy = sy0 - 27 * z;
      if (a.alert) {
        const icon = a.alert === 'thief' ? '$' : '!';
        g.fillStyle = '#2a1a12'; g.fillRect(Math.round(sx) - 6, Math.round(sy) - 16, 13, 15);
        g.fillStyle = a.alert === 'thief' ? '#6a9a30' : '#f0b838'; g.fillRect(Math.round(sx) - 5, Math.round(sy) - 15, 11, 13);
        A.ptext(g, icon, sx + 0.5, sy - 13, { align: 'center', color: '#2a1a12' });
      }
      if (!a.bubble) continue;
      const lines = wrap(a.bubble.text.toUpperCase(), 150);
      const lh = 10;
      const bw = Math.max(...lines.map((l) => A.ptWidth(l))) + 10;
      const bh = lines.length * lh + 5;
      const bx = Math.round(R.clamp(sx - bw / 2, 3, cam.vw - bw - 3));
      const by = Math.round(sy - bh - (a.alert ? 20 : 6));
      const fill = a === pl ? '#f0b838' : '#f6ecd0';
      g.fillStyle = '#2a1a12'; g.fillRect(bx - 2, by - 2, bw + 4, bh + 4);
      g.fillStyle = fill; g.fillRect(bx, by, bw, bh);
      const tx = Math.round(R.clamp(sx, bx + 6, bx + bw - 6));
      g.fillStyle = '#2a1a12'; g.fillRect(tx - 3, by + bh + 2, 6, 2); g.fillRect(tx - 1, by + bh + 4, 3, 2);
      g.fillStyle = fill; g.fillRect(tx - 2, by + bh, 4, 2);
      lines.forEach((l, i) => A.ptext(g, l, bx + bw / 2, by + 3 + i * lh, { align: 'center', color: '#3a2418' }));
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
