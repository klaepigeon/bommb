// RHAPSODY — the armoured car. Brink's-style grey trucks run the banks' cash between branches,
// a driver and a guard with a shotgun up front. A bartender will sell you the route for the day;
// sometimes you just see one go by. You can't blow it up (that's the point of the armour), but
// you can ram it, shoot the engine out, and once it's dead on the road the crew bails out to
// fight. Then it's the back doors: dynamite, or a crowbar and a long, loud minute. Inside are
// canvas bags of bank money. Every cop in the county is on the radio before you've counted it.
'use strict';
(function () {
  const TS = R.TILE;
  const G = () => R.game;
  const AR = (R.armored = { t: 0 });
  const GREY = '#6a6e66';
  AR.state = function () { const st = R.shark.street(); return (st.armored = st.armored || { hits: 0, earned: 0, tipDay: -1, seenDay: -1 }); };
  AR.truck = function () { return G().traffic.list.find((v) => v.armored && !v.removed) || null; };
  // put one on the road out of sight, heading somewhere
  AR.spawn = function (near) {
    const g = G(), w = g.world, pl = g.player;
    const ptx = ((near || pl).x / TS) | 0, pty = ((near || pl).y / TS) | 0;
    const road = (x, y) => { const f = w.flow[w.idx(x, y)]; return f && !(f & R.FLOW.X); };
    const s = w.findNear(ptx, pty, 14, 30, road) || w.findNear(ptx, pty, 10, 40, road) || w.findNear(ptx, pty, 6, 50, road);
    if (!s) return null;
    const f = w.flow[w.idx(s.x, s.y)], dirs = [0, 1, 2, 3].filter((d) => f & R.DIRBIT[d]);
    const dir = R.rng.pick(dirs.length ? dirs : [0]);
    const DIRA = [-Math.PI / 2, 0, Math.PI / 2, Math.PI];
    const v = g.traffic.make('truck', s.x * TS + 8, s.y * TS + 8, DIRA[dir], { ai: { tx: s.x, ty: s.y, dir, turned: false }, keep: true, locked: true, color: GREY });
    v.model = Object.assign({}, v.model, { name: 'Armored Car', hp: 900, top: 100 });
    v.hp = v.maxHp = 900;
    v.armored = { bags: R.rng.int(3, 6), open: false, dead: false };
    v.cargo = null; // not swag: the hijack fence doesn't want it
    const d = g.traffic.addDriver(v, { role: 'guard', weapon: 'revolver', arch: 'square', cash: 30 });
    d.strangerName = 'Armored Car Driver'; d.keep = true; d.tr.brave = 1;
    const gd = g.actors.makeHuman(v.x, v.y, { tag: 'guard', weapon: 'shotgun', arch: 'tough', cash: 40 });
    gd.inCar = v; gd.state = 'drive'; gd.keep = true; gd.strangerName = 'Armored Car Guard'; gd.tr.brave = 1;
    v.passengers = (v.passengers || []).concat([gd]);
    v.crew = [d, gd];
    this.state().seenDay = g.pop.day;
    return v;
  };
  // the engine dies: stop dead, crew out and fighting
  AR.disable = function (v) {
    const g = G(), pl = g.player;
    if (v.armored.dead) return;
    v.armored.dead = true;
    v.ai = null; v.speed = 0; v.vx = v.vy = 0; v.parked = true; v.burning = 0;
    v.model = Object.assign({}, v.model, { top: 0, acc: 0 });
    for (const c of v.crew || []) {
      if (!c || c.dead) continue;
      if (c.inCar === v) g.traffic.exitVehicle(v, c);
      c.hostile = true; c.hostileLocked = true; c.state = 'idle';
      g.actors.setFight(c, pl);
    }
    v.passengers = [];
    g.fx.smoke(v.x, v.y - 4, true);
    g.ui.toast('The armored car grinds to a stop, steam pouring out of the grille. The crew\'s coming out shooting.', 'warn');
    g.law.crime('explosion', v.x, v.y, {});
  };
  AR.crack = function (v, how) {
    const g = G(), pl = g.player, s = this.state();
    if (v.armored.open) return;
    const alive = (v.crew || []).filter((c) => c && !c.dead && !(c.down > 0) && !c.tied && R.dist(c.x, c.y, v.x, v.y) < TS * 10);
    if (alive.length) return g.ui.toast('Not with the crew still on their feet.', 'warn');
    if (how === 'dynamite') {
      if (!(pl.inv.ammo.dynamite > 0)) return g.ui.toast('You need a stick of dynamite.', 'warn');
      pl.inv.ammo.dynamite--;
      R.combat.explosion(v.x - Math.cos(v.angle) * 30, v.y - Math.sin(v.angle) * 30, 20, 10, pl, false);
    } else {
      g.audio.sfx('crash', v.x, v.y);
      pl.stats && (pl.stats.pried = (pl.stats.pried || 0) + 1);
      g.clock.t += 2; // a long, loud couple of minutes
    }
    v.armored.open = true;
    const per = R.rng.int(700, 1400), n = v.armored.bags, total = per * n;
    pl.addCash(total);
    s.hits++; s.earned += total;
    g.audio.sfx('cash');
    g.law.crime('heist', v.x, v.y, {});
    // the bank's radio call goes out whether anyone saw your face or not
    if (!g.law.incident) g.law.startIncident({ type: 'heist', def: g.law.CRIMES.heist, x: v.x, y: v.y, jur: g.law.jurAt(v.x, v.y), identified: !pl.masked, t: g.clock.t, lvl: 3, bounty: g.law.CRIMES.heist.bounty }, null);
    const inc = g.law.incident;
    if (inc) inc.level = Math.max(inc.level, 3);
    const city = g.world.cityAt((v.x / TS) | 0, (v.y / TS) | 0);
    g.pop.addNews(city ? city.id : g.world.cities[0].id, `ARMORED CAR HIT IN BROAD DAYLIGHT. ${R.fmtMoney(total)} in bank money gone. "A military-style operation," says the chief. The FBI has been called.`);
    g.ui.banner('ARMORED CAR', `${n} canvas bags · ${R.fmtMoney(total)}. Every cop in the county is coming.`);
  };
  AR.context = function (pl) {
    if (pl.inCar || pl.room || pl.carrying) return null;
    const v = this.truck();
    if (!v || !v.armored.dead || v.armored.open || R.dist(pl.x, pl.y, v.x, v.y) > TS * 3) return null;
    return { label: 'The back doors', fn: () => G().ui.choice('Armored car: the back doors', [
      { label: 'Blow them', small: `A stick of dynamite (${pl.inv.ammo.dynamite || 0}). Quick and very loud`, fn: () => this.crack(v, 'dynamite') },
      { label: 'Pry them', small: 'A crowbar and a couple of minutes of screaming metal', fn: () => this.crack(v, 'pry') },
      { label: 'Leave it', fn: () => {} },
    ]) };
  };
  AR.update = function (dt) {
    const g = G(), pl = g.player, s = this.state();
    this.t -= dt;
    if (this.t > 0) return;
    this.t = 2;
    const v = this.truck();
    if (v) {
      // gone off the map, or empty and forgotten
      if (R.dist(v.x, v.y, pl.x, pl.y) > TS * 90 || (v.armored.open && R.dist(v.x, v.y, pl.x, pl.y) > TS * 40)) { g.traffic.remove(v); return; }
      if (!v.armored.dead && v.hp < v.maxHp * 0.45) this.disable(v);
      // crew shot from inside or dragged out: the truck dies with them
      if (!v.armored.dead && v.driver !== (v.crew || [])[0]) this.disable(v);
      return;
    }
    // the day's run, if you bought the route, or once in a while by chance, in daylight, in town
    const h = g.clock.hour(), city = g.world.cityAt((pl.x / TS) | 0, (pl.y / TS) | 0);
    if (!city || pl.room || h < 9 || h > 16 || s.seenDay === g.pop.day) return;
    if (s.tipDay === g.pop.day || R.rng() < 0.004) {
      const t = this.spawn();
      if (t) g.ui.toast(s.tipDay === g.pop.day ? 'There: the grey armored car, right on the bartender\'s schedule.' : 'A grey armored car rumbles past on its bank run. Two men up front.', 'warn');
    }
  };
  AR.draw = function (gx) {
    const v = this.truck();
    if (!v || v.removed) return;
    // bank stencil on the box, and the doors hanging open once cracked
    gx.save(); gx.translate(Math.round(v.x), Math.round(v.y)); gx.rotate(v.angle);
    gx.fillStyle = '#e4a92a'; gx.fillRect(-18, -2, 14, 4);
    if (v.armored.open) { gx.fillStyle = '#2a2a2a'; gx.fillRect(-v.model.w / 2 - 1, -7, 3, 14); gx.fillStyle = GREY; gx.fillRect(-v.model.w / 2 - 6, -10, 5, 3); gx.fillRect(-v.model.w / 2 - 6, 7, 5, 3); }
    gx.restore();
  };
  AR.init = function (g) {
    this.t = 0;
    if (this.wrapped) return;
    this.wrapped = true;
    const TP = R.Traffic.prototype, dmg = TP.damage, ex = TP.explode;
    // armour: a fraction of the damage, and it never blows
    TP.damage = function (v, amt, by, blast) {
      if (v && v.armored) { amt *= 0.4; if (v.hp - amt < 1) amt = Math.max(0, v.hp - 1); blast = false; }
      return dmg.call(this, v, amt, by, blast);
    };
    TP.explode = function (v, by) { if (v && v.armored) { v.burning = 0; if (!v.armored.dead) AR.disable(v); return; } return ex.call(this, v, by); };
    const PP = R.Player.prototype, ctx = PP.contextAction;
    PP.contextAction = function () { return AR.context(this) || ctx.call(this); };
    const GP = R.Game.prototype, tk = GP.tick;
    GP.tick = function (dt) { const r = tk.apply(this, arguments); if (this.traffic && this.player && this.pop && !this.ui.paused()) AR.update(dt); return r; };
    const rd = R.ring.draw;
    R.ring.draw = function (gx) { rd.apply(this, arguments); AR.draw(gx); };
    const U = R.UI.prototype, io = U.interiorOptions;
    U.interiorOptions = function (b) {
      const o = io.call(this, b), g2 = this.game, s = AR.state();
      if ((b.type === 'bar' || b.type === 'club') && s.tipDay !== g2.pop.day && g2.clock.hour() < 15) o.push({ label: 'Buy the armored car route', price: '$300', small: 'A bank guard drinks here. Today\'s run, in town, 9 to 4', fn: () => {
        if (!g2.player.pay(300)) return g2.ui.toast('$300 for the route.');
        s.tipDay = g2.pop.day; s.seenDay = -1;
        g2.ui.toast('Napkin, pencil: the route. The armored car comes through town today between nine and four. Stop it (it won\'t blow), drop the crew, open the back.', 'good');
      } });
      return o;
    };
  };
})();
