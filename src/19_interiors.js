// RHAPSODY — walk-in interiors, like the original Port Hollow build. Rooms are stamped
// on demand into a hidden strip below the map, furnished by building type, and
// filled with the people the population sim says are inside right now.
'use strict';
(function () {
  const D = R.data, T = D.T, O = D.O, TS = R.TILE;
  const SLOT_W = 24, SLOT_H = 16, COLS = 26, ROWS = 4;

  const SIZES = {
    house: [14, 10], cabin: [12, 9], apartment: [14, 10], barn: [16, 11], bar: [18, 12], club: [20, 13], diner: [16, 10],
    bank: [20, 12], police: [20, 12], hospital: [20, 12], casino: [22, 13], church: [16, 13], social: [18, 12], garage: [18, 11],
    hotel: [16, 11], motel: [14, 10], arcade: [16, 10], laundry: [14, 9], barber: [12, 9], school: [20, 12], factory: [22, 13],
    warehouse: [22, 13], office: [18, 11],
  };
  const FLOOR = {
    bar: T.WOOD, club: T.CARPET, diner: T.TILEF, bank: T.CARPET, police: T.TILEF, hospital: T.TILEF, casino: T.CARPET, church: T.WOOD,
    social: T.CARPET, garage: T.CONCRETE, house: T.WOOD, cabin: T.WOOD, apartment: T.WOOD, barn: T.CONCRETE, factory: T.CONCRETE,
    warehouse: T.CONCRETE, arcade: T.CARPET, laundry: T.TILEF, barber: T.TILEF, school: T.WOOD, office: T.CARPET, hotel: T.CARPET, motel: T.WOOD,
    pharmacy: T.TILEF, general: T.TILEF, liquor: T.WOOD, pawn: T.WOOD, gunshop: T.WOOD, tailor: T.CARPET, butcher: T.TILEF, gas: T.TILEF,
  };

  const Int = (R.Interiors = function (game) {
    this.game = game;
    this.rooms = new Map(); // building id -> room
    this.slots = new Array(COLS * ROWS).fill(null);
    this.t = 0;
  });
  const P = Int.prototype;

  P.roomAt = function (tx, ty) {
    const w = this.game.world;
    if (ty < w.H) return null;
    const i = Math.floor((ty - w.H) / SLOT_H) * COLS + Math.floor((tx - 4) / SLOT_W);
    return this.slots[i] || null;
  };
  // outdoor spot that stands in for a position inside a room (for the law & the map)
  P.outside = function (x, y) {
    const r = this.roomAt((x / TS) | 0, (y / TS) | 0);
    if (!r) return { x, y };
    return { x: r.b.out.x * TS + 8, y: r.b.out.y * TS + 10 };
  };

  // ---------------------------------------------------------------- building rooms
  P.get = function (b) {
    let r = this.rooms.get(b.id);
    if (r) { r.used = performance.now(); return r; }
    let si = this.slots.indexOf(null);
    if (si < 0) {
      let old = 0;
      for (let i = 1; i < this.slots.length; i++) if (this.slots[i].used < this.slots[old].used) old = i;
      if (this.slots[old] === this.game.player.room) old = (old + 1) % this.slots.length;
      this.clearRoom(this.slots[old]);
      si = old;
    }
    r = this.build(b, si);
    this.slots[si] = r;
    this.rooms.set(b.id, r);
    return r;
  };
  P.clearRoom = function (r) {
    const w = this.game.world;
    for (let y = r.y0; y < r.y0 + SLOT_H; y++)
      for (let x = r.x0 - 1; x < r.x0 - 1 + SLOT_W; x++) {
        const i = w.idx(x, y);
        w.tile[i] = T.VOID; w.obj[i] = 0; w.bid[i] = 0; w.zone[i] = 0;
        w.markDirty(x, y);
      }
    this.rooms.delete(r.b.id);
    this.slots[r.slot] = null;
  };

  P.build = function (b, slot) {
    const w = this.game.world;
    const type = b.type;
    const [rw, rh] = SIZES[type] || [14, 10];
    const x0 = 4 + (slot % COLS) * SLOT_W + Math.floor((SLOT_W - 2 - rw) / 2) + 1;
    const y0 = w.H + Math.floor(slot / COLS) * SLOT_H + Math.floor((SLOT_H - rh) / 2);
    const floor = FLOOR[type] || T.TILEF;
    const room = { b, slot, x0, y0, w: rw, h: rh, staff: [], seats: [], beds: [], extra: [], searched: new Map(), used: performance.now(), don: null };
    const zone = b.city && !b.city.rural && b.city.idx >= 0 ? b.city.idx + 1 : 0;
    for (let y = 0; y < rh; y++)
      for (let x = 0; x < rw; x++) {
        const i = w.idx(x0 + x, y0 + y);
        const wall = y < 2 || x === 0 || x === rw - 1 || y === rh - 1;
        w.tile[i] = wall ? T.WALL : floor;
        w.obj[i] = 0;
        w.bid[i] = b.id;
        w.zone[i] = zone;
        w.markDirty(x0 + x, y0 + y);
      }
    const ex = Math.floor(rw / 2);
    w.tile[w.idx(x0 + ex, y0 + rh - 1)] = T.EXITMAT;
    room.exit = { x: x0 + ex, y: y0 + rh - 1 };
    room.entry = { x: x0 + ex, y: y0 + rh - 2 };
    room.center = { x: x0 + ex, y: y0 + Math.floor(rh / 2) };
    const rnd = R.mulberry(b.seedArt + 17);
    const set = (x, y, o) => {
      if (x < 1 || y < 2 || x > rw - 2 || y > rh - 2) return false;
      if (x === ex && y >= rh - 3) return false; // keep the doorway clear
      w.obj[w.idx(x0 + x, y0 + y)] = o;
      return true;
    };
    const floorAt = (x, y, t) => { if (x >= 1 && y >= 2 && x <= rw - 2 && y <= rh - 2) w.tile[w.idx(x0 + x, y0 + y)] = t; };
    const spot = (list, x, y) => list.push({ x: x0 + x, y: y0 + y });
    const counter = (y, xa, xb, regAt) => {
      for (let x = xa; x <= xb; x++) set(x, y, x === regAt ? O.REGISTER : O.COUNTER);
      for (let x = xa; x <= xb; x += 3) spot(room.staff, x, y - 1);
    };
    const tables = (ya, yb, step) => {
      for (let y = ya; y <= yb; y += 3)
        for (let x = 2; x < rw - 2; x += step) {
          if (Math.abs(x - ex) < 2) continue;
          if (set(x, y, O.TABLE)) { if (set(x - 1, y, O.CHAIR)) spot(room.seats, x - 1, y); if (set(x + 1, y, O.CHAIR)) spot(room.seats, x + 1, y); }
        }
    };
    const plants = () => { set(1, rh - 2, O.PLANT); set(rw - 2, rh - 2, O.PLANT); };
    const lamp = (x, y) => set(x, y, O.FLOORLAMP);
    switch (type) {
      case 'bar': {
        for (let x = 2; x <= rw - 6; x += 2) set(x, 2, O.SHELF);
        counter(4, 2, rw - 6, 3);
        for (let x = 2; x <= rw - 6; x += 2) { set(x, 5, O.STOOL); spot(room.seats, x, 5); }
        set(rw - 2, 2, O.JUKEBOX);
        if (rw >= 16) { set(rw - 4, rh - 4, O.POOL); set(rw - 3, rh - 4, O.POOL); }
        tables(7, rh - 3, 4);
        set(rw - 2, 5, O.PHONE);
        lamp(1, 6);
        break;
      }
      case 'club': {
        for (let y = 5; y <= rh - 4; y++) for (let x = 5; x <= rw - 6; x++) floorAt(x, y, T.DANCE);
        set(ex - 1, 2, O.DESK); set(ex, 2, O.DESK); set(ex + 1, 2, O.MIC); spot(room.staff, ex, 3);
        counter(3, 2, 5, 2);
        set(rw - 2, 3, O.SOFA); set(rw - 3, 3, O.SOFA); spot(room.seats, rw - 3, 4);
        set(1, rh - 3, O.SOFA); set(2, rh - 3, O.SOFA); spot(room.seats, 2, rh - 4);
        for (let y = 5; y <= rh - 4; y += 2) for (let x = 6; x <= rw - 7; x += 3) spot(room.extra, x, y);
        lamp(1, 3); lamp(rw - 2, rh - 3);
        break;
      }
      case 'diner': {
        set(2, 2, O.STOVE); set(3, 2, O.STOVE); set(4, 2, O.FRIDGE); set(rw - 3, 2, O.SHELF);
        counter(4, 2, rw - 4, rw - 4);
        for (let x = 2; x <= rw - 4; x += 2) { set(x, 5, O.STOOL); spot(room.seats, x, 5); }
        tables(7, rh - 3, 4);
        set(rw - 2, 4, O.JUKEBOX);
        break;
      }
      case 'bank': {
        set(ex, 2, O.VAULT); set(ex - 2, 2, O.SAFE); set(ex + 2, 2, O.SAFE);
        for (let x = 2; x <= rw - 3; x++) set(x, 5, x % 4 === 0 ? O.REGISTER : O.COUNTER);
        for (let x = 2; x <= rw - 3; x += 4) spot(room.staff, x, 4);
        set(2, 8, O.DESK); set(rw - 3, 8, O.DESK); spot(room.seats, 2, 9); spot(room.seats, rw - 3, 9);
        plants();
        spot(room.extra, ex + 2, rh - 3);
        break;
      }
      case 'police': {
        counter(rh - 5, ex - 2, ex + 2, ex);
        for (let x = 2; x <= 7; x++) set(x, 2, O.LOCKER);
        for (let y = 4; y <= rh - 7; y += 3) for (let x = 2; x <= 7; x += 3) { set(x, y, O.DESK); spot(room.staff, x, y + 1); }
        for (let y = 2; y <= 6; y++) set(rw - 7, y, O.BARS);
        set(rw - 5, 2, O.BED); set(rw - 5, 3, O.BED); set(rw - 3, 2, O.BED); set(rw - 3, 3, O.BED);
        set(rw - 2, rh - 3, O.PHONE);
        plants();
        break;
      }
      case 'hospital': {
        counter(rh - 5, ex - 2, ex + 2, -1);
        for (let x = 2; x <= rw - 3; x += 3) { set(x, 2, O.HOSPBED); set(x, 3, O.HOSPBED); }
        for (let x = 2; x <= rw - 3; x += 4) set(x, 6, O.CABINET);
        spot(room.staff, 4, 5); spot(room.staff, rw - 5, 5);
        plants();
        break;
      }
      case 'casino': {
        counter(3, ex - 3, ex + 3, ex);
        for (let x = 2; x <= rw - 3; x += 2) if (Math.abs(x - ex) > 4) { set(x, 2, O.SLOT); spot(room.seats, x, 3); }
        for (let y = 6; y <= rh - 3; y += 3) for (let x = 3; x <= rw - 4; x += 4) { if (Math.abs(x - ex) < 2) continue; set(x, y, O.CARDTABLE); spot(room.staff, x, y - 1); spot(room.seats, x, y + 1); }
        plants();
        break;
      }
      case 'church': {
        set(ex, 3, O.ALTAR); set(ex - 3, 2, O.PIANO); spot(room.staff, ex, 2);
        for (let y = 6; y <= rh - 3; y += 2) {
          for (let x = 2; x <= ex - 2; x++) set(x, y, O.PEW);
          for (let x = ex + 2; x <= rw - 3; x++) set(x, y, O.PEW);
          spot(room.seats, 3, y + 1); spot(room.seats, rw - 4, y + 1);
        }
        for (let y = 4; y <= rh - 2; y++) floorAt(ex, y, T.CARPET);
        break;
      }
      case 'social': {
        set(ex - 1, 3, O.DESK); set(ex, 3, O.DESK); set(ex + 1, 3, O.DESK);
        room.don = { x: x0 + ex, y: y0 + 2 };
        set(rw - 2, 2, O.SAFE); set(1 + 1, 2, O.BOOKCASE); set(3, 2, O.BOOKCASE);
        counter(6, 2, 5, 2);
        set(rw - 5, 7, O.CARDTABLE); spot(room.seats, rw - 5, 8); spot(room.seats, rw - 6, 7);
        set(rw - 3, rh - 3, O.SOFA); set(rw - 4, rh - 3, O.SOFA); spot(room.seats, rw - 4, rh - 4);
        spot(room.extra, ex - 2, 5); spot(room.extra, ex + 2, 5);
        set(2, rh - 3, O.BED); set(2, rh - 2, O.BED);
        set(rw - 2, 5, O.PHONE);
        lamp(1, 5);
        break;
      }
      case 'garage': {
        for (let x = 2; x <= 5; x++) set(x, 2, O.LOCKER);
        set(rw - 4, 2, O.DESK); counter(4, rw - 5, rw - 3, rw - 4);
        set(5, 6, O.LIFT); set(9, 6, O.LIFT);
        for (let k = 0; k < 4; k++) set(2 + rnd.int(0, 3), rh - 3 - rnd.int(0, 1), rnd() < 0.5 ? O.CRATE : O.BARREL);
        spot(room.staff, 5, 7); spot(room.staff, 9, 7);
        break;
      }
      case 'hotel': case 'motel': {
        counter(4, ex - 2, ex + 2, ex - 2);
        set(2, 7, O.SOFA); set(3, 7, O.SOFA); spot(room.seats, 2, 6); set(rw - 3, 7, O.SOFA); set(rw - 4, 7, O.SOFA);
        set(rw - 2, 2, O.BED); set(rw - 2, 3, O.BED); set(rw - 3, 2, O.DRESSER);
        set(2, 2, O.TV); plants();
        break;
      }
      case 'arcade': {
        counter(rh - 4, rw - 5, rw - 3, rw - 4);
        for (let x = 2; x <= rw - 3; x += 2) { set(x, 2, O.ARCADE); spot(room.seats, x, 3); }
        for (let x = 2; x <= rw - 7; x += 2) { set(x, 5, O.ARCADE); spot(room.extra, x, 6); }
        break;
      }
      case 'laundry': {
        for (let x = 2; x <= rw - 3; x++) set(x, 2, O.WASHER);
        for (let x = 2; x <= 5; x++) set(x, 5, O.WASHER);
        counter(rh - 4, rw - 5, rw - 3, rw - 4);
        set(rw - 6, 5, O.CHAIR); spot(room.seats, rw - 6, 5);
        break;
      }
      case 'barber': {
        for (let x = 2; x <= rw - 3; x += 3) { set(x, 3, O.BCHAIR); spot(room.seats, x, 4); spot(room.staff, x + 1, 3); }
        set(2, rh - 3, O.CHAIR); set(3, rh - 3, O.CHAIR); counter(rh - 3, rw - 4, rw - 3, rw - 3);
        break;
      }
      case 'school': {
        set(ex, 3, O.DESK); spot(room.staff, ex, 2);
        for (let y = 5; y <= rh - 3; y += 2) for (let x = 2; x <= rw - 3; x += 2) { if (Math.abs(x - ex) < 1) continue; set(x, y, O.DESK); spot(room.seats, x, y + 1); }
        set(1, 2, O.BOOKCASE); set(rw - 2, 2, O.BOOKCASE);
        break;
      }
      case 'factory': case 'warehouse': case 'barn': {
        for (let x = 2; x <= 6; x++) set(x, 2, O.LOCKER);
        set(rw - 3, 2, O.DESK); spot(room.staff, rw - 3, 3);
        for (let k = 0; k < 18; k++) { const x = rnd.int(2, rw - 3), y = rnd.int(4, rh - 3); set(x, y, rnd() < 0.6 ? O.CRATE : O.BARREL); }
        for (let k = 0; k < 4; k++) spot(room.staff, rnd.int(3, rw - 4), rnd.int(4, rh - 3));
        if (type === 'barn') { set(rw - 3, rh - 3, O.BED); set(rw - 3, rh - 2, O.BED); }
        break;
      }
      case 'office': {
        for (let y = 4; y <= rh - 3; y += 3) for (let x = 2; x <= rw - 3; x += 3) { set(x, y, O.DESK); spot(room.staff, x, y + 1); }
        set(1, 2, O.CABINET); set(2, 2, O.CABINET); set(rw - 2, 2, O.SAFE); plants();
        break;
      }
      case 'house': case 'cabin': case 'apartment': {
        // living room | bedroom split by a wall with a gap
        const split = Math.floor(rw * 0.58);
        for (let y = 2; y <= rh - 2; y++) if (y !== 4 && y !== 5) { w.tile[w.idx(x0 + split, y0 + y)] = T.WALL; }
        set(2, 2, O.FRIDGE); set(3, 2, O.STOVE); set(4, 2, O.CABINET);
        set(2, 5, O.TABLE); set(3, 5, O.CHAIR); spot(room.seats, 3, 5);
        set(split - 2, 2, O.TV); set(split - 3, 5, O.SOFA); set(split - 2, 5, O.SOFA); spot(room.seats, split - 3, 6);
        floorAt(split - 3, 7, T.CARPET); floorAt(split - 2, 7, T.CARPET);
        set(2, rh - 3, O.BOOKCASE); set(split - 1, rh - 2, O.PLANT);
        const nb = Math.max(1, Math.min(3, Math.ceil(b.residents.length / 2)));
        for (let k = 0; k < nb; k++) { const bx = split + 2 + k * 2; if (bx > rw - 2) break; set(bx, 2, O.BED); set(bx, 3, O.BED); room.beds.push({ x: x0 + bx, y: y0 + 3 }); }
        set(rw - 2, rh - 3, O.DRESSER); set(split + 1, rh - 2, O.DRESSER);
        set(split - 1, 2, O.PHONE);
        break;
      }
      default: {
        // shops: counter top-right, aisles of shelves
        counter(3, rw - 6, rw - 2, rw - 5);
        const shelfType = type === 'gunshop' ? O.GUNRACK : type === 'tailor' ? O.RACK : type === 'butcher' ? O.FRIDGE : type === 'pharmacy' ? O.CABINET : O.SHELF;
        for (let y = 5; y <= rh - 3; y += 2) for (let x = 2; x <= rw - 7; x++) if (x % 5 !== 4) set(x, y, shelfType);
        if (type === 'gunshop') for (let x = 2; x <= rw - 7; x++) set(x, 2, O.GUNRACK);
        if (type === 'pawn') { set(2, 2, O.CABINET); set(3, 2, O.TV); set(4, 2, O.SAFE); }
        if (type === 'gas' || type === 'general' || type === 'liquor') { set(2, 2, O.FRIDGE); set(3, 2, O.FRIDGE); }
        for (let k = 0; k < 3; k++) spot(room.extra, rnd.int(2, rw - 7), 4 + rnd.int(0, 1) * 2);
        break;
      }
    }
    // everybody else can stand around on free floor
    for (let k = 0; k < 8; k++) {
      const x = rnd.int(2, rw - 3), y = rnd.int(3, rh - 3);
      if (!w.solidPed(x0 + x, y0 + y)) spot(room.extra, x, y);
    }
    return room;
  };

  // ---------------------------------------------------------------- entering & leaving
  P.doorPrompt = function (b) {
    const g = this.game, ui = g.ui, pl = g.player;
    const bt = D.btypes[b.type];
    const open = ui.isOpen(b) || b.playerOwned;
    const home = !!bt.house && !bt.hours;
    if (b.playerOwned) return this.enter(b, 'normal');
    if (home) {
      const occ = g.life.occupants(b);
      const night = g.clock.isNight();
      const opts = [];
      if (!b.residents.length && (b.type === 'house' || b.type === 'cabin')) {
        const price = b.type === 'cabin' ? 900 : 1600;
        opts.push({ label: `Buy this place (${R.fmtMoney(price)})`, small: 'A safehouse: sleep and save any time.', fn: () => { if (!pl.pay(price)) return ui.toast("You can't afford it.", 'warn'); b.playerOwned = true; pl.properties.push(b.id); ui.toast('The keys are yours.', 'good'); this.enter(b, 'normal'); } });
        opts.push({ label: 'Look around', fn: () => this.enter(b, 'normal') });
      } else {
        if (occ.length && !night) opts.push({ label: 'Knock', fn: () => {
          const best = occ.reduce((a, p) => (p.opinion + p.fam * 8 > a.opinion + a.fam * 8 ? p : a), occ[0]);
          if (best.opinion >= 15 || best.fam >= 3 || best.fear > 60) { ui.toast(`${best.met ? best.first : 'Someone'}: "Come on in."`, 'good'); this.enter(b, 'guest'); }
          else ui.toast(`${best.met ? best.first : 'A voice'}: "${R.rng.pick(['Who is it? Go away.', 'We don\'t want any!', 'I\'m calling the cops if you don\'t leave.'])}"`, 'warn');
        } });
        opts.push({ label: 'Break in', small: occ.length ? (night ? `${occ.length} asleep inside. Move quietly.` : `${occ.length} inside and awake!`) : 'Nobody home right now.', fn: () => this.breakIn(b) });
      }
      opts.push({ label: 'Leave', fn: () => {} });
      return ui.choice(b.name, opts);
    }
    if (!open) {
      const opts = [];
      if (b.type !== 'police' && b.type !== 'hospital') opts.push({ label: 'Break in', small: pl.inv.tools.lockpick ? 'Uses a lockpick. Quiet, but someone may see.' : 'No lockpick: you\'ll have to force it. Noisy.', fn: () => this.breakIn(b) });
      opts.push({ label: 'Walk away', fn: () => {} });
      return ui.choice(`${b.name}: closed (opens ${bt.hours[0]}:00)`, opts);
    }
    this.enter(b, 'normal');
  };
  P.breakIn = function (b) {
    const g = this.game, pl = g.player;
    if (pl.inv.tools.lockpick) { if (R.rng() < 0.5) pl.inv.tools.lockpick--; g.audio.sfx('reload'); }
    else { g.actors.noise(pl.x, pl.y, TS * 6, 'scream', pl); g.audio.sfx('glass'); }
    g.law.crime('burglary', pl.x, pl.y, { minor: false });
    this.enter(b, 'breakin');
  };

  P.enter = function (b, mode) {
    const g = this.game, pl = g.player;
    if (pl.inCar) return;
    const room = this.get(b);
    room.mode = mode || 'normal';
    pl.room = room;
    pl.place(room.entry.x * TS + 8, room.entry.y * TS + 8);
    pl.dir = 0;
    pl.ang = -Math.PI / 2;
    pl.knockV = null;
    g.cam.x = pl.x; g.cam.y = pl.y;
    // the street empties while you're indoors
    for (const a of g.actors.list) if (!a.room && !a.crew) g.actors.remove(a);
    for (const c of pl.crew) if (!c.dead) { c.x = pl.x + 10; c.y = pl.y; c.room = room; }
    this.populate(room);
    R.props.furnishRoom(room);
    g.audio.sfx('door');
    g.ui.banner(b.name, room.mode === 'breakin' ? 'Breaking in' : D.btypes[b.type].name);
    if (b.type === 'bar' || b.type === 'club' || b.type === 'casino' || b.type === 'diner') g.audio.indoorMusic(b.type === 'club' ? 1 : b.type === 'bar' ? 2 : 0);
    const inc = g.law.incident;
    if (inc && inc.state === 'pursuit') { room.copsT = 7; g.ui.toast('They saw you go in. They\'ll be through that door any second.', 'warn'); }
    else if (inc) g.ui.toast('Lying low inside. The search clock runs faster while you hide.', 'good');
  };
  P.exit = function () {
    const g = this.game, pl = g.player, room = pl.room;
    if (!room) return;
    for (const a of g.actors.list) if (a.room === room && !a.crew) { if (a.person && a.person.alive) a.person.place = 'b:' + room.b.id; g.actors.remove(a); }
    const b = room.b;
    pl.room = null;
    pl.place(b.out.x * TS + 8, b.out.y * TS + 10);
    pl.dir = 2;
    pl.ang = Math.PI / 2;
    for (const c of pl.crew) if (!c.dead) { c.room = null; c.x = pl.x + 10; c.y = pl.y + 4; }
    g.cam.x = pl.x; g.cam.y = pl.y;
    g.audio.indoorMusic(null);
    g.audio.sfx('door');
  };

  P.spawnAt = function (room, p, s, opts) {
    const g = this.game;
    const h = p ? g.life.spawnPerson(p, s.x * TS + 8, s.y * TS + 8) : g.actors.makeHuman(s.x * TS + 8, s.y * TS + 8, opts || {});
    if (!h) return null;
    h.room = room;
    h.keep = true;
    h.destKey = 'b:' + room.b.id;
    h.spot = { x: s.x, y: s.y, city: room.b.city, kind: 'room' };
    h.state = 'idle';
    h.timer = 1 + R.rng() * 4;
    h.stay = !!(opts && opts.stay);
    return h;
  };
  P.populate = function (room) {
    const g = this.game, b = room.b;
    const bt = D.btypes[b.type];
    const occ = g.life.occupants(b).slice(0, 12);
    const night = g.clock.isNight() || g.clock.hour() < 7;
    const pick = (list, used) => { const free = list.filter((s) => !used.has(s.x * 1000 + s.y)); const s = free.length ? R.rng.pick(free) : R.rng.pick(room.extra.length ? room.extra : [room.center]); used.add(s.x * 1000 + s.y); return s; };
    const used = new Set();
    let staffed = false;
    for (const p of occ) {
      let h;
      if (p.isDon && room.don) h = this.spawnAt(room, p, room.don, { stay: true });
      else if (p.work === b.id && room.staff.length) { h = this.spawnAt(room, p, pick(room.staff, used), { stay: true }); staffed = true; }
      else if (bt.house && !bt.hours && night && room.beds.length) {
        h = this.spawnAt(room, p, pick(room.beds, used));
        if (h) { h.state = 'sleep'; h.timer = 1e9; }
      } else h = this.spawnAt(room, p, pick(room.seats.length ? room.seats.concat(room.extra) : room.extra, used));
      if (h && h.stay) h.staff = true;
    }
    // businesses always have someone at the counter while open
    if (!staffed && bt.hours && room.staff.length && room.mode !== 'breakin' && g.ui.isOpen(b)) {
      const role = Object.keys(bt.jobs || { clerk: 1 })[0];
      const h = this.spawnAt(room, null, room.staff[0], { stay: true, role, city: b.cityId, cop: role === 'cop' });
      if (h) { h.staff = true; h.role = role; }
    }
    // a lively crowd at night spots
    if ((b.type === 'bar' || b.type === 'club' || b.type === 'casino') && room.mode !== 'breakin') {
      const n = g.clock.hour() > 19 || g.clock.hour() < 3 ? R.rng.int(2, 5) : R.rng.int(0, 2);
      for (let k = 0; k < n; k++) {
        const h = this.spawnAt(room, null, pick(room.extra.concat(room.seats), used), { arch: R.rng.pick(['flirt', 'friendly', 'gossip', 'tough', 'eccentric']), city: b.cityId });
        if (h && b.type === 'club' && R.rng() < 0.7) { h.state = 'perform'; h.role = 'dancer'; h.timer = 20 + R.rng() * 30; }
      }
    }
    // the police station has cops, the hospital has a nurse
    if (b.type === 'police' && room.mode !== 'breakin') for (let k = 0; k < 2; k++) { const h = this.spawnAt(room, null, pick(room.staff, used), { cop: true, role: 'cop', city: b.cityId, stay: true }); if (h) h.look = g.pop.makeLook(R.mulberry(R.rng.int(0, 1e9)), { fem: R.rng.chance(0.3), age: 35, role: 'cop', city: b.cityId }); }
  };

  // ---------------------------------------------------------------- per-frame
  P.update = function (dt) {
    const g = this.game, pl = g.player, room = pl.room;
    if (!room) return;
    room.used = performance.now();
    // leaving by walking onto the doormat
    const tx = (pl.x / TS) | 0, ty = ((pl.y + 2) / TS) | 0;
    if (tx === room.exit.x && ty === room.exit.y && g.input.stick.y > 0.3) return this.exit();
    if (pl.y > room.exit.y * TS + 12) return this.exit();
    this.t -= dt;
    if (room.copsT > 0) {
      room.copsT -= dt;
      if (room.copsT <= 0 && g.law.incident) {
        for (let k = 0; k < 2; k++) {
          const c = this.spawnAt(room, null, { x: room.entry.x + k, y: room.entry.y }, { cop: true, role: 'cop', city: room.b.cityId });
          if (c) { c.look = g.pop.makeLook(R.mulberry(R.rng.int(0, 1e9)), { fem: false, age: 35, role: 'cop', city: room.b.cityId }); c.stay = false; g.actors.setFight(c, pl); g.law.incident.units.push(c); }
        }
        g.actors.say(g.actors.list[g.actors.list.length - 1], 'Police! Nobody move!');
      }
    }
    if (this.t > 0) return;
    this.t = 1.5;
    // schedules: people leave, others arrive
    const key = 'b:' + room.b.id;
    let inside = 0;
    for (const a of g.actors.list) {
      if (a.room !== room || a.dead || a.removed) continue;
      inside++;
      if (!a.person || a.crew) continue;
      const want = g.life.desiredKey(a.person);
      const calm = a.state === 'idle' || a.state === 'hang' || a.state === 'wander' || a.state === 'perform';
      if (want !== key && calm && !a.leaving) {
        a.leaving = true;
        a.stay = false;
        g.actors.goTo(a, room.exit.x, room.exit.y - 1, { enter: true, placeKey: want, near: 8 });
        a.state = 'travel';
      }
    }
    if (inside < 12 && room.mode !== 'breakin') {
      const occ = g.life.occupants(room.b);
      const p = occ.find((q) => !q.actor);
      if (p && R.rng() < 0.5) {
        const h = this.spawnAt(room, p, room.entry);
        if (h) {
          const s = R.rng.pick(p.work === room.b.id && room.staff.length ? room.staff : room.seats.length ? room.seats : room.extra);
          h.spot = { x: s.x, y: s.y, city: room.b.city, kind: 'room' };
          h.stay = p.work === room.b.id;
          g.actors.goTo(h, s.x, s.y, { near: 6 });
          h.state = 'travel';
          if (R.rng() < 0.5) g.actors.say(h, R.rng.pick(['Evening, all.', 'What a day.', 'The usual, please.', 'Hey!']));
        }
      }
    }
  };

  // ---------------------------------------------------------------- furniture
  P.furnitureAhead = function () {
    const g = this.game, pl = g.player, w = g.world;
    const tx = (pl.x / TS) | 0, ty = ((pl.y - 4) / TS) | 0;
    const [dx, dy] = R.DIRS[pl.dir];
    const cands = [[tx + dx, ty + dy], [tx + dx, (pl.y / TS | 0) + dy], [tx, ty - 1], [tx - 1, ty], [tx + 1, ty], [tx, ty + 1]];
    for (const [x, y] of cands) {
      const o = w.o(x, y);
      if (o && D.furniture[o]) return { o, x, y, f: D.furniture[o] };
    }
    return null;
  };
  P.staffIn = function (room) {
    return this.game.actors.list.find((a) => a.room === room && a.staff && !a.dead && a.down <= 0 && a.state !== 'flee' && a.state !== 'sleep');
  };
  P.furnitureAction = function (fa) {
    const g = this.game, pl = g.player, room = pl.room, f = fa.f;
    const staff = this.staffIn(room);
    const owned = room.b.playerOwned;
    if (f.register) {
      if (staff && !owned) {
        if (pl.weaponOut && D.weapons[pl.weapon] && !D.weapons[pl.weapon].melee || pl.weapon === 'knife') return { label: 'Rob the register', fn: () => this.robRegister(fa, staff) };
        return { label: 'Counter', fn: () => g.ui.openCounter(room.b) };
      }
      return { label: owned ? 'Empty your till' : 'Crack the till', fn: () => this.search(fa, { cash: [Math.max(3, room.b.cash) * 0.8, room.b.cash + 20], items: [] }) };
    }
    if (f.service) return staff || owned ? { label: 'Counter', fn: () => g.ui.openCounter(room.b) } : { label: 'Nobody at the counter', fn: () => g.ui.toast('Nobody is behind the counter.') };
    if (f.shop) return staff || owned ? { label: f.verb, fn: () => g.ui.openShop(f.shop) } : null;
    if (f.cash) return { label: f.verb, fn: () => this.search(fa, f) };
    if (f.bed) return { label: 'Sleep', fn: () => this.sleep(room) };
    if (f.heal) return { label: f.verb, fn: () => { if (pl.hp >= pl.maxHp) return g.ui.toast('You feel fine.'); if (!pl.pay(30)) return g.ui.toast('Thirty bucks, sweetie.', 'warn'); pl.hp = pl.maxHp; pl.bloody = 0; g.ui.toast('Stitched up and good as new.', 'good'); } };
    if (f.jukebox) return { label: f.verb, fn: () => { g.audio.indoorMusic(R.rng.int(0, 2)); pl.cool = Math.min(100, pl.cool + 5); for (const a of g.actors.list) if (a.room === room && !a.staff && !a.dead && R.rng() < 0.4) { a.state = 'perform'; a.timer = 15; } } };
    if (f.game) return { label: f.verb, fn: () => this.gamble(f.game[0], f.game[1], f.game[2]) };
    if (f.arcade) return { label: f.verb, fn: () => { if (!pl.pay(1)) return; const s = R.rng.int(1000, 99000); pl.cool = Math.min(100, pl.cool + 8); g.ui.toast(`TILT! ${s.toLocaleString()} points.${s > 70000 ? ' High score!' : ''}`); } };
    if (f.wash) return { label: f.verb, fn: () => { if (!pl.pay(2)) return; pl.bloody = 0; g.ui.toast('The blood comes out. Mostly.'); } };
    if (f.barber) return { label: f.verb, fn: () => { if (!pl.pay(8)) return; pl.outfitChangedSince = 600; g.ui.toast('Fresh shave, new part. Harder to recognise for a while.', 'good'); } };
    if (f.pray) return { label: f.verb, fn: () => { g.clock.skip(30); pl.cool = Math.min(100, pl.cool + 10); pl.rep.honor += 0.5; g.ui.toast('Half an hour of quiet. Stained glass and old wood.'); } };
    if (f.confess) return { label: f.verb, fn: () => { if (!pl.pay(40)) return g.ui.toast('The Lord takes IOUs. The church does not.', 'warn'); pl.rep.infamy = Math.max(0, pl.rep.infamy - 8); pl.rep.honor += 5; g.ui.toast('Ten Hail Marys and stop hitting people.', 'good'); } };
    if (f.piano) return { label: f.verb, fn: () => { g.audio.sfx('promote'); pl.cool = Math.min(100, pl.cool + 6); for (const a of g.actors.list) if (a.room === room && !a.dead && R.rng() < 0.5) g.actors.say(a, R.rng.pick(['Bravo!', 'Play it again!', 'Not bad for a hood.'])); } };
    if (f.tv) return { label: f.verb, fn: () => { const n = g.pop.news[0]; g.ui.toast(n ? `TV: ${n.text}` : 'TV: Disco still not dead, experts say.'); } };
    if (f.phone) return { label: f.verb, fn: () => g.ui.openPhone() };
    if (f.cook) return { label: f.verb, fn: () => { pl.hp = Math.min(pl.maxHp, pl.hp + 15); g.ui.toast('Eggs and bacon. Hits the spot.'); } };
    if (f.vault) return { label: f.verb, fn: () => g.ui.heist(room.b) };
    return null;
  };
  P.sleep = function (room) {
    const g = this.game, pl = g.player, b = room.b;
    const mine = b.playerOwned || (b.type === 'social' && b.city.def && b.city.def.family === pl.family);
    if (b.type === 'police') return g.ui.toast('You really want to sleep in a cell?');
    if (!mine && (b.type === 'hotel' || b.type === 'motel')) {
      if (!pl.pay(15)) return g.ui.toast('A room is $15.', 'warn');
    } else if (!mine) return g.ui.toast('Not your bed.', 'warn');
    const h = g.clock.hour();
    g.clock.skip(Math.round((h < 7 ? 8 - h : 24 - h + 8) * 60));
    pl.hp = pl.maxHp; pl.drunk = 0; pl.cool = Math.max(pl.cool, 60);
    g.save();
    g.ui.story('Good Morning', `You sleep till 8. Game saved.\n\n${R.rng.pick(['You dream of disco balls.', 'Somebody next door plays the Bee Gees all night.', 'The radiator bangs like a drum.'])}`);
  };
  P.gamble = function (p, stake, mult) {
    const g = this.game, pl = g.player;
    if (!pl.pay(stake)) return g.ui.toast(`You need ${R.fmtMoney(stake)}.`, 'warn');
    if (R.rng() < p) { const w = stake * (mult || 2); pl.addCash(w); g.ui.toast(`You win ${R.fmtMoney(w)}!`, 'good'); pl.cool = Math.min(100, pl.cool + 5); g.audio.sfx('cash'); }
    else g.ui.toast(R.rng.pick([`Lost ${R.fmtMoney(stake)}.`, `Snake eyes. -${R.fmtMoney(stake)}.`, `The house wins. -${R.fmtMoney(stake)}.`]));
  };

  // Searching furniture: loot, noise, and anyone watching may call it in.
  P.search = function (fa, f) {
    const g = this.game, pl = g.player, room = pl.room;
    const key = fa.x * 1000 + fa.y;
    if (room.searched.get(key) === g.pop.day) return g.ui.toast('Already cleaned out.');
    room.searched.set(key, g.pop.day);
    const cash = f.cash ? Math.round(R.rng.range(f.cash[0], f.cash[1])) : 0;
    const got = [];
    if (cash > 0) { pl.addCash(cash); got.push(R.fmtMoney(cash)); }
    if (f.o === O.REGISTER || fa.o === O.REGISTER) room.b.cash = 0;
    if (f.items && f.items.length && R.rng() < 0.7) {
      const it = R.rng.pick(f.items);
      if (D.loot[it]) { pl.inv.loot[it] = (pl.inv.loot[it] || 0) + 1; got.push(D.loot[it].name); }
      else if (D.consumables[it]) { pl.inv.cons[it] = (pl.inv.cons[it] || 0) + 1; got.push(D.consumables[it].name); }
      else if (it === 'ammo') { pl.inv.ammo.pistol += 6; got.push('6 rounds'); }
    }
    g.ui.toast(got.length ? `Found ${got.join(' and ')}.` : 'Nothing worth taking.');
    g.audio.sfx('loot');
    if (room.b.playerOwned) return;
    // noise wakes sleepers; anyone awake who sees it reacts
    g.actors.noise(pl.x, pl.y, TS * (pl.sneak ? 3 : 6), 'rustle', pl);
    const watching = g.actors.list.some((a) => a.room === room && !a.dead && a.kind === 'h' && a.state !== 'sleep' && a.down <= 0 && !a.crew && g.world.los(a.x, a.y - 8, pl.x, pl.y - 8));
    if (watching) g.law.crime(room.mode === 'breakin' ? 'burglary' : 'theft', pl.x, pl.y, {});
  };
  P.robRegister = function (fa, clerk) {
    const g = this.game, pl = g.player, room = pl.room, b = room.b;
    const brave = clerk.tr.brave;
    const roll = R.rng();
    const cash = g.pop.day - b.robbedDay >= 3 ? b.cash + R.rng.int(20, 80) : R.rng.int(3, 15);
    b.robbedDay = g.pop.day;
    g.law.crime('robbery', pl.x, pl.y, { victim: clerk });
    if (roll < 0.1 + brave * 0.25) {
      g.actors.arm(clerk, 'shotgun');
      clerk.hostile = true;
      clerk.stay = false;
      g.actors.setFight(clerk, pl);
      g.actors.say(clerk, 'Not in MY store!');
      return;
    }
    if (roll < 0.25 + brave * 0.2) { g.audio.sfx('alarm'); g.ui.toast('The clerk hit the silent alarm!', 'bad'); }
    pl.addCash(cash);
    g.actors.setCower(clerk, 8);
    g.actors.say(clerk, R.rng.pick(['Take it! Just take it!', 'Please, I have a family!', 'It\'s all there, I swear!']));
    if (clerk.person) { clerk.person.fear = Math.min(100, clerk.person.fear + 40); clerk.person.opinion -= 30; }
    b.city.prosperity = Math.max(0, (b.city.prosperity || 50) - 2);
    g.pop.addNews(b.cityId, `${b.name} robbed ${pl.masked ? 'by a masked gunman' : 'by a big fella in a fedora'}.`);
    g.jobs.progress('robbed', b);
    g.ui.toast(`Took ${R.fmtMoney(cash)} from the register.`, 'warn');
  };
})();
