// RHAPSODY — white lightning. A general store sells a copper still (and the sugar and cornmeal
// to feed it). Haul it somewhere out in the country, away from town, and set it up: load it with
// mash and it cooks a jug every few hours, a fire flickering under the pot all night. Bars and
// liquor stores buy the jugs, no tax stamps asked about. But the revenuers from the ATF drive the
// back roads: an untended still gets found and smashed, and one you're standing next to gets
// visited by two men in suits with shotguns.
'use strict';
(function () {
  const TS = R.TILE, D = R.data;
  const G = () => R.game;
  const MS = (R.moonshine = {});
  const JUG = 35, MAX = 8, HOURS = 5;
  MS.state = function () { const st = R.shark.street(); return (st.shine = st.shine || { stills: [], jugs: 0, sold: 0, raids: 0 }); };
  const inTown = (x, y) => { const w = G().world; return w.cities.some((c) => x >= c.x0 - 8 && x <= c.x1 + 8 && y >= c.y0 - 8 && y <= c.y1 + 8); };
  MS.near = function (pl, r) { const s = this.state(); return s.stills.find((q) => Math.hypot(q.x * TS + 8 - pl.x, q.y * TS + 8 - pl.y) < TS * (r || 1.6)) || null; };
  MS.setUp = function () {
    const g = G(), pl = g.player, s = this.state(), tx = (pl.x / TS) | 0, ty = (pl.y / TS) | 0;
    if (inTown(tx, ty)) return g.ui.toast('Too close to town. Somebody would smell it. Head out into the country.', 'warn');
    pl.inv.tools.still--;
    s.stills.push({ x: tx, y: ty, mash: 0, jugs: 0, t: g.clock.t, id: (s.stills.length ? s.stills[s.stills.length - 1].id + 1 : 1) });
    g.audio.sfx('equip');
    g.ui.toast('Copper pot, worm, a barrel and a fire pit. Load it with mash and it\'ll cook a jug every few hours.', 'good');
  };
  MS.menu = function (st) {
    const g = G(), pl = g.player, s = this.state();
    const mash = pl.inv.tools.mash || 0;
    g.ui.choice('Your still', [
      { label: `Collect the jugs (${st.jugs})`, small: `${s.jugs} jugs in your trunk already`, fn: () => { if (!st.jugs) return g.ui.toast('Nothing\'s come through yet.'); s.jugs += st.jugs; pl.inv.loot.moonshine = s.jugs; g.ui.toast(`${st.jugs} jugs of white lightning. Bars will take them.`, 'good'); st.jugs = 0; } },
      { label: `Load it with mash (${st.mash}/${MAX} · you carry ${mash})`, small: 'A sack of sugar and cornmeal per jug', fn: () => { const k = Math.min(mash, MAX - st.mash); if (!k) return g.ui.toast(mash ? 'It\'s full.' : 'You\'re out of mash. A general store sells it.', 'warn'); st.mash += k; pl.inv.tools.mash -= k; st.t = g.clock.t; g.ui.toast(`${k} batches of mash in the pot. Low and slow.`, 'good'); } },
      { label: 'Break it down', small: 'Pack the still up and take it with you', fn: () => { s.stills = s.stills.filter((q) => q !== st); pl.inv.tools.still = (pl.inv.tools.still || 0) + 1; s.jugs += st.jugs; pl.inv.loot.moonshine = s.jugs; } },
      { label: 'Leave it', fn: () => {} },
    ]);
  };
  MS.context = function (pl) {
    if (pl.inCar || pl.room || pl.carrying) return null;
    const st = this.near(pl);
    if (st) return { label: 'Your still', fn: () => this.menu(st) };
    if (pl.inv.tools.still > 0 && !this.near(pl, 20)) {
      const w = G().world, tx = (pl.x / TS) | 0, ty = (pl.y / TS) | 0;
      if (!inTown(tx, ty) && !w.isWater(tx, ty) && !R.data.roadTile[w.t(tx, ty)]) return { label: 'Set up the still', fn: () => this.setUp() };
    }
    return null;
  };
  MS.update = function (dt) {
    const g = G(), s = this.state(), pl = g.player;
    this.t = (this.t || 0) - dt;
    if (this.t > 0) return;
    this.t = 3;
    for (const st of s.stills) {
      while (st.mash > 0 && g.clock.t - st.t >= HOURS * 60) { st.mash--; st.jugs++; st.t += HOURS * 60; }
      if (st.mash <= 0) st.t = g.clock.t;
    }
    // the revenuers, once a day
    const day = g.pop.day;
    if (s.raidDay !== day && s.stills.length) {
      s.raidDay = day;
      const st = R.rng.pick(s.stills);
      if (R.rng() < 0.12 + s.stills.length * 0.04) {
        const here = Math.hypot(st.x * TS - pl.x, st.y * TS - pl.y) < TS * 30;
        if (!here) {
          s.stills = s.stills.filter((q) => q !== st); s.raids++;
          g.pop.addNews(g.world.cities[0].id, `ATF AGENTS SMASH MOONSHINE STILL in the county. "${st.jugs} jugs poured into the creek," says Agent Ness. No arrests.`);
          g.ui.toast('Word comes down the road: the revenuers found one of your stills and put an axe through it.', 'bad');
        } else {
          for (let k = 0; k < 2; k++) {
            const a = g.actors.makeHuman(st.x * TS + 8 + (k ? 60 : -60), st.y * TS + 50, { weapon: 'shotgun', arch: 'square', tag: 'revenuer', cash: 30, cop: true });
            if (!a) continue;
            a.strangerName = k ? 'Agent Ness' : 'Agent Pruitt'; a.hostile = true; a.keep = true; g.actors.setFight(a, pl);
          }
          g.ui.toast('Two men in suits and hats coming up the track, shotguns out. Revenuers!', 'bad');
          g.audio.sfx('alarm');
        }
      }
    }
  };
  MS.draw = function (gx) {
    const g = G(), s = this.state(), t = g.clock.real;
    for (const st of s.stills) {
      const x = st.x * TS + 8, y = st.y * TS + 8;
      gx.fillStyle = '#1b1410'; gx.fillRect(x - 7, y - 11, 11, 12);
      gx.fillStyle = '#b8642a'; gx.fillRect(x - 6, y - 10, 9, 9); gx.fillStyle = '#e0904a'; gx.fillRect(x - 5, y - 9, 3, 6);
      gx.fillStyle = '#8a4a1a'; gx.fillRect(x - 2, y - 14, 2, 4); gx.fillRect(x, y - 14, 8, 1); gx.fillRect(x + 7, y - 14, 1, 8);
      gx.fillStyle = '#5a3a1a'; gx.fillRect(x + 5, y - 6, 6, 7); gx.fillStyle = '#3a2410'; gx.fillRect(x + 5, y - 4, 6, 1);
      if (st.mash > 0) { gx.fillStyle = Math.floor(t * 8) % 2 ? '#ff9a3a' : '#ffd060'; gx.fillRect(x - 4, y + 1, 5, 2); gx.fillStyle = 'rgba(200,200,200,0.4)'; gx.fillRect(x - 1, y - 18 - (Math.floor(t * 3) % 4), 2, 2); }
    }
  };
  MS.init = function (g) {
    if (this.wrapped) return;
    this.wrapped = true;
    D.loot.moonshine = D.loot.moonshine || { name: 'Jug of Moonshine', v: 0 };
    const PP = R.Player.prototype, ctx = PP.contextAction;
    PP.contextAction = function () { return MS.context(this) || ctx.call(this); };
    const GP = R.Game.prototype, tk = GP.tick;
    GP.tick = function (dt) { const r = tk.apply(this, arguments); if (this.pop && this.player && !this.ui.paused()) MS.update(dt); return r; };
    const rd = R.ring.draw;
    R.ring.draw = function (gx) { rd.apply(this, arguments); if (MS.state().stills.length) MS.draw(gx); };
    const U = R.UI.prototype, io = U.interiorOptions;
    U.interiorOptions = function (b) {
      const o = io.call(this, b), g2 = this.game, pl = g2.player, s = MS.state();
      if (b.type === 'general') {
        o.push({ label: 'Copper still', price: '$250', small: 'For "making perfume". Set it up out in the country', fn: () => { if (!pl.pay(250)) return g2.ui.toast('$250.'); pl.inv.tools.still = (pl.inv.tools.still || 0) + 1; g2.audio.sfx('cash'); g2.ui.toast('A copper still, wrapped in a tarp. Set it up somewhere nobody goes.', 'good'); } });
        o.push({ label: 'Sugar and cornmeal (4 batches)', price: '$20', small: 'Mash for a still. The clerk doesn\'t ask', fn: () => { if (!pl.pay(20)) return g2.ui.toast('$20.'); pl.inv.tools.mash = (pl.inv.tools.mash || 0) + 4; g2.audio.sfx('cash'); } });
      }
      if ((b.type === 'bar' || b.type === 'liquor') && s.jugs > 0) o.push({ label: `Sell moonshine (${s.jugs} jugs)`, price: R.fmtMoney(s.jugs * JUG), small: 'The back door, cash, no tax stamps', fn: () => { const n = s.jugs; pl.addCash(n * JUG, true); s.sold += n; s.jugs = 0; pl.inv.loot.moonshine = 0; g2.audio.sfx('cash'); g2.ui.toast(`${n} jugs out the back door. ${R.fmtMoney(n * JUG)}.`, 'good'); } });
      return o;
    };
  };
})();
