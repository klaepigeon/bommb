// RHAPSODY — the other families are working too. Their collectors lean on people in the
// street for money owed to somebody else's shark; step in, pay it off, or tell them the
// block is yours now. Out on the highways their crews stop trucks and unload them into
// a van, and a man with a gun and some nerve can rob the robbers.
'use strict';
(function () {
  const D = R.data, TS = R.TILE;
  const G = () => R.game;
  const RV = (R.rivals = { scene: null, t: 60 });
  const LINES = {
    shake: ['Mr. {D} says you\'re late. Again.', 'Where\'s the money, {N}?', 'You think we forget? We don\'t forget.', 'Friday, you said. It\'s Tuesday.'],
    beg: ['Please! I\'ll have it tomorrow!', 'I got kids, man!', 'Not the face, not the face!', 'I swear on my mother!'],
    leave: ['Next week. All of it.', 'Don\'t make me come back.', 'Tell your wife I said hi.'],
    crew: ['Keep driving, pal.', 'Nothing to see here.', 'You didn\'t see nothing.', 'Move along before you get hurt.'],
  };
  const fill = (s, h) => s.replace('{N}', h && h.person ? h.person.first : 'pal').replace('{D}', RV.scene ? G().jobs.donName(RV.scene.fam) : 'the boss');
  const pick = (a) => a[(Math.random() * a.length) | 0];

  RV.rivalOf = function (city) {
    const g = G(), pl = g.player;
    const f = city && city.def && city.def.family;
    if (f && f !== pl.family) return f;
    const fams = D.cities.map((c) => c.family).filter((x) => x !== pl.family);
    return fams[(Math.random() * fams.length) | 0];
  };
  RV.goon = function (x, y, fam, tag, weapon) {
    const g = G();
    const h = g.actors.makeHuman(x, y, { arch: 'tough', tag, weapon, cash: 40 + ((Math.random() * 80) | 0) });
    h.keep = true; h.rivalFam = fam; h.strangerName = `${fam} ${tag}`; h.tr.brave = 0.85;
    h.look.hatKind = 'fedora'; h.look.hatCol = '#2a1a12';
    h.weaponOut = false;
    return h;
  };

  // ---------------------------------------------------------------- scenes
  RV.update = function (dt) {
    const g = G(), pl = g.player, w = g.world;
    const sc = this.scene;
    if (sc) return this.run(g, sc, dt);
    this.t -= dt;
    if (this.t > 0) return;
    this.t = 70 + Math.random() * 80;
    if (pl.room || pl.inCar && pl.inCar.speed > 40 || g.law.incident || (R.opening && R.opening.active) || g.calm() < 0.5) return;
    const city = w.cityAt((pl.x / TS) | 0, (pl.y / TS) | 0);
    if (city && Math.random() < 0.5) this.collector(g, city);
    else if (!city && Math.random() < 0.35) this.crew(g);
  };
  RV.collector = function (g, city) {
    const pl = g.player;
    const victim = g.actors.near(pl.x, pl.y, TS * 12).find((a) => a.kind === 'h' && !a.dead && !a.inCar && !a.cop && !a.crew && a.person && !a.person.isDon && a.state !== 'fight' && !a.hostile && !a.keep && (a.person.wealth || 30) < 50 && R.dist(a.x, a.y, pl.x, pl.y) > TS * 3);
    if (!victim) return;
    const sp = g.world.findNear((victim.x / TS) | 0, (victim.y / TS) | 0, 7, 11, (x, y) => !g.world.solidPed(x, y) && !g.world.isWater(x, y));
    if (!sp || g.cam.onScreen(sp.x * TS + 8, sp.y * TS + 8, 10)) return;
    const fam = this.rivalOf(city);
    const c = this.goon(sp.x * TS + 8, sp.y * TS + 8, fam, 'collector', 'knuckles');
    c.rivalCollector = true;
    victim.keep = true;
    this.scene = { kind: 'collect', fam, c, v: victim, stage: 'walk', t: 0, owed: 60 + ((victim.person.wealth || 20) * 3) | 0 };
  };
  RV.crew = function (g) {
    const pl = g.player, w = g.world;
    const s = w.findNear((pl.x / TS) | 0, (pl.y / TS) | 0, 14, 22, (x, y) => D.roadTile[w.t(x, y)] && !w.cityAt(x, y) && D.roadTile[w.t(x + 1, y)] && D.roadTile[w.t(x - 1, y)]);
    if (!s || g.cam.onScreen(s.x * TS + 8, s.y * TS + 8, 40)) return;
    const fam = this.rivalOf(null);
    const truck = g.traffic.make('truck', s.x * TS + 8, s.y * TS + 8, 0, { parked: true, keep: true, locked: false });
    if (R.hijack) R.hijack.load(truck, true);
    truck.rivalLoad = fam; truck.hotwired = true;
    const van = g.traffic.make('van', s.x * TS + 8 + 60, s.y * TS + 8, 0, { parked: true, keep: true, locked: true });
    const men = [0, 1].map((i) => { const h = this.goon(truck.x + 20 + i * 14, truck.y + 16, fam, 'hijacker', i ? 'shotgun' : 'revolver'); h.crewTruck = truck; return h; });
    this.scene = { kind: 'crew', fam, truck, van, men, t: 0, warned: false };
    if (R.hijack) g.pop.addNews((w.cityAt(s.x, s.y) || { id: 'port' }).id, `Truckers report ${fam}-connected men stopping rigs on the county highways. Police "are aware".`);
  };

  RV.run = function (g, sc, dt) {
    const pl = g.player;
    sc.t += dt;
    if (sc.kind === 'collect') {
      const { c, v } = sc;
      if (!c || c.dead || c.removed || !v || v.dead || v.removed || sc.t > 60) return this.end();
      if (c.state === 'fight' || c.hostile) { if (sc.stage !== 'fight') { sc.stage = 'fight'; v.keep = false; if (v.state !== 'flee') g.actors.setFlee(v, c, 5); } if (sc.t > 50) this.end(); return; }
      const d = R.dist(c.x, c.y, v.x, v.y);
      if (sc.stage === 'walk') { if (d > 14) { g.actors.goTo(c, (v.x / TS) | 0, (v.y / TS) | 0, { near: 1 }); v.state = 'idle'; v.timer = 3; } else { sc.stage = 'shake'; sc.t = 0; g.actors.say(c, fill(pick(LINES.shake), v)); } }
      if (sc.stage === 'shake') {
        v.state = 'cower'; v.timer = 3;
        if (sc.t > 2.6 && !sc.begged) { sc.begged = true; g.actors.say(v, pick(LINES.beg)); }
        if (sc.t > 4.5 && !sc.hit) { sc.hit = true; v.hp = Math.max(5, v.hp - 10); g.audio.sfx('punch', v.x, v.y); g.cam.shake(0.5); if (R.butcher) R.butcher.mark(v, 12, c, 'melee'); if (v.person) v.person.fear = Math.min(100, (v.person.fear || 0) + 30); }
        if (sc.t > 6.5) { sc.stage = 'leave'; sc.t = 0; g.actors.say(c, pick(LINES.leave)); const far = g.world.findNear((c.x / TS) | 0, (c.y / TS) | 0, 20, 30, (x, y) => !g.world.solidPed(x, y)); if (far) g.actors.goTo(c, far.x, far.y, {}); }
      }
      if (sc.stage === 'leave' && sc.t > 15) this.end();
      return;
    }
    if (sc.kind === 'crew') {
      const { truck, men } = sc;
      if (truck.removed || sc.t > 180 || R.dist(pl.x, pl.y, truck.x, truck.y) > TS * 60) return this.end();
      const alive = men.filter((h) => !h.dead && !h.removed);
      const near = R.dist(pl.x, pl.y, truck.x, truck.y) < TS * 6;
      for (const h of alive) {
        if (h.hostile) continue;
        h.ang = Math.atan2(pl.y - h.y, pl.x - h.x);
        if (near && !sc.warned) { sc.warned = true; g.actors.say(h, pick(LINES.crew)); h.weaponOut = true; }
        if (near && (pl.weaponOut || pl.inCar === truck)) { h.hostile = true; h.hostileLocked = true; h.weaponOut = true; g.actors.setFight(h, pl); }
      }
      if (!alive.length && !sc.cleared) { sc.cleared = true; g.ui.toast(`The ${sc.fam} crew is down. The truck's full, and nobody's going to report it stolen.`, 'good'); if (truck.cargo) truck.cargo.noReport = true; }
    }
  };
  RV.end = function () {
    const g = G(), sc = this.scene;
    this.scene = null;
    if (!sc) return;
    for (const h of [sc.c, ...(sc.men || [])]) if (h && !h.dead && !h.removed) { h.keep = false; }
    if (sc.v) sc.v.keep = false;
    for (const v of [sc.truck, sc.van]) if (v && !v.removed) v.keep = false;
  };

  // ---------------------------------------------------------------- stepping in
  RV.opts = function (h, opts) {
    const g = G(), pl = g.player, sc = this.scene;
    if (!h.rivalCollector || !sc || sc.kind !== 'collect' || sc.c !== h || sc.stage === 'fight') return;
    const i = Math.max(0, opts.findIndex((o) => /Goodbye/.test(o.label)));
    opts.splice(i, 0,
      { label: '"Leave them alone."', small: `They owe the ${sc.fam}s. Stepping in means a fight`, cls: 'bad', fn: () => { g.actors.say(h, 'This ain\'t your business, friend.'); h.hostile = true; h.hostileLocked = true; g.actors.setFight(h, pl); pl.rep.honor += 1; } },
      { label: `"What do they owe? I'll cover it." (${R.fmtMoney(sc.owed)})`, small: 'Honor +2. They\'ll remember who paid', fn: () => { if (!pl.pay(sc.owed)) return g.ui.toast('You don\'t have it.'); pl.rep.honor += 2; if (sc.v.person) sc.v.person.opinion = Math.min(100, (sc.v.person.opinion || 0) + 40); g.actors.say(h, 'Huh. Your funeral.'); g.actors.say(sc.v, 'God bless you. I won\'t forget this.'); sc.stage = 'leave'; sc.t = 0; } },
      { label: `"Tell Don ${g.jobs.donName(sc.fam)} this block is mine now."`, small: 'Infamy +2. The family takes it personally', fn: () => { pl.rep.infamy += 2; if (R.turf) { const t = R.turf.state(); if (t.grudge && t.grudge.hasOwnProperty(sc.fam)) t.grudge[sc.fam] += 12; } if (Math.random() < 0.5 + pl.rep.infamy / 200) { g.actors.say(h, 'Okay... okay. I\'ll tell him.'); sc.stage = 'leave'; sc.t = 0; } else { g.actors.say(h, 'Yours? Let\'s see about that.'); h.hostile = true; h.hostileLocked = true; g.actors.setFight(h, pl); } } },
    );
  };

  RV.init = function (g) {
    this.scene = null; this.t = 60;
    if (this.wrapped) return;
    this.wrapped = true;
    const tree = R.dialog.tree;
    R.dialog.tree = function (h) { const t = tree.call(this, h); if (t && t.options) RV.opts(h, t.options); return t; };
    // killing a family's men is noticed by the family
    const C = R.combat, kill = C.kill;
    C.kill = function (h, source, kind) {
      const r = kill.call(this, h, source, kind);
      if (h && h.rivalFam && source === G().player && R.turf) { const t = R.turf.state(); if (t.grudge && t.grudge.hasOwnProperty(h.rivalFam)) t.grudge[h.rivalFam] += 8; }
      return r;
    };
    // a load stolen from thieves doesn't get reported
    if (R.hijack) {
      const up = R.hijack.update;
      R.hijack.update = function (dt) {
        const v = G().player.inCar;
        if (v && v.cargo && v.cargo.noReport && !v.cargoCrime) v.cargoCrime = true;
        return up.call(this, dt);
      };
    }
    void g;
  };
})();
