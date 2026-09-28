// RHAPSODY — swag. Every box truck on the Brass Coast is carrying something: cigarettes,
// furs, Scotch, color TVs, frozen steaks. Pull the driver out, drive it somewhere quiet
// and a fence at a pawn shop or a garage will empty it for cash, no questions. The good
// loads come with a tip (from a bartender, a debtor, a driver who owes you) and a guard
// riding shotgun. The trucking company calls the police, and the papers call it a crime wave.
'use strict';
(function () {
  const TS = R.TILE;
  const G = () => R.game;
  const HJ = (R.hijack = {});
  const CARGO = [
    ['cigarettes', '400 cartons of Luckies', 700], ['scotch', '60 cases of Scotch', 900], ['furs', 'a rack of mink coats', 1600],
    ['tvs', '30 color TVs', 1300], ['steaks', 'frozen steaks', 450], ['suits', 'Italian suits, still in plastic', 800],
    ['hifi', 'hi-fi stereos and eight-tracks', 1000], ['razors', 'crates of razor blades', 350], ['perfume', 'French perfume', 1100], ['tires', 'whitewall tires', 500],
  ];
  const FENCE = { pawn: 0.45, garage: 0.35, butcher: 0.4 };

  HJ.state = function () { const st = R.shark.street(); return (st.swag = st.swag || { trucks: 0, earned: 0, tip: null }); };
  HJ.load = function (v, rich) {
    const c = R.rng.pick(rich ? CARGO.filter((c) => c[2] >= 900) : CARGO);
    v.cargo = { id: c[0], name: c[1], value: Math.round(c[2] * (rich ? 1.1 : 0.5 + R.rng() * 0.5)) };
  };

  // a tip: a truck parked at a truck stop outside town, a guard on it
  HJ.tip = function (from) {
    const g = G(), s = this.state(), w = g.world;
    const gas = w.buildings.filter((b) => b && !b.destroyed && b.type === 'gas');
    const b = R.rng.pick(gas.length ? gas : w.buildings.filter((b) => b && b.type === 'garage'));
    if (!b) return;
    s.tip = { bid: b.id, day: g.pop.day, until: g.pop.day + 2, from: from ? g.pop.name(from) : 'a bartender' };
    g.waypoint = { x: b.out.x * TS + 8, y: b.out.y * TS + 8 };
    g.ui.toast(`A load worth stealing sits at ${b.name} until day ${s.tip.until + 1}. One guard. Waypoint set.`, 'good');
  };
  HJ.barOpts = function (b, opts) {
    const g = G(), pl = g.player, s = this.state();
    if (b.type !== 'bar' && b.type !== 'diner' && b.type !== 'gas') return;
    if (s.tip && g.pop.day <= s.tip.until) return;
    opts.push({ label: 'Ask the regulars about trucks', small: '$120 for a tip on a good load', fn: () => { if (!pl.pay(120)) return g.ui.toast('Tips cost money.'); this.tip(null); } });
  };
  // stage the tipped truck when you get close
  HJ.stage = function () {
    const g = G(), s = this.state(), pl = g.player, t = s.tip;
    if (!t || t.spawned || g.pop.day > t.until) return;
    const b = g.world.buildings[t.bid];
    if (!b || R.dist(pl.x, pl.y, b.out.x * TS, b.out.y * TS) > TS * 30) return;
    const sp = g.world.findNear(b.out.x, b.out.y, 2, 7, (x, y) => !g.world.solidPed(x, y) && !g.world.isWater(x, y) && !g.world.solidPed(x + 1, y) && !g.world.solidPed(x - 1, y));
    if (!sp) return;
    t.spawned = true;
    const v = g.traffic.make('truck', sp.x * TS + 8, sp.y * TS + 8, 0, { parked: true, keep: true, locked: false });
    this.load(v, true);
    v.tipped = true;
    const gd = g.actors.makeHuman(v.x + 10, v.y + 16, { weapon: R.rng.pick(['shotgun', 'revolver']), arch: 'tough', tag: 'guard', cash: 40 });
    gd.keep = true; gd.strangerName = 'Guard'; gd.tr.brave = 0.95; gd.guarding = v; gd.state = 'idle'; gd.timer = 1e9;
    v.guard = gd;
  };

  // ---------------------------------------------------------------- while you drive it
  HJ.update = function (dt) {
    const g = G(), pl = g.player, s = this.state();
    this.t = (this.t || 0) - dt;
    if (this.t > 0) return;
    this.t = 0.5;
    this.stage();
    for (const v of g.traffic.list) if (v.modelId === 'truck' && v.cargo === undefined && !v.removed) { if (R.rng() < 0.7) this.load(v, false); else v.cargo = null; }
    const v = pl.inCar;
    // the guard notices
    for (const tv of g.traffic.list) {
      const gd = tv.guard;
      if (!gd || gd.dead || gd.hostile) continue;
      if (R.dist(pl.x, pl.y, tv.x, tv.y) < TS * 3.5 && (pl.inCar === tv || pl.weaponOut)) { gd.hostile = true; gd.hostileLocked = true; g.actors.setFight(gd, pl); g.actors.say(gd, 'Hey! Get away from the truck!'); }
    }
    if (!v || !v.cargo) return;
    if (!v.cargoSeen) {
      v.cargoSeen = true;
      g.ui.toast(`The truck's full of ${v.cargo.name}. A fence would pay about ${R.fmtMoney(v.cargo.value * 0.45)}. Park by a pawn shop or garage and get out.`, 'good');
      if (!v.cargoCrime) { v.cargoCrime = true; g.law.crime('hijack', v.x, v.y, {}); g.pop.addNews((g.world.cityAt((v.x / TS) | 0, (v.y / TS) | 0) || { id: 'port' }).id, `HIJACKERS STRIKE AGAIN. A truckload of ${v.cargo.name} vanished off the road yesterday. The Teamsters are "very upset."`); }
    }
  };
  // get out beside a fence and they'll unload it
  HJ.fenceNear = function (v) {
    const g = G();
    return g.world.buildings.find((b) => b && !b.destroyed && FENCE[b.type] && R.dist(v.x, v.y, b.out.x * TS + 8, b.out.y * TS + 8) < TS * 6);
  };
  HJ.exit = function (v) {
    const g = G(), pl = g.player, s = this.state();
    if (!v || !v.cargo) return;
    const b = this.fenceNear(v);
    if (!b) return;
    const pay = Math.round(v.cargo.value * FENCE[b.type] * (1 + g.jobs.rank() * 0.05));
    setTimeout(() => g.ui.choice(`${b.name}: the back door opens`, [
      { label: `Sell ${v.cargo.name} (${R.fmtMoney(pay)})`, small: 'Dirty cash. They\'ll strip the truck too', cls: 'go', fn: () => { pl.addCash(pay); s.trucks++; s.earned += pay; v.cargo = null; g.audio.sfx('cash'); g.ui.toast(`Unloaded in eleven minutes flat. ${R.fmtMoney(pay)}.`, 'good'); setTimeout(() => { if (!v.removed && pl.inCar !== v) g.traffic.remove(v); }, 4000); } },
      { label: 'Not here', fn: () => {} },
    ]), 200);
  };

  HJ.html = function () {
    const s = this.state(), g = G();
    if (!s.trucks && !s.tip) return '';
    let h = '<div class="sect">Swag</div>';
    if (s.tip && g.pop.day <= s.tip.until) { const b = g.world.buildings[s.tip.bid]; h += `<p>• A load at <b>${b ? b.name : '?'}</b> until day ${s.tip.until + 1}. One guard.</p>`; }
    if (s.trucks) h += `<p><small>${s.trucks} truckload${s.trucks > 1 ? 's' : ''} fenced for ${R.fmtMoney(s.earned)}.</small></p>`;
    return h;
  };

  HJ.init = function (g) {
    if (this.wrapped) return;
    this.wrapped = true;
    const TP = R.Traffic.prototype, ex = TP.exitVehicle;
    TP.exitVehicle = function (v, h) { const r = ex.call(this, v, h); if (h === this.game.player) HJ.exit(v); return r; };
    const U = R.UI.prototype, io = U.interiorOptions;
    U.interiorOptions = function (b) { const o = io.call(this, b); HJ.barOpts(b, o); return o; };
    const cj = R.campaign.jobsHtml;
    R.campaign.jobsHtml = function () { return cj.call(this) + HJ.html(); };
  };
})();
