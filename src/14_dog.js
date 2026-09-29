// RHAPSODY — a dog. The strays on the Brass Coast are thin and wary; feed one (a sandwich will
// do) and it's yours. It follows you everywhere (it waits outside when you go in, and jumps in
// the back when you drive), goes for anyone who comes at you, digs up the odd coin, and makes
// people like you a little more. Give it a name. Pet it now and then. Try to keep it alive.
'use strict';
(function () {
  const TS = R.TILE, D = R.data;
  const G = () => R.game;
  const DG = (R.dog = {});
  const NAMES = ['Rufus', 'Bandit', 'Duke', 'Lucky', 'Sadie', 'Boomer', 'Rosie', 'Hank', 'Pepper', 'Buster', 'Molly', 'Cash'];
  DG.state = function () { return R.shark.street(); };
  DG.info = function () { return this.state().dog || null; };
  DG.actor = function () { return G().actors.list.find((a) => a.kind === 'a' && a.companion && !a.dead) || null; };
  DG.adopt = function (a) {
    const g = G(), pl = g.player, st = this.state();
    if (!(pl.inv.cons.sandwich > 0)) return g.ui.toast('It sniffs your empty hands. Bring it something to eat (a sandwich).', 'warn');
    pl.inv.cons.sandwich--;
    const name = R.rng.pick(NAMES);
    st.dog = { name, day: g.pop.day, bond: 10 };
    this.tame(a);
    g.audio.sfx('accept');
    g.ui.story(name, `It wolfs the sandwich down, then leans its whole weight against your leg and won't move.\n\nYou've got a dog. You call it ${name}; it doesn't object.\n\n${name} follows you everywhere, goes for anyone who comes at you, and digs up the odd coin. People like a man with a dog. (USE next to ${name} to pet it or send it home.)`);
  };
  DG.tame = function (a) {
    const info = this.info();
    a.companion = true; a.keep = true; a.state = 'follow'; a.target = null; a.strangerName = info ? info.name : 'Dog';
    a.maxHp = a.hp = Math.max(a.maxHp, 60);
  };
  DG.summon = function () {
    const g = G(), pl = g.player, info = this.info();
    if (!info || this.actor() || pl.room || pl.inCar) return;
    const s = g.world.findNear(pl.x / TS, pl.y / TS, 1, 4, (x, y) => !g.world.solidPed(x, y) && !g.world.isWater(x, y));
    if (!s) return;
    const a = g.actors.makeAnimal(s.x * TS + 8, s.y * TS + 8, 'dog');
    if (a) this.tame(a);
  };
  DG.context = function (pl) {
    const g = G(), info = this.info();
    const own = this.actor();
    if (own && Math.hypot(own.x - pl.x, own.y - pl.y) < TS * 1.4) {
      return { label: info.name, fn: () => g.ui.choice(info.name, [
        { label: `Pet ${info.name}`, small: 'Good dog', fn: () => { info.bond = Math.min(100, (info.bond || 0) + 5); pl.cool = Math.min(100, (pl.cool || 0) + 3); g.fx.text(own.x, own.y - 14, '♥', '#e8586a'); g.audio.sfx('click'); } },
        { label: 'Send it home', small: 'It\'ll find its own way. You can whistle for another stray later', fn: () => { this.state().dog = null; own.companion = false; own.keep = false; own.state = 'wander'; g.ui.toast(`${info.name} trots off without looking back. Dogs are like that.`); } },
        { label: 'Leave it', fn: () => {} },
      ]) };
    }
    if (!info) {
      const stray = g.actors.near(pl.x, pl.y, TS * 1.5, (a) => a.kind === 'a' && !a.dead && a.def === D.animals.dog && !a.companion)[0];
      if (stray) return { label: 'Feed the stray', fn: () => this.adopt(stray) };
    }
    return null;
  };
  DG.update = function (dt) {
    const g = G(), pl = g.player, info = this.info();
    if (!info) return;
    this.t = (this.t || 0) - dt;
    if (this.t <= 0) {
      this.t = 1;
      if (!this.actor()) this.summon();
      const a = this.actor();
      if (a && a.hp < a.maxHp) a.hp = Math.min(a.maxHp, a.hp + 1);
      // now and then it digs something up
      if (a && !pl.inCar && R.rng() < 0.004) { const n = R.rng.int(3, 25); pl.addCash(n); g.fx.text(a.x, a.y - 14, `+$${n}`, '#e4a92a'); g.ui.toast(`${info.name} digs up something shiny: $${n}.`, 'good'); }
    }
  };
  DG.init = function (g) {
    this.t = 0;
    if (this.wrapped) return;
    this.wrapped = true;
    const AP = R.Actors.prototype, ua = AP.updateAnimal;
    AP.updateAnimal = function (a, dt) {
      if (!a.companion || a.dead) return ua.call(this, a, dt);
      const pl = this.game.player, def = a.def;
      a.t += dt; a.moving = false;
      // riding along: when you're in a car or indoors it waits; it catches up when you're out
      if (pl.inCar || pl.room) { a.hidden = !!pl.inCar; return; }
      a.hidden = false;
      const dp = R.dist(a.x, a.y, pl.x, pl.y);
      if (dp > TS * 20) { const s = this.game.world.findNear(pl.x / TS, pl.y / TS, 1, 3, (x, y) => !this.game.world.solidPed(x, y) && !this.game.world.isWater(x, y)); if (s) { a.x = s.x * TS + 8; a.y = s.y * TS + 8; } return; }
      // anyone coming at you gets the teeth
      if (!a.target || a.target.dead || a.timer <= 0) {
        const foe = this.near(pl.x, pl.y, TS * 8, (q) => q.kind === 'h' && !q.dead && q.hostile && !(q.down > 0) && !q.tied)[0] || this.near(pl.x, pl.y, TS * 6, (q) => q.kind === 'a' && !q.dead && q !== a && q.state === 'attack' && q.target === pl)[0];
        if (foe) { a.state = 'attack'; a.target = foe; a.timer = 10; if (R.rng() < 0.5) this.game.fx.text(a.x, a.y - 14, 'GRRR', '#d9621e'); }
      }
      if (a.state === 'attack' && a.target && !a.target.dead) return ua.call(this, a, dt);
      a.state = 'follow'; a.target = null;
      // stuck behind a wall: it finds its own way round (and turns up at your heel)
      if (dp > 60 && Math.hypot(a.x - (a.lastX || 0), a.y - (a.lastY || 0)) < 0.3) a.stuckT = (a.stuckT || 0) + dt; else a.stuckT = 0;
      a.lastX = a.x; a.lastY = a.y;
      if (a.stuckT > 1.5) { const s = this.game.world.findNear(pl.x / TS, pl.y / TS, 1, 2, (x, y) => !this.game.world.solidPed(x, y) && !this.game.world.isWater(x, y)); if (s) { a.x = s.x * TS + 8; a.y = s.y * TS + 8; } a.stuckT = 0; return; }
      if (dp > 28) {
        const ang = Math.atan2(pl.y - a.y, pl.x - a.x);
        a.angle = ang; a.moving = true;
        this.moveActor(a, Math.cos(ang) * def.speed * (dp > 90 ? 1 : 0.7), Math.sin(ang) * def.speed * (dp > 90 ? 1 : 0.7), dt);
      }
    };
    const PP = R.Player.prototype, ctx = PP.contextAction;
    PP.contextAction = function () { return (!this.inCar && !this.room && DG.context(this)) || ctx.call(this); };
    const GP = R.Game.prototype, tk = GP.tick;
    GP.tick = function (dt) { const r = tk.apply(this, arguments); if (this.player && this.actors && !this.ui.paused()) DG.update(dt); return r; };
    // losing it
    const C = R.combat, ck = C.kill;
    C.kill = function (h, source, kind) {
      const was = h && h.dead, r = ck.apply(this, arguments);
      if (!was && h && h.companion && h.kind === 'a') {
        const g2 = G(), info = DG.info();
        DG.state().dog = null;
        g2.player.cool = Math.max(0, (g2.player.cool || 0) - 30);
        g2.ui.story(info ? info.name : 'Your dog', `${info ? info.name : 'Your dog'} doesn't get up.\n\nYou kneel in the road for a long time. Nobody says anything to you, and that's the kindest thing anybody's done for you in years.`);
      }
      return r;
    };
    // people like a man with a dog
    const D2 = R.dialog, tree = D2.tree;
    D2.tree = function (h) { const t = tree.call(this, h); const a = DG.actor(); if (a && h && h.person && Math.hypot(a.x - h.x, a.y - h.y) < TS * 4 && R.rng() < 0.3) h.person.opinion = Math.min(100, (h.person.opinion || 0) + 1); return t; };
  };
})();
