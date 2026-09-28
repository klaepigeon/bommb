// RHAPSODY — bodies. People who stumble on a corpse scream, run and call it in, and the
// cops come looking; if you're standing over it bloody or armed, you're the suspect.
// So pick it up: carry the dead (or the knocked-out) over your shoulder, slowly, and put
// them somewhere quiet — a car trunk, a dumpster, the bushes, the water.
'use strict';
(function () {
  const D = R.data, O = D.O, T = D.T, TS = R.TILE;
  const B = (R.bodies = { t: 0 });
  const G = () => R.game;

  // remember who the player killed
  const baseKill = R.combat.kill;
  R.combat.kill = function (h, source, kind) {
    const g = G();
    if (h && !h.dead && g && (source === g.player || (source && source.driver === g.player) || (source && source.owner === g.player))) h.byPlayer = true;
    return baseKill.call(this, h, source, kind);
  };

  // ---------------------------------------------------------------- carrying
  B.pickUp = function (a) {
    const g = G(), pl = g.player;
    if (pl.carrying) return;
    pl.carrying = a;
    a.carried = true;
    g.actors.remove(a);
    pl.weaponOut = false; pl.sneak = false;
    g.audio.sfx('swing', pl.x, pl.y);
    g.ui.toast(a.dead ? 'You heave the body over your shoulder. Heavy. Find somewhere quiet.' : 'You sling them over your shoulder. They\'re out cold, for now.');
  };
  B.putDown = function (x, y) {
    const g = G(), pl = g.player, a = pl.carrying;
    if (!a) return null;
    pl.carrying = null;
    a.carried = false;
    a.x = x != null ? x : pl.x + Math.cos(pl.ang) * 10; a.y = y != null ? y : pl.y + Math.sin(pl.ang) * 6 + 4;
    g.actors.add(a);
    return a;
  };
  // what you can do with a body where you're standing
  B.spots = function (pl) {
    const g = G(), w = g.world, tx = (pl.x / TS) | 0, ty = (pl.y / TS) | 0;
    const near = (pred, r) => { for (let yy = ty - (r || 1); yy <= ty + (r || 1); yy++) for (let xx = tx - (r || 1); xx <= tx + (r || 1); xx++) if (pred(xx, yy)) return { x: xx, y: yy }; return null; };
    return {
      car: g.traffic.list.find((v) => !v.removed && !v.wrecked && !v.sinkT && !v.model.bus && R.dist(v.x, v.y, pl.x, pl.y) < v.model.w * 0.75 && !v.driver),
      trash: near((x, y) => w.o(x, y) === O.TRASH),
      bush: near((x, y) => [O.BUSH, O.REED, O.TREE, O.PINE, O.PALM].includes(w.o(x, y)) || w.t(x, y) === T.FOREST || w.t(x, y) === T.MARSH),
      water: near((x, y) => w.isWater(x, y), 2),
    };
  };
  B.context = function (pl) {
    const g = G();
    if (pl.inCar || pl.room) return null;
    if (pl.carrying) {
      const a = pl.carrying, s = this.spots(pl);
      if (s.car) return { label: `Stuff ${a.dead ? 'the body' : 'them'} in the trunk`, fn: () => { const v = s.car; this.putDown(); g.actors.remove(a); a.hidden = true; (v.trunk = v.trunk || []).push(a); g.audio.sfx('door', v.x, v.y); g.ui.toast(`Into the trunk of the ${v.model.name}. Slam.`); } };
      if (s.trash && a.dead) return { label: 'Dump the body in the trash', fn: () => { this.putDown(); g.actors.remove(a); a.hidden = true; if (a.person) { a.person.missing = true; if (R.rng() < 0.35) setTimeout(() => { g.pop.addNews(a.person.city, `Garbagemen find the body of ${a.person.first} ${a.person.last} (${a.person.age}) in a trash can. Police have "several leads".`); if (a.byPlayer) { const c = g.world.cityAt(s.trash.x, s.trash.y); if (c) c.heat = Math.min(100, (c.heat || 0) + 12); } }, 30000); } g.ui.toast('Under the lid, under the bags. Trash day is Thursday.'); } };
      if (s.water) return { label: `Throw ${a.dead ? 'the body' : 'them'} in the water`, fn: () => { this.putDown(s.water.x * TS + 8, s.water.y * TS + 8); if (!a.dead) a.down = Math.max(a.down, 10); g.fx.add && R.water && R.water.splash(a.x, a.y); if (a.person && a.dead && R.rng() < 0.4) setTimeout(() => g.pop.addNews(a.person.city, `A body identified as ${a.person.first} ${a.person.last} washed up this morning. Foul play suspected.`), 45000); } };
      if (s.bush && a.dead) return { label: 'Hide the body in the brush', fn: () => { const b = this.putDown(s.bush.x * TS + 8, s.bush.y * TS + 10); b.hidden = true; g.ui.toast('Leaves over the face. Only a shoe shows, if you know where to look.'); } };
      return { label: a.dead ? 'Put the body down' : 'Put them down', fn: () => this.putDown() };
    }
    // take one back out of a trunk
    const v = g.traffic.list.find((c) => !c.removed && c.trunk && c.trunk.length && R.dist(c.x - Math.cos(c.angle) * c.model.w * 0.5, c.y - Math.sin(c.angle) * c.model.w * 0.5, pl.x, pl.y) < 16);
    if (v) return { label: 'Open the trunk', fn: () => { const a = v.trunk.pop(); a.hidden = false; a.x = pl.x; a.y = pl.y; this.pickUp(a); } };
    // pick up the searched dead, or anyone out cold
    const a = g.actors.near(pl.x, pl.y, TS * 1.2, (q) => q.kind === 'h' && !q.carried && !q.sunk && ((q.dead && q.looted && !q.gibbed) || (!q.dead && q.down > 0)))[0];
    if (a) return { label: a.dead ? 'Pick up the body' : 'Carry them', fn: () => this.pickUp(a) };
    return null;
  };
  const PP = R.Player.prototype, baseCtx = PP.contextAction;
  B.trunkCtx = function (pl) {
    const g = G();
    if (pl.carrying || pl.inCar || pl.room) return null;
    const v = g.traffic.list.find((c) => !c.removed && c.trunk && c.trunk.length && R.dist(c.x - Math.cos(c.angle) * c.model.w * 0.5, c.y - Math.sin(c.angle) * c.model.w * 0.5, pl.x, pl.y) < 16);
    return v ? { label: 'Open the trunk', fn: () => { const a = v.trunk.pop(); a.hidden = false; a.x = pl.x; a.y = pl.y; this.pickUp(a); } } : null;
  };
  PP.contextAction = function () { return (this.carrying && B.context(this)) || B.trunkCtx(this) || baseCtx.call(this) || B.context(this); };
  // slow, no running, no shooting while you carry
  const AP = R.Actors.prototype, baseMove = AP.moveActor;
  AP.moveActor = function (a, vx, vy, dt) {
    if (a && a === G().player && a.carrying) { vx *= 0.55; vy *= 0.55; }
    return baseMove.call(this, a, vx, vy, dt);
  };
  const baseFire = PP.fire;
  PP.fire = function () { if (this.carrying) return this.game.ui.toast('Your hands are full.'); return baseFire.apply(this, arguments); };
  const baseEnter = PP.enterCar;
  PP.enterCar = function (v, wired) { if (this.carrying) { const a = this.carrying; this.carrying = null; a.carried = false; a.hidden = true; (v.trunk = v.trunk || []).push(a); this.game.ui.toast('You toss them in the trunk first.'); } return baseEnter.call(this, v, wired); };

  // ---------------------------------------------------------------- discovery
  B.update = function (dt) {
    const g = G(), pl = g.player;
    const c = pl.carrying;
    if (c) {
      pl.weaponOut = false;
      if (!c.dead) {
        c.down -= dt;
        if (c.down <= 0) {
          this.putDown();
          c.down = 0; c.state = 'idle';
          g.actors.say(c, R.rng.pick(['PUT ME DOWN!', 'Where are you taking me?!', 'Help! HELP!']));
          g.actors.setFlee(c, pl, 12);
          g.law.crime('assault', pl.x, pl.y, { victim: c });
        }
      }
    }
    this.t -= dt;
    if (this.t > 0) return;
    this.t = 1.2;
    for (const b of g.actors.list) {
      if (b.kind !== 'h' || !b.dead || b.found || b.hidden || b.sunk || b.carried) continue;
      const seer = g.actors.near(b.x, b.y, TS * 7, (a) => a.kind === 'h' && !a.dead && !(a.down > 0) && a !== b && !a.crew && a.state !== 'fight' && a.state !== 'sleep' && !a.look.kid && g.world.los(a.x, a.y - 8, b.x, b.y - 4))[0];
      if (!seer) continue;
      b.found = true;
      if (seer.cop) g.actors.say(seer, 'Dispatch, I\'ve got a body. Send a wagon.');
      else { g.actors.say(seer, R.rng.pick(['Oh my God! Somebody\'s dead!', 'Is that... is that a body?!', 'Help! Police! There\'s a dead man!'])); g.actors.setFlee(seer, b, 8); }
      if (b.byPlayer && !g.law.active()) {
        const dPl = R.dist(pl.x, pl.y, b.x, b.y);
        const suspect = dPl < TS * 6 && (pl.bloody > 0.3 || pl.weaponOut || pl.carrying);
        const def = g.law.CRIMES.murder;
        g.law.startIncident({ type: 'murder', def, x: suspect ? pl.x : b.x, y: suspect ? pl.y : b.y, jur: g.law.jurAt(b.x, b.y), identified: suspect && !pl.masked, lvl: suspect ? 2 : 1, bounty: suspect ? def.bounty : 0 }, null);
        g.ui.toast(suspect ? 'They found the body, and you standing over it.' : 'Somebody found a body. Cops are coming to look around.', suspect ? 'bad' : 'warn');
      }
    }
  };

  // ---------------------------------------------------------------- drawing
  const A = R.art, baseDrawPerson = A.drawPerson;
  const Rn = R.Renderer && R.Renderer.prototype;
  B.drawCarried = function (g, pl) {
    const a = pl.carrying;
    if (!a) return;
    baseDrawPerson.call(A, g, pl.x + 1, pl.y - 12, 2, 0, a.look, { down: true });
  };
  B.drawHidden = function (g, b) {
    // a shoe poking out of the leaves
    g.fillStyle = '#1b1410'; g.fillRect(Math.round(b.x) + 3, Math.round(b.y) - 2, 4, 3);
    g.fillStyle = '#3a2a22'; g.fillRect(Math.round(b.x) + 4, Math.round(b.y) - 2, 2, 1);
  };
})();
