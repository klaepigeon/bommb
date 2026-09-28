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
    a.removed = false; // picking it up took it out of the world; putting it down puts it back
    if (a.person && !a.dead) a.person.actor = a;
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
    // pick up the searched dead, anyone out cold, or anyone tied up
    const a = g.actors.near(pl.x, pl.y, TS * 1.2, (q) => q.kind === 'h' && !q.carried && !q.sunk && ((q.dead && q.looted && !q.gibbed) || (!q.dead && (q.down > 0 || q.tied))))[0];
    if (a) return { label: a.dead ? 'Pick up the body' : a.tied ? 'Throw them over your shoulder' : 'Carry them', fn: () => this.pickUp(a) };
    return null;
  };
  const PP = R.Player.prototype, baseCtx = PP.contextAction;
  // tie up the surrendered, the cowering or the knocked out; gag the tied
  B.captiveCtx = function (pl) {
    const g = G();
    if (pl.carrying || pl.inCar || pl.room && pl.room.b.type === 'jail') return null;
    const cap = g.actors.near(pl.x, pl.y, TS * 1.3, (q) => q.kind === 'h' && !q.dead && !q.carried && !q.cop && !q.crew && (q.tied || q.down > 0 || q.state === 'surrender' || q.state === 'cower'))[0];
    if (cap && !cap.tied && pl.inv.tools.rope) return { label: 'Tie them up', fn: () => this.tie(cap) };
    if (cap && cap.tied && !cap.gagged && pl.inv.tools.tape) return { label: 'Tape their mouth shut', fn: () => { pl.inv.tools.tape--; cap.gagged = true; g.actors.say(cap, 'Mmmph!'); if (cap.witness) cap.witness.silenced = true; } };
    if (cap && cap.tied) return { label: 'Throw them over your shoulder', fn: () => this.pickUp(cap) };
    return null;
  };
  B.trunkCtx = function (pl) {
    const g = G();
    if (pl.carrying || pl.inCar || pl.room) return null;
    const v = g.traffic.list.find((c) => !c.removed && c.trunk && c.trunk.length && R.dist(c.x - Math.cos(c.angle) * c.model.w * 0.5, c.y - Math.sin(c.angle) * c.model.w * 0.5, pl.x, pl.y) < 16);
    return v ? { label: 'Open the trunk', fn: () => { const a = v.trunk.pop(); a.hidden = false; a.x = pl.x; a.y = pl.y; this.pickUp(a); } } : null;
  };
  PP.contextAction = function () { return (this.carrying && B.context(this)) || B.captiveCtx(this) || B.trunkCtx(this) || baseCtx.call(this) || B.context(this); };
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

  // ---------------------------------------------------------------- captives
  B.tie = function (h) {
    const g = G(), pl = g.player;
    pl.inv.tools.rope--;
    h.tied = true; h.tiedAt = g.clock.real; h.down = 0; h.stay = true; h.state = 'tied'; h.timer = 1e9; h.hostile = false;
    if (h.witness) h.witness.silenced = true;
    g.actors.say(h, R.rng.pick(['Please! Don\'t hurt me!', 'What are you gonna do with me?!', 'You won\'t get away with this!']));
    g.audio.sfx('swing', h.x, h.y);
    // tying someone up in front of people is a crime
    for (const a of g.actors.near(h.x, h.y, TS * 7)) if (a !== h && a.kind === 'h' && !a.dead && (a.cop || R.rng() < 0.5) && g.world.los(a.x, a.y - 8, h.x, h.y - 8)) { g.law.crime('kidnap', h.x, h.y, { victim: h }); break; }
  };
  B.updateCaptives = function (dt) {
    const g = G(), pl = g.player;
    for (const a of g.actors.list) {
      if (!a.tied || a.dead) continue;
      a.state = 'tied'; a.timer = 1e9; a.vx = a.vy = 0; a.stay = true;
      if (!a.gagged && R.rng() < dt * 0.15) { g.actors.say(a, R.rng.pick(['HELP! Somebody help me!', 'I\'m tied up over here!', 'Police! POLICE!'])); g.actors.noise(a.x, a.y, TS * 9, 'scream', pl); const cop = g.actors.near(a.x, a.y, TS * 9, (q) => q.cop && !q.dead)[0]; if (cop) g.law.crime('kidnap', a.x, a.y, { victim: a, witness: cop }); }
      // left alone long enough, anyone can work the knots loose
      if (g.clock.real - (a.tiedAt || 0) > (a.gagged ? 300 : 150) && R.rng() < dt * 0.05 && Math.hypot(a.x - pl.x, a.y - pl.y) > TS * 4) {
        a.tied = false; a.gagged = false; a.stay = false; a.state = 'idle';
        g.actors.say(a, 'I\'m free!'); g.actors.setFlee(a, pl, 12);
        if (g.actors.startReport) g.actors.startReport(a);
      }
    }
  };
  // ransom: call the family of someone you're holding
  B.captives = function () {
    const g = G(), out = [];
    for (const a of g.actors.list) if (a.tied && !a.dead && !a.removed && !a.hidden && a.person) out.push(a);
    for (const v of g.traffic.list) for (const a of v.trunk || []) if (!a.dead && a.person) out.push(a);
    if (G().player.carrying && !G().player.carrying.dead && G().player.carrying.person) out.push(G().player.carrying);
    return [...new Set(out)];
  };
  B.ransom = function (a) {
    const g = G(), p = a.person, pop = g.pop;
    const kin = pop.people[p.spouse] || (p.parents || []).map((id) => pop.people[id]).find((q) => q && q.alive);
    const amt = Math.round(150 + (p.wealth || 20) * 6 + (p.isDon ? 3000 : 0) + (p.faction && p.faction !== 'law' ? 400 : 0));
    const who = kin ? `${kin.first} ${kin.last}` : `the ${p.last} family`;
    g.ui.choice(`Ransom for ${pop.name(p)}`, [
      { label: `Demand ${R.fmtMoney(amt)} from ${who}`, small: 'They pay, you let them go', fn: () => {
        if (R.rng() < 0.15 && !p.isDon) { g.law.crime('kidnap', g.player.x, g.player.y, {}); return g.ui.toast(`${who} called the cops instead. They're tracing the call!`, 'bad'); }
        g.player.addCash(amt); g.audio.sfx('cash');
        // the hostage walks free
        for (const v of g.traffic.list) if (v.trunk) v.trunk = v.trunk.filter((q) => q !== a);
        if (g.player.carrying === a) g.player.carrying = null;
        a.tied = false; a.gagged = false; g.actors.remove(a);
        p.fear = 100; p.opinion = -100; p.grudge = 1;
        g.pop.addNews(p.city, `${p.first} ${p.last} released unharmed after ${who} paid a ransom. Police have "no comment".`);
        g.player.rep.infamy += 6;
        g.ui.toast(`The money's in a locker at the bus depot. ${p.first} walks home.`, 'good');
      } },
      { label: 'Hang up', fn: () => {} },
    ]);
  };
  B.drawBound = function (g, h) {
    const X = Math.round(h.x), Y = Math.round(h.y);
    g.fillStyle = '#8a6a3a'; g.fillRect(X - 5, Y - 11, 10, 1); g.fillRect(X - 5, Y - 7, 10, 1); g.fillRect(X - 3, Y - 3, 6, 1);
    g.fillStyle = '#c8a060'; g.fillRect(X - 4, Y - 11, 2, 1); g.fillRect(X + 1, Y - 7, 2, 1);
    if (h.gagged) { g.fillStyle = '#a8a8b0'; g.fillRect(X - 2, Y - 15, 5, 2); g.fillStyle = '#e0e0e8'; g.fillRect(X - 2, Y - 15, 5, 1); }
  };

  // ---------------------------------------------------------------- discovery
  B.update = function (dt) {
    const g = G(), pl = g.player;
    this.updateCaptives(dt);
    const c = pl.carrying;
    if (c) {
      pl.weaponOut = false;
      if (!c.dead && !c.tied) {
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
