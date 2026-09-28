// RHAPSODY — hotel rooms and real estate (loads after 19_interiors, which it extends).
// Rent a room at any hotel or motel and walk upstairs into your own suite: a bed to
// sleep and save in, a closet, a stash safe, a TV and a phone. Call the realtor (phone or
// any bank) for every property for sale on the coast. Safehouses are places to sleep,
// save and stash; businesses pay you every morning. Upgrade what you own with security
// and renovations.
'use strict';
(function () {
  const D = R.data, O = D.O, T = D.T, TS = R.TILE;
  const ES = (R.estate = {});
  D.btypes.suite = { name: 'Hotel Room', w: [1, 1], h: [1, 1], roof: ['#3a2a2a'], wall: ['#c8b8a0'], house: 1, fl: 0.6 };

  // ---------------------------------------------------------------- hotel rooms
  ES.rental = function (g) { const h = g.player.hotel; return h && h.until > g.clock.t ? h : null; };
  ES.suiteFor = function (g, hotel) {
    const w = g.world;
    let s = w.buildings.find((b) => b && b.suiteOf === hotel.id);
    if (!s) {
      s = { id: w.buildings.length, type: 'suite', suiteOf: hotel.id, x: hotel.x, y: hotel.y, w: 0, h: 0, face: hotel.face, city: hotel.city, cityId: hotel.cityId,
        door: hotel.door, out: hotel.out, roof: '#3a2a2a', wall: '#c8b8a0', name: `${hotel.name}, Room ${200 + (hotel.id % 60)}`, residents: [], workers: [], owner: null,
        hp: 100, burning: 0, destroyed: false, cash: 0, robbedDay: -9, burgledDay: -9, racket: 0, playerOwned: false, floors: 1, seedArt: hotel.seedArt + 5 };
      w.buildings.push(s);
    }
    const r = this.rental(g);
    s.playerOwned = !!(r && r.hid === hotel.id);
    return s;
  };
  ES.rent = function (g, hotel, nights) {
    const pl = g.player, price = nights >= 7 ? 80 : 15 * nights;
    if (!pl.pay(price)) return g.ui.toast(`That's ${R.fmtMoney(price)}.`, 'warn');
    const now = g.clock.t, checkout = (Math.floor(now / 1440) + nights) * 1440 + 11 * 60 + (g.clock.hour() >= 11 ? 1440 : 0);
    pl.hotel = { hid: hotel.id, until: checkout };
    g.audio.sfx('cash');
    g.ui.toast(`Room ${200 + (hotel.id % 60)} is yours for ${nights === 1 ? 'the night' : `${nights} nights`}. Checkout 11 AM.`, 'good');
    this.goUp(g, hotel);
  };
  ES.goUp = function (g, hotel) {
    g.ui.closeSheet();
    if (g.player.room) g.interiors.exit();
    const s = this.suiteFor(g, hotel);
    g.interiors.enter(s, 'normal');
  };
  // furnish the suite when it's built
  const IP = R.Interiors.prototype, baseBuild = IP.build;
  IP.build = function (b, slot) {
    const room = baseBuild.call(this, b, slot);
    if (b.type === 'suite') {
      const w = this.game.world, set = (x, y, o) => { w.obj[w.idx(room.x0 + x, room.y0 + y)] = o; };
      const rw = room.w, rh = room.h;
      for (let y = 2; y < rh - 1; y++) for (let x = 1; x < rw - 1; x++) { w.tile[w.idx(room.x0 + x, room.y0 + y)] = T.CARPET; w.obj[w.idx(room.x0 + x, room.y0 + y)] = 0; }
      room.staff.length = 0; room.seats.length = 0; room.extra.length = 0; room.beds.length = 0;
      set(rw - 3, 2, O.BED); set(rw - 2, 2, O.BED); set(rw - 3, 3, O.BED); set(rw - 2, 3, O.BED);
      set(rw - 4, 2, O.FLOORLAMP); set(1, 2, O.DRESSER); set(2, 2, O.SAFE); set(4, 2, O.TV);
      set(3, 4, O.SOFA); set(4, 4, O.SOFA); set(rw - 2, rh - 3, O.PHONE); set(1, rh - 2, O.PLANT); set(rw - 2, rh - 2, O.PLANT);
      for (let x = 5; x < rw - 4; x++) for (let y = 5; y < rh - 3; y++) w.tile[w.idx(room.x0 + x, room.y0 + y)] = T.WOOD;
      set(rw - 5, 6, O.TABLE); set(rw - 6, 6, O.CHAIR); set(rw - 4, 6, O.CHAIR); set(2, 5, O.RUG);
      room.extra.push({ x: room.x0 + 3, y: room.y0 + 6 });
      room.beds.push({ x: room.x0 + rw - 3, y: room.y0 + 3 });
    }
    return room;
  };

  // your own places: the closet and the stash
  const baseFA = IP.furnitureAction;
  IP.furnitureAction = function (fa) {
    const g = this.game, room = g.player.room;
    if (room && room.b.playerOwned) {
      const o = g.world.o(fa.x, fa.y);
      if (o === O.DRESSER) return { label: 'Your closet', fn: () => R.openWardrobe('tailor') };
      if (o === O.SAFE) return { label: 'Your stash', fn: () => ES.openStash(g) };
    }
    return baseFA.call(this, fa);
  };
  ES.openStash = function (g) {
    const pl = g.player, st = (pl.stash = pl.stash || { cash: 0, loot: {} });
    const lootN = Object.values(pl.inv.loot).reduce((a, b) => a + (b || 0), 0), stashN = Object.values(st.loot).reduce((a, b) => a + (b || 0), 0);
    g.ui.choice(`Your stash · ${R.fmtMoney(st.cash)} and ${stashN} valuables inside`, [
      { label: `Stash your cash (${R.fmtMoney(Math.max(0, pl.cash - 20))})`, small: 'Keeps $20 on you. Cops and muggers can\'t touch the rest.', fn: () => { const n = Math.max(0, pl.cash - 20); pl.cash -= n; st.cash += n; g.audio.sfx('cash'); } },
      { label: `Take the cash (${R.fmtMoney(st.cash)})`, fn: () => { pl.addCash(st.cash); st.cash = 0; g.audio.sfx('cash'); } },
      { label: `Stash your valuables (${lootN})`, small: 'Watches, jewels, bonds, pelts...', fn: () => { for (const k in pl.inv.loot) { st.loot[k] = (st.loot[k] || 0) + (pl.inv.loot[k] || 0); pl.inv.loot[k] = 0; } } },
      { label: `Take the valuables (${stashN})`, fn: () => { for (const k in st.loot) { pl.inv.loot[k] = (pl.inv.loot[k] || 0) + st.loot[k]; st.loot[k] = 0; } } },
      { label: 'Close it', fn: () => {} },
    ]);
  };

  // ---------------------------------------------------------------- real estate
  const BIZ = ['bar', 'diner', 'laundry', 'arcade', 'barber', 'general', 'liquor', 'pawn', 'tailor', 'club', 'garage', 'butcher'];
  ES.isBiz = (b) => BIZ.includes(b.type);
  ES.price = function (b) {
    if (b.type === 'cabin') return 900;
    if (b.type === 'house') return 1600;
    return Math.round((1500 + b.w * b.h * 60) * (b.type === 'club' ? 1.6 : 1) * (0.7 + (b.city.prosperity || 50) / 120) / 50) * 50;
  };
  ES.income = function (b) {
    if (!this.isBiz(b)) return 0;
    const base = (b.w * b.h * 1.2 + 25) * ((b.city.prosperity || 50) / 60 + 0.4) * (b.type === 'club' ? 1.5 : 1);
    return Math.round(base * (b.reno ? 1.5 : 1));
  };
  ES.forSale = function (b) {
    if (!b || b.destroyed || b.playerOwned || b.type === 'suite' || !b.city || b.city.rural && b.type !== 'cabin') return false;
    if (b.type === 'house' || b.type === 'cabin') return !b.residents.length && !b.fromLot;
    return this.isBiz(b) && b.workers.length > 0;
  };
  ES.buy = function (g, b, remote) {
    const pl = g.player, price = Math.round(this.price(b) * (remote ? 1.1 : 1));
    if (this.isBiz(b)) {
      const owner = g.pop.people[b.owner];
      const willing = !owner || !owner.alive || owner.opinion > 30 || owner.fear > 60 || remote;
      if (!willing) return g.ui.toast('The owner won\'t sell to you. Get them to like you, or fear you.', 'warn');
    }
    if (!pl.pay(price)) return g.ui.toast(`You need ${R.fmtMoney(price)}.`, 'warn');
    b.playerOwned = true;
    if (!pl.properties.includes(b.id)) pl.properties.push(b.id);
    pl.stats.props = (pl.stats.props || 0) + 1;
    if (this.isBiz(b)) { b.racket = 1; b.racketFamily = pl.family; b.racketDue = 0; }
    g.audio.sfx('promote');
    g.pop.addNews(b.cityId, `${b.name} changes hands. New owner wears a fedora.`);
    g.ui.story('SOLD', `${b.name} in ${b.city.name} is yours.\n\n${this.isBiz(b) ? `It pays about ${R.fmtMoney(this.income(b))} every morning.` : 'Sleep and save there any time. The safe is your stash.'}${remote ? '\n\n(The realtor took a 10% cut.)' : ''}`);
    g.miniDirty = true;
  };
  ES.openRealtor = function (g) {
    const ui = g.ui, pl = g.player;
    const list = g.world.buildings.filter((b) => this.forSale(b)).sort((a, b) => (a.cityId === b.cityId ? this.price(a) - this.price(b) : a.cityId < b.cityId ? -1 : 1));
    const here = g.world.cityAt((pl.x / TS) | 0, (pl.y / TS) | 0);
    const pick = list.filter((b) => !here || b.city === here).slice(0, 14).concat(list.filter((b) => here && b.city !== here && (b.type === 'cabin' || this.isBiz(b))).slice(0, 6));
    const opts = pick.map((b) => ({ label: `${b.name} (${b.city.name})`, small: `${D.btypes[b.type].name}${this.isBiz(b) ? ` · ~${R.fmtMoney(this.income(b))}/day` : ' · safehouse'}`, price: R.fmtMoney(this.price(b)), fn: () => ui.choice(b.name, [
      { label: `Buy it over the phone (${R.fmtMoney(Math.round(this.price(b) * 1.1))})`, small: 'The realtor takes 10%. No haggling with the owner.', fn: () => this.buy(g, b, true) },
      { label: 'Mark it on my map', fn: () => { g.waypoint = { x: b.out.x * TS + 8, y: b.out.y * TS + 8 }; ui.toast(`Route set to ${b.name}.`, 'good'); } },
      { label: 'Back', fn: () => this.openRealtor(g) },
    ]) }));
    const mine = pl.properties.map((id) => g.world.buildings[id]).filter((b) => b && !b.destroyed);
    if (mine.length) opts.unshift({ label: `My properties (${mine.length})`, small: `${R.fmtMoney(mine.reduce((a, b) => a + this.income(b), 0))} a day`, cls: 'go', fn: () => this.openMine(g) });
    if (!opts.length) opts.push({ label: 'Nothing on the market right now.', fn: () => {} });
    ui.choice('Brass Coast Realty: listings', opts);
  };
  ES.openMine = function (g) {
    const ui = g.ui, pl = g.player;
    const mine = pl.properties.map((id) => g.world.buildings[id]).filter((b) => b && !b.destroyed);
    ui.choice('My properties', mine.map((b) => ({ label: `${b.name} (${b.city.name})`, small: `${this.isBiz(b) ? `${R.fmtMoney(this.income(b))}/day` : 'Safehouse'}${b.sec ? ' · alarm' : ''}${b.reno ? ' · renovated' : ''}`, fn: () => ui.choice(b.name, [
      { label: 'Route me there', fn: () => { g.waypoint = { x: b.out.x * TS + 8, y: b.out.y * TS + 8 }; } },
      b.sec ? { label: 'Alarm system installed', fn: () => {} } : { label: 'Install an alarm system', small: 'Burglars and robbers leave it alone', price: '$400', fn: () => { if (!pl.pay(400)) return ui.toast('$400.', 'warn'); b.sec = 1; ui.toast('Bells, wires, a sticker on the window.', 'good'); } },
      this.isBiz(b) ? (b.reno ? { label: 'Renovated', fn: () => {} } : { label: 'Renovate', small: 'Half again as much money every day', price: '$600', fn: () => { if (!pl.pay(600)) return ui.toast('$600.', 'warn'); b.reno = 1; ui.toast('New paint, new neon, new customers.', 'good'); } }) : { label: 'Your stash is in the safe inside', fn: () => {} },
      { label: 'Back', fn: () => this.openMine(g) },
    ]) })).concat([{ label: 'Back to the listings', fn: () => this.openRealtor(g) }]));
  };
  // every morning: the businesses pay, rentals check out
  ES.daily = function (g) {
    const pl = g.player;
    let total = 0;
    for (const id of pl.properties || []) { const b = g.world.buildings[id]; if (b && !b.destroyed && this.isBiz(b)) { total += this.income(b); b.racketDue = 0; } }
    if (total) { pl.addCash(total); g.ui.toast(`Your businesses made ${R.fmtMoney(total)} yesterday.`, 'good'); }
    if (pl.hotel && pl.hotel.until <= g.clock.t) { const h = g.world.buildings[pl.hotel.hid]; pl.hotel = null; if (h) { const s = g.world.buildings.find((b) => b && b.suiteOf === h.id); if (s) s.playerOwned = false; g.ui.toast(`You've checked out of ${h.name}.`); } }
  };
  const JD = R.Jobs.prototype.daily;
  R.Jobs.prototype.daily = function () { JD.call(this); ES.daily(this.game); };

  // menus: the hotel desk, the bank, the phone
  const U = R.UI.prototype, baseOpts = U.interiorOptions;
  U.interiorOptions = function (b) {
    const g = this.game, opts = baseOpts.call(this, b);
    const add = (o) => { const li = opts.findIndex((x) => /^(Leave|Done)$/.test(x.label)); opts.splice(li >= 0 ? li : opts.length, 0, o); };
    if (b.type === 'hotel' || b.type === 'motel') {
      const i = opts.findIndex((o) => /^Rent a room/.test(o.label));
      if (i >= 0) opts.splice(i, 1);
      const r = ES.rental(g);
      if (r && r.hid === b.id) add({ label: `Go up to your room`, small: `Room ${200 + (b.id % 60)} · checkout 11 AM, day ${Math.floor(r.until / 1440) + 1}`, cls: 'go', fn: () => ES.goUp(g, b) });
      else {
        add({ label: 'Rent a room for the night', small: 'Your own room: bed, closet, stash, TV', price: '$15', cls: 'go', fn: () => ES.rent(g, b, 1) });
        add({ label: 'Rent a room for the week', small: 'Seven nights for the price of five and a bit', price: '$80', fn: () => ES.rent(g, b, 7) });
      }
    }
    if (b.type === 'bank') add({ label: 'Property listings', small: 'Brass Coast Realty has a desk here', fn: () => ES.openRealtor(g) });
    return opts;
  };
})();
