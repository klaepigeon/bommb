// RHAPSODY — cars that show what happened to them. Every hit leaves a dent where it
// landed; as the engine weakens the windshield cracks, a headlight dies, the hood
// crumples and the bumper hangs. Tyres leave rubber when you brake hard or throw it
// sideways, and dirt roads and desert kick up a plume behind anything moving fast.
'use strict';
(function () {
  const D = R.data, T = D.T, TS = R.TILE;
  const G = () => R.game;
  const CR = (R.cars = {});
  const DUSTY = new Set([T.DIRT, T.SAND, T.DESERT, T.DIRTROAD].filter((t) => t != null));

  // a dent at the point of impact, in the car's own frame
  CR.dent = function (v, px, py, force) {
    const c = Math.cos(-v.angle), s = Math.sin(-v.angle), rx = px - v.x, ry = py - v.y;
    const x = R.clamp(rx * c - ry * s, -v.model.w / 2 + 2, v.model.w / 2 - 3), y = R.clamp(rx * s + ry * c, -v.model.h / 2 + 1, v.model.h / 2 - 3);
    v.dents = v.dents || [];
    v.dents.push({ x: Math.round(x), y: Math.round(y), n: force > 80 ? 3 : force > 45 ? 2 : 1 });
    if (v.dents.length > 8) v.dents.shift();
  };

  // ---------------------------------------------------------------- drawn over the car
  CR.overlay = function (g, v) {
    const m = v.model, L = m.w, H = m.h, f = v.hp / (v.maxHp || m.hp), seed = v.id * 7919;
    if (v.wrecked) return;
    const hash = (k) => R.hash2(seed, k, 11);
    g.save();
    g.translate(Math.round(v.x), Math.round(v.y));
    g.rotate(v.angle);
    // dents where it was hit: a dark crumple and a bright scrape
    for (const d of v.dents || []) {
      g.fillStyle = 'rgba(10,8,8,0.42)'; g.fillRect(d.x, d.y, d.n > 1 ? 3 : 2, 2);
      if (d.n > 2) g.fillRect(d.x - 1, d.y + 1, 2, 2);
      g.fillStyle = 'rgba(255,250,240,0.35)'; g.fillRect(d.x + (d.n > 1 ? 3 : 2), d.y, d.n + 1, 1);
    }
    // wear from general punishment
    if (f < 0.75) { // scratches along the doors
      g.fillStyle = 'rgba(255,250,240,0.3)';
      for (let k = 0; k < 3; k++) g.fillRect(Math.round(-L / 2 + 6 + hash(k) * (L - 14)), hash(k + 5) < 0.5 ? -H / 2 + 1 : H / 2 - 2, 3 + Math.round(hash(k + 9) * 3), 1);
    }
    if (f < 0.5) { // spider-cracked windshield and one dead headlight
      const wx = Math.round(L * 0.18);
      g.fillStyle = 'rgba(240,248,255,0.75)';
      g.fillRect(wx, -1, 1, 3); g.fillRect(wx - 1, -2, 1, 1); g.fillRect(wx + 1, 1, 1, 1); g.fillRect(wx - 1, 2, 1, 1); g.fillRect(wx + 1, -3, 1, 1);
      g.fillStyle = '#1a1414'; g.fillRect(L / 2 - 2, hash(2) < 0.5 ? -H / 2 + 1 : H / 2 - 3, 2, 2);
    }
    if (f < 0.28) { // hood crumpled, bumper hanging off one corner
      g.fillStyle = 'rgba(12,10,10,0.5)';
      for (let k = 0; k < 4; k++) g.fillRect(Math.round(L / 2 - 8 + hash(k + 20) * 6), Math.round(-H / 2 + 2 + hash(k + 30) * (H - 5)), 2, 1);
      g.fillStyle = '#8a8a8a'; g.fillRect(L / 2, hash(3) < 0.5 ? -H / 2 + 1 : H / 2 - 4, 1, 3);
      g.fillStyle = 'rgba(0,0,0,0.3)'; g.fillRect(-L / 2 + 3, -H / 2 + 2, 2, H - 4); // rear glass shattered
    }
    g.restore();
  };

  // ---------------------------------------------------------------- rubber and dust
  CR.tick = function (dt) {
    const g = G(), w = g.world, pl = g.player;
    for (const v of g.traffic.list) {
      if (v.removed || v.wrecked) continue;
      if (!g.cam.onScreen(v.x, v.y, 60)) continue;
      const sp = Math.abs(v.speed || Math.hypot(v.vx || 0, v.vy || 0));
      if (sp < 25) continue;
      const c = Math.cos(v.angle), s = Math.sin(v.angle), L = v.model.w, H = v.model.h;
      const rearX = v.x - c * (L / 2 - 6), rearY = v.y - s * (L / 2 - 6);
      const side = (k) => [rearX - s * k * (H / 2 - 2), rearY + c * k * (H / 2 - 2)];
      // sideways slip: the difference between where it's pointed and where it's going
      const slip = Math.abs(-(v.vx || 0) * s + (v.vy || 0) * c);
      const skid = (v === pl.inCar && ((slip > 38 && sp > 60) || (v.braking && sp > 95))) || (v !== pl.inCar && v.mode === 'chase' && slip > 50);
      if (skid && g.settings.skids !== false) {
        for (const k of [-1, 1]) { const [x, y] = side(k); g.fx.decal({ x, y, r: 0.9, c: 'rgba(18,16,16,0.32)', t: 700 }); }
        if (R.rng() < dt * 8) g.fx.add({ x: rearX, y: rearY - 2, vx: (R.rng() - 0.5) * 12, vy: -8 - R.rng() * 6, life: 0.9, max: 0.9, c: 'rgba(200,200,200,0.35)', s: 3, grow: 4 });
      }
      // dust off dirt and sand
      const t = w.t((rearX / TS) | 0, (rearY / TS) | 0);
      if (DUSTY.has(t) && R.rng() < dt * (4 + sp / 25)) {
        const [x, y] = side(R.rng() < 0.5 ? -1 : 1);
        g.fx.add({ x, y, vx: -c * sp * 0.15 + (R.rng() - 0.5) * 16 + g.env.weather.wind.x * 12, vy: -s * sp * 0.15 - 4 - R.rng() * 6, life: 1.6, max: 1.6, c: 'rgba(236,218,178,0.6)', s: 4, grow: 10 });
      }
    }
  };

  // ---------------------------------------------------------------- drivers are people
  // They slow down to stare at a wreck, and some of them yell back when you lean on the horn.
  CR.drivers = function (dt) {
    const g = G();
    this.lookT = (this.lookT || 0) - dt;
    const scan = this.lookT <= 0;
    if (scan) this.lookT = 0.5;
    if (!scan) return;
    const wrecks = g.traffic.list.filter((v) => (v.wrecked || v.burning > 0) && !v.removed);
    if (!wrecks.length) return;
    for (const v of g.traffic.list) {
      if (v.removed || v.wrecked || !v.driver || v.driver === g.player || v.mode !== 'lane') continue;
      const wr = wrecks.find((q) => q !== v && R.dist(q.x, q.y, v.x, v.y) < TS * 5);
      if (!wr) { v.gawk = 0; continue; }
      v.gawk = 1.2; // seconds of crawling past
      if (!v.gawked && Math.random() < 0.3) { v.gawked = true; g.actors.say(v.driver, R.rng.pick(['Jesus, look at that.', 'Somebody call somebody!', 'Is he okay in there?', 'Holy moly.'])); }
    }
  };

  CR.init = function () {
    if (this.wrapped) return;
    this.wrapped = true;
    const TPx = R.Traffic.prototype, ld = TPx.laneDrive;
    TPx.laneDrive = function (v, dt) {
      if (v.gawk > 0) { v.gawk -= dt; const top = v.speed; ld.call(this, v, dt); if (v.speed > 28) v.speed = Math.max(28, top - 120 * dt); return; }
      return ld.call(this, v, dt);
    };
    const hk = TPx.honk;
    TPx.honk = function (v) {
      const r = hk.call(this, v);
      // the car in front sometimes answers
      if (v.driver === this.game.player || Math.random() < 0.25) {
        const ob = this.obstacleAhead ? this.obstacleAhead(v) : null, o = ob && ob.o;
        if (o && o.kind === 'v' && o.driver && o.driver !== this.game.player && !o.honked) { o.honked = true; setTimeout(() => { if (!o.removed && o.driver) this.game.actors.say(o.driver, R.rng.pick(['Hold your horses!', 'Honk again. I dare you.', 'It\'s RED, genius!', 'Relax, Mario Andretti.'])); o.honked = false; }, 700); }
      }
      return r;
    };
    const A = R.art, dc = A.drawCar;
    A.drawCar = function (g, v) { dc.call(this, g, v); if ((v.dents && v.dents.length) || v.hp < (v.maxHp || v.model.hp) * 0.75) CR.overlay(g, v); };
    const TP = R.Traffic.prototype, up = TP.update;
    TP.update = function (dt) { up.call(this, dt); CR.tick(dt); CR.drivers(dt); };
  };
})();
