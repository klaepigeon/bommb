// RHAPSODY — water that behaves like water. People swim chest-deep and slow, guns
// holstered; treading deep water too long wears you out. The knocked-out drown, bodies
// sink, cars bog down and go under in a stream of bubbles. And with a cinder block and
// some rope, anyone beside the water can be fitted for a pair of cement shoes.
'use strict';
(function () {
  const D = R.data, T = D.T, TS = R.TILE;
  const W = (R.water = {});
  const G = () => R.game;
  const wet = (x, y) => { const w = G().world; return w.isWater((x / TS) | 0, (y / TS) | 0); };
  const deep = (x, y) => G().world.t((x / TS) | 0, (y / TS) | 0) === T.DEEP;
  W.wet = wet;
  W.sinking = [];

  // everyone wades at half speed
  const AP = R.Actors.prototype, baseMove = AP.moveActor;
  AP.moveActor = function (a, vx, vy, dt) {
    if (a && a.kind === 'h' && !a.flying && wet(a.x, a.y)) { vx *= 0.5; vy *= 0.5; }
    return baseMove.call(this, a, vx, vy, dt);
  };

  W.update = function (dt) {
    const g = G(), pl = g.player, w = g.world;
    // the player
    const sw = !pl.inCar && !pl.room && wet(pl.x, pl.y);
    if (sw && !pl.swimming) { g.fx.splash ? g.fx.splash(pl.x, pl.y) : this.splash(pl.x, pl.y); pl.weaponOut = false; pl.sneak = false; }
    pl.swimming = sw;
    if (sw) {
      pl.weaponOut = false;
      pl.swimT = deep(pl.x, pl.y) ? (pl.swimT || 0) + dt : Math.max(0, (pl.swimT || 0) - dt * 2);
      if (pl.swimT > 45) { if (!pl.tiredWarn) { pl.tiredWarn = true; g.ui.toast('Your arms are lead. Get to shore!', 'bad'); } pl.hurt(dt * 4, null, 'drown'); }
      if (R.rng() < dt * 3) this.ripple(pl.x, pl.y);
    } else { pl.swimT = 0; pl.tiredWarn = false; }
    // people in the water
    for (const a of g.actors.list) {
      if (a.kind !== 'h' || a.inCar) continue;
      if (!wet(a.x, a.y)) continue;
      if (!a.dead && a.down > 0) {
        // out cold, face down in the water
        a.drownT = (a.drownT || 0) + dt;
        if (a.drownT > 3) { a.lastHitKind = 'drown'; R.combat.kill(a, a.lastHitBy || null, 'drown'); }
      } else if (a.dead && !a.sunk) {
        // floats a moment, clouding the water red, then settles and slides under
        if (!a.sinkT) { a.sinkT = 0; this.splash(a.x, a.y); if (g.settings.gore !== false) g.fx.decal({ x: a.x + 3, y: a.y - 2, r: 7, c: 'rgba(120,22,18,0.28)', t: 900 }); }
        a.sinkT += dt;
        if (a.look) a.look._sink = Math.max(0, (a.sinkT - 2) / 5);
        if (a.sinkT > 2 && R.rng() < dt * 8) this.bubble(a.x + (R.rng() - 0.3) * 16, a.y - 3);
        if (R.rng() < dt * 1.5) this.ripple(a.x + 3, a.y - 2);
        if (a.sinkT > 7) { if (a.look) a.look._sink = null; this.sink(a, false); }
      } else if (!a.dead && R.rng() < dt * 2) this.ripple(a.x, a.y);
    }
    // cars
    for (const v of g.traffic.list) {
      if (v.removed) continue;
      if (wet(v.x, v.y)) {
        v.sinkT = (v.sinkT || 0) + dt;
        v.vx *= 1 - Math.min(1, dt * 3); v.vy *= 1 - Math.min(1, dt * 3); v.speed *= 1 - Math.min(1, dt * 3);
        if (R.rng() < dt * 12) this.bubble(v.x + (R.rng() - 0.5) * v.model.w * 0.6, v.y + (R.rng() - 0.5) * v.model.h);
        if (v.sinkT > 0.8) {
          if (v.driver === pl) { pl.exitCar(); g.ui.toast('The car is going under! Swim for it!', 'bad'); }
          else if (v.driver) { const d = v.driver; g.traffic.exitVehicle(v, d); if (!d.dead) g.actors.setFlee(d, v, 6); }
          for (const p of v.passengers || []) { p.inCar = null; p.x = v.x + 10; p.y = v.y; }
          v.passengers = [];
        }
        if (v.sinkT > 4.5) {
          for (let k = 0; k < 14; k++) this.bubble(v.x + (R.rng() - 0.5) * 20, v.y + (R.rng() - 0.5) * 12);
          g.audio.sfx('splash', v.x, v.y);
          if (g.player.inCar === v) pl.exitCar();
          v.keep = false;
          g.traffic.remove(v);
          if (v.stolen || v.owner === 'player') g.ui.toast(`The ${v.model.name} is at the bottom of the water now.`);
        }
      } else if (v.sinkT) v.sinkT = Math.max(0, v.sinkT - dt);
    }
    // severed parts that land in the water go down too
    if (R.gore && R.gore.parts) {
      for (const p of R.gore.parts) {
        if (!p.rest || p.sunk || !wet(p.x, p.y)) continue;
        p.sinkT = (p.sinkT || 0) + dt;
        if (R.rng() < dt * 6) this.bubble(p.x, p.y - 1);
        if (p.sinkT > 3) { p.sunk = true; this.splash(p.x, p.y); }
      }
      if (R.gore.parts.some((p) => p.sunk)) R.gore.parts = R.gore.parts.filter((p) => !p.sunk);
    }
    // cement shoes going down
    for (let i = this.sinking.length - 1; i >= 0; i--) {
      const s = this.sinking[i];
      s.t += dt;
      if (R.rng() < dt * 10) this.bubble(s.x + (R.rng() - 0.5) * 6, s.y - 2);
      if (s.t > 2.5) this.sinking.splice(i, 1);
    }
  };
  W.ripple = function (x, y) { G().fx.add({ x: x + (R.rng() - 0.5) * 6, y: y - 1, vx: 0, vy: 0, life: 0.7, max: 0.7, c: 'rgba(220,240,250,0.55)', s: 2, grow: 6 }); };
  W.bubble = function (x, y) { G().fx.add({ x, y, vx: (R.rng() - 0.5) * 6, vy: -10 - R.rng() * 10, life: 0.8, max: 0.8, c: 'rgba(230,248,255,0.8)', s: 1 }); };
  W.splash = function (x, y) { for (let k = 0; k < 10; k++) G().fx.add({ x, y: y - 4, vx: (R.rng() - 0.5) * 60, vy: -30 - R.rng() * 40, life: 0.5, max: 0.5, c: 'rgba(210,235,250,0.85)', s: 2, grav: 160 }); };
  // a body (or a live one in cement shoes) goes to the bottom
  W.sink = function (a, cement) {
    const g = G();
    a.sunk = true;
    this.sinking.push({ x: a.x, y: a.y, t: 0 });
    this.splash(a.x, a.y);
    if (a.person) { a.person.missing = true; a.person.missingDay = g.pop.day; }
    g.actors.remove(a);
    if (cement) g.audio.sfx('splash', a.x, a.y);
  };
  // "fit them for cement shoes": USE on someone out cold, surrendered or dead, beside the water
  W.context = function (pl) {
    const g = G(), w = g.world;
    if (pl.inCar || pl.room || !pl.inv.tools.cinder) return null;
    const tx = (pl.x / TS) | 0, ty = (pl.y / TS) | 0;
    let water = null;
    for (let r = 1; r <= 2 && !water; r++) for (let yy = ty - r; yy <= ty + r && !water; yy++) for (let xx = tx - r; xx <= tx + r; xx++) if (w.isWater(xx, yy)) { water = { x: xx, y: yy }; break; }
    if (!water) return null;
    const v = g.actors.near(pl.x, pl.y, TS * 1.6, (a) => a.kind === 'h' && !a.sunk && !a.crew && (a.dead ? a.looted : a.down > 0 || a.state === 'surrender'))[0];
    if (!v) return null;
    return { label: v.dead ? 'Sink the body (cinder block)' : 'Fit them for cement shoes', fn: () => this.cement(v, water) };
  };
  W.cement = function (v, water) {
    const g = G(), pl = g.player;
    pl.inv.tools.cinder--;
    const alive = !v.dead;
    if (alive) {
      g.actors.say(v, R.dialog.line('beg', v));
      g.law.crime('murder', v.x, v.y, { victim: v });
      if (v.person) { g.pop.kill(v.person, 'player'); v.person.missing = true; }
      pl.rep.infamy += 6;
    }
    v.x = water.x * TS + 8; v.y = water.y * TS + 8;
    this.sink(v, true);
    g.cam.shake(2);
    g.ui.toast(alive ? 'Rope, a cinder block, a shove. The water closes over. A few bubbles, then nothing.' : 'The body goes under with the block. No body, no case.', alive ? 'bad' : '');
    if (v.person) setTimeout(() => g.pop.addNews(v.person.city, `${v.person.first} ${v.person.last} (${v.person.age}) reported missing. Family asks anyone with information to come forward.`), 400);
  };
  // draw people chest-deep, and sinking cars low in the water
  const A = R.art, baseDraw = A.drawPerson;
  A.drawPerson = function (g, x, y, dir, walk, look, st) {
    const game = G();
    // a body in the water: bobbing, then going under
    if (look && look._sink != null && st && st.down && game && game.renderer && g === game.renderer.g) {
      const k = Math.min(1, look._sink), t = game.clock.real, X = Math.round(x), Y = Math.round(y);
      const bob = k < 0.05 ? Math.round(Math.sin(t * 2.2) * 1) : 0;
      g.save();
      g.globalAlpha = 1 - k * 0.9;
      baseDraw.call(this, g, x, y + bob + Math.round(k * 3), dir, walk, look, st);
      g.restore();
      // the water closing over it
      g.save();
      g.fillStyle = `rgba(28,78,108,${(0.18 + k * 0.6).toFixed(2)})`;
      g.beginPath(); g.ellipse(X + 3, Y - 3, 16, 7, 0, 0, Math.PI * 2); g.fill();
      g.fillStyle = 'rgba(220,240,250,0.5)';
      g.fillRect(X - 10 + Math.round(Math.sin(t * 3) * 2), Y - 9 + Math.round(k * 2), 8, 1);
      g.fillRect(X + 6 - Math.round(Math.sin(t * 3) * 2), Y + 2, 7, 1);
      g.restore();
      return;
    }
    if (!game || !game.renderer || g !== game.renderer.g || !wet(x, y) || (st && st.down && !(st && st.dead))) return baseDraw.call(this, g, x, y, dir, walk, look, st);
    const X = Math.round(x), Y = Math.round(y);
    g.save();
    g.beginPath(); g.rect(X - 16, Y - 60, 32, 52); g.clip();
    baseDraw.call(this, g, x, y + 5, dir, walk, look, st);
    g.restore();
    const t = game.clock.real;
    g.fillStyle = 'rgba(220,240,250,0.6)';
    g.fillRect(X - 6 + Math.round(Math.sin(t * 4) * 1), Y - 8, 12, 1);
    g.fillStyle = 'rgba(20,50,70,0.35)';
    g.fillRect(X - 5, Y - 7, 10, 2);
  };
  const baseCar = A.drawCar;
  A.drawCar = function (g, v) {
    if (!v.sinkT) return baseCar.call(this, g, v);
    const k = Math.min(1, v.sinkT / 4.5);
    g.save();
    g.globalAlpha = 1 - k * 0.75;
    baseCar.call(this, g, v);
    g.restore();
    g.save();
    g.translate(Math.round(v.x), Math.round(v.y)); g.rotate(v.angle);
    g.fillStyle = `rgba(30,80,110,${0.25 + k * 0.5})`;
    g.fillRect(-v.model.w / 2, -v.model.h / 2, v.model.w, v.model.h);
    g.restore();
  };
  // the general store stocks cinder blocks
  D.tools = D.tools || {};
  D.tools.cinder = { name: 'Cinder Block & Rope' };
  const PP = R.Player.prototype, baseCtx = PP.contextAction;
  PP.contextAction = function () {
    const c = W.context(this);
    return c || baseCtx.call(this);
  };
})();
