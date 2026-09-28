// RHAPSODY — carrying, the way it should feel. Anything that's down can go over your
// shoulder: the dead, the knocked out, the tied up, and the deer you just shot. A whole
// carcass is worth more to the butcher than a pelt and a steak. Press attack to throw what
// you're carrying (off a pier, into a ditch, at somebody). And people notice a man walking
// down the street with a body on his back.
'use strict';
(function () {
  const D = R.data, TS = R.TILE;
  const G = () => R.game;
  const CY = (R.carry = { flying: [] });

  CY.isAnimal = (a) => a && a.kind === 'a';
  // an animal carcass nearby that isn't spoken for
  CY.carcass = function (pl) {
    const g = G();
    return g.actors.near(pl.x, pl.y, TS * 1.3, (q) => q.kind === 'a' && q.dead && !q.carried && !q.sunk)[0];
  };
  CY.value = function (a) {
    const pelt = a.def.pelt && D.loot[a.def.pelt];
    const base = (pelt ? pelt.v : 5) + (a.def.size > 8 ? 2 : 1) * D.loot.meat.v;
    return Math.round(base * (a.skinned ? 0.4 : 1.6));
  };
  CY.context = function (pl) {
    const g = G();
    if (pl.inCar || pl.room) return null;
    const a = pl.carrying;
    if (a && this.isAnimal(a)) {
      const shop = g.world.buildings.find((b) => b && !b.destroyed && b.type === 'butcher' && R.dist(b.out.x * TS + 8, b.out.y * TS + 8, pl.x, pl.y) < TS * 3.5);
      if (shop) return { label: `Sell the ${a.def.name.toLowerCase()} whole (${R.fmtMoney(this.value(a))})`, fn: () => { const v = this.value(a); pl.carrying = null; a.carried = false; a.removed = true; pl.addCash(v, true); g.audio.sfx('cash'); g.ui.toast(`The butcher weighs it and pays ${R.fmtMoney(v)}. "Clean shot. Come back anytime."`, 'good'); } };
      return null;
    }
    if (a) return null;
    const c = this.carcass(pl);
    if (c) {
      if (c.skinned) return { label: `Pick up the ${c.def.name.toLowerCase()}`, fn: () => R.bodies.pickUp(c) };
      return { label: c.def.name, fn: () => g.ui.choice(`A dead ${c.def.name.toLowerCase()}`, [
        { label: 'Skin it', small: 'Pelt and meat, right here', fn: () => pl.skin(c) },
        { label: 'Carry it', small: `Worth about ${R.fmtMoney(this.value(c))} whole at a butcher`, fn: () => R.bodies.pickUp(c) },
        { label: 'Leave it', fn: () => {} },
      ]) };
    }
    return null;
  };
  // attack while carrying: throw it
  CY.throw = function (pl) {
    const g = G(), a = pl.carrying;
    if (!a) return;
    const ang = pl.ang, heavy = a.kind === 'a' ? (a.def.size > 8 ? 0.6 : 1.2) : 0.9;
    const b = R.bodies.putDown(pl.x + Math.cos(ang) * 8, pl.y + Math.sin(ang) * 6 + 2);
    if (!b) return;
    this.flying.push({ a: b, vx: Math.cos(ang) * 95 * heavy, vy: Math.sin(ang) * 70 * heavy, z: 12, vz: 55, t: 0 });
    g.audio.sfx('swing', pl.x, pl.y);
    if (b.kind === 'h' && !b.dead) b.down = Math.max(b.down, 3);
  };
  CY.update = function (dt) {
    const g = G(), pl = g.player, w = g.world;
    for (const f of this.flying.slice()) {
      f.t += dt; f.vz -= 320 * dt; f.z += f.vz * dt;
      const nx = f.a.x + f.vx * dt, ny = f.a.y + f.vy * dt;
      if (!w.solidPed((nx / TS) | 0, (ny / TS) | 0)) { f.a.x = nx; f.a.y = ny; }
      else { f.vx *= -0.2; f.vy *= -0.2; }
      f.a.airZ = Math.max(0, f.z);
      // hit anybody in the way
      for (const h of g.actors.near(f.a.x, f.a.y, 9)) if (h !== f.a && h.kind === 'h' && !h.dead && !f.hit) { f.hit = true; R.combat.damage(h, 12, pl, 'melee'); h.down = Math.max(h.down, 1.5); g.audio.sfx('punch', h.x, h.y); }
      if (f.z <= 0) {
        g.audio.sfx('thud', f.a.x, f.a.y);
        g.fx.debris && g.fx.hit(f.a.x, f.a.y - 4);
        if (f.a.kind === 'h' && !f.a.dead) { R.combat.damage(f.a, 8, pl, 'fall'); }
        if (f.a.dead && g.settings.gore !== false) g.fx.blood(f.a.x, f.a.y, 4);
        f.vx *= 0.25; f.vy *= 0.25; f.bounces = (f.bounces || 0) + 1;
        if (f.bounces > 1 || Math.abs(f.vx) + Math.abs(f.vy) < 20 || f.t > 2) { f.a.airZ = 0; this.flying.splice(this.flying.indexOf(f), 1); }
        else { f.z = 0.1; f.vz = 25; }
      }
    }
    // someone sees you hauling a person
    this.st = (this.st || 0) - dt;
    const c = pl.carrying;
    if (!c || c.kind !== 'h' || pl.room || pl.inCar || this.st > 0) return;
    this.st = 1;
    if ((this.warnT || 0) > g.clock.t) return;
    const night = g.clock.isNight();
    const seer = g.actors.near(pl.x, pl.y, TS * (night ? 6 : 10), (a) => a.kind === 'h' && !a.dead && !(a.down > 0) && !a.crew && !a.hostile && a.state !== 'sleep' && !a.look.kid && (!night || g.env.litAt(a.x, a.y) || R.dist(a.x, a.y, pl.x, pl.y) < TS * 3) && g.world.los(a.x, a.y - 8, pl.x, pl.y - 8))[0];
    if (!seer) return;
    this.warnT = g.clock.t + 20;
    g.actors.say(seer, c.dead ? R.rng.pick(['Is that... a BODY?!', 'Oh God, he\'s carrying a dead man!', 'Somebody call the cops! He\'s got a corpse!']) : R.rng.pick(['Hey! Put them down!', 'Where are you taking her?!', 'Help! He\'s kidnapping somebody!']));
    g.law.crime(c.dead ? 'corpse' : 'kidnap', pl.x, pl.y, {});
  };
  // bodies and big game ride in a little red wagon, towed on its handle
  CY.wagonFor = (a) => a && (a.kind === 'h' || (a.kind === 'a' && a.def.size > 8));
  CY.moveWagon = function (pl) {
    const w = (pl.wagon = pl.wagon || { x: pl.x - 14, y: pl.y + 2, roll: 0 });
    const dx = w.x - pl.x, dy = w.y - (pl.y + 2), d = Math.hypot(dx, dy) || 1, L = 15;
    // a rigid handle: the wagon stays exactly a handle's length behind
    if (Math.abs(d - L) > 0.2) { const k = (d - L) / d; w.x -= dx * k; w.y -= dy * k; w.roll += Math.abs(d - L) * 0.35; }
    return w;
  };
  CY.drawWagon = function (g, pl, w) {
    const a = pl.carrying, X = Math.round(w.x), Y = Math.round(w.y);
    const ang = Math.atan2(pl.y + 2 - w.y, pl.x - w.x);
    // the handle: a black bar from the hitch to his fist, with a T-grip
    const hx0 = X + Math.cos(ang) * 9, hy0 = Y - 4 + Math.sin(ang) * 3, hx1 = pl.x - Math.cos(ang) * 2, hy1 = pl.y - 9;
    g.strokeStyle = '#0c0a0c'; g.lineWidth = 2; g.lineCap = 'square'; g.beginPath(); g.moveTo(Math.round(hx0), Math.round(hy0)); g.lineTo(Math.round(hx1), Math.round(hy1)); g.stroke();
    g.strokeStyle = '#3a3a40'; g.lineWidth = 0.8; g.beginPath(); g.moveTo(Math.round(hx0), Math.round(hy0) - 0.5); g.lineTo(Math.round(hx1), Math.round(hy1) - 0.5); g.stroke();
    const px = -Math.sin(ang), py = Math.cos(ang);
    g.fillStyle = '#0c0a0c'; g.fillRect(Math.round(hx1 - px * 2) - 1, Math.round(hy1 - py * 2) - 1, 2, 2); g.fillRect(Math.round(hx1 + px * 2) - 1, Math.round(hy1 + py * 2) - 1, 2, 2); g.fillRect(Math.round(hx1) - 1, Math.round(hy1) - 1, 2, 2);
    // shadow, wheels, bed
    g.fillStyle = 'rgba(16,12,36,0.4)'; g.fillRect(X - 10, Y + 1, 20, 3);
    const spin = Math.floor(w.roll) % 2;
    for (const wx of [X - 7, X + 5]) { g.fillStyle = '#141014'; g.fillRect(wx - 1, Y - 2, 5, 5); g.fillStyle = '#2a2a2e'; g.fillRect(wx, Y - 1, 3, 3); g.fillStyle = spin ? '#8a8a90' : '#5a5a60'; g.fillRect(wx + (spin ? 1 : 0), Y, 1 + (spin ? 0 : 1), 1); }
    g.fillStyle = '#141014'; g.fillRect(X - 10, Y - 9, 21, 8);
    g.fillStyle = '#9a1a14'; g.fillRect(X - 9, Y - 8, 19, 6);
    g.fillStyle = '#d8302a'; g.fillRect(X - 9, Y - 8, 19, 2);
    g.fillStyle = '#ff6a58'; g.fillRect(X - 8, Y - 8, 6, 1);
    g.fillStyle = '#f0e8d8'; g.fillRect(X - 5, Y - 5, 11, 1); // the little white stripe on the side
    // cargo
    if (a.kind === 'h') { g.save(); g.translate(X - 7, Y - 8); g.scale(0.72, 0.72); R.art.drawPerson(g, 0, 0, 2, 0, a.look, { down: true }); g.restore(); }
    else { const proxy = Object.assign(Object.create(Object.getPrototypeOf(a)), a, { x: X, y: Y - 7, dead: true }); g.save(); g.translate(X, Y - 7); g.scale(0.7, 0.7); g.translate(-X, -(Y - 7)); R.art.drawAnimal(g, proxy); g.restore(); }
  };
  // a carcass on your shoulder
  CY.drawCarried = function (g, pl) {
    const a = pl.carrying;
    if (a && this.wagonFor(a)) { if (!pl._wagonDrawn) this.drawWagon(g, pl, this.moveWagon(pl)); pl._wagonDrawn = false; return true; }
    if (!a || a.kind !== 'a') return false;
    const proxy = Object.assign(Object.create(Object.getPrototypeOf(a)), a, { x: pl.x + 1, y: pl.y - 13, dead: true });
    g.save();
    g.translate(pl.x + 1, pl.y - 13); g.scale(0.85, 0.85); g.translate(-(pl.x + 1), -(pl.y - 13));
    R.art.drawAnimal(g, proxy);
    g.restore();
    return true;
  };

  CY.init = function (g) {
    this.flying = [];
    if (this.wrapped) return;
    this.wrapped = true;
    const LP = R.Law.prototype;
    if (!LP.CRIMES.corpse) LP.CRIMES.corpse = { name: 'Carrying a Corpse', bounty: 30, lvl: 1 };
    const PP = R.Player.prototype, ctx = PP.contextAction, fire = PP.fire;
    PP.contextAction = function () {
      const own = CY.context(this);
      if (own) return own;
      const base = ctx.call(this);
      // one button, several things you can do with someone who's down: like a hold-prompt wheel
      if (this.carrying || this.inCar || this.room) return base;
      const g = G(), pl = this;
      const h = g.actors.near(pl.x, pl.y, TS * 1.3, (q) => q.kind === 'h' && !q.carried && !q.sunk && !q.hidden && !q.gibbed && !q.tied && (q.dead || q.down > 0))[0];
      if (!h) return base;
      const opts = [];
      if (base && /pocket|Search|Pick|Tie|Tape|Throw|Carry|Cut/i.test(base.label)) opts.push({ label: base.label, fn: base.fn });
      if (!opts.some((o) => /Pick|Throw|Carry/.test(o.label))) opts.push({ label: h.dead ? 'Pick up the body' : 'Throw them over your shoulder', fn: () => R.bodies.pickUp(h) });
      const tie = R.bodies.captiveCtx && R.bodies.captiveCtx(pl);
      if (tie && !opts.some((o) => o.label === tie.label)) opts.push({ label: tie.label, fn: tie.fn });
      if (h.dead && D.weapons[pl.weapon] && D.weapons[pl.weapon].blade && R.butcher && g.settings.gore !== false) opts.push({ label: 'Cut up the body', fn: () => R.butcher.menu(h) });
      if (opts.length === 1) return opts[0];
      const name = h.person && h.person.met && !h.person.unidentified ? g.pop.name(h.person) : h.dead ? 'The body' : 'Out cold';
      return { label: name, fn: () => g.ui.choice(name, opts.concat([{ label: 'Leave it', fn: () => {} }])) };
    };
    PP.fire = function () { if (this.carrying) return CY.throw(this); return fire.apply(this, arguments); };
    // whatever the carry drew before, animals get their own
    const RP = R.Renderer.prototype, dp = RP.drawPlayer;
    RP.drawPlayer = function (g, pl) {
      pl._wagonDrawn = false;
      if (pl.carrying && CY.wagonFor(pl.carrying) && !pl.inCar) { const w = CY.moveWagon(pl); if (w.y < pl.y) { CY.drawWagon(g, pl, w); pl._wagonDrawn = true; } }
      else pl.wagon = null;
      return dp.call(this, g, pl);
    };
    const B = R.bodies, dc = B.drawCarried;
    B.drawCarried = function (g, pl) { if (CY.drawCarried(g, pl)) return; return dc.call(this, g, pl); };
    // the pick-up toast knows what it picked up
    const pu = B.pickUp;
    B.pickUp = function (a) {
      if (a && a.kind === 'a') { const pl = G().player; if (pl.carrying) return; pl.carrying = a; a.carried = true; G().actors.remove(a); pl.weaponOut = false; pl.sneak = false; G().audio.sfx('swing', pl.x, pl.y); G().ui.toast(`You heave the ${a.def.name.toLowerCase()} over your shoulders.${a.def.size > 8 ? ' It weighs a ton.' : ''}`); return; }
      return pu.call(this, a);
    };
    // the remains module only carries the searched dead; the unsearched come too, after a search prompt
  };
})();
